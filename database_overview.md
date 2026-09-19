# FET3D v6 — Database Overview (Họp nhóm)

> **Dự án:** Fire Evacuation Training 3D | **DB:** PostgreSQL | **Schema version:** v6.7
> **Đối chiếu:** SQL thiết kế là nguồn chính cho bảng, field, FK và constraint. Tài liệu này mô tả các nhóm nghiệp vụ; không dùng số lượng bảng cũ làm cam kết vì Learn, billing, AI và integration schema tiếp tục được đồng bộ.
> Stored function/gate được mô tả tại technology và schema; đây là thiết kế mục tiêu, chưa phải migration đã chạy.

---

## 🗺️ Sơ đồ kiến trúc tổng quan

```
[organizations] ──── [users] ──── [user_devices]
      │
      ▼
[buildings]  (địa chỉ/GPS nằm cùng bảng)
      │         [building_floors]      (1-N)
      │         [building_contacts]    (1-N)
      │
      ▼
[revisions] ──── [source_documents]    (1-1)
      │         [processing_jobs]      (1-N)
      │              └── [revision_processing_logs]
      │         [revision_floors]      (1-N, snapshot bất biến)
      │         [revision_artifacts]   (1-N, output pipeline)
      │         [annotation_sets]      (1-N)
      │         [validation_runs]      (1-N)
      │              └── [validation_issues]
      │
      ▼
[scenarios] ──── [scenario_versions]   (1-N)
      │               └── [revision_reviews]   (1-1 per version)
      │
      ▼
[releases] ──── [release_packages]     (1-1)
      │
      ▼
[trainings] ──── [release_qr_codes]    (1-N)
      │
      ▼
[sessions] ──── [session_events]       (1-N)
           ──── [session_results]      (1-1)
                     └── [debrief_artifacts]  (1-1, thiết kế mục tiêu)
           ──── [session_checkpoints]  (1-N, thiết kế mục tiêu)

[audit_logs]                           (có provenance user/org, append-only)

── Phase 2 ──
[service_packages] → [quotations] → [payos_payment_requests]
                                          └── [payment_transactions]
                                                    └── [invoice_metadata]
[feedback] → [support_tickets]
```

---

## Nhóm 1 — Identity & Phân quyền

### 1. `organizations`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Đơn vị thuê nền tảng (tenant). Gốc của mọi dữ liệu nghiệp vụ. |
| **Cột quan trọng** | `slug` (định danh URL duy nhất), `name`, `address`, `phone`, `is_active`, `profile_revision_no` |
| **Quan hệ** | 1 org → N users, N buildings, N trainings, N sessions |
| **Ràng buộc** | slug phải lowercase + dấu gạch ngang, không xóa nếu còn FK |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 2. `users`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Tài khoản người dùng với 3 role cố định |
| **Cột quan trọng** | `role` (PlatformAdmin / OrganizationUser / Trainee), `organization_id` (NULL với Admin/Trainee), `email`, `password_hash`, `firebase_uid`, `username`, `full_name`, `avatar_storage_key`, `profile_revision_no`, `is_active` |
| **Quan hệ** | N users → 1 org; 1 user → N devices, N sessions (as trainee), N buildings (as creator) |
| **Ràng buộc** | OrganizationUser **phải** có `organization_id`; Trainee/Admin **không được** có |
| **Lưu ý** | Email và username unique toàn hệ thống; username không phân biệt hoa thường. Password/refresh/reset token do BE quản lý; avatar chỉ lưu S3 object key. Đổi role/org = tạo account mới |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 3. `user_devices`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Lịch sử thiết bị Android đã đăng nhập |
| **Cột quan trọng** | `device_uuid` (UUID cài đặt), `device_model`, `os_version`, `app_version`, `last_seen_at` |
| **Quan hệ** | N devices → 1 user; Session pin device qua composite FK |
| **Ràng buộc** | UNIQUE(user_id, device_uuid) — cùng user, cùng thiết bị chỉ 1 row |
| **Lưu ý** | Khi Session tạo, `device_id` bị pin cứng — không đổi được |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 3.1. `auth_google_onboarding_sessions`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Lưu trạng thái ngắn hạn sau khi Firebase đã xác minh Google nhưng trước khi tạo/hoàn tất tài khoản FET3D |
| **Cột quan trọng** | `firebase_uid`, `email`, `onboarding_token_hash`, `requested_role`, `organization_draft`, `expires_at`, `completed_at`, `completed_user_id`, `completed_input_hash` |
| **Ràng buộc** | Chỉ nhận `Trainee` hoặc `OrganizationUser`; token chỉ lưu hash, có hạn và không tự cấp role/tenant; PlatformAdmin không đi qua onboarding này. Khi hoàn tất, lưu user đã tạo và hash input để retry trả kết quả cũ thay vì tạo user/tổ chức mới |
| **Trạng thái** | Thiết kế đích; API Google onboarding và migration dữ liệu còn triển khai sau |

