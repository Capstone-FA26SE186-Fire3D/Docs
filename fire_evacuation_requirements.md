# Tài Liệu Yêu Cầu Dự Án

**Dự án:** Fire Evacuation Training 3D (FET3D)
**Phiên bản:** v2.0
**Trạng thái:** Scope đồng bộ cho Phase 1 và Phase 2

## 1. Mục tiêu và giới hạn

FET3D là đồ án tạo trải nghiệm tập huấn sơ tán 3D trên Android từ mô hình **IFC** của Building. Ứng dụng Android được cài một lần. Mọi `Trainee` đã xác thực có thể quét bất kỳ QR active pin một `Training` của release đã publish; ứng dụng tải content package, xác minh package và khởi chạy Unity để thực hành scenario.

Headline Phase 1 là **IFC → 3D → Unity Android → QR → Training → Result**. Ở backend, QR chỉ được tạo active sau khi revision/scenario đã readiness, release và `Training` khớp nhau đã được tạo, rồi release được publish.

Sản phẩm là công cụ học tập và đánh giá hoạt động của đồ án. Mô phỏng hazard, route, điểm số, analytics và `ConfirmForTraining` không phải chứng nhận an toàn, phê duyệt PCCC, thẩm duyệt thiết kế, tư vấn chuyên môn hay hướng dẫn ứng phó sự cố thực tế.

## 2. Tài khoản và quyền

| Loại tài khoản | Trách nhiệm |
| :--- | :--- |
| `PlatformAdmin` | Quản trị nền tảng, tổ chức, tài khoản, cấu hình vận hành và giám sát tổng quan. |
| `OrganizationUser` | Sở hữu Building, IFC, scenario, publish, QR, analytics và billing của tổ chức. |
| `Trainee` | Đăng nhập ứng dụng, quét bất kỳ QR active của release đã publish, tải package, thực hiện buổi tập huấn và xem kết quả của chính mình. |

Không có cơ chế thành viên tổ chức, lời mời tài khoản, token khách, truy cập khách hoặc tập huấn không định danh. Mọi truy cập QR và buổi tập huấn phải gắn với `Trainee` đã xác thực; active QR của release đã publish không dùng account-specific permission, allowlist hoặc đối chiếu `organizationId` làm điều kiện tham gia.

Sau IFC/connectivity QA, revision ở `ReadyForScenario`. `ConfirmForTraining` là action do `OrganizationUser` thực hiện sau khi scenario và candidate package/manifest đạt readiness; action này chuyển revision sang `ConfirmedForTraining`. QR không phải điều kiện đầu vào của action vì QR chỉ tồn tại sau release và `Training`. Action không xác nhận công trình, lối thoát, phương án PCCC hay hiệu lực pháp lý của bất kỳ nội dung nào.

## 3. Functional Requirements

### FR-AUTH: xác thực và phân quyền

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AUTH-01 | Cho phép ba loại tài khoản đăng nhập bằng cơ chế xác thực an toàn; API và giao diện kiểm tra quyền ownership theo loại tài khoản và `organizationId`, ngoại trừ QR participation của `Trainee` theo FR-AUTH-03. | 1 |
| FR-AUTH-02 | `PlatformAdmin` có thể tạo, khóa hoặc khôi phục tài khoản và organization; `OrganizationUser` không cấp thêm loại tài khoản. | 1 |
| FR-AUTH-03 | `Trainee` đã xác thực có thể resolve và tham gia mọi active QR của release đã publish; chỉ kết quả cá nhân của chính `Trainee` được hiển thị. | 1 |

### FR-BUILD: Building và IFC

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-BUILD-01 | `OrganizationUser` tạo, cập nhật, lưu trữ Building của organization. | 1 |
| FR-IFC-01 | `OrganizationUser` tải mô hình IFC cho Building; hệ thống kiểm tra định dạng, kích thước, hash và lưu source riêng tư. | 1 |
| FR-IFC-02 | Worker phân tích IFC, tạo geometry runtime, semantic graph, NavMesh source, hazard grid và manifest cho revision. | 1 |
| FR-IFC-03 | Hệ thống hiển thị trạng thái xử lý, issue và log để `OrganizationUser` sửa source IFC rồi xử lý lại. | 1 |
| FR-IFC-04 | Revision phải kiểm tra floor, cửa, cầu thang, lối thoát, kết nối liên tầng và route từ spawn trước khi chuyển `ReadyForScenario`. | 1 |

### FR-SCENARIO: scenario và readiness

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-SCENARIO-01 | `OrganizationUser` tạo và version scenario trên revision hợp lệ: spawn, mục tiêu, hazard surrogate, giới hạn thời gian và rubric. | 1 |
| FR-SCENARIO-02 | Hệ thống lưu cấu hình risk-aware A* cùng version scenario để replay và so sánh được. | 1 |
| FR-SCENARIO-03 | `OrganizationUser` thực hiện action `ConfirmForTraining` khi candidate package/manifest, scenario và kiểm tra kết nối đã sẵn sàng; hệ thống persist transition `ReadyForScenario` → `ConfirmedForTraining`. | 1 |
| FR-SCENARIO-04 | Màn hình readiness phải hiển thị rõ giới hạn của mô phỏng và không dùng ngôn ngữ chứng nhận hoặc phê duyệt PCCC. | 1 |

