# Fire Evacuation Training 3D - Tổng Hợp Tính Năng

> Tài liệu đặc tả sản phẩm cho đồ án 12 tháng. Cập nhật: 03/08/2026.

## 1. Định Vị Sản Phẩm

**Fire Evacuation Training 3D** là nền tảng biến dữ liệu BIM/bản vẽ của một công trình cụ thể thành trò chơi huấn luyện sơ tán chạy trên Android. Hệ thống kết hợp:

- Nhập mô hình `IFC` và bản vẽ 2D để dựng lại không gian có tầng, phòng, cửa, cầu thang và lối thoát.
- Mô hình hazard thời gian thực dạng surrogate nhẹ cho lửa, khói, tầm nhìn và mức nguy hiểm.
- Định tuyến `risk-aware A*` có thể tính lại khi cửa bị chặn, khói lan hoặc khu vực quá nguy hiểm.
- Game training trong Unity, được mở từ ứng dụng Flutter và có thể chơi offline sau khi tải gói công trình.
- Dashboard Next.js cho chủ công trình, người vận hành BIM/PCCC, chiến dịch huấn luyện và phân tích kết quả.

Mục tiêu của sản phẩm là giúp người học **thực hành quyết định thoát hiểm trong chính không gian của công trình**, thay vì chỉ đọc sơ đồ hoặc nghe hướng dẫn lý thuyết.

Hệ thống là công cụ tập huấn/nghiên cứu. Kết quả mô phỏng không được trình bày là chứng nhận an toàn, phê duyệt thiết kế, chỉ dẫn cứu nạn chuyên nghiệp hoặc hướng dẫn thay thế thông báo khẩn cấp thực tế.

## 2. Bài Toán Và Giá Trị Khác Biệt

### 2.1. Bài Toán Thực Tế

Các buổi tập huấn phổ biến thường gặp những hạn chế sau:

- Người học không quen vị trí thật của phòng, hành lang, cầu thang và cửa thoát.
- Sơ đồ tĩnh không thể hiện việc một lối đi bị khói, lửa hoặc đám đông làm giảm chất lượng.
- Một tuyến ngắn nhất chưa chắc là tuyến có mức phơi nhiễm hazard thấp hơn.
- Người hướng dẫn khó tạo cùng một kịch bản cho nhiều người ở các vị trí xuất phát khác nhau.
- Kết quả thường chỉ là “đã tham gia”, thiếu dữ liệu về quyết định sai, thời gian và khả năng nhớ tuyến.

### 2.2. Điểm Mới Của Đồ Án

Đồ án không tuyên bố là nghiên cứu đầu tiên kết hợp BIM, mô phỏng cháy và AI. Điểm đóng góp thực tế hơn là một pipeline chi phí thấp, có con người kiểm duyệt:

- `BIM-to-game`: từ IFC/bản vẽ đến package Unity có graph ngữ nghĩa, collider, NavMesh và checkpoint.
- `Risk-aware routing`: A* dùng chi phí khoảng cách, hazard, ùn tắc, cửa/cầu thang; có re-plan khi trạng thái thay đổi.
- `Human-in-the-loop`: tự động hóa chuyển đổi nhưng chặn publish nếu thiếu scale, tầng, lối thoát, kết nối hoặc review chuyên môn.
- `QR + offline`: QR gắn công trình/checkpoint giúp bắt đầu đúng vị trí; package đã duyệt có thể dùng không mạng.
- `Training evidence`: phân biệt học có hướng dẫn, drill thích ứng và assessment không gợi ý để đo kết quả.

## 3. Nhóm Người Dùng Và Phân Quyền

Hệ thống multi-tenant, mỗi tổ chức có thể quản lý nhiều tòa nhà. Mọi truy vấn và URL tải gói đều phải kiểm tra `organizationId`.

### 3.1. Organization Owner / Building Manager

- Tạo tổ chức và nhiều tòa nhà.
- Mời thành viên, duyệt người học ở công trình private.
- Xem revision, chiến dịch, QR và analytics của tòa nhà thuộc tổ chức.
- Chọn một release đã review làm kênh public guest nếu muốn.

### 3.2. BIM Operator / Fire Reviewer

