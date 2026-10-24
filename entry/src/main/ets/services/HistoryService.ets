import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { preferences } from '@kit.ArkData';
import { Logger } from '../common/Logger';

export interface HistoryItem {
  filePath: string;   // đường dẫn JPEG crop trong cacheDir/history
  mode: string;       // 'search' | 'ocr' | 'translate'
  createdAt: number;  // timestamp ms
}

/**
 * Service lưu lịch sử các vùng ảnh đã khoanh (tối đa 20 mục gần nhất).
 * - File JPEG lưu trong filesDir/history để hệ thống không tự xóa như cache
 * - Metadata (path + mode + time) lưu trong Preferences
 */
export class HistoryService {
  private static readonly PREF_NAME: string = 'lens_history';
  private static readonly KEY_ITEMS: string = 'history_items';
  private static readonly MAX_ITEMS: number = 20;

  private static async openPreferences(context: common.UIAbilityContext): Promise<preferences.Preferences> {
    try {
      return preferences.getPreferencesSync(context, { name: HistoryService.PREF_NAME });
    } catch (error) {
      Logger.error('Không thể mở kho lưu lịch sử: %{public}s', String(error));
      throw new Error('Không thể mở kho lưu lịch sử');
    }
  }

  /**
   * Lưu một ảnh crop vào lịch sử (tự dọn mục cũ vượt quá 20)
   */
  public static async addItem(context: common.UIAbilityContext, pixelMap: image.PixelMap, mode: string): Promise<void> {
    try {
      // 1. Nén và ghi file
      const packer = image.createImagePacker();
      const jpegBytes = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 80 });
      await packer.release();

      const dir = `${context.filesDir}/history`;
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
      const filePath = `${dir}/lens_crop_${Date.now()}.jpg`;
      const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      try {
        fileIo.writeSync(file.fd, jpegBytes);
      } finally {
        fileIo.closeSync(file);
      }

      // 2. Cập nhật metadata trong Preferences
      const prefs = await HistoryService.openPreferences(context);
      const items = HistoryService.readItems(prefs);
      items.unshift({ filePath: filePath, mode: mode, createdAt: Date.now() });

      // 3. Giữ tối đa MAX_ITEMS, xóa file của mục bị loại
      while (items.length > HistoryService.MAX_ITEMS) {
        const removed = items.pop();
        if (removed && fileIo.accessSync(removed.filePath)) {
          try {
            fileIo.unlinkSync(removed.filePath);
          } catch (e) {
            Logger.warn('Không xóa được file cũ: %{public}s', removed.filePath);
          }
        }
      }

      prefs.putSync(HistoryService.KEY_ITEMS, JSON.stringify(items));
      prefs.flush();
      Logger.info('Đã lưu lịch sử: %{public}s (mode=%{public}s)', filePath, mode);
    } catch (err) {
      Logger.error('Lỗi khi lưu lịch sử: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * Đọc danh sách lịch sử (mới nhất lên đầu)
   */
  public static async getItems(context: common.UIAbilityContext): Promise<HistoryItem[]> {
    try {
      const prefs = await HistoryService.openPreferences(context);
      const items = HistoryService.readItems(prefs);
      // Bỏ mục có file đã bị hệ thống dọn cache
      return items.filter((it) => fileIo.accessSync(it.filePath));
    } catch (err) {
      Logger.error('Lỗi khi đọc lịch sử: %{public}s', JSON.stringify(err));
      return [];
    }
  }

  /**
   * Xóa toàn bộ lịch sử (file + metadata)
   */
  public static async clearAll(context: common.UIAbilityContext): Promise<void> {
    try {
      const prefs = await HistoryService.openPreferences(context);
      const items = HistoryService.readItems(prefs);
      for (const it of items) {
        if (fileIo.accessSync(it.filePath)) {
          try {
            fileIo.unlinkSync(it.filePath);
          } catch (e) {
            // bỏ qua lỗi xóa từng file
          }
        }
      }
      prefs.putSync(HistoryService.KEY_ITEMS, JSON.stringify([]));
      prefs.flush();
      Logger.info('Đã xóa toàn bộ lịch sử');
    } catch (err) {
      Logger.error('Lỗi khi xóa lịch sử: %{public}s', JSON.stringify(err));
    }
  }

  private static readItems(prefs: preferences.Preferences): HistoryItem[] {
    try {
      const raw = prefs.getSync(HistoryService.KEY_ITEMS, '[]') as string;
      const parsed: object = JSON.parse(raw) as object;
      if (Array.isArray(parsed)) {
        return parsed as HistoryItem[];
      }
      return [];
    } catch (error) {
      Logger.warn('Không thể đọc dữ liệu lịch sử: %{public}s', String(error));
      return [];
    }
  }
}
