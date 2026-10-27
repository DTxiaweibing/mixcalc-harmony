import { FeedData } from '../model/FeedData';
import { t } from '../common/Strings';

const COLUMN_IDS: string[] = ['seq', 'shed_number', 'shed_count', 'average_feed', 'fermented', 'powder', 'feed03', 'feed05', 'feed10', 'water', 'weighed_feed'];
const HEADS: string[] = ['序号', '棚号', '棚数', '平均', '发酵料', '粉料', '0.3料', '0.5料', '1.0料', '水', '称料'];
const HEAD_KEYS: string[] = ['col.seq', 'col.shed', 'col.count', 'col.avg', 'col.ferm', 'col.powder', 'col.f03', 'col.f05', 'col.f10', 'col.water', 'col.weigh'];
const WIDTHS: number[] = [40, 60, 40, 40, 60, 60, 60, 60, 60, 60, 60];
const ROW_H: number = 40;
const HEAD_H: number = 40;
const FOOT_H: number = 40;
@CustomDialog
struct CellEditorDialog {
  controller?: CustomDialogController;
  title: string = '';
  initValue: string = '';
  isNumber: boolean = false;
  onConfirm: (value: string) => void = () => {};
  @State input: string = '';

  aboutToAppear(): void {
    this.input = this.initValue;
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .padding({ top: 16, bottom: 12 })

      Divider().strokeWidth(1).color('#E0E0E0')

      TextInput({ text: this.input })
        .type(this.isNumber ? InputType.Number : InputType.Normal)
        .fontSize(16)
        .textAlign(TextAlign.Center)
        .height(44)
        .margin({ left: 20, right: 20, top: 12 })
        .defaultFocus(true)
        .onChange((value: string) => {
          this.input = value;
        })

      Row() {
        Button('取消')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(44)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#666666')
          .onClick(() => {
            this.controller?.close();
          })

        Divider().vertical(true).height(44).strokeWidth(1).color('#E0E0E0')

        Button('确定')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(44)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize(15)
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
  confirmColor: string = '#D32F2F';
  onConfirm: () => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 12, left: 16, right: 16 })

      Divider().strokeWidth(1).color('#E0E0E0')

      Text(this.message)
        .fontSize(15)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .lineHeight(23)
        .padding({ top: 20, bottom: 20, left: 20, right: 20 })

      Divider().strokeWidth(1).color('#E0E0E0')

      Row() {
        Button('取消')
          .type(ButtonType.Normal)
          .layoutWeight(1)
          .height(48)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize(15)
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
          .fontSize(15)
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
struct ColumnMenuDialog {
  controller?: CustomDialogController;
  title: string = '';
  items: string[] = [];
  onSelect: (index: number) => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#000000')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 12, left: 16, right: 16 })

      Divider().strokeWidth(1).color('#E0E0E0')

      ForEach(this.items, (item: string, index: number) => {
        Button(item)
          .type(ButtonType.Normal)
          .width('100%')
          .height(40)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .fontSize(15)
          .fontColor('#333333')
          .onClick(() => {
            this.controller?.close();
            this.onSelect(index);
          })
        if (index < this.items.length - 1) {
          Divider().strokeWidth(1).color('#E0E0E0')
        }
      }, (item: string, index: number) => item + index.toString())
    }
    .width(200)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .clip(true)
  }
}

@Component
export struct MixCalcTable {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  rows: FeedData[] = [];
  onChanged: () => void = () => {};
  onHelp: () => void = () => {};
  onColumnAction: (action: string, index: number) => void = () => {};
  onWaterChange: (percent: number) => void = () => {};
  onFermentChange: (which: number) => void = () => {};

  @State pickOpen: boolean = false;
  @State pickX: number = 0;
  @State pickY: number = 0;
  @State pickTitle: string = '';
  @State pickItems: string[] = [];
  private pickKind: string = '';

  visibleMask: boolean[] = [];
  fixedMask: boolean[] = [];

  @Prop lang: string = 'zh';
  waterPercentage: number = 20;
  fermentedInWater: boolean = false;
  fermentedInAverage: boolean = false;

  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State viewW: number = 0;
  @State viewH: number = 0;

  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private flingTimer: number = -1;

