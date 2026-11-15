# Kịch bản kiểm thử chấp nhận (UAT)

Kịch bản này để người kiểm thử đi qua ba vai trò của FET3D — Quản trị, Tổ chức, Học viên — theo đúng thứ tự một bài tập đi từ mô hình công trình tới kết quả của học viên, rồi thử các trường hợp phải bị từ chối quyền. Hai cột **Kết quả thực tế** và **Đạt?** để trống cho người kiểm thử điền.

> **Nguồn và mức xác nhận.** Các bước và kết quả mong đợi được viết từ [luồng nghiệp vụ](fire-evacuation-training-workflows.md), [tính năng](fire-evacuation-training-features.md) và mã nguồn của [bản phát hành 15/11/2026](release-manifest.md) (FE `7be3008`, Mobile `3ada34b`, BE `46716f8`). Câu chữ trong ngoặc kép là câu đọc được trong mã nguồn. **Chưa có bước nào trong bảng được chạy lại trên màn hình thật khi soạn tài liệu này**; mục 7 liệt kê những chỗ cần chú ý nhất khi chạy lần đầu.

## 1. Thông tin lượt kiểm thử

| Mục | Điền |
| :--- | :--- |
| Ngày kiểm thử | |
| Người kiểm thử | |
| Môi trường web (địa chỉ) | |
| Phiên bản ứng dụng (mục Tôi → Phiên bản ứng dụng) | |
| Điện thoại và phiên bản Android | |
| Phiên bản runtime đang bật (trang Phiên bản runtime) | |

## 2. Chuẩn bị

