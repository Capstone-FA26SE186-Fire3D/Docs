# Kế hoạch thêm OrganizationUser vào Mobile

**Ngày lập:** 10/10/2026

**Trạng thái:** Kế hoạch triển khai; chưa phải bằng chứng Mobile hoặc BE/Unity đã nghiệm thu.

## 1. Mục tiêu và ranh giới

Mở một khu riêng trong ứng dụng Android hiện tại cho `OrganizationUser` để đăng ký/đăng nhập, quản lý hồ sơ tổ chức, xem Building và theo dõi vận hành khi không ngồi ở máy tính. Giữ nguyên các luồng Trainee. `PlatformAdmin` không có khu Mobile trong đợt này.

Mobile chỉ **đọc** Building và số liệu vận hành. Tạo/sửa/lưu trữ Building, IFC/editor, soạn/phát hành kịch bản, xuất hoặc xoay QR, billing chi tiết và thống kê học viên đầy đủ tiếp tục ở web. Playtest trên Mobile/Unity là giai đoạn sau, chỉ mở khi toàn bộ điều kiện tích hợp ở mục 4 đạt. Phạm vi này là lựa chọn kênh sử dụng, không thay đổi quyền nghiệp vụ của `OrganizationUser` trong [requirements](fire_evacuation_requirements.md) và [features](fire-evacuation-training-features.md).

## 2. Hiện trạng và contract dùng làm nguồn

- [Mobile hiện tại](../Mobile/README.md) chỉ nhận phiên `Trainee`; đăng nhập Google, OTP, hồ sơ cá nhân, support và FCM đã có mã nhưng vẫn cần thử trên Android với Firebase/BE thật. Không coi test mock hoặc route có trong OpenAPI là nghiệm thu provider.
- [BE authentication](../BE/docs/authentication.md) có đăng ký OrganizationUser qua OTP, Google exchange/onboarding/link, phiên Fire3D và `GET/PATCH /api/organizations/me`. BE quyết định role, tenant và trạng thái tài khoản/tổ chức; client không gửi `organizationId` để tự nhận quyền.
- [BE API guide](../BE/docs/api-docs.md) có `GET /api/buildings`, `GET /api/buildings/{id}` và `GET /api/organizations/me/analytics/operations`. Endpoint analytics hiện trả snapshot tài khoản, Building, IFC jobs và support tickets trong phạm vi tenant; **không** trả `Trainee unique`, `Learner plays`, completion hay duration theo yêu cầu analytics học viên.
- [BE playtest contract](../BE/docs/playtest-manual-test.md) có prepare/start theo phiên, tenant, package và entitlement. Start có thể trả `503 PLAYTEST_LAUNCH_UNAVAILABLE` khi signing chưa bật; source/test BE không chứng minh Unity, package thực hoặc client Android đã chạy.

Khi bắt đầu từng mốc, đối chiếu lại OpenAPI của môi trường đích với source BE đang deploy. Nếu contract thực tế khác tài liệu, cập nhật ma trận tích hợp trước khi mở UI phụ thuộc; không tạo dữ liệu giả để lấp khoảng trống.

## 3. Lộ trình Mobile

### Mốc A — Tài khoản và phân quyền

