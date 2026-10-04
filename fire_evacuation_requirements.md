# Tài Liệu Yêu Cầu Dự Án

**Dự án:** Fire Evacuation Training 3D (FET3D)
**Phiên bản:** v2.2 — đồng bộ nghiệp vụ và auth BE 03/10/2026
**Trạng thái:** Scope bản cuối đã đồng bộ; Phase chỉ biểu thị thứ tự triển khai

**Đồng bộ thiết kế ngày 03/10/2026:** yêu cầu nghiệp vụ, SQL design v7, ERD Markdown và Word ý tưởng đã được đồng bộ. Tên bảng/function là contract thiết kế, không chứng minh migration/API/runtime đã triển khai. [Requirements](fire_evacuation_requirements.md) là nguồn yêu cầu sản phẩm; [ghi chú quyết định](phan_tich_khoang_cach_va_quyet_dinh_nghiep_vu.md) ghi lại lựa chọn và chi tiết còn mở.

## 1. Mục tiêu và giới hạn

FET3D là đồ án tạo trải nghiệm tập huấn sơ tán 3D trên Android từ mô hình **IFC** của Building. Ứng dụng Android được cài một lần. Trainee đăng nhập quét QR Building public hoặc xác minh mã tham gia Building private, xem/chọn bài đã publish được phép; backend tạo session preparation để ứng dụng tải/xác minh package, rồi chỉ bước `start` online mới kiểm tra entitlement, kiểm tra quyền public/private và suất người, pin Training/release/scenario và cấp launch grant để khởi chạy Unity.

Luồng cốt lõi là **IFC → 3D → Unity Android → QR → Training → Result**. Ở backend, QR Building có thể tồn tại như điểm resolve ổn định; danh sách chỉ trả bài đã publish, preparation có thể tạo trước, nhưng session mới chỉ được start sau khi entitlement online còn hợp lệ.

Sản phẩm là công cụ học tập và đánh giá hoạt động của đồ án. Website landing và Learn cung cấp nội dung công khai; việc đọc/tìm nội dung không cần tài khoản. Mô phỏng hazard, route, điểm số, analytics và `ConfirmForTraining` không phải chứng nhận an toàn, phê duyệt PCCC, thẩm duyệt thiết kế, tư vấn chuyên môn hay hướng dẫn ứng phó sự cố thực tế.

## 2. Tài khoản và quyền

| Loại tài khoản | Trách nhiệm |
| :--- | :--- |
| `PlatformAdmin` | Quản trị nền tảng, tổ chức, tài khoản, cấu hình vận hành và giám sát tổng quan. |
| `OrganizationUser` | Sở hữu Building, IFC, editor/scenario, publish, QR, analytics, billing và AI usage của tổ chức. |
| `Trainee` | Đăng ký/đăng nhập email và mật khẩu hoặc Google với username theo quy trình onboarding, quét QR Building, chọn bài đã publish, tải package, thực hiện buổi tập huấn, hỏi AI ngoài game và xem kết quả của chính mình. Tài khoản cũ thiếu username hoàn thiện qua profile/onboarding; game start không tự tạo username gate. |

Không có guest account, guest training không định danh hoặc role Visitor. Landing/Learn công khai; mọi game session gắn với Trainee đã xác thực. Building public cho mọi Trainee đã đăng nhập tham gia; Building private yêu cầu thêm mã tham gia chung do Organization cung cấp. Mã không tạo role, membership hoặc quyền đọc tài liệu nội bộ. Xác minh mã tạo grant theo tài khoản ở `access_revision` hiện tại; đổi/thu hồi mã hoặc đổi public/private làm grant cũ mất hiệu lực. QR chỉ resolve Building, không thay kiểm tra quyền. Backend kiểm tra quyền trước khi trả bài/package private và kiểm tra lại ở online start.

Sau IFC/connectivity QA, revision ở `ReadyForScenario`. `OrganizationUser` có thể tạo nhiều Scenario/version trên revision, kể cả sau khi scenario khác đã được confirm nếu geometry tương thích. `ConfirmForTraining` là action cho đúng cặp revision/version; QR không phải điều kiện đầu vào vì QR chỉ là Building resolve point. Action không xác nhận công trình, lối thoát, phương án PCCC hay hiệu lực pháp lý của bất kỳ nội dung nào.

**Thư viện hỗ trợ Organization** gồm template kịch bản tùy chọn, bộ tiêu chí chấm mẫu và danh mục thiết bị game đã được runtime hỗ trợ. PlatformAdmin duy trì các nội dung chuẩn; OrganizationUser dùng để soạn/cấu hình bài trong khu quản lý đã đăng nhập. Thư viện này tách khỏi **Learn công khai** trên web: bài viết, mẹo và video cho mọi người đọc không cần đăng nhập; lưu bài/hỏi AI cần đăng nhập. Learn giữ quy trình biên tập hiện tại và không có bước duyệt bài riêng. Mode Learn trong Unity là trải nghiệm làm quen không gian, không phải blog. IFC, mô hình và kịch bản riêng của Organization không tự được chia sẻ vào thư viện.

