/**
 * ShedText / ShedRange 模型测试（直译自
 * app/src/test/java/.../ShedTextTest.java 与 ShedTransferTest.java 的全部用例）。
 *
 * 测试文件是 ESM；模型产物是 run-model-tests.mjs 用 tsc 编译出的 commonjs，
 * 通过 createRequire 从 MODEL_TEST_OUT_DIR 加载。
 */
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);

/** 加载编译后的模型产物（由 run-model-tests.mjs 设置 MODEL_TEST_OUT_DIR）。 */
export function loadModel(name) {
  const outDir = process.env.MODEL_TEST_OUT_DIR;
  if (!outDir) {
    throw new Error('MODEL_TEST_OUT_DIR 未设置，请用 node scripts/run-model-tests.mjs 运行');
  }
  return require(path.join(outDir, `${name}.js`));
}

const ShedText = loadModel('ShedText');
const ShedRange = loadModel('ShedRange');
const ShedCoverage = loadModel('ShedCoverage');

/**
 * 模拟活动的转移流程：改文本 → 打点覆盖 → 参与行重写为「实际拥有」。
 * 对应 ShedTransferTest.runTransfer；用 ShedRange.compressNumbers 代替 normalize（二者等价）。
 */
function runTransfer(rows, sourceRow, targetRow, numbers) {
  const moved = ShedText.transfer(rows[sourceRow], rows[targetRow], numbers);
  rows[sourceRow] = moved[0];
  rows[targetRow] = moved[1];
  const owned = ShedCoverage.ownedSets(rows);
  const participants = [sourceRow, targetRow];
  for (let k = 0; k < participants.length; k++) {
    const row = participants[k];
    rows[row] = ShedRange.compressNumbers(owned[row]);
  }
  return rows;
}

