# 两份启动指令，分别存成 run/KICKOFF.md 和 run/KICKOFF-polish.md（去掉本行和分隔标题）

## ===== run/KICKOFF.md =====

你在 ~/labs/<代号>/<代号> 里独立工作，这是一次无人值守的长时间开发，没有人会回答问题。

1. 先读 AGENTS.md、docs/progress.md、docs/blockers.md（如有）和 `git log --oneline -20`，弄清上一轮做到哪里。工作区里可能有上一轮没提交的代码：先看懂，能用就接着做完再提交。
2. 从 docs/progress.md 里选下一个未完成项，按 AGENTS.md 实现。
3. 每完成一个能验证的小步：跑相关测试（锁定测试用 `npm run test:locked`），通过就 `git commit`。
4. 本轮结束前：更新 docs/progress.md 和 docs/validation.md，提交。工作区不留未提交改动。
5. 驱动可能在任何时候结束本轮，所以随时保持"已提交即可交接"。

不要修改 tests/locked、tests/corpus、tests/locked.sha256、scripts/verify.sh。不要推送、不要发布。遇阻按 AGENTS.md「遇阻」处理，不要停下。

## ===== run/KICKOFF-polish.md =====

你在 ~/labs/<代号>/<代号> 里独立工作，这是一次无人值守的长时间开发，没有人会回答问题。

进度清单已全部完成（docs/progress.md 第一行 ALL_DONE），现在是打磨阶段。

1. 先读 AGENTS.md、docs/progress.md（尤其「打磨」一节和实现备忘）、docs/validation.md 的「未验证」、docs/blockers.md（如有）、tests/locked/ui-review.md 和 `git log --oneline -20`。
2. 选一个最有价值的问题：对照 docs/requirements.md 找没做或做得不完整的功能（含「健壮性与防护」「交付物」）；或者自己做代码审查，优先找会丢数据、改坏原文、导致崩溃的缺陷；或者改观感——晨检会按 tests/locked/ui-review.md 对固定界面截图打分。
3. 功能和缺陷：先写能复现问题的测试（tests/features/），再修；`npm run test:locked` 和相关测试通过后 `git commit`。
   观感：按量表截图自评（能看图就自己看），挑分最低的一项改，改完重截再评；分数记在 docs/ui-scores.md，写明评分人（你的模型名，自评）和提交号；README 截图跟着更新，再 `git commit`。
4. 本轮结束前更新 docs/progress.md 的「打磨」一节和 docs/validation.md，提交。工作区不留未提交改动。

不要修改 tests/locked、tests/corpus、tests/locked.sha256、scripts/verify.sh。不要推送、不要发布。遇阻按 AGENTS.md「遇阻」处理，不要停下。