Organization tự soạn hoặc dùng template tùy chọn, có thể kết hợp mục tiêu sơ tán, nhận biết nguy cơ, dùng thiết bị và hỗ trợ người khác trong capability runtime. Admin cung cấp tiêu chí mẫu; Organization điều chỉnh rồi gửi duyệt cùng kịch bản. PlatformAdmin duyệt mọi phiên bản trước phát hành hoặc từ chối kèm lý do. Sửa nội dung/rubric phải tạo phiên bản mới và gửi duyệt lại. IFC QA/ConfirmForTraining là readiness kỹ thuật, không thay bước duyệt nội dung; release chỉ publish khi cả hai đạt. Phiên và kết quả cũ giữ phiên bản đã pin.

## 3. Functional Requirements

### FR-WEB: website công khai và cổng học tập

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-WEB-01 | Website chung cung cấp landing, Khám phá, Dành cho tổ chức, Learn, Về chúng tôi, Đăng nhập và Tải ứng dụng; không bắt người dùng chọn role trước khi xem nội dung công khai. | 1 |
| FR-WEB-02 | Landing trình bày hành trình POV cuộn qua công trình đang cháy và hai hướng nhu cầu: tập huấn hoặc tổ chức tập huấn. Three.js phục vụ landing và editor/preview 3D; phải có fallback khi WebGL/reduced motion không dùng được. | 1 |
| FR-WEB-03 | Learn cho phép khách tìm/đọc bài có nguồn; hỏi AI, hỏi về bài đang đọc và lưu bài yêu cầu đăng nhập. Câu trả lời AI phải kèm nguồn. | TBD |
| FR-WEB-04 | Góc học tập của Trainee đã xác thực hiển thị AI, bài lưu, lịch sử và kết quả cá nhân; trang Dành cho tổ chức công khai phần giới thiệu nhưng khu quản lý enforce quyền `OrganizationUser` và `organizationId`. | 1 |
| FR-WEB-05 | Organization editor hiển thị IFC preview, tầng/lớp, đặt/chỉnh/xóa scenario objects, lưu draft, undo/redo, validation và version. Preview web chỉ minh họa; full playtest chạy riêng trong Mobile/Unity với quyền OrganizationUser, trong Trial còn quota thử hoặc entitlement Building `Active`. | 1 |
| FR-WEB-06 | Web hiển thị gói Building 6/12 tháng, hạn mức người/còn lại và quota AI chung Organization; có thao tác nâng cấp gói và mua thêm quota AI trả trước. Hết quota chặn yêu cầu AI tính phí mới, không áp dụng overage trả sau. | 1 |

