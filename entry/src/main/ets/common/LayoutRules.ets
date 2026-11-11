// 布局判据（纯计算，不依赖 UI / 设备类型），对齐安卓 0.3.5 的 TabletLayout / PopupGeometry。
// 表格列宽和 Index 的「快捷设置」入口都用这里的同一套规则，避免两处各猜一次。

export const LAYOUT_COLUMN_IDS: string[] = [
  'seq', 'shed_number', 'shed_count', 'average_feed', 'fermented', 'powder',
  'feed03', 'feed05', 'feed10', 'water', 'weighed_feed'
];

// 手机布局的固定列宽（vp），合计 612：窗口宽度不到 612 时横向滚动
// 棚号列 72vp + 展示字号 15vp：云调试多机型复测，68vp 在部分手机上两行棚号显示异常，
// 放宽到 72vp 兼容（与已发布安卓 72dp 一致）；字号仍保持 15vp，不照搬安卓 16dp，
// 因为鸿蒙字体比安卓宽，16vp 时显示会出问题。其余列保持 0.3.5 基线不变。
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
  // 平板 / 宽窗口布局（>=600vp，含横屏平板）会把可见列整体缩放到窗宽，
  // 全可见时必然铺满，与固定列宽总和（612vp）无关。
  // 判据与 MixCalcTable.isTabletMode() 同源（同一个 isTabletWidth / TABLET_MIN_WIDTH），
  // 依据的是鸿蒙自身的缩放逻辑，不是照搬安卓的竖屏假设：鸿蒙横屏平板 >=600vp 走缩放，
  // 竖屏手机 <600vp 仍按固定列宽横向滚动。两端平台形态不同，这里只对齐鸿蒙自己。
  if (isTabletWidth(widthVp)) {
    return true;
  }
  // 手机布局：固定列宽总和 612vp，窗口放不下就还要横向滚动，入口必须留着。
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
