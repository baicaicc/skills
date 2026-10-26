# 晨检 prompt（用 botmux schedule add "<时长>" "$(cat 本文件替换后)" --name <代号>-morning-review --topic 创建）

<代号> 夜跑晨检（复刻 <原 App>，对照组 <对照组>）。背景与时间线见 ~/labs/<代号>/notes/method-log.md，需求与方案见 ~/labs/<代号>/plan/。

0. 本轮若因 provider 故障中断，30 分钟后用 botmux schedule add "30m" ... --topic 重排一次自己，再结束。
1. 读 ~/labs/<代号>/run/logs/rounds.txt 和 final-verify.log。如果夜跑还在进行（tmux 会话在，且没有 finished 行），在本话题简短汇报进度，用 botmux schedule add "1h" ... --topic 再排一次晨检，然后结束本轮。
2. 锁定测试：`shasum -a 256 -c tests/locked.sha256`；哈希文件本身的哈希应与 run/locked-sha256.of-hashfile 一致；`git log -- tests/locked tests/corpus` 只应有基线提交。
3. 越界审计：`python3 -I <技能目录>/references/audit.py ~/labs/<代号>/run/logs ~/labs/<代号>/<代号>`，逐项看报告里的命中。
4. 工作区有没提交的改动时，先 `git stash push -m "<说明>"`，不要混进验收。然后独立运行 `npm run verify`，记录锁定测试、功能测试、原生自测各自的结果；读 docs/validation.md、blockers.md、locked-test-issues.md。
5. 对照组：按 compare-template.mjs 写同场景脚本放 ~/labs/<代号>/compare/，同样的点击和按键，按用户能拿到的结果判定，两边都跑。
6. 用 kimi-cu 亲手打开成品，抽查 2–3 项核心特质（先点标题栏让窗口成为 key window，再用菜单命令），截图保存到 audit/。
7. 按 run/logs/rounds.txt 统计各模型的轮数、时长、提交数和结束原因。
8. 在本话题发结论，结构固定：一句话结论 → 测试结果 → 越界审计 → 与对照组对比（附截图）→ 各模型贡献 → 方法上学到的（成立的 / 要改的）→ 需要人亲手确认的。删除已经完成的巡检和晨检定时任务。只在本机，不推送、不发布任何东西。
