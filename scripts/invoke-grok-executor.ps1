[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TaskCardPath,

    [Parameter(Mandatory)]
    [string]$WorkingDirectory,

    [string[]]$WritablePath = @(),
    [string[]]$AllowedCommandPrefix = @(),

    [ValidateSet('grok-4.5')]
    [string]$Model = 'grok-4.5',

    [ValidateRange(1, 100)]
    [int]$MaxTurns = 40,

    [string]$GrokHome = '',
    [string]$GrokPath = '',

    [switch]$ReadOnly,
    [switch]$AllowWebSearch,

    # When set, skip the fixed task-cards directory requirement (diagnostics only).
    [switch]$AllowExternalTaskCard,

    # When set, fail if inspect still sees real-user .claude / .agents sources.
    [switch]$RequireCleanIsolation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Real Windows profile (not process HOME). Grok Claude-compat resolves this path
# even when the child HOME/USERPROFILE is shadowed.
$script:RealUserProfile = [Environment]::GetFolderPath('UserProfile')
if (-not $script:RealUserProfile) {
    $script:RealUserProfile = $env:USERPROFILE
}
if (-not $script:RealUserProfile) {
    $script:RealUserProfile = $HOME
}

if (-not $GrokHome) {
    $GrokHome = Join-Path $script:RealUserProfile '.grok-executor'
}
if (-not $GrokPath) {
    $candidates = @(
        (Join-Path $script:RealUserProfile '.grok\bin\grok.exe'),
        (Join-Path $script:RealUserProfile '.grok\bin\grok'),
        (Join-Path $script:RealUserProfile '.local\bin\grok')
    )
    $fromPath = $null
    try { $fromPath = (Get-Command grok -ErrorAction Stop).Source } catch { }
    if ($fromPath) { $candidates = @($fromPath) + $candidates }
    $GrokPath = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $GrokPath) {
        $GrokPath = $candidates[0]
    }
}

