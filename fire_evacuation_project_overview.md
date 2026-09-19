# Tổng Quan Dự Án Fire Evacuation Training 3D (FET3D)

## Mục đích

FET3D là đồ án tạo trải nghiệm tập huấn và đánh giá sơ tán trong môi trường 3D trên Android, xây dựng từ mô hình **IFC** của một công trình. Hệ thống giúp người học quan sát không gian, thực hành scenario mô phỏng và xem debrief về quyết định của mình.

Luồng cốt lõi:

```text
IFC -> 3D -> Unity Android -> QR -> Training -> Result
```

Sản phẩm phục vụ học tập, tập huấn và nghiên cứu. Nó không chứng nhận an toàn PCCC, không phê duyệt thiết kế, không thay thế tư vấn chuyên môn và không đưa ra hướng dẫn trong sự cố cháy thực tế.

## Vấn đề giải quyết

Slide, sơ đồ hai chiều và bài giảng thuần văn bản khó giúp người học ghi nhớ phòng, cửa, cầu thang và lối ra trong công trình cụ thể. FET3D chuyển IFC thành không gian runtime 3D để người học thực hành với hazard surrogate, lựa chọn tuyến đường và rubric đánh giá.

Thời lượng, lựa chọn tuyến, trạng thái hoàn thành và modeled exposure chỉ mô tả hành vi trong mô phỏng; chúng không phải bằng chứng rằng công trình an toàn hoặc người học đủ năng lực xử lý sự cố thật.

## Vai trò

| Vai trò | Trách nhiệm |
|---|---|
| `PlatformAdmin` | Quản trị nền tảng, organization, tài khoản, nội dung Learn công khai, cấu hình vận hành và giám sát tổng quan. |
| `OrganizationUser` | Quản lý Building, IFC, scenario, publish, QR, analytics và billing của organization. |
| `Trainee` | Đăng nhập Android, quét QR Building, chọn bài đã publish, thực hiện training và xem kết quả của chính mình. |

Landing và Learn trên web là nội dung công khai cho khách. Hệ thống không có guest account, guest training không định danh, lời mời thành viên hoặc role hệ thống thứ tư cho kiểm tra nội dung PCCC. Trainee local nhập username ngay khi đăng ký. Google mới xác minh xong phải chọn Trainee hoặc OrganizationUser và hoàn tất onboarding; Google đã liên kết giữ role/tenant cũ. `Trainee` đã xác thực quét QR canonical của Building, xem danh sách bài đã publish và chọn một bài; session sau đó pin đúng `Training`, release và scenario.

## Trải nghiệm web

Website chung điều hướng theo nhu cầu với các mục Khám phá, Dành cho tổ chức, Learn, Về chúng tôi, Đăng nhập và Tải ứng dụng. Landing dùng Three.js cho hành trình góc nhìn thứ nhất: cuộn qua công trình đang cháy, khói/lửa bám nguồn trong kiến trúc, rồi gặp hai ngã rẽ. Hướng tập huấn dẫn tới cảnh thu vào điện thoại và Góc học tập; hướng tổ chức nâng camera ra mặt cắt tòa nhà rồi chuyển sang trang Dành cho tổ chức. Learn web là blog công khai gồm bài viết, tip & trick và video theo tình huống; khách được đọc/tìm bản đã phát hành, còn hỏi AI và bookmark yêu cầu đăng nhập. `PlatformAdmin` quản trị draft, có thể phát hành ngay, ẩn/hiện hoặc xóa mềm/khôi phục bài; không có bước duyệt riêng của Learn. Hidden không đọc trực tiếp nhưng vẫn là nguồn RAG hợp lệ; Deleted bị loại khỏi RAG. Video dùng provider allowlist với fallback link/mô tả khi không embed được. Thiết kế chi tiết, màu, font, motion và fallback nằm trong [đặc tả UX web](fire3d-web-ux-design.md).

## Workflow

