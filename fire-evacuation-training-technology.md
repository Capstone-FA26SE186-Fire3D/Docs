# Fire Evacuation Training 3D - Tổng Hợp Công Nghệ

> Đặc tả kỹ thuật và kiểm thử cho hệ thống mô phỏng sơ tán cháy 3D. Cập nhật: 03/08/2026.

## 1. Ràng Buộc Và Mục Tiêu Kỹ Thuật

### 1.1. Ràng Buộc Đã Chốt

- Team 4 người, 12 tháng, ngân sách tối đa 2 triệu đồng.
- Android-first; không VR, không iOS trong đồ án.
- Thiết bị đích là Android tầm trung khoảng 6 GB RAM.
- Máy phát triển Ryzen 7 4800H, RAM 24 GB, GTX 1650 4 GB, còn khoảng 92 GB trống.
- Ưu tiên phần mềm miễn phí/education; chỉ trả phí cho dữ liệu chuyên gia, thiết bị hoặc compute thật sự cần.
- Backend .NET, mobile Flutter, web Next.js và game Unity là bốn phần tách rời nhưng có hợp đồng versioned.

### 1.2. Mục Tiêu Đo Được

- 30 FPS mục tiêu ở vertical slice trên thiết bị 6 GB RAM.
- 15 phút Guided Drill không crash hoặc mất session.
- 20 chu kỳ Flutter → Unity → Flutter liên tiếp không tạo duplicate session.
- Package có hash, có thể resume download, verify và chạy offline.
- Mọi spawn hợp lệ phải có route hoặc trả `NoModeledRoute` có lý do.
- Không có lỗi truy cập chéo tenant trong test authorization.

## 2. Stack Chính

| Lớp | Công nghệ baseline | Vai trò |
|---|---|---|
| Backend/API | .NET 10 LTS, ASP.NET Core | auth, tenant, workflow, delivery, session |
| Database | PostgreSQL | entity, revision, graph metadata, analytics |
| Object storage | MinIO S3-compatible | IFC/PDF/DXF, GLB, Addressables, manifest |
| Admin web | Next.js 16.2, TypeScript | upload, 3D preview, annotation, review, dashboard |
| Mobile shell | Flutter 3.44.x | login, QR, download/cache, campaign, bridge |
| 3D training | Unity 6.3 LTS, URP | runtime, input, camera, UI, hazard, NPC |
| BIM processing | IfcOpenShell/IfcConvert 0.8.5, Blender/Bonsai | parse IFC, geometry, semantic extraction |
| Fire reference | NIST CFAST, FDS/Smokeview | tạo benchmark, calibrate surrogate |
| CI/version | GitHub Education, Git LFS giới hạn | source, checksum, issue, release notes |

Không dùng API LLM trả phí cho quyết định an toàn. RAG chỉ là stretch có kiểm soát và không nằm trong đường chạy core.

## 3. Kiến Trúc Tổng Thể

```text
                 +-----------------------------+
                 | Next.js Authoring/Dashboard|
                 +--------------+--------------+
                                |
                         HTTPS JSON/API
                                |
+-------------------------------v-------------------------------+
| ASP.NET Core .NET 10: Auth | Tenant | Jobs | Release | Events |
+----------------------+-------------------+-------------------+
                       |                   |
             PostgreSQL metadata       MinIO object storage
                       |                   |
             revision/graph/events    IFC/GLB/Addressables
                       |                   |
                 signed manifest/content URL
                       |
             Flutter Android shell + QR/cache
                       |
                  Unity as a Library
                       |
              hazard grid / A* / NPC / result
```

Backend là nguồn sự thật cho quyền, revision, release, session và result. Unity không tự quyết định quyền hoặc release hiện tại.

## 4. Domain Model Và Tenant Isolation

### 4.1. Entity

```text
Organization
Membership
Building
BuildingRevision
SourceDocument
AnnotationSet
ReviewRecord
TrainingRelease
Checkpoint
ScenarioVersion
Campaign
Assignment
TrainingSession
SessionEvent
TrainingResult
AuditLog
```

