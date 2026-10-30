# 锁定测试写法

锁定测试是夜里唯一的裁判，写不好，Agent 就会朝错的方向努力，或者用"假通过"糊弄过去。

## 原则

1. **期望值来自原 App 实测（L1）**，不是想象中的"应该"。例如 Typora 实测：未规范化文件编辑后再改回、保存，字节不变；改一个表格单元格，diff 只有一行。
2. **测用户能拿到的结果**：写入磁盘的字节、可见文本、导出产物。不测内部函数。
3. **断言要精确**：`expect(source).toBe(original.replace(a, b))`，而不是 `toContain`。宽松断言最容易被凑过去。
4. **通过真实输入驱动**：键盘、鼠标、输入法事件（CDP `Input.imeSetComposition` / `Input.insertText`）。用应用自己的 API 直接改状态不算数。
5. **小契约读写状态**：应用在测试构建中暴露最少的接口，例如 `window.<app>.load(text)`、`source()`、`setCaret(offset)`；根元素带 `data-testid`。契约写进 AGENTS.md。
6. **语料覆盖边界**：BOM、CRLF、无末尾换行、中文与全角标点、不规整格式（多余空格、连续空行、未对齐表格）、扩展语法、恶意 HTML。
7. **安全用例**：带脚本的内容渲染后必须不执行（`window.__pwned` 保持 undefined）。
8. **对着空壳先跑一遍**：必须全红，但要能跑完。能跑完说明测试框架本身没问题。

## 结构

```
tests/
  locked/harness.ts        契约包装：open / source / caretAt / visibleLines …
  locked/r<N>-<名>.spec.ts  每条 P0 一个文件，文件头注明期望值来源
  locked/ui-target/         用户选定的外观样稿（target.html / target.png）与要对照的界面状态（states.md），一起锁
  corpus/                   语料（自写或许可兼容的规范样例）
  locked.sha256             上面两个目录所有文件，加上 scripts/verify.sh、playwright.config.ts 的哈希
  features/                 P1 测试，Agent 夜里写
```

## 锁定与核对

```bash
(find tests/locked tests/corpus -type f; printf '%s\n' scripts/verify.sh playwright.config.ts) | sort | xargs shasum -a 256 > tests/locked.sha256
shasum -a 256 tests/locked.sha256 > ../run/locked-sha256.of-hashfile   # 晨检用：哈希文件本身的哈希
git add -A && git commit -m "基线：锁定测试、语料与验收脚本"
git rev-parse HEAD > ../run/baseline-commit                            # 晨检用：基线提交号
```

晨检核对：`shasum -a 256 -c tests/locked.sha256`；哈希文件本身的哈希与记录一致；`git diff <基线提交> -- tests/locked tests/corpus tests/locked.sha256 scripts/verify.sh playwright.config.ts` 为空，`git log` 查这几个路径只有基线提交。

## 规模参考（Typora 试跑）

29 条锁定测试：R1 原文保真 11 条、R2 行内标记显隐 7 条、R3 块标记 6 条、R4 扩展语法 2 条、R5 输入法 3 条；语料 6 个文件。夜跑后 Agent 自己补到 160 条功能测试。
