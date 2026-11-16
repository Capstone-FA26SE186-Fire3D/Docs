# Biên bản bàn giao FET3D (mẫu)

Mẫu biên bản bàn giao bản cuối của đồ án FET3D (FA26SE186), theo yêu cầu của Docs#42 (Completion D5). Các phần "Nội dung bàn giao" và "Tình trạng tiêu chí" đã điền theo hiện trạng ngày 16/11/2026; phần ký để trống, điền khi bàn giao thật. Nếu bàn giao ở commit khác, cập nhật [release-manifest.md](release-manifest.md) trước rồi chép lại số liệu vào đây.

## 1. Thông tin chung

| Mục | Nội dung |
| :--- | :--- |
| Sản phẩm | FET3D — hệ thống tập huấn thoát nạn cháy trên mô hình 3D từ tệp IFC |
| Bản bàn giao | Bản phát hành 16/11/2026, runtime 2.5.0, ứng dụng Android 1.0.0 (versionCode 1002350) |
| Ngày lập biên bản | ____/____/________ |
| Địa điểm | |

## 2. Nội dung bàn giao

### 2.1. Mã nguồn

Sáu repo trong tổ chức GitHub `Capstone-FA26SE186-Fire3D`, nhánh `main`, đúng commit dưới đây (chi tiết ở [release-manifest mục 1](release-manifest.md#1-commit-main-của-từng-repo)).

| Repo | Commit `main` | Nội dung | Đã nhận |
| :--- | :--- | :--- | :---: |
| BE | `528f9c4` | API nghiệp vụ .NET | ☐ |
| AI | `47efb6d` | Dịch vụ AI/RAG FastAPI | ☐ |
| FE | `51f705b` | Web Next.js | ☐ |
| Mobile | `7807eee` | Ứng dụng Android React Native/Expo, ghim bản Unity 2.5.0 | ☐ |
| Unity | `43839c2` | Runtime 3D, worker IFC, worker dựng gói | ☐ |
| Docs | `ad49be8` hoặc commit mới hơn | Tài liệu dự án | ☐ |

### 2.2. Hệ thống đang chạy

| Phần | Địa chỉ | Đã nhận |
| :--- | :--- | :---: |
| Web | https://fet3d.io.vn | ☐ |
| API | https://api.fet3d.io.vn | ☐ |
| AI/RAG, worker IFC và dựng gói, cơ sở dữ liệu, lưu trữ tệp | Không có địa chỉ công khai; nơi chạy ở [release-manifest mục 4](release-manifest.md#4-máy-chủ-production) | ☐ |
| Quyền quản trị: tài khoản PlatformAdmin, AWS, Azure, Vercel, Supabase, Firebase, Google Play Console, Expo, tên miền | Bàn giao riêng, không ghi vào tài liệu | ☐ |
| Giá trị bí mật (chỉ tên biến ở [cau-hinh-va-thu-vien mục 2](cau-hinh-va-thu-vien.md#2-biến-cấu-hình-chỉ-tên)) và khóa tải lên Google Play | Bàn giao riêng, không ghi vào tài liệu | ☐ |

### 2.3. Sản phẩm dựng sẵn

| Sản phẩm | Nhận dạng | Đã nhận |
| :--- | :--- | :---: |
| Gói Android đã ký (AAB) | versionCode 1002350, dựng từ Mobile `7807eee`, sha256 `136146bbf85d361b0d93fd05c17ca88e1f2456365100242a5b51c6f45d712237` | ☐ |
| Bản Unity ghim trong ứng dụng | Thẻ `unity-runtime-2.5.0-202611151038-portable.1`, sha256 `122cd6a6a347ca364733475c99aae64e5d28684277da0cc1e058efae20708319` | ☐ |
| Danh mục năng lực runtime | `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json` | ☐ |

### 2.4. Tài liệu

| Tài liệu | Đã nhận |
| :--- | :---: |
| [README](README.md): mục lục, công nghệ, quyết định, giới hạn đã biết | ☐ |
| Yêu cầu, công nghệ, luồng nghiệp vụ, schema, ERD: [requirements](fire_evacuation_requirements.md), [technology](fire-evacuation-training-technology.md), [workflows](fire-evacuation-training-workflows.md), [schema v7](schema_v7_contract.md), [ERD](fire_evacuation_erd.md), thư mục `ERD Logical Physical/` | ☐ |
| IFC, tương tác và số đo nghiệm thu: [ifc_ingestion_visual_interaction.md](ifc_ingestion_visual_interaction.md) | ☐ |
| Hướng dẫn: [học viên](huong-dan-hoc-vien.md), [quản trị](huong-dan-quan-tri.md), tổ chức (`FE/public/guides/fet3d-huong-dan-v1.md`) | ☐ |
| Kịch bản kiểm thử chấp nhận: [kich-ban-uat.md](kich-ban-uat.md) | ☐ |
| [release-manifest.md](release-manifest.md) | ☐ |
| [cau-hinh-va-thu-vien.md](cau-hinh-va-thu-vien.md): hướng dẫn vận hành, tên biến cấu hình, thư viện và giấy phép | ☐ |
| Báo cáo Review 2 (R1–R5, tài liệu kiểm thử, hai workbook): đang ở máy trưởng nhóm, không nằm trong repo | ☐ |

## 3. Tình trạng tiêu chí D5 (Docs#42) ngày 16/11/2026

| Tiêu chí | Tình trạng | Còn thiếu / chờ ai |
| :--- | :--- | :--- |
| Requirements, technology, workflows, schema, ERD khớp mã nguồn và quyết định đã chốt; liên kết kiểm tra được | Gần xong | Docs#9 (đồng bộ tài liệu với mã) đã đóng; quyết định 16/11/2026 đã ghi vào [overview](fire_evacuation_project_overview.md#quyết-định-của-trưởng-nhóm-ngày-16112026). Còn các quyết định mở ở Docs#10. Chờ trưởng nhóm xác nhận |
| Có hướng dẫn từng vai trò, cài APK, vận hành, migration, sao lưu/khôi phục và xử lý lỗi | Có, chưa nghiệm thu | Hướng dẫn viết từ mã nguồn, chưa bấm lại trên màn hình thật. Thiếu tài liệu chạy AI trên AWS EC2 (tiến trình, TLS, luật mạng) trong repo AI. Chờ nhóm AI và người thử |
| Có test report, UAT/khảo sát người dùng, danh mục thư viện và giấy phép, release manifest ghim commit sáu repo và mã băm sản phẩm | Một phần | Đã có: release manifest, mã băm AAB và bản Unity, danh mục thư viện và giấy phép. Thiếu: báo cáo UAT/khảo sát (Docs#41), test report nằm trong báo cáo Review 2 chưa đưa vào repo, mã băm các gói bài trên production. Chờ trưởng nhóm |
| Ghi cấu hình cần thiết dạng tên biến không kèm bí mật, giới hạn đã biết và người xác nhận; không sửa `Mẫu report/` chưa track | Một phần | Đã có tên biến và [giới hạn đã biết](README.md#giới-hạn-đã-biết-của-bản-phát-hành-15112026); `Mẫu report/` không bị sửa. Thiếu người xác nhận (mục 5 để trống). Chờ trưởng nhóm |
| D0 không còn yêu cầu thiếu bằng chứng hoặc quyết định treo trước khi ký | Chưa | Phụ thuộc Docs#37 (D0), #40 (ngưỡng RAM, thời gian tải, kích thước gói, số NPC, biên bản đo 15 phút), #41 (UAT), #10 (quyết định mở). Chờ trưởng nhóm |

Các issue chặn D5: Docs#41 (mở), Docs#10 (mở), Docs#9 (đã đóng), BE#103 (đã đóng).

## 4. Giới hạn đã biết và điểm chưa xác nhận

- Giới hạn của bản đang chạy (chỉ Android, không có gió, không có nét mặt hoảng loạn, máy ấm lên khi chơi lâu, chưa lên Google Play công khai, …): [README, Giới hạn đã biết](README.md#giới-hạn-đã-biết-của-bản-phát-hành-15112026).
- Những gì chưa kiểm trực tiếp (commit đang chạy trên máy chủ, runtime đang bật, AAB đã lên kênh thử nghiệm chưa, …): [release-manifest mục 6](release-manifest.md#6-chưa-xác-nhận-trong-lần-rà-này).
- Giấy phép: tài sản 3D, động tác và hai tệp IFC nghiệm thu không rà thêm theo quyết định 16/11/2026; dòng ghi tên tác giả cho mô hình CC BY 4.0 chưa có trong ứng dụng ([cau-hinh-va-thu-vien mục 4](cau-hinh-va-thu-vien.md#4-tài-sản-3d-động-tác-âm-thanh-và-ảnh)).
- Lượt dựng Android miễn phí của Expo hết tới 01/12/2026; trước ngày đó gói Android phải dựng trên máy.

## 5. Xác nhận

Bên nhận xác nhận đã nhận đủ các mục đánh dấu ☑ ở mục 2. Mục chưa đánh dấu ghi rõ lý do vào phần ghi chú.

Ghi chú: ______________________________________________________________

| | Người bàn giao | Người nhận | Người xác nhận |
| :--- | :--- | :--- | :--- |
| Họ và tên | | | |
| Vai trò | | | |
| Ngày | ____/____/________ | ____/____/________ | ____/____/________ |
| Chữ ký | | | |
