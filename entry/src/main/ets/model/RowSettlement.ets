import { FeedData } from './FeedData';
import { ownedCounts } from './ShedCoverage';

/**
 * 一次结算的结果：被回收的行下标（升序）、以及本次是否真的有变化。
 * 用显式类而非对象字面量，所有字段显式初始化。
 */
export class RowSettleResult {
  removed: number[] = [];
  changed: boolean = false;

  constructor() {
    this.removed = [];
    this.changed = false;
  }
}

/**
 * 失焦结算：棚数为 0 的行当“新的一行”处理。
 *
 * 只在用户真正离开编辑时调用（收起编辑、换格、切批次、退出页面、载入）；
 * 编辑途中只按显示规则把料列置灰、平均/水/称料留白，底层数据必须保留，
 * 这样棚数重新分回来时数据能立刻恢复显示。
 *
 * 棚号列不清：用户填过的棚号保留，只清料量、水和派生值。
 *
 * @returns 是否真的清掉了数据（没变化就不用触发重绘/落盘）
 */
export function settleZeroRowData(rows: FeedData[]): boolean {
  let changed: boolean = false;
  for (let i = 0; i < rows.length; i++) {
    const row: FeedData = rows[i];
    if (row.shedCount > 0 || !hasRowData(row)) {
      continue;
    }
    row.average = 0;
    row.fermented = 0;
    row.powder = 0;
    row.feed03 = 0;
    row.feed05 = 0;
    row.feed10 = 0;
    row.water = 0;
    row.weighed = 0;
    row.switchRatio = 0;
    row.isAverageManuallyModified = false;
    changed = true;
  }
  return changed;
}

/**
 * 行级销毁：有内容但有效棚数为 0 的行，整行从列表移除（连棚号文本一起），下面的行上移。
 *
 * 纯空行（没填过棚号也没填过数据）不算死行——那是留给用户继续录入的容量，绝不删。
 * 删除依据在清数据之前判断，所以“只有数据没有棚号”的历史脏行也能一并回收。
 *
 * 有效棚数一律按申明文本重算（后行优先），绝不读 row.shedCount 缓存：结算时机早于
 * 某些路径的刷新，缓存可能还没刷新，几行同时被下面一行覆盖时这一轮只认得一个死行，
 * 用户就会看到“一行一行往上进”。以文本为准，一次就能把该删的全认出来。
 *
 * @param emptiedByUser 本次被用户删空（棚号删到一点不剩）的行下标，这类行文本/数据都空，
 *                      按纯空行本应保留，但必须强制回收，否则表中间留洞、下面的行不上顶。
 * @returns 被移除行的下标（升序）；没删到返回空数组
 */
export function recycleDeadRows(rows: FeedData[], emptiedByUser: number[]): number[] {
  const texts: string[] = [];
  for (let i = 0; i < rows.length; i++) {
    // ArkTS 里 rows 元素不会是 null，shedNumber 默认就是空串，天然是“空串兜底”。
    texts.push(rows[i].shedNumber);
  }
  const owned: number[] = ownedCounts(texts);
  const dead: number[] = [];
  for (let i = 0; i < rows.length; i++) {
    if (owned[i] > 0) {
      continue;
    }
    const row: FeedData = rows[i];
    const hasContent: boolean = row.shedNumber.trim() !== '' || hasRowData(row);
    const emptied: boolean = emptiedByUser.indexOf(i) >= 0;
    if (hasContent || emptied) {
      dead.push(i);
    }
  }
  // 先记录升序下标，再从后往前删，避免前面的删除把后面的下标顶偏。
  for (let i = dead.length - 1; i >= 0; i--) {
    rows.splice(dead[i], 1);
  }
  return dead;
}

/**
 * 一次结算：先回收死行，再兜底清数据，最后底部补空行保持总行数守恒。
 * 顺序不能反：回收会把整行（含棚号）拿掉，兜底清只动留下的行。
 */
export function settleRows(rows: FeedData[], emptiedByUser: number[]): RowSettleResult {
  const total: number = rows.length;
  const removed: number[] = recycleDeadRows(rows, emptiedByUser);
  const cleared: boolean = settleZeroRowData(rows);
  const changed: boolean = cleared || removed.length > 0;
  // 回收删掉几行就补几个新空行，rows.length 回到 total。
  for (let i = rows.length; i < total; i++) {
    rows.push(new FeedData());
  }
  const result: RowSettleResult = new RowSettleResult();
  result.removed = removed;
  result.changed = changed;
  return result;
}

function hasRowData(row: FeedData): boolean {
  return row.average !== 0 || row.fermented !== 0 || row.powder !== 0
    || row.feed03 !== 0 || row.feed05 !== 0 || row.feed10 !== 0
    || row.water !== 0 || row.weighed !== 0
    || row.switchRatio !== 0 || row.isAverageManuallyModified;
}
