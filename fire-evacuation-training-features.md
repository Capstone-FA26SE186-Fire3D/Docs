# Fire Evacuation Training 3D — Tổng Hợp Tính Năng

> Đặc tả sản phẩm cho đồ án FET3D. Toàn bộ nhóm năng lực dưới đây thuộc mục tiêu bản cuối; phase chỉ dùng để sắp xếp triển khai.

## 1. Định vị sản phẩm

FET3D biến mô hình **IFC** của một Building thành content package Unity dùng cho tập huấn sơ tán 3D trên Android. Người học cài ứng dụng một lần, đăng nhập và quét QR canonical của Building để xem danh sách bài đã publish, chọn một bài và tải package còn thiếu. Package đã xác minh được Unity dùng để chạy scenario, ghi nhận quyết định và trả result về React Native/Expo qua native Android bridge.

Mỗi Building có QR canonical để mở danh sách training của tòa nhà. Three.js được dùng cho landing và editor/preview 3D của organization; gameplay BIM 3D/2.5D đầy đủ chạy trong Unity của Mobile. Landing và Learn là nội dung web công khai; không có guest account hoặc guest training không định danh. Xem [đặc tả UX web](fire3d-web-ux-design.md) để biết storyboard POV, editor, nhận diện, motion và hai hướng nhu cầu.

Luồng cốt lõi: **IFC → 3D → Unity Android → QR → Training → Result**.

Giá trị cốt lõi là giúp người học làm quen với không gian đã được mô hình hóa, thử quyết định route trong hazard surrogate và nhận debrief sau buổi tập huấn. FET3D không thay thế biển báo, quy trình ứng phó khẩn cấp, tư vấn chuyên môn hoặc hoạt động PCCC thực tế.

## 2. Ba loại tài khoản

| Tài khoản | Phạm vi |
| :--- | :--- |
| `PlatformAdmin` | Quản lý nền tảng, organization, tài khoản, giám sát và support ở cấp nền tảng. |
| `OrganizationUser` | Sở hữu Building, IFC, scenario, publish, QR, analytics và billing cho organization. |
| `Trainee` | Quét QR Building, chọn bài đã publish trong app Android và chỉ xem dữ liệu buổi tập huấn của chính mình. |

Mô hình quyền không dùng cơ chế thành viên, lời mời, truy cập khách hoặc tập huấn không định danh. `organizationId` giới hạn ownership của Building, authoring, analytics và billing; nó không là điều kiện QR participation của `Trainee` đã xác thực.

## 3. Năng lực của OrganizationUser

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
- Revision đạt IFC/connectivity QA ở `ReadyForScenario`; OrganizationUser có thể tạo nhiều logical Scenario và version trên cùng geometry. `ConfirmForTraining` được persist cho đúng cặp revision/version và không khóa scenario khác.
- OrganizationUser có thể chạy thử draft/version riêng trên Mobile/Unity trong hạn mức Admin cấu hình. Playtest phải thuộc đúng tenant, không mở qua QR Trainee và không tính learner analytics.

`ConfirmForTraining` là nhãn readiness nội bộ. Nó không tuyên bố Building, lối thoát, scenario hay kết quả mô phỏng đã được chứng nhận, phê duyệt hoặc kiểm định về PCCC.

### 3.3. Publish, QR và analytics

- Sau `ConfirmedForTraining`, tạo release `Built`, package và `Training` khớp revision/scenario/organization; publish chỉ khi package có checksum/manifest/runtime tương thích, validation đạt, không còn issue Error/Critical mở và `Training` active đã tồn tại.
- Sau publish, tạo, in và rotate QR canonical ở cấp Building. QR resolve danh sách `Training`/release đã publish; khi Trainee chọn bài, session mới pin đúng `trainingId`, `releaseId` và `scenarioVersionId`.
- Publish chỉ được phép khi Building còn dịch vụ tháng hợp lệ. Hết hạn khóa publish và session mới; QR vẫn mở landing/trang trạng thái để đăng nhập, tải app hoặc gia hạn.
- Xem analytics cơ bản và expanded analytics cho Building/scenario thuộc organization theo thứ tự rollout; tách learner plays, playtest, Trainee unique và active sessions ước tính từ heartbeat.
- Xem quotation, transaction, invoice metadata, entitlement và revenue theo quyền billing.

## 4. Trải nghiệm Trainee

