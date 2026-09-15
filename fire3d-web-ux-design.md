# Fire3D — đặc tả UX web và hướng hình ảnh

**Trạng thái:** quyết định thiết kế đã thống nhất, chưa phải tính năng đã triển khai  
**Cập nhật:** 2026-09-15  
**Phạm vi:** website công khai, cổng Learn, Góc học tập và khu quản lý tổ chức

## 1. Ý tưởng sản phẩm

Fire3D dùng một website chung và điều hướng theo nhu cầu. Khách có thể mở landing, khám phá dự án, đọc/tìm bài Learn và xem cách tham gia tập huấn mà không cần chọn vai trò trước. Đăng nhập chỉ xuất hiện khi hành động cần dữ liệu cá nhân hoặc quyền nghiệp vụ.

Thanh menu thống nhất:

```text
Khám phá · Dành cho tổ chức · Learn · Về chúng tôi       Đăng nhập · Tải ứng dụng
```

Landing dùng một hành trình góc nhìn thứ nhất trong công trình đang cháy. Người xem cuộn để di chuyển qua không gian, hiểu Fire3D qua những gì đang xảy ra trong công trình, rồi mới gặp hai hướng đi theo nhu cầu:

```text
POV trong công trình đang cháy
  -> giới thiệu không gian, tập huấn và kết quả
  -> hai ngã rẽ
       -> Tôi muốn tập huấn -> cảnh thu vào điện thoại -> đăng nhập/Góc học tập
       -> Tôi muốn tổ chức tập huấn -> mặt cắt tòa nhà -> Dành cho tổ chức
```

Hai nhánh là điều hướng nội dung, không thay đổi loại tài khoản. Menu vẫn cho phép truy cập trực tiếp từng khu vực.

## 2. Hệ thống hình ảnh

### 2.1. Màu sắc

| Vai trò | Giá trị |
|---|---|
| Nền chính | `#141719` |
| Bề mặt nổi | `#202629` |
| Chữ chính | `#F3F5F4` |
| Chữ phụ | `#B8C1C4` |
| Ember cam, hành động chính | `#EE8654` |
| Chữ trên nền ember | `#141719` |

Cam là tín hiệu thương hiệu và hành động chính. Màu biển báo, đèn thoát và trạng thái trong cảnh phải giữ ngữ nghĩa riêng; không dùng cam cho mọi trạng thái. Trạng thái quan trọng luôn đi cùng chữ hoặc biểu tượng để không phụ thuộc màu.

### 2.2. Chữ và bố cục

- Font đề xuất: **Be Vietnam Pro**, self-host WOFF2 có đủ dấu tiếng Việt; fallback `system-ui, sans-serif`.
- Thân bài dùng weight 400, điều hướng 500, tiêu đề 600–700. Không dùng font display hẹp làm giảm khả năng đọc tiếng Việt.
- Hero heading khởi điểm 48–72 px trên desktop và 32–44 px trên mobile. Thân bài 16–18 px.
- Learn dùng 18 px, line-height khoảng 1.7 và measure khoảng 60–70 ký tự để đọc dài thoải mái.
- Khoảng cách theo nhịp 8 px; vùng bấm tối thiểu 44 px; nút bo 8 px; bề mặt nội dung bo 12 px.
- Landing giữ chữ ngắn, tương phản trên vùng tối ổn định. Learn, Về chúng tôi và Dành cho tổ chức dùng bố cục đọc rõ, không đặt đoạn dài lên vùng khói sáng.
- Headline định hướng: **“Làm quen hôm nay. Chủ động ngày mai.”**

Font, cỡ chữ và spacing ở trên là mặc định thiết kế để dựng prototype; cần kiểm tra lại bằng ảnh chụp thực tế, dấu tiếng Việt và độ tương phản ở frame sáng nhất trước khi khóa design token.

## 3. Storyboard landing

### Cảnh 1 — bước vào

Khung hình mở ngay trong hành lang, không có màn hình chọn vai trò. Camera ở tầm mắt người, đường chân trời ổn định. Ánh sáng chính yếu, một nguồn lửa ở bên cạnh hoặc phía xa tạo vùng ember trên sàn, tường và khung cửa. Headline và một câu mô tả ngắn nằm ở vùng ít khói.

