# Fire Evacuation Training 3D — Workflows

**Đồng bộ thiết kế ngày 03/10/2026:** yêu cầu nghiệp vụ, SQL design v7, ERD Markdown và Word ý tưởng đã được đồng bộ. Tên bảng/function là contract thiết kế, không chứng minh migration/API/runtime đã triển khai. [Requirements](fire_evacuation_requirements.md) là nguồn yêu cầu sản phẩm; [ghi chú quyết định](phan_tich_khoang_cach_va_quyet_dinh_nghiep_vu.md) ghi lại lựa chọn và chi tiết còn mở.

## 1. Nguyên tắc chung

- Có ba loại tài khoản: `PlatformAdmin`, `OrganizationUser`, `Trainee`.
- `OrganizationUser` sở hữu Building, IFC, scenario, publish, QR, analytics và billing của organization.
- IFC là source duy nhất cho pipeline mô hình. Android app được cài một lần; QR canonical cấp Building mở danh sách bài, sau đó session mới pin release/content package mà Trainee chọn.
- `ConfirmForTraining` là kiểm tra readiness cho tập huấn của đồ án, không phải chứng nhận hoặc phê duyệt PCCC.
- Luồng cốt lõi: **IFC → 3D → Unity Android → QR → Training → Result**.
- Hoạt động đánh giá chuyên môn và user study là hoạt động capstone, không tạo system role hoặc quyền duyệt hệ thống.

## 1.1. Workflow website công khai

```text
Khách mở website chung
  -> landing POV cuộn qua công trình đang cháy
  -> đọc các mốc không gian/tập huấn/kết quả
  -> chọn nhu cầu
       -> Tôi muốn tập huấn -> đăng nhập nếu cần -> Góc học tập
       -> Tôi muốn tổ chức tập huấn -> mặt cắt tòa nhà -> Dành cho tổ chức
```

1. Khách xem landing, Khám phá, Learn và Về chúng tôi mà không cần account hoặc role selection.
2. Cuộn xuống tiến và cuộn lên lùi theo camera; Three.js render presentation web và editor/preview 3D của organization, không thay Unity gameplay.
3. Nhánh tập huấn đưa khách chưa đăng nhập đến đăng nhập; Trainee đã đăng nhập vào Góc học tập. Nhánh tổ chức dẫn tới trang giới thiệu công khai; thao tác quản lý vẫn đi qua authz `OrganizationUser` và `organizationId`.
4. Learn web (bài có nguồn, hỏi AI, lưu bài) là luồng riêng với mode Learn trong Unity. Chức năng hỏi AI/lưu bài cần auth và nguồn trả lời.

**Thư viện hỗ trợ Organization** gồm template kịch bản tùy chọn, bộ tiêu chí chấm mẫu và danh mục thiết bị game đã được runtime hỗ trợ. PlatformAdmin duy trì các nội dung chuẩn; OrganizationUser dùng để soạn/cấu hình bài trong khu quản lý đã đăng nhập. Thư viện này tách khỏi **Learn công khai** trên web: bài viết, mẹo và video cho mọi người đọc không cần đăng nhập; lưu bài/hỏi AI cần đăng nhập. Learn giữ quy trình biên tập hiện tại và không có bước duyệt bài riêng. Mode Learn trong Unity là trải nghiệm làm quen không gian, không phải blog. IFC, mô hình và kịch bản riêng của Organization không tự được chia sẻ vào thư viện.

### 1.2. Workflow Learn blog

```text
PlatformAdmin tạo Draft
  -> gắn situation + content blocks + nguồn
  -> chuẩn hóa/kiểm tra video provider
  -> lưu nháp hoặc publish ngay qua gate
  -> Published immutable version
  -> public API/cache/Common RAG
```

1. `PlatformAdmin` tạo `learn_post` và version Draft, chọn `Article`, `Tip` hoặc `Video`, gắn một hoặc nhiều tình huống và nguồn Common.
2. Backend kiểm tra slug/ETag, content schema và URL video. Draft có thể gắn Common source chưa Approved; publish/show mới kiểm tra source Common đã Approved. Chỉ URL YouTube/Facebook/TikTok hợp lệ theo allowlist mới được renderer xử lý; iframe, HTML hoặc script tùy ý bị từ chối.
3. `publishImmediately=true` tạo post/draft và publish trong cùng transaction; nếu false, chỉ lưu Draft. Publish version Draft qua gate cập nhật pointer và audit cùng transaction. Bản Published không được sửa tại chỗ.
4. Sửa nội dung tạo version Draft mới. Public API tiếp tục trả version Published cũ tới khi version mới được publish; hide chuyển bài sang Hidden nhưng giữ pointer, show dùng lại version cũ; delete là soft-delete giữ lịch sử nhưng loại khỏi public/RAG; restore đưa bài từng public về Hidden và bài chưa public về Unpublished.
5. Khách chỉ đọc/tìm version Published của bài đang Published. Trainee đăng nhập để bookmark và hỏi AI với `postId`/`versionId`; AI kiểm tra pointer/trạng thái tại backend, cho phép Published/Hidden hợp lệ nhưng loại Unpublished/Deleted, và chỉ truy xuất nguồn Common đã Approved.
6. Video không xem được phải có tóm tắt/link fallback. Mobile mở provider bằng trình duyệt trong thiết kế mục tiêu; hệ thống không tự tải hoặc đăng lại video.
7. Publish/hide/show ghi post, audit và `PlatformCacheInvalidation` vào PostgreSQL cùng transaction; dispatcher sau commit cập nhật Redis/index. Redis/indexing lỗi không đổi trạng thái PostgreSQL và phải retry/dedup được; event cũ không ghi đè index mới.

## 2. Workflow quản trị nền tảng

