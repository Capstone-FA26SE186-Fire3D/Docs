# Hướng dẫn cho quản trị FET3D

Hướng dẫn này dành cho người giữ tài khoản quản trị FET3D (vai trò PlatformAdmin). Nó nói về bốn việc: duyệt kịch bản của tổ chức, quản lý phiên bản runtime, quản lý thư viện mẫu và quản lý bài học công khai.

> **Nguồn và mức xác nhận.** Tên trang, tên nút và câu chữ lấy từ mã nguồn web (FE `main` `7be3008`) của [bản phát hành 15/11/2026](release-manifest.md) và từ [luồng nghiệp vụ](fire-evacuation-training-workflows.md). Người viết chưa bấm lại từng bước trên trang production trong lần soạn này; chỗ nào chưa xác nhận trên màn hình thật được ghi **(chưa xác nhận trên màn hình thật)**.

## 1. Vào khu quản trị

1. Mở `https://fet3d.io.vn` và đăng nhập bằng tài khoản quản trị. Sau khi đăng nhập, web tự đưa bạn tới trang **Tổng quan** của khu **Quản trị hệ thống**.
2. Thanh bên trái chia theo nhóm:

| Nhóm | Mục |
| :--- | :--- |
| Xử lý công việc | Tổng quan · **Duyệt kịch bản** · Hỗ trợ & nhật ký |
| Quản lý hệ thống | Tài khoản · Tổ chức · **Phiên bản runtime** |
| Quản lý nội dung | **Bài học** · **Thư viện mẫu** · AI & nguồn tri thức |
| Thương mại | Dịch vụ & thanh toán |

Tài khoản không phải quản trị mở các trang này sẽ thấy "Không có quyền truy cập". Tài khoản quản trị không tạo được bằng màn đăng ký hay bằng Google.

## 2. Duyệt kịch bản và phát hành nội dung

### 2.1. Ai làm gì

Một bài tập đến tay học viên qua các bước sau. Quản trị chỉ làm bước 3.

| Bước | Người làm | Việc |
| :--- | :--- | :--- |
| 1 | Tổ chức | Tải mô hình IFC, xác nhận mô hình dùng được cho huấn luyện, soạn kịch bản và tiêu chí chấm |
| 2 | Tổ chức | Tạo phiên bản từ bản nháp, chạy thử, rồi **Gửi duyệt nội dung** |
| 3 | **Quản trị** | **Duyệt nội dung** hoặc **Từ chối** đúng phiên bản đó |
| 4 | Tổ chức | **Phát hành và tạo mã QR** khi nội dung đã được duyệt, điều kiện kỹ thuật đã đạt và công trình còn dịch vụ |

Duyệt nội dung **không phải** là phát hành: sau khi bạn duyệt, tổ chức mới là bên bấm phát hành. Việc duyệt cũng không phải là chứng nhận an toàn PCCC.

### 2.2. Các bước duyệt

1. Mở **Duyệt kịch bản**. Trang hiện hàng chờ với các cột Kịch bản, Tổ chức · Công trình, Gửi lúc, Trạng thái. Lọc theo trạng thái **Chờ duyệt**, **Đã duyệt**, **Từ chối**, hoặc theo tổ chức. Ô tìm chỉ lọc trong trang đang xem.
2. Bấm một hàng để mở bản duyệt. Bạn thấy nội dung đã khóa của phiên bản:
   - **Mục tiêu học tập** và **Hướng dẫn cho người học**;
   - **Tiêu chí chấm điểm**: ngưỡng đạt, từng tiêu chí, điều kiện, trọng số và tiêu chí nào bắt buộc;
   - **Nội dung kịch bản**: tóm tắt theo từng phần, mở từng mục để xem dữ liệu gốc (chỉ đọc);
   - Thông tin bản duyệt: người gửi, thời điểm gửi, và mã nội dung dành cho bộ phận hỗ trợ.
3. Nếu thấy nhãn "Chưa đủ điều kiện kỹ thuật": bạn vẫn duyệt được nội dung, nhưng phiên bản chưa phát hành được cho tới khi tổ chức hoàn tất phần kỹ thuật.
4. Quyết định:
   - **Duyệt nội dung**: bạn duyệt đúng nội dung và tiêu chí chấm đang xem.
   - **Từ chối**: nhập lý do từ 1 đến 4 000 ký tự. Tổ chức đọc được lý do này.
5. Xác nhận trong hộp thoại. Trang báo "Đã duyệt nội dung" hoặc "Đã từ chối phiên bản".

Cần nhớ:

