import { FeedData } from '../model/FeedData';
import { t } from '../common/Strings';
import { CellEditor } from './CellEditor';

const COLUMN_IDS: string[] = ['seq', 'shed_number', 'shed_count', 'average_feed', 'fermented', 'powder', 'feed03', 'feed05', 'feed10', 'water', 'weighed_feed'];
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
        .type(this.isNumber ? InputType.NUMBER_DECIMAL : InputType.Normal)
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

@Component
export struct MixCalcTable {
  rows: FeedData[] = [];
  onChanged: () => void = () => {};
  onHelp: () => void = () => {};
  onColumnAction: (action: string, index: number, vis: boolean[], fix: boolean[]) => void = () => {};
  onWaterChange: (percent: number) => void = () => {};
  onFermentChange: (which: number) => void = () => {};

  initVisible: boolean[] = [];
  initFixed: boolean[] = [];

  @State vis: boolean[] = [];
  @State fix: boolean[] = [];

  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  @Prop lang: string = 'zh';
  @Prop @Watch('onSettingsChanged') waterPercentage: number = 20;
  @Prop @Watch('onSettingsChanged') fermentedInWater: boolean = false;
  @Prop fermentedInAverage: boolean = false;

  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State viewW: number = 0;
  @State viewH: number = 0;
  @State version: number = 0;
  @State editingRow: number = -1;
  @State editingCol: number = -1;
  @State editingText: string = '';

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
      w += WIDTHS[fixed[i]];
    }
    return w;
  }

  private normalWidth(): number {
    let w: number = 0;
    const normal: number[] = this.normalIndices();
    for (let i = 0; i < normal.length; i++) {
      w += WIDTHS[normal[i]];
    }
    return w;
  }

  private totalWidth(): number {
    return this.frozenWidth() + this.normalWidth();
  }

  private bodyHeight(): number {
    return this.rows.length * ROW_H;
  }

  private maxOffsetX(): number {
    return Math.max(0, this.totalWidth() - this.viewW);
  }

  private maxOffsetY(): number {
    return Math.max(0, this.bodyHeight() - this.viewH);
  }

  private clampOffsets(): void {
    this.offsetX = Math.min(Math.max(0, this.offsetX), this.maxOffsetX());
    this.offsetY = Math.min(Math.max(0, this.offsetY), this.maxOffsetY());
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
    let nx: number = 0;
    const normal: number[] = this.normalIndices();
    for (let i = 0; i < normal.length; i++) {
      if (normal[i] === index) {
        return this.frozenWidth() + nx - this.offsetX;
      }
      nx += WIDTHS[normal[i]];
    }
    return 0;
  }

  // ===== 文案与数值 =====
  private headLabel(col: number): string {
    if (col === 9) {
      return t(this.lang, 'col.water') + this.waterPercentage.toString() + '%';
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
    switch (column) {
      case 0: return (rowIndex + 1).toString();
      case 1: return row.shedNumber;
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
    if (column === 3 || column === 9 || column === 10) {
      return '#0000FF';
    }
    return '#000000';
  }

  private isWarningCell(data: FeedData, column: number, rowIndex: number): boolean {
    return column === 2 && rowIndex === 0 && data.shedCountBase > 0 && data.shedCount <= 0;
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
    if (column >= 4 && column <= 8 && data.shedCount <= 0) {
      return '#F0F0F0';
    }
    if (column >= 5 && column <= 8 && data.shedCount > 0 && data.switchRatio > 0
      && this.isSwitchTargetCell(data, column)) {
      return '#F0F8F0';
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
    return column >= 1 && column <= 8;
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
    this.version = this.version + 1;
    this.onChanged();
  }

  /** 按可见顺序取可编辑列（1..8），用于跳格 */
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

  /** 提交当前值并跳到下一格：右边一格；行末则下一行首格；到底则结束 */
  private nextCell(): void {
    this.applyEdit(this.editingText);
    const cols: number[] = this.editableColumns();
    const col: number = this.editingCol;
    const row: number = this.editingRow;
    this.editingRow = -1;
    this.editingCol = -1;
    if (cols.length === 0) {
      return;
    }
    let pos: number = cols.indexOf(col);
    if (pos < 0) {
      pos = 0;
    }
    let nextRow: number = row;
    let nextPos: number = pos + 1;
    if (nextPos >= cols.length) {
      nextRow = row + 1;
      nextPos = 0;
    }
    if (nextRow >= this.rows.length) {
      return;
    }
    this.openEditor(nextRow, cols[nextPos]);
  }
  private openEditor(row: number, column: number): void {
    if (!this.isEditableColumn(column) || row < 0 || row >= this.rows.length) {
      return;
    }
    if (!this.isCellEnabled(this.rows[row], column)) {
      return;
    }
    this.editRow = row;
    this.editCol = column;
    this.editorTitle = this.headLabel(column) + ' · ' + t(this.lang, 'dlg.row').replace('%d', (row + 1).toString());
    this.editorValue = this.currentValue(row, column);
    this.editorIsNumber = column !== 1;
    this.editingRow = row;
    this.editingCol = column;
    this.editingText = this.currentValue(row, column);
  }

  // ===== 列操作菜单 =====
  private showColumnMenu(index: number, x: number): void {
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
    this.colMenuX = Math.max(0, Math.min(x, Math.max(0, this.viewW - 200)));
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
  private showWaterPicker(index: number, x: number): void {
    const items: string[] = [];
    for (let pct = 10; pct <= 40; pct += 5) {
      const label: string = t(this.lang, 'col.water') + pct.toString() + '%';
      items.push(pct === this.waterPercentage ? label + ' ✓' : label);
    }
    this.pickKind = 'water';
    this.pickTitle = t(this.lang, 'water.title');
    this.pickItems = items;
    this.pickX = Math.max(0, Math.min(x, Math.max(0, this.viewW - 200)));
    this.pickOpen = true;
  }

  private showFermentPicker(index: number, x: number): void {
    this.pickKind = 'ferment';
    this.pickTitle = t(this.lang, 'ferment.title');
    this.pickItems = [
      (this.fermentedInWater ? '● ' : '○ ') + t(this.lang, 'ferment.inWater'),
      (this.fermentedInWater ? '○ ' : '● ') + t(this.lang, 'ferment.exWater'),
      (this.fermentedInAverage ? '● ' : '○ ') + t(this.lang, 'ferment.inAvg'),
      (this.fermentedInAverage ? '○ ' : '● ') + t(this.lang, 'ferment.exAvg')
    ];
    this.pickX = Math.max(0, Math.min(x, Math.max(0, this.viewW - 200)));
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
    this.ratioRow = row;
    this.ratioCurrent = data.switchRatio;
    const maxX: number = Math.max(0, this.viewW - 160);
    this.ratioX = Math.max(0, Math.min(this.columnLeft(column), maxX));
    this.ratioY = Math.min((row + 1) * ROW_H - this.offsetY, Math.max(0, this.viewH - 260));
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

  private footerText(c: number): string {
    switch (c) {
      case 0: return this.filledRows().toString() + '/' + this.rows.length.toString();
      case 1: return t(this.lang, 'footer.help');
      case 3: return this.formatNumber(Math.round(this.weightedAverage() * 100) / 100);
      case 10: return t(this.lang, 'footer.reset');
      default: return this.formatNumber(Math.round(this.sumColumn(c) * 100) / 100);
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
  }

  @Builder
  cellView(row: FeedData, col: number, r: number) {
    Text(this.cellText(row, col, r))
      .width(WIDTHS[col])
      .height(ROW_H)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.cellColor(col))
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
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
      .width(WIDTHS[col])
      .height(HEAD_H)
      .fontSize(12)
      .fontWeight(FontWeight.Bold)
      .fontColor('#000000')
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .backgroundColor(col === 4 && this.fermentedInWater ? '#F0F8F0' : '#E8F5E9')
      .border({
        width: col === 4 && this.fermentedInAverage ? 1.5 : 0.5,
        color: col === 4 && this.fermentedInAverage ? '#6E511E' : '#000000'
      })
      .onClick(() => {
        const x: number = this.columnLeft(col);
        if (col === 9) {
          this.showWaterPicker(col, x);
        } else if (col === 4) {
          this.showFermentPicker(col, x);
        }
      })
      .gesture(
        LongPressGesture({ duration: 350 })
          .onAction(() => {
            this.showColumnMenu(col, this.columnLeft(col));
          })
      )
  }

  @Builder
  footerCell(col: number) {
    Text(this.footerText(col))
      .width(WIDTHS[col])
      .height(FOOT_H)
      .fontSize(12)
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
        .height(HEAD_H)
        .backgroundColor('#E8F5E9')
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
              .height(ROW_H)
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
              .height(ROW_H)
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
          this.viewW = Number(newValue.width);
          this.viewH = Number(newValue.height);
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
              this.footerCell(col)
            }, (col: number) => 'f' + col.toString() + '_' + this.version.toString())
          }
          .position({ x: this.frozenWidth() - this.offsetX, y: 0 })

          Row() {
            ForEach(this.fixedIndices(), (col: number) => {
              this.footerCell(col)
            }, (col: number) => 'ff' + col.toString() + '_' + this.version.toString())
          }
          .zIndex(1)
        }
        .width('100%')
        .height(FOOT_H)
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

      if (this.editingRow >= 0 && this.editingCol >= 0) {
        CellEditor({
          value: this.editingText,
          widthVp: WIDTHS[this.editingCol],
          heightVp: ROW_H,
          xVp: this.columnLeft(this.editingCol),
          yVp: HEAD_H + this.editingRow * ROW_H - this.offsetY,
          isNumber: this.editingCol !== 1,
          onValueChange: (text: string) => {
            this.editingText = text;
          },
          onDone: () => {
            this.editingRow = -1;
            this.editingCol = -1;
          }
        })
      }

      // 列操作菜单
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
            Row() {
              Text(item)
                .layoutWeight(1)
                .fontSize(15)
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
        .width(200)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.colMenuX, y: HEAD_H })
      }

      // 水比 / 发酵料
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
            Row() {
              Text(item)
                .layoutWeight(1)
                .fontSize(15)
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
        .width(Math.min(200, this.viewW))
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.pickX, y: HEAD_H })
      }

      // 换料比例
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
          }, (p: number) => 'ratio' + p.toString())
        }
        .width(Math.min(160, this.viewW))
        .backgroundColor(Color.White)
        .borderRadius(12)
        .clip(true)
        .shadow({ radius: 10, color: '#40000000', offsetX: 0, offsetY: 2 })
        .position({ x: this.ratioX, y: this.ratioY })
      }
    }
    .width('100%')
    .height('100%')
  }
}
