import { MixCalcTable } from '../table/MixCalcTable';
import { FeedData } from '../model/FeedData';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

const PREF_NAME: string = 'MixCalcPrefs';
const KEY_DATA: string = 'saved_data';
const ROW_COUNT: number = 30;

@Entry
@Component
struct Index {
  private rows: FeedData[] = [];
  @State ready: boolean = false;
  private store: preferences.Preferences | null = null;

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
                value: '批次（01 / 02）',
                action: () => {
                  this.toast('批次切换：下一步实现');
                }
              },
              {
                value: '使用帮助',
                action: () => {
                  this.toast('第一行填总棚号，其余行填细分棚号');
                }
              },
              {
                value: '选择语言',
                action: () => {
                  this.toast('中英文切换：下一步实现');
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