### FR-AUTH: xác thực và phân quyền

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AUTH-01 | Tài khoản local dùng email/password do BE quản lý; Google Sign-In dùng Firebase Authentication. BE xác minh Firebase ID token cho Google, ánh xạ UID vào user và cấp phiên Fire3D; authorization lấy role/tenant/trạng thái từ PostgreSQL. Tài khoản Google-only có thể chưa có password hash nhưng luôn có ít nhất một phương thức đăng nhập. | 1 |
| FR-AUTH-02 | `PlatformAdmin` có thể tạo, khóa hoặc khôi phục tài khoản và organization; `OrganizationUser` không cấp thêm loại tài khoản. | 1 |
| FR-AUTH-03 | Trainee đăng nhập xem/chọn bài được phép theo quyền Building public/private; private cần mã tham gia chung. Preparation không cấp quyền chơi; online start kiểm tra quyền, entitlement và suất người. Chỉ xem kết quả của mình; username hoàn tất khi đăng ký/onboarding. | 1 |
| FR-AUTH-04 | BE lưu password hash local, refresh-token hash và reset-token hash; không lưu mật khẩu thô, Google refresh token hoặc credential provider. Mailgun gửi OTP đăng ký và email reset do BE tạo. | 1 |
| FR-AUTH-05 | Đăng ký local theo form → OTP → proof → register → login. Trainee gửi email/username/password/confirmPassword; OrganizationUser gửi email/password/confirmPassword cùng organizationName/organizationAddress/organizationPhoneNumber, chưa nhận username cá nhân. Register nhận thêm registrationToken, tạo account đã verified; Organization và owner tạo atomic. Trả 201 AccountResponse, sau đó login riêng để lấy JWT. Client không tự chọn role/tenant; confirmPassword không lưu. | 1 |
| FR-AUTH-06 | Username Trainee là định danh bắt buộc, duy nhất toàn hệ thống, lowercase theo `[a-z0-9._-]{3,30}` khi đăng ký. Đăng nhập local dùng email/password. OrganizationUser có thể bổ sung username qua profile; tên hiển thị và tên tổ chức được phép trùng. | 1 |
| FR-AUTH-07 | GET/PATCH /api/auth/me và GET/PATCH /api/organizations/me trả ETag; sửa profile/avatar yêu cầu If-Match. Hồ sơ cá nhân sửa fullName/username/dob/gender/phoneNumber; không sửa role, tenant, email hoặc trạng thái. Change password là API riêng dùng Bearer và mật khẩu hiện tại, không dùng ETag profile. | 1 |
| FR-AUTH-08 | Firebase UID nullable và unique khi liên kết Google; Google trùng email local chưa liên kết phải xác thực tài khoản local trước khi link, không tự đổi role/tenant. | 1 |
| FR-AUTH-09 | Avatar lưu ở S3 private qua upload intent/complete; PostgreSQL chỉ lưu object key. File phải là ảnh hợp lệ, đúng giới hạn và URL đọc là signed URL ngắn hạn. | 1 |
| FR-AUTH-10 | POST /api/auth/login-firebase nhận Firebase ID token dạng JSON string. UID đã liên kết trả 200 Authenticated với authentication; identity mới trả 200 OnboardingRequired, chưa tạo account; email local trùng trả 409 ACCOUNT_LINK_REQUIRED. Onboarding chọn Trainee/OrganizationUser và explicit link là yêu cầu đích còn thiếu API hoàn tất, không được coi là đã đăng nhập. | 1 |
| FR-AUTH-11 | Reset khóa user và consume token một lần; change xác minh currentPassword dưới khóa user. Cả hai đổi hash, vô hiệu reset token còn lại, thu hồi toàn bộ refresh-token family và audit trong cùng transaction; access token cũ bị từ chối khi backend kiểm tra family. Forgot trả phản hồi chung, reset không cấp password local cho Google-only. | 1 |
| FR-AUTH-12 | OTP đăng ký là chuỗi sáu số, hạn 10 phút; sai đủ 5 lần vô hiệu challenge. Gửi lại có cooldown 60 giây, hạn mức chung 5/email/giờ và 20/IP/giờ; mã mới vô hiệu challenge/proof cũ. Proof hạn 15 phút, gắn email, dùng một lần khi register; form sai không consume proof. Email trim/lowercase đã tồn tại, kể cả inactive/deleted, trả 409 EMAIL_EXISTS cùng errors.email; vượt quota trả 429 OTP_RATE_LIMITED và Retry-After. | 1 |
| FR-AUTH-13 | Login cấp access/refresh token và session family; API kiểm trạng thái account/organization và family trong DB. Refresh rotate token, giữ hạn tuyệt đối family; replay token đã consume/revoke thu hồi family. Logout thu hồi family hiện tại; logout-all thu hồi tất cả family và tắt push bindings. Response login/refresh không có expiresAt; TTL theo cấu hình BE. | 1 |

Nguồn đồng bộ auth: [BE authentication](../BE/docs/authentication.md) và [BE API guide](../BE/docs/api-docs.md), đối chiếu source BE main `0683d90` ngày 03/10/2026. Reset/change đã có transaction trong source; nghiệm thu PostgreSQL/provider/deployment và tích hợp client phải được xác nhận riêng. FE giữ password trong bộ nhớ, đổi email bỏ proof, reload quay về form; không lưu password vào URL/web storage. `/verify-email` chỉ phục vụ pending legacy. Forgot trả 202 chung; reset token 64 ký tự hex, hạn 30 phút, dùng một lần cho account có password local. Reset/change trả 204 và yêu cầu login lại.

