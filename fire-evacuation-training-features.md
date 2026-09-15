# Fire Evacuation Training 3D — Tổng Hợp Tính Năng

> Đặc tả sản phẩm cho đồ án FET3D. Phạm vi được chia rõ giữa Phase 1 và Phase 2.

## 1. Định vị sản phẩm

FET3D biến mô hình **IFC** của một Building thành content package Unity dùng cho tập huấn sơ tán 3D trên Android. Người học cài ứng dụng một lần, đăng nhập và quét bất kỳ QR active pin một `Training` của release đã publish để tải package. Package đã xác minh được Unity dùng để chạy scenario, ghi nhận quyết định và trả result về React Native/Expo qua native Android bridge.

Mỗi Building có QR canonical để mở đúng training của tòa nhà. Three.js chỉ được dùng cho hiệu ứng landing/giới thiệu trên web; gameplay BIM 3D/2.5D chạy trong Unity của Mobile, không chạy thành game Three.js trên trình duyệt. Landing và Learn là nội dung web công khai; không có guest account hoặc guest training không định danh. Xem [đặc tả UX web](fire3d-web-ux-design.md) để biết storyboard POV, nhận diện, motion và hai hướng nhu cầu.

Headline Phase 1: **IFC → 3D → Unity Android → QR → Training → Result**.

Giá trị cốt lõi là giúp người học làm quen với không gian đã được mô hình hóa, thử quyết định route trong hazard surrogate và nhận debrief sau buổi tập huấn. FET3D không thay thế biển báo, quy trình ứng phó khẩn cấp, tư vấn chuyên môn hoặc hoạt động PCCC thực tế.

## 2. Ba loại tài khoản

| Tài khoản | Phạm vi |
| :--- | :--- |
| `PlatformAdmin` | Quản lý nền tảng, organization, tài khoản, giám sát và support ở cấp nền tảng. |
| `OrganizationUser` | Sở hữu Building, IFC, scenario, publish, QR, analytics và billing cho organization. |
| `Trainee` | Tham gia training bằng ứng dụng Android qua bất kỳ QR active của release đã publish và chỉ xem dữ liệu của buổi tập huấn của chính mình. |

Mô hình quyền không dùng cơ chế thành viên, lời mời, truy cập khách hoặc tập huấn không định danh. `organizationId` giới hạn ownership của Building, authoring, analytics và billing; nó không là điều kiện QR participation của `Trainee` đã xác thực.

## 3. Năng lực của OrganizationUser

### 3.1. Building và IFC

- Tạo Building, quản lý revision và tải source IFC.
- Theo dõi worker parse IFC, geometry runtime, hierarchy tầng, door/stair/exit, connectivity QA và log lỗi.
- Xem preview 3D, issue list và metadata của revision trước khi đưa vào scenario.
- Chỉ source IFC hợp lệ mới có thể tạo package; raw IFC không được đưa xuống ứng dụng Android.

### 3.2. Scenario và ConfirmForTraining

- Tạo version scenario với spawn, mục tiêu, hazard surrogate, time limit, rubric và cấu hình risk-aware A*.
- Chạy checklist readiness: candidate package/manifest, graph, route kiểm tra và scenario; QR chưa tồn tại ở bước này.
- Revision đạt IFC/connectivity QA ở `ReadyForScenario`; action `ConfirmForTraining` persist transition sang `ConfirmedForTraining`.

`ConfirmForTraining` là nhãn readiness nội bộ. Nó không tuyên bố Building, lối thoát, scenario hay kết quả mô phỏng đã được chứng nhận, phê duyệt hoặc kiểm định về PCCC.

### 3.3. Publish, QR và analytics

