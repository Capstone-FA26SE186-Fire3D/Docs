# Fire Evacuation Training 3D — Technology & Architecture

## 1. Mục tiêu kỹ thuật

FET3D tạo content package Unity từ **IFC** cho Building và phân phối package đó đến Android sau khi người dùng xác thực và quét QR. Ứng dụng Android được cài một lần; Building QR resolve danh sách Training đã publish, người dùng chọn bài, backend tạo preparation record để ứng dụng tải/verify manifest và content package, sau đó chỉ API `start` online mới kiểm tra entitlement và cấp launch grant pin release/scenario rồi mở Unity.

Luồng cốt lõi: **IFC → 3D → Unity Android → QR → Training → Result**.

Kiến trúc phục vụ mô phỏng và tập huấn của đồ án. Nó không thực hiện CFD thiết kế, hệ thống điều khiển khẩn cấp, thẩm duyệt hoặc chứng nhận PCCC.

### 1.1. QR theo tòa nhà và ranh giới web/mobile

- Mỗi `Building` có một QR canonical ổn định để mở danh sách bài đã publish của tòa nhà. Session mới pin bài/release/scenario mà Trainee chọn; QR không bị buộc vào một Training duy nhất.
- QR chỉ chứa mã opaque hoặc deep link công khai để backend resolve `Building`/`TrainingRelease`; không nhúng model BIM, access token, credential hay APK.
- Mobile app được cài một lần. Sau khi quét, backend kiểm tra entitlement online, trả danh sách bài và khi Trainee chọn bài thì trả manifest/URL ngắn hạn để app tải, xác minh và cache content package; không tải/cài một game APK hoặc Unity runtime mới cho từng QR.
- FE dùng Three.js cho hiệu ứng landing và editor/preview 3D của organization. Gameplay BIM 3D với góc nhìn 2.5D chạy trong Unity runtime của Mobile, không phải game Three.js trên web. Nếu chưa cài app, landing chỉ dẫn tới đăng nhập/tải app và người dùng có thể quét lại QR.

## 2. Ba loại tài khoản và ownership

| Tài khoản | Quyền kiến trúc cần hỗ trợ |
| :--- | :--- |
| `PlatformAdmin` | Quản trị platform, organization, account, health, support và aggregate vận hành. |
| `OrganizationUser` | Sở hữu Building, IFC, scenario, publish, QR, analytics và billing trong `organizationId`. |
| `Trainee` | Quét QR Building, chọn Training đã publish, tham gia session và truy cập kết quả cá nhân. |

Không triển khai bảng/cơ chế thành viên, lời mời, truy cập khách, token khách hoặc training không định danh. `organizationId` bảo vệ ownership của Building, authoring, analytics và billing. Mọi `Trainee` đã xác thực có thể resolve QR Building và chọn bài published; backend không dùng account-specific allowlist hoặc đối chiếu `organizationId` của Trainee để thay thế kiểm tra identity, Building entitlement và trạng thái bài.

## 3. Kiến trúc tổng thể

```text
PlatformAdmin / OrganizationUser web
            |
      Next.js web application          React Native/Expo Android
            |                                  |
            +------ Firebase Auth / FCM -------+
            |
 C# / ASP.NET Core API + background jobs
      |                    |                       |
Supabase PostgreSQL     AWS S3          Python/FastAPI workers
   + pgvector        private IFC/package     IFC processing + RAG
      \                    |                       /
             immutable TrainingRelease
                        |
                  signed QR resolve
                        |
       React Native/Expo Android shell with native Unity bridge (installed once)
                        |
         verified content package + Unity runtime
                        |
         hazard surrogate / A* / event / result
```

Backend là nguồn sự thật cho ownership scope, Building, revision, scenario, release, session, service entitlement, AI usage, analytics và billing. Unity không giữ access token dài hạn, không tự chọn release và không thay đổi quyền. QR resolve cho Trainee mở danh sách bài; preparation chỉ pin lựa chọn, còn explicit session start mới kiểm tra entitlement online và cấp launch grant.

## 4. Thành phần và stack

| Lớp | Công nghệ | Trách nhiệm |
| :--- | :--- | :--- |
| Web | Next.js + Three.js (landing, preview/editor) | Next.js vận hành Building, IFC, scenario/editor, release, QR, analytics, billing, AI usage và support; Three.js hiển thị landing và model preview/editor. |
| API/jobs | C# + ASP.NET Core trên .NET | Xác minh Firebase ID token, AuthZ, domain command, QR resolve, session, audit, billing webhook và job orchestration. |
| Database | Supabase Database (PostgreSQL) | Dữ liệu tenant-scoped, revision, release, session/result, analytics, quotation/transaction/invoice metadata. Supabase Auth không được dùng. |
| Vector database | `pgvector` trên cùng PostgreSQL/Supabase | Embedding, metadata-filtered retrieval và vector index cho RAG; thay thế ChromaDB của prototype cũ. |
| Cache/event transport | Redis cache-aside + Redis Streams | Cache dữ liệu đọc và vận chuyển event/job sau transactional outbox; PostgreSQL vẫn là nguồn sự thật. Redis là kiến trúc đích, chưa triển khai; provider, version, retention và TTL còn mở. |
| Authentication | Firebase Authentication + Google Sign-In | Xác thực danh tính. Backend ánh xạ Firebase UID sang user, role và `organizationId`; Firebase không quyết định authorization nghiệp vụ. |
| Push notification | Firebase Cloud Messaging (FCM) | Gửi notification đến installation đã đăng ký; token FCM phải được rotate/revoke và không dùng làm credential đăng nhập. |
| Object storage | Amazon S3 (AWS S3) | Raw IFC private, manifest và content package bất biến qua bucket policy và signed URL TTL ngắn. |
| AI/RAG service | Python + FastAPI trên Azure; Container Apps là phương án triển khai đề xuất | Service nội bộ cho retrieval, grounded generation, citations, safety gate và usage kỹ thuật; client không gọi trực tiếp. Prototype hiện vẫn gọi API riêng. |
| IFC/Blender worker | Python + IfcOpenShell/IfcConvert; Blender script/Container Apps Job khi phù hợp | Nhận job qua dispatch bền vững, parse IFC, geometry/LOD, GlobalId/facts, graph và QA; worker không phục vụ chat đồng thời. |
| Unity build worker | Unity Editor + build toolchain riêng | Tạo collider/NavMesh/runtime package và manifest; không coi Python/GLB là AssetBundle nếu thiếu Unity Editor worker. |
| LLM provider | OpenAI API hoặc Google Gemini API qua Google AI Studio | Chưa chọn nhà cung cấp cuối; dùng provider adapter và chỉ bật một provider production sau đánh giá chất lượng, chi phí và quota. |
| Android shell | React Native/Expo + native Android bridge | Login, QR/list bài, download/verify/cache, local queue sau khi session bắt đầu và Unity handoff. |
| Native Android bridge | Thành phần tích hợp Mobile–Unity | Nhận yêu cầu launch từ Mobile, truyền dữ liệu cho Unity và chuyển callback/event/result về Mobile. |
| 3D runtime | Unity 6 LTS + URP + Addressables | Scene, navigation, hazard surrogate, A*, reusable NPC/interaction behaviors và event emission. |
| Compute/VPS | Azure cho AI/RAG; BE và worker còn lại chưa chốt | Azure là quyết định cho AI service. Container Apps là phương án triển khai đề xuất; SKU, region, chi phí và môi trường Unity vẫn cần spike. Không tự suy ra toàn bộ hệ thống chạy Azure. |
| Payments | PayOS production | Thanh toán dịch vụ theo Building/tháng, entitlement, quotation/transaction/invoice metadata và AI usage settlement. |

LLM vẫn là decision gate giữa OpenAI và Gemini; Azure cho AI service không có nghĩa đã chọn LLM. Code không được phụ thuộc trực tiếp vào SDK LLM hay hạ tầng provider ngoài adapter/configuration boundary.

Hiện trạng code chưa đồng nhất hoàn toàn với kiến trúc đích: AI prototype còn ChromaDB/OpenAI và backend đã có nhánh triển khai password/JWT. Tài liệu này không tuyên bố các phần đó đã migrate sang `pgvector`/Firebase; migration code, dữ liệu và rollback phải được thiết kế, review và kiểm thử trong task riêng.

### 4.1. Ranh giới motion và runtime web

