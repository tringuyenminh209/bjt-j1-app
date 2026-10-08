# BJT J1 — 8 tuần, 90 phút/ngày

Flutter iOS dùng cá nhân. 125 bài, 4 dạng câu hỏi, audio offline, ôn cách quãng,
luyện 30/80 câu có đồng hồ, lưu tiến độ SQLite. Cupertino UI tiếng Việt / nội dung Nhật.
Đề luyện lấy từ kho bài học, không phải mô phỏng chuẩn hóa điểm BJT.

## Build và cài IPA
1. Trong repo public, mở Actions → Build private IPA on public runner → Run workflow.
2. Tải IPA từ nhánh `ipa-builds` của repo private `tringuyenminh209/bjt-j1`.
3. Mở Sideloadly trên Windows, kết nối iPhone, chọn IPA và ký bằng Apple ID của bạn.
4. Cấp quyền tin cậy / Developer Mode nếu iPhone yêu cầu. Tài khoản Apple miễn phí
   cần ký lại định kỳ; giữ cùng bundle ID để bảo toàn dữ liệu, không xóa app.

Không đưa Apple ID hoặc mật khẩu Apple vào GitHub. Windows không build binary iOS;
GitHub macOS runner thực hiện bước này.

Nếu job chưa có bất kỳ step nào và báo lỗi billing/spending limit, mở
https://github.com/settings/billing để xử lý tài khoản, rồi Run workflow lại.
Đây là lỗi trước khi runner khởi chạy, chưa phải lỗi biên dịch app.

## Google Login / Supabase Free
File `.env` nằm ở thư mục gốc repo code (bên cạnh `mobile/`), đã gitignore.
Điền `SUPABASE_URL` và `SUPABASE_ANON_KEY`; có thể dùng publishable key cho key thứ hai.
Flutter đọc file lúc build, không cần thêm thư viện dotenv. Từ `mobile/`, dùng:
```sh
flutter run --dart-define-from-file=../.env
```
GitHub Actions dùng hai secrets cùng tên; file `.env` local không tự upload lên GitHub.
Google Client ID/Secret chỉ nhập trong Supabase Auth, không đóng gói vào app.

App chạy offline khi chưa cấu hình. Để bật Google và đồng bộ:
1. Tạo Supabase project và áp dụng `supabase/migrations/202610080001_learning_progress.sql`
   bằng migration runner / SQL Editor khi khởi tạo project.
2. Trong Google Cloud, tạo OAuth client loại Web Application; callback:
   `https://<project-ref>.supabase.co/auth/v1/callback`.
3. Bật Google provider trong Supabase Auth, nhập client ID và secret.
   Nếu OAuth consent còn Testing, thêm email của bạn vào test users.
4. Supabase Auth → URL Configuration → Redirect URLs:
   `vn.bjt.j1://login-callback/`.
5. GitHub Settings → Secrets and variables → Actions: thêm `SUPABASE_URL`
   và `SUPABASE_ANON_KEY` (publishable/anon key, tuyệt đối không dùng service_role).
6. Build lại IPA. Mở Tiến độ → Đăng nhập Google → Đồng bộ tiến độ.

App cho một người dùng: dữ liệu local vẫn giữ sau đăng xuất; không dùng trên thiết bị
chung hoặc chuyển giữa nhiều tài khoản. Supabase lưu lịch ôn và phiên học;
ngày bắt đầu kế hoạch hiện lưu trên máy. Khi lỗi mạng, có thể thử đồng bộ lại.

## Kiểm tra local
```sh
node scripts/prepare-content.mjs
cd mobile
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Nội dung/audio được giữ trong repo dữ liệu private, không nằm trong repo code public.
Bài nghe không có MP3 hiển thị rõ trạng thái chỉ có lời thoại.
