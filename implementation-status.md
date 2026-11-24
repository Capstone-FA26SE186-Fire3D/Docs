# Hiện trạng source và giới hạn nghiệm thu

Đối chiếu ngày 21/10/2026 trên checkout local: FE `b3c2b55`, BE `8bd99c0`, AI `51e86a2`. Đây là baseline đọc source, không phải xác nhận deployment/provider đang chạy đúng các commit này. Requirements và schema v7 là nguồn quyết định sản phẩm; source/API hiện hành là nguồn trạng thái triển khai.

## Auth và phiên đăng nhập

**Đối chiếu auth hiện hành — 21/10/2026:** theo [BE authentication](../BE/docs/authentication.md) và [API guide](../BE/docs/api-docs.md). Local registration: form → OTP → registrationToken → register trả account → login riêng. Google mới nhận proof `OnboardingRequired`; `POST /api/auth/google/onboarding/complete` tạo account/phiên và trả 201 Authenticated. Đã có `POST /api/me/link-google` (mật khẩu local hiện tại + Firebase ID token) và `POST /api/me/password` (đặt mật khẩu local đầu tiên cho Google-only). Mất response hoặc proof đã dùng phải xác minh Google/exchange lại; không tự phát lại JWT từ receipt. Firebase thật, database và client/deployment vẫn cần nghiệm thu riêng.

Token được lưu bằng cookie first-party `fire3d_session` do JavaScript quản lý, dùng chung giữa các tab; fallback `localStorage` khi cookie không ghi được hoặc payload quá lớn, và đọc `sessionStorage` cũ để tương thích. Đây không phải cookie HttpOnly hay phiên xác thực phía server. Client gửi Bearer token tới .NET; backend vẫn quyết định authorization. Xem `FE/src/features/auth/session-store.ts` và `FE/src/features/auth/auth-session.tsx`.

Session là phiên đăng nhập; cookie/localStorage/sessionStorage là cách client lưu token. Shared cookie store không tự bổ sung server-side role gate. Password, Firebase ID token và onboarding proof không được lưu chung vào kho phiên hoặc log. Chi tiết source: `FE/src/features/auth/api.ts`, `session-store.ts`, `auth-session.tsx`; backend có [authentication](../BE/docs/authentication.md) và [manual test Google](../BE/docs/google-auth-manual-test.md).

## RAG v2 và legacy

Source AI hiện có **RAG v2** tại `AI/rag-api/app/v2`, request store/recovery, `PgVectorIndex`/`MemoryIndex`, OpenAI/Gemini/fake adapters, safety gate và eval offline. ChromaDB cùng `/chat`, `/documents`, `/pccc/*` thuộc legacy (routes tắt mặc định), không đại diện toàn bộ implementation. FE gọi .NET cho AI nghiệp vụ; backend cấp scope/quota rồi mới gọi FastAPI. Có source không chứng minh dữ liệu đã migrate hoặc provider/pgvector/deployment production đã nghiệm thu.

RAG là retrieval-augmented generation: tìm evidence được cấp quyền trước rồi mới tạo câu trả lời có nguồn. “v2” là tên phiên bản implementation trong FET3D, không phải chuẩn chung hay tên model. Xem [AI README](../AI/README.md) và [hướng dẫn AI](../AI/docs/huong-dan-ai.md). Backend sở hữu auth, tenant/scope, quota và accounting; FastAPI không tự cấp quyền, lưu scenario hoặc publish.

Hạ tầng đang chạy (11/11/2026): BE (`api.fet3d.io.vn`) và AI/RAG trên AWS EC2 Singapore, mỗi service một máy sau Caddy; IFC geometry worker và Unity build worker trên Azure VM Windows (Indonesia Central), pull job từ BE. Azure App Service và subscription Azure cũ đã ngừng 06/11/2026; hướng dẫn [deploy-azure.md](../AI/docs/deploy-azure.md) của AI không còn dùng cho production.

