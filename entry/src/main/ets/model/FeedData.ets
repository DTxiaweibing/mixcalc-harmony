const NF_POWDER: number = 0;
const NF_FEED03: number = 1;
const NF_FEED05: number = 2;
const NF_FEED10: number = 3;

export class FeedData {
  shedNumber: string = '';
  shedCount: number = 0;
  defaultShedCount: number = 0;
  shedCountBase: number = 0;
  shedCountBaseSum: number = 0;
  average: number = 0;
  fermented: number = 0;
  powder: number = 0;
  feed03: number = 0;
  feed05: number = 0;
  feed10: number = 0;
  water: number = 0;
  weighed: number = 0;
  switchRatio: number = 0;
  isShedCountManuallyModified: boolean = false;
  isAverageManuallyModified: boolean = false;

  toJson(): Record<string, Object> {
    return {
      'shedNumber': this.shedNumber,
      'shedCount': this.shedCount,
      'shedCountBase': this.shedCountBase,
      'shedCountBaseSum': this.shedCountBaseSum,
      'average': this.average,
      'fermented': this.fermented,
      'powder': this.powder,
      'feed03': this.feed03,
      'feed05': this.feed05,
      'feed10': this.feed10,
      'water': this.water,
      'weighed': this.weighed,
      'switchRatio': this.switchRatio,
      'isShedCountManuallyModified': this.isShedCountManuallyModified,
      'isAverageManuallyModified': this.isAverageManuallyModified
    };
  }

  fromJson(obj: Record<string, Object>): void {
    this.shedNumber = obj['shedNumber'] as string;
    this.shedCount = obj['shedCount'] as number;
    this.shedCountBase = obj['shedCountBase'] as number;
    this.shedCountBaseSum = obj['shedCountBaseSum'] as number;
    this.average = obj['average'] as number;
    this.fermented = obj['fermented'] as number;
    this.powder = obj['powder'] as number;
    this.feed03 = obj['feed03'] as number;
    this.feed05 = obj['feed05'] as number;
    this.feed10 = obj['feed10'] as number;
    this.water = obj['water'] as number;
    this.weighed = obj['weighed'] as number;
    this.switchRatio = obj['switchRatio'] as number;
    this.isShedCountManuallyModified = obj['isShedCountManuallyModified'] as boolean;
    this.isAverageManuallyModified = obj['isAverageManuallyModified'] as boolean;
  }
  setShedNumber(value: string): void {
    this.shedNumber = value;
    if (!this.isShedCountManuallyModified) {
      this.calculateShedCount();
    }
  }

