import { FeedData } from './FeedData';

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

function hasRowData(row: FeedData): boolean {
  return row.average !== 0 || row.fermented !== 0 || row.powder !== 0
    || row.feed03 !== 0 || row.feed05 !== 0 || row.feed10 !== 0
    || row.water !== 0 || row.weighed !== 0
    || row.switchRatio !== 0 || row.isAverageManuallyModified;
}