CI/CD BE (workflow *Build and Deploy to AWS*, khôi phục 11/11/2026, BE#203): test processing (Postgres + Redis) và test deployment → kiểm tra migration bằng role chỉ đọc `fet3d_deploy_preflight` (chỉ `SELECT` `__EFMigrationsHistory`) → build image lên GHCR → SSH bằng khóa riêng của CI → đổi container và kiểm tra health. Phiên bản gói NuGet ghim cố định (BE#202). Sau sự cố token GitHub 10–11/11/2026, mọi secret CI của BE và Mobile đã thay mới; không dùng phiên bản gói trôi (`*`), không đặt credential quyền cao vào GitHub Secrets.

## Web và pipeline

FE đã có Learn CMS/public reader/search, bookmark, Hỏi đáp AI Trainee và lịch sử/kết quả gọi .NET API. Test mock và smoke API thật là các mức bằng chứng riêng; không coi source UI là nghiệm thu CMS/provider embed hoặc indexing production. Xem [tracker FE](../FE/docs/fet3d-operations-ui-tracker.md).

Source FE đã có Organization/Admin console, Building/IFC, editor `fet3d.editor/1`, review/readiness/release, billing/quota, Library, analytics và playtest QR/deep link handoff. Building mutations dùng idempotency/If-Match; editor toolbar dẫn tới tab playtest. IFC có xác nhận thiết bị/chọn cửa thoát và QA codes. Three.js phục vụ landing/editor; Unity Android chạy gameplay qua Mobile. ThreeUI là reference cũ, không có trong dependencies FE hiện hành.

BE có source Redis cache/Streams/recovery; không gọi toàn bộ Redis pipeline là chưa viết, cũng không suy nguồn PostgreSQL, migration hoặc deployment production đã đạt. Xem [context BE](../BE/.codex/context.md). Ingress API hiện tại: DNS iNET → Caddy trên EC2 → .NET; OneShield/OnePortal chỉ đứng trước web.

## Định hướng 23/11/2026: phần đã có mã và phần còn chờ

Nhóm yêu cầu FR-PLAN theo góp ý của giảng viên hướng dẫn ngày 23/11/2026 là thiết kế đích. Xem [pháp lý PCCC](phap-ly-pccc.md) và [Flow 1](phan_tich_khoang_cach_va_quyet_dinh_nghiep_vu.md#flow-1---organization-dựng-hạ-tầng-và-tình-huống-theo-phương-án-pc06). Trạng thái mã nguồn tại ngày 24/11/2026 (bằng chứng là test có mock hoặc test trong Editor, chưa nghiệm thu trên máy chủ và thiết bị thật). Ngày 24/11 BE đã gộp vào main và deploy BE#211, #212, #213, #214 (BE PR #220 đến #223); phần web và worker tương ứng nằm ở FE PR #259 và Unity PR #159, đang chờ gộp:

| Yêu cầu | Đã có mã | Còn chờ |
| :--- | :--- | :--- |
| FR-PLAN-01 | BE: loại công trình `Apartment`/`School`, phiếu thông tin cơ sở PC06, nhóm nguy cơ, tệp PC06 đã ký (BE main, BE#212). FE: form phiếu thông tin cơ sở, hiện nhóm nguy cơ kèm nhắc PC08, tải lên và xem bản đã ký (FE PR #259). | Gộp FE PR #259; thử với máy chủ thật, nhất là xem tệp PDF đã ký. |
| FR-PLAN-02 | FE: kiểm tra tệp IFC trên máy trước khi tải (FE main). BE: `GET /api/ifc/upload-limits` (BE main, BE#214). FE: lấy giới hạn dung lượng từ máy chủ (FE PR #259). | Gộp FE PR #259. |
| FR-PLAN-03 | BE: kiểm tra `FILE_SCHEMA` ở máy chủ, xoá bản tải bị từ chối, ba mã QA mới (BE main, BE#214). Worker hình học: dừng sớm (Unity main) và phát ba mã QA mới (Unity PR #159, chưa chạy job thật trên máy ảo). FE: thông báo sai phiên bản IFC, 12 tiêu chí sau xử lý (FE PR #259). | Gộp FE PR #259 và Unity PR #159. Giới hạn lượt xử lý, từ chối tệp trùng, quét nhanh nội dung: BE#219. |
| FR-PLAN-04 | BE: hạ tầng PCCC theo bản IFC, có phiên bản, khoá khi đạt thẩm định (BE main, BE#213). FE: mục Hạ tầng PCCC và soạn hạ tầng trên mô hình 3D (FE PR #259). | Gộp FE PR #259; thử với máy chủ thật. |
| FR-PLAN-05 | BE: vai trò Chuyên viên PCCC và hàng chờ thẩm định cho hạ tầng và tình huống (BE main, BE#211, #213). FE: khu Chuyên viên PCCC, màn quản trị chỉ còn theo dõi (FE PR #259). | Gộp FE PR #259; tạo tài khoản chuyên viên thật và thử một vòng thẩm định. |
| FR-PLAN-06 | BE: tình huống chỉ tạo trên hạ tầng đã khoá và không chứa lối thoát, thiết bị cố định (BE main, BE#213). FE: bắt buộc chọn hạ tầng đã khoá, trình soạn tình huống hiện hạ tầng ở dạng chỉ đọc (FE PR #259). | Gộp FE PR #259. |
| FR-PLAN-07, 08 | Chưa có. | BE#215, #217; FE làm sau BE. |
| FR-PLAN-09 | Unity: khối "Nhiệm vụ của bạn" ở thẻ giới thiệu, ô mục tiêu hiện ở mọi chế độ (Unity develop, PR #157). | Lên main, thử trên điện thoại. |
| FR-PLAN-10 | Unity: thẻ kết quả có thời gian, số bước ước tính và so với đường ngắn nhất, chỉ hiển thị trên máy (Unity develop, PR #157). | Gửi số bước và đường tối ưu về máy chủ, chấm điểm: BE#216. |
| FR-PLAN-11 | FE: tab "Nhật ký luyện tập" theo kịch bản, xuất CSV kèm dòng ghi chú mô phỏng, tối đa 90 ngày (FE develop, PR #256). | Ngày luyện gần nhất, kịch bản chưa luyện trong năm, khoảng một năm: BE#218. |
| FR-PLAN-12 | Chưa có. | Sau FR-PLAN-04 đến 07. |

## Cách dùng bằng chứng

- Source/contract: endpoint và DTO tồn tại, chưa chứng minh runtime đúng.
- FE integration/mock: client và fixture kiểm cùng contract; không thay API/provider thật.
- Acceptance: ghi môi trường, commit/migration, dữ liệu test và kết quả thực tế cho DB/worker/provider/thiết bị.

Không chạy build/test ứng dụng, migration, payment hoặc LLM chỉ để cập nhật trang này. Giá/quota/expiry/rollover còn mở vẫn theo [overview](fire_evacuation_project_overview.md); không tự đặt con số. [Backlog tổng](https://github.com/Capstone-FA26SE186-Fire3D/Docs/issues/37) liên kết các phần việc triển khai/nghiệm thu và phải kiểm trạng thái hiện hành trước khi thực hiện.
