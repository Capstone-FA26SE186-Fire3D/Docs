# Tài Liệu Yêu Cầu Dự Án

**Dự án:** Fire Evacuation Training 3D (FET3D)
**Phiên bản:** v2.0
**Trạng thái:** Scope bản cuối đã đồng bộ; Phase chỉ biểu thị thứ tự triển khai

## 1. Mục tiêu và giới hạn

FET3D là đồ án tạo trải nghiệm tập huấn sơ tán 3D trên Android từ mô hình **IFC** của Building. Ứng dụng Android được cài một lần. Mọi `Trainee` đã xác thực có thể quét QR ổn định của Building, xem danh sách bài đã publish, chọn một bài; backend tạo session preparation để ứng dụng tải/xác minh package, rồi chỉ bước `start` online mới kiểm tra entitlement, pin `Training`/release/scenario và cấp launch grant để khởi chạy Unity.

Luồng cốt lõi là **IFC → 3D → Unity Android → QR → Training → Result**. Ở backend, QR Building có thể tồn tại như điểm resolve ổn định; danh sách chỉ trả bài đã publish, preparation có thể tạo trước, nhưng session mới chỉ được start sau khi entitlement online còn hợp lệ.

Sản phẩm là công cụ học tập và đánh giá hoạt động của đồ án. Website landing và Learn cung cấp nội dung công khai; việc đọc/tìm nội dung không cần tài khoản. Mô phỏng hazard, route, điểm số, analytics và `ConfirmForTraining` không phải chứng nhận an toàn, phê duyệt PCCC, thẩm duyệt thiết kế, tư vấn chuyên môn hay hướng dẫn ứng phó sự cố thực tế.

## 2. Tài khoản và quyền

| Loại tài khoản | Trách nhiệm |
| :--- | :--- |
| `PlatformAdmin` | Quản trị nền tảng, tổ chức, tài khoản, cấu hình vận hành và giám sát tổng quan. |
| `OrganizationUser` | Sở hữu Building, IFC, editor/scenario, publish, QR, analytics, billing và AI usage của tổ chức. |
| `Trainee` | Đăng nhập web/Mobile bằng Google, quét QR Building, chọn bài đã publish, tải package, thực hiện buổi tập huấn, hỏi AI ngoài game và xem kết quả của chính mình. |

Không có cơ chế thành viên tổ chức, lời mời tài khoản, guest account, token khách hoặc guest training không định danh. Landing/QR status có thể mở trước đăng nhập, nhưng mọi session phải gắn với `Trainee` đã xác thực; QR Building không dùng account-specific permission, allowlist hoặc đối chiếu `organizationId` của Trainee để thay thế kiểm tra identity, entitlement và bài đã publish. Nội dung landing, Learn và trang giới thiệu Dành cho tổ chức vẫn có thể xem công khai.

Sau IFC/connectivity QA, revision ở `ReadyForScenario`. `OrganizationUser` có thể tạo nhiều Scenario/version trên revision, kể cả sau khi scenario khác đã được confirm nếu geometry tương thích. `ConfirmForTraining` là action cho đúng cặp revision/version; QR không phải điều kiện đầu vào vì QR chỉ là Building resolve point. Action không xác nhận công trình, lối thoát, phương án PCCC hay hiệu lực pháp lý của bất kỳ nội dung nào.

## 3. Functional Requirements

