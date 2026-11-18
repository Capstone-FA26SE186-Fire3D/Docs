# Bản phát hành 18/11/2026 — danh mục phiên bản

Tài liệu này ghi lại đúng những gì tạo nên bản phát hành hiện hành của FET3D tính tới ngày 18/11/2026: commit của từng repo, phiên bản runtime, bản Unity được ghim trong ứng dụng, phiên bản ứng dụng, gói Android đã ký và nơi chạy production. Dùng nó để biết "bản đang chạy là bản nào" khi nghiệm thu, báo lỗi hoặc dựng lại. Bản này thay cho danh mục ngày 17/11/2026 (sửa thêm 18/11: chỉ đường, mũi tên cầu thang, tay che mũi; danh mục 17/11 thay cho 16/11); runtime vẫn là 2.5.0. Thay đổi sau 16/11 nằm ở web, ứng dụng Android và bản Unity ghim trong ứng dụng (sửa lỗi sau buổi UAT 16/11), không đổi giao thức hay định dạng gói.

Cách lấy số liệu: commit đọc bằng `git rev-parse --short origin/main` và `git log -1 --format=%ci origin/main` sau `git fetch origin` tối 17/11/2026 (giờ đổi sang UTC+7 bằng `--date=format-local` với `TZ=UTC-7`, vì commit gộp trên GitHub ghi giờ UTC); các mục còn lại đọc từ tệp trong repo ở đúng commit đó hoặc từ ghi chú bàn giao của nhóm. Mục nào không kiểm được trực tiếp được ghi rõ. Cấu hình (tên biến) và danh mục thư viện, giấy phép ở [cau-hinh-va-thu-vien.md](cau-hinh-va-thu-vien.md); biên bản bàn giao ở [bien-ban-ban-giao.md](bien-ban-ban-giao.md).

## 1. Commit `main` của từng repo

| Repo | Commit `main` | Ngày giờ commit (giờ Việt Nam) | Thay đổi so với danh mục 16/11/2026 |
| :--- | :--- | :--- | :--- |
| Unity | `a9f854b` | 18/11/2026 15:00 | Gộp PR #151/#152: chỉ đường dò lại từ vị trí người chơi mỗi 0,25 giây, không xuyên tường; mũi tên nằm trên bậc cầu thang; che mũi bằng khăn ướt: tay cầm khăn đưa lên mặt (động tác TowelCover). Trước đó 17/11: Gộp PR #146, #148, #150: cửa chỉ mở hết góc phòng cho phép, cửa chật thì kéo; cửa hai cánh không còn bị quay ngược khi dựng gói; ô kỹ thuật thấp không tính là cửa (#145); cánh thứ hai của cửa hai cánh không còn bị gộp tĩnh khi bake ánh sáng (#147); bồn rửa, vòi sen, giường từ IFC được nhắm đúng chỗ đặt (`PivotOnMesh`). Runtime vẫn 2.5.0 |
| Mobile | `8d7afbe` | 18/11/2026 16:06 | Gộp PR #117/#118: ghim bản Unity `2.5.0-202611180802-portable.1`. Trước đó PR #116: Gộp PR #116 (từ PR #115): ảnh đại diện gửi byte ảnh, vì `fetch` của Expo 57 từ chối phần `{uri}` và app báo nhầm là mất kết nối. Trước đó PR #110, #112, #114: mất mạng hiện một câu tiếng Việt dễ hiểu ở mọi màn hình (lỗi L7 UAT); ảnh đại diện tải lên qua API thay vì PUT thẳng S3 (L10); lượt chơi mà Unity tắt giữa chừng được kết thúc là "Chưa kết thúc" (L11); nút nổi không còn làm văng ứng dụng khi chơi lại (L9); ghim lại bản Unity ba lần theo các bản sửa cửa và thiết bị IFC |
| FE | `c2a340d` | 16/11/2026 22:49 | Gộp PR #241: sửa lỗi buổi UAT 16/11 (nhãn dễ hiểu, trang hiện trạng thái mới ngay sau thao tác, mỗi thao tác một nút); bộ test e2e chạy đủ |
| BE | `528f9c4` | 15/11/2026 23:05 | Không đổi so với danh mục 16/11/2026 |
| AI | `47efb6d` | 15/11/2026 19:20 | Không đổi so với danh mục 16/11/2026 |
| Docs | `af7d165` | 16/11/2026 13:12 | Gộp PR #114 (danh mục 16/11). Bản cập nhật danh mục này vào `main` sau commit đó, nên `main` của Docs sẽ mới hơn |

Ngày giờ là giờ Việt Nam (UTC+7), đổi từ giờ ghi trong commit. Commit `main` của một repo không tự chứng minh máy chủ đang chạy đúng commit đó: commit đang chạy trên máy chủ BE, máy chủ AI và bản web trên Vercel chưa được kiểm trong lần rà này (mục 6).

## 2. Runtime và bản Unity trong ứng dụng

