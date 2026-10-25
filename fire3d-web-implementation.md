# Fire3D web — triển khai, thay đổi và bài học

> Hiện trạng implementation và giới hạn nghiệm thu: xem [đối chiếu source 21/10/2026](implementation-status.md). Các thiết kế và bằng chứng lịch sử bên dưới không thay thế kiểm chứng deployment hiện hành.

Cập nhật 2026-09-16. Đây là báo cáo prototype, không phải biên bản nghiệm thu toàn bộ sản phẩm. Thiết kế chuẩn ở [UX web](fire3d-web-ux-design.md). Tài liệu mục tiêu hiện mở rộng website từ landing/Learn/RAG mẫu thành khu editor Three.js, billing/AI usage và QR landing; các năng lực này chưa được coi là đã triển khai chỉ vì đã có trong thiết kế.

**Đối chiếu auth hiện hành — 21/10/2026:** theo [BE authentication](../BE/docs/authentication.md) và [API guide](../BE/docs/api-docs.md). Local registration: form → OTP → registrationToken → register trả account → login riêng. Google mới nhận proof `OnboardingRequired`; `POST /api/auth/google/onboarding/complete` tạo account/phiên và trả 201 Authenticated. Đã có `POST /api/me/link-google` (mật khẩu local hiện tại + Firebase ID token) và `POST /api/me/password` (đặt mật khẩu local đầu tiên cho Google-only). Mất response hoặc proof đã dùng phải xác minh Google/exchange lại; không tự phát lại JWT từ receipt. Firebase thật, database và client/deployment vẫn cần nghiệm thu riêng.

## Khác biệt với yêu cầu đồng bộ ngày 03/10/2026

Báo cáo này giữ nguyên bằng chứng prototype đã chạy. Thiết kế mới tách thư viện hỗ trợ Organization (template tùy chọn, tiêu chí mẫu, thiết bị) khỏi Learn/blog công khai; bổ sung Admin duyệt mọi phiên bản kịch bản, Building public/private dùng mã tham gia, đánh giá đạt/chưa đạt không prerequisite và thi lại không giới hạn. Gói từng Building 6/12 tháng gồm hạn mức người và quota AI; hết suất nâng cấp gói, hết quota mua thêm trả trước. Các năng lực này cần triển khai/tích hợp, chưa được chứng minh bởi FE demo.

Learn tiếp tục đọc công khai, auth cho bookmark/hỏi AI, Admin biên tập theo lifecycle hiện có; chưa tuyên bố CMS/embed/index production đã hoàn tất. SQL design v7, ERD và Word đã đồng bộ contract nghiệp vụ; code/API vẫn chưa là bằng chứng triển khai. [Requirements](fire_evacuation_requirements.md) là nguồn yêu cầu; [UX](fire3d-web-ux-design.md) mô tả trải nghiệm đích.

## So với thiết kế ban đầu (bằng chứng prototype 16/09/2026)

| Ban đầu | Hiện tại |
|---|---|
| FE Vite, RAG mẫu | Next App Router, feature-first; landing, Learn/detail, login, learning-hub, organizations, about, download, demo/rag |
| Hai nút lựa chọn | Chữ sơn trên tường, mũi tên, vùng bấm trong suốt; chọn chạy chuyển cảnh, Tiếp tục mới đổi route |
| Mặt cắt tách tầng | Giữ ba tầng nối cầu thang; ẩn vỏ ngoài để thấy hành lang; kéo/phím mũi tên/Home đổi góc |
| Khung viền vùng xoay và footer landing | Bỏ theo phản hồi; vẫn giữ focus để nhận phím, footer trang nội dung riêng không bị xóa |
| Nguồn cháy cục bộ | Cháy lan phòng, hai bên hành lang, sàn, trần, cầu thang, mặt ngoài và mái; thời gian môi trường độc lập scroll |
| NPC đơn giản | Nhân vật instanced có khớp gối/khuỷu, đường đi qua cầu thang; 3 phản ứng hoảng loạn/bén lửa và 3 phản ứng ho cúi người, không thương tích đồ họa |
| Không có sụp | Nhánh tổ chức có cháy đen rồi sụp nối tiếp từng khu, mảnh vỡ; reset khi rời nhánh |
| Phác thảo luồng tài khoản | Phiên mẫu sessionStorage: lưu/hỏi bài qua login rồi quay lại đúng ngữ cảnh; chat định sẵn có nguồn |

