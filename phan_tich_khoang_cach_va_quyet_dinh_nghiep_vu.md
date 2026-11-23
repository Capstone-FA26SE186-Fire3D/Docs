# Phân tích khoảng cách và quyết định nghiệp vụ FET3D

> Hiện trạng implementation và giới hạn nghiệm thu: xem [đối chiếu source 21/10/2026](implementation-status.md). Các thiết kế và bằng chứng lịch sử bên dưới không thay thế kiểm chứng deployment hiện hành.

## Mục đích và trạng thái

Tài liệu đối chiếu bộ Docs hiện tại với các quyết định nghiệp vụ đã chốt về kịch bản, quyền chơi, đánh giá học viên, gói dịch vụ và AI/RAG. Các note đã được chuẩn hóa thành quyết định và bốn flow; các tài liệu Markdown liên quan đã được đồng bộ theo quyết định này.

Cập nhật ngày 03/10/2026. Requirements, workflow, ERD Markdown, SQL design v7 và file Word ý tưởng đã được đồng bộ ở mức đặc tả. Đây chưa là migration đã chạy, API/runtime đã triển khai hoặc nghiệm thu production. Các con số và chính sách còn mở được liệt kê riêng ở cuối.

## Tổng quan quyết định đã chốt

FET3D tiếp tục dùng luồng IFC → 3D → Unity Android → QR → Training → Result. Organization tự soạn hoặc dùng template tùy chọn, kết hợp các mục tiêu đào tạo và gửi PlatformAdmin duyệt trước phát hành. Trainee tự chọn đọc bài, luyện tập hoặc chơi bài đánh giá ngay; lưu từng kết quả và cho thi lại không giới hạn. Không cấp chứng nhận hoặc xây chương trình học theo module/sprint.

Building có quyền chơi public/private. Mọi người chơi đều đăng nhập bằng tài khoản Trainee; tòa private cần thêm mã tham gia. Gói mua theo từng tòa trong 6 hoặc 12 tháng, gồm phí game, số người giới hạn và quota AI. Quota AI các tòa cộng chung cho Organization; hết quota phải mua thêm trước khi tiếp tục dùng AI tính phí.

## Quyết định camera gameplay — 14/10/2026

