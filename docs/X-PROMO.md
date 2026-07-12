# X / Twitter promo drafts

Repo: https://github.com/Zion74/grok-build-executor  
Deep dive: `docs/COLLABORATION.md`

---

## 中文主帖（推荐）

```text
Codex 原生子 agent 调不了 Grok。

我们踩完坑后的稳定配合：

① Codex(Sol) 写 job 目录
   PROMPT.md → 人类/Grok Build 打开
   RESULT.md → Sol 亲审 diff + 重跑测试

② 需要并行时：Grok 总控 + 不重叠 ownership 的子 agent
③ 小任务才用 headless CLI wrapper（隔离 SuperGrok OAuth）

CLI/PS 直调 grok.exe 的坑也写了：参数被拆、Cancelled、超时、项目 .mcp.json 拖 Figma…

GitHub: https://github.com/Zion74/grok-build-executor
docs/COLLABORATION.md
```

---

## 中文线程

**1/3**

```text
想「Sol 规划 + Grok 干活」别硬 spawn。

现在更稳的是「文档交接」：
job 文件夹里 PROMPT / RESULT，
Grok Build 交互执行（可总控多 subagent），
Codex 只负责边界和验收。
```

**2/3**

```text
我们用 headless CLI 踩过的坑：

• PowerShell 把 node --test 拆成 -test
• 超大任务卡 stopReason=Cancelled（exit 0 也算失败）
• dontAsk 没给 git 前缀 → 静默拒绝
• Codex timeout 掐死长任务
• 项目 .mcp.json 的 Figma MCP 空等 30s

所以大改动改走 PROMPT→RESULT 文件协议。
```

**3/3**

```text
Skill + 协议文档开源了：

npx skills add Zion74/grok-build-executor -g -y

读 docs/COLLABORATION.md
欢迎 PR / 补充失败案例。
不隶属 xAI / OpenAI。
```

---

## English short

```text
Codex can’t natively spawn Grok.

What worked for us:
• Sol writes PROMPT.md in a job folder
• Human runs it in Grok Build (optional coordinator + exclusive subagents)
• Grok writes RESULT.md
• Sol re-diff + re-test (never trust Grok “ok”)

Headless CLI only for tiny clean-worktree cards.

Lessons from CLI/PS failures → docs/COLLABORATION.md
https://github.com/Zion74/grok-build-executor
```

---

## Hashtags (optional)

`#Codex #Grok #GrokBuild #AgentSkills #AICoding`
