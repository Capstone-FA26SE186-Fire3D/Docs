# Fire Evacuation Training 3D — Workflows

## 1. Nguyên tắc chung

- Có ba loại tài khoản: `PlatformAdmin`, `OrganizationUser`, `Trainee`.
- `OrganizationUser` sở hữu Building, IFC, scenario, publish, QR, analytics và billing của organization.
- IFC là source duy nhất cho pipeline mô hình. Android app được cài một lần; QR chỉ định release/content package để app tải sau khi người dùng xác thực.
- `ConfirmForTraining` là kiểm tra readiness cho tập huấn của đồ án, không phải chứng nhận hoặc phê duyệt PCCC.
- Headline Phase 1: **IFC → 3D → Unity Android → QR → Training → Result**.
- Hoạt động đánh giá chuyên môn và user study là hoạt động capstone, không tạo system role hoặc quyền duyệt hệ thống.

## 2. Workflow quản trị nền tảng

1. `PlatformAdmin` tạo organization và ba loại tài khoản cần thiết.
2. Hệ thống gắn `OrganizationUser` với phạm vi `organizationId` để ownership. `Trainee` là tài khoản xác thực có thể tham gia qua bất kỳ QR active của release đã publish; QR participation không đối chiếu `organizationId`.
3. `PlatformAdmin` khóa/mở khóa tài khoản, xem health, audit, support và billing aggregate cấp nền tảng.
4. API từ chối request ownership không có tài khoản đã xác thực hoặc không khớp `organizationId`; QR participation của `Trainee` chỉ yêu cầu tài khoản xác thực cùng QR active của release đã publish.

## 3. Workflow Building và IFC

```text
OrganizationUser tạo Building
  -> tải IFC
  -> validate MIME/kích thước/hash và lưu private
  -> worker parse IFC
  -> tạo geometry runtime + floor graph + NavMesh source + hazard grid
  -> connectivity QA + issue list
  -> revision ReadyForScenario hoặc NeedsFix
```

1. `OrganizationUser` tạo Building với metadata cần cho tập huấn.
2. `OrganizationUser` tải IFC của Building. Backend đưa source vào vùng private, kiểm tra hash và tạo revision.
3. Worker đọc spatial hierarchy, tách tầng, tạo geometry tối ưu cho runtime, semantic graph, door/stair/exit mapping, NavMesh source và manifest nháp.
4. QA kiểm tra unit, origin, floor order, portal liên tầng, spawn-to-exit route, collision và budget package.
5. Nếu lỗi, hệ thống lưu issue, log và trạng thái `NeedsFix`. `OrganizationUser` cập nhật IFC, tạo revision mới và chạy lại pipeline.
6. Nếu đạt, revision chuyển `ReadyForScenario`. Không publish partial package hoặc source chưa qua QA.

## 4. Workflow scenario và readiness

```text
ReadyForScenario revision
  -> OrganizationUser tạo ScenarioVersion
  -> validate spawn/goal/hazard/rubric/A* weights
  -> validate candidate package + manifest
  -> checklist readiness
  -> ConfirmForTraining
  -> revision ConfirmedForTraining
```

1. `OrganizationUser` chọn revision hợp lệ và tạo `ScenarioVersion`.
2. Scenario ghi spawn, mục tiêu, hazard surrogate, time limit, rubric, route weights và seed để replay được.
3. Hệ thống chạy validation về route, blocked edge, floor portal, package hash, manifest schema và runtime version.
4. Khi mọi điều kiện readiness đạt, `OrganizationUser` thực hiện action `ConfirmForTraining`; hệ thống persist transition `ReadyForScenario` → `ConfirmedForTraining`.
5. Hệ thống audit actor, timestamp, revision, scenario và các validation pass/fail. QR không nằm trong checklist vì chưa có release/`Training` để bind.