- Scene landing giữ một camera path và presentation state riêng. Scroll progress điều khiển camera/copy; khói, lửa và ánh sáng môi trường có animation nhẹ độc lập, dừng khi tab ẩn.
- WebGL không khả dụng hoặc `prefers-reduced-motion` phải chuyển sang ảnh tĩnh/fade ngắn nhưng giữ menu, nội dung và hai nhánh.
- ThreeUI (`@designcodeio/threeui@1.2.0`) là thư viện component React phụ trợ ở FE; component phải được kiểm tra trước khi dùng. Không đưa ThreeUI/Three.js vào BE hoặc Mobile và không dùng component có sẵn để giả định gameplay.
- `motion/react` chỉ xử lý UI/scroll transition; Remotion chỉ là công cụ tùy chọn cho storyboard/teaser dùng `useCurrentFrame()`, không phải dependency runtime đã chốt.

### 4.2. Cấu trúc source FE theo feature

FE tổ chức source theo feature-first để giảm phụ thuộc chéo và hỗ trợ bảo trì:

```text
src/
├─ app/                         # Next.js App Router; route/layout composition
├─ assets/ · components/ui/ · configs/
├─ features/
│  ├─ auth/{components,services,types}
│  ├─ landing/{components,scene,types}
│  ├─ learn/{components,services,types}
│  ├─ learning-hub/{components,services,types}
│  └─ organization/{components,services,types}
└─ hooks/ · layouts/ · services/ · store/ · utils/
```

`features/<name>` sở hữu logic nghiệp vụ và type riêng; `components/ui` là UI dùng chung; `services` là client/interceptor và adapter cross-feature; `configs` parse route/env không nhạy cảm; `store` chỉ giữ state liên route; `app/` và `layouts` chỉ composition. Landing scene và asset 3D được lazy-load theo route. FE hiện dùng Next.js App Router; không tạo lại `pages/`, root `App.tsx` hoặc cấu hình Vite. RAG/auth trong FE vẫn là tích hợp prototype cho tới khi nối Firebase và API production.

### 4.3. Kinh nghiệm triển khai Mobile Expo/React Native và bảo trì

Prototype Mobile dùng Expo Router nhưng giữ route mỏng: `app/` chỉ khai báo URL, layout và redirect; màn hình, model, service và test nằm trong `src/features/<feature>`. UI nền, theme token và store demo chỉ đặt ở `src/components`, `src/theme` và `src/store` khi thực sự dùng lại. Không tạo sẵn các thư mục `navigation`, `hooks`, `utils` rỗng; thêm chúng khi có logic dùng chung để tránh một nơi chứa “mọi thứ”.

Ranh giới runtime phải được giữ rõ:

- React Native/Expo chịu login, QR, cache metadata, điều hướng và trạng thái phiên. Three.js/ThreeUI là phụ thuộc DOM/CSS của FE, không đưa vào native UI.
- Hình low-poly ở lobby là PNG sprite tĩnh để tải nhanh và có fallback; 3D gameplay, hazard, A* và event vẫn thuộc Unity qua native bridge. Không dựng mesh Unity trong Expo để mô phỏng tính năng gameplay.
- Demo chỉ dùng allowlist QR và `AsyncStorage` cho session giả. Bản production phải resolve QR opaque qua API, kiểm tra `TrainingRelease`/`Training` đang active và xác minh quyền trước khi tải content; token đăng nhập phải dùng SecureStore, không lưu secret trong AsyncStorage hoặc deep link.

Nguyên tắc hiệu năng và độ bền:

- Import trực tiếp từng font/icon và chỉ nạp weight cần dùng; tránh barrel import toàn bộ family. Dùng `FlatList` khi danh sách tòa nhà tăng, giữ style/token ổn định ngoài hot path và giới hạn vùng map/sprite trong kích thước màn hình.
- Khóa callback camera sau lần QR hợp lệ, pause preview và reset lock khi unmount/scan lại để không tạo nhiều session. Mọi route nhận `id` từ deep link phải kiểm tra lại id đã lưu/API, không tin dữ liệu URL.
- Animation dùng Reanimated/native transition, tôn trọng `prefers-reduced-motion`/Reduce Motion và dừng camera khi screen mất focus hoặc app xuống nền. Chỉ tắt animation trong screenshot test; không tắt transition của runtime.
- State persist phải có version, validate id/ngày và migration rõ ràng. Khi backend sẵn sàng, thay demo provider bằng adapter API nhưng giữ interface của feature để màn hình không phụ thuộc transport.

Bảng lỗi đã gặp và cách phòng tái phát trong prototype:

| Triệu chứng | Nguyên nhân đã xác minh | Khắc phục và kiểm tra |
| :--- | :--- | :--- |
| Quét QR xong quay lại thấy hai lobby/nhãn trùng | `router.replace('/(tabs)')` đẩy một tab root mới vào stack | Dùng `router.dismissTo('/(tabs)')`; E2E kiểm tra không có duplicate label |
| TypeScript báo thiếu `absoluteFillObject` | Kiểu public SDK57/RN 0.86 expose `StyleSheet.absoluteFill` | Dùng `absoluteFill` và chạy typecheck + Android export |
| TypeScript 6 cảnh báo `baseUrl` deprecated | Cấu hình cũ dùng `baseUrl` chỉ để phục vụ alias | Bỏ `baseUrl`, giữ `paths` alias `@/*`; chạy typecheck sạch |
| Android bundle phình do nhiều asset font/icon | Barrel import nạp cả family dù chỉ dùng vài glyph/weight | Import trực tiếp; export giảm từ 67 xuống 35 asset (HBC khoảng 3.7 MB ở prototype) |
| Screenshot bottom sheet bị chụp giữa transition | Playwright chụp trước khi animation kết thúc | Chờ trạng thái ổn định; chỉ disable animation trong screenshot capture |
| Camera gọi nhiều lần cùng một mã | Callback `onBarcodeScanned` lặp trong lúc preview còn chạy | `scanLocked` + pause preview + reset lifecycle; test mã hợp lệ/không hợp lệ/lặp |
| Expo checker báo lệch patch | `expo` không khớp patch SDK trong lockfile | Chạy `expo install --check`, cập nhật patch tương thích rồi frozen install/typecheck/export |

Bằng chứng kiểm tra của prototype: `pnpm install --frozen-lockfile`, `pnpm typecheck`, `pnpm format:check`, `pnpm test` (5 model tests), Playwright Chrome (6 E2E tests), `expo install --check` và `expo export --platform android` đều đạt. Chưa nghiệm thu camera native, APK trên thiết bị, Unity bridge, auth backend hoặc tải content package; các hạng mục đó phải có smoke test riêng trước khi gọi là production-ready.

## 5. Domain model và trạng thái

Các aggregate cốt lõi là `Organization`, `Account`, `Building`, `BuildingRevision`, `IfcSource`, `ProcessingJob`, `ValidationRun`, `ValidationIssue`, `Scenario`, `ScenarioDraft`, `ScenarioVersion`, `TrainingRelease`, `Training`, `QrCode`, `TrainingSession`, `TrainingResult`, `AuditLog`, `Quotation`, `Transaction`, `PaymentProvisioningRecord`, `InvoiceMetadata`, `FeedbackTicket`.

Mọi aggregate tenant-scoped có `organizationId`. `Scenario` là logical object; `ScenarioVersion` pin `revisionId` và giữ hash/config bất biến. `TrainingRelease` pin `revisionId`, `scenarioId` và `scenarioVersionId`; `QrCode` cấp Building không FK tới Training/release và resolve danh sách Training; `TrainingSession` pin `trainingId`, `releaseId`, `scenarioVersionId` và `qrCodeId` để replay và reconcile không bị thay đổi bởi lần publish sau.

```text
RevisionStatus = Draft | Uploaded | Processing | NeedsFix | ReadyForScenario
               | ConfirmedForTraining | Rejected | Failed | Superseded
ReviewAction   = ConfirmForTraining | Rejected
ReleaseStatus  = Built | Published | Superseded | Revoked
SessionStatus  = Created | Launching | Running | Completed
               | CompletedWithSupersededRelease | ScenarioUnsurvivable
               | Aborted | Abandoned | Crashed
```

`ConfirmForTraining` là action persist trên `revision_reviews`; nó xác nhận một revision/version sau validation candidate package/scenario/editor. Revision được author nhiều Scenario; action này không khóa việc tạo version tương thích khác. Trạng thái chỉ biểu thị readiness tập huấn của capstone, không bao hàm bất kỳ quyết định chứng nhận hoặc phê duyệt PCCC nào.

