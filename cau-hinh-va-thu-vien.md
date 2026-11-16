# Cấu hình, hướng dẫn vận hành và thư viện của FET3D

Trang này gom ba thứ người nhận bàn giao cần để chạy lại hệ thống: chỗ đọc hướng dẫn chạy, triển khai và vận hành của từng repo; danh sách tên biến cấu hình; danh mục thư viện, tài sản 3D, âm thanh và giấy phép. Số liệu đọc từ `main` của sáu repo ngày 16/11/2026, đúng các commit trong [release-manifest.md](release-manifest.md#1-commit-main-của-từng-repo).

Trang này **chỉ ghi tên biến**, không ghi giá trị. Giá trị bí mật (mật khẩu, khóa, chuỗi kết nối, token) nằm ở GitHub Secrets, tệp môi trường trên máy chủ, Vercel hoặc tệp cấu hình trên máy worker, do trưởng nhóm giữ và bàn giao riêng, không qua tài liệu hay repo.

Liên kết dạng `../BE/...` trỏ sang repo khác trong cùng thư mục làm việc của nhóm (mỗi repo clone cạnh nhau), giống các tài liệu khác trong Docs.

## 1. Hướng dẫn chạy, triển khai và vận hành

### Hướng dẫn theo vai trò người dùng

| Vai trò | Tài liệu |
| :--- | :--- |
| Học viên (cài ứng dụng, quét QR, chơi bài) | [huong-dan-hoc-vien.md](huong-dan-hoc-vien.md) |
| Quản trị FET3D (PlatformAdmin) | [huong-dan-quan-tri.md](huong-dan-quan-tri.md) |
| Tổ chức (OrganizationUser) | [FE/public/guides/fet3d-huong-dan-v1.md](../FE/public/guides/fet3d-huong-dan-v1.md), bản 27/10/2026, cũng mở được trên web |
| Kiểm thử chấp nhận | [kich-ban-uat.md](kich-ban-uat.md) |

### BE (.NET API)

| Việc | Tài liệu |
| :--- | :--- |
| Tổng quan, cách đọc tài liệu BE | [BE/README.md](../BE/README.md), [BE/docs/README.md](../BE/docs/README.md) |
| Triển khai lên AWS EC2 (Docker, Caddy, tệp môi trường, workflow) | [BE/docs/aws-ec2-deployment.md](../BE/docs/aws-ec2-deployment.md) |
| Kiểm tra sẵn sàng, smoke test, sao lưu và khôi phục (đã diễn tập 23/10/2026) | [BE/docs/deployment-readiness.md](../BE/docs/deployment-readiness.md) |
| Nghiệm thu production liên dịch vụ | [BE/docs/production-acceptance.md](../BE/docs/production-acceptance.md) |
| Cơ sở dữ liệu: quyền, script nâng cấp, triển khai thay đổi schema | [BE/docs/database-hardening.md](../BE/docs/database-hardening.md), [BE/docs/ifc-authoring-deployment.md](../BE/docs/ifc-authoring-deployment.md), thư mục `BE/database/` |
| Worker IFC và worker dựng gói Unity (giao kèo với BE) | [BE/docs/geometry-worker.md](../BE/docs/geometry-worker.md), [BE/docs/unity-package-worker.md](../BE/docs/unity-package-worker.md), [BE/docs/processing-worker.md](../BE/docs/processing-worker.md), [BE/docs/worker-permissions.md](../BE/docs/worker-permissions.md) |
| Redis | [BE/docs/redis-processing.md](../BE/docs/redis-processing.md) |
| Thanh toán PayOS | [BE/docs/payos-deployment.md](../BE/docs/payos-deployment.md) |
| AI (cách BE gọi AI, quota) | [BE/docs/organization-ai.md](../BE/docs/organization-ai.md) |
| Quản trị tổ chức, tài khoản, báo cáo vận hành | [BE/docs/administration.md](../BE/docs/administration.md), [BE/docs/reporting-operations.md](../BE/docs/reporting-operations.md) |
| Dọn refresh token | [BE/docs/refresh-token-cleanup.md](../BE/docs/refresh-token-cleanup.md) |
| Chạy kiểm thử tích hợp trên máy | [BE/docs/integration-tests.md](../BE/docs/integration-tests.md) |
| Tài liệu Azure/Mailgun cũ (trước khi chuyển AWS ngày 10/11/2026) | [BE/docs/azure-mailgun-deployment.md](../BE/docs/azure-mailgun-deployment.md) |

### AI (FastAPI, RAG, IFC worker cũ)

| Việc | Tài liệu |
| :--- | :--- |
| Tổng quan, chạy, kiểm thử, eval | [AI/README.md](../AI/README.md) |
| Kiến trúc và biến môi trường | [AI/docs/tong-quan-va-env.md](../AI/docs/tong-quan-va-env.md) |
| Tính năng và cách dùng AI | [AI/docs/huong-dan-ai.md](../AI/docs/huong-dan-ai.md) |
| Triển khai | [AI/docs/deploy-azure.md](../AI/docs/deploy-azure.md). Tài liệu viết cho Azure; đầu tệp ghi rõ AI đã chạy trên AWS EC2 từ 10/11/2026 và cách chạy tiến trình, TLS, luật mạng trên EC2 **chưa được ghi lại** |

### FE (web Next.js)

| Việc | Tài liệu |
| :--- | :--- |
| Chạy trên máy, xác thực, kiểm tra | [FE/README.md](../FE/README.md) |
| CI và triển khai Vercel | [FE/docs/ci-cd.md](../FE/docs/ci-cd.md) |
| Trang và API mà web gọi | [FE/docs/PAGES-API.md](../FE/docs/PAGES-API.md) |

### Mobile (React Native/Expo)

| Việc | Tài liệu |
| :--- | :--- |
| Thiết lập, dựng APK có Unity, kiểm tra | [Mobile/README.md](../Mobile/README.md) |
| Phát hành Google Play, cài đặt, lùi bản | [Mobile/docs/google-play-release.md](../Mobile/docs/google-play-release.md) |
| Ghép bản Unity vào ứng dụng | [Mobile/docs/unity-integration.md](../Mobile/docs/unity-integration.md) |

### Unity (runtime, worker IFC, worker dựng gói)

| Việc | Tài liệu |
| :--- | :--- |
| Môi trường, chạy nhanh, cấu trúc, kiểm tra | [Unity/README.md](../Unity/README.md) |
| Xuất bản Unity cho Android | [Unity/Assets/_Fire3D/Editor/AndroidExport/README.md](../Unity/Assets/_Fire3D/Editor/AndroidExport/README.md) |
| Worker IFC (cài, cấu hình, chạy trên máy ảo) | [Unity/Tools/GeometryWorker/README.md](../Unity/Tools/GeometryWorker/README.md) |
| Worker dựng gói bài (cài, cấu hình, chạy trên máy ảo) | [Unity/Tools/PackageWorker/README.md](../Unity/Tools/PackageWorker/README.md) |
| Danh mục năng lực runtime để đăng ký trên trang quản trị | `Unity/Tools/RuntimeCatalog/runtime-<phiên bản>.json` |

## 2. Biến cấu hình (chỉ tên)

Tên biến ASP.NET viết dạng `Mục:Khóa` trong tệp cấu hình, hoặc `Mục__Khóa` khi đặt bằng biến môi trường.

### BE

Đặt trong tệp môi trường `/opt/fire3d-api/.env` trên máy chủ AWS EC2 (quyền 600, xem [aws-ec2-deployment](../BE/docs/aws-ec2-deployment.md)); khi chạy trên máy dùng user secrets hoặc `appsettings.Development.json` (không commit).

| Nhóm | Tên biến | Dùng cho |
| :--- | :--- | :--- |
| Cơ sở dữ liệu | `ConnectionStrings:DefaultConnection`, `ConnectionStrings:DispatcherExecutor`, `ConnectionStrings:ProcessingExecutor`, `ConnectionStrings:PayosRequestExecutor`, `ConnectionStrings:PayosWebhookExecutor` | Kết nối Supabase PostgreSQL; các chuỗi `*Executor` là tài khoản cơ sở dữ liệu quyền hẹp cho từng tiến trình nền |
| Đăng nhập | `Jwt:SigningKey`, `Jwt:Audience`, `Auth:FrontendUrl`, `Auth:FrontendUrls`, `AuthEmail:FrontendUrl`, `AuthTokenCleanup:*`, `LoginAttempts:*` | Ký token, địa chỉ web được phép, link trong email, dọn token, giới hạn đăng nhập sai |
| Firebase | `Firebase:ServiceAccountJson`, mục `FirebaseAdmin` | Xác minh đăng nhập Google, gửi thông báo |
| Email | `Mailgun:ApiKey`, `Mailgun:Domain`, `Mailgun:From` | Gửi email xác minh, đặt lại mật khẩu |
| Lưu trữ tệp | `AWS:AccessKey`, `AWS:SecretKey`, `AWS:BucketName` (hoặc `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET_NAME`), `LearnMedia:PublicBaseUrl`, `IfcUpload:Enabled`, `IfcUpload:MaxBytes`, `IfcUpload:CleanupEnabled` | Amazon S3 cho IFC, gói bài, ảnh bài học |
| Thanh toán | `PayOS:Enabled`, `PayOS:ClientId`, `PayOS:ApiKey`, `PayOS:ChecksumKey`, `PayOS:ReturnUrl`, `PayOS:CancelUrl`, `PayOS:WorkerEnabled`, `PayOS:PollSeconds`, `BillingReminders:*` | Cổng PayOS và nhắc gia hạn |
| AI | `OrganizationAi:Enabled`, `OrganizationAi:BaseUrl`, `OrganizationAi:ApiKey`, `OrganizationAi:TimeoutSeconds`, `OrganizationAi:ScenarioDraftTimeoutSeconds`, `OrganizationAi:PollSeconds`, `OrganizationAi:LeaseSeconds`, `OrganizationAi:MaxAttempts`, `OrganizationAi:BackoffSeconds` | Gọi dịch vụ AI. Không bật `Enabled` khi chưa có `BaseUrl` |
| Hàng đợi, worker | `Redis:Enabled`, `Redis:Host`, `Redis:Port`, `Redis:Password`, `Redis:Ssl`, `ProcessingWorker:*` (`Transport`, `DispatcherEnabled`, `ConsumerEnabled`, `WorkerApiEnabled`, `GeometryPullEnabled`, `GeometryLeaseSeconds`), `Publishing:*` | Hàng đợi xử lý IFC và dựng gói |
| Chơi thử, phiên học | `Playtest:Enabled`, `Playtest:SigningKey`, `Playtest:HandoffKey`, `Playtest:HandoffDeepLinkBaseUrl`, `LearnerSessions:*` | Mở bài chơi thử từ web sang điện thoại, phiên học viên |
| Khác | `BootstrapAdmin:Email`, `BootstrapAdmin:Password`, `MediatR:LicenseKey`, `ForwardedHeaders:KnownProxies`, `Compatibility:BuildingHeadersOptional`, `AuthDiagnostics:DatabaseTimingEnabled`, `APP_VERSION` | Tạo Admin đầu tiên, khóa giấy phép MediatR, proxy Caddy, chẩn đoán |
| Kiểm thử (chỉ trên máy) | `FIRE3D_TEST_*`, `FIRE3D_IFC_TEST_CONNECTION`, `FIRE3D_RESET_TEST_ADMIN`, `FET3D_BILLING_TEST_ADMIN`, `FIRE3D_OPENAPI_OUTPUT` | Kiểm thử tích hợp, sinh tài liệu API |

GitHub Actions của BE (workflow `azure-deploy.yml`, dựng ảnh Docker lên GHCR rồi triển khai lên EC2):

| Tên | Loại | Dùng cho |
| :--- | :--- | :--- |
| `AWS_BE_SSH_KEY` | Secret | Khóa SSH vào máy chủ BE |
| `DEPLOY_PREFLIGHT_CONNECTION` | Secret | Chuỗi kết nối để kiểm tra cơ sở dữ liệu trước khi triển khai |
| `AWS_BE_HOST`, `AWS_BE_KNOWN_HOSTS`, `AWS_BE_URL` | Variable | Địa chỉ máy chủ, dấu vân tay SSH, địa chỉ kiểm tra sau triển khai |

### AI

Đặt trong `rag-api/.env` và `ifc-worker/.env` trên máy chủ AI (không commit; mẫu ở `.env.example`). Workflow CI của AI không dùng secret.

| Dịch vụ | Tên biến | Dùng cho |
| :--- | :--- | :--- |
| RAG API | `AI_API_KEY` | Khóa BE dùng để gọi AI |
| RAG API | `DATABASE_URL`, `KNOWLEDGE_DATABASE_URL`, `CHROMA_PATH` | Cơ sở dữ liệu tri thức (`pgvector`), kho Chroma cũ |
| RAG API | `LLM_PROVIDER`, `GEMINI_API_KEY`, `GEMINI_CHAT_MODEL`, `GEMINI_EMBEDDING_MODEL`, `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OPENAI_VISION_MODEL` | Nhà cung cấp mô hình (production dùng Gemini) |
| RAG API | `CHAT_PROVIDER`, `CHAT_BASE_URL`, `CHAT_API_KEY`, `CHAT_MODEL`, `CHAT_REASONING_EFFORT`, `EMBED_PROVIDER`, `LOCAL_MODEL_DIR`, `LOCAL_EMBED_THREADS` | Tùy chọn: cổng trả lời riêng, mô hình nhúng chạy tại máy |
| RAG API | `LLM_TIMEOUT_SECONDS`, `MAX_OUTPUT_TOKENS`, `GENERAL_ANSWERS`, `REQUEST_STALE_SECONDS`, `RECOVERY_INTERVAL_SECONDS`, `SOURCE_MAX_BYTES`, `SOURCE_FETCH_TIMEOUT_SECONDS`, `SOURCE_RETRY_SECONDS`, `EMBED_ITEMS_PER_MINUTE`, `EMBED_TOKENS_PER_MINUTE`, `EMBED_BATCH_SIZE`, `MAX_BIM_UPLOAD_BYTES`, `ALLOWED_IMAGE_MIME_TYPES`, `CORS_ORIGINS`, `LEGACY_ROUTES_ENABLED`, `ENVIRONMENT` | Giới hạn, thời gian chờ, nhịp nạp nguồn |
| IFC worker (cũ, đã thay bằng worker trong repo Unity) | `BE_BASE_URL`, `WORKER_KEY`, `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT_URL`, `BLENDER_PATH`, `MAX_SOURCE_BYTES`, `MAX_CONCURRENT_JOBS`, `ENVIRONMENT` | Lấy việc từ BE, đọc/ghi S3 |

Chi tiết từng biến (bắt buộc hay không, mặc định) ở [AI/docs/tong-quan-va-env.md](../AI/docs/tong-quan-va-env.md).

### FE

Đặt trong Environment Variables của dự án Vercel; khi chạy trên máy dùng `.env.local` (mẫu ở `.env.example`). Workflow CI của FE không dùng secret; Vercel tự triển khai khi gộp nhánh ([ci-cd](../FE/docs/ci-cd.md)).

| Tên biến | Dùng cho |
| :--- | :--- |
| `NEXT_PUBLIC_API_BASE_URL` | Địa chỉ BE |
| `NEXT_PUBLIC_AUTH_MODE` | Chế độ đăng nhập |
| `NEXT_PUBLIC_RAG_API_URL` | Địa chỉ AI (đường cũ) |
| `NEXT_PUBLIC_FIREBASE_API_KEY`, `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`, `NEXT_PUBLIC_FIREBASE_PROJECT_ID`, `NEXT_PUBLIC_FIREBASE_APP_ID` | Đăng nhập Google qua Firebase (giá trị công khai phía trình duyệt) |
| `NEXT_PUBLIC_QR_LANDING_ORIGIN` | Tên miền in trong mã QR |
| `FET3D_DEV_API_PROXY`, `ANALYZE`, `PLAYWRIGHT_BASE_URL` | Chỉ dùng khi phát triển: proxy API, đo kích thước gói, kiểm thử trình duyệt |

### Mobile

Ứng dụng đọc `.env` khi dựng trên máy (mẫu ở `.env.example`); workflow `google-play.yml` lấy từ GitHub Variables và Secrets. `google-services.json` (cấu hình Firebase Android) nằm trong repo.

| Tên | Loại / nơi đặt | Dùng cho |
| :--- | :--- | :--- |
| `EXPO_PUBLIC_API_BASE_URL` | Variable, `.env` | Địa chỉ BE |
| `EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID` | Variable, `.env` | Đăng nhập Google |
| `EXPO_OWNER`, `EXPO_PROJECT_SLUG` | Variable | Dự án Expo |
| `ANDROID_VERSION_CODE_BASE` | Variable | Gốc tính versionCode cho mỗi lượt dựng CI |
| `EXPO_TOKEN_FET3D` | Secret | Đăng nhập Expo để dựng (đưa vào bước dựng thành `EXPO_TOKEN`) |
| `ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_KEYSTORE_PASSWORD`, `ANDROID_UPLOAD_KEY_ALIAS`, `ANDROID_UPLOAD_KEY_PASSWORD` | Secret | Khóa tải lên Google Play để ký AAB |
| `FET3D_APP_VERSION`, `FET3D_ANDROID_VERSION_CODE` | Biến môi trường khi dựng | Phiên bản ứng dụng và versionCode (`app.config.js`) |
| `FET3D_RELEASE_STORE_PASSWORD`, `FET3D_RELEASE_KEY_ALIAS`, `FET3D_RELEASE_KEY_PASSWORD` | Biến môi trường khi dựng, lấy từ các Secret trên hoặc do trưởng nhóm nhập khi dựng trên máy | Ký gói Android |

### Unity worker

Hai worker chạy trên máy ảo Azure Windows, cấu hình bằng tệp JSON cạnh script (mẫu có trong repo); khóa worker để gọi BE nằm trong tệp riêng do `keyFile` trỏ tới, không commit. Repo Unity không có GitHub Actions.

| Worker | Tệp mẫu | Khóa cấu hình |
| :--- | :--- | :--- |
| Worker IFC | `Unity/Tools/GeometryWorker/geometry-worker.config.example.json` | `baseUrl`, `toolchainVersion`, `pythonExe`, `workRoot`, `keyFile`, `pollSeconds`, `renewSeconds`, `timeoutMinutes`, `keepJobs`, `httpTimeoutSeconds`, `selfUpdate`, `codeBranch`, `gitTimeoutSeconds` |
| Worker dựng gói | `Unity/Tools/PackageWorker/worker.config.example.json` | `baseUrl`, `toolchainVersion`, `buildTarget`, `unityExe`, `projectPath`, `workRoot`, `keyFile`, `pollSeconds`, `renewSeconds`, `buildTimeoutMinutes`, `gpuBake`, `noBake`, `noGraphics`, `gitPull`, `gitBranch`, `keepJobs`, `httpTimeoutSeconds` |

Phiên bản runtime đang bật trên production không phải biến môi trường: PlatformAdmin đăng ký trên trang quản trị từ tệp `runtime-<phiên bản>.json` ([huong-dan-quan-tri.md](huong-dan-quan-tri.md)).

## 3. Thư viện chính và giấy phép

Chỉ liệt kê thư viện khai báo trực tiếp, không liệt kê gói phụ thuộc gián tiếp. Giấy phép ghi theo giấy phép công bố của dự án gốc ở phiên bản đang dùng; chưa chạy công cụ quét giấy phép tự động trên toàn bộ cây phụ thuộc.

### BE — .NET 10 (`BE/Fire3D/*/*.csproj`)

| Thư viện | Phiên bản | Giấy phép | Ghi chú |
| :--- | :--- | :--- | :--- |
| ASP.NET Core, Entity Framework Core, Identity, JwtBearer, OpenApi | 10.0.x | MIT | Nền tảng API |
| Npgsql.EntityFrameworkCore.PostgreSQL, EFCore.NamingConventions | 10.0.3 / 10.0.1 | PostgreSQL License / Apache-2.0 | Truy cập PostgreSQL |
| MediatR | 14.2.0 | Giấy phép thương mại của Lucky Penny Software, có bản Community miễn phí | Từ bản 13 cần khóa giấy phép (`MediatR:LicenseKey`). Chưa xác nhận nhóm dùng bản nào |
| FluentValidation | 12.2.0 | Apache-2.0 | |
| FirebaseAdmin | 3.6.0 | Apache-2.0 | |
| AWSSDK (Core, S3, Extensions) | 4.0.x | Apache-2.0 | |
| StackExchange.Redis | 3.3.1 | MIT | |
| payOS | 2.1.0 | Chưa xác định | SDK của PayOS |
| Serilog (AspNetCore, Console, Debug, Grafana.Loki), prometheus-net | 10.0.0 / 8.2.1 | Apache-2.0 / MIT | Ghi log, số đo |
| Swashbuckle.AspNetCore | 10.3.1 | MIT | Trang tài liệu API |
| SkiaSharp | 4.153.1 | MIT | Xử lý ảnh |
| MiniExcel | 1.46.0 | Apache-2.0 | Xuất Excel |
| xunit, Testcontainers.PostgreSql, JsonSchema.Net | 2.9.3 / 4.15.0 / 9.4.1 | Apache-2.0 / MIT / MIT | Chỉ dùng khi kiểm thử |

### AI — Python (`AI/rag-api/requirements.txt`, `AI/ifc-worker/requirements.txt`)

| Thư viện | Giấy phép |
| :--- | :--- |
| fastapi, uvicorn, pydantic-settings, httpx, python-multipart | MIT / BSD-3-Clause |
| google-genai, openai, fastembed | Apache-2.0 |
| chromadb | Apache-2.0 |
| psycopg | LGPL-3.0 |
| pgvector (Python), sqlalchemy | MIT |
| pypdf | BSD-3-Clause |
| ifcopenshell | LGPL-3.0 |
| trimesh / numpy / jsonschema / boto3 | MIT / BSD-3-Clause / MIT / Apache-2.0 |

### FE — Next.js (`FE/package.json`)

| Thư viện | Phiên bản | Giấy phép |
| :--- | :--- | :--- |
| next, react, react-dom | 16.3.5 / 19.3.0 | MIT |
| three, web-ifc | 0.176 / 0.0.68 | MIT / MPL-2.0 |
| firebase | 12.19 | Apache-2.0 |
| Radix UI, cmdk, class-variance-authority, clsx, tailwind-merge, tailwindcss | — | MIT |
| motion, recharts, qrcode | — | MIT |
| lucide-react | 0.511 | ISC |
| Phông Be Vietnam Pro (`@fontsource/be-vietnam-pro`) | 5.3 | SIL OFL 1.1 |
| Bộ biểu tượng Iconsax trong `FE/public/icons/iconsax/` | — | Tệp `LICENSE` kèm theo là GPL-3.0; chưa rà lại điều kiện dùng cho web |
| Công cụ phát triển: typescript, eslint, playwright | — | Apache-2.0 / MIT |

### Mobile — React Native/Expo (`Mobile/package.json`)

| Thư viện | Phiên bản | Giấy phép |
| :--- | :--- | :--- |
| react-native, react | 0.86.3 / 19.2.3 | MIT |
| expo và các gói `expo-*` (router, camera, sqlite, file-system, notifications, secure-store, …) | ~57.0 | MIT |
| @react-native-firebase/app, /auth | 26.4 | Apache-2.0 |
| @react-native-google-signin/google-signin | 16.1 | MIT |
| @react-native-async-storage/async-storage, react-native-screens, react-native-safe-area-context, react-native-svg | — | MIT |
| lucide-react-native | 1.61 | ISC |
| @noble/hashes | 2.4 | MIT |
| Phông Be Vietnam Pro (`@expo-google-fonts/be-vietnam-pro`) | 0.4 | SIL OFL 1.1 |
| Unity as a Library (bản Unity ghim, xem [release-manifest](release-manifest.md#2-runtime-và-bản-unity-trong-ứng-dụng)) | 6000.6.6f1 | Điều khoản Unity (Unity Personal/Student) |

### Unity (`Unity/Packages/manifest.json`, `Unity/Tools/GeometryWorker/requirements.txt`)

| Thư viện | Phiên bản | Giấy phép |
| :--- | :--- | :--- |
| Unity Editor 6000.6.6f1 | — | Điều khoản Unity |
| com.unity.entities, collections, burst, mathematics | 6.6.0 / 6.6.0 / 2.0.0 / 1.4.0 | Unity Companion License |
| com.unity.render-pipelines.universal (URP), inputsystem, ugui, test-framework | 17.6.0 / 1.20.0 / 2.6.0 / 1.8.0 | Unity Companion License |
| com.unity.cloud.gltfast | 6.14.1 | Unity Companion License |
| com.unity.nuget.newtonsoft-json | 3.2.2 | MIT (Newtonsoft.Json) |
| Biểu tượng Lucide trong `Assets/_Fire3D/Resources/UI/Icons/` | — | ISC (`LICENSE-lucide.txt`) |
| Worker IFC: ifcopenshell, numpy, shapely, lark | 0.9.0.post1 / 2.4.6 / 2.2.0 / 1.3.1 | LGPL-3.0 / BSD-3-Clause / BSD-3-Clause / MIT |
| Công cụ trên máy ảo: Blender (dựng hình IFC cũ), Python 3 | — | GPL-2.0+ / PSF |

## 4. Tài sản 3D, động tác, âm thanh và ảnh

Nguồn từng tệp ghi trong các tệp CREDITS của repo Unity; bảng dưới chỉ tóm tắt.

| Loại | Nguồn chính | Giấy phép | Chi tiết |
| :--- | :--- | :--- | :--- |
| Nhân vật (người chơi, NPC) | Trưởng nhóm tạo bằng Tripo Studio, chỉnh trong Blender, gắn xương bằng Reallusion AccuRig (thân cũ dùng Mixamo) | Điều khoản dùng của Tripo, AccuRig, Mixamo | [Characters/CREDITS.md](../Unity/Assets/_Fire3D/Art/Characters/CREDITS.md) |
| Động tác | Universal Animation Library của Quaternius (CC0); động tác nhóm tự làm trong Blender trên khung xương đó; một số động tác ActionForge; hai động tác `InjuredWalk`, `PanicRun` và tư thế `WaveForHelp` chưa ghi nguồn | CC0 / tự làm / điều khoản ActionForge / chưa ghi | Như trên |
| Thiết bị PCCC, đồ vật | Poly Haven, Kenney, ambientCG, Blendkit (CC0 và Royalty Free), Sketchfab (CC BY 4.0, phải ghi tên tác giả), mô hình nhóm tạo bằng Tripo hoặc script Blender | CC0 / CC BY 4.0 / Blendkit Royalty Free / của nhóm | [Equipment/CREDITS.md](../Unity/Assets/_Fire3D/Art/Equipment/CREDITS.md) |
| Biển báo | Hình ISO 7010 từ Wikimedia Commons + phông Be Vietnam Pro | Phạm vi công cộng / SIL OFL 1.1 | Như trên |
| Bầu trời, hiệu ứng | HDRI Poly Haven, Kenney Particle Pack, khói và nổ dựng từ tài sản Blendkit | CC0 / theo Blendkit | Như trên |
| Âm thanh | Bản ghi thật từ Freesound, OpenGameArt, Kenney (CC0) và Pixabay (Pixabay Content License); không dùng âm thanh tổng hợp bằng mã, không dùng bản Pixabay gắn nhãn "AI generated" | CC0 / Pixabay Content License | [Audio/CREDITS.md](../Unity/Assets/_Fire3D/Art/Audio/CREDITS.md) |
| Ảnh bài học trên web | Ảnh thật có ghi nguồn trong từng bài | Theo nguồn ghi trong bài | Dữ liệu bài học trên production |
| Hai tệp IFC nghiệm thu | Tệp thử nội bộ của nhóm, không commit vào repo | Chưa rà | [IFC mục 10.1](ifc_ingestion_visual_interaction.md#101-hai-công-trình-nghiệm-thu) |

**Quyết định của trưởng nhóm ngày 16/11/2026:** không rà thêm điều khoản thương mại của tài sản 3D, động tác và hai tệp IFC nghiệm thu. Dự án dùng cho học tập, phi thương mại; hai tệp IFC không phát hành kèm sản phẩm, công trình thật do tổ chức tự tải lên ([overview, Quyết định ngày 16/11/2026](fire_evacuation_project_overview.md#quyết-định-của-trưởng-nhóm-ngày-16112026)). Nếu sau này phát hành thương mại thì phải rà lại các mục ghi "điều khoản dùng", "chưa ghi" ở bảng trên, giấy phép MediatR và bộ biểu tượng Iconsax.

**Việc còn thiếu không phụ thuộc mục đích thương mại:** giấy phép CC BY 4.0 của các mô hình Sketchfab yêu cầu ghi tên tác giả. `Equipment/CREDITS.md` ghi cần có dòng ghi tên trong màn hình giấy phép của ứng dụng, nhưng lần rà ngày 16/11/2026 không tìm thấy màn hình hay dòng ghi tên nào trong mã Mobile, Unity hoặc FE.
