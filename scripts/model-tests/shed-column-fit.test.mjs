/**
 * 棚号列「按列宽算字符预算 + 字号回退」回归（0.3.6 A 方案）。
 *
 * 口径：单元格 72vp，左右边框各 0.5vp → 可用 71vp，不留内边距；
 * 15vp 粗体每字符实测 8.25vp → 71 / 8.25 = 8 字符，装不下标称 9 字符 → 整列降 14vp。
 * 只有棚号列（col 1）走这套规则，其它列的字号与文本规则不受影响。
 */
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);

/** 加载编译后的纯计算模块（由 run-model-tests.mjs 设置 MODEL_TEST_OUT_DIR）。 */
function loadModel(name) {
  const outDir = process.env.MODEL_TEST_OUT_DIR;
  if (!outDir) {
    throw new Error('MODEL_TEST_OUT_DIR 未设置，请用 node scripts/run-model-tests.mjs 运行');
  }
  return require(path.join(outDir, `${name}.js`));
}

export default function run(t) {
  const S = loadModel('ShedDisplay');

  // 常量口径
  t.equal(S.SHED_BORDER_VP, 1, '左右边框合计 1vp');
  t.equal(S.SHED_CHAR_VP_AT_15, 8.25, '15vp 粗体每字符 8.25vp');
  t.equal(S.SHED_FONT_PRIMARY, 15, '首选字号 15vp');
  t.equal(S.SHED_FONT_FALLBACK, 14, '回退字号 14vp');

  // 可用宽度：只扣边框，不留内边距
  t.equal(S.shedAvailableWidth(72), 71, '72vp 列可用 71vp');
  t.equal(S.shedAvailableWidth(87), 86, '87vp 列可用 86vp');
  t.equal(S.shedAvailableWidth(0), 1, '列宽 0 兜底为 1vp');
  t.equal(S.shedAvailableWidth(-5), 1, '负列宽兜底为 1vp');

  // 字符预算：标称 9 是上限，只往下调不往上调
  t.equal(S.shedMaxCharsAt(72, 15), 8, '72vp @15vp 只能放 8 字符');
  t.equal(S.shedMaxCharsAt(72, 14), 9, '72vp @14vp 能放 9 字符');
  t.equal(S.shedMaxCharsAt(87, 15), 9, '87vp @15vp 达到上限 9');
  t.equal(S.shedMaxCharsAt(64, 14), 8, '64vp @14vp 只有 8 字符');

  // 字号选择：72vp 降到 14vp，宽列保持 15vp
  t.equal(S.shedFontSizeVp(72), 14, '72vp 列整列用 14vp');
  t.equal(S.shedFontSizeVp(87), 15, '87vp 列保持 15vp');
  t.equal(S.shedFontSizeVp(64), 14, '64vp 列用 14vp');
  t.equal(S.shedMaxChars(72), 9, '72vp 最终预算 9 字符');
  t.equal(S.shedMaxChars(87), 9, '87vp 最终预算 9 字符');
  t.equal(S.shedMaxChars(64), 8, '64vp 最终预算 8 字符');

  const samples = [
    '1 3 5 7 9 11 13',
    '1 3-15 17 19-32',
    '1 3-15 18 20 22 25-32',
    '1 3 7-15',
    ''
  ];

  // 列宽足够时，输出与旧的 render()（标称 9 字符）完全一致
  for (const s of samples) {
    t.equal(
      JSON.stringify(S.renderForColumn(s, 87)),
      JSON.stringify(S.render(s)),
      `87vp 与标称 9 字符输出一致: ${s || '(空)'}`
    );
  }

  // 预算收紧时每行不超预算、最多 2 行
  for (const width of [72, 64, 87, 50]) {
    const budget = S.shedMaxChars(width);
    for (const s of samples) {
      const lines = S.renderForColumn(s, width);
      t.equal(lines.length <= 2, true, `${width}vp 最多 2 行: ${s || '(空)'}`);
      for (const line of lines) {
        t.equal(line.length <= budget, true, `${width}vp 每行 ≤${budget} 字符: ${line}`);
      }
    }
  }

  // 收紧预算后仍不把连续区间从中间切断
  const narrow = S.renderForColumn('1 3-15 18 20 22 25-32', 64);
  const joined = narrow.join('|');
  t.equal(narrow.length <= 2, true, '窄列仍最多 2 行');
  t.equal(
    joined.indexOf('3-') < 0 || joined.indexOf('3-15') >= 0,
    true,
    '窄列不把 3-15 从中间切断'
  );
  t.equal(
    joined.indexOf('25-') < 0 || joined.indexOf('25-32') >= 0,
    true,
    '窄列不把 25-32 从中间切断'
  );
}