### FR-WEB: website công khai và cổng học tập

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-WEB-01 | Website chung cung cấp landing, Khám phá, Dành cho tổ chức, Learn, Về chúng tôi, Đăng nhập và Tải ứng dụng; không bắt người dùng chọn role trước khi xem nội dung công khai. | 1 |
| FR-WEB-02 | Landing trình bày hành trình POV cuộn qua công trình đang cháy và hai hướng nhu cầu: tập huấn hoặc tổ chức tập huấn. Three.js phục vụ landing và editor/preview 3D; phải có fallback khi WebGL/reduced motion không dùng được. | 1 |
| FR-WEB-03 | Learn cho phép khách tìm/đọc bài có nguồn; hỏi AI, hỏi về bài đang đọc và lưu bài yêu cầu đăng nhập. Câu trả lời AI phải kèm nguồn. | TBD |
| FR-WEB-04 | Góc học tập của Trainee đã xác thực hiển thị AI, bài lưu, lịch sử và kết quả cá nhân; trang Dành cho tổ chức công khai phần giới thiệu nhưng khu quản lý enforce quyền `OrganizationUser` và `organizationId`. | 1 |
| FR-WEB-05 | Organization editor hiển thị IFC preview, tầng/lớp, đặt/chỉnh/xóa scenario objects, lưu draft, undo/redo, validation và version. Preview web chỉ minh họa; full playtest chạy riêng trong Mobile/Unity với quyền OrganizationUser, trong Trial còn quota thử hoặc entitlement Building `Active`. | 1 |
| FR-WEB-06 | Web hiển thị quota AI, usage, remaining, overage, đơn giá, tạm tính, kỳ đối soát và điều khoản trước khi cho phép dùng vượt hạn mức. | 1 |

### FR-AUTH: xác thực và phân quyền

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AUTH-01 | Ba loại tài khoản đăng nhập qua Firebase Authentication, gồm Google Sign-In. API xác minh Firebase ID token và ánh xạ Firebase UID sang user, role, trạng thái và `organizationId` trong PostgreSQL; authorization không dựa riêng vào dữ liệu client/custom claim. | 1 |
| FR-AUTH-02 | `PlatformAdmin` có thể tạo, khóa hoặc khôi phục tài khoản và organization; `OrganizationUser` không cấp thêm loại tài khoản. | 1 |
| FR-AUTH-03 | `Trainee` đã xác thực có thể resolve QR Building, xem bài đã publish, chọn bài và chỉ xem kết quả cá nhân của chính mình; preparation không cấp quyền, API start mới kiểm tra entitlement online trước session mới. | 1 |
| FR-AUTH-04 | Firebase/Google quản lý credential đăng nhập; FET3D không lưu password hash hoặc Google refresh token. Backend vẫn cấp launch grant và signed content URL ngắn hạn theo session/release. | 1 |

### FR-NOTIFY: thông báo thiết bị

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-NOTIFY-01 | Mobile đăng ký Firebase Cloud Messaging token theo installation; backend cho phép rotate/revoke token và loại token không hợp lệ. FCM token không được dùng như credential xác thực. | 1 |

### FR-BUILD: Building và IFC

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-BUILD-01 | `OrganizationUser` tạo, cập nhật, lưu trữ Building của organization. | 1 |
| FR-IFC-01 | `OrganizationUser` tải mô hình IFC cho Building; hệ thống kiểm tra định dạng, kích thước, hash và lưu source riêng tư. | 1 |
| FR-IFC-02 | Worker phân tích IFC, tạo geometry runtime, semantic graph, NavMesh source, hazard grid và manifest cho revision. | 1 |
| FR-IFC-03 | Hệ thống hiển thị trạng thái xử lý, issue và log để `OrganizationUser` sửa source IFC rồi xử lý lại. | 1 |
| FR-IFC-04 | Revision phải kiểm tra floor, cửa, cầu thang, lối thoát, kết nối liên tầng và route từ spawn trước khi chuyển `ReadyForScenario`. | 1 |
| FR-IFC-05 | Pipeline dùng IfcOpenShell/IfcConvert, Blender script và Unity build worker để tự động tạo geometry runtime, GLB/metadata, collider, NavMesh và content package; issue thiếu dữ liệu phải hiển thị để OrganizationUser sửa/xác nhận. | 1 |
| FR-IFC-06 | Thay IFC tạo revision mới; thay scenario chỉ tạo scenario version mới nếu geometry tương thích. Mã IFC, tọa độ, đơn vị và provenance phải được giữ qua các artifact. | 1 |