Thứ tự backend là: validated IFC → scenario draft/version → optional organization playtest (Trial còn quota thử hoặc Building entitlement `Active`, kiểm tra tại start) → `ConfirmForTraining` cho đúng revision/version → release `Built`, package và matching Active `Training` → kiểm tra Building entitlement `Active` → publish release → canonical QR resolve danh sách bài → authenticated `Trainee` prepare/download/verify → API start online cấp launch grant → Unity gameplay/result. Trial không đủ cho publish/session Trainee và QR không thể là prerequisite của readiness.

## 6. IFC pipeline tự động

```text
IFC upload
  -> MIME/size/hash validation + private storage
  -> Python/IfcOpenShell/IfcConvert parse spatial hierarchy and units
  -> Blender script clean/decimate/LOD/material policy
  -> preview GLB + facts + stable IFC GlobalId mapping
  -> Unity build worker import/build runtime artifacts
  -> semantic floor graph + door/stair/exit mapping
  -> collider/NavMesh/link source + hazard grid
  -> connectivity/performance/object identity QA
  -> manifest draft + revision status
```

- IFC là định dạng source duy nhất. Các endpoint và UI import chỉ nhận IFC.
- Worker phải ghi toolchain version, hash source, unit/origin, floor metadata, stable IFC GlobalId và issue có thể truy vết qua GLB/Unity artifact.
- Blender/Unity xử lý tự động theo pipeline dùng chung; chủ tòa chỉ upload, kiểm tra preview và xác nhận issue. Không cam kết mọi IFC bất kỳ đều dùng được nếu thiếu semantic/geometry.
- QA yêu cầu floor hợp lệ, stable IDs, door endpoint chạm vùng điều hướng, stair/portal đúng tầng, spawn có route hoặc lỗi rõ ràng, collider không chặn nhầm đường và budget geometry/texture phù hợp Android.
- Raw IFC chỉ có ở backend/workstation private. Runtime nhận geometry/metadata tối thiểu cần cho package.

## 7. Scenario, hazard và route

`ScenarioVersion` lưu spawn, goal, fire/smoke/wind parameters, interaction anchors/catalog IDs, blocked elements, time limit, rubric, seed, schema/algorithm version và trọng số A* để kết quả tái lập. Cấu hình scenario tách khỏi geometry artifact. Wind theo khu vực/cửa là mô hình game đề xuất, không phải airflow/CFD đã kiểm chứng.

```text
cost(edge) = distance
           + hazardExposure * wh
           + congestion * wc
           + portalPenalty * wp
           + blocked * wb
```

Hazard runtime là surrogate nhẹ: grid lưu fire, smoke, visibility, wind influence và risk proxy. Lửa, khói, gió và cháy lan có lớp hiệu ứng hiển thị cùng trạng thái mô phỏng dùng cho visibility, exposure, route và scoring. Gió theo vùng/cửa/cửa sổ là mô hình game có thể kiểm thử, không phải CFD hoặc mô phỏng thông gió kỹ thuật.

Runtime có thư viện dùng chung cho movement, camera, collision, cửa và item interaction, lửa/khói/gió/cháy lan, event và scoring. Organization chỉ đặt/chọn/cấu hình capability; không viết script Unity cho từng Building. Basic NPC state machine/flow được triển khai theo budget thiết bị; analytics NPC chỉ mô tả scenario mô phỏng.

## 8. Runtime package, QR và Android handoff

Manifest tối thiểu gồm:

```json
{
  "schemaVersion": "1.0",
  "releaseId": "...",
  "buildingId": "...",
  "scenarioId": "...",
  "packageSha256": "...",
  "minRuntimeVersion": "..."
}
```

```text
QR opens web/app context
  -> Firebase Google Sign-In if needed
  -> API checks Building service entitlement online
  -> resolve list of Published Trainings
  -> Trainee selects one training/mode
  -> receive short-lived manifest/package URL for selected release
  -> download missing content and verify hash/schema/runtime
  -> POST /api/training/sessions (prepare, idempotency key; chưa cấp quyền start)
  -> POST /api/training/sessions/{sessionId}/start (online entitlement/QR/package check)
  -> native Android bridge launches Unity(sessionId, manifestPath, launchGrant, protocolVersion)
  -> Unity emits versioned events/result through bridge to React Native/Expo
  -> React Native/Expo syncs API
```

QR vật lý được gắn với Building nhưng chỉ là điểm resolve. Luồng quét không mở gameplay trên web và không cài APK mới; app dùng release đã chọn để tải content package Unity tương ứng. QR còn hoạt động để hiển thị trạng thái khi entitlement hết hạn.

Mọi session mới phải gọi bước `start` có kết nối để kiểm tra entitlement, QR và package rồi mới tạo launch grant; preparation và package cache không thay thế quyền này. Nếu mất mạng sau khi session bắt đầu, Mobile/Unity tiếp tục chạy, local queue giữ event/result và reconcile bằng `eventId` ổn định cùng sequence khi có mạng. Entitlement hết hạn sau start không chặn complete hoặc sync/reconcile.

### 8.1. Contract tích hợp Mobile–Unity–backend

Đây là contract ở mức yêu cầu để nhóm Mobile, Unity và backend triển khai thống nhất. Native Android bridge nối Mobile với Unity trên thiết bị; React Native/Expo chịu trách nhiệm gọi API. Các endpoint tham chiếu nằm ở mục 9; phần phân tích này không thêm endpoint hoặc migration database.

| Bên gửi → bên nhận | Dữ liệu trao đổi | Trách nhiệm |
| :--- | :--- | :--- |
| Mobile → backend → Mobile | QR opaque cấp Building, danh sách bài, kết quả chọn pin `Training`/release/scenario version, manifest và URL package ngắn hạn | Backend kiểm tra tài khoản, entitlement và lifecycle; Mobile tải, kiểm tra hash/schema/runtime trước khi launch. |
| Mobile → backend → Mobile | `prepare` tạo session preparation với idempotency key; `start` gửi start key/runtime để nhận launch `grant` online | Preparation chỉ pin training/release/scenario/QR và package metadata; backend chỉ cấp grant sau entitlement/QR/package/runtime check. Mobile dùng đúng package đã xác minh cho session này. |
| Mobile → bridge → Unity | `sessionId`, `manifestPath`, `grant`, `protocolVersion` | `manifestPath` trỏ đến manifest local đã xác minh mà Unity đọc được; bridge chuyển yêu cầu launch, Unity kiểm tra khả năng nhận protocol và nạp package. |
| Unity → bridge → Mobile | Event/result có session ID, `eventId`, schema version và sequence; thông tin release/scenario theo mục 10 | Unity phát dữ liệu của phiên; bridge chuyển callback về Mobile, giữ thông tin định danh và thứ tự. Lỗi launch/runtime phải được trả về Mobile với lý do. |
| Mobile → backend → Mobile | Event batch/result của cùng session; phản hồi chấp nhận hoặc từ chối từ API | Mobile gọi API khi online; backend kiểm tra grant, release pin, schema và chống ghi trùng. Callback Unity chưa phải xác nhận backend đã lưu kết quả. |

Unity không nhận access/refresh token dài hạn. Việc chọn thư viện bridge, phiên bản protocol được hỗ trợ và cấu trúc payload chi tiết phải được đối chiếu với code Mobile/Unity/backend trong đầu việc tích hợp tiếp theo; tài liệu Docs hiện tại không chứng minh các thành phần đó đã hoạt động.

## 9. API boundary