| Mục | Giá trị | Đọc từ |
| :--- | :--- | :--- |
| Phiên bản runtime | 2.5.0 | `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json`; `Mobile/src/features/training/runtime-version.ts` (`APP_RUNTIME_VERSION`) |
| Giao thức kết nối / định dạng gói bài | `1` / `1` | Cùng tệp `runtime-2.5.0.json` (`protocolVersion`, `manifestSchemaVersion`) |
| Tệp danh mục năng lực để đăng ký trên trang quản trị | `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json` | Repo Unity |
| Trạng thái trên production | Phiên bản 2.5.0 đã đăng ký và bật ngày 15/11/2026 | Ghi chú bàn giao của nhóm; chưa mở lại trang quản trị để kiểm trong lần rà này |
| Unity Editor | 6000.6.6f1 | [technology mục 4](fire-evacuation-training-technology.md#4-thành-phần-và-stack) |
| Bản Unity ghim trong Mobile (thẻ phát hành) | `unity-runtime-2.5.0-202611180802-portable.1` (repo `Capstone-FA26SE186-Fire3D/Mobile`, tệp `fet3d-unityLibrary-2.5.0-202611180802-portable.1.zip`) | `Mobile/unity-artifact.lock.json`, đổi lần cuối ngày 18/11/2026 (Mobile PR #117) |
| sha256 của bản ghim | `669249b3328b1391b9ab2d9f8eaba288886f4e91e76d5f7a8675b16bfbc9cbc2` | `Mobile/unity-artifact.lock.json` |
| Bản xuất Unity gốc | `2.5.0-202611180802`, sha256 `813861bd0cfe68e8271d034dec21c565ab8b2a31a4e9ec024768b0d23a0175be` | `Mobile/unity-artifact.lock.json` (`sourceExport`) |

Runtime 2.5.0 giữ nguyên giao thức, định dạng gói và danh sách thiết bị của 2.4.0; gói bài đã dựng cho 2.0.0 đến 2.4.0 vẫn chơi được ([IFC mục 6.2, Runtime 2.5.0](ifc_ingestion_visual_interaction.md#runtime-250-15112026)). Bản xuất ghim ngày 17/11 đã gồm các sửa cửa và thiết bị IFC ở mục 1. Gói bài trường học được dựng lại thành bản v5 ngày 17/11/2026 để có cánh cửa thứ hai đúng; các bản v3, v4 đã thu hồi.

## 3. Ứng dụng Android

| Mục | Giá trị | Đọc từ |
| :--- | :--- | :--- |
| Tên gói | `com.fet3d.app` | `Mobile/app.json` |
| Phiên bản ứng dụng | 1.0.0 | `Mobile/app.json` |
| Gói bàn giao (AAB) | versionCode 1003050, dựng từ Mobile nhánh ghim `b3d614b` (nội dung trùng `main` `8d7afbe`) | Ghi chú bàn giao |
| Cách dựng | Dựng trên máy trưởng nhóm ngày 17/11/2026 bằng script dựng gói đã ký của nhóm, ký bằng khóa tải lên (upload key) của Google Play; script kiểm chữ ký trùng khóa tải lên. Mật khẩu khóa do trưởng nhóm nhập, không lưu trong repo | Ghi chú bàn giao |
| Tệp và mã băm | `artifacts/apk/play-1003050/app-release.aab` trên máy trưởng nhóm (189.805.724 byte), sha256 `b0090787d1ab59bc6846cad6fe3467cc889f53f0395bf037f9479cfdd75d9c71`; ký bằng khóa tải lên (SHA-256 `77:B5:D3:…:3B:28`), gói JS gọi `https://api.fet3d.io.vn/` | Tính lại bằng `sha256sum` ngày 18/11/2026. Tệp không nằm trong repo nào |
| Vì sao dựng trên máy | Lượt dựng Android miễn phí của Expo đã hết tới 01/12/2026, nên workflow Google Play trên Mobile `main` sẽ hỏng ở bước dựng tới ngày đó. Lượt dựng CI gần nhất thành công là versionCode 1001901 (Mobile `3ada34b`, 15/11/2026). Mã kết thúc bằng 50 để không trùng mã do CI cấp | Ghi chú bàn giao; [Mobile/docs/google-play-release.md](../Mobile/docs/google-play-release.md) |
| Google Play, kênh chính thức | Chưa có. Lượt nộp ngày 15/11/2026 dựng và ký đạt nhưng Google từ chối vì chưa đủ 12 người thử trong 14 ngày | Ghi chú bàn giao |
| Cách phát hành hiện tại | Trưởng nhóm tự tải gói lên kênh thử nghiệm của Google Play (1002850 tải lên ngày 17/11/2026; 1002950 thay thế, sửa lỗi ảnh đại diện), hoặc nhóm gửi tệp cài `.apk`. Các bản 1002450 trở về trước không dùng nữa; 1002450 gọi nhầm máy chủ cũ | Ghi chú bàn giao |
| Thiết bị đã cài và chơi | Redmi Note 10S ngày 17/11/2026: bản 1002850 (chơi thử cửa trường học, bồn rửa, vòi sen IFC) rồi APK thử 1002900 cùng mã nguồn với 1002950 (chơi liền 15 phút, chơi lại từ 3 lượt, đổi ảnh đại diện: trưởng nhóm báo đạt) | [IFC mục 10.2](ifc_ingestion_visual_interaction.md#102-thiết-bị-nghiệm-thu-và-số-đo-trên-máy) |

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

- Commit đang chạy thật trên máy chủ BE (`528f9c4` hay commit cũ hơn), máy chủ AI (`47efb6d` hay commit cũ hơn) và bản web trên Vercel (`c2a340d` hay cũ hơn). Lần rà này chỉ đọc `origin/main`, không đăng nhập máy chủ hay trang Vercel.
- AI chạy cùng máy EC2 với BE hay trên máy riêng: hai nguồn ghi khác nhau, chưa đăng nhập AWS để kiểm.
- Phiên bản runtime đang bật trên trang quản trị production (lấy theo ghi chú bàn giao).
- Mã băm của các gói bài Android đang phát hành trên production.
- Bản cài từ Google Play (1002950) đăng nhập Google được chưa (Mobile#9); bản thử trên điện thoại ngày 17/11 là APK ký debug cài qua cáp.
- Lần chơi 15 phút ngày 17/11 chỉ có xác nhận của trưởng nhóm, chưa có tệp số đo khung hình, nhiệt.
