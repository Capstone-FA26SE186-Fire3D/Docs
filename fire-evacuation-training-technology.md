# Fire Evacuation Training 3D — Technology & Architecture

## 1. Mục tiêu kỹ thuật

FET3D tạo content package Unity từ **IFC** cho Building và phân phối package đó đến Android sau khi người dùng xác thực và quét QR. Ứng dụng Android được cài một lần; mỗi QR resolve release phù hợp, cho phép ứng dụng tải/verify manifest và content package rồi mở Unity.

Headline Phase 1: **IFC → 3D → Unity Android → QR → Training → Result**.

Kiến trúc phục vụ mô phỏng và tập huấn của đồ án. Nó không thực hiện CFD thiết kế, hệ thống điều khiển khẩn cấp, thẩm duyệt hoặc chứng nhận PCCC.

### 1.1. QR theo tòa nhà và ranh giới web/mobile

- Mỗi `Building` có một QR canonical để mở đúng training của tòa nhà. QR có thể được rotate/revoke khi release thay đổi; ở mỗi thời điểm chỉ QR active của release đã publish mới được dùng.
- QR chỉ chứa mã opaque hoặc deep link công khai để backend resolve `Building`/`TrainingRelease`; không nhúng model BIM, access token, credential hay APK.
- Mobile app được cài một lần. Sau khi quét, backend trả manifest và URL ngắn hạn để app tải, xác minh và cache content package của đúng tòa nhà; không tải/cài một game APK hoặc Unity runtime mới cho từng QR.
- FE dùng Three.js cho hiệu ứng landing/giới thiệu trên web. Gameplay BIM 3D với góc nhìn 2.5D chạy trong Unity runtime của Mobile, không phải game Three.js trên web. Landing dùng camera POV cuộn qua công trình đang cháy rồi rẽ sang hướng tập huấn hoặc tổ chức; chi tiết màu, font, motion và fallback nằm trong [đặc tả UX web](fire3d-web-ux-design.md). Nếu chưa cài app, landing chỉ dẫn tới kênh cài đặt hợp lệ.

## 2. Ba loại tài khoản và ownership

| Tài khoản | Quyền kiến trúc cần hỗ trợ |
| :--- | :--- |
| `PlatformAdmin` | Quản trị platform, organization, account, health, support và aggregate vận hành. |
| `OrganizationUser` | Sở hữu Building, IFC, scenario, publish, QR, analytics và billing trong `organizationId`. |
| `Trainee` | Quét bất kỳ QR active của release đã publish, tham gia session và truy cập kết quả cá nhân. |

Không triển khai bảng/cơ chế thành viên, lời mời, truy cập khách, token khách hoặc training không định danh. `organizationId` bảo vệ ownership của Building, authoring, analytics và billing. QR participation là ngoại lệ có chủ đích: mọi `Trainee` đã xác thực có thể dùng bất kỳ QR active của release đã publish, không có account-specific permission, allowlist hoặc đối chiếu `organizationId`.

## 3. Kiến trúc tổng thể

