import { FeedData } from '../model/FeedData';

class Metrics {
  rowH: number = 40;
  headH: number = 40;
  footH: number = 40;
  widths: number[] = [40, 60, 40, 40, 60, 60, 60, 60, 60, 60, 60];
  heads: string[] = ['序号', '棚号', '棚数', '平均', '发酵料', '粉料', '0.3料', '0.5料', '1.0料', '水', '称料'];
}


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
@Component
export struct MixCalcTable {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private metrics: Metrics = new Metrics();

  rows: FeedData[] = [];
  onChanged: () => void = () => {};
  private offsetX: number = 0;
  private offsetY: number = 0;
  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private flingTimer: number = -1;
  private widthVp: number = 0;
  private heightVp: number = 0;
  private frozenW: number = 40;

  @State editing: boolean = false;
  @State editText: string = '';
  private editRow: number = -1;
  private editCol: number = -1;
  private editX: number = 0;
  private editY: number = 0;
  private editW: number = 0;

  waterPercentage: number = 20;
  fermentedInWater: boolean = false;
  fermentedInAverage: boolean = false;

  private readonly headBg: string = '#E8F5E9';
  private readonly footBg: string = '#EAF3EC';
  private readonly gridColor: string = '#000000';
  private readonly textBlack: string = '#000000';
  private readonly textGray: string = '#666666';
  private readonly textBlue: string = '#0000FF';
  private readonly footText: string = '#1F6B30';

  editorTitle: string = '';
  editorValue: string = '';
  editorIsNumber: boolean = false;
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
  private isEditableColumn(column: number): boolean {
    return column >= 1 && column <= 8;
  }

  private columnAt(x: number): number {
    if (x < this.frozenW) {
      return 0;
    }
    for (let c = 1; c < this.metrics.widths.length; c++) {
      let cx: number = this.xOfColumn(c) - this.offsetX;
      if (x >= cx && x < cx + this.metrics.widths[c]) {
        return c;
      }
    }
    return -1;
  }

  private xOfColumn(index: number): number {
    let x: number = 0;
    for (let i = 0; i < index; i++) {
      x += this.metrics.widths[i];
    }
    return x;
  }

  private columnTitle(column: number): string {
    switch (column) {
      case 1: return '棚号';
      case 2: return '棚数';
      case 3: return '平均';
      case 4: return '发酵料';
      case 5: return '粉料';
      case 6: return '0.3料';
      case 7: return '0.5料';
      case 8: return '1.0料';
      default: return '';
    }
  }

  private currentValue(row: number, column: number): string {
    let data: FeedData = this.rows[row];
    if (column === 1) {
      return data.shedNumber;
    }
    let value: number = 0;
    switch (column) {
      case 2: value = data.shedCount; break;
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

  private nfIndexOf(column: number): number {
    switch (column) {
      case 5: return 0;
      case 6: return 1;
      case 7: return 2;
      case 8: return 3;
      default: return -1;
    }
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

    // 安卓 applyRowChange：第 2 行起，没有棚数就清空料格
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
    this.draw();
  }

  /** 清空一行数据；keepShedNumber 为 true 时保留棚号。 */
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
    row.isAverageManuallyModified = false;
  }

  private showHelp(): void {
    AlertDialog.show({
      title: '使用帮助',
      message: '1. 第一行填总棚号（如 1-40），后面各行填细分棚号，第一行棚数会自动扣减。\n2. 点单元格修改数值，确定后自动计算平均、水、称料。\n3. 长按较大料格可设置换料比例（后续版本）。',
      confirm: {
        value: '知道了',
        action: () => {
        }
      }
    });
  }

  private confirmReset(): void {
    AlertDialog.show({
      title: '重置数据',
      message: '将清空当前批次的所有行，确定继续？',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确定',
        action: () => {
          this.resetAll();
        }
      }
    });
  }

  private resetAll(): void {
    for (let i = 0; i < this.rows.length; i++) {
      let r: FeedData = this.rows[i];
      r.shedNumber = '';
      r.shedCount = 0;
      r.average = 0;
      r.fermented = 0;
      r.powder = 0;
      r.feed03 = 0;
      r.feed05 = 0;
      r.feed10 = 0;
      r.water = 0;
      r.weighed = 0;
      r.shedCountBase = 0;
      r.shedCountBaseSum = 0;
      r.isShedCountManuallyModified = false;
      r.isAverageManuallyModified = false;
    }
    this.recomputeFirstRow();
    this.draw();
  }
  private sumBelowFirst(): number {
    let sum: number = 0;
    for (let i = 1; i < this.rows.length; i++) {
      sum += this.rows[i].shedCount;
    }
    return sum;
  }

