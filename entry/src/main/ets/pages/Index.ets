import { MixCalcTable } from '../table/MixCalcTable';
import { FeedData } from '../model/FeedData';

@Entry
@Component
struct Index {
  private rows: FeedData[] = [];
  private sheetW: number = 0;
  private sheetH: number = 0;

  aboutToAppear(): void {
    let demo: string[] = ['1-5', '6-8', '9-12', '13-15', '16-20'];
    for (let i = 0; i < 30; i++) {
      let row: FeedData = new FeedData();
      if (i < demo.length) {
        row.shedNumber = demo[i];
        row.shedCount = i === 0 ? 5 : 3;
        row.fermented = 20 + i;
        row.powder = 10 + i;
        row.feed03 = 5.5 + i;
        row.feed05 = 4.25;
        row.feed10 = 3.75;
        row.average = 43.5 + i;
        row.water = 8.7;
        row.weighed = 52.2 + i;
      }
      this.rows.push(row);
    }
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.title_main'))
          .fontSize(20)
          .fontColor(Color.White)
      }
      .width('100%')
      .height(40)
      .backgroundColor($r('app.color.title_bar_bg'))
      .justifyContent(FlexAlign.Center)

      MixCalcTable({ rows: this.rows })
        .layoutWeight(1)
        .width('100%')
        .onAreaChange((_o: Area, n: Area) => {
          this.sheetW = Number(n.width);
          this.sheetH = Number(n.height);
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}