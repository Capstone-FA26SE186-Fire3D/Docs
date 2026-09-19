# Danh Mục Tài Liệu Dự Án (Docs)

Thư mục này chứa tài liệu sản phẩm và kiến trúc cho **Fire Evacuation Training 3D (FET3D)**, một đồ án hỗ trợ tập huấn và đánh giá trải nghiệm sơ tán trong môi trường 3D của công trình.

## Tài liệu chính

| Tệp | Nội dung |
| :--- | :--- |
| `fire_evacuation_requirements.md` | Yêu cầu chức năng/phi chức năng của bản cuối và thứ tự phase triển khai. |
| Tính năng/phase | Đã hợp nhất vào [requirements](fire_evacuation_requirements.md) và [project overview](fire_evacuation_project_overview.md); không tạo nguồn quyết định song song. |
| `fire-evacuation-training-workflows.md` | Luồng từ mô hình IFC đến package, QR, buổi tập huấn và dữ liệu kết quả. |
| `fire-evacuation-training-technology.md` | Kiến trúc, pipeline IFC, runtime Android và các quyết định kỹ thuật. |
| `fire_evacuation_schema.sql` | Thiết kế cơ sở dữ liệu. |
| `fire_evacuation_erd.md` | Sơ đồ thực thể–quan hệ. |
| `3D-Fire-Evacuation-Training-IDEA2.docx` | Bản ý tưởng đã đồng bộ với kiến trúc và workflow hiện hành; vẫn giữ vai trò tài liệu ý tưởng, không thay thế requirements. |
| `fire_evacuation_project_overview.md` | Tổng quan thống nhất về mục tiêu, phạm vi, workflow và giới hạn của FET3D. |
| `fire_evacuation_bim_rag_pccc.md` | Thiết kế RAG Python dùng BIM để tạo gợi ý PCCC cần chuyên gia thẩm tra. |
| `fire3d-web-ux-design.md` | Đặc tả UX web, landing POV 3D, hai hướng nhu cầu, Learn, Góc học tập và ranh giới Android/Unity. |
| `fire3d-web-implementation.md` | Prototype đã triển khai, khác biệt so với thiết kế đầu, lỗi, giải pháp và giới hạn kiểm chứng. |

`fire-evacuation-training-technology.md` (technology) là nguồn chính cho service boundary, transaction boundary và worker/AI contract; schema/ERD biểu diễn dữ liệu/invariant tương ứng, còn requirements/workflows/DOCX mô tả hành vi quan sát được. Schema/ERD hiện ghi target version 6.7; đây là thiết kế chưa chạy migration.

Learn là blog công khai theo tình huống, gồm bài viết, tip & trick và video. `PlatformAdmin` quản trị draft, có thể phát hành ngay, ẩn/hiện hoặc xóa mềm/khôi phục bài; Learn không có bước duyệt riêng. `learn_posts`/`learn_post_versions` cùng các bảng liên quan trong SQL/ERD là thiết kế mục tiêu. Learn không phải khóa học có lesson bắt buộc, quiz, chứng chỉ hoặc tiến độ. Published là nội dung công khai; Hidden không công khai nhưng vẫn có thể làm nguồn RAG; Deleted giữ lịch sử nhưng bị loại khỏi public/RAG. Video provider embed và CMS production chưa được triển khai.

FET3D hỗ trợ một Organization quản lý nhiều Building. Mỗi Building phải có tên và địa chỉ trước khi đưa vào quotation. Gói chuẩn mua theo số Building/thời hạn; quotation BuildingService có dòng riêng cho từng Building, discount do PlatformAdmin cấu hình và snapshot tại thời điểm phát hành. Header quotation không lặp Building scope; `quotation_building_items` là nguồn chính. Số lượng lớn hoặc công trình ngoài phạm vi chuẩn dùng yêu cầu báo giá Liên hệ. Entitlement vẫn độc lập theo Building; trước hạn 5 ngày có thông báo web/email theo kỳ. Các API onboarding Google, profile/avatar, quotation nhiều dòng, discount, enterprise quote và nhắc hạn là thiết kế mục tiêu, chưa phải tính năng đã triển khai.

## Tổng quan công nghệ