Các entity tenant-scoped bắt buộc có `organizationId`. `BuildingRevision` tham chiếu `buildingId`; `TrainingRelease` tham chiếu revision bất biến; `TrainingSession` lưu `releaseId` đã pin.

### 4.2. Trạng Thái Revision

```text
Draft
Uploaded
Processing
NeedsFix
ReviewRequired
Approved
Published
Superseded
```

Worker chỉ chuyển `Processing -> NeedsFix/ReviewRequired`. Chỉ reviewer/owner có quyền chuyển sang `Approved`; publish tạo release mới và không sửa snapshot cũ.

### 4.3. Bảo Mật Dữ Liệu

- JWT/refresh token cho member/operator; guest dùng opaque QR grant ngắn hạn.
- Mọi query repository nhận tenant context và phải có integration test cross-tenant.
- Raw source file đưa vào quarantine, kiểm tra MIME, kích thước, hash và malware scan trước khi worker đọc.
- Mobile chỉ nhận package đã approve, không nhận raw IFC hay issue nội bộ.
- Signed URL có TTL; download client kiểm tra SHA-256 và manifest schema.
- AuditLog cho upload, annotation, review, publish, rollback, grant và download release.

Hợp đồng import mặc định là `BuildingRevision` cấp tòa/block, không phải một floor rời. IFC đầy đủ được parse theo `IfcBuildingStorey`, sau đó kiểm tra graph liên tầng (stair, ramp, lift portal nếu được mô hình hóa) và đường tới exit. PDF/DXF có thể upload từng tầng rồi ghép revision thủ công; các mảnh thiếu kết nối chỉ được lưu Draft/ReviewRequired và không thể tạo `TrainingRelease`.

Governance hỗ trợ mô hình phối hợp với cơ quan PCCC/chuyên gia được ủy quyền. `FireReviewer` có thể gắn tổ chức chuyên môn, checklist quy định, phạm vi xem xét và chữ ký review vào `ReviewRecord`. `BuildingManager` chỉ tạo được `ScenarioVersion` trong tham số mà release đã approve (vị trí spawn, mật độ NPC, rubric và lịch campaign); thay đổi geometry, exit, hazard baseline hoặc quy tắc an toàn phải tạo revision mới và review lại. Checklist này là bằng chứng cho quy trình tập huấn, không phải kết quả thẩm duyệt, nghiệm thu hoặc chứng nhận pháp lý.

## 5. Pipeline BIM/Bản Vẽ

### 5.1. IFC Automatic Path

```text
Upload -> Quarantine -> Validate/hash
       -> Normalize units/origin/coordinates
       -> Parse spatial hierarchy and semantics
       -> Tessellate/LOD -> GLB per floor
       -> Build graph/collision/NavMesh source/hazard grid
       -> Automated QA -> Human correction -> Review
```

IfcOpenShell đọc spatial structure và geometry; `IfcConvert` tạo intermediate; Blender/Bonsai sửa material, giảm polygon, chia tầng và tạo collision proxy. Metadata semantic lưu bên cạnh GLB, không nhúng cứng vào mesh nếu không cần.

### 5.2. PDF/DXF Assisted Trace

- Hiển thị PDF/DXF trong web hoặc workstation operator.
- Operator đặt hai điểm chuẩn và nhập khoảng cách thực để calibrate scale.
- Vẽ polygon phòng/hành lang, line cửa/cầu thang/exit.
- Lưu annotation với provenance `manual-trace`, người sửa và thời gian.
- Chạy connectivity QA giống IFC trước khi cho review.

### 5.3. DWG/RVT

- RVT export sang IFC là default vì không mua thêm importer commercial.
- DWG direct chỉ bật khi có quyền ODA Educational Membership hoặc license tương đương.
- Nếu không, operator chuyển DWG thành DXF/PDF bằng công cụ được phép và ghi lại công cụ/phiên bản trong `SourceDocument`.

### 5.4. Automated QA

```text
units != unknown
floor_count >= 1
each floor has a coordinate frame
rooms/doors/stairs/exits have stable IDs
door endpoints touch navigable areas
stairs connect intended floors
each spawn => route or explicit NoModeledRoute
origin is near local project origin
triangle/material/texture budgets pass
```

## 6. Runtime Package Và Versioning