`ConfirmForTraining` chỉ nói rằng package và scenario đã sẵn sàng cho phiên tập huấn của đồ án. Nếu geometry, exit, hazard baseline hoặc scenario bị thay đổi, cần revision/scenario version mới và readiness mới. Không kết quả nào trong workflow này xác nhận mức độ an toàn thực tế.

## 5. Workflow publish và QR

```text
ConfirmedForTraining revision + pinned ScenarioVersion
  -> create immutable TrainingRelease ở Built
  -> persist manifest/content package
  -> create matching Active Training
  -> publish release
  -> generate active QR pinned to release + Training
  -> distribute QR for the intended training activity
```

1. Từ revision `ConfirmedForTraining` và đúng scenario đã được action pin, backend tạo `TrainingRelease` bất biến ở `Built`.
2. Backend persist manifest/package gồm `releaseId`, `buildingId`, `scenarioId`, package hash, schema version và `minRuntimeVersion`, rồi tạo một `Training` active khớp release/scenario/organization.
3. `OrganizationUser` publish release. Publish bị từ chối nếu package hoặc `Training` active khớp chưa tồn tại.
4. Chỉ sau publish, backend sinh QR opaque pin cả `release_id` và một `training_id` duy nhất; `OrganizationUser` có thể in, rotate hoặc revoke QR.
5. Active QR bị từ chối nếu release/`Training`/scenario/organization lệch nhau. QR phải được deactivate trước khi đóng `Training` hoặc chuyển release sang `Superseded`/`Revoked`.

Quy ước sản phẩm là mỗi Building có một QR canonical đang active cho release/training được phát hành. QR chỉ là mã resolve công khai; nó không chứa package, access token hoặc APK. Khi phát hành release mới, backend rotate QR và revoke mã cũ theo lifecycle.

## 6. Workflow quét QR, download và launch

```text
Trainee đăng nhập Android app (cài một lần)
  -> quét QR
  -> backend resolve QR active + pinned Active Training + Published release
  -> tải manifest/content package
  -> verify hash/schema/runtime
  -> create session + launch grant
  -> React Native/Expo native bridge launch Unity
```

1. `Trainee` đăng nhập ứng dụng Android và quét QR của hoạt động tập huấn.
2. Backend kiểm tra `Trainee` đã xác thực, QR active chưa hết hạn, `training_id` đã pin còn `Active`, release đã `Published`, và release/Training/scenario/organization khớp nhau. Mọi `Trainee` đã xác thực đều hợp lệ, không cần account-specific permission, allowlist hoặc đối chiếu `organizationId`. Backend trả manifest/package URL ký ngắn hạn.
3. React Native/Expo tiếp tục download khi kết nối còn hoạt động, xác minh hash rồi lưu package đã verified.
4. Backend tạo session, pin `trainingId`/`releaseId`/`scenarioId`/`qrCodeId` và cấp launch grant ngắn hạn.
5. Native Android bridge của React Native/Expo truyền `sessionId`, manifest path, grant và protocol version cho Unity.
6. Unity không giữ credential dài hạn và không tự chọn release.

Nếu thiết bị chưa cài Mobile app, URL/deep link của QR chỉ mở landing giới thiệu và dẫn tới kênh cài đặt phù hợp; gameplay không chạy bằng Three.js trên trình duyệt. Three.js của FE chỉ phục vụ hiệu ứng landing/intro.

## 7. Workflow training online — Phase 1

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
3. Event có sequence, session ID, schema version và idempotency key. Unity trả event/result qua native Android bridge về React Native/Expo; Mobile gửi dữ liệu đó lên API khi online.
4. Backend validate grant, release pin và sequence rồi đánh dấu `Completed`, `Aborted` hoặc trạng thái lỗi có lý do.
5. `Trainee` xem debrief cá nhân; `OrganizationUser` xem aggregate cơ bản.

