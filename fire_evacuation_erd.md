# Fire Evacuation Training 3D — PostgreSQL ERD

This ERD mirrors the design target in `fire_evacuation_schema.sql` version 6.7. SQL is authoritative for defaults and check-constraint expressions; every table, column, enum-backed field, foreign key, and relationship is represented below. This is a design document, not a database migration.

## Contract notes

- `user_role_enum` is exactly `PlatformAdmin | OrganizationUser | Trainee`. `OrganizationUser` requires `organization_id`; `PlatformAdmin` and `Trainee` require it to be null.
- BE owns local email/password credentials and Fire3D sessions. `users.password_hash` is nullable for Google-only accounts, while `users.firebase_uid` maps a verified Firebase Google identity to FET3D roles/tenant data. The database stores only password/refresh/reset token hashes, never plaintext passwords or Google refresh tokens. FCM registration tokens belong to device installations and are not authentication credentials.
- Supabase hosts PostgreSQL and the `pgvector` extension for RAG storage; Supabase Auth is not used. Raw IFC and immutable runtime packages are stored in private AWS S3 buckets.
- `file_type_enum` is exactly `IFC`.
- Redis is a target cache/Streams transport behind the backend; PostgreSQL remains authoritative and Redis is not modeled as a source table. Outbox and consumer dedup are represented by `integration_outbox_events` and `integration_event_consumptions`.
- `ConfirmForTraining` is the persisted `revision_reviews.action` for one revision/ScenarioVersion pair; it may transition the revision from `ReadyForScenario` to `ConfirmedForTraining` but does not prevent authoring other compatible Scenarios. It is readiness-only. The executable order is confirmed revision/scenario → `Built` release + package + matching Active `Training` → Active Building service entitlement → `Published` release → stable Building QR → published training list → selected session pin.
- `release_qr_codes` is canonical at Building scope and has no release/training FK. Preparation directly pins `trainee_user_id`, selected `training_id`, `scenario_version_id`, `release_id`, and `qr_code_id`; only the explicit online session start requires an Active Building entitlement. QR participation never compares the Trainee to an organization or allowlist.
- The design keeps at most one active canonical row per Building; physical copies may reuse the same opaque QR value. A management revoke deactivates the QR separately from service expiry.
- A trusted PayOS adapter verifies `req.body` with the official SDK `webhooks.verify`, or canonicalizes and alphabetically sorts webhook `data` fields using the official algorithm, before database invocation. `apply_verified_payos_webhook` performs no cryptography; it records adapter attestation, deduplicates `webhook_event_id`, and compares `orderCode`, amount, and currency before recording `Paid`.
- `create_pending_payos_payment_request` derives organization, amount and currency from an unexpired `Accepted` quotation and can create only `Pending`. `fet3d_payos_request_executor` and `fet3d_payos_webhook_executor` are separate function-only `NOLOGIN` roles with no payment-table DML; the function/table owner is a separate `NOLOGIN` ledger role. Deployment must not grant ledger-owner inheritance or direct payment-table DML to runtime logins.
- `payment_transactions` is append-only once terminal, and an `Applied` transaction plus its `Paid` request provenance is immutable.
- `return_url` is UI navigation only and is never payment confirmation. PayOS does not imply automatic recurring debit.
- Building service periods are independent from organization AI billing periods. AI usage is ledgered by organization/building/user/audience/request type with request/idempotency keys, reservation allocations, overage consent and immutable price snapshots. Trainee daily grants are user-scoped and do not require organization membership.
- `Scenario` is the logical authoring object; `ScenarioVersion` is an append-only snapshot tied to compatible revision geometry. A revision can host multiple scenarios and can continue authoring after one scenario has been confirmed.
- `ScenarioDraft` and `ProcessingJob` are non-release working records. `ValidationRun`/`ValidationIssue` hold toolchain/artifact evidence and block publish on open Error/Critical issues. Organization playtest may use a verified draft package within Admin limits or an Active Building entitlement, but it is not a Trainee session and is excluded from learning analytics.
- `processing_jobs.input_hash` is the canonical logical-job input hash. Attempts add lease/toolchain/output provenance; an attempt may be claimed only when queued or when the current lease has expired. A completed job is replay-safe and is not re-run by duplicate delivery.
- AI billing snapshots become immutable at `Closed`, while `settlement_quotation_id` is attached only on `Closed → Invoiced` and `settlement_payment_transaction_id` only on `Invoiced → Paid`. Adjustment records are used after close; dispute metadata does not become a settlement status and does not reopen or rewrite the period.
- `close_ai_billing_period` locks the period, includes only confirmed billable usage, creates immutable items and freezes the totals in one transaction. Items cannot be added, edited or deleted after close; late/uncertain usage becomes an adjustment with its own organization and idempotency key.
- Runtime capability arrays are valid only when every element is a non-empty string; an explicitly declared empty array is valid. Publish accepts any active catalog runtime that is numerically at least the package minimum and matches protocol/schema.
- Worker claim returns `Claimed`, `Busy`, `AlreadyCompleted`, `NotClaimable` or `Conflict`; requeue is an explicit idempotent outbox operation. Job identity/input hash, artifact rows, accepted validation provenance and policy versions are immutable.
- `fet3d_session_owner`, `fet3d_ai_accounting_owner` and `fet3d_processing_owner` are `NOLOGIN` function owners. Runtime executors receive only the listed `EXECUTE` privileges and no direct DML on protected tables. Learn actor, ETag, idempotency, audit and publish/hide/show/delete/restore orchestration belongs to the .NET application service; SQL retains only relational and immutable Published-snapshot checks.
- Learn is a public blog/library, separate from Unity `trainings` and `sessions`. `PlatformAdmin` owns editorial writes; a post can be created as Unpublished or published immediately, then moved Published ↔ Hidden or soft-deleted/restored through controlled gates. `learn_posts` is the stable identity and `learn_post_versions` is the immutable published snapshot; Hidden retains `published_version_id` and remains eligible for RAG, while Deleted is excluded from public reads and retrieval. A Published version also freezes its situation/source join rows; bookmark rows are Trainee-owned create/delete records, not editable enrollment. Drafts may reference Common sources before independent approval, but publish/show and RAG require an allowed Approved Common source. Video blocks store validated provider/URL metadata; no provider-specific media table or arbitrary iframe/script is part of the design.