## Kiến trúc và giải pháp

- Một canvas/một renderer. Cảnh điện thoại lấy render target từ cùng renderer; volume khói/lửa render riêng rồi ghép với depth của cảnh để che khuất đúng kiến trúc.
- Geometry, materials, fire timeline, camera, NPC, compositor, collapse và lifecycle tách module. Các frame cập nhật refs/uniforms; React quản lý nội dung và trạng thái giao diện.
- Lửa thể tích và particle có mật độ, biến dạng, biên tan; màu ánh sáng không đóng sẵn trong texture. Khói giữ màu tối nhưng làm mềm biên để tránh đốm tròn/khối hộp.
- Sụp là hoạt cảnh dựng sẵn: bốn khu lệch 7 giây, tầng dưới lệch 3 giây; không phải solver kết cấu. Việc nhóm geometry theo khu giúp giữ phần chưa sụp đứng nguyên.
- Reduced motion bỏ WebGL; lỗi WebGL chuyển poster và nội dung đọc thông thường. Pause khi tab ẩn/ngoài viewport và dispose khi rời route.

## Console Organization và PlatformAdmin v2 (24/10/2026)

FE #123 (bộ component v2) và #124 (console v2) code theo Figma `bmEp9L3tQSjxTrrrU3WmCR`, trang 02b, 04b, 05b:

- Mọi form mở trong modal; bản ghi mở trong drawer; trường có danh sách cố định dùng combobox tìm được không dấu. Danh sách là DataTable: bấm hàng để mở, menu "···", dưới 640px chuyển sang dạng thẻ.
- Organization: chi tiết công trình có 5 tab (Hành trình, IFC, Kịch bản, Truy cập, Dịch vụ); một lối vào "Tải IFC"; bong bóng Trợ lý AI ở mọi trang; tìm nhanh ⌘K; tour spotlight thay cho checklist bắt đầu.
- PlatformAdmin: tổng quan dạng ô số và biểu đồ; duyệt kịch bản trong drawer; tài khoản, tổ chức, Learn, thư viện, AI, thương mại và hỗ trợ cùng một mẫu bảng + drawer.
- Chỉ hiện trường và hành động mà API BE có. Cố ý chưa làm vì BE chưa trả dữ liệu: chênh lệch theo kỳ, histogram thời lượng, tìm trong lịch sử AI, tỉnh/huyện ở hồ sơ tổ chức.

Bằng chứng: Playwright với mock route trên bản build production (995 test đạt; các lỗi còn lại đã có trước trên develop). Đây không phải nghiệm thu với BE, dữ liệu hoặc thiết bị thật.

## Kịch bản, phiên bản và trình soạn theo Figma v3 (24/10/2026)

Trang Figma `04b Organization v2` có thêm các khung từ "Kịch bản" trở vào (bản tối và sáng). FE code theo đó:

