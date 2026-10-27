# Kế hoạch vẽ ERD Logical & Physical — Fire3D

Bạn cần vẽ hai bộ sơ đồ cho báo cáo:

- **Logical:** 9 hình.
- **Physical:** 12 hình, có thể thành 14 nếu tách hai nhóm lớn.

Mọi nội dung (thực thể, cột, kiểu, khóa, bản số) đã lấy từ database thật trên production (Supabase Singapore, đối chiếu ngày 27/10/2026, 136 migration, đã tính đợt dọn dẹp cùng ngày; xem mục 7). Việc của bạn là **vẽ cho đẹp và đúng**, không cần tự thiết kế lại.

## 1. Trong thư mục có gì

| File | Dùng để |
|---|---|
| `0-Ke-hoach-ve.md` | File này: vẽ gì, thứ tự, quy ước, kiểm tra. |
| `1-Logical.md` | Đọc **trước**. Gồm ký hiệu bản số, logical khác physical ở đâu, 9 sơ đồ logical (A0–A8), từ điển thực thể, và các bảng không đưa vào logical. |
| `2-Physical.md` | Quy ước physical, 16 kiểu enum, 12 sơ đồ physical (B1–B12), đủ cột, kiểu, PK/FK/UK, NULL. |
| `dbml-theo-nhom/B01…B12.dbml` | Mỗi nhóm physical một file để dán vào dbdiagram.io. Bảng màu xám là bảng của nhóm khác, chỉ giữ cột khóa. |
| `Fire3D-Physical.dbml` | Toàn bộ 112 bảng trong một file, đã chia sẵn 12 `TableGroup`. Dùng để tra cứu, **không** dùng để vẽ một hình duy nhất: 112 bảng trên một trang thì không đọc được. |

Mở file `.md` bằng VS Code (bấm `Ctrl+Shift+V` để xem sơ đồ) hoặc GitHub. Nếu không thấy hình, dán khối ` ```mermaid ` vào [mermaid.live](https://mermaid.live).

## 2. Danh sách hình cần vẽ

### Logical (công cụ: draw.io)

| Hình | Nội dung | Lấy từ | Độ lớn |
|---|---|---|---|
| L0 | Tổng quan trục nghiệp vụ, chỉ tên thực thể | `1-Logical.md` → A0 | 23 thực thể, 27 quan hệ |
| L1 | Tổ chức, người dùng & công trình | A1 | 7 thực thể, 8 quan hệ |
| L2 | Mô hình IFC & xử lý | A2 | 12 + 3 tham chiếu, 19 quan hệ |
| L3 | Kịch bản & chơi thử | A3 | 7 + 4 tham chiếu, 12 quan hệ |
| L4 | Phát hành, huấn luyện & phiên học | A4 | 7 + 7 tham chiếu, 14 quan hệ |
| L5 | Báo giá, thanh toán & dịch vụ | A5 | 14 + 3 tham chiếu, 26 quan hệ |
| L6 | AI & kho tri thức | A6 | 4 + 3 tham chiếu, 7 quan hệ |
| L7 | Learn & thư viện | A7 | 5 + 2 tham chiếu, 8 quan hệ |
| L8 | Hỗ trợ, thông báo & audit | A8 | 7 + 4 tham chiếu, 15 quan hệ |

"Tham chiếu" là thực thể đã vẽ đầy đủ ở hình khác. Hình này chỉ vẽ nó với ô `id` để nối dây.

### Physical (công cụ: dbdiagram.io)

| Hình | Nhóm | File để dán | Độ lớn |
|---|---|---|---|
| P1 | Định danh & phiên đăng nhập | `B01-dinh-danh-phien-dang-nhap.dbml` | 14 bảng, 9 FK |
| P2 | Công trình & quyền truy cập | `B02-cong-trinh-quyen-truy-cap.dbml` | 5 bảng (+2 xám), 10 FK |
| P3 | IFC & xử lý (worker) | `B03-ifc-xu-ly-worker.dbml` | 16 bảng (+4), 38 FK — **nên tách đôi** |
| P4 | Outbox & giao job | `B04-outbox-giao-job-redis-http.dbml` | 7 bảng (+3), 8 FK |
| P5 | Kịch bản & playtest | `B05-kich-ban-playtest.dbml` | 10 bảng (+7), 28 FK |
| P6 | Phát hành & bài huấn luyện | `B06-phat-hanh-bai-huan-luyen.dbml` | 4 bảng (+8), 14 FK |
| P7 | Phiên học viên & chấm điểm | `B07-phien-hoc-vien-cham-diem.dbml` | 5 bảng (+6), 16 FK |
| P8 | Báo giá, PayOS & dịch vụ | `B08-bao-gia-payos-dich-vu.dbml` | 19 bảng (+3), 62 FK — **nên tách đôi** |
| P9 | AI & kho tri thức | `B09-ai-kho-tri-thuc.dbml` | 5 bảng (+2), 11 FK |
| P10 | Learn & thư viện tổ chức | `B10-learn-thu-vien-to-chuc.dbml` | 9 bảng (+2), 17 FK |
| P11 | Hỗ trợ, thông báo, audit | `B11-ho-tro-thong-bao-audit.dbml` | 7 bảng (+5), 18 FK |
| P12 | Biên nhận idempotency | `B12-bien-nhan-idempotency.dbml` | 11 bảng (+3), 13 FK |

**Cách tách hai nhóm lớn** nếu một trang A4 không đủ chỗ. Bảng ngoài phần đang vẽ thì để màu xám, chỉ giữ cột khóa.

- **P3a — Tải lên & xử lý:**
  - `revisions`, `source_documents`
  - `ifc_upload_intents`, `ifc_upload_attempts`, `ifc_object_cleanup`
  - `processing_jobs`, `processing_job_attempts`, `processing_candidate_outputs`
  - `revision_artifacts`
- **P3b — Kiểm tra & duyệt:**
  - `validation_runs`, `revision_issues`, `bim_facts`, `annotation_sets`
  - `revision_equipment_decisions`, `revision_style_selections`, `revision_reviews`
- **P8a — Bán hàng:**
  - `service_packages`, `service_package_discount_rules`, `billing_quota_policy_versions`
  - `quotations`, `quotation_building_items`, `quotation_topup_items`
  - `enterprise_quote_requests`, `enterprise_quote_responses`
- **P8b — Thanh toán & cấp quyền:**
  - `billing_checkout_operations`, `billing_service_reservations`, `billing_upgrade_reservations`
  - `payos_payment_requests`, `payos_webhook_inbox`, `payment_transactions`, `payment_provisioning_records`
  - `service_entitlements`, `billing_entitlement_upgrades`, `billing_ai_quota_grants`, `billing_ai_quota_allocations`

## 3. Các bước

### Bước 1 — Đọc trước

Mở `1-Logical.md`, đọc hai mục **Ký hiệu bản số** và **Logical khác Physical ở đâu**. Hai mục này quyết định cách vẽ cả hai bộ hình.

### Bước 2 — Vẽ logical (L0 → L8) trong draw.io

1. Mở [draw.io](https://app.diagrams.net), tạo file `Fire3D-Logical.drawio`, mỗi hình một trang (page) tên `L0`…`L8`.
2. Copy nội dung **bên trong** khối mermaid của mục tương ứng, gồm cả dòng `erDiagram`. Không lấy hai dòng ` ``` `.
3. Vào *Arrange → Insert → Advanced → Mermaid…*, dán vào, rồi bấm *Insert*.
4. Sắp xếp lại cho gọn:
   - thực thể chính của hình đặt ở giữa;
   - thực thể tham chiếu (chỉ có `id`) đặt ở mép và tô xám.
