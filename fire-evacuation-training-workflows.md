# Fire Evacuation Training 3D — Workflows

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

1. Người dùng đăng nhập bằng email/password do BE xác minh hoặc Google Sign-In qua Firebase; backend ánh xạ Firebase UID (khi có) sang bản ghi FET3D. `PlatformAdmin` tạo organization và gán ba loại tài khoản nghiệp vụ cần thiết. Mailgun phục vụ reset password, FCM chỉ phục vụ push.
2. Hệ thống gắn `OrganizationUser` với phạm vi `organizationId` để ownership. `Trainee` là tài khoản xác thực có thể xem danh sách bài qua QR canonical của Building; session participation pin bài đã chọn và không biến Trainee thành thành viên của organization. Firebase chỉ xác thực Google identity, không quyết định quyền nghiệp vụ.
3. `PlatformAdmin` khóa/mở khóa tài khoản, xem health, audit, support và billing aggregate cấp nền tảng.
   Quản trị Learn theo workflow riêng: tạo/sửa draft, phát hành ngay hoặc lưu nháp, ẩn/hiện bài; thao tác editorial được audit và không trao quyền CMS cho `OrganizationUser` hay `Trainee`.
4. API từ chối request ownership không có tài khoản đã xác thực hoặc không khớp `organizationId`; QR resolve cần identity để mở danh sách, còn explicit session start mới cần entitlement Building, bài Published và kiểm tra online.
5. Mobile đăng ký/rotate token FCM theo installation. Backend xóa hoặc vô hiệu hóa token không hợp lệ; token FCM không thay thế password session hoặc Firebase ID token.

### 2.1. Đăng ký, username và hồ sơ

1. `POST /api/auth/register/trainee` nhận email/username/password/confirm password; `POST /api/auth/register/organization` nhận email/password/confirm password cùng tên, địa chỉ và số điện thoại tổ chức. BE tự gán role/tenant và retry không tạo bản ghi trùng.
2. Google exchange xác minh Firebase ID token. Tài khoản Google đã liên kết đăng nhập theo role/tenant hiện có; Google mới nhận onboarding token ngắn hạn, chọn Trainee hoặc OrganizationUser rồi hoàn tất thông tin tương ứng. Không có lựa chọn PlatformAdmin hoặc organization có sẵn.
3. Username Trainee phải unique, lowercase và đúng pattern ngay trong đăng ký local hoặc bước Google onboarding. OrganizationUser có thể bổ sung username sau. Game start không còn `ProfileIncomplete`; tài khoản Trainee cũ thiếu username phải hoàn thiện trong profile/onboarding trước khi dùng chức năng phụ thuộc username.
4. `GET/PATCH /api/me/profile`, change/set password, link Google và `GET/PATCH /api/me/organization` kiểm tra ETag/actor; không cập nhật role, tenant, email hoặc account status. Avatar upload dùng S3 intent/complete/delete, không nhận URL tùy ý.

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

```text
ReadyForScenario hoặc ConfirmedForTraining revision
  -> OrganizationUser tạo logical Scenario + editor Draft
  -> snapshot ScenarioVersion bất biến
  -> validate spawn/goal/hazard/rubric/A* weights
  -> validate candidate package + manifest
  -> checklist readiness
  -> optional Organization playtest (Trial còn quota thử hoặc Building entitlement Active)
  -> ConfirmForTraining cho revision/version
  -> readiness record của đúng ScenarioVersion
```

