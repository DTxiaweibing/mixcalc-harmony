import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct WebPage {
  @State pageSrc: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== undefined && params !== null) {
      const route = params['route'] as string;
      this.pageSrc = 'resource://rawfile/' + route;
    }
    // 与安卓 AssetWebViewActivity 一致：白底状态栏/导航栏 + 深色图标
    this.applyLightSystemBars();
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