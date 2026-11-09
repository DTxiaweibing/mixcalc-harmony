/**
 * RowSettlement 失焦结算回归：
 *  - 直译 Android 侧 RowSettlementTest（4 条，测 settleZeroRowData）
 *  - 直译 Android 侧 RowSettlementRecycleTest（8 条，测 recycleDeadRows）
 *  - settleRows：先回收再兜底清、底部补空行后的行数守恒
 *
 * 造行一律 `new FeedData()` + 直接赋值字段，不依赖 setShedNumber 的解析副作用。
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

const { FeedData } = loadModel('FeedData');
const { settleZeroRowData, recycleDeadRows, settleRows, RowSettleResult } = loadModel('RowSettlement');

/** 被后面行覆盖、有效棚数为 0 但仍留有料/派生值的行（对应 zeroRowWithData）。 */
function zeroRowWithData() {
  const d = new FeedData();
  d.shedNumber = '1-10';
  d.shedCount = 0;
  d.average = 5;
  d.fermented = 1;
  d.powder = 2;
  d.feed03 = 3;
  d.feed05 = 4;
  d.feed10 = 5;
  d.water = 6;
  d.weighed = 7;
  d.switchRatio = 0.5;
  d.isAverageManuallyModified = true;
  return d;
}

/** 回收用例的造行助手：shedNumber / shedCount(缓存) / average 直接赋值。 */
function row(shedNumber, shedCount, average) {
  const d = new FeedData();
  d.shedNumber = shedNumber;
  d.shedCount = shedCount;
  d.average = average;
  return d;
}