### FR-RELEASE: publish, QR và content package

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-RELEASE-01 | Sau `ConfirmedForTraining`, hệ thống tạo TrainingRelease `Built`, package và một `Training` khớp revision/scenario/organization; chỉ sau đó mới publish release. Release mới không ghi đè package của phiên đang dùng. | 1 |
| FR-RELEASE-02 | Sau publish, hệ thống tạo active QR pin đồng thời một release và đúng một `Training`. Mọi `Trainee` đã xác thực có thể resolve QR đó để nhận manifest/package và bắt đầu session của `Training` đã pin; không áp dụng account-specific permission, allowlist hay điều kiện `organizationId` cho participation. | 1 |
| FR-RELEASE-03 | Android tải package theo manifest, kiểm tra hash/schema/runtime version rồi chuyển trạng thái sẵn sàng. | 1 |
| FR-RELEASE-04 | `OrganizationUser` có thể xem, in, rotate hoặc revoke QR của Building; QR phải bị deactivate trước khi đóng `Training` hoặc chuyển release sang `Superseded`/`Revoked`. | 1 |

### FR-TRAINING: buổi tập huấn

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-TRAINING-01 | Hỗ trợ Learn, Guided Drill và Assessment với luật scenario nhất quán. | 1 |
| FR-TRAINING-02 | React Native/Expo dùng native Android bridge gọi Unity với `sessionId`, `manifestPath`, launch `grant` ngắn hạn và `protocolVersion`; Unity trả event/result có schema version qua bridge về Mobile để Mobile đồng bộ bằng API. | 1 |
| FR-TRAINING-03 | Runtime cung cấp risk-aware A*, hazard surrogate và debrief cơ bản; không trình bày output là hướng dẫn thoát nạn thực tế. | 1 |
| FR-TRAINING-04 | Basic offline: package đã xác minh có thể khởi chạy khi mất mạng, event/result được xếp hàng và đồng bộ khi có mạng. | 2 |
| FR-TRAINING-05 | Basic NPC: scenario hỗ trợ số lượng NPC giới hạn, state đơn giản và budget hiệu năng trên Android. | 2 |

### FR-ANALYTICS: analytics

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-ANALYTICS-01 | `OrganizationUser` xem aggregate cơ bản: số phiên, thời lượng, kết quả, route decision và modeled exposure. | 1 |
| FR-ANALYTICS-02 | `Trainee` xem kết quả của chính mình theo policy của mode. | 1 |
| FR-ANALYTICS-03 | Expanded analytics bổ sung filter theo Building/scenario/thời gian, so sánh cohort, export và debrief aggregate. | 2 |

### FR-BILLING: quotation, thanh toán và hỗ trợ

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-BILLING-01 | `OrganizationUser` xem quotation cho dịch vụ tổ chức. | 2 |
| FR-BILLING-02 | Tích hợp PayOS production: backend tạo duy nhất request `Pending` qua `SECURITY DEFINER` entry point dành cho NOLOGIN executor, không có table DML; webhook adapter dùng SDK `webhooks.verify(req.body)` hoặc canonicalize và sắp xếp tăng dần các trường trong `data` theo thuật toán chính thức trước khi gọi entry point webhook idempotent. Database không tự xác thực mật mã. | 2 |
| FR-BILLING-03 | Lưu invoice metadata, trạng thái thanh toán và revenue aggregate theo organization. | 2 |
| FR-BILLING-04 | `returnUrl`/`cancelUrl` chỉ điều hướng; chỉ trusted webhook đã được adapter xác thực và khớp `orderCode`, amount, currency mới có thể ghi `Paid`. | 2 |
| FR-SUPPORT-01 | `OrganizationUser` và `Trainee` gửi feedback/support; `PlatformAdmin` theo dõi và phản hồi ticket. | 2 |

### FR-AUDIT: truy vết

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AUDIT-01 | Lưu audit cho tải IFC, xử lý revision, scenario, `ConfirmForTraining`, publish, QR, billing và các thao tác quản trị. | 1 |

## 4. Non-Functional Requirements

- **Performance:** mục tiêu tối thiểu 30 FPS trên Android tầm trung cho content package Phase 1; Phase 2 benchmark basic NPC theo ngân sách thiết bị đã công bố.
- **Security:** raw IFC chỉ nằm ở backend/workstation; mobile nhận package runtime qua manifest và URL ký có TTL. Mọi query tenant-scoped phải lọc `organizationId`.
- **Integrity:** package, manifest, event batch và webhook thanh toán phải có hash, schema/version hoặc idempotency key phù hợp.
- **Privacy:** chỉ thu thập dữ liệu cần cho tập huấn, analytics và vận hành; `Trainee` không xem dữ liệu của người khác.
- **Availability:** backend stateless, worker retry có kiểm soát; lỗi processing hoặc hash mismatch không được publish im lặng.
- **Compatibility:** Android 10 trở lên; web vận hành trên các trình duyệt hiện đại.

## 5. Phạm vi theo phase

| Phase 1 — core online | Phase 2 — mở rộng vận hành |
| :--- | :--- |
| Tài khoản, Building, IFC pipeline, scenario, `ConfirmForTraining`, publish, QR, Android/Unity online session, analytics cơ bản và audit. | PayOS production, quotation, transaction, invoice metadata, revenue, feedback/support, basic offline, basic NPC và expanded analytics. |

## 6. Ngoài phạm vi

- Chứng nhận, phê duyệt, kiểm định hoặc kết luận tuân thủ PCCC.
- Chuyển đổi tự động từ định dạng mô hình ngoài IFC.
- Truy cập không có tài khoản xác thực hoặc chia sẻ dữ liệu vượt phạm vi organization.
- Hướng dẫn quyết định trong tình huống cháy nổ thực tế.

## 7. Đánh giá đồ án

Hoạt động đánh giá chuyên môn và user study là hoạt động thu thập phản hồi cho đồ án. Chúng kiểm tra tính dễ sử dụng, độ rõ ràng của scenario, hiệu năng và cách người học tương tác với mô phỏng; chúng không tạo quyền hệ thống và không thay thế quy trình pháp lý hoặc nghiệp vụ PCCC.