```text
PlatformAdmin / OrganizationUser web
            |
      Next.js web application
            |
 ASP.NET Core API + background jobs
      |             |              |
PostgreSQL       MinIO        IFC processing worker
      |             |              |
 audit/session    private IFC  runtime geometry/graph/manifest
      \             |             /
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

Backend là nguồn sự thật cho ownership scope, Building, revision, scenario, release, session, analytics và billing. Unity không giữ access token dài hạn, không tự chọn release và không thay đổi quyền. QR resolve cho `Trainee` xác thực không bị giới hạn bởi ownership scope của release.

## 4. Thành phần và stack

| Lớp | Công nghệ | Trách nhiệm |
| :--- | :--- | :--- |
| Web | Next.js + Three.js (landing/intro effects) | Next.js vận hành Building, IFC, scenario, release, QR, analytics, billing và support; Three.js chỉ phục vụ landing/giới thiệu. |
| API/jobs | ASP.NET Core | AuthZ, domain command, QR resolve, session, audit, billing webhook và job orchestration. |
| Database | PostgreSQL | Dữ liệu tenant-scoped, revision, release, session/result, analytics, quotation/transaction/invoice metadata. |
| Object storage | MinIO S3-compatible | Raw IFC private, manifest và content package bất biến. |
| IFC worker | Python + IfcOpenShell + Blender/Bonsai khi cần | Parse IFC, geometry/LOD, graph, QA và package input. |
| Android shell | React Native/Expo + native Android bridge | Login, QR, download/verify/cache, local queue Phase 2 và Unity handoff. |

| Native Android bridge | Thành phần tích hợp Mobile–Unity | Nhận yêu cầu launch từ Mobile, truyền dữ liệu cho Unity và chuyển callback/event/result về Mobile. |
| 3D runtime | Unity 6 LTS + URP + Addressables | Scene, navigation, hazard surrogate, A*, basic NPC Phase 2 và event emission. |
| Payments | PayOS production (Phase 2) | Quotation flow, transaction, invoice metadata và revenue signals. |

### 4.1. Ranh giới motion và runtime web

- Scene landing giữ một camera path và presentation state riêng. Scroll progress điều khiển camera/copy; khói, lửa và ánh sáng môi trường có animation nhẹ độc lập, dừng khi tab ẩn.
- WebGL không khả dụng hoặc `prefers-reduced-motion` phải chuyển sang ảnh tĩnh/fade ngắn nhưng giữ menu, nội dung và hai nhánh.
- ThreeUI (`@designcodeio/threeui@1.2.0`) là thư viện component React phụ trợ ở FE; component phải được kiểm tra trước khi dùng. Không đưa ThreeUI/Three.js vào BE hoặc Mobile và không dùng component có sẵn để giả định gameplay.
- `motion/react` chỉ xử lý UI/scroll transition; Remotion chỉ là công cụ tùy chọn cho storyboard/teaser dùng `useCurrentFrame()`, không phải dependency runtime đã chốt.

## 5. Domain model và trạng thái

Các aggregate cốt lõi là `Organization`, `Account`, `Building`, `BuildingRevision`, `IfcSource`, `ScenarioVersion`, `TrainingRelease`, `Training`, `QrCode`, `TrainingSession`, `TrainingResult`, `AuditLog`, `Quotation`, `Transaction`, `InvoiceMetadata`, `FeedbackTicket`.

Mọi aggregate tenant-scoped có `organizationId`. `TrainingRelease` pin `revisionId` và `scenarioId`; mỗi `QrCode` pin một `Training`; `TrainingSession` pin `trainingId`, `releaseId`, `scenarioId` và `qrCodeId` để replay và reconcile không bị thay đổi bởi lần publish sau.

```text
RevisionStatus = Draft | Uploaded | Processing | NeedsFix | ReadyForScenario
               | ConfirmedForTraining | Rejected | Failed | Superseded
ReviewAction   = ConfirmForTraining | Rejected
ReleaseStatus  = Built | Published | Superseded | Revoked
SessionStatus  = Created | Launching | Running | Completed
               | CompletedWithSupersededRelease | ScenarioUnsurvivable
               | Aborted | Abandoned | Crashed
```

`ConfirmForTraining` là action persist trên `revision_reviews`; nó chuyển revision đã khóa từ `ReadyForScenario` sang `ConfirmedForTraining` sau validation candidate package/scenario. Trạng thái này chỉ biểu thị readiness tập huấn của capstone, không bao hàm bất kỳ quyết định chứng nhận hoặc phê duyệt PCCC nào.

Thứ tự backend duy nhất là: validated IFC + scenario/candidate-package readiness → `ConfirmForTraining` → revision `ConfirmedForTraining` → tạo release `Built`, package và matching Active `Training` → publish release → tạo active QR pin `training_id` → authenticated `Trainee` tạo session/result. QR không thể là prerequisite của `ConfirmForTraining`.

## 6. IFC pipeline

```text
IFC upload
  -> MIME/size/hash validation + private storage
  -> parse spatial hierarchy and units
  -> tessellate/LOD runtime geometry
  -> semantic floor graph + door/stair/exit mapping
  -> NavMesh source + hazard grid
  -> connectivity/performance QA
  -> manifest draft + revision status
```

- IFC là định dạng source duy nhất. Các endpoint và UI import chỉ nhận IFC.
- Worker phải ghi toolchain version, hash source, unit/origin, floor metadata và issue có thể truy vết.
- QA yêu cầu floor hợp lệ, stable IDs, door endpoint chạm vùng điều hướng, stair/portal đúng tầng, spawn có route hoặc lỗi rõ ràng, và budget geometry/texture phù hợp Android.
- Raw IFC chỉ có ở backend/workstation private. Runtime nhận geometry/metadata tối thiểu cần cho package.

## 7. Scenario, hazard và route

`ScenarioVersion` lưu spawn, goal, hazard parameters, time limit, rubric, seed và trọng số A* để kết quả tái lập.

```text
cost(edge) = distance
           + hazardExposure * wh
           + congestion * wc
           + portalPenalty * wp
           + blocked * wb