### Cảnh 2 — nhận ra không gian

Cuộn xuống đưa camera tiến theo đường đi đã dựng. Các mốc như cửa, cột, cầu thang, biển thoát và điểm cháy giúp người xem hiểu công trình. Khói chia lớp gần và xa, có thể khuất sau cửa/cột; không đặt một lớp khói phẳng lên toàn màn hình.

### Cảnh 3 — hiểu cách tập huấn

Khi camera đi qua các mốc, nội dung lần lượt giải thích: làm quen không gian, thử quyết định trong mô phỏng, xem lại lựa chọn và kết quả. Mỗi thông điệp xuất hiện tại một khoảng camera di chuyển chậm, sau đó giữ đủ lâu để đọc.

### Cảnh 4 — điểm chuyển

Camera đi qua khung cửa hoặc vùng khói dày. Vật thể tiền cảnh che một phần khung hình để tạo chuyển cảnh tự nhiên. Hình học và ánh sáng của cảnh kế tiếp khớp phối cảnh với cảnh trước; không dùng màn hình trắng hoặc đường phân đoạn trang lộ rõ.

### Cảnh 5 — hai ngã rẽ

Hai lựa chọn hiện bằng nhãn nhu cầu, không bằng tên role:

- **Tôi muốn tập huấn**
- **Tôi muốn tổ chức tập huấn**

Người dùng có thể chọn bằng nút, bàn phím hoặc liên kết trong menu. Nếu không chọn, cuộn tiếp sẽ giữ cảnh ở trạng thái chờ và giải thích ngắn hai hướng.

## 4. Motion và tương tác

- Cuộn xuống tiến và cuộn lên lùi theo cùng một đường camera. Dừng cuộn thì camera dừng tại vị trí hiện tại; khói, lửa và ánh sáng môi trường tiếp tục chuyển động nhẹ.
- Không phát lùi video cháy. Nếu dùng clip tham khảo hoặc video dựng sẵn, clip chỉ chạy theo chiều tiến; trạng thái lùi dùng frame seek hoặc lớp 3D tương ứng.
- Camera dùng nội suy mượt, không rung đầu liên tục, không scroll-jacking và không tự kéo trang vượt quyền điều khiển của người dùng.
- Chỉ có một cao trào thị giác: hành lang đang cháy chuyển thành điểm nhìn mở ra hai nhánh. Các đoạn đọc trước đó phải yên hơn.
- Chuyển nhánh có thể bị ngắt; thao tác mới tiếp tục từ vị trí camera hiện tại và kết thúc ở lựa chọn cuối cùng, không snap về một nhánh cũ.
- Hiệu ứng lặp phải dừng khi tab ẩn. Tải cảnh theo vùng nhìn, giải phóng tài nguyên khi rời landing và tránh khởi tạo nhiều renderer.
- `prefers-reduced-motion: reduce` tắt camera transform, particle và biến dạng; thay bằng ảnh tĩnh, fade tối đa 200 ms và các liên kết vẫn hoạt động.
- Mobile dùng bố cục và crop riêng, giảm mật độ khói/particle, cho phép bỏ WebGL khi thiết bị không đáp ứng; nội dung và hai nhánh vẫn phải sử dụng được.

Các nguyên tắc này dựa trên `scroll-craft`, `3dviz-pro-max` và các record `state-playback`, `physics-timeline-lifecycle`, `interruptible-focus`, `loop-seam-continuity` trong bộ `motion-profile`. Đây là hướng dẫn thực thi, không phải bằng chứng hiệu năng đã đo.

## 5. Hai nhánh sau ngã rẽ

### 5.1. Người muốn tập huấn

Camera rẽ vào một vùng sáng hơn; cảnh công trình thu nhỏ thành mô hình trong màn hình Android. Một QR minh họa có thể xuất hiện như tín hiệu “mở hoạt động trên điện thoại”, nhưng không được hiểu là cài một game mới cho mỗi tòa nhà.

