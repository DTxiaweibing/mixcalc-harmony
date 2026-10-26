import { FeedData } from '../model/FeedData';

const WIDTHS: number[] = [40, 60, 40, 40, 60, 60, 60, 60, 60, 60, 60];
const HEADS: string[] = ['序号', '棚号', '棚数', '平均', '发酵料', '粉料', '0.3料', '0.5料', '1.0料', '水', '称料'];
const ROW_H: number = 40;
const HEAD_H: number = 40;
const FOOT_H: number = 40;
const FROZEN_W: number = 40;

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
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 12 })

      TextInput({ text: this.input })
        .type(this.isNumber ? InputType.Number : InputType.Normal)
        .fontSize(16)
        .textAlign(TextAlign.Center)
        .height(44)
        .margin({ left: 20, right: 20 })
        .defaultFocus(true)
        .onChange((value: string) => {
          this.input = value;
        })

      Row() {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => {
            this.controller?.close();
          })
        Button('确定')
          .layoutWeight(1)
          .backgroundColor('#2D8C42')
          .fontColor(Color.White)
          .margin({ left: 12 })
          .onClick(() => {
            this.onConfirm(this.input);
            this.controller?.close();
          })
      }
      .width('100%')
      .padding(16)
    }
    .width('88%')
    .backgroundColor(Color.White)
    .borderRadius(12)
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

      Divider()
        .strokeWidth(1)
        .color('#E0E0E0')

      Text(this.message)
        .fontSize(15)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .lineHeight(23)
        .padding({ top: 20, bottom: 20, left: 20, right: 20 })

      Divider()
        .strokeWidth(1)
        .color('#E0E0E0')

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

        Divider()
          .vertical(true)
          .height(48)
          .strokeWidth(1)
          .color('#E0E0E0')

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
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  rows: FeedData[] = [];
  onChanged: () => void = () => {};
  onHelp: () => void = () => {};

  private resetTitle: string = '确认重置';
  private resetMessage: string = '';
  private resetController: CustomDialogController = new CustomDialogController({
    builder: ConfirmDialog({
      title: this.resetTitle,
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

  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State viewW: number = 0;
  @State viewH: number = 0;

  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private flingTimer: number = -1;

  waterPercentage: number = 20;
  fermentedInWater: boolean = false;
  fermentedInAverage: boolean = false;

  editorTitle: string = '';
  editorValue: string = '';
  editorIsNumber: boolean = false;
  private editRow: number = -1;
  private editCol: number = -1;

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

  private totalWidth(): number {
    let sum: number = 0;
    for (let i = 0; i < WIDTHS.length; i++) {
      sum += WIDTHS[i];
    }
    return sum;
  }

  private xOfColumn(index: number): number {
    let x: number = 0;
    for (let i = 0; i < index; i++) {
      x += WIDTHS[i];
    }
    return x;
  }

  private maxOffsetX(): number {
    return Math.max(0, this.totalWidth() - this.viewW);
  }

  private maxOffsetY(): number {
    let bodyH: number = this.rows.length * ROW_H;
    return Math.max(0, bodyH - this.viewH);
  }

  private clampOffsets(): void {
    this.offsetX = Math.min(Math.max(0, this.offsetX), this.maxOffsetX());
    this.offsetY = Math.min(Math.max(0, this.offsetY), this.maxOffsetY());
  }

  // ===== 数据派生 =====
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
      let r: FeedData = this.rows[i];
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
      let r: FeedData = this.rows[i];
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
      case 1: return '帮助';
      case 3: return this.formatSum(this.weightedAverage());
      case 10: return '重置';
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

  private columnAt(x: number): number {
    if (x < FROZEN_W) {
      return 0;
    }
    for (let c = 1; c < WIDTHS.length; c++) {
      let cx: number = this.xOfColumn(c) - this.offsetX;
      if (x >= cx && x < cx + WIDTHS[c]) {
        return c;
      }
    }
    return -1;
  }

  private columnTitle(column: number): string {
    return column >= 0 && column < HEADS.length ? HEADS[column] : '';
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
    let data: FeedData = this.rows[row];
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
    let first: FeedData = this.rows[0];
    let oldCount: number = first.shedCount;
    let oldAverage: number = first.average;

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

    let sum: number = this.sumBelowFirst();
    let remainder: number = first.shedCountBase - (sum - first.shedCountBaseSum);
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
    let row: FeedData = this.rows[this.editRow];
    let value: string = text.trim();
    let col: number = this.editCol;
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
      let newCount: number = Math.round(number);
      row.shedCount = newCount;
      row.isShedCountManuallyModified = !(newCount === 0 || value.length === 0);
      if (this.editRow === 0) {
        row.shedCountBase = newCount;
        row.shedCountBaseSum = this.sumBelowFirst();
      }
    } else if (col === 3) {
      row.setAverageManually(number, this.fermentedInAverage);
    } else {
      let nfIndex: number = this.nfIndexOf(col);
      let origin: number = nfIndex >= 0 ? row.getNonFermentedValue(nfIndex) : 0;
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
    this.stopFling();
    this.editRow = row;
    this.editCol = column;
    this.editorTitle = this.columnTitle(column) + ' · 第' + (row + 1).toString() + '行';
    this.editorValue = this.currentValue(row, column);
    this.editorIsNumber = column !== 1;
    this.editorController.open();
  }

  private showHelp(): void {
    this.onHelp();
  }

  private confirmReset(): void {
    let filled: number = this.filledRows();
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

    for (let r = 0; r < this.rows.length; r++) {
      let y: number = r * ROW_H - this.offsetY;
      if (y + ROW_H < 0 || y > this.viewH) {
        continue;
      }
      let row: FeedData = this.rows[r];

      // 冻结序号列
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.fillRect(0, y, FROZEN_W, ROW_H);
      this.ctx.strokeStyle = '#000000';
      this.ctx.lineWidth = 0.5;
      this.ctx.strokeRect(0, y, FROZEN_W, ROW_H);
      this.ctx.fillStyle = '#666666';
      this.ctx.font = 'bold 12vp sans-serif';
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'middle';
      this.ctx.fillText((r + 1).toString(), FROZEN_W / 2, y + ROW_H / 2);

      // 其余列
      this.ctx.save();
      this.ctx.beginPath();
      this.ctx.rect(FROZEN_W, 0, Math.max(0, this.viewW - FROZEN_W), this.viewH);
      this.ctx.clip();
      for (let c = 1; c < WIDTHS.length; c++) {
        let cx: number = this.xOfColumn(c) - this.offsetX;
        if (cx + WIDTHS[c] <= FROZEN_W || cx > this.viewW) {
          continue;
        }
        this.ctx.fillStyle = '#FFFFFF';
        this.ctx.fillRect(cx, y, WIDTHS[c], ROW_H);
        this.ctx.strokeStyle = '#000000';
        this.ctx.lineWidth = 0.5;
        this.ctx.strokeRect(cx, y, WIDTHS[c], ROW_H);
        let text: string = this.cellText(row, c);
        if (text.length > 0) {
          this.ctx.fillStyle = this.cellColor(c);
          this.ctx.font = 'bold 12vp sans-serif';
          this.ctx.textAlign = 'center';
          this.ctx.textBaseline = 'middle';
          this.ctx.fillText(text, cx + WIDTHS[c] / 2, y + ROW_H / 2);
        }
      }
      this.ctx.restore();
    }
    // 冻结尾线
    this.ctx.strokeStyle = '#000000';
    this.ctx.lineWidth = 0.5;
    this.ctx.beginPath();
    this.ctx.moveTo(FROZEN_W, 0);
    this.ctx.lineTo(FROZEN_W, this.viewH);
    this.ctx.stroke();
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
      let now: number = Date.now();
      let dt: number = Math.min(0.05, (now - lastTime) / 1000);
      lastTime = now;
      let decay: number = Math.exp(-4.5 * dt);
      velocityX *= decay;
      velocityY *= decay;

      let nextX: number = this.offsetX - velocityX * dt;
      let nextY: number = this.offsetY - velocityY * dt;
      let maxX: number = this.maxOffsetX();
      let maxY: number = this.maxOffsetY();
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
    Column() {
      // ===== 表头（独立组件） =====
      Row() {
        Text(HEADS[0])
          .width(FROZEN_W)
          .height(HEAD_H)
          .backgroundColor('#E8F5E9')
          .zIndex(1)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
          .textAlign(TextAlign.Center)
          .border({ width: 0.5, color: '#000000' })

        Row() {
          ForEach(HEADS.slice(1), (title: string, index: number) => {
            Text(title)
              .width(WIDTHS[index + 1])
              .height(HEAD_H)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#000000')
              .textAlign(TextAlign.Center)
              .border({ width: 0.5, color: '#000000' })
          }, (title: string, index: number) => title + index.toString())
        }
        .translate({ x: -this.offsetX })
      }
      .width('100%')
      .height(HEAD_H)
      .backgroundColor('#E8F5E9')
      .clip(true)

      // ===== 表体 =====
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
          PanGesture()
            .onActionStart(() => {
              this.stopFling();
              this.lastPanX = 0;
              this.lastPanY = 0;
            })
            .onActionUpdate((event: GestureEvent) => {
              let dx: number = event.offsetX - this.lastPanX;
              let dy: number = event.offsetY - this.lastPanY;
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
        .onClick((event: ClickEvent) => {
          let row: number = Math.floor((event.y + this.offsetY) / ROW_H);
          if (row < 0 || row >= this.rows.length) {
            return;
          }
          this.openEditor(row, this.columnAt(event.x));
        })

      // ===== 表尾（独立组件） =====
      Row() {
        Text(this.footerText(0))
          .width(FROZEN_W)
          .height(FOOT_H)
          .zIndex(1)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F6B30')
          .textAlign(TextAlign.Center)
          .border({ width: 0.5, color: '#000000' })
          .backgroundColor('#EAF3EC')

        Row() {
          ForEach(HEADS.slice(1), (title: string, index: number) => {
            Text(this.footerText(index + 1))
              .width(WIDTHS[index + 1])
              .height(FOOT_H)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.footerColor(index + 1))
              .textAlign(TextAlign.Center)
              .border({ width: 0.5, color: '#000000' })
              .backgroundColor(this.footerCellBg(index + 1))
              .onClick(() => {
                if (index + 1 === 1) {
                  this.showHelp();
                } else if (index + 1 === 10) {
                  this.confirmReset();
                }
              })
          }, (title: string, index: number) => title + index.toString())
        }
        .translate({ x: -this.offsetX })
      }
      .width('100%')
      .height(FOOT_H)
      .backgroundColor('#EAF3EC')
      .clip(true)
    }
    .width('100%')
    .height('100%')
  }
}
