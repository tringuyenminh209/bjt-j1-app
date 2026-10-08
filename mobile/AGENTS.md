# BJT J1 cá nhân
- Flutter iOS, tiếng Nhật cho nội dung; tiếng Việt cho hướng dẫn.
- Mục tiêu J1 trong 8 tuần, 90 phút mỗi ngày.
- Nội dung JSON là nguồn chính; SQLite lưu offline, Supabase sao lưu.
- Tìm caller trước khi thêm helper. Không thêm backend hoặc state framework nếu chưa cần.
- Không commit secrets. Supabase chỉ dùng publishable/anon key và RLS.
- Chạy `dart format lib test`, `flutter analyze`, `flutter test` trước build.
- IPA chưa ký dùng Sideloadly; không cần distribution certificate trong CI.