1. `OrganizationUser` chọn revision tương thích, tạo hoặc chọn logical `Scenario`, sau đó tạo `ScenarioDraft`; version mới không ghi đè version đã dùng.
2. OrganizationUser dùng editor Three.js để đặt/chỉnh/xóa source lửa, khói, gió, tốc độ cháy, blocked elements, bình chữa cháy, khăn, nguồn nước, spawn, mục tiêu và các tương tác runtime đã có. Draft được lưu tách khỏi geometry.
3. AI Organization có thể tạo scenario draft từ facts IFC và corpus được phép; draft chỉ là gợi ý có citation và phải được người dùng tự edit/accept.
4. Scenario ghi hazard parameters, time limit, rubric, route weights, seed, interaction config và version để replay được.
5. Hệ thống chạy validation về route, blocked edge, floor portal, object anchors, package hash, protocol/schema, runtime version và giới hạn hiệu năng.
6. OrganizationUser có thể chạy thử riêng bằng Mobile/Unity với package đã verify. Khi start, backend kiểm tra Trial còn hạn/còn quota thử hoặc entitlement Building `Active`; playtest không yêu cầu QR, không tạo learner session và không vào learner analytics. Entitlement hết hạn sau start không cắt playtest.
7. Khi mọi điều kiện readiness đạt, `OrganizationUser` thực hiện action `ConfirmForTraining`; hệ thống persist readiness của đúng revision/version. Revision có thể tiếp tục author scenario khác.
8. Hệ thống audit actor, timestamp, revision, scenario/version và các validation pass/fail. QR không nằm trong checklist vì chưa có release/`Training` để bind.

`ConfirmForTraining` chỉ nói rằng package và scenario version đã sẵn sàng cho phiên tập huấn của đồ án. Nếu geometry, exit hoặc hazard baseline thay đổi thì cần revision mới; nếu chỉ đổi tham số scenario tương thích thì tạo version mới và readiness mới. Không kết quả nào trong workflow này xác nhận mức độ an toàn thực tế.

## 5. Workflow publish và QR

```text
ConfirmedForTraining revision + confirmed ScenarioVersion
  -> create immutable TrainingRelease ở Built
  -> persist manifest/content package
  -> create matching Active Training
  -> verify Active Building service entitlement
  -> publish release
  -> keep/generate canonical Building QR
  -> QR resolves list of published Trainings
```

1. Từ revision `ConfirmedForTraining` và đúng scenario/version đã được action confirm, backend tạo `TrainingRelease` bất biến ở `Built`.
2. Backend persist manifest/package gồm `releaseId`, `buildingId`, `scenarioId`, `scenarioVersionId`, package hash, `protocolVersion`, schema version và `minRuntimeVersion`, rồi tạo một `Training` active khớp release/scenario/version/organization.
3. Backend kiểm tra Building còn service entitlement `Active` cho publish. Trial chỉ cấp import/editor/playtest theo quota và không đủ để publish; playtest cũng có thể start với entitlement Active. Publish bị từ chối nếu package, `Training` active hoặc entitlement chưa hợp lệ.
4. `OrganizationUser` publish release. QR canonical cấp Building được giữ ổn định; người dùng có thể in hoặc rotate vì lý do quản trị.
5. QR resolve Building và trả danh sách bài Published còn khả dụng. Khi Trainee chọn một bài, backend pin `release_id`, `training_id`, `scenario_version_id` vào session.
6. Release/Training/scenario/version/organization phải khớp nhau. Hết hạn entitlement chặn publish/session mới nhưng không làm mất QR landing; revoke QR vì quản trị là trạng thái riêng.

Quy ước sản phẩm là mỗi Building có một QR canonical ổn định. QR chỉ là mã resolve công khai; nó không chứa package, access token hoặc APK. Khi phát hành release mới, danh sách bài thay đổi nhưng QR không cần đổi; rotate/revoke chỉ là thao tác quản trị.

## 6. Workflow quét QR, download và launch

```text
QR
  -> chưa cài app: web landing/login/download app
  -> đã cài app: Mobile nhận context Building và yêu cầu Google Sign-In
  -> backend resolve Building + trạng thái QR/dịch vụ
  -> trả danh sách Published Training
  -> Trainee chọn bài
  -> tải/verify package còn thiếu
  -> POST /api/training/sessions (prepare + idempotency key)
  -> POST /api/training/sessions/{sessionId}/start (online entitlement/QR/package/runtime check)
  -> React Native/Expo native bridge launch Unity
```

