# skills — 个人技能库

跨项目、跨 co-agent 共享的个人技能仓库（单一事实来源）。

## 为什么存在

部署 EdgeOne Pages 时重新踩了一遍 memo 踩过的全部坑——经验如果只写在某个项目的
README 或某个 agent 的私有目录里，就既跨不过项目，也跨不过工具。
本仓库把经验沉淀成**标准化的技能**（SKILL.md + references），一份内容分发给所有
co-agent（kimi-code / claude-code / 未来新增）。

## 目录结构

```
skills/            # 技能本体，每个子目录一个技能
  <name>/
    SKILL.md       # 主文件：YAML frontmatter（name/description）+ 照做清单
    references/    # 支撑文件（模板、配置样例），SKILL.md 里用相对路径引用
bin/sync           # 分发脚本：把 skills/* 复制到各 agent 的技能目录
```

## 日常用法

```bash
bin/sync                   # 全部分发（当前支持 kimi-code、claude-code）
bin/sync kimi-code         # 只分发到指定 agent
```

- **改技能**：只改本仓库，然后 `bin/sync`（agent 目录里是副本，改了会被覆盖）
- **换电脑**：clone 本仓库到 `~/skills`，跑一次 `bin/sync`
- **新增 agent**：在 `bin/sync` 的 `DEST` 表里加一行它的技能目录

## 新增一个技能

1. `mkdir skills/<name>`，写 `SKILL.md`：frontmatter 必填 `name`（与目录同名）
   和 `description`（写成「何时使用」的触发描述，agent 靠它自动命中）
2. 正文用「照做即可」的清单式写法；支撑文件放 `references/`
3. `bin/sync` 分发，新开会话验证能被命中

## 已有技能

| 技能 | 用途 | 版本 |
|---|---|---|
| [deploy-edgeone-pages](skills/deploy-edgeone-pages/SKILL.md) | 部署/上线纯前端项目到腾讯云 EdgeOne Pages（GitHub Actions CI/CD），或排查 EdgeOne 部署问题 | 1.0.0 |