## Enum values

| Enum | Values |
|---|---|
| `user_role_enum` | `PlatformAdmin`, `OrganizationUser`, `Trainee` |
| `file_type_enum` | `IFC` |
| `revision_status_enum` | `Draft`, `Uploaded`, `Processing`, `NeedsFix`, `ReadyForScenario`, `ConfirmedForTraining`, `Rejected`, `Failed`, `Superseded` |
| `review_action_enum` | `ConfirmForTraining`, `Rejected` |
| `release_status_enum` | `Built`, `Published`, `Superseded`, `Revoked` |
| `training_status_enum` | `Draft`, `Active`, `Closed`, `Archived` |
| `quarantine_status_enum` | `Pending`, `Accepted`, `Rejected` |
| `session_mode_enum` | `Learn`, `Guided`, `Assessment` |
| `session_status_enum` | `Created`, `Launching`, `Running`, `Completed`, `CompletedWithSupersededRelease`, `ScenarioUnsurvivable`, `Aborted`, `Abandoned`, `Crashed` |
| `audit_action_enum` | `Upload`, `ConfirmForTraining`, `Reject`, `Publish`, `Revoke`, `Sync`, `Login`, `Logout`, `Download`, `Delete`, `Create`, `Update`, `Rollback`, `Grant`, `Resume`, `Payment`, `Support` |
| `processing_step_enum` | `Quarantine`, `Parse`, `CleanGeometry`, `Decimate`, `GenNavMesh`, `GenHazardGrid`, `ExportGLB`, `PackageBundle` |
| `processing_step_status_enum` | `Started`, `Success`, `Failed` |
| `quotation_status_enum` | `Draft`, `Issued`, `Accepted`, `Expired`, `Cancelled` |
| `payment_request_status_enum` | `Pending`, `Paid`, `Expired`, `Cancelled`, `Failed` |
| `payment_transaction_status_enum` | `Received`, `Verified`, `Rejected`, `Applied` |
| `feedback_status_enum` | `Submitted`, `Reviewed`, `Closed` |
| `support_ticket_status_enum` | `Open`, `InProgress`, `Resolved`, `Closed` |
| `support_priority_enum` | `Low`, `Normal`, `High`, `Urgent` |