PlatformAdmin có hai khu riêng: thư viện hỗ trợ Organization (template, rubric mẫu, thiết bị) và biên tập Learn công khai. Admin nhận/duyệt mọi phiên bản kịch bản cùng rubric; sửa phải duyệt lại. Không áp dụng bước duyệt kịch bản vào Learn, vốn giữ workflow editorial ở mục 1.2.

1. Người dùng đăng nhập bằng email/password do BE xác minh hoặc Google Sign-In qua Firebase; backend ánh xạ Firebase UID (khi có) sang bản ghi FET3D. `PlatformAdmin` tạo organization và gán ba loại tài khoản nghiệp vụ cần thiết. Mailgun phục vụ OTP đăng ký và reset password, FCM chỉ phục vụ push.
2. Hệ thống gắn `OrganizationUser` với phạm vi `organizationId` để ownership. Trainee là tài khoản đăng nhập; tòa public tham gia trực tiếp, private cần mã chung trước khi nhận bài/package được phép; session participation pin bài đã chọn và không biến Trainee thành thành viên của organization. Firebase chỉ xác thực Google identity, không quyết định quyền nghiệp vụ.
3. `PlatformAdmin` khóa/mở khóa tài khoản, xem health, audit, support và billing aggregate cấp nền tảng.
   Quản trị Learn theo workflow riêng: tạo/sửa draft, phát hành ngay hoặc lưu nháp, ẩn/hiện bài; thao tác editorial được audit và không trao quyền CMS cho `OrganizationUser` hay `Trainee`.
4. API từ chối request ownership không có tài khoản đã xác thực hoặc không khớp `organizationId`; QR resolve cần identity để mở danh sách, còn explicit session start mới cần entitlement Building, bài Published và kiểm tra online.
5. Mobile đăng ký/rotate token FCM theo installation. Backend xóa hoặc vô hiệu hóa token không hợp lệ; token FCM không thay thế password session hoặc Firebase ID token.

### 2.1. Đăng ký local: form → OTP → account → login

Đối chiếu [BE authentication](../BE/docs/authentication.md) và [API guide](../BE/docs/api-docs.md), BE main `0683d90` ngày 03/10/2026. Đây là hành vi source hiện tại; nghiệm thu client và gửi Mailgun thật được kiểm tra riêng.

1. Trainee nhập email/username/password/confirmPassword; OrganizationUser nhập email/password/confirmPassword và tên/địa chỉ/điện thoại organization. Client giữ form/password trong bộ nhớ rồi chuyển sang OTP. Username Trainee lowercase, unique, pattern `[a-z0-9._-]{3,30}`; local login dùng email/password. Organization register chưa nhận username cá nhân; bổ sung qua profile sau.
2. `POST /api/auth/registration/request-otp` nhận email. Email trim/lowercase đã có account, kể cả inactive/deleted, trả `409 EMAIL_EXISTS` và `errors.email`, không enqueue. Email mới trả 202, lưu challenge/job, chưa tạo user/organization. Mailgun worker gửi mã; 202 chưa chứng minh delivered.
3. OTP sáu số giữ số 0 đầu, hạn 10 phút; verify sai đủ 5 lần vô hiệu challenge. `POST /api/auth/resend-verification` trong cooldown 60 giây trả 202 nhưng không tạo job mới; sau cooldown phát mã mới và vô hiệu mã/proof cũ. Hai route gửi mã chung quota 5/email/giờ, 20/IP/giờ; vượt trả `429 OTP_RATE_LIMITED` và `Retry-After`.
4. Nút “Xác thực và đăng ký” gọi `POST /api/auth/registration/verify-otp` với email/otp để nhận registrationToken/expiresAt, rồi gửi toàn bộ form + registrationToken tới `/api/auth/register/trainee` hoặc `/api/auth/register/organization`. Proof gắn email, hạn 15 phút, dùng một lần; verify chưa tạo account hay kiểm password. `/api/auth/register` là alias Trainee.
5. Register validate form trước khi consume proof. Form sai trả 400 theo field và giữ proof; proof thiếu/sai/hết hạn/đã dùng trả `400 EMAIL_VERIFICATION_REQUIRED`; email/username trùng trả 409. BE consume proof, tạo account đã verified, organization/owner nếu có và audit trong cùng transaction. Trả `201 AccountResponse`, chưa cấp JWT; gọi login tiếp theo. Retry không được tạo account thứ hai.
6. Đổi email bỏ proof và xác minh lại; reload mất form thì quay về form. Không lưu password trong URL/web storage. `/check-email/` BE là demo OTP/proof; `/api/auth/verify-email` deprecated chỉ hỗ trợ account pending legacy. Game start không có username gate.

```mermaid
sequenceDiagram
    participant Client as Web/Mobile
    participant BE
    participant DB as PostgreSQL
    participant Mail as Mailgun worker
    Client->>Client: Nhập form và giữ trong bộ nhớ
    Client->>BE: request-otp(email)
    BE->>DB: Kiểm email, cooldown/quota; lưu challenge/job
    BE-->>Client: 202 hoặc 409 EMAIL_EXISTS
    Mail->>DB: Claim job còn hiệu lực
    Mail->>Mail: Gửi OTP
    Client->>BE: verify-otp(email, otp)
    BE-->>Client: registrationToken + expiresAt
    Client->>BE: register(form + registrationToken)
    BE->>DB: Validate; consume proof + account/organization + audit atomic
    BE-->>Client: 201 AccountResponse
    Client->>BE: login(email, password)
    BE-->>Client: accessToken + refreshToken + user
```

### 2.2. Login, refresh và logout

