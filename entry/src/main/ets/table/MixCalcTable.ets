import { FeedData } from '../model/FeedData';
import { ownedSets, findOverLimit, MAX_SHED_NUMBER, renormalize } from '../model/ShedCoverage';
import { settleZeroRowData, settleRows, RowSettleResult } from '../model/RowSettlement';
import { recompute, ShedDraftResult } from '../model/ShedDraft';
import { render as renderShedDisplay } from '../model/ShedDisplay';
import { transfer, giveDown, remove as removeShedNumbers, pointlessWholeRowMove, normalize as normalizeShedNumbers } from '../model/ShedText';
import { ShedDeletePlan } from '../model/ShedDeletePlan';
import { t } from '../common/Strings';
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { LAYOUT_COLUMN_IDS, LAYOUT_WIDTHS, isTabletWidth, rightAlignedX } from '../common/LayoutRules';

const COLUMN_IDS: string[] = LAYOUT_COLUMN_IDS;
const HEAD_KEYS: string[] = ['col.seq', 'col.shed', 'col.count', 'col.avg', 'col.ferm', 'col.powder', 'col.f03', 'col.f05', 'col.f10', 'col.water', 'col.weigh'];
const WIDTHS: number[] = LAYOUT_WIDTHS;
// 棚号气泡 ⋮ 菜单的动作码
const SHED_ACTION_SELECT_ALL: number = 1;
const SHED_ACTION_SELECT_INVERT: number = 2;
const SHED_ACTION_DELETE: number = 3;
const SHED_ACTION_TRANSFER_OUT: number = 4;
const SHED_ACTION_TRANSFER_IN: number = 5;
const ROW_H: number = 40;
const HEAD_H: number = 40;

@CustomDialog
struct CellEditorDialog {
  controller?: CustomDialogController;
  title: string = '';
  initValue: string = '';
  isNumber: boolean = false;
  lang: string = 'zh';
  onConfirm: (value: string) => void = () => {};
  @State input: string = '';


  aboutToAppear(): void {
    this.input = this.initValue;
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize('18vp')
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .padding({ top: 16, bottom: 12 })

      Divider().strokeWidth(1).color('#E0E0E0')

      TextInput({ text: this.input })
        .type(this.isNumber ? InputType.NUMBER_DECIMAL : InputType.Normal)
        .fontSize('16vp')
        .textAlign(TextAlign.Center)
        .height(44)
        .margin({ left: 20, right: 20, top: 12 })
        .defaultFocus(true)
        .onChange((value: string) => {
          this.input = value;
        })

      Row() {
        Button(t(this.lang, 'btn.cancel'))
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(44)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize('15vp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#666666')
          .onClick(() => {
            this.controller?.close();
          })

        Divider().vertical(true).height(44).strokeWidth(1).color('#E0E0E0')

        Button(t(this.lang, 'btn.ok'))
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(44)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize('15vp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#2D8C42')
          .onClick(() => {
            this.onConfirm(this.input);
            this.controller?.close();
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('80%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .clip(true)
  }
}

@CustomDialog
struct ConfirmDialog {
  controller?: CustomDialogController;
  title: string = '';
  message: string = '';
  confirmText: string = '确定重置';
  cancelText: string = '取消';
  confirmColor: string = '#D32F2F';
  onConfirm: () => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize('18vp')
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 12, left: 16, right: 16 })

      Divider().strokeWidth(1).color('#E0E0E0')

      Text(this.message)
        .fontSize('15vp')
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .lineHeight(23)
        .padding({ top: 20, bottom: 20, left: 20, right: 20 })

      Divider().strokeWidth(1).color('#E0E0E0')

      Row() {
        Button(this.cancelText)
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize('15vp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#666666')
          .onClick(() => {
            this.controller?.close();
          })

        Divider().vertical(true).height(48).strokeWidth(1).color('#E0E0E0')

        Button(this.confirmText)
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize('15vp')
          .fontWeight(FontWeight.Bold)
          .fontColor(this.confirmColor)
          .onClick(() => {
            this.controller?.close();
            this.onConfirm();
          })
      }
      .width('100%')
      .height(48)
    }
    .width('70%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .clip(true)
  }
}

@CustomDialog
struct HintDialog {
  controller?: CustomDialogController;
  title: string = '';
  message: string = '';
  confirmText: string = '知道了';
  // 可选的第二个按钮（目前用于「查看帮助」）
  secondaryText: string = '';
  onConfirm: () => void = () => {};
  onSecondary: () => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize('18vp')
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 12, left: 16, right: 16 })

      Divider().strokeWidth(1).color('#E0E0E0')

      Text(this.message)
        .fontSize('15vp')
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .lineHeight(23)
        .padding({ top: 20, bottom: 20, left: 20, right: 20 })

      Divider().strokeWidth(1).color('#E0E0E0')

      if (this.secondaryText.length > 0) {
        Row() {
          Button(this.secondaryText)
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(48)
            .borderRadius(0)
            .backgroundColor(Color.Transparent)
            .fontSize('15vp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#2D8C42')
            .onClick(() => {
              this.onSecondary();
              this.controller?.close();
            })
          Divider().vertical(true).strokeWidth(1).color('#E0E0E0').height(28)
          Button(this.confirmText)
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(48)
            .borderRadius(0)
            .backgroundColor(Color.Transparent)
            .fontSize('15vp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#2D8C42')
            .onClick(() => {
              this.onConfirm();
              this.controller?.close();
            })
        }
        .width('100%')
      } else {
        Button(this.confirmText)
          .type(ButtonType.Normal)
          .width('100%')
          .height(48)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize('15vp')
          .fontWeight(FontWeight.Bold)
          .fontColor('#2D8C42')
          .onClick(() => {
            this.onConfirm();
            this.controller?.close();
          })
      }
    }
    .width('70%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .clip(true)
  }
}

@Component
export struct MixCalcTable {
  rows: FeedData[] = [];
  onChanged: () => void = () => {};
  onHelp: () => void = () => {};
  onColumnAction: (action: string, index: number, vis: boolean[], fix: boolean[]) => void = () => {};
  onWaterChange: (percent: number) => void = () => {};
  onFermentChange: (which: number) => void = () => {};
  // 表体实际宽度回报给 Index：判「是否已铺满 11 列」用表格自己的宽度，不再让外面拿窗口宽度猜
  onViewWidth: (widthVp: number) => void = () => {};

  initVisible: boolean[] = [];
  initFixed: boolean[] = [];

  @State vis: boolean[] = [];
  @State fix: boolean[] = [];

  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  @Prop lang: string = 'zh';
  @Prop kbVisible: boolean = false;
  @Prop @Watch('onSettingsChanged') waterPercentage: number = 20;
  @Prop @Watch('onSettingsChanged') fermentedInWater: boolean = false;
  @Prop fermentedInAverage: boolean = false;

  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State viewW: number = 0;
  @State viewH: number = 0;
  @State version: number = 0;
  // 编辑态：只有坐标是 @State（决定输入框挂不挂），
  // 文本用普通字段，敲键盘不会触发重排，光标才稳。
  @State editingRow: number = -1;
  @State editingCol: number = -1;
  private editingText: string = '';
  private editingSeed: string = '';
  @State editorText: string = '';
  @State caretOn: boolean = true;
  private caretTimer: number = -1;
  private editDirty: boolean = false;
  // 换格时旧输入框的 blur 会晚一步到达，别让它把新开的编辑器关掉
  private editorOpenedAt: number = 0;
  // 程序化改文本（换格塞初值）时压住 onChange，不然一换格就当用户输入提交了
  private suppressChange: boolean = false;
  private editorCtrl: TextInputController = new TextInputController();
  private lastNextAt: number = 0;
  // 棚号编辑期快照：进入编辑那一刻每行的“声明原文”，每敲一个字符都从它重推
  private shedEditActive: boolean = false;
  private shedEditRow: number = -1;
  private shedEditSnapshot: string[] = [];

  @State colMenuOpen: boolean = false;
  @State colMenuX: number = 0;
  @State colMenuTitle: string = '';
  @State colMenuItems: string[] = [];
  private colMenuIndex: number = -1;

  @State pickOpen: boolean = false;
  @State pickX: number = 0;
  @State pickTitle: string = '';
  @State pickItems: string[] = [];
  private pickKind: string = '';

  @State ratioOpen: boolean = false;
  @State ratioX: number = 0;
  @State ratioY: number = 0;
  @State ratioCurrent: number = 0;
  private ratioRow: number = -1;
  private ratioOpenedAt: number = 0;
  private colMenuOpenedAt: number = 0;
  private pickOpenedAt: number = 0;

  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private flingTimer: number = -1;

  private editRow: number = -1;
  private editCol: number = -1;
  // 超上限提示每次编辑只弹一次，别敲一个字符弹一次
  private overLimitWarned: boolean = false;
  private editorTitle: string = '';
  private editorValue: string = '';
  private editorIsNumber: boolean = false;
  private editorController: CustomDialogController = new CustomDialogController({
    builder: CellEditorDialog({
      title: this.editorTitle,
      initValue: this.editorValue,
      isNumber: this.editorIsNumber,
      lang: this.lang,
      onConfirm: (value: string) => {
        this.applyEdit(value);
      }
    }),
    autoCancel: true,
    customStyle: true
  });

