# Bản phát hành 15/11/2026 — danh mục phiên bản

Tài liệu này ghi lại đúng những gì tạo nên bản phát hành ngày 15/11/2026 của FET3D: commit của từng repo, phiên bản runtime, bản Unity được ghim trong ứng dụng, phiên bản ứng dụng và nơi chạy production. Dùng nó để biết "bản đang chạy là bản nào" khi nghiệm thu, báo lỗi hoặc dựng lại.

Cách lấy số liệu: commit đọc bằng `git rev-parse --short origin/main` sau `git fetch origin` lúc tối 15/11/2026; các mục còn lại đọc từ tệp trong repo ở đúng commit đó hoặc từ ghi chú bàn giao của nhóm. Mục nào không kiểm được trực tiếp được ghi rõ.

## 1. Commit `main` của từng repo

| Repo | Commit `main` | Ngày giờ commit (giờ Việt Nam) | Ghi chú |
| :--- | :--- | :--- | :--- |
| Unity | `ae71e04` | 15/11/2026 18:08 | Gộp PR #140: sửa cửa sau khi thử trên điện thoại. Runtime 2.5.0 |
| Mobile | `3ada34b` | 15/11/2026 18:26 | Gộp PR #95: ghim bản Unity `…151038-portable.1` |
| FE | `7be3008` | 14/11/2026 23:21 | Gộp PR #231. Không đổi trong ngày 15/11 |
| BE | `46716f8` | 13/11/2026 08:31 | Không đổi trong ngày 15/11 |
| AI | `47efb6d` | 15/11/2026 19:20 | Commit này vào `main` sau khi Unity và Mobile đã phát hành; chưa xác nhận máy chủ AI đã chạy commit này |
| Docs | `83262d5` | 15/11/2026 18:08 | Gộp PR #102 |

Ngày giờ là giờ Việt Nam (UTC+7), đổi từ giờ ghi trong commit. Commit `main` của một repo không tự chứng minh máy chủ đang chạy đúng commit đó: commit đang chạy trên máy chủ BE và AI chưa được kiểm trong lần rà này.

## 2. Runtime và bản Unity trong ứng dụng

| Mục | Giá trị | Đọc từ |
| :--- | :--- | :--- |
| Phiên bản runtime | 2.5.0 | `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json`; `Mobile/src/features/training/runtime-version.ts` (`APP_RUNTIME_VERSION`) |
| Giao thức kết nối / định dạng gói bài | `1` / `1` | Cùng tệp `runtime-2.5.0.json` (`protocolVersion`, `manifestSchemaVersion`) |
| Tệp danh mục năng lực để đăng ký trên trang quản trị | `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json` | Repo Unity |
| Trạng thái trên production | Phiên bản 2.5.0 đã đăng ký và bật ngày 15/11/2026 | Ghi chú bàn giao của nhóm; chưa mở lại trang quản trị để kiểm trong lần rà này |
| Unity Editor | 6000.6.6f1 | [technology mục 4](fire-evacuation-training-technology.md#4-thành-phần-và-stack) |
| Bản Unity ghim trong Mobile (thẻ phát hành) | `unity-runtime-2.5.0-202611151038-portable.1` (repo `Capstone-FA26SE186-Fire3D/Mobile`, tệp `fet3d-unityLibrary-2.5.0-202611151038-portable.1.zip`) | `Mobile/unity-artifact.lock.json` |
| sha256 của bản ghim | `122cd6a6a347ca364733475c99aae64e5d28684277da0cc1e058efae20708319` | `Mobile/unity-artifact.lock.json` |
| Bản xuất Unity gốc | `2.5.0-202611151038`, sha256 `74dbd1d613aacf54a9a120479d2e2810d04a021f5643531f2cf4778016600482` | `Mobile/unity-artifact.lock.json` (`sourceExport`) |

Runtime 2.5.0 giữ nguyên giao thức, định dạng gói và danh sách thiết bị của 2.4.0; gói bài đã dựng cho 2.0.0 đến 2.4.0 vẫn chơi được ([IFC mục 6.2, Runtime 2.5.0](ifc_ingestion_visual_interaction.md#runtime-250-15112026)).

## 3. Ứng dụng Android

| Mục | Giá trị | Đọc từ |
| :--- | :--- | :--- |
| Tên gói | `com.fet3d.app` | `Mobile/app.json` |
| Phiên bản ứng dụng | 1.0.0 | `Mobile/app.json` |
| Mã phiên bản (versionCode) | 1001901 | Lượt dựng Google Play ngày 15/11/2026 từ Mobile `main` `3ada34b` (ghi chú bàn giao) |
| Google Play, kênh chính thức | Chưa có. Lượt nộp ngày 15/11/2026 dựng và ký đạt nhưng Google từ chối vì chưa đủ 12 người thử trong 14 ngày | Ghi chú bàn giao |
| Cách phát hành hiện tại | Kênh thử nghiệm của Google Play do trưởng nhóm tự tải gói lên, hoặc tệp cài `.apk` do nhóm gửi | Ghi chú bàn giao; trạng thái từng kênh thử nghiệm chưa kiểm trong lần rà này |
| Thiết bị đã cài và chơi | Redmi Note 10S | [IFC mục 10.2](ifc_ingestion_visual_interaction.md#102-thiết-bị-nghiệm-thu-và-số-đo-trên-máy) |

## 4. Máy chủ production

| Phần | Địa chỉ / nơi chạy |
| :--- | :--- |
| Web | `fet3d.io.vn`, chạy trên Vercel, đi qua lớp bảo vệ OneShield của iNET |
| API (BE) | `api.fet3d.io.vn`, AWS EC2 Singapore, Caddy giữ TLS |
| AI/RAG | AWS EC2 Singapore, máy riêng, chỉ BE gọi tới |
| IFC geometry worker và Unity build worker | Một máy ảo Azure Windows, tự lấy việc từ BE; tắt khi không dùng |
| Cơ sở dữ liệu / lưu trữ tệp | Supabase PostgreSQL / Amazon S3 |

Chi tiết hạ tầng ở [README, bảng Tổng quan công nghệ](README.md#tổng-quan-công-nghệ) và [technology mục 14.1](fire-evacuation-training-technology.md#141-phân-chia-thành-phần).

## 5. Nội dung nghiệm thu đi cùng bản này

- Hai công trình nghiệm thu, tệp nguồn và mã băm: [IFC mục 10.1](ifc_ingestion_visual_interaction.md#101-hai-công-trình-nghiệm-thu).
- Số đo trên điện thoại và các mục chưa đo: [IFC mục 10.2](ifc_ingestion_visual_interaction.md#102-thiết-bị-nghiệm-thu-và-số-đo-trên-máy).
- Giới hạn đã biết: [README, Giới hạn đã biết](README.md#giới-hạn-đã-biết-của-bản-phát-hành-15112026).
- Kịch bản kiểm thử chấp nhận: [kich-ban-uat.md](kich-ban-uat.md).

## 6. Chưa xác nhận trong lần rà này

- Commit đang chạy thật trên máy chủ BE, máy chủ AI và bản web trên Vercel.
- Phiên bản runtime đang bật trên trang quản trị production (lấy theo ghi chú bàn giao).
- Mã băm của các gói bài Android đang phát hành trên production.
- Kênh thử nghiệm Google Play nào đang có bản versionCode 1001901.