1. `POST /api/auth/login` nhận email/password; kiểm hash, account/organization và pending legacy. Sai credential trả 401; account/organization bị khóa trả 403. Thành công tạo family, lưu refresh hash và audit atomic; response gồm accessToken/refreshToken/user, không có expiresAt. TTL theo cấu hình Jwt.
2. API bảo vệ nhận Bearer Fire3D; middleware kiểm JWT và trạng thái account/organization/role/tenant/family trong DB. Access token còn hạn vẫn bị từ chối khi family revoked.
3. `POST /api/auth/refresh` nhận refreshToken mới nhất, không cần Bearer; rotation giữ hạn tuyệt đối family. Replay token consume/revoke thu hồi family và trả `401 INVALID_REFRESH_TOKEN`. Client đồng bộ refresh và thay cả hai token. Quota 10/IP/phút mỗi instance; vượt trả `429 AUTH_REFRESH_RATE_LIMITED` cùng Retry-After.
4. `POST /api/auth/logout` dùng Bearer, không body, trả 204 và revoke family hiện tại. `/api/auth/logout-all` revoke mọi family, tắt push bindings và audit atomic; client xóa token, login mới và đăng ký device lại khi cần push.

### 2.3. Google và hồ sơ

`POST /api/auth/login-firebase` nhận Firebase ID token dạng JSON string. UID đã link trả `200 Authenticated` kèm authentication; UID/email mới trả `200 OnboardingRequired`, chưa tạo account; email local trùng trả `409 ACCOUNT_LINK_REQUIRED`. Chưa có API/proof hoàn tất onboarding hoặc explicit link. Yêu cầu đích vẫn là chọn Trainee/OrganizationUser cho identity mới và chứng minh local account trước khi link; không cấp PlatformAdmin hoặc tự gia nhập tenant.

`GET/PATCH /api/auth/me` sửa fullName/username/dob/gender/phoneNumber; `GET/PATCH /api/organizations/me` sửa hồ sơ organization. GET trả ETag, PATCH cần If-Match; không đổi role/tenant/email/status. Avatar dùng `/api/me/avatar` upload-intent/upload/complete/GET/delete với private S3; complete/upload/delete cần If-Match. Device dùng Bearer và X-Installation-Key, không dùng FCM token để login.

### 2.4. Forgot/reset và change password

`POST /api/auth/forgot-password` nhận email, trả 202 chung; chỉ account hoạt động có password local được enqueue reset. Worker Mailgun gửi link token 64 ký tự hex, hạn 30 phút, dùng một lần. `POST /api/auth/reset-password` nhận token/newPassword, không cần Bearer; `POST /api/auth/change-password` cần Bearer và currentPassword/newPassword, không gửi email. Password mới 6–128 ký tự, không chỉ whitespace, không tự trim. Google-only không dùng reset để thêm password local.

BE source đã khóa user, đổi hash, vô hiệu reset token, revoke family và audit trong transaction; lỗi rollback toàn bộ. Thành công trả 204, không cấp JWT mới; client login lại. Nghiệm thu DB/provider được xác nhận riêng.

### 2.5. Tiêu chí nghiệm thu auth

| Tình huống | Kết quả cần kiểm chứng |
| --- | --- |
| OTP hết hạn, sai 5 lần, gửi lại và vượt quota | Không verify challenge vô hiệu; mã/proof cũ bị chặn sau resend; 429 có Retry-After |
| Email trùng khác casing/whitespace, inactive/deleted | 409 EMAIL_EXISTS theo errors.email, không enqueue OTP; forgot vẫn trả 202 chung |
| Form sai, proof dùng lại, đăng ký Organization lỗi DB/audit | Form sai giữ proof; proof dùng rồi không tạo account mới; consume/owner/organization/audit rollback cùng nhau |
| Refresh đồng thời/replay và logout/logout-all | Client đồng bộ refresh; token replay revoke family; access JWT cũ bị từ chối; logout-all tắt push bindings |
| Reset hết hạn/dùng lại, change sai currentPassword, race login/reset | Không đổi hash sai; commit revoke phiên; lỗi DB/audit rollback; không cấp phiên từ password cũ sau reset commit |
| Google linked/new/local-email collision | Linked nhận phiên đúng role/tenant; hai nhánh còn lại không tự tạo/link account hoặc coi là đã login |
| Profile/avatar ETag và client reload/đổi email | Mutation thiếu ETag trả 428, stale trả 412; không sửa role/tenant; reload quay form, đổi email phải verify lại |

Đây là ca nghiệm thu cho triển khai/tích hợp; đợt đồng bộ Markdown chỉ kiểm tra contract, liên kết và định dạng, không chạy lại provider/DB/client tests.

## 3. Workflow Building và IFC

```text
OrganizationUser tạo Building
  -> tải IFC (có thể trong quota thử)
  -> validate MIME/kích thước/hash và lưu private
  -> Python/IfcOpenShell/IfcConvert parse IFC
  -> Blender script tối ưu geometry/LOD/material
  -> tạo preview GLB + facts + floor graph + NavMesh source + hazard grid
  -> Unity build worker tạo collider/package input
  -> connectivity/performance QA + issue list
  -> revision ReadyForScenario hoặc NeedsFix
```

1. `OrganizationUser` tạo Building với metadata cần cho tập huấn.
2. `OrganizationUser` tải IFC của Building. Backend đưa source vào vùng private, kiểm tra hash và tạo revision.
3. Worker Python đọc spatial hierarchy, tách tầng, giữ GlobalId/provenance, tạo geometry/GLB, semantic graph, door/stair/exit mapping và manifest nháp.
4. Blender script giảm polygon/gộp vật liệu theo quy tắc đã kiểm thử; Unity build worker dùng asset input để tạo collider, NavMesh/link tầng và runtime package. Chủ tòa không cần chạy các công cụ này.
5. QA kiểm tra unit, origin, floor order, portal liên tầng, spawn-to-exit route, collision, object identity và budget package.
6. Nếu lỗi, hệ thống lưu issue, log và trạng thái `NeedsFix`. `OrganizationUser` cập nhật IFC hoặc xác nhận mapping, tạo revision mới và chạy lại pipeline.
7. Nếu đạt, revision chuyển `ReadyForScenario`. Không publish partial package hoặc source chưa qua QA.

