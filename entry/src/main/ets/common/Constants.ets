/**
 * Định nghĩa hằng số toàn cục cho ứng dụng Circle Lens trên HarmonyOS NEXT (API 24)
 */
export class Constants {
  // Google Lens Upload Endpoint
  public static readonly LENS_UPLOAD_URL: string = 'https://lens.google.com/v3/upload';

  // User-Agent mô phỏng Chrome Mobile hiện đại để Google Lens trả giao diện mobile tối ưu
  public static readonly LENS_USER_AGENT: string =
    'Mozilla/5.0 (Linux; Android 14; HarmonyOS; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.6613.88 Mobile Safari/537.36';

  // Want action nhận ảnh chia sẻ từ share sheet hệ thống
  public static readonly ACTION_SEND_DATA: string = 'ohos.want.action.sendData';
  // Want nội bộ được kích hoạt khi người dùng chạm notification "Bắt đầu khoanh ảnh".
  public static readonly ACTION_OPEN_CROP: string = 'com.mihyuoko.ggcirlesearch.action.OPEN_CROP';
  public static readonly ACTION_HOME: string = 'ohos.want.action.home';

  // Notification do Smart Sidebar tạo để đưa người dùng vào luồng chọn/crop ảnh.
  public static readonly CROP_NOTIFICATION_ID: number = 1001;

  // Nguồn gốc của ảnh nền cho trang khoanh tròn
  public static readonly SOURCE_SHARED: string = 'source_shared';       // ảnh chia sẻ từ hệ thống
  public static readonly SOURCE_CAPTURE: string = 'source_capture';      // tự chụp màn hình
  public static readonly SOURCE_GALLERY: string = 'source_gallery';     // ảnh chọn từ thư viện

  // Nới vùng khoanh mỗi phía (px canvas) để không cắt sát mép đối tượng
  public static readonly CROP_PADDING_PX: number = 12;

  // Chế độ tìm kiếm khi nhấc tay khoanh
  public static readonly MODE_SEARCH: string = 'search';        // Tìm kiếm hình ảnh (Google Lens)
  public static readonly MODE_OCR: string = 'ocr';             // Trích xuất văn bản (OCR on-device)
  public static readonly MODE_TRANSLATE: string = 'translate';  // Dịch thuật (nhận dạng + Google Translate)

  // AppStorage keys
  public static readonly KEY_PENDING_PIXELMAP: string = 'key_pending_pixelmap';
  public static readonly KEY_IMAGE_SOURCE: string = 'key_image_source';
  public static readonly KEY_SEARCH_MODE: string = 'key_search_mode';
  public static readonly KEY_TRANSLATE_TEXT: string = 'key_translate_text';

  // CSS tiêm vào Webview để ẩn header/footer/quảng cáo của Google.
  // Dùng nhiều selector khác nhau vì Google đổi tên class thường xuyên.
  public static readonly INJECTED_CLEANUP_CSS: string = `
    /* Ẩn thanh header và thanh tìm kiếm web của Google */
    header,
    #gb,
    #gbwa,
    .gb_Fa,
    .search-box-wrapper,
    .f6F9ud,
    footer,
    .sfbg,
    .minidiv,
    [role="banner"],
    #sf,
    .smart-app-banner,
    .app-upsell-banner,
    #app-promo,
    .google-app-banner {
      display: none !important;
    }

    /* Đưa nội dung kết quả lên sát mép trên */
    body, html {
      padding-top: 0 !important;
      margin-top: 0 !important;
      background-color: #FFFFFF !important;
      -webkit-tap-highlight-color: transparent;
    }

    /* Kéo phần nội dung chính lên bù phần header đã ẩn */
    #main,
    #rcnt,
    main {
      margin-top: 0 !important;
    }
  `;

  // Template JavaScript tiêm vào Webview: __CSS_JSON__ sẽ được thay bằng JSON string của CSS.
  // Chạy lập lại qua MutationObserver để xử lý các phần tử render muộn (SPA).
  private static readonly INJECTED_CLEANUP_SCRIPT_TEMPLATE: string = `
    (function() {
      var CSS_TEXT = __CSS_JSON__;
      function applyCleanup() {
        try {
          if (!document.getElementById('circle-lens-cleanup-style')) {
            const style = document.createElement('style');
            style.type = 'text/css';
            style.id = 'circle-lens-cleanup-style';
            style.textContent = CSS_TEXT;
            document.head.appendChild(style);
          }
          const meta = document.querySelector('meta[name="viewport"]');
          if (meta) {
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
          }
        } catch(e) {
          console.error('Circle Lens cleanup error:', e);
        }
      }
      applyCleanup();
      // Google Lens là SPA: nhiều phần tử (banner mở app, header dính) render sau load
      new MutationObserver(applyCleanup).observe(document.documentElement, {
        childList: true, subtree: true
      });
    })();
  `;

  /**
   * Tạo script cleanup hoàn chỉnh (nhúng CSS vào template JS) dùng cho Webview.
   */
  public static buildCleanupScript(): string {
    const cssJson = JSON.stringify(Constants.INJECTED_CLEANUP_CSS);
    return Constants.INJECTED_CLEANUP_SCRIPT_TEMPLATE.replace('__CSS_JSON__', cssJson);
  }
}