1. Mở lựa chọn đăng ký **Trainee** hoặc **Tổ chức**. Form tổ chức giữ email, password/confirmPassword, `organizationName`, `organizationAddress`, `organizationPhoneNumber` và các trường hồ sơ cá nhân tùy chọn chỉ trong bộ nhớ. Dùng chung request OTP → verify OTP → `registrationToken`, sau đó gọi `POST /api/auth/register/organization`. `201 AccountResponse` chưa phải phiên; chuyển tới đăng nhập để nhận Fire3D token. Không lưu password, proof hoặc OTP vào URL/AsyncStorage.
2. Google Sign-In tiếp tục gửi Firebase ID token dạng JSON string tới `POST /api/auth/login-firebase`. Với `OnboardingRequired`, cho chọn loại tài khoản và dùng form tổ chức để gọi `POST /api/auth/google/onboarding/complete` với `accountType: "organization"`, onboarding token và ba trường tổ chức; không gửi email/UID/tenant do client tự nhận. `Authenticated` dùng phiên BE và role trong `authentication.user`. Nếu completion đã commit nhưng mất response hoặc trả `ONBOARDING_ALREADY_COMPLETED`, exchange Firebase token lại để phục hồi; không phát hành phiên từ proof cũ. `ACCOUNT_LINK_REQUIRED` đi qua đăng nhập local và liên kết Google có xác nhận mật khẩu hiện tại.
3. Thay chặn `role !== Trainee` trong khôi phục phiên/đăng nhập bằng định tuyến rõ ràng: `Trainee` vào khu học viên; `OrganizationUser` có `organizationId` vào khu tổ chức; `PlatformAdmin` hiện thông báo chưa hỗ trợ trên Mobile và không mở màn nghiệp vụ. Không suy quyền từ màn đã chọn, Google account hoặc `organizationId` lưu trên máy.
4. Khi đăng xuất hoặc đổi tài khoản, thu hồi binding FCM của tài khoản cũ theo luồng hiện có rồi xóa phiên và state/cached response theo role/tenant. Nếu revoke thất bại do mạng, giữ phiên và báo thử lại; không để dữ liệu tổ chức A hiện dưới tài khoản B. Giữ hành vi refresh, logout-all, reset/change password và support dùng phiên Fire3D.

**Điều kiện xong mốc A:** hai role vào đúng khu; OTP, Google onboarding/link và account switch có trạng thái lỗi rõ; tài khoản bị khóa/organization không hoạt động không giữ màn tổ chức sau xác minh phiên.

### Mốc B — Hồ sơ, Building và dashboard chỉ đọc

1. Khu tổ chức có trang tổng quan, danh sách Building, chi tiết Building, hồ sơ tổ chức và lối vào hồ sơ cá nhân/support. Hồ sơ tổ chức dùng `GET /api/organizations/me` lấy ETag riêng, rồi `PATCH /api/organizations/me` với `If-Match`; chỉ gửi field người dùng sửa (`name`, `address`, `phoneNumber` theo DTO BE), không dùng ETag của `/api/auth/me`. Sau `412` tải lại dữ liệu và yêu cầu người dùng xác nhận lần sửa mới; `428`, `400` và `409 ORGANIZATION_PHONE_EXISTS` hiển thị đúng field. Hồ sơ cá nhân/avatar giữ API và ETag riêng hiện có.
2. Danh sách `GET /api/buildings` dùng phân trang, search và lọc active theo contract BE; chi tiết dùng `GET /api/buildings/{id}`. Không thêm nút tạo/sửa/archive/IFC/QR trong Mobile. BE là nguồn kiểm tenant; `403/404` không được biến thành dữ liệu của tenant khác. Khi tài khoản/tenant đổi, hủy request cũ và xóa cache Building trước khi render tài khoản mới.
3. Dashboard gọi `GET /api/organizations/me/analytics/operations` với khoảng thời gian dương tối đa 90 ngày, hiển thị `asOf`, kỳ lọc và đúng bốn nhóm BE trả về: accounts, buildings, ifcJobs, tickets. Đặt nhãn **Vận hành tổ chức**; không đổi các số này thành analytics học viên. Trạng thái rỗng, tải lại, lỗi mạng và phiên hết hạn phải có đường xử lý rõ.
4. Tái sử dụng support và FCM cho OrganizationUser. Binding FCM vẫn gắn installation với phiên/tài khoản hiện hành; không gửi Expo push token thay cho FCM device token. Nội dung push chỉ mở màn mà role hiện tại được phép truy cập.

