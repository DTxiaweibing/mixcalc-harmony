import { MixCalcTable } from '../table/MixCalcTable';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { promptAction, router, display } from '@kit.ArkUI';
import { Batch } from '../model/Batch';
import { BatchStore, BATCH_COUNT } from '../model/BatchStore';

const PREF_NAME: string = 'MixCalcPrefs';
const ROW_COUNT: number = 30;
const TITLE_BASE: string = '养虾拌料计算器';
const COLUMN_IDS: string[] = ['seq', 'shed_number', 'shed_count', 'average_feed', 'fermented', 'powder', 'feed03', 'feed05', 'feed10', 'water', 'weighed_feed'];
const COLUMN_HEADS: string[] = ['序号', '棚号', '棚数', '平均', '发酵料', '粉料', '0.3料', '0.5料', '1.0料', '水', '称料'];

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
  @State screenW: number = 360;
  @State settingsOpen: boolean = false;
  @State settingsVersion: number = 0;

  private menuItems: MenuItem[] = [
    new MenuItem('快捷设置', () => {
      this.openSettings();
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
      this.screenW = widthVp;
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

  private settingsColumns(): number[] {
    const result: number[] = [];
    for (let i = 1; i < COLUMN_IDS.length; i++) {
      result.push(i);
    }
    return result;
  }

  @Builder
  settingCell(label: string, selected: boolean, action: () => void) {
    Text(label)
      .layoutWeight(1)
      .height(28)
      .fontSize(12)
      .fontColor(selected ? Color.White : '#333333')
      .textAlign(TextAlign.Center)
      .backgroundColor(selected ? '#2D8C42' : '#FFFFFF')
      .border({ width: 0.5, color: '#CCCCCC' })
      .onClick(action)
  }

  private colVisible(col: number): boolean {
    return this.currentBatch().columnVisibility[COLUMN_IDS[col]] !== false;
  }

  private colFixed(col: number): boolean {
    return this.currentBatch().columnFixed[COLUMN_IDS[col]] === true;
  }

  private openSettings(): void {
    this.settingsVersion = this.settingsVersion + 1;
    setTimeout(() => {
      this.settingsOpen = true;
    }, 60);
  }

  private closeSettings(): void {
    this.settingsOpen = false;
  }

  private confirmSettings(): void {
    this.settingsOpen = false;
    this.saveAll();
    this.rebuildTable();
    this.toast('列设置已保存');
  }

  private setColumnFixed(col: number, fixed: boolean): void {
    this.currentBatch().columnFixed[COLUMN_IDS[col]] = fixed;
    this.settingsVersion = this.settingsVersion + 1;
  }

  private setColumnVisible(col: number, visible: boolean): void {
    this.currentBatch().columnVisibility[COLUMN_IDS[col]] = visible;
    this.settingsVersion = this.settingsVersion + 1;
  }

  private panelUnfixAll(): void {
    const batch: Batch = this.currentBatch();
    for (let i = 1; i < COLUMN_IDS.length; i++) {
      batch.columnFixed[COLUMN_IDS[i]] = false;
    }
    this.settingsVersion = this.settingsVersion + 1;
    this.saveAll();
    this.rebuildTable();
  }

  private panelShowAll(): void {
    const batch: Batch = this.currentBatch();
    for (let i = 1; i < COLUMN_IDS.length; i++) {
      batch.columnVisibility[COLUMN_IDS[i]] = true;
    }
    this.settingsVersion = this.settingsVersion + 1;
    this.saveAll();
    this.rebuildTable();
  }
  private visibleMask(): boolean[] {
    const batch: Batch = this.currentBatch();
    const result: boolean[] = [];
    for (let i = 0; i < COLUMN_IDS.length; i++) {
      result.push(i === 0 ? true : batch.columnVisibility[COLUMN_IDS[i]] !== false);
    }
    return result;
  }

  private fixedMask(): boolean[] {
    const batch: Batch = this.currentBatch();
    const result: boolean[] = [];
    for (let i = 0; i < COLUMN_IDS.length; i++) {
      result.push(i === 0 ? true : batch.columnFixed[COLUMN_IDS[i]] === true);
    }
    return result;
  }

  private rebuildTable(): void {
    this.ready = false;
    setTimeout(() => {
      this.ready = true;
    }, 50);
  }

  private handleColumnAction(action: string, index: number): void {
    if (this.batches.length === 0 || index < 0 || index >= COLUMN_IDS.length) {
      return;
    }
    const batch: Batch = this.currentBatch();
    const id: string = COLUMN_IDS[index];
    if (id === 'seq') {
      return;
    }
    if (action === 'toggle-fixed') {
      const next: boolean = batch.columnFixed[id] !== true;
      batch.columnFixed[id] = next;
      this.toast(COLUMN_HEADS[index] + (next ? '列已固定' : '列已取消固定'));
    } else if (action === 'toggle-visible') {
      const next: boolean = batch.columnVisibility[id] === false;
      batch.columnVisibility[id] = next;
      this.toast(COLUMN_HEADS[index] + (next ? '列已显示' : '列已隐藏'));
    } else if (action === 'show-all') {
      for (let i = 1; i < COLUMN_IDS.length; i++) {
        batch.columnVisibility[COLUMN_IDS[i]] = true;
      }
      this.toast('所有列已显示');
    } else if (action === 'unfix-all') {
      for (let i = 1; i < COLUMN_IDS.length; i++) {
        batch.columnFixed[COLUMN_IDS[i]] = false;
      }
      this.toast('已取消所有固定');
    }
    this.saveAll();
    this.rebuildTable();
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
            visibleMask: this.visibleMask(),
            fixedMask: this.fixedMask(),
            onChanged: () => {
              this.saveAll();
            },
            onHelp: () => {
              this.openPage('help/index.html');
            },
            onColumnAction: (action: string, index: number) => {
              this.handleColumnAction(action, index);
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

      if (this.settingsOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.closeSettings();
          })

        Column() {
          Row() {
            Text('列名').layoutWeight(1).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.Center)
            Text('固列').layoutWeight(1).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.Center)
            Text('解固').layoutWeight(1).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.Center)
            Text('隐列').layoutWeight(1).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.Center)
            Text('显列').layoutWeight(1).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#333333').textAlign(TextAlign.Center)
          }
          .width('100%')
          .height(40)
          .backgroundColor('#E8F5E9')

          ForEach(this.settingsColumns(), (col: number) => {
            Row() {
              Text(COLUMN_HEADS[col])
                .layoutWeight(1)
                .fontSize(14)
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
              this.settingCell('固列', this.colFixed(col), () => {
                this.setColumnFixed(col, true);
              })
              this.settingCell('解固', !this.colFixed(col), () => {
                this.setColumnFixed(col, false);
              })
              this.settingCell('隐列', !this.colVisible(col), () => {
                this.setColumnVisible(col, false);
              })
              this.settingCell('显列', this.colVisible(col), () => {
                this.setColumnVisible(col, true);
              })
            }
            .width('100%')
            .height(40)
            .padding({ left: 8, right: 8 })
            if (col < 9) {
              Divider().strokeWidth(1).color('#E0E0E0')
            }
          }, (col: number) => 'set' + col.toString())

          Divider()
            .strokeWidth(1)
            .color('#E0E0E0')

          Row() {
            Text('全取消')
              .layoutWeight(1)
              .height(32)
              .fontSize(13)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor('#999999')
              .borderRadius(8)
              .onClick(() => {
                this.closeSettings();
              })
            Text('全解固')
              .layoutWeight(1)
              .height(32)
              .fontSize(13)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor('#2D8C42')
              .borderRadius(8)
              .margin({ left: 4 })
              .onClick(() => {
                this.panelUnfixAll();
              })
            Text('列全显')
              .layoutWeight(1)
              .height(32)
              .fontSize(13)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor('#2D8C42')
              .borderRadius(8)
              .margin({ left: 4 })
              .onClick(() => {
                this.panelShowAll();
              })
            Text('全确认')
              .layoutWeight(1)
              .height(32)
              .fontSize(13)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor('#2D8C42')
              .borderRadius(8)
              .margin({ left: 4 })
              .onClick(() => {
                this.confirmSettings();
              })
          }
          .width('100%')
          .height(44)
          .padding({ left: 8, right: 8 })
        }
        .width(Math.min(360, this.screenW))
        .backgroundColor(Color.White)
        .shadow({ radius: 8, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: 0, y: 40 })
      }

    }
    .width('100%')
    .height('100%')
  }
}
