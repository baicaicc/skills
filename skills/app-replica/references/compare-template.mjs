// Template: run the same user-level scenarios against our build and an existing comparison app
// (not the step-2.5 probe in control/, which is only for planning).
// Copy to ~/labs/<code>/compare/, then edit the `apps` adapters and the `scenarios` list.
// Rules:
// - Scenarios come from compare/scenarios.md, picked blind: an agent that has seen neither implementation picks them
//   from the original app's official feature list. Script each one as written; never add, drop or reword after the fact.
// - Drive both apps with real clicks/keys; judge only what a user gets back (saved bytes, visible text);
//   one fresh browser context per app per scenario. Label scenarios that simulate input (e.g. CDP IME events) as such.
// - The final line is a raw count. Report scores deduplicated by root cause (failures sharing one cause count once),
//   and name the dimensions this script does not compare (look and feel, packaging, safeguards, performance).
// Output: a ✓/✗ table plus results.json.
// Example below is the 2026-10-26 Typora run (mdlive vs TyporaX), kept for its adapters and helpers only. Do not
// reuse its scenario list: it was picked after seeing TyporaX's weak spots, and both IME failures share the
// trailing-newline cause already counted under 原文保真.
// Same scenarios against both browser builds: mdlive (ours) and TyporaX (reference).
// Usage: node compare.mjs <mdlive dist url> <typorax dist url> <corpus dir>
// Each scenario drives the UI with real clicks and keys; output is read back the way a user would get it
// (mdlive: window.mdlive.source(), the text the native shell writes; TyporaX: its browser "save" download).
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const require = createRequire(join(process.env.HOME, 'labs/app-replica/mdlive/package.json'));
const { chromium } = require('@playwright/test');
const [mdUrl, txUrl, corpusDir] = process.argv.slice(2);
const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const apps = {
  mdlive: {
    async open(page, text) {
      await page.goto(mdUrl);
      await page.waitForFunction(() => typeof window.mdlive?.load === 'function');
      await page.evaluate(t => window.mdlive.load(t), text);
      await page.waitForTimeout(200);
    },
    root: page => page.getByTestId('editor'),
    output: page => page.evaluate(() => window.mdlive.source()),
  },
  typorax: {
    async open(page, text) {
      await page.goto(txUrl);
      await page.locator('#editor [contenteditable="true"]').waitFor();
      const chooser = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: '打开 Markdown 文件', exact: true }).click();
      await (await chooser).setFiles({ name: 'case.md', mimeType: 'text/markdown', buffer: Buffer.from(text) });
      await page.waitForTimeout(400);
    },
    root: page => page.locator('#source-editor .cm-content').or(page.locator('#editor [contenteditable="true"]')).filter({ visible: true }).first(),
    async output(page) {
      const pending = page.waitForEvent('download');
      await page.getByRole('button', { name: '更多操作', exact: true }).click();
      await page.locator('[data-action="save"]').click();
      const file = await pending;
      return readFileSync(await file.path(), 'utf8');
    },
  },
};

/** Click at the end of the first visible occurrence of `needle` inside the editor. */
async function clickAfter(page, root, needle) {
  const box = await root.evaluate((el, n) => {
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    for (let t = walker.nextNode(); t; t = walker.nextNode()) {
      const i = t.textContent.indexOf(n);
      if (i < 0) continue;
      const r = document.createRange(); r.setStart(t, i + n.length - 1); r.setEnd(t, i + n.length);
      const b = r.getBoundingClientRect();
      if (b.width || b.height) return { x: b.right - 1, y: b.top + b.height / 2 };
    }
    return null;
  }, needle);
  if (!box) throw new Error(`text "${needle}" not visible`);
  await page.mouse.click(box.x, box.y);
  await page.waitForTimeout(200);
}

const visibleText = async root => (await root.innerText()).replace(/[\u200B\uFEFF]/g, '');

async function compose(page, steps, commit) {
  const cdp = await page.context().newCDPSession(page);
  for (const text of steps) {
    await cdp.send('Input.imeSetComposition', { text, selectionStart: text.length, selectionEnd: text.length });
    await page.waitForTimeout(80);
  }
  await cdp.send('Input.insertText', { text: commit });
  await page.waitForTimeout(250);
}

// Anchor word used for the "type a character, delete it" edit in each corpus file.
const anchors = { 'unnormalized.md': 'trailing', 'extended.md': 'quote line', 'mixed.md': 'Intro paragraph',
  'no-eol.md': 'no trailing newline', 'crlf-bom.md': 'CRLF paragraph', 'chinese.md': '列表项一' };