## 4. Workflow scenario và readiness

Organization tự soạn hoặc dùng template tùy chọn, có thể kết hợp mục tiêu sơ tán, nhận biết nguy cơ, dùng thiết bị và hỗ trợ người khác trong capability runtime. Admin cung cấp tiêu chí mẫu; Organization điều chỉnh rồi gửi duyệt cùng kịch bản. PlatformAdmin duyệt mọi phiên bản trước phát hành hoặc từ chối kèm lý do. Sửa nội dung/rubric phải tạo phiên bản mới và gửi duyệt lại. IFC QA/ConfirmForTraining là readiness kỹ thuật, không thay bước duyệt nội dung; release chỉ publish khi cả hai đạt. Phiên và kết quả cũ giữ phiên bản đã pin.

```text
ReadyForScenario hoặc ConfirmedForTraining revision
  -> OrganizationUser tạo logical Scenario + editor Draft
  -> snapshot ScenarioVersion bất biến
  -> validate spawn/goal/hazard/rubric/A* weights
  -> validate candidate package + manifest
  -> checklist readiness
  -> optional Organization playtest (Trial còn quota thử hoặc Building entitlement Active)
  -> ConfirmForTraining kỹ thuật cho revision/version
  -> submit phiên bản + rubric cho PlatformAdmin
  -> Admin duyệt hoặc từ chối kèm lý do; sửa thì gửi lại
  -> readiness record của đúng ScenarioVersion
```

1. `OrganizationUser` chọn revision tương thích, tạo hoặc chọn logical `Scenario`, sau đó tạo `ScenarioDraft`; version mới không ghi đè version đã dùng.
2. OrganizationUser dùng editor Three.js để đặt/chỉnh/xóa source lửa, khói, gió, tốc độ cháy, blocked elements, bình chữa cháy, khăn, nguồn nước, spawn, mục tiêu và các tương tác runtime đã có. Draft được lưu tách khỏi geometry.
3. AI Organization có thể tạo scenario draft từ facts IFC và corpus được phép; draft chỉ là gợi ý có citation và phải được người dùng tự edit/accept.
4. Scenario ghi hazard parameters, time limit, rubric, route weights, seed, interaction config và version để replay được.
5. Hệ thống chạy validation về route, blocked edge, floor portal, object anchors, package hash, protocol/schema, runtime version và giới hạn hiệu năng.
6. OrganizationUser có thể chạy thử riêng bằng Mobile/Unity với package đã verify. Khi start, backend kiểm tra Trial còn hạn/còn quota thử hoặc entitlement Building `Active`; playtest không yêu cầu QR, không tạo learner session và không vào learner analytics. Entitlement hết hạn sau start không cắt playtest.
7. Readiness kỹ thuật được ghi bằng ConfirmForTraining đúng revision/version. Organization gửi phiên bản/rubric cho PlatformAdmin duyệt nội dung; bị từ chối thì chỉnh và gửi lại. Sửa bản đã duyệt phải tạo phiên bản mới và duyệt lại, không đổi phiên bản kết quả cũ.
8. Hệ thống audit actor, timestamp, revision, scenario/version và các validation pass/fail. QR không nằm trong checklist vì chưa có release/`Training` để bind.

`ConfirmForTraining` chỉ nói rằng package và scenario version đã sẵn sàng cho phiên tập huấn của đồ án. Nếu geometry, exit hoặc hazard baseline thay đổi thì cần revision mới; nếu chỉ đổi tham số scenario tương thích thì tạo version mới và readiness mới. Không kết quả nào trong workflow này xác nhận mức độ an toàn thực tế.

## 5. Workflow publish và QR

```text
ConfirmedForTraining revision + confirmed ScenarioVersion
  -> create immutable TrainingRelease ở Built
  -> persist manifest/content package
  -> create matching Active Training
  -> verify PlatformAdmin approval đúng ScenarioVersion/rubric
  -> verify Active Building service entitlement
  -> publish release
  -> keep/generate canonical Building QR
  -> QR resolves list of published Trainings
```

1. Từ revision `ConfirmedForTraining` và đúng scenario/version đã được action confirm, backend tạo `TrainingRelease` bất biến ở `Built`.
2. Backend persist manifest/package gồm `releaseId`, `buildingId`, `scenarioId`, `scenarioVersionId`, package hash, `protocolVersion`, schema version và `minRuntimeVersion`, rồi tạo một `Training` active khớp release/scenario/version/organization.
3. Backend kiểm tra đúng ScenarioVersion/rubric có approval của PlatformAdmin và Building có gói 6/12 tháng còn Active cho publish. Trial chỉ cấp import/editor/playtest theo quota và không đủ để publish; playtest cũng có thể start với entitlement Active. Publish bị từ chối nếu package, `Training` active hoặc entitlement chưa hợp lệ.
4. `OrganizationUser` publish release. QR canonical cấp Building được giữ ổn định; người dùng có thể in hoặc rotate vì lý do quản trị.
5. QR resolve Building/trạng thái public; danh sách bài/package private chỉ trả sau đăng nhập và xác minh mã/quyền tham gia. Khi Trainee chọn một bài, backend pin `release_id`, `training_id`, `scenario_version_id` vào session.
6. Release/Training/scenario/version/organization phải khớp nhau. Hết hạn entitlement chặn publish/session mới nhưng không làm mất QR landing; revoke QR vì quản trị là trạng thái riêng.