- Sau `ConfirmedForTraining`, tạo release `Built`, package và `Training` khớp revision/scenario/organization; publish release chỉ khi package và `Training` active đã tồn tại.
- Sau publish, tạo, in, rotate và revoke QR pin đúng một `Training` cùng release. Mọi `Trainee` đã xác thực có thể resolve QR active này, không có account-specific permission, allowlist hoặc điều kiện `organizationId`.
- Xem analytics cơ bản Phase 1 và expanded analytics Phase 2 cho Building/scenario thuộc organization.
- Xem quotation, transaction, invoice metadata và revenue khi các năng lực billing Phase 2 được bật.

## 4. Trải nghiệm Trainee

1. Cài ứng dụng Android một lần và đăng nhập.
2. Quét QR được phát cho hoạt động tập huấn.
3. Ứng dụng resolve active, published release cho `Trainee` đã xác thực, tải manifest/content package và xác minh hash.
4. React Native/Expo mở Unity qua native Android bridge với session và protocol version đã cấp.
5. Người học hoàn thành Learn, Guided Drill hoặc Assessment; Unity trả event/result qua bridge để Mobile đồng bộ backend.
6. Người học xem debrief của chính mình theo policy của mode.

Trong Phase 1, buổi tập huấn chạy online sau khi package được tải. Phase 2 bổ sung basic offline: package đã verify có thể mở khi mất mạng, event/result vào local queue và được đồng bộ lại khi kết nối trở lại.

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

## 6. Phase 1 — core online

| Nhóm | Tính năng |
| :--- | :--- |
| Authoring | Building, IFC pipeline, geometry/connectivity QA, revision và scenario. |
| Readiness/release | `ConfirmForTraining`, publish, manifest, package versioning và QR. |
| Runtime | React Native/Expo shell, native Android Unity bridge, Unity, hazard surrogate, risk-aware A*, online event/result sync. |
| Dữ liệu | session, result, audit và analytics cơ bản. |

Phase 1 không có offline runtime, NPC runtime, PayOS production hoặc luồng hóa đơn/quotation/revenue.

## 7. Phase 2 — mở rộng vận hành

| Nhóm | Tính năng |
| :--- | :--- |
| Billing | PayOS production, quotation, transaction, invoice metadata và revenue. |
| Trải nghiệm | basic offline, local queue/reconcile và basic NPC trong ngân sách hiệu năng công bố. |
| Vận hành | feedback/support, expanded analytics, filter/cohort/export và debrief aggregate. |

Basic NPC chỉ là tác nhân mô phỏng phục vụ scenario; không đại diện cho hành vi con người thật. Expanded analytics chỉ dùng để xem hoạt động học tập/mô phỏng, không kết luận mức độ an toàn của công trình.

PayOS request chỉ được tạo `Pending` qua function-only executor. Trusted webhook adapter xác thực `req.body` bằng SDK `webhooks.verify` hoặc canonicalize `data` theo thứ tự alphabet trước khi gọi database; database chỉ ghi attestation và đối soát, còn `returnUrl` không thể ghi `Paid`.

## 8. Analytics và debrief

Analytics cơ bản hiển thị số phiên, completion, thời lượng, route decision và modeled exposure. Expanded analytics bổ sung xu hướng theo thời gian, filter Building/scenario, cohort comparison, export và debrief aggregate.

`Trainee` chỉ xem kết quả của chính mình. `OrganizationUser` chỉ xem aggregate và dữ liệu thuộc organization. Heatmap, route tham chiếu hoặc analytics không được gọi là bằng chứng tuân thủ, chứng nhận hoặc xác nhận PCCC.

## 9. Đánh giá đồ án và giới hạn

Đánh giá chuyên môn, usability session và user study là các hoạt động của capstone để nhận phản hồi về độ rõ ràng, khả năng sử dụng, hiệu năng và trải nghiệm training. Các hoạt động này không xuất hiện như loại tài khoản hoặc quyền hệ thống.

Mô hình hazard dùng surrogate nhẹ, deterministic theo scenario và có giới hạn rõ ràng. Khi demo, tài liệu và giao diện phải nêu rằng kết quả chỉ phù hợp với phạm vi mô phỏng/tập huấn của đồ án.