```text
POST /api/buildings
POST /api/buildings/{buildingId}/ifc
POST /api/revisions/{revisionId}/process
GET  /api/revisions/{revisionId}/issues
GET  /api/buildings/{buildingId}/editor-preview
POST /api/scenarios/{scenarioId}/draft
PUT  /api/scenario-drafts/{draftId}
POST /api/scenario-drafts/{draftId}/snapshot
GET  /api/scenario-interactions/catalog
POST /api/scenarios/{scenarioId}/playtests
POST /api/playtests/{playtestId}/start
POST /api/processing-jobs/{jobId}/retry
GET  /api/processing-jobs/{jobId}/qa
GET  /api/validation-runs/{validationRunId}
POST /api/scenarios
POST /api/revisions/{revisionId}/confirm-for-training
POST /api/releases/{releaseId}/publish
GET  /api/buildings/{buildingId}/trainings
GET  /api/qr/{qrToken}
GET  /api/qr/{qrToken}/trainings
POST /api/training/sessions
POST /api/training/sessions/{sessionId}/start
POST /api/training/sessions/{sessionId}/heartbeat
POST /api/training/sessions/{sessionId}/events:batch
POST /api/training/sessions/{sessionId}/complete
POST /api/training/reconcile
GET  /api/buildings/{buildingId}/service-entitlement
POST /api/quotations
POST /api/payments/payos/create
POST /api/payments/payos/webhook
POST /api/payments/{transactionId}/reconcile
GET  /api/organizations/{organizationId}/ai-usage
POST /api/organizations/{organizationId}/ai-overage-consents
GET  /api/ai/requests/{requestId}
POST /api/ai/usage/{requestId}/reconcile
POST /api/ai/organization/scenario-draft
POST /api/ai/trainee/answer
POST /api/feedback
```

Các endpoint trên là contract mục tiêu; code hiện tại chưa chứng minh chúng đã được triển khai. Endpoint ownership phải enforce account type, `organizationId`, Building entitlement, release/scenario pin, protocol/schema version, quota và audit. Playtest chỉ dành cho OrganizationUser đúng tenant, pin draft/version và loại khỏi learner analytics; start dùng Trial quota hoặc Active Building entitlement. QR resolve trả danh sách bài theo Building; preparation không cấp quyền, session start bắt buộc online entitlement `Active` và bài Published. AI draft không được tự mutate scenario hoặc publish; request/usage/consent có idempotency và source citations.

### 9.0. Quy tắc contract theo nhóm endpoint

| Nhóm | Quyền và điều kiện | Dữ liệu phải pin/ghi | Idempotency và lỗi chính |
|---|---|---|---|
| IFC, processing, QA | `OrganizationUser` đúng tenant; worker chỉ nhận artifact/source đã được backend cấp quyền | `buildingId`, `revisionId`, source hash, `jobId`, attempt, toolchain, artifact hash, QA issue/validation run | `jobKey` + attempt; retry không tạo artifact logic trùng; trả `409` khi revision không hợp lệ, `422` khi geometry/QA fail |
| Draft, snapshot, interaction catalog | `OrganizationUser` đúng tenant; draft có thể sửa, version snapshot mới append-only | `scenarioId`, `scenarioDraftId`, `revisionId`, `scenarioVersionId`, schema/hash, capability identifiers | draft update dùng version/ETag; snapshot retry không tạo version trùng; trả `409` conflict và `422` capability/geometry không hỗ trợ |
| Organization playtest | `OrganizationUser` đúng tenant; start kiểm tra Trial còn hạn/còn quota thử hoặc Building entitlement `Active`; không dùng QR công khai | `playtestId`, draft/version, package hash, service entitlement, runtime/protocol version | prepare/start key chống mở trùng; trả `403` sai tenant/hết entitlement/quota, `409` package chưa verify, `422` lỗi nghiêm trọng; hết hạn sau start không cắt phiên |
| QR, training list, Trainee session | `GET /api/qr/{qrToken}` chỉ trả public metadata/trạng thái được phép; danh sách bài cần Firebase identity; preparation không cấp quyền, `start` mới cần bài Published và Building entitlement `Active` online | QR → Building; session pin `trainingId`, `releaseId`, `scenarioVersionId`, `qrCodeId`, manifest/package hash, preparation key, start key, launch grant | prepare/start request key và event sequence chống trùng; trả `404/410` QR không hợp lệ/thu hồi, `403` hết quyền, `409` package/hash/schema không khớp; cache không cho offline start |
| Heartbeat, event, complete, reconcile | Chỉ Trainee sở hữu session; phải đúng launch grant và session status; mất mạng chỉ reconcile sau khi session đã bắt đầu | `sessionId`, `eventId`, release/scenario hash, sequence, client timestamps, sync state | event ID ổn định và sequence; trả `409` duplicate/conflict, `422` payload/schema lỗi, không cắt session đang chạy vì entitlement hết hạn |
| Billing, entitlement, settlement | OrganizationUser đúng tenant tạo quotation/payment; PlatformAdmin quản lý giá/quota; webhook chỉ trusted adapter | Building/package/duration/term/price/terms snapshot; payment transaction; deterministic entitlement/payment provisioning key; AI period/usage snapshot | quotation/payment/webhook/provisioning key chống trùng; trả `409` duplicate/mismatch, `402/403` chưa thanh toán/chưa đồng ý overage, có reconcile khi payment Applied nhưng cấp quyền lỗi |
| AI/RAG và usage | OrganizationUser chỉ corpus/BIM đúng tenant; Trainee chỉ corpus chung đã duyệt và dữ liệu cá nhân được phép | `requestId`, response type/status, citations/source version/scope, policy/reservation allocation, consent, usage/price snapshot | request idempotency; trả `422` input/safety gate, `409` quota/consent conflict, `200` `InsufficientEvidence` khi thiếu nguồn thay vì bịa |

### 9.1. Bảng thiết kế đích và hiện trạng code

| Năng lực | Thiết kế đích/SQL/ERD | Hiện trạng code đã đối chiếu | Việc còn thiếu |
|---|---|---|---|
| Scenario reuse | `scenarios` + immutable `scenario_versions` theo Scenario/version và revision tương thích | BE đã có entity Scenario/ScenarioVersion với nhiều trường hơn SQL cũ | Đồng bộ migration/EF mapping và API draft/snapshot; chưa triển khai trong task Docs |
| Building QR | QR chỉ có Building/tenant; session mới pin bài/release/version | Entity BE hiện còn `ReleaseId`/`TrainingId` | Refactor entity/API/migration có kế hoạch chuyển đổi; chưa chạy migration |
| Processing | `processing_jobs`, attempt, artifact/job, `validation_runs`/`validation_issues` và QA provenance | BE có ProcessingJob/ValidationRun/RevisionIssue | Đối chiếu tên cột, FK, severity/status và worker contract; chưa chứng minh runtime worker |
| Playtest | Organization-only draft/version package, entitlement Trial/Active kiểm tra ở start, giới hạn thử, loại khỏi learner analytics | Chưa có contract/runtime đã triển khai | Thiết kế grant/session type, quota reservation và native Unity flow |
| Billing | Quotation phân biệt BuildingService/AIUsage với duration/price/terms snapshot; entitlement/payment provisioning và AI settlement period | BE có entity payment/quotation nhưng chưa chứng minh provisioning/reconcile | Thiết kế EF/API/idempotency, deterministic provisioning và kiểm thử webhook sau task tài liệu |
| AI quota | Grant organization hoặc Trainee user; reservation allocations phân bổ grant, usage liên kết request/consent/price snapshot | AI prototype còn ChromaDB/OpenAI; BE chưa có production ledger | Firebase/pgvector migration, quota service và tenant/evidence tests |

Đây là bảng truy vết thiết kế, không phải tuyên bố code đã khớp hoặc database đã được migrate.

### 9.2. Nguồn chính của field và mapping triển khai

| Chủ đề | Nguồn chính trong thiết kế đích | Field giữ lại/loại bỏ | Hiện trạng code và phần còn thiếu |
|---|---|---|---|
| Processing | `processing_jobs` là logical job; `processing_job_attempts` là attempt/lease/toolchain/error | Bỏ attempt/lease/toolchain khỏi job; artifact/validation phải pin `attempt_id` | BE còn model job/validation cũ; cần EF mapping, claim/lease và stale-result test |
| Scenario routing/scoring | `routing_config` và `scoring_config` | Loại scalar scoring/replan trùng; thêm `time_limit_seconds` vào snapshot/hash | Entity BE có `TimeLimitSeconds` và một số scalar; cần hợp nhất mapping, không copy ngược vào SQL |
| Runtime | Catalog server quản lý | `app_version`, `unity_engine_version`, `runtime_version` là ba khái niệm riêng; package pin protocol/schema/capability | Mobile/Unity bridge và package manifest chưa chứng minh tương thích production |
| AI request/finance | `ai_requests` (kèm `policy_version_id`) → `ai_usage_reservations` + allocations → `ai_usage_ledger` → period items/adjustments | Request giữ trạng thái/kết quả kỹ thuật và policy đã áp dụng; allocation giữ lượt; ledger giữ usage/giá/consent; không dùng một `quota_grant_id` duy nhất làm nguồn phân bổ | AI prototype chưa có durable request; BE cần implementation và reconcile |
| Historical billing | Quotation/entitlement/payment/period snapshots | Lặp giá/terms là historical fact có chủ ý, không hợp nhất thành giá hiện tại | Entity BE và provider integration còn cần idempotency/reconcile |
| Tenant scope | Compound invariant giữa organization–Building–revision–scenario | Các `organization_id` lặp lại để lọc tenant/query; không xóa máy móc | Cần FK/validator và test cross-tenant |