**Điều kiện xong mốc B:** profile ETag và xung đột phone đúng contract; Building/dashboard chỉ hiển thị dữ liệu tenant đã xác thực; thay tài khoản không lộ state của tài khoản trước; không có số liệu học viên được suy diễn từ dashboard vận hành.

### Mốc C — Thiết kế và cổng mở playtest

Thiết kế màn chọn Building → scenario/draft/version thuộc tenant → chuẩn bị playtest, nhưng không hiện nút chạy Unity cho người dùng cho tới khi cổng dưới đây đạt. Khi triển khai, prepare dùng `POST /api/scenarios/{scenarioId}/playtests` với revision/version hoặc draft hợp lệ và `Idempotency-Key`; start dùng `POST /api/playtests/{playtestId}/start` với `runtimeVersion` thực và key riêng. Không dùng QR Trainee, learner session, learner result hoặc learner analytics để đại diện playtest.

Chỉ mở launch khi có **accepted immutable PlaytestPackage** khớp revision/version, manifest và artifact đã verify; Building có paid entitlement hợp lệ hoặc Trial còn lượt; BE bật signing/start; Unity Android xác minh issuer/audience/purpose và pin của launch grant; native bridge trao grant/package đúng protocol. Phải xử lý `503 PLAYTEST_LAUNCH_UNAVAILABLE`, entitlement/package/runtime conflict, grant hết hạn và replay idempotent mà không tự cấp quyền hay trừ quota trên client. Nghiệm thu bằng BE + package + Unity thật, không bằng fake worker hoặc mock API đơn lẻ.

## 4. Kiểm thử và nghiệm thu

| Lớp | Ca tối thiểu | Bằng chứng |
| --- | --- | --- |
| Contract/model | Organization OTP/register, Google onboarding/recovery/link, phân role, ETag tổ chức riêng, query Building/dashboard, FCM revoke/bind | Test tự động với response BE mẫu; không thay cho provider thật |
| UI/e2e mock | Chuyển Trainee ↔ OrganizationUser, đổi tài khoản A → B, lỗi OTP/phone/ETag/401/403/404, empty/loading/retry, không có nút mutation Building hoặc playtest chưa mở | Playwright/screenshots và kiểm tra state sau đăng xuất |
| Android + BE | Development build trên emulator có Google Play: đăng ký OTP, Google, profile, avatar, support, FCM, Building và dashboard bằng tài khoản OrganizationUser thử nghiệm thuộc ít nhất hai tenant | Ghi môi trường, account test và kết quả từng API; không đưa secret vào repo |
| Playtest | Package, entitlement, BE signing, Unity verifier/bridge và start idempotent cùng hoạt động; không ghi vào learner analytics | Biên bản tích hợp BE/Unity/Android riêng trước khi bật UI |

Sau mỗi mốc chạy typecheck, contract tests, Playwright phù hợp và Android build; phân biệt lỗi ứng dụng với lỗi cấu hình Firebase, provider, BE hoặc Unity. Tài liệu API/README Mobile được cập nhật khi mã thực sự triển khai, không đánh dấu hoàn tất trước khi có bằng chứng.

## 5. Phụ thuộc và tiêu chí dừng

- Google trên Android cần Google provider, SHA-1 của development build và `google-services.json` có Android OAuth client cho `com.fet3d.app`; cấu hình này chưa được xác nhận. Không chặn viết UI/test mock, nhưng chặn nghiệm thu Google thật.
- Cần tài khoản OrganizationUser thử nghiệm ở hai tenant và một Trainee để kiểm phân quyền/chuyển tài khoản. Chưa có tài khoản thử nghiệm được cung cấp trong phiên lập kế hoạch.
- Mốc C dừng ở thiết kế khi thiếu package thực, entitlement, signing hoặc Unity verifier/bridge. Không mở nút playtest hoặc báo hoàn tất chỉ vì BE có endpoint.
- Kế hoạch này không xác nhận QR → Unity → kết quả Trainee của bản capstone; đó là luồng tích hợp riêng.
