# Fire Evacuation Training 3D - Luồng Workflow User & System

> Các luồng nghiệp vụ, trạng thái và failure mode của hệ thống. Cập nhật: 03/08/2026.

## 1. Mục Tiêu Tài Liệu

Tài liệu này mô tả cách Owner, BIM Operator, Fire Reviewer, Member và Guest đi qua hệ thống từ lúc có bản vẽ đến lúc hoàn thành buổi tập huấn. Mỗi luồng tách rõ:

- User flow: hành động người dùng nhìn thấy.
- System flow: API, worker, storage, game runtime và state transition.
- Acceptance: điều kiện để chuyển bước hoặc trả lỗi có thể xử lý.

Backend là nguồn dữ liệu chuẩn; client không được tự suy ra quyền từ QR, tên file hoặc cache cũ.

Quy ước đầu vào: mỗi revision phát hành là một tòa nhà hoặc block hoàn chỉnh. Người dùng có thể tải một IFC multi-storey (khuyến nghị) hoặc nhiều file theo tầng; hệ thống chỉ publish sau khi kiểm tra đủ tầng, kết nối đứng và exit. Floor đơn lẻ chỉ dành cho preview/demo nội bộ.

## 2. Vai Trò Chính

### 2.1. Organization Owner / Building Manager

Quản lý portfolio, thành viên, public channel, campaign, release và analytics của tổ chức.

### 2.2. BIM Operator

Nhập source, sửa annotation, xử lý issue và chuẩn bị revision cho reviewer.

### 2.3. Fire Reviewer

Kiểm tra giả định, lối thoát, hazard source, scenario và approve/reject revision.

### 2.4. Platform Admin

Xử lý tenant, audit, retention và hỗ trợ được cấp quyền. Không tự động xem raw building model.

### 2.5. Member

Người học private được mời hoặc owner duyệt.

### 2.6. Guest

Người học public, truy cập bằng QR release đã bật guest; không xem dữ liệu nội bộ.

### 2.7. Cơ Quan PCCC / Chuyên Gia Được Ủy Quyền

Được mời vào vai trò `Fire Reviewer` để kiểm tra mô hình và kịch bản theo checklist PCCC của công trình. Reviewer phê duyệt lối thoát, điểm tập kết, hazard baseline và giới hạn hỗ trợ NPC. Hệ thống lưu review record để truy vết, nhưng không thay thế thẩm duyệt, nghiệm thu hoặc chứng nhận của cơ quan có thẩm quyền.

Chủ tòa có thể chọn mật độ NPC, điểm xuất phát, thời lượng và rubric trong phạm vi release đã duyệt. Nếu muốn đổi geometry, exit, hazard baseline hoặc quy tắc an toàn, workflow phải quay lại bước tạo revision và review.

## 3. Vòng Đời Công Trình

```text
Organization
  -> Building
  -> BuildingRevision
  -> SourceDocument + AnnotationSet
  -> ReviewRecord
  -> TrainingRelease
  -> Channel/QR
  -> Campaign/Session/Result
```

Một building có nhiều revision; một revision có thể có nhiều review attempt nhưng chỉ release approved mới được phát. Session lưu release bất biến để kết quả có thể tái lập.

## 4. Workflow Tạo Tổ Chức Và Công Trình

### 4.1. User Flow

1. Owner đăng nhập và tạo Organization.
2. Owner tạo Building với tên, loại công trình, số tầng dự kiến và private/public mặc định.
3. Owner mời BIM Operator và Fire Reviewer.
4. Hệ thống hiển thị dashboard trống với checklist “chưa có release”.

### 4.2. System Flow

```text
POST /organizations
POST /organizations/{orgId}/memberships
POST /buildings
-> validate unique slug within organization
-> append AuditLog
-> return tenant-scoped IDs
```

### 4.3. Acceptance

- Email/user phải có membership đúng organization.
- User không thể dùng building ID của tenant khác để xem metadata.
- Building mới ở `Draft`, chưa có QR public và chưa có training package.

## 5. Workflow Upload Và Processing

### 5.1. User Flow

1. Operator mở Building → New Revision.
2. Chọn IFC hoặc PDF/DXF.
3. Nhập mô tả nguồn, quyền sử dụng, đơn vị đo và số tầng dự kiến.
4. Upload theo progress.
5. Xem job status và issue sau processing.

### 5.2. System Flow

