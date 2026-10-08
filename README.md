# BJT J1 — Flutter source

Code Flutter iOS cho app học cá nhân, mục tiêu J1 trong 8 tuần, 90 phút/ngày.
Cupertino UI, 4 dạng câu hỏi, ôn cách quãng, SQLite offline, Google / Supabase sync.

Repo public này chỉ chứa code, cấu hình và tests; không có bài học, audio hoặc lịch sử
của repo dữ liệu private. `mobile/assets/` bị gitignore.

## Build IPA

Actions → **Build private IPA on public runner** → **Run workflow**.
Workflow chỉ chạy thủ công bởi chủ repo. Nó lấy assets từ repo private bằng deploy key
giới hạn đúng repo đó, build trên macOS standard runner rồi lưu IPA ở nhánh `ipa-builds`+của repo private. Không upload IPA thành artifact public vì IPA chứa nội dung học.

Sau khi build thành công, tải file từ:
https://github.com/tringuyenminh209/bjt-j1/blob/ipa-builds/BJT-J1-unsigned.ipa
và cài bằng Sideloadly. Apple ID chỉ dùng trên máy của bạn.

Secret `PRIVATE_DATA_SSH_KEY` là SSH deploy key có quyền ghi cho repo dữ liệu private,
để đọc nội dung và lưu IPA. Không dùng token có quyền toàn tài khoản.
Không thêm trigger chạy code pull request với key này.

Mỗi build lưu một bản binary vào Git private; nếu build thường xuyên, chuyển IPA sang
private object storage để giảm kích thước lịch sử.

## Chạy local

Copy `mobile/assets/` từ repo dữ liệu private vào máy, rồi:
```sh
cd mobile
flutter pub get
flutter analyze
flutter test
```

Google Login cần project Supabase riêng. Xem `mobile/README.md` để cấu hình.
