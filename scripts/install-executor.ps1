<#
.SYNOPSIS
  One-shot setup for grok-build-executor (Codex / GPT orchestrator + Grok 4.5).

.DESCRIPTION
  Safe for a coding agent to run. Creates isolated SuperGrok OAuth home,
  copies executor config, installs AGENTS.md snippet, verifies CLI.

  Does NOT print or copy auth secrets. OAuth login still requires a human browser step.

.PARAMETER SkillRoot
  Path to this skill directory (folder that contains SKILL.md).

.PARAMETER SkipAgentsMd
  Do not append the Codex AGENTS.md snippet.

.PARAMETER SkipLoginCheck
  Do not require auth.json yet (first-time install before human OAuth).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-executor.ps1
#>
[CmdletBinding()]
param(
    [string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$SkipAgentsMd,
    [switch]$SkipLoginCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

$realHome = [Environment]::GetFolderPath('UserProfile')
if (-not $realHome) { $realHome = $env:USERPROFILE }

$skillMd = Join-Path $SkillRoot 'SKILL.md'
$configSrc = Join-Path $SkillRoot 'assets\config.toml'
$snippetSrc = Join-Path $SkillRoot 'examples\AGENTS.md.snippet'
$wrapper = Join-Path $SkillRoot 'scripts\invoke-grok-executor.ps1'

if (-not (Test-Path -LiteralPath $skillMd)) {
    throw "SKILL.md not found under SkillRoot: $SkillRoot"
}
if (-not (Test-Path -LiteralPath $configSrc)) {
    throw "Missing assets/config.toml"
}
if (-not (Test-Path -LiteralPath $wrapper)) {
    throw "Missing scripts/invoke-grok-executor.ps1"
}

Write-Step "Locate Grok Build CLI"
$grokCandidates = @(
    (Join-Path $realHome '.grok\bin\grok.exe'),
    (Join-Path $realHome '.grok\bin\grok')
)
try {
    $cmd = Get-Command grok -ErrorAction Stop
    $grokCandidates = @($cmd.Source) + $grokCandidates
} catch { }

$grokPath = $grokCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $grokPath) {
    Write-Host @"
Grok Build CLI not found.

Install from xAI docs, then re-run this script:
  https://docs.x.ai/

Typical Windows binary:
  $realHome\.grok\bin\grok.exe
"@ -ForegroundColor Yellow
    throw "grok CLI missing"
}
Write-Host "grok: $grokPath"

Write-Step "Create isolated executor home"
$grokHome = Join-Path $realHome '.grok-executor'
$taskCards = Join-Path $grokHome 'task-cards'
$profileDir = Join-Path $grokHome 'profile'
$logs = Join-Path $grokHome 'logs\executor'
New-Item -ItemType Directory -Force -Path $grokHome, $taskCards, $profileDir, $logs | Out-Null

$configDst = Join-Path $grokHome 'config.toml'
if (-not (Test-Path -LiteralPath $configDst)) {
    Copy-Item -LiteralPath $configSrc -Destination $configDst
    Write-Host "wrote $configDst"
} else {
    Write-Host "keep existing $configDst (not overwritten)"
}

$readmeTask = Join-Path $taskCards 'README.md'
if (-not (Test-Path -LiteralPath $readmeTask)) {
    @"
# Task cards

Codex / orchestrator agents must write approved Grok task cards here:

  $taskCards\<run-id>.md

Do not write task cards into product repositories.
"@ | Set-Content -Path $readmeTask -Encoding utf8
}

Write-Step "Check SuperGrok OAuth for executor home"
$auth = Join-Path $grokHome 'auth.json'
$env:GROK_HOME = $grokHome
if (-not (Test-Path -LiteralPath $auth)) {
    Write-Host @"
auth.json missing under $grokHome

Human action required (coding agent must STOP and ask the user):

  `$env:GROK_HOME = '$grokHome'
  & '$grokPath' login

Use a SuperGrok-capable account. Do not copy interactive ~/.grok/auth.json by hand
unless you understand the security tradeoffs.
"@ -ForegroundColor Yellow
    if (-not $SkipLoginCheck) {
        throw "OAuth not configured. Run grok login with GROK_HOME=$grokHome then re-run install."
    }
} else {
    Write-Host "auth.json present (contents not printed)"
    try {
        $models = & $grokPath models 2>&1 | Out-String
        Write-Host $models
        if ($models -notmatch 'grok-4\.5') {
            Write-Host "WARNING: grok-4.5 not listed. Check subscription / model availability." -ForegroundColor Yellow
        } else {
            Write-Host "grok-4.5 available"
        }
    } catch {
        Write-Host "WARNING: could not list models: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $SkipAgentsMd) {
    Write-Step "Install Codex AGENTS.md snippet"
    $agentsMd = Join-Path $realHome '.codex\AGENTS.md'
    $codexDir = Join-Path $realHome '.codex'
    if (-not (Test-Path -LiteralPath $codexDir)) {
        New-Item -ItemType Directory -Force -Path $codexDir | Out-Null
    }
    $marker = '<!-- grok-build-executor:start -->'
    $snippet = Get-Content -Raw -Encoding utf8 -LiteralPath $snippetSrc
    if (Test-Path -LiteralPath $agentsMd) {
        $existing = Get-Content -Raw -Encoding utf8 -LiteralPath $agentsMd
        if ($existing -match [regex]::Escape($marker)) {
            Write-Host "AGENTS.md already contains grok-build-executor block"
        } else {
            Add-Content -LiteralPath $agentsMd -Value "`n$snippet" -Encoding utf8
            Write-Host "appended snippet to $agentsMd"
        }
    } else {
        Set-Content -LiteralPath $agentsMd -Value $snippet -Encoding utf8
        Write-Host "created $agentsMd"
    }
}

Write-Step "Skill install hint for agents / humans"
Write-Host @"
If this skill is not already under ~/.agents/skills/grok-build-executor:

  npx skills add Zion74/grok-build-executor -g -y

Or copy this folder to:

  $realHome\.agents\skills\grok-build-executor
"@

Write-Step "Smoke command (optional)"
Write-Host @"
After OAuth is ready, a coding agent can run a read-only smoke with a clean git worktree
and a task card under:

  $taskCards

Example invoke:

  powershell -NoProfile -ExecutionPolicy Bypass -File ``
    '$wrapper' ``
    -TaskCardPath '$taskCards\demo.md' ``
    -WorkingDirectory '<clean-git-worktree>' ``
    -ReadOnly ``
    -RequireCleanIsolation
"@

Write-Host ""
Write-Host "install-executor.ps1 finished OK" -ForegroundColor Green
Write-Host "GROK_HOME=$grokHome"
Write-Host "WRAPPER=$wrapper"
