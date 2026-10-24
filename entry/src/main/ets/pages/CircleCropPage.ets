import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ImageService } from '../services/ImageService';
import { Geometry, Point } from '../common/Geometry';

interface ModeChip {
  mode: string;
  label: string;
  color: string;
}

/**
 * Trang Canvas pop-up khi mở từ Smart Sidebar hoặc nhận ảnh chia sẻ.
 * Cho phép khoanh tròn đối tượng trực tiếp trên ảnh nền và chọn chế độ xử lý:
 * - Tìm kiếm hình ảnh (Google Lens)
 * - Trích xuất văn bản (OCR on-device)
 * - Dịch thuật (OCR + Google Translate)
 */
@Entry
@Component
struct CircleCropPage {
  @State private frozenPixelMap: image.PixelMap | null = null;
  @State private isCapturing: boolean = true;
  @State private currentMode: string = Constants.MODE_SEARCH;
  @State private statusHint: string = '';
  @State private isPickingImage: boolean = false;
  @State private isProcessing: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // Tọa độ nét vẽ cử chỉ của người dùng
  private pathPoints: Point[] = [];
  // Kích thước canvas thực (để map tọa độ chạm sang tọa độ ảnh)
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;

  private readonly modeChips: ModeChip[] = [
    { mode: Constants.MODE_SEARCH, label: 'Tìm kiếm', color: '#4285F4' },
    { mode: Constants.MODE_OCR, label: 'Trích text', color: '#34A853' },
    { mode: Constants.MODE_TRANSLATE, label: 'Dịch thuật', color: '#EA4335' }
  ];

  async aboutToAppear(): Promise<void> {
    Logger.info('CircleCropPage: chuẩn bị ảnh nền...');
    this.isCapturing = true;

    // Ảnh có thể đến từ bộ chọn vùng màn hình của hệ thống, ảnh được chia sẻ,
    // hoặc thư viện. App không tự đọc nội dung của app khác.
    const pending = AppStorage.get<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP);
    if (pending) {
      this.frozenPixelMap = pending;
      this.isCapturing = false;
      this.statusHint = 'Khoanh tròn vùng muốn xử lý';
      return;
    }