```mermaid
erDiagram

    organizations {
        UUID id PK
        VARCHAR name
        VARCHAR slug
        TEXT address
        VARCHAR phone
        BIGINT profile_revision_no
        BOOLEAN is_active
        JSONB metadata
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
        TIMESTAMPTZ deleted_at
    }

    users {
        UUID id PK
        UUID organization_id FK
        VARCHAR firebase_uid
        VARCHAR email
        TEXT password_hash
        VARCHAR username UK
        VARCHAR full_name
        TEXT avatar_storage_key
        BIGINT profile_revision_no
        user_role_enum role
        BOOLEAN is_active
        TIMESTAMPTZ last_login_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
        TIMESTAMPTZ deleted_at
    }

    auth_google_onboarding_sessions {
        UUID id PK
        VARCHAR firebase_uid
        VARCHAR email
        VARCHAR onboarding_token_hash UK
        user_role_enum requested_role
        JSONB organization_draft
        TIMESTAMPTZ expires_at
        TIMESTAMPTZ completed_at
        UUID completed_user_id FK
        VARCHAR completed_input_hash
        TIMESTAMPTZ created_at
    }

    user_devices {
        UUID id PK
        UUID user_id FK
        VARCHAR device_uuid
        VARCHAR device_model
        VARCHAR os_version
        VARCHAR app_version
        TEXT fcm_token
        TIMESTAMPTZ fcm_token_updated_at
        BOOLEAN notifications_enabled
        TIMESTAMPTZ last_seen_at
        TIMESTAMPTZ created_at
    }

    buildings {
        UUID id PK
        UUID organization_id FK
        VARCHAR name
        VARCHAR building_type
        INT total_floors
        TEXT address
        VARCHAR city
        VARCHAR district
        DECIMAL latitude
        DECIMAL longitude
        JSONB geojson
        BOOLEAN is_active
        UUID created_by FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
        TIMESTAMPTZ deleted_at
    }

    building_floors {
        UUID id PK
        UUID building_id FK
        UUID organization_id FK
        INT floor_number
        VARCHAR floor_name
        TEXT floor_plan_url
        DECIMAL area_sqm
        DECIMAL elevation_meters
        BOOLEAN is_basement
        JSONB metadata
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    building_contacts {
        UUID id PK
        UUID building_id FK
        VARCHAR contact_name
        VARCHAR contact_role
        VARCHAR phone
        VARCHAR email
        BOOLEAN is_primary
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    revisions {
        UUID id PK
        UUID building_id FK
        UUID uploaded_by FK
        VARCHAR version_label
        file_type_enum primary_type
        revision_status_enum status
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    source_documents {
        UUID id PK
        UUID revision_id FK
        UUID floor_id FK
        UUID uploaded_by FK
        VARCHAR original_filename
        file_type_enum file_type
        BIGINT file_size_bytes
        TEXT storage_url
        VARCHAR mime_type
        VARCHAR sha256_hash
        quarantine_status_enum quarantine_status
        TEXT quarantine_note
        TEXT usage_rights
        VARCHAR source_tool
        TIMESTAMPTZ created_at
    }

    annotation_sets {
        UUID id PK
        UUID revision_id FK
        INT version_number
        JSONB data
        VARCHAR provenance
        UUID created_by FK
        TIMESTAMPTZ created_at
    }

    revision_processing_logs {
        UUID id PK
        UUID revision_id FK
        UUID job_id FK
        UUID attempt_id FK
        processing_step_enum step
        processing_step_status_enum status
        TEXT message
        INT duration_ms
        TIMESTAMPTZ logged_at
    }

    revision_artifacts {
        UUID id PK
        UUID revision_id FK
        UUID job_id FK
        UUID attempt_id FK
        VARCHAR artifact_type
        TEXT storage_key
        VARCHAR sha256_hash
        JSONB metadata
        BOOLEAN is_runtime_ready
        TIMESTAMPTZ created_at
    }

    bim_facts {
        UUID id PK
        UUID revision_id FK
        VARCHAR ifc_global_id
        VARCHAR entity_type
        TEXT property_path
        JSONB value
        VARCHAR source_hash
        JSONB quality_flags
        TIMESTAMPTZ created_at
    }

    revision_reviews {
        UUID id PK
        UUID revision_id FK
        UUID scenario_version_id FK
        UUID reviewed_by FK
        UUID annotation_set_id FK
        review_action_enum action
        TEXT review_message
        TIMESTAMPTZ reviewed_at
    }

    processing_jobs {
        UUID id PK
        UUID revision_id FK
        UUID source_document_id FK
        UUID scenario_version_id FK
        VARCHAR kind
        UUID job_key
        VARCHAR input_hash
        VARCHAR status
        UUID current_attempt_id FK
        TIMESTAMPTZ created_at
    }

    validation_runs {
        UUID id PK
        UUID revision_id FK
        UUID scenario_version_id FK
        UUID processing_job_id FK
        UUID processing_attempt_id FK
        UUID artifact_id FK
        UUID release_id FK
        VARCHAR scope
        VARCHAR validator_version
        VARCHAR status
        JSONB summary
        VARCHAR issues_hash
        TIMESTAMPTZ started_at
        TIMESTAMPTZ finished_at
        TIMESTAMPTZ created_at
    }

    validation_issues {
        UUID id PK
        UUID validation_run_id FK
        UUID revision_id FK
        UUID scenario_version_id FK
        UUID artifact_id FK
        VARCHAR issue_code
        VARCHAR severity
        VARCHAR status
        TEXT message
        JSONB evidence
        TIMESTAMPTZ created_at
        TIMESTAMPTZ resolved_at
        UUID resolved_by FK
    }

    scenarios {
        UUID id PK
        UUID building_id FK
        UUID organization_id FK
        VARCHAR name
        UUID created_by FK
        TIMESTAMPTZ created_at
    }

    scenario_drafts {
        UUID id PK
        UUID scenario_id FK
        UUID revision_id FK
        UUID building_id FK
        UUID organization_id FK
        INT draft_number
        JSONB state
        VARCHAR source
        UUID last_ai_request_id
        UUID created_by FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    scenario_versions {
        UUID id PK
        UUID scenario_id FK
        UUID revision_id FK
        UUID building_id FK
        UUID organization_id FK
        INT version_number
        VARCHAR name
        VARCHAR schema_version
        VARCHAR algorithm_version
        BIGINT random_seed
        JSONB spawn_config
        JSONB goal_config
        JSONB fire_source_config
        JSONB smoke_config
        JSONB wind_config
        JSONB interaction_anchors
        JSONB npc_config
        JSONB blocked_elements
        VARCHAR guidance_level
        JSONB safety_thresholds
        INT time_limit_seconds
        JSONB routing_config
        JSONB scoring_config
        JSONB mode_policy
        VARCHAR scenario_hash
        UUID created_by FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    releases {
        UUID id PK
        UUID revision_id FK
        UUID scenario_version_id FK
        UUID building_id FK
        UUID organization_id FK
        UUID published_by FK
        UUID revoked_by FK
        release_status_enum status
        JSONB safety_thresholds
        TEXT revoked_reason
        TIMESTAMPTZ published_at
        TIMESTAMPTZ updated_at
    }

    release_packages {
        UUID id PK
        UUID release_id FK
        TEXT manifest_url
        TEXT package_url
        VARCHAR checksum_sha256
        VARCHAR protocol_version
        VARCHAR manifest_schema_version
        BIGINT package_size_bytes
        VARCHAR min_runtime_version
        JSONB required_capabilities
        VARCHAR build_target
        UUID candidate_artifact_id FK
        UUID candidate_validation_run_id FK
        VARCHAR manifest_sha256
        TIMESTAMPTZ created_at
    }

    release_qr_codes {
        UUID id PK
        UUID building_id FK
        UUID organization_id FK
        UUID floor_id FK
        UUID created_by FK
        VARCHAR qr_hash
        VARCHAR label
        TIMESTAMPTZ expires_at
        BOOLEAN is_active
        TIMESTAMPTZ created_at
    }

    trainings {
        UUID id PK
        UUID release_id FK
        UUID scenario_version_id FK
        UUID organization_id FK
        VARCHAR name
        TEXT description
        TIMESTAMPTZ start_date
        TIMESTAMPTZ end_date
        training_status_enum status
        session_mode_enum mode
        TEXT_ARRAY allowed_modes
        INT max_attempts
        UUID created_by FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    sessions {
        UUID id PK
        UUID training_id FK
        UUID release_id FK
        UUID scenario_version_id FK
        UUID organization_id FK
        UUID trainee_user_id FK
        UUID device_id FK
        UUID qr_code_id FK
        VARCHAR app_version
        VARCHAR unity_engine_version
        VARCHAR package_hash
        UUID package_artifact_id FK
        UUID package_validation_run_id FK
        VARCHAR prepare_idempotency_key
        VARCHAR manifest_sha256
        VARCHAR build_target
        VARCHAR protocol_version
        VARCHAR manifest_schema_version
        VARCHAR runtime_version
        UUID runtime_catalog_id FK
        VARCHAR prepare_idempotency_key
        VARCHAR start_idempotency_key
        session_mode_enum mode
        session_status_enum status
        TIMESTAMPTZ created_at
        TIMESTAMPTZ launch_granted_at
        TIMESTAMPTZ started_at
        TIMESTAMPTZ last_heartbeat_received_at
        BIGINT last_heartbeat_sequence
        TIMESTAMPTZ ended_at
    }

    playtest_sessions {
        UUID id PK
        UUID organization_id FK
        UUID building_id FK
        UUID revision_id FK
        UUID scenario_draft_id FK
        UUID scenario_version_id FK
        UUID service_entitlement_id FK
        UUID created_by FK
        VARCHAR package_hash
        UUID package_artifact_id FK
        UUID package_validation_run_id FK
        VARCHAR manifest_sha256
        VARCHAR build_target
        VARCHAR protocol_version
        VARCHAR manifest_schema_version
        VARCHAR runtime_version
        VARCHAR unity_engine_version
        UUID runtime_catalog_id FK
        VARCHAR start_idempotency_key
        VARCHAR completion_idempotency_key
        VARCHAR status
        TIMESTAMPTZ created_at
        TIMESTAMPTZ started_at
        TIMESTAMPTZ last_heartbeat_received_at
        TIMESTAMPTZ ended_at
    }

    session_results {
        UUID id PK
        UUID session_id FK
        DECIMAL score
        INT time_taken_seconds
        INT wrong_exits
        DECIMAL hazard_exposure_score
        DECIMAL total_distance_meters
        BOOLEAN reached_exit
        VARCHAR exit_point_id
        JSONB path_traveled
        TIMESTAMPTZ client_started_at
        TIMESTAMPTZ client_ended_at
        BOOLEAN is_synced
        TIMESTAMPTZ synced_at
        VARCHAR result_idempotency_key
        VARCHAR result_hash
        JSONB result_snapshot
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    session_checkpoints {
        UUID id PK
        UUID session_id FK
        INT sequence_number
        JSONB player_transform
        JSONB player_status
        JSONB world_interactive_states
        INT hazard_time_step
        JSONB npc_states
        JSONB active_objectives
        VARCHAR release_hash
        VARCHAR scenario_hash
        TIMESTAMPTZ created_at
    }

    debrief_artifacts {
        UUID id PK
        UUID session_id FK
        JSONB trajectory_heatmap
        JSONB optimal_path
        JSONB wrong_decisions
        JSONB hazard_timeline
        JSONB npc_summary
        BOOLEAN is_visible_to_trainee
        TIMESTAMPTZ generated_at
    }

    session_events {
        UUID id PK
        UUID session_id FK
        BIGINT sequence_number
        VARCHAR schema_version
        VARCHAR event_type
        JSONB event_data
        TIMESTAMPTZ recorded_at
        TIMESTAMPTZ received_at
    }

    audit_logs {
        UUID id PK
        UUID user_id FK
        UUID organization_id FK
        UUID correlation_id
        VARCHAR actor_type
        audit_action_enum action
        VARCHAR target_entity
        UUID target_id
        JSONB old_values
        JSONB new_values
        INET ip_address
        TEXT user_agent
        TIMESTAMPTZ created_at
    }

    service_packages {
        UUID id PK
        VARCHAR code
        VARCHAR name
        TEXT description
        DECIMAL unit_price
        VARCHAR currency
        INT duration_months
        JSONB features
        BOOLEAN is_active
        UUID created_by FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    quotations {
        UUID id PK
        UUID organization_id FK
        VARCHAR billing_purpose
        UUID requested_by FK
        UUID issued_by FK
        VARCHAR quotation_number
        quotation_status_enum status
        INT quantity
        DECIMAL unit_price
        DECIMAL subtotal_amount
        DECIMAL tax_amount
        DECIMAL discount_amount
        DECIMAL total_amount
        VARCHAR currency
        UUID discount_rule_id FK
        JSONB discount_snapshot
        JSONB price_snapshot
        JSONB terms_snapshot
        TIMESTAMPTZ valid_until
        TIMESTAMPTZ issued_at
        TIMESTAMPTZ accepted_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    quotation_building_items {
        UUID id PK
        UUID quotation_id FK
        UUID building_id FK
        UUID service_package_id FK
        VARCHAR purchase_action
        INT service_duration_months
        DECIMAL unit_price
        DECIMAL discount_amount
        DECIMAL subtotal_amount
        DECIMAL total_amount
        VARCHAR currency
        JSONB price_snapshot
        JSONB terms_snapshot
        JSONB discount_snapshot
        VARCHAR line_provisioning_key UK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    enterprise_quote_requests {
        UUID id PK
        UUID organization_id FK
        UUID requested_by FK
        INT requested_building_count
        INT requested_duration_months
        TEXT contact_name
        VARCHAR contact_email
        VARCHAR contact_phone
        TEXT notes
        VARCHAR status
        UUID quotation_id FK
        VARCHAR idempotency_key UK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    payos_payment_requests {
        UUID id PK, FK
        UUID quotation_id FK
        UUID organization_id FK
        UUID requested_by FK
        VARCHAR idempotency_key
        BIGINT order_code
        DECIMAL expected_amount
        VARCHAR expected_currency
        TEXT checkout_url
        TEXT return_url
        TEXT cancel_url
        payment_request_status_enum status
        UUID paid_transaction_id FK
        TIMESTAMPTZ expires_at
        TIMESTAMPTZ paid_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    payment_transactions {
        UUID id PK
        UUID payment_request_id FK
        VARCHAR webhook_event_id
        VARCHAR provider_transaction_id
        BIGINT received_order_code
        DECIMAL received_amount
        VARCHAR received_currency
        BOOLEAN signature_verified
        payment_transaction_status_enum status
        JSONB raw_payload
        TEXT rejection_reason
        TIMESTAMPTZ received_at
        TIMESTAMPTZ signature_verified_at
        TIMESTAMPTZ processed_at
    }

    payment_provisioning_records {
        UUID id PK
        UUID payment_transaction_id FK
        UUID quotation_id FK
        UUID quotation_item_id FK
        UUID organization_id FK
        VARCHAR provisioning_key
        VARCHAR status
        INT attempts
        TEXT last_error
        TIMESTAMPTZ provisioned_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    invoice_metadata {
        UUID id PK
        UUID payment_transaction_id FK
        UUID quotation_id FK
        UUID organization_id FK
        VARCHAR invoice_number
        TEXT legal_name
        VARCHAR tax_code
        TEXT billing_address
        DECIMAL subtotal_amount
        DECIMAL tax_amount
        DECIMAL total_amount
        VARCHAR currency
        TIMESTAMPTZ issued_at
        TEXT invoice_url
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    service_entitlements {
        UUID id PK
        UUID organization_id FK
        UUID building_id FK
        UUID service_package_id FK
        UUID quotation_id FK
        UUID quotation_item_id FK
        UUID payment_transaction_id FK
        VARCHAR provisioning_key
        VARCHAR status
        TIMESTAMPTZ starts_at
        TIMESTAMPTZ ends_at
        JSONB price_snapshot
        JSONB terms_snapshot
        INT playtest_units_granted
        INT playtest_units_used
        UUID created_by FK
        TIMESTAMPTZ created_at
    }

    ai_billing_periods {
        UUID id PK
        UUID organization_id FK
        TIMESTAMPTZ period_start
        TIMESTAMPTZ period_end
        VARCHAR status
        UUID settlement_quotation_id FK
        UUID settlement_payment_transaction_id FK
        JSONB unit_price_snapshot
        INT overage_units
        DECIMAL overage_amount
        VARCHAR currency
        TIMESTAMPTZ disputed_at
        TEXT disputed_reason
        UUID disputed_by FK
        TIMESTAMPTZ closed_at
        TIMESTAMPTZ created_at
    }

    ai_policy_versions {
        UUID id PK
        UUID organization_id FK
        VARCHAR audience
        VARCHAR policy_kind
        VARCHAR version_label
        JSONB policy_snapshot
        TIMESTAMPTZ effective_from
        TIMESTAMPTZ effective_until
        UUID created_by FK
        TIMESTAMPTZ created_at
    }

    ai_quota_grants {
        UUID id PK
        UUID organization_id FK
        UUID building_id FK
        UUID trainee_user_id FK
        VARCHAR audience
        VARCHAR quota_kind
        INT units_granted
        INT units_used
        INT units_reserved
        UUID policy_version_id FK
        TIMESTAMPTZ starts_at
        TIMESTAMPTZ ends_at
        UUID configured_by FK
        TIMESTAMPTZ created_at
    }

    ai_overage_consents {
        UUID id PK
        UUID organization_id FK
        UUID accepted_by FK
        TIMESTAMPTZ accepted_at
        JSONB terms_snapshot
        JSONB scope
    }

    ai_requests {
        UUID id PK
        VARCHAR idempotency_key
        UUID organization_id FK
        UUID building_id FK
        UUID user_id FK
        VARCHAR audience
        VARCHAR request_type
        JSONB source_scope
        UUID policy_version_id FK
        VARCHAR input_hash
        TEXT input_reference
        VARCHAR status
        VARCHAR result_type
        TEXT result_reference
        JSONB response_snapshot
        VARCHAR result_hash
        JSONB citations
        VARCHAR model_provider
        VARCHAR model_version
        JSONB technical_usage
        VARCHAR failure_code
        TIMESTAMPTZ created_at
        TIMESTAMPTZ completed_at
        TIMESTAMPTZ last_reconciled_at
    }

    ai_usage_ledger {
        UUID id PK
        UUID request_id FK
        VARCHAR idempotency_key
        UUID organization_id FK
        UUID building_id FK
        UUID user_id FK
        UUID session_id FK
        VARCHAR audience
        VARCHAR request_type
        UUID policy_version_id FK
        INT units
        UUID overage_consent_id FK
        BOOLEAN billable
        JSONB unit_price_snapshot
        UUID billing_period_id FK
        VARCHAR status
        JSONB source_scope
        TIMESTAMPTZ created_at
    }

    ai_billing_period_items {
        UUID id PK
        UUID billing_period_id FK
        UUID usage_ledger_id FK
        INT units
        JSONB unit_price_snapshot
        DECIMAL amount
        VARCHAR status
        TIMESTAMPTZ created_at
    }

    ai_billing_adjustments {
        UUID id PK
        UUID billing_period_id FK
        UUID organization_id FK
        UUID usage_ledger_id FK
        UUID original_item_id FK
        VARCHAR adjustment_type
        INT units
        DECIMAL amount
        TEXT reason
        VARCHAR idempotency_key
        UUID created_by FK
        TIMESTAMPTZ created_at
    }

    runtime_compatibility_catalog {
        UUID id PK
        VARCHAR runtime_version
        VARCHAR protocol_version
        VARCHAR manifest_schema_version
        JSONB capabilities
        BOOLEAN is_active
        TIMESTAMPTZ created_at
    }

    ai_usage_reservations {
        UUID id PK
        UUID request_id FK, UNIQUE
        INT units
        VARCHAR status
        TIMESTAMPTZ reserved_at
        TIMESTAMPTZ settled_at
    }

    ai_usage_reservation_allocations {
        UUID id PK
        UUID reservation_id FK
        UUID quota_grant_id FK
        INT units
        TIMESTAMPTZ created_at
    }

    integration_outbox_events {
        VARCHAR idempotency_key PK
        VARCHAR aggregate_type
        UUID aggregate_id
        VARCHAR event_type
        VARCHAR schema_version
        UUID organization_id FK
        JSONB payload
        VARCHAR payload_hash
        VARCHAR status
        INT attempts
        TIMESTAMPTZ available_at
        VARCHAR lease_owner
        UUID lease_token
        TIMESTAMPTZ lease_until
        UUID published_lease_token
        TEXT last_error
        TIMESTAMPTZ created_at
        TIMESTAMPTZ published_at
    }

    integration_event_consumptions {
        VARCHAR consumer_name PK
        VARCHAR event_key PK, FK
        VARCHAR payload_hash
        TEXT result_reference
        TIMESTAMPTZ processed_at
    }

    processing_job_attempts {
        UUID id PK
        UUID processing_job_id FK
        INT attempt_number
        VARCHAR input_hash
        VARCHAR toolchain_version
        VARCHAR lease_owner
        UUID lease_token
        TIMESTAMPTZ lease_until
        VARCHAR status
        VARCHAR output_hash
        UUID output_artifact_id FK
        UUID result_validation_run_id FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ started_at
        TIMESTAMPTZ finished_at
        TEXT error_message
    }

    knowledge_sources {
        UUID id PK
        UUID organization_id FK
        VARCHAR visibility
        TEXT title
        TEXT source_uri
        VARCHAR version_label
        VARCHAR source_hash
        TEXT jurisdiction
        TIMESTAMPTZ effective_from
        TIMESTAMPTZ effective_until
        VARCHAR approval_status
        UUID approved_by FK
        TIMESTAMPTZ created_at
    }

    application_command_receipts {
        UUID id PK
        UUID actor_user_id FK
        UUID organization_id FK
        VARCHAR operation_name
        VARCHAR idempotency_key
        VARCHAR input_hash
        VARCHAR result_status
        JSONB result_payload
        TIMESTAMPTZ created_at
    }

    organization_notifications {
        UUID id PK
        UUID organization_id FK
        UUID recipient_user_id FK
        UUID building_id FK
        UUID entitlement_id FK
        VARCHAR notification_type
        TEXT title
        TEXT body
        TIMESTAMPTZ reference_ends_at
        VARCHAR idempotency_key UK
        TIMESTAMPTZ read_at
        TIMESTAMPTZ created_at
    }

    notification_deliveries {
        UUID id PK
        UUID notification_id FK
        VARCHAR channel
        VARCHAR status
        INT attempts
        TEXT provider_message_id
        TEXT last_error
        TIMESTAMPTZ sent_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    auth_refresh_tokens {
        UUID id PK
        UUID user_id FK
        UUID family_id
        TEXT token_hash UK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ expires_at
        TIMESTAMPTZ consumed_at
        TIMESTAMPTZ revoked_at
    }

    password_reset_tokens {
        UUID id PK
        UUID user_id FK
        TEXT token_hash UK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ expires_at
        TIMESTAMPTZ used_at
    }

    learn_situations {
        UUID id PK
        VARCHAR slug UK
        VARCHAR name
        TEXT description
        BOOLEAN is_active
        UUID created_by FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    service_package_discount_rules {
        UUID id PK
        UUID service_package_id FK
        VARCHAR code UK
        VARCHAR discount_kind
        DECIMAL discount_value
        VARCHAR discount_currency
        INT minimum_buildings
        INT minimum_duration_months
        TIMESTAMPTZ valid_from
        TIMESTAMPTZ valid_until
        BOOLEAN is_active
        UUID created_by FK
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    learn_posts {
        UUID id PK
        VARCHAR slug UK
        VARCHAR publication_status -- Unpublished | Published | Hidden | Deleted
        UUID published_version_id FK
        UUID created_by FK
        BIGINT revision_no
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    learn_post_versions {
        UUID id PK
        UUID post_id FK
        INT version_number
        VARCHAR content_schema_version
        VARCHAR content_kind
        VARCHAR title
        TEXT summary
        TEXT cover_image_url
        JSONB content_blocks
        VARCHAR content_hash
        VARCHAR status
        UUID created_by FK
        UUID published_by FK
        TIMESTAMPTZ published_at
        BIGINT revision_no
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    learn_post_version_situations {
        UUID post_version_id FK
        UUID situation_id FK
        TIMESTAMPTZ created_at
    }

    learn_post_version_sources {
        UUID post_version_id FK
        UUID source_id FK
        VARCHAR source_role
        JSONB locator
        TIMESTAMPTZ created_at
    }

    learn_bookmarks {
        UUID trainee_user_id FK
        UUID post_id FK
        TIMESTAMPTZ created_at
    }

    knowledge_chunks {
        UUID id PK
        UUID source_id FK
        INT chunk_index
        TEXT content
        JSONB locator
        VECTOR embedding
        JSONB metadata
        TIMESTAMPTZ created_at
    }

    feedback {
        UUID id PK
        UUID submitted_by FK
        UUID organization_id FK
        UUID session_id FK
        VARCHAR category
        INT rating
        TEXT message
        feedback_status_enum status
        UUID reviewed_by FK
        TIMESTAMPTZ reviewed_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    support_tickets {
        UUID id PK
        VARCHAR ticket_number
        UUID created_by FK
        UUID organization_id FK
        UUID session_id FK
        UUID feedback_id FK
        UUID assigned_to FK
        VARCHAR subject
        TEXT description
        support_priority_enum priority
        support_ticket_status_enum status
        TIMESTAMPTZ resolved_at
        TIMESTAMPTZ created_at
        TIMESTAMPTZ updated_at
    }

    organizations o|--o{ users : scopes
    users o|--o{ auth_google_onboarding_sessions : completes
    users ||--o{ user_devices : registers
    users ||--o{ auth_refresh_tokens : owns
    users ||--o{ password_reset_tokens : resets
    users ||--o{ application_command_receipts : executes
    organizations o|--o{ application_command_receipts : scopes

    organizations ||--o{ buildings : owns
    users ||--o{ buildings : creates
    buildings ||--o{ building_floors : contains
    organizations ||--o{ building_floors : scopes
    buildings ||--o{ building_contacts : has

    buildings ||--o{ revisions : versions
    users ||--o{ revisions : uploads
    revisions ||--o{ source_documents : contains
    building_floors o|--o{ source_documents : locates
    users ||--o{ source_documents : uploads
    revisions ||--o{ annotation_sets : annotates
    revisions ||--o{ revision_artifacts : produces
    processing_jobs ||--o{ revision_artifacts : produces
    processing_job_attempts ||--o{ revision_artifacts : attests
    revisions ||--o{ bim_facts : extracts
    users ||--o{ annotation_sets : creates
    revisions ||--o{ revision_processing_logs : logs
    processing_jobs ||--o{ revision_processing_logs : attempts
    processing_jobs ||--o{ validation_runs : validates
    processing_job_attempts ||--o{ validation_runs : validates
    revision_artifacts o|--o{ validation_runs : proves
    validation_runs ||--o{ validation_issues : reports
    releases o|--o{ validation_runs : gates
    revisions ||--o{ revision_reviews : reviews
    scenario_versions ||--o{ revision_reviews : confirms
    users ||--o{ revision_reviews : performs
    annotation_sets o|--o{ revision_reviews : references

    buildings ||--o{ scenarios : owns
    organizations ||--o{ scenarios : scopes
    users ||--o{ scenarios : creates
    scenarios ||--o{ scenario_drafts : edits
    revisions ||--o{ scenario_drafts : targets
    scenarios ||--o{ scenario_versions : versions
    revisions ||--o{ scenario_versions : configures
    organizations ||--o{ scenario_versions : owns
    users ||--o{ scenario_versions : creates

    revisions ||--o{ releases : pins
    scenario_versions ||--o{ releases : pins
    buildings ||--o{ releases : publishes
    organizations ||--o{ releases : owns
    users o|--o{ releases : publishes
    users o|--o{ releases : revokes
    releases ||--o| release_packages : packages
    revision_artifacts ||--o{ release_packages : candidates
    validation_runs ||--o{ release_packages : attests
    buildings ||--o{ release_qr_codes : identifies
    organizations ||--o{ release_qr_codes : owns
    building_floors o|--o{ release_qr_codes : places
    users ||--o{ release_qr_codes : creates

    releases ||--o{ trainings : uses
    scenario_versions ||--o{ trainings : configures
    organizations ||--o{ trainings : owns
    users ||--o{ trainings : creates

    trainings ||--o{ sessions : groups
    releases ||--o{ sessions : pins
    scenario_versions ||--o{ sessions : runs
    organizations ||--o{ sessions : aggregates
    users ||--o{ sessions : participates
    user_devices ||--o{ sessions : runs
    release_qr_codes ||--o{ sessions : starts
    organizations ||--o{ playtest_sessions : owns
    buildings ||--o{ playtest_sessions : runs
    revisions ||--o{ playtest_sessions : uses
    scenario_drafts o|--o{ playtest_sessions : tests
    scenario_versions ||--o{ playtest_sessions : runs
    service_entitlements o|--o{ playtest_sessions : limits
    users ||--o{ playtest_sessions : starts
    sessions ||--o| session_results : produces
    sessions ||--o{ session_checkpoints : saves
    sessions ||--o| debrief_artifacts : summarizes
    sessions ||--o{ session_events : records
    organizations ||--o{ integration_outbox_events : scopes
    integration_outbox_events ||--o{ integration_event_consumptions : delivers

    users ||--o{ service_packages : creates
    organizations ||--o{ quotations : receives
    service_package_discount_rules o|--o{ quotations : applies
    quotations ||--o{ quotation_building_items : contains
    buildings ||--o{ quotation_building_items : selected
    service_packages ||--o{ quotation_building_items : prices
    organizations ||--o{ enterprise_quote_requests : requests
    quotations o|--o{ enterprise_quote_requests : answers
    ai_billing_periods o|--o| quotations : settles
    users ||--o{ quotations : requests
    users o|--o{ quotations : issues
    quotations ||--o{ payos_payment_requests : requests
    organizations ||--o{ payos_payment_requests : owns
    users ||--o{ payos_payment_requests : initiates
    payos_payment_requests ||--o{ payment_transactions : receives
    payment_transactions o|--o| payos_payment_requests : confirms
    payment_transactions ||--o| invoice_metadata : invoices
    payment_transactions ||--o{ payment_provisioning_records : reconciles
    quotations ||--o{ invoice_metadata : documents
    organizations ||--o{ invoice_metadata : owns
    organizations ||--o{ service_entitlements : owns
    buildings ||--o{ service_entitlements : activates
    service_packages ||--o{ service_entitlements : grants
    quotations o|--o{ service_entitlements : funds
    quotation_building_items o|--o{ service_entitlements : provisions
    payment_transactions o|--o{ service_entitlements : provisions
    quotations ||--o{ payment_provisioning_records : provisions
    quotation_building_items ||--o{ payment_provisioning_records : reconciles
    users ||--o{ service_entitlements : grants
    organizations ||--o{ organization_notifications : receives
    users ||--o{ organization_notifications : notified
    buildings o|--o{ organization_notifications : concerns
    service_entitlements o|--o{ organization_notifications : expires
    organization_notifications ||--o{ notification_deliveries : delivers
    organizations ||--o{ ai_billing_periods : settles
    ai_billing_periods ||--o{ ai_billing_period_items : includes
    ai_billing_periods ||--o{ ai_billing_adjustments : adjusts
    ai_usage_ledger ||--o{ ai_billing_period_items : billed
    ai_usage_ledger o|--o{ ai_billing_adjustments : corrected
    ai_billing_period_items o|--o{ ai_billing_adjustments : references
    organizations o|--o{ ai_policy_versions : configures
    organizations ||--o{ ai_quota_grants : receives
    buildings o|--o{ ai_quota_grants : scopes
    users o|--o{ ai_quota_grants : receives
    users ||--o{ ai_quota_grants : configures
    organizations ||--o{ ai_overage_consents : accepts
    users ||--o{ ai_overage_consents : accepts
    organizations o|--o{ ai_requests : accounts
    buildings o|--o{ ai_requests : scopes
    users ||--o{ ai_requests : submits
    ai_requests ||--o| ai_usage_ledger : charges
    organizations o|--o{ ai_usage_ledger : accounts
    buildings o|--o{ ai_usage_ledger : attributes
    users ||--o{ ai_usage_ledger : requests
    sessions o|--o{ ai_usage_ledger : debriefs
    ai_billing_periods o|--o{ ai_usage_ledger : settles
    ai_policy_versions ||--o{ ai_quota_grants : versions
    ai_policy_versions ||--o{ ai_usage_ledger : versions
    ai_quota_grants o|--o{ ai_usage_reservation_allocations : allocates
    ai_usage_ledger ||--o| ai_usage_reservations : reserves
    ai_usage_reservations ||--o{ ai_usage_reservation_allocations : allocates
    ai_overage_consents o|--o{ ai_usage_ledger : authorizes
    organizations o|--o{ knowledge_sources : owns
    knowledge_sources ||--o{ knowledge_chunks : chunks
    users o|--o{ knowledge_sources : approves
    users ||--o{ learn_situations : creates
    users ||--o{ learn_posts : creates
    users ||--o{ learn_post_versions : authors
    users o|--o{ learn_post_versions : publishes
    learn_posts ||--o{ learn_post_versions : versions
    learn_posts o|--o| learn_post_versions : publishes
    learn_post_versions ||--o{ learn_post_version_situations : classifies
    learn_situations ||--o{ learn_post_version_situations : groups
    learn_post_versions ||--o{ learn_post_version_sources : cites
    knowledge_sources ||--o{ learn_post_version_sources : supports
    users ||--o{ learn_bookmarks : saves
    learn_posts ||--o{ learn_bookmarks : bookmarked


    runtime_compatibility_catalog o|--o{ sessions : pins
    runtime_compatibility_catalog o|--o{ playtest_sessions : pins
    revision_artifacts ||--o{ sessions : pins
    validation_runs ||--o{ sessions : verifies
    revision_artifacts ||--o{ playtest_sessions : pins
    validation_runs ||--o{ playtest_sessions : verifies
    processing_jobs ||--o{ processing_job_attempts : retries

    users ||--o{ feedback : submits
    organizations o|--o{ feedback : scopes
    sessions o|--o{ feedback : concerns
    users o|--o{ feedback : reviews
    users ||--o{ support_tickets : opens
    organizations o|--o{ support_tickets : scopes
    sessions o|--o{ support_tickets : concerns
    feedback o|--o{ support_tickets : originates
    users o|--o{ support_tickets : handles
```

`application_command_receipts` also has the composite unique constraint
`(actor_user_id, operation_name, idempotency_key)` in SQL. It is documented
here as a relationship invariant rather than as a synthetic Mermaid field.
