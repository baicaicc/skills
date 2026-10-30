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

# 6. 交付物（需求表 P1「交付物」；人划进 P2 的项，删掉对应几行）
#    脚本只查得了"在不在"：README 写的能力是否都已实现、截图是不是当前界面，由晨检核对。
test -s README.md
if grep -qi '<原 App>' README.md; then echo "README 里出现了原 App 的名字"; exit 1; fi
grep -Eq '!\[[^]]*\]\([^)]+\.(png|jpe?g|webp)\)' README.md     # 至少一张截图
for f in $(grep -Eo '\]\([^)#[:space:]]+' README.md | cut -c3- | grep -Ev '^(https?|mailto):' || true); do
  [ -e "$f" ] || { echo "README 链接的文件不存在：$f"; exit 1; }   # 外链不在这里查
done
test -s assets/icon.svg                                          # 图标源文件，路径按项目改
bash scripts/package.sh       # 夜跑 Agent 写：在 build/release/ 出安装包（桌面 DMG / 网页压缩包）和同名 .sha256
(cd build/release && shasum -a 256 -c ./*.sha256)
# hdiutil verify build/release/*.dmg                             # 桌面 App：DMG 本身完好

echo "VERIFY PASSED"
