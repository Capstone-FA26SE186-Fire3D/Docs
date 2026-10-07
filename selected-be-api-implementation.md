# Hồ sơ triển khai BE: Building, IFC, authoring, playtest, release và support

Requirements/workflow/schema v7 tiếp tục là đích nghiệp vụ; tài liệu này ghi lựa chọn triển khai của đợt API được chọn, không tuyên bố toàn bộ v7 hoặc deployment hoàn tất.

## Transport và worker

Đợt này dùng PostgreSQL transactional outbox → HTTP worker có machine authentication riêng, không dùng Redis. Redis Streams trong kiến trúc đích là phương án transport khác; các invariant receipt-before-ACK, canonical SHA-256/schema1, lease/attempt fencing, provenance và retry vẫn bắt buộc. URL worker do deployment cấu hình, không nhận từ client; machine không có DML trực tiếp. Dispatcher mặc định tắt nếu chưa cấu hình. Nghiệm thu bằng fake HTTP worker, chưa có repo/toolchain IFC/Blender/Unity thật.

## Chuỗi tác giả và readiness

Bound upload intent pin actor/tenant/revision/key/size/hash và source immutable đã xác minh. Scenario version/rubric/learner fields là snapshot bất biến; structural validation không thay geometry/package QA. ConfirmForTraining attests đúng revision–scenarioVersion–validationRun–annotation/artifact của current accepted attempt; technical rejection không thay approval nội dung.

Submit pin server content/rubric hashes; chỉ active PlatformAdmin approve/reject đúng hash, rejection cần reason. Legacy version không tự có approval. Built release chỉ dùng accepted ReleasePackage/manifest, exact confirmation và Approved content/rubric; server derive package metadata, legacy input chỉ được khớp server. Built/package/Training/receipt/audit atomic; Built không chứng minh Unity thật. Publish tiếp tục bị chặn trong đợt này.

## Playtest và Building access

OrganizationUser owner prepare đúng một draft snapshot hoặc immutable version; pin package/run/manifest/hash/compatibility mà không cấp entitlement/grant hoặc tiêu thụ Trial. Start recheck live family/lifecycle/tenant/runtime/exact Building entitlement; Trial consumption hoặc Active paid entitlement cùng receipt/audit; riêng purpose/audience5-minute grant. Không auto seed Trial, không coi playtest là learner start/analytics.

Building mặc định Private; visibility/code change tăng access revision, invalidate grant cũ. Random high-entropy code chỉ trả plaintext lúc rotate, DB chỉ lưu SHA-256; không nhận mã yếu do user chọn. Participation grant gắn Trainee account và revision; không tạo tenant membership. Public cũng cần login. Trainee list chỉ Active Training có Published release/pinned Approved review và current Building access; list không cấp learner seat/start. Learner start/sync/result và canonical Building QR vẫn backlog.

## Feedback/support

User chỉ đọc tài nguyên do mình tạo; admin filter platform. Create/message bắt buộc Idempotency-Key, canonical receipt theo actor/operation/resource/input; cùng input replay, khác input409. PATCH dùng If-Match, detail trả ETag; list/page message mặc định20/max100. Message append-only, Closed cần reopen trước message mới. Mutation/receipt/audit atomic, audit tenant lấy từ resource. Không attachment/rich HTML/email/push hỗ trợ trong đợt này.

## Nghiệm thu và rollout

BE có source/HTTP/actual-migration-history PostgreSQL tests với runtime roles hạn chế và provider/worker fake. Hai migration mới release/access và support phải triển khai trước binary; chưa áp Supabase ở Task7–9. Các migration Task1–6 đã có rollout schema riêng, không dùng đó để chứng minh binary hoặc provider thật. Không reset/backfill fabricated readiness/approval/provenance.

Đích ngoài phạm vi: publish hoàn chỉnh, learner start/heartbeat/offline sync/result, Library/Learn/AI/billing v7, training analytics, real IFC/Blender/Unity pipeline. PayOS GET200 DTO metadata thay đổi trong source; không đổi thanh toán. Auth/OTP/Google/Avatar giữ luồng hiện có.