---

## Nhóm 2 — Building / Hồ sơ Tòa nhà

### 4. `buildings`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Hồ sơ hiện hành của công trình |
| **Cột quan trọng** | `name`, `building_type`, `total_floors`, `address`, `city`, `district`, `latitude`, `longitude`, `geojson`, `is_active`, `created_by` |
| **Quan hệ** | 1 org → N buildings; 1 building → N revisions, N scenarios |
| **Ràng buộc** | UNIQUE(id, organization_id) — dùng cho composite FK từ bảng con |
| **Lưu ý** | Không chứa dữ liệu 3D. Soft delete qua `deleted_at` |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 3.2. `auth_refresh_tokens` và `password_reset_tokens`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Lưu phiên refresh và token reset do BE quản lý |
| **Cột quan trọng** | `user_id`, `family_id`, `token_hash`, `expires_at`, `consumed_at`/`used_at`, `revoked_at` |
| **Ràng buộc** | Chỉ lưu hash; token hết hạn hoặc đã dùng không được tái sử dụng; không tiết lộ email tồn tại |
| **Trạng thái** | Thiết kế đích cần đối chiếu với entity BE |

### 5. `building_floors`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Metadata **mutable** từng tầng của tòa nhà |
| **Cột quan trọng** | `floor_number`, `floor_name`, `area_sqm`, `elevation_meters`, `is_basement`, `floor_plan_url` |
| **Quan hệ** | N floors → 1 building; được "chụp lại" bởi `revision_floors` |
| **Ràng buộc** | UNIQUE(building_id, floor_number) — không có 2 tầng cùng số |
| **Lưu ý** | Đây là dữ liệu "hiện tại". Lịch sử 3D nằm ở `revision_floors` |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 6. `building_contacts`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Đầu mối liên hệ của tòa nhà (quản lý, PCCC...) |
| **Cột quan trọng** | `contact_name`, `contact_role`, `phone`, `email`, `is_primary` |
| **Quan hệ** | N contacts → 1 building |
| **Ràng buộc** | Partial unique index: chỉ một đầu mối `is_primary = true` / building |
| **⚠️ Nhận xét** | Không có feature nào trong Phase 1 đọc bảng này. Có thể lưu tạm vào `buildings.metadata` |
| **Trạng thái** | 🟡 Phase 1 optional |

---

## Nhóm 3 — Source / Pipeline Xử lý BIM

> Pipeline 8 bước: Quarantine → Parse → CleanGeometry → Decimate → GenNavMesh → GenHazardGrid → ExportGLB → PackageBundle

### 8. `revisions`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Một lần upload file IFC = một Revision. Gốc của toàn bộ nội dung 3D |
| **Cột quan trọng** | `version_label`, `status` (9 trạng thái), `primary_type` (chỉ IFC), `uploaded_by` |
| **Quan hệ** | 1 building → N revisions; 1 revision → 1 source_doc, N jobs, N floors, N artifacts |
| **Vòng đời** | Draft → Uploaded → Processing → ReadyForScenario → ConfirmedForTraining / NeedsFix / Failed → Superseded |
| **Ràng buộc** | UNIQUE(building_id, version_label); composite FK đến buildings |
| **Trạng thái** | ✅ Phase 1 — trung tâm của pipeline |

```
Draft ──[Source Accepted]──► Uploaded ──► Processing ──► ReadyForScenario ──► ConfirmedForTraining
                                               │                │                      │
                                               ▼                ▼                      ▼
                                            NeedsFix         Failed              Superseded
                                               │               │
                                          [Retry]──────────────┘
```

### 9. `source_documents`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Metadata file IFC gốc đã upload |
| **Cột quan trọng** | `sha256_hash` (64 hex), `file_size_bytes`, `storage_url` (object key, không phải signed URL), `quarantine_status`, `mime_type`, `usage_rights` |
| **Quan hệ** | 1-1 với revisions |
| **Ràng buộc** | quarantine_status: Pending → Accepted / Rejected; chỉ Accepted mới cho pipeline chạy |
| **Lưu ý** | `storage_url` là stable object key. Signed URL được API tạo theo request, không lưu DB |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 10. `processing_jobs`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Một lần worker chạy pipeline (Geometry hoặc Scenario) |
| **Cột quan trọng** | `revision_id`, `source_document_id`, `scenario_version_id`, `kind` (Geometry/PlaytestPackage/ReleasePackage/QA), `job_key` (UUID duy nhất), `input_hash`, `status` (Queued/Running/Succeeded/Failed/Cancelled) |
| **Quan hệ** | N logical jobs → 1 revision; 1 job → N `processing_job_attempts`, N logs, N artifacts, N validation runs |
| **Ràng buộc** | Chỉ một job Queued/Running / revision tại một thời điểm (partial unique index) |
| **Lưu ý** | `processing_jobs` là job logic; retry/requeue giữ cùng job và tạo `processing_job_attempts` mới, không mất lịch sử attempt. `Cancelled` không tự chạy lại |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 10.1. `integration_outbox_events` và `integration_event_consumptions`

| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Giao event/job bền vững từ transaction PostgreSQL tới dispatcher/Redis Streams và dedup tác động của consumer |
| **Cột chính** | `idempotency_key`, `event_type`, `schema_version`, `organization_id`, `aggregate_id`, `payload_hash`, `status`, `lease_token`, `lease_until`, `published_lease_token` |
| **Consumer dedup** | Khóa chính `(consumer_name, event_key)`, giữ `payload_hash`, `processed_at` và `result_reference`; cùng key/hash là replay no-op trước tác động, khác hash/envelope là conflict |
| **Nguồn sự thật** | PostgreSQL outbox/consumption record; Redis Stream ID chỉ là delivery ID. ACK chỉ sau commit kết quả hoặc bàn giao bền vững |
| **Ràng buộc** | Trigger kiểm tra INSERT/UPDATE; tenant enqueue chỉ nhận `ProcessingJobRequested` schema `1`, system enqueue chỉ nhận `SystemNotification`/`PlatformCacheInvalidation` schema `1` bằng executor riêng, còn `ProcessingJobRequeue` chỉ do requeue gate tạo. Event lạ, sai scope hoặc sai schema bị từ chối. Identity/scope/type/schema/payload bất biến sau enqueue; scope null chỉ cho event hệ thống được backend xác minh. Dispatcher claim chỉ lấy Pending/Failed đến hạn hoặc Leased hết hạn; không dùng Redis cache để cấp quyền |
| **Trạng thái** | Kiến trúc đích, chưa migration/triển khai |

### 11. `revision_processing_logs`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Log từng bước nhỏ trong pipeline (8 bước cụ thể) |
| **Cột quan trọng** | `job_id`, `attempt_id`, `step` (enum 8 bước), `status` (Started/Success/Failed), `message`, `duration_ms` |
| **Quan hệ** | N logs → 1 attempt → 1 logical job → 1 revision |
| **Trạng thái** | ✅ Phase 1 cần thiết (debug pipeline) |

---

## Nhóm 4 — Snapshot / QA (Bằng chứng chất lượng)

> Tất cả các bảng trong nhóm này là **append-only** — không bao giờ sửa kết quả cũ.

### 12. `revision_floors`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | **Snapshot bất biến** tọa độ tầng tại thời điểm revision được xử lý |
| **Cột quan trọng** | `ifc_guid`, `floor_number`, `floor_name`, `elevation_meters`, `coordinate_transform` (JSONB ma trận 4×4) |
| **Quan hệ** | N revision_floors → 1 revision; tham chiếu đến building_floor gốc |
| **Lưu ý** | Khi QA Geometry Passed → không được thêm/sửa snapshot. Session lịch sử dùng bảng này, **không** join building_floors |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 13. `annotation_sets`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Bộ nhãn bổ sung cho mô hình 3D (cửa thoát hiểm, vật cản, điểm tập kết) |
| **Cột quan trọng** | `version_number`, `data` (JSONB), `provenance` (manual/pipeline), `created_by` |
| **Quan hệ** | N annotation_sets → 1 revision; được tham chiếu bởi validation_runs và revision_reviews |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 14. `revision_artifacts`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Registry các file output của pipeline — bằng chứng đã xử lý |
| **Cột quan trọng** | `artifact_type`, `storage_key`, `sha256_hash`, `metadata`, `is_runtime_ready`, `attempt_id`, `job_id` |
| **Quan hệ** | N artifacts → 1 attempt → 1 logical job → 1 revision |
| **Ràng buộc** | Artifact bất biến, có provenance attempt; cùng bytes ở hai attempt vẫn có bản ghi bằng chứng riêng |
| **Lưu ý** | Bytes nằm ở object storage, DB chỉ lưu registry/provenance |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 15. `validation_runs`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kết quả QA tự động sau khi pipeline xong |
| **Cột quan trọng** | `revision_id`, `scenario_version_id`, `processing_job_id`, `processing_attempt_id`, `artifact_id`, `release_id`, `scope`, `validator_version`, `status`, `summary`, `issues_hash`, timestamps |
| **Quan hệ** | Gắn với logical job và attempt cụ thể; mỗi attempt/validator/scope có một run; artifact/release/scenario provenance được kiểm tra trước publish |
| **Ràng buộc** | Scope quyết định target bắt buộc; `issues_hash` là hash canonical của toàn bộ danh sách issue; `Passed` và không còn Error/Critical mới đủ điều kiện publish/package |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 16. `validation_issues`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Chi tiết từng vấn đề phát hiện trong một validation run |
| **Cột quan trọng** | `validation_run_id`, `revision_id`, `scenario_version_id`, `artifact_id`, `issue_code`, `severity`, `status`, `message`, `evidence`, `resolved_at`, `resolved_by` |
| **Quan hệ** | N issues → 1 validation_run; issue nghiêm trọng còn mở chặn publish |
| **Trạng thái** | ✅ Phase 1 cần thiết (hiển thị cho OrganizationUser) |

