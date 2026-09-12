# Danh Mục Tài Liệu Dự Án (Docs)

Thư mục này chứa tài liệu sản phẩm và kiến trúc cho **Fire Evacuation Training 3D (FET3D)**, một đồ án hỗ trợ tập huấn và đánh giá trải nghiệm sơ tán trong môi trường 3D của công trình.

## Tài liệu chính

| Tệp | Nội dung |
| :--- | :--- |
| `fire_evacuation_requirements.md` | Yêu cầu chức năng, phi chức năng, phạm vi Phase 1 và Phase 2. |
| `fire-evacuation-training-features.md` | Giá trị sản phẩm, ba loại tài khoản, tính năng và giới hạn sử dụng. |
| `fire-evacuation-training-workflows.md` | Luồng từ mô hình IFC đến package, QR, buổi tập huấn và dữ liệu kết quả. |
| `fire-evacuation-training-technology.md` | Kiến trúc, pipeline IFC, runtime Android và các quyết định kỹ thuật. |
| `fire_evacuation_schema.sql` | Thiết kế cơ sở dữ liệu. |
| `fire_evacuation_erd.md` | Sơ đồ thực thể–quan hệ. |
| `3D-Fire-Evacuation-Training-IDEA2.docx` | Bản phác thảo ý tưởng gốc; được lưu nguyên trạng. |
| `fire_evacuation_project_overview.md` | Tổng quan thống nhất về mục tiêu, phạm vi, workflow và giới hạn của FET3D. |
| `fire_evacuation_bim_rag_pccc.md` | Thiết kế RAG Python dùng BIM để tạo gợi ý PCCC cần chuyên gia thẩm tra. |

## Phạm vi thống nhất

- Ba loại tài khoản là `PlatformAdmin`, `OrganizationUser` và `Trainee`. Không có cơ chế thành viên tổ chức, lời mời, truy cập khách hay tập huấn không định danh. Mọi `Trainee` đã xác thực có thể quét bất kỳ QR active pin một `Training` của release đã publish để tham gia.
- `OrganizationUser` sở hữu toàn bộ nghiệp vụ của tổ chức: Building, nhập IFC, scenario, publish, QR, analytics và billing.
- Đầu vào mô hình của sản phẩm là **IFC**. Ứng dụng Android được cài một lần; khi quét QR hợp lệ, ứng dụng tải và xác minh content package của release tương ứng rồi khởi chạy Unity.
- Headline Phase 1 giữ nguyên: **IFC → 3D → Unity Android → QR → Training → Result**.
- Lifecycle thực thi là: IFC đạt QA chuyển revision sang `ReadyForScenario`; action `ConfirmForTraining` chuyển nó sang `ConfirmedForTraining`; backend tạo release `Built`, package và `Training` khớp nhau; sau đó publish release rồi mới tạo active QR pin chính xác `trainingId`. `ConfirmForTraining` chỉ là readiness nội bộ, không phải chứng nhận, phê duyệt PCCC, thẩm duyệt thiết kế hoặc chỉ dẫn ứng phó sự cố thực tế.
- Phase 1 cung cấp luồng core online. Phase 2 bổ sung PayOS production, quotation, transaction, invoice metadata, revenue, feedback/support, basic offline, basic NPC và expanded analytics.
- Với PayOS Phase 2, backend tạo request `Pending` qua entry point đặc quyền hẹp. Adapter webhook xác thực bằng SDK `webhooks.verify(req.body)` hoặc thuật toán chính thức trên `data` đã canonicalize theo thứ tự tên trường tăng dần trước khi gọi database; `returnUrl` chỉ dùng điều hướng.

## Lưu ý sử dụng

FET3D phục vụ học tập, tập huấn và hoạt động đánh giá của đồ án. Kết quả mô phỏng, analytics và `ConfirmForTraining` không được dùng để kết luận công trình an toàn, đáp ứng quy chuẩn hay thay thế hướng dẫn khẩn cấp tại hiện trường.
