#!/usr/bin/env node
/**
 * 棚号列定档测算（60vp / 14vp / 7 字符）——全量排布预览，只读。
 *
 * 直接调用项目里真实的 ShedDisplay 模型（run-model-tests.mjs 编译产物），
 * 不模拟算法、不改应用代码、不打包、不推手机。
 *
 * 逐条检查是否合乎目标：
 *   1. 最多 2 行；2. 每行 ≤ 字符预算；3. 按真机字形表估算每行像素宽 ≤ 可用宽；
 *   4. 区间绝不被从中间切断；5. 不出现空白格 / 只剩省略号的信息全丢；
 *   6. 左右到边框仍有余量，不浪费也不被 Clip 裁字。
 *
 * 用法：node scripts/preview-shed-layout.mjs [列宽=60] [--html 输出路径]
 * 例：  node scripts/preview-shed-layout.mjs
 *       node scripts/preview-shed-layout.mjs 60 --html dist/shed-layout-preview.html
 */
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BUILD = path.join(ROOT, 'scripts', '.model-test-build');
const OUT = path.join(BUILD, 'out');

const argv = process.argv.slice(2);
const htmlFlag = argv.indexOf('--html');
const HTML_OUT = htmlFlag >= 0 && argv[htmlFlag + 1] ? path.resolve(ROOT, argv[htmlFlag + 1]) : '';
const WIDTH = Number(argv.find((a) => /^\d+(\.\d+)?$/.test(a)) || 60);

// ===== 真机字形表（@14vp 截图实测，与 scripts/check-shed-font-fit.py 同源）=====
// 数字 7.00 / 连字符 3.33 / 半角空格 3.50 / 省略号 11.33 / 省略号相邻间隙 1.67
const GLYPH = { digit: 7.0, dash: 3.33, space: 3.5, ellipsis: 11.33, gap: 1.67 };
const BASE_FS = 14;
const BORDER_VP = 1; // 单元格左右边框各 0.5vp，Text 无 padding
const SCALE = 0.5;   // 终端预览：1vp ≈ 0.5 个等宽字符

/** 一行文本在指定字号下的估算像素宽（vp）。 */
function lineWidthVp(s, fs) {
  let total = 0;
  let prev = '';
  for (const ch of Array.from(s)) {
    if (ch === '…') {
      total += GLYPH.ellipsis;
      if (prev && prev !== ' ' && prev !== '…') total += GLYPH.gap;
    } else if (ch === '-') {
      total += GLYPH.dash;
    } else if (ch === ' ') {
      total += GLYPH.space;
    } else {
      total += GLYPH.digit;
      if (prev === '…') total += GLYPH.gap;
    }
    prev = ch;
  }
  return total * fs / BASE_FS;
}

/** 与模型 preprocess 同口径的显示项解析（仅用于校验「区间是否被切断」，不参与渲染）。 */
function parseItems(raw) {
  let text = raw.trim().replace(/[到至~～—－]/g, '-').replace(/\s*-\s*/g, '-');
  const parts = text.split(/[,，、;；\/\s]+/);
  const intOf = (s) => (/^[+-]?\d+$/.test(s) ? parseInt(s, 10) : NaN);
  const intervals = [];
  for (const part of parts) {
    const t = part.trim();
    if (!t) continue;
    const dash = t.indexOf('-');
    let a, b;
    if (dash >= 0) { a = intOf(t.substring(0, dash)); b = intOf(t.substring(dash + 1)); }
    else { a = intOf(t); b = a; }
    if (isNaN(a) || isNaN(b)) continue;
    if (a > b) { const tmp = a; a = b; b = tmp; }
    if (a > 0) intervals.push([a, b]);
  }
  intervals.sort((p, q) => (p[0] !== q[0] ? p[0] - q[0] : p[1] - q[1]));
  const merged = [];
  for (const iv of intervals) {
    if (merged.length > 0 && iv[0] <= merged[merged.length - 1][1] + 1) {
      merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], iv[1]);
    } else {
      merged.push([iv[0], iv[1]]);
    }
  }
  return merged.map((iv) => (iv[0] === iv[1] ? String(iv[0]) : iv[0] + '-' + iv[1]));
}

