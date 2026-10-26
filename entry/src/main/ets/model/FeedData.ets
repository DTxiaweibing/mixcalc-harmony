export class FeedData {
  shedNumber: string = '';
  shedCount: number = 0;
  average: number = 0;
  fermented: number = 0;
  powder: number = 0;
  feed03: number = 0;
  feed05: number = 0;
  feed10: number = 0;
  water: number = 0;
  weighed: number = 0;
  shedCountBase: number = 0;
  shedCountBaseSum: number = 0;
  isShedCountManuallyModified: boolean = false;
  isAverageManuallyModified: boolean = false;

  private parsePart(part: string): number {
    if (part.length === 0) {
      return 0;
    }
    let normalized: string = part
      .replace(/到/g, '-')
      .replace(/至/g, '-')
      .replace(/~/g, '-')
      .replace(/—/g, '-');
    if (normalized.indexOf('-') >= 0) {
      let seg: string[] = normalized.split('-');
      if (seg.length >= 2) {
        let a: number = parseInt(seg[0].replace(/[^0-9]/g, ''), 10);
        let b: number = parseInt(seg[1].replace(/[^0-9]/g, ''), 10);
        if (!isNaN(a) && !isNaN(b) && a > 0 && b > 0) {
          return Math.abs(b - a) + 1;
        }
      }
      return 0;
    }
    let single: number = parseInt(normalized.replace(/[^0-9]/g, ''), 10);
    return isNaN(single) ? 0 : (single > 0 ? 1 : 0);
  }

  calculateShedCount(): void {
    if (this.isShedCountManuallyModified) {
      return;
    }
    let text: string = this.shedNumber.trim();
    if (text.length === 0) {
      this.shedCount = 0;
      return;
    }
    let parts: string[] = text.split(/[,，、\s]+/);
    let total: number = 0;
    for (let i = 0; i < parts.length; i++) {
      total += this.parsePart(parts[i].trim());
    }
    this.shedCount = Math.max(0, total);
  }

  private nonFermentedSum(): number {
    return this.powder + this.feed03 + this.feed05 + this.feed10;
  }

  countNonFermentedFeeds(): number {
    let count: number = 0;
    if (this.powder > 0) count++;
    if (this.feed03 > 0) count++;
    if (this.feed05 > 0) count++;
    if (this.feed10 > 0) count++;
    return count;
  }

  calculateAverage(fermentedInAverage: boolean): void {
    let sum: number = this.nonFermentedSum();
    if (fermentedInAverage) {
      sum += this.fermented;
    }
    this.average = this.shedCount > 0 ? sum / this.shedCount : 0;
  }

  calculateWater(waterPercentage: number, fermentedInWater: boolean): void {
    let sum: number = this.nonFermentedSum();
    if (fermentedInWater) {
      sum += this.fermented;
    }
    this.water = sum * waterPercentage / 100.0;
  }

  calculateWeighedFeed(): void {
    let total: number = this.nonFermentedSum() + this.water + this.fermented;
    this.weighed = this.shedCount > 0 ? total / this.shedCount : 0;
  }

  /** 只重算派生值，棚数不动。 */
  recalculateDerivedOnly(waterPercentage: number, fermentedInWater: boolean,
                         fermentedInAverage: boolean): void {
    if (!this.isAverageManuallyModified) {
      this.calculateAverage(fermentedInAverage);
    }
    this.calculateWater(waterPercentage, fermentedInWater);
    this.calculateWeighedFeed();
  }

  updateAllCalculations(waterPercentage: number, fermentedInWater: boolean,
                        fermentedInAverage: boolean): void {
    if (!this.isShedCountManuallyModified) {
      this.calculateShedCount();
    }
    if (!this.isAverageManuallyModified) {
      this.calculateAverage(fermentedInAverage);
    }
    this.calculateWater(waterPercentage, fermentedInWater);
    this.calculateWeighedFeed();
  }
}