### 6.1. Manifest

```json
{
  "schemaVersion": "1.0",
  "buildingId": "...",
  "revisionId": "...",
  "releaseId": "...",
  "coordinateTransform": { "origin": [0, 0, 0], "scale": 1.0 },
  "floors": [{ "id": "F08", "glbSha256": "...", "addressablesKey": "..." }],
  "graphSha256": "...",
  "scenarioSha256": "...",
  "toolchain": { "ifcOpenShell": "0.8.5", "unity": "6000.3" },
  "minRuntimeVersion": "1.0.0",
  "approvedAt": "..."
}
```

Không dùng `Unity 6000.3` nếu Editor thực tế chưa cài đúng release; CI phải ghi version thực tế vào manifest. Định dạng `Unity 6.3 LTS` là tên marketing, còn lockfile lưu revision cụ thể.

### 6.2. Addressables

- Gói từng tầng và scenario thành Addressables group.
- Local cache cho demo offline; remote catalog/MinIO cho delivery.
- Baked collider/NavMesh/lighting được build trên workstation của nhóm sau khi reviewer approve.
- Content update tạo release mới; không overwrite bundle đang được session sử dụng.
- Cache key gồm `releaseId`, platform, schema và hash.

## 7. Unity–Flutter–Android Integration

### 7.1. Chọn Unity

Unity phù hợp hơn Unreal trong điều kiện GPU 4 GB và mục tiêu Android/Flutter:

- C# và hệ sinh thái mobile dễ tuyển trong team.
- Unity as a Library hỗ trợ Android và full-screen, đúng với thiết kế một game training riêng.
- URP, Addressables và NavMesh đủ cho vertical slice.
- Không cần Datasmith/Pixyz thương mại vì IFC được xử lý ngoài bằng IfcOpenShell/Blender.

### 7.2. Process Và Handoff

- Flutter là shell; Unity chạy full-screen trong Android process/module riêng (`:unity` theo cấu hình build).
- Kotlin/Java Intent hoặc Pigeon bridge truyền `sessionId`, launch grant, package path và protocol version.
- Unity không tự giữ access token dài hạn.
- Khi thoát Unity, result được ghi local và Flutter gọi reconcile.

```text
Flutter.startTraining(request)
  -> backend creates session and grants release
  -> download/verify package
  -> launch Unity(sessionId, manifestPath, grant)
  -> Unity emits event batches / result
  -> Flutter receives handoff and syncs backend
```

### 7.3. Offline State

```text
PackageMissing -> Downloading -> Verified -> ReadyOffline
TrainingRunning -> PendingSync -> Syncing -> Synced
                          \-> SyncFailed -> RetryBackoff
```

Event batch có sequence monotonic, idempotency key và payload schema version. Backend đánh giá `sessionStartTimestamp` cùng signed `launchGrant`, không chỉ thời điểm nhận batch. Nếu release bị revoke sau khi session bắt đầu, batch vẫn được nhận và session chuyển `CompletedWithDeprecation`; release/campaign bị thu hồi có `ArchivedWarning` trong audit và không vào aggregate chính mặc định.

## 8. Fire/Hazard Surrogate

### 8.1. Mô Hình Ba Lớp

1. **Semantic graph**: cạnh là cửa, hành lang, stair, exit và vertical portal.
2. **Hazard grid**: ô theo floor lưu `fire`, `smoke`, `visibility`, `temperatureProxy`, `risk` và timestamp step.
3. **NavMesh**: chuyển động cục bộ, tránh collision; không thay cho graph route.

### 8.2. Cellular Automata Deterministic

Mỗi time step, cell cập nhật theo:

```text
fire(t+1) = clamp(fire(t) + source + neighborSpread - suppression)
smoke(t+1) = clamp(smoke(t) + buoyancy + neighborDiffusion - ventilation)
visibility = 1 - smoke * visibilityFactor
risk = combine(temperatureProxy, smoke, visibility, sourceDistance)
```

Các hệ số là cấu hình scenario, không được gọi là CFD. Seed cố định giúp replay và so sánh; thay đổi grid size/time step phải có sensitivity test.

### 8.3. Calibration