1. QR mở web nếu chưa cài app; người dùng có thể đăng ký/đăng nhập email/password hoặc Google rồi tải app và quét lại QR.
2. Mobile dùng phiên FET3D từ local email/password hoặc Google exchange; với Google, gửi Firebase ID token để backend kiểm tra. Không bắt buộc Google nếu người dùng đã có phiên local hợp lệ.
3. Backend resolve QR và trả danh sách bài Published được phép hiển thị; bước preparation chỉ kiểm tra identity, bài, QR, release/scenario và package metadata, chưa cấp quyền chơi.
4. Trainee chọn bài, Mobile nhận manifest/package URL ký ngắn hạn, tải phần còn thiếu, xác minh hash/schema/runtime rồi tạo preparation record với idempotency key.
5. Chỉ `POST /api/training/sessions/{sessionId}/start` kiểm tra Building entitlement `Active`, QR chưa revoke, release/training/scenario tương thích, package hash/schema/runtime và cấp launch grant online; không cho start mới offline dù package đã cache. Sau start, backend pin `trainingId`/`releaseId`/`scenarioId`/`qrCodeId` bất biến.
6. Native Android bridge truyền `sessionId`, manifest path, grant và protocol version cho Unity. Unity không giữ credential dài hạn và không tự chọn release.

Nếu thiết bị chưa cài Mobile app, URL/deep link của QR mở landing/trạng thái Building và dẫn tới kênh cài đặt phù hợp; người dùng quét lại sau khi cài nếu context chưa được giữ. Gameplay không chạy bằng Three.js trên trình duyệt; Three.js làm landing và editor/preview tổ chức, còn gameplay đầy đủ chạy trong Unity.

### 6.1. Handoff từ Góc học tập sang Android

1. Trainee chọn Building/bài đã publish trên web và bấm **Mở trên điện thoại**.
2. Web hiển thị QR canonical của Building; QR không tạo package, APK hoặc quyền mới.
3. Điện thoại đã cài Android app quét QR, xác thực nếu cần, xem danh sách bài, chọn bài rồi tải/verify content package và mở Unity. Điện thoại chưa cài app đi tới kênh cài đặt hợp lệ và người dùng quét lại QR sau khi cài.
4. Web không suy đoán hoặc persist trạng thái cài đặt của điện thoại. Quy tắc QR canonical, rotate/revoke và package pin giữ nguyên.

## 7. Workflow training online

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
2. Learn cung cấp hướng dẫn; Guided Drill ghi decision và re-plan; Assessment áp dụng rubric đã cấu hình.
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
- Dashboard phải nhắc rõ analytics mô tả hoạt động trong mô phỏng, không phải kết luận an toàn hay chứng nhận PCCC.

## 11. Workflow dịch vụ Building, AI usage, thanh toán và support

```text
OrganizationUser quản lý nhiều Building có tên + địa chỉ
  -> chọn Building mới hoặc Building đã import/thử nghiệm
  -> chọn một/nhiều Building, gói và thời hạn
  -> backend tính discount đủ điều kiện và phát hành quotation nhiều dòng
  -> backend gọi PayOS ngoài DB transaction
  -> webhook xác thực + DB idempotent
  -> cấp/gia hạn entitlement đúng Building
  -> AI usage ghi quota/overage riêng organization
  -> đối soát cuối kỳ AI + invoice/revenue
```

1. `OrganizationUser` quản lý nhiều Building; mỗi Building bắt buộc có tên và địa chỉ trước khi đưa vào quotation. Có thể chọn Building đã tạo để thử nghiệm/import hoặc tạo mới. Import/editor/playtest thử chỉ bị giới hạn bởi quota thử do Admin cấu hình; playtest cũng được phép khi entitlement Building đã Active.
2. Organization chọn một hoặc nhiều Building, thời hạn và gói chuẩn. Backend tính số dòng, lọc rule theo package/số Building/thời hạn/thời gian hiệu lực; nếu nhiều rule hợp lệ thì chọn mức giảm lớn nhất, tie-break ổn định bằng rule ID, không cộng dồn, không vượt tổng hợp lệ và phân bổ discount xuống từng dòng theo quy tắc làm tròn của currency. Giá/discount/terms snapshot được lưu vào quotation `BuildingService`. Số lượng không được dùng thay cho danh sách Building. Với yêu cầu Liên hệ, request chỉ ghi nhu cầu ban đầu; trước khi checkout, Admin/backend vẫn phải chốt danh sách Building cụ thể thành các quotation line.
3. Thanh toán trước khi publish. Quotation snapshot phải ghi từng Building, mục đích, thời hạn dịch vụ, giá và điều khoản; AI settlement dùng quotation `AIUsage`/kỳ AI riêng và không cấp quyền service Building.
   Quotation đi qua `Draft → Issued → Accepted`; khi chuyển sang `Accepted`, backend/trigger ghi `accepted_at` đúng một lần. Sau khi phát hành, line không thể chuyển sang quotation khác và snapshot thương mại không thể sửa.
