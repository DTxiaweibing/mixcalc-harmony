import { MixCalcTable } from '../table/MixCalcTable';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction, router, display } from '@kit.ArkUI';
import { Batch } from '../model/Batch';
import { BatchStore, BATCH_COUNT } from '../model/BatchStore';

const PREF_NAME: string = 'MixCalcPrefs';
const ROW_COUNT: number = 30;
const TITLE_BASE: string = '养虾拌料计算器';

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
  private store: preferences.Preferences | null = null;
  private batches: Batch[] = [];
  @State activeBatch: number = 0;
  @State ready: boolean = false;
  @State menuOpen: boolean = false;
  @State batchMenuOpen: boolean = false;
  @State menuWidth: number = 140;

  private menuItems: MenuItem[] = [
    new MenuItem('快捷设置', () => {
      this.toast('快捷设置：下一步接入列显示与冻结');
    }),
    new MenuItem('批次切换', () => {
      this.batchMenuOpen = !this.batchMenuOpen;
    }),
    new MenuItem('隐私政策', () => {
      this.openPage('privacy.html');
    }),
    new MenuItem('用户协议', () => {
      this.openPage('user.html');
    }),
    new MenuItem('使用帮助', () => {
      this.openPage('help/index.html');
    }),
    new MenuItem('选择语言', () => {
      this.toast('中英文切换：下一步实现');
    }),
    new MenuItem('版本:v1.0.0', () => {
    })
  ];

  async aboutToAppear(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      this.store = await preferences.getPreferences(ctx, PREF_NAME);
      this.batches = await BatchStore.load(this.store, ROW_COUNT);
      this.activeBatch = await BatchStore.loadActive(this.store);
    } catch (e) {
      this.batches = [];
      for (let i = 0; i < BATCH_COUNT; i++) {
        this.batches.push(new Batch(ROW_COUNT));
      }
    }
    this.ready = true;
    try {
      const info = display.getDefaultDisplaySync();
      const widthVp = this.getUIContext().px2vp(info.width);
      this.menuWidth = Math.max(140, widthVp / 3);
    } catch (e) {
      this.menuWidth = 140;
    }
  }

  private currentBatch(): Batch {
    return this.batches[this.activeBatch];
  }

  private saveAll(): void {
    if (this.store === null || this.batches.length === 0) {
      return;
    }
    BatchStore.save(this.store, this.batches, this.activeBatch);
  }

  private switchBatch(index: number): void {
    this.menuOpen = false;
    this.batchMenuOpen = false;
    if (index === this.activeBatch || index < 0 || index >= this.batches.length) {
      return;
    }
    this.saveAll();
    this.activeBatch = index;
    this.ready = false;
    setTimeout(() => {
      this.ready = true;
    }, 50);
    this.saveAll();
  }

  private toast(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }

  private openPage(route: string): void {
    router.pushUrl({
      url: 'pages/WebPage',
      params: {
        route: route
      }
    });
  }

  private batchTitle(index: number): string {
    return index === 0 ? '批次01' : '批次02';
  }

  onPageHide(): void {
    this.saveAll();
  }

  @Builder
  menuRow(item: MenuItem, isLast: boolean) {
    Button(item.label)
      .type(ButtonType.Normal)
      .width('100%')
      .height(39)
      .borderRadius(0)
      .backgroundColor(Color.Transparent)
      .fontSize(18)
      .fontColor(item.label.startsWith('版本') ? '#999999' : '#333333')
      .stateEffect(!item.label.startsWith('版本'))
      .enabled(!item.label.startsWith('版本'))
      .onClick(() => {
        if (item.label !== '批次切换') {
          this.menuOpen = false;
          this.batchMenuOpen = false;
        }
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
              this.batchMenuOpen = false;
            })

          Text(this.activeBatch === 0 ? TITLE_BASE : TITLE_BASE + ' 02')
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
            rows: this.currentBatch().rows,
            waterPercentage: this.currentBatch().waterPercentage,
            fermentedInWater: this.currentBatch().fermentedInWater,
            fermentedInAverage: this.currentBatch().fermentedInAverage,
            onChanged: () => {
              this.saveAll();
            },
            onHelp: () => {
              this.openPage('help/index.html');
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
            this.batchMenuOpen = false;
          })

        Column() {
          ForEach(this.menuItems, (item: MenuItem, index: number) => {
            this.menuRow(item, index === this.menuItems.length - 1)
          }, (item: MenuItem) => item.label)
        }
        .width(this.menuWidth)
        .backgroundColor(Color.White)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: 0, y: 40 })

        if (this.batchMenuOpen) {
          Column() {
            Text('选择批次')
              .width('100%')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .textAlign(TextAlign.Center)
              .padding({ top: 16, bottom: 12, left: 16, right: 16 })

            Divider()
              .strokeWidth(1)
              .color('#E0E0E0')

            ForEach([0, 1], (index: number) => {
              Button(index === this.activeBatch
                ? this.batchTitle(index) + ' ✓'
                : this.batchTitle(index))
                .type(ButtonType.Normal)
                .width('100%')
                .height(40)
                .borderRadius(0)
                .backgroundColor(Color.Transparent)
                .fontSize(15)
                .fontColor('#333333')
                .onClick(() => {
                  this.switchBatch(index);
                })
              if (index === 0) {
                Divider()
                  .strokeWidth(1)
                  .color('#E0E0E0')
              }
            }, (index: number) => index.toString())
          }
          .width(180)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .clip(true)
          .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
          .position({ x: this.menuWidth, y: 80 })
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}