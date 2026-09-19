# Fire3D — đặc tả UX web và hướng hình ảnh

**Trạng thái:** thiết kế và prototype FE đã triển khai; chưa nghiệm thu đầy đủ chất lượng hình ảnh/hiệu năng

**Cập nhật:** 2026-09-16
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

Trong cảnh 3D, hai lựa chọn là chữ sơn trên tường với mũi tên và vùng bấm trong suốt có nhãn truy cập. Khi đã chọn nhánh, các liên kết chữ cho phép đổi lựa chọn; nút Tiếp tục chỉ điều hướng khi chuyển cảnh ổn định. Bản reduced motion dùng điều khiển HTML thông thường. Nếu không chọn, cảnh giữ trạng thái chờ.

## 4. Motion và tương tác

- Cuộn xuống tiến và cuộn lên lùi theo cùng một đường camera. Dừng cuộn thì camera dừng tại vị trí hiện tại; khói, lửa và ánh sáng môi trường tiếp tục chuyển động nhẹ.
- Không phát lùi video cháy. Nếu dùng clip tham khảo hoặc video dựng sẵn, clip chỉ chạy theo chiều tiến; trạng thái lùi dùng frame seek hoặc lớp 3D tương ứng.
- Camera dùng nội suy mượt, không rung đầu liên tục, không scroll-jacking và không tự kéo trang vượt quyền điều khiển của người dùng.
- Cao trào của hành trình POV là điểm mở ra hai nhánh. Theo cập nhật prototype, nhánh tổ chức có thêm diễn tiến cháy đen và sụp từng khu khi người xem ở lại đủ lâu; không áp dụng cảnh sụp cho POV/điện thoại.
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
- QR công khai là QR ổn định của **Building**, không pin một Training. QR mở landing web/app để xem danh sách bài đã phát hành; Trainee chọn bài rồi phiên mới pin `training/release/scenario` cụ thể.
- Chưa cài app: QR mở trang web của tòa nhà, có đăng ký/đăng nhập và hướng dẫn tải app. Đã cài nhưng chưa đăng nhập: mở app và yêu cầu Google Sign-In/Firebase Auth. Đã đăng nhập: chỉ bắt đầu phiên sau khi backend kiểm tra service entitlement online.
- Nếu service hết hạn, QR và landing vẫn mở được nhưng chặn phát hành/bắt đầu phiên mới; phiên đang chạy có thể hoàn tất. Mất mạng sau khi bắt đầu thì app giữ kết quả và đồng bộ lại; mất mạng trước khi bắt đầu không được mở phiên.
- Web không suy đoán trạng thái “đã cài app”. Không hứa giữ deep link xuyên cài đặt nếu chưa kiểm chứng; có nút quay lại trang tòa nhà hoặc quét lại QR.

### 5.2. Tổ chức muốn tổ chức tập huấn

Camera quay và nâng ra khỏi hành lang, lộ mặt cắt tòa nhà vừa đi qua. Các tầng giữ kết nối thật, không tách nổi; lớp vỏ phía quan sát ẩn để thấy hành lang và cầu thang. Người xem kéo để xoay hoặc click/Tab vào vùng mô hình rồi dùng phím mũi tên; Home đặt lại góc. Theo phản hồi, bỏ khung viền vùng xoay cả khi dùng bàn phím, nhưng giữ focus và handler. Footer riêng dưới landing đã bỏ; footer trang nội dung vẫn dùng theo route.

Nhánh tổ chức đếm thời gian riêng sau khi cảnh ổn định: sạm đen khoảng giây 65–105, sụp nối tiếp bốn khu khoảng giây 110–143; tầng dưới theo sau tầng trên cùng khu. Lửa nguồn và mảnh vỡ dùng chung lịch từng khu; lửa thể tích giảm tại khu đang đổ. Đổi khỏi nhánh tổ chức đặt lại giai đoạn hư hại. Đây là hoạt cảnh dựng sẵn, không phải dự báo kết cấu hoặc thời gian an toàn thực tế. Snapshot bàn giao route đã có cơ chế nhưng tính liên tục mọi chuyển cảnh vẫn cần nghiệm thu trực quan.

Trang công khai giải thích năng lực chuẩn bị công trình, nhập IFC, kiểm tra revision, tạo scenario, publish release/QR và xem analytics. Khu quản lý thực tế yêu cầu `OrganizationUser` đúng `organizationId`; landing không cấp quyền và không thay thế kiểm tra backend.

