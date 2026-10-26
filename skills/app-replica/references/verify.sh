#!/bin/bash
# 一条命令的验收：任何一步失败即停。Agent 夜里只认最后这行 VERIFY PASSED。
# 按项目改第 3 段以后的内容；前两段（锁定哈希、构建）保持在最前面。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# 1. 锁定测试与语料未被改动
shasum -a 256 -c tests/locked.sha256 --quiet

# 2. 构建（类型检查 + 打包）
npm run build

# 3. 全部浏览器测试（锁定 + 功能）；用系统 Chrome，见 playwright.config.ts
npx playwright test

# 4. 原生外壳（桌面 App 才有）：构建 → 真实 WebView 启动 → 语料往返保真 → 集成自测
#    集成自测只模拟系统对话框的选择结果，编辑器、桥接、磁盘读写都真实执行。
# bash scripts/build-macos.sh
# app="build/<App>.app/Contents/MacOS/<App>"
# "$app" --web-smoke-test
# "$app" --roundtrip-self-test "$root/tests/corpus"
# "$app" --integration-self-test
# codesign --verify --deep --strict "build/<App>.app"

# 5. 文档：验收记录必须如实区分三类
grep -q '^## 实际执行通过' docs/validation.md
grep -q '^## 模拟验证' docs/validation.md
grep -q '^## 未验证' docs/validation.md

echo "VERIFY PASSED"