### FR-SCENARIO: scenario và readiness

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-SCENARIO-01 | `OrganizationUser` tạo và version scenario trên revision hợp lệ: spawn, mục tiêu, hazard surrogate, giới hạn thời gian và rubric. | 1 |
| FR-SCENARIO-02 | Hệ thống lưu cấu hình risk-aware A* cùng version scenario để replay và so sánh được. | 1 |
| FR-SCENARIO-03 | `OrganizationUser` thực hiện action `ConfirmForTraining` khi candidate package/manifest, đúng ScenarioVersion và kiểm tra kết nối đã sẵn sàng; hệ thống persist readiness theo revision/version và không khóa scenario khác trên geometry. | 1 |
| FR-SCENARIO-04 | Màn hình readiness phải hiển thị rõ giới hạn của mô phỏng và không dùng ngôn ngữ chứng nhận hoặc phê duyệt PCCC. | 1 |
| FR-SCENARIO-05 | Scenario hỗ trợ cấu hình nguồn lửa, tốc độ cháy, khói, hướng/cường độ gió, cửa/vùng chặn, spawn, mục tiêu, thời lượng và các tương tác runtime đã được cung cấp. | 1 |
| FR-SCENARIO-06 | AI có thể tạo draft scenario từ tài liệu/facts được phép; draft không tự lưu, sửa editor hoặc publish và phải có nguồn/giả định. | 1 |

### FR-RELEASE: publish, QR và content package

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-RELEASE-01 | Sau `ConfirmedForTraining`, hệ thống tạo TrainingRelease `Built`, package và một `Training` khớp revision/scenario/organization; package phải pin candidate artifact, checksum package, manifest hash, build target, protocol/manifest schema, runtime tương thích, `ValidationRun` đạt và không còn `Error/Critical` issue mở; chỉ sau đó mới publish release. Release mới không ghi đè package của phiên đang dùng. | 1 |
| FR-RELEASE-02 | Sau publish, hệ thống duy trì QR canonical ở cấp Building. QR resolve danh sách bài đã publish; Trainee chọn bài, rồi backend pin đúng release/scenario/training cho session. | 1 |
| FR-RELEASE-03 | Android tải package theo manifest, kiểm tra package hash, manifest hash, build target, schema/runtime version và artifact provenance rồi chuyển trạng thái sẵn sàng. | 1 |
| FR-RELEASE-04 | `OrganizationUser` có thể xem, in, rotate hoặc revoke QR của Building. QR hết hạn dịch vụ vẫn mở landing/trạng thái; backend chặn publish và session mới. Thu hồi QR vì quản trị được phân biệt với hết hạn dịch vụ. | 1 |

### FR-TRAINING: buổi tập huấn

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-TRAINING-01 | Hỗ trợ Learn, Guided Drill và Assessment với luật scenario nhất quán. | 1 |
| FR-TRAINING-02 | React Native/Expo dùng native Android bridge gọi Unity với `sessionId`, `manifestPath`, launch `grant` ngắn hạn và `protocolVersion`; Unity trả event/result có schema version qua bridge về Mobile để Mobile đồng bộ bằng API. | 1 |
| FR-TRAINING-03 | Runtime cung cấp risk-aware A*, hazard surrogate và debrief cơ bản; không trình bày output là hướng dẫn thoát nạn thực tế. | 1 |
| FR-TRAINING-04 | Tách `prepare` (identity/bài/QR/package hash, manifest hash, build target, metadata, idempotency, tải và verify) khỏi `start` (`POST /api/training/sessions/{sessionId}/start`, online entitlement/QR/package/runtime check). Package cache không cho mở session mới offline. | 1 |
| FR-TRAINING-05 | Basic NPC: scenario hỗ trợ số lượng NPC giới hạn, state đơn giản và budget hiệu năng trên Android. | 2 |
| FR-TRAINING-06 | Mỗi session mới kiểm tra online ở bước start kể cả package đã cache; sau khi launch grant/gameplay đã bắt đầu, mất mạng hoặc entitlement hết hạn không dừng gameplay, event/result được xếp hàng và đồng bộ khi có mạng. `training`, `release`, `scenario`, tenant và QR đã pin không được đổi. | 1 |
| FR-TRAINING-07 | Unity runtime cung cấp thư viện dùng chung cho movement, camera, collision, cửa, vật phẩm, lửa/khói/gió/cháy lan và chấm điểm. Organization chỉ cấu hình capability đã có. | 1 |