- CFAST dùng cho smoke/temperature profile ở quy mô tòa nhà.
- FDS dùng cho 2–3 khu vực/benchmark nhỏ quan trọng nếu compute cho phép.
- Runtime chỉ chạy surrogate nhẹ, sau đó báo rõ sai số và giới hạn so với reference.
- Không dùng output để chứng minh tuân thủ quy chuẩn hoặc quyết định cứu nạn thực.

## 9. Risk-Aware A* Và Re-planning

### 9.1. Hàm Chi Phí

```text
cost(e) = distance(e)
        + wh * hazardExposure(e)
        + wc * congestion(e)
        + wp * portalPenalty(e)
        + wb * blocked(e)
```

`wh`, `wc`, `wp`, `wb` là scenario weights, phải ghi vào `ScenarioVersion` để kết quả tái lập.

### 9.2. Acceptance

- So sánh A* với Dijkstra trên graph cùng trọng số.
- So sánh shortest-only với risk-aware bằng distance, modeled exposure và compute time.
- Kiểm tra blocked edge, no wall-crossing, one-way door, stair portal và invalid start.
- Re-plan phải ổn định, không đổi route liên tục khi hazard chênh lệch dưới hysteresis threshold.
- Nếu hazard xâm nhập safe pause point khi route là `NoModeledRoute`, runtime trả `ScenarioUnsurvivable` thay vì chờ timeout.

## 10. NPC Và Crowd Budget

- Behavior tree/state machine cho từng NPC.
- Multi-source Dijkstra hoặc flow field cho nhóm cùng đích.
- Detail culling: NPC xa chỉ cập nhật logical state, NPC gần camera mới render animation.
- Benchmark 30, 60, 100 logical agents; xác định mức render chi tiết chấp nhận được trên thiết bị 6 GB.
- Owner cấu hình occupancy, tốc độ, tỷ lệ hoảng loạn và nhu cầu hỗ trợ trong `SafetyThresholds` do Reviewer duyệt; không lấy dữ liệu người thật mặc định.

## 11. Web 3D Và Authoring

Next.js hiển thị GLB preview/intermediate, không chạy Unity. Editor cung cấp:

- upload/progress/job status.
- floor plan và 3D preview.
- semantic selection, annotation CRUD và issue list.
- review diff giữa revision.
- approve/publish/rollback/QR.
- campaign assignment và aggregate analytics.

Web không cho sửa raw IFC trực tiếp. Sửa qua `AnnotationSet` versioned, có undo/audit và phải chạy lại connectivity QA. Floor stacking lấy cao độ từ IFC/bản vẽ; QA kiểm tra thứ tự tầng, ΔZ nhất quán với nguồn, portal đúng tầng và collider/NavMesh không lệch. Không dùng ngưỡng ΔZ cứng; ngoại lệ phải có lý do và Fire Reviewer xác nhận.

## 12. API Contract

### 12.1. Authoring

```text
POST   /api/buildings/{buildingId}/sources
POST   /api/revisions/{revisionId}/process
GET    /api/revisions/{revisionId}/issues
PATCH  /api/revisions/{revisionId}/annotations
GET    /api/revisions/{revisionId}/preview
```

### 12.2. Governance

```text
POST /api/revisions/{revisionId}/review
POST /api/revisions/{revisionId}/approve
POST /api/revisions/{revisionId}/publish
POST /api/buildings/{buildingId}/rollback
POST /api/buildings/{buildingId}/qr
POST /api/campaigns
```

### 12.3. Delivery Và Training

```text
GET  /api/qr/{opaqueCode}/resolve
POST /api/releases/{releaseId}/entitlement
GET  /api/releases/{releaseId}/manifest
POST /api/training/sessions
POST /api/training/sessions/{sessionId}/events:batch
POST /api/training/sessions/{sessionId}/complete
POST /api/training/sessions/{sessionId}/abort
POST /api/training/reconcile
POST /api/training/sessions/{sessionId}/checkpoint
POST /api/training/sessions/{sessionId}/resume
GET  /api/training/sessions/{sessionId}/debrief
POST /api/campaigns/{campaignId}/validate-scenario
GET  /api/mobile/cache/catalog
```