| Cần có | Ghi chú |
| :--- | :--- |
| Tài khoản quản trị (Admin) | Do nhóm cấp; không tự đăng ký được |
| Tài khoản tổ chức A | Dùng cho phần Tổ chức |
| Tài khoản tổ chức B | Chỉ dùng cho các ca từ chối quyền giữa hai tổ chức |
| Tài khoản học viên 1 và học viên 2 | Học viên 2 dùng cho ca Riêng tư và ca hết suất |
| Một tệp IFC | Ví dụ tệp trường học ở [IFC mục 10.1](ifc_ingestion_visual_interaction.md#101-hai-công-trình-nghiệm-thu) |
| Điện thoại Android đã cài ứng dụng FET3D | Xem [hướng dẫn học viên, mục 2](huong-dan-hoc-vien.md#2-cài-ứng-dụng) |
| Công trình của tổ chức A còn dịch vụ | Cần để phát hành và để học viên bắt đầu lượt chơi |

Quy ước cột **Đạt?**: ghi Đạt, Không đạt, hoặc Bỏ qua (kèm lý do ở cột Kết quả thực tế).

## 3. Phần A — Quản trị

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt? |
| :--- | :--- | :--- | :--- | :--- |
| A1 | Đăng nhập web bằng tài khoản quản trị | Web chuyển tới trang Tổng quan của khu Quản trị hệ thống; thanh bên có Duyệt kịch bản, Phiên bản runtime, Bài học, Thư viện mẫu | | |
| A2 | Mở **Phiên bản runtime** | Thấy danh sách phiên bản, mới nhất ở trên; phiên bản 2.5.0 có trạng thái "Đang dùng" | | |
| A3 | Bấm vào hàng 2.5.0 | Thấy danh sách năng lực của phiên bản, kèm sự kiện và thao tác; không có nút sửa nội dung | | |
| A4 | Bấm **Đăng ký phiên bản**, chọn một tệp không phải `.json` của runtime | Trang báo "Tệp chưa đúng" và không đăng ký được | | |
| A5 | Mở **Thư viện mẫu**, bấm **Thêm mục**, tạo một mục Tiêu chí chấm mẫu, **Tạo phiên bản**, lưu nháp rồi **Xuất bản** | Trang báo "Đã xuất bản phiên bản"; mục có "Bản tổ chức đang thấy" | | |
| A6 | Mở lại phiên bản vừa xuất bản | Phiên bản ghi "Đã xuất bản (không sửa được)"; chỉ có thể tạo Phiên bản mới | | |
| A7 | Bấm **Ngừng dùng** cho mục đó, rồi **Dùng lại** | Trang báo "Đã ngừng dùng mục" rồi "Đã dùng lại mục" | | |
| A8 | Mở **Bài học**, bấm **Bài mới**, tạo bài loại Bài viết với Xuất bản ngay đang tắt | Trang báo "Đã tạo bản nháp"; bài chưa hiện ở trang Bài học công khai | | |
| A9 | Xuất bản bài nháp đó | Bài hiện ở trang Bài học công khai khi chưa đăng nhập | | |
| A10 | **Ẩn bài**, kiểm tra trang công khai, rồi **Hiện lại** | Sau khi ẩn, bài không còn ở trang công khai; sau Hiện lại, bài có lại | | |
| A11 | **Xóa bài** rồi **Khôi phục** | Sau khôi phục, bài ở trạng thái Đã ẩn, không tự công khai | | |
| A12 | (Sau bước B9) Mở **Duyệt kịch bản**, lọc Chờ duyệt | Thấy phiên bản tổ chức A vừa gửi, có tên kịch bản, tổ chức · công trình và thời điểm gửi | | |
| A13 | Mở bản duyệt | Thấy Mục tiêu học tập, Hướng dẫn cho người học, Tiêu chí chấm điểm (ngưỡng đạt, trọng số, bắt buộc) và Nội dung kịch bản; tất cả chỉ đọc | | |
| A14 | Bấm **Từ chối**, để trống lý do | Không ghi được; trang yêu cầu "Nhập lý do từ chối (1–4000 ký tự)." | | |
| A15 | Bấm **Duyệt nội dung** và xác nhận | Trang báo "Đã duyệt nội dung"; hộp thoại đã nhắc duyệt nội dung không phải là phát hành | | |
| A16 | Mở lại bản vừa duyệt | Thấy "Quyết định đã được ghi và không đổi được."; không còn nút Duyệt hay Từ chối | | |

## 4. Phần B — Tổ chức

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt? |
| :--- | :--- | :--- | :--- | :--- |
| B1 | Đăng nhập web bằng tài khoản tổ chức A | Web chuyển tới trang **Công trình** của Không gian tổ chức | | |
| B2 | Tạo một công trình mới với tên và địa chỉ, rồi mở công trình | Công trình có các thẻ Thông tin, IFC và xử lý, Soạn kịch bản, Phiên bản, Chuẩn bị phát hành, Quản lý sử dụng | | |
| B3 | Ở thẻ **IFC và xử lý**, tải lên tệp IFC và chạy xử lý | Trạng thái xử lý cập nhật tới khi xong; hiện mô hình 3D và danh sách vấn đề (nếu có) | | |
| B4 | Nếu có nhắc chọn cửa thoát, bấm **Chọn cửa thoát** và chọn một cửa; xem danh sách thiết bị phát hiện được và xác nhận | Trang báo "Đã lưu quyết định thiết bị" | | |
| B5 | Bấm **Xác nhận mô hình dùng được cho huấn luyện** | Trang báo "Đã xác nhận mô hình dùng được cho huấn luyện" | | |
| B6 | Ở thẻ **Soạn kịch bản**, bấm **Tạo kịch bản**, mở trình soạn; đặt điểm xuất phát, nguồn lửa, thiết bị, mục tiêu và tiêu chí chấm; lưu | Bản nháp được lưu; trình soạn không có mục cấu hình gió | | |
| B7 | Bấm **Tạo phiên bản từ bản nháp** | Có phiên bản mới ở thẻ Phiên bản | | |
| B8 | Mở phần chạy thử của phiên bản: tạo lượt chạy thử, hiện mã QR "Chạy thử trên điện thoại". Trên điện thoại đăng nhập bằng tài khoản tổ chức A, bấm **Quét mã bàn giao**, quét mã, **Tải và kiểm tra gói**, **Bắt đầu chạy thử** | Web báo "Điện thoại đã nhận mã và đang giữ lượt chạy thử này."; màn chơi mở trên điện thoại; xong, ứng dụng báo "Đã gửi kết quả chạy thử. Xem kết quả trên web." | | |
| B9 | Bấm **Gửi duyệt nội dung** | Phiên bản chuyển sang trạng thái chờ quản trị duyệt; không sửa được nội dung phiên bản đó nữa | | |
| B10 | (Sau bước A15) Ở thẻ **Chuẩn bị phát hành**, bấm **Phát hành và tạo mã QR** | Bài được phát hành; công trình có mã QR đang hoạt động; có thể sao chép liên kết QR dạng `https://fet3d.io.vn/qr/…` | | |
| B11 | Bấm tạo mã QR lần nữa cho cùng công trình | Trang báo "Công trình đã có mã QR đang hoạt động" | | |
| B12 | Ở phần **Quyền tham gia**, đổi sang **Riêng tư (cần mã tham gia)** và tạo mã tham gia | Có mã tham gia; sao chép được ("Đã sao chép mã tham gia") | | |
| B13 | (Sau phần C) Mở **Báo cáo**, chọn khoảng thời gian có lượt chơi | Số lượt chơi và số học viên khớp với các lượt đã chơi ở phần C; lượt chạy thử ở B8 không được tính | | |
| B14 | Ở báo cáo Huấn luyện, bấm **Xuất CSV** | Tải được tệp `.csv`; tệp chỉ có dòng tổng hợp theo nhóm, không có tên hay email học viên | | |
| B15 | Bấm **Tạo lại mã QR** (xác nhận trong hộp thoại) | Có mã QR mới; mã cũ không còn dùng được (kiểm ở ca D8) | | |

## 5. Phần C — Học viên

| # | Bước | Kết quả mong đợi | Kết quả thực tế | Đạt? |
| :--- | :--- | :--- | :--- | :--- |
| C1 | Mở ứng dụng, bấm **Chưa có tài khoản? Đăng ký**, làm ba bước với email thật | Nhận được email có mã 6 chữ số; sau bước 3, tài khoản được tạo | | |
| C2 | Đăng nhập bằng email và mật khẩu vừa tạo | Vào mục **Nhà**; thanh dưới có Nhà, Bài học, Kết quả, Tôi và nút QUÉT | | |
| C3 | Bấm **QUÉT**, quét mã QR của công trình (đang Công khai) | Mở trang tòa nhà có nhãn Công khai và danh sách bài đã phát hành | | |
| C4 | Chọn bài, chọn **Học**, bấm **Chuẩn bị phiên** rồi **Tải gói nhiệm vụ** | Thanh tải chạy tới "Gói sẵn sàng" | | |
| C5 | Bấm **Bắt đầu phiên** | Màn chơi 3D mở; thẻ giới thiệu cho chọn nhân vật Nam hoặc Nữ | | |
| C6 | Chơi tới khi ra khỏi tòa nhà | Màn **Kết quả phiên** hiện "Không chấm điểm" (cách Học không chấm Đạt/Chưa đạt) | | |
| C7 | Vào lại bài, chọn **Đánh giá**, chơi hết bài | Kết quả là Đạt hoặc Chưa đạt, có lý do và danh sách tiêu chí bằng tiếng Việt | | |
| C8 | Trong một lượt Đánh giá, thử mở Hỏi AI | Không dùng được AI trong lượt Đánh giá | | |
| C9 | Bắt đầu một lượt chơi, tắt mạng giữa chừng, chơi hết | Vẫn chơi được tới hết; kết quả ghi "Kết quả đã lưu trên máy" hoặc "Chờ đồng bộ" | | |
| C10 | Bật mạng lại, mở mục **Kết quả** | Lượt chơi ở C9 được gửi lên và hiện kết quả | | |
| C11 | Tắt mạng, vào **Bài đã tải**, bấm **Chơi lại** | Bài hiện "Sẵn sàng trên máy" nhưng không bắt đầu được lượt mới; ứng dụng báo cần mạng | | |
| C12 | Mở mục **Bài học** khi đã đăng xuất | Đọc được bài công khai không cần đăng nhập | | |
| C13 | Đăng nhập web bằng tài khoản học viên | Web chuyển tới Góc học tập; xem được lịch sử kết quả của chính mình | | |

## 6. Phần D — Các trường hợp phải bị từ chối

Mỗi ca dưới đây đạt khi hệ thống **chặn** thao tác và hiện thông báo dễ hiểu, không lộ dữ liệu của người khác.

| # | Vai trò | Thao tác | Kết quả mong đợi | Kết quả thực tế | Đạt? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| D1 | Học viên | Trên web, gõ thẳng địa chỉ `/admin/reviews` | "Không có quyền truy cập" — "Chỉ quản trị FET3D duyệt được kịch bản." | | |
| D2 | Tổ chức | Gõ thẳng địa chỉ `/admin/runtime` | "Không có quyền truy cập" — "Chỉ quản trị FET3D có thể quản lý phiên bản chương trình mô phỏng." | | |
| D3 | Tổ chức | Gõ thẳng địa chỉ `/admin/learn` và `/admin/library` | "Không có quyền truy cập" ở cả hai trang | | |
| D4 | Học viên | Gõ thẳng địa chỉ `/workspace/ifc` | "Không có quyền truy cập" — "Tài khoản học viên không có quyền chuẩn bị mô hình IFC." | | |
| D5 | Học viên hoặc Quản trị | Gõ thẳng địa chỉ `/workspace/billing` | "Không có quyền truy cập" — "Khu này dành cho tài khoản tổ chức." | | |
| D6 | Học viên | Gõ thẳng địa chỉ `/workspace/analytics` | "Không có quyền truy cập" — "Báo cáo này dành cho tài khoản tổ chức." | | |
| D7 | Tổ chức B | Mở liên kết QR của công trình thuộc tổ chức A | "Không tìm thấy công trình"; không hiện tên công trình của tổ chức A | | |
| D8 | Học viên | Quét mã QR cũ sau bước B15 | Ứng dụng báo "Mã QR này đã bị thu hồi" và nhắc quét mã mới | | |
| D9 | Người chưa đăng nhập | Mở liên kết QR trên trình duyệt | "Đăng nhập để xem công trình"; không hiện danh sách bài | | |
| D10 | Học viên 2 | Quét mã QR khi công trình đang Riêng tư, chưa nhập mã tham gia | Thấy "Tòa nhà riêng tư" và ô Mã tham gia; không thấy danh sách bài để chơi | | |
| D11 | Học viên 2 | Nhập sai mã tham gia | "Mã tham gia không đúng hoặc đã bị đổi/thu hồi." | | |
| D12 | Học viên 2 | Sau khi vào được bằng mã đúng, tổ chức tạo mã tham gia mới; học viên mở lại bài | Ứng dụng báo "Quyền vào tòa nhà đã thay đổi" và yêu cầu nhập mã mới | | |
| D13 | Học viên | Quét mã chạy thử (mã ở bước B8) bằng nút QUÉT | "Đây là mã chạy thử dành cho tài khoản tổ chức, không phải mã công trình…" | | |
| D14 | Tổ chức | Trong ứng dụng, quét mã QR công trình ở màn Quét mã bàn giao | "Đây là mã QR công trình dành cho học viên…" | | |
| D15 | Học viên | Bấm **Bắt đầu phiên** khi công trình đã hết suất học viên của kỳ | Màn "Tòa nhà đã hết suất"; không vào được màn chơi | | |
| D16 | Học viên | Mở công trình đã hết hạn dịch vụ | Xem được danh sách bài nhưng không bắt đầu được lượt mới; có dòng giải thích dịch vụ đã hết hạn | | |
| D17 | Tổ chức | Bấm lưu một bài học công khai | "Chỉ tài khoản học viên mới lưu được bài." | | |
| D18 | Quản trị | Mở một báo giá của tổ chức và tìm nút thanh toán | Không thanh toán được thay tổ chức: "Quản trị FET3D có thể xem trạng thái nhưng không tạo thanh toán thay tổ chức." | | |
| D19 | Quản trị (hai người) | Hai quản trị cùng mở một bản chờ duyệt; người thứ hai quyết định sau người thứ nhất | Người thứ hai được báo bản này "không còn ở trạng thái chờ duyệt"; quyết định đầu giữ nguyên | | |
| D20 | Tổ chức | Xuất CSV báo cáo lần thứ 11 trong cùng một ngày | Bị từ chối vì quá 10 lần xuất mỗi ngày; không tải được tệp | | |
| D21 | Tổ chức | Chọn khoảng thời gian báo cáo dài hơn 90 ngày | Không xem được báo cáo cho khoảng đó; trang báo khoảng thời gian không hợp lệ | | |
| D22 | Quản trị | Đăng nhập ứng dụng điện thoại bằng tài khoản quản trị | Không vào được khu học viên hay khu chạy thử (ứng dụng chỉ dành cho học viên và tổ chức) | | |
| D23 | Tổ chức | Phát hành một phiên bản chưa được quản trị duyệt | Không phát hành được | | |
| D24 | Tổ chức | Sửa nội dung một phiên bản đã được duyệt | Không sửa được phiên bản đó; phải tạo phiên bản mới và gửi duyệt lại | | |

## 7. Chỗ chưa xác nhận trên màn hình thật

Người kiểm thử lần đầu cần chú ý và ghi lại câu chữ thật ở các chỗ sau, vì tài liệu này chỉ biết quy tắc mà chưa thấy màn hình:

- B2: tên nút tạo công trình và các ô phải nhập.
- B3: tên các bước xử lý IFC hiện trên màn hình và thời gian xử lý.
- B8: tên thẻ và nút tạo lượt chạy thử trên web (mã nguồn chỉ cho biết tiêu đề "Chạy thử trên điện thoại" và lời nhắc mã có hạn 5 phút).
- B9: nhãn trạng thái chính xác của phiên bản sau khi gửi duyệt.
- B12: vị trí phần Quyền tham gia trong trang công trình.
- C8: cách ứng dụng chặn Hỏi AI trong lượt Đánh giá (ẩn nút hay báo lỗi).
- C11: câu báo chính xác khi bấm Chơi lại lúc không có mạng.
- D16, D20, D21, D22, D23, D24: quy tắc có trong máy chủ hoặc tài liệu nghiệp vụ, nhưng câu thông báo trên màn hình chưa đọc được trong mã nguồn.
- Toàn bộ phần C chưa chạy lại trên điện thoại khác ngoài máy nghiệm thu của nhóm.

## 8. Tổng kết lượt kiểm thử

| Phần | Số bước | Đạt | Không đạt | Bỏ qua |
| :--- | :--- | :--- | :--- | :--- |
| A — Quản trị | 16 | | | |
| B — Tổ chức | 15 | | | |
| C — Học viên | 13 | | | |
| D — Từ chối quyền | 24 | | | |

Lỗi tìm thấy (mô tả ngắn, bước liên quan, ảnh chụp màn hình nếu có):

| # | Bước | Mô tả | Mức độ |
| :--- | :--- | :--- | :--- |
| | | | |