1. `OrganizationUser` tạo Building, tải IFC vào vùng lưu trữ riêng; có thể chỉnh thử trước khi mua dịch vụ trong hạn mức thử do Admin cấu hình.
2. Worker kiểm tra hash/định dạng, dùng Python/IfcOpenShell/IfcConvert để trích xuất, dùng Blender script để tối ưu geometry và tạo preview/issue.
3. Unity build worker dùng asset runtime đã chuẩn bị để tạo collider, NavMesh, liên kết tầng và content package; không dựng thủ công từng tòa.
4. QA kiểm tra floor, cửa, cầu thang, exit, liên kết liên tầng, route, collider, budget package và mã đối tượng. Revision chuyển `ReadyForScenario` hoặc `NeedsFix`.
5. `OrganizationUser` có thể tạo nhiều logical `Scenario` trên cùng revision; editor Three.js lưu draft, đặt nguồn lửa, khói, gió, tốc độ cháy, vật phẩm, spawn, mục tiêu và rubric. AI có thể tạo draft có nguồn để người dùng sửa.
6. OrganizationUser có thể chạy thử riêng bằng Mobile/Unity trong hạn mức thử. Playtest không đi qua QR Trainee và không tính learner analytics.
7. Khi một scenario version/package sẵn sàng, `ConfirmForTraining` được ghi cho đúng cặp revision/version; xác nhận bài đầu không khóa authoring scenario khác trên cùng geometry.
8. Backend tạo release `Built`, package bất biến và `Training` khớp revision/scenario/version. Payment dịch vụ Building phải cấp entitlement `Active` trước khi publish.
9. Sau publish, QR canonical của Building mở danh sách bài. Trainee chọn bài; backend tạo preparation record pin release/scenario/version để Mobile tải/verify. API start online mới kiểm tra dịch vụ, QR, package/runtime và cấp launch grant để mở Unity.
10. Unity trả event/result versioned qua native Android bridge về React Native/Expo để Mobile đồng bộ bằng API; `Trainee` xem debrief cá nhân, `OrganizationUser` xem aggregate thuộc organization.

11. `PlatformAdmin` quản lý Learn post và situation catalog: tạo version Draft, lưu nháp hoặc phát hành trực tiếp version Published, rồi ẩn/hiện hoặc xóa mềm/khôi phục bài khi cần. Bản Published bất biến; sửa tạo version mới. Content blocks có thể chứa text, ảnh hoặc URL video YouTube/Facebook/TikTok đã chuẩn hóa; không nhận iframe/script tùy ý. Chỉ bài Published với pointer đúng version và nguồn Common Approved được public API/cache sử dụng; Published và Hidden có thể vào Common RAG, còn Unpublished và Deleted bị loại.

Mỗi Building có một QR canonical để người dùng mở đúng tòa nhà; QR không giữ FK tới Training/release và không đổi Building sau khi cấp. QR không tải/cài APK riêng cho từng tòa nhà: Mobile app cài một lần rồi tải content package Unity theo bài/release đã chọn. Khi dịch vụ hết hạn, QR vẫn mở web/app để đăng nhập hoặc tải ứng dụng nhưng backend chặn phát hành và phiên mới. Three.js dùng cho landing và editor/preview; gameplay đầy đủ vẫn chạy trong Unity.

`ConfirmForTraining` chỉ là trạng thái readiness nội bộ, không phải xác nhận, phê duyệt hoặc thẩm duyệt PCCC.

## Kiến trúc

```text
IFC private storage on AWS S3
  -> Python/FastAPI processing worker (geometry, graph, QA, package)
  -> C#/.NET backend + Supabase PostgreSQL metadata
  -> signed manifest/content URL
  -> React Native/Expo Android shell + native Unity bridge -> Unity runtime
  -> event/result sync + analytics
```

