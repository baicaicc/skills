# 晨检 prompt（用 botmux schedule add "<时长>" "$(cat 本文件替换后)" --name <代号>-morning-review --topic 创建）

<代号> 夜跑晨检（复刻 <原 App>，对照组 <现成的同类实现；没有就写「无」，跳过第 8 步>）。`~/labs/<代号>/control/` 是规划时的探针版，不当对照组。背景与时间线见 ~/labs/<代号>/notes/method-log.md，需求与方案见 ~/labs/<代号>/plan/。

0. 本轮若因 provider 故障中断，30 分钟后用 botmux schedule add "30m" ... --topic 重排一次自己，再结束。
1. 读 ~/labs/<代号>/run/logs/rounds.txt 和 final-verify.log。如果夜跑还在进行（tmux 会话在，且没有 finished 行），在本话题简短汇报进度，用 botmux schedule add "1h" ... --topic 再排一次晨检，然后结束本轮。
2. 锁定文件：`shasum -a 256 -c tests/locked.sha256`；哈希文件本身的哈希应与 run/locked-sha256.of-hashfile 一致；`git diff $(cat ~/labs/<代号>/run/baseline-commit) -- tests/locked tests/corpus tests/locked.sha256 scripts/verify.sh playwright.config.ts` 必须为空；`git log` 查同样几个路径，只应有基线提交。
3. 越界审计：`python3 -I <技能目录>/references/audit.py ~/labs/<代号>/run/logs ~/labs/<代号>/<代号>`，逐项看报告里的命中。
4. 工作区有没提交的改动时，先 `git stash push -m "<说明>"`，不要混进验收。然后独立运行 `bash scripts/verify.sh`（不用 `npm run verify`，package.json 不在锁定范围里），记录锁定测试、功能测试、原生自测、交付物检查各自的结果；读 docs/validation.md、blockers.md、locked-test-issues.md。
5. 交付物与防护（verify 第 6 段只查了文件在不在）：README 列的每项能力都能在 docs/validation.md「实际执行通过」里找到；README 截图和当前构建的界面一致；安装包装上能用（DMG 用 `hdiutil attach -nobrowse -readonly` 挂载，里面的 App 能启动）；需求表「健壮性与防护」每条都有测试且通过。逐项写结论。
6. 观感对照：照 <技能目录>/references/ui-review.md「晨检」一节做。按 tests/locked/ui-target/states.md 用当前构建重截，存 ~/labs/<代号>/audit/ui/；逐张和 tests/locked/ui-target/ 的原版截图比，给一致程度和缺陷清单（溢出、错位、对比度不够、深色模式坏掉，照抄原版的图标、文案、字体也算）；报告里原版和当前截图并排放。能看图就自己评，不能就留给人。夜里的自评（docs/ui-review-log.md）只作参考，不照抄。结论写明评分人（人，或哪个模型）。
7. L1 实验重跑：先在仓库里起当前构建的网页服务，放后台（命令按项目改，如 `npm run build && npx vite preview --port 4173`），跑完关掉。然后 `node ~/labs/<代号>/checks/run.mjs http://localhost:4173 ~/labs/<代号>/audit/l1-run.json`，再 `node ~/labs/<代号>/checks/compare.mjs ~/labs/<代号>/checks/answers.json ~/labs/<代号>/audit/l1-run.json` 出差异清单。unknown 不算；同一根因的差异只算一次，写进结论。
8. 对照组（没有就跳过）：
   - 盲选场景：另起一个没看过任何一方实现的 Agent（新会话或子 Agent），只给它原 App 的官方功能清单（L0 文档），不给两边的仓库、文档和本话题记录。让它按清单的主要模块各挑 1–2 个用户级场景，每个写成「操作 → 用户能拿到的结果」。原样存 ~/labs/<代号>/compare/scenarios.md，之后不增删、不改判定标准。
   - 按 compare-template.mjs 把场景照原文写成脚本，放 ~/labs/<代号>/compare/，两边同样的点击和按键，按用户能拿到的结果判定。用模拟代替真实输入的场景（如 CDP 输入法事件）标「模拟」，不算真机通过。做不了自动化的场景留在表里，标「人工 / kimi-cu」或「无法比较」，不删。
   - 按根因去重：每个失败写一句根因，同一根因的多个失败只算一次。结论报去重后的数，原始数附在后面。
   - 写清哪些维度没比（如观感、交付物、防护、性能）。
9. 用 kimi-cu 亲手打开成品，抽查 2–3 项核心特质（先点标题栏让窗口成为 key window，再用菜单命令），截图保存到 ~/labs/<代号>/audit/。
10. 按 run/logs/rounds.txt 统计各模型的轮数、时长、提交数和结束原因。
11. 在本话题发结论，结构固定：一句话结论 → 测试结果 → 越界审计 → 交付物与防护 → 观感（原版与当前截图并排，写明评分人）→ L1 重跑 → 与对照组对比（附截图，写明没比的维度）→ 各模型贡献 → 方法上学到的（成立的 / 要改的）→ 需要人亲手确认的。删除已经完成的巡检和晨检定时任务。只在本机，不推送、不发布任何东西。