| Khối | Công nghệ/nhà cung cấp | Trạng thái quyết định |
| :--- | :--- | :--- |
| Web frontend | Next.js, React, TypeScript; Three.js cho landing và editor/preview 3D | Đã chốt |
| Mobile shell | React Native + Expo; native Android bridge để gọi Unity | Đã chốt |
| 3D training runtime | Unity | Đã chốt |
| Edge/security protection | OneShield thuộc hệ thống OnePortal của iNET | Đã chọn nền tảng; cấu hình gói/SKU, DNS, TLS, WAF, rate limit, log và SLA còn cần xác minh; chưa triển khai |
| Backend | C# và ASP.NET Core trên .NET | Đã chốt |
| Reverse proxy | Nginx | Đã chốt; chi tiết tại mục 14.1 của technology, chưa triển khai |
| AI, RAG và IFC processing | Python + FastAPI; IfcOpenShell cho IFC khi phù hợp | Đã chốt |
| Database | Supabase Database, dùng PostgreSQL | Đã chốt |
| Vector database | `pgvector` trong PostgreSQL/Supabase | Đã chốt; thay cho hướng ChromaDB trong prototype cũ |
| Cache/event transport | Redis cache-aside và Redis Streams | Kiến trúc đích, chưa triển khai; client không kết nối trực tiếp, PostgreSQL vẫn là nguồn sự thật |
| Authentication và push | BE email/password; Firebase Authentication cho Google Sign-In; Firebase Cloud Messaging (FCM) | Đã chốt; Mailgun dùng cho reset password |
| LLM | OpenAI API hoặc Google Gemini API (khóa/cấu hình qua Google AI Studio) | Chưa chọn nhà cung cấp cuối; chỉ triển khai một adapter production sau đánh giá |
| Object storage | Amazon S3 (AWS S3) | Đã chốt |
| AI compute | Azure (AI/RAG); Container Apps là phương án triển khai đề xuất | Đã chốt provider Azure cho AI/RAG; SKU, region và chi phí còn cần spike |
| BE/worker compute | Chưa chọn | Không suy ra BE, IFC/Blender hoặc Unity worker chạy Azure chỉ vì AI đã chọn Azure |

OneShield thuộc hệ thống OnePortal của iNET là lớp edge/bảo vệ phía trước Nginx theo kiến trúc đích; capability, gói/SKU, DNS, TLS termination, WAF/rate limit, logging, SLA, region và chi phí phải xác minh trước production. OneShield không cấp quyền nghiệp vụ và không thay thế kiểm tra identity, tenant hoặc authorization của .NET/PostgreSQL.

Supabase chỉ cung cấp PostgreSQL/`pgvector` trong kiến trúc này, không thay Firebase Authentication. BE quản lý email/password và FET3D session; Firebase chỉ xác minh Google Sign-In, FCM chỉ gửi push, Mailgun gửi reset password. Redis chỉ phục vụ cache-aside và vận chuyển event/job qua backend; FE/Mobile không kết nối Redis và cache không cấp quyền. PostgreSQL outbox là nguồn event/replay, dispatcher có lease riêng, còn worker claim attempt/lease sau khi nhận message; consumer ACK chỉ sau transaction ghi tác động và receipt thành công. Backend vẫn là nơi ánh xạ Firebase UID sang ba vai trò FET3D, kiểm tra `organizationId` và thực thi authorization. Azure đã được chọn cho AI/RAG service; LLM, BE/worker compute và các thông số production khác vẫn qua decision gate.

Đây là kiến trúc đích. Prototype AI hiện còn ChromaDB/OpenAI và backend đã có phần xác thực mật khẩu/JWT; các phần đó chưa tự động trở thành Firebase/`pgvector` chỉ vì tài liệu được cập nhật. Việc chuyển code, dữ liệu và migration phải là task triển khai riêng có kiểm thử.

## Phạm vi thống nhất

