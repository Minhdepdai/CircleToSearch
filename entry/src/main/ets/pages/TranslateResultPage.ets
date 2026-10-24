import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { OcrService } from '../services/OcrService';
import { HistoryService } from '../services/HistoryService';
import { LensLoadingView } from '../components/LensLoadingView';
import { LensTopBar } from '../components/LensTopBar';

/**
 * Trang Dịch thuật: OCR on-device vùng đã khoanh, sau đó mở Google Translate
 * với text nhận diện được (mặc định dịch sang tiếng Việt).
 */
@Entry
@Component
struct TranslateResultPage {
  @State private isLoading: boolean = true;
  @State private translateUrl: string = '';
  @State private errorMessage: string = '';
  private webviewController: webview.WebviewController = new webview.WebviewController();
  private requestId: number = 0;

  private async runTranslate(): Promise<void> {
    const requestId = ++this.requestId;
    this.isLoading = true;
    this.errorMessage = '';
    this.translateUrl = '';

    const pixelMap = AppStorage.get<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP);
    if (!pixelMap) {
      Logger.error('TranslateResultPage: không tìm thấy PixelMap');
      if (requestId === this.requestId) {
        this.errorMessage = 'Không có hình ảnh để dịch';
        this.isLoading = false;
      }
      return;
    }

    try {
      // 1. OCR on-device
      const text = await OcrService.recognizeText(pixelMap);
      if (requestId !== this.requestId) {
        return;
      }
      if (text === '') {
        this.errorMessage = 'Không nhận diện được văn bản trong vùng đã khoanh';
        return;
      }
      AppStorage.setOrCreate<string>(Constants.KEY_TRANSLATE_TEXT, text);

      // 2. Mở Google Translate với text đã nhận diện (dịch sang tiếng Việt)
      const encoded = encodeURIComponent(text);
      this.translateUrl = `https://translate.google.com/?sl=auto&tl=vi&text=${encoded}&op=translate`;

      // 3. Lưu lịch sử
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await HistoryService.addItem(context, pixelMap, Constants.MODE_TRANSLATE);
    } catch (error) {
      Logger.error('TranslateResultPage lỗi: %{public}s', String(error));
      if (requestId === this.requestId) {
        this.errorMessage = 'Không thể xử lý nội dung để dịch. Hãy thử lại.';
      }
    } finally {
      if (requestId === this.requestId && this.errorMessage !== '') {
        this.isLoading = false;
      }
    }
  }

  aboutToAppear(): void {
    this.runTranslate();
  }

  private closePage(): void {
    const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      abilityContext.terminateSelf().catch((error: Error) => {
        Logger.error('Không thể đóng trang dịch: %{public}s', error.message);
      });
    } catch (error) {
      Logger.error('Không thể đóng trang dịch: %{public}s', String(error));
    }
  }

  build() {
    Column() {
      LensTopBar({
        title: 'Dịch thuật',
        onClose: () => {
          this.closePage();
        },
        onRefresh: () => {
          this.runTranslate();
        }
      })

      Stack() {
        if (this.translateUrl !== '') {
          Web({ src: this.translateUrl, controller: this.webviewController })
            .width('100%')
            .height('100%')
            .domStorageAccess(true)
            .javaScriptAccess(true)
            .fileAccess(false)
            .imageAccess(true)
            .onlineImageAccess(true)
            .onPageEnd(() => {
              this.isLoading = false;
              // Dọn UI Google Translate: ẩn banner mở app
              try {
                this.webviewController.runJavaScript(Constants.buildCleanupScript()).catch((error: Error) => {
                  Logger.warn('Không thể dọn giao diện Translate: %{public}s', error.message);
                });
              } catch (error) {
                Logger.warn('Không thể dọn giao diện Translate: %{public}s', String(error));
              }
            })
            .onErrorReceive((event: OnErrorReceiveEvent) => {
              Logger.error('Webview Translate lỗi: %{public}s', event.error.getErrorInfo());
              if (this.isLoading) {
                this.errorMessage = 'Không thể tải Google Translate. Hãy thử lại.';
                this.isLoading = false;
              }
            })
        }

        if (this.isLoading) {
          LensLoadingView({ loadingText: 'Đang nhận diện & dịch...' })
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
                this.runTranslate();
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
  }
}