- Upload IFC hoặc bản vẽ được phép sử dụng.
- Sửa semantic annotation: tầng, phòng, cửa, cầu thang, exit, spawn, hazard source.
- Xem issue tự động và tạo issue thủ công.
- Fire Reviewer xác nhận giả định mô hình, approve hoặc reject trước khi publish.

### 3.3. Platform Admin

- Quản lý tài khoản nền tảng, audit log, retention và xử lý sự cố.
- Không tự động có quyền xem raw model của tenant nếu chưa được cấp quyền hỗ trợ.

### 3.4. Member / Guest

- `Member` đăng nhập hoặc được mời vào công trình private.
- `Guest` có thể chơi package public bằng QR mà không cần tạo tài khoản bắt buộc.
- Guest vẫn phải tải package từ server lần đầu; sau đó có thể tiếp tục offline.

### 3.5. Bảng Quyền Tối Thiểu

| Tài nguyên | Owner | BIM Operator | Fire Reviewer | Member | Guest |
|---|---:|---:|---:|---:|---:|
| Upload source | Có | Có | Không | Không | Không |
| Sửa annotation | Có | Có | Có | Không | Không |
| Approve revision | Có | Không | Có | Không | Không |
| Publish release | Có | Không | Có | Không | Không |
| Chơi public package | Có | Có | Có | Có | Có |
| Xem analytics chi tiết | Có | Theo cấp | Theo cấp | Kết quả của mình | Không |

### 3.6. Mô Hình Phối Hợp Với PCCC

Mô hình triển khai ưu tiên sự tham gia của cơ quan PCCC hoặc chuyên gia PCCC được ủy quyền:

- Chủ tòa/Building Manager cung cấp bản vẽ, thông tin vận hành và lựa chọn phạm vi buổi tập.
- BIM Operator dựng mô hình, nhập checkpoint và chuẩn hóa dữ liệu.
- Fire Reviewer (đại diện cơ quan PCCC hoặc chuyên gia được ủy quyền) kiểm tra lối thoát, giả định hazard, điểm tập kết và kịch bản NPC trước khi approve.
- Chủ tòa chỉ được cấu hình tham số huấn luyện trong release đã duyệt; không tự ý thay đổi geometry, lối thoát hoặc mức nguy hiểm nền.

Checklist quy tắc PCCC được lưu như dữ liệu review để hỗ trợ đối chiếu, nhưng hệ thống không tự động thẩm duyệt, nghiệm thu hay cấp chứng nhận công trình.

## 4. Quản Lý Công Trình Và Revision

### 4.1. Portfolio Công Trình

Một organization có thể có:

- Chung cư nhiều block và nhiều tầng.
- Karaoke, trường học, văn phòng, trung tâm thương mại.
- Tòa nhà demo public để trình diễn.
- Tòa nhà private chỉ dành cho thành viên được duyệt.

### 4.2. Phạm Vi Bản Vẽ Đầu Vào

Một `BuildingRevision` phát hành cho tập huấn phải đại diện cho **toàn bộ tòa nhà hoặc block được chọn**, gồm các tầng, cầu thang, thang máy/vertical portal liên quan, lối thoát và điểm tập kết. Luồng IFC ưu tiên một file chứa đầy đủ mô hình multi-storey; hệ thống tự tách `IfcBuildingStorey` thành các tầng để preview và build package. Nếu dữ liệu đến từ nhiều file IFC hoặc bản vẽ PDF/DXF theo từng tầng, Operator phải khai báo cùng một revision và chạy kiểm tra kết nối đứng. Revision sẽ bị chặn publish nếu thiếu tầng trung gian, cầu thang hoặc exit cần cho scenario. Một tầng đơn lẻ chỉ được dùng cho demo nội bộ không có route xuyên tầng.

Mỗi `Building` có metadata: tên, địa chỉ mô tả, loại công trình, số tầng dự kiến, trạng thái public/private, người phụ trách và thời điểm cập nhật.

### 4.2. Revision Và Release

Revision là vùng làm việc có thể sửa; release là snapshot bất biến được phát cho mobile.

```text
Draft -> Uploaded -> Processing -> NeedsFix/ReviewRequired
      -> Approved -> Published -> Superseded
```

Quy tắc:

- Chỉ revision `Approved` mới được publish.
- Một release đã được dùng cho session không bị thay đổi giữa chừng.
- QR ổn định có thể trỏ đến release hiện tại, nhưng session pin vào `releaseId` cụ thể.
- Rollback chỉ chuyển channel về một release cũ đã approve; không sửa nội dung release cũ.
- Annotation được lưu riêng với GLB để sửa semantic không buộc convert lại toàn bộ hình học.

