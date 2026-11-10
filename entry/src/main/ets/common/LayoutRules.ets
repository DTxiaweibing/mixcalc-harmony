// 布局判据（纯计算，不依赖 UI / 设备类型），对齐安卓 0.3.5 的 TabletLayout / PopupGeometry。
// 表格列宽和 Index 的「快捷设置」入口都用这里的同一套规则，避免两处各猜一次。

export const LAYOUT_COLUMN_IDS: string[] = [
  'seq', 'shed_number', 'shed_count', 'average_feed', 'fermented', 'powder',
  'feed03', 'feed05', 'feed10', 'water', 'weighed_feed'
];

// 手机布局的固定列宽（vp），合计 612：窗口宽度不到 612 时横向滚动
// 棚号列 72vp：与已发布安卓端 MixCalcActivity.columnWidths 完全一致（安卓 72dp / 合计 612dp）。
// 棚号展示字号也同步安卓 SHED_TEXT_SIZE_DP = 16，9 字符一行靠 72vp 容纳。
// 安卓已发布、鸿蒙未发布，故以安卓为基准；其余列保持 0.3.5 基线不变。
export const LAYOUT_WIDTHS: number[] = [40, 72, 40, 40, 60, 60, 60, 60, 60, 60, 60];

// 平板布局的最小窗口宽度（vp），与安卓 TABLET_MIN_WIDTH_DP 一致
export const TABLET_MIN_WIDTH: number = 600;

// 只看**当前窗口宽度**，不看设备类型：折叠屏折成外屏后设备没变，但窗口只有 370vp 左右
export function isTabletWidth(widthVp: number): boolean {
  return widthVp >= TABLET_MIN_WIDTH;
}

// 表格是否已经铺满全部列。满足时菜单不再提供「快捷设置」。
// 还有列被隐藏时必须返回 false，否则用户没有入口把列恢复回来。
export function fillsAllColumns(visible: boolean[], widthVp: number): boolean {
  if (visible.length === 0 || widthVp <= 0) {
    return false;
  }
  for (let i = 0; i < visible.length; i++) {
    if (!visible[i]) {
      return false;
    }
  }
  // 平板布局（>=600vp）会把可见列整体缩放到窗宽，全可见时必然铺满；
  // 手机布局是固定列宽总和（612vp），只有窗口宽到放得下才算铺满，否则还在横向滚动。
  let total: number = 0;
  for (let i = 0; i < LAYOUT_WIDTHS.length; i++) {
    total += LAYOUT_WIDTHS[i];
  }
  return total <= widthVp;
}

// 弹窗右边缘对齐被点的单元格，再夹进窗口（安卓 PopupGeometry.rightAlignedX）
export function rightAlignedX(cellRight: number, popupWidth: number, widthVp: number): number {
  if (widthVp <= 0) {
    return 0;
  }
  const maxX: number = Math.max(0, widthVp - popupWidth);
  return Math.max(0, Math.min(cellRight - popupWidth, maxX));
}