  private editRow: number = -1;
  private editCol: number = -1;

  private editorTitle: string = '';
  private editorValue: string = '';
  private editorIsNumber: boolean = false;
  private editorController: CustomDialogController = new CustomDialogController({
    builder: CellEditorDialog({
      title: this.editorTitle,
      initValue: this.editorValue,
      isNumber: this.editorIsNumber,
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
      title: '确认重置',
      message: this.resetMessage,
      confirmText: '确定重置',
      confirmColor: '#D32F2F',
      onConfirm: () => {
        this.resetAll();
      }
    }),
    autoCancel: true,
    customStyle: true
  });

  @State ratioOpen: boolean = false;
  @State ratioX: number = 0;
  @State ratioY: number = 0;
  @State ratioCurrent: number = 0;
  private ratioRow: number = -1;

  @State colMenuOpen: boolean = false;
  @State colMenuX: number = 0;
  @State colMenuTitle: string = '';
  @State colMenuItems: string[] = [];
  private colMenuIndex: number = -1;


  private headLabel(col: number): string {
    return t(this.lang, HEAD_KEYS[col]);
  }  private isVisible(index: number): boolean {
    if (index === 0) {
      return true;
    }
    if (this.visibleMask.length > index) {
      return this.visibleMask[index];
    }
    return true;
  }