- Web Next.js quản lý Building/IFC/scenario/editor, trạng thái xử lý, publish, QR, billing, AI usage và analytics; Three.js phục vụ landing và editor/preview.
- Backend C#/ASP.NET Core trên .NET xác minh email/password hoặc Firebase Google ID token, ánh xạ role/tenant, quản lý hồ sơ, lifecycle revision/release/training, session, audit và URL S3 ngắn hạn. Mailgun chỉ gửi thư reset mật khẩu; FCM chỉ gửi push.
- OneShield thuộc hệ thống OnePortal của iNET là lớp edge/bảo vệ phía trước Nginx; Nginx là reverse proxy đã chốt trước API và client gọi AI qua backend. OneShield không thay thế authorization của .NET/PostgreSQL. Chi tiết triển khai theo mục 14.1–14.2 của [technology](fire-evacuation-training-technology.md); cấu hình edge/reverse proxy là kiến trúc đích chưa triển khai.
- BE quản lý đăng nhập email/password; Firebase Authentication chỉ xác minh Google Sign-In; FCM cung cấp push notification. Authorization nghiệp vụ vẫn thuộc backend và PostgreSQL, không thuộc client hoặc custom claim đơn lẻ.
- Supabase cung cấp managed PostgreSQL; `pgvector` lưu embedding/index của RAG. Supabase Auth không nằm trong stack đã chọn.
- AI/RAG là service Python/FastAPI riêng trên Azure; Container Apps là phương án triển khai đề xuất. IFC/Blender và Unity build là worker độc lập nhận job bền vững. Worker tạo facts/artifact/QA nhưng không ghi billing, entitlement hoặc publish.
- Redis là kiến trúc đích cho cache-aside và Redis Streams sau transactional outbox. Dispatcher/consumer có retry và dedup qua PostgreSQL; Redis không là nguồn quyền, quota, billing, session hay kết quả học tập. FE/Mobile chỉ gọi API qua OneShield/OnePortal → Nginx và không kết nối Redis trực tiếp.
- AI service thực hiện ingestion/retrieval RAG qua `pgvector`; backend .NET kiểm tra identity, tenant, quota, consent và ghi usage kỹ thuật thành ledger. Client production không gọi AI service trực tiếp.
- AWS S3 lưu raw IFC riêng tư, manifest và content package bất biến.
- React Native/Expo xử lý local email/password hoặc Google Sign-In, QR, danh sách bài, download/cache/verify, kiểm tra dịch vụ, FCM và handoff qua native Android bridge; Unity thực hiện scene, hazard surrogate, routing, hành vi tương tác và kết quả training.

LLM production sẽ chọn **một** trong OpenAI API hoặc Google Gemini API (cấu hình qua Google AI Studio) sau đánh giá. Azure đã được chọn cho AI/RAG service; compute cho BE, IFC worker và Unity worker, cùng SKU/region/cost, vẫn là quyết định mở.

## Mô hình thương mại và AI

Mỗi Building có dịch vụ theo tháng và kỳ riêng. Một Organization có thể quản lý nhiều Building, mỗi Building bắt buộc có tên và địa chỉ. Gói chuẩn mua theo số Building/thời hạn; một quotation có nhiều dòng Building và một payment có thể cấp entitlement riêng cho từng dòng. Tòa mua thêm hoặc gia hạn chọn lọc có kỳ riêng; PlatformAdmin cấu hình discount không cộng dồn, còn số lượng lớn/công trình ngoài phạm vi chuẩn dùng báo giá Liên hệ. Trước hạn 5 ngày, hệ thống tạo thông báo web và email cho tổ chức theo từng entitlement. Thanh toán PayOS xác nhận quyền publish và mở phiên mới; hết hạn thì giữ dữ liệu, cho phiên đang chạy hoàn tất, nhưng chặn phát hành và session mới. Organization có quota AI dùng chung; số lượt vượt quota miễn phí được ghi nhận theo Building/tài khoản/loại yêu cầu, có liên kết grant/consent, hiển thị tạm tính và đối soát cuối kỳ organization. Trainee có quota ngày riêng theo user, không trừ quota organization và không cần membership tổ chức.

AI organization nhận câu hỏi, phạm vi Building/tầng/phòng được phép và facts IFC để trả lời có nguồn hoặc tạo scenario draft. Người dùng phải chỉnh trong editor và xác nhận trước khi lưu/publish. AI Trainee chỉ dùng corpus công khai/bài đã phát hành và kết quả cá nhân; không đọc tài liệu nội bộ của organization.

## Dữ liệu và an toàn

Raw IFC chỉ nằm trên backend/workstation; `Trainee` chỉ nhận package runtime đã publish qua manifest và URL ký có TTL. `OrganizationUser` có thể nhận package playtest draft/version đã verify qua flow riêng, không qua QR Trainee. Package, manifest, event batch và result cần hash, schema/version hoặc idempotency key phù hợp. `Trainee` không xem dữ liệu người khác; thao tác upload, processing, scenario, readiness, publish, QR, billing và quản trị đều có audit.

