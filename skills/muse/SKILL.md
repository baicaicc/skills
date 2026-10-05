---
name: muse
description: 给 Meta Muse 派任务、取回结果或下载产出文件，支持 cai、lin、zhu 三个账号。当用户说“让 Muse 做……”或指定其中一个 Muse 账号时使用。
---

# Muse 多账号任务

通过 kidsbox 已接通的 Muse Gadget SDK 通道执行任务。认证使用官方网页取得的账号连接凭据，结果由 Muse 调用注册的 `task.submit` 命令回传；不抓取网页聊天。凭据和运行工具留在 kidsbox，Skill 不携带登录信息。

## 调用入口

以下 `入口` 指本 Skill 目录下的 `scripts/muse`，执行时替换成它的实际绝对路径。kidsbox 本机直接运行；其他机器自动经免密 SSH 别名 `kidsbox` 执行同一套工具。远程执行前按当前协同公约核对 umbrella `docs/SYSTEM.md` §7。

账号用 `cai`、`lin`、`zhu`，不指定时默认 `zhu`。保持用户原始任务、提示词和附件要求；派给 Muse 仍受用户本轮授权范围约束。此入口目前只发送文本，不会自动上传图片：用户要求使用参考图时，不能声称图片已随任务送达，也不要自行忽略。

```sh
入口 task --account cai --timeout 600 <<'TASK'
这里放用户的完整任务文本。
TASK
```

任务通过 UTF-8 stdin 输入，避免把内容放进 shell 命令参数。按任务选择等待时间（单位秒，默认 180）；视频可以留更长时间。工具返回 JSON，同时提供 `request_id`、`session_id`。保留这两个编号用于恢复和续聊。底层文档在 kidsbox `/Users/kidsbox/muse-gadget-lab/USAGE.md`，需要排查时读取，不要输出私有 state 或完整任务记录。

不同账号可并行；同账号的派任务、下载和刷新凭据互斥，`busy` 表示该账号正在使用，等待后再尝试，不自动切换到其他账号。

## 读结果与恢复

- `succeeded` 且最终 `result` 已收到：向用户交付结果。投递回执 `delivery` 仅说明收到任务，不表示完成。
- `pending`：还在进行；`recovery_unavailable`：本次恢复暂时未取到。它们不是最终失败。工具收到进度仍保持连接，直到最终结果、超时或断线。
- 原任务的最终 `failed`：报告实际失败。退出码 1 也可能是超时或进度状态，先读 JSON，不要仅凭退出码判定任务失败。
- `delivery_uncertain`、`result_timeout`、`result_unknown`：可能已送达或正在执行，先恢复已有任务，避免重复生成和重复消耗额度。
- `connection_timeout` / `connection_failed` 且 `delivery_state=not_sent`：原任务未发出，可重试派发。已被拒收的任务不能靠恢复重新派发。

恢复使用原任务编号，不附原任务文本、不换账号：

```sh
入口 task --resume muse-task-原编号 --timeout 600
```

已保存的最终结果直接返回；否则在原会话发消息请 Muse 取回已有结果，禁止重新执行。恢复依赖 Muse 保留结果及遵循指令，不保证成功；对正在生成的长视频有无影响还未验证。不要自动反复恢复。续聊则用 `task --account 原账号 --session-id 原会话编号` 并通过 stdin 输入新需求。

## 下载产出

Muse 返回 `workspace/…` 文件路径后，按原任务编号下载；只有文字结果时直接交付文字。下载经 SDK 加密连接读取文件，不需公开上传。

```sh
入口 download --request-id muse-task-原编号 workspace/产出.mp4 /tmp/muse-唯一任务编号.mp4
```

输出路径在 **kidsbox**，即使调用者在其他机器；下载后按命令返回的实际路径用 `scp kidsbox:/tmp/muse-唯一任务编号.mp4 本机目标路径` 取回，再通过当前渠道发送文件。文件名选唯一值，不覆盖已有文件。没有任务编号时必须显式 `download --account cai …`，下载没有默认账号。不要编造路径或把其他账号的文件当作本任务产出。

## 连接凭据

`auth_required`（HTTP 401）需要更新凭据；`forbidden`（403）不能直接认定为过期。cai、lin 可通过各自已登录的 Roxy 窗口刷新：

```sh
入口 refresh --account cai
```

zhu 不支持这个 Roxy 刷新入口，需按 kidsbox 现有共享浏览器流程处理；不要求用户用手机反复配对。`account_mismatch` 表示账号绑定不一致，不能跳过校验。凭据有效期及真实过期行为尚未验证，不承诺自动续期。不要将 token、代理口令、设备身份或完整私有记录写入 Git、聊天或复制到另一台机器。
