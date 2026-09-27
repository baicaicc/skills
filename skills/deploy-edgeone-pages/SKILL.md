---
name: deploy-edgeone-pages
description: |
  把新的纯前端项目部署/上线到腾讯云 EdgeOne Pages（GitHub Actions CI/CD 路线），或排查 EdgeOne 部署问题。
  当用户要部署、上线、发布新前端项目到 EdgeOne Pages，配置 EdgeOne API Token / GitHub Secret，
  绑自定义域名 / CNAME / HTTPS 免费证书，或提到 EdgeOne、EdgeOne Pages、腾讯云、makers deploy、
  edgeone.cool、pages.dnsoeN.com 等关键词时使用本技能。
metadata:
  version: "1.0.0"
---

# 部署新项目到腾讯云 EdgeOne Pages

「GitHub Actions CI/CD + EdgeOne Pages（腾讯云国内版）」纯前端项目的照做清单，
memo（memo.sesamebox.cn）与 raz（raz.sesamebox.cn）均由此跑通。
标准 workflow 模板见 `${KIMI_SKILL_DIR}/references/deploy.yml`。

## 前置认知（三条坑）

1. **仓库建议 public**：私有仓库 Actions 每月仅 2000 免费分钟，表现为 job 一直排不上 runner；public 不限量。
2. **默认域名不可对外**：`*.edgeone.cool` 只支持带一次性 token 的预览访问，公网直接访问返回 401。
   要对外使用必须绑自定义域名（需已备案）。
3. **GitHub Secret 按仓库隔离且不可回读**：值写入后永远读不回来，每个新仓库都要重新配一遍。

## 第 1 步：拿到 EdgeOne API Token（三选一）

- **A. 本机部署过 EdgeOne 项目**：token 已在本机 `~/.edgeone/` 下（文件名为十六进制哈希、无扩展名），
  在其中找 `key == "eo_token"` 那行 JSON 的 `value.Token` 字段即是（CLI 首次 deploy 自动生成，
  账号级、同账号所有项目通用；控制台里显示为 `edgeone-cli-auto-generated`）。
- **B. 控制台新建**：[EdgeOne Makers 控制台](https://console.cloud.tencent.com/edgeone/makers)
  → 设置 → API Token → 创建。两个坑：
  ①「过期时间」是隐藏必填项，不选则提交按钮永远灰着（选「永久有效」）；
  ② 提交后 token 明文**只显示一次**，当场复制，关掉就再也找不回（列表里只有掩码）。
- **C. 全新电脑**：项目目录里直接跑一次 `npx edgeone@1.6.41 makers deploy ./dist -n <项目名>`，
  会引导腾讯云登录并自动生成 token 存到 `~/.edgeone/`。

## 第 2 步：把 token 写入 GitHub Secret

```bash
GH_TOKEN=<GitHub令牌> gh secret set EDGEONE_PAGES_API_TOKEN --repo <owner>/<repo> --body "<token值>"
```

或网页操作：仓库 Settings → Secrets and variables → Actions → New repository secret，
Name 填 `EDGEONE_PAGES_API_TOKEN`。

- 值不能从旧仓库复制（GitHub 不提供回读），要从第 1 步的来源取。
- 没配 secret 时 CI 只有 deploy 步骤失败，test job 不受影响。

## 第 3 步：放 CI workflow

把 `${KIMI_SKILL_DIR}/references/deploy.yml` 复制为仓库的 `.github/workflows/deploy.yml`，
把 `-n` 后面的项目名换成 EdgeOne Pages 项目名。要点：

- `test` job：install → test → build，PR 也跑（只测不部署）。
- `deploy` job：仅 main push 触发，build 后 `npx edgeone@1.6.41 makers deploy ./dist -n <项目名>`，
  通过 env 注入 secret `EDGEONE_PAGES_API_TOKEN`。
- CLI 锁已知可用版本（`edgeone@1.6.41`），避免 CLI 变动引入意外。
- workflow 用 `pnpm/action-setup@v4`，要求 `package.json` 里有 `packageManager` 字段固定 pnpm 版本。

## 第 4 步：绑自定义域名（五步，缺一不可）

以 `<子域>.<主域>`（如 raz.sesamebox.cn）为例：

1. **添加域名**：Makers 控制台 → 项目 → 域名管理 → 添加自定义域名，
   填域名、关联环境选**生产** → 下一步（此时状态「部署中」）。
2. **归属权验证**：对话框给出 TXT 记录（主机记录 `edgeonereclaim.<子域>`），
   域名 DNS 托管在腾讯系时点「一键添加」自动写入 DNSPod → 等 1 分钟 → 点「验证」。
3. **加 CNAME**：⚠️ CNS 控制台（console.cloud.tencent.com/cns/...）有已知 bug——
   DNSPod SDK 微前端加载失败导致记录表格白屏，别在那儿耗。改用
   [API Explorer · CreateRecord](https://console.cloud.tencent.com/api/explorer?Product=dnspod&Version=2021-03-23&Action=CreateRecord)：
   `Domain=<主域>`、`SubDomain=<子域>`、`RecordType=CNAME`、`RecordLine=默认`、
   `Value=<CNAME 目标>`，点「发送请求」。⚠️ 会弹**微信扫码 MFA**，扫码即过。
   ⚠️ CNAME 目标以**本项目**域名列表「一键添加」给出的为准，别照抄别的项目
   （memo 是 `pages.dnsoe4.com`，raz 是 `pages.dnsoe5.com`，`dnsoeN` 编号每次分配可能不同）。
   也可直接点域名列表里的「一键添加」按钮让控制台自动写记录。
4. **等生效**：域名状态变「已生效」。
5. **HTTPS**：HTTPS 配置 → 配置 → 申请免费证书 → 保存。
   证书签发需几分钟，期间 HTTPS 访问会握手失败，属正常现象。

## 第 5 步：验证

```bash
curl -s -o /dev/null -w "%{http_code}" https://<域名>   # 期望 200
```

## 日常迭代（项目跑通之后）

- **发布**：合入 main 即自动发布（Actions → EdgeOne Pages），发布后用上面的 curl 验证。
- **回滚**：`git revert` 合入的提交并 push（CI 自动重新部署）；
  或在 EdgeOne 控制台对项目部署记录回滚到上一 deployment。
- **排障路由**：
  - CI 红：`gh run list` → `gh run view <id> --log-failed`。
  - 线上白屏/404：EdgeOne 控制台 → edgeone/makers → 项目 → 构建部署/域名管理。
  - 本地构建过但 CI 挂：优先怀疑依赖没写进 `package.json`（本地 node_modules 有残留）。
  - 只有 deploy 步骤失败：检查 `EDGEONE_PAGES_API_TOKEN` secret 是否已配置或已失效。

## 本机手动部署（可选）

要求全局装过 edgeone CLI 且设置了 `EDGEONE_PAGES_API_TOKEN` 环境变量；
没装全局可直接 `npx edgeone@1.6.41 makers deploy ./dist -n <项目名>`。