Quy ước sản phẩm là mỗi Building có một QR canonical ổn định. QR chỉ là mã resolve công khai; nó không chứa package, access token hoặc APK. Khi phát hành release mới, danh sách bài thay đổi nhưng QR không cần đổi; rotate/revoke chỉ là thao tác quản trị.

## 6. Workflow quét QR, download và launch

```text
QR
  -> chưa cài app: web landing/login/download app
  -> đã cài app: Mobile nhận Building, đăng nhập local hoặc Google
  -> backend resolve Building + trạng thái QR/dịch vụ
  -> public: Trainee đăng nhập; private: đăng nhập + mã tham gia
  -> trả danh sách Published Training được phép
  -> Trainee chọn bài
  -> tải/verify package còn thiếu
  -> POST /api/training/sessions (prepare + idempotency key)
  -> POST /api/training/sessions/{sessionId}/start (online quyền public/private/suất người/entitlement/QR/package/runtime check)
  -> React Native/Expo native bridge launch Unity
```

1. QR mở web nếu chưa cài app; người dùng có thể đăng ký/đăng nhập email/password hoặc Google rồi tải app và quét lại QR.
2. Mobile dùng phiên FET3D từ local email/password hoặc Google exchange; với Google, gửi Firebase ID token để backend kiểm tra. Không bắt buộc Google nếu người dùng đã có phiên local hợp lệ.
3. Backend resolve QR/status; Trainee đăng nhập, tòa private xác minh mã tham gia chung trước khi trả bài/package được phép; bước preparation chỉ kiểm tra identity, bài, QR, release/scenario và package metadata, chưa cấp quyền chơi.
4. Trainee chọn bài, Mobile nhận manifest/package URL ký ngắn hạn, tải phần còn thiếu, xác minh hash/schema/runtime rồi tạo preparation record với idempotency key.
5. Chỉ `POST /api/training/sessions/{sessionId}/start` kiểm tra quyền public/private, suất người theo Building/kỳ, entitlement Active, QR chưa revoke, release/training/scenario tương thích, package hash/schema/runtime và cấp launch grant online; không cho start mới offline dù package đã cache. Sau start, backend pin `trainingId`/`releaseId`/`scenarioId`/`qrCodeId` bất biến.
6. Native Android bridge truyền `sessionId`, manifest path, grant và protocol version cho Unity. Unity không giữ credential dài hạn và không tự chọn release.

Nếu thiết bị chưa cài Mobile app, URL/deep link của QR mở landing/trạng thái Building và dẫn tới kênh cài đặt phù hợp; người dùng quét lại sau khi cài nếu context chưa được giữ. Gameplay không chạy bằng Three.js trên trình duyệt; Three.js làm landing và editor/preview tổ chức, còn gameplay đầy đủ chạy trong Unity.

### 6.1. Handoff từ Góc học tập sang Android

1. Trainee chọn Building/bài đã publish trên web và bấm **Mở trên điện thoại**.
2. Web hiển thị QR canonical của Building; QR không tạo package, APK hoặc quyền mới.
3. Điện thoại đã cài Android app quét QR, xác thực nếu cần, xem danh sách bài, chọn bài rồi tải/verify content package và mở Unity. Điện thoại chưa cài app đi tới kênh cài đặt hợp lệ và người dùng quét lại QR sau khi cài.
4. Web không suy đoán hoặc persist trạng thái cài đặt của điện thoại. Quy tắc QR canonical, rotate/revoke và package pin giữ nguyên.

## 7. Workflow training online

Trainee tự chọn đọc Learn/blog, Learn trong Unity, Guided Drill hoặc vào Assessment ngay; không có prerequisite học/luyện. Assessment giảm/tắt gợi ý, chấm đạt/chưa đạt theo rubric đã duyệt và trả lý do/debrief. Lưu từng lần làm; thi lại không giới hạn và không bắt buộc luyện lại. Hoàn thành session không tự đồng nghĩa đạt; lỗi, hủy và chưa sync phải phân biệt với kết quả hợp lệ. Không cấp chứng nhận, không curriculum/module/sprint. Tiêu chí bắt buộc/tùy chọn, trọng số, ngưỡng điểm và lỗi khiến chưa đạt cần chốt theo từng loại bài, chưa hard-code con số.

```text
Unity load package
  -> initialize scenario/hazard surrogate/risk-aware A*
  -> learner actions + event batches
  -> complete/abort
  -> Unity returns result through native Android bridge to React Native/Expo
  -> React Native/Expo sends result to backend API
  -> backend validates and updates analytics
```

1. Unity load scene, navigation graph, hazard surrogate và luật mode từ manifest/scenario đã pin.
2. Người chơi tự chọn Learn/Guided Drill/Assessment; không cần học trước. Assessment dùng rubric đã được Admin duyệt, giảm/tắt gợi ý; debrief đạt/chưa đạt lưu theo từng lần và phiên bản bài.
3. Event có `eventId` ổn định do client tạo, sequence, session ID và schema version. Unity trả event/result qua native Android bridge về React Native/Expo; Mobile gửi dữ liệu đó lên API khi online.
4. Backend validate grant, release pin và sequence rồi đánh dấu `Completed`, `Aborted` hoặc trạng thái lỗi có lý do.
5. `Trainee` xem debrief cá nhân; `OrganizationUser` xem aggregate cơ bản.

Contract bên gửi/nhận và checklist tích hợp được mô tả tại mục 8.1 và 13 của [tài liệu kiến trúc](fire-evacuation-training-technology.md). Mobile chỉ coi kết quả đã đồng bộ khi API xác nhận chấp nhận dữ liệu.