- **Quyết định không đổi được.** Từ chối là quyết định cuối cùng của phiên bản đó; tổ chức phải sửa bản nháp, tạo phiên bản mới và gửi duyệt lại. Nội dung đã duyệt mà thay đổi thì cũng phải qua phiên bản mới.
- Nếu mạng chập chờn khi bạn bấm, trang báo "Chưa xác nhận được quyết định". Bấm **Thử lại** là an toàn: quyết định không bị ghi hai lần.
- Nếu trang báo bản này "không còn ở trạng thái chờ duyệt", đã có quyết định trước đó (ví dụ từ một quản trị khác); trang tự tải lại trạng thái đúng.

## 3. Phiên bản runtime

"Runtime" là phiên bản chương trình mô phỏng nằm trong ứng dụng FET3D trên điện thoại. Mỗi phiên bản ghi những năng lực (thiết bị, sự kiện, thao tác) mà ứng dụng hỗ trợ. Trình soạn kịch bản, lượt chạy thử và buổi huấn luyện mới chỉ dùng được phiên bản đang bật.

Bản đang dùng của đợt phát hành 15/11/2026 là **2.5.0**; tệp để đăng ký là `Unity/Tools/RuntimeCatalog/runtime-2.5.0.json` trong repo Unity (xem [release-manifest.md](release-manifest.md)).

### 3.1. Đăng ký một phiên bản mới

Làm việc này khi nhóm phát triển giao một phiên bản runtime mới kèm tệp `runtime-<phiên bản>.json`.

1. Mở **Phiên bản runtime** và bấm **Đăng ký phiên bản**.
2. Chọn tệp `.json` nhóm phát triển giao (tối đa 2 MB). Không sửa tay tệp này. Tệp chỉ được đọc trong trình duyệt để xem trước; chưa có gì được gửi cho tới khi bạn bấm Đăng ký.
3. Kiểm tra phần xem trước: Phiên bản, Số năng lực, Giao thức kết nối, Định dạng gói bài.
4. Chọn trạng thái sau khi đăng ký. Mặc định là **Tắt (bật sau)**; gạt **Kích hoạt ngay** nếu muốn dùng ngay.
5. Bấm **Đăng ký**. Trang báo "Đã đăng ký phiên bản".

Phiên bản đã đăng ký không sửa được, chỉ bật hoặc tắt được.

### 3.2. Bật hoặc tắt một phiên bản

1. Trong danh sách (mới nhất ở trên), dùng cột **Bật / tắt** của phiên bản cần đổi.
2. Đọc hộp thoại xác nhận rồi bấm **Bật phiên bản** hoặc **Tắt phiên bản**.

Khi tắt một phiên bản: không ai bắt đầu được lượt chạy thử hay buổi huấn luyện **mới** trên phiên bản đó, và trình soạn không chọn được nó nữa. Gói bài và buổi học đã gắn với phiên bản đó giữ nguyên.

Bấm vào một hàng để xem danh sách năng lực của phiên bản, kèm sự kiện, thao tác và việc năng lực đó có được chấm điểm hay không.

### 3.3. Thứ tự khi ra phiên bản mới

Theo cách nhóm đã làm với 2.5.0:

1. Đăng ký và bật phiên bản mới ở trang này.
2. Sau đó mới phát hành ứng dụng điện thoại mang runtime mới.

Lý do: ứng dụng chỉ vào được bài khi phiên bản runtime của nó đang bật trên máy chủ, và máy dựng gói bài cũng dùng phiên bản mới ngay khi có. Không tắt phiên bản mà ứng dụng đang phát hành còn dùng.

## 4. Thư viện mẫu

Thư viện mẫu là nơi quản trị cung cấp nội dung chuẩn để tổ chức dùng khi soạn bài. Có ba loại mục:

| Loại | Dùng để |
| :--- | :--- |
| **Kịch bản mẫu** | Tổ chức lấy làm điểm bắt đầu rồi chỉnh theo công trình của mình |
| **Tiêu chí chấm mẫu** | Bộ tiêu chí gợi ý; tổ chức chỉnh rồi gửi duyệt cùng kịch bản |
| **Thiết bị** | Thiết bị mà ứng dụng hỗ trợ, để tổ chức đặt vào kịch bản |

Thư viện không có dữ liệu sẵn: mục chỉ hiện cho tổ chức khi có ít nhất một phiên bản đã xuất bản.

### 4.1. Thêm một mục và xuất bản

1. Mở **Thư viện mẫu** và bấm **Thêm mục**. Chọn loại mục và nhập thông tin của mục.
2. Mở mục, bấm **Tạo phiên bản**, nhập nội dung.
3. Lưu bản nháp, rồi bấm **Xuất bản**. Trang báo "Đã xuất bản phiên bản".

Mọi thao tác thêm và sửa diễn ra trong cửa sổ mở giữa trang.

### 4.2. Sửa nội dung