## Phạm vi

| Năng lực bản cuối | Thứ tự triển khai |
|---|---|
| Tài khoản, Building, IFC pipeline, editor kịch bản, Learn blog public, payment Building, AI/RAG, release/package, QR danh sách bài, Android/Unity, analytics, feedback/support và audit. | Chia thành các đợt: IFC/preview → editor/runtime → Learn/CMS → payment/AI → bridge/benchmark → mở rộng NPC/analytics; không đẩy payment/AI ra ngoài mục tiêu bản cuối. |

Session mới luôn kiểm tra online ở bước `start`, không phải preparation. Mất mạng hoặc entitlement hết hạn sau khi session/playtest bắt đầu vẫn cho Unity tiếp tục, lưu event/result cục bộ và đồng bộ lại khi có mạng; đây là khả năng tiếp tục phiên, không phải quyền mở session offline.

Dashboard dùng các định nghĩa cố định: `Trainee unique` là số Trainee khác nhau có session đã bắt đầu; `Learner plays` là số session Trainee đã bắt đầu; `Active sessions` là session có heartbeat trong cửa sổ cấu hình; `Completion rate` là số session hoàn tất chia cho số session đã bắt đầu; `Duration` chỉ tính session có `started_at` và `ended_at` hợp lệ. Preparation, playtest và session chưa bắt đầu không tính learner analytics; session chưa đồng bộ được ghi riêng và chưa tính hoàn thành cho tới khi backend xác nhận.

## Quyết định còn mở và điều kiện chốt

| Quyết định | Tác động | Chốt trước |
|---|---|---|
| Giá gói, hạn mức import/editor/playtest thử, quota AI, overage | UI billing, grant và consent | Payment/quota production |
| Redis provider/version, region, cache TTL/eviction, Streams retention và outbox recovery window | Retry, replay, chi phí, tải database và khả năng phục hồi | Trước triển khai event/cache production |
| OneShield/OnePortal plan/SKU, DNS ownership, TLS termination, WAF/rate limits, logging, SLA, region, cost và failover | Edge protection, ingress, observability và chi phí vận hành | Trước public production ingress |
| Ngày chốt/reset/rollover kỳ AI, nợ phí, hoàn tiền, hủy và retention | Settlement, entitlement và dữ liệu sau hết hạn | Billing lifecycle |
| Catalog hành vi Unity và kiểm tra nội dung PCCC | Editor, scoring và acceptance | Runtime authoring |
| Bộ IFC, Android mục tiêu và benchmark | QA support matrix, package budget | IFC/Mobile release |
| Unity project/build worker, LLM/embedding, Azure SKU/region và compute cho BE/worker | Toolchain, vector dimension, chi phí và vận hành | Production deployment |

Đây là bảng nguồn chính cho các mục chưa chốt; không trình bày các lựa chọn này như đã triển khai.

## Ranh giới service và nhất quán dữ liệu

`.NET core` là API nghiệp vụ duy nhất cho client và sở hữu identity, tenant, payment, Building entitlement, quota/usage, scenario, session và dashboard. AI/RAG FastAPI chạy riêng trên Azure; Container Apps chỉ là phương án triển khai đề xuất. IFC/Blender và Unity Editor là worker riêng nhận job. Notification và reconcile vẫn là background task của BE cho tới khi có nhu cầu scale độc lập được đo bằng benchmark.

