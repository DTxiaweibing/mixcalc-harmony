import { FeedData } from './FeedData';

export class Batch {
  rows: FeedData[] = [];
  waterPercentage: number = 20;
  fermentedInWater: boolean = false;
  fermentedInAverage: boolean = false;
  columnVisibility: Record<string, boolean> = {};
  columnFixed: Record<string, boolean> = {};

  constructor(rowCount: number) {
    for (let i = 0; i < rowCount; i++) {
      this.rows.push(new FeedData());
    }
  }

  toJson(): Record<string, Object> {
    const rowArr: Record<string, Object>[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      rowArr.push(this.rows[i].toJson());
    }
    return {
      'water': this.waterPercentage,
      'fermentedWater': this.fermentedInWater,
      'fermentedAverage': this.fermentedInAverage,
      'columns': this.columnVisibility,
      'fixed': this.columnFixed,
      'rows': rowArr
    };
  }

  static fromJson(obj: Record<string, Object>, rowCount: number): Batch {
    let batch: Batch = new Batch(rowCount);
    if (obj === undefined || obj === null) {
      return batch;
    }
    const water = obj['water'] as number;
    if (water !== undefined) {
      batch.waterPercentage = water;
    }
    const fw = obj['fermentedWater'] as boolean;
    if (fw !== undefined) {
      batch.fermentedInWater = fw;
    }
    const fa = obj['fermentedAverage'] as boolean;
    if (fa !== undefined) {
      batch.fermentedInAverage = fa;
    }
    const cols = obj['columns'] as Record<string, boolean>;
    if (cols !== undefined && cols !== null) {
      batch.columnVisibility = cols;
    }
    const fixed = obj['fixed'] as Record<string, boolean>;
    if (fixed !== undefined && fixed !== null) {
      batch.columnFixed = fixed;
    }
    const rows = obj['rows'] as Record<string, Object>[];
    if (rows !== undefined && rows !== null) {
      let count: number = Math.min(rows.length, rowCount);
      for (let i = 0; i < count; i++) {
        if (rows[i] !== undefined && rows[i] !== null) {
          batch.rows[i].fromJson(rows[i]);
        }
      }
    }
    return batch;
  }
}