Contract bên gửi/nhận và checklist tích hợp được mô tả tại mục 8.1 và 13 của [tài liệu kiến trúc](fire-evacuation-training-technology.md). Mobile chỉ coi kết quả đã đồng bộ khi API xác nhận chấp nhận dữ liệu.

## 8. Workflow basic offline — Phase 2

1. Chỉ package đã verified khi online mới có thể vào trạng thái `ReadyOffline`.
2. Khi mất kết nối, React Native/Expo launch package đã pin và Unity tiếp tục ghi event/result local.
3. React Native/Expo xếp event/result theo thứ tự với idempotency key, retry backoff và giữ release/scenario hash.
4. Khi có mạng, React Native/Expo gọi reconcile; backend chỉ nhận batch hợp lệ, không nhân đôi dữ liệu.
5. Nếu release bị revoke hoặc trở thành `Superseded` sau thời điểm start hợp lệ, session được giữ audit với trạng thái lịch sử thay vì bị biến mất.

## 9. Workflow basic NPC — Phase 2

1. `OrganizationUser` cấu hình số lượng NPC giới hạn trong `ScenarioVersion`.
2. Unity khởi tạo state đơn giản (ví dụ idle, moving, blocked) theo seed của scenario.
3. NPC chỉ tác động đến trải nghiệm mô phỏng và budget hiệu năng; kết quả không diễn giải là dự báo hành vi con người thật.
4. Event có thể ghi tương tác với NPC để phục vụ debrief/analytics của đồ án.

## 10. Workflow analytics

- Phase 1: backend aggregate session count, completion, duration, route decision và modeled exposure theo Building/scenario.
- Phase 2: expanded analytics thêm filter thời gian, cohort comparison, export và debrief aggregate.
- `Trainee` chỉ xem session của mình. `OrganizationUser` chỉ xem dữ liệu organization. `PlatformAdmin` giám sát aggregate nền tảng khi cần vận hành.
- Dashboard phải nhắc rõ analytics mô tả hoạt động trong mô phỏng, không phải kết luận an toàn hay chứng nhận PCCC.

## 11. Workflow quotation, thanh toán và support — Phase 2

```text
OrganizationUser yêu cầu quotation
  -> PlatformAdmin phát hành quotation
  -> backend gọi PayOS ngoài DB transaction
  -> function-only executor tạo request Pending
  -> adapter xác thực webhook PayOS
  -> DB idempotent + đối soát
  -> lưu invoice metadata và revenue
```

1. `OrganizationUser` xem quotation và yêu cầu thanh toán cho dịch vụ organization.
2. Backend gọi PayOS bên ngoài database transaction, rồi role `fet3d_payos_request_executor` chỉ có quyền execute function tạo request `Pending`; amount, currency và organization được derive từ quotation `Accepted`. Role này không có table DML.
3. Trusted webhook adapter xác thực `req.body` bằng SDK `webhooks.verify` hoặc thuật toán chính thức canonicalize `data` bằng cách sắp xếp alphabet các trường. Chỉ khi xác thực thành công adapter mới gọi `apply_verified_payos_webhook`; function database không thực hiện mật mã, chỉ persist attestation, idempotency và đối soát `orderCode`/amount/currency.
4. `returnUrl` và `cancelUrl` chỉ điều hướng UI. Chúng không gọi đường ghi `Paid`; mismatched webhook được lưu `Rejected`, request vẫn `Pending`.
5. `OrganizationUser` xem trạng thái billing; `PlatformAdmin` xem revenue aggregate.
6. Người dùng gửi feedback/support ticket; `PlatformAdmin` tiếp nhận, phân loại và phản hồi.

## 12. Đánh giá capstone

Các buổi phản hồi chuyên môn, usability test và user study được tổ chức ngoài workflow phân quyền. Dữ liệu được consent và phân tích để đánh giá trải nghiệm, hiệu năng, độ rõ scenario và giá trị học tập của đồ án. Báo cáo phải tránh mô tả kết quả là phê duyệt hoặc chứng nhận PCCC.
