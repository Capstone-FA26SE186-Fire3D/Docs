# Fire3D — Mô hình dữ liệu Physical

> Bắt đầu từ [0-Ke-hoach-ve.md](0-Ke-hoach-ve.md): danh sách hình cần vẽ, các bước và checklist.

Sinh từ schema PostgreSQL thật trên production (Supabase Singapore, đối chiếu ngày 27/10/2026, 136 migration; đã bỏ trước bảng `revision_processing_logs` và 2 enum của nó, xóa ở đợt dọn dẹp cùng ngày). **Logical:** 63 thực thể, 4 quan hệ nhiều-nhiều. **Physical:** 112 bảng, 1289 cột, 244 khóa ngoại, 16 kiểu enum (chưa tính bảng hệ thống `__EFMigrationsHistory` của EF Core).

## Mục lục

- [Quy ước](#quy-ước)
- [Kiểu enum](#kiểu-enum)
- [B1. Định danh & phiên đăng nhập](#b1-định-danh--phiên-đăng-nhập)
- [B2. Công trình & quyền truy cập](#b2-công-trình--quyền-truy-cập)
- [B3. IFC & xử lý (worker)](#b3-ifc--xử-lý-worker)
- [B4. Outbox & giao job (Redis/HTTP)](#b4-outbox--giao-job-redishttp)
- [B5. Kịch bản & playtest](#b5-kịch-bản--playtest)
- [B6. Phát hành & bài huấn luyện](#b6-phát-hành--bài-huấn-luyện)
- [B7. Phiên học viên & chấm điểm](#b7-phiên-học-viên--chấm-điểm)
- [B8. Báo giá, PayOS & dịch vụ](#b8-báo-giá-payos--dịch-vụ)
- [B9. AI & kho tri thức](#b9-ai--kho-tri-thức)
- [B10. Learn & thư viện tổ chức](#b10-learn--thư-viện-tổ-chức)
- [B11. Hỗ trợ, thông báo, audit](#b11-hỗ-trợ-thông-báo-audit)
- [B12. Biên nhận idempotency](#b12-biên-nhận-idempotency)
- [Bảng hệ thống](#bảng-hệ-thống)


## Quy ước

- Mỗi cột ghi `kiểu tên khóa "ghi chú"`. Khóa: `PK` khóa chính, `FK` khóa ngoại, `UK` UNIQUE một cột. Ghi chú `NULL` là cột cho phép NULL; cột không ghi là **NOT NULL**. `numeric` ghi độ chính xác trong ghi chú, ví dụ `"(14,2)"`.
- Viết tắt kiểu: `timestamptz` = `timestamp with time zone`, `varchar(n)` = `character varying(n)`, `int` = `integer`, `bool` = `boolean`.
- Nhãn trên đường nối là **cột khóa ngoại** ở bảng con. Bản số suy ra từ schema: khóa ngoại NULL được thì phía cha là `|o`; khóa ngoại trùng một UNIQUE thì phía con là `o|` (1:1).
- Bảng thuộc nhóm khác chỉ vẽ cột khóa chính, ghi chú số nhóm. Ký hiệu bản số giải thích ở `1-Logical.md`.
- UNIQUE nhiều cột, index một phần (có `WHERE`) và CHECK có đủ trong `Fire3D-Physical.dbml`.

## Kiểu enum

| Enum | Giá trị |
|---|---|
| `audit_action_enum` | Upload, ConfirmForTraining, Reject, Publish, Revoke, Sync, Login, Logout, Download, Delete, Create, Update, Rollback, Grant, Resume, Payment, Support |
| `feedback_status_enum` | Submitted, Reviewed, Closed |
| `file_type_enum` | IFC |
| `payment_request_status_enum` | Pending, Paid, Expired, Cancelled, Failed |
| `payment_transaction_status_enum` | Received, Verified, Rejected, Applied |
| `quarantine_status_enum` | Pending, Accepted, Rejected |
| `quotation_status_enum` | Draft, Issued, Accepted, Expired, Cancelled |
| `release_status_enum` | Built, Published, Superseded, Revoked |
| `review_action_enum` | ConfirmForTraining, Rejected |
| `revision_status_enum` | Draft, Uploaded, Processing, NeedsFix, ReadyForScenario, ConfirmedForTraining, Rejected, Failed, Superseded |
| `session_mode_enum` | Learn, Guided, Assessment |
| `session_status_enum` | Created, Launching, Running, Completed, CompletedWithSupersededRelease, ScenarioUnsurvivable, Aborted, Abandoned, Crashed |
| `support_priority_enum` | Low, Normal, High, Urgent |
| `support_ticket_status_enum` | Open, InProgress, Resolved, Closed |
| `training_status_enum` | Draft, Active, Closed, Archived |
| `user_role_enum` | PlatformAdmin, OrganizationUser, Trainee |

## B1. Định danh & phiên đăng nhập

```mermaid
erDiagram
  device_installations |o--o{ user_devices : "installation_id"
  organizations |o--o{ users : "organization_id"
  registration_email_challenges ||--o{ registration_otp_email_jobs : "challenge_id"
  users |o--o{ auth_google_onboarding_sessions : "completed_user_id"
  users ||--o{ auth_refresh_tokens : "user_id"
  users ||--o{ avatar_upload_intents : "user_id"
  users ||--o{ email_verification_tokens : "user_id"
  users ||--o{ local_password_reset_tokens : "user_id"
  users ||--o{ user_devices : "user_id"
  users {
    uuid id PK
    uuid organization_id FK "NULL"
    text email UK
    text full_name "NULL"
    user_role_enum role
    bool is_active
    timestamptz last_login_at "NULL"
    timestamptz created_at
    timestamptz updated_at
    timestamptz deleted_at "NULL"
    varchar(128) firebase_uid "NULL"
    text password_hash "NULL"
    date dob "NULL"
    text gender "NULL"
    varchar(32) phone_number "NULL"
    timestamptz email_verified_at "NULL"
    varchar(30) username "NULL"
    timestamptz registration_expires_at "NULL"
    text avatar_storage_key "NULL"
    bigint profile_revision_no
  }
  organizations {
    uuid id PK
    text name
    text slug UK
    bool is_active
    jsonb metadata
    timestamptz created_at
    timestamptz updated_at
    timestamptz deleted_at "NULL"
    text address "NULL"
    varchar(50) phone "NULL"
    uuid registration_owner_user_id "NULL"
    bigint profile_revision_no
  }
  auth_refresh_tokens {
    uuid id PK
    uuid user_id FK
    uuid family_id
    varchar(64) token_hash UK
    timestamptz created_at
    timestamptz expires_at
    timestamptz consumed_at "NULL"
    timestamptz revoked_at "NULL"
  }
  device_installations {
    uuid id PK
    varchar(255) device_uuid UK
    varchar(64) secret_hash
    timestamptz created_at
    timestamptz updated_at
    varchar(32) secret_hash_scheme "NULL"
  }
  user_devices {
    uuid id PK
    uuid user_id FK
    text device_uuid
    text device_model "NULL"
    text os_version "NULL"
    text app_version "NULL"
    timestamptz last_seen_at
    timestamptz created_at
    text fcm_token "NULL"
    uuid installation_id FK "NULL"
    bool notifications_enabled
    int fcm_token_generation
    timestamptz revoked_at "NULL"
    timestamptz fcm_token_updated_at "NULL"
  }
  auth_google_onboarding_sessions {
    uuid id PK
    varchar(128) firebase_uid
    varchar(255) email
    varchar(128) onboarding_token_hash UK
    user_role_enum requested_role "NULL"
    jsonb organization_draft
    timestamptz expires_at
    timestamptz completed_at "NULL"
    uuid completed_user_id FK "NULL"
    varchar(128) completed_input_hash "NULL"
    timestamptz created_at
    varchar(200) display_name "NULL"
  }
  registration_email_challenges {
    uuid id PK
    text email
    text otp_hash
    bytea otp_ciphertext
    bytea otp_nonce
    bytea otp_tag
    timestamptz expires_at
    int failed_attempts
    timestamptz verified_at "NULL"
    timestamptz superseded_at "NULL"
    text registration_token_hash "NULL"
    bytea registration_token_ciphertext "NULL"
    bytea registration_token_nonce "NULL"
    bytea registration_token_tag "NULL"
    timestamptz registration_token_expires_at "NULL"
    timestamptz registration_token_used_at "NULL"
    timestamptz created_at
    timestamptz updated_at
  }
  registration_otp_email_jobs {
    uuid id PK
    uuid challenge_id FK
    text email
    text remote_address "NULL"
    text status
    int attempts
    timestamptz available_at
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    timestamptz created_at
  }
  local_password_reset_tokens {
    uuid id PK
    uuid user_id FK
    text token_hash UK
    timestamptz created_at
    timestamptz expires_at
    timestamptz used_at "NULL"
  }
  password_reset_email_jobs {
    uuid id PK
    varchar(254) email
    text status
    int attempts
    timestamptz available_at
    timestamptz created_at
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
  }
  email_verification_tokens {
    uuid id PK
    uuid user_id FK
    char(64) token_hash UK
    timestamptz created_at
    timestamptz expires_at
    timestamptz used_at "NULL"
  }
  email_verification_jobs {
    uuid id PK
    text email
    text status
    int attempts
    timestamptz available_at
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    timestamptz created_at
    uuid user_id "NULL"
    int generation
  }
  avatar_upload_intents {
    uuid id PK
    uuid user_id FK
    text staging_object_key
    text content_type
    bigint expected_size_bytes
    timestamptz expires_at
    timestamptz completed_at "NULL"
    timestamptz created_at
    text final_object_key "NULL"
    bigint expected_profile_revision "NULL"
    uuid candidate_attempt_id "NULL"
    text candidate_object_key "NULL"
    text candidate_source_etag "NULL"
    timestamptz candidate_lease_until "NULL"
  }
  avatar_object_cleanups {
    uuid id PK
    text object_key UK
    timestamptz available_at
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    int attempts
    timestamptz created_at
  }
```
*14 bảng, 9 khóa ngoại.*

- **UNIQUE nhiều cột:** `user_devices(id, user_id)`; `user_devices(user_id, device_uuid)`
- **Xóa dây chuyền:** `registration_otp_email_jobs` → `registration_email_challenges` ON DELETE CASCADE; `local_password_reset_tokens` → `users` ON DELETE CASCADE; `email_verification_tokens` → `users` ON DELETE CASCADE; `avatar_upload_intents` → `users` ON DELETE CASCADE

## B2. Công trình & quyền truy cập

```mermaid
erDiagram
  building_qr_codes |o--o{ building_qr_codes : "replaced_by"
  buildings ||--o{ building_contacts : "building_id"
  buildings ||--o| building_locations : "building_id"
  buildings ||--o{ building_participation_grants : "building_id"
  buildings ||--o{ building_qr_codes : "building_id"
  organizations ||--o{ building_qr_codes : "organization_id"
  organizations ||--o{ buildings : "organization_id"
  users ||--o{ building_participation_grants : "trainee_user_id"
  users ||--o{ building_qr_codes : "created_by"
  users ||--o{ buildings : "created_by"
  buildings {
    uuid id PK
    uuid organization_id FK
    text name
    text building_type "NULL"
    int total_floors
    bool is_active
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
    timestamptz deleted_at "NULL"
    text visibility
    bigint access_revision
    varchar(64) participation_code_hash "NULL"
  }
  building_locations {
    uuid id PK
    uuid building_id FK, UK
    text address "NULL"
    text city "NULL"
    text district "NULL"
    numeric latitude "(10,8), NULL"
    numeric longitude "(11,8), NULL"
    jsonb geojson "NULL"
    timestamptz created_at
    timestamptz updated_at
  }
  building_contacts {
    uuid id PK
    uuid building_id FK
    text contact_name
    text contact_role "NULL"
    text phone "NULL"
    text email "NULL"
    bool is_primary
    timestamptz created_at
    timestamptz updated_at
  }
  building_participation_grants {
    uuid building_id PK, FK
    uuid trainee_user_id PK, FK
    bigint access_revision PK
    timestamptz granted_at
  }
  building_qr_codes {
    uuid id PK
    uuid building_id FK
    uuid organization_id FK
    varchar(64) token_hash UK
    varchar(255) label "NULL"
    text status
    uuid created_by FK
    timestamptz created_at
    timestamptz revoked_at "NULL"
    uuid replaced_by FK "NULL"
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*5 bảng, 10 khóa ngoại, 2 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `buildings(id, organization_id)`

## B3. IFC & xử lý (worker)

```mermaid
erDiagram
  annotation_sets |o--o{ revision_reviews : "annotation_set_id, revision_id"
  annotation_sets |o--o{ validation_runs : "annotation_set_id, revision_id"
  buildings ||--o{ ifc_upload_intents : "building_id"
  buildings ||--o{ revisions : "building_id, organization_id"
  ifc_upload_intents ||--o{ ifc_upload_attempts : "revision_id"
  organizations ||--o{ ifc_upload_intents : "organization_id"
  processing_job_attempts ||--o{ processing_candidate_outputs : "attempt_id"
  processing_job_attempts |o--o{ processing_jobs : "current_attempt_id"
  processing_job_attempts |o--o{ revision_artifacts : "attempt_id"
  processing_job_attempts |o--o{ validation_runs : "processing_attempt_id"
  processing_jobs ||--o{ processing_job_attempts : "processing_job_id"
  processing_jobs ||--o{ revision_artifacts : "job_id, revision_id"
  processing_jobs ||--o{ validation_runs : "job_id, revision_id"
  revision_artifacts |o--o{ validation_runs : "candidate_artifact_id, revision_id"
  revisions ||--o{ annotation_sets : "revision_id"
  revisions ||--o{ bim_facts : "revision_id"
  revisions ||--o| ifc_upload_intents : "revision_id"
  revisions ||--o{ processing_jobs : "revision_id"
  revisions ||--o{ revision_artifacts : "revision_id"
  revisions ||--o{ revision_equipment_decisions : "revision_id"
  revisions ||--o{ revision_reviews : "revision_id"
  revisions ||--o{ revision_style_selections : "revision_id"
  revisions ||--o| source_documents : "revision_id"
  revisions ||--o{ validation_runs : "revision_id"
  scenario_versions |o--o{ processing_jobs : "scenario_version_id"
  scenario_versions ||--o{ revision_reviews : "scenario_version_id"
  scenario_versions |o--o{ validation_runs : "scenario_version_id"
  source_documents |o--o{ ifc_upload_intents : "source_document_id"
  source_documents ||--o{ processing_jobs : "source_document_id, revision_id"
  users ||--o{ annotation_sets : "created_by"
  users ||--o{ ifc_upload_intents : "actor_id"
  users ||--o{ revision_equipment_decisions : "created_by"
  users ||--o{ revision_reviews : "reviewed_by"
  users ||--o{ revision_style_selections : "created_by"
  users ||--o{ revisions : "uploaded_by"
  users ||--o{ source_documents : "uploaded_by"
  validation_runs ||--o{ revision_issues : "validation_run_id"
  validation_runs ||--o{ revision_reviews : "validation_run_id"
  revisions {
    uuid id PK
    uuid building_id FK
    uuid organization_id FK
    uuid uploaded_by FK
    text version_label
    file_type_enum primary_type
    revision_status_enum status
    timestamptz created_at
    timestamptz updated_at
  }
  source_documents {
    uuid id PK
    uuid revision_id FK, UK
    uuid uploaded_by FK
    text original_filename
    file_type_enum file_type
    bigint file_size_bytes
    text storage_url
    text mime_type
    varchar(64) sha256_hash
    quarantine_status_enum quarantine_status
    text quarantine_note "NULL"
    text usage_rights
    text source_tool "NULL"
    timestamptz created_at
    timestamptz upload_verified_at "NULL"
    text source_etag "NULL"
  }
  ifc_upload_intents {
    uuid revision_id PK, FK
    uuid building_id FK
    uuid organization_id FK
    uuid actor_id FK
    varchar(128) idempotency_key
    varchar(64) input_hash
    text staging_key UK
    bigint size
    varchar(64) hash
    varchar(255) filename
    timestamptz expires_at
    timestamptz completed_at "NULL"
    varchar(64) completion_hash "NULL"
    text final_key "NULL"
    uuid source_document_id FK "NULL"
  }
  ifc_upload_attempts {
    uuid id PK
    uuid revision_id FK
    text final_key UK
    text source_etag
    varchar(64) input_hash
    timestamptz lease_until
    text state
    timestamptz created_at
  }
  ifc_object_cleanup {
    text object_key PK
    timestamptz available_at
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    int attempts
    timestamptz cleaned_at "NULL"
    text last_error "NULL"
  }
  processing_jobs {
    uuid id PK
    uuid revision_id FK
    uuid source_document_id FK
    text kind
    uuid scenario_version_id FK "NULL"
    uuid job_key UK
    text status
    text input_hash
    text lease_owner "NULL"
    timestamptz heartbeat_at "NULL"
    timestamptz started_at "NULL"
    timestamptz finished_at "NULL"
    text error_message "NULL"
    timestamptz created_at
    uuid current_attempt_id FK "NULL"
    jsonb input_snapshot "NULL"
  }
  processing_job_attempts {
    uuid id PK
    uuid processing_job_id FK
    int attempt_number
    varchar(64) input_hash
    varchar(100) toolchain_version
    varchar(100) lease_owner
    uuid lease_token UK
    timestamptz lease_until
    text status
    varchar(64) output_hash "NULL"
    timestamptz created_at
    timestamptz started_at
    timestamptz finished_at "NULL"
    text error_message "NULL"
  }
  processing_candidate_outputs {
    uuid attempt_id PK, FK
    text artifact_type PK
    varchar(64) input_hash
    uuid artifact_id UK
    jsonb output
  }
  revision_artifacts {
    uuid id PK
    uuid revision_id FK
    uuid job_id FK
    text artifact_type
    text object_key
    varchar(64) sha256_hash
    bigint size_bytes
    text schema_version
    jsonb metadata
    timestamptz created_at
    uuid attempt_id FK "NULL"
    bool is_runtime_ready
    text storage_key "NULL"
  }
  validation_runs {
    uuid id PK
    uuid revision_id FK
    uuid job_id FK, UK
    text kind
    uuid scenario_version_id FK "NULL"
    uuid candidate_artifact_id FK "NULL"
    uuid annotation_set_id FK "NULL"
    text outcome
    varchar(64) scenario_hash "NULL"
    text validator_version
    jsonb report
    timestamptz created_at
    uuid processing_attempt_id FK "NULL"
    uuid processing_job_id "NULL"
    uuid artifact_id "NULL"
    text scope "NULL"
    text status "NULL"
    jsonb summary "NULL"
    timestamptz started_at "NULL"
    timestamptz finished_at "NULL"
  }
  revision_issues {
    uuid id PK
    uuid validation_run_id FK
    text severity
    text code
    text ifc_guid "NULL"
    text message
    jsonb details
    timestamptz created_at
  }
  bim_facts {
    uuid id PK
    uuid revision_id FK
    varchar(255) ifc_global_id
    varchar(100) entity_type
    text property_path
    jsonb value "NULL"
    varchar(64) source_hash
    jsonb quality_flags
    timestamptz created_at
  }
  revision_equipment_decisions {
    uuid id PK
    uuid revision_id FK
    int version_number
    jsonb data
    uuid created_by FK
    timestamptz created_at
  }
  revision_style_selections {
    uuid id PK
    uuid revision_id FK
    int version_number
    jsonb data
    uuid created_by FK
    timestamptz created_at
  }
  annotation_sets {
    uuid id PK
    uuid revision_id FK
    int version_number
    jsonb data
    text provenance
    uuid created_by FK
    timestamptz created_at
  }
  revision_reviews {
    uuid id PK
    uuid revision_id FK
    uuid scenario_version_id FK
    uuid reviewed_by FK
    uuid validation_run_id FK
    uuid annotation_set_id FK "NULL"
    review_action_enum action
    text review_message "NULL"
    timestamptz reviewed_at
  }
  buildings {
    uuid id PK "nhóm 2"
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  scenario_versions {
    uuid id PK "nhóm 5"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*16 bảng, 38 khóa ngoại, 4 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `revisions(building_id, version_label)`; `revisions(id, building_id, organization_id)`; `revisions(id, organization_id)`; `source_documents(id, revision_id)`; `ifc_upload_intents(actor_id, idempotency_key)`; `processing_jobs(id, revision_id)`; `processing_job_attempts(id, processing_job_id)`; `processing_job_attempts(processing_job_id, attempt_number)`; `revision_artifacts(id, revision_id)`; `revision_artifacts(job_id, artifact_type, sha256_hash)`; `bim_facts(revision_id, ifc_global_id, property_path)`; `revision_equipment_decisions(revision_id, version_number)`; `revision_style_selections(revision_id, version_number)`; `annotation_sets(id, revision_id)`; `annotation_sets(revision_id, version_number)`; `revision_reviews(validation_run_id, action)`
- **Xóa dây chuyền:** `bim_facts` → `revisions` ON DELETE CASCADE

## B4. Outbox & giao job (Redis/HTTP)

```mermaid
erDiagram
  integration_outbox_events ||--o{ integration_event_consumptions : "event_key"
  integration_outbox_events ||--o| processing_delivery_receipts : "event_key"
  integration_outbox_events ||--o{ processing_stream_deliveries : "event_key"
  integration_outbox_events ||--o{ processing_stream_retry_receipts : "event_key"
  integration_outbox_events ||--o| processing_stream_state : "event_key"
  organizations |o--o{ integration_outbox_events : "organization_id"
  processing_job_attempts ||--o{ processing_delivery_receipts : "attempt_id"
  processing_jobs ||--o{ processing_stream_retry_receipts : "job_id"
  integration_outbox_events {
    varchar(255) idempotency_key PK
    varchar(80) aggregate_type
    uuid aggregate_id
    varchar(100) event_type
    varchar(50) schema_version
    uuid organization_id FK "NULL"
    jsonb payload
    varchar(64) payload_hash
    varchar(20) status
    int attempts
    timestamptz available_at
    varchar(255) lease_owner "NULL"
    uuid lease_token UK "NULL"
    timestamptz lease_until "NULL"
    uuid published_lease_token "NULL"
    text last_error "NULL"
    timestamptz created_at
    timestamptz published_at "NULL"
  }
  integration_event_consumptions {
    varchar(120) consumer_name PK
    varchar(255) event_key PK, FK
    varchar(64) payload_hash
    text result_reference "NULL"
    timestamptz processed_at
  }
  processing_delivery_receipts {
    text event_key PK, FK
    varchar(64) payload_hash
    uuid attempt_id FK
    uuid receipt_id UK
    timestamptz created_at
  }
  processing_stream_deliveries {
    bigint id PK
    text event_key FK
    uuid lease_token UK
    text stream_name
    text stream_id
    timestamptz published_at
  }
  processing_stream_state {
    text event_key PK, FK
    int delivery_failures
    timestamptz next_delivery_at
    text blocked_reason "NULL"
    timestamptz last_replay_at "NULL"
    text last_error "NULL"
  }
  processing_stream_rejections {
    text stream_name PK
    text stream_id PK
    text event_key "NULL"
    text code
    timestamptz created_at
  }
  processing_stream_retry_receipts {
    text request_key PK
    uuid job_id FK
    text event_key FK
    text reason
    jsonb previous_delivery
    timestamptz created_at
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  processing_job_attempts {
    uuid id PK "nhóm 3"
  }
  processing_jobs {
    uuid id PK "nhóm 3"
  }
```
*7 bảng, 8 khóa ngoại, 3 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `processing_stream_deliveries(stream_name, stream_id)`

## B5. Kịch bản & playtest

```mermaid
erDiagram
  buildings ||--o{ playtest_sessions : "building_id"
  buildings ||--o{ scenario_drafts : "building_id"
  buildings ||--o{ scenarios : "building_id, organization_id"
  organizations ||--o{ playtest_sessions : "organization_id"
  organizations ||--o{ scenario_drafts : "organization_id"
  playtest_sessions ||--o{ playtest_events : "playtest_id"
  playtest_sessions ||--o{ playtest_handoffs : "playtest_id"
  playtest_sessions ||--o| playtest_package_pins : "playtest_id"
  playtest_sessions ||--o| playtest_runtime_state : "playtest_id"
  processing_job_attempts ||--o{ playtest_package_pins : "attempt_id"
  revision_artifacts ||--o{ playtest_package_pins : "artifact_id"
  revision_artifacts ||--o{ playtest_package_pins : "manifest_artifact_id"
  revisions ||--o{ playtest_sessions : "revision_id"
  revisions ||--o{ scenario_drafts : "revision_id"
  revisions ||--o{ scenario_versions : "revision_id, building_id, organization_id"
  scenario_drafts |o--o{ playtest_sessions : "scenario_draft_id"
  scenario_versions ||--o{ playtest_sessions : "scenario_version_id"
  scenario_versions ||--o| scenario_content_reviews : "scenario_version_id"
  scenarios ||--o{ scenario_drafts : "scenario_id"
  scenarios ||--o{ scenario_versions : "scenario_id, building_id, organization_id"
  users ||--o{ playtest_handoffs : "created_by"
  users ||--o{ playtest_sessions : "created_by"
  users |o--o{ scenario_content_reviews : "reviewed_by"
  users ||--o{ scenario_content_reviews : "submitted_by"
  users ||--o{ scenario_drafts : "created_by"
  users ||--o{ scenario_versions : "created_by"
  users ||--o{ scenarios : "created_by"
  validation_runs ||--o{ playtest_package_pins : "validation_run_id"
  scenarios {
    uuid id PK
    uuid building_id FK
    uuid organization_id FK
    text name
    uuid created_by FK
    timestamptz created_at
  }
  scenario_drafts {
    uuid id PK
    uuid scenario_id FK
    uuid revision_id FK
    uuid organization_id FK
    uuid building_id FK
    int draft_number
    jsonb state
    text source
    uuid last_ai_request_id "NULL"
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
  }
  scenario_versions {
    uuid id PK
    uuid scenario_id FK
    uuid revision_id FK
    uuid building_id FK
    uuid organization_id FK
    int version_number
    text name
    text schema_version
    text algorithm_version
    bigint random_seed
    int time_limit_seconds
    jsonb spawn_config
    jsonb goal_config
    jsonb fire_source_config
    jsonb npc_config
    jsonb blocked_elements
    jsonb routing_config
    jsonb scoring_config
    jsonb mode_policy
    jsonb safety_thresholds
    int replan_interval_seconds
    varchar(64) scenario_hash
    uuid created_by FK
    timestamptz created_at
    jsonb state_snapshot "NULL"
    jsonb learning_objectives "NULL"
    text learner_instructions "NULL"
    jsonb rubric "NULL"
  }
  scenario_content_reviews {
    uuid id PK
    uuid scenario_version_id FK, UK
    text status
    varchar(64) content_hash
    varchar(64) rubric_hash
    uuid submitted_by FK
    timestamptz submitted_at
    uuid reviewed_by FK "NULL"
    timestamptz reviewed_at "NULL"
    text reason "NULL"
  }
  runtime_compatibility_catalog {
    uuid id PK
    text runtime_version
    text protocol_version
    text manifest_schema_version
    jsonb capabilities
    bool is_active
    timestamptz created_at
    jsonb capability_contracts
  }
  playtest_sessions {
    uuid id PK
    uuid organization_id FK
    uuid building_id FK
    uuid revision_id FK
    uuid scenario_draft_id FK "NULL"
    uuid scenario_version_id FK
    uuid service_entitlement_id "NULL"
    uuid created_by FK
    text package_hash
    text protocol_version
    text manifest_schema_version
    text prepare_idempotency_key "NULL"
    text runtime_version "NULL"
    text start_idempotency_key "NULL"
    text status
    text completion_idempotency_key "NULL"
    timestamptz created_at
    timestamptz started_at "NULL"
    timestamptz ended_at "NULL"
  }
  playtest_handoffs {
    uuid id PK
    uuid playtest_id FK
    varchar(64) code_hash UK
    bytea code_ciphertext "NULL"
    uuid issuing_family
    uuid created_by FK
    timestamptz created_at
    timestamptz expires_at
    timestamptz redeemed_at "NULL"
    uuid redeemed_family "NULL"
    timestamptz revoked_at "NULL"
  }
  playtest_package_pins {
    uuid playtest_id PK, FK
    uuid artifact_id FK
    uuid manifest_artifact_id FK
    uuid validation_run_id FK
    uuid attempt_id FK
    uuid prepared_family
    jsonb snapshot
    uuid started_family "NULL"
    timestamptz grant_issued_at "NULL"
    timestamptz grant_expires_at "NULL"
  }
  playtest_runtime_state {
    uuid playtest_id PK, FK
    uuid bound_family "NULL"
    timestamptz bound_at "NULL"
    int grant_generation
    timestamptz grant_issued_at "NULL"
    timestamptz grant_expires_at "NULL"
    int launched_generation "NULL"
    timestamptz launched_at "NULL"
    timestamptz last_heartbeat_at "NULL"
    timestamptz terminal_at "NULL"
    text terminal_status "NULL"
    varchar(64) completion_hash "NULL"
    jsonb completion "NULL"
  }
  playtest_events {
    uuid playtest_id PK, FK
    uuid event_id PK
    bigint sequence
    varchar(32) schema_version
    varchar(100) event_type
    timestamptz occurred_at "NULL"
    jsonb payload
    varchar(64) payload_hash
    timestamptz received_at
    varchar(64) rejection_code "NULL"
  }
  buildings {
    uuid id PK "nhóm 2"
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  processing_job_attempts {
    uuid id PK "nhóm 3"
  }
  revision_artifacts {
    uuid id PK "nhóm 3"
  }
  revisions {
    uuid id PK "nhóm 3"
  }
  users {
    uuid id PK "nhóm 1"
  }
  validation_runs {
    uuid id PK "nhóm 3"
  }
```
*10 bảng, 28 khóa ngoại, 7 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `scenarios(id, building_id, organization_id)`; `scenario_versions(id, revision_id, organization_id)`; `scenario_versions(scenario_id, version_number)`; `playtest_events(playtest_id, sequence)`
- **Xóa dây chuyền:** `scenario_drafts` → `buildings` ON DELETE CASCADE; `scenario_drafts` → `organizations` ON DELETE CASCADE; `scenario_drafts` → `revisions` ON DELETE CASCADE; `scenario_drafts` → `scenarios` ON DELETE CASCADE; `scenario_drafts` → `users` ON DELETE CASCADE; `playtest_sessions` → `buildings` ON DELETE CASCADE; `playtest_sessions` → `organizations` ON DELETE CASCADE; `playtest_sessions` → `revisions` ON DELETE CASCADE; `playtest_sessions` → `scenario_versions` ON DELETE CASCADE; `playtest_sessions` → `users` ON DELETE CASCADE

## B6. Phát hành & bài huấn luyện

```mermaid
erDiagram
  processing_job_attempts ||--o{ release_build_provenance : "attempt_id"
  releases ||--o| release_build_provenance : "release_id"
  releases ||--o| release_packages : "release_id"
  releases ||--o{ trainings : "release_id, scenario_version_id, organization_id"
  revision_artifacts ||--o{ release_build_provenance : "manifest_artifact_id"
  revision_artifacts ||--o{ release_packages : "candidate_artifact_id"
  revision_reviews ||--o{ releases : "confirmation_review_id"
  revisions ||--o{ releases : "revision_id, building_id, organization_id"
  scenario_content_reviews ||--o{ release_build_provenance : "content_review_id"
  scenario_versions ||--o{ releases : "scenario_version_id, revision_id, organization_id"
  users |o--o{ releases : "published_by"
  users |o--o{ releases : "revoked_by"
  users ||--o{ trainings : "created_by"
  validation_runs ||--o{ release_build_provenance : "validation_run_id"
  releases {
    uuid id PK
    uuid revision_id FK
    uuid scenario_version_id FK
    uuid building_id FK
    uuid organization_id FK
    uuid confirmation_review_id FK
    uuid published_by FK "NULL"
    uuid revoked_by FK "NULL"
    release_status_enum status
    jsonb safety_thresholds
    text revoked_reason "NULL"
    timestamptz published_at "NULL"
    timestamptz revoked_at "NULL"
    timestamptz created_at
    timestamptz updated_at
  }
  release_packages {
    uuid id PK
    uuid release_id FK, UK
    uuid candidate_artifact_id FK
    text manifest_url
    varchar(64) manifest_sha256
    text package_url
    varchar(64) checksum_sha256
    bigint package_size_bytes
    text min_runtime_version
    text schema_version
    text build_target
    timestamptz created_at
  }
  release_build_provenance {
    uuid release_id PK, FK
    uuid validation_run_id FK
    uuid manifest_artifact_id FK
    uuid attempt_id FK
    uuid content_review_id FK
    timestamptz created_at
  }
  trainings {
    uuid id PK
    uuid release_id FK
    uuid scenario_version_id FK
    uuid organization_id FK
    text name
    text description "NULL"
    timestamptz start_date "NULL"
    timestamptz end_date "NULL"
    training_status_enum status
    session_mode_enum mode
    text[] allowed_modes
    int max_attempts "NULL"
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
  }
  processing_job_attempts {
    uuid id PK "nhóm 3"
  }
  revision_artifacts {
    uuid id PK "nhóm 3"
  }
  revision_reviews {
    uuid id PK "nhóm 3"
  }
  revisions {
    uuid id PK "nhóm 3"
  }
  scenario_content_reviews {
    uuid id PK "nhóm 5"
  }
  scenario_versions {
    uuid id PK "nhóm 5"
  }
  users {
    uuid id PK "nhóm 1"
  }
  validation_runs {
    uuid id PK "nhóm 3"
  }
```
*4 bảng, 14 khóa ngoại, 8 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `releases(id, scenario_version_id, organization_id)`; `releases(revision_id, scenario_version_id)`; `trainings(id, release_id, organization_id)`; `trainings(id, release_id, scenario_version_id, organization_id)`

## B7. Phiên học viên & chấm điểm

```mermaid
erDiagram
  billing_learner_seats |o--o{ sessions : "seat_id"
  buildings ||--o{ billing_learner_seats : "building_id"
  buildings |o--o{ sessions : "building_id"
  buildings ||--o{ training_session_preparations : "building_id"
  organizations ||--o{ billing_learner_seats : "organization_id"
  organizations ||--o{ training_session_preparations : "organization_id"
  service_entitlements ||--o{ billing_learner_seats : "entitlement_id"
  service_entitlements |o--o{ sessions : "entitlement_id"
  sessions ||--o{ session_events : "session_id"
  sessions ||--o| session_results : "session_id"
  trainings ||--o{ sessions : "training_id, release_id, scenario_version_id, organization_id"
  trainings ||--o{ training_session_preparations : "training_id, release_id, scenario_version_id, organization_id"
  user_devices |o--o{ sessions : "device_id, trainee_user_id"
  users ||--o{ billing_learner_seats : "trainee_id"
  users ||--o{ sessions : "trainee_user_id"
  users ||--o{ training_session_preparations : "trainee_user_id"
  training_session_preparations {
    uuid id PK
    uuid trainee_user_id FK
    uuid organization_id FK
    uuid building_id FK
    uuid training_id FK
    uuid release_id FK
    uuid scenario_version_id FK
    text mode
    varchar(64) scenario_hash
    varchar(64) rubric_hash "NULL"
    jsonb package
    text runtime_version
    text status
    timestamptz created_at
    timestamptz expires_at
    timestamptz started_at "NULL"
  }
  sessions {
    uuid id PK
    uuid training_id FK
    uuid release_id FK
    uuid scenario_version_id FK
    uuid organization_id FK
    uuid trainee_user_id FK
    uuid device_id FK "NULL"
    uuid start_key
    text app_version "NULL"
    text unity_version "NULL"
    text protocol_version
    varchar(64) scenario_hash
    varchar(64) release_hash
    session_mode_enum mode
    session_status_enum status
    timestamptz started_at
    timestamptz launched_at "NULL"
    timestamptz ended_at "NULL"
    text terminal_reason "NULL"
    release_status_enum content_status_at_completion "NULL"
    int contract_version
    uuid building_id FK "NULL"
    uuid entitlement_id FK "NULL"
    uuid seat_id FK "NULL"
    varchar(64) rubric_hash "NULL"
    jsonb package "NULL"
    text runtime_version "NULL"
    uuid launch_family "NULL"
    int grant_generation "NULL"
    timestamptz grant_issued_at "NULL"
    timestamptz grant_expires_at "NULL"
    timestamptz last_heartbeat_at "NULL"
    uuid continuation_id "NULL"
    timestamptz continuation_expires_at "NULL"
    varchar(128) completion_key "NULL"
    varchar(64) completion_hash "NULL"
    bigint completion_last_sequence "NULL"
    text completion_end_reason "NULL"
    timestamptz completion_requested_at "NULL"
  }
  session_events {
    uuid id PK
    uuid session_id FK
    bigint sequence_number
    uuid client_event_id
    text schema_version
    text event_type
    jsonb event_data
    bigint elapsed_ms
    timestamptz recorded_at
    timestamptz received_at
    varchar(64) payload_hash "NULL"
    varchar(64) rejection_code "NULL"
  }
  session_results {
    uuid id PK
    uuid session_id FK, UK
    uuid completion_key
    bigint last_event_sequence
    jsonb submission_payload
    text result_schema_version
    text rubric_version
    numeric score "(5,2), NULL"
    int time_taken_seconds "NULL"
    int wrong_exits "NULL"
    numeric hazard_exposure_score "(12,2), NULL"
    numeric total_distance_meters "(12,2), NULL"
    bool reached_exit "NULL"
    text exit_point_id "NULL"
    jsonb path_traveled "NULL"
    timestamptz client_started_at "NULL"
    timestamptz client_ended_at "NULL"
    timestamptz synced_at
    timestamptz created_at
    int contract_version
    text mode "NULL"
    text outcome "NULL"
    text outcome_reason "NULL"
    varchar(64) rubric_hash "NULL"
    jsonb criterion_results "NULL"
    jsonb metrics "NULL"
  }
  billing_learner_seats {
    uuid id PK
    uuid entitlement_id FK
    uuid organization_id FK
    uuid building_id FK
    uuid trainee_id FK
    uuid first_session_id
    timestamptz allocated_at
  }
  buildings {
    uuid id PK "nhóm 2"
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  service_entitlements {
    uuid id PK "nhóm 8"
  }
  trainings {
    uuid id PK "nhóm 6"
  }
  user_devices {
    uuid id PK "nhóm 1"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*5 bảng, 16 khóa ngoại, 6 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `sessions(trainee_user_id, start_key)`; `session_events(session_id, client_event_id)`; `session_events(session_id, sequence_number)`; `billing_learner_seats(entitlement_id, trainee_id)`

## B8. Báo giá, PayOS & dịch vụ

```mermaid
erDiagram
  billing_ai_quota_grants ||--o{ billing_ai_quota_allocations : "grant_id"
  billing_checkout_operations ||--o{ billing_service_reservations : "checkout_id"
  billing_checkout_operations ||--o{ billing_upgrade_reservations : "checkout_id"
  billing_entitlement_upgrades |o--o| billing_ai_quota_grants : "upgrade_id"
  billing_quota_policy_versions ||--o{ billing_ai_quota_grants : "policy_version_id"
  billing_quota_policy_versions |o--o{ quotation_building_items : "ai_policy_version_id"
  billing_quota_policy_versions |o--o{ quotation_topup_items : "policy_version_id"
  billing_quota_policy_versions |o--o{ service_packages : "ai_policy_version_id"
  buildings ||--o{ billing_service_reservations : "building_id"
  buildings ||--o{ quotation_building_items : "building_id"
  buildings ||--o{ service_entitlements : "building_id"
  enterprise_quote_requests ||--o{ enterprise_quote_responses : "request_id"
  organizations ||--o{ billing_ai_quota_allocations : "organization_id"
  organizations ||--o{ billing_ai_quota_grants : "organization_id"
  organizations ||--o{ billing_service_reservations : "organization_id"
  organizations ||--o{ enterprise_quote_requests : "organization_id"
  organizations ||--o{ payment_provisioning_records : "organization_id"
  organizations ||--o{ payos_payment_requests : "organization_id"
  organizations ||--o{ quotation_topup_items : "organization_id"
  organizations ||--o{ quotations : "organization_id"
  organizations ||--o{ service_entitlements : "organization_id"
  payment_transactions ||--o{ billing_ai_quota_grants : "payment_transaction_id"
  payment_transactions ||--o{ billing_entitlement_upgrades : "payment_transaction_id"
  payment_transactions ||--o{ payment_provisioning_records : "payment_transaction_id"
  payment_transactions |o--o{ payos_payment_requests : "paid_transaction_id, id"
  payment_transactions |o--o{ service_entitlements : "payment_transaction_id"
  payos_payment_requests |o--o{ billing_checkout_operations : "payment_request_id"
  payos_payment_requests ||--o{ payment_transactions : "payment_request_id"
  quotation_building_items |o--o{ billing_ai_quota_grants : "quotation_item_id"
  quotation_building_items ||--o{ billing_entitlement_upgrades : "quotation_item_id"
  quotation_building_items ||--o{ billing_service_reservations : "quotation_item_id"
  quotation_building_items ||--o{ billing_upgrade_reservations : "quotation_item_id"
  quotation_building_items |o--o{ service_entitlements : "quotation_item_id, quotation_id"
  quotation_topup_items |o--o{ billing_ai_quota_grants : "topup_item_id"
  quotations ||--o{ billing_checkout_operations : "quotation_id"
  quotations |o--o{ enterprise_quote_requests : "quotation_id"
  quotations ||--o{ payment_provisioning_records : "quotation_id"
  quotations ||--o{ payos_payment_requests : "quotation_id"
  quotations ||--o{ quotation_building_items : "quotation_id"
  quotations ||--o| quotation_topup_items : "quotation_id"
  quotations |o--o{ service_entitlements : "quotation_id"
  service_entitlements |o--o{ billing_ai_quota_grants : "entitlement_id"
  service_entitlements ||--o{ billing_entitlement_upgrades : "entitlement_id"
  service_entitlements ||--o{ billing_upgrade_reservations : "entitlement_id"
  service_entitlements |o--o{ quotation_building_items : "upgrade_entitlement_id"
  service_package_discount_rules |o--o{ quotations : "discount_rule_id"
  service_packages ||--o{ quotation_building_items : "service_package_id"
  service_packages |o--o{ quotations : "service_package_id"
  service_packages ||--o{ service_entitlements : "service_package_id"
  service_packages |o--o{ service_package_discount_rules : "service_package_id"
  users ||--o{ billing_checkout_operations : "actor_id"
  users ||--o{ billing_quota_policy_versions : "created_by"
  users |o--o{ enterprise_quote_requests : "assigned_to"
  users |o--o{ enterprise_quote_requests : "closed_by"
  users ||--o{ enterprise_quote_requests : "requested_by"
  users ||--o{ enterprise_quote_responses : "author_id"
  users ||--o{ payos_payment_requests : "requested_by"
  users |o--o{ quotations : "issued_by"
  users ||--o{ quotations : "requested_by"
  users ||--o{ service_entitlements : "created_by"
  users ||--o{ service_package_discount_rules : "created_by"
  users ||--o{ service_packages : "created_by"
  service_packages {
    uuid id PK
    varchar(50) code UK
    varchar(255) name
    text description "NULL"
    numeric unit_price "(14,2)"
    varchar(3) currency
    int duration_months "NULL"
    jsonb features
    bool is_active
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
    bigint revision
    int commercial_version
    int learner_limit "NULL"
    int ai_quota_units "NULL"
    uuid ai_policy_version_id FK "NULL"
  }
  service_package_discount_rules {
    uuid id PK
    uuid service_package_id FK "NULL"
    varchar(80) code UK
    varchar(20) discount_kind
    numeric discount_value "(14,2)"
    varchar(3) discount_currency "NULL"
    int minimum_buildings
    int minimum_duration_months "NULL"
    timestamptz valid_from
    timestamptz valid_until "NULL"
    bool is_active
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
    bigint revision
  }
  billing_quota_policy_versions {
    uuid id PK
    text audience
    text policy_kind
    text quota_unit
    timestamptz effective_from
    timestamptz effective_until "NULL"
    text rollover
    uuid created_by FK
    timestamptz created_at
  }
  quotations {
    uuid id PK
    uuid organization_id FK
    uuid service_package_id FK "NULL"
    uuid requested_by FK
    uuid issued_by FK "NULL"
    varchar(50) quotation_number UK
    quotation_status_enum status
    int quantity
    numeric unit_price "(14,2)"
    numeric subtotal_amount "(14,2)"
    numeric tax_amount "(14,2)"
    numeric discount_amount "(14,2)"
    numeric total_amount "(14,2)"
    varchar(3) currency
    timestamptz valid_until
    timestamptz issued_at "NULL"
    timestamptz accepted_at "NULL"
    timestamptz created_at
    timestamptz updated_at
    varchar(30) billing_purpose
    uuid discount_rule_id FK "NULL"
    jsonb discount_snapshot
    jsonb price_snapshot
    jsonb terms_snapshot
    bigint revision
    int commercial_version
  }
  quotation_building_items {
    uuid id PK
    uuid quotation_id FK
    uuid building_id FK
    uuid service_package_id FK
    varchar(20) purchase_action
    int service_duration_months
    numeric unit_price "(14,2)"
    numeric discount_amount "(14,2)"
    numeric subtotal_amount "(14,2)"
    numeric total_amount "(14,2)"
    varchar(3) currency
    jsonb price_snapshot
    jsonb terms_snapshot
    jsonb discount_snapshot
    varchar(255) line_provisioning_key UK "NULL"
    timestamptz created_at
    timestamptz updated_at
    int commercial_version
    bigint package_revision "NULL"
    int learner_limit "NULL"
    int ai_quota_units "NULL"
    uuid ai_policy_version_id FK "NULL"
    text ai_quota_unit "NULL"
    timestamptz starts_at "NULL"
    timestamptz ends_at "NULL"
    text pricing_basis
    uuid upgrade_entitlement_id FK "NULL"
    int upgrade_base_capacity_revision "NULL"
    int upgrade_previous_learner_limit "NULL"
  }
  quotation_topup_items {
    uuid id PK
    uuid quotation_id FK, UK
    uuid organization_id FK
    int requested_quota_units "NULL"
    uuid policy_version_id FK "NULL"
    text quota_unit "NULL"
    int quota_units "NULL"
    numeric amount "(14,2), NULL"
    timestamptz starts_at "NULL"
    timestamptz ends_at "NULL"
    text line_provisioning_key UK
    timestamptz created_at
    timestamptz updated_at
  }
  billing_checkout_operations {
    uuid id PK
    uuid quotation_id FK
    uuid actor_id FK
    varchar(128) idempotency_key
    varchar(64) input_hash
    bigint order_code UK
    varchar(30) status
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    jsonb provider_result "NULL"
    timestamptz created_at
    timestamptz updated_at
    jsonb provider_input
    varchar(100) payment_link_id "NULL"
    uuid payment_request_id FK "NULL"
    timestamptz expires_at "NULL"
    int attempts
    timestamptz next_attempt_at
    varchar(80) last_error "NULL"
    bool cancel_requested
    uuid session_family_id "NULL"
  }
  billing_service_reservations {
    uuid id PK
    uuid checkout_id FK
    uuid quotation_item_id FK
    uuid building_id FK
    uuid organization_id FK
    timestamptz starts_at
    timestamptz ends_at
    text status
    timestamptz created_at
    timestamptz updated_at
  }
  billing_upgrade_reservations {
    uuid id PK
    uuid checkout_id FK
    uuid quotation_item_id FK
    uuid entitlement_id FK
    int base_capacity_revision
    text status
    timestamptz created_at
    timestamptz updated_at
  }
  payos_payment_requests {
    uuid id PK, FK
    uuid quotation_id FK
    uuid organization_id FK
    uuid requested_by FK
    bigint order_code UK
    numeric expected_amount "(14,2)"
    varchar(3) expected_currency
    text checkout_url
    text return_url
    text cancel_url
    payment_request_status_enum status
    uuid paid_transaction_id FK, UK "NULL"
    timestamptz expires_at "NULL"
    timestamptz paid_at "NULL"
    timestamptz created_at
    timestamptz updated_at
    varchar(255) idempotency_key
    varchar(100) payment_link_id "NULL"
  }
  payos_webhook_inbox {
    uuid id PK
    varchar(255) event_key UK
    varchar(64) input_hash
    bigint order_code
    jsonb payload
    timestamptz verified_at
    varchar(30) status
    int attempts
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    timestamptz next_attempt_at
    timestamptz created_at
    varchar(80) last_error "NULL"
    timestamptz processed_at "NULL"
  }
  payment_transactions {
    uuid id PK
    uuid payment_request_id FK
    varchar(255) webhook_event_id UK
    varchar(255) provider_transaction_id UK "NULL"
    bigint received_order_code
    numeric received_amount "(14,2)"
    varchar(3) received_currency
    bool signature_verified
    payment_transaction_status_enum status
    jsonb raw_payload
    text rejection_reason "NULL"
    timestamptz received_at
    timestamptz signature_verified_at "NULL"
    timestamptz processed_at "NULL"
  }
  payment_provisioning_records {
    uuid id PK
    uuid payment_transaction_id FK
    uuid quotation_id FK
    uuid quotation_item_id
    uuid organization_id FK
    varchar(255) provisioning_key UK
    varchar(30) status
    int attempts
    text last_error "NULL"
    timestamptz provisioned_at "NULL"
    timestamptz created_at
    timestamptz updated_at
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    timestamptz next_attempt_at
  }
  service_entitlements {
    uuid id PK
    uuid organization_id FK
    uuid building_id FK
    uuid service_package_id FK
    uuid quotation_id FK "NULL"
    uuid quotation_item_id FK "NULL"
    uuid payment_transaction_id FK "NULL"
    varchar(255) provisioning_key UK
    varchar(30) status
    timestamptz starts_at
    timestamptz ends_at
    jsonb price_snapshot
    jsonb terms_snapshot
    int playtest_units_granted
    int playtest_units_used
    uuid created_by FK
    timestamptz created_at
    int commercial_version
    int learner_limit "NULL"
  }
  billing_entitlement_upgrades {
    uuid id PK
    uuid entitlement_id FK
    int capacity_revision
    int previous_learner_limit
    int learner_limit
    int additional_quota_units
    timestamptz effective_from
    uuid quotation_item_id FK
    uuid payment_transaction_id FK
    text provisioning_key UK
    timestamptz created_at
  }
  billing_ai_quota_grants {
    uuid id PK
    uuid organization_id FK
    uuid policy_version_id FK
    text quota_unit
    int quota_units
    timestamptz starts_at
    timestamptz ends_at
    uuid quotation_item_id FK "NULL"
    uuid payment_transaction_id FK
    uuid entitlement_id FK "NULL"
    text provisioning_key UK
    text rollover
    timestamptz created_at
    text source_kind
    uuid upgrade_id FK, UK "NULL"
    uuid topup_item_id FK "NULL"
  }
  billing_ai_quota_allocations {
    uuid id PK
    uuid grant_id FK
    uuid organization_id FK
    uuid request_id
    text quota_unit
    int reserved_units
    int consumed_units "NULL"
    text status
    timestamptz created_at
    timestamptz settled_at "NULL"
  }
  enterprise_quote_requests {
    uuid id PK
    uuid organization_id FK
    uuid requested_by FK
    int requested_building_count
    int requested_duration_months "NULL"
    text contact_name
    varchar(255) contact_email
    varchar(50) contact_phone "NULL"
    text notes "NULL"
    varchar(20) status
    uuid quotation_id FK "NULL"
    varchar(255) idempotency_key UK
    timestamptz created_at
    timestamptz updated_at
    bigint revision
    uuid assigned_to FK "NULL"
    timestamptz closed_at "NULL"
    uuid closed_by FK "NULL"
    text close_reason "NULL"
  }
  enterprise_quote_responses {
    uuid id PK
    uuid request_id FK
    uuid author_id FK
    text message
    timestamptz created_at
  }
  buildings {
    uuid id PK "nhóm 2"
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*19 bảng, 62 khóa ngoại, 3 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `quotation_building_items(id, quotation_id)`; `quotation_building_items(quotation_id, building_id)`; `billing_checkout_operations(actor_id, idempotency_key)`; `billing_service_reservations(checkout_id, quotation_item_id)`; `billing_upgrade_reservations(checkout_id, quotation_item_id)`; `payment_transactions(id, payment_request_id)`; `payment_provisioning_records(payment_transaction_id, quotation_item_id)`; `service_entitlements(building_id, starts_at)`; `service_entitlements(quotation_item_id, payment_transaction_id)`; `billing_entitlement_upgrades(entitlement_id, capacity_revision)`; `billing_entitlement_upgrades(quotation_item_id, payment_transaction_id)`; `billing_ai_quota_grants(quotation_item_id, payment_transaction_id)`; `billing_ai_quota_grants(topup_item_id, payment_transaction_id)`; `billing_ai_quota_allocations(request_id, grant_id)`

## B9. AI & kho tri thức

```mermaid
erDiagram
  ai_operation_policies ||--o{ ai_requests : "policy_id"
  knowledge_sources ||--o{ knowledge_chunks : "source_id"
  knowledge_sources |o--o| knowledge_source_files : "source_id"
  organizations |o--o{ ai_requests : "organization_id"
  organizations |o--o{ knowledge_sources : "organization_id"
  users ||--o{ ai_operation_policies : "created_by"
  users ||--o{ ai_requests : "actor_user_id"
  users |o--o{ ai_requests : "reconcile_requested_by"
  users ||--o{ knowledge_source_files : "created_by"
  users |o--o{ knowledge_sources : "approved_by"
  users ||--o{ knowledge_sources : "created_by"
  ai_operation_policies {
    uuid id PK
    text operation
    text quota_unit
    int reserve_units
    int max_input_chars
    int max_sources
    timestamptz effective_from
    timestamptz effective_until "NULL"
    uuid created_by FK
    timestamptz created_at
    int daily_units "NULL"
  }
  ai_requests {
    uuid id PK
    uuid organization_id FK "NULL"
    uuid actor_user_id FK
    text operation
    uuid policy_id FK
    text quota_unit
    int reserved_units
    int consumed_units "NULL"
    text status
    jsonb input
    varchar(64) input_hash
    jsonb sources
    jsonb result "NULL"
    jsonb provider_result "NULL"
    varchar(80) failure_code "NULL"
    int attempts
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    timestamptz next_attempt_at
    timestamptz reconcile_requested_at "NULL"
    uuid reconcile_requested_by FK "NULL"
    timestamptz created_at
    timestamptz updated_at
    timestamptz completed_at "NULL"
    bigint revision
    text audience
    text result_type "NULL"
    jsonb context "NULL"
    jsonb bim "NULL"
    text model_version "NULL"
    jsonb technical_usage "NULL"
  }
  knowledge_sources {
    uuid id PK
    uuid organization_id FK "NULL"
    text visibility
    text title
    text source_uri "NULL"
    varchar(100) version_label
    varchar(64) source_hash
    text jurisdiction "NULL"
    timestamptz effective_from "NULL"
    timestamptz effective_until "NULL"
    text approval_status
    uuid approved_by FK "NULL"
    timestamptz approved_at "NULL"
    uuid created_by FK
    timestamptz created_at
    bigint revision
  }
  knowledge_chunks {
    uuid id PK
    uuid source_id FK
    int chunk_index
    text content
    jsonb locator
    vector embedding "NULL"
    jsonb metadata
    timestamptz created_at
  }
  knowledge_source_files {
    uuid id PK
    uuid created_by FK
    varchar(128) idempotency_key
    char(64) input_hash
    varchar(255) file_name
    text content_type
    bigint size_bytes
    text staging_key UK
    text object_key UK "NULL"
    char(64) sha256 "NULL"
    uuid source_id FK, UK "NULL"
    timestamptz created_at
    timestamptz expires_at
    timestamptz completed_at "NULL"
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*5 bảng, 11 khóa ngoại, 2 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `knowledge_chunks(source_id, chunk_index)`; `knowledge_source_files(created_by, idempotency_key)`
- **Xóa dây chuyền:** `knowledge_chunks` → `knowledge_sources` ON DELETE CASCADE

## B10. Learn & thư viện tổ chức

```mermaid
erDiagram
  knowledge_sources ||--o{ learn_post_version_sources : "source_id"
  learn_post_versions ||--o{ learn_post_version_situations : "post_version_id"
  learn_post_versions ||--o{ learn_post_version_sources : "post_version_id"
  learn_post_versions |o--o{ learn_posts : "published_version_id, id"
  learn_posts ||--o{ learn_bookmarks : "post_id"
  learn_posts ||--o{ learn_post_versions : "post_id"
  learn_situations ||--o{ learn_post_version_situations : "situation_id"
  organization_library_items ||--o{ organization_library_versions : "item_id"
  users ||--o{ learn_bookmarks : "trainee_user_id"
  users ||--o{ learn_media_images : "created_by"
  users ||--o{ learn_post_versions : "created_by"
  users |o--o{ learn_post_versions : "published_by"
  users ||--o{ learn_posts : "created_by"
  users ||--o{ learn_situations : "created_by"
  users ||--o{ organization_library_items : "created_by"
  users ||--o{ organization_library_versions : "created_by"
  users |o--o{ organization_library_versions : "published_by"
  learn_situations {
    uuid id PK
    varchar(120) slug UK
    varchar(255) name
    text description "NULL"
    bool is_active
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
  }
  learn_posts {
    uuid id PK, FK
    varchar(180) slug UK
    text publication_status
    uuid published_version_id FK "NULL"
    uuid created_by FK
    bigint revision_no
    timestamptz created_at
    timestamptz updated_at
  }
  learn_post_versions {
    uuid id PK
    uuid post_id FK
    int version_number
    varchar(50) content_schema_version
    text content_kind
    varchar(255) title
    text summary
    text cover_image_url "NULL"
    jsonb content_blocks
    varchar(64) content_hash
    text status
    uuid created_by FK
    uuid published_by FK "NULL"
    timestamptz published_at "NULL"
    bigint revision_no
    timestamptz created_at
    timestamptz updated_at
  }
  learn_post_version_situations {
    uuid post_version_id PK, FK
    uuid situation_id PK, FK
    timestamptz created_at
  }
  learn_post_version_sources {
    uuid post_version_id PK, FK
    uuid source_id PK, FK
    text source_role PK
    jsonb locator
    timestamptz created_at
  }
  learn_bookmarks {
    uuid trainee_user_id PK, FK
    uuid post_id PK, FK
    timestamptz created_at
  }
  organization_library_items {
    uuid id PK
    text kind
    varchar(80) code UK
    bool is_active
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
    bigint revision
  }
  organization_library_versions {
    uuid id PK
    uuid item_id FK
    int version_number
    varchar(255) name
    jsonb payload
    jsonb required_capabilities
    varchar(64) payload_hash
    text status
    uuid published_by FK "NULL"
    timestamptz published_at "NULL"
    uuid created_by FK
    timestamptz created_at
    timestamptz updated_at
    bigint revision
  }
  learn_media_images {
    uuid id PK
    uuid created_by FK
    varchar(128) idempotency_key
    char(64) input_hash
    varchar(255) file_name
    text content_type
    bigint size_bytes
    char(64) sha256
    text staging_key UK
    text object_key UK "NULL"
    int width "NULL"
    int height "NULL"
    timestamptz created_at
    timestamptz expires_at
    timestamptz completed_at "NULL"
  }
  knowledge_sources {
    uuid id PK "nhóm 9"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*9 bảng, 17 khóa ngoại, 2 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `learn_post_versions(id, post_id)`; `learn_post_versions(post_id, version_number)`; `organization_library_versions(item_id, version_number)`; `learn_media_images(created_by, idempotency_key)`

## B11. Hỗ trợ, thông báo, audit

```mermaid
erDiagram
  buildings ||--o{ organization_notifications : "building_id"
  feedback |o--o{ support_tickets : "feedback_id"
  organization_notifications ||--o{ notification_deliveries : "notification_id"
  organizations |o--o{ analytics_exports : "organization_id"
  organizations |o--o{ feedback : "organization_id"
  organizations ||--o{ organization_notifications : "organization_id"
  organizations |o--o{ support_tickets : "organization_id"
  service_entitlements ||--o{ organization_notifications : "entitlement_id"
  sessions |o--o{ feedback : "session_id"
  sessions |o--o{ support_tickets : "session_id"
  support_tickets ||--o{ support_ticket_messages : "ticket_id"
  users ||--o{ analytics_exports : "actor_id"
  users |o--o{ feedback : "reviewed_by"
  users ||--o{ feedback : "submitted_by"
  users ||--o{ organization_notifications : "recipient_user_id"
  users ||--o{ support_ticket_messages : "author_id"
  users |o--o{ support_tickets : "assigned_to"
  users ||--o{ support_tickets : "created_by"
  feedback {
    uuid id PK
    uuid submitted_by FK
    uuid organization_id FK "NULL"
    uuid session_id FK "NULL"
    varchar(100) category
    int rating "NULL"
    text message
    feedback_status_enum status
    uuid reviewed_by FK "NULL"
    timestamptz reviewed_at "NULL"
    timestamptz created_at
    timestamptz updated_at
    bigint revision
  }
  support_tickets {
    uuid id PK
    varchar(50) ticket_number UK
    uuid created_by FK
    uuid organization_id FK "NULL"
    uuid session_id FK "NULL"
    uuid feedback_id FK "NULL"
    uuid assigned_to FK "NULL"
    varchar(255) subject
    text description
    support_priority_enum priority
    support_ticket_status_enum status
    timestamptz resolved_at "NULL"
    timestamptz created_at
    timestamptz updated_at
    bigint revision
  }
  support_ticket_messages {
    uuid id PK
    uuid ticket_id FK
    uuid author_id FK
    text message
    timestamptz created_at
  }
  organization_notifications {
    uuid id PK
    uuid organization_id FK
    uuid recipient_user_id FK
    uuid building_id FK
    uuid entitlement_id FK
    varchar(50) notification_type
    text title
    text body
    timestamptz reference_ends_at
    varchar(255) idempotency_key UK
    timestamptz read_at "NULL"
    timestamptz created_at
  }
  notification_deliveries {
    uuid id PK
    uuid notification_id FK
    varchar(20) channel
    varchar(20) status
    int attempts
    text provider_message_id "NULL"
    text last_error "NULL"
    timestamptz sent_at "NULL"
    timestamptz created_at
    timestamptz updated_at
    uuid lease_token "NULL"
    timestamptz lease_until "NULL"
    timestamptz next_attempt_at
  }
  audit_logs {
    uuid id PK
    uuid user_id "NULL"
    uuid organization_id "NULL"
    text actor_type
    audit_action_enum action
    text target_entity
    uuid target_id "NULL"
    uuid correlation_id
    jsonb old_values "NULL"
    jsonb new_values "NULL"
    inet ip_address "NULL"
    text user_agent "NULL"
    timestamptz created_at
  }
  analytics_exports {
    uuid id PK
    uuid actor_id FK
    uuid organization_id FK "NULL"
    text report
    jsonb filters
    int row_count
    timestamptz created_at
  }
  buildings {
    uuid id PK "nhóm 2"
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  service_entitlements {
    uuid id PK "nhóm 8"
  }
  sessions {
    uuid id PK "nhóm 7"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*7 bảng, 18 khóa ngoại, 5 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `notification_deliveries(notification_id, channel)`
- **Xóa dây chuyền:** `feedback` → `organizations` ON DELETE SET NULL; `feedback` → `sessions` ON DELETE SET NULL; `support_tickets` → `feedback` ON DELETE SET NULL; `support_tickets` → `organizations` ON DELETE SET NULL; `support_tickets` → `sessions` ON DELETE SET NULL

## B12. Biên nhận idempotency

```mermaid
erDiagram
  organizations |o--o{ application_command_receipts : "organization_id"
  processing_jobs ||--o{ processing_command_receipts : "job_id"
  users ||--o{ ai_command_receipts : "actor_user_id"
  users ||--o{ application_command_receipts : "actor_user_id"
  users ||--o{ authoring_command_receipts : "actor_id"
  users ||--o{ billing_command_receipts : "actor_id"
  users ||--o{ content_command_receipts : "actor_id"
  users ||--o{ learner_command_receipts : "actor_id"
  users ||--o{ playtest_command_receipts : "actor_id"
  users ||--o{ processing_command_receipts : "actor_id"
  users ||--o{ readiness_command_receipts : "actor_id"
  users ||--o{ release_command_receipts : "actor_id"
  users ||--o{ support_command_receipts : "actor_id"
  ai_command_receipts {
    uuid actor_user_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    jsonb result
    timestamptz created_at
  }
  application_command_receipts {
    uuid id PK
    uuid actor_user_id FK
    uuid organization_id FK "NULL"
    varchar(100) operation_name
    varchar(255) idempotency_key
    varchar(128) input_hash
    varchar(30) result_status
    jsonb result_payload
    timestamptz created_at
  }
  authoring_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    uuid result_id
    timestamptz created_at
  }
  billing_command_receipts {
    uuid id PK
    uuid actor_id FK
    varchar(80) operation
    varchar(128) idempotency_key
    varchar(64) input_hash
    uuid resource_id
    timestamptz created_at
    jsonb response "NULL"
  }
  content_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    jsonb result
    timestamptz created_at
  }
  learner_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    jsonb result
    timestamptz created_at
  }
  playtest_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    jsonb result
    timestamptz created_at
  }
  processing_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    text idempotency_key PK
    varchar(64) input_hash
    uuid job_id FK
    timestamptz created_at
  }
  readiness_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    jsonb result
    timestamptz created_at
  }
  release_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    jsonb result
  }
  support_command_receipts {
    uuid actor_id PK, FK
    text operation PK
    varchar(128) idempotency_key PK
    varchar(64) input_hash
    jsonb result
    timestamptz created_at
  }
  organizations {
    uuid id PK "nhóm 1"
  }
  processing_jobs {
    uuid id PK "nhóm 3"
  }
  users {
    uuid id PK "nhóm 1"
  }
```
*11 bảng, 13 khóa ngoại, 3 bảng ở nhóm khác.*

- **UNIQUE nhiều cột:** `application_command_receipts(actor_user_id, operation_name, idempotency_key)`; `billing_command_receipts(actor_id, operation, idempotency_key)`

## Bảng hệ thống

`__EFMigrationsHistory(MigrationId varchar(150) PK, ProductVersion varchar(32))`: EF Core ghi migration đã áp. Không vẽ vào ERD.
