# Ma trận nghiệm thu FET3D (đối chiếu ngày 16/11/2026)

Tài liệu này điền cột "Trạng thái và bằng chứng" cho ma trận của [Docs#37](https://github.com/Capstone-FA26SE186-Fire3D/Docs/issues/37): 89 mã yêu cầu, 9 nhóm NFR và 8 dòng checklist, giữ đúng thứ tự và issue sở hữu như trong issue. Mỗi dòng ghi mức bằng chứng cao nhất tìm được và nơi mở lại bằng chứng đó.

**Chưa có yêu cầu nào được nghiệm thu chính thức.** Chưa có buổi UAT ba vai trò và chưa có biên bản ký ([Docs#41](https://github.com/Capstone-FA26SE186-Fire3D/Docs/issues/41) còn mở). "Đã thử trên production / máy thật" chỉ có nghĩa là đã có người chạy thử trên môi trường thật và ghi kết quả vào issue; đó không phải nghiệm thu.

## Cách đọc

| Trạng thái | Nghĩa |
| :--- | :--- |
| **Đã thử trên production / máy thật** | Có lượt chạy trên `api.fet3d.io.vn`, `fet3d.io.vn`, máy ảo worker hoặc điện thoại thật, ghi trong bình luận issue (nêu ngày). Có thể chỉ phủ một phần yêu cầu; phần còn thiếu ghi ở cột Ghi chú. |
| **Có test tự động** | Mã đã lên `main` và có test tự động nêu tên. Test FE và Mobile chạy với API giả lập (mock); không thay cho lượt chạy với API, nhà cung cấp hoặc thiết bị thật. |
| **Đã có trên main** | Mã đã lên `main` nhưng chưa tìm thấy test hay lượt chạy thật được ghi lại cho đúng yêu cầu này. |
| **Chờ người khác** | Issue sở hữu hoặc issue chặn của BE/AI (hoặc việc của người có quyền nhà cung cấp) vẫn mở. |
| **Bỏ / đổi theo quyết định** | Một phần hoặc toàn bộ yêu cầu bị bỏ hoặc đổi theo quyết định có ghi ngày. |
| **Chờ trưởng nhóm** | Cần quyết định, ngưỡng hoặc buổi UAT mà chỉ trưởng nhóm chốt được. |

Lưu ý chung về issue đã đóng: ngày 15/11/2026 phần lớn issue FE, Mobile và Unity được đóng theo quy ước của trưởng nhóm "mục đã có trong bản phát hành nhưng chưa nghiệm thu riêng thì không giữ issue mở". Bình luận đóng của từng issue tự ghi phần nào mới chạy với mock và phần nào "chưa chạy nghiệm thu riêng". Vì vậy **issue đóng không được tính là đạt**; ma trận này dựa vào nội dung bình luận, không dựa vào trạng thái đóng.

Commit `main` dùng khi đối chiếu (16/11/2026): AI `47efb6d`, BE `528f9c4`, FE `f1a7a22`, Mobile `533b6ee`, Unity `43839c2`. Commit đang chạy thật trên máy chủ BE, AI và Vercel chưa được kiểm trong lần rà này (giống [release-manifest.md](release-manifest.md) mục 6).

Viết tắt bằng chứng production dùng nhiều lần:

- **B1 21/10**: [BE#136](https://github.com/Capstone-FA26SE186-Fire3D/BE/issues/136), 12 bước thử trên production với Mailgun, Google/Firebase và S3 thật (OTP, giới hạn OTP, đăng ký, đăng nhập, refresh xoay vòng và replay, quên mật khẩu, ETag hồ sơ, avatar S3, Google onboarding, khóa tài khoản, logout-all); AuthTests 732/732.
- **B2 21/10**: [BE#137](https://github.com/Capstone-FA26SE186-Fire3D/BE/issues/137), 9 bước trên production: chặn publish khi chưa có dịch vụ, publish idempotent, mã tham gia tòa Private, xoay mã, một suất cho nhiều phiên, tranh suất cuối, chấm theo rubric ghim, chơi tiếp sau khi khóa/thu hồi, playtest không vào analytics. Sự kiện runtime ở bước 7–8 gửi qua API giả lập Unity, không phải từ điện thoại.
- **B3 21/10**: [BE#138](https://github.com/Capstone-FA26SE186-Fire3D/BE/issues/138), giao dịch PayOS thật 2.000 ₫ (order 10000008 đến 10000013): mua, gia hạn, hủy, nâng cấp, mua thêm quota AI, returnUrl không cấp quyền. Webhook lặp và trả link đã hủy chỉ có test tự động.
- **B8 23/10**: [BE#143](https://github.com/Capstone-FA26SE186-Fire3D/BE/issues/143), analytics tổ chức so với DB, lọc và chặn chéo tổ chức, xuất CSV chống chèn công thức (có audit), doanh thu Admin, khóa/mở tài khoản và tổ chức, ticket hỗ trợ.
- **B6 23/10**: [BE#141](https://github.com/Capstone-FA26SE186-Fire3D/BE/issues/141), retest bảo mật trên production: khóa đăng nhập sau 10 lần sai (429, `Retry-After`), header bảo mật, không còn header `Server`.
- **AI prod 13/11**: [BE#185](https://github.com/Capstone-FA26SE186-Fire3D/BE/issues/185), bình luận 13/11: trợ lý học viên hỏi được (người dùng xác nhận); trợ lý tổ chức có 9 yêu cầu `Succeeded` từ 10/11 đến 13/11 (hỏi đáp và đề xuất kịch bản), trừ đúng 1 lượt mỗi câu, có trích nguồn.
- **Redmi 15/11**: Redmi Note 10S, runtime 2.5.0, APK `FET3D-2.5.0-202611151038`, bài trường học trên production chạy 30 khung hình/giây ([Mobile#12](https://github.com/Capstone-FA26SE186-Fire3D/Mobile/issues/12), [Unity#12](https://github.com/Capstone-FA26SE186-Fire3D/Unity/issues/12)). Chưa có biên bản từng bước cho ba chế độ.

## Ma trận 89 mã yêu cầu

| Yêu cầu | Issue sở hữu | Trạng thái | Bằng chứng (mở lại ở đâu) | Ghi chú / còn thiếu |
| :--- | :--- | :--- | :--- | :--- |
| FR-WEB-01 | FE#104 (đóng 15/11) | Có test tự động | FE PR #234 (trang `/download` viết lại, đã lên production, xem bằng ảnh 375/1440 px); `tests/e2e/landing.spec.ts`, `learn-public.spec.ts` | Chưa có kênh tải chính thức (Google Play kênh chính thức bị từ chối, cần 12 người thử × 14 ngày) |
| FR-WEB-02 | FE#104 (đóng 15/11) | Có test tự động | `landing.spec.ts`, `landing-quality.spec.ts`, `ui-quality.spec.ts` (giảm chuyển động, ảnh thay thế khi WebGL lỗi; FE#69) | Chưa có lượt rà trên trình duyệt thật kèm ảnh (FE#69) |
| FR-WEB-03 | FE#104 (đóng 15/11) | Đã thử trên production / máy thật | AI prod 13/11 (trợ lý học viên hỏi được); `learn-search.spec.ts`, `learning-hub.spec.ts` | Chỉ có xác nhận miệng của người dùng cho câu trả lời có nguồn; chưa ghi request ID |
| FR-WEB-04 | FE#57 (đóng 15/11) | Có test tự động | `learning-hub.spec.ts`, `training-history.spec.ts`, `regression-session-tenant.spec.ts` (FE#57) | Lịch sử/kết quả chưa kiểm với phiên chơi Unity thật; bản sửa FE#100 chưa thử lại trên production |
| FR-WEB-05 | FE#49 (đóng 15/11) | Có test tự động | `scenario-editor-v1.spec.ts`, `scenario-editor-store.spec.ts` (FE#49); màn chạy thử PR #233 (FE#51) | Đổi tọa độ GLB mới thử trên fixture JSON; chuỗi Web → Mobile → Unity → kết quả về web chưa chạy hết (Mobile#14) |
| FR-WEB-06 | FE#52 (đóng 15/11) | Đã thử trên production / máy thật | B3 21/10 (mua gói, nâng cấp, mua thêm quota AI bằng PayOS thật); `billing-quota.spec.ts`, `billing-org.spec.ts` | Màn FE với dữ liệu thật chưa rà riêng sau PR #232 |
| FR-AUTH-01 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 | Mobile#9 còn mở: đăng nhập Google trên bản cài từ Google Play chưa thử (SHA-1 khóa Play đã thêm 15/11) |
| FR-AUTH-02 | BE#143 (đóng 23/10) | Đã thử trên production / máy thật | B8 23/10 bước 6–7; B1 bước 11 | |
| FR-AUTH-03 | BE#137 (đóng 23/10) | Đã thử trên production / máy thật | B2 21/10 bước 3–6; Redmi 15/11 (bài trường học bắt đầu được) | |
| FR-AUTH-04 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 1, 7 (mail OTP và đặt lại mật khẩu thật qua Mailgun); log không lộ mật khẩu/OTP/token | |
| FR-AUTH-05 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 1–4 | Luồng đăng ký trên Mobile chỉ có test (`registration.spec.ts`, Mobile#9) |
| FR-AUTH-06 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 4–5 | Ràng buộc định dạng username chỉ có test tự động |
| FR-AUTH-07 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 8 (428 / 200 / 412) | |
| FR-AUTH-08 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 10 (Google mới vào onboarding, không tự gộp); `google-link.spec.ts` | Liên kết Google vào tài khoản local chưa thấy lượt thử thật |
| FR-AUTH-09 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 9 (S3 thật, URL có chữ ký, bỏ chữ ký thì 403) | |
| FR-AUTH-10 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 10 | 409 `ACCOUNT_LINK_REQUIRED` chỉ có test tự động |
| FR-AUTH-11 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 7 (token cũ 401, mật khẩu cũ 401) | |
| FR-AUTH-12 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 2–3 (`OTP_RATE_LIMITED`, `INVALID_OTP`) | |
| FR-AUTH-13 | BE#136 (đóng 23/10) | Đã thử trên production / máy thật | B1 21/10 bước 5, 6, 12; FE `auth.spec.ts`, `fe-polish.spec.ts` (FE#103) | |
| FR-LEARN-01 | FE#53 (đóng 15/11) | Có test tự động | `learn-public.spec.ts`, `learn-search.spec.ts`; lọc nhiều tình huống ở `FE/src/features/learn/components/learn-browser.tsx` | App Mobile chỉ lọc theo loại bài, chưa lọc theo tình huống (Mobile#15) |
| FR-LEARN-02 | FE#53 (đóng 15/11) | Có test tự động | `learn-cms.spec.ts`; PR #235 (sửa/ngừng dùng tình huống) | Vòng đời xuất bản/ẩn với API thật chưa chạy (FE#53) |
| FR-LEARN-03 | FE#53 (đóng 15/11) | Có test tự động | `learn-cms.spec.ts` (FE#53) | Như trên |
| FR-LEARN-04 | FE#53 (đóng 15/11) | Có test tự động | PR #235 (tình huống không bao giờ bị xóa, chỉ ngừng dùng); `learn-cms.spec.ts` | |
| FR-LEARN-05 | FE#53 (đóng 15/11) | Có test tự động | Danh sách nhà cung cấp video trong `FE/src/features/admin-learn/components/learn-blocks.tsx`; Mobile `tests/learn-rich-text.test.mjs` (Mobile#58) | Kiểm video với API thật chưa chạy |
| FR-LEARN-06 | FE#53 (đóng 15/11) | Đã có trên main | Mobile mở đường dẫn nhà cung cấp bằng ứng dụng ngoài (`Mobile/app/learn/[slug].tsx`, Mobile#15) | Chưa thử từng nhà cung cấp trên điện thoại |
| FR-LEARN-07 | AI#20 (mở) | Chờ người khác | Mã có ở AI `rag-api` và BE; AI#20 bình luận 15/11 | Test pgvector chưa từng chạy với DB thật; cô lập tenant và nguồn bị thu hồi chưa nghiệm thu (AI#20, AI#33) |
| FR-LEARN-08 | Mobile#15 (đóng 15/11) | Có test tự động | `Mobile/app/learn/bookmarks.tsx`; e2e `learn-ai.spec.ts`; FE `learning-hub.spec.ts` | Đổi tài khoản trên điện thoại chưa thử |
| FR-LEARN-09 | BE#141 (đóng 23/10) | Đã có trên main | API Learn công khai (BE#79, đóng 14/10); B6 23/10 không nêu riêng bước Learn | Chưa tìm thấy lượt thử ghi riêng cho Draft/Hidden/Deleted trên production |
| FR-LEARN-10 | AI#20 (mở) | Chờ người khác | BE ghi audit và `PlatformCacheInvalidation` trong cùng transaction (thiết kế ở overview) | Issue sở hữu AI#20 còn mở; Redis Streams đang tắt trên production (`PROCESSING_DISABLED`, BE#132) |
| FR-LIBRARY-01 | FE#54 (đóng 15/11) | Có test tự động | `library-admin.spec.ts`; PR #235 (`isActive`, `libraryRefs[]`) | Một test cũ trong `library-admin.spec.ts` (dòng 408) đang đỏ, chưa sửa (FE#54) |
| FR-LIBRARY-02 | FE#54 (đóng 15/11) | Có test tự động | Như trên | If-Match, phiên bản bất biến và chặn chéo tổ chức với API thật chưa chạy; tìm/lọc ở trang thư viện tổ chức chỉ lọc trang đang tải vì API BE chưa nhận bộ lọc |
| FR-NOTIFY-01 | BE#140 (mở) | Chờ người khác | Mobile `src/services/device.native.ts`, test `tests/contracts.test.mjs` ("FCM binding and revoke…"); Mobile#51 đóng theo phạm vi | BE#140: chưa gửi push thật tới điện thoại; Mobile#9 còn mở |
| FR-BUILD-01 | FE#48 (đóng 15/11) | Đã thử trên production / máy thật | B2 21/10 (tạo hai tòa QA); `building-mutations.spec.ts`, `building-stale-etag.spec.ts` | |
| FR-IFC-01 | FE#48 (đóng 15/11) | Đã thử trên production / máy thật | B2 21/10 (tải `duplex.ifc`, Geometry `Passed`); hai công trình nghiệm thu đã tải và dựng ([IFC mục 10.1](ifc_ingestion_visual_interaction.md#101-hai-công-trình-nghiệm-thu)) | Từ chối theo mã kiểm tệp và kích thước chưa có lượt thử riêng (FE#48) |
| FR-IFC-02 | AI#23 (đóng 15/11) | Đã thử trên production / máy thật | Worker `Unity/Tools/GeometryWorker` chuyển trường học 5 tầng và tháp 28 tầng, chơi được trên Android (AI#23 bình luận 15/11) | **Lệch đặc tả:** không có NavMesh dựng sẵn; lưới đi lại do app tự quét (`GridRasterizer`), ghi ở README "Giới hạn đã biết" |
| FR-IFC-03 | FE#48 (đóng 15/11) | Có test tự động | `building-detail.spec.ts`, `ifc-pipeline-progress.spec.ts` (15 mã QA tiếng Việt); Unity PR #143 gửi cảnh báo dựng gói thật (`43839c2`) | Lần dựng gói kế tiếp trên VM là lần đầu gửi cảnh báo thật tới BE (Unity#6) |
| FR-IFC-04 | Unity#6 (đóng 16/11) | Đã thử trên production / máy thật | Hai công trình nghiệm thu qua QA và chơi được trên Redmi; bước chọn cửa thoát `door.exit` (BE#100, BE#102) | Kiểm đường từ điểm xuất phát làm bằng lưới trong app, không bằng NavMesh |
| FR-IFC-05 | Unity#6 (đóng 16/11) | Đã thử trên production / máy thật | Máy ảo worker dựng gói thật (B2 21/10: ReleasePackage Android 242 s) | **Lệch đặc tả:** không tìm thấy Blender trong mã `GeometryWorker` (grep 16/11) và không có NavMesh; đặc tả vẫn ghi "Blender script" và "NavMesh" |
| FR-IFC-06 | AI#23 (đóng 15/11) | Có test tự động | FE `scenario-editor-v1.spec.ts` (đổi tọa độ trên fixture BE); quyết định 16/11 một IFC cho mỗi phiên bản (BE#103) | Chưa thử trên một tệp GLB thật (FE#49) |
| FR-SCENARIO-01 | FE#49 (đóng 15/11) | Có test tự động | `scenario-editor-v1.spec.ts`; `libraryRefs[]` ghi khi áp mẫu (PR #235) | Bộ rubric mẫu khuyến nghị chưa chốt (overview, "Còn mở") |
| FR-SCENARIO-02 | Unity#55 (đóng 15/11 theo quyết định) | Có test tự động | B9 contract `routing_config.weights` nghiệm thu production 21/10 (BE#144); Unity `EvacuationRouteTests.RoutingConfigMapsToWeightsAndClamps`, `ScenarioWeightsChangeTheChosenRoute` (Unity#9) | Số hạng ùn tắc không còn được tính (gió bỏ 15/11). Issue sở hữu U1 đã đóng vì bỏ gió, nên dòng này không còn issue sở hữu đang hiệu lực |
| FR-SCENARIO-03 | FE#50 (đóng 15/11) | Đã thử trên production / máy thật | B2 21/10 (submit → Admin duyệt → confirm-for-training → release `Built`); `admin-scenario-reviews.spec.ts` | Smoke ba vai trò cho ca từ chối chưa chạy (FE#50) |
| FR-SCENARIO-04 | FE#48 (đóng 15/11) | Có test tự động | Test "Built is not Published…" (FE#50); Unity `RouteHintTests.HintWordingNeverClaimsRealWorldSafety` | |
| FR-SCENARIO-05 | Unity#55 (đóng 15/11 theo quyết định) | Bỏ / đổi theo quyết định | Gió bỏ 15/11/2026 (Unity#55, FE#106 đóng theo quyết định; README "Không có gió"). Phần còn lại (nguồn lửa, khói, cửa/vùng chặn, xuất phát, mục tiêu, thời lượng) có test ở `scenario-editor-v1.spec.ts` và Unity `HazardSimulationTests` | Xem mục "Điểm lệch": issue sở hữu và phối hợp (U1, B9, F4) đều là việc gió; mã gió vẫn còn trong BE/FE/Unity |
| FR-SCENARIO-06 | AI#22 (mở) | Chờ người khác | AI prod 13/11 có đề xuất kịch bản `Succeeded`; sau đó kẹt `NeedsReconcile` (BE#204, đóng 15/11) | BE#206 (thử lại một lần sau bản sửa) và AI#22 còn mở |
| FR-RELEASE-01 | BE#137 (đóng 23/10) | Đã thử trên production / máy thật | B2 21/10 bước 1–2; bài trường học phát hành 13/11 | |
| FR-RELEASE-02 | FE#58 (đóng 15/11) | Đã thử trên production / máy thật | B2 21/10 bước 3; Redmi 15/11 vào bài trường học từ production; `building-qr.spec.ts`, PR #234 | Quét QR in từ web bằng app chưa ghi riêng (FE#58) |
| FR-RELEASE-03 | Mobile#50 (đóng 15/11) | Đã thử trên production / máy thật | Điện thoại tải và kiểm SHA-256 gói 20/10 (Mobile#14) và 15/11 (Mobile#12) | Báo hết bộ nhớ chưa thử trên máy đầy (Mobile#50) |
| FR-RELEASE-04 | FE#58 (đóng 15/11) | Có test tự động | `building-qr.spec.ts`; PR #234 (mã thu hồi/thay khác với hết hạn dịch vụ) | Smoke API thật chưa chạy (FE#58) |
| FR-TRAINING-01 | Mobile#50 (đóng 15/11) | Có test tự động | Unity từ chối chế độ không cho phép (`MODE_NOT_ALLOWED`, Unity#10); Mobile `tests/training.test.mjs` | Ba chế độ tới màn kết quả chưa chạy trên điện thoại (Mobile#50) |
| FR-TRAINING-02 | Unity#10 (đóng 15/11) | Đã thử trên production / máy thật | Redmi 15/11 (bắt tay `Ready`/`Launch`); `tests/contracts.test.mjs` ("Ready must match the app"), Unity `ContractTests` | |
| FR-TRAINING-03 | Mobile#12 (đóng 15/11) | Đã thử trên production / máy thật | Chơi trên Redmi 04/11–15/11; Unity `EvacuationRouteTests`, `HazardSimulationTests`, `ForceWayOutTests` (Unity#9) | Debrief chi tiết theo kết quả BE chưa kiểm trên điện thoại (Mobile#16) |
| FR-TRAINING-04 | Mobile#50 (đóng 15/11) | Đã thử trên production / máy thật | B2 21/10 bước 3–6 (prepare/start chặn đúng); `tests/playtest.test.mjs` | |
| FR-TRAINING-05 | Unity#11 (đóng 16/11 theo quyết định) | Bỏ / đổi theo quyết định | Quyết định 16/11: số NPC do người soạn đặt, không giới hạn cứng (overview) | **Lệch tài liệu:** FR-TRAINING-05 vẫn ghi "số lượng NPC giới hạn … budget hiệu năng"; chưa đo số NPC tối đa máy chịu được |
| FR-TRAINING-06 | Mobile#13 (đóng 15/11) | Có test tự động | `tests/playtest.test.mjs` ("callbacks: persisted before ack…", "lost completion response…"), `tests/training.test.mjs` | Mất mạng giữa bài và tắt app giữa chừng chưa thử trên điện thoại (Mobile#13) |
| FR-TRAINING-07 | Unity#8 (đóng 15/11) | Đã thử trên production / máy thật | `CameraSweepTests`, `WallContactTests`, `StairDescentTests`; kiểm lại trên tòa IFC thật và trên Redmi (Unity#8) | Chưa có biên bản từng ca cảm ứng nhiều ngón |
| FR-TRAINING-08 | BE#137 (đóng 23/10) | Đã thử trên production / máy thật | B2 21/10 bước 7 (Passed / NotPassed / Incomplete / NotAssessed); chỉ số theo runtime catalog (BE#183) | Sự kiện gửi bằng API giả lập Unity; màn kết quả sau bài chơi thật trên điện thoại chưa kiểm (Mobile#16) |
| FR-TRAINING-09 | Unity#9 (đóng 15/11) | Đã thử trên production / máy thật | `SmokeLayerTests`, `SmokeContainmentTests`, `StanceSmokeTests`; chơi trên Redmi | |
| FR-ANALYTICS-01 | BE#143 (đóng 23/10) | Đã thử trên production / máy thật | B8 23/10 bước 1–2 (số liệu khớp DB) | |
| FR-ANALYTICS-02 | Mobile#16 (đóng 15/11) | Có test tự động | Mobile `tests/result-presentation.test.mjs`; FE `training-history.spec.ts`; chấm ở B2 21/10 | Màn kết quả trên điện thoại sau bài thật chưa kiểm |
| FR-ANALYTICS-03 | FE#61 (đóng 15/11) | Đã thử trên production / máy thật | B8 23/10 bước 2–3 (lọc, xuất CSV); FE PR #232 (CSV Admin, 429) | So sánh nhóm và CSV phía Admin mới chạy với mock (FE#61) |
| FR-BILLING-01 | BE#138 (đóng 23/10) | Đã thử trên production / máy thật | B3 21/10 (dịch vụ 12 tháng, 5 suất, grant quota AI) | Hạn mức Trial chưa thấy lượt thử thật; giá do PlatformAdmin đặt (quyết định 16/11) |
| FR-BILLING-02 | BE#137 (đóng 23/10) | Đã thử trên production / máy thật | B2 21/10 bước 1 (409 `BUILDING_ENTITLEMENT_REQUIRED`) | Hết hạn thật (không phải tòa chưa mua) chưa thử |
| FR-BILLING-03 | BE#138 (đóng 23/10) | Đã thử trên production / máy thật | B3 21/10 | Webhook lặp chỉ có test tự động |
| FR-BILLING-04 | BE#138 (đóng 23/10) | Đã thử trên production / máy thật | B3 21/10; B8 23/10 bước 4 (doanh thu khớp `payment_transactions`) | |
| FR-BILLING-05 | BE#139 (mở) | Chờ người khác | B3 21/10 ca 7 (mua thêm 100 credit); AI prod 13/11 (trừ đúng 1 lượt) | BE#139 (B4): tranh quota cuối và chặn khi hết quota chưa thử với AI thật |
| FR-BILLING-06 | BE#138 (đóng 23/10) | Đã thử trên production / máy thật | B3 21/10 ca 1 (returnUrl không cấp quyền), ca 7 (mua quota không gia hạn tòa) | |
| FR-BILLING-07 | BE#138 (đóng 23/10) | Đã thử trên production / máy thật | B3 21/10 (gia hạn nối kỳ, nâng cấp 5 → 6 suất) | |
| FR-BILLING-08 | BE#138 (đóng 23/10) | Có test tự động | `BE/Fire3D/Fire3D.Application/Billing/BillingContracts.cs`; `Fire3D.AuthTests/BillingPureUnitTests.cs`, `BillingApiTests.cs` | Chưa thấy lượt áp giảm giá trên production |
| FR-BILLING-09 | BE#140 (mở) | Chờ người khác | Nhắc hạn web/email/push có trong BE (`docs/billing.md`), test với adapter giả | BE#140: chưa gửi email nhắc hạn thật qua Mailgun, chưa kiểm không nhắc sau khi gia hạn |
| FR-BILLING-10 | BE#138 (đóng 23/10) | Có test tự động | Test billing của BE (B3 hướng dẫn `docs/acceptance/B3-payos-provisioning.md` ánh xạ checklist sang test) | Vòng đời báo giá có dùng trong B3 nhưng không ghi bước riêng |
| FR-BILLING-11 | BE#137 (đóng 23/10) | Đã thử trên production / máy thật | B2 21/10 bước 5–6 | |
| FR-SUPPORT-01 | BE#143 (đóng 23/10) | Đã thử trên production / máy thật | B8 23/10 bước 8 (ticket); FE `ops-admin-support.spec.ts`; Mobile `app/support.tsx` | Gửi hỗ trợ từ app chưa thử trên điện thoại |
| FR-AUDIT-01 | BE#143 (đóng 23/10) | Đã thử trên production / máy thật | B8 23/10 bước 3 (xuất CSV có audit) | Chỉ một loại audit được ghi lại trên production; các loại khác dựa vào test |
| FR-AUDIT-02 | BE#143 (đóng 23/10) | Chờ người khác | Audit AI có trong BE; B8 23/10 bước 5 lúc đó chưa có request AI | Phần AI phụ thuộc BE#139 (mở) |
| FR-AI-01 | AI#22 (mở) | Đã thử trên production / máy thật | AI prod 13/11 (9 yêu cầu tổ chức `Succeeded`, có nguồn); FE `org-ai-v7.spec.ts`, `org-ai-apply.spec.ts` | Nghiệm thu chung AI–BE chưa làm (AI#22, BE#139 mở) |
| FR-AI-02 | AI#22 (mở) | Chờ người khác | Như FR-SCENARIO-06 | BE#206, AI#22 |
| FR-AI-03 | AI#22 (mở) | Đã thử trên production / máy thật | AI prod 13/11 (trợ lý học viên); FE `learning-hub.spec.ts`; Mobile `tests/ai-suggestions.test.mjs` | Trên app Mobile với nhà cung cấp thật chưa thử (Mobile#16) |
| FR-AI-04 | BE#139 (mở) | Chờ người khác | Quota ngày học viên 20 lượt đang hiệu lực, hoàn lượt khi lỗi (BE#185) | BE#139 |
| FR-AI-05 | AI#20 (mở) | Chờ người khác | Lọc phạm vi trước khi tìm có trong `rag-api` | AI#20, AI#33: chưa chạy test với PostgreSQL + pgvector thật |
| FR-AI-06 | BE#139 (mở) | Chờ người khác | BE#204 (chờ AI lâu hơn, đóng 15/11), BE#187 (chuẩn bị nguồn, đóng 15/11) | BE#139, BE#188, BE#206 |
| FR-COMPAT-01 | BE#137 (đóng 23/10) | Đã thử trên production / máy thật | Runtime 2.5.0 bật trên production 15/11; app chặn lệch runtime trước `Launch` (Mobile#12, Redmi 15/11) | |
| FR-BILLING-RECOVERY-01 | BE#138 (đóng 23/10) | Đã thử trên production / máy thật | B3 21/10 (mỗi order `Applied` đúng 1 lần) | Phần AI reserve/timeout thuộc BE#139 (mở) |
| FR-AI-RECOVERY-01 | BE#139 (mở) | Chờ người khác | BE#204 đóng 15/11 | BE#139, BE#206 |
| FR-PROCESS-02 | BE#132 (đóng 23/10) | Đã thử trên production / máy thật | BE#132: test với Postgres + Redis thật trong CI; worker trên máy ảo nhận việc có lease trên production (AI#23) | |
| FR-PROCESS-03 | BE#132 (đóng 23/10) | Có test tự động | BE#132 (`RedisRecoveryRepairTests`, job CI `processing-regression`) | |
| FR-PROCESS-04 | Unity#6 (đóng 16/11) | Có test tự động | Unity PR #143 (`43839c2`): EditMode 7/7, kiểm payload 6/6, chạy trọn với máy chủ giả 2 lần | Chưa chạy với BE thật |
| FR-TRAINING-RECOVERY-01 | Mobile#13 (đóng 15/11) | Đã thử trên production / máy thật | B2 21/10 bước 8 (khóa học viên/thu hồi bài khi đang chơi vẫn nhận event và complete) | Phía app trên điện thoại chưa thử (Mobile#13) |
| NFR-RECOVERY-02 | BE#132 (đóng 23/10) | Có test tự động | BE#132 (`RedisProcessingPostgresTests`, `IfcProcessingContractPostgresTests`, coverage 100% các lớp processing) | |

## 9 nhóm NFR

| Nhóm | Sở hữu | Trạng thái | Bằng chứng | Còn thiếu |
| :--- | :--- | :--- | :--- | :--- |
| Performance | Unity#12 (đóng 15/11) | Đã thử trên production / máy thật | Redmi: 04/11 từ ~2 lên 30 khung hình/giây; tháp 28 tầng 20–29 khung hình/giây; 15/11 bài trường học 30 khung hình/giây; vào bài tháp 56–65 giây (Unity#12) | Ngưỡng RAM/thời gian tải/kích thước gói/NPC chưa chốt, chưa có biên bản đo 15 phút (Docs#40) |
| Security | BE#141 (đóng 23/10) | Đã thử trên production / máy thật | B6 23/10; B1 21/10 (log không lộ bí mật) | Sau sự cố token GitHub 10–11/11 secret BE/Mobile đã thay (BE#203); chưa có lượt rà bảo mật lại sau đó |
| Integrity | BE#137 (đóng 23/10) | Đã thử trên production / máy thật | B2 (publish idempotent), B3 (cấp quyền đúng 1 lần), sha256 gói ghim trong Mobile (`unity-artifact.lock.json`) | |
| Privacy | BE#141 (đóng 23/10) | Đã thử trên production / máy thật | B6 23/10; B8 23/10 (CSV không có tên/email học viên, chặn chéo tổ chức) | Cô lập tenant ở kho vector chưa thử với DB thật (AI#20) |
| Availability | BE#142 (đóng 15/11) | Đã thử trên production / máy thật | BE#142: diễn tập khôi phục sao lưu 23/10 (130 migration, 34/34 tệp S3 khớp SHA-256), `/health/ready` | Hai mục chưa diễn tập trên môi trường thật (BE#142); AI#21 mở |
| Consistency | BE#139 (mở) | Chờ người khác | Test tự động có (BE#139 bình luận 31/10) | BE#139 |
| Failure-policy | BE#132 (đóng 23/10) | Có test tự động | BE#132 | |
| Compatibility | Mobile#52 (đóng 15/11) | Đã thử trên production / máy thật | Một máy Android thật (Redmi Note 10S); app cần Android 10 trở lên, chỉ `arm64-v8a` (Unity#4) | Chỉ một thiết bị; chưa rà xoay màn hình, cỡ chữ, trợ năng (Mobile#52) |
| Portability | AI#21 (mở) | Chờ người khác | Toolchain ghim (Unity#4), bản Unity ghim có sha256 (Mobile#22) | AI#21: chưa chạy eval thật, chưa có hướng dẫn triển khai AWS cho AI (AI#34) |

## Checklist bổ sung ngoài 89 mã

| Nghĩa vụ | Sở hữu | Trạng thái | Bằng chứng | Còn thiếu |
| :--- | :--- | :--- | :--- | :--- |
| Redis/event/cache | BE#132 (đóng 23/10) | Có test tự động | BE#132 (test Postgres + Redis thật trong CI) | Redis Streams đang tắt trên production (`PROCESSING_DISABLED`); TTL/retention/recovery window chưa chốt (overview, "Còn mở") |
| IFC fixtures và chất lượng chuyển đổi | AI#23 (đóng 15/11) | Chờ trưởng nhóm | Hai công trình nghiệm thu chuyển và chơi được (AI#23, IFC mục 10.1) | Bộ fixture đã đổi sang hai công trình; các kỳ vọng cũ (KIT 119 tường, Revit MEP, 100% UV0, ≥90% material mapping) chưa đo lại hoặc chưa được thay bằng ngưỡng mới (Docs#40 mở) |
| NavMesh/connectivity và preservation BIM | Unity#6 (đóng 16/11) | Chờ trưởng nhóm | README "Giới hạn đã biết": dùng lưới trong app (`GridRasterizer`), không NavMesh | Tiêu chí của dòng này đòi "quyết định có xác nhận"; hiện mới là kết quả rà Unity#6, chưa thấy trưởng nhóm chốt |
| Catalog runtime, context interaction và HUD | Unity#8 (đóng 15/11) | Đã thử trên production / máy thật | Runtime 2.1.0–2.5.0, `RescueActionsTests`, `Batch3RulesTests`, `TapInteractionTests`; chơi trên Redmi (Unity#8) | Ca "bẫy vẫn hiện nút" và chính sách Guided/Assessment chưa có test riêng |
| Bake/lighting và material library | Unity#6 (đóng 16/11) | Đã thử trên production / máy thật | Gói theo tầng dựng trên máy ảo, chơi trên Redmi; Unity#114 lọc vật nhỏ ở xa sau lỗi GPU 13/11 | |
| Quyết định thương mại/quota/rubric | Docs#10 (mở) | Chờ trưởng nhóm | Quyết định 16/11: giá/quota/Trial do PlatformAdmin đặt, không hoàn tiền, một IFC mỗi công trình (Docs#38, BE#103) | Còn mở: rubric mẫu khuyến nghị, Redis, OneShield, chi phí AWS/Azure |
| Asset và dataset licensing | Unity#56 (đóng 16/11 theo quyết định) | Bỏ / đổi theo quyết định | Quyết định 16/11: dự án học tập phi thương mại, không rà thêm; nguồn ghi ở `Unity/Assets/_Fire3D/Art/Characters/CREDITS.md`; hai tệp IFC là tệp thử nội bộ, không commit (Docs#40) | |
| UAT/user-study và hồ sơ bàn giao | Docs#41 (mở) | Chờ trưởng nhóm | `kich-ban-uat.md`, `huong-dan-hoc-vien.md`, `huong-dan-quan-tri.md`, `release-manifest.md` (Docs PR #103/#104) | Chưa có buổi UAT, phản hồi người dùng, biên bản ký; Docs#42 còn thiếu mục lục vận hành, danh sách biến cấu hình, người xác nhận bàn giao |

## Tổng hợp theo trạng thái

| Trạng thái | 89 mã | 9 NFR | 8 checklist | Tổng (106) |
| :--- | ---: | ---: | ---: | ---: |
| Đã thử trên production / máy thật | 47 | 6 | 2 | 55 |
| Có test tự động | 26 | 1 | 1 | 28 |
| Đã có trên main | 2 | 0 | 0 | 2 |
| Chờ người khác | 12 | 2 | 0 | 14 |
| Bỏ / đổi theo quyết định | 2 | 0 | 1 | 3 |
| Chờ trưởng nhóm | 0 | 0 | 4 | 4 |
| Chưa có | 0 | 0 | 0 | 0 |

Không có dòng nào ở trạng thái "Chưa có": với mọi yêu cầu còn hiệu lực đều tìm thấy mã trên `main` (đã grep các mục nghi thiếu: lọc nhiều tình huống, giảm giá, danh sách nhà cung cấp video, màn hỗ trợ trên app). Phần thiếu nằm ở mức bằng chứng, không nằm ở mã. Hai chỗ mã khác đặc tả (NavMesh, Blender) ghi ở mục dưới.

Tỷ lệ trên không phải % hoàn thành sản phẩm: "Đã thử trên production" thường chỉ phủ một phần yêu cầu, và chưa dòng nào được nghiệm thu.

## Yêu cầu mồ côi, issue trùng và điểm lệch

**Yêu cầu mồ côi**

1. **FR-WEB-07** (khách và Trainee không thuộc tòa nhà nào) có trong `fire_evacuation_requirements.md` nhưng không có trong ma trận 89 mã của Docs#37 (Docs có 90 mã). Phần mã tương ứng có test (`learn-public.spec.ts`, `learning-hub.spec.ts`, trang `/download`), nhưng chưa có issue sở hữu.
2. **FR-SCENARIO-02** và **FR-SCENARIO-05**: issue sở hữu Unity#55 (U1) và các issue phối hợp BE#144 (B9), FE#106 (F4) là việc gió, đã đóng vì bỏ gió. Phần còn hiệu lực của hai mã (trọng số định tuyến; nguồn lửa, khói, cửa, mục tiêu, thời lượng) không còn issue sở hữu đang hiệu lực.

**Issue trùng hoặc chồng việc**

- AI#33 (test kho vector với PostgreSQL + pgvector thật) trùng một phần AI#20 (A1).
- AI#35 (chạy eval với mô hình production và chốt ngưỡng) và AI#34 (hướng dẫn triển khai AWS) trùng một phần AI#21 (A2).
- BE#206 (thử lại đề xuất kịch bản thật) và BE#188 (kiểm hash nguồn) chồng với AI#22 (A3) và BE#139 (B4).
- FE#70 (E2E toàn bộ hành trình liên repo) chồng với Docs#41 (UAT ba vai trò); FE#70 đóng 15/11 mà không tick mục nào.
- Thông báo Android được theo dõi ở ba nơi: Mobile#9 (token FCM), Mobile#51 (đóng theo phạm vi), BE#140 (B5).
- Trùng tên nhãn dễ nhầm: "[F1]" FE#48 và "[Completion F1]" FE#103 (tương tự F2–F4), "[U1]" Unity#4 và "[Completion U1]" Unity#55, "[M1]" Mobile#9 và "[Completion M1]" Mobile#50, "[A1]" AI#2 và "[Completion A1]" AI#20. Ma trận này luôn ghi số issue để tránh nhầm.

Không tìm thấy chu kỳ phụ thuộc: Docs#42 phụ thuộc #37–#41, còn #37 ghi rõ tracker không chặn issue con.

**Tài liệu hoặc mã lệch nhau**

- **Gió:** FR-SCENARIO-05 đã ghi "Không có cấu hình gió (bỏ ngày 15/11/2026)", nhưng mã vẫn còn phần gió: BE `Fire3D.Application/Editor/EditorContract.cs` (contract `fet3d.editor/1` có `wind`), FE `features/scenario-editor/scene/palette.ts` và `scene-controller.ts`, Unity `Runtime/Contracts/ScenarioState.cs`, `Simulation/Building/HazardGrid.cs`, `Simulation/Hazards/HazardSystems.cs` (Unity#9: gió luôn bằng 0). Ma trận của Docs#37 vẫn trỏ dòng này tới U1/B9/F4.
- **NPC:** FR-TRAINING-05 ghi "số lượng NPC giới hạn … budget hiệu năng"; quyết định 16/11 là không giới hạn cứng (Unity#11).
- **NavMesh và Blender:** FR-IFC-02/FR-IFC-05 ghi worker tạo NavMesh và dùng Blender script; bản đang chạy dùng lưới trong app và worker Python IfcOpenShell trong `Unity/Tools/GeometryWorker`.
- **Bảng quyết định** trong overview ghi "Bộ IFC, Android mục tiêu và benchmark: Đã có", trong khi Docs#40 còn mở vì ngưỡng chưa chốt.
- `implementation-status.md` vẫn ghi đối chiếu ngày 21/10/2026. (`release-manifest.md` đã cập nhật theo `main` ngày 16/11/2026.)
- FE#70 bình luận 15/11 ghi FE#51, #52, #53, #54, #58, #61, #104 "đang mở", nhưng các issue này đã đóng cùng ngày.
- Một test FE đang đỏ: `tests/e2e/library-admin.spec.ts` dòng 408 (FE#54), chưa sửa.

## Quyết định và việc còn chặn mức 100%

Theo Docs#37, chỉ đánh dấu 100% khi toàn bộ baseline được nghiệm thu và tài liệu nhất quán. Những việc sau đang chặn:

1. **UAT ba vai trò và biên bản ký** (Docs#41): cần trưởng nhóm tổ chức; kịch bản đã có ở `kich-ban-uat.md`.
2. **Ngưỡng đo trên máy** (Docs#40): RAM, thời gian tải, kích thước gói, số NPC, dung sai exposure/replay, biên bản chơi đủ 15 phút.
3. **Bộ rubric mẫu khuyến nghị** (ngưỡng/trọng số theo loại bài): "Còn mở" trong overview.
4. **Redis** (nhà cung cấp, TTL, retention, recovery window), **OneShield** (gói, WAF, SLA) và **chi phí AWS/Azure**: "Còn mở" trong overview.
5. **Xác nhận dùng lưới trong app thay NavMesh** để đóng dòng checklist NavMesh và sửa FR-IFC-02/05.
6. **Sửa tài liệu cho nhất quán:** thêm FR-WEB-07 vào ma trận, sửa FR-TRAINING-05 theo quyết định NPC, gỡ hoặc ghi rõ phần gió còn trong mã, cập nhật `implementation-status.md` và `release-manifest.md`.
7. **Việc của BE/AI còn mở:** BE#139 (B4), BE#140 (B5), BE#188, BE#194 (cần migration xóa dữ liệu trên production, chờ người phụ trách BE), BE#206; AI#20, AI#21, AI#22, AI#33, AI#34, AI#35.
8. **Việc cần chủ tài khoản nhà cung cấp hoặc điện thoại:** đăng nhập Google trên bản cài từ Google Play (Mobile#9); email nhắc hạn qua Mailgun và push thật (BE#140).
9. **Google Play kênh chính thức:** bị từ chối tới khi đủ 12 người thử trong 14 ngày (yêu cầu của Google, ngoài phạm vi nhóm).
10. **Gói bằng chứng chung:** gần như mọi issue FE/Mobile/Unity đã đóng còn thiếu mục "Bằng chứng và điều kiện đóng" (bước thử, phiên bản sáu repo, log/ảnh môi trường thật). Các mục này dồn về UAT (Docs#41) và hồ sơ bàn giao (Docs#42).

## Những gì chưa kiểm được trong lần rà này

- Commit đang chạy thật trên máy chủ BE, AI và Vercel; phiên bản runtime đang bật trên trang quản trị production (lấy theo ghi chú của nhóm).
- Nội dung đầy đủ của bình luận nghiệm thu B6 (BE#141) và B8 (BE#143) sau bước 8; các dòng dựa vào hai issue này chỉ dẫn những bước đã đọc được.
- Không chạy lại bất kỳ test hay lượt thử nào; mọi trạng thái lấy từ bình luận issue, ghi chú bàn giao của nhóm và grep mã trên `main`.
