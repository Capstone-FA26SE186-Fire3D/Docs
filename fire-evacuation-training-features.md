# Fire Evacuation Training 3D — Tổng Hợp Tính Năng

**Đồng bộ auth BE 03/10/2026:** theo [authentication](../BE/docs/authentication.md) và [API guide](../BE/docs/api-docs.md), source BE main `0683d90`. Local registration dùng form → OTP → registrationToken → register → login; register trả account, chưa cấp JWT. Google UID đã link đăng nhập được; onboarding/link mới còn thiếu API hoàn tất. Các quy tắc đầy đủ và sơ đồ nằm tại [workflows mục 2.1–2.4](fire-evacuation-training-workflows.md#21-đăng-ký-local-form--otp--account--login). Source không chứng minh client/provider/deployment đã nghiệm thu.

**Đồng bộ thiết kế ngày 03/10/2026:** yêu cầu nghiệp vụ, SQL design v7, ERD Markdown và Word ý tưởng đã được đồng bộ. Tên bảng/function là contract thiết kế, không chứng minh migration/API/runtime đã triển khai. [Requirements](fire_evacuation_requirements.md) là nguồn yêu cầu sản phẩm; [ghi chú quyết định](phan_tich_khoang_cach_va_quyet_dinh_nghiep_vu.md) ghi lại lựa chọn và chi tiết còn mở.

> Đặc tả sản phẩm cho đồ án FET3D. Toàn bộ nhóm năng lực dưới đây thuộc mục tiêu bản cuối; phase chỉ dùng để sắp xếp triển khai.

## 1. Định vị sản phẩm

FET3D biến mô hình **IFC** của một Building thành content package Unity dùng cho tập huấn sơ tán 3D trên Android. Người học cài ứng dụng một lần, đăng nhập và quét QR canonical của Building để xem danh sách bài đã publish, chọn một bài và tải package còn thiếu. Package đã xác minh được Unity dùng để chạy scenario, ghi nhận quyết định và trả result về React Native/Expo qua native Android bridge.

Mỗi Building có QR canonical để mở danh sách training của tòa nhà. Three.js được dùng cho landing và editor/preview 3D của organization; gameplay BIM 3D/2.5D đầy đủ chạy trong Unity của Mobile. Landing và Learn là nội dung web công khai; không có guest account hoặc guest training không định danh. Xem [đặc tả UX web](fire3d-web-ux-design.md) để biết storyboard POV, editor, nhận diện, motion và hai hướng nhu cầu.

Luồng cốt lõi: **IFC → 3D → Unity Android → QR → Training → Result**.

Giá trị cốt lõi là giúp người học làm quen với không gian đã được mô hình hóa, thử quyết định route trong hazard surrogate và nhận debrief sau buổi tập huấn. FET3D không thay thế biển báo, quy trình ứng phó khẩn cấp, tư vấn chuyên môn hoặc hoạt động PCCC thực tế.

## 2. Ba loại tài khoản

| Tài khoản | Phạm vi |
| :--- | :--- |
| `PlatformAdmin` | Quản lý nền tảng, thư viện hỗ trợ Organization, Learn công khai, gói/quota; duyệt mọi phiên bản kịch bản/rubric. |
| `OrganizationUser` | Sở hữu Building, IFC, scenario, publish, QR, analytics và billing cho organization. |
| `Trainee` | Quét QR Building, chọn bài đã publish trong app Android và chỉ xem dữ liệu buổi tập huấn của chính mình. |

Building public cho mọi Trainee đã đăng nhập tham gia; Building private yêu cầu thêm mã tham gia chung do Organization cung cấp. Mã không tạo role, membership hoặc quyền đọc tài liệu nội bộ. Xác minh mã tạo grant theo tài khoản ở `access_revision` hiện tại; đổi/thu hồi mã hoặc đổi public/private làm grant cũ mất hiệu lực. QR chỉ resolve Building, không thay kiểm tra quyền. Backend kiểm tra quyền trước khi trả bài/package private và kiểm tra lại ở online start.

## 3. Năng lực của OrganizationUser

**Thư viện hỗ trợ Organization** gồm template kịch bản tùy chọn, bộ tiêu chí chấm mẫu và danh mục thiết bị game đã được runtime hỗ trợ. PlatformAdmin duy trì các nội dung chuẩn; OrganizationUser dùng để soạn/cấu hình bài trong khu quản lý đã đăng nhập. Thư viện này tách khỏi **Learn công khai** trên web: bài viết, mẹo và video cho mọi người đọc không cần đăng nhập; lưu bài/hỏi AI cần đăng nhập. Learn giữ quy trình biên tập hiện tại và không có bước duyệt bài riêng. Mode Learn trong Unity là trải nghiệm làm quen không gian, không phải blog. IFC, mô hình và kịch bản riêng của Organization không tự được chia sẻ vào thư viện.

Organization tự soạn hoặc dùng template tùy chọn, có thể kết hợp mục tiêu sơ tán, nhận biết nguy cơ, dùng thiết bị và hỗ trợ người khác trong capability runtime. Admin cung cấp tiêu chí mẫu; Organization điều chỉnh rồi gửi duyệt cùng kịch bản. PlatformAdmin duyệt mọi phiên bản trước phát hành hoặc từ chối kèm lý do. Sửa nội dung/rubric phải tạo phiên bản mới và gửi duyệt lại. IFC QA/ConfirmForTraining là readiness kỹ thuật, không thay bước duyệt nội dung; release chỉ publish khi cả hai đạt. Phiên và kết quả cũ giữ phiên bản đã pin.

### 3.1. Building và IFC

- Tạo Building, quản lý revision và tải source IFC.
- Theo dõi worker parse IFC, geometry runtime, hierarchy tầng, door/stair/exit, connectivity QA và log lỗi.
- Pipeline dùng Python/IfcOpenShell/IfcConvert, Blender script và Unity build worker để tạo GLB/metadata, mô hình nhẹ, collider, NavMesh và package; đây là pipeline dùng chung, không dựng thủ công từng Building.
- Xem preview 3D/editor, issue list và metadata của revision trước khi đưa vào scenario. Nếu IFC thiếu đơn vị, tầng, cửa, cầu thang hoặc lối thoát, hệ thống tạo issue để người dùng sửa/xác nhận.
- Chỉ source IFC hợp lệ mới có thể tạo package; raw IFC không được đưa xuống ứng dụng Android.

### 3.2. Scenario và ConfirmForTraining

- Tạo version scenario với spawn, mục tiêu, hazard surrogate, time limit, rubric và cấu hình risk-aware A*.
- Trên editor Three.js, chọn tầng, xoay/zoom/ẩn lớp, đặt và chỉnh nguồn lửa, tốc độ cháy, khói, hướng/cường độ gió, cửa/vùng chặn, bình chữa cháy, khăn, nguồn nước và các vật phẩm runtime đã hỗ trợ.
- Lưu draft, undo/redo, validation và version scenario riêng với geometry. Đổi tham số scenario không convert lại toàn bộ IFC; đổi IFC tạo revision mới.
- Preview web chỉ minh họa timeline/hiệu ứng; chạy thử đầy đủ hành vi, route và scoring bằng app Unity của organization.
- Chạy checklist readiness: candidate package/manifest, graph, route kiểm tra và scenario; QR chưa tồn tại ở bước này.
- Revision đạt IFC/connectivity QA ở ReadyForScenario; mọi scenario/rubric version còn phải được PlatformAdmin duyệt nội dung trước phát hành; OrganizationUser có thể tạo nhiều logical Scenario và version trên cùng geometry. `ConfirmForTraining` được persist cho đúng cặp revision/version và không khóa scenario khác.
- OrganizationUser có thể chạy thử draft/version riêng trên Mobile/Unity trong hạn mức Admin cấu hình. Playtest phải thuộc đúng tenant, không mở qua QR Trainee và không tính learner analytics.

`ConfirmForTraining` là nhãn readiness nội bộ. Nó không tuyên bố Building, lối thoát, scenario hay kết quả mô phỏng đã được chứng nhận, phê duyệt hoặc kiểm định về PCCC.

### 3.3. Publish, QR và analytics

- Sau `ConfirmedForTraining`, tạo release `Built`, package và `Training` khớp revision/scenario/organization; publish còn yêu cầu đúng phiên bản/rubric được PlatformAdmin duyệt và chỉ khi package có checksum/manifest/runtime tương thích, validation đạt, không còn issue Error/Critical mở và `Training` active đã tồn tại.
- Sau publish, tạo, in và rotate QR canonical ở cấp Building. QR resolve trạng thái Building; public cần đăng nhập, private cần mã/quyền trước danh sách Training/package; khi Trainee chọn bài, session mới pin đúng `trainingId`, `releaseId` và `scenarioVersionId`.
- Publish chỉ được phép khi Building còn gói 6/12 tháng hợp lệ. Hết hạn khóa publish và session mới; QR vẫn mở landing/trang trạng thái để đăng nhập, tải app hoặc gia hạn.
- Xem analytics cơ bản và expanded analytics cho Building/scenario thuộc organization theo thứ tự rollout; tách learner plays, playtest, Trainee unique và active sessions ước tính từ heartbeat.
- Xem quotation, transaction, invoice metadata, entitlement và revenue theo quyền billing.

## 4. Trải nghiệm Trainee

1. Chưa cài app: quét QR mở web, đăng nhập/đăng ký email/password hoặc Google và hướng dẫn tải app; sau khi cài có thể quét lại QR.
2. Đã cài nhưng chưa đăng nhập: app dùng phiên local email/password hoặc Google Sign-In qua Firebase.
3. Đã đăng nhập: tòa public tham gia trực tiếp, private nhập mã chung; app chỉ trả bài/package được phép rồi cho chọn mode.
4. App tải phần package còn thiếu, verify hash/schema/runtime và tạo session preparation; `POST /api/training/sessions/{sessionId}/start` mới kiểm tra quyền public/private, dịch vụ Building/QR và suất người online và cấp launch grant để mở Unity qua native Android bridge.
5. Người học hoàn thành Learn, Guided Drill hoặc Assessment; Unity trả event/result qua bridge để Mobile đồng bộ backend.
6. Người học hỏi AI trên web/Mobile ngoài gameplay và xem debrief của chính mình.

Mọi session mới phải kiểm tra online ở bước start, kể cả package đã cache; không hỗ trợ start offline. Nếu mất mạng hoặc dịch vụ hết hạn sau khi session bắt đầu, Unity tiếp tục chạy, Mobile lưu event/result local và đồng bộ lại khi có mạng.

### 4.1. Cổng web và hai nhu cầu

- Khách có thể khám phá dự án, đọc/tìm Learn và xem cách tham gia tập huấn mà không cần tài khoản.
- Landing mở bằng hành trình góc nhìn thứ nhất cuộn qua công trình đang cháy. Cuối hành trình, **Tôi muốn tập huấn** dẫn tới cảnh thu vào điện thoại rồi đăng nhập/Góc học tập; **Tôi muốn tổ chức tập huấn** dẫn tới mặt cắt tòa nhà và trang Dành cho tổ chức.
- Góc học tập của Trainee đã đăng nhập gồm hỏi AI, bài đã lưu, lịch sử và kết quả cá nhân. Hỏi AI, hỏi về bài đang đọc và lưu bài yêu cầu đăng nhập.
- Trang Dành cho tổ chức công khai giải thích năng lực sản phẩm; thao tác quản lý Building, IFC, scenario, publish, QR, analytics và billing vẫn yêu cầu `OrganizationUser` đúng ownership.
- Learn web (blog kiến thức cộng đồng có nguồn) là luồng riêng với mode Learn trong Unity (làm quen không gian/runtime). Learn web là thiết kế mục tiêu; prototype hiện có chưa chứng minh CMS, video provider hoặc indexing production.

## 5. Nội dung training

### 5.1. Learn

Learn web là thư viện bài viết, tip & trick và video PCCC theo tình huống để mọi người đọc/xem công khai.

- `PlatformAdmin` tạo và chỉnh sửa draft; có thể lưu nháp, phát hành ngay, hoặc ẩn/hiện bài đã phát hành. Không có bước duyệt riêng của Learn; audit lưu actor, thời điểm và phiên bản.
- Bài có loại `Article`, `Tip` hoặc `Video`, tiêu đề, tóm tắt, ảnh, content blocks, nguồn và một hoặc nhiều tình huống. Tình huống chỉ là danh mục nội dung, không phải scenario Unity.
- Video YouTube, Facebook Video và TikTok được nhập bằng URL chuẩn hóa; backend chỉ cho provider allowlist và renderer chính thức. URL private, bị xóa hoặc không hỗ trợ embed phải có fallback link/mô tả.
- Bản phát hành bất biến. Chỉnh sửa tạo version mới; public API/cache chỉ trả version đang Published. Không có lesson bắt buộc, quiz, chứng chỉ hoặc bảng tiến độ khóa học trong thiết kế này.
- Khách được tìm/đọc bài Published; bài Hidden/Unpublished/Deleted không xuất hiện công khai. Trainee đăng nhập để lưu bookmark và hỏi AI về đúng bài/version. Hidden vẫn có thể là nguồn RAG khi pointer/version và nguồn Common hợp lệ; Deleted bị loại ngay cả khi cache/index cũ còn tham chiếu.

### 5.1.1. Tài khoản và hồ sơ

- Trainee đăng ký bằng email/username/password/confirm password; username được BE chuẩn hóa lowercase và unique không phân biệt hoa thường. OrganizationUser đăng ký email/password/confirm password cùng tên, địa chỉ và số điện thoại tổ chức; username cá nhân có thể bổ sung sau. Confirm password không được lưu.
- Local registration nhập form → OTP → proof → register → login; OTP chưa tạo account, register trả 201 account verified và chưa cấp JWT. Google UID đã link đăng nhập theo role/tenant cũ; identity mới trả OnboardingRequired, email local trùng trả 409 ACCOUNT_LINK_REQUIRED. Onboarding chọn Trainee/OrganizationUser và explicit link còn thiếu API hoàn tất. Game start không hỏi username.
- Hồ sơ cho phép đổi username, tên hiển thị, mật khẩu và avatar; OrganizationUser có thể cập nhật tên/địa chỉ/điện thoại tổ chức. Không cho đổi role, tenant, email đăng nhập hoặc trạng thái qua profile API.
- Avatar dùng private S3 object key do backend cấp upload intent; API tạo signed URL ngắn hạn để đọc. Firebase chỉ dùng Google Sign-In, FCM chỉ dùng push và Mailgun gửi OTP đăng ký và reset password.

Mode Learn trong Unity vẫn là trải nghiệm tự do quan sát không gian và route đã mô hình hóa; nó không dùng kết quả như thước đo an toàn thực tế.

### 5.2. Guided Drill

- Có hazard surrogate theo scenario và gợi ý route risk-aware.
- Ghi route choice, thời lượng, modeled exposure và các lần re-plan.
- Phục vụ luyện tập và so sánh trong đánh giá đồ án.

### 5.3. Assessment

Trainee tự chọn đọc Learn/blog, Learn trong Unity, Guided Drill hoặc vào Assessment ngay; không có prerequisite học/luyện. Assessment giảm/tắt gợi ý, chấm đạt/chưa đạt theo rubric đã duyệt và trả lý do/debrief. Lưu từng lần làm; thi lại không giới hạn và không bắt buộc luyện lại. Hoàn thành session không tự đồng nghĩa đạt; lỗi, hủy và chưa sync phải phân biệt với kết quả hợp lệ. Không cấp chứng nhận, không curriculum/module/sprint. Tiêu chí bắt buộc/tùy chọn, trọng số, ngưỡng điểm và lỗi khiến chưa đạt cần chốt theo từng loại bài, chưa hard-code con số.


- Scenario cố định, giảm hoặc tắt gợi ý theo rubric.
- Result/debrief chỉ xuất hiện sau khi nộp bài theo policy đã cấu hình.
- Điểm là dữ liệu học tập trong mô phỏng, không là năng lực hay chứng nhận PCCC.

## 6. Năng lực bản cuối và thứ tự triển khai

| Nhóm | Tính năng |
| :--- | :--- |
| Authoring | Building, IFC pipeline, geometry/connectivity QA, preview/editor 3D, revision và scenario. |
| Readiness/release | ConfirmForTraining kỹ thuật, Admin duyệt phiên bản/rubric, payment dịch vụ, publish, manifest, package versioning và QR Building/list bài. |
| Runtime | React Native/Expo shell, native Android Unity bridge, Unity library, lửa/khói/gió/cháy lan, tương tác, hazard surrogate, risk-aware A*, online start và sync sau mất mạng. |
| AI | RAG hướng dẫn organization, tạo scenario draft có nguồn, AI Trainee có quota ngày và debrief ngoài game. |
| Billing/operations | Gói Building 6/12 tháng, hạn mức người/kỳ, nâng cấp gói, PayOS và mua quota AI trả trước. |
| Dữ liệu | session, result, audit, analytics người duy nhất/lượt chơi/active session và usage billing. |

Thứ tự triển khai có thể chia thành các đợt kỹ thuật; các tính năng trên là mục tiêu bản cuối. Session offline launch không được hỗ trợ, nhưng mất mạng giữa session phải được xử lý.

## 7. AI, payment và thư viện hành vi

| Nhóm | Tính năng |
| :--- | :--- |
| AI organization | Hỏi đáp có nguồn, giải thích IFC/PCCC, draft scenario ở trạng thái `NeedsUserEdit`; người dùng tự edit và xác nhận. |
| AI Trainee | Hỏi đáp kiến thức, mục tiêu/hướng dẫn của bài đã duyệt/phát hành có quyền chơi và kết quả cá nhân trên web/Mobile ngoài game; quota ngày riêng. |
| Billing | Gói 6/12 tháng từng Building gồm phí game, hạn mức người và quota; quota AI cộng chung Organization, hết mua thêm trước. |
| Runtime library | Hành vi di chuyển, camera, collider, cửa, vật phẩm, bình chữa cháy, khăn/nước theo rule đã kiểm tra, lửa/khói/gió/cháy lan và chấm điểm. Tác dụng khăn/nước/che mũi/khu vệ sinh không mặc định là đúng; phải có nội dung được duyệt. |
| Vận hành | feedback/support, expanded analytics, filter/cohort/export và debrief aggregate. |

Chủ tòa chọn/cấu hình hành vi đã có; không viết script Unity cho từng Building. Hiệu ứng hiển thị và trạng thái mô phỏng dùng cùng scenario state. Gió/khói là mô hình game, không phải mô phỏng CFD. Basic NPC chỉ là tác nhân mô phỏng; không đại diện cho hành vi con người thật. Expanded analytics chỉ dùng để xem hoạt động học tập/mô phỏng.

PayOS request chỉ được tạo `Pending` qua function-only executor. Trusted webhook adapter xác thực `req.body` bằng SDK `webhooks.verify` hoặc canonicalize `data` theo thứ tự alphabet trước khi gọi database; database chỉ ghi attestation và đối soát, còn `returnUrl` không thể ghi `Paid`. Giá, quota, usage và quyền publish do backend quyết định; retry/webhook trùng không tạo usage hoặc quyền trùng.

Gói từng Building có thời hạn 6 hoặc 12 tháng, gộp phí game, hạn mức người và quota AI. Hạn mức đếm Trainee khác nhau theo mã tài khoản đã start game tại Building trong kỳ; đăng nhập, xem bài, preparation và Organization playtest không tính suất. Chơi lại/nhiều kịch bản cùng tòa trong kỳ chỉ một suất; tòa khác tính riêng. Hết suất chặn người mới, người đã tính suất vẫn chơi lại trong quyền/dịch vụ còn hợp lệ; Organization nâng cấp gói nhiều người hơn. Kỳ gia hạn mới tính hạn mức theo kỳ mới. Giá, các mức người và cách tính nâng cấp giữa kỳ chưa chốt.

Quota AI đi kèm các Building cộng chung cho Organization; hết quota phải mua thêm và thanh toán trước khi tiếp tục dùng AI tính phí. Không tự cho dùng vượt quota rồi đối soát cuối kỳ. Trainee giữ quota ngày miễn phí riêng, không trừ quỹ Organization. Đơn vị/lượng quota, hiệu lực và xử lý quota còn dư chưa chốt. Reserve/settle và retry phải chống trừ/cấp quota trùng; timeout reconcile bằng request ID trước khi hoàn hoặc gọi lại.

## 8. Analytics và debrief

Analytics cơ bản hiển thị `Trainee unique` (Trainee khác nhau có session đã bắt đầu), `Learner plays` (session Trainee đã bắt đầu), `Active sessions` (heartbeat trong cửa sổ cấu hình), completion và duration. Completion rate = session hoàn tất / session đã bắt đầu; duration chỉ tính timestamp hợp lệ. Preparation/playtest không tính learner analytics, session chưa đồng bộ ghi riêng và chưa tính hoàn thành tới khi backend xác nhận. Expanded analytics bổ sung xu hướng theo thời gian, filter Building/scenario, cohort comparison, export và debrief aggregate.

`Trainee` chỉ xem kết quả của chính mình. `OrganizationUser` chỉ xem aggregate và dữ liệu thuộc organization. Heatmap, route tham chiếu hoặc analytics không được gọi là bằng chứng tuân thủ, chứng nhận hoặc xác nhận PCCC.

## 9. Đánh giá đồ án và giới hạn

Đánh giá chuyên môn, usability session và user study là các hoạt động của capstone để nhận phản hồi về độ rõ ràng, khả năng sử dụng, hiệu năng và trải nghiệm training. Các hoạt động này không xuất hiện như loại tài khoản hoặc quyền hệ thống.

Mô hình hazard dùng surrogate nhẹ, deterministic theo scenario và có giới hạn rõ ràng. Khi demo, tài liệu và giao diện phải nêu rằng kết quả chỉ phù hợp với phạm vi mô phỏng/tập huấn của đồ án.

### 9.1. Tính bất biến và retry

- Package/artifact đã publish hoặc đã được phiên pin không được thay tại chỗ; thay nội dung tạo release/package mới.
- Payment mua quota AI và nâng cấp hạn mức xử lý idempotent; snapshot giá/điều khoản/quota đã mua bất biến. Không tự dùng overage trả sau; lifecycle period/adjustment trong SQL cũ cần đồng bộ riêng.
- Worker/AI retry dùng idempotency và provenance; retry stale hoặc khác input không được tạo charge, artifact, publication hay analytics trùng.

### 9.2. Event, cache và phục hồi

- Thay đổi nghiệp vụ được commit cùng `integration_outbox_events` trong PostgreSQL. Dispatcher giao event/job qua Redis Streams; consumer hoặc worker ghi tác động bền vững về PostgreSQL rồi mới ACK.
- Tenant enqueue hiện chỉ nhận `ProcessingJobRequested` schema `1`; system event dùng allowlist riêng; `ProcessingJobRequeue` chỉ được tạo qua gate requeue. Event cùng key và envelope được xử lý idempotent; envelope khác bị từ chối.
- Redis cache-aside chỉ tối ưu catalog, package metadata, danh sách bài và dashboard. Quyền start/publish, entitlement, revoke QR, quota, billing và learner result vẫn kiểm tra PostgreSQL/backend.
- Redis mất dữ liệu, message lặp, dispatcher mất ACK hoặc worker crash phải replay/retry từ outbox và job attempt mà không tạo tác động nghiệp vụ trùng. Cache lỗi hoặc cũ không được cấp quyền sai tenant.
- FE/Mobile chỉ gọi API qua OneShield/OnePortal → Nginx/.NET; không kết nối Redis trực tiếp. Session đã bắt đầu vẫn giữ event/result local khi mất mạng và đồng bộ lại sau khi backend xác nhận.