  private isFixed(index: number): boolean {
    if (index === 0) {
      return true;
    }
    if (this.fixedMask.length > index) {
      return this.fixedMask[index];
    }
    return false;
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
      w += WIDTHS[fixed[i]];
    }
    return w;
  }

  private totalWidth(): number {
    let w: number = 0;
    for (let i = 0; i < WIDTHS.length; i++) {
      if (this.isVisible(i)) {
        w += WIDTHS[i];
      }
    }
    return w;
  }

  private maxOffsetX(): number {
    return Math.max(0, this.totalWidth() - this.viewW);
  }

  private maxOffsetY(): number {
    return Math.max(0, this.rows.length * ROW_H - this.viewH);
  }

  private clampOffsets(): void {
    this.offsetX = Math.min(Math.max(0, this.offsetX), this.maxOffsetX());
    this.offsetY = Math.min(Math.max(0, this.offsetY), this.maxOffsetY());
  }

  private columnAt(x: number): number {
    const fixed: number[] = this.fixedIndices();
    let acc: number = 0;
    for (let i = 0; i < fixed.length; i++) {
      if (x >= acc && x < acc + WIDTHS[fixed[i]]) {
        return fixed[i];
      }
      acc += WIDTHS[fixed[i]];
    }
    const normal: number[] = this.normalIndices();
    for (let i = 0; i < normal.length; i++) {
      const cx: number = acc - this.offsetX;
      if (x >= cx && x < cx + WIDTHS[normal[i]]) {
        return normal[i];
      }
      acc += WIDTHS[normal[i]];
    }
    return -1;
  }

  private cellText(row: FeedData, column: number): string {
    switch (column) {
      case 1: return row.shedNumber;
      case 2: return row.shedCount === 0 ? '' : Math.round(row.shedCount).toString();
      case 3: return row.average > 0 ? row.average.toFixed(2) : '';
      case 4: return row.fermented > 0 ? row.fermented.toFixed(2) : '';
      case 5: return row.powder > 0 ? row.powder.toFixed(2) : '';
      case 6: return row.feed03 > 0 ? row.feed03.toFixed(2) : '';
      case 7: return row.feed05 > 0 ? row.feed05.toFixed(2) : '';
      case 8: return row.feed10 > 0 ? row.feed10.toFixed(2) : '';
      case 9: return row.water > 0 ? row.water.toFixed(2) : '';
      case 10: return row.weighed > 0 ? row.weighed.toFixed(2) : '';
      default: return '';
    }
  }

  private cellColor(column: number): string {
    if (column === 0) {
      return '#666666';
    }
    if (column === 3 || column === 9 || column === 10) {
      return '#0000FF';
    }
    return '#000000';
  }

  private sumColumn(column: number): number {
    let s: number = 0;
    for (let i = 0; i < this.rows.length; i++) {
      const r: FeedData = this.rows[i];
      switch (column) {
        case 2: s += r.shedCount; break;
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

  private formatSum(value: number): string {
    if (value === 0) {
      return '0';
    }
    if (value === Math.floor(value)) {
      return Math.floor(value).toString();
    }
    return value.toFixed(2);
  }

  private footerText(c: number): string {
    switch (c) {
      case 0: return this.filledRows().toString() + '/' + this.rows.length.toString();
      case 1: return t(this.lang, 'footer.help');
      case 3: return this.formatSum(this.weightedAverage());
      case 10: return t(this.lang, 'footer.reset');
      default: return this.formatSum(this.sumColumn(c));
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

  private isEditableColumn(column: number): boolean {
    return column >= 1 && column <= 8;
  }

  /** 与安卓 isCellEnabled 一致：棚号/棚数恒可编辑；平均看能否手改；料格要有棚数。 */
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

  /** 第一行棚数被后续行扣成 ≤0 时用警告色（安卓 STATE_WARNING）。 */
  private isWarningCell(data: FeedData, column: number, rowIndex: number): boolean {
    return column === 2 && rowIndex === 0 && data.shedCountBase > 0 && data.shedCount <= 0;
  }

  private cellFillColor(data: FeedData, column: number, rowIndex: number): string {
    if (this.isWarningCell(data, column, rowIndex)) {
      return '#FFC64B';
    }
    // 平均列永不置灰（与安卓一致），只有料格按棚数禁用
    if (column >= 4 && column <= 8 && data.shedCount <= 0) {
      return '#F0F0F0';
    }
    // 换料中的目标格浅绿高亮（安卓 STATE_HIGHLIGHT）
    if (column >= 5 && column <= 8 && data.shedCount > 0 && data.switchRatio > 0
      && this.switchTargetIndex(data) === column) {
      return '#F0F8F0';
    }
    return '#FFFFFF';
  }

  private cellStrokeColor(data: FeedData, column: number, rowIndex: number): string {
    if (this.isWarningCell(data, column, rowIndex)) {
      return '#FF0000';
    }
    if (column >= 4 && column <= 8 && data.shedCount <= 0) {
      return '#CCCCCC';
    }
    return '#000000';
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
    return value === 0 ? '' : value.toFixed(2);
  }

  private clearRowData(row: FeedData, clearShedNumber: boolean): void {
    if (clearShedNumber) {
      row.shedNumber = '';
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
    row.shedCountBase = 0;
    row.shedCountBaseSum = 0;
    row.switchRatio = 0;
    row.isAverageManuallyModified = false;
  }

  private sumBelowFirst(): number {
    let sum: number = 0;
    for (let i = 1; i < this.rows.length; i++) {
      sum += this.rows[i].shedCount;
    }
    return sum;
  }

  private recomputeFirstRow(): void {
    if (this.rows.length < 2) {
      return;
    }
    const first: FeedData = this.rows[0];
    const oldCount: number = first.shedCount;
    const oldAverage: number = first.average;

    if (!first.isShedCountManuallyModified) {
      first.calculateShedCount();
      first.shedCountBase = first.shedCount;
      first.shedCountBaseSum = 0;
    } else if (first.shedCountBase <= 0) {
      if (first.shedCount > 0) {
        first.shedCountBase = first.shedCount;
        first.shedCountBaseSum = 0;
      } else {
        first.isShedCountManuallyModified = false;
        first.calculateShedCount();
        first.shedCountBase = first.shedCount;
        first.shedCountBaseSum = 0;
      }
    }

    const sum: number = this.sumBelowFirst();
    const remainder: number = first.shedCountBase - (sum - first.shedCountBaseSum);
    first.shedCount = remainder;

    if (remainder !== oldCount && oldAverage > 0 && !first.isAverageManuallyModified) {
      first.average = oldAverage;
      first.isAverageManuallyModified = true;
    }
    first.recalculateDerivedOnly(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
  }

  private applyEdit(text: string): void {
    if (this.editRow < 0 || this.editCol < 0) {
      return;
    }
    const row: FeedData = this.rows[this.editRow];
    const value: string = text.trim();
    const col: number = this.editCol;
    let number: number = value.length === 0 ? 0 : Number(value);
    if (isNaN(number)) {
      number = 0;
    }

    if (col === 1) {
      row.setShedNumber(value);
      if (value.length === 0) {
        this.clearRowData(row, true);
      }
    } else if (col === 2) {
      const newCount: number = Math.round(number);
      row.shedCount = newCount;
      row.isShedCountManuallyModified = !(newCount === 0 || value.length === 0);
      if (this.editRow === 0) {
        row.shedCountBase = newCount;
        row.shedCountBaseSum = this.sumBelowFirst();
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

    if (this.editRow !== 0 && row.shedCount <= 0) {
      row.fermented = 0;
      row.powder = 0;
      row.feed03 = 0;
      row.feed05 = 0;
      row.feed10 = 0;
      row.water = 0;
      row.weighed = 0;
      row.average = 0;
      row.isAverageManuallyModified = false;
      row.switchRatio = 0;
    }

    if (this.editRow !== 0) {
      row.updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    }
    this.recomputeFirstRow();
    this.drawBody();
    this.onChanged();
  }

  private openEditor(row: number, column: number): void {
    if (!this.isEditableColumn(column) || row < 0 || row >= this.rows.length) {
      return;
    }
    if (!this.isCellEnabled(this.rows[row], column)) {
      return;
    }
    this.stopFling();
    this.editRow = row;
    this.editCol = column;
    this.editorTitle = this.headLabel(column) + ' · ' + t(this.lang, 'dlg.row').replace('%d', (row + 1).toString());
    this.editorValue = this.currentValue(row, column);
    this.editorIsNumber = column !== 1;
    this.editorController.open();
  }

  private columnLeft(index: number): number {
    const fixed: number[] = this.fixedIndices();
    let x: number = 0;
    for (let i = 0; i < fixed.length; i++) {
      if (fixed[i] === index) {
        return x;
      }
      x += WIDTHS[fixed[i]];
    }
    const normal: number[] = this.normalIndices();
    x = 0;
    for (let i = 0; i < normal.length; i++) {
      if (normal[i] === index) {
        return this.frozenWidth() + x - this.offsetX;
      }
      x += WIDTHS[normal[i]];
    }
    return 0;
  }


  /** 换料目标列：一格数据时取它的“大一号”，两格时取较大的那档。 */
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
      return last > 0 && last < 3 ? last + 1 : -1;
    }
    if (count === 2) {
      return last;
    }
    return -1;
  }

  private handleFeedLongPress(x: number, y: number): void {
    const row: number = Math.floor((y + this.offsetY) / ROW_H);
    if (row < 0 || row >= this.rows.length) {
      return;
    }
    const col: number = this.columnAt(x);
    if (col < 5 || col > 8) {
      return;
    }
    const data: FeedData = this.rows[row];
    if (!this.isCellEnabled(data, col)) {
      return;
    }
    if (this.switchTargetIndex(data) !== col) {
      return;
    }
    this.ratioRow = row;
    this.ratioCurrent = data.switchRatio;
    const maxX: number = Math.max(0, this.viewW - 160);
    this.ratioX = Math.max(0, Math.min(this.columnLeft(col), maxX));
    this.ratioY = (row + 1) * ROW_H - this.offsetY;
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
    this.drawBody();
    this.onChanged();
  }  private showWaterPicker(col: number): void {
    const items: string[] = [];
    for (let pct = 10; pct <= 40; pct += 5) {
      items.push(t(this.lang, 'col.water') + pct.toString() + '%');
    }
    this.pickKind = 'water';
    this.pickTitle = t(this.lang, 'water.title');
    this.pickItems = items;
    this.pickX = Math.max(0, Math.min(this.columnLeft(col), Math.max(0, this.viewW - 180)));
    this.pickY = HEAD_H;
    this.pickOpen = true;
  }

  private showFermentPicker(col: number): void {
    const items: string[] = [
      (this.fermentedInWater ? '● ' : '○ ') + t(this.lang, 'ferment.inWater'),
      (this.fermentedInWater ? '○ ' : '● ') + t(this.lang, 'ferment.exWater'),
      (this.fermentedInAverage ? '● ' : '○ ') + t(this.lang, 'ferment.inAvg'),
      (this.fermentedInAverage ? '○ ' : '● ') + t(this.lang, 'ferment.exAvg')
    ];
    this.pickKind = 'ferment';
    this.pickTitle = t(this.lang, 'ferment.title');
    this.pickItems = items;
    this.pickX = Math.max(0, Math.min(this.columnLeft(col), Math.max(0, this.viewW - 200)));
    this.pickY = HEAD_H;
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

  private showColumnMenu(index: number): void {
    if (index === 0) {
      return;
    }
    const fixed: boolean = this.isFixed(index);
    const visible: boolean = this.isVisible(index);
    this.colMenuIndex = index;
    this.colMenuTitle = t(this.lang, 'dlg.colOps') + this.headLabel(index);
    this.colMenuItems = [
      fixed ? t(this.lang, 'col.unfix') : t(this.lang, 'col.fix'),
      visible ? t(this.lang, 'col.hide') : t(this.lang, 'col.show'),
      t(this.lang, 'col.showAll'),
      t(this.lang, 'col.unfixAllCols')
    ];
    const maxX: number = Math.max(0, this.viewW - 200);
    this.colMenuX = Math.max(0, Math.min(this.columnLeft(index), maxX));
    this.colMenuOpen = true;
  }

  private handleColumnChoice(choice: number): void {
    const index: number = this.colMenuIndex;
    this.colMenuOpen = false;
    if (index < 0) {
      return;
    }
    if (choice === 0) {
      this.onColumnAction('toggle-fixed', index);
    } else if (choice === 1) {
      this.onColumnAction('toggle-visible', index);
    } else if (choice === 2) {
      this.onColumnAction('show-all', index);
    } else if (choice === 3) {
      this.onColumnAction('unfix-all', index);
    }
  }

  private confirmReset(): void {
    const filled: number = this.filledRows();
    this.resetMessage = filled > 0
      ? '确定要重置所有数据吗？\n\n当前已有 ' + filled.toString() + ' 行数据，重置后将全部清空。'
      : '确定要重置所有数据吗？\n\n当前没有数据需要重置。';
    this.resetController.open();
  }

  private resetAll(): void {
    for (let i = 0; i < this.rows.length; i++) {
      this.clearRowData(this.rows[i], true);
    }
    this.drawBody();
    this.onChanged();
  }

  private drawBody(): void {
    if (this.viewW <= 0 || this.viewH <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, this.viewW, this.viewH);
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.fillRect(0, 0, this.viewW, this.viewH);
    this.clampOffsets();

    const fixed: number[] = this.fixedIndices();
    const normal: number[] = this.normalIndices();
    const frozenW: number = this.frozenWidth();

    for (let r = 0; r < this.rows.length; r++) {
      const y: number = r * ROW_H - this.offsetY;
      if (y + ROW_H < 0 || y > this.viewH) {
        continue;
      }
      const row: FeedData = this.rows[r];

      this.ctx.save();
      this.ctx.beginPath();
      this.ctx.rect(frozenW, 0, Math.max(0, this.viewW - frozenW), this.viewH);
      this.ctx.clip();
      let cx: number = frozenW - this.offsetX;
      for (let i = 0; i < normal.length; i++) {
        const col: number = normal[i];
        this.ctx.fillStyle = this.cellFillColor(row, col, r);
        this.ctx.fillRect(cx, y, WIDTHS[col], ROW_H);
        this.ctx.strokeStyle = this.cellStrokeColor(row, col, r);
        this.ctx.lineWidth = 0.5;
        this.ctx.strokeRect(cx, y, WIDTHS[col], ROW_H);
        const text: string = col === 0 ? (r + 1).toString() : this.cellText(row, col);
        if (text.length > 0) {
          this.ctx.fillStyle = this.cellColor(col);
          this.ctx.font = 'bold 12vp sans-serif';
          this.ctx.textAlign = 'center';
          this.ctx.textBaseline = 'middle';
          this.ctx.fillText(text, cx + WIDTHS[col] / 2, y + ROW_H / 2);
        }
        cx += WIDTHS[col];
      }
      this.ctx.restore();

      let fx: number = 0;
      for (let i = 0; i < fixed.length; i++) {
        const col: number = fixed[i];
        this.ctx.fillStyle = this.cellFillColor(row, col, r);
        this.ctx.fillRect(fx, y, WIDTHS[col], ROW_H);
        this.ctx.strokeStyle = this.cellStrokeColor(row, col, r);
        this.ctx.lineWidth = 0.5;
        this.ctx.strokeRect(fx, y, WIDTHS[col], ROW_H);
        const text: string = col === 0 ? (r + 1).toString() : this.cellText(row, col);
        if (text.length > 0) {
          this.ctx.fillStyle = this.cellColor(col);
          this.ctx.font = 'bold 12vp sans-serif';
          this.ctx.textAlign = 'center';
          this.ctx.textBaseline = 'middle';
          this.ctx.fillText(text, fx + WIDTHS[col] / 2, y + ROW_H / 2);
        }
        fx += WIDTHS[col];
      }
    }
  }

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
      this.drawBody();
      if (Math.abs(velocityX) < 15 && Math.abs(velocityY) < 15) {
        this.stopFling();
      }
    }, 16);
  }

  aboutToDisappear(): void {
    this.stopFling();
  }

  aboutToAppear(): void {
    for (let i = 0; i < this.rows.length; i++) {
      this.rows[i].updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    }
    this.recomputeFirstRow();
  }

  build() {
    Stack() {
      Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          ForEach(this.normalIndices(), (col: number) => {
            Text(this.headLabel(col))
              .width(WIDTHS[col])
              .height(HEAD_H)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .textAlign(TextAlign.Center)
              .border({ width: col === 4 && this.fermentedInAverage ? 1.5 : 0.5, color: col === 4 && this.fermentedInAverage ? '#6E511E' : '#000000' })

              .backgroundColor(col === 4 && this.fermentedInWater ? '#F0F8F0' : '#E8F5E9')
              .onClick(() => {
                if (col === 9) {
                  this.showWaterPicker(col);
                } else if (col === 4) {
                  this.showFermentPicker(col);
                }
              })
              .gesture(LongPressGesture().onAction(() => {
                this.showColumnMenu(col);
              }))
          }, (col: number) => 'h' + col.toString())
        }
        .position({ x: this.frozenWidth() - this.offsetX, y: 0 })

        Row() {
          ForEach(this.fixedIndices(), (col: number) => {
            Text(this.headLabel(col))
              .width(WIDTHS[col])
              .height(HEAD_H)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .textAlign(TextAlign.Center)
              .border({ width: col === 4 && this.fermentedInAverage ? 1.5 : 0.5, color: col === 4 && this.fermentedInAverage ? '#6E511E' : '#000000' })

              .backgroundColor(col === 4 && this.fermentedInWater ? '#F0F8F0' : '#E8F5E9')
              .onClick(() => {
                if (col === 9) {
                  this.showWaterPicker(col);
                } else if (col === 4) {
                  this.showFermentPicker(col);
                }
              })
              .gesture(LongPressGesture().onAction(() => {
                this.showColumnMenu(col);
              }))
          }, (col: number) => 'f' + col.toString())
        }
      }
      .width('100%')
      .height(HEAD_H)
      .backgroundColor('#E8F5E9')
      .clip(true)

      Canvas(this.ctx)
        .layoutWeight(1)
        .width('100%')
        .onReady(() => {
          this.viewW = this.ctx.width;
          this.viewH = this.ctx.height;
          this.drawBody();
        })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.viewW = Number(newValue.width);
          this.viewH = Number(newValue.height);
          this.drawBody();
        })
        .gesture(
          LongPressGesture()
            .onAction((event: GestureEvent) => {
              if (event.fingerList.length > 0) {
                this.handleFeedLongPress(event.fingerList[0].localX, event.fingerList[0].localY);
              }
            })
        )
        .onClick((event: ClickEvent) => {
          const row: number = Math.floor((event.y + this.offsetY) / ROW_H);
          if (row < 0 || row >= this.rows.length) {
            return;
          }
          this.openEditor(row, this.columnAt(event.x));
        })

      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          ForEach(this.normalIndices(), (col: number) => {
            Text(this.footerText(col))
              .width(WIDTHS[col])
              .height(FOOT_H)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.footerColor(col))
              .textAlign(TextAlign.Center)
              .border({ width: 0.5, color: '#000000' })
              .backgroundColor(this.footerCellBg(col))
              .onClick(() => {
                if (col === 1) {
                  this.onHelp();
                } else if (col === 10) {
                  this.confirmReset();
                }
              })
          }, (col: number) => 'hn' + col.toString())
        }
        .position({ x: this.frozenWidth() - this.offsetX, y: 0 })

        Row() {
          ForEach(this.fixedIndices(), (col: number) => {
            Text(this.footerText(col))
              .width(WIDTHS[col])
              .height(FOOT_H)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.footerColor(col))
              .textAlign(TextAlign.Center)
              .border({ width: 0.5, color: '#000000' })
              .backgroundColor(this.footerCellBg(col))
              .onClick(() => {
                if (col === 1) {
                  this.onHelp();
                } else if (col === 10) {
                  this.confirmReset();
                }
              })
          }, (col: number) => 'fn' + col.toString())
        }
      }
      .width('100%')
      .height(FOOT_H)
      .backgroundColor('#EAF3EC')
      .clip(true)
      }
      .width('100%')
      .height('100%')

      if (this.colMenuOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.colMenuOpen = false;
          })

        Column() {
          Text(this.colMenuTitle)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 12, left: 16, right: 16 })

          Divider().strokeWidth(1).color('#E0E0E0')

          ForEach(this.colMenuItems, (item: string, index: number) => {
            Button(item)
              .type(ButtonType.Normal)
              .width('100%')
              .height(40)
              .borderRadius(0)
              .backgroundColor(Color.Transparent)
              .fontSize(15)
              .fontColor('#333333')
              .onClick(() => {
                this.handleColumnChoice(index);
              })
            if (index < this.colMenuItems.length - 1) {
              Divider().strokeWidth(1).color('#E0E0E0')
            }
          }, (item: string, index: number) => item + index.toString())
        }
        .width(200)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.colMenuX, y: HEAD_H })
      }
      if (this.ratioOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.ratioOpen = false;
          })

        Column() {
          Text(t(this.lang, 'switch.title'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 12, left: 16, right: 16 })

          Divider().strokeWidth(1).color('#E0E0E0')

          ForEach([10, 20, 30, 40, 50, 60, 70, 80, 90], (p: number) => {
            Row() {
              Text(p.toString() + '%')
                .layoutWeight(1)
                .fontSize(15)
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
              Text(Math.abs(this.ratioCurrent - p / 100) < 0.0001 ? '✓' : '')
                .width(24)
                .fontSize(16)
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
          }, (p: number) => 'r' + p.toString())
        }
        .width(Math.min(160, this.viewW))
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.ratioX, y: this.ratioY })
      }

      if (this.pickOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.pickOpen = false;
          })

        Column() {
          Text(this.pickTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#000000')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 12, left: 16, right: 16 })

          Divider().strokeWidth(1).color('#E0E0E0')

          ForEach(this.pickItems, (item: string, index: number) => {
            Text(item)
              .width('100%')
              .height(40)
              .fontSize(15)
              .fontColor('#333333')
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.applyPick(index);
              })
            if (index < this.pickItems.length - 1) {
              Divider().strokeWidth(1).color('#E0E0E0')
            }
          }, (item: string, index: number) => item + index.toString())
        }
        .width(Math.min(200, this.viewW))
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.pickX, y: this.pickY })
      }

    }
    .width('100%')
    .height('100%')
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
          this.drawBody();
        })
        .onActionEnd((event: GestureEvent) => {
          this.startFling(event.velocityX, event.velocityY);
        })
    )
  }
}