  private resetMessage: string = '';
  private resetController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: t(this.lang, 'dlg.reset'),
      message: this.resetMessage,
      cancelText: t(this.lang, 'btn.cancel'),
      confirmText: t(this.lang, 'btn.reset'),
      confirmColor: '#D32F2F',
      onConfirm: () => {
        this.resetAll();
      }
    }),
    autoCancel: true,
    customStyle: true
  });

  // 删除棚号确认框：正文按「有来路会退回 / 没来路真删」分开说清，要真删的点名
  private shedDeleteMessage: string = '';
  private shedDeleteRow: number = -1;
  private shedDeleteTargets: number[] = [];
  private shedDeleteController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: t(this.lang, 'shed.deleteTitle'),
      message: this.shedDeleteMessage,
      cancelText: t(this.lang, 'btn.cancel'),
      confirmText: t(this.lang, 'shed.delete'),
      confirmColor: '#D32F2F',
      onConfirm: () => {
        this.applyDeleteShedNumbers();
      }
    }),
    autoCancel: true,
    customStyle: true
  });

  private hintTitle: string = '';
  private hintMessage: string = '';
  private hintSecondaryText: string = '';
  private hintRefocus: boolean = false;

  private hintController: CustomDialogController = new CustomDialogController({
    builder: HintDialog({
      title: this.hintTitle,
      message: this.hintMessage,
      confirmText: t(this.lang, 'btn.gotIt'),
      secondaryText: this.hintSecondaryText,
      onConfirm: () => {
        if (this.hintRefocus) {
          setTimeout(() => {
            focusControl.requestFocus('cellEditor');
          }, 120);
        }
      },
      onSecondary: () => {
        this.onHelp();
      }
    }),
    autoCancel: true,
    customStyle: true
  });

  // 棚数按钮点开的本行棚号气泡（跟随被点单元格的下沿）
  @State shedListOpen: boolean = false;
  @State shedListX: number = 0;
  @State shedListY: number = 0;
  @State shedListW: number = 0;
  @State shedListScrollH: number = 60;
  @State shedListTitleText: string = '';
  @State shedListCountText: string = '';
  @State shedListNumbers: number[] = [];
  private shedListOpenedAt: number = 0;
  // 气泡属于哪一行（删/转都按行号定位，行被回收后要重定位）
  @State shedListRow: number = -1;
  // 气泡里已选中的号码（绿底 ↔ 蓝底）
  @State shedSelected: number[] = [];
  // 气泡右上角 ⋮ 菜单
  @State shedMenuOpen: boolean = false;
  @State shedMenuX: number = 0;
  @State shedMenuY: number = 0;
  @State shedMenuLabels: string[] = [];
  @State shedMenuActions: number[] = [];
  @State shedMenuW: number = 150;
  // 待转池：转出后先记在这里，等另一行点【转入】才真正搬走；来源行数据一个字都不改
  private pendingTransferNumbers: number[] = [];
  private pendingTransferSourceRow: number = -1;

  // ===== 列状态 =====
  private isVisible(index: number): boolean {
    if (index === 0) {
      return true;
    }
    return this.vis.length > index ? this.vis[index] : true;
  }

  private isFixed(index: number): boolean {
    if (index === 0) {
      return true;
    }
    return this.fix.length > index ? this.fix[index] : false;
  }

  private fixedIndices(): number[] {
    const result: number[] = [];
    for (let i = 0; i < WIDTHS.length; i++) {
      if (this.isVisible(i) && this.isFixed(i)) {
        result.push(i);
      }
    }
    return result;
  }

  private normalIndices(): number[] {
    const result: number[] = [];
    for (let i = 0; i < WIDTHS.length; i++) {
      if (this.isVisible(i) && !this.isFixed(i)) {
        result.push(i);
      }
    }
    return result;
  }

  private frozenWidth(): number {
    let w: number = 0;
    const fixed: number[] = this.fixedIndices();
    for (let i = 0; i < fixed.length; i++) {
      w += this.cw(fixed[i]);
    }
    return w;
  }

  private normalWidth(): number {
    let w: number = 0;
    const normal: number[] = this.normalIndices();
    for (let i = 0; i < normal.length; i++) {
      w += this.cw(normal[i]);
    }
    return w;
  }

  private totalWidth(): number {
    return this.frozenWidth() + this.normalWidth();
  }

  private bodyHeight(): number {
    return this.rows.length * this.rh();
  }

  private maxOffsetX(): number {
    return Math.max(0, this.totalWidth() - this.viewW);
  }

  private maxOffsetY(): number {
    return Math.max(0, this.bodyHeight() - this.viewH);
  }

  // 编辑器横坐标：和格子用同一套坐标，不做夹紧（夹紧会让它停在别的格子上“悬浮”）
  private editorX(): number {
    return this.columnLeft(this.editingCol);
  }

  // ===== 平板/手机列宽（照搬安卓 TabletLayout.computeWidths）=====
  // 手机：固定 vp 宽度，横向滚动；平板：按当前窗口宽度均分 11 列，再按列语义微调、整体贴合屏宽
  private isTabletMode(): boolean {
    // 只看当前窗口宽度（与安卓 0.3.5 一致）：折叠屏外屏约 370vp 会自动回到手机布局
    return isTabletWidth(this.viewW);
  }

  // 窗口宽度变了（折叠/展开、分屏、转屏）：列宽会按新窗宽重算，贴表头的弹窗先关掉，避免停在旧位置
  private applyViewSize(widthVp: number, heightVp: number): void {
    const widthChanged: boolean = Math.abs(widthVp - this.viewW) >= 1;
    this.viewW = widthVp;
    this.viewH = heightVp;
    if (widthChanged) {
      this.colMenuOpen = false;
      this.pickOpen = false;
      this.ratioOpen = false;
      this.shedListOpen = false;
      this.shedMenuOpen = false;
      this.clearPendingTransfer();
      this.onViewWidth(widthVp);
    }
    // 变宽后旧的横向滚动量可能超出新内容宽，不收就会在右侧留一条空白
    this.clampOffsets();
  }

  private colShown(index: number): boolean {
    if (index === 0) {
      return true;
    }
    return this.vis.length > index ? this.vis[index] !== false : true;
  }

  private cachedW: number[] = [];
  private cachedWidthKey: string = '';

  private ensureWidths(): void {
    const key: string = Math.round(this.viewW * 10).toString() + '|' + this.vis.join(',');
    if (key === this.cachedWidthKey) {
      return;
    }
    this.cachedWidthKey = key;
    const out: number[] = [];
    if (!this.isTabletMode()) {
      // 手机：固定列宽；隐藏列后如果总宽不够，下面统一铺满
      for (let i = 0; i < WIDTHS.length; i++) {
        out.push(this.colShown(i) ? WIDTHS[i] : 0);
      }
    } else {
      let visibleCount: number = 0;
      for (let i = 0; i < WIDTHS.length; i++) {
        if (this.colShown(i)) {
          visibleCount++;
        }
      }
      if (visibleCount === 0) {
        visibleCount = 1;
      }
      const base: number = this.viewW / visibleCount;
      for (let i = 0; i < WIDTHS.length; i++) {
        if (!this.colShown(i)) {
          out.push(0);
          continue;
        }
        const id: string = COLUMN_IDS[i];
        let w: number = base;
        if (id === 'shed_number' || id === 'weighed_feed') {
          w = base * 1.2;
        }
        if (id === 'seq' || id === 'average_feed') {
          w = base * 0.8;
        }
        w = Math.max(50, Math.min(w, 120));
        out.push(w);
      }
      // 平板：始终贴合屏宽，保证所有可见列一次全显示
      let total: number = 0;
      for (let i = 0; i < out.length; i++) {
        total += out[i];
      }
      if (total > 0) {
        const scale: number = this.viewW / total;
        for (let i = 0; i < out.length; i++) {
          out[i] = Math.floor(out[i] * scale);
        }
      }
    }
    // 可见列总宽 < 屏宽时按比例放大铺满（隐藏列太多时右侧会留白，看起来像少了一列）
    let sum: number = 0;
    let lastShown: number = -1;
    for (let i = 0; i < out.length; i++) {
      if (out[i] > 0) {
        sum += out[i];
        lastShown = i;
      }
    }
    if (sum > 0 && sum < this.viewW && lastShown >= 0) {
      const k: number = this.viewW / sum;
      let newSum: number = 0;
      for (let i = 0; i < out.length; i++) {
        if (out[i] > 0) {
          out[i] = Math.max(1, Math.floor(out[i] * k));
          newSum += out[i];
        }
      }
      // 取整误差补给最后一个可见列，正好铺满、不留缝
      const diff: number = Math.round(this.viewW) - newSum;
      if (diff !== 0) {
        out[lastShown] = Math.max(1, out[lastShown] + diff);
      }
    }
    this.cachedW = out;
  }

  private cw(index: number): number {
    this.ensureWidths();
    if (this.cachedW.length > index && this.cachedW[index] > 0) {
      return this.cachedW[index];
    }
    return WIDTHS[index];
  }

  private rh(): number {
    return ROW_H;
  }

  private hh(): number {
    return HEAD_H;
  }

  // 字号固定：用 vp 而不是 fp，不随系统字体大小缩放
  private fs(): string {
    return '15vp';
  }

  // 表头单独一号：比正文小 1vp
  private fsHeader(): string {
    return '14vp';
  }

  // 棚号列：两行折叠后每行最多 9 个字符，字号必须比正文小一号才塞得进列宽。
  // 对齐安卓「固定字号、不缩放、放不下裁掉」，所以这里给死值，不跟内容自适应。
  private fsShed(): string {
    return '13vp';
  }

  // 自绘光标（数字列没有系统输入框，只能自己闪）
  private startCaret(): void {
    this.stopCaret();
    this.caretOn = true;
    this.caretTimer = setInterval(() => {
      this.caretOn = !this.caretOn;
    }, 520);
  }

  private stopCaret(): void {
    if (this.caretTimer !== -1) {
      clearInterval(this.caretTimer);
      this.caretTimer = -1;
    }
    this.caretOn = true;
  }

  private clampOffsets(): void {
    this.offsetX = Math.min(Math.max(0, this.offsetX), this.maxOffsetX());
    this.offsetY = Math.min(Math.max(0, this.offsetY), this.maxOffsetY());
    // 编辑中的格子滚出可视区就收起来（对齐安卓 CellEditorOverlay.onScrolled）
    if (this.editingRow >= 0) {
      const top: number = this.editingRow * this.rh() - this.offsetY;
      // 只要这一行不再完整地待在表体里（钻到表头下面或滑出底部），就收起编辑，
      // 免得输入框画到表头 / 表尾上面去
      if (this.viewH > 0 && (top < 0 || top + this.rh() > this.viewH)) {
        this.finishEdit();
        return;
      }
      if (this.editingCol >= 0 && !this.isFixed(this.editingCol)) {
        const x: number = this.columnLeft(this.editingCol);
        const w: number = this.cw(this.editingCol);
        // 只要这格横向不再完整可见（滚到冻结列底下或滚出右边），立刻收编辑
        if (x < this.frozenWidth() || x + w > this.viewW) {
          this.finishEdit();
        }
      }
    }
  }

  private columnLeft(index: number): number {
    const fixed: number[] = this.fixedIndices();
    let x: number = 0;
    for (let i = 0; i < fixed.length; i++) {
      if (fixed[i] === index) {
        return x;
      }
      x += this.cw(fixed[i]);
    }
    let nx: number = 0;
    const normal: number[] = this.normalIndices();
    for (let i = 0; i < normal.length; i++) {
      if (normal[i] === index) {
        return this.frozenWidth() + nx - this.offsetX;
      }
      nx += this.cw(normal[i]);
    }
    return 0;
  }

  // ===== 文案与数值 =====
  private headLabel(col: number): string {
    if (col === 9) {
      return t(this.lang, 'water.header').replace('%d', this.waterPercentage.toString());
    }
    return t(this.lang, HEAD_KEYS[col]);
  }

  private formatNumber(value: number): string {
    if (value === 0) {
      return '';
    }
    if (value === Math.floor(value)) {
      return Math.floor(value).toString();
    }
    return value.toFixed(2);
  }

  private cellText(row: FeedData, column: number, rowIndex: number): string {
    // 棚数为 0：料列一律不显示数据（背景仍由 cellFill 置灰），
    // 平均/水/称料也留白；底层数据还在，等失焦结算时才真正清掉
    if (row.shedCount <= 0
      && (column === 3 || column === 9 || (column >= 4 && column <= 8))) {
      return '';
    }
    switch (column) {
      case 0: return (rowIndex + 1).toString();
      // 棚号列：显示「实际拥有」的号，按两行极简折叠；不依赖 Text 的自动折行，
      // 否则系统会按像素把区间从中间切断
      case 1: return renderShedDisplay(row.getShedDisplay()).join('\n');
      case 2: return row.shedCount === 0 ? '' : Math.round(row.shedCount).toString();
      case 3: return this.formatNumber(row.average);
      case 4: return this.formatNumber(row.fermented);
      case 5: return this.formatNumber(row.powder);
      case 6: return this.formatNumber(row.feed03);
      case 7: return this.formatNumber(row.feed05);
      case 8: return this.formatNumber(row.feed10);
      case 9: return this.formatNumber(row.water);
      case 10:
        if (row.shedCount > 0 && row.weighed > 0) {
          return this.formatNumber(row.weighed) + '×' + row.shedCount.toString();
        }
        return '';
      default: return '';
    }
  }

  private cellColor(column: number): string {
    if (column === 0) {
      return '#666666';
    }
    // 棚数是可点的按钮，用深绿提示可点
    if (column === 2) {
      return '#1F6B30';
    }
    if (column === 3 || column === 9 || column === 10) {
      return '#0000FF';
    }
    return '#000000';
  }

  private isWarningCell(data: FeedData, column: number, rowIndex: number): boolean {
    // 所有行平等：不再有“第一行 = 总棚数”，也就没有超额报警
    return false;
  }

  private isCellEnabled(data: FeedData, column: number): boolean {
    if (column === 1 || column === 2) {
      return true;
    }
    if (column === 3) {
      return data.canEditAverage();
    }
    if (column >= 4 && column <= 8) {
      return data.shedCount > 0;
    }
    return false;
  }

  private cellFill(data: FeedData, column: number, rowIndex: number): string {
    if (this.isWarningCell(data, column, rowIndex)) {
      return '#FFC64B';
    }
    // 换料目标格：浅绿。直接改过这格数值后 switchRatio 会被清 0，自动回乳白
    if (column >= 5 && column <= 8 && data.shedCount > 0 && data.switchRatio > 0
      && this.isSwitchTargetCell(data, column)) {
      return '#F0F8F0';
    }
    // 不能输入的格子（还没填棚数）保持灰色
    if (column >= 4 && column <= 8 && data.shedCount <= 0) {
      return '#F0F0F0';
    }
    return '#FFFFFF';
  }

  private cellBorderColor(data: FeedData, column: number, rowIndex: number): string {
    if (this.isWarningCell(data, column, rowIndex)) {
      return '#FF0000';
    }
    if (column >= 4 && column <= 8 && data.shedCount <= 0) {
      return '#CCCCCC';
    }
    return '#000000';
  }

  private switchTargetIndex(data: FeedData): number {
    let count: number = 0;
    let last: number = -1;
    for (let i = 0; i < 4; i++) {
      if (data.getNonFermentedValue(i) > 0) {
        count++;
        last = i;
      }
    }
    if (count === 1) {
      return last >= 0 && last < 3 ? last + 1 : -1;
    }
    if (count === 2) {
      return last;
    }
    return -1;
  }

  private isSwitchTargetCell(data: FeedData, column: number): boolean {
    const nf: number = column - 5;
    if (nf < 0 || nf > 3) {
      return false;
    }
    return this.switchTargetIndex(data) === nf;
  }

  // ===== 编辑 =====
  private isEditableColumn(column: number): boolean {
    // 棚数(2)由棚号自动算出，不允许手改；序号、水质、称料也不可改
    return column === 1 || column === 3 || (column >= 4 && column <= 8);
  }

  private nfIndexOf(column: number): number {
    switch (column) {
      case 5: return 0;
      case 6: return 1;
      case 7: return 2;
      case 8: return 3;
      default: return -1;
    }
  }

  private currentValue(row: number, column: number): string {
    const data: FeedData = this.rows[row];
    if (column === 1) {
      return data.shedNumber;
    }
    if (column === 2) {
      return data.shedCount === 0 ? '' : Math.round(data.shedCount).toString();
    }
    let value: number = 0;
    switch (column) {
      case 3: value = data.average; break;
      case 4: value = data.fermented; break;
      case 5: value = data.powder; break;
      case 6: value = data.feed03; break;
      case 7: value = data.feed05; break;
      case 8: value = data.feed10; break;
      default: break;
    }
    const rounded: number = Math.round(value * 100) / 100;
    return rounded === 0 ? '' : rounded.toString();
  }

  private clearRowData(row: FeedData, clearShedNumber: boolean): void {
    if (clearShedNumber) {
      // 必须走 setShedNumber：它会同时清掉显示串 shedDisplay。
      // 以前直接写 shedNumber = ''，显示串留在那儿不清，格子就继续显示老棚号，
      // 只有杀掉进程从 JSON 重新载入（不含显示串）才会空——「重置清不掉」就是这么来的。
      row.setShedNumber('');
    }
    row.shedCount = 0;
    row.average = 0;
    row.fermented = 0;
    row.powder = 0;
    row.feed03 = 0;
    row.feed05 = 0;
    row.feed10 = 0;
    row.water = 0;
    row.weighed = 0;
    row.switchRatio = 0;
    row.isAverageManuallyModified = false;
  }

  // 失焦结算：棚数为 0 的行当新行处理（棚号保留，只清料/水/平均/称料）
  private settleZeroRows(): void {
    if (settleZeroRowData(this.rows)) {
      this.version = this.version + 1;
      this.onChanged();
    }
  }

  // 每行当前的“声明原文”（不是显示文本）：覆盖/快照只认这个
  private snapshotShedTexts(): string[] {
    const texts: string[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      texts.push(this.rows[i].shedNumber);
    }
    return texts;
  }

  private beginShedEdit(row: number): void {
    this.shedEditSnapshot = this.snapshotShedTexts();
    this.shedEditRow = row;
    this.shedEditActive = true;
  }

  private endShedEdit(): void {
    this.shedEditActive = false;
    this.shedEditRow = -1;
    this.shedEditSnapshot = [];
  }

  /**
   * 结算并补空行：先按声明文本回收死行，再兜底清 0 棚行，底部补齐总行数。
   * 只在“离开编辑”的时刻调用；编辑途中绝不删行。
   */
  private settleRowsAndPad(emptied: number[]): void {
    const result: RowSettleResult = settleRows(this.rows, emptied);
    if (result.removed.length === 0 && !result.changed) {
      return;
    }
    this.editingRow = -1;
    this.editingCol = -1;
    this.editRow = -1;
    this.editCol = -1;
    this.endShedEdit();
    this.shedListOpen = false;
    // 待转池的生命周期在任务 11 接入：任何结算都作废一次待转
    this.clearPendingTransfer();
    this.applyShedCoverage();
    this.version = this.version + 1;
    this.onChanged();
  }

  // 待转池作废：转出后没走来转入这条路，或任何一次结算，都把这次转出丢掉
  private clearPendingTransfer(): void {
    this.pendingTransferNumbers = [];
    this.pendingTransferSourceRow = -1;
  }

  private hasPendingTransfer(): boolean {
    return this.pendingTransferSourceRow >= 0 && this.pendingTransferNumbers.length > 0;
  }

  private sumBelowFirst(): number {
    let sum: number = 0;
    for (let i = 1; i < this.rows.length; i++) {
      sum += this.rows[i].shedCount;
    }
    return sum;
  }

  // 打点覆盖：后一行覆盖前一行的重叠棚号，所有行一视同仁。
  // 声明（shedNumber）永不改写，只写“显示”（shedDisplay）与权威棚数（shedCount）：
  // 这样下行把号占走后，上行原文还在，下行改小/清空时号能自动退回。
  private applyShedCoverage(): void {
    if (this.rows.length < 1) {
      return;
    }
    const texts: string[] = this.snapshotShedTexts();
    const liveTyping: boolean = this.shedEditActive
      && this.shedEditSnapshot.length === texts.length
      && this.shedEditRow >= 0 && this.shedEditRow < texts.length;

    let counts: number[] = [];
    let canonical: string[] = [];
    if (liveTyping) {
      // 编辑中：每帧都从编辑前快照 + 当前这一格的输入重推，
      // 半成品区间（16-4 被当成 4~16）只影响这一帧，不会永久抢走别人的号
      const draft: ShedDraftResult = recompute(
        this.shedEditSnapshot, this.shedEditRow, texts[this.shedEditRow]);
      counts = draft.counts;
      canonical = draft.texts;
    } else {
      canonical = renormalize(texts);
      const sets: number[][] = ownedSets(texts);
      for (let i = 0; i < sets.length; i++) {
        counts.push(sets[i].length);
      }
    }

    for (let i = 0; i < this.rows.length; i++) {
      const row: FeedData = this.rows[i];
      const oldCount: number = row.shedCount;   // 必须在写显示/棚数之前取
      const oldAverage: number = row.average;
      const display: string = i < canonical.length ? canonical[i] : row.shedNumber;
      row.setShedDisplay(display);
      const count: number = i < counts.length ? counts[i] : 0;
      if (oldCount !== count) {
        // 棚数变了：平均不动，料量按“平均 × 新棚数”重算
        row.setShedCountDirectly(count);
        if (oldAverage > 0 && row.canEditAverage()) {
          row.setAverageManually(oldAverage, this.fermentedInAverage);
        }
        row.recalculateDerivedOnly(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
      }
    }
  }

  private recomputeFirstRow(): void {
    // 所有行平等：只做打点覆盖，没有“第一行 = 总棚数”这回事
    this.applyShedCoverage();
  }

  private applyEdit(text: string, persist: boolean = true): void {
    if (this.editRow < 0 || this.editCol < 0) {
      return;
    }
    const row: FeedData = this.rows[this.editRow];
    const value: string = text.trim();
    const col: number = this.editCol;
    const over: number = col === 1 ? findOverLimit(value) : 0;
    if (over > 0) {
      this.warnOverLimit();
    } else {
      this.overLimitWarned = false;
    }
    let number: number = value.length === 0 ? 0 : Number(value);
    if (isNaN(number)) {
      number = 0;
    }

    if (col === 1) {
      // 棚数由棚号自动算，改棚号即可；棚数格子不允许手改
      const oldCount: number = row.shedCount;
      const oldAverage: number = row.average;
      row.setShedNumber(value);
      if (row.shedCount !== oldCount && oldAverage > 0 && row.canEditAverage()) {
        // 改棚号本质是改棚数：平均保持不变，料量重算
        row.setAverageManually(oldAverage, this.fermentedInAverage);
      }
    } else if (col === 3) {
      row.setAverageManually(number, this.fermentedInAverage);
    } else {
      const nfIndex: number = this.nfIndexOf(col);
      const origin: number = nfIndex >= 0 ? row.getNonFermentedValue(nfIndex) : 0;
      row.isAverageManuallyModified = false;
      if (number === 0 && nfIndex >= 0) {
        row.mergeSmallerWhenCleared(nfIndex, origin);
      }
      switch (col) {
        case 4: row.fermented = number; break;
        case 5: row.powder = number; break;
        case 6: row.feed03 = number; break;
        case 7: row.feed05 = number; break;
        case 8: row.feed10 = number; break;
        default: break;
      }
      row.switchRatio = 0;
    }

    // 编辑途中棚数变成 0 只隐藏显示，不动底层数据：
    // 别把用户已经填好的料清掉，等失焦结算时再按“新行”处理
    // 先打点覆盖算出权威棚数（棚数真的变了才按旧平均重算料量），再刷新派生值：
    // 顺序反了会拿“本行棚号自己数的个数”当权威值，和别的行重叠时
    // 每敲一个键都会把料量按错误棚数改一遍（手动填料被改写）
    this.recomputeFirstRow();
    row.updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    this.version = this.version + 1;
    if (persist) {
      this.onChanged();
    }
  }

  // 对齐安卓 afterTextChanged：敲一个字符就重算（边输边算），但不落盘
  private editLive(text: string): void {
    this.editDirty = true;
    this.applyEdit(text, false);
  }

  // 收尾：只有真改过才提交落盘；只点一下没输入不写脏数据（安卓 dirty 标记）
  // 编辑结束＝失去焦点：这里做一次结算，棚数仍为 0 的行彻底清空
  private finishEdit(): void {
    if (this.editingRow >= 0 && this.editingCol >= 0) {
      const text: string = this.editingText;
      const wasDirty: boolean = this.editDirty;
      const wasShed: boolean = this.editingCol === 1;
      this.editingRow = -1;
      this.editingCol = -1;
      this.editingSeed = '';
      this.editDirty = false;
      this.stopCaret();
      // 必须先清快照再做定稿重算：否则这一遍会拿旧快照把刚敲的内容回滚掉
      this.endShedEdit();
      if (wasDirty) {
        this.applyEdit(text, true);
      }
      // 棚号格离开时无条件重算一次显示：只点开又离开（没改）也要保证
      // 格子里显示的就是当前声明，不会留着上一轮的显示串
      if (wasShed) {
        this.recomputeFirstRow();
        this.version = this.version + 1;
      }
    } else {
      this.endShedEdit();
    }
    this.settleRowsAndPad([]);
  }

  // 数字键盘（自己画，不用系统输入法）：回车键不再由输入法处理，
  // 换格时键盘不会收起来再弹，也不会闪
  @Builder
  numKeypad() {
    Row() {
      // 左边 3 列数字，4 行
      Column() {
        Row() {
          this.padNum('1')
          this.padNum('2')
          this.padNum('3')
        }
        .width('100%')
        Row() {
          this.padNum('4')
          this.padNum('5')
          this.padNum('6')
        }
        .width('100%')
        Row() {
          this.padNum('7')
          this.padNum('8')
          this.padNum('9')
        }
        .width('100%')
        Row() {
          this.padNum('00')
          this.padNum('0')
          this.padFn('.', () => {
            this.padDot();
          })
        }
        .width('100%')
      }
      .layoutWeight(3)

      // 右边一列：退格、清空，下面是竖着占两行的「下一步」
      Column() {
        this.padFn('\u232B', () => {
          this.padBackspace();
        })
        this.padFn(t(this.lang, 'pad.clear'), () => {
          this.padClear();
        })
        Text(t(this.lang, 'pad.next'))
          .width('100%')
          .height(110)
          .margin(3)
          .fontSize('16vp')
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .backgroundColor('#2D8C42')
          .borderRadius(6)
          .onClick(() => {
            this.nextCell();
          })
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height(240)
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
    .backgroundColor('#ECECEC')
  }

  @Builder
  padNum(label: string) {
    Text(label)
      .layoutWeight(1)
      .height(52)
      .margin(3)
      .fontSize('22vp')
      .fontColor('#000000')
      .textAlign(TextAlign.Center)
      .backgroundColor(Color.White)
      .borderRadius(6)
      .onClick(() => {
        this.padInput(label);
      })
  }

  @Builder
  padFn(label: string, action: () => void) {
    Text(label)
      .layoutWeight(1)
      .width('100%')
      .height(52)
      .margin(3)
      .fontSize('18vp')
      .fontColor('#000000')
      .textAlign(TextAlign.Center)
      .backgroundColor('#D8D8D8')
      .borderRadius(6)
      .onClick(action)
  }

  private padInput(ch: string): void {
    const next: string = this.editorText + ch;
    this.applyPadText(next);
  }

  private padDot(): void {
    if (this.editingCol === 1) {
      return;
    }
    if (this.editorText.indexOf('.') >= 0) {
      return;
    }
    this.applyPadText(this.editorText + '.');
  }

  private padBackspace(): void {
    const t: string = this.editorText;
    this.applyPadText(t.length <= 1 ? '' : t.substring(0, t.length - 1));
  }

  private padClear(): void {
    this.applyPadText('');
  }

  private applyPadText(text: string): void {
    this.editorText = text;
    this.editingText = text;
    this.editLive(text);
  }

  private editableColumns(): number[] {
    const result: number[] = [];
    const fixed: number[] = this.fixedIndices();
    for (let i = 0; i < fixed.length; i++) {
      if (this.isEditableColumn(fixed[i])) {
        result.push(fixed[i]);
      }
    }
    const normal: number[] = this.normalIndices();
    for (let i = 0; i < normal.length; i++) {
      if (this.isEditableColumn(normal[i])) {
        result.push(normal[i]);
      }
    }
    return result;
  }

  // 「下一行」：相当于回车向下，同一列换到下一行
  private nextRowDown(): void {
    const now: number = Date.now();
    if (now - this.lastNextAt < 120) {
      return;
    }
    this.lastNextAt = now;
    // 跟点击格子同一套顺序规则：本行没填、下一行又是空行，就拦下来
    const nextRowIndex: number = this.editingRow + 1;
    const firstEmpty: number = this.firstEmptyRow();
    if (firstEmpty >= 0 && nextRowIndex > firstEmpty
      && nextRowIndex < this.rows.length && !this.rowHasInput(nextRowIndex)) {
      this.hintTitle = t(this.lang, 'order.title');
      this.hintMessage = t(this.lang, 'order.message').replace('%d', (firstEmpty + 1).toString());
      this.hintController.open();
      return;
    }
    if (this.editDirty) {
      this.applyEdit(this.editingText, true);
    }
    this.editDirty = false;
    const col: number = this.editingCol;
    let row: number = this.editingRow + 1;
    while (row < this.rows.length) {
      if (!this.isCellEnabled(this.rows[row], col)) {
        // 这列在下面某行不能编辑，就停在原处（跟安卓回车到头一样）
        return;
      }
      // 真正换格才结算：上面提前 return 时编辑还留在原格，不能清数据
      this.settleZeroRows();
      this.moveEditor(row, col);
      return;
    }
  }

  private nextCell(): void {
    const now: number = Date.now();
    if (now - this.lastNextAt < 120) {
      return;
    }
    this.lastNextAt = now;
    if (this.editDirty) {
      this.applyEdit(this.editingText, true);
    }
    this.editDirty = false;
    const cols: number[] = this.editableColumns();
    if (cols.length === 0) {
      return;
    }
    let row: number = this.editingRow;
    let pos: number = cols.indexOf(this.editingCol);
    if (pos < 0) {
      pos = 0;
    }
    // 一直往后找，跳过这一格不允许编辑的（对齐安卓：棚号/棚数没填时平均、料量都进不去）
    let guard: number = 0;
    const limit: number = cols.length * (this.rows.length + 1);
    while (guard < limit) {
      guard = guard + 1;
      pos = pos + 1;
      if (pos >= cols.length) {
        pos = 0;
        row = row + 1;
      }
      if (row >= this.rows.length) {
        return;
      }
      const target: number = cols[pos];
      if (this.isCellEnabled(this.rows[row], target)) {
        // 换到别的行时同样要守顺序规则：前面有空行、目标行又没数据，就拦住
        if (row !== this.editingRow) {
          const firstEmpty: number = this.firstEmptyRow();
          if (firstEmpty >= 0 && row > firstEmpty && !this.rowHasInput(row)) {
            this.hintTitle = t(this.lang, 'order.title');
            this.hintMessage = t(this.lang, 'order.message').replace('%d', (firstEmpty + 1).toString());
            this.hintController.open();
            return;
          }
        }
        this.settleZeroRows();
        this.moveEditor(row, target);
        return;
      }
    }
  }

  // 编辑器保持同一个节点、只换坐标和初值：不动焦点，键盘才不会收
  private moveEditor(row: number, column: number): void {
    this.overLimitWarned = false;
    this.editRow = row;
    this.editCol = column;
    this.editingSeed = this.currentValue(row, column);
    this.editingText = this.editingSeed;
    this.editorText = this.editingSeed;
    this.editingRow = row;
    this.editingCol = column;
    this.editorOpenedAt = Date.now();
    this.suppressChange = true;
    setTimeout(() => {
      this.suppressChange = false;
    }, 400);
    // 棚号格是系统输入框，新建节点后要主动要一次焦点，否则只是显示了框、键盘不弹
    if (column === 1) {
      setTimeout(() => {
        focusControl.requestFocus('cellEditor');
      }, 300);
      setTimeout(() => {
        focusControl.requestFocus('cellEditor');
      }, 700);
      setTimeout(() => {
        focusControl.requestFocus('cellEditor');
      }, 1200);
    }
    this.startCaret();
    this.ensureEditorVisible();
  }

  // 把正在编辑的格子滚进可视区（对齐安卓 keepEditingCellVisible）
  private ensureEditorVisible(): void {
    if (this.editingRow < 0 || this.editingCol < 0) {
      return;
    }
    const rowTop: number = this.editingRow * this.rh();
    if (rowTop < this.offsetY) {
      this.offsetY = rowTop;
    } else if (rowTop + this.rh() > this.offsetY + this.viewH) {
      this.offsetY = rowTop + this.rh() - this.viewH;
    }
    const x: number = this.columnLeft(this.editingCol);
    const w: number = this.cw(this.editingCol);
    if (!this.isFixed(this.editingCol)) {
      // 非固定列不能钻到冻结列底下（否则输入框会盖在“序号”上）
      const fw: number = this.frozenWidth();
      if (x < fw) {
        this.offsetX = this.offsetX - (fw - x);
      } else if (x + w > this.viewW) {
        this.offsetX = this.offsetX + (x + w - this.viewW);
      }
    }
    this.clampOffsets();
  }

  // 这一行是否已经有输入（棚号或棚数填过）
  private rowHasInput(r: number): boolean {
    const d: FeedData = this.rows[r];
    const sn: string = d.shedNumber === undefined || d.shedNumber === null ? '' : d.shedNumber;
    return sn.trim().length > 0 || d.shedCount > 0;
  }

  // 从第一行开始找第一行还没输入的
  private firstEmptyRow(): number {
    for (let i = 0; i < this.rows.length; i++) {
      if (!this.rowHasInput(i)) {
        return i;
      }
    }
    return -1;
  }

  // ===== 提示弹窗：顺序提示 / 棚号格式提示 =====

  private shedHintShown: boolean = false;
  private shedHintLoaded: boolean = false;

  private loadShedHintFlag(): void {
    if (this.shedHintLoaded) {
      return;
    }
    this.shedHintLoaded = true;
    try {
      const store = preferences.getPreferencesSync(getContext(this), { name: 'MixCalcPrefs' });
      this.shedHintShown = store.getSync('shed_hint_shown', false) as boolean;
    } catch (e) {
      this.shedHintShown = false;
    }
  }

  private markShedHintShown(): void {
    this.shedHintShown = true;
    try {
      const store = preferences.getPreferencesSync(getContext(this), { name: 'MixCalcPrefs' });
      store.putSync('shed_hint_shown', true);
      store.flush();
    } catch (e) {
    }
  }

  // 「请先填写第 N 行的棚号」：N 永远是最靠前的空行，不是被点的那一行
  private showOrderHint(): void {
    const firstEmpty: number = this.firstEmptyRow();
    if (firstEmpty < 0) {
      return;
    }
    this.hintTitle = t(this.lang, 'order.title');
    this.hintMessage = t(this.lang, 'order.message').replace('%d', (firstEmpty + 1).toString());
    this.hintSecondaryText = '';
    this.hintRefocus = false;
    this.hintController.open();
  }

  // 第一行棚号的格式提示：带「查看帮助」，关掉后把焦点还回输入框
  private showShedHint(): void {
    this.hintTitle = t(this.lang, 'shed.hintTitle');
    this.hintMessage = t(this.lang, 'shed.hintMessage').replace('%d', MAX_SHED_NUMBER.toString());
    this.hintSecondaryText = t(this.lang, 'btn.viewHelp');
    this.hintRefocus = true;
    this.hintController.open();
  }

  // 棚号超过上限：一边输一边提示，但同一次编辑只提示一次
  private warnOverLimit(): void {
    if (this.overLimitWarned) {
      return;
    }
    this.overLimitWarned = true;
    promptAction.showToast({
      message: t(this.lang, 'shed.overLimit').replace('%d', MAX_SHED_NUMBER.toString()),
      duration: 2000
    });
  }

  // 本行棚数对应的棚号（打点覆盖之后真正归本行的号码）
  private shedNumbersOf(rowIndex: number): number[] {
    if (rowIndex < 0 || rowIndex >= this.rows.length) {
      return [];
    }
    const texts: string[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      texts.push(this.rows[i].shedNumber);
    }
    const sets: number[][] = ownedSets(texts);
    return sets[rowIndex];
  }

  // 棚号块区域高度：按实际号码块宽（最多几位数）算每行能放几个
  private badgeAreaHeight(count: number, boxW: number, chipW: number): number {
    if (count <= 0) {
      return 0;
    }
    const usableW: number = Math.max(80, boxW - 12);
    const perRow: number = Math.max(1, Math.floor(usableW / (chipW + 2)));
    const rows: number = Math.max(1, Math.ceil(count / perRow));
    return rows * 30 + 18;
  }

  // 点「棚数」：在格子下沿弹出本行实际的棚号。
  // 打开条件（对齐安卓）：本行棚号有内容（哪怕棚数被后行盖成 0），或者有待转池要往这行转入；
  // 两者都没有就没什么可点的，不弹。
  private showShedList(rowIndex: number): void {
    if (rowIndex < 0 || rowIndex >= this.rows.length) {
      return;
    }
    const numbers: number[] = this.shedNumbersOf(rowIndex);
    const hasShedText: boolean = this.rows[rowIndex].getShedDisplay().trim().length > 0;
    const canTransferIn: boolean = this.hasPendingTransfer() && rowIndex !== this.pendingTransferSourceRow;
    if (numbers.length === 0 && !hasShedText && !canTransferIn) {
      return;
    }
    // 每次打开都是全新的选择态；待转池不受影响（它只在“关掉气泡却没转入”时作废）
    this.shedSelected = [];
    this.shedMenuOpen = false;
    this.shedListRow = rowIndex;
    // 号码块宽度随位数变化：1~2 位是 28vp 圆点，位数多了变胶囊
    // 13vp 粗体一个数字约 6vp 宽（实测 3 位数块宽 30vp），按 6.2 估偏保守一点
    let maxDigits: number = 1;
    for (let i = 0; i < numbers.length; i++) {
      const d: number = numbers[i].toString().length;
      if (d > maxDigits) {
        maxDigits = d;
      }
    }
    const chipW: number = Math.max(28, Math.ceil(maxDigits * 6.2) + 12);
    const maxW: number = Math.max(180, this.viewW - 16);
    const capW: number = Math.min(Math.max(200, this.viewW * 0.8), maxW);
    // 号码块按实际宽度紧凑排：左右只留 6vp，能多塞一个就多塞一个
    const needW: number = 12 + numbers.length * (chipW + 2);
    let w: number = Math.min(capW, Math.max(170, needW));
    const cellLeft: number = this.columnLeft(2);
    let x: number = Math.max(6, cellLeft);
    if (x + w > this.viewW - 4) {
      const fitW: number = this.viewW - x - 4;
      if (fitW >= 170) {
        w = fitW;
      } else {
        w = capW;
        x = Math.max(6, this.viewW - w - 4);
      }
    }
    // 没有棚号（被后行盖光 / 只等转入）时留一块空白位置放提示文字
    const badgeH: number = numbers.length === 0 ? 46 : this.badgeAreaHeight(numbers.length, w, chipW);
    const headH: number = 40;
    const contentH: number = headH + badgeH;
    // 上边贴住单元格下沿（表头高 + 行号*行高 - 滚动量）
    const cellBottom: number = this.hh() + (rowIndex + 1) * this.rh() - this.offsetY;
    const bodyBottom: number = this.hh() + this.viewH;
    const gap: number = 2;
    let y: number = cellBottom + gap;
    let scrollH: number = badgeH;
    const avail: number = bodyBottom - 8 - y;
    if (avail < contentH) {
      if (avail >= headH + 34) {
        // 弹窗高度最多到表尾行上沿：超出就内部滚动，不盖住表尾
        scrollH = Math.max(34, avail - headH);
      } else {
        // 贴着表尾时下面实在放不下，才整块翻到格子上方
        scrollH = badgeH;
        y = Math.max(8, cellBottom - this.rh() - contentH - gap);
      }
    }
    this.shedListNumbers = numbers;
    this.shedListTitleText = t(this.lang, 'shedList.title').replace('%d', (rowIndex + 1).toString());
    this.shedListCountText = t(this.lang, 'shedList.count').replace('%d', numbers.length.toString());
    this.shedListW = w;
    this.shedListX = x;
    this.shedListY = y;
    this.shedListScrollH = scrollH;
    this.shedListOpenedAt = Date.now();
    this.shedListOpen = true;
  }

  // ===== 气泡：号码块选中 / ⋮ 菜单 / 删除 / 转出 / 转入 =====

  private isShedSelected(n: number): boolean {
    return this.shedSelected.indexOf(n) >= 0;
  }

  // 号码块选中态：绿底黑字 ↔ 蓝底白字（对齐安卓 applyShedChipStyle）
  private toggleShedChip(n: number): void {
    const next: number[] = [];
    let found: boolean = false;
    for (let i = 0; i < this.shedSelected.length; i++) {
      if (this.shedSelected[i] === n) {
        found = true;
      } else {
        next.push(this.shedSelected[i]);
      }
    }
    if (!found) {
      next.push(n);
      next.sort((a: number, b: number): number => a - b);
    }
    this.shedSelected = next;
  }

  // ⋮ 菜单：全选 / 反选 / 删除 / 转出 / 转入
  private openShedMenu(): void {
    const labels: string[] = [];
    const actions: number[] = [];
    actions.push(SHED_ACTION_SELECT_ALL);
    labels.push(t(this.lang, 'shed.selectAll'));
    actions.push(SHED_ACTION_SELECT_INVERT);
    labels.push(t(this.lang, 'shed.invert'));
    if (this.shedSelected.length > 0) {
      actions.push(SHED_ACTION_DELETE);
      labels.push(t(this.lang, 'shed.delete'));
      actions.push(SHED_ACTION_TRANSFER_OUT);
      labels.push(t(this.lang, 'shed.transferOut'));
    }
    // 转入：只要不是来源行自己，上下都能转——
    // 往下转靠后行优先压过来；往上转靠把来源行的单号删掉，号码自动退回给上面的行
    if (this.hasPendingTransfer() && this.shedListRow !== this.pendingTransferSourceRow) {
      actions.push(SHED_ACTION_TRANSFER_IN);
      labels.push(t(this.lang, 'shed.transferIn'));
    }
    const itemH: number = 40;
    const menuW: number = Math.max(150, Math.min(220, this.shedListW));
    let x: number = this.shedListX + this.shedListW - menuW;
    if (x < 6) {
      x = 6;
    }
    // 菜单右边缘跟气泡右边缘对齐，上边贴住气泡表头下沿
    let y: number = this.shedListY + 40;
    const menuH: number = labels.length * itemH + 8;
    if (y + menuH > this.viewH - 4) {
      y = Math.max(8, this.shedListY - menuH - 4);
    }
    this.shedMenuW = menuW;
    this.shedMenuLabels = labels;
    this.shedMenuActions = actions;
    this.shedMenuX = x;
    this.shedMenuY = y;
    this.shedMenuOpen = true;
  }

  private handleShedMenuAction(action: number): void {
    this.shedMenuOpen = false;
    const row: number = this.shedListRow;
    if (row < 0 || row >= this.rows.length) {
      return;
    }
    if (action === SHED_ACTION_SELECT_ALL || action === SHED_ACTION_SELECT_INVERT) {
      const all: boolean = action === SHED_ACTION_SELECT_ALL;
      const next: number[] = [];
      for (let i = 0; i < this.shedListNumbers.length; i++) {
        const n: number = this.shedListNumbers[i];
        if (all || !this.isShedSelected(n)) {
          next.push(n);
        }
      }
      this.shedSelected = next;
      return;
    }
    if (action === SHED_ACTION_DELETE) {
      this.confirmDeleteShedNumbers(row);
      return;
    }
    if (action === SHED_ACTION_TRANSFER_OUT) {
      // 只把号码记进待转池，来源行的数据一个字都不改，气泡直接关掉
      this.startPendingTransfer(row, this.shedSelected);
      this.shedListOpen = false;
      return;
    }
    if (action === SHED_ACTION_TRANSFER_IN) {
      this.shedListOpen = false;
      this.applyTransferIn(row);
    }
  }

  private startPendingTransfer(row: number, numbers: number[]): void {
    if (numbers.length === 0) {
      return;
    }
    this.pendingTransferNumbers = numbers.slice();
    this.pendingTransferSourceRow = row;
  }

  // 删除 = 这些棚卖了：从本行的棚号里剔掉（区间该拆就拆），然后整表重算。
  // 「有地方退就退」：上面某行还申明着的号，只从本行申明里拿掉，号立刻退回上行继续算料；
  // 「没地方退就等于删除」：别的行都没有它，本行剔掉就是全表消失。
  private confirmDeleteShedNumbers(row: number): void {
    const targets: number[] = this.shedSelected.slice();
    if (targets.length === 0) {
      return;
    }
    // 点了删除就不是转入这条路，待转池作废
    this.clearPendingTransfer();
    const declared: string[] = this.snapshotShedTexts();
    const plan: ShedDeletePlan = ShedDeletePlan.of(declared, row, targets);
    this.shedDeleteRow = row;
    this.shedDeleteTargets = targets;
    this.shedDeleteMessage = this.buildShedDeleteMessage(plan);
    this.shedDeleteController.open();
  }

  /**
   * 删除确认框的正文：说清楚“会退回上面”和“真被删掉”各有多少个，
   * 后半段把要真删的号码点名（升序、连号收区间），用户才知道自己删掉的是什么。
   */
  private buildShedDeleteMessage(plan: ShedDeletePlan): string {
    const fallback: number = plan.fallback.length;
    const permanent: number = plan.permanent.length;
    if (permanent > 0 && fallback > 0) {
      return t(this.lang, 'shed.deleteMsgMixed')
        .replace('%d', (fallback + permanent).toString())
        .replace('%d', fallback.toString())
        .replace('%d', permanent.toString())
        .replace('%s', this.compactNumberList(plan.permanent));
    }
    if (permanent > 0) {
      return t(this.lang, 'shed.deleteMsgPermanent')
        .replace('%d', permanent.toString())
        .replace('%s', this.compactNumberList(plan.permanent));
    }
    return t(this.lang, 'shed.deleteMsgFallback').replace('%d', fallback.toString());
  }

  // 号码列表压成一行；太长就只列前 12 个，别把确认框撑出屏幕
  private compactNumberList(numbers: number[]): string {
    if (numbers.length === 0) {
      return '';
    }
    const full: string = normalizeShedNumbers(numbers);
    if (full.length <= 80) {
      return full;
    }
    const head: number[] = [];
    const take: number = Math.min(12, numbers.length);
    for (let i = 0; i < take; i++) {
      head.push(numbers[i]);
    }
    const suffix: string = this.lang === 'en' ? ' … (%d total)' : ' …（共 %d 个）';
    return normalizeShedNumbers(head) + suffix.replace('%d', numbers.length.toString());
  }

  private applyDeleteShedNumbers(): void {
    const rowIndex: number = this.shedDeleteRow;
    const targets: number[] = this.shedDeleteTargets;
    this.shedDeleteRow = -1;
    this.shedDeleteTargets = [];
    if (rowIndex < 0 || rowIndex >= this.rows.length) {
      return;
    }
    const data: FeedData = this.rows[rowIndex];
    this.shedListOpen = false;
    const oldText: string = data.shedNumber;
    const newText: string = removeShedNumbers(oldText, targets);
    if (newText !== oldText) {
      this.commitShedText(rowIndex, newText);
    }
    // 号删光了：这行既没棚号也没棚数，它就是一张废纸，整行回收，
    // 下面的行往上顶，底部补空行
    const emptied: number[] = [];
    if (data.shedNumber.trim().length === 0 && data.shedCount <= 0) {
      emptied.push(this.rows.indexOf(data));
    }
    this.settleRowsAndPad(emptied);
  }

  // 转入：号码池的作用就是任意行之间随便转，上下都要能走通。
  //   往下转：来源行一个字都不用动——目标行在下面，后行优先自然把这批号压过去。
  //   往上转：来源行必须真的松手，单号直接删；号在连续段里只能把这段拆开
  //          （20-30 去 25 → 20-24 26-30），拆完自动退回给包着它的上一行。
  private applyTransferIn(targetRow: number): void {
    if (!this.hasPendingTransfer() || targetRow === this.pendingTransferSourceRow) {
      this.clearPendingTransfer();
      return;
    }
    const numbers: number[] = this.pendingTransferNumbers.slice();
    const sourceRow: number = this.pendingTransferSourceRow;
    if (targetRow < 0 || targetRow >= this.rows.length || sourceRow < 0 || sourceRow >= this.rows.length) {
      this.clearPendingTransfer();
      return;
    }
    const target: FeedData = this.rows[targetRow];
    const source: FeedData = this.rows[sourceRow];
    const oldTarget: string = target.shedNumber;
    const oldSource: string = source.shedNumber;
    const sourceHadContent: boolean = oldSource.trim().length > 0;
    const targetHadContent: boolean = oldTarget.trim().length > 0;

    // 防呆：整行的号全转给一个空行，等于只是把整行往下挪一格（来源行被回收、下面整体上移），
    // 屏幕闪一下却什么都没变——直接不让转；目标行不是空的（真合并）才照常转。
    if (pointlessWholeRowMove(oldTarget, this.shedNumbersOf(sourceRow), numbers)) {
      promptAction.showToast({
        message: t(this.lang, 'shed.transferWholeToBlank'),
        duration: 2500
      });
      this.clearPendingTransfer();
      return;
    }

    // 文本改写分两个方向，差别只在「来源行要不要留原文」：
    //   往下转（来源在上）：后行优先，这批号本来就归目标行，来源行原文一个字都不用改——
    //     原文留在来源行就是「这些号从哪来」的账，目标行以后清空/删除时号能自动退回去。
    //   往上转（来源在下）：来源行必须真的松手，否则它还在下面压着，号根本没走。
    const moved: string[] = targetRow > sourceRow
      ? giveDown(oldSource, oldTarget, numbers)
      : transfer(oldSource, oldTarget, numbers);

    // 先把池子清掉，后面可能弹提示，别让池子停在半路
    this.clearPendingTransfer();

    this.commitShedText(sourceRow, moved[0]);
    this.commitShedText(targetRow, moved[1]);

    // 注意：这里绝不能把两行文本重写成「只留实际占有的号」（Android 的 rewriteToOwned）。
    // 那样会把来源行里「被下行占走的号」从声明中抹掉，等于销毁来路账本——
    // 目标行日后一清空，这些号就成了「没来路」，会被 ShedDeletePlan 判成真删而彻底消失。
    this.forceRecomputeRows([sourceRow, targetRow]);

    // 一次算齐所有该回收的行：被转空的两行 + 别的死行（幽灵号清掉后露出来的），
    // 一起删、一次上顶。分两次删会让用户看到“先进一行、再进一行”。
    const emptied: number[] = [];
    if (target.shedCount <= 0 && targetHadContent) {
      const tIdx: number = this.rows.indexOf(target);
      if (tIdx >= 0) {
        emptied.push(tIdx);
      }
    }
    if (source.shedCount <= 0 && sourceHadContent) {
      const sIdx: number = this.rows.indexOf(source);
      if (sIdx >= 0 && emptied.indexOf(sIdx) < 0) {
        emptied.push(sIdx);
      }
    }
    this.settleRowsAndPad(emptied);
  }

  // 一次动好几行的操作（转入）收尾用：先跑打点覆盖，再把参与的行强制重算一遍派生值
  private forceRecomputeRows(rowIndexes: number[]): void {
    this.applyShedCoverage();
    for (let i = 0; i < rowIndexes.length; i++) {
      const r: number = rowIndexes[i];
      if (r >= 0 && r < this.rows.length) {
        this.rows[r].updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
      }
    }
    this.version = this.version + 1;
    this.onChanged();
  }

  // 提交一格的棚号文本（对齐安卓 commitCell(row, "shed_number", text)）
  private commitShedText(rowIndex: number, text: string): void {
    if (rowIndex < 0 || rowIndex >= this.rows.length) {
      return;
    }
    const row: FeedData = this.rows[rowIndex];
    const value: string = text.trim();
    const oldCount: number = row.shedCount;
    const oldAverage: number = row.average;
    row.setShedNumber(value);
    if (row.shedCount !== oldCount && oldAverage > 0 && row.canEditAverage()) {
      row.setAverageManually(oldAverage, this.fermentedInAverage);
    }
    this.applyShedCoverage();
    row.updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    this.version = this.version + 1;
    this.onChanged();
  }

  private openEditor(row: number, column: number): void {
    if (row < 0 || row >= this.rows.length) {
      return;
    }
    // 棚数是按钮：点开看本行实际的棚号列表，不进编辑、不弹键盘
    if (column === 2) {
      // 点按钮也是离开当前编辑格：先记对象，结算可能回收行，行下标会平移
      const targetRef: FeedData = this.rows[row];
      this.finishEdit();
      const targetIdx: number = this.rows.indexOf(targetRef);
      if (targetIdx < 0) {
        return;
      }
      this.showShedList(targetIdx);
      return;
    }
    if (!this.isEditableColumn(column)) {
      return;
    }
    // 待转池有号码时，除了「点另一行的棚数格」（上面已 return），任何一次落到格子上都把池子作废
    if (this.hasPendingTransfer()) {
      this.clearPendingTransfer();
    }
    if (!this.isCellEnabled(this.rows[row], column)) {
      return;
    }
    // 只能从上往下按顺序填，但只拦“空行”：
    // 中间某行被清空后，后面已经有数据的行照样能改，不会把人挡死
    const firstEmpty: number = this.firstEmptyRow();
    if (firstEmpty >= 0 && row > firstEmpty && !this.rowHasInput(row)) {
      this.showOrderHint();
      return;
    }
    // 第一次点第一行「棚号」：先告诉用户怎么填（只提示一次）
    if (row === 0 && column === 1) {
      this.loadShedHintFlag();
      if (!this.shedHintShown) {
        this.markShedHintShown();
        this.showShedHint();
      }
    }
    // 已经在编辑这一格：只把焦点抢回来，不重置文本
    if (this.editingRow === row && this.editingCol === column) {
      focusControl.requestFocus('cellEditor');
      return;
    }
    // 换格前先把上一格提交掉（对齐安卓 commitInternal，键盘不闪）
    const targetRef: FeedData = this.rows[row];   // 结算可能删行，先记住对象
    if (this.shedEditActive) {
      this.endShedEdit();
    }
    if (this.editingRow >= 0 && this.editDirty) {
      this.applyEdit(this.editingText, true);
    }
    this.editDirty = false;
    // 换格 = 上一格失焦：先结算死行并补空行，再打开新格
    this.settleRowsAndPad([]);
    const targetIdx: number = this.rows.indexOf(targetRef);
    if (targetIdx < 0) {
      return;   // 这一行自己刚被回收，不要再往它上面开编辑器
    }
    row = targetIdx;
    this.overLimitWarned = false;
    this.editRow = row;
    this.editCol = column;
    this.editorTitle = this.headLabel(column) + ' · ' + t(this.lang, 'dlg.row').replace('%d', (row + 1).toString());
    this.editorValue = this.currentValue(row, column);
    this.editorIsNumber = column !== 1;
    this.editingSeed = this.currentValue(row, column);
    this.editingText = this.editingSeed;
    this.editorText = this.editingSeed;
    this.editingRow = row;
    this.editingCol = column;
    this.editorOpenedAt = Date.now();
    this.suppressChange = true;
    setTimeout(() => {
      this.suppressChange = false;
    }, 400);
    setTimeout(() => {
      focusControl.requestFocus('cellEditor');
    }, 60);
    this.startCaret();
    this.ensureEditorVisible();
    // 棚号格：拍下全表声明快照，之后每敲一个字符都从快照重推
    if (column === 1) {
      this.beginShedEdit(row);
    }
  }

  // ===== 列操作菜单 =====
  // 列菜单和水比/发酵料弹窗共用同一个宽度（与安卓 listPopupWidth 一致）
  private listPopupWidth(): number {
    return Math.min(200, this.viewW);
  }

  // 弹窗右边缘对齐被点的表头单元格（安卓 P1），靠左的列夹到 0，靠右的列不超出屏幕
  private popupXFor(col: number, popupWidth: number): number {
    return rightAlignedX(this.columnLeft(col) + this.cw(col), popupWidth, this.viewW);
  }

  private showColumnMenu(index: number): void {
    if (index === 0) {
      return;
    }
    this.finishEdit();
    const fixed: boolean = this.isFixed(index);
    const visible: boolean = this.isVisible(index);
    this.colMenuIndex = index;
    this.colMenuTitle = t(this.lang, 'dlg.colOps').replace('%s', this.headLabel(index));
    this.colMenuItems = [
      fixed ? t(this.lang, 'col.unfix') : t(this.lang, 'col.fix'),
      visible ? t(this.lang, 'col.hide') : t(this.lang, 'col.show'),
      t(this.lang, 'col.showAll'),
      t(this.lang, 'col.unfixAllCols')
    ];
    this.colMenuX = this.popupXFor(index, this.listPopupWidth());
    this.colMenuOpenedAt = Date.now();
    this.colMenuOpen = true;
  }

  private handleColumnChoice(choice: number): void {
    const index: number = this.colMenuIndex;
    this.colMenuOpen = false;
    if (index < 0) {
      return;
    }
    const vis: boolean[] = [];
    for (let i = 0; i < COLUMN_IDS.length; i++) {
      vis.push(i === 0 ? true : (this.vis.length > i ? this.vis[i] : true));
    }
    const fix: boolean[] = [];
    for (let i = 0; i < COLUMN_IDS.length; i++) {
      fix.push(i === 0 ? true : (this.fix.length > i ? this.fix[i] : false));
    }
    if (choice === 0) {
      fix[index] = !fix[index];
    } else if (choice === 1) {
      vis[index] = !vis[index];
    } else if (choice === 2) {
      for (let i = 1; i < vis.length; i++) {
        vis[i] = true;
      }
    } else if (choice === 3) {
      for (let i = 1; i < fix.length; i++) {
        fix[i] = false;
      }
    }
    this.vis = vis;
    this.fix = fix;
    this.onColumnAction('sync', index, this.vis, this.fix);
  }

  // ===== 水 / 发酵料 =====
  private showWaterPicker(col: number): void {
    this.finishEdit();
    const items: string[] = [];
    for (let pct = 10; pct <= 40; pct += 5) {
      const label: string = t(this.lang, 'col.water') + pct.toString() + '%';
      items.push(pct === this.waterPercentage ? label + ' ✓' : label);
    }
    this.pickKind = 'water';
    this.pickTitle = t(this.lang, 'water.title');    this.pickItems = items;
    this.pickX = this.popupXFor(col, this.listPopupWidth());
    this.pickOpenedAt = Date.now();
    this.pickOpen = true;
  }

  private showFermentPicker(col: number): void {
    this.finishEdit();
    this.pickKind = 'ferment';
    this.pickTitle = t(this.lang, 'ferment.title');
    this.pickItems = [
      (this.fermentedInWater ? '● ' : '○ ') + t(this.lang, 'ferment.inWater'),
      (this.fermentedInWater ? '○ ' : '● ') + t(this.lang, 'ferment.exWater'),
      (this.fermentedInAverage ? '● ' : '○ ') + t(this.lang, 'ferment.inAvg'),
      (this.fermentedInAverage ? '○ ' : '● ') + t(this.lang, 'ferment.exAvg')
    ];
    this.pickX = this.popupXFor(col, this.listPopupWidth());
    this.pickOpenedAt = Date.now();
    this.pickOpen = true;
  }

  private applyPick(index: number): void {
    this.pickOpen = false;
    if (this.pickKind === 'water') {
      this.onWaterChange(10 + index * 5);
    } else if (this.pickKind === 'ferment') {
      this.onFermentChange(index);
    }
  }

  // ===== 换料比例 =====
  private openRatio(row: number, column: number): void {
    const data: FeedData = this.rows[row];
    if (!this.isCellEnabled(data, column) || column < 5 || column > 8) {
      return;
    }
    if (!this.isSwitchTargetCell(data, column)) {
      return;
    }
    // 弹菜单前先收起单元格编辑，不然输入框会压在菜单上面
    this.finishEdit();
    this.ratioRow = row;
    this.ratioCurrent = data.switchRatio;
    const maxX: number = Math.max(0, this.viewW - 160);
    this.ratioX = Math.max(0, Math.min(this.columnLeft(column), maxX));
    this.ratioY = Math.min((row + 1) * this.rh() - this.offsetY, Math.max(0, this.viewH - 260));
    this.ratioOpenedAt = Date.now();
    this.ratioOpen = true;
  }

  private selectRatio(ratio: number): void {
    if (this.ratioRow < 0) {
      return;
    }
    const data: FeedData = this.rows[this.ratioRow];
    data.switchRatio = ratio;
    const avg: number = data.average;
    if (!data.isAverageManuallyModified && avg > 0) {
      data.average = avg;
      data.isAverageManuallyModified = true;
    }
    if (this.ratioRow !== 0) {
      data.recalculateDerivedOnly(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    }
    this.recomputeFirstRow();
    this.ratioOpen = false;
    this.version = this.version + 1;
    this.onChanged();
  }

  // ===== 表尾与重置 =====
  private sumColumn(column: number): number {
    let s: number = 0;
    for (let i = 0; i < this.rows.length; i++) {
      const r: FeedData = this.rows[i];
      if (column === 2) {
        s += r.shedCount;
        continue;
      }
      // 棚数被后面的行覆盖成 0 的行不参与料/水合计，否则重叠棚的料会算两遍
      if (r.shedCount <= 0) {
        continue;
      }
      switch (column) {
        case 4: s += r.fermented; break;
        case 5: s += r.powder; break;
        case 6: s += r.feed03; break;
        case 7: s += r.feed05; break;
        case 8: s += r.feed10; break;
        case 9: s += r.water; break;
        default: break;
      }
    }
    return s;
  }

  private filledRows(): number {
    let n: number = 0;
    for (let i = 0; i < this.rows.length; i++) {
      if (this.rows[i].shedCount > 0) {
        n++;
      }
    }
    return n;
  }

  private weightedAverage(): number {
    let sheds: number = 0;
    let total: number = 0;
    for (let i = 0; i < this.rows.length; i++) {
      const r: FeedData = this.rows[i];
      if (r.average > 0 && r.shedCount > 0) {
        sheds += r.shedCount;
        total += r.average * r.shedCount;
      }
    }
    return sheds > 0 ? total / sheds : 0;
  }

  private footerText(c: number): string {
    switch (c) {
      case 0: return this.filledRows().toString() + '/' + this.rows.length.toString();
      case 1: return t(this.lang, 'footer.help');
      case 3: {
        const avg: number = Math.round(this.weightedAverage() * 100) / 100;
        return avg === 0 ? '0' : this.formatNumber(avg);
      }
      case 10: return t(this.lang, 'footer.reset');
      default: {
        // 表尾的料/水列没数据也要显示 0，不能留空
        const sum: number = Math.round(this.sumColumn(c) * 100) / 100;
        return sum === 0 ? '0' : this.formatNumber(sum);
      }
    }
  }

  private footerCellBg(c: number): string {
    if (c === 1) {
      return '#000042';
    }
    if (c === 10) {
      return '#960018';
    }
    return '#EAF3EC';
  }

  private footerColor(c: number): string {
    if (c === 1 || c === 10) {
      return '#FFFFFF';
    }
    return '#1F6B30';
  }

  private confirmReset(): void {
    const filled: number = this.filledRows();
    this.resetMessage = filled > 0
      ? t(this.lang, 'dlg.resetHas').replace('%d', filled.toString())
      : t(this.lang, 'dlg.resetNone');
    this.resetController.open();
  }

  private resetAll(): void {
    for (let i = 0; i < this.rows.length; i++) {
      this.clearRowData(this.rows[i], true);
    }
    // 清完必须重跑一遍打点覆盖：显示串、棚数、派生值全部归零，
    // 否则棚号格会留着上一轮的显示文本
    this.endShedEdit();
    this.applyShedCoverage();
    for (let i = 0; i < this.rows.length; i++) {
      this.rows[i].updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    }
    this.settleRowsAndPad([]);
    this.version = this.version + 1;
    this.onChanged();
  }

  // ===== 滚动 =====
  private stopFling(): void {
    if (this.flingTimer !== -1) {
      clearInterval(this.flingTimer);
      this.flingTimer = -1;
    }
  }

  private startFling(vx: number, vy: number): void {
    this.stopFling();
    let velocityX: number = vx;
    let velocityY: number = vy;
    if (Math.abs(velocityX) < 60 && Math.abs(velocityY) < 60) {
      return;
    }
    let lastTime: number = Date.now();
    this.flingTimer = setInterval(() => {
      const now: number = Date.now();
      const dt: number = Math.min(0.05, (now - lastTime) / 1000);
      lastTime = now;
      const decay: number = Math.exp(-4.5 * dt);
      velocityX *= decay;
      velocityY *= decay;

      let nextX: number = this.offsetX - velocityX * dt;
      let nextY: number = this.offsetY - velocityY * dt;
      const maxX: number = this.maxOffsetX();
      const maxY: number = this.maxOffsetY();
      if (nextX <= 0 || nextX >= maxX) {
        velocityX = 0;
        nextX = Math.min(Math.max(0, nextX), maxX);
      }
      if (nextY <= 0 || nextY >= maxY) {
        velocityY = 0;
        nextY = Math.min(Math.max(0, nextY), maxY);
      }
      this.offsetX = nextX;
      this.offsetY = nextY;
      if (Math.abs(velocityX) < 15 && Math.abs(velocityY) < 15) {
        this.stopFling();
      }
    }, 16);
  }

  aboutToDisappear(): void {
    this.stopFling();
    this.stopCaret();
  }

  onRefreshTick(): void {
    // 只刷新显示，不重算料量（用于“参与算料”切换：平均变了、料量不变）
    this.version = this.version + 1;
  }

  onSettingsChanged(): void {
    for (let i = 0; i < this.rows.length; i++) {
      this.rows[i].updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    }
    this.recomputeFirstRow();
    this.version = this.version + 1;
  }

  aboutToAppear(): void {
    if (this.initVisible.length > 0) {
      this.vis = this.initVisible;
    }
    if (this.initFixed.length > 0) {
      this.fix = this.initFixed;
    }
    for (let i = 0; i < this.rows.length; i++) {
      this.rows[i].updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    }
    this.recomputeFirstRow();
    // 载入后清一次历史脏数据：棚数为 0 却还留着料的，按新行处理
    this.settleZeroRows();
  }

  @Builder
  cellView(row: FeedData, col: number, r: number) {
    Text(this.cellText(row, col, r))
      .width(this.cw(col))
      .height(this.rh())
      // 棚号列用小一号的固定字号：9 字符一行要整行露出来，跟安卓一样不随内容缩放
      .fontSize(col === 1 ? this.fsShed() : this.fs())
      .fontWeight(FontWeight.Bold)
      .fontColor(this.cellColor(col))
      .textAlign(TextAlign.Center)
      // 棚号列两行：行高 15 → 共 30vp，放进 40vp 行高；单行文本也居中
      .lineHeight(col === 1 ? 15 : 18)
      .maxLines(col === 1 ? 2 : 1)
      .textOverflow({ overflow: col === 1 ? TextOverflow.Clip : TextOverflow.Ellipsis })
      .backgroundColor(this.cellFill(row, col, r))
      .border({ width: 0.5, color: this.cellBorderColor(row, col, r) })
      .onClick(() => {
        this.openEditor(r, col);
      })
      .gesture(
        LongPressGesture({ duration: 350 })
          .onAction(() => {
            this.openRatio(r, col);
          })
      )
  }

  @Builder
  headerCell(col: number) {
    Text(this.headLabel(col))
      .width(this.cw(col))
      .height(this.hh())
      .fontSize(this.fsHeader())
      .fontWeight(FontWeight.Bold)
      .fontColor('#000000')
      .textAlign(TextAlign.Center)
      .maxLines(1)
      // 表头默认乳白；只有发酵料表头按“参与算水”上浅绿，“参与算料”加粗棕边
      .backgroundColor(col === 4 && this.fermentedInWater ? '#F0F8F0' : '#FFFFFF')
      .border({
        width: col === 4 && this.fermentedInAverage ? 3 : 0.5,
        color: col === 4 && this.fermentedInAverage ? '#6E511E' : '#000000'
      })
      .onClick(() => {
        if (col === 9) {
          this.showWaterPicker(col);
        } else if (col === 4) {
          this.showFermentPicker(col);
        }
      })
      .gesture(
        LongPressGesture({ duration: 350 })
          .onAction(() => {
            this.showColumnMenu(col);
          })
      )
  }

  @Builder
  footerCell(col: number) {
    Text(this.footerText(col))
      .width(this.cw(col))
      .height(this.rh())
      .fontSize(this.fs())
      .fontWeight(FontWeight.Bold)
      .fontColor(this.footerColor(col))
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .backgroundColor(this.footerCellBg(col))
      .border({ width: 0.5, color: '#000000' })
      .onClick(() => {
        if (col === 1) {
          this.onHelp();
        } else if (col === 10) {
          this.confirmReset();
        }
      })
  }

  build() {
    Stack() {
      Column() {
        // 表头
        Stack({ alignContent: Alignment.TopStart }) {
          Row() {
            ForEach(this.normalIndices(), (col: number) => {
              this.headerCell(col)
            }, (col: number) => 'h' + col.toString() + '_' + this.version.toString())
          }
          .position({ x: this.frozenWidth() - this.offsetX, y: 0 })

          Row() {
            ForEach(this.fixedIndices(), (col: number) => {
              this.headerCell(col)
            }, (col: number) => 'hf' + col.toString() + '_' + this.version.toString())
          }
          .zIndex(1)
        }
        .width('100%')
        .height(this.hh())
        .backgroundColor('#FFFFFF')
        .clip(true)

        // 表体
        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            ForEach(this.rows, (row: FeedData, r: number) => {
              Row() {
                ForEach(this.normalIndices(), (col: number) => {
                  this.cellView(row, col, r)
                }, (col: number) => 'c' + r.toString() + '_' + col.toString() + '_' + this.version.toString())
              }
              .height(this.rh())
            }, (row: FeedData, r: number) => 'row' + r.toString() + '_' + this.version.toString())
          }
          .width(this.normalWidth())
          .position({ x: this.frozenWidth() - this.offsetX, y: -this.offsetY })

          Column() {
            ForEach(this.rows, (row: FeedData, r: number) => {
              Row() {
                ForEach(this.fixedIndices(), (col: number) => {
                  this.cellView(row, col, r)
                }, (col: number) => 'f' + r.toString() + '_' + col.toString() + '_' + this.version.toString())
              }
              .height(this.rh())
            }, (row: FeedData, r: number) => 'frow' + r.toString() + '_' + this.version.toString())
          }
          .width(this.frozenWidth())
          .position({ x: 0, y: -this.offsetY })
          .zIndex(1)
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(Color.White)
        .clip(true)
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.applyViewSize(Number(newValue.width), Number(newValue.height));
        })
        .gesture(
          PanGesture()
            .onActionStart(() => {
              this.stopFling();
              this.lastPanX = 0;
              this.lastPanY = 0;
            })
            .onActionUpdate((event: GestureEvent) => {
              const dx: number = event.offsetX - this.lastPanX;
              const dy: number = event.offsetY - this.lastPanY;
              this.lastPanX = event.offsetX;
              this.lastPanY = event.offsetY;
              this.offsetX -= dx;
              this.offsetY -= dy;
              this.clampOffsets();
            })
            .onActionEnd((event: GestureEvent) => {
              this.startFling(event.velocityX, event.velocityY);
            })
        )

        // 表尾
        Stack({ alignContent: Alignment.TopStart }) {
          Row() {
            ForEach(this.normalIndices(), (col: number) => {
              // 「重置」单独钉在屏幕右边缘，不跟着表格横向滚动走
              if (col !== 10) {
                this.footerCell(col)
              }
            }, (col: number) => 'f' + col.toString() + '_' + this.version.toString())
          }
          .position({ x: this.frozenWidth() - this.offsetX, y: 0 })

          Row() {
            ForEach(this.fixedIndices(), (col: number) => {
              this.footerCell(col)
            }, (col: number) => 'ff' + col.toString() + '_' + this.version.toString())
          }
          .zIndex(1)

          // 重置：跟着表格滚动时会被推到屏幕外（只露一条边），点都点不到。
          // 钉死在右边缘，永远可点。
          Row() {
            this.footerCell(10)
          }
          .position({ x: Math.max(0, this.viewW - this.cw(10)), y: 0 })
          .zIndex(2)
        }
        .width('100%')
        .height(this.rh())
        .backgroundColor('#EAF3EC')
        .clip(true)

      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
      .gesture(
        PanGesture()
          .onActionStart(() => {
            this.stopFling();
            this.lastPanX = 0;
            this.lastPanY = 0;
          })
          .onActionUpdate((event: GestureEvent) => {
            const dx: number = event.offsetX - this.lastPanX;
            const dy: number = event.offsetY - this.lastPanY;
            this.lastPanX = event.offsetX;
            this.lastPanY = event.offsetY;
            this.offsetX -= dx;
            this.offsetY -= dy;
            this.clampOffsets();
          })
          .onActionEnd((event: GestureEvent) => {
            this.startFling(event.velocityX, event.velocityY);
          })
      )

      // 单元格编辑器：放在最外层 Stack（和表体平级），
      // 表体重排不会重建它，焦点和键盘才稳；坐标自己按 表头高 + 行号*行高 - 滚动量 算
      // 单元格编辑器：全表唯一，和最外层 Stack 平级（表体重排不会重建它）
      // 统一用系统输入法（搜狗/小艺都行，平板上也稳），数字列只允许数字和小数点
      if (this.editingRow >= 0 && this.editingCol >= 0) {
        TextInput({ text: this.editorText, controller: this.editorCtrl })
          .id('cellEditor')
          .type(this.editingCol === 1 ? InputType.Normal : InputType.NUMBER_DECIMAL)
          // 棚号列白名单：数字 + 能解析的分隔/区间符号（到 至 ~ — 、 ， , 空格 号 -），
          // 其它字符（字母、汉字、表情等）一律打不进去；数字列只收数字和小数点
          .inputFilter(this.editingCol === 1 ? '[0-9\\-到至~—、，, 号]' : '[0-9.]')
          .width(this.cw(this.editingCol))
          .height(this.rh())
          .fontSize(this.fs())
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .padding(0)
          .borderRadius(0)
          .backgroundColor(Color.White)
          .border({ width: 1.5, color: '#2D8C42' })
          .caretColor('#2D8C42')
          .position({
            x: this.editorX(),
            y: this.hh() + this.editingRow * this.rh() - this.offsetY
          })
          .defaultFocus(true)
          .focusable(true)
          .enableKeyboardOnFocus(true)
          .enterKeyType(EnterKeyType.Next)
          .onChange((text: string) => {
            this.editingText = text;
            this.editorText = text;
            if (this.suppressChange) {
              this.suppressChange = false;
              return;
            }
            this.editLive(text);
          })
          .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
            // 保持编辑态，输入法就不会因为“提交”动作把键盘收起来
            event.keepEditableState();
            this.nextCell();
          })
          .onBlur(() => {
            if (Date.now() - this.editorOpenedAt < 400) {
              return;
            }
            this.finishEdit();
          })

        // 自己的「下一行」按钮：相当于回车向下，同一列下一行
        // 只在键盘弹起时显示（键盘收起就跟着隐藏，与安卓一致）
        // 自绘：Row 的 alignItems(VerticalAlign.Center) 负责上下居中，
        // 不再依赖 Text 固定高度时的字体基线（否则文字看着会偏下）；
        // 小三角也用 Polygon 画，避免 ▾ 字符自带基线再次把文字顶偏。
        if (this.kbVisible) {
          Row({ space: 4 }) {
            Text(t(this.lang, 'pad.nextRow'))
              .fontSize('13vp')
              .fontColor(Color.White)
              .maxLines(1)
            Polygon({ width: 7, height: 5 })
              .points([[0, 0], [7, 0], [3.5, 5]])
              .fill(Color.White)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .width(84)
          .height(30)
          .backgroundColor('#2D8C42')
          .borderRadius(15)
          .position({
            x: Math.max(4, this.viewW - 92),
            y: this.hh() + Math.max(0, this.viewH - 38)
          })
          .zIndex(9)
          .onClick(() => {
            this.nextRowDown();
          })
        }
      }

      // 列操作菜单
      if (this.colMenuOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            // 长按松手那一下不要立刻把刚弹出来的菜单点掉
            if (Date.now() - this.colMenuOpenedAt < 450) {
              return;
            }
            this.colMenuOpen = false;
          })

        Column() {
          Text(this.colMenuTitle)
            .fontSize('18vp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 12, left: 16, right: 16 })

          Divider().strokeWidth(1).color('#E0E0E0')

          ForEach(this.colMenuItems, (item: string, index: number) => {
            Row() {
              Text(item)
                .layoutWeight(1)
                .fontSize('15vp')
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(40)
            .onClick(() => {
              this.handleColumnChoice(index);
            })
            if (index < this.colMenuItems.length - 1) {
              Divider().strokeWidth(1).color('#E0E0E0')
            }
          }, (item: string, index: number) => item + index.toString())
        }
        .width(this.listPopupWidth())
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.colMenuX, y: this.hh() })
      }

      // 水比 / 发酵料
      if (this.pickOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            if (Date.now() - this.pickOpenedAt < 450) {
              return;
            }
            this.pickOpen = false;
          })

        Column() {
          Text(this.pickTitle)
            .fontSize('16vp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 12, left: 16, right: 16 })

          Divider().strokeWidth(1).color('#E0E0E0')

          ForEach(this.pickItems, (item: string, index: number) => {
            Row() {
              Text(item)
                .layoutWeight(1)
                .fontSize('15vp')
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(40)
            .onClick(() => {
              this.applyPick(index);
            })
            if (index < this.pickItems.length - 1) {
              Divider().strokeWidth(1).color('#E0E0E0')
            }
          }, (item: string, index: number) => item + index.toString())
        }
        .width(this.listPopupWidth())
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.pickX, y: this.hh() })
      }

      // 换料比例
      if (this.ratioOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            if (Date.now() - this.ratioOpenedAt < 450) {
              return;
            }
            this.ratioOpen = false;
          })

        Column() {
          Text(t(this.lang, 'switch.title'))
            .fontSize('16vp')
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 12, left: 16, right: 16 })

          Divider().strokeWidth(1).color('#E0E0E0')

          ForEach([10, 20, 30, 40, 50, 60, 70, 80, 90], (p: number) => {
            Row() {
              Text(p.toString() + '%')
                .layoutWeight(1)
                .fontSize('15vp')
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
              Text(Math.abs(this.ratioCurrent - p / 100) < 0.0001 ? '✓' : '')
                .width(24)
                .fontSize('16vp')
                .fontColor('#2E7D32')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(40)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.selectRatio(p / 100);
            })
            if (p < 90) {
              Divider().strokeWidth(1).color('#E0E0E0')
            }
          }, (p: number) => 'ratio' + p.toString())
        }
        .width(Math.min(160, this.viewW))
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.ratioX, y: this.ratioY })
      }

      // 棚数按钮 → 本行棚号气泡（上边贴着被点单元格的下沿）
      if (this.shedListOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            // 点格子那一下不要立刻把刚弹出来的气泡点掉
            if (Date.now() - this.shedListOpenedAt < 350) {
              return;
            }
            this.shedListOpen = false;
            this.shedMenuOpen = false;
            // 气泡关掉了却没走来转入这条路，这次转出作废
            this.clearPendingTransfer();
          })

        Column() {
          Row() {
            Text(this.shedListTitleText)
              .fontSize('15vp')
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .layoutWeight(1)
            Text(this.shedListCountText)
              .fontSize('12vp')
              .fontColor('#666666')
            // ⋮ 菜单入口：全选 / 反选 / 删除 / 转出 / 转入
            Text('⋮')
              .fontSize('20vp')
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .textAlign(TextAlign.Center)
              .width(48)
              .height(40)
              .margin({ left: 6 })
              .onClick(() => {
                this.openShedMenu();
              })
          }
          .width('100%')
          .height(40)
          .padding({ left: 10, right: 4 })

          Divider().strokeWidth(1).color('#E0E0E0')

          if (this.shedListNumbers.length === 0) {
            Text(t(this.lang, 'shedList.empty'))
              .width('100%')
              .fontSize('13vp')
              .fontColor('#999999')
              .textAlign(TextAlign.Center)
              .padding({ top: 14, bottom: 14 })
          } else {
            Scroll() {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.shedListNumbers, (n: number) => {
                  // 默认 28×28 圆点；数字变宽（3 位以上）自动撑成胶囊，高度不变
                  Text(n.toString())
                    .height(28)
                    .constraintSize({ minWidth: 28 })
                    .padding({ left: 6, right: 6 })
                    .borderRadius(14)
                    .backgroundColor(this.isShedSelected(n) ? '#2F6FED' : '#A8DDB5')
                    .fontColor(this.isShedSelected(n) ? '#FFFFFF' : '#000000')
                    .fontSize('13vp')
                    .fontWeight(FontWeight.Bold)
                    .textAlign(TextAlign.Center)
                    .margin({ right: 2, bottom: 2 })
                    .onClick(() => {
                      this.toggleShedChip(n);
                    })
                }, (n: number) => 's' + n.toString() + (this.isShedSelected(n) ? '1' : '0'))
              }
              .width('100%')
            }
            .width('100%')
            .height(this.shedListScrollH)
            .scrollBar(BarState.Auto)
            .padding({ left: 6, right: 6, top: 10, bottom: 8 })
          }
        }
        .width(this.shedListW)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 12, color: '#33000000', offsetX: 0, offsetY: 3 })
        .position({ x: this.shedListX, y: this.shedListY })

        // ⋮ 菜单：右边缘跟气泡右边缘对齐
        if (this.shedMenuOpen) {
          Column() {
            ForEach(this.shedMenuLabels, (label: string, index: number) => {
              Text(label)
                .width('100%')
                .height(40)
                .fontSize('14vp')
                .fontColor(index < 2 ? '#333333' : (this.shedMenuActions[index] === SHED_ACTION_DELETE ? '#D32F2F' : '#333333'))
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.handleShedMenuAction(this.shedMenuActions[index]);
                })
            }, (label: string, index: number) => 'm' + index.toString() + label)
          }
          .width(this.shedMenuW)
          .padding({ top: 4, bottom: 4 })
          .backgroundColor(Color.White)
          .borderRadius(10)
          .clip(true)
          .shadow({ radius: 10, color: '#33000000', offsetX: 0, offsetY: 2 })
          .position({ x: this.shedMenuX, y: this.shedMenuY })
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