## 8. Workflow mất mạng sau khi bắt đầu session

1. Chỉ session đã qua explicit online start và có launch grant hợp lệ mới được tiếp tục khi mất mạng.
2. Khi mất kết nối, React Native/Expo và Unity tiếp tục ghi event/result local.
3. React Native/Expo xếp event/result theo thứ tự với `eventId`/sequence, retry backoff và giữ release/scenario hash.
4. Khi có mạng, React Native/Expo gọi reconcile; backend chỉ nhận batch hợp lệ, không nhân đôi dữ liệu.
5. Nếu release bị revoke hoặc trở thành `Superseded` sau thời điểm start hợp lệ, session được giữ audit với trạng thái lịch sử thay vì bị biến mất.

## 9. Workflow NPC và hành vi runtime — thứ tự rollout

1. `OrganizationUser` cấu hình số lượng NPC giới hạn trong `ScenarioVersion`.
2. Unity khởi tạo state đơn giản (ví dụ idle, moving, blocked) theo seed của scenario.
3. NPC chỉ tác động đến trải nghiệm mô phỏng và budget hiệu năng; kết quả không diễn giải là dự báo hành vi con người thật.
4. Event có thể ghi tương tác với NPC để phục vụ debrief/analytics của đồ án.

## 10. Workflow analytics

- `Trainee unique`: số tài khoản Trainee khác nhau có ít nhất một learner session bắt đầu trong kỳ.
- `Learner plays`: số learner session đã bắt đầu; session chuẩn bị và Organization playtest không tính.
- `Active sessions`: session có heartbeat trong cửa sổ cấu hình gần nhất; đây là ước tính online, không đồng nghĩa mọi session đang tương tác.
- `Completion rate`: số session Trainee hoàn tất / số session Trainee đã bắt đầu; preparation, playtest và session chưa bắt đầu bị loại.
- `Duration`: chỉ tính session có `started_at` và `ended_at` hợp lệ. Session chưa đồng bộ được ghi riêng và chưa tính hoàn thành cho tới khi backend xác nhận.
- Đợt đầu: backend aggregate learner plays, completion, duration, route decision và modeled exposure theo Building/scenario.
- Đợt mở rộng: thêm filter thời gian, cohort comparison, export và debrief aggregate; đây vẫn là năng lực mục tiêu bản cuối.
- `Trainee` chỉ xem session của mình. `OrganizationUser` chỉ xem dữ liệu organization. `PlatformAdmin` giám sát aggregate nền tảng khi cần vận hành.
- Pass rate Assessment phải tách khỏi completion rate; điểm/đạt-chưa đạt theo rubric đã duyệt, session lỗi/hủy/chưa sync không tự coi là kết quả hợp lệ.
- Dashboard phải nhắc rõ analytics mô tả hoạt động trong mô phỏng, không phải kết luận an toàn hay chứng nhận PCCC.

## 11. Workflow dịch vụ Building, hạn mức người và quota AI

1. Organization tạo/chọn Building có tên và địa chỉ; Trial import/editor/playtest giữ hạn mức thử Admin cấu hình.
2. Chọn gói từng Building thời hạn 6 hoặc 12 tháng. Quotation nhiều dòng snapshot phí game, hạn mức người, quota AI, giá/discount, điều khoản, policy quota và thời hạn quota; mọi dữ liệu quota phải hợp lệ trước khi báo giá rời Draft. Kỳ dịch vụ đã cam kết không được chồng nhau; discount không cộng dồn theo quy tắc hiện có. Báo giá Liên hệ phải xác định từng Building trước checkout.
3. Backend gọi PayOS ngoài transaction DB; returnUrl/cancelUrl chỉ điều hướng. Adapter verify webhook, đối chiếu và ghi payment idempotent.
4. Payment thành công cấp/gia hạn entitlement từng Building đúng một lần và cộng quota đi kèm vào quỹ Organization. Retry provisioning dùng khóa ổn định, kể cả khi kỳ đã hết hạn, và trả lại entitlement/quota đã cấp thay vì cấp trùng.
5. Trước hạn 5 ngày nhắc web/email theo entitlement/kỳ, gia hạn chọn lọc từng Building. Hết hạn chặn publish/start mới, giữ dữ liệu và phiên đã start.
6. Người mới hết suất bị chặn; Organization nâng cấp gói có hạn mức người cao hơn. Nâng cấp giữ identity kỳ hiện tại và không được chồng với kỳ dịch vụ khác đã cam kết. Giá/thời hạn nâng cấp giữa kỳ chưa chốt.
7. Khi quota AI Organization hết, chặn request tính phí mới; thanh toán mua thêm quota rồi mới tiếp tục. Payment AI không gia hạn dịch vụ Building.

Gói từng Building có thời hạn 6 hoặc 12 tháng, gộp phí game, hạn mức người và quota AI. Hạn mức đếm Trainee khác nhau theo mã tài khoản đã start game tại Building trong kỳ; đăng nhập, xem bài, preparation và Organization playtest không tính suất. Chơi lại/nhiều kịch bản cùng tòa trong kỳ chỉ một suất; tòa khác tính riêng. Hết suất chặn người mới, người đã tính suất vẫn chơi lại trong quyền/dịch vụ còn hợp lệ; Organization nâng cấp gói nhiều người hơn. Kỳ gia hạn mới tính hạn mức theo kỳ mới. Giá, các mức người và cách tính nâng cấp giữa kỳ chưa chốt.

