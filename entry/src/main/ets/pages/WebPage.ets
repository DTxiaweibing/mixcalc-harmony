import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct WebPage {
  @State pageTitle: string = '';
  @State pageSrc: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params !== undefined && params !== null) {
      const route = params['route'] as string;
      const title = params['title'] as string;
      this.pageSrc = 'resource://rawfile/' + route;
      this.pageTitle = title;
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(Color.White)
          .width(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Text(this.pageTitle)
          .fontSize(18)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(44)
      }
      .width('100%')
      .height(40)
      .backgroundColor($r('app.color.title_bar_bg'))

      Web({ src: this.pageSrc, controller: this.controller })
        .width('100%')
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}