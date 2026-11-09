/**
 * ShedCoverage.renormalize 模型测试（直译 ShedCoverageRenormalizeTest.java 全部用例）。
 *
 * 规则：一行文本里的号码被后面的行占走后，文本重写成它真正拥有的号码，
 * 保证“看到的号码 = 参与算料的号码”；没被占走的行保留用户自己的写法。
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

export default function run(t) {
  const coverage = loadModel('ShedCoverage');
  const renormalize = coverage.renormalize;
  const ownedCounts = coverage.ownedCounts;

  // 1. prefixTakenByRowBelow：第 1 行 1-40、第 2 行 1-15 → 第 1 行变 16-40
  const prefix = renormalize(['1-40', '1-15']);
  t.equal(prefix, ['16-40', '1-15'], 'prefixTakenByRowBelow: 覆盖后文本');
  t.equal(ownedCounts(prefix), [25, 15], 'prefixTakenByRowBelow: 校正后 count 25/15');

  // 2. middleNumbersTakenSplitsRange：20-30 少了 25 → 20-24 26-30
  t.equal(renormalize(['20-30', '25']), ['20-24 26-30', '25'], 'middleNumbersTakenSplitsRange');

  // 3. scatteredTakesLeaveRanges
  t.equal(renormalize(['1-40', '1-15 20']), ['16-19 21-40', '1-15 20'], 'scatteredTakesLeaveRanges');

  // 4. untouchedRowKeepsItsOwnWriting：一个号都没被占走，格式原样保留，不重排成升序
  t.equal(renormalize(['24-40 1-20']), ['24-40 1-20'], 'untouchedRowKeepsItsOwnWriting: 24-40 1-20');
  t.equal(renormalize(['1 3 5 7 8-40']), ['1 3 5 7 8-40'], 'untouchedRowKeepsItsOwnWriting: 1 3 5 7 8-40');

  // 5. fullyCoveredRowKeepsText：整行被后行盖住（有效棚数 0），文本不动，交给行回收
  t.equal(renormalize(['1-40', '1-40']), ['1-40', '1-40'], 'fullyCoveredRowKeepsText');

  // 6. idempotent：renormalize(renormalize(x)) 与一次结果相同
  const once = renormalize(['1-40', '1-15']);
  const twice = renormalize(once);
  t.equal(twice, once, 'idempotent');

  // 7. blankRowsStayBlank：空串行原样留白（安卓版的 ["", null] 在 ArkTS 里即 ["", ""]）
  t.equal(renormalize(['', '']), ['', ''], 'blankRowsStayBlank');

  // 8. threeRowsHandOverInOrder：三行叠加，后行优先，前面两行按实际归属重写
  t.equal(renormalize(['1-40', '1-20', '1-5']), ['21-40', '6-20', '1-5'], 'threeRowsHandOverInOrder');
}