    this.frozenPixelMap = null;
    this.isCapturing = false;
    this.statusHint = 'Chưa có ảnh — hãy chọn ảnh hoặc chạm notification để chọn vùng màn hình';
  }

  aboutToDisappear(): void {
    // Ảnh nền chỉ thuộc trang này (bản crop đã thay vào AppStorage khi chuyển trang).
    const pending = AppStorage.get<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP);
    if (this.frozenPixelMap !== null && this.frozenPixelMap !== pending) {
      ImageService.releaseQuietly(this.frozenPixelMap);
    }
  }

  private async pickImage(): Promise<void> {
    this.isPickingImage = true;
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      const pixelMap = await ImageService.loadPixelMapFromUri(result.photoUris[0]);
      const previous = this.frozenPixelMap;
      AppStorage.setOrCreate<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP, pixelMap);
      AppStorage.setOrCreate<string>(Constants.KEY_IMAGE_SOURCE, Constants.SOURCE_GALLERY);
      this.frozenPixelMap = pixelMap;
      this.resetStroke();
      if (previous !== null && previous !== pixelMap) {
        ImageService.releaseQuietly(previous);
      }
      this.statusHint = 'Khoanh tròn vùng muốn xử lý';
    } catch (err) {
      Logger.error('Chọn ảnh để crop thất bại: %{public}s', JSON.stringify(err));
      this.statusHint = 'Không mở được thư viện ảnh, hãy thử lại';
    } finally {
      this.isPickingImage = false;
    }
  }

  /** Xóa nét vẽ hiện tại để người dùng vẽ lại. */
  private resetStroke(): void {
    this.pathPoints = [];
    if (this.canvasWidth > 0 && this.canvasHeight > 0) {
      this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    }
  }

  /**
   * Xử lý vùng khoanh theo chế độ đang chọn
   */
  private async processAndSearch(): Promise<void> {
    if (this.isProcessing) {
      return;
    }
    // Kiểm tra vòng khoanh khép kín trước khi xử lý
    if (!Geometry.isClosedStroke(this.pathPoints)) {
      this.statusHint = 'Vòng chưa khép kín — hãy khoanh tròn trọn vẹn hơn';
      Logger.warn('Nét vẽ không khép kín, bỏ qua lượt khoanh');
      this.resetStroke();
      return;
    }

    const source = this.frozenPixelMap;
    if (!source) {
      Logger.warn('Không có PixelMap nền, không thể xử lý vùng khoanh');
      this.statusHint = 'Không có ảnh nền để xử lý';
      return;
    }

    this.isProcessing = true;
    try {
      const strokeBox = Geometry.boundingBoxOf(this.pathPoints);
      if (strokeBox === null) {
        this.resetStroke();
        return;
      }
      // Nới nhẹ vùng khoanh để không cắt sát mép đối tượng
      const padded = Geometry.padBox(strokeBox, Constants.CROP_PADDING_PX, this.canvasWidth, this.canvasHeight);
      const info = await source.getImageInfo();
      const box = Geometry.mapCanvasBoxToImage(padded, this.canvasWidth, this.canvasHeight,
        info.size.width, info.size.height);
      if (box === null) {
        this.statusHint = 'Vùng khoanh nằm ngoài ảnh — hãy khoanh lên phần có ảnh';
        this.resetStroke();
        return;
      }
      Logger.info('Tọa độ vùng khoanh: %{public}s (mode=%{public}s)', JSON.stringify(box), this.currentMode);

      // Cắt vùng khoanh thành PixelMap mới
      const croppedMap = await ImageService.cropPixelMap(source, box);
      AppStorage.setOrCreate<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP, croppedMap);
      AppStorage.setOrCreate<string>(Constants.KEY_SEARCH_MODE, this.currentMode);

      // Điều hướng theo chế độ
      const uiRouter = this.getUIContext().getRouter();
      if (this.currentMode === Constants.MODE_OCR) {
        uiRouter.replaceUrl({ url: 'pages/TextResultPage' });
      } else if (this.currentMode === Constants.MODE_TRANSLATE) {
        uiRouter.replaceUrl({ url: 'pages/TranslateResultPage' });
      } else {
        uiRouter.replaceUrl({ url: 'pages/LensResultPage' });
      }
    } catch (err) {
      Logger.error('Lỗi khi xử lý vùng khoanh: %{public}s', JSON.stringify(err));
      this.statusHint = 'Xử lý vùng khoanh thất bại, thử lại';
      this.resetStroke();
    } finally {
      this.isProcessing = false;
    }
  }

  /**
   * Hủy bỏ và đóng ngay cửa sổ nổi để trở về app trước
   */
  private dismissOverlay(): void {
    const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (abilityContext) {
      abilityContext.terminateSelf();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 1. Ảnh do người dùng chọn/chia sẻ và lớp nét vẽ khoanh vùng.
      if (this.frozenPixelMap) {
        Image(this.frozenPixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .draggable(false)

        Canvas(this.context)
        .width('100%')
        .height('100%')
        .backgroundColor('#26000000')
        .onReady(() => {
          this.canvasWidth = this.context.width;
          this.canvasHeight = this.context.height;
        })
        .gesture(
          PanGesture({ fingers: 1, distance: 1 })
            .onActionStart((event: GestureEvent) => {
              if (this.isProcessing) {
                return;
              }
              this.pathPoints = [];
              const touchX = event.fingerList[0]?.localX || 0;
              const touchY = event.fingerList[0]?.localY || 0;
              this.pathPoints.push({ x: touchX, y: touchY });

              this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
              this.context.beginPath();
              this.context.moveTo(touchX, touchY);
            })
            .onActionUpdate((event: GestureEvent) => {
              if (this.isProcessing) {
                return;
              }
              const touchX = event.fingerList[0]?.localX || 0;
              const touchY = event.fingerList[0]?.localY || 0;
              this.pathPoints.push({ x: touchX, y: touchY });

              // Hiệu ứng nét vẽ phát sáng viền xanh neon phong cách Google Lens
              this.context.strokeStyle = '#4285F4';
              this.context.lineWidth = 4.5;
              this.context.lineCap = 'round';
              this.context.lineJoin = 'round';
              this.context.shadowColor = '#B34285F4';
              this.context.shadowBlur = 12;
              this.context.lineTo(touchX, touchY);
              this.context.stroke();
            })
            .onActionEnd(() => {
              this.processAndSearch();
            })
            .onActionCancel(() => {
              this.resetStroke();
            })
          )
      } else {
        Column({ space: 14 }) {
          Image($r('sys.media.ohos_ic_public_albums'))
            .width(52)
            .height(52)
            .fillColor('#1A73E8')
          Text('Chọn ảnh để khoanh vùng')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#202124')
          Text('Bạn đã hủy chọn vùng màn hình. Hãy chọn ảnh khác hoặc chụp màn hình bằng Knuckle rồi Chia sẻ → Circle Lens.')
            .fontSize(14)
            .fontColor('#5F6368')
            .textAlign(TextAlign.Center)
            .margin({ left: 32, right: 32 })
          Button(this.isPickingImage ? 'Đang mở thư viện...' : 'Chọn ảnh')
            .enabled(!this.isPickingImage)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#1A73E8')
            .borderRadius(24)
            .padding({ left: 28, right: 28 })
            .onClick(() => {
              this.pickImage();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#F8F9FA')
      }

      // 3. Nút Hủy (Đóng) ở góc trên bên phải
      Row() {
        Blank()
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('sys.media.ohos_ic_public_cancel'))
            .width(20)
            .height(20)
            .fillColor(Color.White)
        }
        .width(40)
        .height(40)
        .backgroundColor('#80000000')
        .margin({ top: 40, right: 20 })
        .onClick(() => {
          this.dismissOverlay();
        })
      }
      .width('100%')
      .position({ x: 0, y: 0 })

      // 4. Thanh dưới: chips chọn chế độ + dòng hướng dẫn/trạng thái
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          ForEach(this.modeChips, (chip: ModeChip) => {
            Text(chip.label)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.currentMode === chip.mode ? Color.White : '#E8EAED')
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor(this.currentMode === chip.mode ? chip.color : '#66000000')
              .borderRadius(18)
              .border({
                width: 1,
                color: this.currentMode === chip.mode ? chip.color : '#40FFFFFF'
              })
              .onClick(() => {
                this.currentMode = chip.mode;
              })
          }, (chip: ModeChip) => chip.mode)
        }

        Row({ space: 8 }) {
          Circle({ width: 6, height: 6 }).fill('#4285F4')
          Circle({ width: 6, height: 6 }).fill('#EA4335')
          Circle({ width: 6, height: 6 }).fill('#FBBC05')
          Circle({ width: 6, height: 6 }).fill('#34A853')
          Text(this.statusHint !== '' ? this.statusHint : 'Khoanh tròn bất kỳ đối tượng nào trên màn hình')
            .fontColor(Color.White)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(VerticalAlign.Center)
        .padding({ left: 20, right: 20 })
      }
      .padding({ left: 16, right: 16, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
