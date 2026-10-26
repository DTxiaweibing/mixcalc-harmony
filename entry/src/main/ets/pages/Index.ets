import { MixCalcTable } from '../table/MixCalcTable';
import { FeedData } from '../model/FeedData';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

const PREF_NAME: string = 'MixCalcPrefs';
const KEY_DATA: string = 'saved_data';
const ROW_COUNT: number = 30;

const HELP_TEXT: string = '一、填表\n' +
  '1. 第一行填总棚号（如 1-40），棚数自动算出。\n' +
  '2. 第二行起填细分棚号（如 1-5、6-8），第一行棚数会自动扣减后续各行之和。\n' +
  '3. 棚号清空 → 该行数据全部清零；棚号保留、棚数改 0 → 只清料，保留棚号。\n\n' +
  '二、计算\n' +
  '平均 =（粉料 + 0.3料 + 0.5料 + 1.0料[ + 发酵料]）÷ 棚数\n' +
  '水 =（同上合计）× 水比\n' +
  '称料 =（料合计 + 水 + 发酵料）÷ 棚数\n\n' +
  '三、编辑\n' +
  '点单元格弹出输入框，确定后自动重算；平均在料种不超过两种时可手改，改后按棚数反推料量。\n\n' +
  '四、表尾\n' +
  '左侧显示已填行数/总行数；「帮助」看本说明；「重置」清空当前表（需二次确认）。';

@CustomDialog
struct HelpDialog {
  controller?: CustomDialogController;

  build() {
    Column() {
      Text('使用帮助')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 8 })

      Scroll() {
        Text(HELP_TEXT)
          .fontSize(14)
          .lineHeight(23)
          .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)

      Button('关闭')
        .width('86%')
        .height(42)
        .backgroundColor('#2D8C42')
        .fontColor(Color.White)
        .margin({ top: 12, bottom: 16 })
        .onClick(() => {
          this.controller?.close();
        })
    }
    .width('88%')
    .height('72%')
    .backgroundColor(Color.White)
    .borderRadius(12)
  }
}
@Entry
@Component
struct Index {
  private rows: FeedData[] = [];
  @State ready: boolean = false;
  private store: preferences.Preferences | null = null;
  private helpController: CustomDialogController = new CustomDialogController({
    builder: HelpDialog(),
    autoCancel: true,
    customStyle: true
  });

  async aboutToAppear(): Promise<void> {
    await this.loadRows();
    this.ready = true;
  }

  private async loadRows(): Promise<void> {
    let text: string = '';
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      this.store = await preferences.getPreferences(ctx, PREF_NAME);
      text = await this.store.get(KEY_DATA, '') as string;
    } catch (e) {
      text = '';
    }
    if (text.length > 0) {
      try {
        const arr = JSON.parse(text) as Record<string, Object>[];
        for (let i = 0; i < ROW_COUNT; i++) {
          let row: FeedData = new FeedData();
          if (i < arr.length) {
            row.fromJson(arr[i]);
          }
          this.rows.push(row);
        }
        return;
      } catch (e) {
        this.rows = [];
      }
    }
    for (let i = 0; i < ROW_COUNT; i++) {
      this.rows.push(new FeedData());
    }
  }

  private saveRows(): void {
    if (this.store === null) {
      return;
    }
    const arr: Record<string, Object>[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      arr.push(this.rows[i].toJson());
    }
    const text: string = JSON.stringify(arr);
    this.store.put(KEY_DATA, text).then(() => {
      this.store?.flush();
    });
  }

  private toast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }

  onPageHide(): void {
    this.saveRows();
  }

  build() {
    Column() {
      Row() {
        Row() {
          Text('☰')
            .fontSize(22)
            .fontColor(Color.White)
            .padding({ left: 4, right: 12, top: 4, bottom: 4 })
            .bindMenu([
              {
                value: '快捷设置',
                action: () => {
                  this.toast('快捷设置：下一步接入列显示与冻结');
                }
              },
              {
                value: '批次切换',
                action: () => {
                  this.toast('批次 01 / 02 切换：下一步实现');
                }
              },
              {
                value: '隐私政策',
                action: () => {
                  this.toast('隐私政策：下一步接入');
                }
              },
              {
                value: '用户协议',
                action: () => {
                  this.toast('用户协议：下一步接入');
                }
              },
              {
                value: '使用帮助',
                action: () => {
                  this.helpController.open();
                }
              },
              {
                value: '选择语言',
                action: () => {
                  this.toast('中英文切换：下一步实现');
                }
              },
              {
                value: '版本:v1.0.0',
                enabled: false,
                action: () => {
                }
              }
            ])
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

      if (this.ready) {
        MixCalcTable({ rows: this.rows, onChanged: () => {
          this.saveRows();
        } })
          .layoutWeight(1)
          .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}