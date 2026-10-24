# Đặc Tả Kỹ Thuật: Google Lens Upload Endpoint & Fallbacks

Tài liệu này cung cấp chi tiết kỹ thuật về giao thức giao tiếp với **Google Lens Web Backend** và các giải pháp dự phòng (Fallback APIs).

---

## 1. Giao thức Upload Google Lens Web (Primary Endpoint)

Google Lens không cung cấp REST API công khai cho người dùng cá nhân. Tuy nhiên, trình duyệt Chrome (Desktop & Mobile) tương tác với máy chủ Google Lens thông qua endpoint nội bộ sau:

### 1.1. Thông số Request

*   **URL**: `https://lens.google.com/v3/upload`
*   **Method**: `POST`
*   **Content-Type**: `multipart/form-data; boundary=<BOUNDARY_STRING>`
*   **Headers bắt buộc**:
    ```http
    User-Agent: Mozilla/5.0 (Linux; Android 14; HarmonyOS; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.6613.88 Mobile Safari/537.36
    Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8
    Accept-Language: vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7
    Origin: https://lens.google.com
    Referer: https://lens.google.com/
    ```

### 1.2. Cấu trúc Multipart Payload

Với HarmonyOS NetworkKit (API 12+), KHÔNG cần đóng gói multipart thủ công. `HttpRequestOptions.multiFormDataList` tự sinh boundary và đóng gói chuẩn:

```typescript
const response = await httpRequest.request(Constants.LENS_UPLOAD_URL, {
  method: http.RequestMethod.POST,
  header: { 'User-Agent': Constants.LENS_USER_AGENT, /* ... */ },
  multiFormDataList: [
    {
      name: 'encoded_image',        // trường chứa dữ liệu nhị phân JPEG
      contentType: 'image/jpeg',
      remoteFileName: 'screenshot.jpg',
      data: imageBytes              // ArrayBuffer JPEG
    }
  ],
  readTimeout: 20000,
  connectTimeout: 10000
});
```

### 1.3. Cơ chế Phản hồi (Response Handling)

Máy chủ Google Lens có thể phản hồi theo 2 kịch bản:

*   **Kịch bản 1: HTTP 302 / 303 Redirect (Phổ biến nhất)**:
    *   Header phản hồi chứa: `Location: https://lens.google.com/search?p=<ENCODED_PARAMS>`
    *   **Lưu ý**: http stack của HarmonyOS tự follow redirect — `response.header` cuối cùng có thể KHÔNG còn Location của redirect đầu. Giải pháp đã áp dụng trong `LensUploadService`: đăng ký `httpRequest.on('headersReceive', ...)` để chụp header của MỌI phản hồi trung gian, giữ lại Location đầu tiên (wrapper object `LocationHolder` vì ArkTS không nhận type-narrowing trên biến được gán trong callback).
*   **Kịch bản 2: HTTP 200 OK kèm HTML chứa script điều hướng**:
    *   Dùng regex `https:\/\/lens\.google\.com\/[^"'\s\\]+` trích xuất URL đích từ HTML.

Thứ tự ưu tiên trích xuất URL trong code: (1) Location từ headersReceive → (2) Location trong response.header cuối → (3) regex quét HTML → (4) fallback trang chủ `https://lens.google.com/`.

---

## 2. Các Biện pháp Phòng ngừa & Tối ưu (Best Practices)

1.  **Duy trì Cookie / Session**:
    *   Webview của HarmonyOS (`@kit.ArkWeb`) tự động lưu cookie giữa các phiên duyệt web. Điều này giúp giảm tỷ lệ bị Google nghi ngờ là bot tự động.
2.  **Kích thước & Dung lượng ảnh**:
    *   Không nên gửi ảnh quá lớn (> 10 MB) hoặc quá bé (< 50x50 px).
    *   Kích thước lý tưởng: Chiều rộng 600px - 1440px, dung lượng 100KB - 500KB.
    *   `ImageService.scaleForUpload()` đã tự động scale ảnh về chiều rộng tối đa 1440px trước khi nén JPEG quality 85.
3.  **Xử lý trường hợp CAPTCHA**:
    *   Nếu người dùng bị Google yêu cầu xác minh CAPTCHA (do đổi mạng hoặc gửi request liên tục), vì chúng ta dùng `Web` component hoàn chỉnh nên **người dùng có thể trực tiếp giải CAPTCHA ngay trên màn hình** mà không làm crash ứng dụng.

---

## 3. Các Phương án Dự phòng (Fallback Engines)

Nếu Google siết chặt chính sách hoặc chặn IP, kiến trúc ứng dụng cho phép hoán đổi nhanh sang các engine tìm kiếm sau:

### Phương án A: Google Cloud Vision API
*   Dành cho trường hợp muốn kết quả JSON thuần túy (nhận diện chữ viết Text OCR, phát hiện nhãn Label Detection, nhận diện địa danh Landmark).
*   Endpoint: `https://vision.googleapis.com/v1/images:annotate?key=YOUR_API_KEY`
*   Payload: Base64 ảnh JPEG gửi kèm tính năng `IMAGE_PROPERTIES`, `TEXT_DETECTION`, `WEB_DETECTION`.

### Phương án B: Bing Visual Search API
*   Endpoint: `https://api.bing.microsoft.com/v7.0/images/visualsearch`
*   Hỗ trợ upload ảnh multipart tương tự và trả về JSON danh sách các sản phẩm và hình ảnh tương tự.

### Phương án C: Huawei Core ML Kit (Chạy On-Device hoặc Cloud)
*   Sử dụng bộ công cụ trí tuệ nhân tạo có sẵn của HarmonyOS NEXT:
    *   `@kit.CoreVisionKit` hoặc `@kit.VisionKit`
    *   Ưu điểm: Chạy offline hoàn toàn trên NPU của chip Kirin, nhận diện chữ tiếng Việt/Anh cực nhanh và an toàn tuyệt đối.