1. Chưa cài app: quét QR mở web, đăng nhập/đăng ký Google và hướng dẫn tải app; sau khi cài có thể quét lại QR.
2. Đã cài nhưng chưa đăng nhập: app yêu cầu Google Sign-In.
3. Đã đăng nhập: app resolve Building, hiển thị danh sách bài đã publish và cho chọn mode.
4. App tải phần package còn thiếu, verify hash/schema/runtime và tạo session preparation; `POST /api/training/sessions/{sessionId}/start` mới kiểm tra dịch vụ Building/QR online và cấp launch grant để mở Unity qua native Android bridge.
5. Người học hoàn thành Learn, Guided Drill hoặc Assessment; Unity trả event/result qua bridge để Mobile đồng bộ backend.
6. Người học hỏi AI trên web/Mobile ngoài gameplay và xem debrief của chính mình.

Mọi session mới phải kiểm tra online ở bước start, kể cả package đã cache; không hỗ trợ start offline. Nếu mất mạng hoặc dịch vụ hết hạn sau khi session bắt đầu, Unity tiếp tục chạy, Mobile lưu event/result local và đồng bộ lại khi có mạng.

### 4.1. Cổng web và hai nhu cầu

- Khách có thể khám phá dự án, đọc/tìm Learn và xem cách tham gia tập huấn mà không cần tài khoản.
- Landing mở bằng hành trình góc nhìn thứ nhất cuộn qua công trình đang cháy. Cuối hành trình, **Tôi muốn tập huấn** dẫn tới cảnh thu vào điện thoại rồi đăng nhập/Góc học tập; **Tôi muốn tổ chức tập huấn** dẫn tới mặt cắt tòa nhà và trang Dành cho tổ chức.
- Góc học tập của Trainee đã đăng nhập gồm hỏi AI, bài đã lưu, lịch sử và kết quả cá nhân. Hỏi AI, hỏi về bài đang đọc và lưu bài yêu cầu đăng nhập.
- Trang Dành cho tổ chức công khai giải thích năng lực sản phẩm; thao tác quản lý Building, IFC, scenario, publish, QR, analytics và billing vẫn yêu cầu `OrganizationUser` đúng ownership.
- Learn web (kiến thức cộng đồng có nguồn) là luồng riêng với mode Learn trong Unity (làm quen không gian/runtime); cổng web và AI cộng đồng là phần mở rộng cần bổ sung vào đặc tả, chưa coi là đã triển khai.

## 5. Nội dung training

### 5.1. Learn

- Tự do quan sát không gian và route đã mô hình hóa.
- Có highlight và gợi ý route để làm quen.
- Không dùng kết quả như thước đo an toàn thực tế.

### 5.2. Guided Drill

- Có hazard surrogate theo scenario và gợi ý route risk-aware.
- Ghi route choice, thời lượng, modeled exposure và các lần re-plan.
- Phục vụ luyện tập và so sánh trong đánh giá đồ án.

### 5.3. Assessment

- Scenario cố định, giảm hoặc tắt gợi ý theo rubric.
- Result/debrief chỉ xuất hiện sau khi nộp bài theo policy đã cấu hình.
- Điểm là dữ liệu học tập trong mô phỏng, không là năng lực hay chứng nhận PCCC.

## 6. Năng lực bản cuối và thứ tự triển khai

| Nhóm | Tính năng |
| :--- | :--- |
| Authoring | Building, IFC pipeline, geometry/connectivity QA, preview/editor 3D, revision và scenario. |
| Readiness/release | `ConfirmForTraining`, payment dịch vụ, publish, manifest, package versioning và QR Building/list bài. |
| Runtime | React Native/Expo shell, native Android Unity bridge, Unity library, lửa/khói/gió/cháy lan, tương tác, hazard surrogate, risk-aware A*, online start và sync sau mất mạng. |
| AI | RAG hướng dẫn organization, tạo scenario draft có nguồn, AI Trainee có quota ngày và debrief ngoài game. |
| Billing/operations | Gói theo Building/tháng, PayOS, usage AI cuối kỳ, dashboard account/service/usage và audit. |
| Dữ liệu | session, result, audit, analytics người duy nhất/lượt chơi/active session và usage billing. |

Thứ tự triển khai có thể chia thành các đợt kỹ thuật; các tính năng trên là mục tiêu bản cuối. Session offline launch không được hỗ trợ, nhưng mất mạng giữa session phải được xử lý.

## 7. AI, payment và thư viện hành vi

| Nhóm | Tính năng |
| :--- | :--- |
| AI organization | Hỏi đáp có nguồn, giải thích IFC/PCCC, draft scenario ở trạng thái `NeedsUserEdit`; người dùng tự edit và xác nhận. |
| AI Trainee | Hỏi đáp kiến thức/bài học và giải thích kết quả cá nhân trên web/Mobile ngoài game; quota ngày riêng. |
| Billing | Dịch vụ từng Building theo tháng; quota AI dùng chung organization; usage vượt mức thông báo và đối soát cuối kỳ. |
| Runtime library | Hành vi di chuyển, camera, collider, cửa, vật phẩm, bình chữa cháy, khăn/nước theo rule đã kiểm tra, lửa/khói/gió/cháy lan và chấm điểm. Tác dụng khăn/nước/che mũi/khu vệ sinh không mặc định là đúng; phải có nội dung được duyệt. |
| Vận hành | feedback/support, expanded analytics, filter/cohort/export và debrief aggregate. |