- Trang phiên bản: tiêu đề là tên kịch bản; thẻ "Hành trình" gồm 8 bước trên một hàng, thanh "Bước tiếp theo" và ba cổng độc lập (kết quả kỹ thuật, duyệt nội dung, release). Tab ngang: Tổng quan, Package build, Kết quả kỹ thuật, Gửi duyệt, Release, Playtest.
- Gửi duyệt có dòng thời gian ba mốc và nút gửi ở chân thẻ; chỉ hiện hai hash BE trả (nội dung, rubric). Release hiện dịch vụ của công trình và trạng thái Built/Published do máy chủ trả. Tạo phiên bản là modal.
- Tạo kịch bản chỉ nhập tên vì API tạo kịch bản chỉ nhận tên; revision IFC được chọn khi tạo bản nháp đầu tiên.
- Trình soạn 3D: một thanh trên với trạng thái lưu và các nút Kiểm tra, Lưu, Playtest, Phiên bản; công cụ và thanh "thêm đối tượng" nổi trên khung nhìn.
- Hiệu năng: năm panel tab và modal tạo phiên bản tải theo nhu cầu; first-load gzip trang phiên bản giảm từ 317 KB xuống 289 KB.

Bằng chứng: Playwright với mock route trên bản build production. Chưa nghiệm thu với BE thật cho các trạng thái QA/release.

## Chữ dễ hiểu trên mọi màn (25/10/2026)

Người dùng tổ chức và học viên không đọc được từ ngữ của dev, nên web đổi toàn bộ chữ hiển thị sang tiếng Việt thường dùng (chưa làm song ngữ VI/EN).

- Lỗi từ máy chủ luôn là câu tiếng Việt: FE dịch theo mã lỗi, rồi theo trạng thái HTTP; câu tiếng Anh của BE không bao giờ hiện ra. Mã lỗi và định danh nằm trong mục gập "Thông tin cho bộ phận hỗ trợ".
- Bộ từ thống nhất: bản IFC (revision), máy xử lý / lượt xử lý (worker / job), kiểm tra tự động (QA), gói, dựng gói, bản phát hành, chạy thử (playtest), quản trị FET3D (PlatformAdmin), tài khoản tổ chức (OrganizationUser), học viên (Trainee), đường dẫn rút gọn (slug), bài học (Learn). Tên thương hiệu là FET3D.
- Giữ nguyên từ chuyên ngành người dùng đã quen hoặc khó dịch gọn: IFC, BIM, QR, PayOS, token, rubric, GLB.
- Tab IFC: nút xác nhận là "Xác nhận mô hình dùng được cho huấn luyện".

## Lỗi, nguyên nhân và bài học