---

## Nhóm 5 — Scenario / Kịch bản Diễn tập

### 17. `scenarios`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Thực thể logic của kịch bản (như "thư mục" chứa versions) |
| **Cột quan trọng** | `name`, `building_id`, `organization_id`, `created_by` |
| **Quan hệ** | 1 building → N scenarios; 1 scenario → N scenario_versions |
| **Lưu ý** | Không chứa config thực tế — đó là trách nhiệm của scenario_versions |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 18. `scenario_versions`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | **Snapshot bất biến** config kịch bản cụ thể — append-only khi save |
| **Cột quan trọng** | `version_number`, `scenario_hash` (64 hex fingerprint), `algorithm_version`, `random_seed`, `time_limit_seconds` |
| **Config JSONB** | `spawn_config` (điểm xuất phát), `goal_config` (lối thoát), `fire_source_config` (nguồn lửa), `npc_config` (dự phòng), `blocked_elements` (vật cản), `routing_config` (trọng số đường đi), `scoring_config` (rubric chấm điểm), `mode_policy` (policy Learn/Guided/Assessment), `safety_thresholds` |
| **Quan hệ** | N versions → 1 scenario; pin vào 1 revision |
| **Ràng buộc** | UNIQUE(scenario_id, version_number); `scenario_hash` do server tính từ config JSONB |
| **Trạng thái** | ✅ Phase 1 — trung tâm của nội dung diễn tập |

> **Lưu ý quan trọng:** `scenario_hash` do PostgreSQL tính từ các cột config, **khác với** SHA-256 của file scenario.json trong bundle. Không so sánh hai hash này với nhau.

---

## Nhóm 6 — Governance / Phát hành & Điều phối Đào tạo

### 19. `revision_reviews`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Lịch sử xác nhận hoặc từ chối kịch bản trước khi phát hành |
| **Cột quan trọng** | `revision_id`, `scenario_version_id`, `reviewed_by`, `annotation_set_id`, `action` (ConfirmForTraining/Rejected), `review_message`, `reviewed_at` |
| **Quan hệ** | N reviews → 1 revision; mỗi review gắn một scenario_version và có thể gắn annotation snapshot |
| **Ràng buộc** | Readiness được quyết định theo action mới nhất của đúng cặp revision–scenario version; Reject B không ảnh hưởng A và không khóa authoring geometry |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 20. `releases`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Gói phát hành chính thức — pin cứng revision + scenario version + review |
| **Cột quan trọng** | `revision_id`, `scenario_version_id`, `building_id`, `organization_id`, `status` (Built/Published/Superseded/Revoked), `published_by`, `revoked_by`, `revoked_reason`, `safety_thresholds`, `published_at`, `updated_at` |
| **Quan hệ** | 1 release → 1 package, N trainings, N QR codes |
| **Ràng buộc** | UNIQUE(revision_id, scenario_version_id) — tối đa một release / cặp nội dung |
| **Vòng đời** | Built → Published ← (cần package + Training Active) → Superseded / Revoked |
| **Trạng thái** | ✅ Phase 1 cần thiết |

```
Built ──[package + Active Training]──► Published ──► Superseded
  │                                        │              │
  └──────────────────────────────────────► Revoked ◄──────┘
```

### 21. `release_packages`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Thông tin kỹ thuật của bundle 3D đính kèm release |
| **Cột quan trọng** | `manifest_url` + `manifest_sha256`, `package_url` + `checksum_sha256`, `package_size_bytes`, `min_runtime_version`, `protocol_version`, `manifest_schema_version`, `required_capabilities`, `build_target`, `candidate_artifact_id`, `candidate_validation_run_id` |
| **Quan hệ** | 1-1 với releases |
| **Ràng buộc** | Append-only sau insert; sai metadata thì rollback transaction, không sửa |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 22. `trainings`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Một "đợt đào tạo" dùng release cụ thể cho học viên |
| **Cột quan trọng** | `release_id`, `scenario_version_id`, `organization_id`, `name`, `status` (Draft/Active/Closed/Archived), `mode`, `allowed_modes`, `max_attempts`, `start_date`, `end_date`, `created_by` |
| **Quan hệ** | N trainings → 1 release; 1 training → N QR codes, N sessions |
| **Ràng buộc** | Sau khi có QR/session: lịch, mode, max_attempts **bị khóa** (không sửa được). Tên/mô tả vẫn sửa được |
| **Lưu ý** | `max_attempts` là số dương theo thiết kế hiện tại; policy đếm Assessment/không đếm Learn-Guided phải được backend đặc tả khi triển khai |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 23. `release_qr_codes`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Mã QR để học viên vào phiên diễn tập |
| **Cột quan trọng** | `qr_hash` (SHA-256 của token bí mật), `label`, `expires_at`, `is_active`, `revision_floor_id` (vị trí dán, không phải spawn point) |
| **Quan hệ** | QR thuộc một Building và không pin trực tiếp một training; resolve mở danh sách bài đã publish, sau đó session pin training/release/scenario đã chọn |
| **Ràng buộc** | Token raw chỉ trả **một lần** khi tạo để in. Rotation = tạo row mới. Deactivate = một chiều |
| **Lưu ý** | QR active chưa đủ để start — API còn kiểm tra bài Published, package/runtime compatibility, entitlement Building và online start gate |
| **Trạng thái** | ✅ Phase 1 cần thiết |

