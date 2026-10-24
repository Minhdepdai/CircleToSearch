# Kiến Trúc Kỹ Thuật: Harmony Circle to Search (Smart Sidebar Edition)

Ứng dụng **Circle Lens** chạy trên **HarmonyOS NEXT (API 24)**, kích hoạt từ **Smart Sidebar** hoặc **Share Sheet** hệ thống.

---

## 1. Mô hình Kiến trúc Tổng thể

```
┌─────────────────────────────────────────────────────────────┐
│                    HỆ ĐIỀU HÀNH HARMONYOS NEXT              │
│  - Huawei Smart Sidebar (thanh bên thông minh)             │
│  - Share Sheet (ohos.want.action.sendData)                 │
│  - Multi-window Window Manager (Floating / SubWindow)      │
└──────────────────────────────┬──────────────────────────────┘
                               │ Want (home | sendData)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 ENTRY ABILITY (STAGE MODEL)                 │
│  - supportWindowMode: ["floating", "fullscreen"]            │
│  - setWindowBackgroundColor('#00000000') + FullScreen      │
│  - handleIncomingWant(): ảnh share -> AppStorage           │
│  - setUIContent('pages/CircleCropPage')                    │
└──────────────────────────────┬──────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼ (không có ảnh share)                 ▼ (có ảnh share)
┌─────────────────────────┐             ┌─────────────────────────┐
│  ScreenCaptureService   │             │     CircleCropPage      │
│  - AVScreenCaptureRec   │──PixelMap──▶│  - Ảnh nền đóng băng    │
│    (ghi mp4 ngắn)       │             │  - Kiểm tra vòng khép   │
│  - AVImageGenerator     │             │    kín trước khi xử lý   │
│    fetchFrameByTime     │             │  - Chips: Search/OCR/   │
└─────────────────────────┘             │    Translate            │
                                        └───────────┬─────────────┘
                                                    │ BoundingBox
                                                    ▼
                                        ┌─────────────────────────┐
                                        │      ImageService       │
                                        │ - crop desiredRegion    │
                                        │ - scale ≤ 1440px        │
                                        │ - packToData JPEG       │
                                        └───┬──────────┬──────────┘
                        ┌───────────────────┘          └──────────────┐
                        ▼ (mode=search)                 ▼ (mode=ocr|translate)
        ┌──────────────────────────┐         ┌──────────────────────────┐
        │    LensUploadService     │         │       OcrService          │
        │ - multiFormDataList      │         │ - CoreVisionKit           │
        │ - on('headersReceive')   │         │   textRecognition        │
        │   bắt redirect 302 đầu   │         │ - offline trên NPU       │
        └────────────┬─────────────┘         └──────────┬───────────────┘
                     ▼ Location URL                     ▼ Text
        ┌──────────────────────────┐         ┌──────────────────────────┐
        │     LensResultPage       │         │  TextResultPage (copy)   │
        │  - Webview + CSS inject  │         │  TranslateResultPage    │
        │  - MutationObserver      │         │   (Google Translate web) │
        │  - terminateSelf() đóng  │         └──────────────────────────┘
        └──────────────────────────┘
                     │
                     └────── HistoryService (Preferences + cacheDir/history, tối đa 20)
```

---

## 2. Các Cơ Chế Kỹ Thuật Trọng Tâm

### 2.1. Hai điểm kích hoạt (module.json5)

```json5
"supportWindowMode": ["floating", "fullscreen"],
"skills": [
  { "actions": ["ohos.want.action.home"] },                     // launcher / sidebar
  { "actions": ["ohos.want.action.sendData"],                   // share sheet
    "uris": [{ "scheme": "file", "type": "image/*" }] }
]
```

*   **Smart Sidebar**: OS mở app dạng cửa sổ nổi; `EntryAbility` pop-up thẳng `CircleCropPage` với nền trong suốt.
*   **Share Sheet**: Khi người dùng khoanh vùng bằng cử chỉ knuckle của Huawei rồi bấm Chia sẻ, Want mang `uri` ảnh (kèm action `sendData`) đến app. `handleIncomingWant()` nạp ảnh thành PixelMap đặt vào `AppStorage`, trang khoanh mở với ảnh nền *thật*.