- Ba loại tài khoản là `PlatformAdmin`, `OrganizationUser` và `Trainee`. Website landing và Learn là nội dung công khai; không có guest account hoặc guest training không định danh. Mọi `Trainee` đã xác thực có thể quét QR canonical của Building, xem danh sách bài đã publish và tạo preparation cho bài đã chọn; chỉ explicit online start mới cấp quyền chơi.
- `OrganizationUser` sở hữu toàn bộ nghiệp vụ của tổ chức: Building, nhập IFC, scenario, publish, QR, analytics và billing.
- Đầu vào mô hình của sản phẩm là **IFC**. Pipeline dùng IfcOpenShell/IfcConvert, Blender script và Unity build worker để tạo nội dung riêng cho từng Building; chủ tòa chỉ thao tác trên web, không cần cài Blender hoặc Unity.
- Mỗi Building có một QR canonical ổn định. QR mở danh sách bài đã publish; session mới pin `Training`/release/scenario mà Trainee chọn. QR chỉ mang mã opaque/deep link, không chứa model, credential hoặc file cài đặt.
- Three.js dùng cho landing và editor/preview 3D của organization. Gameplay BIM 3D/2.5D đầy đủ chạy trong Unity runtime của Mobile. Landing dùng góc nhìn thứ nhất cuộn qua công trình đang cháy, sau đó rẽ theo nhu cầu người tập huấn hoặc tổ chức; chi tiết nằm trong [đặc tả UX web](fire3d-web-ux-design.md).
- Luồng cốt lõi: **IFC → 3D → Unity Android → QR → Training → Result**.
- Lifecycle thực thi là: IFC đạt QA → revision có thể author nhiều `Scenario` → mỗi scenario có draft và `ScenarioVersion` bất biến → OrganizationUser có thể playtest riêng trong hạn mức thử → `ConfirmForTraining` theo từng revision/version → release `Built` + package → entitlement dịch vụ Building `Active` → publish → QR canonical resolve Building và danh sách bài. `ConfirmForTraining` chỉ là readiness nội bộ, không phải chứng nhận, phê duyệt PCCC, thẩm duyệt thiết kế hoặc chỉ dẫn ứng phó sự cố thực tế.
- Luồng bản cuối bao gồm editor 3D, payment theo từng Building, AI/RAG cho organization và Trainee, IFC processing, Unity runtime, QR, analytics và cơ chế tiếp tục phiên khi mất mạng. Phase chỉ sắp xếp thứ tự triển khai; không dùng Phase 2 để phủ nhận các capability đã chốt.
- Mỗi Building có dịch vụ theo tháng với kỳ riêng. Khi hết hạn, hệ thống khóa phát hành và phiên mới; QR vẫn mở landing để đăng nhập/tải app và hiển thị trạng thái dịch vụ. Phiên đã bắt đầu được hoàn tất.
- Với PayOS, backend tạo request `Pending` qua entry point đặc quyền hẹp. Adapter webhook xác thực bằng SDK `webhooks.verify(req.body)` hoặc thuật toán chính thức trên `data` đã canonicalize theo thứ tự tên trường tăng dần trước khi gọi database; `returnUrl`/`cancelUrl` chỉ dùng điều hướng. Lượt AI vượt hạn mức miễn phí được ghi nhận theo usage và đối soát cuối kỳ của organization, tách khỏi ngày gia hạn từng Building.
- Playtest OrganizationUser được pin với draft/version và package đã verify, không dùng QR Trainee, không cấp quyền học viên và không tính vào learner analytics.

## Quyết định đã chốt trong phiên thiết kế

- Organization được import IFC, xem preview/editor trên web và tự chỉnh scenario. AI chỉ trả lời có nguồn hoặc tạo draft; không tự sửa editor và không tự publish.
- Lửa, khói, gió, cháy lan, cửa, bình chữa cháy, khăn, nguồn nước và hành vi nhân vật là thư viện runtime Unity do nhóm xây dựng. Organization chỉ đặt/chọn/cấu hình những capability đã có.
- Gió và khói tác động theo mô hình game có thể kiểm thử, không phải CFD hoặc mô phỏng thông gió kỹ thuật.
- Trainee dùng AI trên web và Mobile, ngoài gameplay; quota ngày miễn phí do PlatformAdmin cấu hình và không trừ vào quota AI organization.
- Tổ chức có quota AI dùng chung; usage vượt mức được thông báo và tính theo kỳ đối soát cuối kỳ. Lỗi hoặc retry không tính trùng.
- QR ổn định theo Building mở danh sách bài. Session mới phải kiểm tra online; mất mạng sau khi session bắt đầu không làm mất phiên hoặc kết quả.

## Quyết định còn mở trước khi triển khai production

Bảng nguồn chính về quyết định còn mở, tác động và mốc phải chốt nằm tại [tổng quan dự án — bảng quyết định còn mở](fire_evacuation_project_overview.md). Các tài liệu khác dẫn chiếu bảng đó và không tự đặt giá trị thay thế.

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
- Stack đã chốt cho nhóm nằm ở bảng Tổng quan công nghệ: web Next.js, Mobile React Native/Expo với native Android bridge gọi Unity, backend C#/.NET, AI/IFC Python/FastAPI, AI/RAG trên Azure, Supabase PostgreSQL + `pgvector`, Redis cache/Streams ở kiến trúc đích, Firebase Auth/FCM và AWS S3. Không triển khai Flutter. Redis chưa triển khai; LLM và compute cho BE/worker vẫn phải qua bước chọn/benchmark trước khi gọi là production stack.

### Giới hạn sản phẩm

FET3D phục vụ học tập, tập huấn và hoạt động đánh giá của đồ án. Kết quả mô phỏng, analytics và `ConfirmForTraining` không được dùng để kết luận công trình an toàn, đáp ứng quy chuẩn hay thay thế hướng dẫn khẩn cấp tại hiện trường.
