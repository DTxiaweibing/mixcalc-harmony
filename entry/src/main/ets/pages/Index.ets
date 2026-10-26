import { MixCalcTable } from '../table/MixCalcTable';
import { FeedData } from '../model/FeedData';

@Entry
@Component
struct Index {
  private rows: FeedData[] = [];

  aboutToAppear(): void {
    let demo: string[] = ['1-5', '6-8', '9-12', '13-15', '16-20'];
    for (let i = 0; i < 30; i++) {
      let row: FeedData = new FeedData();
      if (i < demo.length) {
        row.shedNumber = demo[i];
        row.fermented = 120 + i * 10;
        row.powder = 60 + i * 5;
        row.feed03 = 30 + i * 2;
        row.feed05 = 25 + i;
        row.feed10 = 20 + i;
      }
      row.updateAllCalculations(20, false, false);
      this.rows.push(row);
    }
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text('☰')
            .fontSize(22)
            .fontColor(Color.White)
            .onClick(() => {
            })
        }
        .width('20%')
        .padding({ left: 10 })
        .justifyContent(FlexAlign.Start)

        Text($r('app.string.title_main'))
          .fontSize(20)
          .fontColor(Color.White)
          .width('60%')
          .textAlign(TextAlign.Center)

        Text('')
          .fontSize(14)
          .fontColor(Color.White)
          .width('20%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(40)
      .backgroundColor($r('app.color.title_bar_bg'))

      MixCalcTable({ rows: this.rows })
        .layoutWeight(1)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}