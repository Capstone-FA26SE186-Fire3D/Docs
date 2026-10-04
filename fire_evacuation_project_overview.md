# Tổng Quan Dự Án Fire Evacuation Training 3D (FET3D)

**Đồng bộ auth BE 03/10/2026:** theo [authentication](../BE/docs/authentication.md) và [API guide](../BE/docs/api-docs.md), source BE main `0683d90`. Local registration dùng form → OTP → registrationToken → register → login; register trả account, chưa cấp JWT. Google UID đã link đăng nhập được; onboarding/link mới còn thiếu API hoàn tất. Các quy tắc đầy đủ và sơ đồ nằm tại [workflows mục 2.1–2.4](fire-evacuation-training-workflows.md#21-đăng-ký-local-form--otp--account--login). Source không chứng minh client/provider/deployment đã nghiệm thu.

**Đồng bộ thiết kế ngày 03/10/2026:** yêu cầu nghiệp vụ, SQL design v7, ERD Markdown và Word ý tưởng đã được đồng bộ. Tên bảng/function là contract thiết kế, không chứng minh migration/API/runtime đã triển khai. [Requirements](fire_evacuation_requirements.md) là nguồn yêu cầu sản phẩm; [ghi chú quyết định](phan_tich_khoang_cach_va_quyet_dinh_nghiep_vu.md) ghi lại lựa chọn và chi tiết còn mở.

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
| `PlatformAdmin` | Quản trị nền tảng, thư viện hỗ trợ Organization, Learn công khai và duyệt mọi phiên bản kịch bản/rubric; quản lý gói và quota. |
| `OrganizationUser` | Quản lý Building, IFC, scenario, publish, QR, analytics và billing của organization. |
| `Trainee` | Đăng nhập Android, quét QR Building, chọn bài đã publish, thực hiện training và xem kết quả của chính mình. |

Landing và Learn trên web là nội dung công khai cho khách. Hệ thống không có guest account, guest training không định danh, lời mời thành viên hoặc role hệ thống thứ tư cho kiểm tra nội dung PCCC. Trainee local nhập username ngay khi đăng ký; form → OTP → proof → account verified → login bằng email/password. Google đã link giữ role/tenant cũ; Google mới trả OnboardingRequired, email local trùng trả ACCOUNT_LINK_REQUIRED, còn thiếu API hoàn tất onboarding/link. Thiết kế đích chỉ onboarding Trainee/OrganizationUser. Trainee đăng nhập quét QR; Building public tham gia trực tiếp, private cần mã tham gia chung; xem/chọn bài được phép; session sau đó pin đúng `Training`, release và scenario.

## Trải nghiệm web

Website chung điều hướng theo nhu cầu với các mục Khám phá, Dành cho tổ chức, Learn, Về chúng tôi, Đăng nhập và Tải ứng dụng. Landing dùng Three.js cho hành trình góc nhìn thứ nhất: cuộn qua công trình đang cháy, khói/lửa bám nguồn trong kiến trúc, rồi gặp hai ngã rẽ. Hướng tập huấn dẫn tới cảnh thu vào điện thoại và Góc học tập; hướng tổ chức nâng camera ra mặt cắt tòa nhà rồi chuyển sang trang Dành cho tổ chức. Learn web là blog công khai gồm bài viết, tip & trick và video theo tình huống; khách được đọc/tìm bản đã phát hành, còn hỏi AI và bookmark yêu cầu đăng nhập. `PlatformAdmin` quản trị draft, có thể phát hành ngay, ẩn/hiện hoặc xóa mềm/khôi phục bài; không có bước duyệt riêng của Learn. Hidden không đọc trực tiếp nhưng vẫn là nguồn RAG hợp lệ; Deleted bị loại khỏi RAG. Video dùng provider allowlist với fallback link/mô tả khi không embed được. Thiết kế chi tiết, màu, font, motion và fallback nằm trong [đặc tả UX web](fire3d-web-ux-design.md).

**Thư viện hỗ trợ Organization** gồm template kịch bản tùy chọn, bộ tiêu chí chấm mẫu và danh mục thiết bị game đã được runtime hỗ trợ. PlatformAdmin duy trì các nội dung chuẩn; OrganizationUser dùng để soạn/cấu hình bài trong khu quản lý đã đăng nhập. Thư viện này tách khỏi **Learn công khai** trên web: bài viết, mẹo và video cho mọi người đọc không cần đăng nhập; lưu bài/hỏi AI cần đăng nhập. Learn giữ quy trình biên tập hiện tại và không có bước duyệt bài riêng. Mode Learn trong Unity là trải nghiệm làm quen không gian, không phải blog. IFC, mô hình và kịch bản riêng của Organization không tự được chia sẻ vào thư viện.

## Workflow

1. `OrganizationUser` tạo Building, tải IFC vào vùng lưu trữ riêng; có thể chỉnh thử trước khi mua dịch vụ trong hạn mức thử do Admin cấu hình.
2. Worker kiểm tra hash/định dạng, dùng Python/IfcOpenShell/IfcConvert để trích xuất, dùng Blender script để tối ưu geometry và tạo preview/issue.
3. Unity build worker dùng asset runtime đã chuẩn bị để tạo collider, NavMesh, liên kết tầng và content package; không dựng thủ công từng tòa.
4. QA kiểm tra floor, cửa, cầu thang, exit, liên kết liên tầng, route, collider, budget package và mã đối tượng. Revision chuyển `ReadyForScenario` hoặc `NeedsFix`.
5. Organization tự soạn hoặc dùng template tùy chọn, có thể kết hợp mục tiêu sơ tán, nhận biết nguy cơ, dùng thiết bị và hỗ trợ người khác trong capability runtime. Admin cung cấp tiêu chí mẫu; Organization điều chỉnh rồi gửi duyệt cùng kịch bản. PlatformAdmin duyệt mọi phiên bản trước phát hành hoặc từ chối kèm lý do. Sửa nội dung/rubric phải tạo phiên bản mới và gửi duyệt lại. IFC QA/ConfirmForTraining là readiness kỹ thuật, không thay bước duyệt nội dung; release chỉ publish khi cả hai đạt. Phiên và kết quả cũ giữ phiên bản đã pin.
6. OrganizationUser có thể chạy thử riêng bằng Mobile/Unity trong hạn mức thử. Playtest không đi qua QR Trainee và không tính learner analytics.
7. ConfirmForTraining ghi readiness kỹ thuật theo revision/version; PlatformAdmin phải duyệt đúng phiên bản nội dung/rubric trước publish. Xác nhận một bài không khóa geometry dùng chung.
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
- Backend C#/ASP.NET Core trên .NET xác minh email/password hoặc Firebase Google ID token, ánh xạ role/tenant, quản lý hồ sơ, lifecycle revision/release/training, session, audit và URL S3 ngắn hạn. Mailgun gửi OTP đăng ký và thư reset mật khẩu; FCM chỉ gửi push.
- OneShield thuộc hệ thống OnePortal của iNET là lớp edge/bảo vệ phía trước Nginx; Nginx là reverse proxy đã chốt trước API và client gọi AI qua backend. OneShield không thay thế authorization của .NET/PostgreSQL. Chi tiết triển khai theo mục 14.1–14.2 của [technology](fire-evacuation-training-technology.md); cấu hình edge/reverse proxy là kiến trúc đích chưa triển khai.
- BE quản lý đăng nhập email/password; Firebase Authentication chỉ xác minh Google Sign-In; FCM cung cấp push notification. Authorization nghiệp vụ vẫn thuộc backend và PostgreSQL, không thuộc client hoặc custom claim đơn lẻ.
- Supabase cung cấp managed PostgreSQL; `pgvector` lưu embedding/index của RAG. Supabase Auth không nằm trong stack đã chọn.
- AI/RAG là service Python/FastAPI riêng trên Azure; Container Apps là phương án triển khai đề xuất. IFC/Blender và Unity build là worker độc lập nhận job bền vững. Worker tạo facts/artifact/QA nhưng không ghi billing, entitlement hoặc publish.
- Redis là kiến trúc đích cho cache-aside và Redis Streams sau transactional outbox. Dispatcher/consumer có retry và dedup qua PostgreSQL; Redis không là nguồn quyền, quota, billing, session hay kết quả học tập. FE/Mobile chỉ gọi API qua OneShield/OnePortal → Nginx và không kết nối Redis trực tiếp.
- AI service thực hiện ingestion/retrieval RAG qua `pgvector`; backend .NET kiểm tra identity, tenant, quyền bài và quota trả trước và ghi usage kỹ thuật thành ledger. Client production không gọi AI service trực tiếp.
- AWS S3 lưu raw IFC riêng tư, manifest và content package bất biến.
- React Native/Expo xử lý local email/password hoặc Google Sign-In, QR, danh sách bài, download/cache/verify, kiểm tra dịch vụ, FCM và handoff qua native Android bridge; Unity thực hiện scene, hazard surrogate, routing, hành vi tương tác và kết quả training.

LLM production sẽ chọn **một** trong OpenAI API hoặc Google Gemini API (cấu hình qua Google AI Studio) sau đánh giá. Azure đã được chọn cho AI/RAG service; compute cho BE, IFC worker và Unity worker, cùng SKU/region/cost, vẫn là quyết định mở.

## Mô hình thương mại và AI

Gói từng Building có thời hạn 6 hoặc 12 tháng, gộp phí game, hạn mức người và quota AI. Hạn mức đếm Trainee khác nhau theo mã tài khoản đã start game tại Building trong kỳ; đăng nhập, xem bài, preparation và Organization playtest không tính suất. Chơi lại/nhiều kịch bản cùng tòa trong kỳ chỉ một suất; tòa khác tính riêng. Hết suất chặn người mới, người đã tính suất vẫn chơi lại trong quyền/dịch vụ còn hợp lệ; Organization nâng cấp gói nhiều người hơn. Kỳ gia hạn mới tính hạn mức theo kỳ mới. Giá, các mức người và cách tính nâng cấp giữa kỳ chưa chốt.

Một Organization quản lý nhiều Building, mỗi tòa có tên/địa chỉ trước quotation. Báo giá có dòng riêng từng tòa, snapshot gói, hạn mức/quota và giá/điều khoản; payment cấp entitlement từng dòng đúng một lần. Discount Admin cấu hình, nhắc hạn trước 5 ngày và PayOS xác thực webhook giữ nguyên. Hết hạn chặn publish/session mới, cho phiên đã start hoàn tất.

Quota AI đi kèm các Building cộng chung cho Organization; hết quota phải mua thêm và thanh toán trước khi tiếp tục dùng AI tính phí. Không tự cho dùng vượt quota rồi đối soát cuối kỳ. Trainee giữ quota ngày miễn phí riêng, không trừ quỹ Organization. Đơn vị/lượng quota, hiệu lực và xử lý quota còn dư chưa chốt. Reserve/settle và retry phải chống trừ/cấp quota trùng; timeout reconcile bằng request ID trước khi hoàn hoặc gọi lại.

AI Organization hỗ trợ draft thuộc mình và BIM facts được cấp quyền; không tự sửa editor/publish. AI Trainee giải thích bài đã được Admin duyệt/phát hành có quyền chơi và kết quả của mình ngoài lượt đánh giá, cùng nguồn Learn/Common hợp lệ; không đọc kho riêng hoặc draft doanh nghiệp.

Trainee tự chọn đọc Learn/blog, Learn trong Unity, Guided Drill hoặc vào Assessment ngay; không có prerequisite học/luyện. Assessment giảm/tắt gợi ý, chấm đạt/chưa đạt theo rubric đã duyệt và trả lý do/debrief. Lưu từng lần làm; thi lại không giới hạn và không bắt buộc luyện lại. Hoàn thành session không tự đồng nghĩa đạt; lỗi, hủy và chưa sync phải phân biệt với kết quả hợp lệ. Không cấp chứng nhận, không curriculum/module/sprint. Tiêu chí bắt buộc/tùy chọn, trọng số, ngưỡng điểm và lỗi khiến chưa đạt cần chốt theo từng loại bài, chưa hard-code con số.

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
| Giá gói 6/12 tháng, mức người, quota AI đi kèm/mua thêm và hạn mức Trial | UI billing, entitlement, quota trả trước | Payment/quota production |
| Redis provider/version, region, cache TTL/eviction, Streams retention và outbox recovery window | Retry, replay, chi phí, tải database và khả năng phục hồi | Trước triển khai event/cache production |
| OneShield/OnePortal plan/SKU, DNS ownership, TLS termination, WAF/rate limits, logging, SLA, region, cost và failover | Edge protection, ingress, observability và chi phí vận hành | Trước public production ingress |
| Đơn vị/hiệu lực/rollover quota AI, hoàn tiền/hủy; phí và thời hạn nâng cấp giữa kỳ | Mua thêm, provisioning và dữ liệu lịch sử | Billing lifecycle |
| Catalog runtime ưu tiên; tiêu chí, trọng số, ngưỡng và lỗi khiến chưa đạt | Thư viện Organization, editor, scoring và review | Runtime authoring |
| Bộ IFC, Android mục tiêu và benchmark | QA support matrix, package budget | IFC/Mobile release |
| Unity project/build worker, LLM/embedding, Azure SKU/region và compute cho BE/worker | Toolchain, vector dimension, chi phí và vận hành | Production deployment |

Đây là bảng nguồn chính cho các mục chưa chốt; không trình bày các lựa chọn này như đã triển khai.

## Ranh giới service và nhất quán dữ liệu

`.NET core` là API nghiệp vụ duy nhất cho client và sở hữu identity, tenant, payment, Building entitlement, quota/usage, scenario, session và dashboard. AI/RAG FastAPI chạy riêng trên Azure; Container Apps chỉ là phương án triển khai đề xuất. IFC/Blender và Unity Editor là worker riêng nhận job. Notification và reconcile vẫn là background task của BE cho tới khi có nhu cầu scale độc lập được đo bằng benchmark.

Database dùng một Supabase PostgreSQL + `pgvector`; S3 giữ IFC, manifest và package lớn. PostgreSQL giữ Learn post/version, situation, bookmark và nguồn; `knowledge_sources/chunks` được dùng lại cho citation/RAG. `ai_requests` là nguồn trạng thái/kết quả kỹ thuật; reservation allocations và prepaid grants là nguồn quota; `integration_outbox_events` và `integration_event_consumptions` là nguồn giao/replay/dedup event. Publish/hide/show Learn phát `PlatformCacheInvalidation` trong cùng transaction với audit/state, sau đó dispatcher gửi; Redis không trở thành nguồn công khai hay nguồn RAG. Tenant enqueue chỉ nhận `ProcessingJobRequested` schema `1` qua entry point backend và suy tenant từ aggregate; system event chỉ nhận allowlist `SystemNotification`/`PlatformCacheInvalidation` schema `1` qua entry point/executor riêng; `ProcessingJobRequeue` chỉ do requeue gate tạo. Outbox bắt đầu `Pending`, khóa identity/payload/hash sau enqueue và dùng dispatcher lease riêng; worker claim attempt/lease riêng qua backend, không nhận lease worker từ Redis message. Consumer kiểm tra envelope/receipt trước tác động, ghi receipt cùng transaction với tác động rồi mới ACK. ACID chỉ áp dụng trong transaction PostgreSQL: quota reserve, payment provenance, provisioning, outbox và idempotency phải được cập nhật nguyên tử trong transaction ngắn. Không giữ transaction khi chờ LLM, PayOS, S3, Redis hoặc worker. Redis mất thì outbox/cache fallback xử lý theo contract; không tuyên bố transaction ACID xuyên Azure, S3, Redis và PayOS.

Khi nguồn có thẩm quyền không khả dụng, payment/quota/publish/start mới bị từ chối hoặc chờ reconcile; phiên đã bắt đầu được tiếp tục offline và sync sau. Đây là chính sách nhất quán theo capability, không gắn toàn hệ thống bằng nhãn CAP “CP” hoặc “AP”.

Trong SQL thiết kế hiện hành, compatibility của publish/start/playtest phải fail-closed; AI period trả sau là phần SQL cũ chưa đồng bộ; payment mới phải cấp quota trả trước đúng một lần; AI request được authorize ngay khi INSERT; và processing worker dùng logical job/input hash/current attempt/lease fencing. Các invariant này là thiết kế đích, chưa phải kết quả chạy database. Acceptance phải bao gồm tranh chấp lease, retry idempotency, payment reconcile và kết quả stale.

Hardening giữ policy/result/artifact/package bất biến, pin provenance, worker lease/idempotency và runtime compatibility. AI quota reserve/settle phải khóa theo thứ tự ổn định và không giữ transaction khi gọi provider; v7 bỏ lifecycle period/close trả sau khỏi product path.

Đợt sửa recovery bổ sung các đường ghi có kiểm soát: preparation gate xác minh identity/package provenance trước khi tạo phiên nhưng không cấp quyền start; `record_session_event`/`complete_training_session` và `complete_playtest_session` ghi nhận retry sau gameplay bằng key/hash mà không kiểm tra lại entitlement hoặc trạng thái active hiện tại. Worker đăng ký artifact/validation/issues qua `register_processing_output` theo lease hiện hành; v7 reserve/settle quota trả trước thay period invoice. Đây vẫn là SQL/Docs thiết kế, chưa chạy migration hoặc kiểm thử concurrency/quyền/recovery.

## Tài liệu liên quan

- [Yêu cầu dự án](fire_evacuation_requirements.md)
- [Yêu cầu và phase](fire_evacuation_requirements.md)
- [Workflow](fire-evacuation-training-workflows.md)
- [Kiến trúc công nghệ](fire-evacuation-training-technology.md)
- [Thiết kế RAG BIM hỗ trợ gợi ý PCCC](fire_evacuation_bim_rag_pccc.md)