Quota AI đi kèm các Building cộng chung cho Organization; hết quota phải mua thêm và thanh toán trước khi tiếp tục dùng AI tính phí. Không tự cho dùng vượt quota rồi đối soát cuối kỳ. Trainee giữ quota ngày miễn phí riêng, không trừ quỹ Organization. Đơn vị/lượng quota, hiệu lực và xử lý quota còn dư chưa chốt. Reserve/settle và retry phải chống trừ/cấp quota trùng; timeout reconcile bằng request ID trước khi hoàn hoặc gọi lại.

## 12. Đánh giá capstone

Các buổi phản hồi chuyên môn, usability test và user study được tổ chức ngoài workflow phân quyền. Dữ liệu được consent và phân tích để đánh giá trải nghiệm, hiệu năng, độ rõ scenario và giá trị học tập của đồ án. Báo cáo phải tránh mô tả kết quả là phê duyệt hoặc chứng nhận PCCC.

## 13. Workflow liên service, quota và recovery

### 13.1. AI/RAG trên Azure

1. Web/Mobile gửi request tới `.NET API`, không gọi trực tiếp FastAPI trong contract production.
2. `.NET API` xác minh phiên FET3D, role, tenant, audience, corpus scope, quyền bài public/private và quota hiện có; nếu phiên bắt nguồn từ Google thì Firebase chỉ cung cấp bước xác minh Google identity.
3. Backend tạo `ai_requests`, reserve quota và tạo request ledger bằng transaction PostgreSQL ngắn; khóa request/ledger/reservation/grants theo thứ tự ổn định; không cho quota âm hoặc tự dùng overage. Lock order/schema trả trước chi tiết cần đồng bộ riêng. Sau commit mới gọi AI/RAG FastAPI trên Azure.
4. AI trả `requestId`, response type/status, citations/source version, BIM anchors khi có, model/version và usage kỹ thuật. AI không quyết định giá, mua quota hoặc entitlement.
5. Backend ghi kết quả qua contract `record_ai_request_result` sau khi xác minh request, evidence/citations, model và usage kỹ thuật; sau đó chốt `Recorded` hoặc giải phóng reservation đúng một lần. Timeout chuyển request/ledger sang `NeedsReconcile`; backend gọi `GET /api/ai/requests/{requestId}` hoặc reconcile nội bộ trước khi quyết định chốt/hoàn, không tự hoàn rồi tạo request mới.

IFC/Blender và Unity build không chạy trong request chat. Backend ghi processing job + outbox trong transaction; dispatcher giao message, worker claim lease, gọi `register_processing_output` để ghi artifact/validation/issues theo lease rồi mới accept attempt. `issues_hash` giữ dấu vết canonical của danh sách QA để replay khác nội dung bị từ chối. Attempt cũ hết lease không được ghi đè kết quả mới; package fail hoặc QA còn Error/Critical thì không publish.

### 13.2. Quy tắc nhất quán và mất kết nối

- Hai request tranh lượt cuối chỉ một request reserve thành công; việc khóa grant không dùng `SKIP LOCKED` để báo hết quota giả. Retry cùng idempotency key và cùng input hash trả request cũ, key dùng lại cho input khác bị từ chối.
- Webhook PayOS trùng không ghi payment hoặc entitlement trùng. Payment Applied nhưng provisioning lỗi đi vào `NeedsReconcile` và được retry bằng provisioning key cũ. Payment mua thêm quota phải chống cấp trùng; retry không sửa snapshot giá/quota đã mua.
- Transaction không bao quanh LLM, PayOS, S3 hay worker. ACID chỉ bảo vệ từng transaction PostgreSQL; outbox/lease/reconcile xử lý eventual consistency giữa các service. Attempt hết lease không được ghi đè attempt hiện hành.
- Payment, quota, publish và start session mới bị từ chối khi không kiểm tra được nguồn có thẩm quyền. Session đã start được tiếp tục offline và sync event/result sau khi có mạng.

### 13.3. Event, heartbeat và learner analytics

- Mobile gửi event bằng `event_id` ổn định do client tạo, `sequence_number`, `schema_version` và thời gian trên thiết bị; backend ghi thêm `received_at`. Retry cùng session/ID hoặc sequence không nhân đôi dữ liệu.
- Heartbeat ghi `last_heartbeat_received_at` và sequence phía server; `Active sessions` chỉ là ước tính trong cửa sổ cấu hình, không phải trạng thái chắc chắn người học còn thao tác. `p_sequence` null bị từ chối trước khi cập nhật.
- Completion chỉ được tính sau khi backend xác nhận result hợp lệ. `record_session_event` và `complete_training_session` khóa session theo owner, dedup bằng event/result key và không kiểm tra lại entitlement hoặc trạng thái active hiện tại sau khi gameplay đã bắt đầu. `complete_playtest_session` áp dụng cùng nguyên tắc cho playtest và không tạo learner analytics. Preparation, playtest và result chưa sync không vào learner analytics.

### 13.4. Redis Streams, outbox và cache

Public API ingress theo kiến trúc đích là `Web/Mobile → OneShield/OnePortal (iNET) → Nginx → .NET API`. OneShield chỉ là lớp edge/bảo vệ; authorization, tenant scope và quyết định nghiệp vụ vẫn do .NET/PostgreSQL kiểm tra. Domain, TLS, WAF/rate limit, health check và cấu hình failover còn phải xác minh trước production.