function Normalize-RelativePattern {
    param([Parameter(Mandatory)][string]$Value)

    $candidate = $Value.Trim().Replace('\', '/')
    if (-not $candidate) {
        throw 'Writable path patterns cannot be empty.'
    }
    if ([IO.Path]::IsPathRooted($candidate) -or $candidate -match '(^|/)\.\.(/|$)') {
        throw "Writable path must stay relative to the worktree: $Value"
    }
    if ($candidate -match '[\r\n()]') {
        throw "Writable path contains permission-rule control characters: $Value"
    }
    return $candidate
}

function Normalize-CommandPrefix {
    param([Parameter(Mandatory)][string]$Value)

    $candidate = $Value.Trim()
    if (-not $candidate) {
        throw 'Allowed command prefixes cannot be empty.'
    }
    if ($candidate -match '[\r\n()*?;&|<>`$]') {
        throw "Allowed command prefix contains permission-rule control characters: $Value"
    }
    return $candidate
}

function Test-ChangedPathAllowed {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    $normalizedPath = $Path.Replace('\', '/')
    foreach ($pattern in $Patterns) {
        $wildcard = $pattern.Replace('**', '*')
        if ($normalizedPath -like $wildcard) {
            return $true
        }
    }
    return $false
}

function Get-GitLines {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $lines = @(& $script:GitPath @Arguments 2>$null)
    $commandExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($commandExitCode -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
    return @($lines | ForEach-Object { "$($_)".Trim() } | Where-Object { $_ })
}

$exitCode = 2
$mutex = $null
$hasMutex = $false
$leaderSocket = $null
$gitConfigPath = $null
$stdoutTemp = $null
$stderrLog = $null
$previousEnvironment = @{}
$executorProfile = $null

try {
    if (-not (Test-Path -LiteralPath $GrokPath -PathType Leaf)) {
        throw "Official Grok CLI not found: $GrokPath"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $GrokHome 'config.toml') -PathType Leaf)) {
        throw "Executor config missing: $(Join-Path $GrokHome 'config.toml')"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $GrokHome 'auth.json') -PathType Leaf)) {
        throw "Executor OAuth is missing. Run grok login with GROK_HOME=$GrokHome"
    }
    if (-not (Test-Path -LiteralPath $TaskCardPath -PathType Leaf)) {
        throw "Task card not found: $TaskCardPath"
    }
    if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
        throw "Working directory not found: $WorkingDirectory"
    }

    $taskInfo = Get-Item -LiteralPath $TaskCardPath
    if ($taskInfo.Length -gt 65536) {
        throw 'Task card exceeds the 64 KiB context boundary.'
    }

    $resolvedWorktree = (Resolve-Path -LiteralPath $WorkingDirectory).ProviderPath
    $resolvedTaskCard = (Resolve-Path -LiteralPath $TaskCardPath).ProviderPath
    $taskCardsRoot = (Join-Path $GrokHome 'task-cards')
    New-Item -ItemType Directory -Force -Path $taskCardsRoot | Out-Null
    $resolvedTaskCardsRoot = (Resolve-Path -LiteralPath $taskCardsRoot).ProviderPath
    if (-not $AllowExternalTaskCard) {
        $cardFull = [IO.Path]::GetFullPath($resolvedTaskCard)
        $rootFull = [IO.Path]::GetFullPath($resolvedTaskCardsRoot).TrimEnd('\') + '\'
        if (-not $cardFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Task card must live under $resolvedTaskCardsRoot (got $resolvedTaskCard). Pass -AllowExternalTaskCard only for diagnostics."
        }
    }

    $writablePatterns = @($WritablePath | ForEach-Object { Normalize-RelativePattern $_ })
    $commandPrefixes = @($AllowedCommandPrefix | ForEach-Object { Normalize-CommandPrefix $_ })

    if ($env:OS -eq 'Windows_NT') {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $worktreeOwner = (Get-Acl -LiteralPath $resolvedWorktree).Owner
        try {
            $ownerAccount = New-Object Security.Principal.NTAccount($worktreeOwner)
            $ownerSid = $ownerAccount.Translate([Security.Principal.SecurityIdentifier])
        }
        catch {
            throw "Unable to resolve the Grok worktree owner '$worktreeOwner' to a Windows SID."
        }
        if ($ownerSid.Value -ne $currentIdentity.User.Value) {
            throw "Grok worktree owner mismatch: owner=$worktreeOwner; executor=$($currentIdentity.Name). Create the worktree as the Windows user that owns the isolated Grok OAuth session."
        }
    }

    if ($ReadOnly -and $writablePatterns.Count -gt 0) {
        throw 'ReadOnly mode cannot receive writable paths.'
    }
    if (-not $ReadOnly -and $writablePatterns.Count -eq 0) {
        throw 'Edit mode requires at least one writable path.'
    }

    $mutex = New-Object Threading.Mutex($false, 'Local\GrokBuildExecutor')
    $hasMutex = $mutex.WaitOne(0)
    if (-not $hasMutex) {
        throw 'Another Grok executor process is active; concurrency is disabled until forward-tested.'
    }

    $runId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $logDirectory = Join-Path $GrokHome 'logs\executor'
    $executorProfile = Join-Path $GrokHome 'profile'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    New-Item -ItemType Directory -Force -Path $executorProfile | Out-Null
    $stderrLog = Join-Path $logDirectory "$runId.stderr.log"
    $resultLog = Join-Path $logDirectory "$runId.result.json"
    $stdoutTemp = [IO.Path]::GetTempFileName()
    $gitConfigPath = Join-Path ([IO.Path]::GetTempPath()) "$runId.gitconfig"
    $leaderSocket = Join-Path ([IO.Path]::GetTempPath()) "$runId.sock"

    $safeDirectory = $resolvedWorktree.Replace('\', '/')
    [IO.File]::WriteAllText($gitConfigPath, "[safe]`n`tdirectory = $safeDirectory`n", (New-Object Text.UTF8Encoding($false)))

    foreach ($name in @(
            'GROK_HOME', 'GROK_WRITE_FILE', 'GIT_CONFIG_GLOBAL',
            'HOME', 'USERPROFILE', 'HOMEDRIVE', 'HOMEPATH',
            'APPDATA', 'LOCALAPPDATA',
            'CLAUDE_CONFIG_DIR', 'CLAUDE_HOME',
            'GROK_CLAUDE_SKILLS_ENABLED', 'GROK_CLAUDE_RULES_ENABLED',
            'GROK_CLAUDE_AGENTS_ENABLED', 'GROK_CLAUDE_MCPS_ENABLED',
            'GROK_CLAUDE_HOOKS_ENABLED',
            'GROK_CURSOR_SKILLS_ENABLED', 'GROK_CURSOR_RULES_ENABLED',
            'GROK_CURSOR_AGENTS_ENABLED', 'GROK_CURSOR_MCPS_ENABLED',
            'GROK_CURSOR_HOOKS_ENABLED'
        )) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    $env:GROK_HOME = $GrokHome
    $env:GROK_WRITE_FILE = if ($ReadOnly) { '0' } else { '1' }
    $env:GIT_CONFIG_GLOBAL = $gitConfigPath
    $env:HOME = $executorProfile
    $env:USERPROFILE = $executorProfile
    $env:APPDATA = (Join-Path $executorProfile 'AppData\Roaming')
    $env:LOCALAPPDATA = (Join-Path $executorProfile 'AppData\Local')
    $env:CLAUDE_CONFIG_DIR = (Join-Path $executorProfile '.claude')
    $env:CLAUDE_HOME = $env:CLAUDE_CONFIG_DIR
    foreach ($flag in @(
            'GROK_CLAUDE_SKILLS_ENABLED', 'GROK_CLAUDE_RULES_ENABLED',
            'GROK_CLAUDE_AGENTS_ENABLED', 'GROK_CLAUDE_MCPS_ENABLED',
            'GROK_CLAUDE_HOOKS_ENABLED',
            'GROK_CURSOR_SKILLS_ENABLED', 'GROK_CURSOR_RULES_ENABLED',
            'GROK_CURSOR_AGENTS_ENABLED', 'GROK_CURSOR_MCPS_ENABLED',
            'GROK_CURSOR_HOOKS_ENABLED'
        )) {
        [Environment]::SetEnvironmentVariable($flag, 'false', 'Process')
    }
    New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA, $env:CLAUDE_CONFIG_DIR | Out-Null
    if ($env:OS -eq 'Windows_NT') {
        $profileDrive = [IO.Path]::GetPathRoot($executorProfile).TrimEnd('\')
        if ($profileDrive -match '^[A-Za-z]:$') {
            $env:HOMEDRIVE = $profileDrive
            $env:HOMEPATH = $executorProfile.Substring($profileDrive.Length)
        }
    }

    # Preflight isolation check (skills HOME-shadow works; Claude settings may
    # still resolve the real Windows user profile — see SKILL.md).
    $inspectJsonPath = Join-Path $logDirectory "$runId.inspect.json"
    $ErrorActionPreference = 'Continue'
    & $GrokPath inspect --json 1> $inspectJsonPath 2> $null
    $inspectExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $claudeResidue = @()
    $agentsResidue = @()
    if ($inspectExit -eq 0 -and (Test-Path -LiteralPath $inspectJsonPath)) {
        try {
            $inspectRaw = Get-Content -Raw -Encoding UTF8 -LiteralPath $inspectJsonPath
            $inspect = $inspectRaw | ConvertFrom-Json
            $realClaude = (Join-Path $script:RealUserProfile '.claude')
            $realAgents = (Join-Path $script:RealUserProfile '.agents')
            foreach ($src in @($inspect.permissions.sources)) {
                if ("$src" -like "*$realClaude*") { $claudeResidue += "permissions:$src" }
            }
            foreach ($hook in @($inspect.hooks)) {
                $hp = "$($hook.source.path)"
                if ($hp -like "*$realClaude*") { $claudeResidue += "hook:$hp" }
            }
            foreach ($plugin in @($inspect.plugins)) {
                $pp = "$($plugin.path)"
                if ($pp -like "*$realClaude*") { $claudeResidue += "plugin:$pp" }
            }
            foreach ($skill in @($inspect.skills)) {
                $sp = "$($skill.source.path)"
                if ($sp -like "*$realAgents*") { $agentsResidue += "skill:$sp" }
                if ($sp -like "*$realClaude*") { $claudeResidue += "skill:$sp" }
            }
        }
        catch {
            # inspect parse failure is non-fatal unless strict isolation required
            if ($RequireCleanIsolation) {
                throw "Failed to parse grok inspect output at $inspectJsonPath : $($_.Exception.Message)"
            }
        }
    }
    elseif ($RequireCleanIsolation) {
        throw "grok inspect --json failed (exit $inspectExit); cannot prove isolation."
    }
    if ($RequireCleanIsolation -and ($claudeResidue.Count -gt 0 -or $agentsResidue.Count -gt 0)) {
        throw "Isolation leak detected.`nClaude: $($claudeResidue -join '; ')`nAgents: $($agentsResidue -join '; ')`nSee $GrokHome\docs\claude-residue-archive.md"
    }

    $script:GitPath = (Get-Command git -ErrorAction Stop).Source
    $insideWorktree = @(Get-GitLines @('-C', $resolvedWorktree, 'rev-parse', '--is-inside-work-tree'))
    if ($insideWorktree.Count -ne 1 -or $insideWorktree[0] -ne 'true') {
        throw 'Working directory is not a Git worktree.'
    }
    $statusBefore = @(Get-GitLines @('-C', $resolvedWorktree, 'status', '--short', '--untracked-files=all'))
    if ($statusBefore.Count -gt 0) {
        throw "Working tree must be clean before delegation:`n$($statusBefore -join "`n")"
    }

    $taskText = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedTaskCard
    $grokArguments = @(
        '--leader-socket', $leaderSocket,
        '--no-auto-update',
        '-p', $taskText,
        '--cwd', $resolvedWorktree,
        '--model', $Model,
        '--output-format', 'json',
        '--no-subagents',
        '--no-memory',
        '--no-plan',
        '--max-turns', "$MaxTurns",
        '--permission-mode', 'dontAsk',
        '--allow', 'Read',
        '--allow', 'Grep'
    )

    if (-not $AllowWebSearch) {
        $grokArguments += '--disable-web-search'
    }
    foreach ($pattern in $writablePatterns) {
        $permissionPattern = if ($pattern.StartsWith('**/')) { $pattern } else { "**/$pattern" }
        $grokArguments += @('--allow', "Edit($permissionPattern)")
    }
    foreach ($prefix in $commandPrefixes) {
        $grokArguments += @('--allow', "Bash($prefix*)")
    }
    foreach ($rule in @(
        'Bash(git push*)',
        'Bash(git reset --hard*)',
        'Bash(git clean*)',
        'Bash(rm *)',
        'Bash(del *)',
        'Bash(Remove-Item *)',
        'Bash(format *)',
        'Bash(shutdown *)',
        'Bash(Stop-Computer*)',
        'Bash(Restart-Computer*)'
    )) {
        $grokArguments += @('--deny', $rule)
    }

    $ErrorActionPreference = 'Continue'
    & $GrokPath @grokArguments 1> $stdoutTemp 2> $stderrLog
    $grokExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    $rawOutput = Get-Content -Raw -Encoding Unicode -LiteralPath $stdoutTemp
    if (-not $rawOutput.Trim()) {
        $rawOutput = Get-Content -Raw -Encoding UTF8 -LiteralPath $stdoutTemp
    }
    try {
        $grokResult = $rawOutput | ConvertFrom-Json
    }
    catch {
        $rawLog = Join-Path $logDirectory "$runId.raw-stdout.log"
        Copy-Item -LiteralPath $stdoutTemp -Destination $rawLog -Force
        throw "Grok returned non-JSON output. Raw output: $rawLog"
    }

    $changedFiles = @(@(
        Get-GitLines @('-C', $resolvedWorktree, 'diff', '--name-only', '--')
        Get-GitLines @('-C', $resolvedWorktree, 'diff', '--cached', '--name-only', '--')
        Get-GitLines @('-C', $resolvedWorktree, 'ls-files', '--others', '--exclude-standard')
    ) | Sort-Object -Unique)

    $scopeViolations = @($changedFiles | Where-Object {
        -not (Test-ChangedPathAllowed -Path $_ -Patterns $writablePatterns)
    })

    $ErrorActionPreference = 'Continue'
    $diffCheckOutput = @(& $script:GitPath -C $resolvedWorktree diff --check 2>&1 | ForEach-Object { "$_" })
    $diffCheckExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $diffCheckOk = ($diffCheckExitCode -eq 0)
    $statusAfter = @(Get-GitLines @('-C', $resolvedWorktree, 'status', '--short', '--untracked-files=all'))
    $taskCardHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedTaskCard).Hash
    $stderrTail = if (Test-Path -LiteralPath $stderrLog) {
        @((Get-Content -LiteralPath $stderrLog -Tail 20 -ErrorAction SilentlyContinue)) -join "`n"
    } else {
        ''
    }

    $ok = (
        $grokExitCode -eq 0 -and
        $grokResult.stopReason -eq 'EndTurn' -and
        $scopeViolations.Count -eq 0 -and
        $diffCheckOk
    )

    $envelope = [ordered]@{
        runId = $runId
        ok = $ok
        exitCode = $grokExitCode
        stopReason = $grokResult.stopReason
        sessionId = $grokResult.sessionId
        model = $Model
        taskCardSha256 = $taskCardHash
        taskCardPath = $resolvedTaskCard
        workingDirectory = $resolvedWorktree
        text = $grokResult.text
        changedFiles = @($changedFiles)
        scopeViolations = @($scopeViolations)
        diffCheckOk = $diffCheckOk
        diffCheckOutput = @($diffCheckOutput)
        statusAfter = @($statusAfter)
        isolation = [ordered]@{
            claudeResidue = @($claudeResidue)
            agentsResidue = @($agentsResidue)
            inspectLog = $inspectJsonPath
            realUserProfile = $script:RealUserProfile
        }
        stderrTail = $stderrTail
        stderrLog = $stderrLog
        resultLog = $resultLog
    }

    $json = $envelope | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($resultLog, $json, (New-Object Text.UTF8Encoding($false)))
    Write-Output $json
    $exitCode = if ($ok) { 0 } else { 1 }
}
catch {
    $failure = [ordered]@{
        ok = $false
        error = $_.Exception.Message
        stderrLog = $stderrLog
    }
    Write-Output ($failure | ConvertTo-Json -Depth 5)
    $exitCode = 2
}
finally {
    if ($leaderSocket -and (Test-Path -LiteralPath $GrokPath -PathType Leaf)) {
        try {
            & $GrokPath leader --leader-socket $leaderSocket kill *> $null
        }
        catch {
        }
    }
    foreach ($name in $previousEnvironment.Keys) {
        $value = $previousEnvironment[$name]
        if ($null -eq $value) {
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
        } else {
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
    foreach ($path in @($gitConfigPath, $stdoutTemp)) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
    if ($hasMutex -and $mutex) {
        $mutex.ReleaseMutex()
    }
    if ($mutex) {
        $mutex.Dispose()
    }
}

exit $exitCode
