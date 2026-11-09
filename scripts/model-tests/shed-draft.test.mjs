/**
 * ShedDraft 模型测试：直译 ShedDraftTest.java 全部 5 组场景。
 * 逐字符敲入用循环模拟，对每个前缀断言整帧 texts + counts。
 * 中间帧 texts 依据任务 2 的 renormalize 规格推导：
 *   每行取 ownedSets，compressNumbers（连号 >=3 收区间、空格分隔、否则逐个写），
 *   否则返回原文；被整行覆盖时原样返回。
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

const model = loadModel('ShedDraft');
const recompute = model.recompute;

/** 逐字符敲入，返回每一步的实际结果（最后一帧即定稿）。 */
function typeCharByChar(snapshot, row, target) {
  const frames = [];
  for (let i = 1; i <= target.length; i++) {
    frames.push(recompute(snapshot, row, target.slice(0, i)));
  }
  return frames;
}

/** 对每个前缀（每一帧）断言 texts 与 counts。 */
function assertFrames(t, frames, expected, label) {
  for (let i = 0; i < expected.length; i++) {
    t.equal(frames[i].texts, expected[i].texts, `${label} 帧${i + 1} texts`);
    t.equal(frames[i].counts, expected[i].counts, `${label} 帧${i + 1} counts`);
  }
}

// 快照 ["1-40",""]，逐字符敲 "1-15" 的期望帧
const TYPING_1_15 = [
  { texts: ['2-40', '1'], counts: [39, 1] },
  { texts: ['2-40', '1-'], counts: [39, 1] },
  { texts: ['2-40', '1-1'], counts: [39, 1] },
  { texts: ['16-40', '1-15'], counts: [25, 15] }
];

// 快照 ["1-40",""]，逐字符敲 "16-40" 的期望帧
const TYPING_16_40 = [
  { texts: ['2-40', '1'], counts: [39, 1] },
  { texts: ['1-15 17-40', '16'], counts: [39, 1] },
  { texts: ['1-15 17-40', '16-'], counts: [39, 1] },
  { texts: ['1-3 17-40', '16-4'], counts: [27, 13] },
  { texts: ['1-15', '16-40'], counts: [15, 25] }
];

export default function run(t) {
  // 场景 1 typingWholeRangeKeepsOtherRowInSync：末帧 ["16-40","1-15"] counts 25/15
  const s1 = typeCharByChar(['1-40', ''], 1, '1-15');
  assertFrames(t, s1, TYPING_1_15, '场景1');
  const last1 = s1[s1.length - 1];
  t.equal(last1.texts[0], '16-40', '场景1 末帧首行');
  t.equal(last1.texts[1], '1-15', '场景1 末帧编辑行');
  t.equal(last1.counts[0], 25, '场景1 末帧首行棚数');
  t.equal(last1.counts[1], 15, '场景1 末帧编辑行棚数');

  // 场景 2 firstCharAlreadyShowsRemainderOfAboveRow：第一个 "1" → ["2-40","1"] counts 39/1
  const first = recompute(['1-40', ''], 1, '1');
  t.equal(first.texts, ['2-40', '1'], '场景2 texts');
  t.equal(first.counts, [39, 1], '场景2 counts');

  // 场景 3 halfTypedRangeDoesNotPermanentlyStealNumbers：16-4 半成品只影响当前帧
  const snapshot3 = ['1-40', ''];
  const s3 = typeCharByChar(snapshot3, 1, '16-40');
  assertFrames(t, s3, TYPING_16_40, '场景3');
  const half = recompute(snapshot3, 1, '16-4');
  t.equal(half.texts[0], '1-3 17-40', '场景3 半成品 16-4 首行');
  const last3 = s3[s3.length - 1];
  t.equal(last3.texts[0], '1-15', '场景3 末帧首行');
  t.equal(last3.texts[1], '16-40', '场景3 末帧编辑行');
  t.equal(last3.counts[0], 15, '场景3 末帧首行棚数');
  t.equal(last3.counts[1], 25, '场景3 末帧编辑行棚数');

  // 场景 4 editingRowAlwaysKeepsRawText：编辑行 "24-40 1-20" 原样保留
  const r4 = recompute(['1-40', ''], 1, '24-40 1-20');
  t.equal(r4.texts, ['21-23', '24-40 1-20'], '场景4 texts');
  t.equal(r4.counts, [3, 37], '场景4 counts');
  t.equal(r4.texts[1], '24-40 1-20', '场景4 编辑行原样');
  t.equal(r4.texts[0], '21-23', '场景4 首行');

  // 场景 5 clearingTypedTextGivesNumbersBackToAboveRow：清空即完全回到基线
  const snapshot5 = ['1-40', ''];
  const s5 = typeCharByChar(snapshot5, 1, '1-15');
  assertFrames(t, s5, TYPING_1_15, '场景5');
  const cleared = recompute(snapshot5, 1, '');
  t.equal(cleared.texts, ['1-40', ''], '场景5 清空 texts');
  t.equal(cleared.counts, [40, 0], '场景5 清空 counts');
  t.equal(s5[s5.length - 1].counts[0], 25, '场景5 清空前末帧首行棚数（与中间态无关）');
}