### FR-ANALYTICS: analytics

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-ANALYTICS-01 | `OrganizationUser` xem aggregate cơ bản theo định nghĩa: `Trainee unique` là số Trainee khác nhau có session đã bắt đầu; `Learner plays` là số session Trainee đã bắt đầu; `Active sessions` là session có heartbeat trong cửa sổ cấu hình; `Completion rate` = session hoàn tất / session đã bắt đầu; `Duration` chỉ tính session có `started_at` và `ended_at` hợp lệ. Playtest, preparation và session chưa bắt đầu không tính learner analytics; session chưa đồng bộ ghi riêng và chưa tính hoàn thành cho tới khi backend xác nhận. | 1 |
| FR-ANALYTICS-02 | `Trainee` xem kết quả của chính mình theo policy của mode. | 1 |
| FR-ANALYTICS-03 | Expanded analytics bổ sung filter theo Building/scenario/thời gian, so sánh cohort, export và debrief aggregate. | 2 |

### FR-BILLING: quotation, thanh toán và hỗ trợ

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-BILLING-01 | Mỗi Building có service subscription theo tháng và ngày hiệu lực/hết hạn riêng; import/editor/playtest thử có thể hoạt động trong hạn mức do Admin cấu hình trước thanh toán. Trial không publish và không mở session Trainee. | 1 |
| FR-BILLING-02 | Publish và mở session mới yêu cầu Building còn service hợp lệ. Hết hạn khóa publish/session mới, giữ dữ liệu và cho session đang chạy hoàn tất. | 1 |
| FR-BILLING-03 | Tích hợp PayOS production: quotation lưu purpose, thời hạn, giá và điều khoản snapshot; backend tạo duy nhất request `Pending` với idempotency key qua `SECURITY DEFINER` entry point dành cho NOLOGIN executor, không có table DML; webhook adapter dùng SDK `webhooks.verify(req.body)` hoặc canonicalize và sắp xếp tăng dần các trường trong `data` theo thuật toán chính thức trước khi gọi entry point webhook idempotent. Database không tự xác thực mật mã. Payment `Applied` có provisioning key ổn định và record reconcile nếu cấp entitlement lỗi. | 1 |
| FR-BILLING-04 | Lưu invoice metadata, trạng thái thanh toán, service entitlement từng Building, giá/điều khoản snapshot và revenue aggregate theo organization. | 1 |
| FR-BILLING-05 | Quota AI organization dùng chung; Trainee có quota ngày theo user. Admin cấu hình quota miễn phí theo gói/tòa nhà/user. Usage ghi grant, organization/building/user/audience, loại yêu cầu, request id, đơn giá snapshot và consent overage; vượt quota được thông báo, tính theo usage và đối soát cuối kỳ riêng của organization. | 1 |
| FR-BILLING-06 | `returnUrl`/`cancelUrl` chỉ điều hướng; chỉ trusted webhook đã được adapter xác thực và khớp `orderCode`, amount, currency mới có thể ghi `Paid`, gia hạn entitlement hoặc tạo AI settlement. Retry/webhook trùng không tạo cấp quyền hoặc usage trùng; payment AI không cấp service Building. | 1 |
| FR-SUPPORT-01 | `OrganizationUser` và `Trainee` gửi feedback/support; `PlatformAdmin` theo dõi và phản hồi ticket. | 2 |

### FR-AUDIT: truy vết

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AUDIT-01 | Lưu audit cho tải IFC, xử lý revision, scenario, `ConfirmForTraining`, publish, QR, billing và các thao tác quản trị. | 1 |
| FR-AUDIT-02 | Lưu audit cho AI request/usage, nguồn truy xuất, quota, overage, consent dùng vượt hạn mức và quyết định accept/edit/reject draft scenario. | 1 |