/** 复用模型测试框架的 tsc 编译产物，保证预览用的是真正会上线的算法。 */
function loadModel() {
  const r = spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'run-model-tests.mjs')], {
    cwd: ROOT,
    env: Object.assign({}, process.env, { MODEL_TEST_KEEP: '1' }),
    encoding: 'utf8'
  });
  if (r.status !== 0) {
    console.error(r.stdout || '');
    console.error(r.stderr || '');
    throw new Error('模型回归未通过，预览中止');
  }
  console.log((r.stdout || '').trim());
  if (!existsSync(path.join(OUT, 'ShedDisplay.js'))) throw new Error('缺少编译产物 ShedDisplay.js');
  return {
    S: require(path.join(OUT, 'ShedDisplay.js')),
    L: require(path.join(OUT, 'LayoutRules.js'))
  };
}

// ===== 用例集：按排布形态分组，覆盖空值、单行、两行、散点、单/多区间、业务场景、极端长号 =====
// 业务口径：棚号最大 99（不过百）。所有用例的号码都 ≤ 99，
// 原来用于探边界的 1000 级输入一律换成 99 以内的等价极端。
const GROUPS = [
  {
    name: 'A 空值 / 非法 / 解析边界',
    cases: [
      ['', '空输入'], ['   ', '全是空格'], ['abc 中文', '完全解析不出号码'],
      ['0', '只有 0'], ['0 0 0', '多个 0'], ['-1 2', '负数'],
      ['1-', '残缺区间'], ['-', '只有横杠'], ['1,,3,,5', '连续分隔符'],
      ['99', '上限单号 99'], ['91-99', '贴上限的区间'], ['1-99', '整段到上限'],
      ['3-1', '反向区间'], ['1 1 1 2', '重复号'], ['1,2,3,4,5', '连续号合并'],
      ['１ ３ ５', '全角数字']
    ]
  },
  {
    name: 'B 单行完整显示（A-1）',
    cases: [
      ['1', '单个一位号'], ['9', '一位号'], ['10', '两位号'], ['99', '两位号'],
      ['21-35', '用户目标：中间 21 到 35'], ['1-3 5', 'Java 样例第 1 行'],
      ['1 3 5 7', '恰好 7 字符，预算用满'], ['1-3 5-7', '两个短区间'],
      ['60-99', '贴上限的两位区间'], ['1-7', '合并成单区间'],
      ['1 3 5', '短散号'], ['1-3 5 7', '区间 + 散号']
    ]
  },
  {
    name: 'C 两行完整、零省略号（A-2）',
    cases: [
      ['1 3 5 7 9 11 13', '7 个散号全部露出'], ['1 3 5 7 9 11', '6 个散号'],
      ['1-3 5-7 9-11', '三个短区间'], ['21-25 27-31', '两个五位区间'],
      ['1-3 5 7-9 11', '混合'], ['1 3 5 7 9 11 13 15', '8 个散号（17 字符）'],
      ['1 3 5 7 9 11 13 15 17', '9 个散号'], ['1-9 11-19', '两段较长区间']
    ]
  },
  {
    name: 'D 纯散点截断（B-1）',
    cases: [
      ['1 3 5 7 9 11 13 15', '8 个散号'], ['1 3 5 7 9 11 13 15 17 19', '10 个散号'],
      ['1 3 5 7 9 11 13 15 17 19 21 23', '12 个散号'],
      ['1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31', '16 个散号'],
      ['1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20', '20 个连续号'],
      ['11 13 15 17 19 21 23 25', '全两位散号'],
      ['91 93 95 97 99', '贴上限的散号'],
      ['1 3 5 7 91 95 99', '位数混合']
    ]
  },
  {
    name: 'E 单区间 + 散号（ellipsizedTail，双省略号最宽行）',
    cases: [
      ['1 3 21-35 41 43 45 47 49 51 53', '最宽行 …21-35… 形态'],
      ['1 3 21-30 41 43 45 47', '真机实测最宽行 …21-30…'],
      ['1 21-35 41', '区间在中间'], ['21-35 41 43', '区间在最前'],
      ['1 3 5 21-35', '区间在最后'], ['1 3 5 7 21-35 41 43', '前后都有散号'],
      ['1 3 5 7 9 61-99 41', '贴上限区间 + 散号'],
      ['1 3 5 7 9 91-99 41', '尾段区间 + 散号']
    ]
  },
  {
    name: 'F 双 / 多区间紧凑折叠（B-2）',
    cases: [
      ['1 3-15 18 20 22 25-32 41-50', '三个区间 + 散号'],
      ['1-3 5 7-9 11-13 15-17', '四个区间'],
      ['1 3-15 25-32', '两个区间 + 前导散号'],
      ['3-15 25-32 41-50', '三个区间'],
      ['1-9 11-19 21-29 31-39', '四段连续区间'],
      ['1 3 5-7 9 11 13-15 17', '交替区间与散号'],
      ['21-30 41-50 61-70 91-99', '四段贴上限区间']
    ]
  },
  {
    name: 'G 真实业务排布（转入 / 转出 / 连续段 / 分隔符）',
    cases: [
      ['1-30', '整段一次给全'], ['1-15 17-30', '分出去一段后剩两段'],
      ['21-35', '用户设想：中间 21 到 35'], ['31-40 42 44 46', '尾段 + 零星号'],
      ['1-20 22-40 42-60', '三段大区间'],
      ['5 8-12 15 18-22 25', '典型混合输入'],
      ['1，3、5；7/9', '全角分隔符'], ['1到5 8至10 12~14', '中文区间写法'],
      ['1 - 3 5', '横杠两侧带空格'], ['01 03 05 07', '前导零'],
      ['1 3 5 7 9 11 13 15 17 19 21', '奇数号连续段'],
      ['2 4 6 8 10 12 14 16 18 20', '偶数号连续段']
    ]
  },
  {
    name: 'H 99 以内的极端宽度 / 最宽行',
    cases: [
      ['90-99', '贴上限短区间'], ['1-99', '整段到上限'],
      ['21-30 41-50 61-70 91-99', '四段区间'],
      ['91 93 95 97 99', '全两位散号'],
      ['1-30 41-60 71-99', '三段长区间'],
      ['1 3 5 7 9 11 13 15 17 19 61-80 91-99', '散号 + 多区间'],
      ['1 3 21-30 41 43 45 47 49 51 53 55', '最宽行 …21-30…'],
      ['1 3 5-7 9 11 13-15 17', '双省略号 …13-15…']
    ]
  }
];