```

Hazard runtime là surrogate nhẹ: grid lưu fire, smoke, visibility và risk proxy. Nó được dùng để thay đổi chi phí route và phản hồi trong game, không được diễn giải là mô phỏng kỹ thuật dùng để thiết kế hoặc quyết định cứu nạn thực tế.

Phase 1 không chạy NPC. Phase 2 có basic NPC state machine/flow đơn giản với budget render/logical agent công bố; bất kỳ analytics nào về NPC chỉ mô tả scenario mô phỏng.

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
React Native/Expo scan QR
  -> API validates authenticated Trainee + active QR
  -> resolve exactly one pinned Active Training + Published release
  -> receive short-lived manifest/package URL
  -> download and verify hash/schema/runtime
  -> create TrainingSession and launch grant
  -> native Android bridge launches Unity(sessionId, manifestPath, grant, protocolVersion)
  -> Unity emits versioned events/result through bridge to React Native/Expo
  -> React Native/Expo syncs API
```

QR vật lý được gắn với Building/training cụ thể nhưng chỉ là điểm resolve. Luồng quét không mở gameplay trên web và không cài APK mới; app dùng release đã pin để tải content package Unity tương ứng.

Phase 1 yêu cầu kết nối cho launch và sync. Phase 2 thêm cache state `Missing -> Downloading -> Verified -> ReadyOffline`, local queue có monotonic sequence/idempotency key và reconcile retry khi kết nối trở lại.

### 8.1. Contract tích hợp Mobile–Unity–backend

Đây là contract ở mức yêu cầu để nhóm Mobile, Unity và backend triển khai thống nhất. Native Android bridge nối Mobile với Unity trên thiết bị; React Native/Expo chịu trách nhiệm gọi API. Các endpoint tham chiếu nằm ở mục 9; phần phân tích này không thêm endpoint hoặc migration database.

| Bên gửi → bên nhận | Dữ liệu trao đổi | Trách nhiệm |
| :--- | :--- | :--- |
| Mobile → backend → Mobile | QR opaque, kết quả resolve pin `Training`/release, manifest và URL package ngắn hạn | Backend kiểm tra tài khoản và lifecycle; Mobile tải, kiểm tra hash/schema/runtime trước khi launch. |
| Mobile → backend → Mobile | Yêu cầu tạo session cho training đã resolve; `sessionId` và launch `grant` do backend cấp | Backend pin training/release/scenario/QR của session. Mobile dùng đúng package đã xác minh cho session này. |
| Mobile → bridge → Unity | `sessionId`, `manifestPath`, `grant`, `protocolVersion` | `manifestPath` trỏ đến manifest local đã xác minh mà Unity đọc được; bridge chuyển yêu cầu launch, Unity kiểm tra khả năng nhận protocol và nạp package. |
| Unity → bridge → Mobile | Event/result có session ID, schema version, sequence và idempotency key; thông tin release/scenario theo mục 10 | Unity phát dữ liệu của phiên; bridge chuyển callback về Mobile, giữ thông tin định danh và thứ tự. Lỗi launch/runtime phải được trả về Mobile với lý do. |
| Mobile → backend → Mobile | Event batch/result của cùng session; phản hồi chấp nhận hoặc từ chối từ API | Mobile gọi API khi online; backend kiểm tra grant, release pin, schema và chống ghi trùng. Callback Unity chưa phải xác nhận backend đã lưu kết quả. |

Unity không nhận access/refresh token dài hạn. Việc chọn thư viện bridge, phiên bản protocol được hỗ trợ và cấu trúc payload chi tiết phải được đối chiếu với code Mobile/Unity/backend trong đầu việc tích hợp tiếp theo; tài liệu Docs hiện tại không chứng minh các thành phần đó đã hoạt động.

## 9. API boundary

```text
POST /api/buildings
POST /api/buildings/{buildingId}/ifc
POST /api/revisions/{revisionId}/process
GET  /api/revisions/{revisionId}/issues
POST /api/scenarios
POST /api/revisions/{revisionId}/confirm-for-training
POST /api/releases/{releaseId}/publish
POST /api/trainings/{trainingId}/qr
GET  /api/qr/{opaqueCode}/resolve
POST /api/training/sessions
POST /api/training/sessions/{sessionId}/events:batch
POST /api/training/sessions/{sessionId}/complete
POST /api/training/reconcile
POST /api/quotations
POST /api/payments/payos/webhook
POST /api/feedback
```