## 5. Nhập Dữ Liệu Và Dựng Mô Hình

### 5.1. Nguồn Dữ Liệu Được Hỗ Trợ

- `IFC`: luồng tự động chính, ưu tiên file có `IfcBuildingStorey`, `IfcSpace`, `IfcDoor`, `IfcStair`, `IfcWall` và property cần thiết.
- `RVT`: không upload trực tiếp trong MVP; yêu cầu export sang IFC từ phần mềm được cấp phép.
- `PDF/DXF`: operator trace hoặc map-assisted, nhập scale bằng kích thước đã biết, sau đó xác nhận thủ công.
- `DWG`: chỉ xử lý trực tiếp nếu tổ chức có quyền ODA/Educational Membership phù hợp; mặc định chuyển sang DXF/PDF.

### 5.2. Kết Quả Của Processing

Worker tạo các artefact sau:

- GLB preview theo tầng cho web.
- GLB/Addressables package theo tầng cho Unity.
- Semantic graph: room, corridor, door, stair, lift, exit, fire compartment, checkpoint.
- Collision proxy, NavMesh source, baked lighting và material LOD.
- Hazard grid theo tầng và liên kết vertical portal.
- Issue list: thiếu scale, tầng trùng, cửa không nối, exit cô lập, origin quá xa, geometry lỗi.
- Manifest có schema version, revision/release ID, toolchain version và SHA-256.

### 5.3. Human Correction

Operator có thể đặt hoặc sửa:

- Tên tầng và cao độ.
- Phòng bắt đầu, phòng cấm đi, hành lang, cửa một chiều.
- Cầu thang thoát, cửa chống cháy, exit an toàn theo kịch bản.
- Spawn/checkpoint cho QR.
- Nguồn cháy, tốc độ lan giả lập, smoke source và ngưỡng đóng route.
- Sức chứa vùng, tốc độ NPC, vùng cần hỗ trợ.

Release bị chặn nếu chưa có scale, chưa map được tầng, không có exit hợp lệ, graph không liên thông ngoài giả định có chủ ý, hoặc thiếu người review.

## 6. Ba Chế Độ Huấn Luyện

### 6.1. Learn Mode

Mục tiêu là làm quen không gian và biển báo.

- Có bản đồ mini và highlight exit được phép.
- Hiện tên tầng/phòng/cửa khi người học quan sát.
- Cho phép xem vị trí bình chữa cháy, chuông báo và điểm tập kết nếu được annotation.
- Có hotspot giải thích ngắn, không chấm điểm nặng.
- Kết thúc bằng câu hỏi nhận biết cửa thoát, cầu thang và hành vi cần tránh.

### 6.2. Guided Drill

Mục tiêu là luyện quyết định trong kịch bản có hướng dẫn thích ứng.

- Người học bắt đầu từ QR checkpoint hoặc spawn được giao.
- Hazard lan theo time step; smoke ảnh hưởng visibility/risk.
- Route gợi ý được tính bằng risk-aware A*.
- NPC có thể đi cùng, chắn lối hoặc cần hỗ trợ theo kịch bản.
- Hướng dẫn giảm dần: arrow → text ngắn → chỉ cảnh báo khi người học mắc lỗi.
- Nếu đường bị chặn, hệ thống re-plan và giải thích “tuyến cũ không còn phù hợp theo mô hình”.

### 6.3. Assessment Mode

Mục tiêu là đo năng lực không có gợi ý tự động.

- Không hiện đường tối ưu ngay từ đầu.
- Chỉ cung cấp thông tin mà người thật có thể quan sát trong kịch bản.
- Ghi lại thời gian đến exit, quyết định vào khu vực nguy hiểm, quay đầu, bỏ qua biển báo và hỗ trợ NPC.
- Chấm điểm theo rubric đã cấu hình, không gọi là chứng chỉ PCCC pháp lý.
- Kết quả có thể gửi về campaign và dashboard sau khi sync.

## 7. Mô Phỏng Hazard Và Định Tuyến

### 7.1. Ba Lớp Không Gian