// ===== 渲染与判定 =====
const { S, L } = loadModel();
const fs = S.shedFontSizeVp(WIDTH);
const budget = S.shedMaxChars(WIDTH);
const avail = WIDTH - BORDER_VP;
const INNER = Math.max(8, Math.round(avail * SCALE));

function pad(s, n) {
  const len = Array.from(s).reduce((a, c) => a + (c.charCodeAt(0) > 255 ? 2 : 1), 0);
  return s + ' '.repeat(Math.max(0, n - len));
}

function cellRows(lines) {
  const rows = ['┌' + '─'.repeat(INNER) + '┐'];
  for (let i = 0; i < 2; i++) {
    const s = i < lines.length ? lines[i] : '';
    const n = Array.from(s).length;
    const left = Math.max(0, Math.floor((INNER - n) / 2));
    const right = Math.max(0, INNER - n - left);
    rows.push('│' + ' '.repeat(left) + s + ' '.repeat(right) + '│');
  }
  rows.push('└' + '─'.repeat(INNER) + '┘');
  return rows;
}

function bar(w) {
  const filled = Math.max(0, Math.min(INNER, Math.round(w * SCALE)));
  return '[' + '█'.repeat(filled) + '░'.repeat(INNER - filled) + ']';
}

function esc(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function evaluate(raw) {
  const lines = S.renderForColumn(raw, WIDTH);
  const items = parseItems(raw);
  const widths = lines.map((s) => lineWidthVp(s, fs));
  const lens = lines.map((s) => Array.from(s).length);
  // 用户目标口径：棚号「不过百」。分开统计，避免超百号掩盖真实达标情况。
  const nums = (raw.match(/\d+/g) || []).map(Number);
  const maxNum = nums.length ? Math.max(...nums) : 0;
  const scope = maxNum >= 100 ? 'over100' : (maxNum > 0 ? 'under100' : 'none');
  const expectedEmpty = raw.trim().length === 0;
  const problems = [];
  if (lines.length > 2) problems.push('超过 2 行');
  // 空棚号本来就不画任何内容，属于设计行为，不算缺陷
  if (!expectedEmpty && (lines.length === 0 || lines.every((s) => s.trim() === ''))) problems.push('空白格');
  if (lines.length > 0 && !lines.join('').match(/\d/) && raw.match(/\d/)) problems.push('信息全丢（只剩省略号）');
  for (let i = 0; i < lines.length; i++) {
    if (lens[i] > budget) problems.push(`行${i + 1} 超字符预算 ${lens[i]}>${budget}`);
    if (widths[i] > avail) problems.push(`行${i + 1} 像素超宽 ${widths[i].toFixed(1)}>${avail}vp（会被裁字）`);
    // 输出里出现的每个号码片段都必须是完整的显示项，否则说明区间被从中间切断
    const segs = lines[i].match(/\d+(?:-\d+)?/g) || [];
    for (const seg of segs) {
      if (items.length > 0 && !items.includes(seg)) problems.push(`区间/号码被切断: ${seg}`);
    }
  }
  const worst = widths.length ? Math.max(...widths) : 0;
  const thin = worst > 0 && avail - worst < 2;
  return {
    lines, widths, lens, problems, worst, thin, scope, expectedEmpty, maxNum,
    ok: problems.length === 0
  };
}

const all = [];
for (const group of GROUPS) {
  for (const [raw, note] of group.cases) all.push({ group: group.name, raw, note, ...evaluate(raw) });
}

// ===== 终端报告 =====
const SEP = '─'.repeat(78);
console.log('');
console.log('='.repeat(78));
console.log(`棚号列定档测算：列宽 ${WIDTH}vp · 边框 1vp · 可用 ${avail}vp · 字号 ${fs}vp · 每行预算 ${budget} 字符`);
console.log(`固定列宽总和 ${L.LAYOUT_WIDTHS.reduce((a, b) => a + b, 0)}vp（实际取 LAYOUT_WIDTHS[1]=${L.LAYOUT_WIDTHS[1]}vp）`);
console.log('渲染用真实 ShedDisplay.renderForColumn()；像素宽按 @14vp 真机字形表估算');
console.log('='.repeat(78));

let idx = 0;
for (const group of GROUPS) {
  console.log('');
  console.log(SEP);
  console.log(`【${group.name}】`);
  console.log(SEP);
  for (const c of all.filter((x) => x.group === group.name)) {
    idx++;
    console.log(`${String(idx).padStart(2, '0')}. ${c.note}`);
    console.log(`    输入：${c.raw === '' ? '(空)' : c.raw}`);
    for (const row of cellRows(c.lines)) console.log('    ' + row);
    const lineInfo = c.lines.length
      ? c.lines.map((s, i) => `行${i + 1} "${s}" ${c.lens[i]}字符/${c.widths[i].toFixed(1)}vp`).join('  |  ')
      : '(无输出)';
    console.log('    ' + lineInfo);
    console.log('    宽度占用 ' + bar(c.worst) + ` ${c.worst.toFixed(1)}/${avail.toFixed(1)}vp，余 ${(avail - c.worst).toFixed(1)}vp`);
    if (c.expectedEmpty) {
      console.log('    · 预期空白（空棚号不显示，符合设计）');
    } else if (c.ok) {
      console.log('    ✓ 合格' + (c.thin ? '（余量偏薄，<2vp）' : ''));
    } else {
      console.log('    ✗ ' + [...new Set(c.problems)].join('；'));
    }
  }
}

// ===== 汇总 =====
const bad = all.filter((c) => !c.ok);
const thin = all.filter((c) => c.ok && c.thin && c.worst > 0);
const business = all.filter((c) => c.scope === 'under100');
const badBusiness = business.filter((c) => !c.ok);
console.log('');
console.log('='.repeat(78));
console.log('汇总（业务口径：棚号最大 99）');
console.log('='.repeat(78));
console.log(`用例 ${all.length} 组 · 合格 ${all.length - bad.length} · 有问题 ${bad.length} · 余量偏薄 ${thin.length}`);
console.log(`其中业务输入（含号码且 ≤99）${business.length} 组 · 合格 ${business.length - badBusiness.length} · 有问题 ${badBusiness.length}`);
console.log(`另有 ${all.length - business.length} 组空值 / 无号码输入，按设计不显示内容。`);
const kinds = {};
for (const c of bad) {
  for (const p of new Set(c.problems)) {
    const k = p.replace(/ \d+.*$/, '').replace(/:.*$/, '');
    kinds[k] = (kinds[k] || 0) + 1;
  }
}
console.log('问题分布：' + (Object.keys(kinds).length ? Object.entries(kinds).map(([k, v]) => `${k} ${v}`).join(' / ') : '无'));
console.log('');
console.log('最宽的 8 行（按估算像素宽）：');
for (const c of [...all].filter((x) => x.worst > 0).sort((a, b) => b.worst - a.worst).slice(0, 8)) {
  console.log(`  ${c.worst.toFixed(2).padStart(6)}vp  余 ${(avail - c.worst).toFixed(2).padStart(6)}vp  ` +
    `${JSON.stringify(c.lines)}  ← ${c.raw || '(空)'}`);
}
if (bad.length > 0) {
  console.log('');
  console.log('不合格明细：');
  for (const c of bad) console.log(`  · ${c.raw || '(空)'} → ${JSON.stringify(c.lines)}  ${[...new Set(c.problems)].join('；')}`);
}

// ===== 越界演示：>99 的输入会怎样（不计入统计，仅作风险提示）=====
console.log('');
console.log('='.repeat(78));
console.log('越界输入演示（棚号 >99，不在业务口径内，仅说明为什么上限要定 99）');
console.log('='.repeat(78));
for (const raw of ['100', '100-200', '1001-1005', '1000-2000', '1 3 5 7 9 1000-2000 41']) {
  const c = evaluate(raw);
  console.log(`  ${raw.padEnd(30)} → ${JSON.stringify(c.lines).padEnd(30)} ` +
    `最宽 ${c.worst.toFixed(1)}vp  ${c.ok ? '合格' : [...new Set(c.problems)].join('；')}`);
}

// ===== 档位对照：不同列宽下的字号 / 预算 / 最宽行余量 =====
console.log('');
console.log('='.repeat(78));
console.log('列宽档位对照');
console.log('='.repeat(78));
const refWorst = '…21-30…';  // 业务口径内的最宽行（双省略号）
const refPlain = '1 3 5 7';  // 普通 7 字符行
console.log(`  参照行 A "${refWorst}"（最宽，@14vp ${lineWidthVp(refWorst, 14).toFixed(2)}vp）`);
console.log(`  参照行 B "${refPlain}"（普通 7 字符，@14vp ${lineWidthVp(refPlain, 14).toFixed(2)}vp）`);
console.log('  列宽   可用   字号  预算    A 余量           B 余量');
for (const w of [56, 58, 60, 62, 64, 68, 72, 87]) {
  const f = S.shedFontSizeVp(w);
  const b = S.shedMaxChars(w);
  const a = w - BORDER_VP;
  const rA = a - lineWidthVp(refWorst, f);
  const rB = a - lineWidthVp(refPlain, f);
  const flag = (r) => (r < 0 ? '✗裁' : (r < 2 ? '⚠薄' : '✓'));
  console.log(`  ${String(w).padStart(3)}vp  ${String(a).padStart(3)}vp  ${String(f).padStart(3)}vp   ${b}     ` +
    `${rA.toFixed(2).padStart(6)}vp ${flag(rA)}    ${rB.toFixed(2).padStart(6)}vp ${flag(rB)}`);
}
console.log('');
console.log('说明：省略号只在真发生截断时出现；编辑态点进格子仍显示完整原始字符串。');
console.log('像素宽为浏览器/真机字形近似估算，最终以真机截图为准。');

// ===== 可选：生成 2× 放大的 HTML 单元格预览 =====
if (HTML_OUT) {
  const cards = GROUPS.map((g) => {
    const body = all.filter((x) => x.group === g.name).map((c) => {
      const linesHtml = [0, 1].map((i) => {
        const s = i < c.lines.length ? c.lines[i] : '';
        return `<div class="ln${c.widths[i] > avail ? ' over' : ''}">${esc(s) || '&nbsp;'}</div>`;
      }).join('');
      const badge = c.expectedEmpty ? '预期空白' :
        (c.ok ? (c.thin ? '合格·余量偏薄' : '合格') : [...new Set(c.problems)].join('；'));
      const badgeClass = !c.ok ? 'fail' : (c.expectedEmpty ? 'muted' : 'pass');
      return `<div class="case">
        <div class="meta"><span class="raw">${esc(c.raw || '(空)')}</span><span class="note">${esc(c.note)}</span></div>
        <div class="cell${c.ok ? '' : ' bad'}">${linesHtml}</div>
        <div class="stat">${c.worst.toFixed(1)} / ${avail.toFixed(1)}vp · 余 ${(avail - c.worst).toFixed(1)}vp<br>
          <b class="${badgeClass}">${esc(badge)}</b></div>
      </div>`;
    }).join('');
    return `<h2>${esc(g.name)}</h2><div class="grid">${body}</div>`;
  }).join('');

  const html = `<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>棚号列 ${WIDTH}vp / ${fs}vp 排布预览</title>
<style>
  body{font-family:-apple-system,"HarmonyOS Sans SC","Microsoft YaHei",sans-serif;background:#f5f6f8;color:#1a1a1a;margin:24px;}
  h1{font-size:20px;margin:0 0 6px} h2{font-size:15px;margin:26px 0 10px;color:#333;border-left:4px solid #2D8C42;padding-left:8px}
  .sub{font-size:13px;color:#666;margin-bottom:18px;line-height:1.7}
  .grid{display:flex;flex-wrap:wrap;gap:12px}
  .case{background:#fff;border:1px solid #e3e5e8;border-radius:8px;padding:10px;width:250px;box-sizing:border-box}
  .meta{font-size:11px;color:#666;height:32px;overflow:hidden;line-height:1.4}
  .raw{display:block;color:#111;font-family:monospace;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .cell{width:120px;height:80px;border:1px solid #b9bdc4;background:#fff;margin:8px auto;
        display:flex;flex-direction:column;justify-content:center;overflow:hidden;box-sizing:border-box}
  .cell.bad{border-color:#d32f2f;background:#fff6f6}
  .ln{font-size:28px;line-height:30px;font-weight:700;text-align:center;white-space:nowrap;color:#111}
  .ln.over{color:#d32f2f}
  .stat{font-size:11px;color:#777;text-align:center;line-height:1.5}
  .pass{color:#2D8C42} .fail{color:#d32f2f} .muted{color:#888}
  .legend{font-size:12px;color:#666;margin-top:20px}
</style></head><body>
<h1>棚号列定档预览：${WIDTH}vp / ${fs}vp / 每行 ${budget} 字符</h1>
<div class="sub">业务口径：<b>棚号最大 99</b>（不过百）。单元格按 <b>2× 放大</b> 绘制（120×80px 对应 60×40vp，字号 28px 对应 14vp）；左右边框合计 1vp，无内边距，实际可用 ${avail}vp。<br>
文本由真实 ShedDisplay.renderForColumn() 生成；红色 = 估算像素超宽或判定不合格。浏览器字体与鸿蒙真机略有差异，最终以真机为准。</div>
${cards}
<div class="legend">合计 ${all.length} 组 · 合格 ${all.length - bad.length} · 有问题 ${bad.length} · 余量偏薄 ${thin.length}；
其中业务输入（含号码且 ≤99）${business.length} 组，合格 ${business.length - badBusiness.length} 组。</div>
</body></html>`;
  mkdirSync(path.dirname(HTML_OUT), { recursive: true });
  writeFileSync(HTML_OUT, html, 'utf8');
  console.log(`\nHTML 预览已生成：${HTML_OUT}`);
}

rmSync(BUILD, { recursive: true, force: true });