---

## Nhóm 7 — Learning Records / Dữ liệu Học tập

### 24. `sessions`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Mỗi lượt chơi của học viên = một Session |
| **Cột quan trọng** | `status` (9 trạng thái), `mode`, `prepare_idempotency_key`, `start_idempotency_key`, `app_version`, `unity_engine_version`, `runtime_version`, `package_hash`, `manifest_sha256`, `protocol_version`, `manifest_schema_version`, `build_target`, `package_artifact_id`, `package_validation_run_id`, `runtime_catalog_id`, `created_at`, `launch_granted_at`, `started_at`, `ended_at`, `last_heartbeat_received_at`, `last_heartbeat_sequence` |
| **Quan hệ** | Pin cứng: training + release + scenario_version + QR + device + org |
| **Ràng buộc** | Preparation và start có idempotency key riêng; package/artifact/validation/runtime metadata được pin, start mới cấp launch grant online |
| **Vòng đời** | Created → Launching → Running → [Completed / CompletedWithSupersededRelease / ScenarioUnsurvivable / Aborted / Abandoned / Crashed] |
| **Trạng thái** | ✅ Phase 1 — trung tâm của gameplay |

```
Created ──► Launching ──► Running ──► Completed
   │             │            │       CompletedWithSupersededRelease
   │             │            │       ScenarioUnsurvivable
   ▼             ▼            ▼
 Aborted      Crashed      Crashed
 Abandoned    Abandoned    Aborted
                           Abandoned
```

### 25. `session_events`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Stream sự kiện thô gửi từ Unity trong quá trình chơi |
| **Cột quan trọng** | `id` (UUID ổn định do client tạo), `sequence_number` (theo session), `schema_version`, `event_type`, `event_data` (JSONB), `recorded_at` (client), `received_at` (server) |
| **Quan hệ** | N events → 1 session |
| **Ràng buộc** | `id` là khóa chính ổn định do client tạo; `UNIQUE(session_id, sequence_number)` chống nhận lặp/đảo thứ tự |
| **Lưu ý** | Retry giữ nguyên `id`; backend dedup theo `id` và sequence theo session, ghi thời điểm server nhận riêng với thời điểm client |
| **Event đề xuất** | SESSION_STARTED, ROUTE_SELECTED, ROUTE_REPLANNED, ENTER_HAZARD_ZONE, EXIT_HAZARD_ZONE, WRONG_EXIT, REACHED_EXIT, SESSION_ABORTED |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 26. `session_results`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kết quả chốt và trạng thái đồng bộ cuối của session; backend là nguồn xác nhận |
| **Cột quan trọng** | `score`, `time_taken_seconds`, `wrong_exits`, `hazard_exposure_score`, `total_distance_meters`, `reached_exit`, `exit_point_id`, `path_traveled` (JSONB), `client_started_at`, `client_ended_at`, `is_synced`, `synced_at`, `result_idempotency_key`, `result_hash`, `result_snapshot`, `created_at`, `updated_at` |
| **Quan hệ** | 1-1 với sessions (UNIQUE) |
| **Ràng buộc** | Backend chấm điểm trước khi ghi. SQL **không tự tính** score; kết quả đồng bộ được xác nhận bởi backend và không mở lại phiên terminal |
| **Lưu ý** | Client timestamps chỉ là bằng chứng bổ trợ; `synced_at` là thời điểm backend xác nhận nhận kết quả. `complete_training_session` chống replay theo key/hash/snapshot/timestamps và cho phép sync sau khi phiên đã bắt đầu mà không kiểm tra lại entitlement hoặc trạng thái active hiện tại của user |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 27. `session_checkpoints`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Lưu trạng thái game tại mốc thời gian để có thể resume |
| **Cột quan trọng** | `player_transform` (JSONB vị trí), `player_status`, `world_interactive_states`, `hazard_time_step`, `npc_states`, `active_objectives`, `release_hash`, `scenario_hash` |
| **Trạng thái** | Thiết kế mục tiêu của khả năng resume offline; implementation/API và benchmark chưa hoàn tất. Dữ liệu phải pin release/scenario; phiên đã bắt đầu tiếp tục cục bộ và đồng bộ event/result sau khi có mạng. |