  /** 第一行是总棚数：自动扣掉后面各行已用的棚数。 */
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

    // 棚数变了就钉住每棚平均，避免平均被重新除出来
    if (remainder !== oldCount && oldAverage > 0 && !first.isAverageManuallyModified) {
      first.average = oldAverage;
      first.isAverageManuallyModified = true;
    }
    first.recalculateDerivedOnly(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
  }
  private openEditor(row: number, column: number): void {
    if (!this.isEditableColumn(column)) {
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
  private totalWidth(): number {
    let sum: number = 0;
    for (let i = 0; i < this.metrics.widths.length; i++) {
      sum += this.metrics.widths[i];
    }
    return sum;
  }

  private bodyHeight(): number {
    return this.rows.length * this.metrics.rowH;
  }

  private maxOffsetX(): number {
    return Math.max(0, this.totalWidth() - this.widthVp);
  }

  private maxOffsetY(): number {
    let visible: number = this.heightVp - this.metrics.headH - this.metrics.footH;
    return Math.max(0, this.bodyHeight() - visible);
  }

  private clampOffsets(): void {
    this.offsetX = Math.min(Math.max(0, this.offsetX), this.maxOffsetX());
    this.offsetY = Math.min(Math.max(0, this.offsetY), this.maxOffsetY());
  }

  private drawBox(x: number, y: number, w: number, h: number): void {
    this.ctx.strokeStyle = this.gridColor;
    this.ctx.lineWidth = 0.5;
    this.ctx.strokeRect(x, y, w, h);
  }

  private drawText(x: number, y: number, w: number, h: number, text: string, color: string): void {
    if (text.length === 0) {
      return;
    }
    this.ctx.fillStyle = color;
    this.ctx.font = 'bold 12vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    let measure: number = this.ctx.measureText(text).width;
    let clipped: string = text;
    while (measure > w - 4 && clipped.length > 1) {
      clipped = clipped.substring(0, clipped.length - 1);
      measure = this.ctx.measureText(clipped + '…').width;
    }
    if (clipped.length < text.length) {
      clipped = clipped + '…';
    }
    this.ctx.fillText(clipped, x + w / 2, y + h / 2);
  }

  private drawCell(x: number, y: number, w: number, h: number, text: string, color: string): void {
    this.drawBox(x, y, w, h);
    this.drawText(x, y, w, h, text, color);
  }

  private cellText(row: FeedData, column: number): string {
    switch (column) {
      case 1: return row.shedNumber;
      case 2: return row.shedCount > 0 ? row.shedCount.toString() : '';
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
      return this.textGray;
    }
    if (column === 3 || column === 9 || column === 10) {
      return this.textBlue;
    }
    return this.textBlack;
  }

  private drawHeader(): void {
    this.ctx.fillStyle = this.headBg;
    this.ctx.fillRect(0, 0, this.widthVp, this.metrics.headH);

    let x: number = 0;
    for (let c = 0; c < this.metrics.heads.length; c++) {
      let cx: number = x - (c === 0 ? 0 : this.offsetX);
      let w: number = this.metrics.widths[c];
      if (c > 0 && cx + w <= this.frozenW) {
        x += w;
        continue;
      }
      if (c > 0) {
        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.rect(this.frozenW, 0, this.widthVp - this.frozenW, this.metrics.headH);
        this.ctx.clip();
        this.drawCell(cx, 0, w, this.metrics.headH, this.metrics.heads[c], this.textBlack);
        this.ctx.restore();
      } else {
        this.drawCell(0, 0, w, this.metrics.headH, this.metrics.heads[0], this.textBlack);
      }
      x += w;
    }
  }

  private drawBody(): void {
    let top: number = this.metrics.headH;
    let bottom: number = this.heightVp - this.metrics.footH;

    for (let r = 0; r < this.rows.length; r++) {
      let y: number = top + r * this.metrics.rowH - this.offsetY;
      if (y + this.metrics.rowH < top || y > bottom) {
        continue;
      }
      let row: FeedData = this.rows[r];

      this.ctx.save();
      this.ctx.beginPath();
      this.ctx.rect(0, top, this.widthVp, bottom - top);
      this.ctx.clip();

      let x: number = 0;
      for (let c = 0; c < this.metrics.widths.length; c++) {
        let cx: number = x - (c === 0 ? 0 : this.offsetX);
        let w: number = this.metrics.widths[c];
        if (c === 0) {
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(0, y, w, this.metrics.rowH);
          this.drawCell(0, y, w, this.metrics.rowH, (r + 1).toString(), this.textGray);
        } else if (cx + w > this.frozenW) {
          this.ctx.save();
          this.ctx.beginPath();
          this.ctx.rect(this.frozenW, top, this.widthVp - this.frozenW, bottom - top);
          this.ctx.clip();
          this.ctx.fillStyle = '#FFFFFF';
          this.ctx.fillRect(Math.max(cx, this.frozenW), y, w, this.metrics.rowH);
          this.drawCell(cx, y, w, this.metrics.rowH, this.cellText(row, c), this.cellColor(c));
          this.ctx.restore();
        }
        x += w;
      }
      this.ctx.restore();
    }
  }

  private sumColumn(column: number): number {
    let s: number = 0;
    for (let i = 0; i < this.rows.length; i++) {
      let row: FeedData = this.rows[i];
      switch (column) {
        case 2: s += row.shedCount; break;
        case 4: s += row.fermented; break;
        case 5: s += row.powder; break;
        case 6: s += row.feed03; break;
        case 7: s += row.feed05; break;
        case 8: s += row.feed10; break;
        case 9: s += row.water; break;
        case 10: s += row.weighed; break;
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

  private footerColor(c: number): string {
    if (c === 1 || c === 10) {
      return '#FFFFFF';
    }
    return this.footText;
  }

  private footerCellBg(c: number): string {
    if (c === 1) {
      return '#000042';
    }
    if (c === 10) {
      return '#960018';
    }
    return this.footBg;
  }
  private drawFooter(): void {
    let y: number = this.heightVp - this.metrics.footH;
    this.ctx.fillStyle = this.footBg;
    this.ctx.fillRect(0, y, this.widthVp, this.metrics.footH);

    // 首列（已填行数/总行数）不参与横向偏移
    this.ctx.fillStyle = this.footBg;
    this.ctx.fillRect(0, y, this.frozenW, this.metrics.footH);
    this.drawCell(0, y, this.frozenW, this.metrics.footH, this.footerText(0), this.footerColor(0));

    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.rect(this.frozenW, y, Math.max(0, this.widthVp - this.frozenW), this.metrics.footH);
    this.ctx.clip();

    let x: number = this.frozenW;
    for (let c = 1; c < this.metrics.widths.length; c++) {
      let cx: number = x - this.offsetX;
      let w: number = this.metrics.widths[c];
      this.ctx.fillStyle = this.footerCellBg(c);
      this.ctx.fillRect(cx, y, w, this.metrics.footH);
      this.drawCell(cx, y, w, this.metrics.footH, this.footerText(c), this.footerColor(c));
      x += w;
    }
    this.ctx.restore();
  }

  private stopFling(): void {
    if (this.flingTimer !== -1) {
      clearInterval(this.flingTimer);
      this.flingTimer = -1;
    }
  }

  /** 松手后的惯性滑动：指数衰减，撞到边界即停该轴。 */
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
      this.draw();
      if (Math.abs(velocityX) < 15 && Math.abs(velocityY) < 15) {
        this.stopFling();
      }
    }, 16);
  }

  aboutToDisappear(): void {
    this.stopFling();
  }
  private draw(): void {
    if (this.widthVp <= 0 || this.heightVp <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, this.widthVp, this.heightVp);
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.fillRect(0, 0, this.widthVp, this.heightVp);
    this.clampOffsets();
    this.drawBody();
    this.drawHeader();
    this.drawFooter();
  }

  aboutToAppear(): void {
    for (let i = 0; i < this.rows.length; i++) {
      this.rows[i].updateAllCalculations(this.waterPercentage, this.fermentedInWater, this.fermentedInAverage);
    }
    this.recomputeFirstRow();
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.widthVp = this.ctx.width;
        this.heightVp = this.ctx.height;
        this.draw();
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.widthVp = Number(newValue.width);
        this.heightVp = Number(newValue.height);
        this.draw();
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
            this.draw();
          })
          .onActionEnd((event: GestureEvent) => {
            this.startFling(event.velocityX, event.velocityY);
          })
      )
      .onClick((event: ClickEvent) => {
        let y: number = event.y;
        if (y < this.metrics.headH || y >= this.heightVp - this.metrics.footH) {
          return;
        }
        let row: number = Math.floor((y - this.metrics.headH + this.offsetY) / this.metrics.rowH);
        if (row < 0 || row >= this.rows.length) {
          return;
        }
        this.openEditor(row, this.columnAt(event.x));
      })
  }
}
