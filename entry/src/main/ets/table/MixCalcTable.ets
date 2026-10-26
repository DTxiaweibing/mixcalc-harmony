import { FeedData } from '../model/FeedData';

class Metrics {
  rowH: number = 40;
  headH: number = 40;
  footH: number = 40;
  widths: number[] = [40, 60, 40, 40, 60, 60, 60, 60, 60, 60, 60];
  heads: string[] = ['序号', '棚号', '棚数', '平均', '发酵料', '粉料', '0.3料', '0.5料', '1.0料', '水', '称料'];
}

@Component
export struct MixCalcTable {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private metrics: Metrics = new Metrics();

  rows: FeedData[] = [];
  private offsetX: number = 0;
  private offsetY: number = 0;
  private lastPanX: number = 0;
  private lastPanY: number = 0;
  private flingTimer: number = -1;
  private widthVp: number = 0;
  private heightVp: number = 0;
  private frozenW: number = 40;

  private readonly headBg: string = '#E8F5E9';
  private readonly footBg: string = '#EAF3EC';
  private readonly gridColor: string = '#000000';
  private readonly textBlack: string = '#000000';
  private readonly textGray: string = '#666666';
  private readonly textBlue: string = '#0000FF';
  private readonly footText: string = '#1F6B30';

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
    if (c === 1) {
      return '#0000FF';
    }
    if (c === 10) {
      return '#960018';
    }
    return this.footText;
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
      this.ctx.fillStyle = this.footBg;
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
          .onActionEnd((event: GestureEvent) => {
            this.startFling(event.velocityX, event.velocityY);
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
      )
  }
}