- Building semantic graph để diễn tả kết nối giữa phòng, cửa, corridor, stair và exit.
- Hazard grid theo tầng cho fire, smoke, visibility và risk proxy; vertical portal nối grid giữa tầng.
- NavMesh Unity chỉ phục vụ chuyển động cục bộ; không phải nguồn sự thật về lối thoát.

### 7.2. Risk-Aware A*

Chi phí cạnh được tính theo cấu hình scenario:

```text
cost(edge) = distance
           + wHazard * hazardExposure
           + wCongestion * congestion
           + wPortal * doorOrStairPenalty
           + blockedPenalty
```

Route result có ba trạng thái bắt buộc:

```text
Found | NoModeledRoute | InvalidStart
```

`Found` chỉ có nghĩa là tìm thấy đường trong mô hình và ngưỡng đã cấu hình. UI phải dùng ngôn ngữ “đường mô phỏng phù hợp nhất” thay vì “đường an toàn tuyệt đối”.

Trong Guided Drill, nếu `NoModeledRoute` xảy ra và hazard đã xâm nhập safe pause point, session kết thúc ngay với `ScenarioUnsurvivable`; không bắt người học chờ timeout. Nếu điểm tạm thời vẫn còn hợp lệ, session ở `NoModeledRoutePaused` và tiếp tục theo dõi re-plan.

### 7.3. Re-plan

Re-plan được kích hoạt khi:

- Cạnh hiện tại bị block.
- Smoke/risk vượt ngưỡng của scenario.
- Cửa đóng hoặc cầu thang bị đánh dấu không dùng.
- Congestion vượt ngưỡng.
- Người học rời khỏi graph quá xa hoặc bắt đầu ở vị trí không hợp lệ.

## 8. NPC Và Hỗ Trợ Người Khác

NPC dùng behavior state machine, không cần machine learning trong MVP. Scenario có thể chọn nhiều archetype: bình tĩnh tự thoát, hoảng loạn/la hét, đi sai hướng hoặc bị kẹt cần hỗ trợ.

```text
Calm -> Alerted -> ChoosingRoute -> Moving
      -> Waiting/Blocked -> Replanning -> Moving
      -> NeedsHelp -> Assisted -> Moving
      -> Evacuated | Failed
```

Tính năng hỗ trợ NPC:

- Người học nhận diện NPC đang hoảng loạn hoặc cần chỉ đường.
- Có thể thực hiện một hành động hỗ trợ ngắn: chỉ hướng, mở cửa được phép hoặc dẫn NPC đến checkpoint.
- Người chơi luôn có mục tiêu chính là tự thoát; cứu NPC là mục tiêu phụ tùy scenario.
- Trong Assessment, NPC đi theo quyết định của người chơi thay vì từ chối blocked edge; nếu bị dẫn vào hazard, cả người chơi và NPC chịu exposure/penalty.
- Hỗ trợ sai hoặc quay lại vùng nguy hiểm ảnh hưởng điểm assessment.
- Chỉ mô phỏng hỗ trợ dân sự trong drill; không mô phỏng cứu hộ chuyên nghiệp, vào lại vùng cháy hay vận chuyển nạn nhân.

Để đạt hiệu năng, hệ thống benchmark 30/60/100 logical agents, chỉ render chi tiết NPC gần camera và dùng flow field/multi-source Dijkstra cho nhóm ở xa.

## 9. Micro-simulation Bình Chữa Cháy

MVP chỉ mô phỏng một micro-sim có kiểm soát:

- Chọn đúng loại bình theo kịch bản.
- Đứng trong khoảng cách và hướng hợp lệ.
- Thực hiện chuỗi Pull–Aim–Squeeze–Sweep.
- Hiện cảnh báo nếu người học đứng quá gần hazard hoặc chọn sai hướng gió giả lập.
- Không khẳng định người học đã đủ năng lực sử dụng thiết bị thật.

Phần này bị cắt trước nếu làm ảnh hưởng vertical slice, performance hoặc validation chính.

## 10. QR, Truy Cập Và Offline

### 10.1. QR Tòa Nhà Và Checkpoint

- QR tòa nhà mở deep link chứa opaque building/channel identifier.
- QR checkpoint đặt ở sảnh, tầng, zone hoặc vị trí tập trung.
- QR không chứa token đăng nhập và không được dùng như credential.
- Nếu QR hỏng, người dùng chọn building và checkpoint thủ công từ danh sách được cấp quyền.

