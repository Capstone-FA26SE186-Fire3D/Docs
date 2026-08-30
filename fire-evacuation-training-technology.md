# Fire Evacuation Training 3D — Technology & Architecture

## 1. Mục tiêu kỹ thuật

FET3D tạo content package Unity từ **IFC** cho Building và phân phối package đó đến Android sau khi người dùng xác thực và quét QR. Ứng dụng Android được cài một lần; mỗi QR resolve release phù hợp, cho phép ứng dụng tải/verify manifest và content package rồi mở Unity.

Headline Phase 1: **IFC → 3D → Unity Android → QR → Training → Result**.

Kiến trúc phục vụ mô phỏng và tập huấn của đồ án. Nó không thực hiện CFD thiết kế, hệ thống điều khiển khẩn cấp, thẩm duyệt hoặc chứng nhận PCCC.

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
       Flutter Android shell (installed once)
                        |
         verified content package + Unity runtime
                        |
         hazard surrogate / A* / event / result
```

Backend là nguồn sự thật cho ownership scope, Building, revision, scenario, release, session, analytics và billing. Unity không giữ access token dài hạn, không tự chọn release và không thay đổi quyền. QR resolve cho `Trainee` xác thực không bị giới hạn bởi ownership scope của release.

## 4. Thành phần và stack

| Lớp | Công nghệ | Trách nhiệm |
| :--- | :--- | :--- |
| Web | Next.js | Vận hành Building, IFC, scenario, release, QR, analytics, billing và support. |
| API/jobs | ASP.NET Core | AuthZ, domain command, QR resolve, session, audit, billing webhook và job orchestration. |
| Database | PostgreSQL | Dữ liệu tenant-scoped, revision, release, session/result, analytics, quotation/transaction/invoice metadata. |
| Object storage | MinIO S3-compatible | Raw IFC private, manifest và content package bất biến. |
| IFC worker | Python + IfcOpenShell + Blender/Bonsai khi cần | Parse IFC, geometry/LOD, graph, QA và package input. |
| Android shell | Flutter | Login, QR, download/verify/cache, local queue Phase 2, Unity handoff. |
| 3D runtime | Unity 6 LTS + URP + Addressables | Scene, navigation, hazard surrogate, A*, basic NPC Phase 2 và event emission. |
| Payments | PayOS production (Phase 2) | Quotation flow, transaction, invoice metadata và revenue signals. |

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
Flutter scan QR
  -> API validates authenticated Trainee + active QR
  -> resolve exactly one pinned Active Training + Published release
  -> receive short-lived manifest/package URL
  -> download and verify hash/schema/runtime
  -> create TrainingSession and launch grant
  -> launch Unity(sessionId, manifestPath, grant, protocolVersion)
  -> Unity emits versioned events/result
  -> Flutter syncs API
```

Phase 1 yêu cầu kết nối cho launch và sync. Phase 2 thêm cache state `Missing -> Downloading -> Verified -> ReadyOffline`, local queue có monotonic sequence/idempotency key và reconcile retry khi kết nối trở lại.

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
| Web/API core, IFC worker, private storage, release/package/QR, Flutter–Unity online flow, hazard/A*, session/result, audit và analytics cơ bản. | PayOS production, quotation, transaction, invoice metadata, revenue, feedback/support, basic offline, basic NPC và expanded analytics. |

## 12. Kiểm thử và đánh giá capstone

- Pipeline: IFC upload → QA → `ReadyForScenario` → scenario/candidate package → `ConfirmForTraining` → `ConfirmedForTraining` → release `Built` + package + `Training` → publish → QR → Android package → session/result → analytics.
- Runtime: hash mismatch, invalid grant, revoked QR, route blocked, session retry và Android performance.
- Phase 2: offline queue/reconcile, basic NPC budget, PayOS webhook idempotency, quotation/transaction/invoice/revenue và support lifecycle.
- Đánh giá chuyên môn, usability testing và user study thu thập phản hồi cho đồ án; chúng không là quyền trong kiến trúc và không tạo ra chứng nhận hoặc phê duyệt PCCC.
