# Fire3D — Mô hình dữ liệu Logical

> Bắt đầu từ [0-Ke-hoach-ve.md](0-Ke-hoach-ve.md): danh sách hình cần vẽ, các bước và checklist.

Sinh từ schema PostgreSQL thật trên production (Supabase Singapore, đối chiếu ngày 27/10/2026, 136 migration; đã bỏ trước bảng `revision_processing_logs` và 2 enum của nó, xóa ở đợt dọn dẹp cùng ngày). **Logical:** 63 thực thể, 4 quan hệ nhiều-nhiều. **Physical:** 112 bảng, 1289 cột, 244 khóa ngoại, 16 kiểu enum (chưa tính bảng hệ thống `__EFMigrationsHistory` của EF Core).

## Mục lục

- [Ký hiệu bản số](#ký-hiệu-bản-số)
- [Logical khác Physical ở đâu](#logical-khác-physical-ở-đâu)
- [A0. Tổng quan](#a0-tổng-quan)
- [A1. Tổ chức, người dùng & công trình](#a1-tổ-chức-người-dùng--công-trình)
- [A2. Mô hình IFC & xử lý](#a2-mô-hình-ifc--xử-lý)
- [A3. Kịch bản & chơi thử](#a3-kịch-bản--chơi-thử)
- [A4. Phát hành, huấn luyện & phiên học](#a4-phát-hành-huấn-luyện--phiên-học)
- [A5. Báo giá, thanh toán & dịch vụ](#a5-báo-giá-thanh-toán--dịch-vụ)
- [A6. AI & kho tri thức](#a6-ai--kho-tri-thức)
- [A7. Learn & thư viện](#a7-learn--thư-viện)
- [A8. Hỗ trợ, thông báo & audit](#a8-hỗ-trợ-thông-báo--audit)
- [Từ điển thực thể](#từ-điển-thực-thể)
- [Bảng không đưa vào logical](#bảng-không-đưa-vào-logical)

## Ký hiệu bản số

Mọi sơ đồ dùng ký hiệu chân chim (crow's foot) của Mermaid:

| Ký hiệu | Nghĩa |
|---|---|
| `\|\|--o{` | Một – nhiều (bên một bắt buộc, bên nhiều có thể 0) |
| `\|o--o{` | Không/một – nhiều (khóa ngoại cho phép NULL) |
| `\|\|--o\|` | Một – không/một (quan hệ 1:1, phía con có ràng buộc UNIQUE) |
| `\|\|--\|\|` | Một – đúng một |
| `}o--o{` | Nhiều – nhiều (chỉ có ở logical; physical tách thành bảng trung gian) |

## Logical khác Physical ở đâu

| | Logical (file này) | Physical (`2-Physical.md`) |
|---|---|---|
| Mục đích | Mô tả **nghiệp vụ**: có những đối tượng nào và chúng liên quan ra sao | Mô tả **cách lưu thật** trong PostgreSQL |
| Phạm vi | 63 thực thể nghiệp vụ; bỏ các bảng kỹ thuật (hàng đợi, outbox, biên nhận, giữ chỗ...) | Đủ 112 bảng |
| Tên | Thực thể dạng `PascalCase` (`ServiceEntitlement`) | Bảng dạng `snake_case` số nhiều (`service_entitlements`) |
| Kiểu dữ liệu | Kiểu miền: `ID`, `String`, `Money`, `DateTime`, `Enum`, `Json`... | Kiểu PostgreSQL: `uuid`, `varchar(64)`, `numeric(14,2)`, `timestamptz`, enum riêng, `jsonb`, `vector` |
| Nhiều – nhiều | Vẽ thẳng `}o--o{` | Tách thành bảng trung gian có khóa chính ghép (xem dưới) |
| Quan hệ 1:1 phụ | Gộp vào thực thể chính (vị trí công trình nằm trong `Building`) | Bảng riêng, khóa ngoại có UNIQUE (`building_locations.building_id`) |
| Cột kỹ thuật | Bỏ: hash token, lease, `revision`/ETag, idempotency key, snapshot giá | Có đủ |
| Khóa ngoại | Chỉ khóa ngoại nghiệp vụ, mỗi quan hệ một khóa | Nhiều khóa ngoại **ghép** mang theo `organization_id` để database tự chặn dữ liệu chéo tổ chức (ví dụ `scenario_versions(scenario_id, building_id, organization_id)`) |

**Quan hệ nhiều-nhiều và bảng trung gian tương ứng:**

| Logical | Bảng trung gian (physical) | Khóa chính |
|---|---|---|
| `User` }o--o{ `Building` (được tham gia) | `building_participation_grants` | (building_id, trainee_user_id, access_revision) |
| `LearnPostVersion` }o--o{ `LearnSituation` (gắn tình huống) | `learn_post_version_situations` | (post_version_id, situation_id) |
| `LearnPostVersion` }o--o{ `KnowledgeSource` (trích nguồn) | `learn_post_version_sources` | (post_version_id, source_id, source_role) |
| `User` }o--o{ `LearnPost` (lưu bookmark) | `learn_bookmarks` | (trainee_user_id, post_id) |


## A0. Tổng quan

Chỉ các thực thể trên trục chính, chưa có thuộc tính. Dùng làm trang đầu của phần logical.

```mermaid
erDiagram
  Organization |o--o{ User : "có thành viên"
  Organization ||--o{ Building : "sở hữu"
  User }o--o{ Building : "được tham gia"
  Building ||--o{ Revision : "có phiên bản IFC"
  Revision ||--o{ ProcessingJob : "được xử lý"
  ProcessingJob ||--o{ RevisionArtifact : "sinh ra"
  Revision ||--o{ RevisionReview : "được duyệt"
  Building ||--o{ Scenario : "có kịch bản"
  Scenario ||--o{ ScenarioVersion : "chốt thành"
  ScenarioVersion ||--o{ Release : "được phát hành"
  Release ||--o| ReleasePackage : "đóng gói thành"
  Release ||--o{ Training : "dùng cho"
  Training ||--o{ Session : "có phiên"
  User ||--o{ Session : "học"
  Session ||--o| SessionResult : "được chấm"
  Organization ||--o{ Quotation : "nhận"
  Quotation ||--o{ QuotationBuildingItem : "gồm"
  Quotation ||--o{ PaymentRequest : "được thanh toán qua"
  PaymentRequest ||--o{ PaymentTransaction : "nhận tiền"
  PaymentTransaction ||--o{ ServiceEntitlement : "kích hoạt"
  Building ||--o{ ServiceEntitlement : "được dùng dịch vụ"
  ServiceEntitlement ||--o{ LearnerSeat : "cấp suất"
  LearnerSeat |o--o{ Session : "được dùng cho"
  PaymentTransaction ||--o{ AiQuotaGrant : "cấp credit"
  AiQuotaGrant ||--o{ AiQuotaAllocation : "bị trừ"
  AiRequest ||--o{ AiQuotaAllocation : "giữ credit"
  User ||--o{ AiRequest : "hỏi"
```

## A1. Tổ chức, người dùng & công trình

Ai dùng hệ thống, thuộc tổ chức nào, và tổ chức có những công trình nào. Học viên (Trainee) không thuộc tổ chức; họ được **tham gia** công trình qua mã QR, đó là quan hệ nhiều-nhiều.

```mermaid
erDiagram
  Organization |o--o{ User : "có thành viên"
  Organization ||--o{ Building : "sở hữu"
  User ||--o{ Building : "tạo"
  User ||--o{ Device : "cài app trên"
  User ||--o{ AuthSession : "đăng nhập"
  Building ||--o{ BuildingContact : "có người liên hệ"
  Building ||--o{ BuildingQrCode : "phát mã QR"
  User }o--o{ Building : "được tham gia"
  Organization {
    ID id PK
    String name
    String slug UK
    String address
    Phone phone UK
    Json metadata
    Bool is_active
    DateTime created_at
    DateTime deleted_at
  }
  User {
    ID id PK
    ID organization_id FK
    Email email UK
    String username UK
    String full_name
    Enum role
    Phone phone_number UK
    Date dob
    String gender
    Url avatar
    DateTime email_verified_at
    Bool is_active
    DateTime last_login_at
    DateTime created_at
    DateTime deleted_at
  }
  Device {
    ID id PK
    ID user_id FK
    String device_uuid
    String device_model
    String os_version
    String app_version
    String push_token
    Bool notifications_enabled
    DateTime last_seen_at
    DateTime revoked_at
  }
  AuthSession {
    ID id PK
    ID user_id FK
    ID family_id
    DateTime created_at
    DateTime expires_at
    DateTime revoked_at
  }
  Building {
    ID id PK
    ID organization_id FK
    ID created_by FK
    String name
    String building_type
    Int total_floors
    Enum visibility
    String address
    String city
    String district
    Decimal latitude
    Decimal longitude
    Bool is_active
    DateTime created_at
    DateTime deleted_at
  }
  BuildingContact {
    ID id PK
    ID building_id FK
    String contact_name
    String contact_role
    Phone phone
    Email email
    Bool is_primary
  }
  BuildingQrCode {
    ID id PK
    ID building_id FK
    ID created_by FK
    String label
    Enum status
    DateTime created_at
    DateTime revoked_at
  }
```
*7 thực thể, 8 quan hệ.*

## A2. Mô hình IFC & xử lý

Mỗi công trình có nhiều phiên bản mô hình IFC. Một phiên bản được xử lý trên VM thành các kết quả (GLB, navmesh, danh sách tầng), được kiểm tra, rồi được duyệt cho huấn luyện.

```mermaid
erDiagram
  Building ||--o{ Revision : "có phiên bản IFC"
  User ||--o{ Revision : "tải lên"
  Revision ||--|| SourceDocument : "có file gốc"
  Revision ||--o{ ProcessingJob : "được xử lý"
  ProcessingJob ||--o{ ProcessingAttempt : "chạy"
  ProcessingJob ||--o{ RevisionArtifact : "sinh ra"
  ProcessingAttempt |o--o{ RevisionArtifact : "tạo"
  Revision ||--o{ RevisionArtifact : "có kết quả"
  ProcessingJob ||--o| ValidationRun : "được kiểm tra"
  ValidationRun ||--o{ RevisionIssue : "phát hiện"
  Revision ||--o{ BimFact : "có thuộc tính BIM"
  Revision ||--o{ AnnotationSet : "có chú thích"
  Revision ||--o{ EquipmentDecision : "có quyết định thiết bị"
  Revision ||--o{ StyleSelection : "có kiểu hiển thị"
  Revision ||--o{ RevisionReview : "được duyệt"
  ValidationRun ||--o{ RevisionReview : "là căn cứ"
  AnnotationSet |o--o{ RevisionReview : "được dùng khi duyệt"
  ScenarioVersion ||--o{ RevisionReview : "được duyệt cùng"
  User ||--o{ RevisionReview : "duyệt"
  Revision {
    ID id PK
    ID building_id FK
    ID uploaded_by FK
    String version_label
    Enum status
    DateTime created_at
  }
  SourceDocument {
    ID id PK
    ID revision_id FK
    String original_filename
    Enum file_type
    Int file_size_bytes
    String sha256_hash
    Enum quarantine_status
    String usage_rights
    String source_tool
    DateTime upload_verified_at
  }
  ProcessingJob {
    ID id PK
    ID revision_id FK
    ID source_document_id FK
    ID scenario_version_id FK
    Enum kind
    Enum status
    DateTime started_at
    DateTime finished_at
    Text error_message
  }
  ProcessingAttempt {
    ID id PK
    ID job_id FK
    Int attempt_number
    String toolchain_version
    Enum status
    DateTime started_at
    DateTime finished_at
    Text error_message
  }
  RevisionArtifact {
    ID id PK
    ID revision_id FK
    ID job_id FK
    ID attempt_id FK
    Enum artifact_type
    String object_key
    String sha256_hash
    Int size_bytes
    Bool is_runtime_ready
    Json metadata
  }
  ValidationRun {
    ID id PK
    ID revision_id FK
    ID job_id FK
    ID scenario_version_id FK
    ID annotation_set_id FK
    Enum kind
    Enum outcome
    Json report
    DateTime created_at
  }
  RevisionIssue {
    ID id PK
    ID validation_run_id FK
    Enum severity
    String code
    String ifc_guid
    Text message
  }
  BimFact {
    ID id PK
    ID revision_id FK
    String ifc_global_id
    String entity_type
    String property_path
    Json value
  }
  AnnotationSet {
    ID id PK
    ID revision_id FK
    ID created_by FK
    Int version_number
    Json data
    String provenance
  }
  EquipmentDecision {
    ID id PK
    ID revision_id FK
    ID created_by FK
    Int version_number
    Json data
  }
  StyleSelection {
    ID id PK
    ID revision_id FK
    ID created_by FK
    Int version_number
    Json data
  }
  RevisionReview {
    ID id PK
    ID revision_id FK
    ID scenario_version_id FK
    ID validation_run_id FK
    ID annotation_set_id FK
    ID reviewed_by FK
    Enum action
    Text review_message
    DateTime reviewed_at
  }
  Building {
    ID id PK "mục A1"
  }
  ScenarioVersion {
    ID id PK "mục A3"
  }
  User {
    ID id PK "mục A1"
  }
```
*12 thực thể, 19 quan hệ. Thực thể chỉ có `id`: `Building`, `ScenarioVersion`, `User` (vẽ đầy đủ ở mục khác).*

## A3. Kịch bản & chơi thử

Kịch bản gắn với một công trình. Người soạn sửa bản nháp nhiều lần, rồi chốt thành **phiên bản bất biến**. Tổ chức chơi thử phiên bản đó trước khi phát hành.

```mermaid
erDiagram
  Building ||--o{ Scenario : "có kịch bản"
  User ||--o{ Scenario : "tạo"
  Scenario ||--o{ ScenarioDraft : "có bản nháp"
  Revision ||--o{ ScenarioDraft : "làm nền cho"
  Scenario ||--o{ ScenarioVersion : "chốt thành"
  Revision ||--o{ ScenarioVersion : "làm nền cho"
  ScenarioVersion ||--o| ContentReview : "được duyệt nội dung"
  ScenarioVersion ||--o{ PlaytestSession : "được chơi thử"
  ScenarioDraft |o--o{ PlaytestSession : "được chơi thử"
  ServiceEntitlement |o--o{ PlaytestSession : "trừ lượt chơi thử"
  User ||--o{ PlaytestSession : "chơi thử"
  PlaytestSession ||--o{ PlaytestEvent : "ghi sự kiện"
  Scenario {
    ID id PK
    ID building_id FK
    ID created_by FK
    String name
    DateTime created_at
  }
  ScenarioDraft {
    ID id PK
    ID scenario_id FK
    ID revision_id FK
    ID created_by FK
    Int draft_number
    Json state
    Enum source
    DateTime updated_at
  }
  ScenarioVersion {
    ID id PK
    ID scenario_id FK
    ID revision_id FK
    ID created_by FK
    Int version_number
    String name
    Int time_limit_seconds
    Int random_seed
    Json spawn_config
    Json goal_config
    Json fire_source_config
    Json npc_config
    Json scoring_config
    Json learning_objectives
    Json rubric
    String scenario_hash
    DateTime created_at
  }
  ContentReview {
    ID id PK
    ID scenario_version_id FK
    ID submitted_by FK
    ID reviewed_by FK
    Enum status
    Text reason
    DateTime submitted_at
    DateTime reviewed_at
  }
  RuntimeVersion {
    ID id PK
    String runtime_version
    String protocol_version
    String manifest_schema_version
    Json capabilities
    Bool is_active
  }
  PlaytestSession {
    ID id PK
    ID scenario_version_id FK
    ID scenario_draft_id FK
    ID building_id FK
    ID entitlement_id FK
    ID created_by FK
    Enum status
    String runtime_version
    DateTime started_at
    DateTime ended_at
    Json completion
  }
  PlaytestEvent {
    ID playtest_id PK, FK
    ID event_id PK
    Int sequence
    String event_type
    Json payload
    DateTime occurred_at
  }
  Building {
    ID id PK "mục A1"
  }
  Revision {
    ID id PK "mục A2"
  }
  ServiceEntitlement {
    ID id PK "mục A5"
  }
  User {
    ID id PK "mục A1"
  }
```
*7 thực thể, 12 quan hệ. Thực thể chỉ có `id`: `Building`, `Revision`, `ServiceEntitlement`, `User` (vẽ đầy đủ ở mục khác).*

## A4. Phát hành, huấn luyện & phiên học

Phiên bản kịch bản đã duyệt được **phát hành** thành gói Android. Tổ chức tạo **bài huấn luyện** từ bản phát hành; học viên vào bài, mỗi lần chơi là một **phiên**, kết thúc thì được chấm điểm. Mỗi học viên chiếm một **suất** của dịch vụ công trình.

```mermaid
erDiagram
  ScenarioVersion ||--o{ Release : "được phát hành"
  Revision ||--o{ Release : "được phát hành"
  RevisionReview ||--o{ Release : "xác nhận"
  Release ||--o| ReleasePackage : "đóng gói thành"
  Release ||--o{ Training : "dùng cho"
  Organization ||--o{ Training : "tổ chức"
  Training ||--o{ Session : "có phiên"
  User ||--o{ Session : "học"
  Device |o--o{ Session : "chạy trên"
  Session ||--o{ SessionEvent : "ghi sự kiện"
  Session ||--o| SessionResult : "được chấm"
  ServiceEntitlement ||--o{ LearnerSeat : "cấp suất"
  User ||--o{ LearnerSeat : "giữ suất"
  LearnerSeat |o--o{ Session : "được dùng cho"
  Release {
    ID id PK
    ID revision_id FK
    ID scenario_version_id FK
    ID confirmation_review_id FK
    ID published_by FK
    ID revoked_by FK
    Enum status
    Json safety_thresholds
    DateTime published_at
    DateTime revoked_at
    Text revoked_reason
  }
  ReleasePackage {
    ID id PK
    ID release_id FK
    Url package_url
    String checksum_sha256
    Int package_size_bytes
    String min_runtime_version
    String build_target
  }
  Training {
    ID id PK
    ID release_id FK
    ID organization_id FK
    ID created_by FK
    String name
    Text description
    DateTime start_date
    DateTime end_date
    Enum status
    Enum mode
    Enum allowed_modes
    Int max_attempts
  }
  Session {
    ID id PK
    ID training_id FK
    ID trainee_user_id FK
    ID device_id FK
    ID seat_id FK
    ID entitlement_id FK
    Enum mode
    Enum status
    String app_version
    DateTime started_at
    DateTime ended_at
    String terminal_reason
  }
  SessionEvent {
    ID id PK
    ID session_id FK
    Int sequence_number
    String event_type
    Json event_data
    Int elapsed_ms
    DateTime recorded_at
  }
  SessionResult {
    ID id PK
    ID session_id FK
    Decimal score
    Int time_taken_seconds
    Int wrong_exits
    Decimal hazard_exposure_score
    Decimal total_distance_meters
    Bool reached_exit
    Enum outcome
    Json criterion_results
    Json metrics
  }
  LearnerSeat {
    ID id PK
    ID entitlement_id FK
    ID trainee_id FK
    ID first_session_id
    DateTime allocated_at
  }
  Device {
    ID id PK "mục A1"
  }
  Organization {
    ID id PK "mục A1"
  }
  Revision {
    ID id PK "mục A2"
  }
  RevisionReview {
    ID id PK "mục A2"
  }
  ScenarioVersion {
    ID id PK "mục A3"
  }
  ServiceEntitlement {
    ID id PK "mục A5"
  }
  User {
    ID id PK "mục A1"
  }
```
*7 thực thể, 14 quan hệ. Thực thể chỉ có `id`: `Device`, `Organization`, `Revision`, `RevisionReview`, `ScenarioVersion`, `ServiceEntitlement`, `User` (vẽ đầy đủ ở mục khác).*

## A5. Báo giá, thanh toán & dịch vụ

Tổ chức nhận **báo giá** (mỗi dòng là một công trình hoặc một lần mua thêm credit AI), trả tiền qua **PayOS**. Tiền về thì sinh ra **quyền dùng dịch vụ** cho công trình và **credit AI** cho tổ chức.

```mermaid
erDiagram
  ServicePackage |o--o{ DiscountRule : "áp dụng"
  QuotaPolicyVersion |o--o{ ServicePackage : "quy định credit"
  Organization ||--o{ Quotation : "nhận"
  User ||--o{ Quotation : "yêu cầu"
  DiscountRule |o--o{ Quotation : "giảm giá"
  Quotation ||--o{ QuotationBuildingItem : "gồm dòng công trình"
  Quotation ||--o| QuotationTopupItem : "gồm dòng mua credit"
  Building ||--o{ QuotationBuildingItem : "được báo giá"
  ServicePackage ||--o{ QuotationBuildingItem : "được chọn"
  Quotation ||--o{ PaymentRequest : "được thanh toán qua"
  PaymentRequest ||--o{ PaymentTransaction : "nhận tiền"
  QuotationBuildingItem ||--o{ ServiceEntitlement : "tạo ra"
  PaymentTransaction ||--o{ ServiceEntitlement : "kích hoạt"
  Building ||--o{ ServiceEntitlement : "được dùng dịch vụ"
  ServicePackage ||--o{ ServiceEntitlement : "theo gói"
  ServiceEntitlement ||--o{ EntitlementUpgrade : "được nâng cấp"
  PaymentTransaction ||--o{ EntitlementUpgrade : "trả cho"
  QuotationBuildingItem |o--o{ EntitlementUpgrade : "tạo ra"
  Organization ||--o{ AiQuotaGrant : "nhận credit"
  PaymentTransaction ||--o{ AiQuotaGrant : "cấp credit"
  QuotaPolicyVersion ||--o{ AiQuotaGrant : "theo chính sách"
  QuotationTopupItem |o--o{ AiQuotaGrant : "mua thêm"
  AiQuotaGrant ||--o{ AiQuotaAllocation : "bị giữ/trừ"
  Organization ||--o{ EnterpriseQuoteRequest : "gửi"
  EnterpriseQuoteRequest ||--o{ EnterpriseQuoteResponse : "được trả lời"
  EnterpriseQuoteRequest }o--o| Quotation : "dẫn tới"
  ServicePackage {
    ID id PK
    ID ai_policy_version_id FK
    String code UK
    String name
    Text description
    Money unit_price
    String currency
    Int duration_months
    Int learner_limit
    Int ai_quota_units
    Json features
    Bool is_active
  }
  DiscountRule {
    ID id PK
    ID service_package_id FK
    String code UK
    Enum discount_kind
    Decimal discount_value
    Int minimum_buildings
    Int minimum_duration_months
    DateTime valid_from
    DateTime valid_until
    Bool is_active
  }
  QuotaPolicyVersion {
    ID id PK
    Enum audience
    Enum policy_kind
    String quota_unit
    Enum rollover
    DateTime effective_from
    DateTime effective_until
  }
  Quotation {
    ID id PK
    ID organization_id FK
    ID requested_by FK
    ID issued_by FK
    ID discount_rule_id FK
    String quotation_number UK
    Enum status
    Enum billing_purpose
    Money subtotal_amount
    Money discount_amount
    Money tax_amount
    Money total_amount
    String currency
    DateTime valid_until
    DateTime issued_at
    DateTime accepted_at
  }
  QuotationBuildingItem {
    ID id PK
    ID quotation_id FK
    ID building_id FK
    ID service_package_id FK
    ID upgrade_entitlement_id FK
    Enum purchase_action
    Int service_duration_months
    Money unit_price
    Money discount_amount
    Money total_amount
    Int learner_limit
    Int ai_quota_units
    DateTime starts_at
    DateTime ends_at
  }
  QuotationTopupItem {
    ID id PK
    ID quotation_id FK
    ID policy_version_id FK
    String quota_unit
    Int quota_units
    Money amount
    DateTime starts_at
    DateTime ends_at
  }
  PaymentRequest {
    ID id PK
    ID quotation_id FK
    ID requested_by FK
    Int order_code UK
    Money expected_amount
    String expected_currency
    Url checkout_url
    Enum status
    DateTime expires_at
    DateTime paid_at
  }
  PaymentTransaction {
    ID id PK
    ID payment_request_id FK
    String provider_transaction_id UK
    Money received_amount
    String received_currency
    Bool signature_verified
    Enum status
    Text rejection_reason
    DateTime received_at
  }
  ServiceEntitlement {
    ID id PK
    ID building_id FK
    ID service_package_id FK
    ID quotation_item_id FK
    ID payment_transaction_id FK
    Enum status
    DateTime starts_at
    DateTime ends_at
    Int learner_limit
    Int playtest_units_granted
    Int playtest_units_used
  }
  EntitlementUpgrade {
    ID id PK
    ID entitlement_id FK
    ID quotation_item_id FK
    ID payment_transaction_id FK
    Int capacity_revision
    Int previous_learner_limit
    Int learner_limit
    Int additional_quota_units
    DateTime effective_from
  }
  AiQuotaGrant {
    ID id PK
    ID organization_id FK
    ID policy_version_id FK
    ID payment_transaction_id FK
    ID entitlement_id FK
    ID topup_item_id FK
    ID upgrade_id FK
    Enum source_kind
    String quota_unit
    Int quota_units
    DateTime starts_at
    DateTime ends_at
  }
  AiQuotaAllocation {
    ID id PK
    ID grant_id FK
    ID ai_request_id FK
    Int reserved_units
    Int consumed_units
    Enum status
    DateTime settled_at
  }
  EnterpriseQuoteRequest {
    ID id PK
    ID organization_id FK
    ID requested_by FK
    ID assigned_to FK
    ID quotation_id FK
    Int requested_building_count
    Int requested_duration_months
    String contact_name
    Email contact_email
    Phone contact_phone
    Text notes
    Enum status
    DateTime closed_at
  }
  EnterpriseQuoteResponse {
    ID id PK
    ID request_id FK
    ID author_id FK
    Text message
    DateTime created_at
  }
  Building {
    ID id PK "mục A1"
  }
  Organization {
    ID id PK "mục A1"
  }
  User {
    ID id PK "mục A1"
  }
```
*14 thực thể, 26 quan hệ. Thực thể chỉ có `id`: `Building`, `Organization`, `User` (vẽ đầy đủ ở mục khác).*

## A6. AI & kho tri thức

Mỗi yêu cầu AI theo một **chính sách thao tác** và giữ trước credit từ các lô credit của tổ chức. Câu trả lời dựa trên **kho tri thức** (quy chuẩn PCCC) đã cắt đoạn và nhúng vector.

```mermaid
erDiagram
  AiOperationPolicy ||--o{ AiRequest : "áp cho"
  User ||--o{ AiRequest : "hỏi"
  Organization |o--o{ AiRequest : "trả credit"
  AiRequest ||--o{ AiQuotaAllocation : "giữ credit"
  Organization |o--o{ KnowledgeSource : "sở hữu"
  User |o--o{ KnowledgeSource : "duyệt"
  KnowledgeSource ||--o{ KnowledgeChunk : "được cắt thành"
  AiOperationPolicy {
    ID id PK
    Enum operation
    String quota_unit
    Int reserve_units
    Int daily_units
    Int max_input_chars
    Int max_sources
    DateTime effective_from
    DateTime effective_until
  }
  AiRequest {
    ID id PK
    ID organization_id FK
    ID actor_user_id FK
    ID policy_id FK
    Enum operation
    Enum audience
    Enum status
    Json input
    Json result
    Int reserved_units
    Int consumed_units
    String model_version
    DateTime created_at
    DateTime completed_at
  }
  KnowledgeSource {
    ID id PK
    ID organization_id FK
    ID approved_by FK
    String title
    Url source_uri
    String version_label
    Enum visibility
    String jurisdiction
    Enum approval_status
    DateTime effective_from
    DateTime effective_until
  }
  KnowledgeChunk {
    ID id PK
    ID source_id FK
    Int chunk_index
    Text content
    Json locator
    Vector embedding
  }
  AiQuotaAllocation {
    ID id PK "mục A5"
  }
  Organization {
    ID id PK "mục A1"
  }
  User {
    ID id PK "mục A1"
  }
```
*4 thực thể, 7 quan hệ. Thực thể chỉ có `id`: `AiQuotaAllocation`, `Organization`, `User` (vẽ đầy đủ ở mục khác).*

## A7. Learn & thư viện

Bài viết Learn có nhiều phiên bản; một phiên bản gắn nhiều **tình huống** và trích nhiều **nguồn tri thức** (nhiều-nhiều). Học viên **lưu bookmark** bài viết. Thư viện dùng chung cũng quản lý theo phiên bản.

```mermaid
erDiagram
  LearnPost ||--o{ LearnPostVersion : "có phiên bản"
  LearnPost |o--o| LearnPostVersion : "đang xuất bản"
  User ||--o{ LearnPostVersion : "viết"
  LearnPostVersion }o--o{ LearnSituation : "gắn tình huống"
  LearnPostVersion }o--o{ KnowledgeSource : "trích nguồn"
  User }o--o{ LearnPost : "lưu bookmark"
  LibraryItem ||--o{ LibraryVersion : "có phiên bản"
  User ||--o{ LibraryItem : "tạo"
  LearnSituation {
    ID id PK
    String slug UK
    String name
    Text description
    Bool is_active
  }
  LearnPost {
    ID id PK
    ID published_version_id FK
    ID created_by FK
    String slug UK
    Enum publication_status
  }
  LearnPostVersion {
    ID id PK
    ID post_id FK
    ID created_by FK
    ID published_by FK
    Int version_number
    String title
    Text summary
    Enum content_kind
    Url cover_image_url
    Json content_blocks
    Enum status
    DateTime published_at
  }
  LibraryItem {
    ID id PK
    ID created_by FK
    Enum kind
    String code UK
    Bool is_active
  }
  LibraryVersion {
    ID id PK
    ID item_id FK
    ID published_by FK
    Int version_number
    String name
    Json payload
    Json required_capabilities
    Enum status
    DateTime published_at
  }
  KnowledgeSource {
    ID id PK "mục A6"
  }
  User {
    ID id PK "mục A1"
  }
```
*5 thực thể, 8 quan hệ. Thực thể chỉ có `id`: `KnowledgeSource`, `User` (vẽ đầy đủ ở mục khác).*

## A8. Hỗ trợ, thông báo & audit

Góp ý và phiếu hỗ trợ (có thể gắn với một phiên học), thông báo nhắc hạn dịch vụ gửi qua nhiều kênh, và nhật ký thao tác.

```mermaid
erDiagram
  User ||--o{ Feedback : "gửi"
  Organization |o--o{ Feedback : "nhận"
  Session |o--o{ Feedback : "được góp ý"
  User ||--o{ SupportTicket : "mở"
  Organization |o--o{ SupportTicket : "liên quan"
  Session |o--o{ SupportTicket : "liên quan"
  Feedback |o--o{ SupportTicket : "chuyển thành"
  SupportTicket ||--o{ TicketMessage : "có tin nhắn"
  User ||--o{ TicketMessage : "viết"
  Organization ||--o{ Notification : "nhận"
  User ||--o{ Notification : "được báo"
  ServiceEntitlement ||--o{ Notification : "được nhắc hạn"
  Notification ||--o{ NotificationDelivery : "gửi qua kênh"
  User |o--o{ AuditLog : "thực hiện"
  User ||--o{ AnalyticsExport : "xuất"
  Feedback {
    ID id PK
    ID submitted_by FK
    ID organization_id FK
    ID session_id FK
    ID reviewed_by FK
    String category
    Int rating
    Text message
    Enum status
    DateTime reviewed_at
  }
  SupportTicket {
    ID id PK
    ID created_by FK
    ID organization_id FK
    ID session_id FK
    ID feedback_id FK
    ID assigned_to FK
    String ticket_number UK
    String subject
    Text description
    Enum priority
    Enum status
    DateTime resolved_at
  }
  TicketMessage {
    ID id PK
    ID ticket_id FK
    ID author_id FK
    Text message
    DateTime created_at
  }
  Notification {
    ID id PK
    ID organization_id FK
    ID recipient_user_id FK
    ID building_id FK
    ID entitlement_id FK
    Enum notification_type
    String title
    Text body
    DateTime read_at
    DateTime created_at
  }
  NotificationDelivery {
    ID id PK
    ID notification_id FK
    Enum channel
    Enum status
    DateTime sent_at
  }
  AuditLog {
    ID id PK
    ID user_id FK
    ID organization_id FK
    Enum actor_type
    Enum action
    String target_entity
    ID target_id
    Json old_values
    Json new_values
    String ip_address
    DateTime created_at
  }
  AnalyticsExport {
    ID id PK
    ID actor_id FK
    ID organization_id FK
    String report
    Json filters
    Int row_count
    DateTime created_at
  }
  Organization {
    ID id PK "mục A1"
  }
  ServiceEntitlement {
    ID id PK "mục A5"
  }
  Session {
    ID id PK "mục A4"
  }
  User {
    ID id PK "mục A1"
  }
```
*7 thực thể, 15 quan hệ. Thực thể chỉ có `id`: `Organization`, `ServiceEntitlement`, `Session`, `User` (vẽ đầy đủ ở mục khác).*

## Từ điển thực thể

Cột "Bảng physical" cho biết thực thể logical được lưu ở bảng nào. Thực thể có hai bảng trở lên là chỗ physical tách quan hệ 1:1 ra bảng riêng.

| Mục | Thực thể | Nghĩa | Bảng physical |
|---|---|---|---|
| A1 | `Organization` | Tổ chức khách hàng | `organizations` |
| A1 | `User` | Người dùng | `users` |
| A1 | `Device` | Thiết bị cài app | `user_devices`<br>`device_installations` |
| A1 | `AuthSession` | Phiên đăng nhập | `auth_refresh_tokens` |
| A1 | `Building` | Công trình | `buildings`<br>`building_locations` |
| A1 | `BuildingContact` | Người liên hệ của công trình | `building_contacts` |
| A1 | `BuildingQrCode` | Mã QR tham gia công trình | `building_qr_codes` |
| A2 | `Revision` | Phiên bản mô hình IFC | `revisions` |
| A2 | `SourceDocument` | File IFC gốc | `source_documents` |
| A2 | `ProcessingJob` | Lượt xử lý mô hình trên VM | `processing_jobs` |
| A2 | `ProcessingAttempt` | Lần chạy của một job | `processing_job_attempts` |
| A2 | `RevisionArtifact` | Kết quả xử lý (GLB, navmesh, tầng...) | `revision_artifacts` |
| A2 | `ValidationRun` | Lần kiểm tra mô hình/kịch bản | `validation_runs` |
| A2 | `RevisionIssue` | Lỗi phát hiện khi kiểm tra | `revision_issues` |
| A2 | `BimFact` | Thuộc tính BIM trích từ IFC | `bim_facts` |
| A2 | `AnnotationSet` | Bộ chú thích trên mô hình | `annotation_sets` |
| A2 | `EquipmentDecision` | Quyết định thiết bị PCCC | `revision_equipment_decisions` |
| A2 | `StyleSelection` | Lựa chọn hiển thị mô hình | `revision_style_selections` |
| A2 | `RevisionReview` | Duyệt mô hình cho huấn luyện | `revision_reviews` |
| A3 | `Scenario` | Kịch bản | `scenarios` |
| A3 | `ScenarioDraft` | Bản nháp kịch bản | `scenario_drafts` |
| A3 | `ScenarioVersion` | Phiên bản kịch bản (bất biến) | `scenario_versions` |
| A3 | `ContentReview` | Duyệt nội dung kịch bản | `scenario_content_reviews` |
| A3 | `RuntimeVersion` | Phiên bản app Unity được hỗ trợ | `runtime_compatibility_catalog` |
| A3 | `PlaytestSession` | Phiên chơi thử của tổ chức | `playtest_sessions`<br>`playtest_runtime_state`<br>`playtest_package_pins` |
| A3 | `PlaytestEvent` | Sự kiện trong phiên chơi thử | `playtest_events` |
| A4 | `Release` | Bản phát hành | `releases`<br>`release_build_provenance` |
| A4 | `ReleasePackage` | Gói Android của bản phát hành | `release_packages` |
| A4 | `Training` | Bài huấn luyện | `trainings` |
| A4 | `Session` | Phiên học của học viên | `sessions` |
| A4 | `SessionEvent` | Sự kiện trong phiên học | `session_events` |
| A4 | `SessionResult` | Kết quả chấm điểm | `session_results` |
| A4 | `LearnerSeat` | Suất học viên của dịch vụ | `billing_learner_seats` |
| A5 | `ServicePackage` | Gói dịch vụ | `service_packages` |
| A5 | `DiscountRule` | Quy tắc giảm giá | `service_package_discount_rules` |
| A5 | `QuotaPolicyVersion` | Chính sách credit AI | `billing_quota_policy_versions` |
| A5 | `Quotation` | Báo giá | `quotations` |
| A5 | `QuotationBuildingItem` | Dòng báo giá cho một công trình | `quotation_building_items` |
| A5 | `QuotationTopupItem` | Dòng báo giá mua thêm credit AI | `quotation_topup_items` |
| A5 | `PaymentRequest` | Yêu cầu thanh toán PayOS | `payos_payment_requests` |
| A5 | `PaymentTransaction` | Giao dịch tiền đã nhận | `payment_transactions` |
| A5 | `ServiceEntitlement` | Quyền dùng dịch vụ của công trình | `service_entitlements` |
| A5 | `EntitlementUpgrade` | Nâng cấp dịch vụ | `billing_entitlement_upgrades` |
| A5 | `AiQuotaGrant` | Lô credit AI được cấp | `billing_ai_quota_grants` |
| A5 | `AiQuotaAllocation` | Credit giữ/trừ cho một yêu cầu AI | `billing_ai_quota_allocations` |
| A5 | `EnterpriseQuoteRequest` | Yêu cầu báo giá doanh nghiệp | `enterprise_quote_requests` |
| A5 | `EnterpriseQuoteResponse` | Phản hồi cho yêu cầu báo giá | `enterprise_quote_responses` |
| A6 | `AiOperationPolicy` | Chính sách cho từng loại thao tác AI | `ai_operation_policies` |
| A6 | `AiRequest` | Yêu cầu gửi AI | `ai_requests` |
| A6 | `KnowledgeSource` | Nguồn tri thức (quy chuẩn, tài liệu) | `knowledge_sources` |
| A6 | `KnowledgeChunk` | Đoạn tri thức đã nhúng vector | `knowledge_chunks` |
| A7 | `LearnSituation` | Tình huống học (chủ đề) | `learn_situations` |
| A7 | `LearnPost` | Bài viết Learn | `learn_posts` |
| A7 | `LearnPostVersion` | Phiên bản bài viết | `learn_post_versions` |
| A7 | `LibraryItem` | Mục thư viện dùng chung | `organization_library_items` |
| A7 | `LibraryVersion` | Phiên bản mục thư viện | `organization_library_versions` |
| A8 | `Feedback` | Góp ý | `feedback` |
| A8 | `SupportTicket` | Phiếu hỗ trợ | `support_tickets` |
| A8 | `TicketMessage` | Tin nhắn trong phiếu hỗ trợ | `support_ticket_messages` |
| A8 | `Notification` | Thông báo cho tổ chức | `organization_notifications` |
| A8 | `NotificationDelivery` | Lần gửi thông báo qua một kênh | `notification_deliveries` |
| A8 | `AuditLog` | Nhật ký thao tác | `audit_logs` |
| A8 | `AnalyticsExport` | Lần xuất báo cáo | `analytics_exports` |

## Bảng không đưa vào logical

40 bảng dưới đây có trong physical nhưng không phải đối tượng nghiệp vụ: chúng phục vụ chống gửi lặp, hàng đợi worker, hoặc các bước trung gian. Vẽ logical thì bỏ; vẽ physical thì có (`2-Physical.md`).

| Loại | Bảng |
|---|---|
| Mã/OTP tạm thời và hàng đợi gửi email | `auth_google_onboarding_sessions`, `registration_email_challenges`, `registration_otp_email_jobs`, `local_password_reset_tokens`, `password_reset_email_jobs`, `email_verification_tokens`, `email_verification_jobs` |
| Phiên tải file và dọn object trên S3 | `avatar_upload_intents`, `avatar_object_cleanups`, `ifc_upload_intents`, `ifc_upload_attempts`, `ifc_object_cleanup`, `learn_media_images`, `knowledge_source_files` |
| Outbox, giao job qua Redis/HTTP, kết quả tạm của worker | `integration_outbox_events`, `integration_event_consumptions`, `processing_delivery_receipts`, `processing_stream_deliveries`, `processing_stream_state`, `processing_stream_rejections`, `processing_stream_retry_receipts`, `processing_candidate_outputs` |
| Bước chuẩn bị trước khi vào phiên | `training_session_preparations`, `playtest_handoffs` |
| Quy trình thanh toán nhiều bước (checkout, giữ chỗ, webhook, cấp quyền) | `billing_checkout_operations`, `billing_service_reservations`, `billing_upgrade_reservations`, `payos_webhook_inbox`, `payment_provisioning_records` |
| Biên nhận chống gửi lặp (Idempotency-Key) | `ai_command_receipts`, `application_command_receipts`, `authoring_command_receipts`, `billing_command_receipts`, `content_command_receipts`, `learner_command_receipts`, `playtest_command_receipts`, `processing_command_receipts`, `readiness_command_receipts`, `release_command_receipts`, `support_command_receipts` |