### FR-LEARN: Learn blog công khai và biên tập nội dung

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-LEARN-01 | Learn cung cấp danh sách và trang chi tiết công khai cho bài `Article`, `Tip` và `Video`; khách có thể tìm theo tiêu đề/mô tả và lọc theo một hoặc nhiều tình huống. | 1 |
| FR-LEARN-02 | `PlatformAdmin` tạo, sửa Draft, có thể phát hành ngay hoặc lưu nháp, ẩn/hiện hoặc xóa mềm/khôi phục bài Learn; mỗi thao tác lưu actor, thời điểm và audit. Không có bước duyệt riêng của Learn. `OrganizationUser` và `Trainee` không có quyền quản trị Learn. | 1 |
| FR-LEARN-03 | Bài Learn có identity/slug ổn định và các version snapshot. Version chỉ dùng `Draft → Published`; version Published bất biến, gồm cả phân loại tình huống và nguồn liên kết. Post dùng `Unpublished`, `Published`, `Hidden`, `Deleted`; Hidden giữ pointer để RAG dùng version Published, Deleted giữ lịch sử nhưng bị loại khỏi RAG. | 1 |
| FR-LEARN-04 | Bài có thể gắn nhiều situation; situation bị tham chiếu không được xóa cứng. Bài đã gỡ không xuất hiện trong public search/list và bookmark chỉ hiển thị trạng thái không còn khả dụng. | 1 |
| FR-LEARN-05 | Content blocks hỗ trợ text, image và external video. YouTube, Facebook Video và TikTok dùng URL chuẩn hóa/provider allowlist; iframe, HTML, script và URL provider không hỗ trợ bị từ chối. | 1 |
| FR-LEARN-06 | Video lỗi, private, bị xóa hoặc không cho embed phải có mô tả/fallback link; Mobile có thể mở provider bằng trình duyệt. Hệ thống không tự tải hoặc đăng lại video. | 1 |
| FR-LEARN-07 | Nguồn tham khảo được gắn với đúng Learn version. Draft có thể tham chiếu Common chưa Approved; Published và Hidden có thể dùng cho Common RAG khi nguồn còn được phép/đã Approved. Unpublished và Deleted không được retrieval. | 1 |
| FR-LEARN-08 | Trainee đã xác thực có thể thêm/xóa bookmark idempotent cho bài Learn; bookmark không cho đổi chủ bằng UPDATE; không có enrollment, quiz, chứng chỉ hoặc tiến độ khóa học trong thiết kế này. | 1 |
| FR-LEARN-09 | Public API không trả Draft, Hidden, Unpublished hoặc Deleted; bookmark Hidden/Deleted chỉ báo không khả dụng. API dùng pagination, ETag/revision và trả `404/410`, `409` hoặc `422 InvalidContent`. | 1 |
| FR-LEARN-10 | Publish/hide/show/delete/restore tạo audit và `PlatformCacheInvalidation` trong cùng transaction PostgreSQL; Redis/indexing lỗi không làm mất trạng thái. Hidden vẫn là nguồn RAG hợp lệ; Deleted bị loại ngay tại backend dù cache/index cũ. | 1 |

### FR-LIBRARY: thư viện hỗ trợ Organization

| ID | Yêu cầu | Phase |
| --- | --- | --- |
| FR-LIBRARY-01 | PlatformAdmin duy trì template tùy chọn, tiêu chí chấm mẫu và danh mục thiết bị runtime; OrganizationUser truy cập trong khu quản lý để soạn bài. Không đưa ba nhóm này vào Learn công khai. | 1 |
| FR-LIBRARY-02 | Template/rubric có version; cập nhật mẫu không tự sửa bài đã phát hành. Danh mục thiết bị chỉ cho chọn capability đã hỗ trợ, chức năng mới cần development. Mô hình/kịch bản riêng không tự chia sẻ. | 1 |

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
| FR-SCENARIO-01 | OrganizationUser tự soạn hoặc tùy chỉnh template không bắt buộc trên revision hợp lệ; hỗ trợ kết hợp mục tiêu trong capability runtime. Admin cung cấp rubric mẫu, Organization chỉnh rồi gửi duyệt cùng bài. | 1 |
| FR-SCENARIO-02 | Hệ thống lưu cấu hình risk-aware A* cùng version scenario để replay và so sánh được. | 1 |
| FR-SCENARIO-03 | ConfirmForTraining ghi readiness kỹ thuật theo revision/version sau validation. Organization gửi mọi phiên bản kịch bản/rubric cho PlatformAdmin duyệt nội dung; từ chối có lý do, sửa phải tạo bản mới và gửi lại. Readiness không thay approval nội dung. | 1 |
| FR-SCENARIO-04 | Màn hình readiness phải hiển thị rõ giới hạn của mô phỏng và không dùng ngôn ngữ chứng nhận hoặc phê duyệt PCCC. | 1 |
| FR-SCENARIO-05 | Scenario hỗ trợ cấu hình nguồn lửa, tốc độ cháy, khói, hướng/cường độ gió, cửa/vùng chặn, spawn, mục tiêu, thời lượng và các tương tác runtime đã được cung cấp. | 1 |
| FR-SCENARIO-06 | AI có thể tạo draft scenario từ tài liệu/facts được phép; draft không tự lưu, sửa editor hoặc publish và phải có nguồn/giả định. | 1 |

### FR-RELEASE: publish, QR và content package

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-RELEASE-01 | Release chỉ publish khi đúng ScenarioVersion/rubric được PlatformAdmin duyệt, readiness kỹ thuật đạt, package/manifest/runtime/provenance hợp lệ, không còn Error/Critical, Training active khớp và Building còn entitlement. Phiên bản mới không ghi đè nội dung phiên/kết quả cũ. | 1 |
| FR-RELEASE-02 | Sau publish, hệ thống duy trì QR canonical ở cấp Building. QR resolve danh sách bài đã publish; Trainee chọn bài, rồi backend pin đúng release/scenario/training cho session. | 1 |
| FR-RELEASE-03 | Android tải package theo manifest, kiểm tra package hash, manifest hash, build target, schema/runtime version và artifact provenance rồi chuyển trạng thái sẵn sàng. | 1 |
| FR-RELEASE-04 | `OrganizationUser` có thể xem, in, rotate hoặc revoke QR của Building. QR hết hạn dịch vụ vẫn mở landing/trạng thái; backend chặn publish và session mới. Thu hồi QR vì quản trị được phân biệt với hết hạn dịch vụ. | 1 |

