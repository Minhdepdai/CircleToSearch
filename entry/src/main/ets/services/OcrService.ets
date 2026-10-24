import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { Logger } from '../common/Logger';

/**
 * Service OCR on-device dùng CoreVisionKit (chạy trên NPU Kirin, offline hoàn toàn).
 * Nhận diện văn bản tiếng Việt/Anh/Trung... từ PixelMap đã khoanh.
 */
export class OcrService {
  /**
   * Nhận diện toàn bộ văn bản trong ảnh.
   * Trả về chuỗi text ghép từ các dòng, hoặc chuỗi rỗng nếu không có text.
   */
  public static async recognizeText(pixelMap: image.PixelMap): Promise<string> {
    try {
      Logger.info('OcrService: bắt đầu nhận diện văn bản...');

      const visionInfo: textRecognition.VisionInfo = {
        pixelMap: pixelMap
      };

      const result: textRecognition.TextRecognitionResult =
        await textRecognition.recognizeText(visionInfo);

      if (result && result.value) {
        Logger.info('OcrService: nhận diện thành công, %{public}d ký tự', result.value.length);
        return result.value;
      }
      Logger.warn('OcrService: không nhận diện được văn bản');
      return '';
    } catch (err) {
      Logger.error('OcrService lỗi: %{public}s', JSON.stringify(err));
      throw new Error(`OCR thất bại: ${JSON.stringify(err)}`);
    }
  }
}