Bản đã xuất bản không sửa được. Muốn đổi nội dung, tạo **Phiên bản mới**, sửa rồi xuất bản; tổ chức sẽ thấy bản mới nhất đã xuất bản ("Bản tổ chức đang thấy"). Kịch bản đã dùng bản cũ không bị ảnh hưởng.

### 4.3. Ngừng dùng và dùng lại

- **Ngừng dùng**: tổ chức không còn thấy mục khi chọn mẫu mới. Các phiên bản đã xuất bản vẫn đọc được, nên kịch bản đã dùng không bị ảnh hưởng.
- **Dùng lại**: nếu mục có phiên bản đã xuất bản, tổ chức thấy lại mục trong danh sách chọn.

Lưu ý: thêm một mục Thiết bị vào thư viện không làm ứng dụng có thêm tính năng. Thiết bị chỉ dùng được khi phiên bản runtime đang bật có năng lực tương ứng (mục 3).

## 5. Bài học (Learn)

Bài học là phần đọc công khai trên web và trong ứng dụng: bài viết, mẹo và video. Ai cũng đọc được mà không cần đăng nhập. Bài học **không cần qua bước duyệt**: quản trị tự soạn và tự xuất bản.

### 5.1. Tạo bài

1. Mở **Bài học** và bấm **Bài mới**.
2. Chọn **Loại bài**, nhập **Tiêu đề**, **Tóm tắt** (một–hai câu), chọn **Tình huống**, và đoạn văn mở đầu. Ảnh bìa là tùy chọn.
3. Chọn một trong hai:
   - Tắt **Xuất bản ngay** → **Tạo và mở trình soạn**: bài lưu thành bản nháp, chưa ai thấy.
   - Bật **Xuất bản ngay** → **Tạo và xuất bản ngay**: bài công khai ngay khi tạo xong.
4. Trong trình soạn, thêm tiêu đề phụ, danh sách, khung lưu ý, ảnh, video. Gõ "/" để chèn nhanh một khối.

Quy định về nội dung:

- Ảnh tải lên: JPG, PNG hoặc WebP, tối đa 5 MB và 4096 × 4096 điểm ảnh; cũng có thể dán đường dẫn ảnh `https`. Nhập **Mô tả ảnh** cho người dùng trình đọc màn hình.
- Bài loại Video cần ít nhất một khối video.
- **Nguồn trích dẫn** không bắt buộc. Bản nháp được trích nguồn chưa duyệt, nhưng chỉ xuất bản được khi mọi nguồn đã được duyệt và còn hiệu lực.
- **Tình huống** dùng để lọc bài công khai. Tạo tình huống ở thẻ "Tình huống"; hiện chưa sửa hay ngừng dùng được tình huống sau khi tạo.

### 5.2. Xuất bản và sửa bài đã xuất bản

1. Lưu bản nháp trước ("Đã lưu bản nháp").
2. Ở phần **Phiên bản & Xuất bản**, bấm xuất bản. Bản nháp trở thành bản công khai và không sửa được nữa.
3. Muốn sửa tiếp, tạo bản nháp mới từ nội dung đang hiển thị, sửa, rồi xuất bản lại. Trong lúc đó bản công khai hiện tại giữ nguyên.

### 5.3. Ẩn, hiện lại, xóa, khôi phục

| Thao tác | Kết quả |
| :--- | :--- |
| **Ẩn bài** | Bài không còn công khai. Bài ẩn vẫn có thể được trợ lý AI dùng làm nguồn trả lời |
| **Hiện lại** | Bài công khai trở lại |
| **Xóa bài** | Bài không công khai và AI không còn dùng. Lịch sử vẫn được giữ |
| **Khôi phục** | Bài từng xuất bản quay về trạng thái Đã ẩn, không tự công khai; bấm **Hiện lại** nếu muốn công khai. Phải khôi phục trước khi sửa, tạo bản nháp hay xuất bản |

Thao tác nào bấm được tùy theo trạng thái hiện tại của bài.

## 6. Việc chưa nằm trong hướng dẫn này

Các trang Tài khoản, Tổ chức, AI & nguồn tri thức, Dịch vụ & thanh toán, Hỗ trợ & nhật ký chưa được viết hướng dẫn trong đợt này. Luồng nghiệp vụ của chúng nằm ở [fire-evacuation-training-workflows.md](fire-evacuation-training-workflows.md).

## 7. Chưa xác nhận trên màn hình thật

- Toàn bộ các bước ở mục 2–5 được viết từ mã nguồn, chưa bấm lại trên production trong lần soạn này.
- Các ô nhập cụ thể trong cửa sổ **Thêm mục** của Thư viện mẫu (mục 4.1, bước 1).
- Vị trí chính xác của nút xuất bản trong phần **Phiên bản & Xuất bản** của trình soạn bài học (mục 5.2).