### FR-TRAINING: buổi tập huấn

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-TRAINING-01 | Trainee tự chọn Learn, Guided Drill hoặc Assessment; được vào Assessment ngay, không cần hoàn thành bài học/luyện trước. Learn/blog web tách khỏi mode Learn Unity. | 1 |
| FR-TRAINING-02 | React Native/Expo dùng native Android bridge gọi Unity với `sessionId`, `manifestPath`, launch `grant` ngắn hạn và `protocolVersion`; Unity trả event/result có schema version qua bridge về Mobile để Mobile đồng bộ bằng API. | 1 |
| FR-TRAINING-03 | Runtime cung cấp risk-aware A*, hazard surrogate và debrief cơ bản; không trình bày output là hướng dẫn thoát nạn thực tế. | 1 |
| FR-TRAINING-04 | Prepare pin bài/QR/package đã được phép và tải/verify, không cấp quyền start. Online start kiểm tra quyền public/private, entitlement, quota người và package/runtime trước launch grant; package cache không cho start offline. | 1 |
| FR-TRAINING-05 | Basic NPC: scenario hỗ trợ số lượng NPC giới hạn, state đơn giản và budget hiệu năng trên Android. | 2 |
| FR-TRAINING-06 | Mỗi session mới kiểm tra online ở bước start kể cả package đã cache; sau khi launch grant/gameplay đã bắt đầu, mất mạng hoặc entitlement hết hạn không dừng gameplay, event/result được xếp hàng và đồng bộ khi có mạng. `training`, `release`, `scenario`, tenant và QR đã pin không được đổi. Gate event/result dùng actor sở hữu session, event ID/sequence hoặc result key/hash để replay an toàn; không kiểm tra lại entitlement hay trạng thái active hiện tại để chặn sync phiên đã bắt đầu. | 1 |
| FR-TRAINING-07 | Unity runtime cung cấp thư viện dùng chung cho movement, camera, collision, cửa, vật phẩm, lửa/khói/gió/cháy lan và chấm điểm. Organization chỉ cấu hình capability đã có. | 1 |
| FR-TRAINING-08 | Assessment chấm đạt/chưa đạt theo rubric đã duyệt/version hóa, trả lý do và lưu từng lần. Hoàn thành khác với đạt. Thi lại không giới hạn; không chứng nhận, module/sprint hoặc điều kiện luyện trước. Ngưỡng và trọng số cụ thể chưa chốt. | 1 |

### FR-ANALYTICS: analytics

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-ANALYTICS-01 | `OrganizationUser` xem aggregate cơ bản theo định nghĩa: `Trainee unique` là số Trainee khác nhau có session đã bắt đầu; `Learner plays` là số session Trainee đã bắt đầu; `Active sessions` là session có heartbeat trong cửa sổ cấu hình; `Completion rate` = session hoàn tất / session đã bắt đầu; `Duration` chỉ tính session có `started_at` và `ended_at` hợp lệ. Playtest, preparation và session chưa bắt đầu không tính learner analytics; session chưa đồng bộ ghi riêng và chưa tính hoàn thành cho tới khi backend xác nhận. | 1 |
| FR-ANALYTICS-02 | `Trainee` xem kết quả của chính mình theo policy của mode. | 1 |
| FR-ANALYTICS-03 | Expanded analytics bổ sung filter theo Building/scenario/thời gian, so sánh cohort, export và debrief aggregate. | 2 |