### FR-AI: RAG cho Organization và Trainee

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AI-01 | AI Organization trả lời hướng dẫn hệ thống, giải thích BIM/PCCC và tạo draft scenario từ corpus được duyệt, facts IFC và scope Building/tầng/phòng được phép. | 1 |
| FR-AI-02 | `ScenarioDraft` AI phải có nguồn, facts anchor, giả định, giới hạn và trạng thái `NeedsUserEdit`; `KnowledgeAnswer` là câu trả lời kiến thức thông thường và không bị ép thành draft review. `InsufficientEvidence` và `RejectedBySafetyGate` là trạng thái phản hồi riêng. AI không tự sửa editor, route, scoring, runtime state, lưu scenario hoặc publish. | 1 |
| FR-AI-03 | AI Trainee chạy trên web/Mobile ngoài gameplay, dùng corpus công khai/bài đã publish và dữ liệu kết quả cá nhân được phép; không đọc tài liệu riêng của Organization. | 1 |
| FR-AI-04 | Trainee có quota ngày miễn phí do PlatformAdmin cấu hình. Organization có quota AI dùng chung và usage vượt hạn mức được tính riêng; frontend không tự quyết định việc trừ lượt. | 1 |
| FR-AI-05 | RAG lọc tenant/scope trước vector retrieval, trả citation và từ chối khi thiếu evidence hoặc câu hỏi yêu cầu chứng nhận/ứng phó sự cố thực tế. | 1 |
| FR-AI-06 | Backend lưu durable `ai_request` với idempotency key, canonical input hash, scope/source version, trạng thái xử lý, citation và usage kỹ thuật; `GET /api/ai/requests/{requestId}` dùng để reconcile timeout. AI chỉ trả usage kỹ thuật, còn backend reserve/chốt quota, overage, consent và tiền. | 1 |

## 4. Non-Functional Requirements

- **Performance:** mục tiêu tối thiểu 30 FPS trên Android tầm trung cho content package; benchmark frame time, RAM, tải/mở package, nhiệt máy, kích thước package, nhiều lần mở/đóng Unity và thời lượng 15 phút trên thiết bị thật. Chưa gọi đạt trước khi có thiết bị và số liệu.
- **Security:** raw IFC nằm trong AWS S3 private hoặc workstation được kiểm soát; mobile nhận package runtime qua manifest và signed URL có TTL. API xác minh Firebase ID token; mọi query tenant-scoped, gồm retrieval `pgvector`, phải lọc `organizationId`. Không đưa Firebase Admin, Supabase service-role, AWS hoặc LLM key vào client.
- **Integrity:** package, manifest, event batch và webhook thanh toán phải có hash, schema/version hoặc idempotency key phù hợp.
- **Privacy:** chỉ thu thập dữ liệu cần cho tập huấn, analytics và vận hành; `Trainee` không xem dữ liệu của người khác.
- **Availability:** backend stateless, worker retry có kiểm soát; lỗi processing hoặc hash mismatch không được publish im lặng. AI/RAG chạy thành service riêng trên Azure; IFC/Blender và Unity build retry theo job/attempt/hash.
- **Consistency:** reserve quota phải khóa grant theo thứ tự cố định và ghi allocation cho một hoặc nhiều grant trong transaction PostgreSQL ngắn; không dùng `SKIP LOCKED` để báo hết quota giả. Payment provenance, entitlement provisioning và idempotency cũng nằm trong transaction ngắn; không giữ transaction khi chờ LLM, PayOS, S3 hoặc worker. Transactional outbox, lease fencing và reconcile xử lý giao tiếp phân tán.
- **Failure policy:** khi nguồn có thẩm quyền không khả dụng, không cấp quyền mới dựa trên cache; session đã bắt đầu được tiếp tục offline và sync sau. Timeout AI phải tra trạng thái bằng request ID trước khi retry hoặc hoàn reservation.
- **Compatibility:** Android 10 trở lên; web vận hành trên các trình duyệt hiện đại.
- **Portability:** LLM đi qua provider adapter để chọn OpenAI hoặc Gemini. Azure đã được chọn cho AI/RAG service; compute cho BE, IFC worker và Unity worker, SKU/region/license vẫn phải chốt bằng spike trước production.

