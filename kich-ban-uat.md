# Kịch bản kiểm thử chấp nhận (UAT)

Kịch bản này để người dùng thật đi qua bốn vai trò của FET3D (Quản trị, Tổ chức, Chuyên viên PCCC, Học viên) theo đúng thứ tự một bài tập đi từ mô hình công trình tới kết quả của học viên, rồi thử các trường hợp phải bị từ chối quyền. Người kiểm thử chỉ cần làm theo từng dòng và điền các cột **Kết quả thực tế**, **Đạt / Không đạt**, **Ghi chú** và **Mã lỗi / issue**. Cuối tài liệu có phiếu góp ý cho từng vai trò, bảng ghi lỗi và biên bản nghiệm thu để ký.

> **Phạm vi.** Đây là nghiệm thu đồ án tốt nghiệp (capstone), không phải chứng nhận phòng cháy chữa cháy (PCCC). Từ BE#211, hạ tầng PCCC và tình huống của tổ chức do **Chuyên viên PCCC** thẩm định; tài khoản Chuyên viên do quản trị FET3D cấp, quản trị chỉ theo dõi. Thẩm định trên mô phỏng không thay việc người đứng đầu cơ sở phê duyệt phương án PC06, và không có chứng nhận của cơ quan PCCC. Tác dụng của khăn ướt, chăn ướt, che mũi miệng, chèn khe cửa và chỗ trú tạm trong game là mô phỏng để tập huấn ([quyết định ngày 16/11/2026](fire_evacuation_project_overview.md#quyết-định-của-trưởng-nhóm-ngày-16112026)).

> **Nguồn và mức xác nhận.** Các bước và câu chữ được đối chiếu với mã nguồn của [bản phát hành ngày 16/11/2026](release-manifest.md) (web FE `f1a7a22`, ứng dụng Mobile `533b6ee`, máy chủ BE `528f9c4`, runtime 2.5.0), rồi sửa theo Flow 1 PC06 (web FE `e965b41`, máy chủ BE `25df26d`). Câu chữ trong ngoặc kép là câu đọc được trong mã nguồn.
>
> **Lượt chạy thật ngày 26–27/11/2026** trên https://fet3d.io.vn do nhóm tự chạy (chưa có người dùng ngoài nhóm): luồng tạo và đăng nhập lần đầu của Chuyên viên PCCC (A12, E1) và luồng Tổ chức → Chuyên viên (B1–B11, E2–E6, D23, D24). Kết quả ghi ở cột Kết quả thực tế với nhãn "Chạy 27/11"; lỗi ghi ở mục 9. Phần C (điện thoại) và các ca D khác chưa chạy.

## 1. Thông tin lượt kiểm thử

| Mục | Điền |
| :--- | :--- |
| Ngày kiểm thử (dd/mm/yyyy) | 26/11/2026 (A12, E1) và 27/11/2026 (B, E) |
| Người kiểm thử và vai trò (Quản trị / Tổ chức / Chuyên viên PCCC / Học viên) | Thành viên nhóm, lần lượt đăng nhập Quản trị, Tổ chức, Chuyên viên PCCC |
| Người chứng kiến (thành viên nhóm) | |
| Môi trường web (địa chỉ) | https://fet3d.io.vn (FE `e965b41`, BE `25df26d`) |
| Phiên bản ứng dụng (mục Tôi → Phiên bản ứng dụng) | |
| Cách cài ứng dụng (Google Play kênh thử nghiệm / tệp cài do nhóm gửi) | |
| Điện thoại và phiên bản Android | |
| Phiên bản runtime đang bật (trang Phiên bản runtime) | Tình huống chọn 2.5.0; bản phát hành ghi ứng dụng tối thiểu 2.3.0 |

## 2. Chuẩn bị