```text
Draft
  -> create BuildingRevision
  -> SourceDocument = Uploading
  -> Quarantine + MIME/size/hash check
  -> SourceDocument = Accepted | Rejected
  -> enqueue ProcessRevisionJob
  -> Revision = Processing
  -> worker creates preview/graph/hazard assets
  -> automated QA
  -> NeedsFix or ReviewRequired
```

### 5.3. Các Issue Có Thể Gặp

- `UnknownUnit`: chưa xác định đơn vị.
- `MissingStorey`: không map được tầng.
- `FarOrigin`: tọa độ quá xa gây precision issue.
- `UnconnectedDoor`: cửa không chạm vùng navigable.
- `StairPortalMissing`: cầu thang không nối hai tầng như khai báo.
- `NoExitFromRegion`: component không có đường đến exit.
- `UnsupportedGeometry`: geometry không convert được.
- `BudgetExceeded`: quá triangle, texture, memory hoặc package size.

Operator sửa annotation hoặc upload source mới; worker không tự âm thầm đổi geometry quan trọng.

## 6. Workflow Human Correction

### 6.1. User Flow

1. Operator mở 2D plan hoặc 3D preview.
2. Chọn floor, room, door, stair, exit, spawn hoặc hazard source.
3. Sửa label, loại, kết nối, chiều đi, capacity và ngưỡng.
4. Lưu AnnotationSet mới.
5. Chạy lại connectivity QA.

### 6.2. System Flow

```text
GET revision preview/issues
PATCH annotations (optimistic version)
-> validate revision version
-> create AnnotationSet revision+1
-> recompute graph/QA only for affected objects
-> mark ReviewRequired when all blocking issues clear
```

### 6.3. Conflict

Nếu hai operator sửa cùng annotation version, API trả `409 AnnotationVersionConflict`; client phải reload và merge thủ công. Không overwrite âm thầm.

## 7. Workflow Review – Approve – Publish

### 7.1. Review Flow

1. Fire Reviewer mở checklist source, scale, floor, exit, stairs, scenario và hazard assumptions.
2. Reviewer xem diff annotation, issue history và preview.
3. Chọn Approve hoặc Request Fix, kèm comment bắt buộc nếu reject.

### 7.2. State Machine

```text
Processing -> NeedsFix
NeedsFix -> ReviewRequired
ReviewRequired -> Approved | NeedsFix
Approved -> Published
Published -> Superseded
```

### 7.3. Publish Flow

```text
POST /revisions/{id}/publish
-> check caller role and Approved state
-> freeze revision + annotations + scenario
-> build Addressables/manifest
-> calculate SHA-256
-> create immutable TrainingRelease
-> update selected channel
-> write AuditLog
```

Nếu build package fail hoặc hash mismatch, không tạo release usable. Revision vẫn `Approved` nhưng channel không đổi cho tới khi build lại thành công.

### 7.4. Rollback

1. Owner chọn một release cũ đã approve.
2. Hệ thống xác nhận release không bị revoke vì lỗi nghiêm trọng.
3. Channel trỏ về release cũ.
4. Session đang chạy giữ release hiện tại; session mới nhận release channel mới.

## 8. Workflow QR Public/Private

### 8.1. Tạo QR

- Building QR: resolve building/channel.
- Checkpoint QR: resolve building/channel/checkpoint.
- QR code chỉ chứa opaque code/deep link, không chứa JWT, raw file URL hoặc PII.
- Owner có thể revoke hoặc rotate code; code cũ trả `RevokedQr`.

### 8.2. Private QR

```text
scan -> app resolves opaque code
     -> backend checks login + membership + building approval
     -> returns release metadata
     -> user downloads or opens cached package
```

### 8.3. Public Guest QR

```text
scan -> resolve public channel
     -> create short-lived guest grant
     -> user chooses Learn/Guided/Assessment
     -> session begins after package verification
```

Guest không thể gọi endpoint private bằng cách thay `buildingId`; mọi endpoint vẫn kiểm tra channel/public policy.

### 8.4. Fallback Không Có QR

Người dùng nhập mã ngắn hoặc chọn building/checkpoint thủ công. Mã thủ công chỉ resolve public channel hoặc entitlement đã cấp; không được coi là password.

## 9. Workflow Download, Cache Và Offline

### 9.1. Download

1. Flutter gọi resolve/entitlement.
2. Backend trả manifest và signed URL.
3. Client tải từng bundle, hiển thị progress và hỗ trợ resume.
4. Client kiểm SHA-256 từng artefact.
5. Client ghi cache index theo releaseId.
6. Chỉ khi toàn bộ required content verified mới đánh dấu `ReadyOffline`.