### 5.3. Editor 3D và khu vận hành tổ chức

Khu `OrganizationUser` dùng Three.js cho preview/editor: chọn tầng, xoay/zoom, ẩn lớp, chọn đối tượng, đặt và chỉnh các thành phần kịch bản được runtime hỗ trợ. Editor có lưu nháp, undo/redo, validation, issue và tạo scenario version; nhiều scenario có thể dùng chung geometry. Fire, smoke, spread, wind, blocked route, extinguisher/towel/water, spawn, goal và thời lượng được lưu tách khỏi geometry. Wind theo khu vực/cửa là đề xuất mô hình game, không phải mô phỏng thông gió đã kiểm chứng.

Preview web chỉ minh họa timeline và hiệu ứng. Playtest đầy đủ dùng app Unity với quyền thử riêng, không phát hành bản nháp qua QR Trainee. Trợ lý AI của tổ chức có thể đề xuất hoặc tạo draft có nguồn, nhưng không tự sửa editor hay publish.

Khu billing/AI usage hiển thị dịch vụ theo từng Building, ngày hiệu lực/hết hạn, lượt AI được cấp/đã dùng/còn/vượt, đơn giá snapshot, chi phí tạm tính, kỳ đối soát và lịch sử. Phân biệt learner session với organization playtest; playtest không vào thống kê học. Điều khoản và sự đồng ý vượt hạn mức phải hiển thị trước khi phát sinh phí.

## 6. Learn và Góc học tập

### Learn công khai

- Tìm và đọc bài không cần tài khoản.
- Bài ngắn, dễ hiểu, có ảnh/diagram và nguồn.
- **Hỏi AI** yêu cầu đăng nhập; câu trả lời phải hiển thị nguồn.
- **Hỏi về bài này** mở chat mang theo ngữ cảnh bài đang đọc.
- **Lưu bài** đưa bài vào Góc học tập và yêu cầu đăng nhập.

Phân biệt rõ Learn web (kiến thức cộng đồng) với mode Learn trong Unity (làm quen không gian/runtime). FE đã có prototype Learn và chat mẫu; tích hợp AI kiến thức cộng đồng/backend thực còn pending implementation, nhưng thuộc mục tiêu bản cuối và không được coi là ngoài scope.

AI Trainee hoạt động trên web/mobile ngoài gameplay, dùng quota ngày do Admin cấu hình, chỉ truy cập kho kiến thức chung đã duyệt và dữ liệu cá nhân được phép. AI tổ chức dùng corpus riêng theo tenant và dữ liệu BIM được cấp quyền; hai nhóm không dùng chung phạm vi truy xuất.

### Góc học tập

Góc học tập là nơi riêng của Trainee sau đăng nhập, gồm hỏi AI, bài đã lưu, lịch sử hoạt động và kết quả tập huấn cá nhân. Trainee chỉ xem dữ liệu của mình; kết quả mô phỏng không phải chứng nhận hoặc kết luận an toàn công trình.

## 7. Cấu trúc source FE

