// 窗口边到边（沉浸式）与系统栏的统一入口。
// 页面不直接调 window API：颜色、避让高度、AppStorage key 都只在这里维护一份，
// 避免 EntryAbility / Index / WebPage 三处各写一套常量走偏。
//
// 为什么用 padding 而不是 expandSafeArea：
// 标题栏（40vp）和表尾（行高）都是固定尺寸，expandSafeArea 只扩展绘制区域、
// 不移动布局内容，固定尺寸组件上等于没效果，内容照样会被系统栏压住。

import { window, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

// 与 resources/base/element/color.json 的 title_bar_bg 同色：
// 状态栏刷成同色，标题栏背景延伸上去才不会有第二条色带。
export const TITLE_BAR_COLOR: string = '#2D8C42';
// 与表尾 backgroundColor 同色：导航栏刷成同色，表尾背景才能一直画到屏幕底边。
export const TABLE_BOTTOM_COLOR: string = '#EAF3EC';

// 避让高度（px）：窗口变化时由 avoidAreaChange 刷新，页面 px2vp 后当 padding 用。
export const INSET_TOP_KEY: string = 'insetTopPx';
export const INSET_BOTTOM_KEY: string = 'insetBottomPx';

let avoidBound: boolean = false;

// 避让高度以 px 存储，布局统一换成 vp；两个页面共用，避免各写一份换算
export function toVp(ctx: UIContext, px: number): number {
  return px > 0 ? ctx.px2vp(px) : 0;
}

function avoidHeight(win: window.Window, type: window.AvoidAreaType, top: boolean): number {
  try {
    const area: window.AvoidArea = win.getWindowAvoidArea(type);
    const rect: window.Rect = top ? area.topRect : area.bottomRect;
    return rect.height > 0 ? rect.height : 0;
  } catch (e) {
    console.error('getWindowAvoidArea failed, type=' + type);
    return 0;
  }
}

// 状态栏高度 + 底部避让：三键导航走 TYPE_SYSTEM，手势条走 TYPE_NAVIGATION_INDICATOR，
// 两种导航方式同时只会有一种生效，取大的那个即可。
export function syncInsets(win: window.Window): void {
  const top: number = avoidHeight(win, window.AvoidAreaType.TYPE_SYSTEM, true);
  const sysBottom: number = avoidHeight(win, window.AvoidAreaType.TYPE_SYSTEM, false);
  const indicator: number = avoidHeight(win, window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR, false);
  AppStorage.setOrCreate(INSET_TOP_KEY, top);
  AppStorage.setOrCreate(INSET_BOTTOM_KEY, Math.max(sysBottom, indicator));
}

export function setupImmersive(win: window.Window): void {
  win.setWindowLayoutFullScreen(true).then(() => {
    syncInsets(win);
  }).catch((e: BusinessError) => {
    console.error('setWindowLayoutFullScreen failed: ' + e.code);
  });
  // 转屏 / 折叠 / 分屏都会重发 avoidAreaChange；只注册一次，重复调用 setup 不会叠加监听
  if (avoidBound) {
    return;
  }
  avoidBound = true;
  win.on('avoidAreaChange', () => {
    syncInsets(win);
  });
}

// 首页系统栏：状态栏跟标题栏同色，导航栏跟表尾同色
export function applyHomeBars(win: window.Window): void {
  win.setWindowSystemBarProperties({
    statusBarColor: TITLE_BAR_COLOR,
    statusBarContentColor: '#FFFFFF',
    navigationBarColor: TABLE_BOTTOM_COLOR,
    navigationBarContentColor: '#000000'
  }).catch((e: BusinessError) => {
    console.error('setWindowSystemBarProperties failed: ' + e.code);
  });
}

// 网页页（帮助 / 隐私 / 协议）：白底黑字，和网页白底连成一片
export function applyLightBars(win: window.Window): void {
  win.setWindowSystemBarProperties({
    statusBarColor: '#FFFFFF',
    statusBarContentColor: '#000000',
    navigationBarColor: '#FFFFFF',
    navigationBarContentColor: '#000000'
  }).catch((e: BusinessError) => {
    console.error('setWindowSystemBarProperties failed: ' + e.code);
  });
}
