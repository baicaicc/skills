---
name: grokbot
description: 唤醒 dr eggbot（用户的 Grok Bot）处理个人系统的活，并取回它的结果。当需要它排查机器（keluoluo / ubuntu）、网络或 GL-MT3000 抖动、检查各项能力是否健康、在仓库开/改 PR，或用户说“让 eggbot / grokbot 看一下”“叫醒 grok bot”时使用。
---

# 唤醒 dr eggbot

dr eggbot 是用户的 Grok Bot，跑在它自己的 box 上，能 SSH 到 `keluoluo` 和 `ubuntu`。适合交给它的活：

- 机器：磁盘、进程、服务、日志、安装和配置检查
- 网络：GL-MT3000 抖动、丢包、延迟，Tailscale 连通性
- 能力健康：各 agent、技能、定时任务、连接器是否还能用
- 仓库：按开发公约在 worktree 开分支、提交、推送、开 PR

自己几条命令就能做完的事不要叫它。它被唤醒后要 1–3 分钟才开始干活，复杂任务可能十几分钟。

## 调用入口

入口是本 Skill 目录下的 `bin/grokbot-wake`；keluoluo 和 ubuntu 上已装到 `~/.local/bin/grokbot-wake`，直接用命令名。只发 HTTP 请求和读本机文件，不需要 SSH。

```sh
grokbot-wake "ubuntu 上 docker 磁盘占用异常，查原因给建议，不要删数据" --from codex --wait
```

- 任务用大白话写清：哪台机器、现象、想要什么结果、哪些不能动。
- `--from NAME`：调用方名字（如 `codex`、`claude-code`、`lark-bot`），默认 `用户@主机`。
- `--chat oc_xxx --msg om_xxx`：任务来自飞书时带上，它会在那条消息下回复。
- `--wait [秒]`：阻塞等结果，默认 900 秒；不加就只唤醒，立即返回。
- `--ping`：连通性测试，它会回 `pong`；配 `--wait` 默认等 120 秒。

stdout 第一行永远是 `request_id`（形如 `20261026T011708-keluoluo-50d5a502`），务必记下。

## 取结果

它做完后通过 SSH 把回执写到**调用方这台机器**的 `~/.local/state/grokbot/replies/<request_id>.json`：先写 `{"status": "working"}`，最后写 `{request_id, status, summary, details?, updated_at}`。

- 加了 `--wait`：每 5 秒读一次，到最终状态就打印 `status`、`summary`、`details`。
- 没等或等超时：之后用 `grokbot-wake --result <request_id>` 读；也可 `--result <id> --wait 600` 接着等。
- 不要因为超时就重新唤醒同一任务，它可能还在做；先 `--result` 看状态。

| 退出码 | 含义 | 怎么做 |
|---|---|---|
| 0 | done | 把 summary / details 交付给用户 |
| 1 | 唤醒失败（网络或 HTTP 非 2xx） | 请求已记到 `~/.local/state/grokbot/wake-failed.jsonl`；稍后重试一次，仍失败告诉用户 |
| 2 | 用法错误 | 改参数 |
| 3 | refused | 它拒绝了，把理由原样转告用户，不要换个说法再派 |
| 4 | failed | 报告实际失败原因 |
| 5 | 超时 / 尚无最终结果 | 用 `--result` 稍后再读 |

## 它不做的事

以下请求它会 `refused`，需要时由用户本人操作或另行明确授权：

- 删除数据（文件、数据库、快照、备份、容器卷）
- 推送或改写 main，合并 PR（它只开 PR）
- 重启路由器、切换代理节点或出口
- 修改凭据：密码、密钥、token、wake.env

## 密钥

URL 和密钥只在各机器的 `~/.config/grokbot/wake.env`（mode 600），字段 `GROKBOT_WAKE_URL`、`GROKBOT_WAKE_KEY`，另有 `GROKBOT_REPLY_HOST`（本机 SSH 别名 `keluoluo` / `ubuntu`，告诉它回执写到哪台）。不要 cat、打印、复制或提交这个文件；脚本也只经 stdin 把密钥交给 curl。新机器需要用户另行配置，Skill 不携带凭据。

## 更新脚本

改本仓库 `skills/grokbot/bin/grokbot-wake`，合并后跑 `bin/sync`，再把它复制到各机器的 `~/.local/bin/grokbot-wake`。