FE đã chuyển từ Vite sang Next.js App Router, giữ feature-first. `app/` chỉ ghép route/layout/provider; logic nghiệp vụ và Three.js thuộc feature.

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
├─ app/          # Next.js App Router, layout, metadata và route composition
├─ services/     # HTTP client, interceptors, cross-feature adapters
├─ store/        # global state tối thiểu (auth/session/UI)
├─ utils/        # hàm thuần và helper nhỏ
└─ (không có App.tsx; root composition ở app/layout.tsx)
```

Quy ước ownership:

- `features/<name>/` giữ UI, service và type chỉ thuộc feature đó; ví dụ camera/scene landing không được import vào Unity Mobile.
- `components/` không biết API hoặc role; các component có dữ liệu nghiệp vụ nhận props/type rõ ràng từ feature.
- `services/` giữ cấu hình Axios/fetch, auth interceptor, error mapping và adapter API dùng chung; endpoint cụ thể của feature ở `features/<name>/services/`.
- `configs/` chỉ parse env và constant không nhạy cảm; không commit secret. `store/` chỉ chứa state thực sự dùng qua nhiều route, còn state cục bộ ở feature.
- `app/` và `layouts/` làm nhiệm vụ composition, loading/error boundary và accessibility; không chứa truy vấn dài hoặc logic Three.js.
- `assets/` chứa font Be Vietnam Pro, ảnh concept/fallback và style tokens. Asset 3D lớn phải lazy-load theo landing route.
- Không tạo lại `pages/`, `App.tsx` hoặc cấu hình Vite. Chỉ tạo thư mục có code sử dụng.

RAG được tổ chức trong `features/rag` và route `/demo/rag`; giữ `POST /chat` với `{question}` và `POST /documents` multipart `file`, answer/sources/loading/error. Env đổi thành `NEXT_PUBLIC_RAG_API_URL`, dev port vẫn 5173, pnpm 10.28.2.

## 8. Công cụ và skill thực thi

| Phần | Công cụ/skill | Ranh giới |
|---|---|---|
| Nhận diện và bố cục | `design-taste-frontend`, `web-design-guidelines`, `vercel-react-best-practices` | Xây token, hierarchy, accessibility, loading và responsive; không tự biến đề xuất thành backend contract |
| Cảnh 3D | Three.js, `3dviz-pro-max` | Custom building scene, camera path, fire source, smoke depth, occlusion, light response; dùng cho landing và editor/preview tổ chức, không thay gameplay Unity |
| Component hiệu ứng | ThreeUI tham khảo | Đã khảo sát component chạy iframe riêng; runtime FE hiện không phụ thuộc ThreeUI. Cảnh chính là Three.js custom |
| Cuộn và UI motion | `motion/react`, `ecc:motion-foundations`, `ecc:motion-advanced`, `scroll-craft` | Scroll progress, focus transition, reduced motion, cleanup và visibility; không dùng CSS layout animation hoặc scroll-jacking |
| Concept/ảnh fallback | `imagegen` | Tạo concept plate, texture và fallback still khi cần; copy chính luôn là HTML |
| Storyboard/video | `remotion-best-practices` | Dùng `useCurrentFrame()` để dựng teaser hoặc kiểm tra storyboard. Không bắt buộc runtime dependency và không thay thế scene Three.js tương tác |
| Handoff | `fire3d-fe-handoff` | Ghi checkpoint, bằng chứng và giới hạn; local notes không push |

FE hiện tại dùng Next.js App Router, TypeScript strict, Tailwind 4, Radix/shadcn và Three.js. Learn, đăng nhập/Góc học tập là dữ liệu demo với sessionStorage; chat định sẵn có nguồn, không đồng nghĩa AI/backend nghiệp vụ đã tích hợp. QR/APK chưa phát hành thì hiển thị chưa khả dụng. Xem [báo cáo triển khai và bài học](fire3d-web-implementation.md) để phân biệt thay đổi, kiểm chứng và hạn chế.

## 9. Tiêu chí nghiệm thu thiết kế

- Khách mở landing và Learn mà không bị buộc chọn vai trò hoặc đăng nhập.
- Menu và hai nhánh dùng nhãn nhu cầu, có keyboard focus và vùng bấm đủ lớn.
- Cuộn tiến/lùi giữ đúng camera, khói lửa bám kiến trúc, có che khuất và phản sáng; dừng cuộn không làm mất trạng thái.
- Chuyển cảnh sang trainee và organization giữ liên tục không gian; người dùng có thể quay lại và chọn nhánh khác.
- QR Building luôn resolve được landing; Trainee xem danh sách bài, chọn bài và chỉ mở phiên mới khi entitlement online còn hạn; không mở gameplay web.
- Editor organization cho phép chỉnh scenario, lưu draft, undo/redo, issue và version; preview web không được coi là gameplay Unity.
- Hết hạn service chặn publish/phiên mới nhưng không làm mất khả năng xem landing hoặc hoàn tất phiên đã bắt đầu.
- OrganizationUser bị backend giới hạn theo `organizationId`; nội dung marketing công khai không cấp quyền nghiệp vụ.
- Cảnh có fallback ảnh tĩnh, reduced motion và phương án mobile; không trình bày mô phỏng như hướng dẫn chữa cháy hoặc chứng nhận PCCC.
- Bản dựng phải kiểm tra ảnh chụp ở desktop/mobile, frame sáng nhất để đo tương phản, loading WebGL, tab ẩn, cuộn nhanh/ngược, focus keyboard và tài nguyên renderer.

## 10. Tài liệu liên quan

- [Yêu cầu dự án](fire_evacuation_requirements.md)
- [Yêu cầu và phase](fire_evacuation_requirements.md)
- [Workflow](fire-evacuation-training-workflows.md)
- [Kiến trúc công nghệ](fire-evacuation-training-technology.md)
- [Tổng quan dự án](fire_evacuation_project_overview.md)