### FR-BILLING: quotation, thanh toán và hỗ trợ

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-BILLING-01 | Gói từng Building thời hạn 6 hoặc 12 tháng gồm phí game, hạn mức Trainee khác nhau/kỳ và quota AI. Mỗi tòa có kỳ riêng; Trial import/editor/playtest theo quota Admin không cấp quyền publish hay session Trainee. | 1 |
| FR-BILLING-02 | Publish và mở session mới yêu cầu Building còn service hợp lệ. Hết hạn khóa publish/session mới, giữ dữ liệu và cho session đang chạy hoàn tất. | 1 |
| FR-BILLING-03 | Tích hợp PayOS production: quotation lưu purpose, thời hạn, giá và điều khoản snapshot; backend tạo duy nhất request `Pending` với idempotency key qua `SECURITY DEFINER` entry point dành cho NOLOGIN executor, không có table DML; webhook adapter dùng SDK `webhooks.verify(req.body)` hoặc canonicalize và sắp xếp tăng dần các trường trong `data` theo thuật toán chính thức trước khi gọi entry point webhook idempotent. Database không tự xác thực mật mã. Payment `Applied` có provisioning key ổn định và record reconcile nếu cấp entitlement lỗi. | 1 |
| FR-BILLING-04 | Lưu invoice metadata, trạng thái thanh toán, service entitlement từng Building, giá/điều khoản snapshot và revenue aggregate theo organization. | 1 |
| FR-BILLING-05 | Quota AI từ gói Building cộng chung cho Organization. Hết quota phải thanh toán mua thêm trước khi dùng AI tính phí tiếp; không overage/đối soát phí cuối kỳ. Trainee có quota ngày riêng. Backend ghi request/usage/grant/policy và chống trừ/cấp trùng. | 1 |
| FR-BILLING-06 | returnUrl/cancelUrl chỉ điều hướng. Chỉ webhook PayOS hợp lệ, khớp orderCode/amount/currency mới ghi Paid và cấp quyền đã mua. Retry không cấp entitlement/quota trùng; payment mua quota AI không gia hạn Building. | 1 |
| FR-BILLING-07 | Quotation BuildingService có dòng riêng từng Building, gói 6/12 tháng, hành động mua/gia hạn/nâng cấp và snapshot phí game, hạn mức người, quota AI, giá/điều khoản. Dòng có quota phải pin policy/version, đơn vị và hiệu lực quota hợp lệ trước khi phát hành; các kỳ dịch vụ đã cam kết không được chồng nhau. Provision retry trả lại kết quả đã cấp kể cả sau khi kỳ hết hạn. V7 biểu diễn field/schema; chính sách giá/expiry/rollover và runtime API vẫn cần cấu hình/triển khai. | 1 |
| FR-BILLING-08 | PlatformAdmin cấu hình discount phần trăm hoặc số tiền theo package, số Building, thời hạn và thời gian hiệu lực. Discount không cộng dồn; nếu nhiều rule hợp lệ, backend chọn mức giảm lớn nhất và tie-break ổn định bằng rule ID, không vượt tổng hợp lệ, rồi phân bổ xuống từng dòng theo quy tắc làm tròn currency. Giá/discount áp dụng được snapshot trong quotation. Số lượng lớn hoặc công trình ngoài phạm vi chuẩn dùng yêu cầu báo giá riêng; yêu cầu chưa phát sinh phí/quyền và quotation riêng phải xác định từng Building trước khi thanh toán. | 1 |
| FR-BILLING-09 | Hệ thống tạo thông báo web và email trước 5 ngày so với hạn Building. Thông báo theo entitlement/kỳ/kênh có idempotency, retry và không gửi lại kỳ đã gia hạn; OrganizationUser chọn Building cần gia hạn. | 1 |
| FR-BILLING-10 | Quotation chỉ chuyển `Draft → Issued → Accepted` theo lifecycle hợp lệ; `Accepted` phải ghi `accepted_at` đúng một lần. Sau khi phát hành, dòng Building không được chuyển quotation, và snapshot tenant, mục đích, giá, discount, currency, điều khoản, thời hạn và tổng tiền không được sửa. | 1 |
| FR-BILLING-11 | Đếm user ID khác nhau đã start tại Building/kỳ; nhiều bài/lượt cùng tòa chỉ một suất. Login/list/prepare/playtest không tính. Tòa khác và kỳ gia hạn mới tính riêng. Hết suất chặn user mới; user đã tính tiếp tục nếu quyền/dịch vụ còn hợp lệ; Organization nâng cấp gói nhiều người hơn. | 1 |
| FR-SUPPORT-01 | `OrganizationUser` và `Trainee` gửi feedback/support; `PlatformAdmin` theo dõi và phản hồi ticket. | 2 |

### FR-AUDIT: truy vết

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AUDIT-01 | Lưu audit cho tải IFC, xử lý revision, scenario, `ConfirmForTraining`, publish, QR, billing, Learn editorial action và các thao tác quản trị. | 1 |
| FR-AUDIT-02 | Audit AI request/usage/nguồn/quota/mua thêm, accept/edit/reject draft, gửi duyệt/duyệt/từ chối phiên bản, quyền Building và nâng cấp hạn mức; không dùng consent overage làm chính sách tính phí mới. | 1 |

### FR-AI: RAG cho Organization và Trainee