Mọi endpoint delivery/training phải kiểm tra release channel, tenant/public flag, session pin và protocol version.

## 13. RAG Stretch Có Kiểm Soát

Chỉ triển khai sau khi core pass tháng 9.

- Owner upload safety document đã approve.
- Chunk/index theo organization, building, revision và role.
- Retrieval bắt buộc scoped; câu trả lời trích evidence và link section.
- Nếu không có evidence, trả lời “chưa có dữ liệu được phê duyệt”.
- Lệnh có cấu trúc chỉ được gọi `openFloor(floorId, elementIds)` trên các element đã tồn tại và user được phép xem.
- LLM không tự vẽ geometry, không đoán exit và không quyết định route/fire response.
- RAG chỉ phục vụ chuẩn bị huấn luyện, không dùng trong live emergency.

## 14. Deployment Và Chi Phí

### 14.1. Miễn Phí/Đã Có

- .NET, PostgreSQL, MinIO, Blender, Bonsai, IfcOpenShell, CFAST/FDS: dùng bản phù hợp license.
- Unity Student cho tài khoản sinh viên đủ điều kiện; Unity Education Grant cho máy lab của trường nếu trường đủ điều kiện.
- GitHub Education cho repo và CI ở mức nhỏ.
- Play Console đã có.

### 14.2. Khoản Nên Trả Nếu Cần

- Review chuyên gia BIM/PCCC và chi phí xin dữ liệu công trình hợp pháp.
- SSD/thiết bị hoặc thuê máy lab nếu build Unity/FDS vượt khả năng máy.
- Compute theo giờ cho batch FDS sau khi dùng hết credit giáo dục.
- Asset/animation nhỏ chỉ khi placeholder không đủ cho usability test.

### 14.3. Không Mua Trong MVP

- Unity Industry/Pro, Pixyz, commercial BIM importer.
- API LLM runtime, GPU cloud dài hạn, VR headset.
- Subscription asset library không có license rõ.
- ODA commercial membership; DWG fallback sang DXF/PDF.

Mọi asset ghi nguồn, license, ngày tải và checksum. Raw scan/build/video/cache không commit vào Git LFS nếu vượt quota; lưu ngoài repo cùng manifest.

## 15. Kiểm Thử Và Đánh Giá

### 15.1. Pipeline/E2E

```text
owner upload -> operator fix -> reviewer approve -> publish
-> QR resolve -> Android download/cache -> offline play
-> sync result -> dashboard aggregate
```

### 15.2. BIM/Geometry

- 5–10 legal IFC samples để compatibility smoke test.
- Hai case khoa học: một IFC public và một công trình Việt Nam được phép dùng.
- Kiểm units/origin/floors, door/stair/exit mapping, spawn connectivity.
- Lưu issue, thời gian processing, triangle/material/memory budget.

### 15.3. Simulation/Pathfinding

- Hazard deterministic với seed.
- Wall/portal/vertical spread đúng hướng.
- Grid/time-step sensitivity.
- A* vs Dijkstra, shortest vs risk-aware, blocked edge và re-plan hysteresis.
- So sánh CFAST/FDS ở scope đã chọn; báo sai số thay vì giấu sai khác.

### 15.4. Mobile/Delivery

- 30 FPS mục tiêu trên máy 6 GB RAM.
- 15 phút không crash; đo memory peak, download size và cold start.
- Unity crash/OOM giữa phiên: Flutter resume checkpoint một lần, không nhân đôi event.
- Replay policy: Learn/Guided thấy A*; Assessment chỉ mở sau submit hoặc khi được cấp quyền.
- 20 vòng Flutter–Unity–Flutter.
- Download resume, hash mismatch, release revoke và offline pending sync.

### 15.5. Security

- Zero cross-tenant read/write.
- Private QR không bypass login.
- Publish bypass bị từ chối.
- Signed URL hết hạn; raw IFC không xuất hiện trong mobile response.
- AuditLog ghi đủ actor/action/resource/time.

### 15.6. User Study

20–40 người, consent và review chuyên gia trước khi chạy:

