# Kịch bản kiểm thử chấp nhận (UAT)

Kịch bản này để người dùng thật đi qua ba vai trò của FET3D (Quản trị, Tổ chức, Học viên) theo đúng thứ tự một bài tập đi từ mô hình công trình tới kết quả của học viên, rồi thử các trường hợp phải bị từ chối quyền. Người kiểm thử chỉ cần làm theo từng dòng và điền các cột **Kết quả thực tế**, **Đạt / Không đạt**, **Ghi chú** và **Mã lỗi / issue**. Cuối tài liệu có phiếu góp ý cho từng vai trò, bảng ghi lỗi và biên bản nghiệm thu để ký.

> **Phạm vi.** Đây là nghiệm thu đồ án tốt nghiệp (capstone), không phải chứng nhận phòng cháy chữa cháy (PCCC). Nội dung PCCC trong bài học và kịch bản do quản trị FET3D (người có chuyên môn của nhóm) duyệt; không có bước thẩm định của chuyên gia PCCC bên ngoài. Tác dụng của khăn ướt, chăn ướt, che mũi miệng, chèn khe cửa và chỗ trú tạm trong game là mô phỏng để tập huấn ([quyết định ngày 16/11/2026](fire_evacuation_project_overview.md#quyết-định-của-trưởng-nhóm-ngày-16112026)).

> **Nguồn và mức xác nhận.** Các bước và câu chữ được đối chiếu với mã nguồn của [bản phát hành ngày 16/11/2026](release-manifest.md) (web FE `f1a7a22`, ứng dụng Mobile `533b6ee`, máy chủ BE `528f9c4`, runtime 2.5.0). Câu chữ trong ngoặc kép là câu đọc được trong mã nguồn. **Chưa có bước nào được chạy lại trên màn hình thật khi soạn tài liệu này**; mục 7 liệt kê những chỗ cần chú ý khi chạy lần đầu.

## 1. Thông tin lượt kiểm thử

| Mục | Điền |
| :--- | :--- |
| Ngày kiểm thử (dd/mm/yyyy) | |
| Người kiểm thử và vai trò (Quản trị / Tổ chức / Học viên) | |
| Người chứng kiến (thành viên nhóm) | |
| Môi trường web (địa chỉ) | |
| Phiên bản ứng dụng (mục Tôi → Phiên bản ứng dụng) | |
| Cách cài ứng dụng (Google Play kênh thử nghiệm / tệp cài do nhóm gửi) | |
| Điện thoại và phiên bản Android | |
| Phiên bản runtime đang bật (trang Phiên bản runtime) | |

## 2. Chuẩn bị

| Cần có | Ghi chú |
| :--- | :--- |
| Tài khoản quản trị | Do nhóm cấp; không tự đăng ký được |
| Tài khoản tổ chức A | Dùng cho phần Tổ chức |
| Tài khoản tổ chức B | Chỉ dùng cho các ca từ chối quyền giữa hai tổ chức |
| Tài khoản học viên 1 và học viên 2 | Học viên 2 dùng cho ca Riêng tư và ca hết suất |
| Một tài khoản Google chưa dùng với FET3D | Cho bước đăng nhập Google (C2) |
| Một tệp IFC | Ví dụ tệp trường học ở [IFC mục 10.1](ifc_ingestion_visual_interaction.md#101-hai-công-trình-nghiệm-thu). Mỗi lần tải lên nhận đúng một tệp; mô hình tách theo bộ môn phải gộp khi xuất |
| Điện thoại Android đã cài ứng dụng FET3D | Chỉ có bản Android, không có bản iOS. Xem [hướng dẫn học viên, mục 2](huong-dan-hoc-vien.md#2-cài-ứng-dụng) |
| Công trình của tổ chức A còn dịch vụ | Cần để phát hành và để học viên bắt đầu lượt chơi |

Quy ước cột **Đạt / Không đạt**: ghi Đạt, Không đạt, hoặc Bỏ qua (ghi lý do ở cột Ghi chú). Khi Không đạt, ghi lỗi vào bảng ở mục 9 và chép số thứ tự lỗi (hoặc số issue nếu nhóm đã mở) vào cột **Mã lỗi / issue**.

## 3. Phần A — Quản trị

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| A1 | Đăng nhập web bằng tài khoản quản trị | Web chuyển tới trang Tổng quan của khu Quản trị hệ thống; thanh bên có Duyệt kịch bản, Phiên bản runtime, Bài học, Thư viện mẫu, Dịch vụ & thanh toán | | | | |
| A2 | Mở **Phiên bản runtime** | Thấy danh sách phiên bản, mới nhất ở trên; phiên bản 2.5.0 có trạng thái "Đang dùng" | | | | |
| A3 | Bấm vào hàng 2.5.0 | Thấy danh sách năng lực của phiên bản, kèm sự kiện và thao tác; không có nút sửa nội dung | | | | |
| A4 | Bấm **Đăng ký phiên bản**, chọn một tệp không phải tệp danh mục của runtime | Trang báo "Tệp chưa đúng" và không đăng ký được | | | | |
| A5 | Mở **Thư viện mẫu**, bấm **Thêm mục**, tạo một mục Tiêu chí chấm mẫu, **Tạo phiên bản**, lưu nháp rồi **Xuất bản** | Trang báo "Đã xuất bản phiên bản"; mục có dòng "Bản tổ chức đang thấy" | | | | |
| A6 | Mở lại phiên bản vừa xuất bản | Phiên bản ghi "Đã xuất bản (không sửa được)"; chỉ có thể tạo Phiên bản mới | | | | |
| A7 | Bấm **Ngừng dùng** cho mục đó, rồi **Dùng lại** | Trang báo "Đã ngừng dùng mục" rồi "Đã dùng lại mục" | | | | |
| A8 | Mở **Bài học**, bấm **Bài mới**, tạo một bài viết với Xuất bản ngay đang tắt | Trang báo "Đã tạo bản nháp"; bài chưa hiện ở trang Bài học công khai | | | | |
| A9 | Xuất bản bài nháp đó | Bài hiện ở trang Bài học công khai khi chưa đăng nhập | | | | |
| A10 | **Ẩn bài**, kiểm tra trang công khai, rồi **Hiện lại** | Sau khi ẩn, bài không còn ở trang công khai; sau Hiện lại, bài có lại | | | | |
| A11 | **Xóa bài** rồi **Khôi phục** | Sau khôi phục, bài ở trạng thái Đã ẩn, không tự công khai | | | | |
| A12 | (Sau bước B10) Mở **Duyệt kịch bản**, lọc Chờ duyệt | Thấy phiên bản tổ chức A vừa gửi, có tên kịch bản, tổ chức · công trình và thời điểm gửi | | | | |
| A13 | Mở bản duyệt | Thấy Mục tiêu học tập, Hướng dẫn cho người học, Tiêu chí chấm điểm (ngưỡng đạt, trọng số, bắt buộc) và Nội dung kịch bản; tất cả chỉ đọc | | | | |
| A14 | Bấm **Từ chối**, để trống lý do | Không ghi được; trang yêu cầu "Nhập lý do từ chối (1–4000 ký tự)." | | | | |
| A15 | Bấm **Duyệt nội dung** và xác nhận | Trang báo "Đã duyệt nội dung"; hộp thoại đã nhắc duyệt nội dung không phải là phát hành | | | | |
| A16 | Mở lại bản vừa duyệt | Thấy "Quyết định đã được ghi và không đổi được."; không còn nút Duyệt hay Từ chối | | | | |
| A17 | (Sau bước B18) Mở **Dịch vụ & thanh toán** → thẻ **Báo giá**, bấm vào báo giá nháp của tổ chức A, bấm **Phát hành báo giá** | Trang báo "Đã phát hành báo giá"; giá của từng dòng công trình là giá quản trị đặt ở gói dịch vụ và giảm giá, không phải con số cố định trong tài liệu | | | | |
| A18 | Mở lại báo giá đó và tìm nút hoàn tiền | Không có thao tác hoàn tiền ở bất kỳ đâu; báo giá chưa thanh toán chỉ có **Hủy báo giá** | | | | |

## 4. Phần B — Tổ chức

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| B1 | Đăng nhập web bằng tài khoản tổ chức A | Web chuyển tới trang **Công trình** của Không gian tổ chức | | | | |
| B2 | Bấm **Thêm công trình**, nhập Tên công trình, Loại công trình, Số tầng, Tỉnh / Thành phố, Quận / Huyện, Địa chỉ; lưu rồi mở công trình | Trang công trình có năm thẻ: Hành trình, IFC, Kịch bản, Truy cập, Dịch vụ | | | | |
| B3 | Ở thẻ **IFC**, bấm **Tải IFC** và chọn tệp IFC | Mục Tiến trình cập nhật tới khi xử lý xong; mục Xem trước 3D hiện mô hình; mục Kỹ thuật có danh sách vấn đề (nếu có) | | | | |
| B4 | Mở mục **Thiết bị**. Nếu có khung "Chọn cửa thoát ra ngoài", chọn một cửa làm cửa thoát; xác nhận hoặc loại các thiết bị được đề xuất rồi lưu | Trang báo "Đã lưu quyết định thiết bị" | | | | |
| B5 | Ở thẻ **Kịch bản**, bấm **Tạo kịch bản**, đặt tên rồi bấm vào kịch bản để mở trình soạn. Đặt điểm xuất phát, nguồn lửa, thiết bị, số người trong tòa nhà, mục tiêu và tiêu chí chấm; bấm **Lưu** | Bản nháp được lưu; trình soạn không có mục cấu hình gió; số người trong tòa nhà đúng bằng số người soạn đã đặt | | | | |
| B6 | Trong trình soạn bấm **Phiên bản**, rồi **Tạo phiên bản mới**, chọn bản nháp vừa lưu và bấm **Tạo phiên bản** | Trang báo "Đã tạo phiên bản mới"; trang phiên bản có các thẻ Tổng quan, Dựng gói, Kiểm tra, Gửi duyệt, Phát hành, Chạy thử | | | | |
| B7 | Ở thẻ **Dựng gói**, bấm **Dựng gói** và chờ xong; sang thẻ **Kiểm tra**, khi kết quả đạt thì bấm **Chốt gói phát hành** | Dựng gói xong (có thể mất nhiều phút); trang báo "Đã chốt gói phát hành" | | | | |
| B8 | Quay lại thẻ **IFC** → mục **Tiến trình**, ở khung "Xác nhận mô hình dùng được cho huấn luyện" chọn phiên bản kịch bản vừa tạo rồi bấm **Xác nhận dùng cho huấn luyện** | Trang báo "Đã xác nhận mô hình dùng được cho huấn luyện" | | | | |
| B9 | Ở trang phiên bản, mở thẻ **Chạy thử**, bấm **Bắt đầu chạy thử** rồi **Tạo mã QR mở trên điện thoại**. Trên điện thoại đăng nhập bằng tài khoản tổ chức A, bấm **Quét mã bàn giao**, quét mã, **Tải và kiểm tra gói**, **Bắt đầu chạy thử**, chơi hết | Web báo "Điện thoại đã nhận mã và đang giữ lượt chạy thử này."; màn chơi mở trên điện thoại; xong, ứng dụng báo "Đã gửi kết quả chạy thử. Xem kết quả trên web." | | | | |
| B10 | Ở thẻ **Gửi duyệt**, bấm **Gửi duyệt** và xác nhận | Phiên bản chuyển sang "Đã gửi, chờ duyệt"; trang ghi phiên bản đã được gửi duyệt nên không gửi lại | | | | |
| B11 | (Sau bước A15) Ở thẻ **Phát hành**, bấm **Tạo bản phát hành**, rồi bấm **Phát hành** | Trang báo "Đã tạo bản phát hành"; sau khi bấm Phát hành, trạng thái là "Đã phát hành" | | | | |
| B12 | Ở thẻ **Truy cập** → mục **Mã QR**, bấm **Tạo mã QR** và xác nhận | Trang báo "Đã tạo mã QR"; có liên kết dạng `https://fet3d.io.vn/qr/…`, nút **Sao chép liên kết** và **In mã QR**; trang nhắc "Mã này chỉ hiển thị một lần" | | | | |
| B13 | Khi công trình đã có mã QR đang hoạt động, xem lại mục Mã QR | Không còn nút Tạo mã QR; chỉ có **Tạo mã mới** và **Thu hồi mã** (mỗi công trình chỉ có một mã đang hoạt động) | | | | |
| B14 | Ở thẻ **Truy cập** → mục **Quyền tham gia**, chọn **Riêng tư (cần mã tham gia)**, bấm **Áp dụng chế độ**, rồi **Tạo mã tham gia** và **Sao chép** | Có mã tham gia; trang báo "Đã sao chép mã tham gia" | | | | |
| B15 | (Sau phần C) Mở **Báo cáo**, chọn khoảng thời gian có lượt chơi | Số lượt chơi và số học viên khớp với các lượt đã chơi ở phần C; lượt chạy thử ở B9 không được tính | | | | |
| B16 | Ở báo cáo Huấn luyện, bấm **Xuất CSV** | Tải được tệp `.csv`; tệp chỉ có dòng tổng hợp, không có tên hay email học viên | | | | |
| B17 | Ở mục Mã QR, bấm **Tạo mã mới**, đọc hộp thoại "Tạo lại mã QR?" rồi bấm **Tạo mã mới** | Trang báo "Đã tạo mã QR mới" và "QR cũ đã ngừng hoạt động." (kiểm mã cũ ở ca D8) | | | | |
| B18 | Mở **Dịch vụ & thanh toán**, bấm **Mua gói công trình**, chọn công trình và gói | Trang báo "Đã tạo báo giá nháp"; báo giá chờ quản trị phát hành ("Đang chờ quản trị FET3D phát hành") | | | | |
| B19 | (Sau bước A17) Mở báo giá đã phát hành, xem giá từng dòng, rồi bấm **Hủy báo giá**, nhập lý do và xác nhận | Giá khớp với giá quản trị đặt; trang báo "Đã hủy báo giá". **Không thanh toán thật** trong buổi UAT trừ khi trưởng nhóm đồng ý: sau khi thanh toán không hoàn tiền | | | | |
| B20 | Mở thẻ **Nhắc gia hạn** trong Dịch vụ & thanh toán | Trang ghi hệ thống nhắc gia hạn trước 5 ngày khi kỳ dịch vụ sắp hết. Nếu có công trình còn dưới 5 ngày dịch vụ: có dòng nhắc trên web, thư nhắc và thông báo trên điện thoại đã đăng nhập tài khoản tổ chức (đã cho phép thông báo). Không có công trình nào sắp hết hạn thì ghi Bỏ qua | | | | |

## 5. Phần C — Học viên

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
| C18 | Trên máy tính, mở trang tải ứng dụng (`https://fet3d.io.vn/download`) | Trang "Ứng dụng FET3D cho Android" giải thích cách nhận ứng dụng; bài tập 3D chỉ chơi trong ứng dụng Android, web không có bài 3D và không có bản iOS | | | | |
| C19 | Đăng nhập web bằng tài khoản học viên | Web chuyển tới Góc học tập; xem được lịch sử kết quả của chính mình | | | | |
| C20 | Chơi liên tục khoảng 15 phút một bài | Chơi được không văng; ghi vào Ghi chú độ ấm của máy và có giật hình không (máy ấm lên khi chơi lâu là giới hạn đã biết) | | | | |

## 6. Phần D — Các trường hợp phải bị từ chối

Mỗi ca dưới đây đạt khi hệ thống **chặn** thao tác và hiện thông báo dễ hiểu, không lộ dữ liệu của người khác.

| # | Vai trò | Thao tác | Kết quả mong đợi | Kết quả thực tế | Đạt / Không đạt | Ghi chú | Mã lỗi / issue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| D1 | Học viên | Trên web, gõ thẳng địa chỉ `/admin/reviews` | "Không có quyền truy cập" — "Chỉ quản trị FET3D duyệt được kịch bản." | | | | |
| D2 | Tổ chức | Gõ thẳng địa chỉ `/admin/runtime` | "Không có quyền truy cập" — "Chỉ quản trị FET3D có thể quản lý phiên bản chương trình mô phỏng." | | | | |
| D3 | Tổ chức | Gõ thẳng địa chỉ `/admin/learn` và `/admin/library` | "Không có quyền truy cập" ở cả hai trang | | | | |
| D4 | Học viên | Gõ thẳng địa chỉ `/workspace/ifc` | "Không có quyền truy cập" — "Tài khoản học viên không có quyền chuẩn bị mô hình IFC." | | | | |
| D5 | Học viên hoặc Quản trị | Gõ thẳng địa chỉ `/workspace/billing` | "Không có quyền truy cập" — "Khu này dành cho tài khoản tổ chức." | | | | |
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
| D17 | Tổ chức | Bấm lưu một bài học công khai | "Chỉ tài khoản học viên mới lưu được bài." | | | | |
| D18 | Quản trị | Mở một báo giá của tổ chức và tìm nút thanh toán | Không thanh toán được thay tổ chức: "Quản trị FET3D có thể xem trạng thái nhưng không tạo thanh toán thay tổ chức." | | | | |
| D19 | Quản trị (hai người) | Hai quản trị cùng mở một bản chờ duyệt; người thứ hai quyết định sau người thứ nhất | Người thứ hai được báo bản này "không còn ở trạng thái chờ duyệt"; quyết định đầu giữ nguyên | | | | |
| D20 | Tổ chức | Xuất CSV báo cáo lần thứ 11 trong cùng một ngày | Bị từ chối vì quá 10 lần xuất mỗi ngày; không tải được tệp | | | | |
| D21 | Tổ chức | Ở báo cáo, chọn khoảng thời gian dài hơn 90 ngày | Không áp dụng được; trang báo "Khoảng thời gian tối đa 90 ngày (đang chọn … ngày)." | | | | |
| D22 | Quản trị | Đăng nhập ứng dụng điện thoại bằng email và mật khẩu của tài khoản quản trị | Không vào được: "Phiên đăng nhập không hợp lệ hoặc loại tài khoản này chưa dùng được trên ứng dụng." | | | | |
| D23 | Tổ chức | Phát hành một phiên bản chưa được quản trị duyệt | Không phát hành được; bước Chuẩn bị phát hành ghi "Cần nội dung được duyệt" | | | | |
| D24 | Tổ chức | Sửa nội dung hoặc gửi duyệt lại một phiên bản đã gửi duyệt | Không làm được trên phiên bản đó; phải tạo phiên bản mới và gửi duyệt lại | | | | |
| D25 | Tổ chức | Trong ứng dụng, bấm **Tiếp tục với Google** bằng tài khoản Google của tổ chức | "Ứng dụng chỉ dành cho học viên. Tài khoản Google này thuộc tài khoản tổ chức hoặc quản trị, hãy đăng nhập trên trang web fet3d.io.vn." | | | | |
| D26 | Quản trị | (Chỉ khi có báo giá đã thanh toán) Mở báo giá đó và tìm nút hủy hoặc hoàn tiền | Không hủy được: "Đã có tiền: không hủy được báo giá này"; không có thao tác hoàn tiền | | | | |

## 7. Chỗ chưa xác nhận trên màn hình thật

Người kiểm thử lần đầu cần chú ý và ghi lại câu chữ thật ở các chỗ sau, vì tài liệu này chỉ đọc được mã nguồn mà chưa thấy màn hình:

- B3: tên các bước xử lý IFC hiện trên màn hình và thời gian xử lý.
- B5: trình soạn mới không có gió. Bản nháp cũ (soạn trước khi có trình soạn trên mô hình 3D) mở bằng trình soạn cũ, trong đó danh sách loại nguy hiểm còn mục "Gió (Wind)". Nếu gặp, ghi vào Ghi chú.
- B7: thời gian dựng gói (máy dựng gói chạy riêng, có thể phải chờ).
- B18, B19, A17: luồng báo giá chưa chạy với người dùng thật; giá phụ thuộc gói và giảm giá quản trị đang cấu hình.
- B20: mục Nhận thông báo trong Cài đặt tài khoản của ứng dụng ghi phụ đề "Kết quả, nhắc đồng bộ", nhưng hiện nay thông báo đẩy duy nhất là nhắc gia hạn dịch vụ trước 5 ngày gửi cho tài khoản tổ chức. Tài khoản tổ chức trên điện thoại vào thẳng màn Chạy thử; thiết bị đăng ký nhận thông báo khi đăng nhập nếu người dùng cho phép.
- C2: đăng nhập Google mới được cấu hình cho bản ký của Google Play ngày 15/11/2026; chưa ai thử trên bản cài từ Google Play.
- C7–C10: câu chữ trong màn chơi đọc từ mã nguồn Unity; vị trí nút trên màn hình chưa xác nhận.
- D16, D20, D23, D24: quy tắc có trong máy chủ hoặc tài liệu nghiệp vụ, nhưng câu thông báo trên màn hình chưa đọc được đủ trong mã nguồn.
- Toàn bộ phần C chưa chạy lại trên điện thoại khác ngoài máy nghiệm thu của nhóm (Redmi Note 10S).

## 8. Phiếu góp ý của người tham gia

**Đồng ý tham gia và cho thu phản hồi.** Tôi đồng ý tham gia buổi kiểm thử này và đồng ý để nhóm FET3D ghi lại kết quả, ảnh chụp màn hình và câu trả lời dưới đây để đánh giá đồ án. Phản hồi chỉ dùng cho đồ án, không công bố họ tên nếu tôi không đồng ý.

| Họ tên | Vai trò | Đồng ý (ký hoặc ghi "Đồng ý") | Cho phép ghi họ tên trong báo cáo (Có / Không) | Ngày (dd/mm/yyyy) |
| :--- | :--- | :--- | :--- | :--- |
| | | | | |

Thang điểm: 1 = rất không đồng ý, 2 = không đồng ý, 3 = bình thường, 4 = đồng ý, 5 = rất đồng ý.

### 8.1. Quản trị

| # | Câu hỏi | Điểm (1–5) | Ý kiến thêm |
| :--- | :--- | :--- | :--- |
| QT1 | Tôi tìm được ngay chức năng mình cần ở thanh bên | | |
| QT2 | Màn Duyệt kịch bản cho tôi đủ thông tin để quyết định duyệt hay từ chối | | |
| QT3 | Tôi hiểu rõ duyệt nội dung khác với phát hành | | |
| QT4 | Soạn, ẩn, hiện và khôi phục bài học dễ làm | | |
| QT5 | Lập và phát hành báo giá cho tổ chức dễ làm | | |
| QT6 | Câu thông báo (thành công, lỗi, không có quyền) dễ hiểu, không có từ kỹ thuật khó | | |

Điều tôi muốn nhóm sửa nhất: ............................................................

### 8.2. Tổ chức

| # | Câu hỏi | Điểm (1–5) | Ý kiến thêm |
| :--- | :--- | :--- | :--- |
| TC1 | Tôi biết bước tiếp theo phải làm nhờ thẻ Hành trình của công trình | | |
| TC2 | Tải IFC và chọn cửa thoát, thiết bị dễ làm | | |
| TC3 | Trình soạn kịch bản đủ rõ để tôi đặt lửa, người trong tòa nhà, mục tiêu và tiêu chí chấm | | |
| TC4 | Chạy thử trên điện thoại giúp tôi kiểm tra bài trước khi gửi duyệt | | |
| TC5 | Phát hành, mã QR và mã tham gia dễ hiểu | | |
| TC6 | Báo cáo và báo giá cho tôi đủ thông tin cần biết | | |
| TC7 | Câu thông báo trên web dễ hiểu, không có từ kỹ thuật khó | | |

Điều tôi muốn nhóm sửa nhất: ............................................................

### 8.3. Học viên

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

## 9. Nhật ký lỗi

Ghi mỗi lỗi một dòng. Mức độ: **Nghiêm trọng** (không làm tiếp được bước chính), **Cao** (làm được nhưng sai kết quả), **Trung bình** (khó dùng, có cách né), **Thấp** (câu chữ, giao diện).

| STT | Bước | Mô tả (kèm ảnh chụp màn hình nếu có) | Mức độ | Issue | Đã sửa ở commit | Kiểm lại ngày (dd/mm/yyyy) | Kết quả kiểm lại |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |

## 10. Tổng kết lượt kiểm thử

| Phần | Số bước | Đạt | Không đạt | Bỏ qua |
| :--- | :--- | :--- | :--- | :--- |
| A — Quản trị | 18 | | | |
| B — Tổ chức | 20 | | | |
| C — Học viên | 20 | | | |
| D — Từ chối quyền | 26 | | | |
| Tổng | 84 | | | |

## 11. Biên bản nghiệm thu

Nghiệm thu đồ án tốt nghiệp FET3D, không phải chứng nhận PCCC.

| Mục | Điền |
| :--- | :--- |
| Ngày nghiệm thu (dd/mm/yyyy) | |
| Địa điểm | |
| Phiên bản đã kiểm (web, ứng dụng, runtime) | |
| Người kiểm thử (họ tên, vai trò) | |
| Người chứng kiến (họ tên, vai trò) | |
| Số bước Đạt / Không đạt / Bỏ qua | |
| Lỗi còn mở (số thứ tự ở mục 9) | |
| Kết luận (Chấp nhận / Chấp nhận kèm điều kiện / Không chấp nhận) | |
| Điều kiện kèm theo (nếu có) | |

| Vai trò | Họ tên | Chữ ký | Ngày (dd/mm/yyyy) |
| :--- | :--- | :--- | :--- |
| Người kiểm thử — Quản trị | | | |
| Người kiểm thử — Tổ chức | | | |
| Người kiểm thử — Học viên | | | |
| Người chứng kiến | | | |
| Trưởng nhóm | | | |
