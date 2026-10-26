---
name: app-replica
description: |
  参照一个现有 App（桌面或网页）独立复刻一版：睡前用 REA 与实际操作拆解原 App、把它的真实行为写成锁定测试，
  再让 Coding Agent 无人值守连跑几小时，醒来按清单晨检。当用户说"复刻/仿一个 XX App""照着 XX 做一个"
  "用 REA 逆向 XX 再让 AI 实现""睡前让 AI 做、醒来验收""夜跑/长跑开发"时使用。
metadata:
  version: "1.0.0"
---

# 复刻一个 App：睡前准备 → 夜跑 → 晨检

2026-10-26 用 Typora 跑通一次：准备约 1 小时，无人值守约 8 小时；成品在 12 个共同场景上通过 12 个，对照组 TyporaX（同样用 AI 一夜做成）通过 4 个。
差别全在锁定测试：对照组输掉的场景都没有被测试覆盖。

**核心原则**：夜里没人看，Agent 只会朝"能被检查到"的方向努力，检查不到的就当作已完成。所以睡前要把三件事变成机器能判断的东西：
做什么（需求表）、做到什么算完（锁定测试 + 一条验收命令）、哪些不能碰（AGENTS.md 边界）。

模板在 `references/`，每步标了用哪个。工作目录统一用 `~/labs/<代号>/`（`inputs/` 原 App，`evidence/` 拆解证据，`notes/` 方法记录，`run/` 夜跑驱动与日志，`<代号>/` 新仓库）。

## 0. 选题（人定，5 分钟）

三条都满足才做：

1. 价值主要在客户端，能观察到。云端模型、服务端算法（如 Typeless 的识别与润色）复刻不了，只能换成自己的后端。
2. 能用成熟开源组件拼出来。Agent 擅长组装，不擅长从零写编辑器内核、渲染引擎。
3. 核心行为能自动化测试：有可读回的结果（文件字节、DOM 文本、导出产物）。

产出：一句话目标、"不做什么"清单、对照组（同类开源实现，没有就用原 App 本身）。

## 1. 环境与配额（Agent，10–20 分钟）

逐项确认，任何一项不满足先解决再往下：

- [ ] **执行模型的配额**：查清速率限制和周期上限（如 GLM 的"5 小时用量上限"）。试跑时第一执行模型大部分时间被限流浪费。
- [ ] **至少两条执行通道**：主力 + 备用，各用一句话冒烟测试确认真能调通（`kll resolve claude-code <模型> --json --launch-env-file <0600 文件>`）。本机 Claude 官方订阅在 CLI 里可能未登录，不要想当然。
- [ ] **凭据不回显**：只检查 env 文件的键名，不打印值。
- [ ] **磁盘**：可用 ≥ 10 GB。Playwright 用系统 Chrome，不下载浏览器。
- [ ] **工具版本**：REA 要求 Node ≥ 24.22.1 或 ≥ 26.12.1，用 fnm 装到独立版本，不改默认 Node；`npm install rea-agents@<版本>` 装在 `~/labs/<代号>/tools`。
- [ ] **GUI 自动化**（需要操作原 App 时）：kimi-cu 在 WebView 类 App 里，后台输入可能进不去，⌘S 会报"无 key window"。可行做法：先点标题栏让窗口成为 key window，再用 AX 菜单命令；输入字符时加 activate。有远程桌面连着时，前台操作会被看到，先告知用户。

## 2. 拆解（Agent + 人确认，30–60 分钟）

**先读许可协议**（安装包或官网的 EULA），按层决定用到哪一层，记进方法记录；L3 以上需要用户明确同意，产出只在本机：

| 层 | 来源 | 价值（Typora 实测） |
| --- | --- | --- |
| L0 | 官方文档、帮助、包内自带文档 | 最高：每个语法、每个行为都有描述，能直接翻成用例 |
| L1 | 试用版实际操作，记录"输入 → 结果"（含保存后的文件字节） | 最高：唯一能拿到测试期望值的来源 |
| L2 | 安装包清单、Info.plist、菜单文字（`rea inspect-artifact` / `inspect-plist`） | 中：结构与平台事实 |
| L3 | 界面文件解码（`rea decode-interface-builder`）、打包代码结构（`rea analyze-javascript-application`） | 菜单解码高（多挖出约 50 项功能）；压缩单文件的代码结构几乎为零 |
| L4 | 反编译、动态调试 | 不做 |

REA 的坑：`decode-interface-builder` 默认最多解 64 个文档，常被 Sparkle 等框架的多语言 nib 占满。解法：把 `Info.plist` 和 `Base.lproj` 下需要的 nib 复制到一个骨架 `.app` 再解。

产出：`references/requirements.md` 格式的需求表。P0 = 核心特质（3–6 条，原 App 的灵魂，对照组最可能丢的东西）；P1 = 功能；P2 = 不做；附 L1 观察表（每条带证据文件）。**人确认 P0 和 P2。**

## 3. 定方案（Agent，10 分钟）

架构说明一页：平台、外壳、核心组件，以及"不选什么、为什么"。不选的理由要落到 P0 上，比如"富文本模型要来回转换，必然改写原文"。
原则：核心特质决定核心组件。

