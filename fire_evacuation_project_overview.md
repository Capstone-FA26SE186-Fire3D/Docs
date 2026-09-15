# Tổng Quan Dự Án Fire Evacuation Training 3D (FET3D)

## Mục đích

FET3D là đồ án tạo trải nghiệm tập huấn và đánh giá sơ tán trong môi trường 3D trên Android, xây dựng từ mô hình **IFC** của một công trình. Hệ thống giúp người học quan sát không gian, thực hành scenario mô phỏng và xem debrief về quyết định của mình.

Luồng cốt lõi Phase 1:

```text
IFC -> 3D -> Unity Android -> QR -> Training -> Result
```

Sản phẩm phục vụ học tập, tập huấn và nghiên cứu. Nó không chứng nhận an toàn PCCC, không phê duyệt thiết kế, không thay thế tư vấn chuyên môn và không đưa ra hướng dẫn trong sự cố cháy thực tế.

## Vấn đề giải quyết

Slide, sơ đồ hai chiều và bài giảng thuần văn bản khó giúp người học ghi nhớ phòng, cửa, cầu thang và lối ra trong công trình cụ thể. FET3D chuyển IFC thành không gian runtime 3D để người học thực hành với hazard surrogate, lựa chọn tuyến đường và rubric đánh giá.

Thời lượng, lựa chọn tuyến, trạng thái hoàn thành và modeled exposure chỉ mô tả hành vi trong mô phỏng; chúng không phải bằng chứng rằng công trình an toàn hoặc người học đủ năng lực xử lý sự cố thật.

## Vai trò

| Vai trò | Trách nhiệm |
|---|---|
| `PlatformAdmin` | Quản trị nền tảng, organization, tài khoản, cấu hình vận hành và giám sát tổng quan. |
| `OrganizationUser` | Quản lý Building, IFC, scenario, publish, QR, analytics và billing của organization. |
| `Trainee` | Đăng nhập Android, quét QR active, thực hiện training và xem kết quả của chính mình. |

Không có guest, lời mời thành viên, reviewer PCCC hoặc training không định danh. `Trainee` đã xác thực có thể tham gia QR active pin một `Training` thuộc release đã publish; participation không dùng allowlist theo tài khoản hay điều kiện `organizationId`.

## Workflow

1. `OrganizationUser` tạo Building, tải IFC vào vùng lưu trữ riêng.
2. Worker kiểm tra hash/định dạng, tạo geometry runtime, semantic graph, NavMesh source, hazard grid và manifest nháp.
3. QA kiểm tra floor, cửa, cầu thang, exit, liên kết liên tầng và route từ spawn. Revision chuyển `ReadyForScenario` hoặc `NeedsFix`.
4. `OrganizationUser` tạo `ScenarioVersion` gồm spawn, mục tiêu, hazard surrogate, time limit, rubric và tham số risk-aware A*.
5. Khi scenario/package sẵn sàng, `ConfirmForTraining` chuyển revision sang `ConfirmedForTraining`.
6. Backend tạo release `Built`, package bất biến và `Training` khớp revision/scenario/organization; sau đó mới publish.
7. Sau publish, QR active pin chính xác release và `Training`. Android resolve QR, tải manifest/package, xác minh rồi mở Unity.
8. Unity trả event/result versioned qua native Android bridge về React Native/Expo để Mobile đồng bộ bằng API; `Trainee` xem debrief cá nhân, `OrganizationUser` xem aggregate thuộc organization.

Mỗi Building có một QR canonical để người dân mở đúng training của tòa nhà đó. QR không tải/cài APK riêng cho từng tòa nhà: Mobile app cài một lần rồi tải content package Unity theo release đã resolve. Three.js chỉ dùng cho landing/giới thiệu trên web, không dùng làm gameplay.

`ConfirmForTraining` chỉ là trạng thái readiness nội bộ, không phải xác nhận, phê duyệt hoặc thẩm duyệt PCCC.

## Kiến trúc

```text
IFC private storage
  -> processing worker (geometry, graph, QA, package)
  -> backend metadata + object storage
  -> signed manifest/content URL
  -> React Native/Expo Android shell + native Unity bridge -> Unity runtime
  -> event/result sync + analytics
```

- Web Next.js quản lý Building/IFC/scenario, trạng thái xử lý, publish, QR và analytics; Three.js phục vụ hiệu ứng landing/giới thiệu.
- Backend phụ trách authentication, tenant scoping, lifecycle revision/release/training, session, audit và URL ngắn hạn.
- Worker parse IFC, tạo runtime data, chạy connectivity QA và build package.
- React Native/Expo xử lý login, QR, download/cache và handoff qua native Android bridge; Unity thực hiện scene, hazard surrogate, routing và tương tác training.

## Dữ liệu và an toàn

Raw IFC chỉ nằm trên backend/workstation; mobile chỉ nhận package runtime đã publish qua manifest và URL ký có TTL. Package, manifest, event batch và result cần hash, schema/version hoặc idempotency key phù hợp. `Trainee` không xem dữ liệu người khác; thao tác upload, processing, scenario, readiness, publish, QR, billing và quản trị đều có audit.

## Phạm vi

| Phase 1 — core online | Phase 2 — mở rộng vận hành |
|---|---|
| Tài khoản, Building, IFC pipeline, scenario, `ConfirmForTraining`, release/package, QR, Android/Unity online, analytics cơ bản và audit. | PayOS production, quotation, transaction, invoice metadata, revenue, feedback/support, basic offline, basic NPC và expanded analytics. |

Phase 1 không có offline runtime, NPC runtime, quotation, PayOS production hay revenue reporting.

## Tài liệu liên quan

- [Yêu cầu dự án](fire_evacuation_requirements.md)
- [Tính năng và phase](fire-evacuation-training-features.md)
- [Workflow](fire-evacuation-training-workflows.md)
- [Kiến trúc công nghệ](fire-evacuation-training-technology.md)
- [Thiết kế RAG BIM hỗ trợ gợi ý PCCC](fire_evacuation_bim_rag_pccc.md)
