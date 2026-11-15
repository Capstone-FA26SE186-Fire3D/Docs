# Hướng dẫn cho học viên

Hướng dẫn này dành cho người tham gia tập huấn thoát nạn bằng ứng dụng FET3D trên điện thoại Android: cài ứng dụng, đăng nhập, quét mã QR của tòa nhà, tải bài, chơi và đọc kết quả.

> **Nguồn và mức xác nhận.** Tên nút và câu chữ trong hướng dẫn lấy từ mã nguồn ứng dụng (Mobile `main` `3ada34b`) và trang web (FE `main` `7be3008`) của [bản phát hành 15/11/2026](release-manifest.md). Người viết chưa bấm lại từng bước trên điện thoại thật trong lần soạn này; chỗ nào chưa xác nhận trên màn hình thật được ghi **(chưa xác nhận trên máy)**.

## 1. Bạn cần gì

- Một điện thoại Android. Ứng dụng chưa có cho iPhone.
- Kết nối mạng khi đăng nhập, khi tải bài và khi bấm bắt đầu một lượt chơi mới.
- Mã QR của tòa nhà do tổ chức in hoặc gửi. Nếu tòa nhà ở chế độ Riêng tư, bạn cần thêm **mã tham gia** do tổ chức cung cấp.

Máy nhóm dùng để thử là Redmi Note 10S (Android 13). Trên máy tầm trung như vậy, điện thoại ấm lên khi chơi lâu; đây là giới hạn đã biết. Máy khác chưa được thử.

## 2. Cài ứng dụng

Ứng dụng FET3D **chưa có trên Google Play công khai**. Trang "Tải ứng dụng" trên web hiện ghi "Chưa khả dụng". Hiện có hai cách nhận ứng dụng, đều do nhóm FET3D gửi cho bạn:

1. Lời mời thử nghiệm trên Google Play: mở lời mời bằng tài khoản Google trên điện thoại rồi cài như một ứng dụng bình thường **(chưa xác nhận trên máy)**.
2. Tệp cài `.apk`: mở tệp trên điện thoại và cho phép cài đặt khi Android hỏi **(chưa xác nhận trên máy với người dùng ngoài nhóm)**.

Chỉ cần cài một lần. Các bài tập được tải về sau, từ trong ứng dụng.

## 3. Tạo tài khoản và đăng nhập

Mở ứng dụng, bạn thấy màn **Đăng nhập**.

**Đã có tài khoản:** nhập email và mật khẩu rồi bấm **Vào game**. Quên mật khẩu thì bấm **Quên mật khẩu?**.

**Chưa có tài khoản:** bấm **Chưa có tài khoản? Đăng ký** và làm ba bước của màn **Tạo tài khoản học viên**:

1. Nhập họ tên, email, tên đăng nhập (3–30 ký tự: chữ thường, số, dấu chấm, gạch dưới, gạch ngang), ngày sinh, giới tính; số điện thoại là tùy chọn. Bấm **Gửi mã xác minh**.
2. Mở email, lấy mã 6 chữ số và nhập vào. Chưa nhận được thì chờ hết thời gian đếm rồi bấm **Gửi lại mã**.
3. Đặt mật khẩu từ 12 đến 128 ký tự, nhập lại để xác nhận, đánh dấu ô xác nhận bạn hiểu FET3D là công cụ học tập, rồi bấm **Tạo tài khoản**. Sau đó đăng nhập bằng email và mật khẩu vừa tạo.

**Dùng Google:** bấm **Tiếp tục với Google**. Lần đầu, ứng dụng mở màn **Đăng ký bằng Google** để bạn chọn tên đăng nhập rồi bấm **Hoàn tất tài khoản**. Nếu email Google đó đã có tài khoản FET3D, ứng dụng nhắc bạn đăng nhập bằng mật khẩu rồi liên kết Google trong Cài đặt tài khoản.

Không muốn đăng nhập ngay, bạn vẫn đọc được bài học bằng dòng **Xem Learn không cần đăng nhập**.

## 4. Màn hình chính

Thanh dưới cùng có bốn mục: **Nhà**, **Bài học**, **Kết quả**, **Tôi**, và nút tròn **QUÉT** ở giữa. Nút **Hỏi AI** mở trợ lý trả lời về bài học và kết quả của bạn.

Ở mục **Nhà** bạn thấy:

- **Quét QR tòa nhà**: bắt đầu từ đây khi đến một tòa nhà mới.
- **Tòa nhà gần nhất**: mở lại tòa nhà vừa quét.
- **Bài đã tải**: các bài đã có trên máy.
- **Tiếp tục chơi**: hiện khi bạn còn một lượt chơi đang mở.
- Dòng trạng thái như "Bạn đang offline", "… chờ gửi" hoặc "Đã đồng bộ".

