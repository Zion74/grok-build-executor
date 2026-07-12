# X / Twitter promo drafts

Copy-paste ready. **No personal paths, tokens, or private screenshots.**

Replace nothing required — repo is `https://github.com/Zion74/grok-build-executor`.

---

## 中文短帖（推荐主帖）

```text
Codex 原生子 agent 调不了 Grok。

我开源了一个 skill：让 GPT‑5.6 Sol 当总控，Grok 4.5 当受控执行器。

链路：
任务卡 → 官方 Grok Build headless → 作用域 allowlist → JSON 回传 → Sol 自己验收

- SuperGrok OAuth（隔离 ~/.grok-executor）
- 禁止伪装成 native spawn
- coding agent 可按文档一键配置

GitHub: https://github.com/Zion74/grok-build-executor

安装：
npx skills add Zion74/grok-build-executor -g -y
```

---

## 中文长帖 / 线程 1/3

```text
1/ 很多人想「Sol 规划 + Grok 干活」，但 Codex multi-agent 模型列表里没有 Grok。

正确姿势不是硬 spawn，而是：
Skill + 官方 Grok Build CLI headless。
```

## 线程 2/3

```text
2/ 我把安全默认值写进 wrapper：

• 固定 grok-4.5
• dontAsk + 路径/命令 allowlist
• 关 nested subagents / memory / plan
• 任务卡只能写在 executor 目录
• 返回 JSON：ok / changedFiles / text…

text 只是线索；diff + 测试由 Sol 复验。
```

## 线程 3/3

```text
3/ 给 coding agent 的安装话术也写好了（docs/CODING-AGENT-SETUP.md）。

仓库：
https://github.com/Zion74/grok-build-executor

npx skills add Zion74/grok-build-executor -g -y

欢迎 issue / PR。不隶属于 xAI 或 OpenAI。
```

---

## English short

```text
Codex can’t natively spawn Grok models.

Open-source skill: GPT‑5.6 Sol orchestrates, Grok 4.5 executes via official Grok Build headless + SuperGrok OAuth.

Task card → scoped allowlist → JSON envelope → orchestrator re-verifies.

https://github.com/Zion74/grok-build-executor

npx skills add Zion74/grok-build-executor -g -y
```

---

## Hashtag suggestions (optional, light)

`#Codex #Grok #GrokBuild #AICoding #AgentSkills #SuperGrok`

Avoid engagement-bait screenshots that show email, machine username, or token fragments.