const scenarios = [];
for (const name of readdirSync(corpusDir).filter(f => f.endsWith('.md')).sort()) {
  scenarios.push({ group: '原文保真', name: `${name}：打字再删掉后保存，字节不变`, async run(app, page) {
    const original = readFileSync(join(corpusDir, name), 'utf8');
    await app.open(page, original);
    await clickAfter(page, app.root(page), anchors[name]);
    await page.keyboard.type('X'); await page.keyboard.press('Backspace');
    const out = await app.output(page);
    const changed = out === original ? 0 : Math.abs(out.length - original.length) + [...original].filter((c, i) => out[i] !== c).length;
    return { pass: out === original, detail: out === original ? '字节一致' : `变了（约 ${changed} 个字符位置不同）` };
  } });
}
scenarios.push({ group: '原文保真', name: '改一个表格单元格，只变这一行', async run(app, page) {
  const original = readFileSync(join(corpusDir, 'unnormalized.md'), 'utf8');
  await app.open(page, original);
  await clickAfter(page, app.root(page), 'long cell');
  await page.keyboard.type('!');
  const out = await app.output(page);
  const want = original.replace('long cell |', 'long cell! |');
  const diffLines = out.split('\n').filter((l, i) => l !== original.split('\n')[i]).length;
  return { pass: out === want, detail: out === want ? '只改了这一格' : `${diffLines} 行不同` };
} });

const inline = 'Paragraph with **bold** and *em* and `code` here.\n\nSecond line.\n';
scenarios.push({ group: '标记随光标显隐', name: '光标在别处：** 等标记隐藏', async run(app, page) {
  await app.open(page, inline);
  await clickAfter(page, app.root(page), 'Second line');
  const text = await visibleText(app.root(page));
  return { pass: !text.includes('**') && text.includes('bold'), detail: text.includes('**') ? '看得到 **' : '标记已隐藏' };
} });
scenarios.push({ group: '标记随光标显隐', name: '光标进入加粗：显示这一处的 **，同段其他保持渲染', async run(app, page) {
  await app.open(page, inline);
  await clickAfter(page, app.root(page), 'bol');
  const line = (await visibleText(app.root(page))).split('\n').find(l => l.includes('Paragraph')) ?? '';
  const pass = line.includes('**bold**') && !line.includes('*em*') && !line.includes('`code`');
  return { pass, detail: `可见：${line.trim()}` };
} });

scenarios.push({ group: '扩展语法直接渲染', name: 'front matter / 脚注 / 引用式链接 / HTML 的文档在预览中打开', async run(app, page) {
  await app.open(page, readFileSync(join(corpusDir, 'extended.md'), 'utf8'));
  const sourceOnly = app === apps.typorax && await page.locator('#source-editor').isVisible();
  const text = await visibleText(app.root(page));
  const raw = ['[^1]', '][id]', '<span'].filter(s => text.includes(s));
  const pass = !sourceOnly && raw.length === 0;
  return { pass, detail: sourceOnly ? '退回源码模式' : raw.length ? `原样显示 ${raw.join(' ')}` : '全部渲染' };
} });

scenarios.push({ group: '中文输入法（CDP 模拟）', name: '在加粗词中间用拼音输入“中文”', async run(app, page) {
  const doc = 'Say **bold** here.\n';
  await app.open(page, doc);
  await clickAfter(page, app.root(page), 'bo');
  await compose(page, ['z', 'zh', 'zhong', 'zhongw', 'zhongwen'], '中文');
  const out = await app.output(page);
  return { pass: out === 'Say **bo中文ld** here.\n', detail: JSON.stringify(out) };
} });
scenarios.push({ group: '中文输入法（CDP 模拟）', name: '在标题末尾用拼音输入“标题”', async run(app, page) {
  const doc = '# Title\n\nBody.\n';
  await app.open(page, doc);
  await clickAfter(page, app.root(page), 'Title');
  await compose(page, ['b', 'biao', 'biaoti'], '标题');
  const out = await app.output(page);
  return { pass: out === '# Title标题\n\nBody.\n', detail: JSON.stringify(out) };
} });

const browser = await chromium.launch({ executablePath: chrome });
const results = [];
for (const s of scenarios) {
  const row = { group: s.group, name: s.name };
  for (const [key, app] of Object.entries(apps)) {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, acceptDownloads: true });
    const page = await context.newPage();
    try { row[key] = await s.run(app, page); }
    catch (e) { row[key] = { pass: false, detail: `出错：${String(e.message).split('\n')[0].slice(0, 120)}` }; }
    await context.close();
  }
  results.push(row);
  console.log(`${row.mdlive.pass ? '✓' : '✗'} ${row.typorax.pass ? '✓' : '✗'}  [${s.group}] ${s.name}\n      mdlive: ${row.mdlive.detail}\n      typorax: ${row.typorax.detail}`);
}
await browser.close();
writeFileSync(new URL('./results.json', import.meta.url), JSON.stringify(results, null, 2));
const score = k => results.filter(r => r[k].pass).length;
console.log(`\nmdlive ${score('mdlive')}/${results.length}   TyporaX ${score('typorax')}/${results.length}`);
