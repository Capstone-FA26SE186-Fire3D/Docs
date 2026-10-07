# Hồ sơ triển khai BE: Building, IFC, authoring, playtest, release và support

Requirements/workflow/schema v7 tiếp tục là đích nghiệp vụ; tài liệu này ghi lựa chọn triển khai của đợt API được chọn, không tuyên bố toàn bộ v7 hoặc deployment hoàn tất.

## Transport và worker

BE giữ Http làm mặc định và có tùy chọn RedisStreams cho IFC/package-build: PostgreSQL job/outbox → publisher → Redis → BE bridge → HTTP worker có machine authentication riêng. PostgreSQL giữ event/replay và durable handoff receipt; Redis không thay outbox. Các invariant receipt-before-ACK, canonical SHA-256/schema1, lease/attempt fencing, provenance và retry vẫn bắt buộc. URL worker do deployment cấu hình, không nhận từ client; machine không có DML trực tiếp. Dispatcher mặc định tắt nếu chưa cấu hình. Nghiệm thu bằng fake HTTP worker, chưa có repo/toolchain IFC/Blender/Unity thật.

## Chuỗi tác giả và readiness

Bound upload intent pin actor/tenant/revision/key/size/hash và source immutable đã xác minh. Receipt replay đối chiếu Building ở SQL, giữ nguyên canonical hash cũ. Object anchors chỉ dùng current Geometry attempt Succeeded có matching validation Passed không Error/Critical; worker Succeeded không đồng nghĩa QA Passed. Scenario version/rubric/learner fields là snapshot bất biến; structural validation không thay geometry/package QA. ConfirmForTraining attests đúng revision–scenarioVersion–validationRun–annotation/artifact của current accepted attempt; technical rejection không thay approval nội dung.

Submit pin server content/rubric hashes; chỉ active PlatformAdmin approve/reject đúng hash, rejection cần reason. Legacy version không tự có approval. Built release chỉ dùng accepted ReleasePackage/manifest, exact confirmation và Approved content/rubric; server derive package metadata, legacy input chỉ được khớp server. Built/package/Training/receipt/audit atomic; Built không chứng minh Unity thật. Publish tiếp tục bị chặn trong đợt này.

## Playtest và Building access

OrganizationUser owner prepare đúng một draft snapshot hoặc immutable version; pin package/run/manifest/hash/compatibility mà không cấp entitlement/grant hoặc tiêu thụ Trial. Start recheck live family/lifecycle/tenant/runtime/exact Building entitlement; Trial consumption hoặc Active paid entitlement cùng receipt/audit; riêng purpose/audience5-minute grant. Không auto seed Trial, không coi playtest là learner start/analytics.

Building mặc định Private; visibility/code change tăng access revision, invalidate grant cũ. Random high-entropy code chỉ trả plaintext lúc rotate, DB chỉ lưu SHA-256; không nhận mã yếu do user chọn. Participation grant gắn Trainee account và revision; không tạo tenant membership. Public cũng cần login. Trainee list chỉ Active Training có Published release/pinned Approved review và current Building access; list không cấp learner seat/start. Learner start/sync/result và canonical Building QR vẫn backlog.

## Feedback/support

User chỉ đọc tài nguyên do mình tạo; admin filter platform. Create/message bắt buộc Idempotency-Key, canonical receipt theo actor/operation/resource/input; cùng input replay, khác input409. PATCH dùng If-Match, detail trả ETag; list/page message mặc định20/max100. Message append-only, Closed cần reopen trước message mới. Mutation/receipt/audit atomic, audit tenant lấy từ resource. Không attachment/rich HTML/email/push hỗ trợ trong đợt này.

## Nghiệm thu và rollout

BE có source/HTTP/actual-migration-history PostgreSQL tests với runtime roles hạn chế và provider/worker fake. Migration release/access, support và repair ACL đã áp Supabase ngày07/10/2026; áp tiếp forward repair20261007130000/20261007140000 cho receipt scope và geometry QA. Read-only postcheck xác nhận history/owner/ACL, giữ8user/6organization/2Building. Schema phải có trước binary khớp; không dùng rollout schema để chứng minh binary hoặc provider thật. Regression cuối API đã chọn36pass, IFC phù hợp105pass, build0warning/error; ba nhóm Docker-only legacy chưa chạy trong lượt này. Không reset/backfill fabricated readiness/approval/provenance.

Đích ngoài phạm vi: publish hoàn chỉnh, learner start/heartbeat/offline sync/result, Library/Learn/AI/billing v7, training analytics, real IFC/Blender/Unity pipeline. PayOS GET200 DTO metadata thay đổi trong source; không đổi thanh toán. Auth/OTP/Google/Avatar giữ luồng hiện có.

## Redis processing implementation — 07/10/2026

Transport tùy chọn chỉ áp dụng IFC/package-build, không mở rộng sang auth cache/rate limit hoặc Hangfire/BullMQ. XADD ngoài transaction, mark Published theo lease token; Published chỉ là gửi Redis. Bridge đối chiếu toàn bộ envelope/hash/tenant với PostgreSQL, gọi HTTPS worker cấu hình sẵn. Claim/attempt/delivery receipt/consumption receipt commit atomic rồi mới ACK; ACK không chứng minh IFC/package thành công.

Stream `fet3d:{environment}:processing`, group `fet3d-processing-bridge-v1`; instance consumer riêng. Reclaim pending idle60s có cursor. Reconciler30s replay Published thiếu receipt sau5min bằng cùng event key, bỏ job terminal và dùng backoff30s–30min/tối đa10lần. Receipt replay không phụ thuộc lease của attempt cũ; attempt hết hạn được recovery gate fence và requeue riêng.

Retention7ngày chỉ xóa message đã bàn giao sau kiểm PostgreSQL và Redis atomic: đã đọc, không pending, đúng group duy nhất. Không TTL toàn stream/XTRIM bất chấp pending, không xóa outbox/receipt. Sai schema/hash/scope giữ diagnostic để vận hành xử lý. Connection singleton reconnect/TLS; Redis không sẵn sàng không làm process202 thành thành công hay chặn auth.

Ba migration additive Delivery/Consumption/Recovery được kiểm trên PostgreSQL disposable, gồm runtime/executor giới hạn quyền; chưa áp Supabase trong đợt Redis. HTTP worker giả lập và Redis Docker chỉ chứng minh BE transport/recovery. Mặc định Http/consumer disabled đến khi migration/grants và dev smoke đạt. Azure TCP/TLS, HA/AOF/NoEviction và worker IFC/Unity thật còn cần nghiệm thu; không suy pass Docker thành deployment hoàn tất. Rollback giữ và drain backlog Redis trước khi chuyển Http, không xóa stream.

Azure dev smoke ngày07/10 chưa tới bước XADD: TCP endpoint port10000 không kết nối được từ máy test. Không xác nhận credential/TLS, không thay cấu hình Azure. Restart Redis Docker với AOF giữ stream/group test; kết quả này không chứng minh HA hoặc reconnect trong lúc xử lý trên Azure.

Regression BE cuối: Auth452passed/0failed/0skipped (19case Redis), IFC110passed/0failed/0skipped gồm Docker legacy, build0warning/error. Một lượt Auth trước có test PayOS partial provisioning fail; test riêng và lượt toàn bộ cuối pass, không sửa PayOS để ép xanh. Kết quả này thuộc source/container/worker giả lập, không phải bằng chứng migration Supabase hay deployment Azure.