Gameplay Unity dùng 3D góc nhìn thứ ba (third-person), thay định hướng camera trước đây. Camera bám theo nhân vật, orbit/zoom có giới hạn và xử lý va chạm/che khuất trong không gian BIM. Pipeline giữ cấu trúc, kích thước, semantic IDs và provenance; không sửa công trình để camera vừa. Chi tiết và nghiệm thu tại [technology §1.2](fire-evacuation-training-technology.md#12-gameplay-third-person-và-biểu-diễn-bim), yêu cầu FR-TRAINING-07 và [Unity #8](https://github.com/Capstone-FA26SE186-Fire3D/Unity/issues/8).

Phiếu `GFA26SE133_Phieu-dang-ky_v2.docx` quy định 3D/Unity nhưng không khóa góc nhìn; người dùng quyết định giữ nguyên phiếu. Landing web vẫn là POV góc nhìn thứ nhất, editor/preview phục vụ authoring. Quyết định này không tự thêm cameraMode vào contract API/bridge hoặc chứng minh runtime đã hoàn thành.

## Đối chiếu với Docs trước đợt đồng bộ

| Chủ đề | Docs hiện tại trước khi đồng bộ | Quyết định đã chốt |
| --- | --- | --- |
| Tạo kịch bản | Organization tự tạo/version scenario; AI có thể tạo bản nháp. | Tự soạn hoặc chọn template rồi tùy chỉnh. Template không bắt buộc; chỉ cấu hình các hành vi game hệ thống hỗ trợ. |
| Duyệt kịch bản | Organization thực hiện ConfirmForTraining; chưa quy định Admin duyệt nội dung trước publish. | PlatformAdmin duyệt mọi kịch bản trước phát hành; sửa nội dung phải gửi duyệt lại. Readiness kỹ thuật và duyệt nội dung là hai bước riêng. |
| Mục tiêu | Làm quen không gian và chọn route trong mô phỏng. | Có thể kết hợp sơ tán/thoát thân, nhận biết nguy cơ, dùng thiết bị chữa cháy trong mô phỏng và hỗ trợ người khác, trong phạm vi runtime được hỗ trợ. |
| Thiết bị và hướng dẫn | Có thư viện runtime và bài viết/tip/video Learn. | Admin quản lý danh mục thiết bị được hỗ trợ và nội dung hướng dẫn; Organization chọn, đặt và cấu hình. Hành vi thiết bị mới cần đội phát triển bổ sung. |
| Đánh giá | Có score, thời gian, exit sai, exposure, completion và debrief. | Admin cung cấp tiêu chí chuẩn; Organization chỉnh rồi gửi duyệt cùng bài. Hiển thị đạt/chưa đạt, lý do và lưu từng lần; thi lại không giới hạn. |
| Chứng nhận | Learn không có chứng chỉ; điểm mô phỏng không phải chứng nhận PCCC. | Không bổ sung cấp chứng nhận; cung cấp kết quả và lịch sử cá nhân. |
| Lộ trình học | Có Learn, Guided Drill và Assessment; chưa có curriculum. | Tự chọn học/luyện/chơi đánh giá; không bắt buộc học trước, không thêm module/sprint. |
| Người ngoài | Mọi Trainee xác thực có thể tham gia qua QR; chưa có quyền public/private hoặc mã tham gia. | Public: mọi Trainee đăng nhập được chơi. Private: cần đăng nhập và mã tham gia chung. Không thêm role Visitor hoặc chơi không định danh. |
| IFC QA | Upload, kiểm tra chất lượng, tạo geometry/package trước publish. | Giữ kiểm tra kỹ thuật trước phát hành; duyệt nội dung không thay thế IFC QA. |
| Tài chính | Gói Building/tháng; AI vượt quota đối soát cuối kỳ. | Gói Building 6/12 tháng gồm game, hạn mức người và quota AI; hết suất nâng cấp gói, hết quota AI mua thêm trước khi dùng tiếp. |
| Admin maintain | Quản lý nền tảng, Learn/kho tri thức, gói và quota. | Quản lý template tùy chọn, tiêu chí mẫu, danh mục thiết bị, Learn/blog; duyệt mọi kịch bản và bản sửa. |
| AI/RAG | Hỏi đáp có nguồn, BIM facts và tạo ScenarioDraft. | Hỗ trợ draft của Organization mình; Trainee hỏi về bài có quyền chơi và kết quả cá nhân ngoài lượt đánh giá. Upload không tự đưa toàn bộ kịch bản vào kho RAG. |

## Hai nhóm nội dung do Admin quản lý

**Thư viện hỗ trợ Organization** gồm template kịch bản tùy chọn, bộ tiêu chí chấm mẫu và danh mục thiết bị game đã được runtime hỗ trợ. PlatformAdmin duy trì các nội dung chuẩn; OrganizationUser dùng để soạn/cấu hình bài trong khu quản lý đã đăng nhập. Thư viện này tách khỏi **Learn công khai** trên web: bài viết, mẹo và video cho mọi người đọc không cần đăng nhập; lưu bài/hỏi AI cần đăng nhập. Learn giữ quy trình biên tập hiện tại và không có bước duyệt bài riêng. Mode Learn trong Unity là trải nghiệm làm quen không gian, không phải blog. IFC, mô hình và kịch bản riêng của Organization không tự được chia sẻ vào thư viện.

| Nhóm | Nội dung | Người sử dụng | Người quản lý |
| --- | --- | --- | --- |
| Thư viện hỗ trợ Organization | Template tùy chọn, tiêu chí chấm mẫu, thiết bị runtime | OrganizationUser trong khu quản lý đã đăng nhập | PlatformAdmin |
| Learn công khai | Bài viết, mẹo và video trên web | Mọi người đọc không cần đăng nhập; lưu bài/hỏi AI cần đăng nhập | PlatformAdmin biên tập |

Ba danh mục dành cho Organization không nằm trong Learn. Hai nhóm có quyền và workflow riêng; Organization tạo bài riêng vẫn giữ ownership theo tenant và gửi duyệt.

## Bốn flow nghiệp vụ

### Flow 1 - Organization dựng hạ tầng và tình huống theo phương án PC06

> Thiết kế đích theo góp ý của giảng viên hướng dẫn ngày 23/11/2026. Căn cứ: [pháp lý PCCC](phap-ly-pccc.md). Bản đang chạy còn theo luồng cũ, tóm tắt ở cuối mục này.

1. **Tạo Building.** Loại công trình chỉ có Chung cư hoặc Trường học (từ tiểu học trở lên; không nhận nhà trẻ, mẫu giáo, mầm non). Organization điền phiếu thông tin cơ sở theo Mẫu PC06 phần II (tên, địa chỉ, người đứng đầu, lực lượng tại chỗ, danh bạ khẩn cấp), số tầng, tổng diện tích sàn, và đính kèm bản PC06 đã ký nếu có. Hệ thống xác định nhóm nguy cơ theo Phụ lục II.
2. **Upload IFC.** Tệp phải đạt tiêu chí đầu vào (bảng dưới). Tệp sai bị chặn ngay trên máy người dùng kèm lý do cụ thể.
3. **Dựng hạ tầng.** Đặt bình chữa cháy, nút ấn và đầu báo cháy, tủ họng nước; xác nhận lối thoát nạn, điểm tập kết, nguồn nước (PC06 phần I, II.5, II.6).
4. **Chuyên viên PCCC thẩm định hạ tầng.** Đạt hoặc từ chối kèm lý do, trả về Organization. Đạt thì hạ tầng được **khóa** thành một phiên bản; muốn sửa phải mở phiên bản mới và thẩm định lại.
5. **Tạo tình huống** trên hạ tầng đã khóa. Một hạ tầng có nhiều tình huống. Mỗi tình huống chọn một đối tượng, khai giả định (giờ, vị trí cháy, nguyên nhân, số người có mặt, trong giờ hay ngoài giờ) và nhiệm vụ theo PC06 mục IV.1; nhiệm vụ trở thành mục tiêu trong game và tiêu chí chấm.
6. **Chuyên viên PCCC thẩm định tình huống.** Đạt hoặc từ chối kèm lý do, trả về Organization.
7. **Organization gửi PlatformAdmin báo giá**, thanh toán, phát hành Training và QR Building.
8. **Trainee luyện tập.** Hệ thống ghi nhật ký theo từng tình huống; Organization xem và xuất số liệu để tham khảo khi viết báo cáo Mẫu PC04.

Sửa tình huống đã thẩm định phải tạo phiên bản mới và thẩm định lại. Kết quả cũ giữ đúng phiên bản bài học viên đã chơi. Mỗi hạ tầng cần ít nhất một tình huống trong giờ và một tình huống ngoài giờ trước khi phát hành.

**Ai chịu trách nhiệm gì:** người đứng đầu cơ sở phê duyệt phương án PC06 (Điều 15 Nghị định 105/2025/NĐ-CP), việc này diễn ra ngoài hệ thống. Chuyên viên PCCC thẩm định nội dung huấn luyện trên FET3D. PlatformAdmin báo giá và phát hành; không thẩm định chuyên môn hạ tầng và tình huống.

**Tiêu chí tệp IFC hợp lệ** (hiển thị công khai dạng đạt/không đạt):

| Thời điểm | Tiêu chí | Khi không đạt |
| --- | --- | --- |
| Trước khi tải lên, kiểm tra trên máy | Đuôi `.ifc`, không rỗng, không vượt dung lượng tối đa | Chặn, báo lý do |
| Trước khi tải lên | Phần đầu tệp có `ISO-10303-21;` và `FILE_SCHEMA` là IFC2X3, IFC4 hoặc IFC4X3 | Chặn; nếu là Word, PDF, ZIP, ảnh thì nói rõ loại tệp và rằng đó không phải mô hình IFC |
| Trong lúc tải | Mất mạng, liên kết hết hạn, chọn nhiều tệp, trùng tệp đã tải | Báo lỗi riêng từng trường hợp, cho thử lại, không để lại bản IFC dở |
| Sau khi xử lý | Có tầng (`IfcBuildingStorey`), có phòng (`IfcSpace`), có cửa | `NeedsFix`, yêu cầu sửa IFC |
| Sau khi xử lý | Công trình nhiều tầng có cầu thang; đơn vị đo là mét | `NeedsFix` |
| Sau khi xử lý | Có ít nhất một lối ra; số tam giác trong ngân sách | Xác nhận cửa thoát có sẵn, hoặc sửa IFC |

**Bốn lớp chặn tệp IFC không đạt** (để tệp rác không tiêu tốn lượt xử lý của worker; lớp rẻ đứng trước):

| Lớp | Chạy ở đâu | Kiểm tra | Khi không đạt |
| --- | --- | --- | --- |
| 1. Phần đầu tệp | Trình duyệt | Đuôi `.ifc`, dung lượng, `ISO-10303-21;`, `FILE_SCHEMA` | Không cho tải lên |
| 2. Nội dung tệp | Trình duyệt, không dựng hình học | Có tầng, có phòng, có cửa, có tường hoặc sàn; nhiều tầng thì có cầu thang; đơn vị mét | Không cho tải lên, hiện danh sách mục không đạt. Tệp quá lớn so với bộ nhớ trình duyệt thì bỏ qua lớp này và để lớp 3, 4 kiểm tra |
| 3. Hạn mức và trùng lặp | Máy chủ | Số lượt xử lý mỗi ngày theo Organization, mỗi Organization một lượt xử lý cùng lúc, tệp trùng mã băm đã hỏng QA, quét nhanh nội dung để chặn lời gọi API trực tiếp | Từ chối, không tạo lượt xử lý |
| 4. Dừng sớm trong worker | Worker hình học | Lỗi chặn (không phải mô hình kiến trúc, không tầng, không phòng, không cửa) | Dừng trước bước dựng lưới, bản IFC về `NeedsFix` |

Web chỉ tự chạy xử lý khi lớp 1 và 2 đều đạt. Lớp 1, 2, 4 thuộc FE và worker trong repo Unity; lớp 3 thuộc BE.

**Đối tượng của tình huống** lấy theo nhóm nhiệm vụ của PC06 mục IV.1:

| Loại công trình | Đối tượng | Nhiệm vụ luyện |
| --- | --- | --- |
| Chung cư | Cư dân | Thoát nạn tới điểm tập kết |
| Chung cư | Bảo vệ, ban quản lý | Báo động, gọi 114, hướng dẫn thoát nạn, chữa cháy ban đầu |
| Trường học | Học sinh | Thoát nạn theo hướng dẫn |
| Trường học | Giáo viên | Hướng dẫn thoát nạn, kiểm đếm |
| Trường học | Bảo vệ, nhân viên | Báo động, gọi 114, chữa cháy ban đầu |

**Nhật ký luyện tập** cho mỗi tình huống: số lượt luyện, số người tham gia, tỷ lệ đạt, thời gian thoát nạn trung bình, ngày luyện gần nhất; cảnh báo tình huống chưa được luyện trong năm. Bản xuất luôn có dòng: "Số liệu luyện tập trên mô phỏng, mang tính hỗ trợ, không thay buổi thực tập phương án."

**Bản đang chạy (trước định hướng 23/11/2026):** Organization tạo Building với loại công trình là văn bản tự do; upload IFC chỉ kiểm tra đuôi tệp ở web và phần đầu `ISO-10303-21;` ở máy chủ, tải xong là tự chạy xử lý, không có hạn mức theo Organization và worker không dừng sớm khi gặp lỗi chặn; thiết bị PCCC và lối thoát nằm trong từng kịch bản, chưa có lớp hạ tầng khóa; kịch bản chưa có trường đối tượng; PlatformAdmin duyệt kịch bản cùng tiêu chí, chưa có vai trò Chuyên viên PCCC; chưa có bước báo giá riêng và chưa có nhật ký theo tình huống.

IFC QA (Quality Assurance) là kiểm tra dữ liệu/mô hình đủ điều kiện kỹ thuật để tạo game: đọc được file, đơn vị và tầng hợp lệ, cửa/cầu thang/lối thoát được mapping, kết nối sử dụng được. Bước này khác với việc Chuyên viên PCCC thẩm định hạ tầng và tình huống có phù hợp để tập huấn hay không.

### Flow 2 - Trainee học, chơi và được đánh giá

1. Đăng nhập Trainee và mở QR Building.
2. Tòa public cho tham gia trực tiếp; tòa private yêu cầu mã tham gia chung của Organization.
3. Chọn bài đã phát hành; tự chọn đọc Learn/blog, chơi luyện tập hoặc vào bài đánh giá ngay.
4. Khi bắt đầu game: kiểm tra quyền, gói dịch vụ và suất người.
5. Hệ thống ghi kết quả theo mode; Assessment được chấm bằng tiêu chí đã duyệt của phiên bản bài.
6. Hiển thị đạt/chưa đạt, lý do và nội dung nên luyện thêm; lưu lịch sử từng lần.
7. Được chơi/thi lại không giới hạn, không bắt buộc luyện lại trước khi thi.

Learn/blog là bài viết, mẹo và video trên web hiện có. Learn trong Unity là mode làm quen không gian; Guided Drill là game luyện tập có gợi ý; Assessment là game mô phỏng giảm/tắt gợi ý và có đánh giá. Đọc blog không tạo tiến độ khóa học hoặc điều kiện mở bài thi.

Admin đặt tiêu chí mẫu, loại bắt buộc/tùy chọn, trọng số và ngưỡng đạt. Organization điều chỉnh theo mục tiêu rồi gửi Admin duyệt cùng kịch bản. Chưa chốt các số cụ thể; không mặc định mức điểm hoặc thời gian chung cho mọi bài.

| Nhóm tiêu chí có thể dùng | Dữ liệu có thể đo | Cách xác định bắt buộc/tùy chọn |
| --- | --- | --- |
| Hoàn thành mục tiêu | Tới exit/điểm tập kết hoặc hoàn thành nhiệm vụ mô phỏng | Do tiêu chí của kịch bản đã duyệt quyết định |
| Quyết định an toàn | Exit sai, vào vùng bị chặn hoặc quyết định không phù hợp | Do tiêu chí của kịch bản đã duyệt quyết định |
| Phơi nhiễm nguy cơ | Mức/thời gian exposure trong hazard surrogate | Do tiêu chí của kịch bản đã duyệt quyết định |
| Thời gian | Thời lượng hoàn thành | Do tiêu chí của kịch bản đã duyệt quyết định |
| Thao tác thiết bị | Chọn/dùng vật phẩm theo nhiệm vụ được hỗ trợ | Áp dụng khi có mục tiêu tương ứng |

Đây là nhóm dữ liệu để xây rubric, chưa phải công thức chấm đã ban hành. Backend chấm theo rubric đã version hóa; debrief giải thích kết quả. Hoàn tất session không tự đồng nghĩa đạt. Lượt bị hủy, lỗi hoặc chưa đồng bộ phải phân biệt với kết quả đánh giá hợp lệ. Không cấp chứng nhận.

### Flow 3 - Gói dịch vụ, nâng cấp và AI

1. Organization chọn từng Building, gói và thời hạn 6 hoặc 12 tháng.
2. Nhận quotation gồm phí game, hạn mức người và quota AI; thanh toán thành công.
3. Cấp entitlement cho từng Building; quota AI cộng vào quỹ chung của Organization.
4. Cho publish và Trainee bắt đầu game trong quyền/hạn mức còn hợp lệ.
5. Hết suất người: nâng cấp gói có hạn mức người cao hơn.
6. Hết quota AI: mua thêm quota trước khi tiếp tục dùng AI tính phí.
7. Gia hạn hoặc hết hạn dịch vụ theo từng Building.

**Hạn mức người:** đếm tài khoản Trainee khác nhau đã bắt đầu game tại một Building trong kỳ dịch vụ, dựa trên mã tài khoản gắn với email đăng nhập. Chơi lại hoặc chơi nhiều kịch bản cùng tòa trong kỳ vẫn chỉ dùng một suất; chơi ở tòa khác được tính riêng cho tòa đó. Đăng nhập, đọc blog, xem danh sách bài hoặc chuẩn bị session chưa tiêu thụ suất. Organization playtest không tính suất học viên.

Khi hết suất, người đã được tính vẫn chơi lại nếu quyền và dịch vụ còn hợp lệ. Người mới bị chặn đến khi Organization thanh toán nâng cấp gói có hạn mức người cao hơn. Đây là hạn mức người khác nhau, không phải số lượt chơi. Kỳ gia hạn mới tính hạn mức theo kỳ mới.

**Quota AI:** quota từ các gói Building cộng chung cho Organization để hỏi AI/soạn kịch bản. Hết quỹ phải mua thêm trước khi phát sinh sử dụng AI tính phí tiếp. Phương án này thay cơ chế tự dùng vượt mức rồi đối soát phí cuối kỳ trong Docs cũ. Trainee giữ quota miễn phí riêng, không trừ vào quỹ Organization.

Giá, hạn mức người, lượng/đơn vị quota, điều kiện nâng cấp và hiệu lực quota mua thêm chưa chốt. Phí game gộp vào gói từng tòa; không bổ sung phí chứng nhận hoặc phí riêng từng kịch bản.

### Flow 4 - PlatformAdmin quản lý hai nhóm nội dung và duyệt kịch bản

1. Duy trì template kịch bản tùy chọn và bộ tiêu chí chấm mẫu.
2. Quản lý danh mục thiết bị hệ thống hỗ trợ.
3. Biên tập bài viết/mẹo/video Learn/blog và kiểm tra nguồn dùng cho RAG.
4. Nhận, duyệt hoặc từ chối kịch bản cùng tiêu chí do Organization gửi; ghi lý do.
5. Duyệt lại các phiên bản sửa trước khi phát hành.

Thư viện hỗ trợ Organization cung cấp mẫu/tiêu chí/thiết bị cho các tổ chức, tách khỏi Learn công khai. IFC, mô hình và kịch bản riêng không tự được chia sẻ vào thư viện. Organization có thể tự soạn thay vì dùng template; thiết bị tương tác phải thuộc capability runtime hỗ trợ. Admin cập nhật danh mục không tự tạo chức năng Unity mới.

Template/tiêu chí mẫu có phiên bản. Bài đã phát hành và kết quả cũ giữ nội dung đã pin; áp dụng thay đổi cho bài cần phiên bản mới và gửi duyệt lại.

## Nội dung template và tiêu chí mẫu

Template là khung gợi ý có phiên bản, có thể gồm:

1. Một hoặc nhiều mục tiêu và loại tình huống.
2. Điều kiện IFC cần cho nhiệm vụ, như exit/cửa/cầu thang/điểm tập kết đã mapping.
3. Điểm bắt đầu, mục tiêu, nguy cơ mô phỏng và thiết bị tương tác.
4. Cấu hình mode Learn, Guided Drill và Assessment.
5. Tiêu chí chấm mẫu: bắt buộc/tùy chọn, trọng số, ngưỡng đạt và điều kiện chưa đạt.
6. Debrief, bài Learn/blog liên quan và nguồn tham khảo.

Dùng template vẫn phải gửi Admin duyệt bài hoàn chỉnh cùng tiêu chí điều chỉnh. Template không đặt điều kiện học bắt buộc, giới hạn thi lại hoặc chính sách cấp chứng nhận.

## AI/RAG và dữ liệu kịch bản

RAG giúp AI tìm nội dung từ kho dữ liệu được phép trước khi trả lời. Upload kịch bản không tự biến toàn bộ file/cấu hình thành nguồn hỏi đáp.

| Người dùng | AI hỗ trợ | Phạm vi dữ liệu |
| --- | --- | --- |
| OrganizationUser | Hỗ trợ draft, soạn/chỉnh kịch bản, giải thích BIM facts, tìm nguồn/template liên quan | Nội dung được cấp quyền của Organization mình, gồm draft được đưa vào ngữ cảnh yêu cầu; nguồn chung hợp lệ |
| Trainee | Hỏi mục tiêu/hướng dẫn của bài và giải thích kết quả cá nhân, ngoài lượt đánh giá | Bài đã được duyệt và phát hành mà người dùng có quyền chơi; kiến thức chung và kết quả của chính mình |

Với Trainee, chỉ `name`, `objectives` và `instructions` của scenario đã duyệt/phát hành được index và truy xuất sau khi kiểm tra lại quyền hiện tại. Rubric, đáp án, tiêu chí chấm, draft, IFC/BIM riêng và nội dung Organization khác bị loại khỏi learner corpus. Organization có thể đưa draft của chính mình vào ngữ cảnh một request hỗ trợ soạn thảo; draft không trở thành thư viện chung hoặc nguồn Trainee đọc.

Hỏi AI về bài private phải tuân theo quyền tham gia. AI không tiết lộ scenario của Organization khác, kết quả người khác hoặc mô hình tòa nhà chỉ vì có QR. Bản sửa chưa duyệt/phát hành không thay nguồn Trainee đang hỏi về phiên bản đã phát hành.

Giữ ranh giới hiện tại: AI trả lời có nguồn hoặc tạo ScenarioDraft để Organization chỉnh; không tự sửa IFC/editor/scoring, tự publish, quyết định vị trí/số lượng lắp đặt cuối cùng hoặc kết luận Building đạt chuẩn PCCC. Duyệt bài và kết quả chỉ phục vụ phạm vi tập huấn FET3D.

## Những nội dung còn cần chốt

1. Giá gói 6/12 tháng, các mức người và lượng quota AI đi kèm.
2. Đơn vị quota, giá mua thêm, hiệu lực và cách xử lý quota còn dư khi gia hạn/hết hạn Building.
3. Giá nâng cấp giữa kỳ và thời hạn dịch vụ sau nâng cấp.
4. Tiêu chí cụ thể, trọng số, ngưỡng đạt và lỗi khiến chưa đạt; chưa tự đặt 70/80 điểm hay thời gian cụ thể.
5. Tình huống, thiết bị và bài mẫu ưu tiên triển khai trước trong phạm vi kết hợp mục tiêu đã chốt.

Đây là chi tiết còn mở; các quyết định về mô hình duyệt, học/chơi, hạn mức người và gói dịch vụ ở trên đã được chốt.

## Trạng thái đồng bộ tài liệu

- fire_evacuation_requirements.md: duyệt phiên bản, quyền public/private, mã tham gia, đạt/chưa đạt, thi lại không giới hạn, gói 6/12 tháng.
- fire-evacuation-training-workflows.md: bốn flow, nâng cấp hạn mức người, mua thêm quota AI và quyền truy cập.
- fire-evacuation-training-features.md: thư viện hỗ trợ Organization tách riêng template tùy chọn, Learn/blog, mode và kết quả cá nhân.
- database_overview.md, fire_evacuation_erd.md và fire_evacuation_schema.sql đã biểu diễn contract v7 cho review phiên bản, template/rubric, quyền tham gia, đếm người theo Building/kỳ và quota mua thêm; không thêm certificate, curriculum hoặc role Visitor.
- fire_evacuation_bim_rag_pccc.md: draft Organization, ngữ cảnh bài cho Trainee, nguồn/phiên bản hợp lệ và quota mới.

Các tài liệu Markdown trong danh sách đã đồng bộ phần đặc tả cùng README, tổng quan, UX, technology, báo cáo prototype, ERD Markdown, SQL design v7 và Word. Không suy từ cập nhật tài liệu rằng code/API, migration database, worker hoặc provider payment/AI đã triển khai. Thư mục `Mẫu report/` được giữ nguyên ngoài phạm vi này.
