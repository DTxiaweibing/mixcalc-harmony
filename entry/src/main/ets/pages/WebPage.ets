import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

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