| ID | Yêu cầu | Phase |
| :--- | :--- | :--- |
| FR-AI-01 | AI Organization hỗ trợ soạn/chỉnh draft thuộc tenant mình trong ngữ cảnh được cấp quyền, giải thích BIM/PCCC và tạo draft có nguồn. Draft không tự vào corpus chung hoặc tự publish. | 1 |
| FR-AI-02 | `ScenarioDraft` AI phải có nguồn, facts anchor, giả định, giới hạn và trạng thái `NeedsUserEdit`; `KnowledgeAnswer` là câu trả lời kiến thức thông thường và không bị ép thành draft review. `InsufficientEvidence` và `RejectedBySafetyGate` là trạng thái phản hồi riêng. AI không tự sửa editor, route, scoring, runtime state, lưu scenario hoặc publish. | 1 |
| FR-AI-03 | AI Trainee trên web/Mobile ngoài lượt đánh giá giải thích mục tiêu/hướng dẫn của bài đã duyệt và phát hành mà user có quyền chơi, kiến thức Learn/Common hợp lệ và kết quả cá nhân; không đọc draft hoặc kho nội bộ Organization. | 1 |
| FR-AI-04 | Trainee có quota ngày riêng do Admin cấu hình. Quota Organization cộng từ các gói Building và khoản mua thêm trả trước; thiếu quota chặn request tính phí mới. Backend quyết định reserve/chốt lượt, frontend không tự trừ. | 1 |
| FR-AI-05 | RAG lọc tenant/scope trước vector retrieval, trả citation và từ chối khi thiếu evidence hoặc câu hỏi yêu cầu chứng nhận/ứng phó sự cố thực tế. | 1 |
| FR-AI-06 | Backend lưu durable ai_request, idempotency/input hash, scope/source version, evidence và usage kỹ thuật; dùng trạng thái request để reconcile timeout. FastAPI chỉ trả evidence/usage; backend reserve/settle quota hiện có và xử lý payment mua thêm riêng. | 1 |

## 4. Non-Functional Requirements

- **Performance:** mục tiêu tối thiểu 30 FPS trên Android tầm trung cho content package; benchmark frame time, RAM, tải/mở package, nhiệt máy, kích thước package, nhiều lần mở/đóng Unity và thời lượng 15 phút trên thiết bị thật. Chưa gọi đạt trước khi có thiết bị và số liệu.
- **Security:** public ingress đi qua OneShield/OnePortal của iNET theo cấu hình edge đã chọn rồi tới Nginx/.NET; edge không thay thế authorization backend. Raw IFC nằm trong AWS S3 private hoặc workstation được kiểm soát; mobile nhận package runtime qua manifest và signed URL có TTL. API xác minh Firebase ID token; mọi query tenant-scoped, gồm retrieval `pgvector`, phải lọc `organizationId`. Không đưa Firebase Admin, Supabase service-role, AWS hoặc LLM key vào client.
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
| Tài khoản, Building public/private, IFC, editor/thư viện Organization, Admin review phiên bản, gói 6/12 tháng/hạn mức người/quota AI trả trước, Learn public, QR, Android/Unity, assessment và analytics/audit. | Có thể triển khai theo các đợt IFC/preview → editor/runtime → payment/AI → bridge/benchmark → mở rộng NPC/analytics; không được coi payment hoặc AI là ngoài cam kết. |

## 6. Ngoài phạm vi

- Cấp chứng nhận hoàn thành; phê duyệt, kiểm định hoặc kết luận tuân thủ PCCC.
- Chương trình học module/sprint hoặc prerequisite bắt buộc; role Visitor và guest gameplay.
- Chuyển đổi tự động từ định dạng mô hình ngoài IFC.
- Game không có tài khoản xác thực hoặc đọc dữ liệu Organization vượt quyền; landing/Learn vẫn đọc công khai.
- Hướng dẫn quyết định trong tình huống cháy nổ thực tế.

## 7. Đánh giá đồ án

Hoạt động đánh giá chuyên môn và user study là hoạt động thu thập phản hồi cho đồ án. Chúng kiểm tra tính dễ sử dụng, độ rõ ràng của scenario, hiệu năng và cách người học tương tác với mô phỏng; chúng không tạo quyền hệ thống và không thay thế quy trình pháp lý hoặc nghiệp vụ PCCC.

## 8. Tiêu chí bổ sung cho compatibility, billing và recovery

### Redis/event/cache acceptance

- PostgreSQL outbox được ghi cùng transaction nghiệp vụ rồi dispatcher giao qua Redis Streams; commit database mà Redis chưa nhận phải replay được từ outbox.
- Entry point tenant chỉ nhận allowlist hiện tại `ProcessingJobRequested` + schema `1` và suy scope từ aggregate; payload phải có `job_id` trùng `aggregate_id`, không mang worker lease/token. Event `System`/`Platform` dùng `enqueue_system_outbox_event` với allowlist `SystemNotification`/`PlatformCacheInvalidation` + schema `1` và executor riêng. Event lạ, sai schema, sai payload hoặc sai scope bị từ chối. `ProcessingJobRequeue` chỉ được tạo qua gate requeue. Event bắt đầu `Pending` với attempts bằng 0; cùng key khác envelope trả conflict. Dispatcher chỉ claim event đến hạn hoặc lease đã hết hạn, không để event đang leased chặn hàng khác.
- Consumer/worker xử lý event có thể lặp bằng event key và payload hash; tác động nghiệp vụ cùng integration_event_consumptions phải commit trước ACK. Cùng key khác hash trả conflict.
- Handler phải đối chiếu đầy đủ schema/scope/aggregate/payload với outbox; kiểm tra receipt trước tác động và ghi receipt sau tác động trong cùng transaction. Message sai metadata được giữ để chẩn đoán kèm event key/stream ID, không ACK giả hoặc retry nóng vô hạn.
- Dispatcher/worker hết lease, crash hoặc mất ACK phải giao lại mà không tạo charge, entitlement, artifact, publication hay analytics trùng. Redis Pub/Sub chỉ là thông báo tiến độ có thể mất.
- Cache-aside chỉ tối ưu đọc catalog, package metadata, danh sách bài và dashboard. Cache cũ không vượt revoke, entitlement, quota hoặc tenant scope; Redis lỗi thì API fallback PostgreSQL và trả trạng thái chờ/chậm.
- Heartbeat PostgreSQL và event/result gameplay là nguồn hiện hành; Redis chỉ cache thống kê online. Preparation/playtest vẫn bị loại khỏi learner analytics.