5. Nếu draw.io chèn sơ đồ thành **ảnh** (không sửa được), dùng ảnh đó làm mẫu và vẽ lại bằng thư viện shape *Entity Relation*. Thư viện này có bảng và các đầu mũi tên chân chim.

### Bước 3 — Vẽ physical (P1 → P12) trong dbdiagram.io

1. Mở [dbdiagram.io](https://dbdiagram.io), tạo diagram mới cho mỗi hình.
2. Dán toàn bộ nội dung một file trong `dbml-theo-nhom/`.
3. Bấm sắp xếp tự động (*Auto-arrange*), rồi kéo tay cho các đường nối ít cắt nhau:
   - bảng cha ở trên hoặc bên trái, bảng con ở dưới hoặc bên phải;
   - bảng xám đặt ở mép.
4. Xuất PNG hoặc PDF.
5. Khi tách P3 hoặc P8: tạo hai bản sao của file `.dbml`. Trong mỗi bản, xóa khối `Table` của những bảng thuộc nửa kia, xóa các dòng `Ref` trỏ tới bảng đã xóa, rồi dán vào dbdiagram như bình thường.

Nếu nhóm muốn mọi hình cùng một công cụ, có thể vẽ physical bằng draw.io theo cách ở Bước 2, lấy khối mermaid trong `2-Physical.md`.

### Bước 4 — Rà soát (checklist cuối file)

### Bước 5 — Đưa vào báo cáo

Gợi ý bố cục chương:

- **x.1 Mô hình dữ liệu logical**
  - Hình L0, rồi L1–L8. Mỗi hình kèm 2–3 câu lấy từ đoạn giới thiệu của mục tương ứng.
  - **Bảng từ điển thực thể**: copy bảng trong `1-Logical.md`.
- **x.2 Mô hình dữ liệu physical**
  - Quy ước: một đoạn ngắn lấy từ mục *Quy ước* của `2-Physical.md`.
  - Bảng các kiểu enum.
  - Hình P1–P12. Dưới mỗi hình ghi hai dòng *UNIQUE nhiều cột* và *Xóa dây chuyền* nếu mục đó có.

Mỗi hình đặt tên dạng: *Hình x.y: ERD logical — Báo giá, thanh toán & dịch vụ*.

## 4. Quy ước thống nhất (để các hình nhìn như một bộ)

- **Tên:**
  - logical giữ tên thực thể `PascalCase` tiếng Anh y như file (`ServiceEntitlement`), không dịch;
  - physical giữ tên bảng `snake_case` y như database;
  - nghĩa tiếng Việt đặt ở bảng từ điển, không viết vào trong hình.
- **Ký hiệu:** chỉ dùng chân chim (crow's foot). Không trộn với ký hiệu Chen (hình thoi, elip).
- **Khóa:**
  - PK ghi chữ `PK` hoặc gạch chân, FK ghi chữ `FK`; chọn một kiểu và giữ nguyên cho mọi hình;
  - physical ghi thêm `UK` và `NULL` như trong file.
- **Màu:**
  - mỗi hình chỉ tô **một** màu cho thực thể/bảng của chính nhóm đó;
  - thực thể/bảng của nhóm khác tô xám.
- **Nhãn đường nối:**
  - logical là động từ tiếng Việt (*"sở hữu"*, *"có phiên"*);
  - physical là tên cột khóa ngoại (dbdiagram tự hiện khi rê chuột, không cần ghi).
- **Không tự sửa bản số hay thêm bớt thực thể.** Thấy chỗ nào lạ thì hỏi lại, đừng sửa trên hình. Bản số đã được suy từ ràng buộc NOT NULL và UNIQUE thật.

## 5. Những điểm hay bị hỏi khi bảo vệ (nên nắm)

- **Logical có 63 thực thể nhưng physical có 112 bảng?**
  - Physical có thêm 40 bảng kỹ thuật: hàng đợi email, phiên tải file, outbox giao job, biên nhận chống gửi lặp, các bước giữ chỗ khi thanh toán. Danh sách nằm ở mục *Bảng không đưa vào logical*.
  - Physical cũng có thêm 4 bảng trung gian cho quan hệ nhiều-nhiều.
  - Ngoài ra, 4 thực thể logical được lưu thành 2–3 bảng mỗi cái (thêm 5 bảng), do tách quan hệ 1:1, ví dụ `Building` = `buildings` + `building_locations`.
- **Vì sao nhiều khóa ngoại ghép có `organization_id`?** Để chính database chặn việc gắn dữ liệu của tổ chức này vào tổ chức khác. Ví dụ phiên bản kịch bản không thể trỏ tới công trình của tổ chức khác.
- **Bảng thứ 113 ở đâu?** `__EFMigrationsHistory`, bảng của EF Core ghi các migration đã chạy. Đây không phải dữ liệu nghiệp vụ nên không vẽ.

## 6. Checklist trước khi nộp

- [ ] Đủ 9 hình logical (L0–L8) và 12 hình physical (P1–P12; hoặc 14 nếu tách P3, P8).
- [ ] Số thực thể/bảng và số đường nối mỗi hình **khớp** dòng chú thích in nghiêng dưới sơ đồ trong file `.md`.
- [ ] Logical có đúng 4 quan hệ nhiều-nhiều `}o--o{`:
  - `User`–`Building`
  - `LearnPostVersion`–`LearnSituation`
  - `LearnPostVersion`–`KnowledgeSource`
  - `User`–`LearnPost`
- [ ] Physical **không** có đường nhiều-nhiều nào: 4 quan hệ trên đã thành bảng trung gian.
- [ ] Logical không có cột kỹ thuật (hash, lease, idempotency key, revision).
- [ ] Physical đủ cột; kiểu dữ liệu ghi đúng như file (`uuid`, `timestamptz`, `numeric(14,2)`…).
- [ ] Mọi hình cùng font, cùng màu xám cho bảng tham chiếu, cùng cách ghi PK/FK.
- [ ] Mỗi hình có số thứ tự và tên theo mẫu ở Bước 5.
- [ ] Xuất ảnh đủ nét (PNG ≥ 2× hoặc PDF vector) để chữ đọc được khi in A4.

## 7. Khi database thay đổi

Số liệu trong thư mục này chốt theo production ngày 27/10/2026 (Supabase Singapore, 136 migration), đã tính đợt dọn dẹp cùng ngày: bỏ bảng `revision_processing_logs` (không có code nào ghi) và 2 enum chỉ bảng đó dùng. So với bản 26/10: thêm `learn_media_images` (ảnh bài Learn, nhóm B10) và `knowledge_source_files` (file tài liệu của nguồn tri thức, nhóm B9); cả hai là bảng kỹ thuật nên chỉ có ở physical. Nếu sau này có migration thêm hoặc xóa bảng, nhờ người giữ repo BE sinh lại thư mục. Script sinh file nằm trong `_sinh-lai/`. Không sửa tay các file `.md`/`.dbml`, vì lần sinh lại sẽ ghi đè.
