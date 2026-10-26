# <代号> 开发约定（夜跑用）

本仓库参照 <原 App> 的公开文档、菜单与实际行为，独立实现 <一句话目标>。只在本机：不推送远程、不发布、不创建 GitHub 仓库。

## 读什么

- `docs/requirements.md`：需求。P0 = 核心特质（已有锁定测试），P1 = 功能，P2 = 不做。
- `docs/architecture.md`：技术方案。偏离方案前，先在 `docs/decisions.md` 写一行理由。
- `docs/progress.md`：进度清单。每轮开始先读它和 `git log --oneline -20`，结束前更新它。

## 边界

- 不使用 <原 App> 的代码、主题、样式、字体、图标、文案或图片；不读取 `~/labs/<代号>/inputs` 与 `evidence`。名字、界面、文档里不出现 "<原 App>" 字样（`docs/` 里的需求来源说明除外）。
- 依赖只用成熟开源库；新增依赖在 `THIRD_PARTY_NOTICES.md` 记名称和许可证。
- 不下载 Playwright 浏览器（用系统 Chrome），不安装大型工具链，生成物只放 `build/`、`dist/`。
- 只在本仓库目录内写文件；不改系统设置、全局配置和其他项目。

## 锁定测试

`tests/locked/`、`tests/corpus/`、`tests/locked.sha256` 在夜跑前由人审过并锁定，**不得修改、删除、跳过或放宽**。认为某条锁定测试本身有误时：不改它，在 `docs/locked-test-issues.md` 写明测试名、理由和证据，然后继续做别的。

测试构建必须暴露契约 `window.<app>`：

- <列出契约方法与语义>

根元素带 `data-testid="<id>"`。P1 测试写在 `tests/features/`，测用户可见的行为和结果，不测内部实现。

## 验收

- `npm run verify`（`scripts/verify.sh`）输出 `VERIFY PASSED` 才算完成。
- 原生自测（桌面 App）：<列出 --self-test 参数与各自覆盖的内容>
- 每完成一个能验证的小步就本地 `git commit`，提交信息写清做了什么、哪些测试通过。不提交会让锁定测试从通过变成失败的改动。
- `docs/validation.md` 分三节：`## 实际执行通过`、`## 模拟验证`、`## 未验证`。没执行的不写成通过。

## 遇阻

同一问题换三种做法仍不行：写进 `docs/blockers.md`（现象、试过什么、猜测原因），转做下一项，不要停下等人。

## 顺序

P0 锁定测试 → 外壳与文件生命周期 → P1（按需求表顺序）→ 打磨。全部 P1 完成且 verify 通过后，在 `docs/progress.md` 第一行写 `ALL_DONE`，然后在"打磨"一节继续。