Đây là contract thiết kế. SQL/ERD biểu diễn mục tiêu; code hiện tại chỉ là bằng chứng phần đã tồn tại và không được coi là migration đã chạy.

## 10. Security, privacy và reliability

- Web/Mobile đăng nhập qua Firebase Authentication, gồm Google Sign-In. API phải xác minh Firebase ID token ở server rồi nạp role, trạng thái tài khoản và `organizationId` từ PostgreSQL; custom claim hoặc dữ liệu client không thay thế authorization server-side.
- Firebase/Google refresh credential do Firebase SDK quản lý; database FET3D chỉ lưu Firebase UID mapping và metadata nghiệp vụ, không lưu password hash hoặc refresh token của Google. Launch grant/URL tải package vẫn là token ngắn hạn riêng do backend cấp cho đúng session/release.
- FCM registration token là dữ liệu thiết bị có thể thay đổi, không phải credential. Backend phải hỗ trợ cập nhật, vô hiệu hóa và xóa token khi logout, uninstall signal hoặc provider báo token không hợp lệ.
- QR opaque không cấp quyền độc lập; row cấp Building không pin một Training/release. Preparation chỉ kiểm tra identity và bài/release/scenario; backend kiểm tra identity, Building service entitlement `Active`, QR và package ở explicit start trước khi cấp launch grant. Không biến Trainee thành thành viên organization hoặc cấp quyền đọc tài liệu nội bộ.
- AWS S3 bucket private, signed URL TTL ngắn, hash verification và schema validation bảo vệ delivery pipeline. Không ghi AWS credential vào FE/Mobile hoặc QR.
- Supabase PostgreSQL/`pgvector` chỉ được truy cập qua backend/service identity theo quyền tối thiểu; không đưa service-role key vào client. Tenant filter áp dụng cho dữ liệu quan hệ, BIM facts, chunks và vector retrieval.
- LLM adapter chỉ gửi dữ liệu tối thiểu cần thiết đến provider đã chọn; không gửi raw IFC, secret hoặc dữ liệu tenant khác. Provider fallback không được tự động chuyển dữ liệu sang nhà cung cấp thứ hai nếu chưa có cấu hình/chấp thuận.
- RAG Organization lọc tenant/Building/floor/room trước vector retrieval; RAG Trainee chỉ dùng corpus public/published và dữ liệu cá nhân được phép. Citation, source version, BIM anchor và usage request id phải được lưu cùng output.
- AI usage chỉ được trừ một lần cho request thành công theo idempotency key, có reservation allocation, policy snapshot và overage consent. Lỗi provider, retry hoặc duplicate webhook không tạo usage trùng; overage hiển thị trước và được đối soát cuối kỳ organization.
- Event/result có `sessionId`, `eventId` ổn định, sequence, protocol/schema version và release/scenario hash.
- PayOS request được tạo `Pending` qua dedicated NOLOGIN executor chỉ có `EXECUTE`; function derive amount/currency/Building/organization từ quotation snapshot và runtime không có direct table DML. External PayOS call hoàn tất trước transaction database ngắn. Entitlement từng Building và lịch sử giá/điều khoản phải được ghi riêng.
- Trusted PayOS webhook adapter dùng SDK `webhooks.verify(req.body)` hoặc thuật toán chính thức canonicalize `data` theo thứ tự alphabet trước khi gọi dedicated webhook executor. SQL function không thực hiện mật mã; nó ghi attestation, chống replay/idempotent và so khớp `orderCode`, amount, currency. `returnUrl` chỉ điều hướng.
- Audit lưu upload, process, scenario, `ConfirmForTraining`, publish, QR, session, billing và support action.

## 11. Thứ tự delivery

| Đợt nền tảng | Đợt mở rộng |
| :--- | :--- |
| Web/API core, IFC worker, preview/editor, payment entitlement, AI/RAG contracts, private storage, release/package/QR Building, React Native/Expo–Unity online start, hazard/A*, session/result và audit. | Bridge production benchmark, mất mạng giữa session, NPC, expanded analytics, feedback/support, usage settlement và hardening vận hành. |

## 12. Kiểm thử và đánh giá capstone

- Pipeline: IFC upload → IfcOpenShell/Blender/Unity artifacts → QA/issues → preview/editor → `ReadyForScenario` → scenario/candidate package → `ConfirmForTraining` → `ConfirmedForTraining` → release `Built` + package + `Training` → entitlement → publish → QR Building → list/select Training → Android package → session/result → analytics.
- Editor: đặt lửa/khói/gió/blocked elements/items hợp lệ, lưu draft/version, undo/redo, issue anchor và AI draft không tự mutate.
- Runtime: hash mismatch, invalid grant, expired entitlement, revoked QR, route blocked, session retry, mất mạng giữa session, Unity bridge, nhiều lần mở/đóng và Android performance.
- Commercial/AI: duplicate PayOS webhook, duplicate AI request, quota/overage, invoice snapshot, tenant RAG isolation, citations và safety gate.
- Đánh giá chuyên môn, usability testing và user study thu thập phản hồi cho đồ án; chúng không là quyền trong kiến trúc và không tạo ra chứng nhận hoặc phê duyệt PCCC.

## 13. Phân tích đầu ra SCRUM-520 và bàn giao SCRUM-524

### 13.1. Mục tiêu và phân chia đầu ra

Phạm vi phân tích là tích hợp mục tiêu cuối với Web **Next.js**, Mobile **React Native/Expo**, native Android bridge và Unity gameplay. Stack và trách nhiệm nằm ở mục 4; luồng và contract nằm ở mục 8. Các capability được chia thành đợt triển khai, nhưng payment, editor và AI là một phần của mục tiêu sản phẩm.