4. Backend gọi PayOS bên ngoài database transaction; executor chỉ tạo request `Pending`. Trusted webhook adapter xác thực `req.body`; chỉ webhook hợp lệ và idempotent mới ghi `Paid`.
5. Sau payment, provisioning/reconcile cấp hoặc gia hạn entitlement riêng cho từng dòng bằng khóa `quotation_item + payment`; cùng đợt dùng chung mốc kích hoạt, tòa mua sau có kỳ riêng. Gia hạn chọn lọc, gia hạn sớm nối tiếp hạn cũ; payment lỗi không cấp trùng.
6. `returnUrl` và `cancelUrl` chỉ điều hướng UI. Mismatched/duplicate webhook được lưu trace, không gia hạn hoặc ghi Paid lần hai.
7. Trước hạn 5 ngày, background task tạo notification web và email cho OrganizationUser theo từng entitlement. Notification/delivery có idempotency và retry; thông báo dẫn tới danh sách để chọn Building gia hạn. Redis không phải nguồn duy nhất của lịch nhắc.
8. Mỗi Building có kỳ tháng riêng. Organization có quota AI dùng chung; Trainee có grant theo user/ngày. Mỗi AI request ghi `requestId`, grant, Building/user/audience, loại request, consent overage, đơn giá và trạng thái thành công/lỗi.
9. Khi vượt quota miễn phí, web/mobile hiển thị overage và yêu cầu đồng ý trước khi phát sinh phí; usage được chốt theo kỳ đối soát organization riêng. `OrganizationUser` xem billing/usage trong organization; `PlatformAdmin` quản lý giá, discount, quota, entitlement và aggregate. Playtest tách khỏi learner analytics.

## 12. Đánh giá capstone

Các buổi phản hồi chuyên môn, usability test và user study được tổ chức ngoài workflow phân quyền. Dữ liệu được consent và phân tích để đánh giá trải nghiệm, hiệu năng, độ rõ scenario và giá trị học tập của đồ án. Báo cáo phải tránh mô tả kết quả là phê duyệt hoặc chứng nhận PCCC.

## 13. Workflow liên service, quota và recovery

### 13.1. AI/RAG trên Azure

1. Web/Mobile gửi request tới `.NET API`, không gọi trực tiếp FastAPI trong contract production.
2. `.NET API` xác minh phiên FET3D, role, tenant, audience, corpus scope và quota/consent; nếu phiên bắt nguồn từ Google thì Firebase chỉ cung cấp bước xác minh Google identity.
3. Backend tạo `ai_requests`, reserve quota và tạo request ledger bằng transaction PostgreSQL ngắn; nếu có kỳ billing thì khóa kỳ trước, sau đó khóa request, ledger/reservation và các grant theo `id` tăng dần. Sau commit mới gọi AI/RAG FastAPI trên Azure.
4. AI trả `requestId`, response type/status, citations/source version, BIM anchors khi có, model/version và usage kỹ thuật. AI không quyết định giá, overage hoặc entitlement.
5. Backend ghi kết quả qua contract `record_ai_request_result` sau khi xác minh request, evidence/citations, model và usage kỹ thuật; sau đó chốt `Recorded` hoặc giải phóng reservation đúng một lần. Timeout chuyển request/ledger sang `NeedsReconcile`; backend gọi `GET /api/ai/requests/{requestId}` hoặc reconcile nội bộ trước khi quyết định chốt/hoàn, không tự hoàn rồi tạo request mới.