Chủ tòa chọn/cấu hình hành vi đã có; không viết script Unity cho từng Building. Hiệu ứng hiển thị và trạng thái mô phỏng dùng cùng scenario state. Gió/khói là mô hình game, không phải mô phỏng CFD. Basic NPC chỉ là tác nhân mô phỏng; không đại diện cho hành vi con người thật. Expanded analytics chỉ dùng để xem hoạt động học tập/mô phỏng.

PayOS request chỉ được tạo `Pending` qua function-only executor. Trusted webhook adapter xác thực `req.body` bằng SDK `webhooks.verify` hoặc canonicalize `data` theo thứ tự alphabet trước khi gọi database; database chỉ ghi attestation và đối soát, còn `returnUrl` không thể ghi `Paid`. Giá, quota, usage và quyền publish do backend quyết định; retry/webhook trùng không tạo usage hoặc quyền trùng.

## 8. Analytics và debrief

Analytics cơ bản hiển thị `Trainee unique` (Trainee khác nhau có session đã bắt đầu), `Learner plays` (session Trainee đã bắt đầu), `Active sessions` (heartbeat trong cửa sổ cấu hình), completion và duration. Completion rate = session hoàn tất / session đã bắt đầu; duration chỉ tính timestamp hợp lệ. Preparation/playtest không tính learner analytics, session chưa đồng bộ ghi riêng và chưa tính hoàn thành tới khi backend xác nhận. Expanded analytics bổ sung xu hướng theo thời gian, filter Building/scenario, cohort comparison, export và debrief aggregate.

`Trainee` chỉ xem kết quả của chính mình. `OrganizationUser` chỉ xem aggregate và dữ liệu thuộc organization. Heatmap, route tham chiếu hoặc analytics không được gọi là bằng chứng tuân thủ, chứng nhận hoặc xác nhận PCCC.

## 9. Đánh giá đồ án và giới hạn

Đánh giá chuyên môn, usability session và user study là các hoạt động của capstone để nhận phản hồi về độ rõ ràng, khả năng sử dụng, hiệu năng và trải nghiệm training. Các hoạt động này không xuất hiện như loại tài khoản hoặc quyền hệ thống.

Mô hình hazard dùng surrogate nhẹ, deterministic theo scenario và có giới hạn rõ ràng. Khi demo, tài liệu và giao diện phải nêu rằng kết quả chỉ phù hợp với phạm vi mô phỏng/tập huấn của đồ án.

### 9.1. Tính bất biến và retry

- Package/artifact đã publish hoặc đã được phiên pin không được thay tại chỗ; thay nội dung tạo release/package mới.
- Đóng kỳ AI tạo snapshot item bất biến; điều chỉnh late/uncertain usage dùng adjustment riêng và không tính lại theo policy mới.
- Worker/AI retry dùng idempotency và provenance; retry stale hoặc khác input không được tạo charge, artifact, publication hay analytics trùng.

### 9.2. Event, cache và phục hồi

- Thay đổi nghiệp vụ được commit cùng `integration_outbox_events` trong PostgreSQL. Dispatcher giao event/job qua Redis Streams; consumer hoặc worker ghi tác động bền vững về PostgreSQL rồi mới ACK.
- Tenant enqueue hiện chỉ nhận `ProcessingJobRequested` schema `1`; system event dùng allowlist riêng; `ProcessingJobRequeue` chỉ được tạo qua gate requeue. Event cùng key và envelope được xử lý idempotent; envelope khác bị từ chối.
- Redis cache-aside chỉ tối ưu catalog, package metadata, danh sách bài và dashboard. Quyền start/publish, entitlement, revoke QR, quota, billing và learner result vẫn kiểm tra PostgreSQL/backend.
- Redis mất dữ liệu, message lặp, dispatcher mất ACK hoặc worker crash phải replay/retry từ outbox và job attempt mà không tạo tác động nghiệp vụ trùng. Cache lỗi hoặc cũ không được cấp quyền sai tenant.
- FE/Mobile chỉ gọi API qua Nginx/.NET; không kết nối Redis trực tiếp. Session đã bắt đầu vẫn giữ event/result local khi mất mạng và đồng bộ lại sau khi backend xác nhận.