```text
PackageMissing -> Downloading -> HashChecking
                -> ReadyOffline | DownloadFailed | HashMismatch
```

### 9.2. Offline Launch

- Cache còn hạn sử dụng cho training đã entitlement.
- Flutter tạo session grant trước khi mất mạng nếu có thể.
- Nếu chưa từng resolve QR/entitlement, Guest không được start offline lần đầu.
- Unity đọc local manifest, không gọi mạng bắt buộc giữa drill.

### 9.3. Cache Cleanup

Owner/Member có thể xóa package; app giữ result/event chưa sync. Khi release bị superseded, cache cũ vẫn được giữ nếu còn session pending hoặc campaign cần replay.

## 10. Workflow Start Training

### 10.1. Tạo Session

```text
POST /training/sessions
input: releaseId, scenarioId, mode, checkpointId?, participantId?
checks: entitlement, release status, scenario status, min runtime
output: sessionId, launchGrant, manifestSha256
```

Session state:

```text
Created -> Launching -> Running
        -> Completed | Aborted | Expired | ReconcileRequired
```

### 10.2. Flutter–Unity Handoff

1. Flutter nhận `sessionId` và local manifest path.
2. Flutter gọi bridge `startTraining(request)`.
3. Android mở Unity full-screen trong process/module riêng.
4. Unity xác nhận protocol, release hash và spawn.
5. Unity trả acknowledgement; nếu fail, Flutter hiển thị retry và không tạo session thứ hai.

```text
startTraining(request) -> acknowledgement
consumeTrainingHandoffs() -> handoff[]
```

## 11. Workflow Learn Mode

### 11.1. User Flow

1. Chọn tầng hoặc checkpoint.
2. Quan sát phòng, cửa, exit, stair và hotspot.
3. Mở giải thích ngắn.
4. Thử đi tới exit trong môi trường không áp lực.
5. Trả lời nhận biết và xem feedback.

### 11.2. System Flow

- Unity load chỉ các floor Addressables cần thiết.
- Map highlight dùng element IDs từ manifest.
- Event ghi `HotspotViewed`, `ExitObserved`, `QuestionAnswered`.
- Kết quả Learn không dùng cùng rubric nặng của Assessment.

## 12. Workflow Guided Drill

### 12.1. Scenario Setup

Owner/reviewer cấu hình:

- fire source và start time.
- smoke/risk parameters.
- blocked door/stair theo time window.
- occupancy và NPC budget.
- allowed exits, assembly point và guidance level.
- SafetyThresholds đã được Fire Reviewer duyệt: NPC density, spawn bounds, exposure/time limit và NPC assistance policy.

Scenario được version hóa, không sửa scenario của release đã publish.

Nếu Building Manager vượt SafetyThresholds, API trả `ReviewRequired` và không cho publish. Thay đổi geometry, exit, hazard baseline hoặc ngưỡng an toàn luôn tạo revision mới.

### 12.2. Runtime Flow

```text
spawn participant/NPC
-> advance hazard time step
-> query current graph + hazard grid
-> A* route
-> move + render local NPC
-> observe threshold/block/congestion
-> re-plan or NoModeledRoute
-> emit events
-> arrive exit/timeout/abort
```

### 12.3. Re-plan UX

- Nếu guidance bật: hiện cảnh báo và route mới sau khi người học đã có cơ hội quan sát.
- Không nói “an toàn tuyệt đối”. Dùng “tuyến mô phỏng hiện phù hợp hơn theo kịch bản”.
- Nếu không có modeled route, yêu cầu dừng tại safe pause point của scenario và ghi failure state; nếu hazard xâm nhập điểm đó thì kết thúc `ScenarioUnsurvivable`, không chờ timeout.

## 13. Workflow Assessment Mode

1. Session tải scenario và rubric.
2. UI ẩn route overlay, chỉ giữ thông tin quan sát được.
3. Người học tự quyết định; hệ thống chỉ ghi event.
4. Khi đến exit, timeout hoặc abort, engine đóng event stream.
5. Backend tính result từ event đã nhận, không tin điểm do client gửi đơn độc.

Các event tối thiểu:

```text
Spawned, DoorOpened, DoorBlockedObserved, HazardEntered
RouteChoice, ReplanTriggered, NpcAssistance
ExitReached, WrongExit, Timeout, Aborted
```

## 14. Workflow Bình Chữa Cháy Và Hỗ Trợ NPC

