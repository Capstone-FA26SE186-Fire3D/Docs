# Danh Mục Tài Liệu Dự Án (Docs)

Thư mục này chứa toàn bộ các tài liệu đặc tả, thiết kế cơ sở dữ liệu và luồng nghiệp vụ cho dự án **Fire Evacuation Training 3D**. 

Dưới đây là mô tả ngắn gọn cho từng file để dễ dàng tra cứu:

### 1. Tài Liệu Đặc Tả & Thiết Kế (Markdown)
* **ire-evacuation-training-features.md**
  Đặc tả chi tiết các tính năng của sản phẩm, phân quyền người dùng, các chế độ huấn luyện (Learn, Guided Drill, Assessment), và định vị sản phẩm.
* **ire-evacuation-training-technology.md**
  Đặc tả kỹ thuật hệ thống, kiến trúc tổng thể, stack công nghệ (ASP.NET Core, Flutter, Unity, PostgreSQL), logic định tuyến A* và các ràng buộc kỹ thuật.
* **ire-evacuation-training-workflows.md**
  Mô tả chi tiết các luồng nghiệp vụ (User Flow & System Flow) - từ khi BIM Operator tải bản vẽ lên cho đến khi kết thúc một buổi tập huấn và xuất báo cáo.
* **ire_evacuation_requirements.md**
  Tài liệu Requirements tổng hợp các yêu cầu chức năng (FR) và phi chức năng (NFR) của hệ thống.

### 2. Thiết Kế Cơ Sở Dữ Liệu (Database)
* **ire_evacuation_schema.sql**
  Script PostgreSQL hoàn chỉnh (v3.0) tạo 23 bảng, các kiểu ENUM, index, rules và trigger cho hệ thống. Dùng để deploy trực tiếp vào DB.
* **ire_evacuation_erd.md**
  Mã nguồn sơ đồ Mermaid (ERD v3.0) thể hiện trực quan các bảng và mối quan hệ trong CSDL. (Copy nội dung dán vào mermaid.live để xem ảnh).

### 3. Tài Liệu Cũ / Khởi Tạo
* **3D-Fire-Evacuation-Training-IDEA2.docx**
  Bản phác thảo ý tưởng gốc và mô tả chung ban đầu của dự án.