## 5. Quét mã QR của tòa nhà

1. Bấm **QUÉT** (hoặc **Quét QR tòa nhà**). Lần đầu, cho phép ứng dụng dùng camera.
2. Đưa mã QR vào khung. Chỗ tối thì bấm **Bật đèn**.
3. Không quét được thì bấm **Nhập mã thủ công** và dán đường dẫn dạng `https://fet3d.io.vn/qr/…` (hoặc đoạn mã 43 ký tự), rồi bấm **Mở tòa nhà**.

Sau khi quét, ứng dụng mở trang của tòa nhà với nhãn **Công khai** hoặc **Riêng tư**, tình trạng dịch vụ và danh sách bài.

| Bạn thấy | Nghĩa là | Việc cần làm |
| :--- | :--- | :--- |
| "Tòa nhà riêng tư" và ô **Mã tham gia** | Tòa nhà chỉ mở cho người có mã | Nhập mã tổ chức cung cấp rồi bấm **Xác minh mã** |
| "Mã tham gia không đúng hoặc đã bị đổi/thu hồi." | Mã sai hoặc tổ chức đã đổi mã | Hỏi lại tổ chức mã hiện hành |
| "Mã QR này đã bị thu hồi" | Tổ chức đã thay mã QR mới | Quét mã QR mới đang dán tại tòa nhà |
| "Không tìm thấy tòa nhà" | Mã không khớp tòa nhà nào | Kiểm tra lại mã hoặc liên hệ tổ chức |
| "Dịch vụ của tòa nhà đã hết hạn nên chưa thể bắt đầu phiên mới…" | Tổ chức chưa gia hạn dịch vụ | Bạn vẫn xem được danh sách bài; liên hệ tổ chức |
| "Chưa có bài tập được phát hành." | Tòa nhà chưa có bài nào | Chờ tổ chức phát hành bài |
| "Đây là mã chạy thử dành cho tài khoản tổ chức…" | Bạn quét nhầm mã chạy thử trên web | Quét mã QR của tòa nhà |

Mã QR chỉ cho ứng dụng biết đây là tòa nhà nào. Nó không thay việc đăng nhập và không tự cấp quyền vào tòa nhà Riêng tư.

Nếu quét mã QR bằng camera thường của điện thoại, trình duyệt mở trang web của tòa nhà. Trang này không tự mở ứng dụng: hãy mở ứng dụng FET3D và quét lại mã bằng nút **QUÉT** trong ứng dụng.

## 6. Chọn bài, tải về và bắt đầu

Bấm vào một bài trong danh sách. Màn **Chuẩn bị tập huấn** có ba bước: **CHẾ ĐỘ**, **TẢI GÓI**, **BẮT ĐẦU**.

**Bước 1 — Chọn cách chơi.**

| Cách chơi | Nội dung |
| :--- | :--- |
| **Học** | Làm quen tòa nhà, có hướng dẫn. Không chấm điểm. |
| **Diễn tập** | Gợi ý từng bước. Không chấm điểm. |
| **Đánh giá** | Tự xử lý, không có AI. Được chấm theo tiêu chí. |

Bạn tự chọn cách chơi, không bắt buộc phải Học hay Diễn tập trước khi Đánh giá. Cách chơi nào tổ chức không mở cho bài đó sẽ ghi "Kịch bản không mở chế độ này". Bấm **Chuẩn bị phiên**.

**Bước 2 — Tải gói nhiệm vụ.** Bấm **Tải gói nhiệm vụ**. Màn hình hiện tên nhiệm vụ, cách chơi, tòa nhà và dung lượng, rồi lần lượt báo "Kiểm tra phần đã tải", "Tải các tệp còn lại", "Kiểm tra tệp không bị lỗi", "Gói sẵn sàng". Muốn dừng thì bấm **Hủy tải**; lần sau ứng dụng tải tiếp phần còn thiếu. Chuẩn bị và tải gói chưa tính suất học viên của tòa nhà.

**Bước 3 — Bắt đầu.** Bấm **Bắt đầu phiên**. Bước này cần có mạng: lúc này hệ thống mới kiểm tra quyền của bạn và dịch vụ của tòa nhà. Nếu thấy "Tòa nhà đã hết suất", tòa nhà đã dùng hết số học viên trong kỳ dịch vụ; hãy liên hệ tổ chức.

Không có mạng thì ứng dụng báo: "Không có kết nối mạng. Cần mạng để chuẩn bị, tải gói và bắt đầu phiên mới."

## 7. Trong lúc chơi

Ứng dụng mở màn chơi 3D của tòa nhà. Bạn điều khiển một nhân vật nhìn từ phía sau.

