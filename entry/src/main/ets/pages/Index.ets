import { MixCalcTable } from '../table/MixCalcTable';
import { FeedData } from '../model/FeedData';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';

const PREF_NAME: string = 'MixCalcPrefs';
const KEY_DATA: string = 'saved_data';
const ROW_COUNT: number = 30;

class MenuItem {
  label: string;
  action: () => void;

  constructor(label: string, action: () => void) {
    this.label = label;
    this.action = action;
  }
}

@Entry
@Component
struct Index {
  private rows: FeedData[] = [];
  @State ready: boolean = false;
  @State menuOpen: boolean = false;
  private store: preferences.Preferences | null = null;

  private menuItems: MenuItem[] = [
    new MenuItem('快捷设置', () => {
      this.toast('快捷设置：下一步接入列显示与冻结');
    }),
    new MenuItem('批次切换', () => {
      this.toast('批次 01 / 02 切换：下一步实现');
    }),
    new MenuItem('隐私政策', () => {
      this.openPage('privacy.html', '隐私政策');
    }),
    new MenuItem('用户协议', () => {
      this.openPage('user.html', '用户协议');
    }),
    new MenuItem('使用帮助', () => {
      this.openPage('help/index.html', '使用帮助');
    }),
    new MenuItem('选择语言', () => {
      this.toast('中英文切换：下一步实现');
    }),
    new MenuItem('版本:v1.0.0', () => {
    })
  ];

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

  private openPage(route: string, title: string): void {
    router.pushUrl({
      url: 'pages/WebPage',
      params: {
        route: route,
        title: title
      }
    });
  }

  onPageHide(): void {
    this.saveRows();
  }

  @Builder
  menuRow(item: MenuItem, isLast: boolean) {
    Text(item.label)
      .width('100%')
      .height(39)
      .fontSize(18)
      .fontColor(item.label.startsWith('版本') ? '#999999' : '#333333')
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.menuOpen = false;
        item.action();
      })
    if (!isLast) {
      Divider()
        .strokeWidth(1)
        .color('#E0E0E0')
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Text('☰')
            .fontSize(22)
            .fontColor(Color.White)
            .width(44)
            .height(40)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.menuOpen = !this.menuOpen;
            })

          Text($r('app.string.title_main'))
            .fontSize(20)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Text('')
            .width(44)
        }
        .width('100%')
        .height(40)
        .backgroundColor($r('app.color.title_bar_bg'))

        if (this.ready) {
          MixCalcTable({
            rows: this.rows,
            onChanged: () => {
              this.saveRows();
            },
            onHelp: () => {
              this.openPage('help/index.html', '使用帮助');
            }
          })
            .layoutWeight(1)
            .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))

      if (this.menuOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.menuOpen = false;
          })

        Column() {
          ForEach(this.menuItems, (item: MenuItem, index: number) => {
            this.menuRow(item, index === this.menuItems.length - 1)
          }, (item: MenuItem) => item.label)
        }
        .width('33%')
        .constraintSize({ minWidth: 140 })
        .backgroundColor(Color.White)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: 0, y: 40 })
      }
    }
    .width('100%')
    .height('100%')
  }
}