Database dùng một Supabase PostgreSQL + `pgvector`; S3 giữ IFC, manifest và package lớn. PostgreSQL giữ Learn post/version, situation, bookmark và nguồn; `knowledge_sources/chunks` được dùng lại cho citation/RAG. `ai_requests` là nguồn trạng thái/kết quả kỹ thuật; reservation allocations là nguồn giữ quota; usage ledger và period items/adjustments là nguồn đối soát; `integration_outbox_events` và `integration_event_consumptions` là nguồn giao/replay/dedup event. Publish/hide/show Learn phát `PlatformCacheInvalidation` trong cùng transaction với audit/state, sau đó dispatcher gửi; Redis không trở thành nguồn công khai hay nguồn RAG. Tenant enqueue chỉ nhận `ProcessingJobRequested` schema `1` qua entry point backend và suy tenant từ aggregate; system event chỉ nhận allowlist `SystemNotification`/`PlatformCacheInvalidation` schema `1` qua entry point/executor riêng; `ProcessingJobRequeue` chỉ do requeue gate tạo. Outbox bắt đầu `Pending`, khóa identity/payload/hash sau enqueue và dùng dispatcher lease riêng; worker claim attempt/lease riêng qua backend, không nhận lease worker từ Redis message. Consumer kiểm tra envelope/receipt trước tác động, ghi receipt cùng transaction với tác động rồi mới ACK. ACID chỉ áp dụng trong transaction PostgreSQL: quota reserve, payment provenance, provisioning, outbox và idempotency phải được cập nhật nguyên tử trong transaction ngắn. Không giữ transaction khi chờ LLM, PayOS, S3, Redis hoặc worker. Redis mất thì outbox/cache fallback xử lý theo contract; không tuyên bố transaction ACID xuyên Azure, S3, Redis và PayOS.

Khi nguồn có thẩm quyền không khả dụng, payment/quota/publish/start mới bị từ chối hoặc chờ reconcile; phiên đã bắt đầu được tiếp tục offline và sync sau. Đây là chính sách nhất quán theo capability, không gắn toàn hệ thống bằng nhãn CAP “CP” hoặc “AP”.

Trong SQL thiết kế hiện hành, compatibility của publish/start/playtest phải fail-closed; AI billing chỉ đóng băng snapshot nhưng cho phép gắn quotation/payment đúng lifecycle; AI request được authorize ngay khi INSERT; và processing worker dùng logical job/input hash/current attempt/lease fencing. Các invariant này là thiết kế đích, chưa phải kết quả chạy database. Acceptance phải bao gồm tranh chấp lease, retry idempotency, payment reconcile và kết quả stale.

Đợt hardening cuối bổ sung: period AI mới chỉ bắt đầu ở `Open`; thao tác close tạo membership item và tổng tiền bất biến trong một transaction; policy version, terminal AI result, artifact và package pinned không sửa tại chỗ. Release package, session và playtest đều pin artifact ID cùng validation-run ID, không chỉ bytes/hash. Worker có mã kết quả có cấu trúc (`Claimed`, `Busy`, `AlreadyCompleted`, `NotClaimable`, `Conflict`), requeue `Failed` idempotent qua outbox và khóa job trước attempt; `Cancelled` là terminal. Runtime catalog kiểm tra capability từng phần tử và chọn runtime active có version số học đủ minimum. Reject một scenario chỉ ảnh hưởng cặp revision–scenario version, không đánh dấu geometry dùng chung `Rejected`. Accounting lock order là period nếu có → request → ledger/reservation → grants theo ID tăng dần; AI service không có quyền reserve/settle/close billing.

Đợt sửa recovery bổ sung các đường ghi có kiểm soát: preparation gate xác minh identity/package provenance trước khi tạo phiên nhưng không cấp quyền start; `record_session_event`/`complete_training_session` và `complete_playtest_session` ghi nhận retry sau gameplay bằng key/hash mà không kiểm tra lại entitlement hoặc trạng thái active hiện tại. Worker đăng ký artifact/validation/issues qua `register_processing_output` theo lease hiện hành; `invoice_ai_billing_period` và `pay_ai_billing_period` nối đầy đủ lifecycle settlement. Đây vẫn là SQL/Docs thiết kế, chưa chạy database hoặc kiểm thử concurrency/quyền/recovery.

## Tài liệu liên quan

- [Yêu cầu dự án](fire_evacuation_requirements.md)
- [Yêu cầu và phase](fire_evacuation_requirements.md)
- [Workflow](fire-evacuation-training-workflows.md)
- [Kiến trúc công nghệ](fire-evacuation-training-technology.md)
- [Thiết kế RAG BIM hỗ trợ gợi ý PCCC](fire_evacuation_bim_rag_pccc.md)
