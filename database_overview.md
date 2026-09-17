# FET3D v6 — Database Overview (Họp nhóm)

> **Dự án:** Fire Evacuation Training 3D | **DB:** PostgreSQL | **Schema version:** v6
> **Tổng:** 36 bảng · 18 enum · 4 stored function chính
> **Phase 1 cần thiết:** ~25 bảng · **Dự phòng / Phase 2:** 11 bảng

---

## 🗺️ Sơ đồ kiến trúc tổng quan

```
[organizations] ──── [users] ──── [user_devices]
      │
      ▼
[buildings] ──── [building_locations]  (1-1)
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
      │              └── [revision_issues]
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
                     └── [debrief_artifacts]  (1-1, dự phòng)
           ──── [session_checkpoints]  (1-N, dự phòng)

[audit_logs]                           (độc lập)

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
| **Cột quan trọng** | `slug` (định danh URL duy nhất), `plan` (gói dịch vụ), `is_active`, `metadata` JSONB |
| **Quan hệ** | 1 org → N users, N buildings, N trainings, N sessions |
| **Ràng buộc** | slug phải lowercase + dấu gạch ngang, không xóa nếu còn FK |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 2. `users`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Tài khoản người dùng với 3 role cố định |
| **Cột quan trọng** | `role` (PlatformAdmin / OrganizationUser / Trainee), `organization_id` (NULL với Admin/Trainee), `is_active`, `password_hash` |
| **Quan hệ** | N users → 1 org; 1 user → N devices, N sessions (as trainee), N buildings (as creator) |
| **Ràng buộc** | OrganizationUser **phải** có `organization_id`; Trainee/Admin **không được** có |
| **Lưu ý** | Email unique toàn hệ thống. Đổi role/org = tạo account mới |
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

---

## Nhóm 2 — Building / Hồ sơ Tòa nhà

### 4. `buildings`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Hồ sơ hiện hành của công trình |
| **Cột quan trọng** | `name`, `building_type`, `total_floors`, `is_active`, `created_by` |
| **Quan hệ** | 1 org → N buildings; 1 building → N revisions, N scenarios |
| **Ràng buộc** | UNIQUE(id, organization_id) — dùng cho composite FK từ bảng con |
| **Lưu ý** | Không chứa dữ liệu 3D. Soft delete qua `deleted_at` |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 5. `building_locations`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Địa chỉ và tọa độ GPS của tòa nhà |
| **Cột quan trọng** | `address`, `city`, `district`, `latitude`, `longitude`, `geojson` |
| **Quan hệ** | 1-1 với buildings |
| **Ràng buộc** | UNIQUE(building_id) — đúng một địa điểm/tòa nhà |
| **⚠️ Nhận xét** | Tách 1-1 không cần thiết nếu không có query geo. Có thể gộp vào `buildings` |
| **Trạng thái** | 🟡 Phase 1 optional (có thể gộp) |

### 6. `building_floors`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Metadata **mutable** từng tầng của tòa nhà |
| **Cột quan trọng** | `floor_number`, `floor_name`, `area_sqm`, `elevation_meters`, `is_basement`, `floor_plan_url` |
| **Quan hệ** | N floors → 1 building; được "chụp lại" bởi `revision_floors` |
| **Ràng buộc** | UNIQUE(building_id, floor_number) — không có 2 tầng cùng số |
| **Lưu ý** | Đây là dữ liệu "hiện tại". Lịch sử 3D nằm ở `revision_floors` |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 7. `building_contacts`
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
| **Cột quan trọng** | `kind` (Geometry/Scenario), `status` (Queued/Running/Succeeded/Failed), `job_key` (UUID duy nhất), `attempt_number`, `toolchain_version`, `lease_owner`, `heartbeat_at` |
| **Quan hệ** | N jobs → 1 revision; 1 job → N logs, N artifacts, 1 validation_run |
| **Ràng buộc** | Chỉ một job Queued/Running / revision tại một thời điểm (partial unique index) |
| **Lưu ý** | Retry = tạo job mới với `attempt_number` tăng, không sửa job cũ |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 11. `revision_processing_logs`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Log từng bước nhỏ trong pipeline (8 bước cụ thể) |
| **Cột quan trọng** | `step` (enum 8 bước), `status` (Started/Success/Failed), `message`, `duration_ms`, `attempt_number` |
| **Quan hệ** | N logs → 1 job → 1 revision |
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
| **Cột quan trọng** | `artifact_type` (Preview/Geometry/Graph/HazardGrid/CandidatePackage), `object_key`, `sha256_hash`, `size_bytes`, `schema_version` |
| **Quan hệ** | N artifacts → 1 job → 1 revision |
| **Ràng buộc** | UNIQUE(job_id, artifact_type, sha256_hash) — không ghi đè artifact cũ |
| **Lưu ý** | Bytes nằm ở object storage, DB chỉ lưu registry/provenance |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 15. `validation_runs`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kết quả QA tự động sau khi pipeline xong |
| **Cột quan trọng** | `kind` (Geometry/Scenario), `outcome` (Passed/Failed), `validator_version`, `report` (JSONB chi tiết), `scenario_hash`, `candidate_artifact_id` |
| **Quan hệ** | 1-1 với processing_jobs; referenced bởi revision_reviews |
| **Ràng buộc** | Geometry run: không có scenario/candidate. Scenario run: bắt buộc có scenario version + candidate + hash |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 16. `revision_issues`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Chi tiết từng vấn đề phát hiện trong một validation run |
| **Cột quan trọng** | `severity` (Info/Warning/Error), `code` (mã lỗi cố định), `ifc_guid` (phần tử IFC liên quan), `message`, `details` JSONB |
| **Quan hệ** | N issues → 1 validation_run |
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
| **Cột quan trọng** | `action` (ConfirmForTraining/Rejected), `reviewed_by`, `validation_run_id` (phải là Passed), `review_message` (bắt buộc khi Rejected) |
| **Quan hệ** | N reviews → 1 revision; 1 review → 1 scenario_version; 1 review → 1 validation_run |
| **Ràng buộc** | Mỗi scenario_version chỉ **một** ConfirmForTraining (partial unique index). Confirm xong không Reject ngược lại được |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 20. `releases`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Gói phát hành chính thức — pin cứng revision + scenario version + review |
| **Cột quan trọng** | `status` (Built/Published/Superseded/Revoked), `confirmation_review_id`, `published_by`, `revoked_by`, `revoked_reason`, `safety_thresholds` |
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
| **Cột quan trọng** | `manifest_url` + `manifest_sha256`, `package_url` + `checksum_sha256`, `package_size_bytes`, `min_runtime_version`, `build_target` (Android only) |
| **Quan hệ** | 1-1 với releases |
| **Ràng buộc** | Append-only sau insert; sai metadata thì rollback transaction, không sửa |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 22. `trainings`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Một "đợt đào tạo" dùng release cụ thể cho học viên |
| **Cột quan trọng** | `name`, `status` (Draft/Active/Closed/Archived), `mode` (default), `allowed_modes` (array), `max_attempts` (NULL = unlimited), `start_date`, `end_date` |
| **Quan hệ** | N trainings → 1 release; 1 training → N QR codes, N sessions |
| **Ràng buộc** | Sau khi có QR/session: lịch, mode, max_attempts **bị khóa** (không sửa được). Tên/mô tả vẫn sửa được |
| **Lưu ý** | `max_attempts` chỉ đếm session **Assessment** (không tính Learn/Guided). NULL = không giới hạn |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 23. `release_qr_codes`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Mã QR để học viên vào phiên diễn tập |
| **Cột quan trọng** | `qr_hash` (SHA-256 của token bí mật), `label`, `expires_at`, `is_active`, `revision_floor_id` (vị trí dán, không phải spawn point) |
| **Quan hệ** | N QRs → 1 training (và pin cả release + org qua composite FK) |
| **Ràng buộc** | Token raw chỉ trả **một lần** khi tạo để in. Rotation = tạo row mới. Deactivate = một chiều |
| **Lưu ý** | QR active chưa đủ để start — API còn kiểm tra training status, window, lượt, org/building active |
| **Trạng thái** | ✅ Phase 1 cần thiết |

---

## Nhóm 7 — Learning Records / Dữ liệu Học tập

### 24. `sessions`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Mỗi lượt chơi của học viên = một Session |
| **Cột quan trọng** | `status` (9 trạng thái), `mode`, `start_key` (idempotency key), `scenario_hash`, `release_hash`, `app_version`, `unity_version`, `protocol_version`, `started_at`, `launched_at`, `ended_at`, `content_status_at_completion` |
| **Quan hệ** | Pin cứng: training + release + scenario_version + QR + device + org |
| **Ràng buộc** | UNIQUE(trainee_user_id, start_key) — retry cùng key trả session cũ |
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
| **Cột quan trọng** | `sequence_number` (bắt đầu từ 1), `client_event_id` (UUID idempotency), `event_type`, `event_data` (JSONB), `elapsed_ms` (runtime đơn điệu), `recorded_at` (client), `received_at` (server) |
| **Quan hệ** | N events → 1 session |
| **Ràng buộc** | UNIQUE(session_id, sequence_number) + UNIQUE(session_id, client_event_id) — dedup retry |
| **Lưu ý** | Complete chỉ được khi **không có khoảng trống** sequence từ 1 đến last_event_sequence |
| **Event đề xuất** | SESSION_STARTED, ROUTE_SELECTED, ROUTE_REPLANNED, ENTER_HAZARD_ZONE, EXIT_HAZARD_ZONE, WRONG_EXIT, REACHED_EXIT, SESSION_ABORTED |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 26. `session_results`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Kết quả chốt cuối cùng của session — append-only, không sửa |
| **Cột quan trọng** | `score` (0–100), `time_taken_seconds`, `wrong_exits`, `hazard_exposure_score`, `total_distance_meters`, `reached_exit`, `exit_point_id`, `rubric_version`, `path_traveled` (JSONB), `completion_key`, `last_event_sequence` |
| **Quan hệ** | 1-1 với sessions (UNIQUE) |
| **Ràng buộc** | Backend chấm điểm trước khi gọi SQL. SQL **không tự tính** score. Retry với key+payload khác → conflict |
| **Lưu ý** | Khi `reached_exit = true`, `exit_point_id` **bắt buộc** có giá trị |
| **Trạng thái** | ✅ Phase 1 cần thiết |

### 27. `session_checkpoints`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Lưu trạng thái game tại mốc thời gian để có thể resume |
| **Cột quan trọng** | `player_transform` (JSONB vị trí), `player_status`, `world_interactive_states`, `hazard_time_step`, `npc_states`, `active_objectives`, `release_hash`, `scenario_hash` |
| **⚠️ Trạng thái** | 🔴 **Dự phòng — Phase 2** (Offline resume). Phase 1 online-only, mất mạng = Crashed, không resume. Hiện không có API nào ghi/đọc bảng này |

### 28. `debrief_artifacts`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Dữ liệu phân tích sau diễn tập (tính toán từ session_results) |
| **Cột quan trọng** | `trajectory_heatmap`, `optimal_path` (đường đi tối ưu so sánh), `wrong_decisions`, `hazard_timeline`, `npc_summary`, `is_visible_to_trainee`, `generator_version` |
| **Quan hệ** | 1-1 với session_results |
| **⚠️ Trạng thái** | 🔴 **Dự phòng — Phase 2**. Cần service riêng để generate. `session_results.path_traveled` đã đủ cho debrief cơ bản |

### 29. `audit_logs`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Nhật ký toàn bộ thao tác quan trọng của hệ thống |
| **Cột quan trọng** | `user_id` (nullable), `organization_id` (snapshot), `actor_type` (User/Worker/System), `action` (17 loại), `target_entity`, `target_id`, `correlation_id`, `old_values`, `new_values`, `ip_address` |
| **Ràng buộc** | Không FK cứng vào users → giữ lịch sử kể cả khi xóa tài khoản. Runtime role không được DELETE/TRUNCATE |
| **Lưu ý** | Không ghi password/token/signed URL. Trigger không đoán người UPDATE từ created_by |
| **Trạng thái** | ✅ Phase 1 cần thiết |

---

## Nhóm 8 — Phase 2: Thương mại & Hỗ trợ

> [!WARNING]
> Các bảng này **giữ từ v5**, chưa production-ready. Doc tự cảnh báo còn thiếu: entitlement, quotation immutability, checkout mồ côi, thanh toán muộn/duplicate, invoice discount, message thread support. Không coi là tính năng đã hoàn thiện.

### 30. `service_packages`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Danh mục gói dịch vụ thương mại do PlatformAdmin quản lý |
| **Cột quan trọng** | `code` (mã ổn định), `name`, `unit_price`, `currency`, `duration_months`, `features` JSONB, `is_active` |
| **Trạng thái** | 🟠 Phase 2 |

### 31. `quotations`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Báo giá gửi cho Organization |
| **Cột quan trọng** | `quotation_number`, `status` (Draft/Issued/Accepted/Expired/Cancelled), `quantity`, `unit_price`, `subtotal_amount`, `tax_amount`, `discount_amount`, `total_amount`, `valid_until` |
| **Ràng buộc** | CHECK tính toán: total = subtotal + tax - discount; subtotal = unit_price × quantity |
| **Trạng thái** | 🟠 Phase 2 |

### 32. `payos_payment_requests`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Yêu cầu thanh toán qua cổng PayOS |
| **Cột quan trọng** | `order_code` (PayOS orderCode), `expected_amount`, `checkout_url`, `return_url`, `cancel_url`, `status`, `paid_transaction_id` |
| **Bảo mật** | Owned bởi `fet3d_payos_ledger_owner` role riêng. Không DML trực tiếp từ API thường |
| **Trạng thái** | 🟠 Phase 2 |

### 33. `payment_transactions`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Ghi nhận webhook từ PayOS sau khi người dùng thanh toán |
| **Cột quan trọng** | `webhook_event_id` (idempotency key), `received_order_code`, `received_amount`, `signature_verified`, `status` (Received→Verified→Applied/Rejected), `raw_payload` |
| **Ràng buộc** | Append-only. Bất biến sau Applied/Rejected. Trigger chặn mọi DELETE |
| **Trạng thái** | 🟠 Phase 2 |

### 34. `invoice_metadata`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Thông tin xuất hóa đơn sau thanh toán thành công |
| **Cột quan trọng** | `invoice_number`, `legal_name`, `tax_code`, `billing_address`, `subtotal_amount`, `tax_amount`, `total_amount`, `invoice_url` |
| **Quan hệ** | 1-1 với payment_transactions (chỉ transaction Applied) |
| **Trạng thái** | 🟠 Phase 2 |

### 35. `feedback`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Phản hồi từ người dùng về hệ thống hoặc một session |
| **Cột quan trọng** | `category`, `rating` (1–5, nullable), `message`, `status` (Submitted/Reviewed/Closed), `submitted_by`, `session_id` (optional) |
| **Trạng thái** | 🟠 Phase 2 |

### 36. `support_tickets`
| Thuộc tính | Giá trị |
|---|---|
| **Mục đích** | Ticket hỗ trợ kỹ thuật, có thể liên kết feedback/session |
| **Cột quan trọng** | `ticket_number`, `subject`, `description`, `priority` (Low/Normal/High/Urgent), `status` (Open/InProgress/Resolved/Closed), `assigned_to`, `resolved_at` |
| **Quan hệ** | Có thể link: feedback, session, organization |
| **Trạng thái** | 🟠 Phase 2 |

---

## 🔑 4 Stored Function chính

| Function | Mục đích | Input quan trọng |
|---|---|---|
| `confirm_revision_for_training()` | Xác nhận scenario version sẵn sàng đào tạo | revision, scenario_version, actor, validation_run |
| `start_training_session()` | Tạo/trả session từ QR quét | actor, QR_id, device_id, mode, start_key, app/unity/protocol version |
| `append_session_event()` | Ghi sự kiện từ Unity (dedup retry) | session_id, sequence, client_event_id, type, payload, elapsed_ms |
| `complete_training_session()` | Chốt kết quả + terminal state (atomic) | actor, session_id, completion_key, last_seq, scored_payload, outcome |

---

## 📊 Tóm tắt theo Phase

| Phase | Số bảng | Bảng |
|---|---|---|
| ✅ Phase 1 core | 23 | organizations, users, user_devices, buildings, building_floors, revisions, source_documents, processing_jobs, revision_processing_logs, revision_floors, annotation_sets, revision_artifacts, validation_runs, revision_issues, scenarios, scenario_versions, revision_reviews, releases, release_packages, trainings, release_qr_codes, sessions, session_events, session_results, audit_logs |
| 🟡 Phase 1 optional | 2 | building_locations, building_contacts |
| 🔴 Dự phòng (Phase 2 offline) | 2 | session_checkpoints, debrief_artifacts |
| 🟠 Phase 2 (billing/support) | 7 | service_packages, quotations, payos_payment_requests, payment_transactions, invoice_metadata, feedback, support_tickets |

---

## ⚠️ Những điểm cần thảo luận trong họp

### 1. Bảng có thể bỏ/gộp
- **`building_locations`**: Gộp vào `buildings` nếu không có query geospatial
- **`building_contacts`**: Gộp vào `buildings.metadata` JSONB tạm thời
- **`session_checkpoints`**: Bỏ khỏi Phase 1, chỉ tạo khi có offline resume thật
- **`debrief_artifacts`**: Bỏ khỏi Phase 1; `path_traveled` trong `session_results` đã đủ cho debrief cơ bản

### 2. Nguyên tắc quan trọng nhóm cần nhớ
| Nguyên tắc | Bảng áp dụng |
|---|---|
| **Snapshot bất biến** | revision_floors, scenario_versions, revision_artifacts, session_results — không UPDATE, chỉ INSERT |
| **Hash là bằng chứng** | source_documents, revision_artifacts, release_packages, sessions — không tin URL hay client value |
| **Composite FK nhiều chiều** | Sessions pin 4–5 bảng cùng lúc qua composite FK để tránh cross-tenant |
| **DB không tự tính score** | Backend chấm điểm trước, gọi SQL với kết quả đã validate |
| **Payment tách biệt role** | payos_payment_requests + payment_transactions owned bởi `fet3d_payos_ledger_owner` riêng |
| **Audit độc lập** | audit_logs không FK vào users để giữ lịch sử khi xóa account |

### 3. Workflow chưa có implementation
- Auth / JWT / refresh token (chỉ có DB schema, chưa có bảng token)
- IFC geometry validator (worker ngoài DB)
- Object storage integration (DB chỉ lưu key, không lưu bytes)
- Flutter-Unity launch protocol
- Phase 2 billing/support hoàn chỉnh