| Cần có | Ghi chú |
| :--- | :--- |
| Tài khoản quản trị | Do nhóm cấp; không tự đăng ký được |
| Tài khoản tổ chức A | Dùng cho phần Tổ chức |
| Tài khoản Chuyên viên PCCC | Quản trị tạo ở bước A12 với một email người kiểm thử mở được; lần đăng nhập đầu cần mã gửi về email đó (E1) |
| Tài khoản tổ chức B | Chỉ dùng cho các ca từ chối quyền giữa hai tổ chức |
| Tài khoản học viên 1 và học viên 2 | Học viên 2 dùng cho ca Riêng tư và ca hết suất |
| Một tài khoản Google chưa dùng với FET3D | Cho bước đăng nhập Google (C2) |
| Một tệp IFC | Lượt 27/11 dùng `ISSUE_159_kleine_Wohnung_R22.ifc` (chung cư 4 tầng, có 6 bình chữa cháy và cầu thang). Ví dụ khác: tệp trường học ở [IFC mục 10.1](ifc_ingestion_visual_interaction.md#101-hai-công-trình-nghiệm-thu). Mỗi lần tải lên nhận đúng một tệp; mô hình tách theo bộ môn phải gộp khi xuất |
| Điện thoại Android đã cài ứng dụng FET3D | Chỉ có bản Android, không có bản iOS. Xem [hướng dẫn học viên, mục 2](huong-dan-hoc-vien.md#2-cài-ứng-dụng) |
| Công trình của tổ chức A còn dịch vụ | Cần để phát hành và để học viên bắt đầu lượt chơi |

Quy ước cột **Đạt / Không đạt**: ghi Đạt, Không đạt, hoặc Bỏ qua (ghi lý do ở cột Ghi chú). Khi Không đạt, ghi lỗi vào bảng ở mục 10 và chép số thứ tự lỗi (hoặc số issue nếu nhóm đã mở) vào cột **Mã lỗi / issue**.

## 3. Phần A — Quản trị

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A1 | Đăng nhập web bằng tài khoản quản trị | Web chuyển tới trang Tổng quan của khu Quản trị hệ thống; thanh bên có Theo dõi thẩm định, Tài khoản, Phiên bản runtime, Bài học, Thư viện mẫu, Dịch vụ & thanh toán | Chạy 27/11 22:15: vào "Tổng quan hệ thống"; thanh bên có Tổng quan, Theo dõi thẩm định, Hỗ trợ & nhật ký, Tài khoản, Tổ chức, Phiên bản runtime, Bài học, Thư viện mẫu, AI & nguồn tri thức, Dịch vụ & thanh toán | Đạt |  |  |
| A2 | Mở **Phiên bản runtime** | Thấy danh sách phiên bản, mới nhất ở trên; phiên bản 2.5.0 có trạng thái "Đang dùng" | Chạy 27/11: 8 phiên bản, mới nhất ở trên; 2.5.0, 2.4.0, 2.3.0 "Đang dùng", các bản cũ "Tắt" | Đạt |  |  |
| A3 | Bấm vào hàng 2.5.0 | Thấy danh sách năng lực của phiên bản, kèm sự kiện và thao tác; không có nút sửa nội dung | Chạy 27/11: hộp "Phiên bản 2.5.0" ghi 42 khả năng, mỗi khả năng có sự kiện và thao tác; ghi "Phiên bản đã đăng ký không sửa được"; không có ô nhập hay nút sửa | Đạt |  |  |
| A4 | Bấm **Đăng ký phiên bản**, chọn một tệp không phải tệp danh mục của runtime | Trang báo "Tệp chưa đúng" và không đăng ký được | | | | |
| A5 | Mở **Thư viện mẫu**, bấm **Thêm mục**, tạo một mục Tiêu chí chấm mẫu, **Tạo phiên bản**, lưu nháp rồi **Xuất bản** | Trang báo "Đã xuất bản phiên bản"; mục có dòng "Bản tổ chức đang thấy" | Chạy 27/11 22:20: tạo mục `RB-UAT-THU-27-11` (Tiêu chí chấm mẫu): "Đã tạo mục thư viện"; tạo phiên bản, lưu: "Đã tạo phiên bản nháp"; xuất bản: "Đã xuất bản phiên bản — v1 · từ giờ không sửa được nữa"; mục ghi "Bản tổ chức đang thấy: v1" | Đạt | Lưu nháp bắt buộc có điểm đạt và ít nhất một tiêu chí. Sau khi thử, mục để ở trạng thái Ngừng dùng |  |
| A6 | Mở lại phiên bản vừa xuất bản | Phiên bản ghi "Đã xuất bản (không sửa được)"; chỉ có thể tạo Phiên bản mới | Chạy 27/11: phiên bản ghi "Đã xuất bản (không sửa được)"; không còn ô nào sửa được; chỉ có nút "Tạo phiên bản mới từ v1" | Đạt |  |  |
| A7 | Bấm **Ngừng dùng** cho mục đó, rồi **Dùng lại** | Trang báo "Đã ngừng dùng mục" rồi "Đã dùng lại mục" | Chạy 27/11: "Đã ngừng dùng mục" rồi "Đã dùng lại mục"; trạng thái đổi Ngừng dùng ↔ Đang dùng | Đạt |  |  |
| A8 | Mở **Bài học**, bấm **Bài mới**, tạo một bài viết với Xuất bản ngay đang tắt | Trang báo "Đã tạo bản nháp"; bài chưa hiện ở trang Bài học công khai | Chạy 27/11 22:18: bấm **Tạo bài**, điền tiêu đề, tóm tắt, đoạn mở đầu, bấm "Tạo và mở trình soạn": trình soạn mở với "V1 (BẢN NHÁP)", "Chưa xuất bản"; trang công khai của bài chưa có nội dung bài | Đạt | Nút thật tên "Tạo bài", không có công tắc "Xuất bản ngay": bài luôn tạo ở dạng nháp. Không thấy câu "Đã tạo bản nháp" |  |
| A9 | Xuất bản bài nháp đó | Bài hiện ở trang Bài học công khai khi chưa đăng nhập | Chạy 27/11: bấm "Xuất bản v1" và xác nhận: "Đã xuất bản — Phiên bản 1 · bài đang công khai"; mở trang bài khi không đăng nhập thấy tiêu đề bài | Đạt | Kiểm trang riêng của bài; danh sách `/learn` tải lần đầu chưa thấy tiêu đề |  |
| A10 | **Ẩn bài**, kiểm tra trang công khai, rồi **Hiện lại** | Sau khi ẩn, bài không còn ở trang công khai; sau Hiện lại, bài có lại | Chạy 27/11: "Đã ẩn bài — Bài hiện đã ẩn", trang công khai không còn bài; "Đã hiện bài — Bài hiện đang công khai", trang công khai có lại bài | Đạt |  |  |
| A11 | **Xóa bài** rồi **Khôi phục** | Sau khôi phục, bài ở trạng thái Đã ẩn, không tự công khai | Chạy 27/11: "Đã xóa bài — Bài hiện đã xóa"; khôi phục: "Đã khôi phục bài — Bài hiện đã ẩn", trang công khai không có bài | Đạt | Sau khi thử, bài thử được xóa lại (trạng thái Đã xóa) |  |
| A12 | Mở **Tài khoản**, bấm **Tạo tài khoản**, chọn vai trò Chuyên viên PCCC, nhập email người kiểm thử mở được, họ tên và mật khẩu ban đầu | Tài khoản được tạo; danh sách ghi "Chưa xác minh email". Nếu email gõ sai, mở tài khoản đó và bấm **Sửa email** | Chạy 27/11 (26/11): lần đầu máy chủ báo lỗi 500 (BE#237); sau khi BE sửa, tạo được lúc 15:25Z. Chạy lại 27/11 22:35 với email cố ý sai `chuyenvien.uat.sai@example.com`: danh sách ghi "Chưa xác minh email"; bấm **Sửa email**, nhập `chuyenvien.uat.dung@example.com`: "Đã sửa email — Lần đăng nhập kế tiếp, mã xác minh được gửi về …"; hộp sửa nhắc "Chỉ sửa được khi tài khoản chưa xác minh email" | Đạt | Form báo rõ lỗi máy chủ kèm mã theo dõi (FE #275) | BE#237 |
| A13 | Mở **Theo dõi thẩm định** | Thấy các mục tổ chức đã gửi và kết quả của Chuyên viên PCCC; quản trị không có nút Đạt / Chưa đạt | Chạy 27/11: ba ô Chờ thẩm định 0 · Đạt thẩm định 23 · Chưa đạt 2; lọc Tất cả thấy v1 (Chưa đạt) và v2 (Đạt) của Chung cư UAT 27/11; không có nút Đạt / Chưa đạt | Đạt | Danh sách chỉ thấy tình huống; chưa thấy dòng Hạ tầng PCCC phiên bản 1 trong các hàng đầu |  |
| A14 | (Sau bước B18) Mở **Dịch vụ & thanh toán** → thẻ **Báo giá**, bấm vào báo giá nháp của tổ chức A, bấm **Phát hành báo giá** | Trang báo "Đã phát hành báo giá"; giá của từng dòng công trình là giá quản trị đặt ở gói dịch vụ và giảm giá, không phải con số cố định trong tài liệu | Chạy 27/11 22:12: mở báo giá nháp `FET-d2e03b4f…`, nhập ngày bắt đầu 12:00 28/11/2026, thuế 0, hạn chấp nhận 12:00 28/11/2026, điều khoản; trang báo "Đã phát hành báo giá — Tổng thanh toán 1.200 ₫ do hệ thống tính."; dòng công trình 100 ₫/tháng × 12, kỳ 28/11/2026 – 28/11/2027 | Đạt | Giá lấy từ gói "Gói thử nghiệm thu BE#138 (QA)" |  |
| A15 | Mở lại báo giá đó và tìm nút hoàn tiền | Không có thao tác hoàn tiền ở bất kỳ đâu; báo giá chưa thanh toán chỉ có **Hủy báo giá** | Chạy 27/11: báo giá đã phát hành chỉ có nút **Hủy báo giá**; không có thao tác hoàn tiền; trang ghi "Quản trị FET3D không chấp nhận hay thanh toán thay tổ chức." | Đạt |  |  |

## 4. Phần B — Tổ chức

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| B1 | Đăng nhập web bằng tài khoản tổ chức A | Web chuyển tới trang **Công trình** của Không gian tổ chức | Chạy 27/11: vào trang Công trình | Đạt | | |
| B2 | Bấm **Thêm công trình**, nhập Tên công trình, Loại công trình, Số tầng, Tỉnh / Thành phố, Quận / Huyện, Địa chỉ; lưu rồi mở công trình | Trang công trình có năm thẻ: Hành trình, IFC, Kịch bản, Truy cập, Dịch vụ | Chạy 27/11: tạo "Chung cư UAT 27/11" (chung cư, 4 tầng) lúc 08:39, mở thẳng thẻ IFC | Đạt | Chọn Chung cư vẫn hiện gợi ý của Trường học | Lỗi 5 |
| B3 | Ở thẻ **IFC**, bấm **Tải IFC** và chọn tệp IFC | Mục Tiến trình cập nhật tới khi xử lý xong; mục Xem trước 3D hiện mô hình; mục Kỹ thuật có danh sách vấn đề (nếu có) | Chạy 27/11: tệp 9,7 MB qua kiểm tra trên máy (4 tầng, 28 phòng, 47 cửa, có cầu thang); máy xử lý nhận sau khoảng 3 phút, dựng xong 08:44 với 0 lỗi, 3 cảnh báo | Đạt | Thanh tiến trình hiện "bước Bước khác" | Lỗi 4 |
| B4 | Mở mục **Thiết bị**. Nếu có khung "Chọn cửa thoát ra ngoài", chọn một cửa làm cửa thoát; xác nhận hoặc loại các thiết bị được đề xuất rồi lưu | Trang báo "Đã lưu quyết định thiết bị" | Chạy 27/11: chọn một cửa tầng trệt làm cửa thoát, xác nhận 6 bình chữa cháy; trang báo đã lưu và "Bản IFC đã sẵn sàng soạn kịch bản." | Đạt | | |
| B4a | Mở mục **Hạ tầng PCCC**, bấm **Lập hạ tầng PCCC**. Kiểm tra lối thoát nạn, điểm tập kết và thiết bị cố định; bấm **Kiểm tra** rồi **Lưu** | Phiên bản 1 lấy sẵn các thiết bị đã xác nhận ở B4; máy chủ báo nội dung hợp lệ; danh sách ghi số lối thoát, điểm tập kết và thiết bị | Chạy 27/11: 6 bình được lấy sang nhưng thiếu loại chất chữa cháy và thời gian phun (12 lỗi "Cần điền ô này."); cửa thoát vào thành thiết bị nên vẫn báo "Cần ít nhất một lối thoát nạn.". Điền tay, thêm Lối ra ngoài gắn vào cửa đó và một Điểm tập kết thì máy chủ báo hợp lệ: "1 lối thoát · 1 điểm tập kết · 7 thiết bị cố định" | Không đạt | Đi tiếp được bằng cách điền tay | Lỗi 1, 2, 3, 4 |
| B4b | Ở danh sách Hạ tầng PCCC, bấm **Gửi thẩm định** và xác nhận | Phiên bản chuyển sang "Chờ thẩm định" và không sửa được nữa | Chạy 27/11: gửi 08:49, "Chờ thẩm định", ghi người gửi và giờ gửi | Đạt | | |
| B5 | (Sau bước E3) Ở thẻ **Kịch bản**, bấm **Tạo kịch bản**, đặt tên, bấm **Tạo bản nháp**. Áp một mẫu ở thẻ **Thư viện** (hoặc tự điền), đặt điểm xuất phát, nguồn lửa, chọn phiên bản ứng dụng; bấm **Lưu** rồi **Kiểm tra** | Bản nháp tự dùng Hạ tầng PCCC đã khoá (lối thoát, điểm tập kết, thiết bị không sửa được ở đây); máy chủ báo nội dung hợp lệ; trình soạn không có mục cấu hình gió | Chạy 27/11: bản nháp ghi "Dùng Hạ tầng PCCC phiên bản 1 (đã khoá)" với 9 đối tượng; áp mẫu PC06 "Chung cư – trong giờ: cháy bếp căn hộ" điền 9 nhóm; thêm phiên bản 2.5.0, điểm xuất phát và nguồn cháy tầng 2; máy chủ hợp lệ 08:54 | Đạt | Mẫu đổi tên bản nháp thành "…tầng 8" trong tòa 4 tầng; còn chữ kỹ thuật | Lỗi 6, 7 |
| B6 | Trong trình soạn bấm **Phiên bản**, rồi **Tạo phiên bản mới**, chọn bản nháp vừa lưu và bấm **Tạo phiên bản** | Trang báo "Đã tạo phiên bản mới"; trang phiên bản có các thẻ Tổng quan, Dựng gói, Kiểm tra, Gửi thẩm định, Phát hành, Chạy thử | Chạy 27/11: "Đã tạo phiên bản mới" 08:56, đủ sáu thẻ | Đạt | Hộp tạo phiên bản hiện mã lần lưu dạng `"20805"` | Lỗi 8 |
| B7 | Ở thẻ **Dựng gói**, bấm **Dựng gói** và chờ xong; sang thẻ **Kiểm tra**, khi kết quả đạt thì bấm **Chốt gói phát hành** | Dựng gói xong (có thể mất nhiều phút); trang báo "Đã chốt gói phát hành" | Chạy 27/11: v1 dựng khoảng 7 phút, kiểm tra đạt 09:03 với 0 lỗi; v2 máy dựng nhận lại lần 2, xong 09:23, kiểm tra đạt; cả hai lần trang báo "Đã chốt gói" | Đạt | Trạng thái đầu trang chỉ đổi sau khi tải lại; lần nhận lại không có lý do | Lỗi 9 |
| B8 | Quay lại thẻ **IFC** → mục **Tiến trình**, ở khung "Xác nhận mô hình dùng được cho huấn luyện" chọn phiên bản kịch bản vừa tạo rồi bấm **Xác nhận dùng cho huấn luyện** | Trang báo "Đã xác nhận mô hình dùng được cho huấn luyện" | Chạy 27/11: khung ghi "Đã xác nhận cho huấn luyện · Lúc 09:23 27/11/26"; bản IFC mang nhãn "Đã xác nhận dùng cho huấn luyện" | Đạt | Ghi lại từ trạng thái trang tối 27/11, không chép câu thông báo lúc bấm | |
| B9 | Ở trang phiên bản, mở thẻ **Chạy thử**, bấm **Bắt đầu chạy thử** rồi **Tạo mã QR mở trên điện thoại**. Trên điện thoại đăng nhập bằng tài khoản tổ chức A, bấm **Quét mã bàn giao**, quét mã, **Tải và kiểm tra gói**, **Bắt đầu chạy thử**, chơi hết | Web báo "Điện thoại đã nhận mã và đang giữ lượt chạy thử này."; màn chơi mở trên điện thoại; xong, ứng dụng báo "Đã gửi kết quả chạy thử. Xem kết quả trên web." | | | | |
| B10 | Ở thẻ **Gửi thẩm định**, bấm **Gửi thẩm định** và xác nhận | Phiên bản chuyển sang "Đã gửi, đang chờ Chuyên viên PCCC"; trang ghi phiên bản đã được gửi nên không gửi lại | Chạy 27/11: v1 gửi 09:06, v2 gửi 09:11 (trước khi gói v2 dựng xong) | Đạt | Thông báo ghi "đã gửi cho quản trị FET3D"; tab hiện mã băm dài | Lỗi 10, 11 |
| B10a | (Sau bước E5) Mở thẻ **Gửi thẩm định** của phiên bản bị Chưa đạt; sửa bản nháp theo lý do, tạo phiên bản mới, dựng gói và gửi thẩm định lại | Thấy "Chưa đạt thẩm định", giờ quyết định và đúng lý do Chuyên viên viết; phiên bản cũ không gửi lại được | Chạy 27/11: v1 hiện "Chưa đạt thẩm định" 09:08 kèm lý do; sửa tên, vị trí cháy, hướng dẫn sang tầng 2 → v2 | Đạt | Bảng quyết định còn chữ "Rejected" | Lỗi 10 |
| B11 | (Sau bước E6) Ở thẻ **Phát hành**, bấm **Tạo bản phát hành**, rồi bấm **Phát hành** | Trang báo "Đã tạo bản phát hành"; sau khi bấm Phát hành, trạng thái là "Đã phát hành". Công trình chưa có dịch vụ trả phí thì Phát hành bị chặn kèm lý do | Chạy 27/11: tạo bản phát hành 09:24 ("Đã tạo, chưa phát hành", Android). Phát hành bị chặn đúng: "Công trình chưa có dịch vụ trả phí còn hiệu lực. Gói dùng thử không đủ để phát hành." | Bỏ qua | Chưa mua dịch vụ cho công trình thử (thanh toán thật); phần chặn chạy đúng | Lỗi 12 |
| B12 | Ở thẻ **Truy cập** → mục **Mã QR**, bấm **Tạo mã QR** và xác nhận | Trang báo "Đã tạo mã QR"; có liên kết dạng `https://fet3d.io.vn/qr/…`, nút **Sao chép liên kết** và **In mã QR**; trang nhắc "Mã này chỉ hiển thị một lần" | Chạy 27/11 22:07: "Đã tạo mã QR"; có liên kết `https://fet3d.io.vn/qr/…`, nút Sao chép liên kết, In mã QR, Ẩn mã; có khung "Mã này chỉ hiển thị một lần" | Đạt | Nhãn "UAT 27/11" | |
| B13 | Khi công trình đã có mã QR đang hoạt động, xem lại mục Mã QR | Không còn nút Tạo mã QR; chỉ có **Tạo mã mới** và **Thu hồi mã** (mỗi công trình chỉ có một mã đang hoạt động) | Chạy 27/11: không còn nút Tạo mã QR; chỉ có **Tạo mã mới** và **Thu hồi mã**; lịch sử ghi 1 mã "Đang hoạt động" | Đạt | | |
| B14 | Ở thẻ **Truy cập** → mục **Quyền tham gia**, chọn **Riêng tư (cần mã tham gia)**, bấm **Áp dụng chế độ**, rồi **Tạo mã tham gia** và **Sao chép** | Có mã tham gia; trang báo "Đã sao chép mã tham gia" | | | | |
| B15 | (Sau phần C) Mở **Báo cáo**, chọn khoảng thời gian có lượt chơi | Số lượt chơi và số học viên khớp với các lượt đã chơi ở phần C; lượt chạy thử ở B9 không được tính | | | | |
| B16 | Ở báo cáo Huấn luyện, bấm **Xuất CSV** | Tải được tệp `.csv`; tệp chỉ có dòng tổng hợp, không có tên hay email học viên | | | | |
| B17 | Ở mục Mã QR, bấm **Tạo mã mới**, đọc hộp thoại "Tạo lại mã QR?" rồi bấm **Tạo mã mới** | Trang báo "Đã tạo mã QR mới" và "QR cũ đã ngừng hoạt động." (kiểm mã cũ ở ca D8) | Chạy 27/11 22:09: hộp thoại "Tạo lại mã QR?" nói mã hiện tại ngừng ngay và mã tham gia giữ nguyên; sau khi bấm: "Đã tạo mã QR mới" — "QR cũ đã ngừng hoạt động."; lịch sử có 2 mã | Đạt | Chạy trước phần C vì chưa có điện thoại; mã cũ giữ lại cho D8 | |
| B18 | Mở **Dịch vụ & thanh toán**, bấm **Mua gói công trình**, chọn công trình và gói | Trang báo "Đã tạo báo giá nháp"; báo giá chờ quản trị phát hành ("Đang chờ quản trị FET3D phát hành") | Chạy 27/11 22:08: chọn "Chung cư UAT 27/11" (Mua mới) và "Gói thử nghiệm thu BE#138 (QA)" 12 tháng; trang báo "Đã tạo báo giá nháp"; báo giá `FET-d2e03b4f…` ghi "Bản nháp · chờ phát hành", tạm tính 1.200 ₫, "Đang chờ quản trị FET3D phát hành", chỉ có nút Hủy báo giá | Đạt | Danh sách báo giá cho thấy đã có ba báo giá "Đã chấp nhận" từ 10–18/11 (2.000–8.200 ₫), tức luồng thanh toán đã từng chạy thật | |
| B19 | (Sau bước A14) Mở báo giá đã phát hành, xem giá từng dòng, rồi bấm **Hủy báo giá**, nhập lý do và xác nhận | Giá khớp với giá quản trị đặt; trang báo "Đã hủy báo giá". **Không thanh toán thật** trong buổi UAT trừ khi trưởng nhóm đồng ý: sau khi thanh toán không hoàn tiền | | | | |
| B20 | Mở thẻ **Nhắc gia hạn** trong Dịch vụ & thanh toán | Trang ghi hệ thống nhắc gia hạn trước 5 ngày khi kỳ dịch vụ sắp hết. Nếu có công trình còn dưới 5 ngày dịch vụ: có dòng nhắc trên web, thư nhắc và thông báo trên điện thoại đã đăng nhập tài khoản tổ chức (đã cho phép thông báo). Không có công trình nào sắp hết hạn thì ghi Bỏ qua | Chạy 27/11: thẻ ghi "Nhắc gia hạn trước 5 ngày khi kỳ dịch vụ sắp hết; không còn nhắc cho kỳ đã gia hạn." Không có công trình nào còn dưới 5 ngày (kỳ gần nhất hết 18/5/2027) | Bỏ qua | Phần nhắc thật chưa kiểm được. Thẻ này lại liệt kê ba thông báo kết quả thẩm định của công trình | Lỗi 15 |

## 5. Phần E — Chuyên viên PCCC

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| E1 | (Sau bước A12) Đăng nhập web bằng email và mật khẩu ban đầu của Chuyên viên | Web không vào thẳng mà hiện "Xác minh email"; nhập mã 6 chữ số gửi về email thì phải "Đổi mật khẩu ban đầu"; đổi xong đăng nhập lại bằng mật khẩu mới và vào **Hàng chờ thẩm định** | Chạy 27/11 (26/11): nhập mã, đổi mật khẩu, đăng nhập lại 15:27Z; tài khoản có email đã xác minh, hàng chờ mở được | Đạt | Sửa email khi gõ sai đã thử ở A12 (27/11); chưa thử xác minh bằng Google | |
| E2 | (Sau bước B4b) Mở **Hàng chờ thẩm định** | Thấy mục Hạ tầng PCCC tổ chức vừa gửi, có tổ chức · công trình và giờ gửi | Chạy 27/11: thấy "Hạ tầng PCCC · phiên bản 1" của Chung cư UAT 27/11, gửi 08:49 | Đạt | | |
| E3 | Mở mục đó, xem mô hình 3D và danh sách đối tượng, bấm **Đạt thẩm định** và xác nhận | Trang báo "Đã ghi: Đạt thẩm định"; hộp xác nhận nhắc hạ tầng sẽ được khoá; mục rời hàng chờ | Chạy 27/11: "Đã ghi: Đạt thẩm định", hàng chờ trống | Đạt | Cột Tên hiện "IfcBuildingElementProxy" thay cho tên thiết bị | Lỗi 4 |
| E4 | (Sau bước B10) Mở tình huống chờ thẩm định | Thấy mục tiêu học tập, hướng dẫn, tiêu chí chấm (điểm đạt, mức quan trọng, bắt buộc), đối tượng trên mô hình; tất cả chỉ đọc | Chạy 27/11: đủ các phần, 11 đối tượng, 7 tiêu chí, điểm đạt 0.7 | Đạt | Phần Nội dung kịch bản hiện tên trường kỹ thuật | Lỗi 7 |
| E5 | Bấm **Chưa đạt**, nhập lý do cần sửa, bấm **Ghi: Chưa đạt** | Trang báo "Đã ghi: Chưa đạt"; tổ chức đọc được lý do (B10a) | Chạy 27/11: lý do "hướng dẫn ghi tầng 8, tòa 4 tầng"; "Đã ghi: Chưa đạt" | Đạt | | |
| E6 | (Sau bước B10a) Mở phiên bản mới và bấm **Đạt thẩm định** | Nội dung đã sửa theo lý do; trang báo "Đã ghi: Đạt thẩm định" | Chạy 27/11: v2 hướng dẫn ghi tầng 2; "Đã ghi: Đạt thẩm định" | Đạt | | |

## 6. Phần C — Học viên

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| C1 | Mở ứng dụng, bấm **Chưa có tài khoản? Đăng ký**, làm theo các bước với email thật | Nhận được email có mã 6 chữ số; làm xong các bước, tài khoản được tạo | | | | |
| C2 | (Chỉ với bản cài từ Google Play) Đăng xuất, bấm **Tiếp tục với Google**, chọn tài khoản Google chưa dùng với FET3D và làm nốt các bước tạo tài khoản | Vào được mục **Nhà** bằng tài khoản Google; với bản cài từ tệp do nhóm gửi thì ghi Bỏ qua | | | | |
| C3 | Đăng nhập bằng email và mật khẩu ở C1 (bấm **Vào game**) | Vào mục **Nhà**; thanh dưới có Nhà, Bài học, Kết quả, Tôi và nút QUÉT | | | | |
| C4 | Bấm **QUÉT**, quét mã QR của công trình (đang Công khai) | Mở trang tòa nhà có nhãn Công khai và danh sách bài đã phát hành | | | | |
| C5 | Chọn bài, chọn **Học**, bấm **Chuẩn bị phiên** rồi **Tải gói nhiệm vụ** | Thanh tải chạy tới "Gói sẵn sàng" | | | | |
| C6 | Bấm **Bắt đầu phiên**; ở thẻ giới thiệu bấm **Nữ** rồi bắt đầu chơi | Màn chơi 3D mở; nhân vật đổi sang nữ | | | | |
| C7 | Tới một cánh cửa, bấm **Mở cửa** rồi chạy thẳng qua | Cửa mở, nhân vật đi qua khung cửa không bị kẹt; tay vẫn mở cửa được sau khi đổi Nam/Nữ | | | | |
| C8 | Khi khói xuống thấp, bấm **Cúi thấp**, bấm lần nữa để **Bò** | Nhân vật cúi rồi bò; game có lời nhắc "Khói xuống sát đầu. Bấm Cúi thấp lần nữa để bò." | | | | |
| C9 | Bấm nút điện thoại để gọi 114 | Hiện "Đang gọi 114…" rồi "Đã gọi 114: báo địa chỉ, tầng đang cháy và số người còn kẹt" | | | | |
| C10 | (Nếu bài có mất điện) Bấm nút đèn pin ở góc trên, rồi nhặt bình chữa cháy | Đèn pin soi đường; khi cầm bình bằng hai tay, game báo "Đã tắt đèn pin để cầm bình bằng hai tay". Bài không có mất điện thì ghi Bỏ qua | | | | |
| C11 | Chơi tới khi ra khỏi tòa nhà | Màn **Kết quả phiên** hiện "Không chấm điểm" (cách Học không chấm Đạt/Chưa đạt) | | | | |
| C12 | Vào lại bài, chọn **Đánh giá**, chơi hết bài | Kết quả là Đạt hoặc Chưa đạt, có lý do và danh sách tiêu chí bằng tiếng Việt | | | | |
| C13 | Trong một lượt Đánh giá, thử mở Hỏi AI | Không dùng được AI: "Bạn không thể hỏi AI khi đang làm bài Đánh giá. Hoàn thành hoặc đóng phiên để hỏi lại." | | | | |
| C14 | Bắt đầu một lượt chơi, tắt mạng giữa chừng, chơi hết | Vẫn chơi được tới hết; kết quả ghi "Kết quả đã lưu trên máy" hoặc "Chờ đồng bộ" | | | | |
| C15 | Bật mạng lại, mở mục **Kết quả** | Lượt chơi ở C14 được gửi lên và hiện kết quả | | | | |
| C16 | Tắt mạng, vào **Bài đã tải**, bấm **Chơi lại** | Bài hiện "Sẵn sàng trên máy" nhưng không bắt đầu được lượt mới; ứng dụng ghi "Chơi lại cần mạng để kiểm tra quyền và bắt đầu lượt mới." | | | | |
| C17 | Đăng xuất, ở màn đăng nhập bấm **Xem Learn không cần đăng nhập** | Đọc được bài công khai không cần đăng nhập | | | | |
| C18 | Trên máy tính, mở trang tải ứng dụng (`https://fet3d.io.vn/download`) | Trang "Ứng dụng FET3D cho Android" giải thích cách nhận ứng dụng; bài tập 3D chỉ chơi trong ứng dụng Android, web không có bài 3D và không có bản iOS | Chạy 27/11 (chưa đăng nhập): trang "Ứng dụng FET3D cho Android" nói ứng dụng đang thử nghiệm trên Google Play, cài qua lời mời, cần Android 10 trở lên, quét mã QR công trình trong ứng dụng. Trang không nói web không có bài 3D và không nói không có bản iOS | Không đạt | Thiếu hai ý trong kết quả mong đợi | Lỗi 13 |
| C19 | Đăng nhập web bằng tài khoản học viên | Web chuyển tới Góc học tập; xem được lịch sử kết quả của chính mình | | | | |
| C20 | Chơi liên tục khoảng 15 phút một bài | Chơi được không văng; ghi vào Ghi chú độ ấm của máy và có giật hình không (máy ấm lên khi chơi lâu là giới hạn đã biết) | | | | |

## 7. Phần D — Các trường hợp phải bị từ chối

Mỗi ca dưới đây đạt khi hệ thống **chặn** thao tác và hiện thông báo dễ hiểu, không lộ dữ liệu của người khác.

| # | Vai trò | Thao tác | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| D1 | Học viên hoặc Tổ chức | Trên web, gõ thẳng địa chỉ `/expert/reviews` | "Không có quyền truy cập" — "Chỉ Chuyên viên PCCC thẩm định được hạ tầng và tình huống." | Chạy 27/11 (tài khoản Tổ chức): "Không có quyền truy cập" — "Khu này chỉ dành cho Chuyên viên PCCC." | Đạt | Câu thật ngắn hơn câu trong tài liệu; chưa thử bằng tài khoản Học viên | |
| D2 | Tổ chức | Gõ thẳng địa chỉ `/admin/runtime` | "Không có quyền truy cập" — "Chỉ quản trị FET3D có thể quản lý phiên bản chương trình mô phỏng." | Chạy 27/11: "Không có quyền truy cập" — "Chỉ quản trị FET3D được vào khu quản trị." | Đạt | Câu thật là câu chung của khu quản trị | |
| D3 | Tổ chức | Gõ thẳng địa chỉ `/admin/learn` và `/admin/library` | "Không có quyền truy cập" ở cả hai trang | Chạy 27/11: cả hai trang hiện "Không có quyền truy cập" — "Chỉ quản trị FET3D được vào khu quản trị." | Đạt | | |
| D4 | Học viên | Gõ thẳng địa chỉ `/workspace/ifc` | "Không có quyền truy cập" — "Tài khoản học viên không có quyền chuẩn bị mô hình IFC." | | | | |
| D5 | Học viên hoặc Quản trị | Gõ thẳng địa chỉ `/workspace/billing` | "Không có quyền truy cập" — "Khu này dành cho tài khoản tổ chức." | Chạy 27/11 (tài khoản Quản trị): trang KHÔNG chặn. Trang "Dịch vụ và thanh toán" mở trong khung Không gian tổ chức, liệt kê công trình của mọi tổ chức với cột hành động "Chỉ xem", kèm một dòng lỗi "Dữ liệu chưa hợp lệ. Kiểm tra các trường được đánh dấu rồi gửi lại." | Không đạt | Quản trị vốn xem được dữ liệu này ở khu quản trị nên không lộ thêm dữ liệu, nhưng sai trang và có dòng lỗi vô nghĩa; chưa thử bằng tài khoản Học viên | Lỗi 17 |
| D6 | Học viên | Gõ thẳng địa chỉ `/workspace/analytics` | "Không có quyền truy cập" — "Báo cáo này dành cho tài khoản tổ chức." | | | | |
| D7 | Tổ chức B | Mở liên kết QR của công trình thuộc tổ chức A | "Không tìm thấy công trình"; không hiện tên công trình của tổ chức A | | | | |
| D8 | Học viên | Quét mã QR cũ sau bước B17 | Ứng dụng báo "Mã QR này đã bị thu hồi" và nhắc quét mã mới | | | | |
| D9 | Người chưa đăng nhập | Mở liên kết QR trên trình duyệt | "Đăng nhập để xem công trình"; không hiện danh sách bài | | | | |
| D10 | Học viên 2 | Quét mã QR khi công trình đang Riêng tư, chưa nhập mã tham gia | Thấy "Tòa nhà riêng tư" và ô Mã tham gia; không thấy danh sách bài để chơi | | | | |
| D11 | Học viên 2 | Nhập sai mã tham gia | "Mã tham gia không đúng hoặc đã bị đổi/thu hồi." | | | | |
| D12 | Học viên 2 | Sau khi vào được bằng mã đúng, tổ chức bấm **Tạo mã mới** cho mã tham gia; học viên mở lại bài | Ứng dụng báo "Quyền vào tòa nhà đã thay đổi" và yêu cầu nhập mã mới | | | | |
| D13 | Học viên | Quét mã chạy thử (mã ở bước B9) bằng nút QUÉT | "Đây là mã chạy thử dành cho tài khoản tổ chức, không phải mã công trình…" | | | | |
| D14 | Tổ chức | Trong ứng dụng, quét mã QR công trình ở màn Quét mã bàn giao | "Đây là mã QR công trình dành cho học viên…" | | | | |
| D15 | Học viên | Bấm **Bắt đầu phiên** khi công trình đã hết suất học viên của kỳ | Màn "Tòa nhà đã hết suất"; không vào được màn chơi | | | | |
| D16 | Học viên | Mở công trình đã hết hạn dịch vụ | Xem được danh sách bài nhưng không bắt đầu được lượt mới; có dòng giải thích dịch vụ đã hết hạn | | | | |
| D17 | Tổ chức | Bấm lưu một bài học công khai | "Chỉ tài khoản học viên mới lưu được bài." | Chạy 27/11: ở trang Bài học, nút "Lưu bài viết" bị khoá, bên cạnh ghi "Chỉ tài khoản học viên lưu được bài." | Đạt | Nút khoá sẵn nên không bấm được | |
| D18 | Quản trị | Mở một báo giá của tổ chức và tìm nút thanh toán | Không thanh toán được thay tổ chức: "Quản trị FET3D có thể xem trạng thái nhưng không tạo thanh toán thay tổ chức." | Chạy 27/11: báo giá đã phát hành không có nút thanh toán; ghi "Đang chờ tổ chức chấp nhận — Quản trị FET3D không chấp nhận hay thanh toán thay tổ chức." | Đạt | Câu thật khác câu trong tài liệu |  |
| D19 | Chuyên viên PCCC (hai người) | Hai Chuyên viên cùng mở một mục chờ thẩm định; người thứ hai quyết định sau người thứ nhất | Người thứ hai bị từ chối; quyết định đầu giữ nguyên (hàng chờ dùng chung: ai thẩm định trước thì kết quả của người đó được ghi) | | | | |
| D20 | Tổ chức | Xuất CSV báo cáo lần thứ 11 trong cùng một ngày | Bị từ chối vì quá 10 lần xuất mỗi ngày; không tải được tệp | | | | |
| D21 | Tổ chức | Ở báo cáo, chọn khoảng thời gian dài hơn 90 ngày | Không áp dụng được; trang báo "Khoảng thời gian tối đa 90 ngày (đang chọn … ngày)." | Chạy 27/11: chọn 01/07–27/11/2026, bấm Áp dụng: "Khoảng thời gian tối đa 90 ngày (đang chọn 150 ngày)."; báo cáo giữ nguyên 30 ngày gần đây | Đạt | | |
| D22 | Quản trị | Đăng nhập ứng dụng điện thoại bằng email và mật khẩu của tài khoản quản trị | Không vào được: "Phiên đăng nhập không hợp lệ hoặc loại tài khoản này chưa dùng được trên ứng dụng." | | | | |
| D23 | Tổ chức | Tạo bản phát hành cho phiên bản chưa được Chuyên viên PCCC thẩm định đạt | Không tạo được; tab Phát hành ghi "Tạo được khi nội dung đã đạt thẩm định và gói đã chốt." | Chạy 27/11: v1 (Chưa đạt) không có bản phát hành; chỉ v2 (Đạt) tạo được | Đạt | | |
| D24 | Tổ chức | Sửa nội dung hoặc gửi thẩm định lại một phiên bản đã gửi | Không làm được trên phiên bản đó; phải tạo phiên bản mới và gửi thẩm định lại | Chạy 27/11: v1 ghi "v1 đã được gửi thẩm định nên không gửi lại. Tạo phiên bản mới để gửi nội dung khác." | Đạt | | |
| D25 | Tổ chức | Trong ứng dụng, bấm **Tiếp tục với Google** bằng tài khoản Google của tổ chức | "Ứng dụng chỉ dành cho học viên. Tài khoản Google này thuộc tài khoản tổ chức hoặc quản trị, hãy đăng nhập trên trang web fet3d.io.vn." | | | | |
| D26 | Quản trị | (Chỉ khi có báo giá đã thanh toán) Mở báo giá đó và tìm nút hủy hoặc hoàn tiền | Không hủy được: "Đã có tiền: không hủy được báo giá này"; không có thao tác hoàn tiền | Chạy 27/11: báo giá `FET-e776a515…` (đã nhận tiền 18/11) ghi "Đã có tiền: không hủy được báo giá này"; không có thao tác hoàn tiền | Đạt | Nút "Hủy báo giá" vẫn hiện bên dưới dòng đó; không bấm thử trên báo giá thật | Lỗi 16 |

## 8. Chỗ chưa xác nhận trên màn hình thật

Người kiểm thử lần đầu cần chú ý và ghi lại câu chữ thật ở các chỗ sau, vì tài liệu này chỉ đọc được mã nguồn mà chưa thấy màn hình:

- B3: tên các bước xử lý IFC hiện trên màn hình và thời gian xử lý.
- B5: trình soạn mới không có gió. Bản nháp cũ (soạn trước khi có trình soạn trên mô hình 3D) mở bằng trình soạn cũ, trong đó danh sách loại nguy hiểm còn mục "Gió (Wind)". Nếu gặp, ghi vào Ghi chú.
- B7: thời gian dựng gói (máy dựng gói chạy riêng, có thể phải chờ).
- B18, B19, A14: luồng báo giá chưa chạy với người dùng thật; giá phụ thuộc gói và giảm giá quản trị đang cấu hình.
- B20: mục Nhận thông báo trong Cài đặt tài khoản của ứng dụng ghi phụ đề "Kết quả, nhắc đồng bộ", nhưng hiện nay thông báo đẩy duy nhất là nhắc gia hạn dịch vụ trước 5 ngày gửi cho tài khoản tổ chức. Tài khoản tổ chức trên điện thoại vào thẳng màn Chạy thử; thiết bị đăng ký nhận thông báo khi đăng nhập nếu người dùng cho phép.
- C2: đăng nhập Google mới được cấu hình cho bản ký của Google Play ngày 15/11/2026; chưa ai thử trên bản cài từ Google Play.
- C7–C10: câu chữ trong màn chơi đọc từ mã nguồn Unity; vị trí nút trên màn hình chưa xác nhận.
- A13, D1, D19: màn Theo dõi thẩm định của quản trị và ca hai Chuyên viên chưa chạy trên màn hình thật.
- D16, D20: quy tắc có trong máy chủ hoặc tài liệu nghiệp vụ, nhưng câu thông báo trên màn hình chưa đọc được đủ trong mã nguồn.
- Toàn bộ phần C chưa chạy lại trên điện thoại khác ngoài máy nghiệm thu của nhóm (Redmi Note 10S).

## 9. Phiếu góp ý của người tham gia

**Đồng ý tham gia và cho thu phản hồi.** Tôi đồng ý tham gia buổi kiểm thử này và đồng ý để nhóm FET3D ghi lại kết quả, ảnh chụp màn hình và câu trả lời dưới đây để đánh giá đồ án. Phản hồi chỉ dùng cho đồ án, không công bố họ tên nếu tôi không đồng ý.

| Họ tên | Vai trò | Đồng ý (ký hoặc ghi "Đồng ý") | Cho phép ghi họ tên trong báo cáo (Có / Không) | Ngày (dd/mm/yyyy) |
| :--- | :--- | :--- | :--- | :--- |
| | | | | |

Thang điểm: 1 = rất không đồng ý, 2 = không đồng ý, 3 = bình thường, 4 = đồng ý, 5 = rất đồng ý.

### 9.1. Quản trị

| # | Câu hỏi | Điểm (1–5) | Ý kiến thêm |
| :--- | :--- | :--- | :--- |
| QT1 | Tôi tìm được ngay chức năng mình cần ở thanh bên | | |
| QT2 | Tạo tài khoản Chuyên viên PCCC và sửa email gõ sai dễ làm | | |
| QT3 | Màn Theo dõi thẩm định cho tôi biết mục nào đang chờ và kết quả ra sao | | |
| QT4 | Soạn, ẩn, hiện và khôi phục bài học dễ làm | | |
| QT5 | Lập và phát hành báo giá cho tổ chức dễ làm | | |
| QT6 | Câu thông báo (thành công, lỗi, không có quyền) dễ hiểu, không có từ kỹ thuật khó | | |

Điều tôi muốn nhóm sửa nhất: ............................................................

### 9.2. Tổ chức

| # | Câu hỏi | Điểm (1–5) | Ý kiến thêm |
| :--- | :--- | :--- | :--- |
| TC1 | Tôi biết bước tiếp theo phải làm nhờ thẻ Hành trình của công trình | | |
| TC2 | Tải IFC và chọn cửa thoát, thiết bị dễ làm | | |
| TC3 | Trình soạn kịch bản đủ rõ để tôi đặt lửa, người trong tòa nhà, mục tiêu và tiêu chí chấm | | |
| TC4 | Chạy thử trên điện thoại giúp tôi kiểm tra bài trước khi gửi thẩm định | | |
| TC5 | Phát hành, mã QR và mã tham gia dễ hiểu | | |
| TC6 | Báo cáo và báo giá cho tôi đủ thông tin cần biết | | |
| TC7 | Câu thông báo trên web dễ hiểu, không có từ kỹ thuật khó | | |

Điều tôi muốn nhóm sửa nhất: ............................................................

### 9.3. Chuyên viên PCCC

| # | Câu hỏi | Điểm (1–5) | Ý kiến thêm |
| :--- | :--- | :--- | :--- |
| CV1 | Lần đăng nhập đầu (mã email, đổi mật khẩu) dễ làm | | |
| CV2 | Màn thẩm định cho tôi đủ thông tin để cho Đạt hay Chưa đạt | | |
| CV3 | Tôi nhận ra ngay từng thiết bị, lối thoát và điểm tập kết trên mô hình | | |
| CV4 | Câu chữ trên màn hình dễ hiểu, không có từ kỹ thuật khó | | |

Điều tôi muốn nhóm sửa nhất: ............................................................

### 9.4. Học viên

| # | Câu hỏi | Điểm (1–5) | Ý kiến thêm |
| :--- | :--- | :--- | :--- |
| HV1 | Cài ứng dụng, đăng ký và đăng nhập dễ làm | | |
| HV2 | Quét mã QR và vào được bài nhanh | | |
| HV3 | Tôi hiểu mình phải làm gì trong bài (mục tiêu, lối thoát, lời nhắc trên màn hình) | | |
| HV4 | Điều khiển nhân vật (đi, cúi, bò, mở cửa, cầm đồ, gọi 114) dễ làm trên điện thoại | | |
| HV5 | Tình huống cháy trong bài giống tình huống thật và giúp tôi nhớ cách thoát nạn | | |
| HV6 | Kết quả sau lượt chơi giải thích rõ vì sao tôi đạt hoặc chưa đạt | | |
| HV7 | Ứng dụng chạy mượt trên điện thoại của tôi | | |

Điều tôi muốn nhóm sửa nhất: ............................................................

## 10. Nhật ký lỗi

Ghi mỗi lỗi một dòng. Mức độ: **Nghiêm trọng** (không làm tiếp được bước chính), **Cao** (làm được nhưng sai kết quả), **Trung bình** (khó dùng, có cách né), **Thấp** (câu chữ, giao diện).

| STT | Bước | Mô tả (kèm ảnh chụp màn hình nếu có) | Mức độ | Issue | Đã sửa ở commit | Kiểm lại ngày (dd/mm/yyyy) | Kết quả kiểm lại |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | B4a | Hạ tầng PCCC lấy bình chữa cháy từ thiết bị đã xác nhận nhưng để trống loại chất chữa cháy và thời gian phun; phải điền tay từng bình | Trung bình |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 2 | B4a | Thông báo "Cần điền ô này." không nói đối tượng hay ô nào; chỉ có trong Thông tin cho bộ phận hỗ trợ | Trung bình |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 3 | B4a | Cửa chọn làm cửa thoát ở B4 vào hạ tầng thành thiết bị chứ không thành lối thoát, nên vẫn báo "Cần ít nhất một lối thoát nạn."; phải tự thêm Lối ra ngoài gắn vào cửa đó | Cao | BE#239 | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 4 | B3, B4a, E3 | Chữ kỹ thuật lộ ra: "IfcBuildingElementProxy", "IfcDoor", "Equipment", "Goal", "LightFixture", "bước Bước khác"; Chuyên viên không biết thiết bị là gì; tên tầng hiện tên thô trong IFC | Trung bình | BE#239 | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 5 | B2 | Chọn loại Chung cư vẫn hiện gợi ý "Trường học: từ tiểu học trở lên" | Thấp |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 6 | B5 | Áp mẫu ghi đè tên bản nháp bằng tên mẫu ("Cháy bếp căn hộ tầng 8…") dù kịch bản đã có tên và tòa chỉ có 4 tầng; tên này đi tiếp vào hộp gửi thẩm định và bài huấn luyện | Trung bình |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 7 | B5, E4 | Còn chữ kỹ thuật: tiêu chí "step_count", "route_efficiency"; "rubric"; mục "NPC"; "Spawn", "Hazard"; ở màn Chuyên viên còn các khoá objects, audience Evacuee, workingHours InHours, schemaVersion; điểm đạt ghi 0.7 thay vì 70% | Thấp |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 8 | B6 | Hộp tạo phiên bản hiện mã lần lưu dạng `"20805"` | Thấp |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 9 | B7 | Trạng thái dựng gói đầu trang chỉ đổi sau khi tải lại trang; lượt dựng v2 bị máy dựng nhận lại lần 2 mà không nói lý do | Thấp | BE#239 | FE `a84e66b` (PR #278), lý do ở FE `90af1c4` (PR #280) | 27/11/2026 | Đạt phần lý do: nhật ký ghi lượt 1 "Bị ngắt" kèm "Máy xử lý bị ngắt giữa chừng (khởi động lại hoặc mất kết nối) nên hệ thống đã giao lại việc."; phần trạng thái tự cập nhật chưa kiểm lại |
| 10 | B10, B10a | Thông báo sau khi gửi ghi "đã gửi cho quản trị FET3D" (người thẩm định là Chuyên viên PCCC); bảng quyết định có chữ "Rejected" | Thấp |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 11 | B10, B11 | Tab Gửi thẩm định và Phát hành hiện mã băm và mã gói dài cho người dùng tổ chức | Thấp |  | FE `a84e66b` (PR #278) |  | Đã sửa trên web; chưa kiểm lại bằng một lượt chạy thật |
| 12 | B11 | Tab Phát hành còn chữ "Built"; bảng Bài huấn luyện ghi "Đang dùng" cho bài chưa phát hành được | Thấp |  | FE `a84e66b` (PR #278) | 27/11/2026 | Đạt: tab Phát hành ghi "Chưa phát hành", không còn chữ "Built" |
| 13 | C18 | Trang `/download` không nói bài tập 3D chỉ chơi trong ứng dụng (web không có bài 3D) và không nói chưa có bản iOS | Thấp |  |  |  |  |
| 14 | B3, B7 | Sau khi dựng gói, thẻ IFC đọc theo việc dựng gói: bước "Dựng mô hình 3D" ghi "lượt xử lý thứ 2", kết quả kiểm tra tự động lấy của việc dựng gói; nhật ký ghi "Bước khác" cho lượt dựng gói | Cao |  | FE `c357c24` (PR #282, #284) | 27/11/2026 | Đạt: "Dựng mô hình 3D · lượt xử lý thứ 1", kiểm tra 08:44 của việc dựng mô hình; nhật ký ghi "Dựng gói phát hành" |
| 15 | B20 | Thẻ "Nhắc gia hạn" trong Dịch vụ & thanh toán liệt kê cả thông báo kết quả thẩm định (hạ tầng, tình huống), không liên quan tới gia hạn | Thấp |  |  |  |  |
| 16 | D26 | Báo giá đã nhận tiền vẫn hiện nút "Hủy báo giá" ngay dưới dòng "Đã có tiền: không hủy được báo giá này" (chưa bấm thử) | Thấp |  |  |  |  |
| 17 | D5 | Quản trị gõ `/workspace/billing` không bị chặn: trang của tổ chức mở ra ở chế độ "Chỉ xem" với công trình của mọi tổ chức và dòng lỗi "Dữ liệu chưa hợp lệ…" | Trung bình |  |  |  |  |
| 18 | A7 | Mục thư viện đang "Ngừng dùng" nhưng phiên bản v1 vẫn mang nhãn "Tổ chức đang thấy" và dòng "Bản tổ chức đang thấy: v1", trái với khung "Tổ chức không thấy mục này" ngay bên trên | Thấp |  |  |  |  |

## 11. Tổng kết lượt kiểm thử

| Phần | Số bước | Đạt | Không đạt | Bỏ qua |
| :--- | :--- | :--- | :--- | :--- |
| A — Quản trị | 15 | 14 | 0 | 0 |
| B — Tổ chức | 23 | 15 | 1 | 2 |
| E — Chuyên viên PCCC | 6 | 6 | 0 | 0 |
| C — Học viên | 20 | 0 | 1 | 0 |
| D — Từ chối quyền | 26 | 9 | 1 | 0 |
| Tổng | 90 | 44 | 3 | 2 |

Các số trên là của lượt chạy 26–27/11/2026 do nhóm tự chạy; các bước còn trống chưa chạy.

## 12. Biên bản nghiệm thu

Nghiệm thu đồ án tốt nghiệp FET3D, không phải chứng nhận PCCC.

| Mục | Điền |
| :--- | :--- |
| Ngày nghiệm thu (dd/mm/yyyy) | |
| Địa điểm | |
| Phiên bản đã kiểm (web, ứng dụng, runtime) | |
| Người kiểm thử (họ tên, vai trò) | |
| Người chứng kiến (họ tên, vai trò) | |
| Số bước Đạt / Không đạt / Bỏ qua | |
| Lỗi còn mở (số thứ tự ở mục 10) | |
| Kết luận (Chấp nhận / Chấp nhận kèm điều kiện / Không chấp nhận) | |
| Điều kiện kèm theo (nếu có) | |

| Vai trò | Họ tên | Chữ ký | Ngày (dd/mm/yyyy) |
| :--- | :--- | :--- | :--- |
| Người kiểm thử — Quản trị | | | |
| Người kiểm thử — Tổ chức | | | |
| Người kiểm thử — Học viên | | | |
| Người chứng kiến | | | |
| Trưởng nhóm | | | |