- Nhóm A học bằng slide/map thông thường.
- Nhóm B học bằng Guided Drill game.
- Cả hai làm cùng assessment không gợi ý.
- Chỉ số: quyết định sai, thời gian, modeled exposure, nhớ route, kiến thức ngay sau học và delayed recall khoảng 7 ngày.
- Báo rõ đây là study của mô hình training, không phải chứng nhận hiệu quả PCCC ngoài đời.

## 16. Roadmap 12 Tháng

| Thời gian | Kết quả bắt buộc |
|---|---|
| M1–M2 | IFC → Android spike, Flutter mở Unity, A* một tầng, 30 FPS |
| M3–M4 | .NET multi-tenant/upload/job/storage, Next editor, IFC worker |
| M5–M6 | hazard grid, risk-aware A*, Addressables builder, QR/cache/offline |
| M7–M8 | Learn/Guided/Assessment, NPC, campaign/analytics, case 1 |
| M9–M10 | case 2, CFAST/FDS, expert review, performance/security |
| M11 | user study 20–40 người, analysis |
| M12 | fix, polish, video, thesis, rehearsal |

## 17. Phân Công Nhóm

- Thành viên A: BIM worker, IFC/GLB, web 3D và geometry QA.
- Thành viên B: Unity, hazard, A*, NPC, Android build.
- Thành viên C: .NET, PostgreSQL, MinIO, auth, jobs, release API.
- Thành viên D: Flutter, QR, offline/cache, campaign UX và dashboard integration.
- Cả nhóm: test, expert review, user study, tài liệu và demo.

## 18. Nguồn Kỹ Thuật Chính Thức

- [.NET support policy](https://dotnet.microsoft.com/en-us/platform/support/policy)
- [Next.js 16.2 release](https://nextjs.org/blog/next-16-2)
- [Flutter 3.44.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.44.0)
- [Unity 6.3 LTS support](https://unity.com/releases/unity-6/support)
- [Unity Student plan](https://unity.com/products/unity-student)
- [Unity as a Library](https://docs.unity3d.com/6000.0/Documentation/Manual/UnityasaLibrary.html)
- [Unity Addressables](https://docs.unity3d.com/6000.0/Manual/com.unity.addressables.html)
- [IfcOpenShell 0.8.5](https://docs.ifcopenshell.org/)
- [buildingSMART IFC specification](https://standards.buildingsmart.org/IFC/RELEASE/IFC4_3/index.html)
- [buildingSMART sample IFC files](https://technical.buildingsmart.org/standards/ifc/ifc-examples/)
- [ODA Educational Membership](https://www.opendesign.com/educational-membership)
- [NIST CFAST](https://pages.nist.gov/cfast/)
- [NIST FDS-SMV](https://pages.nist.gov/fds/)

## 19. Trạng Thái Và Recovery Contract

```text
SessionStatus = Created | Launching | Running | Completed
              | CompletedWithDeprecation | ScenarioUnsurvivable | Aborted
ReleaseStatus = Built | Verified | Channel | Superseded | Revoked | ArchivedWarning
SyncDecision  = Accepted | AcceptedDeprecated | RejectedInvalidGrant
              | RejectedTenant | RejectedDuplicate
```

`SessionCheckpoint` được ký với `sessionId`, `releaseId`, `scenarioId`, monotonic event sequence, hazard step, player transform và NPC state. Resume chỉ được cấp một lần; package hash và release pin phải khớp.

## 20. Báo Cáo Và Câu Hỏi Phản Biện

`DebriefArtifact` lưu trajectory heatmap, hazard exposure, route A* tham chiếu và các quyết định sai. Policy theo mode: Learn/Guided thấy A*; Assessment chỉ mở sau submit hoặc reviewer grant. Aggregate được dùng để đo hiệu quả bài giảng, không phải chứng nhận PCCC.

Luận điểm bảo vệ: A* deterministic/giải thích được hơn ML/RL cho thiết bị mobile; Cellular Automata là surrogate nhận thức không gian được đối chiếu ở phạm vi nhỏ với CFAST/FDS, không phải CFD thiết kế; raw IFC chỉ ở backend/workstation, mobile nhận runtime package đã loại bỏ dữ liệu kỹ thuật không cần thiết.
