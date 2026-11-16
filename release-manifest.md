# Bản phát hành 16/11/2026 — danh mục phiên bản

Tài liệu này ghi lại đúng những gì tạo nên bản phát hành hiện hành của FET3D tính tới ngày 16/11/2026: commit của từng repo, phiên bản runtime, bản Unity được ghim trong ứng dụng, phiên bản ứng dụng, gói Android đã ký và nơi chạy production. Dùng nó để biết "bản đang chạy là bản nào" khi nghiệm thu, báo lỗi hoặc dựng lại. Bản này thay cho danh mục ngày 15/11/2026; runtime vẫn là 2.5.0, các thay đổi sau 15/11 chỉ nằm ở web, máy chủ, ứng dụng Android và worker.

Cách lấy số liệu: commit đọc bằng `git rev-parse --short origin/main` và `git log -1 --format=%ci origin/main` sau `git fetch origin` sáng 16/11/2026; các mục còn lại đọc từ tệp trong repo ở đúng commit đó hoặc từ ghi chú bàn giao của nhóm. Mục nào không kiểm được trực tiếp được ghi rõ. Cấu hình (tên biến) và danh mục thư viện, giấy phép ở [cau-hinh-va-thu-vien.md](cau-hinh-va-thu-vien.md); biên bản bàn giao ở [bien-ban-ban-giao.md](bien-ban-ban-giao.md).

## 1. Commit `main` của từng repo

| Repo | Commit `main` | Ngày giờ commit (giờ Việt Nam) | Thay đổi so với danh mục 15/11/2026 |
| :--- | :--- | :--- | :--- |
| Unity | `43839c2` | 16/11/2026 00:28 | Gộp PR #144: worker dựng gói báo cáo cảnh báo dựng thật về BE (#143); ghi nguồn nhân vật, động tác vào `CREDITS.md` (#141). Runtime vẫn 2.5.0 |
| Mobile | `533b6ee` | 16/11/2026 00:30 | Gộp PR #103: câu báo lỗi dễ hiểu khi đăng nhập Google (#102); cấu hình Firebase có khóa ký của Google Play (#100); gọi lấy token Google một lần (#98). Bản Unity ghim không đổi |
| FE | `f1a7a22` | 15/11/2026 22:05 | Gộp PR #236: sửa và dừng tình huống trong bài học, nguồn gốc mục thư viện (#235); mã QR in nội dung từ BE, trang tải ứng dụng (#233/#234); giao yêu cầu doanh nghiệp cho Admin khác (#232) |
| BE | `528f9c4` | 15/11/2026 23:05 | Gộp PR #205: sửa quá thời gian khi AI soạn nháp kịch bản (BE#204) |
| AI | `47efb6d` | 15/11/2026 19:20 | Không đổi so với danh mục 15/11/2026 |
| Docs | `a3abe37` | 16/11/2026 10:03 | Gộp PR #110: quyết định của trưởng nhóm ngày 16/11/2026 (#107–#110). Bộ hồ sơ nghiệm thu này vào `main` sau commit đó, nên `main` của Docs sẽ mới hơn |

Ngày giờ là giờ Việt Nam (UTC+7), đổi từ giờ ghi trong commit. Commit `main` của một repo không tự chứng minh máy chủ đang chạy đúng commit đó: commit đang chạy trên máy chủ BE, máy chủ AI và bản web trên Vercel chưa được kiểm trong lần rà này (mục 6).

## 2. Runtime và bản Unity trong ứng dụng