| Công việc | Đầu ra có thể review | Điều kiện nghiệm thu |
| :--- | :--- | :--- |
| [SCRUM-520](https://baopgse183233.atlassian.net/browse/SCRUM-520) — phân tích và chia nhỏ yêu cầu | Stack/trách nhiệm, luồng và contract tối thiểu, phụ thuộc, checklist và đầu việc tiếp theo trong tài liệu này | Người review xác định được bên gửi/nhận, dữ liệu, điều kiện launch và cách kiểm tra từng phần; mọi phụ thuộc chưa xác minh được ghi rõ. |
| [SCRUM-524](https://baopgse183233.atlassian.net/browse/SCRUM-524) — triển khai tài liệu theo phân tích | README, kiến trúc, requirements, features, workflows, overview và chú thích phiên bản app trong schema thống nhất | Next.js/React Native/Unity thống nhất; bridge và API đúng trách nhiệm; liên kết và diff được kiểm tra; có PR vào `develop` để người phụ trách duyệt. |

Yêu cầu truy vết: `FR-AUTH-03` cho participation; `FR-RELEASE-02/03` cho resolve và package; `FR-TRAINING-02` cho handoff/event/result; `FR-ANALYTICS-02` cho kết quả cá nhân trong [tài liệu yêu cầu](fire_evacuation_requirements.md). [Workflow](fire-evacuation-training-workflows.md) mục 6–7 mô tả trình tự thực hiện.

### 13.2. Phụ thuộc và đầu việc code tiếp theo

Các đầu việc dưới đây là đề xuất bàn giao theo thành phần, chưa được gán mã ticket mới. Không suy ra trạng thái code từ việc tài liệu đã hoàn tất.

| Đầu việc đề xuất / nhóm phụ trách | Đầu vào cần có | Đầu ra và bằng chứng cần cung cấp |
| :--- | :--- | :--- |
| QR/package/session API — backend phối hợp worker | Training/release đã publish, QR active, tài khoản Trainee, manifest/package mẫu có hash | API resolve và session/grant chạy được; event/result được lưu đúng phiên; fixture và kết quả kiểm tra API. |
| Nhúng Unity và triển khai bridge — Mobile + Unity | Unity runtime có thể nhúng, package mẫu hợp lệ, contract mục 8.1 | Bản Android mở Unity, truyền launch data, nhận callback/event/result và lỗi; ghi rõ app/Unity/protocol version, kèm log/demo. |
| Nối luồng online — Mobile + backend | API và bridge đã kiểm tra độc lập | QR → verify → session → Unity → API → debrief cá nhân chạy xuyên suốt, truy vết cùng session/release. |
| Kiểm thử tích hợp Android — Mobile + Unity + backend | Bản Android, môi trường API, dữ liệu hợp lệ và dữ liệu lỗi | Kết quả từng ca ở mục 13.3, thiết bị/Android version, commit/build và log đã loại credential. |

Trong phạm vi checkout Docs, API session/grant, package mẫu và Unity nhúng **chưa được xác minh**. Nếu thiếu bất kỳ đầu vào tương ứng nào, ghi blocker của đầu việc đó cùng nhóm cần cung cấp, ảnh hưởng và bằng chứng để gỡ blocker. Tài liệu có thể review trước; nghiệm thu tích hợp phải chờ kiểm tra các phụ thuộc và chạy trên Android.

### 13.3. Checklist kiểm thử tích hợp cần bàn giao

Các ca sau là tiêu chí cho đầu việc code tiếp theo, chưa phải kết quả test đã chạy trong repo Docs.

| Ca kiểm tra | Kết quả mong đợi |
| :--- | :--- |
| Luồng hợp lệ online | Unity mở đúng package/session, trả event/result qua bridge; Mobile gửi API, backend lưu và Trainee xem được kết quả của mình. |
| QR hết hạn/revoke hoặc release không còn publish trước launch | Backend từ chối resolve hoặc cấp grant; Mobile hiển thị lý do, không mở training. |
| Hash package sai | Mobile báo xác minh thất bại và không launch package đó. |
| Schema/runtime/protocol không tương thích | Thành phần kiểm tra tương ứng từ chối trước gameplay, Mobile nhận được lỗi rõ ràng. |
| Grant hết hạn hoặc không hợp lệ | Từ chối thao tác yêu cầu grant hợp lệ; Mobile hiển thị lỗi, không coi phiên/kết quả là đã được backend chấp nhận. |
| Unity không mở được hoặc lỗi runtime | Mobile xử lý lỗi; session lỗi có lý do và không bị ghi thành hoàn thành thành công. |
| Gửi lại cùng event batch/result | Giữ nguyên session và `eventId`/sequence; backend không tạo bản ghi hoặc tính analytics trùng. |
| Mất mạng lúc prepare/start/sync | Có thể prepare metadata nhưng trước explicit start phải có mạng và không launch offline; sau khi session đã bắt đầu, local outbox/checkpoint giữ event/result rồi reconcile khi API có mạng. |

### 13.4. Bằng chứng review tài liệu

- Rà stack, chiều dữ liệu bridge/API, thuật ngữ và Phase 1/2 giữa các tài liệu; kiểm tra liên kết local và chạy `git diff --check`.
- Đính kèm diff/commit và PR vào `develop` khi bàn giao review; ghi kiểm tra đã chạy, phần chưa kiểm tra, phụ thuộc và blocker. Chỉ gắn link PR thực sự đã tạo.
- Người phụ trách duyệt nội dung và bằng chứng trước khi nghiệm thu ticket. Kiểm tra tài liệu không thay thế build/test Android; không ghi runtime hoặc CI đạt khi chưa có kết quả thực tế.

## 14. Ranh giới service, database và nhất quán dữ liệu — thiết kế đích

### 14.1. Phân chia thành phần

| Thành phần | Quyền sở hữu/trách nhiệm | Trạng thái |
| :--- | :--- | :--- |
| `.NET core` | Identity, tenant, Building, scenario, session, payment, entitlement, quota, usage ledger và dashboard | Đã chốt |
| `Nginx` | Reverse proxy tại điểm vào HTTP(S), chuyển request API tới .NET | Đã chốt công nghệ; chưa triển khai |
| `AI/RAG FastAPI` | Retrieval, generation, citations, safety và usage kỹ thuật; không tự tính tiền, sửa editor hoặc publish | Đã chốt chạy riêng trên Azure |
| `IFC/Blender worker` | Job xử lý nặng, facts, geometry, artifact và QA; retry theo logical job/attempt/lease/hash | Thiết kế đề xuất |
| `Unity build worker` | Unity Editor/toolchain, collider/NavMesh, runtime package và manifest | Thiết kế đề xuất |
| Notification/reconcile | Background task của BE, retry và audit | Chưa tách service riêng |

Azure là provider đã chốt cho AI/RAG service. Azure Container Apps là phương án triển khai đề xuất cho FastAPI; Container Apps Jobs là ứng viên cho tác vụ hữu hạn như IFC/Blender. SKU, region, giá, máy Unity và cách cấp license còn mở. Không thêm Kubernetes/service mesh/database riêng cho từng module trong phạm vi tài liệu này.

Luồng production mục tiêu là:

```text
Web/Mobile -> Nginx -> .NET API -> AI/RAG FastAPI on Azure
                             -> transactional outbox -> IFC/Blender or Unity worker
```

Prototype web/mobile còn gọi FastAPI trực tiếp; đây là hiện trạng cần chuyển đổi, không phải contract production. Client production chỉ gọi `.NET API`; backend xác minh Firebase, tenant, quota và scope trước khi gọi AI.

### 14.2. Contract liên service

Nginx là reverse proxy đã chốt cho điểm vào API. Backend tiếp tục kiểm tra identity, tenant, quota và scope trước khi gọi AI; không mở tuyến proxy cho client bỏ qua backend để gọi FastAPI. Vị trí chạy Nginx, domain, điểm kết thúc TLS và cấu hình upstream sẽ được xác định khi chốt triển khai BE. Quyết định này không thay đổi Azure cho AI hoặc biến Container Apps thành lựa chọn đã chốt. Cấu hình forwarded headers phải chỉ tin proxy được chỉ định; timeout, giới hạn request và retry cần phù hợp contract idempotency, không tự phát lại thao tác tính phí khi chưa biết kết quả.

- Request `.NET → AI` có `request_id`, idempotency key, audience, organization/building scope được phép, source/revision version, canonical input hash và timeout policy. Không gửi credential dài hạn hoặc raw IFC thừa.
- Response `AI → .NET` có `response_type`, status, citations/source version, BIM anchors khi sử dụng facts, model/provider version và usage kỹ thuật. AI không trả quyết định giá, overage hay quyền dịch vụ.
- Tra cứu `GET /api/ai/requests/{requestId}` là bắt buộc khi timeout; cùng key và cùng input trả kết quả đã lưu, cùng key khác input bị từ chối. Không tự retry tạo request mới trước khi xác minh trạng thái cũ.
- Worker message chỉ mang logical job ID, giao việc/event key, input hash và schema/toolchain reference. Worker claim qua backend mới được cấp attempt ID và lease token; message không mang sẵn lease của worker. Attempt hết lease không được ghi đè attempt mới; worker retry không tạo release/package/publication trùng.
- Service-to-service phải có credential/mTLS hoặc cơ chế workload identity có thể rotate. Network nội bộ không thay thế authorization và tenant scope.

### 14.3. Database ownership và ACID

Fire3D giữ một Supabase PostgreSQL + `pgvector` và AWS S3 cho file lớn. `.NET` sở hữu dữ liệu nghiệp vụ/billing/ledger; AI chỉ sở hữu hoặc ghi phần retrieval/indexing được cấp; worker không được ghi payment, entitlement hoặc publish trực tiếp. Các service dùng database role tối thiểu; không dùng chung service-role toàn quyền.

Quota phải được reserve bằng transaction PostgreSQL ngắn theo cùng thứ tự toàn hệ thống: **billing period nếu có → AI request → ledger/reservation → các grant theo `id` tăng dần**. Kiểm tra `units_used + units_reserved`, ghi allocation cho một hoặc nhiều grant pooled và tạo request/ledger cùng transaction. Không dùng `SKIP LOCKED` để kết luận hết quota. Gọi LLM, PayOS, S3 hoặc Unity nằm ngoài transaction. Sau đó transaction khác chốt `Recorded` hoặc giải phóng `Failed/Reversed` đúng một lần; timeout giữ trạng thái `NeedsReconcile` cho đến khi xác minh. `UNIQUE(request_id/idempotency_key)` chỉ chống request lặp, không thay cho khóa đồng thời.

Transactional outbox nối thay đổi đã commit với Redis Streams thông qua dispatcher. Dispatcher có lease/attempt/retry riêng; consumer/worker claim lease của processing job qua PostgreSQL, rồi chỉ ACK message sau khi kết quả đã được ghi bền vững. Redis Streams là phương án giao event/job có thể đọc lại; Redis Pub/Sub chỉ dành cho thông báo tiến độ không bắt buộc. Payment Applied nhưng entitlement chưa cấp và AI timeout đều đi qua reconcile, không tự suy đoán thành công/thất bại.

ACID áp dụng trong từng transaction PostgreSQL, không tạo một transaction nguyên tử xuyên Azure, S3, PayOS và LLM. PostgreSQL dùng `Read Committed` mặc định; quota/provisioning dùng row lock hoặc conditional update, chỉ dùng `Serializable` cho invariant thật sự cần và phải có retry giới hạn. Khi database/AI không khả dụng, không cấp quyền mới dựa trên cache; gameplay đã start vẫn tiếp tục và sync sau.

### 14.3.1. Redis event/cache contract

Luồng mục tiêu là: .NET transaction (nghiệp vụ + integration_outbox_events) → dispatcher claim/lease → Redis Stream → consumer/worker → PostgreSQL business result + integration_event_consumptions → commit → ACK. Redis không là nguồn trạng thái nghiệp vụ.

- Outbox dùng idempotency_key làm event key ổn định, kèm event type, schema version, aggregate ID, organization scope và canonical payload hash. Stream ID chỉ là mã lần giao, không thay thế event key.
- Dispatcher mất lease, message giao lặp hoặc mất ACK là tình huống bình thường. Cùng event key và hash được xử lý idempotent; khác hash trả conflict. Published chỉ có nghĩa đã gửi tới stream, không có nghĩa consumer đã hoàn tất.
- Worker không nhận lease processing trước từ message. Worker claim attempt/lease qua backend và ghi artifact/validation/result vào PostgreSQL; ACK chỉ sau khi xử lý hoặc bàn giao bền vững thành công.
- `enqueue_integration_outbox_event` là entry point tenant: allowlist duy nhất hiện tại là `ProcessingJob` + `ProcessingJobRequested` + schema `1`; function suy `organization_id` từ aggregate và từ chối `System`/`Platform`, event lạ và `ProcessingJobRequeue`. `enqueue_system_outbox_event` là entry point riêng cho `SystemNotification`/`PlatformCacheInvalidation` + schema `1`, chỉ executor hệ thống được gọi. Hai wrapper dùng helper nội bộ không cấp cho runtime; `ProcessingJobRequeue` chỉ được tạo bởi `requeue_processing_job`. Client không tự gửi scope tenant. Payload/hash/envelope bất biến, cùng key cùng envelope là no-op và khác envelope là conflict.
- Với `ProcessingJobRequested`, payload bắt buộc chứa `job_id` trùng `aggregate_id`; message không chứa attempt/lease/token của worker. Sai payload hoặc sai provenance bị từ chối trước khi dispatcher giao event.
- Requeue khóa theo event key trước khi xét trạng thái job. Cùng key và cùng envelope trả `AlreadyRequeued` dù job đã Queued, Running, Succeeded, Cancelled hoặc Failed lại; khác envelope trả `Conflict`. Key mới chỉ chuyển `Failed` sang Queued và tạo outbox trong cùng transaction; Queued/Running trả `Conflict`, Succeeded/Cancelled trả `NotClaimable`.
- Outbox claim dùng `FOR UPDATE SKIP LOCKED` riêng cho hàng đợi event, chỉ chọn Pending/Failed đến hạn hoặc Leased đã hết hạn; event đang leased không chặn event khác. Renew không được rút ngắn lease; mark/fail/replay phải có token hiện hành hoặc kết quả token đã hoàn tất.
- Consumer bắt đầu transaction, khóa/đối chiếu outbox rồi kiểm tra receipt trước tác động; nếu chưa xử lý thì ghi tác động và receipt trong cùng transaction, commit rồi mới ACK. Receipt cùng key/hash trả kết quả cũ trước tác động; message sai schema/hash/scope bị giữ để chẩn đoán kèm event key/stream ID, không ACK thành công hoặc retry nóng vô hạn.
- Redis mất message hoặc dispatcher mất phản hồi phải replay từ outbox PostgreSQL. Không tự trim outbox/receipt hoặc stream khi chưa qua cửa sổ recovery; `Published` chỉ xác nhận đã gửi, không xác nhận consumer hoàn tất.
- Redis mất dữ liệu hoặc dispatcher mất phản hồi phải replay từ outbox PostgreSQL. Không tạo dead-letter hoặc cache table chung trong đợt thiết kế này; lỗi giao việc nằm ở outbox, lỗi processing nằm ở job attempts.
- Cache dùng cache-aside cho catalog, package metadata, danh sách bài và dashboard. Key phải phân biệt môi trường, tenant/user khi cần và version dữ liệu; TTL, invalidation sau commit và chống stampede là một phần contract triển khai.
- Cache không được cấp quyền start/publish, xác nhận revoke QR, quota hoặc billing. Redis lỗi thì API đọc PostgreSQL với giới hạn tải và thể hiện trạng thái chậm/chờ; không báo thành công giả.
- Heartbeat và event/result gameplay vẫn ghi PostgreSQL trước khi backend xác nhận; Redis chỉ cache thống kê online. Production nên tách resource cache và Streams; số database logic trong một Redis instance không phải cách ly eviction.

Ma trận quyền tối thiểu cho outbox/requeue là: `fet3d_backend_executor` chỉ gọi các entry point backend được cấp; `fet3d_system_event_executor` chỉ gọi `enqueue_system_outbox_event`; `fet3d_dispatcher_executor` chỉ claim/renew/mark/fail delivery; `fet3d_requeue_owner` là `NOLOGIN` và thực thi `requeue_processing_job` với quyền cần thiết để khóa outbox, đọc `processing_jobs`/`revisions`/`buildings` và cập nhật job; `fet3d_processing_worker_executor` và `fet3d_ai_service_executor` không có quyền enqueue, requeue hoặc ghi receipt. Helper nội bộ, owner role và trigger không được cấp cho `PUBLIC`; quyền trigger/đọc gián tiếp phải được kiểm tra cùng effective owner. SQL hiện chỉ mô tả thiết kế đích, chưa chứng minh quyền đã chạy trên database.

### 14.4. Quyết định còn mở về vận hành

Region Azure/Supabase/S3/Redis, connection pool, timeout, RPO/RTO, backup/PITR, ngân sách AI, benchmark độ trễ liên cloud, catalog capability Unity, LLM/embedding model, Redis version/managed provider, stream retention, cache TTL/eviction, outbox recovery window và môi trường Unity build phải được chốt trước production. Tài liệu này không tuyên bố các ngưỡng đó đã benchmark hoặc hạ tầng đã tạo.

### 14.5. Các invariant đã sửa trong thiết kế đích

- Compatibility của release, Trainee start và OrganizationUser playtest dùng cùng `fet3d_runtime_package_is_compatible`. Manifest/artifact phải khai báo rõ `minRuntimeVersion`, `protocolVersion`, `manifestSchemaVersion` và `requiredCapabilities`; thiếu metadata bị từ chối. Không dùng `0.0.0`, protocol của session hoặc capability rỗng làm fallback.
- Start idempotency chỉ replay khi key và payload runtime khớp. Key đã dùng với runtime khác trả conflict; preparation không tạo launch grant hoặc `started_at`.
- Kỳ AI giữ bất biến snapshot tenant/kỳ/currency/giá/tổng tiền sau khi đóng. Chứng từ được gắn đúng một lần theo lifecycle: `Closed → Invoiced` gắn quotation `AIUsage`, `Invoiced → Paid` gắn payment `Applied`; tranh chấp chỉ là metadata riêng, không phải trạng thái settlement và không mở lại snapshot.
- `ai_requests` được kiểm tra ngay khi `INSERT`, gồm audience, user, tenant, Building và policy version. Request mới chỉ vào `Accepted` không có kết quả; policy/identity/input hash không được đổi sau khi tiếp nhận. Tài khoản bị khóa sau đó không chặn reconcile.
- `processing_jobs` là logical job có `input_hash`; attempt mới chỉ được claim khi job `Queued` hoặc attempt `Running` đã hết lease. Lease còn hạn trả `Busy`, job thành công trả attempt cũ, chỉ job `Failed` mới được requeue có chủ đích với key mới; replay key cũ là `AlreadyRequeued`, còn `Cancelled` là terminal và muốn chạy lại phải tạo job mới.
- Worker renew phải giữ đúng current attempt và lease token. Worker accept phải khớp job–attempt–revision–scenario–artifact–hash–validation; kết quả stale bị từ chối, replay cùng output đã chấp nhận là no-op. Worker không tự publish.

Các trạng thái contract worker được backend ánh xạ thành `Claimed`, `Busy`, `AlreadyCompleted`, `NotClaimable`, `StaleAttempt` hoặc `Conflict`; SQL có thể biểu diễn một số trạng thái bằng UUID kết quả hoặc lỗi có mã, nhưng API không được để client suy diễn từ thông báo tự do.

### 14.6. Hardening thiết kế đích — nguồn chính cho invariant

- `close_ai_billing_period` khóa period, đọc usage `Recorded`/billable, tạo `ai_billing_period_items` và đóng băng currency/đơn giá/tổng tiền trong cùng transaction. Trigger item khóa period trước mọi insert/update/delete; usage chưa xác định hoặc đến muộn chỉ đi qua `ai_billing_adjustments` có organization và idempotency key riêng.
- Period mới chỉ được insert ở `Open`; quotation `AIUsage` chỉ gắn ở `Closed → Invoiced`, payment `Applied` chỉ gắn ở `Invoiced → Paid`. Quotation/payment replay cùng chứng từ là no-op, khác chứng từ là conflict. Policy version, terminal AI result và snapshot billing không được sửa lịch sử.
- Reserve/settle khóa theo cùng thứ tự `billing period nếu có → ai_request → ledger/reservation → quota grant theo id tăng dần`. Request được khóa trước khi kiểm tra retry; không giữ transaction khi chờ FastAPI/LLM. User bị khóa sau khi request `Accepted` vẫn được reconcile. `close_ai_billing_period` lấy giá/currency/policy/consent đã lưu trên usage, không nhận đơn giá mới để tính lại lịch sử.
- Worker claim/renew/accept/fail đều khóa job trước attempt. Requeue là gate backend riêng, owner `fet3d_requeue_owner`; helper enqueue nội bộ không được cấp cho worker. Claim chỉ trả lease token mới khi `Claimed`; `Busy`, `AlreadyCompleted`, `NotClaimable` và `Conflict` không cấp token mới. Requeue `Failed` có key mới là thao tác backend có quyền, idempotent qua outbox; `Cancelled` là terminal.
- Runtime capability array phải gồm các chuỗi không rỗng; array rỗng được chấp nhận nếu manifest khai báo rõ. Publish tìm catalog active có protocol/schema khớp và runtime số học `>= minRuntimeVersion`, không yêu cầu catalog có chuỗi minimum y hệt. Package đã publish hoặc đã pin không được đổi provenance bằng cách thay `release_id`.
- Artifact/package đã publish hoặc đã được session pin là bất biến. Release package/session/playtest cùng pin `package hash`, `manifest hash`, `build target`, artifact ID và validation-run ID; hai attempt có cùng bytes vẫn có artifact provenance riêng; `result_validation_run_id` phải FK tới validation run đúng job/attempt/artifact/hash.

SQL/ERD bản 6.7 là thiết kế mục tiêu. Các ca concurrency, function privilege, database recovery và provider integration vẫn là acceptance tests chưa chạy; `git diff --check`/XML/link audit không thay thế các kiểm thử đó.

### 14.7. Bảng truy vết invariant cuối

| Invariant | INSERT/UPDATE/function chính | Quyền gọi thiết kế | Thành công | Từ chối/recovery | Tài liệu dẫn chiếu |
| :--- | :--- | :--- | :--- | :--- | :--- |
| AI billing snapshot | `close_ai_billing_period`, `enforce_ai_billing_period_item_write`, `validate_ai_billing_period_write` | `fet3d_accounting_executor`; `PUBLIC` không execute gate | `Open → Closed → Invoiced → Paid` với item/quotation/payment đúng snapshot | item/snapshot sửa sau close bị chặn; late usage qua adjustment; tranh chấp chỉ là metadata | Requirements FR-BILLING-RECOVERY-01, workflows 14 |
| AI request/result | `create_ai_request`, `enforce_ai_request_write_v2`, `record_ai_request_result`, `reserve_ai_usage`, `settle_ai_usage` | Backend request/result executor và `fet3d_accounting_executor`; AI không có billing DML | request `Accepted`, result evidence được ghi có kiểm soát, reserve/settle đúng một lần | sai tenant/policy bị chặn; timeout `NeedsReconcile`; retry khác input/evidence conflict | BIM/RAG, API contract, context AI/BE |
| Worker fencing | `claim_processing_attempt`, `renew_processing_attempt`, `accept_processing_attempt`, `fail_processing_attempt`, `requeue_processing_job` | worker dùng `fet3d_processing_worker_executor`; backend gọi requeue qua `fet3d_backend_executor`, function owner là `fet3d_requeue_owner`; bảng worker không DML trực tiếp | claim cấp lease, accept đúng provenance, requeue tạo outbox | `Busy`, `StaleAttempt`, `Conflict`, `NotClaimable`, `AlreadyRequeued`; attempt cũ không ghi đè | Requirements FR-PROCESS-02/03, workflows 15 |
| Redis outbox/consumer | `enqueue_integration_outbox_event`, `enqueue_system_outbox_event`, `requeue_processing_job`, `claim_integration_outbox_event`, `renew_integration_outbox_event`, `mark_integration_outbox_published`, `fail_integration_outbox_event`, `replay_integration_outbox_event`, `check_integration_event_consumption`, `record_integration_event_consumption` | Backend executor gọi tenant enqueue/replay/receipt và requeue; `fet3d_system_event_executor` chỉ system enqueue; `fet3d_dispatcher_executor` chỉ claim/renew/mark/fail; AI/worker không có enqueue | envelope `Pending` → dispatcher delivery; consumer effect + receipt commit rồi ACK; requeue tạo `ProcessingJobRequeue` qua gate riêng | key/envelope conflict, replay sau mọi trạng thái trả `AlreadyRequeued`, stale token, message sai metadata, Redis mất thì replay; không dùng cache để cấp quyền | Requirements Redis acceptance, workflows 13.4, ERD outbox |
| Runtime/package | `fet3d_capabilities_are_valid`, `fet3d_runtime_package_is_compatible`, package/session/playtest triggers | Publish/start backend gate; catalog server-side | semver hợp lệ, catalog đủ capability, hash/manifest/build target khớp | metadata thiếu/sai hoặc package pinned sửa tại chỗ bị chặn | Requirements FR-COMPAT-01, ERD package/session |
| Scenario/release | `validate_revision_review_action`, `apply_revision_review_action`, `validate_release_write` | OrganizationUser qua BE; release gate không cho client DML | readiness được xác nhận theo cặp revision–scenario version | Reject B không đổi A; revoke/supersede không chạy lại publish gate | Requirements FR-RELEASE, workflows 15 |

Bảng này mô tả thiết kế đích và đường kiểm tra tĩnh; chưa phải bằng chứng đã chạy concurrency, authorization hoặc recovery trên PostgreSQL.

Acceptance test triển khai cho contract Redis/outbox gồm: event đang leased không chặn event kế tiếp; hai dispatcher không nhận cùng lease; enqueue tenant không tạo được system event; system event chỉ executor riêng tạo được; trigger chặn INSERT sai trạng thái/hash; enqueue đồng thời cùng key chỉ tạo một envelope và khác envelope trả conflict; consumer mất ACK chỉ tạo một tác động và rollback không để receipt thành công; dispatcher không được ghi receipt/nghiệp vụ; replay key requeue sau Running/Succeeded/Cancelled/Failed trả `AlreadyRequeued`, key mới chỉ requeue `Failed`; Redis mất message có thể replay từ PostgreSQL; message sai metadata được giữ kèm event key/stream ID; cache cũ không vượt tenant/revoke/entitlement/quota/billing; heartbeat null bị chặn và preparation/playtest không vào learner analytics. Các luồng payment, AI quota/reconcile, publish/start và offline sync vẫn phải được chạy hồi quy. Đây là tiêu chí cho đợt triển khai, chưa phải kết quả đã pass.
