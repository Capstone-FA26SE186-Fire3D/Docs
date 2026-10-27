# Sinh lại thư mục ERD

Dành cho người có quyền đọc database production (repo BE).

1. Xuất schema (chỉ đọc metadata, không đọc dữ liệu):
   ```
   psql "<connection string>" -X -v ON_ERROR_STOP=1 -f schema_export.sql > schema.json
   ```
2. Nếu có bảng mới, thêm tên bảng vào đúng nhóm trong `groups.json`. Bảng `*_command_receipts` tự vào nhóm B12.
   Script sẽ dừng và in tên bảng chưa có nhóm.
3. Nếu bảng mới là đối tượng nghiệp vụ, thêm thực thể logical vào `erd_lp.py` (hàm `E(...)` và một dòng quan hệ trong `DOM(...)`).
   Nếu là bảng kỹ thuật, thêm vào danh sách `EXCLUDED`. Script cũng dừng nếu một bảng chưa được xếp.
4. Chạy (Python 3.12+, không cần thư viện ngoài):
   ```
   python erd_lp.py schema.json groups.json ..
   ```
   Lệnh này ghi đè `1-Logical.md`, `2-Physical.md`, `Fire3D-Physical.dbml` và `dbml-theo-nhom/`.
   `0-Ke-hoach-ve.md` viết tay, cần tự cập nhật số liệu.