## 4. 先写验收（Agent，30–60 分钟，最关键）

1. **锁定测试**（`references/locked-test-guide.md`）：每条 P0 写成测试，期望值取自 L1 实测。测试通过一个小契约读写应用状态（如 `window.<app>.load/source/setCaret`），把契约写进 AGENTS.md。语料文件覆盖边界：BOM、CRLF、无末尾换行、中文、不规整格式。
2. **一条验收命令**（`references/verify.sh`）：哈希校验 → 构建 → 全部测试 → 原生自测 → 文档检查，任何一步失败即停，最后输出 `VERIFY PASSED`。
3. **对着空壳跑一遍，必须全红但能跑**：试跑时这一步当场抓到 tsconfig 缺 node 类型，不然夜里第一分钟就会卡住。
4. 锁定：`find tests/locked tests/corpus -type f | sort | xargs shasum -a 256 > tests/locked.sha256`，记下这个文件本身的哈希，提交基线。

## 5. 写任务书（Agent，10 分钟）

- `AGENTS.md`（`references/AGENTS.template.md`）：边界、锁定测试规则与契约、验收、遇阻处理、顺序。
- `docs/progress.md`：勾选清单。最后一项完成后在第一行写 `ALL_DONE`，下面留"打磨"一节。
- `run/KICKOFF.md`（`references/KICKOFF.md`）：每轮的启动指令。

**发给用户过目**：准备好的东西、怎么跑、要确认的三件事（跳过权限确认、用量、屏幕会弹窗）。用户同意后启动。

## 6. 夜跑（无人值守）

`references/overnight.sh` + `references/launch.py`，在 tmux 里跑：

```bash
cp references/{overnight.sh,launch.py} ~/labs/<代号>/run/
echo '{"glm":"glm-5.3","opus":"claude-opus-5-5"}' > ~/labs/<代号>/run/models.json   # 简称 → CLI 模型名，与 *.env 同名
tmux new-session -d -s <代号>-overnight "env -u CLAUDECODE -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_CHILD_SESSION \
  REPO=~/labs/<代号>/<代号> RUN_DIR=~/labs/<代号>/run DEADLINE=<epoch 秒> CLAUDE_BIN=<claude 绝对路径> zsh ~/labs/<代号>/run/overnight.sh"
```

tmux 里 PATH 可能找不到 claude（fnm 安装的尤其如此），所以用 `CLAUDE_BIN` 给绝对路径。驱动已用假 Agent 冒烟测试过：清单阶段→打磨阶段切换、按时长结束本轮、配额退避都正常。

- 每轮一个新会话，所有状态放在仓库里（git + progress.md）。中途断了，下一轮从工作区继续；GLM 被限流时写到一半的代码，就是这样被 Opus 接上的。
- 自动换模型：连续两轮没有新提交就换备用模型；`run/FORCE_MODEL` 可以人工锁定模型。
- **按错误类型退避**：限流（429，含"N 小时上限"）等到重置时间或指数退避，不要立刻重试；网关故障（503）短退避后换通道。
- 换会话的条件按时长判断（如单轮 ≥ 90 分钟）或连续无提交判断，不靠"上下文满了"：Opus 靠自动压缩，单轮能跑 4 小时，从来不会触发。
- `ALL_DONE` 后自动进入打磨阶段（`KICKOFF-polish.md`），跑到截止时间。
- 结束时跑一次总验收，日志写进 `run/logs/`。

botmux 定时任务两个，都用 `--topic` 建在当前话题：

- 每 2 小时一次**静默巡检**（`--silent`）：会话在不在、2 小时内有没有提交、磁盘、锁定哈希、是否连续限流。只在异常时报警，夜跑结束后自删。
- **晨检**（一次性，结束后半小时）：prompt 用 `references/morning-review.md`。provider 故障会让它延后，prompt 里要写"失败后 30 分钟重试"。

## 7. 晨检（Agent，30–60 分钟）

照 `references/morning-review.md` 做，结论发到话题：

1. 锁定测试指纹与 git 历史（只应有基线提交）。
2. 越界审计（`references/audit.py`）：所有命令与写文件路径，查有没有写到项目外、推送、全局安装、读 inputs/evidence、改系统配置。
3. 独立重跑总验收；没提交的遗留改动先 `git stash`，不要混进验收。
4. 对照组比较（`references/compare-template.mjs`）：同场景、同样的点击和按键，按用户能拿到的结果判定。
5. 亲手打开真 App 抽查 2–3 项核心特质。
6. 结论按固定结构写：一句话结论 → 测试 → 越界审计 → 对照 → 各模型贡献 → 方法上学到的 → 需要人亲手确认的。

**收尾**：把这次的新教训改进本技能（短分支 + PR）；方法记录 `notes/method-log.md` 留在 labs，不进仓库。

## 方法记录

全程在 `notes/method-log.md` 按时间记一行一事：每一步的耗时、踩过的坑、用户的决定。晨检和改进本技能都靠它。时间写本机时区，并注明和北京时间的换算。
