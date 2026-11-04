// 窗口边到边（沉浸式）与系统栏的统一入口。
// 页面不直接调 window API：颜色、避让高度、AppStorage key 都只在这里维护一份，
// 避免 EntryAbility / Index / WebPage 三处各写一套常量走偏。
//
// 为什么用 padding 而不是 expandSafeArea：
// 标题栏（40vp）和表尾（行高）都是固定尺寸，expandSafeArea 只扩展绘制区域、
// 不移动布局内容，固定尺寸组件上等于没效果，内容照样会被系统栏压住。

import { window, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

// 状态栏区域专用深绿：与安卓一致（状态栏 #1F6B30 + 标题栏 #2D8C42 两条色带）。
// 注意这块颜色是我们自己画在标题栏顶部的（系统状态栏是透明的），不是推给系统的。
export const STATUS_BAR_COLOR: string = '#1F6B30';
// 与单元格同色（未填棚数时的灰 `#F0F0F0`）：底部装饰条铺到屏幕底边，导航条区域也是这个灰，
// 不再是表尾的浅绿，避免底部多出一条绿色带。
export const TABLE_BOTTOM_COLOR: string = '#F0F0F0';

// 避让高度（px）：窗口变化时由 avoidAreaChange 刷新，页面 px2vp 后当 padding 用。
export const INSET_TOP_KEY: string = 'insetTopPx';
export const INSET_BOTTOM_KEY: string = 'insetBottomPx';

let listenersBound: boolean = false;
// 当前是否由应用接管系统栏（沉浸式）。分屏 / 悬浮窗下交还系统，见 applyWindowMode()。
let immersiveOn: boolean = true;
// 最近一次页面要求的系统栏样式：false = 首页（白图标），true = 网页页（黑图标）。
// 图标颜色要跟着页面走，也要跟着窗口模式走（分屏 / 悬浮窗用系统默认白图标）。
let lightBars: boolean = false;

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
  // 分屏 / 悬浮窗：窗口不铺满整屏，系统栏不在窗口坐标里。
  // 这时 topRect 报的是系统「三点控制栏」高度，照着加 padding 会在窗口顶部多画一条应用色，
  // 把本该露出壁纸 / 系统控制栏的位置盖住，所以两个避让高度一律归零。
  if (!immersiveOn) {
    AppStorage.setOrCreate(INSET_TOP_KEY, 0);
    AppStorage.setOrCreate(INSET_BOTTOM_KEY, 0);
    return;
  }
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
  if (listenersBound) {
    return;
  }
  listenersBound = true;
  win.on('avoidAreaChange', () => {
    syncInsets(win);
  });
  // 进 / 出分屏、悬浮窗、全屏时切换沉浸式：系统栏该归谁控制由窗口模式决定
  win.on('windowStatusChange', (status: window.WindowStatusType) => {
    applyWindowMode(win, status);
  });
  // 兜底：个别版本进小窗只发尺寸变化不发 windowStatusChange，尺寸一变就再读一次模式
  win.on('windowSizeChange', () => {
    syncWindowMode(win);
  });
}

// 启动兜底：系统可能直接恢复上次的分屏 / 悬浮窗状态，读一次当前模式把系统栏交还系统。
// 只在 loadContent 之后 / maximize 之后调用，窗口建好前 getWindowStatus() 可能是 UNDEFINED。
export function syncWindowMode(win: window.Window): void {
  let status: window.WindowStatusType = window.WindowStatusType.UNDEFINED;
  try {
    status = win.getWindowStatus();
  } catch (e) {
    console.error('getWindowStatus failed');
    return;
  }
  applyWindowMode(win, status);
}

// 分屏 / 悬浮窗下状态栏由系统绘制，应用着色不生效（微信读书、小艺小窗同样如此），
// 安卓的自由窗口会用焦点窗口的 statusBarColor，所以那边是绿的——平台差异，不是本项目的 bug。
// 这里的处理是主动退出沉浸式，让窗口顶部整个交还系统。
function applyWindowMode(win: window.Window, status: window.WindowStatusType): void {
  const immersive: boolean = !systemOwnsBars(status);
  if (immersive === immersiveOn) {
    return;
  }
  immersiveOn = immersive;
  win.setWindowLayoutFullScreen(immersive).then(() => {
    syncInsets(win);
  }).catch((e: BusinessError) => {
    console.error('setWindowLayoutFullScreen(' + immersive + ') failed: ' + e.code);
  });
  // 按当前模式重设系统栏：非全屏刷透明交还系统，回到全屏补回当前页面要求的样式
  paintBars(win);
  syncInsets(win);
}

function systemOwnsBars(status: window.WindowStatusType): boolean {
  return status === window.WindowStatusType.SPLIT_SCREEN || status === window.WindowStatusType.FLOATING;
}

// 首页：状态栏图标白色（压在标题栏绿上），导航条图标黑色（压在表尾浅绿上）
export function applyHomeBars(win: window.Window): void {
  lightBars = false;
  paintBars(win);
}

// 网页页（帮助 / 隐私 / 协议）：白底黑字，图标黑色
export function applyLightBars(win: window.Window): void {
  lightBars = true;
  paintBars(win);
}

// 系统栏颜色一律透明：绿色 / 白色由我们自己的标题栏、表尾、网页白底画在系统栏下面。
//
// 为什么不用实色（原来 statusBarColor = #2D8C42）：
// 只要颜色推给系统，它就一直跟着窗口走。上滑进小窗时窗口是渐变的，
// 而 windowStatusChange 要等手势结束才来，这中间状态栏一直是我们的绿，
// 松手后才变回壁纸——看起来就是「还晚了」。
// 透明的话每一帧都由窗口自己的内容决定：窗口一离开状态栏区域，状态栏立刻透出壁纸。
//
// 分屏 / 悬浮窗下额外把图标（内容）颜色换回白色，和桌面状态栏默认样式一致。
const HOME_BARS: window.SystemBarProperties = {
  statusBarColor: '#00000000',
  statusBarContentColor: '#FFFFFF',
  navigationBarColor: '#00000000',
  navigationBarContentColor: '#000000'
};

const LIGHT_BARS: window.SystemBarProperties = {
  statusBarColor: '#00000000',
  statusBarContentColor: '#000000',
  navigationBarColor: '#00000000',
  navigationBarContentColor: '#000000'
};

const SYSTEM_BARS: window.SystemBarProperties = {
  statusBarColor: '#00000000',
  statusBarContentColor: '#FFFFFF',
  navigationBarColor: '#00000000',
  navigationBarContentColor: '#FFFFFF'
};

function paintBars(win: window.Window): void {
  // 样式记在 lightBars 里：分屏 / 悬浮窗用系统默认图标色，全屏用当前页面对应的图标色
  let props: window.SystemBarProperties = SYSTEM_BARS;
  if (immersiveOn) {
    props = lightBars ? LIGHT_BARS : HOME_BARS;
  }
  win.setWindowSystemBarProperties(props).catch((e: BusinessError) => {
    console.error('setWindowSystemBarProperties failed: ' + e.code);
  });
}