### 14.1. Extinguisher Micro-sim

```text
Select extinguisher -> validate distance/angle
-> Pull -> Aim -> Squeeze -> Sweep
-> success/fail -> return to evacuation route
```

Chỉ cho phép trong safe training zone hoặc kịch bản đã review. Nếu hazard vượt ngưỡng, UI ưu tiên thoát và khóa micro-sim.

### 14.2. Hỗ Trợ NPC

1. NPC phát trạng thái `NeedsHelp`.
2. Người học đến trong khoảng cách tương tác.
3. Chọn hành động chỉ hướng/dẫn đường được phép.
4. NPC cập nhật route và đi theo quyết định người chơi; trong Assessment không từ chối blocked edge để tránh lộ đáp án.
5. Nếu người chơi dẫn NPC vào hazard, cả hai chịu exposure/penalty; event ghi hành động và mức hazard.

## 15. Workflow Event, Sync Và Analytics

### 15.1. Event Queue

```text
Unity event -> local sequence + timestamp
            -> batch buffer
            -> Flutter handoff
            -> POST events:batch
            -> idempotency acknowledgement
```

Nếu mạng mất, queue ở `PendingSync`. Nếu batch trùng, backend trả acknowledgement cũ thay vì tạo record thứ hai.

### 15.2. Complete/Abort

- `Complete` chỉ được chấp nhận nếu session đang `Running` và có end event hợp lệ.
- `Abort` ghi reason: user, crash, timeout, no modeled route, package error hoặc app killed.
- `CompletedWithDeprecation` dùng khi session offline hoàn tất nhưng release đã revoke; `ArchivedWarning` dùng cho release/campaign bị thu hồi.
- Reconcile cho phép server dựng lại result từ event đã nhận; điểm client gửi chỉ là hint không đáng tin.

### 15.3. Dashboard

Owner xem aggregate; reviewer xem route/hazard trace của session được cấp quyền; participant xem kết quả cá nhân. Guest không xem danh sách người khác.

## 16. Workflow Campaign

1. Owner chọn building/release/scenario.
2. Chọn mode, thời hạn, nhóm participant và số lần thử.
3. Tạo QR/deep link hoặc assignment.
4. Participant bắt đầu session từ checkpoint.
5. Dashboard theo dõi completion và lỗi thường gặp.
6. Owner export aggregate report để review, không gọi là giấy chứng nhận.

Campaign phải pin release; khi building có release mới, owner quyết định campaign tiếp tục bản cũ hay tạo campaign revision mới. Session offline bắt đầu trước campaign deadline được đánh giá theo `sessionStartTimestamp` và launch grant khi sync muộn.

## 17. Workflow Lỗi Và Retry

### 17.1. Processing

- Worker timeout: retry exponential, tối đa cấu hình 3 lần, sau đó `NeedsFix` với log.
- Hash/source lỗi: giữ quarantine, yêu cầu upload lại.
- Geometry unsupported: issue có element ID nếu có, không publish partial im lặng.

### 17.2. Runtime

- Invalid start: cho chọn checkpoint khác hoặc trả `InvalidStart`.
- No route: pause, hiển thị giới hạn mô hình, ghi event; không tìm đường bằng geometry đoán.
- Package mismatch: xóa bundle lỗi, tải lại release pinned.
- Unity crash/OOM: Flutter lưu checkpoint 30–60 giây/lần, mở recovery và cho resume một lần; checkpoint lỗi thì restart có lý do, không mất outbox event.

### 17.3. API/Sync

- `401`: refresh hoặc login lại, không gửi lại token cũ trong log.
- `403`: hiển thị quyền không đủ, không tiết lộ resource của tenant khác.
- `409`: reload version/session state rồi merge.
- `413`: báo file vượt quota và gợi ý nén/chia theo tầng.
- `5xx`: giữ queue, retry có backoff, không nhân đôi result.

## 18. Workflow Revision Mới Và Revoke

```text
New source/revision
-> processing/review
-> publish release B
-> channel switches A -> B
-> new sessions use B
-> running sessions remain pinned to A
-> revoke A only if owner/platform policy requires
```

Nếu phát hiện lỗi nguy hiểm trong release A, channel chuyển về release đã kiểm chứng; session mới của A bị chặn. Session đang chạy nhận thông báo stop/review theo policy được cấu hình trước, không tự chuyển geometry giữa chừng.

## 19. Workflow RAG Stretch

