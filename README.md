# Harmony Circle to Search (Smart Sidebar & Google Lens Port)

> **Ứng dụng tìm kiếm thị giác tương tự Circle to Search / Google Lens dành riêng cho HarmonyOS NEXT (API 24 - HarmonyOS 6.1.1+)**
> **3 chế độ: Tìm kiếm hình ảnh • Trích xuất văn bản (OCR) • Dịch thuật — kích hoạt từ Smart Sidebar hoặc Share Sheet**

---

## 🎯 Giới thiệu Dự án

Dự án mang trải nghiệm **Google Circle to Search** lên hệ sinh thái **HarmonyOS NEXT** (không dùng Android AOSP).

### Điểm đột phá về UX:
*   **Kích hoạt 1 chạm từ Smart Sidebar**: Vuốt mép màn hình → chạm icon **Circle Lens** → cửa sổ trong suốt pop-up ngay lập tức.
*   **Hoặc từ cử chỉ Knuckle của Huawei**: Khoanh vùng màn hình bằng khớp ngón tay → Share → chọn **Circle Lens** → ảnh vùng đó mở sẵn trong trang khoanh tròn (luồng đáng tin nhất để có ảnh nền thật, vì app bên thứ 3 bị OS giới hạn chụp màn hình app khác).
*   **3 chế độ xử lý ngay trên màn hình khoanh**: *Tìm kiếm hình ảnh* (Google Lens), *Trích xuất văn bản* (OCR on-device bằng CoreVisionKit — chạy offline trên NPU Kirin), *Dịch thuật* (OCR + Google Translate tự động sang tiếng Việt).
*   **Kiểm tra vòng khoanh khép kín**: Chỉ khi nét vẽ khép vòng trọn vẹn mới kích hoạt xử lý — chạm/vuốt nhầm sẽ bị bỏ qua.
*   **Kết quả dạng Floating Card**: Webview đã tiêm CSS/JS dọn UI Google (ẩn header, banner mở app), có MutationObserver chống re-render. Bấm **X** là tắt, không văng app đang dùng dở.
*   **Lịch sử 20 vùng khoanh gần nhất**: Ảnh crop + chế độ được lưu trong cache (Preferences), mở lại được bất cứ lúc nào.

---

## 📱 Luồng Trải nghiệm (User Flow)

```
[Đang dùng app bất kỳ] ──vuốt mép màn hình──▶ [Smart Sidebar] ──chạm icon──┐
                                                                          │
[Đang xem nội dung] ──khớp ngón tay khoanh vùng──▶ [Share] ──chọn Circle Lens──┤
                                                                          ▼
                                    [Cửa sổ trong suốt pop-up + CircleCropPage]
                                                          │
                        ┌───────────────── chọn chế độ trên chip bar ─────────────┐
                        ▼                        ▼                              ▼
              [Tìm kiếm hình ảnh]      [Trích xuất văn bản]            [Dịch thuật]
              Upload multipart         OCR on-device                  OCR on-device
              lên lens.google.com      CoreVisionKit                  + Google Translate
                        │                        │                              │
                        ▼                        ▼                              ▼
              [LensResultPage          [TextResultPage                 [TranslateResultPage
               Web shell + CSS]         copy 1 chạm]                   Web Translate]
                        └──────────────────── bấm X: terminateSelf() ────────────┘
```

---

## 🛠️ Cấu trúc Mã nguồn

```
harmony-circle-to-search/
├── README.md / ARCHITECTURE.md / LENS_API_SPEC.md / TASK_ROADMAP.md
├── AppScope/app.json5                 # bundleName khớp signing profile
└── entry/src/main/
    ├── module.json5                   # skills: home + sendData (nhận ảnh share)
    │                                  # supportWindowMode floating/fullscreen
    └── ets/
        ├── entryability/EntryAbility.ets    # Xử lý Want (sendData/home), cửa sổ trong suốt
        ├── pages/
        │   ├── Index.ets               # Dashboard: hướng dẫn + chọn ảnh thử + lịch sử
        │   ├── CircleCropPage.ets      # Canvas khoanh tròn, vòng khép kín, chips chế độ
        │   ├── LensResultPage.ets      # Upload Google Lens + Webview kết quả
        │   ├── TextResultPage.ets       # Kết quả OCR + copy clipboard
        │   ├── TranslateResultPage.ets # OCR + Google Translate webview
        │   └── HistoryPage.ets          # Danh sách 20 vùng khoanh gần nhất
        ├── services/
        │   ├── ScreenCaptureService.ets  # AVScreenCaptureRecorder + AVImageGenerator
        │   ├── LensUploadService.ets     # multiFormDataList native + bắt redirect 302
        │   ├── ImageService.ets          # crop desiredRegion, scale, packToData JPEG
        │   ├── OcrService.ets            # CoreVisionKit textRecognition (offline)
        │   └── HistoryService.ets         # Preferences + file cacheDir/history
        ├── components/
        │   ├── LensLoadingView.ets       # Shimmer animation, text tùy chỉnh
        │   └── LensTopBar.ets            # Header có title/refresh/close
        └── common/
            ├── Constants.ets             # Endpoints, UA, CSS/JS injection, AppStorage keys
            └── Logger.ets                # Hilog wrapper
```

---

## 🚀 Hướng dẫn sử dụng trên máy Huawei

1. **Cài app**: Build từ DevEco Studio (hoặc `hvigorw assembleHap`) rồi cài `entry-default-signed.hap`.
2. **Luồng Smart Sidebar**: Vuốt mép màn hình vào → bấm **+** → ghim **Circle Lens**. Từ đó mở thanh bên → chạm icon → khoanh tròn.
3. **Luồng Knuckle (khuyên dùng)**: Dùng khớp ngón tay khoanh vùng màn hình (tính năng hệ thống) → bấm **Chia sẻ** → chọn **Circle Lens** → ảnh mở sẵn trong trang khoanh, chọn chế độ xử lý.
4. **Chọn chế độ**: Chip dưới màn hình — *Tìm kiếm* (xanh), *Trích text* (xanh lá), *Dịch thuật* (đỏ) — rồi khoanh tròn vùng cần xử lý.

---

## ⚠️ Giới hạn kỹ thuật cần biết

*   **Chụp màn hình app khác**: HarmonyOS khóa chặt việc app bên thứ 3 capture nội dung app khác (bảo mật). `AVScreenCaptureRecorder` của app chỉ ghi được nội dung app mình render. Vì vậy luồng "đóng băng màn hình nền" khi mở từ Smart Sidebar có thể cho nền gần trống — khi đó khoanh tròn vẫn hoạt động theo tọa độ chạm, nhưng **luồng Knuckle + Share mới cho ảnh nền thật**.
*   **Google Lens là API không chính thức**: Endpoint `lens.google.com/v3/upload` có thể thay đổi hoặc chặn bot bất cứ lúc nào. Code đã có 3 lớp fallback bắt redirect (headersReceive → header cuối → quét HTML).
