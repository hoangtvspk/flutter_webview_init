# Hướng dẫn thêm script copy GoogleService-Info.plist

## Cách 1: Thêm script trong Xcode (Khuyến nghị)

1. Mở `ios/Runner.xcworkspace` trong Xcode
2. Với mỗi target (Runner-dev, Runner):
   - Chọn target → Build Phases
   - Nhấn "+" → "New Run Script Phase"
   - Đặt tên: "Copy GoogleService-Info.plist"
   - Kéo script phase lên **TRƯỚC** "Copy Bundle Resources"
   - Thêm script:
     ```bash
     "${SRCROOT}/Runner/copy_google_service_info.sh"
     ```
   - Xóa `GoogleService-Info.plist` khỏi "Copy Bundle Resources" (nếu có)

## Cách 2: Sử dụng Flutter build script

Script sẽ tự động chạy khi build và copy file đúng theo configuration:

- Configuration có "dev" → copy từ `Config/dev/GoogleService-Info.plist`
- Configuration có "prod" hoặc "Release" → copy từ `Config/prod/GoogleService-Info.plist`

## Kiểm tra

Sau khi thêm script, build lại project:

```bash
flutter clean
flutter build ios --flavor dev
```

File `Runner/GoogleService-Info.plist` sẽ được copy tự động từ `Config/dev/` hoặc `Config/prod/` tùy theo flavor.