| Triệu chứng | Nguyên nhân/bằng chứng | Khắc phục và cách kiểm tra |
|---|---|---|
| Fallback thay cảnh 3D | Cần lỗi runtime để kết luận; từng có shader dùng từ GLSL dành riêng `patch` | Đổi tên biến, đưa shader compile error vào runtime failure; kiểm tra canvas thật, không chỉ chữ DOM/build |
| Màn hình điện thoại bị che | Screen nằm sau độ sâu bevel thân máy | Đặt screen ra trước mặt thân; đã có ảnh lịch sử xác nhận cảnh sống |
| Hai hàng NPC thẳng | Path dùng lane cố định | Path chéo khác pha, bo góc, khớp chân/tay; kiểm tra clearance và tiếp đất, chưa coi là navigation solver |
| Khói vuông/tròn | Volume thiếu fade biên, sprite dùng cùng đường tròn | Fade mọi biên mở, noise warp, khác kích thước/góc/vòng đời; nghiệm thu hình ảnh còn cần tiếp tục |
| Chờ lâu vẫn hở phòng | Mask đạt giới hạn; volume 3,4 m trong ô 6 m; thiếu phía đối diện/hành lang | Mở rộng late spread và bounds, map hệ tọa độ theo kích thước thực, thêm các vùng còn thiếu |
| Lửa tắt cùng lúc khi sụp | Tắt cả volume group khi bắt đầu collapse | Giảm opacity theo khu; nguồn lửa/mảnh vỡ cùng timeline |
| Cả tòa bị ép xuống | Transform/scale toàn tầng, batch toàn tầng | Chia geometry dài và batch theo khu; xoay/rơi từng phần; test vùng chưa đến lượt còn đứng |
| Các mảng cam treo trên đống đổ | Annotation không thuộc hình học sụp | Ẩn annotation khi bắt đầu sụp |
| Vỏ ngoài hiện lại che hành lang | Damage đặt visible=true sau reveal đã ẩn shell | Reveal sở hữu visibility; damage chỉ được ẩn thêm. Test trước/trong/sau collapse và trở lại POV |
| Kính dư ra mép sau | Ô cuối vượt z=-17 | Clamp mép kính vào bounds kiến trúc |
| Kéo xong phím không hoạt động | preventDefault ở pointerdown ngăn focus | focus({preventScroll:true}); giữ Arrow/Home; bỏ outline riêng theo yêu cầu |
| Hydration class mdl-js | Screenshot có class trên html nhưng source không khai báo | Chưa xác định extension cụ thể; cần browser sạch để đối chứng. Không thêm suppressHydrationWarning để che chưa rõ nguyên nhân |
| Build lỗi spawn EPERM | Subprocess bị môi trường sandbox chặn | Chạy lệnh đã được cấp quyền; không bỏ TypeScript check để làm xanh build |
| Dropdown trong modal/drawer v2 không bấm được | Dialog và Popover dùng hai bản `@radix-ui/react-dismissable-layer` (1.1.20 và 1.2.1), không chung danh sách layer; body bị `pointer-events: none` | Nâng `@radix-ui/react-dialog` 1.3.1 để chỉ còn một bản; kiểm bằng `pnpm why @radix-ui/react-dismissable-layer` |
| Popover của chip lọc bị cắt trong bảng | `contain: content` (gồm paint containment) trên khung DataTable | Đổi sang `contain: layout style` |
| Hàng bảng đang chọn có mảng tối ở ô đầu | `.ops-cell-primary` đặt `display: inline-block`; khi class này nằm trên `<td>`, ô không còn là table cell nên màu hàng và viền dừng giữa chừng, lộ nền bảng | Chỉ áp inline-block cho phần tử không phải `td`; kiểm bằng ảnh chụp hàng đang chọn ở cả hai theme. Bản sửa đầu (đổi màu hàng sang đục) chỉ che triệu chứng |

## Kiểm chứng và giới hạn

Đã có build/typecheck/lint, kiểm tra logic path/khớp/phản ứng/timeline/sụp/reset/dispose và test production khởi tạo WebGL rồi fallback khi mất context. Những lượt kiểm tra trước không thay thế kiểm chứng bản release hiện tại; báo cáo lệnh mới nhất được ghi trong PR và FE `docs/landing-completion-plan.md`.

Test tổng hợp chuyển cảnh từng vượt 90 giây sau khi qua bước bàn phím; không kết luận assertion sai chỉ từ timeout/session closed. Cần test hẹp hoặc thêm bằng chứng timing. Chưa nghiệm thu trực quan đủ toàn bộ 143 giây, bốn viewport, snapshot continuity, contrast ở frame sáng nhất, hiệu năng production và điện thoại thật. Poster có thể cũ hơn những lần sửa hiệu ứng cuối. Bỏ outline vùng xoay là quyết định UI theo yêu cầu, không phải tuyên bố đạt accessibility đầy đủ.

RAG giữ contract thử nghiệm; dữ liệu học tập/tài khoản/chat mẫu không đại diện backend nghiệp vụ. Không nhập IFC thật hoặc gameplay Unity trên web.

Danh sách tích hợp cần nghiệm thu sau prototype (không phải trạng thái thiếu source hiện tại): IFC pipeline IfcOpenShell/IfcConvert → Blender optimization → Unity build worker, editor/thư viện Organization, review phiên bản, PayOS/gói 6/12 tháng/hạn mức người, quyền private qua mã, QR Building và quota AI trả trước. Những phần này là thiết kế mục tiêu; báo cáo prototype chỉ là bằng chứng cho những gì đã chạy trong FE, không phải bằng chứng tích hợp end-to-end hay benchmark Android/Unity.