- Thẻ giới thiệu đầu bài cho bạn chọn nhân vật **Nam** hoặc **Nữ**.
- Di chuyển trong tòa nhà, tìm lối thoát. Khi đến gần một vật dùng được (cửa, bình chữa cháy, chuông báo cháy, bồn nước…), nút thao tác của vật đó hiện ra; chạm một lần là nhân vật làm.
- Trên màn hình có nút gọi 114 và đèn pin điện thoại. Người khác trong tòa nhà có biểu tượng trạng thái trên đầu.
- Ở cách chơi Đánh giá, màn hình gọn hơn và không có gợi ý.

Nếu mất mạng sau khi đã bắt đầu, bạn vẫn chơi tiếp được. Kết quả được giữ trên máy và gửi đi khi có mạng lại.

Bố cục nút bấm chi tiết trong màn chơi không được mô tả ở đây vì chưa đối chiếu lại trên máy trong lần soạn này. Cách từng thiết bị hoạt động nằm ở [danh mục vật thể tương tác](ifc_ingestion_visual_interaction.md#6-danh-mục-vật-thể-tương-tác-catalog).

**Lưu ý an toàn:** đây là mô phỏng để tập huấn. Tác dụng của khăn ướt, chăn ướt, che mũi miệng, chèn khe cửa và chỗ trú tạm trong game chưa được chuyên gia PCCC thẩm tra. Khi có cháy thật, hãy làm theo hướng dẫn tại chỗ và gọi 114.

## 8. Đọc kết quả

Khi lượt chơi kết thúc, ứng dụng mở màn **Kết quả phiên**. Các lượt cũ nằm ở mục **Kết quả**.

| Kết quả | Nghĩa là |
| :--- | :--- |
| **Đạt** | "Bạn đạt mọi yêu cầu của bài đánh giá." |
| **Chưa đạt** | Điểm thấp hơn mức yêu cầu của bài, hoặc còn một tiêu chí bắt buộc chưa đạt. Màn hình ghi rõ lý do. |
| **Chưa hoàn thành** | Lượt chơi kết thúc trước khi hoàn thành tình huống. |
| **Không chấm điểm** | Bạn chơi cách Học hoặc Diễn tập, hoặc bài chưa có tiêu chí chấm. Chọn Đánh giá để được chấm. |
| **Chờ đồng bộ** | Kết quả đã lưu trên máy và sẽ được gửi khi có mạng. Chờ lâu thì bấm **Đồng bộ lại**. |

Bên dưới là từng tiêu chí của bài bằng tiếng Việt, ví dụ "Đến được lối thoát", "Kéo chuông báo cháy", "Gọi 114", "Dùng thang máy", "Đến điểm tập kết". Tiêu chí thiếu dữ liệu ghi "Chưa đủ dữ liệu đánh giá".

Hoàn thành một lượt chơi không có nghĩa là Đạt. Bạn được chơi lại không giới hạn. Kết quả do FET3D chấm cho mục đích học tập, không phải chứng nhận an toàn PCCC.

## 9. Chơi lại bài đã tải

Mục **Bài đã tải** liệt kê các gói nhiệm vụ đã lưu trên máy, kèm trạng thái "Sẵn sàng trên máy" hoặc "Tải dở, sẽ tải tiếp". Bấm **Chơi lại** để vào bài mà không phải tải lại gói.

Bài đã tải không có nghĩa là chơi được khi không có mạng: mỗi lượt chơi mới vẫn cần mạng ở bước bắt đầu. Nếu tổ chức đã đổi mã QR hoặc mã tham gia, ứng dụng sẽ nhắc bạn quét hoặc nhập lại.

## 10. Khi gặp trục trặc

| Tình huống | Cách xử lý |
| :--- | :--- |
| "Không kết nối được máy chủ FET3D. Kiểm tra mạng rồi thử lại." | Kiểm tra Wi-Fi hoặc dữ liệu di động rồi thử lại |
| "Màn chơi gặp lỗi và đã dừng…" | Thử lại; nếu vẫn lỗi, tải lại gói nhiệm vụ |
| "Lượt chơi đã đóng" | Bấm **Chơi lượt mới**, hoặc quét lại mã QR của tòa nhà |
| Cần người hỗ trợ | Mục **Tôi** → **Hỗ trợ & phản hồi** |
| Xem phiên bản ứng dụng | Mục **Tôi** → dòng **Phiên bản ứng dụng** |

## 11. Dùng trên web

Trên `fet3d.io.vn`, học viên đọc bài học, lưu bài, hỏi AI và xem lại lịch sử kết quả ở Góc học tập. Bài tập 3D không chạy trên web; nó chỉ chạy trong ứng dụng Android.