1. Owner upload safety document.
2. Reviewer approve document scope.
3. Index theo organization/building/revision/role.
4. User hỏi trong màn hình training preparation.
5. Retriever trả passage có evidence.
6. Answer chỉ nêu điều evidence hỗ trợ; nếu thiếu thì refuse.
7. Structured action chỉ highlight element tồn tại qua `openFloor(floorId, elementIds)`.

RAG không được gọi trong live emergency, không tự tạo route, không suy đoán exit và không truy cập tài liệu tenant khác.

## 20. Bảng Tóm Tắt Lifecycle

| Đối tượng | Trạng thái chính | Actor chuyển trạng thái |
|---|---|---|
| Revision | Draft → Processing → ReviewRequired → Approved → Published | Operator/Reviewer/Owner |
| Release | Building → Built → Verified → Channel/Superseded/Revoked/ArchivedWarning | Worker/Reviewer/Owner |
| Package | Missing → Downloading → Verified → ReadyOffline | Flutter |
| Session | Created → Launching → Running → Completed/CompletedWithDeprecation/ScenarioUnsurvivable/Aborted | Backend/Flutter/Unity |
| Event batch | Pending → Sent → Acknowledged/Retry | Flutter/Backend |
| Campaign | Draft → Active → Closed → Archived | Owner |

## 21. Nguyên Tắc Chốt

- Không publish geometry hoặc hazard chưa được review.
- Không coi QR là credential.
- Không coi cache là nguồn quyền lâu dài.
- Không đổi release đang chạy giữa session.
- Không gọi route mô phỏng là bảo đảm an toàn tuyệt đối.
- Không để AI/LLM đoán hình học hoặc quyết định cứu nạn.
- Mọi failure phải có state, reason, retry hoặc hướng xử lý rõ ràng.

## 22. Replay, Cache Và Unity Recovery

### 22.1. Replay/Debrief

Sau khi nộp Assessment hoặc kết thúc Guided Drill, backend dựng `DebriefArtifact` từ event đã xác nhận: trajectory, hazard exposure, quyết định sai và tuyến A* tham chiếu. Learn/Guided xem đầy đủ; Assessment chỉ mở sau submit hoặc khi Reviewer cấp quyền. Owner/Reviewer có thể xuất aggregate theo checkpoint, NPC archetype, tỷ lệ tự thoát/cứu NPC và hiệu quả bài giảng.

### 22.2. Cache Cleanup

Flutter hiển thị dung lượng theo `buildingId/releaseId`, tự đề xuất xóa release `Superseded` không còn campaign active hoặc session pending, và cung cấp nút dọn dẹp thủ công. Outbox event và checkpoint pending không bị xóa cùng package cache.

### 22.3. Resume Sau Crash/OOM

Unity ghi `SessionCheckpoint` mỗi 30–60 giây gồm transform người chơi, hazard time step, NPC state, objective và release/scenario hash. Flutter bắt `UnityCrashed`/`UnityOutOfMemory`, cho resume một lần từ checkpoint gần nhất và ghi interruption event. Nếu checkpoint hoặc hash không hợp lệ, chuyển sang restart có lý do.

## 23. Quy Tắc Báo Cáo Và Bảo Vệ Đồ Án

- Kết quả player/NPC có thể trích xuất thành báo cáo thống kê cho Owner/Reviewer và đánh giá bài giảng, nhưng không gọi là chứng nhận PCCC.
- A* được chọn vì deterministic, giải thích được và phù hợp mobile; ML/RL là hướng mở rộng.
- Cellular Automata là hazard surrogate đã đối chiếu phạm vi nhỏ với CFAST/FDS, không phải CFD dùng cho thiết kế công trình.
- Raw IFC/PDF/DXF chỉ ở backend/workstation; mobile chỉ nhận package runtime đã chuẩn hóa và tenant-scoped.

## 22. Nguồn Tham Khảo

- [Unity as a Library for Android](https://docs.unity3d.com/6000.0/Documentation/Manual/UnityasaLibrary.html)
- [Unity Addressables](https://docs.unity3d.com/6000.0/Manual/com.unity.addressables.html)
- [Unity 6.3 LTS support](https://unity.com/releases/unity-6/support)
- [IfcOpenShell 0.8.5 documentation](https://docs.ifcopenshell.org/)
- [buildingSMART IFC examples](https://technical.buildingsmart.org/standards/ifc/ifc-examples/)
- [NIST CFAST](https://pages.nist.gov/cfast/)
- [NIST FDS-SMV](https://pages.nist.gov/fds/)