- Khách chưa đăng nhập: chọn tiếp tục sẽ đưa tới đăng nhập, sau đó về Góc học tập.
- Trainee đã đăng nhập: đi thẳng tới Góc học tập với AI, bài lưu, lịch sử và kết quả cá nhân.
- Chọn một hoạt động và **Mở trên điện thoại** để web hiển thị QR active của hoạt động. Điện thoại đã cài app mở/resolve training; chưa cài app thì mở kênh cài đặt hợp lệ và người dùng quét lại sau khi cài.
- Web không suy đoán hoặc ghi nhận trạng thái “đã cài app”. Android cài một lần, tải và xác minh content package Unity theo release đã resolve.

### 5.2. Tổ chức muốn tổ chức tập huấn

Camera quay và nâng ra khỏi hành lang, lộ mặt cắt tòa nhà vừa đi qua. Các tầng, cầu thang, điểm spawn và khu vực kịch bản tách nhẹ; đường liên kết ember được vẽ dần để giải thích quy trình. Mô hình giữ cùng vị trí trong lúc tiêu đề **Dành cho tổ chức** xuất hiện, tạo chuyển tiếp liền mạch vào trang chi tiết.

Trang công khai giải thích năng lực chuẩn bị công trình, nhập IFC, kiểm tra revision, tạo scenario, publish release/QR và xem analytics. Khu quản lý thực tế yêu cầu `OrganizationUser` đúng `organizationId`; landing không cấp quyền và không thay thế kiểm tra backend.

## 6. Learn và Góc học tập

### Learn công khai

- Tìm và đọc bài không cần tài khoản.
- Bài ngắn, dễ hiểu, có ảnh/diagram và nguồn.
- **Hỏi AI** yêu cầu đăng nhập; câu trả lời phải hiển thị nguồn.
- **Hỏi về bài này** mở chat mang theo ngữ cảnh bài đang đọc.
- **Lưu bài** đưa bài vào Góc học tập và yêu cầu đăng nhập.

Phân biệt rõ Learn web (kiến thức cộng đồng) với mode Learn trong Unity (làm quen không gian/runtime). Cổng Learn và AI kiến thức cộng đồng là phần mở rộng sản phẩm cần bổ sung vào đặc tả, chưa gán mốc Phase hoặc coi là đã có trong FE hiện tại.

### Góc học tập

Góc học tập là nơi riêng của Trainee sau đăng nhập, gồm hỏi AI, bài đã lưu, lịch sử hoạt động và kết quả tập huấn cá nhân. Trainee chỉ xem dữ liệu của mình; kết quả mô phỏng không phải chứng nhận hoặc kết luận an toàn công trình.

## 7. Cấu trúc source FE

FE áp dụng cấu trúc feature-first giống sơ đồ nhóm đề xuất để dễ tìm code, giới hạn phụ thuộc và bảo trì. `pages/` chỉ ghép route vào layout/feature; logic nghiệp vụ không đặt trong `App.tsx` hoặc page.

```text
src/
├─ assets/       # hình ảnh, fonts, global styles
├─ components/   # UI dùng chung toàn app
├─ configs/      # routes, constants, env parsing
├─ features/     # module theo nghiệp vụ
│  ├─ auth/      # components/, services/, types/
│  ├─ landing/   # components/, scene/, types/
│  ├─ learn/     # components/, services/, types/
│  ├─ learning-hub/ # components/, services/, types/
│  └─ organization/ # components/, services/, types/
├─ hooks/        # hooks dùng chung
├─ layouts/      # MainLayout, AuthLayout, app shell
├─ pages/        # route-level composition
├─ services/     # HTTP client, interceptors, cross-feature adapters
├─ store/        # global state tối thiểu (auth/session/UI)
├─ utils/        # hàm thuần và helper nhỏ
└─ App.tsx       # root composition/provider
```

Quy ước ownership:

- `features/<name>/` giữ UI, service và type chỉ thuộc feature đó; ví dụ camera/scene landing không được import vào Unity Mobile.
- `components/` không biết API hoặc role; các component có dữ liệu nghiệp vụ nhận props/type rõ ràng từ feature.
- `services/` giữ cấu hình Axios/fetch, auth interceptor, error mapping và adapter API dùng chung; endpoint cụ thể của feature ở `features/<name>/services/`.
- `configs/` chỉ parse env và constant không nhạy cảm; không commit secret. `store/` chỉ chứa state thực sự dùng qua nhiều route, còn state cục bộ ở feature.
- `pages/` và `layouts/` làm nhiệm vụ composition, loading/error boundary và accessibility; không chứa truy vấn dài hoặc logic Three.js.
- `assets/` chứa font Be Vietnam Pro, ảnh concept/fallback và style tokens. Asset 3D lớn phải lazy-load theo landing route.
- Khi chuyển FE hiện tại từ Vite sang Next.js, `pages/` có thể map sang App Router route modules; giữ nguyên ownership feature-first, không nhân bản business logic.

Các thư mục là target architecture cho task triển khai tiếp theo; task này không tự tạo placeholder hoặc di chuyển code RAG hiện tại.

## 8. Công cụ và skill thực thi

| Phần | Công cụ/skill | Ranh giới |
|---|---|---|
| Nhận diện và bố cục | `design-taste-frontend`, `web-design-guidelines`, `vercel-react-best-practices` | Xây token, hierarchy, accessibility, loading và responsive; không tự biến đề xuất thành backend contract |
| Cảnh 3D | Three.js, `3dviz-pro-max` | Custom building scene, camera path, fire source, smoke depth, occlusion, light response; Three.js chỉ ở FE landing |
| Component hiệu ứng | `@designcodeio/threeui@1.2.0` | Đã có trong FE và khóa bằng pnpm. Có thể kiểm tra `EmberStorm`, `ParticleDrift`, `WireframeForms` làm phụ trợ; không coi component có sẵn là toàn bộ cảnh cháy công trình |
| Cuộn và UI motion | `motion/react`, `ecc:motion-foundations`, `ecc:motion-advanced`, `scroll-craft` | Scroll progress, focus transition, reduced motion, cleanup và visibility; không dùng CSS layout animation hoặc scroll-jacking |
| Concept/ảnh fallback | `imagegen` | Tạo concept plate, texture và fallback still khi cần; copy chính luôn là HTML |
| Storyboard/video | `remotion-best-practices` | Dùng `useCurrentFrame()` để dựng teaser hoặc kiểm tra storyboard. Không bắt buộc runtime dependency và không thay thế scene Three.js tương tác |
| Handoff | `fire3d-fe-handoff` | Ghi checkpoint, bằng chứng và giới hạn; local notes không push |

FE hiện tại là React/TypeScript/Vite với RAG client thử nghiệm. Docs định hướng web đích là Next.js; việc chuyển stack và triển khai landing/Learn cần task kỹ thuật riêng.

## 9. Tiêu chí nghiệm thu thiết kế

- Khách mở landing và Learn mà không bị buộc chọn vai trò hoặc đăng nhập.
- Menu và hai nhánh dùng nhãn nhu cầu, có keyboard focus và vùng bấm đủ lớn.
- Cuộn tiến/lùi giữ đúng camera, khói lửa bám kiến trúc, có che khuất và phản sáng; dừng cuộn không làm mất trạng thái.
- Chuyển cảnh sang trainee và organization giữ liên tục không gian; người dùng có thể quay lại và chọn nhánh khác.
- Trainee chưa đăng nhập được đưa tới đăng nhập; Trainee đã đăng nhập tới Góc học tập; QR chỉ resolve training/release active và không mở gameplay web.
- OrganizationUser bị backend giới hạn theo `organizationId`; nội dung marketing công khai không cấp quyền nghiệp vụ.
- Cảnh có fallback ảnh tĩnh, reduced motion và phương án mobile; không trình bày mô phỏng như hướng dẫn chữa cháy hoặc chứng nhận PCCC.
- Bản dựng phải kiểm tra ảnh chụp ở desktop/mobile, frame sáng nhất để đo tương phản, loading WebGL, tab ẩn, cuộn nhanh/ngược, focus keyboard và tài nguyên renderer.

## 10. Tài liệu liên quan

- [Yêu cầu dự án](fire_evacuation_requirements.md)
- [Tính năng và phase](fire-evacuation-training-features.md)
- [Workflow](fire-evacuation-training-workflows.md)
- [Kiến trúc công nghệ](fire-evacuation-training-technology.md)
- [Tổng quan dự án](fire_evacuation_project_overview.md)
