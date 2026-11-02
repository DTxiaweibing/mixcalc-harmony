import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct WebPage {
  @State pageSrc: string = '';
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
      win.setWindowSystemBarProperties({
        statusBarColor: '#FFFFFF',
        statusBarContentColor: '#000000',
        navigationBarColor: '#FFFFFF',
        navigationBarContentColor: '#000000'
      });
    }).catch((err: Error) => {
      console.error('setWindowSystemBarProperties failed: ' + err.message);
    });
  }

  private restoreSystemBars(): void {
    window.getLastWindow(getContext(this)).then((win) => {
      win.setWindowSystemBarProperties({
        statusBarColor: '#1F6B30',
        statusBarContentColor: '#FFFFFF',
        navigationBarColor: '#FFFFFF',
        navigationBarContentColor: '#000000'
      });
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
    .backgroundColor(Color.White)
  }
}