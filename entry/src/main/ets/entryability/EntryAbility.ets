import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { screenshot, window } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { CropNotificationService } from '../services/CropNotificationService';
import { ImageService } from '../services/ImageService';
import { image } from '@kit.ImageKit';

/**
 * EntryAbility: Điểm khởi nhập chính của ứng dụng.
 *
 * Hai điểm vào tách biệt:
 * - Mở app bình thường: trang cấu hình Index.
 * - Smart Sidebar: tạo notification để người dùng chủ động mở luồng crop.
 * - Notification hoặc Share Sheet: vào thẳng CircleCropPage.
 */
export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private pendingPage: string = 'pages/Index';
  // screenshot.pick() cần một UIAbility đã có WindowStage. Với notification, app
  // thường vừa mới được khởi tạo nên phải trì hoãn tới khi setUIContent hoàn tất.
  private shouldPickScreenRegion: boolean = false;
  private isPickingScreenRegion: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('EntryAbility onCreate, action: %{public}s', want.action || '');
    this.routeWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Logger.info('EntryAbility onNewWant, action: %{public}s', want.action || '');
    this.routeWant(want);
  }

  private routeWant(want: Want): void {
    if (want.action === Constants.ACTION_SEND_DATA && want.uri) {
      this.loadSharedImage(want.uri);
      return;
    }
    if (want.action === Constants.ACTION_OPEN_CROP) {
      this.requestScreenRegion();
      return;
    }
    if (want.action === Constants.ACTION_HOME) {
      this.publishSidebarNotification();
      return;
    }
    this.showPage('pages/Index');
  }

  private loadSharedImage(uri: string): void {
    Logger.info('Nhận ảnh chia sẻ: %{public}s', uri);
    ImageService.loadPixelMapFromUri(uri)
      .then((pixelMap: image.PixelMap) => {
        AppStorage.setOrCreate<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP, pixelMap);
        AppStorage.setOrCreate<string>(Constants.KEY_IMAGE_SOURCE, Constants.SOURCE_SHARED);
        this.showPage('pages/CircleCropPage');
      })
      .catch((err: Error) => {
        Logger.error('Nạp ảnh chia sẻ thất bại: %{public}s', JSON.stringify(err));
        this.showPage('pages/Index');
      });
  }

  /**
   * Gọi trình chọn vùng chụp của HarmonyOS. API này do hệ thống hiển thị nên người
   * dùng luôn kiểm soát vùng được chụp; app không cần và cũng không thể có quyền
   * tự đọc toàn bộ màn hình của app khác.
   */
  private pickScreenRegion(): void {
    if (this.isPickingScreenRegion) {
      return;
    }
    this.isPickingScreenRegion = true;
    AppStorage.setOrCreate<image.PixelMap | null>(Constants.KEY_PENDING_PIXELMAP, null);
    screenshot.pick()
      .then((picked: screenshot.PickInfo) => {
        AppStorage.setOrCreate<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP, picked.pixelMap);
        AppStorage.setOrCreate<string>(Constants.KEY_IMAGE_SOURCE, Constants.SOURCE_CAPTURE);
        Logger.info('Đã nhận vùng chụp hệ thống: %{public}dx%{public}d', picked.pickRect.width, picked.pickRect.height);
        this.showPage('pages/CircleCropPage');
      })
      .catch((err: Error) => {
        Logger.warn('Người dùng hủy hoặc không mở được trình chọn vùng chụp: %{public}s', JSON.stringify(err));
        this.showPage('pages/CircleCropPage');
      })
      .finally(() => {
        this.isPickingScreenRegion = false;
      });
  }

  /** Đợi WindowStage sẵn sàng rồi mới gọi system picker. */
  private requestScreenRegion(): void {
    this.pendingPage = 'pages/Index';
    this.shouldPickScreenRegion = true;
    if (this.mainWindow) {
      this.showPage(this.pendingPage);
    }
  }

  private publishSidebarNotification(): void {
    CropNotificationService.publish(this.context).then((published: boolean) => {
      if (published) {
        Logger.info('Smart Sidebar đã chuyển sang notification crop');
        this.context.terminateSelf();
      }
    });
  }

  /**
   * Nạp (hoặc nạp lại) trang khoanh tròn lên cửa sổ chính
   */
  private showPage(page: string): void {
    this.pendingPage = page;
    if (!this.mainWindow) return;
    this.mainWindow.setUIContent(page, (err) => {
      if (err.code) {
        Logger.error('Lỗi khi nạp %{public}s: %{public}s', page, JSON.stringify(err));
        return;
      }
      if (this.shouldPickScreenRegion) {
        this.shouldPickScreenRegion = false;
        this.pickScreenRegion();
      }
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((win: window.Window) => {
      this.mainWindow = win;
      try {
        win.setWindowBackgroundColor('#F8F9FA');
      } catch (err) {
        Logger.warn('Không đặt được nền cửa sổ: %{public}s', JSON.stringify(err));
      }
      this.showPage(this.pendingPage);
    }).catch((err: Error) => {
      Logger.error('Không thể lấy mainWindow: %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageDestroy(): void {
    Logger.info('EntryAbility onWindowStageDestroy');
    this.mainWindow = null;
  }

  onForeground(): void {
    Logger.info('EntryAbility onForeground');
  }

  onBackground(): void {
    Logger.info('EntryAbility onBackground');
  }

  onDestroy(): void {
    Logger.info('EntryAbility onDestroy');
  }
}