| Mục | Giá trị | Đọc từ |
| :--- | :--- | :--- |
| Phiên bản runtime | 2.5.0 | `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json`; `Mobile/src/features/training/runtime-version.ts` (`APP_RUNTIME_VERSION`) |
| Giao thức kết nối / định dạng gói bài | `1` / `1` | Cùng tệp `runtime-2.5.0.json` (`protocolVersion`, `manifestSchemaVersion`) |
| Tệp danh mục năng lực để đăng ký trên trang quản trị | `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json` | Repo Unity |
| Trạng thái trên production | Phiên bản 2.5.0 đã đăng ký và bật ngày 15/11/2026 | Ghi chú bàn giao của nhóm; chưa mở lại trang quản trị để kiểm trong lần rà này |
| Unity Editor | 6000.6.6f1 | [technology mục 4](fire-evacuation-training-technology.md#4-thành-phần-và-stack) |
| Bản Unity ghim trong Mobile (thẻ phát hành) | `unity-runtime-2.5.0-202611151038-portable.1` (repo `Capstone-FA26SE186-Fire3D/Mobile`, tệp `fet3d-unityLibrary-2.5.0-202611151038-portable.1.zip`) | `Mobile/unity-artifact.lock.json`, đổi lần cuối ở commit `21720c1` ngày 15/11/2026 |
| sha256 của bản ghim | `122cd6a6a347ca364733475c99aae64e5d28684277da0cc1e058efae20708319` | `Mobile/unity-artifact.lock.json` |
| Bản xuất Unity gốc | `2.5.0-202611151038`, sha256 `74dbd1d613aacf54a9a120479d2e2810d04a021f5643531f2cf4778016600482` | `Mobile/unity-artifact.lock.json` (`sourceExport`) |

Runtime 2.5.0 giữ nguyên giao thức, định dạng gói và danh sách thiết bị của 2.4.0; gói bài đã dựng cho 2.0.0 đến 2.4.0 vẫn chơi được ([IFC mục 6.2, Runtime 2.5.0](ifc_ingestion_visual_interaction.md#runtime-250-15112026)). Thay đổi Unity sau 15/11 (#141, #143) chỉ ở tài liệu và worker dựng gói, không nằm trong bản xuất đã ghim.

## 3. Ứng dụng Android

| Mục | Giá trị | Đọc từ |
| :--- | :--- | :--- |
| Tên gói | `com.fet3d.app` | `Mobile/app.json` |
| Phiên bản ứng dụng | 1.0.0 | `Mobile/app.json` |
| Gói bàn giao (AAB) | versionCode 1002250, dựng từ Mobile `main` `533b6ee` | Ghi chú bàn giao |
| Cách dựng | Dựng trên máy trưởng nhóm ngày 16/11/2026 bằng script dựng gói đã ký của nhóm, ký bằng khóa tải lên (upload key) của Google Play; script kiểm chữ ký trùng khóa tải lên. Mật khẩu khóa do trưởng nhóm nhập, không lưu trong repo | Ghi chú bàn giao |
| Tệp và mã băm | `artifacts/apk/play-1002250/app-release.aab` trên máy trưởng nhóm (189.778.643 byte), sha256 `eb81f9ad10ec5b893f037dedf4cf1b85421fa211b6e3227628435272d320cd20` | Tính lại bằng `sha256sum` ngày 16/11/2026. Tệp không nằm trong repo nào |
| Vì sao dựng trên máy | Lượt dựng Android miễn phí của Expo đã hết tới 01/12/2026, nên workflow Google Play trên Mobile `main` sẽ hỏng ở bước dựng tới ngày đó. Lượt dựng CI gần nhất thành công là versionCode 1001901 (Mobile `3ada34b`, 15/11/2026). Mã kết thúc bằng 50 để không trùng mã do CI cấp | Ghi chú bàn giao; [Mobile/docs/google-play-release.md](../Mobile/docs/google-play-release.md) |
| Google Play, kênh chính thức | Chưa có. Lượt nộp ngày 15/11/2026 dựng và ký đạt nhưng Google từ chối vì chưa đủ 12 người thử trong 14 ngày | Ghi chú bàn giao |
| Cách phát hành hiện tại | Trưởng nhóm tự tải gói lên kênh thử nghiệm của Google Play, hoặc nhóm gửi tệp cài `.apk` | Ghi chú bàn giao |
| Thiết bị đã cài và chơi | Redmi Note 10S (bản 2.5.0 ngày 15/11/2026) | [IFC mục 10.2](ifc_ingestion_visual_interaction.md#102-thiết-bị-nghiệm-thu-và-số-đo-trên-máy) |

## 4. Máy chủ production

| Phần | Địa chỉ / nơi chạy |
| :--- | :--- |
| Web | `fet3d.io.vn`, chạy trên Vercel, đi qua lớp bảo vệ OneShield của iNET |
| API (BE) | `api.fet3d.io.vn`, AWS EC2 Singapore, Caddy giữ TLS; triển khai bằng workflow `azure-deploy.yml` của BE khi gộp vào `main` |
| AI/RAG | AWS EC2 Singapore, chỉ BE gọi tới. `AI/docs/deploy-azure.md` ghi AI chạy cùng máy chủ BE từ 10/11/2026; danh mục 15/11/2026 ghi máy riêng (mục 6) |
| IFC geometry worker và Unity build worker | Một máy ảo Azure Windows, tự lấy việc từ BE và tự cập nhật mã worker từ repo Unity; tắt khi không dùng |
| Cơ sở dữ liệu / lưu trữ tệp | Supabase PostgreSQL / Amazon S3 |

Chi tiết hạ tầng ở [README, bảng Tổng quan công nghệ](README.md#tổng-quan-công-nghệ) và [technology mục 14.1](fire-evacuation-training-technology.md#141-phân-chia-thành-phần). Hướng dẫn chạy, triển khai và vận hành từng phần ở [cau-hinh-va-thu-vien.md mục 1](cau-hinh-va-thu-vien.md#1-hướng-dẫn-chạy-triển-khai-và-vận-hành).

## 5. Nội dung nghiệm thu đi cùng bản này

- Hai công trình nghiệm thu, tệp nguồn và mã băm: [IFC mục 10.1](ifc_ingestion_visual_interaction.md#101-hai-công-trình-nghiệm-thu).
- Số đo trên điện thoại và các mục chưa đo: [IFC mục 10.2](ifc_ingestion_visual_interaction.md#102-thiết-bị-nghiệm-thu-và-số-đo-trên-máy).
- Giới hạn đã biết: [README, Giới hạn đã biết](README.md#giới-hạn-đã-biết-của-bản-phát-hành-15112026).
- Kịch bản kiểm thử chấp nhận: [kich-ban-uat.md](kich-ban-uat.md).
- Cấu hình, thư viện và giấy phép: [cau-hinh-va-thu-vien.md](cau-hinh-va-thu-vien.md).
- Biên bản bàn giao: [bien-ban-ban-giao.md](bien-ban-ban-giao.md).

## 6. Chưa xác nhận trong lần rà này

- Commit đang chạy thật trên máy chủ BE (`528f9c4` hay commit cũ hơn), máy chủ AI (`47efb6d` hay commit cũ hơn) và bản web trên Vercel (`f1a7a22` hay cũ hơn). Lần rà này chỉ đọc `origin/main`, không đăng nhập máy chủ hay trang Vercel.
- AI chạy cùng máy EC2 với BE hay trên máy riêng: hai nguồn ghi khác nhau, chưa đăng nhập AWS để kiểm.
- Phiên bản runtime đang bật trên trang quản trị production (lấy theo ghi chú bàn giao).
- Mã băm của các gói bài Android đang phát hành trên production.
- AAB versionCode 1002250 đã được tải lên kênh thử nghiệm nào của Google Play chưa, và bản cài từ Google Play đăng nhập Google được chưa (Mobile#9).
- Bản AAB 1002250 chưa được cài và chơi thử trên điện thoại; lần chơi thử gần nhất là bản 2.5.0 ngày 15/11/2026.