### 28. `debrief_artifacts`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Dữ liệu phân tích sau diễn tập (tính toán từ session_results) |
| **Cột quan trọng** | `trajectory_heatmap`, `optimal_path` (đường đi tối ưu so sánh), `wrong_decisions`, `hazard_timeline`, `npc_summary`, `is_visible_to_trainee`, `generated_at` |
| **Quan hệ** | 1-1 với session_results |
| **Trạng thái** | Thiết kế mục tiêu cho debrief sau diễn tập; generator/API chưa hoàn tất. `session_results.path_traveled` là dữ liệu nền, không thay thế toàn bộ artifact debrief cuối. |

### 29. `audit_logs`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Nhật ký toàn bộ thao tác quan trọng của hệ thống |
| **Cột quan trọng** | `user_id` (nullable), `organization_id` (snapshot), `actor_type` (User/Worker/System), `action` (17 loại), `target_entity`, `target_id`, `correlation_id`, `old_values`, `new_values`, `ip_address` |
| **Ràng buộc** | `user_id`/`organization_id` là FK bảo vệ provenance; xóa tài khoản/tổ chức bị chặn khi còn audit. Runtime role không được UPDATE/DELETE/TRUNCATE |
| **Lưu ý** | Không ghi password/token/signed URL. Trigger không đoán người UPDATE từ created_by |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 30. Learn blog: `learn_posts`, `learn_post_versions`, `learn_situations`, `learn_post_version_situations`, `learn_post_version_sources`, `learn_bookmarks`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Thư viện blog/tip & trick/video PCCC công khai, phân loại theo tình huống; tách khỏi `trainings`, `sessions` và kết quả Unity |
| **Quyền** | `PlatformAdmin` tạo, sửa draft, phát hành ngay hoặc lưu nháp, ẩn/hiện bài; Trainee chỉ đọc nội dung public và quản lý bookmark của chính mình |
| **Nguồn chính** | `learn_posts` là identity; `learn_post_versions` là snapshot; draft có thể liên kết Common chưa Approved, còn publish/show và RAG yêu cầu source Common Approved; `knowledge_chunks` dùng lại cho RAG |
| **Media** | `content_blocks` JSONB có schema; video chỉ lưu provider/URL/ID đã chuẩn hóa và được allowlist YouTube/Facebook/TikTok; không nhận iframe/script tùy ý |
| **Vòng đời** | Version `Draft → Published`; bài `Unpublished → Published`, `Published ↔ Hidden` hoặc soft-delete `Deleted`. Hidden giữ `published_version_id` và vẫn đủ điều kiện RAG; Deleted giữ lịch sử nhưng không retrieval; bản Published bất biến. Restore không tự public |
| **Ràng buộc** | Public API/cache chỉ trả bài Published với pointer đúng version; Hidden/Unpublished/Deleted không public; Hidden có thể vào RAG; bookmark unique theo Trainee–post; AI loại Deleted/draft |
| **Trạng thái** | Thiết kế mục tiêu; prototype Learn hiện chưa chứng minh CMS, embed provider hoặc indexing production |

---

## Nhóm 8 — Thương mại & Hỗ trợ

> [!WARNING]
> Các nhóm này thuộc thiết kế đích, chưa phải bằng chứng production-ready. Entitlement, quotation immutability, checkout mồ côi, thanh toán muộn/duplicate, invoice discount và notification/reconcile vẫn cần implementation và kiểm thử thực thi riêng.

### 31. `service_packages`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Danh mục gói dịch vụ thương mại do PlatformAdmin quản lý |
| **Cột quan trọng** | `code` (mã ổn định), `name`, `unit_price`, `currency`, `duration_months`, `features` JSONB, `is_active` |
| **Trạng thái** | 🟠 Phase 2 |

### 32. `quotations`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Báo giá gửi cho Organization |
| **Cột quan trọng** | `quotation_number`, `status` (Draft/Issued/Accepted/Expired/Cancelled), header total snapshots, `discount_rule_id`, `discount_snapshot`, `price_snapshot`, `terms_snapshot`, `valid_until` |
| **Ràng buộc** | Header không có `building_id`, `service_package_id` hoặc `service_duration_months`; `BuildingService` dùng `quotation_building_items` làm nguồn duy nhất. Quantity/unit price header chỉ là tổng hợp, không thay danh sách Building. Lifecycle `Draft → Issued → Accepted` ghi `accepted_at` một lần; line không chuyển quotation và snapshot bất biến sau khi phát hành. |
| **Trạng thái** | 🟠 Phase 2 |

