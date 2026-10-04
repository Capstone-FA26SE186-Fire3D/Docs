# Fire3D web — triển khai, thay đổi và bài học

Cập nhật 2026-09-16. Đây là báo cáo prototype, không phải biên bản nghiệm thu toàn bộ sản phẩm. Thiết kế chuẩn ở [UX web](fire3d-web-ux-design.md). Tài liệu mục tiêu hiện mở rộng website từ landing/Learn/RAG mẫu thành khu editor Three.js, billing/AI usage và QR landing; các năng lực này chưa được coi là đã triển khai chỉ vì đã có trong thiết kế.

**Đồng bộ auth BE 03/10/2026:** theo [authentication](../BE/docs/authentication.md) và [API guide](../BE/docs/api-docs.md), source BE main `0683d90`. Local registration dùng form → OTP → registrationToken → register → login; register trả account, chưa cấp JWT. Google UID đã link đăng nhập được; onboarding/link mới còn thiếu API hoàn tất. Các quy tắc đầy đủ và sơ đồ nằm tại [workflows mục 2.1–2.4](fire-evacuation-training-workflows.md#21-đăng-ký-local-form--otp--account--login). Source không chứng minh client/provider/deployment đã nghiệm thu.

## Khác biệt với yêu cầu đồng bộ ngày 03/10/2026

Báo cáo này giữ nguyên bằng chứng prototype đã chạy. Thiết kế mới tách thư viện hỗ trợ Organization (template tùy chọn, tiêu chí mẫu, thiết bị) khỏi Learn/blog công khai; bổ sung Admin duyệt mọi phiên bản kịch bản, Building public/private dùng mã tham gia, đánh giá đạt/chưa đạt không prerequisite và thi lại không giới hạn. Gói từng Building 6/12 tháng gồm hạn mức người và quota AI; hết suất nâng cấp gói, hết quota mua thêm trả trước. Các năng lực này cần triển khai/tích hợp, chưa được chứng minh bởi FE demo.

Learn tiếp tục đọc công khai, auth cho bookmark/hỏi AI, Admin biên tập theo lifecycle hiện có; chưa tuyên bố CMS/embed/index production đã hoàn tất. SQL design v7, ERD và Word đã đồng bộ contract nghiệp vụ; code/API vẫn chưa là bằng chứng triển khai. [Requirements](fire_evacuation_requirements.md) là nguồn yêu cầu; [UX](fire3d-web-ux-design.md) mô tả trải nghiệm đích.

## So với thiết kế ban đầu

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

## Kiểm chứng và giới hạn

Đã có build/typecheck/lint, kiểm tra logic path/khớp/phản ứng/timeline/sụp/reset/dispose và test production khởi tạo WebGL rồi fallback khi mất context. Những lượt kiểm tra trước không thay thế kiểm chứng bản release hiện tại; báo cáo lệnh mới nhất được ghi trong PR và FE `docs/landing-completion-plan.md`.

Test tổng hợp chuyển cảnh từng vượt 90 giây sau khi qua bước bàn phím; không kết luận assertion sai chỉ từ timeout/session closed. Cần test hẹp hoặc thêm bằng chứng timing. Chưa nghiệm thu trực quan đủ toàn bộ 143 giây, bốn viewport, snapshot continuity, contrast ở frame sáng nhất, hiệu năng production và điện thoại thật. Poster có thể cũ hơn những lần sửa hiệu ứng cuối. Bỏ outline vùng xoay là quyết định UI theo yêu cầu, không phải tuyên bố đạt accessibility đầy đủ.

RAG giữ contract thử nghiệm; dữ liệu học tập/tài khoản/chat mẫu không đại diện backend nghiệp vụ. Không nhập IFC thật hoặc gameplay Unity trên web.

Phạm vi production còn cần nối contract với BE/AI: IFC pipeline IfcOpenShell/IfcConvert → Blender optimization → Unity build worker, editor/thư viện Organization, review phiên bản, PayOS/gói 6/12 tháng/hạn mức người, quyền private qua mã, QR Building và quota AI trả trước. Những phần này là thiết kế mục tiêu; báo cáo prototype chỉ là bằng chứng cho những gì đã chạy trong FE, không phải bằng chứng tích hợp end-to-end hay benchmark Android/Unity.
