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
- Mỗi Building có một QR canonical để người dân mở đúng training của tòa nhà đó. QR chỉ mang mã opaque/deep link để backend resolve release; không chứa model, credential hoặc file cài đặt. Khi đổi release, QR được rotate/revoke theo lifecycle publish.
- Three.js chỉ dùng cho hiệu ứng landing/giới thiệu trên web. Gameplay BIM 3D/2.5D chạy trong Unity runtime của Mobile, không chạy thành game Three.js trên trình duyệt.
- Headline Phase 1 giữ nguyên: **IFC → 3D → Unity Android → QR → Training → Result**.
- Lifecycle thực thi là: IFC đạt QA chuyển revision sang `ReadyForScenario`; action `ConfirmForTraining` chuyển nó sang `ConfirmedForTraining`; backend tạo release `Built`, package và `Training` khớp nhau; sau đó publish release rồi mới tạo active QR pin chính xác `trainingId`. `ConfirmForTraining` chỉ là readiness nội bộ, không phải chứng nhận, phê duyệt PCCC, thẩm duyệt thiết kế hoặc chỉ dẫn ứng phó sự cố thực tế.
- Phase 1 cung cấp luồng core online. Phase 2 bổ sung PayOS production, quotation, transaction, invoice metadata, revenue, feedback/support, basic offline, basic NPC và expanded analytics.
- Với PayOS Phase 2, backend tạo request `Pending` qua entry point đặc quyền hẹp. Adapter webhook xác thực bằng SDK `webhooks.verify(req.body)` hoặc thuật toán chính thức trên `data` đã canonicalize theo thứ tự tên trường tăng dần trước khi gọi database; `returnUrl` chỉ dùng điều hướng.

## Lưu ý sử dụng

### Quy trình Git của team

- Docs là repo độc lập. Mỗi task tài liệu mới tạo nhánh `docs/<task>` hoặc `chore/<task>` từ `origin/develop` đã cập nhật; không sửa trực tiếp trên `main` hoặc `develop`.
- Trước task: kiểm tra `git status --short --branch`, `git branch -vv` và `git fetch origin --prune`. Khi worktree an toàn, cập nhật local `develop` theo `origin/develop` bằng fast-forward rồi tạo nhánh task. Nếu đang tiếp tục task, kiểm tra nhánh hiện tại thay vì tạo nhánh trùng.
- Giữ nguyên thay đổi đang dở; không tự stash/reset/clean hoặc bỏ file. Nếu local develop diverged hoặc remote không truy cập được, báo rõ và dừng thao tác đồng bộ/merge/push cần trạng thái mới nhất.
- Fetch lại trước cập nhật PR, merge hoặc push. Nếu nhánh đích có commit mới, merge vào nhánh task, giải quyết conflict theo ý nghĩa tài liệu rồi kiểm tra lại. Không tự rebase/force-push lịch sử đã chia sẻ.
- Task hoàn thành qua PR vào `develop`, có người phụ trách duyệt và bằng chứng kiểm tra. Sau tích hợp, kiểm tra lại tài liệu liên quan trên develop mới nhất: thuật ngữ, vai trò, Phase 1/2, schema, workflow và liên kết theo phạm vi thay đổi.
- Chỉ phát hành qua PR `develop → main` khi được yêu cầu, kiểm tra tích hợp đạt và người có trách nhiệm duyệt. Commit/push/mở PR khi được yêu cầu; không tự merge hay phát hành sau mỗi task.
- Đây là quy tắc team trong tài liệu, không phải branch protection/CI đã được thiết lập. Nếu chưa có CI, ghi rõ kiểm tra thủ công; không báo CI đạt.

### Làm việc với Codex và ghi chú

- Khi mới clone/pull: git chỉ tải file, không tự tạo bộ nhớ. Mở một repo code AI/BE/FE/Mobile đã có hướng dẫn và yêu cầu Codex đọc AGENTS.md cùng .codex/bootstrap.md, tạo các phần còn thiếu và giữ nguyên file đã có. Khi có đủ năm repo Fire3D và quyền ghi ở workspace cha, hướng dẫn sẽ dựng AGENTS.md/.codex của workspace đó; không push bộ cha.
- Nếu chỉ checkout Docs, tiếp tục đọc README và bàn giao trong chat; không tự tạo .codex trong Docs hoặc tạo bộ nhớ trong thư mục cha chưa xác minh.

- Đọc README này và đúng tài liệu trong danh mục trước khi sửa. Không tạo `AGENTS.md`, `.codex` hoặc `.agents/skills` trong Docs; quyết định sản phẩm và sửa lỗi tài liệu cập nhật trực tiếp vào tài liệu tương ứng, tránh tạo bản ghi nhớ nghiệp vụ song song.
- Khi mở Docs độc lập, chủ động yêu cầu Codex đọc README; file này không được bảo đảm tự nạp như AGENTS.md. Khi làm từ workspace chung, AGENTS.md tại gốc định tuyến đến README này.
- Nếu có workspace cha Fire3D, ghi chú phiên Docs nằm tại `.codex/local/handoff.md` và `.codex/local/lessons.md` của workspace. Nếu không có, bàn giao trong chat; không tự tạo thêm bộ nhớ trong Docs. Plan Mode không ghi file.
- Checkpoint sau mốc đáng kể và trước bàn giao; ghi phần đã xong/còn dở, branch/commit, kiểm tra thực tế và bước tiếp theo. Không hứa ghi kịp trước khi hết quota hoặc phiên ngắt đột ngột; không lưu secrets/transcript.
- Giữ nguyên thư mục `Mẫu report/` đang untracked, không stage, xóa hoặc tự chỉnh file mẫu. Kiểm tra danh sách stage cụ thể, không dùng `git add -A` mù quáng.
- Task chỉ sửa tài liệu: kiểm tra liên kết, tính nhất quán và `git diff --check`, không chạy toàn bộ build/test ứng dụng. Không có test chạy không đồng nghĩa đã kiểm thử nghiệp vụ.
- Có khác biệt hiện tại cần giữ rõ: Docs thiết kế Flutter + Unity, trong khi repo Mobile đang có Expo/React Native. Không tự sửa kiến trúc hoặc chuyển stack để che khác biệt; xin quyết định khi task cần lựa chọn.

### Giới hạn sản phẩm

FET3D phục vụ học tập, tập huấn và hoạt động đánh giá của đồ án. Kết quả mô phỏng, analytics và `ConfirmForTraining` không được dùng để kết luận công trình an toàn, đáp ứng quy chuẩn hay thay thế hướng dẫn khẩn cấp tại hiện trường.
