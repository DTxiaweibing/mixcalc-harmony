import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { applyHomeBars, applyLightBars, toVp } from '../common/WindowChrome';

@Entry
@Component
struct WebPage {
  @State pageSrc: string = '';
  // 边到边：网页内容不能钻到状态栏 / 导航条底下（由 WindowChrome 写入 AppStorage）
  @StorageProp('insetTopPx') insetTopPx: number = 0;
  @StorageProp('insetBottomPx') insetBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== undefined && params !== null) {
      const route = params['route'] as string;
      const lang = params['lang'] as string;
      this.pageSrc = 'resource://rawfile/' + this.resolveRoute(route, lang);
    }
    // 与安卓 AssetWebViewActivity 一致：白底状态栏/导航栏 + 深色图标
    this.applyLightSystemBars();
  }

  // 英文环境优先用 rawfile/en 下的同名页，没有就退回中文（照搬安卓 resolveAssetPath）
  private resolveRoute(route: string, lang: string): string {
    if (lang !== 'en' || route === undefined || route.length === 0) {
      return route;
    }
    const enRoute: string = 'en/' + route;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      // 只探测文件是否存在，不解析内容
      ctx.resourceManager.getRawFileContentSync(enRoute);
      return enRoute;
    } catch (e) {
      return route;
    }
  }

  aboutToDisappear(): void {
    this.restoreSystemBars();
  }

  private applyLightSystemBars(): void {
    window.getLastWindow(getContext(this)).then((win) => {
      applyLightBars(win);
    }).catch((err: Error) => {
      console.error('setWindowSystemBarProperties failed: ' + err.message);
    });
  }

  private restoreSystemBars(): void {
    window.getLastWindow(getContext(this)).then((win) => {
      applyHomeBars(win);
    }).catch((err: Error) => {
      console.error('restoreSystemBarProperties failed: ' + err.message);
    });
  }

  build() {
    Column() {
      Web({ src: this.pageSrc, controller: this.controller })
        .width('100%')
        .height('100%')
        .darkMode(WebDarkMode.Off)
    }
    .width('100%')
    .height('100%')
    // 边到边：网页内容留在状态栏 / 导航条之间，留出来的 padding 是白底，
    // 和系统栏（白底黑字）连成一片，不会出现「第一行被状态栏吃掉」。
    .padding({
      top: toVp(this.getUIContext(), this.insetTopPx),
      bottom: toVp(this.getUIContext(), this.insetBottomPx)
    })
    .backgroundColor(Color.White)
  }
}