Các endpoint quotation, PayOS, transaction, invoice metadata, revenue, feedback/support, offline reconcile, basic NPC configuration và expanded analytics là Phase 2. Endpoint ownership Phase 1 phải enforce account type, `organizationId`, release pin, protocol/schema version và audit tác vụ nhạy cảm. QR resolve/session entry chỉ yêu cầu `Trainee` xác thực cùng QR active pin một `Training` active và release `Published` khớp; không áp dụng account-specific permission, allowlist hoặc đối chiếu `organizationId`.

## 10. Security, privacy và reliability

- JWT/refresh token, server-side authorization và tenant filter bắt buộc cho mọi command/query.
- QR opaque không cấp quyền độc lập; mỗi row pin đúng một `training_id` và `release_id`. Backend luôn kiểm tra `Trainee` đã xác thực, QR active/chưa hết hạn, `Training` active, release `Published`, và toàn bộ release/Training/scenario/organization khớp. Không áp dụng organization scope, account-specific permission hoặc allowlist cho eligibility của `Trainee`.
- Private IFC, manifest/package URL ký TTL ngắn, hash verification và schema validation bảo vệ delivery pipeline.
- Event/result có `sessionId`, sequence, idempotency key, protocol/schema version và release/scenario hash.
- PayOS request Phase 2 được tạo `Pending` qua dedicated NOLOGIN executor chỉ có `EXECUTE`; function derive amount/currency/organization từ quotation và runtime không có direct table DML. External PayOS call hoàn tất trước transaction database ngắn.
- Trusted PayOS webhook adapter dùng SDK `webhooks.verify(req.body)` hoặc thuật toán chính thức canonicalize `data` theo thứ tự alphabet trước khi gọi dedicated webhook executor. SQL function không thực hiện mật mã; nó ghi attestation, chống replay/idempotent và so khớp `orderCode`, amount, currency. `returnUrl` chỉ điều hướng.
- Audit lưu upload, process, scenario, `ConfirmForTraining`, publish, QR, session, billing và support action.

## 11. Phase delivery

| Phase 1 | Phase 2 |
| :--- | :--- |
| Web/API core, IFC worker, private storage, release/package/QR, React Native/Expo–Unity online flow, hazard/A*, session/result, audit và analytics cơ bản. | PayOS production, quotation, transaction, invoice metadata, revenue, feedback/support, basic offline, basic NPC và expanded analytics. |

## 12. Kiểm thử và đánh giá capstone

- Pipeline: IFC upload → QA → `ReadyForScenario` → scenario/candidate package → `ConfirmForTraining` → `ConfirmedForTraining` → release `Built` + package + `Training` → publish → QR → Android package → session/result → analytics.
- Runtime: hash mismatch, invalid grant, revoked QR, route blocked, session retry và Android performance.
- Phase 2: offline queue/reconcile, basic NPC budget, PayOS webhook idempotency, quotation/transaction/invoice/revenue và support lifecycle.
- Đánh giá chuyên môn, usability testing và user study thu thập phản hồi cho đồ án; chúng không là quyền trong kiến trúc và không tạo ra chứng nhận hoặc phê duyệt PCCC.

## 13. Phân tích đầu ra SCRUM-520 và bàn giao SCRUM-524

### 13.1. Mục tiêu và phân chia đầu ra

Phạm vi phân tích là tích hợp Phase 1 online, với Web **Next.js**, Mobile **React Native/Expo**, native Android bridge và Unity gameplay. Stack và trách nhiệm nằm ở mục 4; luồng và contract nằm ở mục 8. Offline, NPC và billing production vẫn thuộc Phase 2.

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
| Gửi lại cùng event batch/result | Giữ nguyên session và idempotency key; backend không tạo bản ghi hoặc tính analytics trùng. |
| Mất mạng lúc launch/sync | Phase 1 báo thiếu kết nối/lỗi đồng bộ, không báo kết quả đã lưu khi API chưa xác nhận; offline runtime thuộc Phase 2. |

### 13.4. Bằng chứng review tài liệu

- Rà stack, chiều dữ liệu bridge/API, thuật ngữ và Phase 1/2 giữa các tài liệu; kiểm tra liên kết local và chạy `git diff --check`.
- Đính kèm diff/commit và PR vào `develop` khi bàn giao review; ghi kiểm tra đã chạy, phần chưa kiểm tra, phụ thuộc và blocker. Chỉ gắn link PR thực sự đã tạo.
- Người phụ trách duyệt nội dung và bằng chứng trước khi nghiệm thu ticket. Kiểm tra tài liệu không thay thế build/test Android; không ghi runtime hoặc CI đạt khi chưa có kết quả thực tế.