### 10.2. Public Và Private

- Private building yêu cầu login/invite và owner approval.
- Public building cho phép Guest chơi release đã được owner bật public.
- Guest không xem raw IFC, issue nội bộ, người học khác hoặc analytics private.
- Signed URL có hạn và manifest/hash phải được kiểm tra trước khi giải nén.

### 10.3. Offline

- Lần đầu cần mạng để resolve QR, entitlement, tải manifest và package.
- Sau khi package được xác minh, Learn/Guided/Assessment có thể chạy offline.
- Event lưu `PendingSync` với sessionId, sequence và hash chain đơn giản.
- Khi có mạng, client batch upload event và nhận acknowledgement; retry phải idempotent.
- Backend đối chiếu `sessionStartTimestamp` và `launchGrant` thay vì chỉ dùng thời điểm sync.
- Nếu release đã revoke sau khi session bắt đầu, session hoàn tất được gắn `CompletedWithDeprecation`; release/campaign bị thu hồi được lưu `ArchivedWarning` và ghi lý do vào AuditLog.

## 11. Campaign Và Analytics

Owner tạo `Campaign` gồm:

- building/release được ghim.
- mode, scenario, thời hạn và nhóm người học.
- số lần thử, yêu cầu hoàn thành và rubric.
- QR hoặc deep link phân phối.

Dashboard hiển thị:

- completion rate, median time, crash/abort rate.
- tỷ lệ chọn route rủi ro, số lần re-plan, khu vực gây nhầm.
- kết quả theo mode và checkpoint.
- so sánh trước/sau hoặc nhóm slide/map và nhóm game trong nghiên cứu.
- replay/debrief gồm trajectory heatmap, hazard exposure và tuyến A* tham chiếu. Learn/Guided xem đầy đủ; Assessment chỉ xem sau khi nộp bài hoặc được Reviewer cấp quyền.
- Owner/Reviewer có thể xuất thống kê theo checkpoint, NPC archetype, tỷ lệ tự thoát/cứu NPC và hiệu quả bài giảng; không gọi là chứng nhận PCCC.

Không hiển thị người học như đã “đạt chuẩn PCCC” nếu chưa có quy trình đánh giá được cơ quan có thẩm quyền công nhận.

## 12. Mô Hình Dữ Liệu Và Hợp Đồng Công Khai

### 12.1. Entity Cốt Lõi

```text
Organization, Membership, Building, BuildingRevision
SourceDocument, AnnotationSet, ReviewRecord, TrainingRelease
Checkpoint, ScenarioVersion, Campaign, Assignment
TrainingSession, SessionEvent, TrainingResult, AuditLog
SafetyThresholds, DebriefArtifact, SessionCheckpoint, NpcArchetype
```

### 12.2. Nhóm API

- Authoring: upload, process, issues, annotations.
- Governance: review, approve, publish, rollback, QR, campaign.
- Delivery: QR resolve, entitlement, manifest, signed content URL.
- Training: start, event batch, complete, abort, reconcile, analytics.

### 12.3. Flutter–Unity Handoff

```text
startTraining(request) -> acknowledgement
consumeTrainingHandoffs() -> handoff[]
```

Flutter chỉ truyền `sessionId`, launch grant và local manifest/path. Unity gửi event batch hoặc result qua bridge/intent được version hóa; backend vẫn là nguồn dữ liệu chuẩn.

## 13. Kịch Bản Demo Chính

### 13.1. Chung Cư Private

1. Owner tạo building và mời nhóm cư dân.
2. Operator upload IFC, sửa một cửa và checkpoint.
3. Reviewer approve release.
4. Cư dân quét QR ở tầng 8, tải package.
5. Guided Drill tạo cháy ở phòng kỹ thuật; smoke làm cầu thang A không còn phù hợp.
6. A* re-plan sang cầu thang B, NPC cần được chỉ hướng.
7. Kết quả sync lên dashboard.

### 13.2. Trung Tâm Thương Mại Public

1. Owner bật Public Guest cho một release demo.
2. Khách quét QR ở sảnh, chọn Learn hoặc Assessment.
3. Guest không cần xem dữ liệu vận hành nội bộ.
4. Owner chỉ nhận analytics tổng hợp theo campaign.

## 14. Phạm Vi MVP Và Phần Cắt Trước

