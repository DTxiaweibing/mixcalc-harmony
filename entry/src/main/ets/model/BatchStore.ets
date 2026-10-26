import { preferences } from '@kit.ArkData';
import { Batch } from './Batch';

export const BATCH_COUNT: number = 2;
const KEY_BATCHES: string = 'batches_v2';
const KEY_ACTIVE_BATCH: string = 'active_batch';
const KEY_LEGACY_DATA: string = 'saved_data';

export class BatchStore {
  /** 读取两个批次；没有 batches_v2 时从旧的 saved_data 迁移到批次01。 */
  static async load(store: preferences.Preferences, rowCount: number): Promise<Batch[]> {
    let text: string = '';
    try {
      text = await store.get(KEY_BATCHES, '') as string;
    } catch (e) {
      text = '';
    }

    if (text.length > 0) {
      try {
        const arr = JSON.parse(text) as Record<string, Object>[];
        const batches: Batch[] = [];
        for (let i = 0; i < arr.length && i < BATCH_COUNT; i++) {
          batches.push(Batch.fromJson(arr[i], rowCount));
        }
        while (batches.length < BATCH_COUNT) {
          batches.push(new Batch(rowCount));
        }
        return batches;
      } catch (e) {
        // 落到迁移逻辑
      }
    }
    return await BatchStore.migrateLegacy(store, rowCount);
  }

  private static async migrateLegacy(store: preferences.Preferences, rowCount: number): Promise<Batch[]> {
    const first: Batch = new Batch(rowCount);
    let legacy: string = '';
    try {
      legacy = await store.get(KEY_LEGACY_DATA, '') as string;
    } catch (e) {
      legacy = '';
    }
    if (legacy.length > 0) {
      try {
        const arr = JSON.parse(legacy) as Record<string, Object>[];
        let count: number = Math.min(arr.length, rowCount);
        for (let i = 0; i < count; i++) {
          first.rows[i].fromJson(arr[i]);
        }
      } catch (e) {
        // 忽略损坏数据
      }
    }
    const batches: Batch[] = [first];
    for (let i = 1; i < BATCH_COUNT; i++) {
      batches.push(new Batch(rowCount));
    }
    await BatchStore.save(store, batches, 0);
    return batches;
  }

  static async save(store: preferences.Preferences, batches: Batch[], activeIndex: number): Promise<void> {
    const arr: Record<string, Object>[] = [];
    for (let i = 0; i < batches.length; i++) {
      arr.push(batches[i].toJson());
    }
    await store.put(KEY_BATCHES, JSON.stringify(arr));
    await store.put(KEY_ACTIVE_BATCH, activeIndex);
    await store.flush();
  }

  static async loadActive(store: preferences.Preferences): Promise<number> {
    let value: number = 0;
    try {
      value = await store.get(KEY_ACTIVE_BATCH, 0) as number;
    } catch (e) {
      value = 0;
    }
    if (value < 0 || value >= BATCH_COUNT) {
      value = 0;
    }
    return value;
  }
}