export default function run(t) {
  // ==================== RowSettlementTest（settleZeroRowData）4 条 ====================

  // 1. clearsFeedAndDerivedButKeepsShedNumber
  {
    const d = zeroRowWithData();
    const rows = [d];
    t.equal(settleZeroRowData(rows), true, 'settle: 有数据的 0 棚行被清并返回 true');
    t.equal(d.shedNumber, '1-10', 'settle: 棚号文本保留');
    t.equal(d.shedCount, 0, 'settle: 棚数仍是 0');
    t.equal(d.average, 0, 'settle: average 清 0');
    t.equal(d.fermented, 0, 'settle: fermented 清 0');
    t.equal(d.powder, 0, 'settle: powder 清 0');
    t.equal(d.feed03, 0, 'settle: feed03 清 0');
    t.equal(d.feed05, 0, 'settle: feed05 清 0');
    t.equal(d.feed10, 0, 'settle: feed10 清 0');
    t.equal(d.water, 0, 'settle: water 清 0');
    t.equal(d.weighed, 0, 'settle: weighed 清 0');
    t.equal(d.switchRatio, 0, 'settle: switchRatio 清 0');
    t.equal(d.isAverageManuallyModified, false, 'settle: 手动标记复位');
  }

  // 2. keepsRowsThatStillOwnSheds
  {
    const d = zeroRowWithData();
    d.shedCount = 10;
    const rows = [d];
    t.equal(settleZeroRowData(rows), false, 'settle: 仍有棚数的行不动，返回 false');
    t.equal(d.shedCount, 10, 'settle: 棚数保持 10');
    t.equal(d.average, 5, 'settle: average 保持 5');
    t.equal(d.powder, 2, 'settle: powder 保持 2');
  }

  // 3. ignoresEmptyRowsAndNulls
  // ArkTS 无 null；等价覆盖为「纯空行」「空列表」都不触发清理。
  {
    const rows = [new FeedData()];
    t.equal(settleZeroRowData(rows), false, 'settle: 纯空行不动');
    t.equal(settleZeroRowData([]), false, 'settle: 空列表不动');
  }

  // 4. settlesOnlyTheZeroRowsInAMixedList
  {
    const zero = zeroRowWithData();
    const filled = zeroRowWithData();
    filled.shedCount = 10;
    const rows = [zero, filled];
    t.equal(settleZeroRowData(rows), true, 'settle: 混合列表有 0 棚行被清，返回 true');
    t.equal(zero.powder, 0, 'settle: 0 棚行的 powder 被清');
    t.equal(filled.powder, 2, 'settle: 有棚行的 powder 保留');
  }

  // ==================== RowSettlementRecycleTest（recycleDeadRows）8 条 ====================

  // 1. removesDeadRowAndShiftsBelow
  {
    const rows = [
      row('41-60', 20, 10),
      row('1-40', 0, 0),
      row('', 0, 0),
      row('1-40', 40, 5)
    ];
    const removed = recycleDeadRows(rows, []);
    t.equal(removed.length, 1, 'recycle: 回收 1 个死行');
    t.equal(removed[0], 1, 'recycle: 死行下标是 1');
    t.equal(rows.length, 3, 'recycle: 删后剩 3 行');
    t.equal(rows[0].shedNumber, '41-60', 'recycle: 第 0 行 41-60');
    t.equal(rows[1].shedNumber, '', 'recycle: 第 1 行是原纯空行');
    t.equal(rows[2].shedNumber, '1-40', 'recycle: 下面行上顶为 1-40');
  }

  // 2. keepsAliveRowsAndPureEmptyRows
  {
    const rows = [
      row('1-40', 40, 5),
      row('', 0, 0),
      row('', 0, 12),
      row('41-60', 20, 0)
    ];
    const removed = recycleDeadRows(rows, []);
    t.equal(removed.length, 1, 'recycle: 只回收「只有数据没棚号」的脏行');
    t.equal(removed[0], 2, 'recycle: 脏行下标是 2');
    t.equal(rows.length, 3, 'recycle: 删后剩 3 行');
    t.equal(rows[0].shedNumber, '1-40', 'recycle: 活行保留');
    t.equal(rows[1].shedNumber, '', 'recycle: 纯空行保留');
    t.equal(rows[2].shedNumber, '41-60', 'recycle: 末行 41-60');
  }

  // 3. multipleDeadRowsRemovedTogether
  {
    const rows = [
      row('1-10', 10, 5),
      row('1-10', 10, 0),
      row('20-30', 11, 5),
      row('20-30', 11, 0),
      row('', 0, 0)
    ];
    const removed = recycleDeadRows(rows, []);
    t.equal(removed.length, 2, 'recycle: 两处死行一次全删');
    t.equal(removed[0], 0, 'recycle: 升序下标第 1 个是 0');
    t.equal(removed[1], 2, 'recycle: 升序下标第 2 个是 2');
    t.equal(rows.length, 3, 'recycle: 删后剩 3 行');
    t.equal(rows[0].shedNumber, '1-10', 'recycle: 留下的 1-10');
    t.equal(rows[1].shedNumber, '20-30', 'recycle: 留下的 20-30');
    t.equal(rows[2].shedNumber, '', 'recycle: 纯空行保留在末尾');
  }

  // 4. threeCoveredRowsRemovedInOnePass（核心回归：缓存故意滞后，按文本重算一次删完）
  {
    const rows = [
      row('1-40', 40, 5),
      row('1-40', 40, 5),
      row('1-40', 40, 5),
      row('1-40', 40, 5)
    ];
    const removed = recycleDeadRows(rows, []);
    t.equal(removed.length, 3, 'recycle: 三行被同一行覆盖，缓存滞后也一次删 3 行');
    t.equal(rows.length, 1, 'recycle: 只剩最后一行');
    t.equal(rows[0].shedNumber, '1-40', 'recycle: 留下的是最后那行 1-40');
  }

  // 5. allEmptyListUntouched
  {
    const rows = [];
    for (let i = 0; i < 5; i++) {
      rows.push(row('', 0, 0));
    }
    t.equal(recycleDeadRows(rows, []).length, 0, 'recycle: 全空表一行都不删');
    t.equal(rows.length, 5, 'recycle: 全空表仍是 5 行');
  }

  // 6. rowEmptiedByDeletingAllShedsIsRecycledAndBelowShiftsUp
  {
    const rows = [
      row('41-60', 20, 10),
      row('', 0, 0),
      row('61-80', 20, 8)
    ];
    const removed = recycleDeadRows(rows, [1]);
    t.equal(removed.length, 1, 'recycle: 被用户删空的行被强制回收');
    t.equal(removed[0], 1, 'recycle: 回收下标是 1');
    t.equal(rows.length, 2, 'recycle: 删后剩 2 行');
    t.equal(rows[0].shedNumber, '41-60', 'recycle: 第 0 行 41-60');
    t.equal(rows[1].shedNumber, '61-80', 'recycle: 下面行上顶为 61-80');
  }

  // 7. pureEmptyRowStaysWhenNothingWasEmptied
  {
    const rows = [
      row('41-60', 20, 10),
      row('', 0, 0),
      row('61-80', 20, 8)
    ];
    t.equal(recycleDeadRows(rows, []).length, 0, 'recycle: 不是本次删空的纯空行不回收');
    t.equal(rows.length, 3, 'recycle: 仍是 3 行');
  }

  // 8. emptiedSetIgnoredWhenRowStillHasSheds
  {
    const rows = [
      row('41-60', 20, 10),
      row('1-3', 3, 5)
    ];
    t.equal(recycleDeadRows(rows, [1]).length, 0, 'recycle: 下标塞错、这行还有棚数，不许删活行');
    t.equal(rows.length, 2, 'recycle: 仍是 2 行');
  }

  // ==================== settleRows：补空行后行数守恒 ====================
  {
    const rows = [
      row('41-60', 20, 0),
      row('1-40', 0, 0),
      row('', 0, 0),
      row('1-40', 40, 0)
    ];
    const total = rows.length;
    const result = settleRows(rows, []);
    t.equal(result instanceof RowSettleResult, true, 'settleRows: 返回 RowSettleResult 实例');
    t.equal(result.removed.length, 1, 'settleRows: 回收了 1 行');
    t.equal(result.removed[0], 1, 'settleRows: 回收下标 1');
    t.equal(result.changed, true, 'settleRows: changed 为 true');
    t.equal(rows.length, total, 'settleRows: 补空行后行数回到原值');
    const last = rows[rows.length - 1];
    t.equal(last instanceof FeedData, true, 'settleRows: 末尾是 FeedData 实例');
    t.equal(last.shedNumber, '', 'settleRows: 末尾新空行棚号为空');
    t.equal(last.shedCount, 0, 'settleRows: 末尾新空行棚数为 0');
    t.equal(last.average, 0, 'settleRows: 末尾新空行 average 为 0');
    t.equal(last.fermented, 0, 'settleRows: 末尾新空行 fermented 为 0');
    t.equal(last.powder, 0, 'settleRows: 末尾新空行 powder 为 0');
    t.equal(last.feed03, 0, 'settleRows: 末尾新空行 feed03 为 0');
    t.equal(last.feed05, 0, 'settleRows: 末尾新空行 feed05 为 0');
    t.equal(last.feed10, 0, 'settleRows: 末尾新空行 feed10 为 0');
    t.equal(last.water, 0, 'settleRows: 末尾新空行 water 为 0');
    t.equal(last.weighed, 0, 'settleRows: 末尾新空行 weighed 为 0');
    t.equal(last.switchRatio, 0, 'settleRows: 末尾新空行 switchRatio 为 0');
    t.equal(last.isAverageManuallyModified, false, 'settleRows: 末尾新空行手动标记为 false');
  }
}