### 32.1. `quotation_building_items`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Một dòng cho đúng một Building trong mua mới hoặc gia hạn |
| **Cột quan trọng** | `quotation_id`, `building_id`, `service_package_id`, `purchase_action`, `service_duration_months`, `unit_price`, `discount_amount`, `price_snapshot`, `terms_snapshot`, `line_provisioning_key` |
| **Ràng buộc** | Unique quotation–Building; Building phải cùng organization, có tên và địa chỉ; một payment có thể provision nhiều dòng nhưng entitlement từng dòng có key riêng |
| **Trạng thái** | 🟠 Phase 2 |

### 32.2. `service_package_discount_rules` và `enterprise_quote_requests`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Admin cấu hình discount không cộng dồn và tiếp nhận yêu cầu báo giá số lượng lớn |
| **Cột quan trọng** | Rule: `discount_kind`, `discount_value`, `discount_currency` khi là Fixed, điều kiện số Building/thời hạn/hiệu lực; request: số lượng, thời hạn, contact, status, quotation link |
| **Ràng buộc** | Rule/giá được snapshot trong quotation; request không tạo payment/entitlement trước khi có quotation và payment hợp lệ. Quotation riêng trước khi thanh toán vẫn phải có line xác định từng Building |
| **Trạng thái** | 🟠 Phase 2 |

### 32.3. `organization_notifications` và `notification_deliveries`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Nhắc OrganizationUser trước 5 ngày khi entitlement Building hết hạn |
| **Cột quan trọng** | Notification theo organization/user/Building/entitlement/kỳ; delivery theo `Web|Email`, status, attempts, provider message id |
| **Ràng buộc** | `recipient_user_id`, Building và entitlement phải cùng organization; `reference_ends_at` khớp entitlement. Idempotency theo entitlement/kỳ/kênh; retry độc lập, gia hạn mới không gửi lại nhắc kỳ cũ |
| **Trạng thái** | 🟠 Phase 2 |

### 32.4. `payment_provisioning_records`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Reconcile cấp quyền sau payment Applied theo từng Building line |
| **Cột quan trọng** | `payment_transaction_id`, `quotation_id`, `quotation_item_id`, `organization_id`, `provisioning_key`, `status`, `attempts` |
| **Ràng buộc** | Một payment có nhiều record theo quotation line; mỗi record chỉ xử lý một dòng, retry/reconcile không cấp entitlement trùng và không áp dụng cho quotation AIUsage |
| **Trạng thái** | 🟠 Phase 2 |

### 33. `payos_payment_requests`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Yêu cầu thanh toán qua cổng PayOS |
| **Cột quan trọng** | `order_code` (PayOS orderCode), `expected_amount`, `checkout_url`, `return_url`, `cancel_url`, `status`, `paid_transaction_id` |
| **Bảo mật** | Owned bởi `fet3d_payos_ledger_owner` role riêng. Không DML trực tiếp từ API thường |
| **Trạng thái** | 🟠 Phase 2 |

### 34. `payment_transactions`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Ghi nhận webhook từ PayOS sau khi người dùng thanh toán |
| **Cột quan trọng** | `webhook_event_id` (idempotency key), `received_order_code`, `received_amount`, `signature_verified`, `status` (Received→Verified→Applied/Rejected), `raw_payload` |
| **Ràng buộc** | Append-only. Bất biến sau Applied/Rejected. Trigger chặn mọi DELETE |
| **Trạng thái** | 🟠 Phase 2 |

### 35. `invoice_metadata`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Thông tin xuất hóa đơn sau thanh toán thành công |
| **Cột quan trọng** | `invoice_number`, `legal_name`, `tax_code`, `billing_address`, `subtotal_amount`, `tax_amount`, `total_amount`, `invoice_url` |
| **Quan hệ** | 1-1 với payment_transactions (chỉ transaction Applied) |
| **Trạng thái** | 🟠 Phase 2 |

### 36. `feedback`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Phản hồi từ người dùng về hệ thống hoặc một session |
| **Cột quan trọng** | `category`, `rating` (1–5, nullable), `message`, `status` (Submitted/Reviewed/Closed), `submitted_by`, `session_id` (optional) |
| **Trạng thái** | 🟠 Phase 2 |

### 37. `support_tickets`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Ticket hỗ trợ kỹ thuật, có thể liên kết feedback/session |
| **Cột quan trọng** | `ticket_number`, `subject`, `description`, `priority` (Low/Normal/High/Urgent), `status` (Open/InProgress/Resolved/Closed), `assigned_to`, `resolved_at` |
| **Quan hệ** | Có thể link: feedback, session, organization |
| **Trạng thái** | 🟠 Phase 2 |

---

## 🔑 4 Stored Function/Gate chính

