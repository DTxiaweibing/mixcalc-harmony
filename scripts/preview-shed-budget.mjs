/**
 * 棚号两行折叠「效果预览」——调档位前的人工可读性评估工具。
 *
 * 直接调用项目里真实的 ShedDisplay 模型（不是模拟算法），把极端场景
 * 渲染成等宽字符单元格，并排对比两种列宽/字符预算下的显示效果。
 * 只读，不改应用代码、不产生截图、不落盘业务数据。
 *
 * 用法：node scripts/preview-shed-budget.mjs [窄列宽 宽列宽]
 * 例：  node scripts/preview-shed-budget.mjs 60 72
 *       node scripts/preview-shed-budget.mjs 64 72
 */
import { spawnSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BUILD = path.join(ROOT, 'scripts', '.model-test-build');
const OUT = path.join(BUILD, 'out');
const NARROW = Number(process.argv[2] || 60);
const WIDE = Number(process.argv[3] || 72);

// 复用模型测试框架的 tsc 编译产物，保证预览用的是真正会上线的算法
function loadModel() {
  if (!existsSync(path.join(OUT, 'ShedDisplay.js'))) {
    const r = spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'run-model-tests.mjs')], {
      cwd: ROOT,
      env: Object.assign({}, process.env, { MODEL_TEST_KEEP: '1' }),
      encoding: 'utf8'
    });
    if (r.status !== 0) {
      console.error(r.stdout || '');
      console.error(r.stderr || '');
      throw new Error('模型编译失败');
    }
  }
  return require(path.join(OUT, 'ShedDisplay.js'));
}

// 6 种极端 / 边界场景：覆盖 A-1 单行、A-2 两行完整、B-1 散点截断、
// B-2 双区间折叠、单区间 ellipsizedTail（用户设想的双省略号最宽行）。
const CASES = [
  {
    name: '1 单区间', raw: '21-35',
    note: '只有一个连续区间，最干净；验证单行不换行'
  },
  {
    name: '2 恰好 7 字符', raw: '1 3 5 7',
    note: '单行预算刚好用满，验证边界不溢出'
  },
  {
    name: '3 两行全显示', raw: '1 3 5 7 9 11 13',
    note: '7 个散号全部露出、零省略号，信息量最佳'
  },
  {
    name: '4 全散号 16 个', raw: '1 3 5 7 9 11 13 15 17 19 21 23 25 27 29 31',
    note: '无区间，走 B-1 散点截断；中段号码被吞最多'
  },
  {
    name: '5 三个区间 + 散号', raw: '1 3-15 18 20 22 25-32 41-50',
    note: '多区间走 B-2 紧凑折叠；只保留首尾关键区间'
  },
  {
    name: '6 双省略号最宽行', raw: '1 3 21-35 41 43 45 47 49 51 53',
    note: '产出 …21-35… 形态，是 7 字符里视觉上最宽的一行'
  }
];

// 预览按 0.5 字符 ≈ 1vp 缩放，左右并排才不会超出终端宽度。
const SCALE = 0.5;
function cellLines(textLines, widthVp) {
  const inner = Math.max(8, Math.round(widthVp * SCALE));
  const rows = [];
  rows.push('┌' + '─'.repeat(inner) + '┐');
  for (let i = 0; i < 2; i++) {
    const s = i < textLines.length ? textLines[i] : '';
    const n = Array.from(s).length;
    const left = Math.max(0, Math.floor((inner - n) / 2));
    const right = Math.max(0, inner - n - left);
    rows.push('│' + ' '.repeat(left) + s + ' '.repeat(right) + '│');
  }
  rows.push('└' + '─'.repeat(inner) + '┘');
  return rows;
}

function stats(lines, budget) {
  const lens = lines.map((s) => Array.from(s).length);
  const dots = lines.join('').split('…').length - 1;
  const over = lens.some((n) => n > budget);
  return `${lines.length}行/${lens.join('+')}字符` +
    (dots > 0 ? ` · ${dots}个省略号` : ' · 无省略号') +
    (over ? ' · !! 超预算' : '');
}

function pad(s, n) {
  const len = Array.from(s).reduce((a, c) => a + (c.charCodeAt(0) > 255 ? 2 : 1), 0);
  return s + ' '.repeat(Math.max(0, n - len));
}

const S = loadModel();
const colW = Math.max(8, Math.round(WIDE * SCALE)) + 2;

console.log('棚号两行折叠效果预览（真实 ShedDisplay 模型，非模拟）');
console.log(`对比：${NARROW}vp（7 字符方案）  vs  ${WIDE}vp（当前 9 字符）`);
console.log('预览按 0.5 字符 ≈ 1vp 缩放；… 按单字符计，终端字形可能略有 1 列偏差');
console.log('');

for (const c of CASES) {
  const bn = S.shedMaxChars(NARROW);
  const bw = S.shedMaxChars(WIDE);
  const ln = S.renderForColumn(c.raw, NARROW);
  const lw = S.renderForColumn(c.raw, WIDE);
  const left = cellLines(ln, NARROW);
  const right = cellLines(lw, WIDE);

  console.log('─'.repeat(78));
  console.log(`${c.name}   ${c.note}`);
  console.log(`输入：${c.raw}`);
  console.log(pad(`${NARROW}vp · ${S.shedFontSizeVp(NARROW)}vp · 预算${bn}`, colW + 4) +
    pad(`${WIDE}vp · ${S.shedFontSizeVp(WIDE)}vp · 预算${bw}`, colW + 4));
  for (let i = 0; i < left.length; i++) {
    console.log(pad(left[i], colW + 4) + pad(right[i], colW + 4));
  }
  console.log(pad('  ' + stats(ln, bn), colW + 4) + '  ' + stats(lw, bw));
  console.log('  与当前对比：' +
    (JSON.stringify(ln) === JSON.stringify(lw)
      ? '显示完全相同，没有信息损失'
      : '有差异 → 当前多露出：' + JSON.stringify(lw) + '（窄档为 ' + JSON.stringify(ln) + '）'));
  console.log('');
}

console.log('─'.repeat(78));
console.log('说明：省略号只在真发生截断时出现；两行最多，区间绝不从中间切断。');
console.log('编辑态点进格子仍显示完整原始字符串，不受两行折叠影响。');

rmSync(BUILD, { recursive: true, force: true });
