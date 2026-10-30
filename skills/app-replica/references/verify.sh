#!/bin/bash
# 一条命令的验收：任何一步失败即停。Agent 夜里只认最后这行 VERIFY PASSED。
# 按项目改第 3 段以后的内容；前两段（锁定哈希、构建）保持在最前面。改好后本文件随锁定测试一起锁（写进 tests/locked.sha256）。
# 睡前单独试第 5–6 段：VERIFY_FROM=5 bash scripts/verify.sh，结尾输出 VERIFY PARTIAL，不算通过。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fail() { echo "VERIFY FAILED：$*" >&2; exit 1; }

if [ "${VERIFY_FROM:-1}" != 5 ]; then
  # 1. 锁定测试、语料、本文件与 playwright.config.ts 未被改动
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
fi

# 5. 文档：验收记录必须如实区分三类
for h in '实际执行通过' '模拟验证' '未验证'; do
  grep -q "^## $h" docs/validation.md || fail "docs/validation.md 缺「## ${h}」一节"
done

# 6. 交付物（需求表 P1「交付物」；人划进 P2 的项，睡前删掉对应几行）
#    脚本只查得了"在不在"：README 写的能力是否都已实现、截图是不是当前界面，由晨检核对。
[ -s README.md ] || fail "缺 README.md"
if grep -qi '<原 App>' README.md; then fail "README 里出现了原 App 的名字"; fi
python3 -I - README.md <<'PY'
# README 引用的本地文件都要存在，且至少有一张本地截图；外链、页内锚点和代码里的示例不在这里查。
import os, re, sys, urllib.parse
text = open(sys.argv[1], encoding='utf-8').read()
text = re.sub(r'^ {0,3}(`{3,}|~{3,}).*?^ {0,3}\1', '', text, flags=re.M | re.S)   # 代码块
text = re.sub(r'`[^`\n]+`', '', text)                                            # 行内代码
refs = re.findall(r'\]\(\s*<([^>]+)>', text)                          # [a](<含空格 的路径.png>)
refs += re.findall(r'\]\(\s*([^)\s<]+)', text)                         # [a](x.png "标题")
refs += re.findall(r'^\s*\[(?!\^)[^\]]+\]:\s*<?([^>\s]+)', text, re.M) # [a]: x.png
refs += re.findall(r'<img\b[^>]*?\bsrc\s*=\s*["\']([^"\']+)', text, re.I)
local = [urllib.parse.unquote(r.split('#')[0]) for r in refs if not re.match(r'[a-z][a-z0-9+.-]*:|#', r, re.I)]
missing = sorted({r for r in local if r and not os.path.exists(r)})
if missing:
    sys.exit('VERIFY FAILED：README 引用的文件不存在：' + '、'.join(missing))
if not any(re.search(r'\.(png|jpe?g|gif|webp)$', r, re.I) for r in local):
    sys.exit('VERIFY FAILED：README 里没有本地截图')
PY
[ -s assets/icon.svg ] || fail "缺图标 assets/icon.svg"            # 路径按项目改
rm -rf build/release                                              # 旧产物不算数
bash scripts/package.sh || fail "scripts/package.sh 失败"
#   package.sh 由夜跑 Agent 写：在 build/release/ 出安装包（桌面 DMG / 网页压缩包）和同名 .sha256，.sha256 里只写文件名
if [ -z "$(find build/release -maxdepth 1 -name '*.sha256' 2>/dev/null)" ]; then fail "build/release/ 里没有 .sha256"; fi
if [ -n "$(find build/release -maxdepth 1 -name '*.sha256' -exec grep -l / {} +)" ]; then fail ".sha256 里只写文件名，不带路径"; fi
(cd build/release && shasum -a 256 -c --quiet ./*.sha256) || fail "安装包和 .sha256 对不上"
# hdiutil verify build/release/*.dmg >/dev/null || fail "DMG 校验失败"   # 桌面 App

if [ "${VERIFY_FROM:-1}" = 5 ]; then echo "VERIFY PARTIAL（只跑了第 5–6 段，不算通过）"; exit 0; fi
echo "VERIFY PASSED"