### 14.1. Bắt Buộc

- Một công trình, nhiều tầng, pipeline IFC tối thiểu.
- Human correction, review/approve/publish và revision pinning.
- Hazard surrogate, risk-aware A*, re-plan.
- Unity Android vertical slice chạy 30 FPS trên máy 6 GB RAM.
- Flutter QR/cache/offline/session sync.
- Next.js editor và dashboard kết quả.
- Learn, Guided Drill, Assessment ở mức tối thiểu.

### 14.2. Nên Có

- PDF/DXF assisted trace.
- NPC 30–60 logical agents.
- Micro-sim bình chữa cháy.
- Hai case nghiên cứu và expert review.

### 14.3. Cắt Trước Nếu Thiếu Thời Gian

- RAG hỏi đáp tài liệu.
- DWG direct import.
- Hơn 100 NPC render chi tiết.
- Nhiều khu vực FDS hoặc CFD runtime.
- VR, iOS, professional rescue/re-entry.

## 15. An Toàn, Riêng Tư Và Giới Hạn Pháp Lý

- Không dùng app để điều hướng người đang trong sự cố thật theo vị trí live.
- Không tuyên bố mô hình thay thế thiết kế, nghiệm thu hoặc hướng dẫn của lực lượng PCCC.
- Dữ liệu tòa nhà có thể nhạy cảm: raw IFC chỉ ở backend/operator workstation, không gửi xuống mobile.
- Public release phải được owner duyệt rõ; release private không thể resolve bằng QR public.
- Analytics tối thiểu hóa PII; dùng participantId và retention có thời hạn.
- Mọi thay đổi release, quyền truy cập và rollback đều ghi AuditLog.

## 16. Giả Định Đã Chốt

- Nhóm 4 người, thời gian 12 tháng, ngân sách tối đa 2 triệu đồng, Play Console đã có.
- Thiết bị kiểm thử Android tầm trung khoảng 6 GB RAM; máy dev Ryzen 7 4800H, RAM 24 GB, GTX 1650 4 GB và còn khoảng 92 GB trống.
- Unity 6.3 LTS, URP, Flutter 3.44.x, Next.js 16.2, .NET 10 LTS là baseline; mọi patch được khóa trong manifest/lockfile.
- Phần mềm Student/Education chỉ dùng trong phạm vi học thuật; nếu chuyển thành dịch vụ thương mại phải rà soát license lại.
- Nghiên cứu chính thức dùng một IFC công khai và một công trình Việt Nam được phép sử dụng; các sample khác chỉ để demo tương thích.

## 17. Tài Liệu Tham Khảo Chính Thức

- [Unity 6.3 LTS support](https://unity.com/releases/unity-6/support)
- [Unity Student plan](https://unity.com/products/unity-student)
- [Unity as a Library](https://docs.unity3d.com/6000.0/Documentation/Manual/UnityasaLibrary.html)
- [IfcOpenShell 0.8.5 documentation](https://docs.ifcopenshell.org/)
- [buildingSMART IFC examples](https://technical.buildingsmart.org/standards/ifc/ifc-examples/)
- [NIST CFAST](https://pages.nist.gov/cfast/)
- [NIST FDS-SMV](https://pages.nist.gov/fds/)

## 18. Safety Thresholds, Replay Và Recovery

`TrainingRelease` được Fire Reviewer duyệt kèm `SafetyThresholds`: mật độ NPC tối đa, số NPC đồng thời, vùng spawn hợp lệ, giới hạn exposure/thời lượng và policy hỗ trợ NPC. Building Manager chỉ cấu hình Campaign trong các ngưỡng này; vượt ngưỡng sẽ bị chặn và yêu cầu review lại.

Sau Assessment hoặc Guided Drill, `DebriefArtifact` lưu trajectory heatmap, hazard exposure, quyết định sai và tuyến A* tham chiếu. Learn/Guided xem đầy đủ; Assessment chỉ xem sau khi nộp bài hoặc được Reviewer cấp quyền.

Flutter hiển thị dung lượng theo building/release, đề xuất xóa package `Superseded` không còn campaign active hoặc session pending. Outbox event không bị xóa cùng cache. Checkpoint 30–60 giây/lần cho phép resume một lần sau Unity crash/OOM; nếu checkpoint hoặc package hash không hợp lệ thì chuyển sang restart có lý do.