IFC/Blender và Unity build không chạy trong request chat. Backend ghi processing job + outbox trong transaction; dispatcher giao message, worker claim lease, gọi `register_processing_output` để ghi artifact/validation/issues theo lease rồi mới accept attempt. `issues_hash` giữ dấu vết canonical của danh sách QA để replay khác nội dung bị từ chối. Attempt cũ hết lease không được ghi đè kết quả mới; package fail hoặc QA còn Error/Critical thì không publish.

### 13.2. Quy tắc nhất quán và mất kết nối

- Hai request tranh lượt cuối chỉ một request reserve thành công; việc khóa grant không dùng `SKIP LOCKED` để báo hết quota giả. Retry cùng idempotency key và cùng input hash trả request cũ, key dùng lại cho input khác bị từ chối.
- Webhook PayOS trùng không ghi payment hoặc entitlement trùng. Payment Applied nhưng provisioning lỗi đi vào `NeedsReconcile` và được retry bằng provisioning key cũ. Tranh chấp AI chỉ ghi metadata riêng; không mở lại period hoặc thay snapshot.
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

Kỳ AI được xử lý theo thứ tự `Open → Closed → Invoiced → Paid`. `Closed` chỉ đóng băng snapshot; quotation `AIUsage` được gắn ở bước `Closed → Invoiced`, payment `Applied` tương ứng được gắn ở bước `Invoiced → Paid`. Retry cùng chứng từ là no-op, chứng từ khác là conflict; adjustment là bản ghi mới, không sửa kỳ đã chốt.

Processing ghi `processing_jobs` và outbox trong một transaction. Job giữ input hash bất biến; worker claim khóa job rồi attempt. Lease còn hạn trả `Busy`, attempt thành công trả `AlreadyCompleted`, chỉ job `Failed` mới được requeue có chủ đích bằng key mới; replay key cũ sau Running/Succeeded/Cancelled/Failed lại trả `AlreadyRequeued`, còn key khác envelope trả `Conflict`. `Cancelled` là terminal và muốn chạy lại phải tạo job mới. Attempt hết lease bị đánh dấu `Expired`, attempt mới có lease token mới. Renew và accept chỉ dành cho current attempt; artifact, validation và scenario/revision phải cùng provenance. Kết quả cũ hoặc khác hash trả `StaleAttempt`/`Conflict`.

Các tiêu chí này là yêu cầu kiểm thử triển khai, chưa phải kết quả kiểm thử database. Việc đọc SQL và kiểm tra Markdown không chứng minh concurrency, quyền gọi function hoặc recovery đã pass.

## 15. Acceptance matrix cho invariant cuối

| Invariant | Đường thành công | Đường từ chối/recovery | Nguồn chính |
|---|---|---|---|
| Close AI period | Period `Open` được khóa, items từ usage billable đã xác nhận lấy số lượt/giá/currency/policy/consent lịch sử rồi chuyển `Closed` | Item thêm/sửa/xóa sau close bị chặn; late/uncertain usage tạo adjustment | Technology 14.6, `close_ai_billing_period` |
| AI request/result | Request mới `Accepted`, reserve/settle cùng lock order, terminal result lưu evidence | Sai scope/policy bị chặn tại insert; retry khác input conflict; timeout `NeedsReconcile` | BIM/RAG 10, schema request trigger |
| Worker lease | Job lock trước attempt; `Claimed` nhận token, accept đúng provenance | Lease còn hạn `Busy`; stale `StaleAttempt`; `Failed` chỉ requeue idempotent; `Cancelled` terminal | Technology 14.6, worker contract |
| Runtime/package | Capability hợp lệ, catalog active đủ version/protocol/schema, package hash/manifest hash/build target và artifact hash khớp | null/số/chuỗi rỗng, metadata thiếu, provenance sai hoặc package pinned bị thay đều bị chặn | Schema helper và compatibility contract |
| Scenario/release | Review readiness đúng cặp revision–scenario version; release publish kiểm tra readiness | Reject scenario B không làm revision/Scenario A hỏng; revoke release cũ vẫn được phép | Requirements FR-COMPAT/FR-PROCESS và schema |

Các ca trong bảng là tiêu chí cho đợt triển khai. Hiện mới có kiểm tra tĩnh tài liệu/schema; chưa gọi đây là pass concurrency, authorization hoặc recovery.