- **FR-COMPAT-01:** Publish, Trainee start và OrganizationUser playtest phải dùng chung runtime catalog và manifest contract. Runtime version phải đúng `major.minor.patch`; thiếu minimum runtime, protocol, manifest schema, manifest hash, build target hoặc capability array thì từ chối. Capability phải là các chuỗi không rỗng; array rỗng chỉ hợp lệ khi được khai báo rõ. Release package, session và playtest phải pin đúng artifact ID, validation-run ID, hash và build target; provenance sai hoặc package đã pin bị sửa tại chỗ thì từ chối.
- **FR-BILLING-RECOVERY-01:** Payment hợp lệ cấp entitlement, hạn mức/quota đã mua đúng một lần; retry/reconcile không cấp trùng. AI reserve/settle quota trước khi gọi service, thiếu quota không gọi LLM tính phí. Timeout giữ request ID để reconcile. V7 không dùng lifecycle AI period, close/invoice/pay hay overage consent cho billing mới.
- **FR-AI-RECOVERY-01:** AI request phải được authorize tại thời điểm tạo theo audience, user, tenant, Building và policy version. Request mới bắt đầu `Accepted` không có kết quả; policy/input identity và terminal result bất biến sau tiếp nhận, request đã nhận vẫn được reconcile nếu user bị khóa. FastAPI chỉ trả usage kỹ thuật/evidence; backend ghi result và accounting qua executor/contract riêng.
- **FR-PROCESS-02:** Logical job giữ input hash. Worker chỉ claim job queued hoặc attempt đã hết lease; lease hiện hành không bị thay thế, job thành công không chạy lại do message trùng, và kết quả phải khớp attempt/artifact/validation hiện hành.
- **FR-PROCESS-03:** Requeue job `Failed` là thao tác backend có quyền, có idempotency key và outbox; cùng key/envelope replay trả `AlreadyRequeued` dù job đã tiến trạng thái, khác envelope trả `Conflict`, key mới chỉ requeue `Failed`; job `Cancelled` không tự chạy lại. Hai worker claim đồng thời chỉ một worker nhận lease mới.
- **FR-PROCESS-04:** Worker không ghi trực tiếp artifact/validation/issue. Sau khi claim, worker dùng gate lease-bound để đăng ký output, provenance và QA; `issues_hash` lưu hash canonical của toàn bộ danh sách issue để replay khác nội dung bị từ chối. Chỉ output của current attempt có lease hợp lệ mới được accept. Retry cùng artifact/validation trả kết quả cũ, khác provenance trả `Conflict`.
- **FR-TRAINING-RECOVERY-01:** Backend có gate ghi event và complete cho session đã bắt đầu. Kết quả được lưu với idempotency key/hash và snapshot; replay giống nhau là no-op, payload khác bị từ chối, còn entitlement hết hạn hoặc user bị khóa sau start không làm mất khả năng reconcile.
- **NFR-RECOVERY-02:** Retry, timeout và duplicate delivery phải trả trạng thái xác định (`Claimed`, `Busy`, `AlreadyCompleted`, `NotClaimable`, `StaleAttempt`, `Conflict`) và không tạo charge, entitlement, artifact hoặc publication trùng.

Các tiêu chí trên là contract thiết kế và acceptance criteria cho đợt triển khai; chưa được gọi là đạt nếu chưa có test database/concurrency/recovery tương ứng.

## 9. Chi tiết nghiệp vụ còn mở

Giá/hạn mức gói, lượng/đơn vị/hiệu lực quota AI, nâng cấp giữa kỳ, rubric số cụ thể và vòng đời mã private theo [bảng quyết định mở](fire_evacuation_project_overview.md). Không tự đặt số người, giá hay điểm đạt. SQL/sơ đồ/report cần một đợt đồng bộ riêng trước triển khai.