export default function run(t) {
  // ==================== ShedTextTest.java ====================

  // normalizeSortsAndMerges
  t.equal(ShedText.normalize([5, 1, 3, 2]), '1-3 5',
    'normalizeSortsAndMerges: [5,1,3,2]');
  t.equal(ShedText.normalize([36, 37, 38, 25, 20]), '20 25 36-38',
    'normalizeSortsAndMerges: [36,37,38,25,20]');
  t.equal(ShedText.normalize([40, 39]), '39 40',
    'normalizeSortsAndMerges: [40,39] 两连号不收区间');
  t.equal(ShedText.normalize([]), '',
    'normalizeSortsAndMerges: 空数组');

  // wholeRowToBlankTargetIsPointless
  t.equal(ShedText.pointlessWholeRowMove('', [26, 27, 28], [26, 27, 28]), true,
    'wholeRowToBlankTargetIsPointless: 整行转空行');
  t.equal(ShedText.pointlessWholeRowMove('', [26, 27], [26, 27, 30]), true,
    'wholeRowToBlankTargetIsPointless: targetText=null 等价空串');
  t.equal(ShedText.pointlessWholeRowMove('41-60', [26, 27], [26, 27]), false,
    'wholeRowToBlankTargetIsPointless: 目标行非空，真合并放行');
  t.equal(ShedText.pointlessWholeRowMove('', [26, 27, 28], [26, 27]), false,
    'wholeRowToBlankTargetIsPointless: 只转走一部分，放行');

  // transferMovesNumbersBothSides
  const both = ShedText.transfer('1-40', '', [5]);
  t.equal(both[0], '1-4 6-40', 'transferMovesNumbersBothSides: moved[0]');
  t.equal(both[1], '5', 'transferMovesNumbersBothSides: moved[1]');

  // transferIsNeverANoOpWhenTargetSpanCovers
  const covers = ShedText.transfer('1-40', '20-30', [25]);
  t.equal(covers[0], '1-24 26-40', 'transferIsNeverANoOpWhenTargetSpanCovers: moved[0]');
  t.equal(covers[1], '20-30', 'transferIsNeverANoOpWhenTargetSpanCovers: moved[1]');
  const coversCounts = ShedCoverage.ownedCounts([covers[0], covers[1]]);
  t.equal(coversCounts[0], 29, 'transferIsNeverANoOpWhenTargetSpanCovers: counts[0]');
  t.equal(coversCounts[1], 11, 'transferIsNeverANoOpWhenTargetSpanCovers: counts[1]');

  // transferUpFromRange
  const up = ShedText.transfer('20-30', '1-40', [25]);
  t.equal(up[0], '20-24 26-30', 'transferUpFromRange: moved[0]');
  t.equal(up[1], '1-40', 'transferUpFromRange: moved[1]');

  // transferNumbersNotInSourceStillLandOnTarget
  const notIn = ShedText.transfer('1-10', '', [11, 3]);
  t.equal(notIn[0], '1 2 4-10', 'transferNumbersNotInSourceStillLandOnTarget: moved[0]');
  t.equal(notIn[1], '3 11', 'transferNumbersNotInSourceStillLandOnTarget: moved[1]');

  // removeDeletesStandaloneNumber
  t.equal(ShedText.remove('1 3 5 7 8-40', [3]), '1 5 7 8-40',
    'removeDeletesStandaloneNumber: 删单号 3');
  t.equal(ShedText.remove('1 3 5 7 8-40', [1, 3, 5, 7]), '8-40',
    'removeDeletesStandaloneNumber: 删多个单号');

  // removeSplitsRangeWhenNumberInside
  t.equal(ShedText.remove('1 3 5 7 8-40', [20]), '1 3 5 7 8-19 21-40',
    'removeSplitsRangeWhenNumberInside: 8-40 去 20');
  t.equal(ShedText.remove('1-40', [5]), '1-4 6-40',
    'removeSplitsRangeWhenNumberInside: 1-40 去 5');

  // removeSplitsRangeAtEdges
  t.equal(ShedText.remove('1-40', [1, 40]), '2-39',
    'removeSplitsRangeAtEdges: 去两端');
  t.equal(ShedText.remove('1-40', [1]), '2-40',
    'removeSplitsRangeAtEdges: 去左端');
  t.equal(ShedText.remove('1-40', [40]), '1-39',
    'removeSplitsRangeAtEdges: 去右端');

  // removeSplitsRangeInMiddle
  t.equal(ShedText.remove('10-20', [15, 16]), '10-14 17-20',
    'removeSplitsRangeInMiddle: 去中间两个');
  t.equal(ShedText.remove('10-13', [10, 13]), '11 12',
    'removeSplitsRangeInMiddle: 剩两连号不收区间');

  // removeWholeRangeLeavesEmptyText
  t.equal(ShedText.remove('1-40', ShedCoverage.parseShedNumbers('1-40')), '',
    'removeWholeRangeLeavesEmptyText: 整段删空');

  // removeMixedParts
  t.equal(ShedText.remove('1-10、25、30-40', [5, 25]), '1-4 6-10 30-40',
    'removeMixedParts: 混合段');

  // removeKeepsTextWhenNothingRemoved
  t.equal(ShedText.remove('20-30，5 9', [88]), '20-30，5 9',
    'removeKeepsTextWhenNothingRemoved: 一个都没删到，原样');
  t.equal(ShedText.remove('20-30、5、7', [5]), '20-30 7',
    'removeKeepsTextWhenNothingRemoved: 删到 5 后按空格重排');

  // removeHandlesMixedSeparators
  t.equal(ShedText.remove('5,7 9', [7]), '5 9',
    'removeHandlesMixedSeparators: 混合分隔符');

  // removeHandlesChineseRangeChars
  t.equal(ShedText.remove('1到10', [5]), '1-4 6-10',
    'removeHandlesChineseRangeChars: 1到10');
  t.equal(ShedText.remove('1～10', [5]), '1-4 6-10',
    'removeHandlesChineseRangeChars: 1～10');

  // ==================== ShedTransferTest.java ====================

  // transferMovesNumberInsideTargetSpanButNotInTargetSet
  const r1 = runTransfer(['36-40', '26-35 39-40'], 0, 1, [37]);
  t.equal(r1[0], '36 38', 'transferMovesNumberInsideTargetSpanButNotInTargetSet: rows[0]');
  t.equal(r1[1], '26-35 37 39 40', 'transferMovesNumberInsideTargetSpanButNotInTargetSet: rows[1]');
  const c1 = ShedCoverage.ownedCounts(r1);
  t.equal(c1[0], 2, 'transferMovesNumberInsideTargetSpanButNotInTargetSet: counts[0]');
  t.equal(c1[1], 13, 'transferMovesNumberInsideTargetSpanButNotInTargetSet: counts[1]');

  // transferOfAlreadyOwnedNumberOnlyCleansSourceText
  const r2 = runTransfer(['1-40', '20-30'], 0, 1, [25]);
  t.equal(r2[0], '1-19 31-40', 'transferOfAlreadyOwnedNumberOnlyCleansSourceText: rows[0]');
  t.equal(r2[1], '20-30', 'transferOfAlreadyOwnedNumberOnlyCleansSourceText: rows[1]');
  const c2 = ShedCoverage.ownedCounts(r2);
  t.equal(c2[0], 29, 'transferOfAlreadyOwnedNumberOnlyCleansSourceText: counts[0]');
  t.equal(c2[1], 11, 'transferOfAlreadyOwnedNumberOnlyCleansSourceText: counts[1]');

  // phantomNumbersGetCleanedOnTransfer
  const r3 = runTransfer(['1-25 36-38', '', '36-38'], 0, 1, [36, 37, 38]);
  t.equal(r3[0], '1-25', 'phantomNumbersGetCleanedOnTransfer: rows[0]');
  t.equal(r3[1], '', 'phantomNumbersGetCleanedOnTransfer: rows[1]');
  t.equal(r3[2], '36-38', 'phantomNumbersGetCleanedOnTransfer: rows[2]');
  const c3 = ShedCoverage.ownedCounts(r3);
  t.equal(c3[0], 25, 'phantomNumbersGetCleanedOnTransfer: counts[0]');
  t.equal(c3[1], 0, 'phantomNumbersGetCleanedOnTransfer: counts[1]');
  t.equal(c3[2], 3, 'phantomNumbersGetCleanedOnTransfer: counts[2]');

  // transferBackAndForthWorks
  let r4 = runTransfer(['1-40', ''], 0, 1, [5]);
  t.equal(r4[0], '1-4 6-40', 'transferBackAndForthWorks: 第一次 rows[0]');
  t.equal(r4[1], '5', 'transferBackAndForthWorks: 第一次 rows[1]');
  r4 = runTransfer(r4, 1, 0, [5]);
  t.equal(r4[0], '1-40', 'transferBackAndForthWorks: 转回 rows[0]');
  t.equal(r4[1], '', 'transferBackAndForthWorks: 转回 rows[1]');
  const c4 = ShedCoverage.ownedCounts(r4);
  t.equal(c4[0], 40, 'transferBackAndForthWorks: counts[0]');
  t.equal(c4[1], 0, 'transferBackAndForthWorks: counts[1]');

  // transferUpReallyMoves
  const r5 = runTransfer(['1-40', '41-60', '25'], 2, 0, [25]);
  t.equal(r5[0], '1-40', 'transferUpReallyMoves: rows[0]');
  t.equal(r5[1], '41-60', 'transferUpReallyMoves: rows[1]');
  t.equal(r5[2], '', 'transferUpReallyMoves: rows[2]');
  const c5 = ShedCoverage.ownedCounts(r5);
  t.equal(c5[0], 40, 'transferUpReallyMoves: counts[0]');
  t.equal(c5[1], 20, 'transferUpReallyMoves: counts[1]');
  t.equal(c5[2], 0, 'transferUpReallyMoves: counts[2]');

  // transferBatchToEmptyRow
  const r6 = runTransfer(['1-40', ''], 0, 1, [3, 4, 5]);
  t.equal(r6[0], '1 2 6-40', 'transferBatchToEmptyRow: rows[0]');
  t.equal(r6[1], '3-5', 'transferBatchToEmptyRow: rows[1]');
  const c6 = ShedCoverage.ownedCounts(r6);
  t.equal(c6[0], 37, 'transferBatchToEmptyRow: counts[0]');
  t.equal(c6[1], 3, 'transferBatchToEmptyRow: counts[1]');

  // deleteStillSplitsRangeAndShrinksCount
  const after = ShedText.remove('1 3 5 7 8-40', [20]);
  t.equal(after, '1 3 5 7 8-19 21-40', 'deleteStillSplitsRangeAndShrinksCount: after');
  t.equal(ShedCoverage.parseShedNumbers(after).length, 36,
    'deleteStillSplitsRangeAndShrinksCount: parse 后棚数');
}
