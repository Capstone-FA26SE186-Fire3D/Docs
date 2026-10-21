# Hiện trạng source và giới hạn nghiệm thu

Đối chiếu ngày 21/10/2026 trên checkout local: FE `b3c2b55`, BE `8bd99c0`, AI `51e86a2`. Đây là baseline đọc source, không phải xác nhận deployment/provider đang chạy đúng các commit này. Requirements và schema v7 là nguồn quyết định sản phẩm; source/API hiện hành là nguồn trạng thái triển khai.

## Auth và phiên đăng nhập

**Đối chiếu auth hiện hành — 21/10/2026:** theo [BE authentication](../BE/docs/authentication.md) và [API guide](../BE/docs/api-docs.md). Local registration: form → OTP → registrationToken → register trả account → login riêng. Google mới nhận proof `OnboardingRequired`; `POST /api/auth/google/onboarding/complete` tạo account/phiên và trả 201 Authenticated. Đã có `POST /api/me/link-google` (mật khẩu local hiện tại + Firebase ID token) và `POST /api/me/password` (đặt mật khẩu local đầu tiên cho Google-only). Mất response hoặc proof đã dùng phải xác minh Google/exchange lại; không tự phát lại JWT từ receipt. Firebase thật, database và client/deployment vẫn cần nghiệm thu riêng.

Token được lưu bằng cookie first-party `fire3d_session` do JavaScript quản lý, dùng chung giữa các tab; fallback `localStorage` khi cookie không ghi được hoặc payload quá lớn, và đọc `sessionStorage` cũ để tương thích. Đây không phải cookie HttpOnly hay phiên xác thực phía server. Client gửi Bearer token tới .NET; backend vẫn quyết định authorization. Xem `FE/src/features/auth/session-store.ts` và `FE/src/features/auth/auth-session.tsx`.

Session là phiên đăng nhập; cookie/localStorage/sessionStorage là cách client lưu token. Shared cookie store không tự bổ sung server-side role gate. Password, Firebase ID token và onboarding proof không được lưu chung vào kho phiên hoặc log. Chi tiết source: `FE/src/features/auth/api.ts`, `session-store.ts`, `auth-session.tsx`; backend có [authentication](../BE/docs/authentication.md) và [manual test Google](../BE/docs/google-auth-manual-test.md).

## RAG v2 và legacy

Source AI hiện có **RAG v2** tại `AI/rag-api/app/v2`, request store/recovery, `PgVectorIndex`/`MemoryIndex`, OpenAI/Gemini/fake adapters, safety gate và eval offline. ChromaDB cùng `/chat`, `/documents`, `/pccc/*` thuộc legacy (routes tắt mặc định), không đại diện toàn bộ implementation. FE gọi .NET cho AI nghiệp vụ; backend cấp scope/quota rồi mới gọi FastAPI. Có source không chứng minh dữ liệu đã migrate hoặc provider/pgvector/deployment production đã nghiệm thu.

RAG là retrieval-augmented generation: tìm evidence được cấp quyền trước rồi mới tạo câu trả lời có nguồn. “v2” là tên phiên bản implementation trong FET3D, không phải chuẩn chung hay tên model. Xem [AI README](../AI/README.md) và [hướng dẫn AI](../AI/docs/huong-dan-ai.md). Backend sở hữu auth, tenant/scope, quota và accounting; FastAPI không tự cấp quyền, lưu scenario hoặc publish.

Hướng dẫn triển khai AI hiện dùng [Azure App Service Linux, code deploy](../AI/docs/deploy-azure.md). Container Apps là phương án thay thế trước đó; tài liệu không xác nhận hạ tầng đã được tạo. Unity build worker dùng Azure VM Windows do BE vận hành; không suy compute BE/IFC từ lựa chọn Azure của AI.

## Web và pipeline

FE đã có Learn CMS/public reader/search, bookmark, Hỏi đáp AI Trainee và lịch sử/kết quả gọi .NET API. Test mock và smoke API thật là các mức bằng chứng riêng; không coi source UI là nghiệm thu CMS/provider embed hoặc indexing production. Xem [tracker FE](../FE/docs/fet3d-operations-ui-tracker.md).

Source FE đã có Organization/Admin console, Building/IFC, editor `fet3d.editor/1`, review/readiness/release, billing/quota, Library, analytics và playtest QR/deep link handoff. Building mutations dùng idempotency/If-Match; editor toolbar dẫn tới tab playtest. IFC có xác nhận thiết bị/chọn cửa thoát và QA codes. Three.js phục vụ landing/editor; Unity Android chạy gameplay qua Mobile. ThreeUI là reference cũ, không có trong dependencies FE hiện hành.

BE có source Redis cache/Streams/recovery; không gọi toàn bộ Redis pipeline là chưa viết, cũng không suy nguồn PostgreSQL, migration hoặc deployment production đã đạt. Xem [context BE](../BE/.codex/context.md). OneShield/OnePortal → Nginx là ingress đích; cần kiểm chứng cấu hình/triển khai riêng.

## Cách dùng bằng chứng

- Source/contract: endpoint và DTO tồn tại, chưa chứng minh runtime đúng.
- FE integration/mock: client và fixture kiểm cùng contract; không thay API/provider thật.
- Acceptance: ghi môi trường, commit/migration, dữ liệu test và kết quả thực tế cho DB/worker/provider/thiết bị.

Không chạy build/test ứng dụng, migration, payment hoặc LLM chỉ để cập nhật trang này. Giá/quota/expiry/rollover/rubric còn mở vẫn theo [overview](fire_evacuation_project_overview.md); không tự đặt con số. [Backlog tổng](https://github.com/Capstone-FA26SE186-Fire3D/Docs/issues/37) liên kết các phần việc triển khai/nghiệm thu và phải kiểm trạng thái hiện hành trước khi thực hiện.