1. Backend ghi thay đổi nghiệp vụ và integration_outbox_events trong cùng transaction PostgreSQL. Payload có event key, schema, scope, aggregate ID và canonical hash; commit thành công trước khi dispatcher được phép giao việc.
2. `enqueue_integration_outbox_event` chỉ xử lý allowlist tenant `ProcessingJobRequested` + schema `1`; payload phải có `job_id` trùng aggregate và không mang worker lease/token. `enqueue_system_outbox_event` xử lý allowlist `SystemNotification`/`PlatformCacheInvalidation` + schema `1` bằng executor riêng. Event lạ, sai schema, sai payload hoặc sai scope bị từ chối. `ProcessingJobRequeue` chỉ đi qua `requeue_processing_job`; helper nội bộ không cấp cho runtime. Scope được suy từ aggregate, không nhận tin cậy từ client. Cùng event key cùng envelope trả bản ghi cũ, khác payload/scope/aggregate/schema trả conflict.
3. Dispatcher claim chỉ chọn Pending/Failed đến hạn hoặc Leased đã hết hạn, dùng lease riêng và `SKIP LOCKED` chỉ cho outbox. Redis Stream ID là delivery ID; Redis Pub/Sub chỉ dùng cho tiến độ có thể mất, không dùng cho job bắt buộc.
4. Consumer bắt đầu transaction, khóa/đối chiếu outbox, kiểm tra receipt trước tác động; nếu chưa xử lý thì ghi tác động và receipt cùng transaction, commit rồi mới ACK. Worker claim attempt/lease qua backend, không nhận sẵn lease worker từ message.
5. Redis mất message hoặc dispatcher mất phản hồi được khôi phục bằng replay outbox. `Published` chỉ nghĩa là đã gửi tới stream, không nghĩa consumer hoàn tất; message sai metadata được giữ để chẩn đoán kèm event key/stream ID, không ACK giả hoặc retry nóng vô hạn.
6. API dùng cache-aside cho catalog, package metadata, danh sách bài và dashboard. Cache phải có TTL/key version/invalidation sau commit và kiểm tra quyền nguồn trước khi trả; Redis lỗi thì đọc PostgreSQL có giới hạn tải. FE/Mobile không kết nối Redis.

## 14. Invariant xử lý, billing và retry

Ba cổng runtime của release/publish, Trainee start và OrganizationUser playtest đều đọc manifest/artifact đã pin và runtime catalog server-side. `minRuntimeVersion`, protocol, manifest schema và capability phải tồn tại và hợp lệ; metadata thiếu không được thay bằng giá trị mặc định. Start cùng idempotency key chỉ replay khi runtime payload giống request đầu tiên.

AI dùng quota trả trước: reservation/settle chống trừ trùng và payment mua thêm chống cấp trùng; quota hết không gọi provider tính phí. V7 không có lifecycle Open → Closed → Invoiced → Paid, close/invoice/pay period hoặc overage consent trên workflow billing này.

Processing ghi `processing_jobs` và outbox trong một transaction. Job giữ input hash bất biến; worker claim khóa job rồi attempt. Lease còn hạn trả `Busy`, attempt thành công trả `AlreadyCompleted`, chỉ job `Failed` mới được requeue có chủ đích bằng key mới; replay key cũ sau Running/Succeeded/Cancelled/Failed lại trả `AlreadyRequeued`, còn key khác envelope trả `Conflict`. `Cancelled` là terminal và muốn chạy lại phải tạo job mới. Attempt hết lease bị đánh dấu `Expired`, attempt mới có lease token mới. Renew và accept chỉ dành cho current attempt; artifact, validation và scenario/revision phải cùng provenance. Kết quả cũ hoặc khác hash trả `StaleAttempt`/`Conflict`.

Các tiêu chí này là yêu cầu kiểm thử triển khai, chưa phải kết quả kiểm thử database. Việc đọc SQL và kiểm tra Markdown không chứng minh concurrency, quyền gọi function hoặc recovery đã pass.

## 15. Acceptance matrix cho invariant cuối

| Invariant | Đường thành công | Đường từ chối/recovery | Nguồn chính |
|---|---|---|---|
| AI quota trả trước | Quota còn đủ được reserve, request thành công settle đúng một lần; payment mua thêm cấp quota đúng một lần | Hết quota chặn request mới; timeout reconcile request ID; webhook/retry không cấp hoặc trừ trùng | Requirements FR-BILLING-05/RECOVERY-01; SQL v7 contract cần runtime test |
| AI request/result | Request mới `Accepted`, reserve/settle cùng lock order, terminal result lưu evidence | Sai scope/policy bị chặn tại insert; retry khác input conflict; timeout `NeedsReconcile` | BIM/RAG 10, schema request trigger |
| Worker lease | Job lock trước attempt; `Claimed` nhận token, accept đúng provenance | Lease còn hạn `Busy`; stale `StaleAttempt`; `Failed` chỉ requeue idempotent; `Cancelled` terminal | Technology 14.6, worker contract |
| Runtime/package | Capability hợp lệ, catalog active đủ version/protocol/schema, package hash/manifest hash/build target và artifact hash khớp | null/số/chuỗi rỗng, metadata thiếu, provenance sai hoặc package pinned bị thay đều bị chặn | Schema helper và compatibility contract |
| Scenario/release | Review readiness đúng cặp revision–scenario version; release publish kiểm tra readiness | Reject scenario B không làm revision/Scenario A hỏng; revoke release cũ vẫn được phép | Requirements FR-COMPAT/FR-PROCESS và schema |

Các ca trong bảng là tiêu chí cho đợt triển khai. Hiện mới có kiểm tra tĩnh tài liệu/schema; chưa gọi đây là pass concurrency, authorization hoặc recovery.


## Hồ sơ triển khai API BE được chọn

[Selected BE API implementation](selected-be-api-implementation.md) ghi lựa chọn PostgreSQL outbox → HTTP worker của đợt triển khai, exact readiness/approval, Built/package/Training, account-bound Building access, playtest grant và support receipt/ETag/paging. Redis Streams vẫn là transport trong kiến trúc đích; nguồn/test/mock/schema rollout/binary/provider thật phải được phân biệt. Publish và learner start/sync/result chưa được đóng từ đợt này.
