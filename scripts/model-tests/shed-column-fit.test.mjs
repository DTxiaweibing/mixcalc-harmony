/**
 * 棚号列分档回归（0.3.6 最终定档 + A 方案列宽口径兼容测试）。
 *
 * 应用 UI 定档：11 列全部显示（窗口 >=600vp，铺满、无需滚动）→ 15vp / 9 字符；
 * 需要横向滚动的手机布局（棚号列 60vp）→ 14vp / 7 字符。
 * 字号与字符预算必须取同一个模式判据，只作用于棚号列（col 1）。
 *
 * 另保留「按列宽算预算」的列宽口径函数，供离线测算脚本评估档位；
 * 这部分不参与应用渲染，但回归仍需全绿。
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

  // 字号定档 14vp：整列统一，不随列宽升降
  t.equal(S.shedFontSizeVp(60), 14, '60vp 列用 14vp');
  t.equal(S.shedFontSizeVp(72), 14, '72vp 列也用 14vp');
  t.equal(S.shedFontSizeVp(87), 14, '87vp 宽列仍固定 14vp');
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

  // ===== 应用 UI 定档：铺满 15vp/9 字符，滚动 14vp/7 字符 =====
  t.equal(S.SHED_MAX_CHARS_FULL, 9, '铺满模式预算 9 字符');
  t.equal(S.SHED_MAX_CHARS_SCROLL, 7, '滚动模式预算 7 字符');
  t.equal(S.shedFontSizeForMode(true), 15, '铺满模式字号 15vp');
  t.equal(S.shedFontSizeForMode(false), 14, '滚动模式字号 14vp');
  t.equal(S.shedMaxCharsForMode(true), 9, '铺满模式 9 字符');
  t.equal(S.shedMaxCharsForMode(false), 7, '滚动模式 7 字符');

  // 铺满模式与标称 9 字符的 render() 完全一致；滚动模式与 60vp 列宽口径一致
  for (const s of samples) {
    t.equal(
      JSON.stringify(S.renderForMode(s, true)),
      JSON.stringify(S.render(s)),
      `铺满模式输出 = 标称 9 字符: ${s || '(空)'}`
    );
    t.equal(
      JSON.stringify(S.renderForMode(s, false)),
      JSON.stringify(S.renderForColumn(s, 60)),
      `滚动模式输出 = 60vp 列宽口径: ${s || '(空)'}`
    );
  }

  // 两个模式都不爆行、每行不超自己的预算、区间不被切断
  const modeSamples = [
    '1 3 5 7 9 11 13',
    '1 3-15 17 19-32',
    '1 3-15 18 20 22 25-32',
    '1 3 7-15',
    '1 3 21-35 41 43 45 47',
    '31-40 42 44 46',
    '1-30',
    ''
  ];
  for (const full of [true, false]) {
    const budget = S.shedMaxCharsForMode(full);
    for (const s of modeSamples) {
      const lines = S.renderForMode(s, full);
      t.equal(lines.length <= 2, true, `${full ? '铺满' : '滚动'}最多 2 行: ${s || '(空)'}`);
      for (const line of lines) {
        t.equal(line.length <= budget, true,
          `${full ? '铺满' : '滚动'}每行 ≤${budget} 字符: ${line}`);
      }
    }
  }

  // 9 字符预算确实比 7 字符露出更多内容（不是同一套排版换个字号）
  const wide = '1 3 5 7 9 11 13 15';
  t.equal(
    JSON.stringify(S.renderForMode(wide, true)),
    JSON.stringify(['1 3 5 7 9', '11 13 15']),
    '铺满 9 字符：两行全显示、无省略号'
  );
  t.equal(
    JSON.stringify(S.renderForMode(wide, false)),
    JSON.stringify(['1 3 5 7', '…13 15']),
    '滚动 7 字符：尾部折叠出省略号（省略号紧贴数字，不留空格）'
  );

  // ===== 用户验收清单（未命名2.txt）：滚动档 14vp / 7 字符，12 组逐组钉死 =====
  // 定档要求：A-2 切分取最接近对半、平手偏短首行；B-2 首行用足中间词；
  // B-1 省略号紧贴数字。任何一条被改回去，下面立刻红。
  const acceptance = [
    ['1 2 3 5', ['1-3 5']],
    ['1 2 3 5 7 9 11', ['1-3 5', '7 9 11']],
    ['1 2 3 5 7 8 9 10 11 12 13 14 15', ['1-3 5', '7-15']],
    ['1 2 3 5 7 8 9 10 11 12 13 14 15 17 19', ['1-3 5', '7-15…']],
    ['1 2 3 5 7 8 9 10 11 12 13 14 15 17 19 21 22 23 24 25 26 27 28 29 30', ['1-3 5', '…21-30']],
    ['1 2 3 5 7 8 9 10 11 12 13 14 15 17 19 21 22 23 24 25 26 27 28 29 30 32 34', ['1-3 5', '…21-30…']],
    ['1 3 5 7 9 11 13 15', ['1 3 5 7', '…13 15']],
    [Array.from({ length: 30 }, (_, i) => i + 1).join(' '), ['1-30']],
    ['1 2 3 5 7 8 9', ['1-3 5', '7-9']],
    ['10 11 12 14 15 16', ['10-12', '14-16']],
    ['1 2 3 5 7 8 9 10 11 12 13 14 15 17 19 21 22', ['1-3 5', '…21-22']],
    ['60 61 62 64 65', ['60-62', '64-65']]
  ];
  const scrollBudget = S.shedMaxCharsForMode(false);
  for (let i = 0; i < acceptance.length; i++) {
    const raw = acceptance[i][0];
    const want = acceptance[i][1];
    const lines = S.renderForMode(raw, false);
    t.equal(JSON.stringify(lines), JSON.stringify(want), `验收清单 第${i + 1}组: ${raw.slice(0, 24)}`);
    let within = lines.length <= 2;
    for (const line of lines) {
      if (line.length > scrollBudget) {
        within = false;
      }
    }
    t.equal(within, true, `验收清单 第${i + 1}组 最多 2 行且每行 ≤${scrollBudget} 字符`);
  }
}
