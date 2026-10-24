import { webview } from '@kit.ArkWeb';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ImageService } from '../services/ImageService';
import { LensUploadService, UploadResult } from '../services/LensUploadService';
import { HistoryService } from '../services/HistoryService';
import { LensLoadingView } from '../components/LensLoadingView';
import { LensTopBar } from '../components/LensTopBar';

/**
 * Trang kết quả tìm kiếm Google Lens dạng cửa sổ nổi / Floating Card.
 * Nén ảnh crop -> upload lên lens.google.com -> ưu tiên mở kết quả qua browser hệ
 * thống. Điều này tránh phụ thuộc ArkWeb nhúng, vốn không có trên một số thiết bị.
 */
@Entry
@Component
struct LensResultPage {
  @State private isLoading: boolean = true;
  @State private lensUrl: string = '';
  @State private errorMessage: string = '';
  private webviewController: webview.WebviewController = new webview.WebviewController();
  private requestId: number = 0;

  aboutToAppear(): void {
    this.startUploadAndSearch();
  }

  /**
   * Nén ảnh, upload lên Google Lens và nạp URL kết quả
   */
  private async startUploadAndSearch(): Promise<void> {
    const requestId = ++this.requestId;
    this.isLoading = true;
    this.errorMessage = '';
    this.lensUrl = '';

    const pixelMap = AppStorage.get<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP);
    if (!pixelMap) {
      Logger.error('Không tìm thấy PixelMap trong AppStorage');
      if (requestId === this.requestId) {
        this.errorMessage = 'Không có hình ảnh để tìm kiếm';
        this.isLoading = false;
      }
      return;
    }

    try {
      // 1. Scale + nén JPEG chất lượng cao
      const jpegBytes = await ImageService.packPixelMapToJpeg(pixelMap, 85);
      if (requestId !== this.requestId) {
        return;
      }

      // 2. Upload multipart lên Google Lens, bắt redirect đầu tiên
      const uploadResult: UploadResult = await LensUploadService.uploadToGoogleLens(jpegBytes);
      if (requestId !== this.requestId) {
        return;
      }

      if (uploadResult.success && uploadResult.resultUrl) {
        this.lensUrl = uploadResult.resultUrl;
        Logger.info('Đã nhận URL kết quả Lens: %{public}s', this.lensUrl);

        // 3. Lưu crop vào lịch sử
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        await HistoryService.addItem(context, pixelMap, Constants.MODE_SEARCH);
        if (requestId !== this.requestId) {
          return;
        }

        // ArkWeb trong log của thiết bị đang có api level 0 nên không thể đảm bảo
        // Web component hoạt động. Browser hệ thống xử lý trang kết quả ổn định hơn.
        if (await this.openResultInSystemBrowser(uploadResult.resultUrl) && requestId === this.requestId) {
          this.isLoading = false;
        }
      } else {
        if (requestId === this.requestId) {
          this.errorMessage = uploadResult.errorMessage || 'Lỗi không xác định khi upload';
          this.isLoading = false;
        }
      }
    } catch (error) {
      Logger.error('Lỗi quy trình tìm kiếm: %{public}s', String(error));
      if (requestId === this.requestId) {
        this.errorMessage = 'Không thể hoàn tất tìm kiếm. Hãy kiểm tra kết nối và thử lại.';
        this.isLoading = false;
      }
    }
  }

  /**
   * Khi Webview load xong: tiêm script dọn UI (ẩn header/footer Google)
   */
  private onWebPageEnd(): void {
    Logger.info('Webview đã tải xong, tiêm script dọn dẹp');
    this.isLoading = false;
    try {
      this.webviewController.runJavaScript(Constants.buildCleanupScript()).catch((error: Error) => {
        Logger.warn('Không thể dọn giao diện Webview: %{public}s', error.message);
      });
    } catch (error) {
      Logger.warn('Không thể dọn giao diện Webview: %{public}s', String(error));
    }
  }

  /** Mở kết quả trên browser mặc định; nếu không có handler thì dùng Web fallback. */
  private async openResultInSystemBrowser(url: string): Promise<boolean> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
      Logger.info('Đã bàn giao kết quả Google Lens cho browser hệ thống');
      return true;
    } catch (error) {
      Logger.warn('Không mở được browser hệ thống, dùng Web nhúng: %{public}s', String(error));
      return false;
    }
  }

  /**
   * Tắt cửa sổ nổi và quay lại ứng dụng trước đó
   */
  private closeFloatingResult(): void {
    const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      abilityContext.terminateSelf().catch((error: Error) => {
        Logger.error('Không thể đóng trang kết quả: %{public}s', error.message);
      });
    } catch (error) {
      Logger.error('Không thể đóng trang kết quả: %{public}s', String(error));
    }
  }

  build() {
    Column() {
      LensTopBar({
        onClose: () => {
          this.closeFloatingResult();
        },
        onRefresh: () => {
          this.startUploadAndSearch();
        }
      })

      Stack() {
        if (this.lensUrl !== '') {
          Web({ src: this.lensUrl, controller: this.webviewController })
            .width('100%')
            .height('100%')
            .domStorageAccess(true)
            .javaScriptAccess(true)
            .fileAccess(false)
            .imageAccess(true)
            .onlineImageAccess(true)
            .onPageEnd(() => {
              this.onWebPageEnd();
            })
            .onErrorReceive((event: OnErrorReceiveEvent) => {
              Logger.error('Lỗi Webview: %{public}s', event.error.getErrorInfo());
              if (this.isLoading) {
                this.errorMessage = 'Không thể tải trang kết quả. Hãy thử lại.';
                this.isLoading = false;
              }
            })
        }

        if (this.isLoading) {
          LensLoadingView({ loadingText: 'Đang phân tích hình ảnh...' })
        }

        if (this.errorMessage !== '') {
          Column({ space: 12 }) {
            Image($r('sys.media.ohos_ic_public_fail'))
              .width(48)
              .height(48)
              .fillColor('#EA4335')

            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#5F6368')
              .textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24 })

            Button('Thử lại')
              .fontSize(14)
              .backgroundColor('#1A73E8')
              .onClick(() => {
                this.startUploadAndSearch();
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#FFFFFF')
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 16, topRight: 16 })
    .shadow({ radius: 12, color: '#26000000', offsetY: -2 })
  }
}