## 5. Phạm vi bản cuối và thứ tự triển khai

| Năng lực bản cuối | Thứ tự triển khai |
| :--- | :--- |
| Tài khoản, Building, IFC pipeline, editor, payment Building, scenario, AI/RAG, `ConfirmForTraining`, publish, QR danh sách bài, Android/Unity, analytics và audit. | Có thể triển khai theo các đợt IFC/preview → editor/runtime → payment/AI → bridge/benchmark → mở rộng NPC/analytics; không được coi payment hoặc AI là ngoài cam kết. |

## 6. Ngoài phạm vi

- Chứng nhận, phê duyệt, kiểm định hoặc kết luận tuân thủ PCCC.
- Chuyển đổi tự động từ định dạng mô hình ngoài IFC.
- Truy cập không có tài khoản xác thực hoặc chia sẻ dữ liệu vượt phạm vi organization.
- Hướng dẫn quyết định trong tình huống cháy nổ thực tế.

## 7. Đánh giá đồ án

Hoạt động đánh giá chuyên môn và user study là hoạt động thu thập phản hồi cho đồ án. Chúng kiểm tra tính dễ sử dụng, độ rõ ràng của scenario, hiệu năng và cách người học tương tác với mô phỏng; chúng không tạo quyền hệ thống và không thay thế quy trình pháp lý hoặc nghiệp vụ PCCC.

## 8. Tiêu chí bổ sung cho compatibility, billing và recovery

- **FR-COMPAT-01:** Publish, Trainee start và OrganizationUser playtest phải dùng chung runtime catalog và manifest contract. Runtime version phải đúng `major.minor.patch`; thiếu minimum runtime, protocol, manifest schema, manifest hash, build target hoặc capability array thì từ chối. Capability phải là các chuỗi không rỗng; array rỗng chỉ hợp lệ khi được khai báo rõ. Release package, session và playtest phải pin đúng artifact ID, validation-run ID, hash và build target; provenance sai hoặc package đã pin bị sửa tại chỗ thì từ chối.
- **FR-BILLING-RECOVERY-01:** Kỳ AI chuyển `Open → Closed → Invoiced → Paid`; snapshot và membership item không đổi sau `Closed`, nhưng quotation `AIUsage` và payment `Applied` được gắn đúng ở từng bước. Retry chứng từ cùng định danh không tạo bản ghi mới; chứng từ khác trả conflict. Lock order là period nếu có → request → ledger/reservation → grant theo ID tăng dần. Late/uncertain usage đi qua adjustment riêng có tenant, actor, lý do và idempotency.
- **FR-AI-RECOVERY-01:** AI request phải được authorize tại thời điểm tạo theo audience, user, tenant, Building và policy version. Request mới bắt đầu `Accepted` không có kết quả; policy/input identity và terminal result bất biến sau tiếp nhận, request đã nhận vẫn được reconcile nếu user bị khóa. FastAPI chỉ trả usage kỹ thuật/evidence; backend ghi result và accounting qua executor/contract riêng.
- **FR-PROCESS-02:** Logical job giữ input hash. Worker chỉ claim job queued hoặc attempt đã hết lease; lease hiện hành không bị thay thế, job thành công không chạy lại do message trùng, và kết quả phải khớp attempt/artifact/validation hiện hành.
- **FR-PROCESS-03:** Requeue job `Failed` là thao tác backend có quyền, có idempotency key và outbox; job `Cancelled` không tự chạy lại. Hai worker claim đồng thời chỉ một worker nhận lease mới.
- **NFR-RECOVERY-02:** Retry, timeout và duplicate delivery phải trả trạng thái xác định (`Claimed`, `Busy`, `AlreadyCompleted`, `NotClaimable`, `StaleAttempt`, `Conflict`) và không tạo charge, entitlement, artifact hoặc publication trùng.

Các tiêu chí trên là contract thiết kế và acceptance criteria cho đợt triển khai; chưa được gọi là đạt nếu chưa có test database/concurrency/recovery tương ứng.