  private isValidNumber(text: string): boolean {
    return text.replace(/[^0-9]/g, '').length > 0;
  }

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
    }
    return this.isValidNumber(part) ? 1 : 0;
  }

  calculateShedCount(): void {
    if (this.isShedCountManuallyModified) {
      return;
    }
    let text: string = this.shedNumber.trim();
    if (text.length === 0) {
      this.shedCount = 0;
      this.defaultShedCount = 0;
      return;
    }
    let parts: string[] = text.split(/[,，、\s]+/);
    let total: number = 0;
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].trim().length > 0) {
        total += this.parsePart(parts[i].trim());
      }
    }
    this.shedCount = Math.max(0, total);
    this.defaultShedCount = this.shedCount;
  }

  private nonFermentedSum(): number {
    return this.powder + this.feed03 + this.feed05 + this.feed10;
  }

  getNonFermentedValue(index: number): number {
    switch (index) {
      case NF_POWDER: return this.powder;
      case NF_FEED03: return this.feed03;
      case NF_FEED05: return this.feed05;
      case NF_FEED10: return this.feed10;
      default: return 0;
    }
  }

  setNonFermentedValue(index: number, value: number): void {
    switch (index) {
      case NF_POWDER: this.powder = value; break;
      case NF_FEED03: this.feed03 = value; break;
      case NF_FEED05: this.feed05 = value; break;
      case NF_FEED10: this.feed10 = value; break;
      default: break;
    }
  }

  countNonFermentedFeeds(): number {
    let count: number = 0;
    for (let i = NF_POWDER; i <= NF_FEED10; i++) {
      if (this.getNonFermentedValue(i) > 0) {
        count++;
      }
    }
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

  calculateWeighedFeed(fermentedInWater: boolean): void {
    let total: number = this.nonFermentedSum() + this.water + this.fermented;
    this.weighed = this.shedCount > 0 ? total / this.shedCount : 0;
  }

  canEditAverage(): boolean {
    if (this.shedCount <= 0) {
      return false;
    }
    let nf: number = this.countNonFermentedFeeds();
    if (nf >= 3) {
      return false;
    }
    if (nf === 0 && this.fermented <= 0) {
      return false;
    }
    return true;
  }

  setAverageManually(value: number, fermentedInAverage: boolean): void {
    this.average = value;
    if (value > 0 && this.canEditAverage()) {
      this.isAverageManuallyModified = true;
      this.applyManualAverage(fermentedInAverage);
    } else {
      this.isAverageManuallyModified = false;
    }
  }

  private applyManualAverage(fermentedInAverage: boolean): void {
    let amount: number = this.average * this.shedCount;
    let nf: number = this.countNonFermentedFeeds();
    if (nf === 0) {
      if (this.fermented > 0) {
        this.fermented = amount;
      }
      return;
    }
    let base: number = amount;
    if (fermentedInAverage && this.fermented > 0) {
      base -= this.fermented;
    }
    if (base < 0) {
      base = 0;
    }
    if (nf === 1) {
      let small: number = -1;
      for (let i = NF_POWDER; i <= NF_FEED10; i++) {
        if (this.getNonFermentedValue(i) > 0) {
          small = i;
          break;
        }
      }
      if (small >= 0 && this.switchRatio > 0 && small + 1 <= NF_FEED10) {
        let ratio: number = Math.min(0.9, Math.max(0.1, this.switchRatio));
        this.setNonFermentedValue(small + 1, base * ratio);
        this.setNonFermentedValue(small, base * (1 - ratio));
      } else if (small >= 0) {
        this.setNonFermentedValue(small, base);
      }
    } else if (nf === 2) {
      let small: number = -1;
      let large: number = -1;
      for (let i = NF_POWDER; i <= NF_FEED10; i++) {
        if (this.getNonFermentedValue(i) > 0) {
          if (small < 0) {
            small = i;
          } else {
            large = i;
            break;
          }
        }
      }
      let ratio: number = this.switchRatio;
      if (ratio <= 0 || ratio >= 1) {
        let sv: number = this.getNonFermentedValue(small);
        let lv: number = this.getNonFermentedValue(large);
        let sum: number = sv + lv;
        ratio = sum > 0 ? lv / sum : 0.5;
      }
      ratio = Math.min(0.9, Math.max(0.1, ratio));
      this.setNonFermentedValue(large, base * ratio);
      this.setNonFermentedValue(small, base * (1 - ratio));
    }
  }

  mergeSmallerWhenCleared(clearedIndex: number, amount: number): number {
    if (clearedIndex < NF_POWDER || clearedIndex > NF_FEED10 || amount <= 0) {
      return 0;
    }
    let coarserIndex: number = -1;
    let coarserCount: number = 0;
    for (let i = NF_POWDER; i <= NF_FEED10; i++) {
      if (i === clearedIndex || this.getNonFermentedValue(i) <= 0) {
        continue;
      }
      if (i < clearedIndex) {
        return 0;
      }
      coarserIndex = i;
      coarserCount++;
    }
    if (coarserCount !== 1) {
      return 0;
    }
    this.setNonFermentedValue(coarserIndex, this.getNonFermentedValue(coarserIndex) + amount);
    this.setNonFermentedValue(clearedIndex, 0);
    this.switchRatio = 0;
    return amount;
  }

  recalculateDerivedOnly(waterPercentage: number, fermentedInWater: boolean,
                         fermentedInAverage: boolean): void {
    if (this.isAverageManuallyModified) {
      if (this.canEditAverage()) {
        this.applyManualAverage(fermentedInAverage);
      } else {
        this.isAverageManuallyModified = false;
      }
    }
    if (!this.isAverageManuallyModified) {
      this.calculateAverage(fermentedInAverage);
    }
    this.calculateWater(waterPercentage, fermentedInWater);
    this.calculateWeighedFeed(fermentedInWater);
  }

  updateAllCalculations(waterPercentage: number, fermentedInWater: boolean,
                        fermentedInAverage: boolean): void {
    if (this.countNonFermentedFeeds() !== 2) {
      this.switchRatio = 0;
    }
    if (!this.isShedCountManuallyModified) {
      this.calculateShedCount();
    }
    this.recalculateDerivedOnly(waterPercentage, fermentedInWater, fermentedInAverage);
  }
}