### 2.2. Chụp màn hình & trích frame (ScreenCaptureService)

`AVScreenCaptureRecorder` ghi ~350ms ra mp4 tạm trong `cacheDir`, sau đó `AVImageGenerator.fetchFrameByTime()` trích frame cuối thành PixelMap tĩnh. Lưu ý bảo mật: recorder chỉ ghi nội dung do app render — nên luồng **share sheet mới là nguồn ảnh nền đáng tin**. File tạm được dọn trong `finally`.

### 2.3. Crop không phá ảnh gốc (ImageService)

PixelMap nguồn được encode JPEG (quality 100) rồi decode lại với `DecodingOptions.desiredRegion` — cho PixelMap *mới* chứa đúng vùng khoanh, ảnh gốc giữ nguyên (tránh bug của `pixelMap.crop()` vốn sửa chổ). Trước khi upload, ảnh được `scale()` về chiều rộng ≤ 1440px theo khuyến nghị của Google Lens.

### 2.4. Upload & bắt redirect (LensUploadService)

*   **`multiFormDataList`** của NetworkKit: tự sinh boundary + multipart thay vì đóng gói thủ công.
*   **Bắt redirect đầu tiên**: `http.on('headersReceive')` bắn header của *mỗi* phản hồi (kể cả 302 trung gian trước khi stack auto-follow). Wrapper object `LocationHolder` tránh lỗi type-narrowing của ArkTS với biến bị callback gán.
*   **3 lớp fallback URL**: (1) Location từ headersReceive; (2) header Location của response cuối; (3) regex quét HTML tìm URL lens.google.com.

### 2.5. OCR on-device (OcrService)

`@kit.CoreVisionKit` → `textRecognition.recognizeText({ pixelMap })` trả text + block/line/word + tọa độ. Chạy hoàn toàn offline trên NPU — không gửi ảnh lên mạng, dùng cho cả chế độ *Trích text* và *Dịch thuật* (text OCR được đưa vào `translate.google.com`).

### 2.6. Kiểm tra vòng khoanh khép kín (CircleCropPage)

Trước khi xử lý, nét vẽ phải thỏa: ≥ 12 điểm; điểm cuối cách điểm đầu < 25% chu vi ước lượng; bounding box ≥ 24×24px. Không đạt → hiển thị gợi ý "Vòng chưa khép kín" và xóa nét vẽ để vẽ lại — tránh tìm kiếm nhầm khi chỉ chạm nhẹ.

### 2.7. Webview dọn UI & chống re-render

CSS ẩn header/banner Google với nhiều selector dự phòng (Google đổi class thường xuyên). Script được tiêm qua `runJavaScript()` sau `onPageEnd`, kèm **MutationObserver** áp lại CSS khi Lens (SPA) render thêm phần tử mới. `buildCleanupScript()` nhúng CSS an toàn qua `JSON.stringify` thay vì template literal lồng nhau.

### 2.8. Vòng đời & dọn tài nguyên

*   Kết quả xong: bấm **X** → `terminateSelf()` hủy cửa sổ nổi, giải phóng Webview.
*   Lịch sử: ảnh JPEG trong `cacheDir/history` + metadata `Preferences` (tối đa 20, tự xóa file cũ khi vượt).
*   Không còn quyền MICROPHONE (không dùng ghi âm), chỉ còn INTERNET + GET_NETWORK_INFO.

### 2.9. API hiện đại (không deprecated)

Toàn bộ code dùng API thế hệ mới: `setUIContent` (thay loadContent), `packToData` (thay packing), `getUIContext().getRouter()` (thay router.*), `getUIContext().getHostContext()` (thay getContext), `getPromptAction()` — build hiện **0 warning deprecated**.
