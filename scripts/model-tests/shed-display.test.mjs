/**
 * ShedDisplay 两行极简折叠回归 —— 直译 ShedDisplayTest.java 全量用例 +
 * 0.3.6 计划「任务 3」的全部 12 组期望输出。
 *
 * 判定口径：每行 ≤ 9 字符，最多 2 行，任何 Range 不被拆分；
 * 无信息丢失时绝不出现省略号。
 */
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);

/** 加载编译后的模型产物（由 run-model-tests.mjs 设置 MODEL_TEST_OUT_DIR）。 */
function loadModel(name) {
  const outDir = process.env.MODEL_TEST_OUT_DIR;
  if (!outDir) {
    throw new Error('MODEL_TEST_OUT_DIR 未设置，请用 node scripts/run-model-tests.mjs 运行');
  }
  return require(path.join(outDir, `${name}.js`));
}

export default function run(t) {
  const ShedDisplay = loadModel('ShedDisplay');

  /** 断言：行数、逐行内容、最多 2 行、每行长度 ≤9。 */
  function assertRender(raw, expected, label) {
    const lines = ShedDisplay.render(raw);
    t.equal(lines.length, expected.length, `${label}: 行数`);
    for (let i = 0; i < expected.length; i++) {
      t.equal(lines[i], expected[i], `${label}: 第${i + 1}行`);
    }
    t.equal(lines.length <= 2, true, `${label}: 最多 2 行`);
    for (let i = 0; i < lines.length; i++) {
      t.equal(lines[i].length <= 9, true, `${label}: 第${i + 1}行长度 ≤9`);
    }
  }

  // ① 纯散点全显示 A-2
  assertRender('1 3 5 7 9 11 13', ['1 3 5', '7 9 11 13'], 'case1_pureScatterTwoLines');
  // ② 两行全显示 A-2
  assertRender('1 3-15 17 19-32', ['1 3-15', '17 19-32'], 'case2_twoLinesFull');
  // ③ 三位数防爆 A-2
  assertRender('101-105 107 109', ['101-105', '107 109'], 'case3_threeDigitsNoOverflow');
  // ④ Range 截断 B-2：中间被折叠，首尾 Range 都露出
  assertRender('1 3-15 18 20 22 25-32', ['1…3-15', '…25-32'], 'case4_rangeTruncate');
  // ⑤ 双 Range 极限 B-2（关键极限用例）
  assertRender('1 3 5 7-15 18 20 22 25-32 37 39 41',
    ['1 3…7-15', '…25-32…'], 'case5_doubleRangeLimit');
  // ⑥ 双大 Range + 散点 B-2
  assertRender('1 3-15 18 20 22 24 26 28 30 100-199',
    ['1…3-15', '…100-199'], 'case6_doubleBigRangeWithScatter');
  // 单区间单行 A-1
  assertRender('1-40', ['1-40'], 'singleRangeOneLine');

  // 空 / 空白 / null → []（直译 emptyAndBlank；ArkTS 端用 typeof 防御 null）
  t.equal(ShedDisplay.render(null).length, 0, 'emptyAndBlank: null → 0 行');
  t.equal(ShedDisplay.render('').length, 0, 'emptyAndBlank: 空串 → 0 行');
  t.equal(ShedDisplay.render('   ').length, 0, 'emptyAndBlank: 空白 → 0 行');

  // 预处理：相邻/重叠合并成区间，各种分隔符都能解析
  assertRender('1 2 3', ['1-3'], 'preprocessMergesAdjacent: 1 2 3');
  assertRender('1-3 4', ['1-4'], 'preprocessMergesAdjacent: 1-3 4');
  assertRender('1、2、3', ['1-3'], 'preprocessMergesAdjacent: 1、2、3');

  // B-1 散点截断：第一行贪心、第二行尾部倒推带 "… "
  assertRender('2 4 6 8 10 12 14 16 18 20 22',
    ['2 4 6 8', '… 20 22'], 'scatterTruncateHasLeadingEllipsis');

  // 只有一个区间时只露一次（0.3.17 修复）：9-15 在合并后的输出里只出现一次
  assertRender('1 3 5 7 9-15 17 19 21',
    ['1 3 5 7…', '…9-15 17…'], 'singleRangeNeverShowsTwice');
  {
    const lines = ShedDisplay.render('1 3 5 7 9-15 17 19 21');
    const joined = lines.join('');
    let count = 0;
    let idx = joined.indexOf('9-15');
    while (idx >= 0) {
      count++;
      idx = joined.indexOf('9-15', idx + 1);
    }
    t.equal(count, 1, 'singleRangeNeverShowsTwice: 9-15 只出现一次');
  }

  // 唯一区间且在最前：行 1 区间带头，行 2 接后面的散号
  assertRender('9-15 17 19 21 23 25', ['9-15…', '…17 19…'], 'singleRangeAtFrontLeadsLineOne');
}