| Function | Mục đích | Input quan trọng |
|---|---|---|
| `confirm_revision_for_training()` | Xác nhận scenario version sẵn sàng đào tạo | revision, scenario_version, actor, validation_run |
| `start_training_session(UUID, UUID, TEXT, TEXT)` | Start online và cấp launch grant cho Trainee session đã chuẩn bị | actor, session_id, start idempotency key, runtime version |
| `start_playtest_session(UUID, UUID, TEXT, TEXT)` | Start playtest đúng tenant sau entitlement/quota thử | actor, playtest session id, start idempotency key, runtime version |
| `complete_playtest_session(UUID, UUID, TEXT, TEXT)` | Chốt playtest đã bắt đầu; không kiểm tra lại entitlement hoặc trạng thái active hiện tại của creator | actor, playtest id, completion idempotency key, terminal status |
| `record_session_heartbeat(UUID, UUID, BIGINT, TIMESTAMPTZ)` | Ghi heartbeat server-received, chống sequence NULL/lặp | actor, session id, sequence, client timestamp |
| `record_session_event(UUID, UUID, UUID, BIGINT, TEXT, TEXT, JSONB, TIMESTAMPTZ)` | Ghi event offline theo event ID/sequence, chống replay | actor, session, event ID, sequence, schema/type, payload, client timestamp |
| `complete_training_session(UUID, UUID, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ)` | Ghi kết quả và chuyển phiên đang chạy sang Completed qua gate sync | actor, session, result idempotency key/hash, snapshot, client timestamps |
| `close_ai_billing_period(UUID)` | Đóng kỳ AI và snapshot usage/item/tổng tiền nguyên tử | billing period id |
| `invoice_ai_billing_period(UUID, UUID)` / `pay_ai_billing_period(UUID, UUID)` | Gắn quotation AI rồi payment Applied theo đúng lifecycle, replay-safe | period, quotation hoặc payment transaction |
| `register_processing_output(...)` | Ghi artifact/validation/issues theo current attempt và lease; lưu hash danh sách issue để chống replay khác nội dung | attempt, lease token, output hash, metadata, validator, issues |

---

## 📊 Tóm tắt theo Phase

| Nhóm | Bảng chính | Ghi chú |
|---|---|---|
| Core platform/training | identity, Building, IFC, scenario, release, QR, session, result, audit | Thứ tự triển khai theo requirements; SQL là nguồn field/FK |
| Learn public content | learn_posts, learn_post_versions, learn_situations, learn_post_version_situations, learn_post_version_sources, learn_bookmarks | Thiết kế mục tiêu, chưa có CMS production |
| AI/RAG and integration | knowledge_sources, knowledge_chunks, AI request/quota/ledger, outbox/consumer | AI/Redis integration còn theo contract và migration riêng |
| Commercial/support | service packages, discount rules, quotation + Building items, enterprise quote, payment, entitlement, expiry notifications, feedback, support | Không coi bảng hiện có là production-ready nếu chưa có implementation/reconcile test |
| Resume/debrief | session_checkpoints, debrief_artifacts | Là khả năng trong phạm vi bản cuối; thứ tự implementation và benchmark có thể theo phase, không phải loại khỏi cam kết sản phẩm |

---

## ⚠️ Những điểm cần thảo luận trong họp

### 1. Bảng có thể gộp hoặc cần rà implementation
- **`buildings`**: Địa chỉ/GPS đã gộp trực tiếp vào hồ sơ Building; không tạo bảng 1-1 riêng
- **`building_contacts`**: Giữ riêng cho danh sách đầu mối và cờ primary; chỉ địa chỉ/GPS được gộp vào `buildings`
- **`session_checkpoints`**: Giữ trong thiết kế đích để resume offline có kiểm soát; cần API/runtime benchmark trước khi triển khai.
- **`debrief_artifacts`**: Giữ trong thiết kế đích cho debrief; generator/versioning là implementation work, không xóa vì số bảng.

### 2. Nguyên tắc quan trọng nhóm cần nhớ
| Nguyên tắc | Bảng áp dụng |
|---|---|
| **Snapshot bất biến** | revision_floors, scenario_versions, revision_artifacts, session_results — không UPDATE, chỉ INSERT |
| **Hash là bằng chứng** | source_documents, revision_artifacts, release_packages, sessions — không tin URL hay client value |
| **Composite FK nhiều chiều** | Sessions pin 4–5 bảng cùng lúc qua composite FK để tránh cross-tenant |
| **DB không tự tính score** | Backend chấm điểm trước, gọi SQL với kết quả đã validate |
| **Payment tách biệt role** | payos_payment_requests + payment_transactions owned bởi `fet3d_payos_ledger_owner` riêng |
| **Audit có provenance** | `audit_logs` giữ `user_id`, `organization_id`, `actor_type` và `correlation_id`; append-only, không ghi secret |

### 3. Workflow chưa có implementation
- Auth onboarding Google, profile/avatar và reset-password transaction mục tiêu (schema refresh/reset token đã có; BE hiện có family check nhưng reset handler chưa hoàn tất thu hồi trong cùng transaction)
- IFC geometry validator (worker ngoài DB)
- Object storage integration (DB chỉ lưu key, không lưu bytes)
- React Native/Expo native Android bridge–Unity launch protocol
- Phase 2 billing/support hoàn chỉnh
