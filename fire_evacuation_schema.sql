-- ==============================================================================
-- Project : Fire Evacuation Training 3D
-- Version : 6.7 (Redis outbox/consumer contract, canonical event hashing and dispatcher fencing)
-- Engine  : PostgreSQL 14+
-- Scope   : IFC authoring pipeline; Building-level service entitlement;
--           canonical Building QR -> published training list -> pinned session;
--           scenario versions, AI/RAG usage ledger, PayOS, invoice, feedback.
-- Target  : Supabase PostgreSQL + pgvector, Firebase identity mapping, AWS S3.
--           This design file is not an automatic migration for an existing DB.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- Supabase PostgreSQL hosts RAG embeddings/indexes through pgvector. The core
-- transactional tables below do not expose embedding columns directly.
CREATE EXTENSION IF NOT EXISTS vector;

-- ==============================================================================
-- SECTION 1: ENUM TYPES
-- ==============================================================================

-- Phân quyền người dùng trong hệ thống Multi-tenant
CREATE TYPE user_role_enum AS ENUM (
    'PlatformAdmin',    -- Quản trị viên toàn hệ thống
    'OrganizationUser', -- Sở hữu Building, IFC, scenario, publish, QR, analytics và billing
    'Trainee'           -- Học viên đã xác thực tham gia qua QR
);

-- IFC là định dạng source duy nhất của pipeline
CREATE TYPE file_type_enum AS ENUM (
    'IFC'               -- Industry Foundation Classes
);

-- Vòng đời xử lý phiên bản BIM (Revision Pipeline)
CREATE TYPE revision_status_enum AS ENUM (
    'Draft',            -- Revision mới tạo, chưa upload file
    'Uploaded',         -- File đã lên server, chờ worker xử lý
    'Processing',       -- Worker đang chạy pipeline tự động
    'NeedsFix',         -- Worker xong, có issue cần OrganizationUser sửa
    'ReadyForScenario', -- IFC và connectivity QA đạt, có thể author scenario
    'ConfirmedForTraining', -- ConfirmForTraining đã ghi nhận readiness nội bộ
    'Rejected',         -- OrganizationUser từ chối revision
    'Failed',           -- Worker lỗi sau tất cả lượt retry
    'Superseded'        -- Đã có revision mới hơn thay thế
);

-- Hành động review readiness do OrganizationUser thực hiện; không phải chứng nhận PCCC
CREATE TYPE review_action_enum AS ENUM (
    'ConfirmForTraining', -- Chuyển ReadyForScenario thành ConfirmedForTraining
    'Rejected'          -- Cần chỉnh sửa source/scenario kèm lý do
);

-- Trạng thái bản phát hành gói 3D tòa nhà (Release)
CREATE TYPE release_status_enum AS ENUM (
    'Built',            -- Đã đóng gói bundle 3D thành công
    'Published',        -- Bản phát hành chính thức có thể được QR active sử dụng
    'Superseded',       -- Đã có release mới hơn thay thế
    'Revoked'           -- Bị thu hồi khẩn cấp do phát hiện lỗi nghiêm trọng
);

-- Trạng thái vận hành hoạt động tập huấn; không phải điều kiện QR participation
CREATE TYPE training_status_enum AS ENUM (
    'Draft',            -- Hoạt động mới tạo
    'Active',           -- Hoạt động đang vận hành
    'Closed',           -- Hoạt động đã kết thúc
    'Archived'          -- Hoạt động đã lưu trữ
);

-- Trạng thái kiểm tra an toàn file upload (Antivirus Quarantine)
CREATE TYPE quarantine_status_enum AS ENUM (
    'Pending',          -- Đang chờ quét virus/mã độc
    'Accepted',         -- File an toàn, cho phép đưa vào pipeline
    'Rejected'          -- Phát hiện mã độc/file lỗi, bị chặn
);

-- Chế độ của phiên diễn tập
CREATE TYPE session_mode_enum AS ENUM (
    'Learn',            -- Chế độ tự do tham quan & học tập sơ đồ
    'Guided',           -- Chế độ luyện tập có mũi tên/trợ giúp dẫn đường
    'Assessment'        -- Chế độ thi/chấm điểm thực tế (không trợ giúp)
);

-- Trạng thái phiên diễn tập của người chơi
CREATE TYPE session_status_enum AS ENUM (
    'Created',                  -- Khởi tạo phiên thành công
    'Launching',                -- Đang tải bản đồ 3D & kịch bản vào game
    'Running',                  -- Đang trong quá trình di chuyển thoát nạn
    'Completed',                -- Hoàn thành thoát ra ngoài an toàn
    'CompletedWithSupersededRelease', -- Hoàn thành trên release đã bị thay thế giữa phiên
    'ScenarioUnsurvivable',     -- Nhân vật bị kẹt/ngạt khói tử vong trong game
    'Aborted',                  -- Người chơi chủ động thoát giữa chừng
    'Abandoned',                -- Treo game quá lâu không tương tác
    'Crashed'                   -- Mất kết nối/Sập ứng dụng
);

-- Hành động ghi nhật ký hệ thống (Audit Trail)
CREATE TYPE audit_action_enum AS ENUM (
    'Upload',           -- Tải file tài liệu/bản vẽ lên
    'ConfirmForTraining', -- Ghi nhận transition readiness nội bộ
    'Reject',           -- Từ chối nội dung
    'Publish',          -- Xuất bản bản phát hành mới
    'Revoke',           -- Thu hồi bản phát hành
    'Sync',             -- Đồng bộ dữ liệu offline từ Mobile
    'Login',            -- Đăng nhập hệ thống
    'Logout',           -- Đăng xuất hệ thống
    'Download',         -- Tải xuống tài nguyên/bản vẽ
    'Delete',           -- Xóa dữ liệu
    'Create',           -- Tạo mới dữ liệu
    'Update',           -- Cập nhật dữ liệu
    'Rollback',         -- Khôi phục phiên bản cũ
    'Grant',            -- Cấp quyền truy cập
    'Resume',           -- Khôi phục phiên chơi từ Checkpoint
    'Payment',          -- Xử lý quotation, PayOS hoặc invoice metadata
    'Support'           -- Xử lý feedback hoặc support ticket
);

-- Các bước trong Pipeline xử lý tự động file BIM/3D
CREATE TYPE processing_step_enum AS ENUM (
    'Quarantine',       -- Bước 1: Quét virus & mã độc
    'Parse',            -- Bước 2: Đọc cấu trúc hình học và thuộc tính IFC
    'CleanGeometry',    -- Bước 3: Làm sạch lưới 3D, tối ưu polygon
    'Decimate',         -- Bước 4: Giảm dung lượng mô hình cho Mobile
    'GenNavMesh',       -- Bước 5: Tạo lưới di chuyển NavMesh cho AI/Player
    'GenHazardGrid',    -- Bước 6: Chia lưới tọa độ mô phỏng cháy & khói
    'ExportGLB',        -- Bước 7: Xuất định dạng 3D chuẩn GLB/gTF
    'PackageBundle'     -- Bước 8: Đóng gói AssetBundle & tạo Manifest
);

-- Trạng thái từng bước xử lý trong Pipeline
CREATE TYPE processing_step_status_enum AS ENUM (
    'Started',          -- Bắt đầu thực thi bước
    'Success',          -- Xử lý hoàn tất thành công
    'Failed'            -- Xử lý thất bại
);

-- Phase 2: vòng đời quotation và thanh toán
CREATE TYPE quotation_status_enum AS ENUM (
    'Draft',
    'Issued',
    'Accepted',
    'Expired',
    'Cancelled'
);

CREATE TYPE payment_request_status_enum AS ENUM (
    'Pending',
    'Paid',
    'Expired',
    'Cancelled',
    'Failed'
);

CREATE TYPE payment_transaction_status_enum AS ENUM (
    'Received',
    'Verified',
    'Rejected',
    'Applied'
);

CREATE TYPE feedback_status_enum AS ENUM (
    'Submitted',
    'Reviewed',
    'Closed'
);

CREATE TYPE support_ticket_status_enum AS ENUM (
    'Open',
    'InProgress',
    'Resolved',
    'Closed'
);

CREATE TYPE support_priority_enum AS ENUM (
    'Low',
    'Normal',
    'High',
    'Urgent'
);

-- ==============================================================================
-- SECTION 2: COMMON FUNCTIONS
-- ==============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ==============================================================================
-- SECTION 3: TABLES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- GROUP 1: Multi-tenant & User Management
-- ------------------------------------------------------------------------------

CREATE TABLE organizations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh tổ chức/doanh nghiệp (Tenant)
    name        VARCHAR(255) NOT NULL,                      -- Tên hiển thị của tổ chức (VD: "Công ty ABC")
    slug        VARCHAR(100) UNIQUE NOT NULL,               -- Đường dẫn định danh URL tĩnh của tổ chức
    address     TEXT,                                        -- Địa chỉ liên hệ chính của tổ chức
    phone       VARCHAR(50),                                 -- Số điện thoại liên hệ chính
    is_active   BOOLEAN DEFAULT true,                       -- Cờ trạng thái hoạt động của tổ chức
    metadata    JSONB DEFAULT '{}',                         -- Thông tin bổ sung (logo URL, địa chỉ VP, mã số thuế...)
    created_at  TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm khởi tạo tổ chức
    updated_at  TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật thông tin tổ chức gần nhất
    deleted_at  TIMESTAMPTZ,                                -- Thời điểm xóa mềm tổ chức
    profile_revision_no BIGINT NOT NULL DEFAULT 1,           -- ETag/revision hồ sơ tổ chức
    CONSTRAINT check_organization_profile_revision CHECK (profile_revision_no > 0)
);

CREATE TABLE users (
    -- Định danh và liên kết tổ chức
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh người dùng
    organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT, -- Chỉ OrganizationUser có organization

    -- BE quản lý email/password; Firebase UID chỉ có khi liên kết Google.
    firebase_uid    VARCHAR(128) UNIQUE,                         -- UID Firebase của Google Sign-In, nếu có
    email           VARCHAR(255) UNIQUE NOT NULL,                 -- Email đăng nhập đã chuẩn hóa
    password_hash   TEXT,                                        -- Hash mật khẩu local; NULL với Google-only
    username        VARCHAR(30),                                 -- Tên đăng nhập duy nhất; bắt buộc với Trainee mới
    full_name       VARCHAR(255),                                -- Họ tên hiển thị, được phép trùng
    avatar_storage_key TEXT,                                     -- S3 object key private; không lưu signed URL
    profile_revision_no BIGINT NOT NULL DEFAULT 1,               -- ETag/revision cho cập nhật hồ sơ
    role            user_role_enum NOT NULL,                     -- Vai trò phân quyền chính

    -- Trạng thái & Lịch sử
    is_active       BOOLEAN DEFAULT true,                       -- Cờ trạng thái tài khoản
    last_login_at   TIMESTAMPTZ,                                -- Thời điểm đăng nhập thành công gần nhất
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo tài khoản
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    deleted_at      TIMESTAMPTZ,                                -- Thời điểm xóa mềm
    CONSTRAINT check_user_role_organization CHECK (
        (role = 'OrganizationUser' AND organization_id IS NOT NULL)
        OR (role IN ('PlatformAdmin', 'Trainee') AND organization_id IS NULL)
    ),
    CONSTRAINT check_trainee_username_required CHECK (role <> 'Trainee' OR username IS NOT NULL),
    CONSTRAINT check_user_auth_method CHECK (password_hash IS NOT NULL OR firebase_uid IS NOT NULL),
    CONSTRAINT check_user_username CHECK (
        username IS NULL OR (
            username = pg_catalog.lower(username)
            AND username ~ '^[a-z0-9._-]{3,30}$'
        )
    ),
    CONSTRAINT check_user_profile_revision CHECK (profile_revision_no > 0)
);

-- Short-lived state for a verified Google identity that has not completed
-- FET3D onboarding. It never grants a role or tenant by itself.
CREATE TABLE auth_google_onboarding_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid        VARCHAR(128) NOT NULL,
    email               VARCHAR(255) NOT NULL,
    onboarding_token_hash VARCHAR(128) NOT NULL UNIQUE,
    requested_role      user_role_enum,
    organization_draft  JSONB NOT NULL DEFAULT '{}',
    expires_at           TIMESTAMPTZ NOT NULL,
    completed_at        TIMESTAMPTZ,
    completed_user_id   UUID REFERENCES users(id) ON DELETE RESTRICT,
    completed_input_hash VARCHAR(128),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_google_onboarding_role CHECK (
        requested_role IS NULL OR requested_role IN ('OrganizationUser','Trainee')
    ),
    CONSTRAINT check_google_onboarding_dates CHECK (expires_at > created_at),
    CONSTRAINT check_google_onboarding_completion CHECK (
        completed_at IS NULL
        OR (
            completed_at >= created_at
            AND completed_user_id IS NOT NULL
            AND completed_input_hash IS NOT NULL
            AND completed_input_hash ~ '^[0-9a-fA-F]{64,128}$'
        )
    ),
    CONSTRAINT check_google_onboarding_incomplete CHECK (
        completed_at IS NOT NULL
        OR (completed_user_id IS NULL AND completed_input_hash IS NULL)
    )
);

CREATE TABLE user_devices (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh đăng ký thiết bị
    user_id        UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL, -- Tài khoản đã xác thực trên thiết bị
    device_uuid    VARCHAR(255) NOT NULL UNIQUE,                -- Mã định danh cài đặt Android duy nhất
    device_model   VARCHAR(255),                               -- Tên thiết bị Android (VD: "Samsung S23")
    os_version     VARCHAR(50),                                -- Phiên bản Android (VD: "Android 14")
    app_version    VARCHAR(50),                                -- Phiên bản ứng dụng Android/Unity khi đăng ký
    fcm_token      TEXT,                                       -- Registration token FCM có thể rotate; không phải credential
    fcm_token_updated_at TIMESTAMPTZ,                           -- Thời điểm token FCM được cập nhật gần nhất
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,       -- Người dùng còn cho phép push trên installation này
    last_seen_at   TIMESTAMPTZ DEFAULT NOW(),                  -- Lần cuối cùng thiết bị kết nối Server
    created_at     TIMESTAMPTZ DEFAULT NOW()                   -- Ngày ghi nhận thiết bị lần đầu
);

-- BE-managed authentication state. Access tokens remain short-lived/stateless;
-- refresh and reset credentials are stored only as hashes.
CREATE TABLE auth_refresh_tokens (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    family_id    UUID NOT NULL,
    token_hash   TEXT NOT NULL UNIQUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ NOT NULL,
    consumed_at  TIMESTAMPTZ,
    revoked_at   TIMESTAMPTZ,
    CONSTRAINT check_auth_refresh_token_dates CHECK (expires_at > created_at)
);

CREATE TABLE password_reset_tokens (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    token_hash   TEXT NOT NULL UNIQUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at   TIMESTAMPTZ NOT NULL,
    used_at      TIMESTAMPTZ,
    CONSTRAINT check_password_reset_token_dates CHECK (expires_at > created_at)
);

-- ------------------------------------------------------------------------------
-- GROUP 2: Building Management
-- ------------------------------------------------------------------------------

CREATE TABLE buildings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh tòa nhà
    organization_id UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức sở hữu tòa nhà (Multi-tenant)
    name            VARCHAR(255) NOT NULL,                      -- Tên tòa nhà (VD: "Tòa nhà Keangnam Tower A")
    building_type   VARCHAR(100),                               -- Loại hình công trình (Văn phòng, Chung cư, Bệnh viện)
    total_floors    INT DEFAULT 1,                              -- Tổng số tầng của tòa nhà
    address         TEXT,                                       -- Địa chỉ hành chính
    city            VARCHAR(255),                               -- Tỉnh/thành phố
    district        VARCHAR(255),                               -- Quận/huyện
    latitude        DECIMAL(10, 8),                              -- Vĩ độ nếu có
    longitude       DECIMAL(11, 8),                              -- Kinh độ nếu có
    geojson         JSONB,                                      -- Ranh giới khu đất nếu có
    is_active       BOOLEAN DEFAULT true,                       -- Cờ trạng thái hoạt động của tòa nhà
    created_by      UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser tạo hồ sơ tòa nhà
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm khởi tạo tòa nhà
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    deleted_at      TIMESTAMPTZ                                 -- Thời điểm xóa mềm tòa nhà
);

CREATE TABLE building_floors (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh tầng
    building_id      UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL, -- ID tòa nhà chứa tầng này
    organization_id  UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức sở hữu (Cô lập dữ liệu)
    floor_number     INT NOT NULL,                               -- Số thứ tự tầng (-1 = Hầm 1, 0 = Trệt, 1 = Tầng 1)
    floor_name       VARCHAR(100),                               -- Tên gợi nhớ tầng ("Tầng Trệt", "Tầng Kỹ Thuật")
    floor_plan_url   TEXT,                                       -- Preview/analytics 2D được pipeline sinh từ IFC
    area_sqm         DECIMAL(10, 2),                             -- Diện tích sàn (m2)
    elevation_meters DECIMAL(6, 2),                             -- Cao độ thực của tầng so với mặt đất (m)
    is_basement      BOOLEAN DEFAULT false,                     -- Cờ đánh dấu tầng hầm
    metadata         JSONB DEFAULT '{}',                        -- Thông tin mở rộng (loại tầng, ghi chú kỹ thuật)
    created_at       TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo
    updated_at       TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    UNIQUE (building_id, floor_number)
);

CREATE TABLE building_contacts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh liên hệ
    building_id  UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL, -- ID tòa nhà liên quan
    contact_name VARCHAR(255) NOT NULL,                      -- Họ tên người quản lý/đội trưởng PCCC
    contact_role VARCHAR(100),                               -- Chức vụ ("Trưởng ban quản lý", "Đội trưởng PCCC")
    phone        VARCHAR(50),                                -- Số điện thoại liên hệ khẩn cấp
    email        VARCHAR(255),                               -- Email liên hệ
    is_primary   BOOLEAN DEFAULT false,                      -- Cờ đánh dấu người liên hệ chính
    created_at   TIMESTAMPTZ DEFAULT NOW(),                  -- Ngày khởi tạo
    updated_at   TIMESTAMPTZ DEFAULT NOW()                   -- Ngày cập nhật gần nhất
);

-- ------------------------------------------------------------------------------
-- GROUP 3: BIM Pipeline
-- ------------------------------------------------------------------------------

CREATE TABLE revisions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh phiên bản xử lý BIM
    building_id    UUID REFERENCES buildings(id) NOT NULL,     -- ID tòa nhà gắn với phiên bản IFC
    uploaded_by    UUID REFERENCES users(id) NOT NULL,          -- OrganizationUser tải IFC
    version_label  VARCHAR(100),                               -- Nhãn phiên bản ("v1.0-Arch", "v2.1-Final")
    primary_type   file_type_enum NOT NULL DEFAULT 'IFC',      -- Luôn là IFC
    status         revision_status_enum NOT NULL DEFAULT 'Draft', -- Trạng thái tiến trình pipeline
    created_at     TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo phiên bản
    updated_at     TIMESTAMPTZ DEFAULT NOW()                   -- Thời điểm cập nhật gần nhất
);

CREATE TABLE source_documents (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh file gốc
    revision_id        UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL, -- ID revision chứa IFC
    floor_id           UUID REFERENCES building_floors(id) ON DELETE SET NULL, -- Tầng đại diện do pipeline suy ra từ IFC, nếu áp dụng
    uploaded_by        UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser tải file lên

    -- Metadata file & Lưu trữ
    original_filename  VARCHAR(500) NOT NULL,                      -- Tên file IFC gốc
    file_type          file_type_enum NOT NULL DEFAULT 'IFC',      -- Source duy nhất là IFC
    file_size_bytes    BIGINT,                                     -- Dung lượng file (Bytes)
    storage_url        TEXT NOT NULL,                              -- AWS S3 object URI/key; runtime dùng signed URL
    mime_type          VARCHAR(100),                               -- Định dạng MIME
    sha256_hash        VARCHAR(64),                                -- Mã checksum SHA256 chống trùng lặp

    -- Kiểm tra an toàn & bản quyền
    quarantine_status  quarantine_status_enum NOT NULL DEFAULT 'Pending', -- Trạng thái quét Virus/Mã độc
    quarantine_note    TEXT,                                       -- Ghi chú chi tiết từ dịch vụ antivirus
    usage_rights       TEXT,                                       -- Quy định quyền sử dụng tài liệu
    source_tool        VARCHAR(255),                               -- Toolchain xuất IFC được khai báo trong metadata
    created_at         TIMESTAMPTZ DEFAULT NOW()                   -- Ngày tải file lên
);

CREATE TABLE annotation_sets (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh bộ chú thích
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL, -- ID revision chứa đánh dấu
    version_number INT NOT NULL DEFAULT 1,                     -- Số thứ tự phiên bản chú thích (1, 2, 3...)
    data           JSONB NOT NULL DEFAULT '{}',                -- Tọa độ vòi chữa cháy, bình PCCC, lối thoát hiểm
    provenance     VARCHAR(50) DEFAULT 'manual',               -- Nguồn gốc ('manual' = con người, 'ai' = tự động)
    created_by     UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser tạo chú thích
    created_at     TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo
    UNIQUE (revision_id, version_number)
);

CREATE TABLE revision_processing_logs (
    job_id          UUID,                                       -- Job/attempt cụ thể; FK bổ sung sau khi tạo processing_jobs
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh log pipeline
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL, -- ID phiên bản IFC đang xử lý
    step           processing_step_enum NOT NULL,              -- Bước đang chạy (CleanGeometry, GenNavMesh, ExportGLB...)
    status         processing_step_status_enum NOT NULL,       -- Kết quả bước (Started, Success, Failed)
    message        TEXT,                                       -- Chi tiết lỗi hoặc log từ Python Worker
    duration_ms    INT,                                        -- Thời gian xử lý (milisecond)
    logged_at      TIMESTAMPTZ DEFAULT NOW()                   -- Thời gian ghi log
);

-- Một logical Scenario có thể có nhiều immutable version trên cùng geometry.
CREATE TABLE processing_jobs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id         UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL,
    source_document_id  UUID REFERENCES source_documents(id) ON DELETE RESTRICT NOT NULL,
    scenario_version_id UUID,
    kind                VARCHAR(40) NOT NULL, -- Geometry | PlaytestPackage | ReleasePackage | QA
    job_key             UUID NOT NULL,
    input_hash          VARCHAR(64) NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'Queued',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_processing_job_status CHECK (status IN ('Queued','Running','Succeeded','Failed','Cancelled')),
    CONSTRAINT check_processing_job_input_hash CHECK (input_hash ~ '^[0-9a-fA-F]{64}$')
);

ALTER TABLE revision_processing_logs
    ADD CONSTRAINT fk_revision_processing_logs_job
    FOREIGN KEY (job_id) REFERENCES processing_jobs(id) ON DELETE CASCADE;

-- Artifacts bất biến do Python/Blender/Unity build worker sinh ra.
CREATE TABLE revision_artifacts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id     UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL,
    job_id          UUID REFERENCES processing_jobs(id) ON DELETE RESTRICT,
    artifact_type   VARCHAR(80) NOT NULL, -- source_copy, facts, preview_glb, optimized_mesh, unity_package, manifest
    storage_key     TEXT NOT NULL,        -- AWS S3 object key, client chỉ nhận signed URL
    sha256_hash     VARCHAR(64) NOT NULL,
    metadata        JSONB NOT NULL DEFAULT '{}', -- units, coordinate_system, tool versions, QA summary
    is_runtime_ready BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (revision_id, artifact_type, sha256_hash)
);

CREATE TABLE bim_facts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id     UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL,
    ifc_global_id   VARCHAR(255) NOT NULL,
    entity_type     VARCHAR(100) NOT NULL,
    property_path   TEXT NOT NULL,
    value           JSONB,
    source_hash     VARCHAR(64) NOT NULL,
    quality_flags   JSONB NOT NULL DEFAULT '[]',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (revision_id, ifc_global_id, property_path)
);

CREATE TABLE revision_reviews (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh lượt duyệt mô hình
    revision_id       UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL, -- ID revision được duyệt
    scenario_version_id UUID NOT NULL,                              -- Scenario được ConfirmForTraining; FK thêm sau
    reviewed_by       UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser thực hiện review readiness
    annotation_set_id UUID REFERENCES annotation_sets(id),        -- Phiên bản annotation được duyệt tại thời điểm này
    action            review_action_enum NOT NULL,                -- ConfirmForTraining hoặc Rejected
    review_message    TEXT,                                       -- Nhận xét chuyên môn hoặc lý do yêu cầu sửa
    reviewed_at       TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm duyệt
    CONSTRAINT check_reject_message CHECK (
        action != 'Rejected' OR (review_message IS NOT NULL AND review_message != '')
    )
);

-- ------------------------------------------------------------------------------
-- GROUP 4: Release Management
-- ------------------------------------------------------------------------------

CREATE TABLE releases (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh bản phát hành
    revision_id       UUID REFERENCES revisions(id) NOT NULL,     -- Revision IFC bất biến được pin
    scenario_version_id UUID NOT NULL,                             -- FK được thêm sau khi scenario_versions được định nghĩa
    building_id       UUID REFERENCES buildings(id) NOT NULL,     -- ID tòa nhà phát hành
    organization_id   UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức quản lý bản phát hành

    -- Publish & Thu hồi
    published_by      UUID REFERENCES users(id),                  -- OrganizationUser thực hiện publish
    revoked_by        UUID REFERENCES users(id),                  -- ID người thu hồi bản phát hành (nếu có lỗi)
    status            release_status_enum NOT NULL DEFAULT 'Built', -- Trạng thái (Built, Published, Revoked...)
    safety_thresholds JSONB DEFAULT '{}',                         -- Ngưỡng readiness được pin cùng release
    revoked_reason    TEXT,                                       -- Lý do thu hồi/hủy bỏ
    published_at      TIMESTAMPTZ,                                -- Chỉ có giá trị sau khi publish
    updated_at        TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    UNIQUE (revision_id, scenario_version_id),
    CONSTRAINT check_release_published_at CHECK (
        status NOT IN ('Published', 'Superseded')
        OR (published_at IS NOT NULL AND published_by IS NOT NULL)
    ),
    CONSTRAINT check_revoke_fields CHECK (
        status != 'Revoked'
        OR (revoked_reason IS NOT NULL AND revoked_reason != '' AND revoked_by IS NOT NULL)
    )
);

CREATE TABLE release_packages (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh gói tài nguyên đã biên dịch
    release_id          UUID REFERENCES releases(id) ON DELETE CASCADE UNIQUE NOT NULL, -- ID bản phát hành tương ứng (1-1)
    manifest_url        TEXT NOT NULL,                              -- Đường dẫn file manifest JSON
    package_url         TEXT NOT NULL,                              -- Đường dẫn tải file Zip/AssetBundle 3D
    checksum_sha256     VARCHAR(64) NOT NULL,                       -- Mã checksum SHA256 để Client verify trước khi unpack
    protocol_version    VARCHAR(50) NOT NULL DEFAULT '1',            -- Protocol runtime dùng để đọc package
    manifest_schema_version VARCHAR(50) NOT NULL DEFAULT '1',      -- Schema manifest runtime hiểu được
    package_size_bytes  BIGINT,                                     -- Dung lượng gói tải xuống (Bytes)
    min_runtime_version VARCHAR(20) NOT NULL,                       -- Phiên bản app Unity tối thiểu cần để đọc gói này
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),           -- Ngày đóng gói hoàn tất
    CONSTRAINT check_release_package_checksum CHECK (checksum_sha256 ~ '^[0-9a-fA-F]{64}$'),
    CONSTRAINT check_release_package_size CHECK (package_size_bytes IS NULL OR package_size_bytes > 0)
);

CREATE TABLE release_qr_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh điểm quét QR
    building_id     UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL, -- QR ổn định cấp Building
    organization_id UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức quản lý (Multi-tenant isolation)
    floor_id        UUID REFERENCES building_floors(id),        -- ID tầng dán mã QR
    created_by      UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser tạo mã QR

    -- Cấu hình mã QR
    qr_hash         VARCHAR(255) UNIQUE NOT NULL,               -- Chuỗi mã hóa tĩnh duy nhất in trên QR
    label           VARCHAR(255),                               -- Tên vị trí dán ("Cột A1 - Sảnh Tầng 2")
    expires_at      TIMESTAMPTZ,                                -- Ngày hết hạn của mã QR
    is_active       BOOLEAN NOT NULL DEFAULT true,              -- QR còn resolve landing/list; entitlement quyết định mở session
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo
    CONSTRAINT check_release_qr_hash CHECK (NULLIF(BTRIM(qr_hash), '') IS NOT NULL)
);

-- ------------------------------------------------------------------------------
-- GROUP 5: Scenario & Training
-- ------------------------------------------------------------------------------

CREATE TABLE scenarios (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id     UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    name            VARCHAR(255) NOT NULL,
    created_by      UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_scenarios_building_org UNIQUE (id, building_id, organization_id)
);

CREATE TABLE scenario_versions (
    id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh kịch bản PCCC
    scenario_id                       UUID NOT NULL,                                -- Logical scenario; version mới không tạo lại geometry
    revision_id                       UUID REFERENCES revisions(id) NOT NULL,     -- Revision IFC hợp lệ dùng để author scenario
    building_id                       UUID REFERENCES buildings(id) NOT NULL,
    organization_id                   UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức tạo kịch bản
    version_number                    INT NOT NULL DEFAULT 1,                     -- Phiên bản kịch bản (1, 2, 3...)
    name                              VARCHAR(255) NOT NULL,                      -- Tên kịch bản ("Cháy phòng Server tầng 3")
    schema_version                    VARCHAR(50) NOT NULL DEFAULT '1',
    algorithm_version                 VARCHAR(50) NOT NULL DEFAULT '1',
    random_seed                       BIGINT NOT NULL DEFAULT 0,
    spawn_config                      JSONB NOT NULL DEFAULT '{}',
    goal_config                       JSONB NOT NULL DEFAULT '{}',

    -- Cấu hình mô phỏng đám cháy & NPC
    fire_source_config                JSONB DEFAULT '{}',                        -- Vị trí, thời điểm bắt đầu
    smoke_config                      JSONB NOT NULL DEFAULT '{}',
    wind_config                       JSONB NOT NULL DEFAULT '{}',                -- Mô hình game; không phải CFD đã kiểm chứng
    interaction_anchors               JSONB NOT NULL DEFAULT '[]',
    npc_config                        JSONB DEFAULT '{}',                        -- Archetypes, mật độ, hành vi
    blocked_elements                  JSONB DEFAULT '[]',                        -- Cửa/cầu thang bị chặn theo thời gian
    guidance_level                    VARCHAR(50) DEFAULT 'full',                -- Full | partial | none

    -- Ngưỡng an toàn & Cấu hình tính điểm
    safety_thresholds                 JSONB DEFAULT '{}',                        -- Ngưỡng chịu đựng khói/nhiệt độ của người chơi
    time_limit_seconds               INT NOT NULL,                               -- Thời lượng tối đa của bài, là nguồn chính trong snapshot
    routing_config                    JSONB NOT NULL DEFAULT '{}',
    scoring_config                    JSONB NOT NULL DEFAULT '{}',
    mode_policy                       JSONB NOT NULL DEFAULT '{}',
    scenario_hash                    VARCHAR(64) NOT NULL DEFAULT '',

    -- Readiness được ghi bằng revision_reviews.action = ConfirmForTraining và revision.status
    created_by                        UUID REFERENCES users(id) NOT NULL,        -- OrganizationUser tạo kịch bản
    created_at                        TIMESTAMPTZ DEFAULT NOW(),                 -- Thời điểm tạo
    updated_at                        TIMESTAMPTZ DEFAULT NOW(),                 -- Thời điểm cập nhật gần nhất
    UNIQUE (scenario_id, version_number),
    CONSTRAINT fk_scenario_versions_scenario
        FOREIGN KEY (scenario_id, building_id, organization_id)
        REFERENCES scenarios(id, building_id, organization_id) ON DELETE RESTRICT,
    CONSTRAINT check_scenario_hash CHECK (scenario_hash <> '')
);

-- Editor draft không được dùng làm release/session cho tới khi snapshot thành version.
CREATE TABLE scenario_drafts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scenario_id         UUID REFERENCES scenarios(id) ON DELETE CASCADE NOT NULL,
    revision_id         UUID REFERENCES revisions(id) ON DELETE RESTRICT NOT NULL,
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    building_id         UUID REFERENCES buildings(id) ON DELETE RESTRICT NOT NULL,
    draft_number        INT NOT NULL DEFAULT 1,
    state               JSONB NOT NULL DEFAULT '{}',
    source              VARCHAR(20) NOT NULL DEFAULT 'manual', -- manual | ai
    last_ai_request_id  UUID,
    created_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_scenario_draft_source CHECK (source IN ('manual','ai')),
    UNIQUE (scenario_id, draft_number),
    CONSTRAINT fk_scenario_drafts_scenario_scope
        FOREIGN KEY (scenario_id, building_id, organization_id)
        REFERENCES scenarios(id, building_id, organization_id) ON DELETE RESTRICT
);

-- Validation là bằng chứng độc lập cho geometry, scenario và package. Một run
-- không bị ghi đè; issue được giữ lại để publish/reconcile có thể truy vết.
CREATE TABLE validation_runs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    revision_id         UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL,
    scenario_version_id UUID REFERENCES scenario_versions(id) ON DELETE RESTRICT,
    processing_job_id   UUID REFERENCES processing_jobs(id) ON DELETE RESTRICT NOT NULL,
    artifact_id         UUID REFERENCES revision_artifacts(id) ON DELETE RESTRICT,
    release_id          UUID REFERENCES releases(id) ON DELETE RESTRICT,
    scope               VARCHAR(40) NOT NULL, -- Geometry | Scenario | PlaytestPackage | ReleasePackage
    validator_version   VARCHAR(100) NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'Queued',
    summary             JSONB NOT NULL DEFAULT '{}',
    issues_hash         VARCHAR(64) NOT NULL DEFAULT pg_catalog.encode(
        public.digest(pg_catalog.convert_to('[]', 'UTF8'), 'sha256'), 'hex'
    ),
    started_at          TIMESTAMPTZ,
    finished_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_validation_run_scope CHECK (
        scope IN ('Geometry','Scenario','PlaytestPackage','ReleasePackage')
    ),
    CONSTRAINT check_validation_run_status CHECK (
        status IN ('Queued','Running','Passed','Failed','Cancelled')
    ),
    CONSTRAINT check_validation_run_target CHECK (
        (scope = 'ReleasePackage' AND release_id IS NOT NULL)
        OR (scope <> 'ReleasePackage')
    ),
    CONSTRAINT check_validation_run_artifact CHECK (
        (scope IN ('PlaytestPackage','ReleasePackage') AND artifact_id IS NOT NULL)
        OR (scope NOT IN ('PlaytestPackage','ReleasePackage'))
    ),
    CONSTRAINT check_validation_run_scenario_target CHECK (
        (scope IN ('Scenario','PlaytestPackage','ReleasePackage') AND scenario_version_id IS NOT NULL)
        OR (scope NOT IN ('Scenario','PlaytestPackage','ReleasePackage'))
    ),
    CONSTRAINT check_validation_run_issues_hash CHECK (issues_hash ~ '^[0-9a-fA-F]{64}$'),
    CONSTRAINT uq_validation_run_attempt UNIQUE (processing_job_id, validator_version, scope)
);

CREATE TABLE validation_issues (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    validation_run_id   UUID REFERENCES validation_runs(id) ON DELETE CASCADE NOT NULL,
    revision_id         UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL,
    scenario_version_id UUID REFERENCES scenario_versions(id) ON DELETE RESTRICT,
    artifact_id         UUID REFERENCES revision_artifacts(id) ON DELETE RESTRICT,
    issue_code          VARCHAR(100) NOT NULL,
    severity            VARCHAR(20) NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'Open',
    message             TEXT NOT NULL,
    evidence            JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ,
    resolved_by         UUID REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT check_validation_issue_severity CHECK (severity IN ('Info','Warning','Error','Critical')),
    CONSTRAINT check_validation_issue_status CHECK (status IN ('Open','Acknowledged','Resolved','Waived'))
);

-- Review và release pin scenario đã sẵn sàng; FK được khai báo sau đối tượng đích.
ALTER TABLE revision_reviews
    ADD CONSTRAINT fk_revision_reviews_scenario_version
    FOREIGN KEY (scenario_version_id) REFERENCES scenario_versions(id) ON DELETE RESTRICT;

ALTER TABLE releases
    ADD CONSTRAINT fk_releases_scenario_version
    FOREIGN KEY (scenario_version_id) REFERENCES scenario_versions(id) ON DELETE RESTRICT;

ALTER TABLE processing_jobs
    ADD CONSTRAINT fk_processing_jobs_scenario_version
    FOREIGN KEY (scenario_version_id) REFERENCES scenario_versions(id) ON DELETE RESTRICT;

CREATE TABLE trainings (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh hoạt động tập huấn
    release_id          UUID REFERENCES releases(id) NOT NULL,      -- Release Built được pin trước publish
    scenario_version_id UUID REFERENCES scenario_versions(id) NOT NULL, -- Scenario được pin cho hoạt động
    organization_id     UUID REFERENCES organizations(id) NOT NULL, -- Organization sở hữu hoạt động
    name                VARCHAR(255) NOT NULL,                      -- Tên hoạt động tập huấn
    description         TEXT,                                       -- Mô tả chi tiết yêu cầu
    start_date          TIMESTAMPTZ,                                -- Ngày bắt đầu
    end_date            TIMESTAMPTZ,                                -- Ngày kết thúc
    status              training_status_enum NOT NULL DEFAULT 'Draft', -- Trạng thái vận hành
    mode                session_mode_enum NOT NULL DEFAULT 'Guided', -- Chế độ mặc định
    allowed_modes       TEXT[] DEFAULT ARRAY['Learn','Guided','Assessment'], -- Các chế độ Trainee được chọn
    max_attempts        INT DEFAULT 1,                              -- Số lần diễn tập tối đa cho mỗi học viên
    created_by          UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser tạo hoạt động
    created_at          TIMESTAMPTZ DEFAULT NOW(),                  -- Ngày tạo
    updated_at          TIMESTAMPTZ DEFAULT NOW(),                  -- Ngày cập nhật gần nhất
    CONSTRAINT check_training_dates CHECK (end_date IS NULL OR end_date > start_date),
    CONSTRAINT check_training_attempts CHECK (max_attempts > 0),
    CONSTRAINT check_training_modes CHECK (
        allowed_modes <@ ARRAY['Learn','Guided','Assessment']::TEXT[]
        AND mode::TEXT = ANY(allowed_modes)
    )
);

-- QR cấp Building có thể được tạo trước khi có Training; danh sách bài được
-- resolve động từ các Training/Release Published của Building.

-- ------------------------------------------------------------------------------
-- GROUP 6: Session & Results
-- ------------------------------------------------------------------------------

CREATE TABLE sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh phiên diễn tập
    training_id         UUID REFERENCES trainings(id) NOT NULL,    -- Hoạt động tập huấn được pin trực tiếp
    release_id          UUID REFERENCES releases(id) NOT NULL,     -- Release Published được pin để replay/reconcile
    scenario_version_id UUID REFERENCES scenario_versions(id) NOT NULL, -- ID kịch bản PCCC được tải vào phiên
    organization_id     UUID REFERENCES organizations(id) NOT NULL, -- Phạm vi analytics lấy từ training/release, không phải eligibility của Trainee

    -- Định danh người chơi & thiết bị
    trainee_user_id     UUID REFERENCES users(id) NOT NULL,        -- Tài khoản Trainee đã xác thực
    device_id           UUID REFERENCES user_devices(id) NOT NULL, -- ID thiết bị phần cứng đang chơi
    qr_code_id          UUID REFERENCES release_qr_codes(id) NOT NULL, -- QR active dùng để khởi chạy phiên

    -- Phiên bản ứng dụng tại thời điểm bắt đầu (phục vụ debug crash)
    app_version         VARCHAR(50),                               -- Phiên bản React Native/Expo app tại lúc bắt đầu session
    unity_version       VARCHAR(50),                               -- Phiên bản Unity runtime tại lúc bắt đầu session
    package_hash        VARCHAR(64) NOT NULL,                      -- Hash package đã verify ở bước preparation
    protocol_version    VARCHAR(50) NOT NULL DEFAULT '1',          -- Protocol đã verify trước khi start
    manifest_schema_version VARCHAR(50) NOT NULL DEFAULT '1',      -- Schema manifest đã verify trước khi start
    runtime_version     VARCHAR(50),                               -- Runtime Unity được client báo khi start
    prepare_idempotency_key VARCHAR(255) UNIQUE NOT NULL DEFAULT gen_random_uuid()::TEXT,
    start_idempotency_key VARCHAR(255) UNIQUE,                     -- Idempotency riêng cho online start

    -- Trạng thái phiên
    mode                session_mode_enum NOT NULL,                -- Chế độ (Learn | Guided | Assessment)
    status              session_status_enum NOT NULL DEFAULT 'Created', -- Trạng thái (Created, Running, Completed, Crashed...)
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),        -- Thời điểm tạo preparation record
    launch_granted_at   TIMESTAMPTZ,                               -- Chỉ cấp sau online start và entitlement check
    started_at          TIMESTAMPTZ,                               -- Chỉ ghi khi Mobile/Unity bắt đầu gameplay
    ended_at            TIMESTAMPTZ                                -- Thời điểm Kết thúc phiên
);

-- Playtest của OrganizationUser là aggregate riêng; không phải learner session.
CREATE TABLE playtest_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    building_id         UUID REFERENCES buildings(id) ON DELETE RESTRICT NOT NULL,
    revision_id         UUID REFERENCES revisions(id) ON DELETE RESTRICT NOT NULL,
    scenario_draft_id   UUID REFERENCES scenario_drafts(id) ON DELETE RESTRICT,
    scenario_version_id UUID REFERENCES scenario_versions(id) ON DELETE RESTRICT NOT NULL,
    service_entitlement_id UUID NOT NULL,
    created_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    package_hash        VARCHAR(64) NOT NULL,
    protocol_version    VARCHAR(50) NOT NULL DEFAULT '1',
    manifest_schema_version VARCHAR(50) NOT NULL DEFAULT '1',
    prepare_idempotency_key VARCHAR(255) UNIQUE,
    runtime_version     VARCHAR(50),
    start_idempotency_key VARCHAR(255) UNIQUE,
    status              VARCHAR(30) NOT NULL DEFAULT 'Created',
    completion_idempotency_key VARCHAR(255) UNIQUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at          TIMESTAMPTZ,
    ended_at            TIMESTAMPTZ,
    CONSTRAINT check_playtest_status CHECK (status IN ('Created','Running','Completed','Aborted','Failed'))
);

CREATE TABLE session_results (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh kết quả bài tập
    session_id            UUID REFERENCES sessions(id) ON DELETE CASCADE UNIQUE NOT NULL, -- ID phiên diễn tập (1-1)

    -- Chỉ số chấm điểm
    score                 DECIMAL(10, 2) DEFAULT 0,            -- Tổng điểm đạt được (0 - 100 điểm)
    time_taken_seconds    INT,                                 -- Tổng thời gian thoát nạn (giây)
    wrong_exits           INT DEFAULT 0,                       -- Số lần chạy nhầm vào cửa bị khóa
    hazard_exposure_score DECIMAL(10, 2) DEFAULT 0,            -- Mức độ bị tổn hại do dính khói/nhiệt
    total_distance_meters DECIMAL(8, 2) DEFAULT 0,             -- Quãng đường di chuyển (m)
    reached_exit          BOOLEAN DEFAULT false,               -- Cờ xác nhận đã thoát ra an toàn
    exit_point_id         VARCHAR(100),                        -- ID lối thoát hiểm cuối cùng đi ra

    -- Replay & Offline Sync
    path_traveled         JSONB DEFAULT '[]',                  -- Chuỗi tọa độ [{x,y,z,t}] phục vụ Replay 2D/3D
    client_started_at     TIMESTAMPTZ,                         -- Giờ bắt đầu thực tế ở Mobile (chống lệch giờ Offline)
    client_ended_at       TIMESTAMPTZ,                         -- Giờ kết thúc thực tế ở Mobile
     is_synced             BOOLEAN DEFAULT false,               -- Cờ xác nhận đã đồng bộ lên Cloud chưa
     synced_at             TIMESTAMPTZ,                         -- Thời điểm Server nhận dữ liệu sync
     result_idempotency_key VARCHAR(255) UNIQUE,                 -- Khóa ổn định cho retry kết quả offline
     result_hash           VARCHAR(64),                          -- Hash canonical của payload kết quả
     result_snapshot       JSONB NOT NULL DEFAULT '{}',          -- Payload kết quả đã được backend tiếp nhận
     created_at            TIMESTAMPTZ DEFAULT NOW(),           -- Ngày tạo kết quả
     updated_at            TIMESTAMPTZ DEFAULT NOW(),            -- Ngày cập nhật kết quả
     CONSTRAINT check_session_result_hash CHECK (
         result_hash IS NULL OR result_hash ~ '^[0-9a-fA-F]{64}$'
     ),
     CONSTRAINT check_session_result_idempotency_key CHECK (
         result_idempotency_key IS NULL OR NULLIF(pg_catalog.btrim(result_idempotency_key), '') IS NOT NULL
     )
);

CREATE TABLE session_checkpoints (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh điểm lưu (Auto-save)
    session_id               UUID REFERENCES sessions(id) ON DELETE CASCADE NOT NULL, -- ID phiên diễn tập
    sequence_number          INT NOT NULL,                     -- Số thứ tự checkpoint (1, 2, 3...)

    -- Snapshot sinh tồn & thế giới (Crash Recovery)
    player_transform         JSONB NOT NULL,                   -- Tọa độ (x,y,z) và góc quay (rotation)
    player_status            JSONB DEFAULT '{}',               -- Máu, Oxy còn lại, chỉ số khói độc đã hít
    world_interactive_states JSONB DEFAULT '{}',               -- Trạng thái cửa đã mở, bình chữa cháy đã xịt
    hazard_time_step         INT NOT NULL,                     -- Step thời gian lây lan đám cháy
    npc_states               JSONB DEFAULT '[]',               -- Tọa độ và trạng thái tâm lý đám đông NPC
    active_objectives        JSONB DEFAULT '[]',               -- Danh sách nhiệm vụ phụ đang làm dở

    -- Verification
    release_hash             VARCHAR(64),                      -- Hash gói bản đồ để verify khi Resume
    scenario_hash            VARCHAR(64),                      -- Hash kịch bản để verify khi Resume
    created_at               TIMESTAMPTZ DEFAULT NOW(),        -- Thời điểm tự động lưu checkpoint
    UNIQUE (session_id, sequence_number)
);

-- Artifact phân tích sau mỗi phiên: heatmap, replay path, so sánh A*
CREATE TABLE debrief_artifacts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh artifact phân tích
    session_id          UUID REFERENCES sessions(id) ON DELETE CASCADE UNIQUE NOT NULL, -- ID phiên diễn tập (1-1)
    trajectory_heatmap  JSONB DEFAULT '{}',    -- {floor_id: [{x,y,intensity}]} - heatmap đường di chuyển
    optimal_path        JSONB DEFAULT '[]',    -- Tuyến A* tham chiếu [{x,y,z,floor_id}]
    wrong_decisions     JSONB DEFAULT '[]',    -- [{type, timestamp, location, penalty}]
    hazard_timeline     JSONB DEFAULT '[]',    -- Hazard exposure theo thời gian [{t, level, zone}]
    npc_summary         JSONB DEFAULT '{}',    -- Tổng kết NPC: tỷ lệ được cứu, archetype stats
    is_visible_to_trainee BOOLEAN DEFAULT false, -- OrganizationUser cho phép Trainee xem debrief cá nhân
    generated_at        TIMESTAMPTZ DEFAULT NOW() -- Thời điểm backend tính toán xong artifact
);

CREATE TABLE session_events (
    id          UUID PRIMARY KEY,                            -- Stable client event id; retry giữ nguyên id
    session_id  UUID REFERENCES sessions(id) ON DELETE CASCADE NOT NULL, -- ID phiên diễn tập
    sequence_number BIGINT NOT NULL,                        -- Thứ tự tăng dần trong một session
    schema_version VARCHAR(50) NOT NULL,                     -- Schema của event_data
    event_type  VARCHAR(100) NOT NULL,                      -- Loại sự kiện ('PICKUP_EXTINGUISHER', 'ENTER_SMOKE_ZONE'...)
    event_data  JSONB DEFAULT '{}',                         -- Dữ liệu chi tiết dạng JSON
    recorded_at TIMESTAMPTZ NOT NULL,                       -- Mốc thời gian trên thiết bị
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),         -- Mốc backend nhận event
    UNIQUE (session_id, sequence_number)
);

-- ------------------------------------------------------------------------------
-- GROUP 7: Audit & Security
-- ------------------------------------------------------------------------------

CREATE TABLE audit_logs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh nhật ký hệ thống
    user_id       UUID REFERENCES users(id) ON DELETE RESTRICT, -- ID tài khoản thực hiện thao tác
    organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    correlation_id UUID NOT NULL DEFAULT gen_random_uuid(),   -- Correlates one application operation
    actor_type    VARCHAR(20) NOT NULL DEFAULT 'User',         -- User | Worker | System
    action        audit_action_enum NOT NULL,                 -- Hành động (Upload, Approve, Reject, Delete...)
    target_entity VARCHAR(100) NOT NULL,                      -- Bảng/Thực thể bị tác động ('revisions', 'users'...)
    target_id     UUID,                                       -- ID của bản ghi bị tác động
    old_values    JSONB,                                      -- Dữ liệu cũ trước khi sửa
    new_values    JSONB,                                      -- Dữ liệu mới sau khi sửa
    ip_address    INET,                                       -- Địa chỉ IP người thực hiện
    user_agent    TEXT,                                       -- Thông tin thiết bị/trình duyệt
    created_at    TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm ghi nhật ký
    CONSTRAINT check_audit_actor_type CHECK (actor_type IN ('User','Worker','System'))
);

-- Durable application-command receipt for Learn and other application-service
-- gates whose result must be replayed without creating a second audit/outbox
-- effect. It stores only the canonical input hash and committed result, never
-- passwords, bearer tokens or provider secrets.
CREATE TABLE application_command_receipts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id       UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    operation_name      VARCHAR(100) NOT NULL,
    idempotency_key     VARCHAR(255) NOT NULL,
    input_hash          VARCHAR(128) NOT NULL,
    result_status       VARCHAR(30) NOT NULL,
    result_payload      JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (actor_user_id, operation_name, idempotency_key),
    CONSTRAINT check_command_receipt_key CHECK (NULLIF(pg_catalog.btrim(idempotency_key), '') IS NOT NULL),
    CONSTRAINT check_command_receipt_hash CHECK (input_hash ~ '^[0-9a-fA-F]{64,128}$'),
    CONSTRAINT check_command_receipt_status CHECK (result_status IN ('Succeeded','Rejected'))
);

-- ------------------------------------------------------------------------------
-- GROUP 8: Commercial Entitlement, Payment, AI Usage, Feedback & Support
-- ------------------------------------------------------------------------------

CREATE TABLE service_packages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Gói dịch vụ thương mại
    code            VARCHAR(50) UNIQUE NOT NULL,                -- Mã ổn định dùng trong quotation
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    unit_price      DECIMAL(14, 2) NOT NULL,
    currency        VARCHAR(3) NOT NULL DEFAULT 'VND',
    duration_months INT,
    features        JSONB NOT NULL DEFAULT '{}',
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_by      UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL, -- PlatformAdmin tạo/quản lý
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_service_package_price CHECK (unit_price >= 0),
    CONSTRAINT check_service_package_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT check_service_package_duration CHECK (duration_months IS NULL OR duration_months > 0)
);

-- Discount rules are catalog data. The applied rule and amount are copied into
-- the quotation snapshot; changing a rule never changes an issued quotation.
CREATE TABLE service_package_discount_rules (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_package_id  UUID REFERENCES service_packages(id) ON DELETE RESTRICT,
    code                VARCHAR(80) UNIQUE NOT NULL,
    discount_kind       VARCHAR(20) NOT NULL, -- Percent | Fixed
    discount_value      DECIMAL(14,2) NOT NULL,
    discount_currency   VARCHAR(3),                       -- Required for Fixed; NULL for Percent
    minimum_buildings   INT NOT NULL DEFAULT 1,
    minimum_duration_months INT,
    valid_from          TIMESTAMPTZ NOT NULL,
    valid_until         TIMESTAMPTZ,
    is_active            BOOLEAN NOT NULL DEFAULT true,
    created_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_discount_kind CHECK (discount_kind IN ('Percent','Fixed')),
    CONSTRAINT check_discount_value CHECK (discount_value >= 0),
    CONSTRAINT check_discount_percent CHECK (discount_kind <> 'Percent' OR discount_value <= 100),
    CONSTRAINT check_discount_currency CHECK (
        (discount_kind = 'Fixed' AND discount_currency IS NOT NULL
            AND discount_currency ~ '^[A-Z]{3}$')
        OR (discount_kind = 'Percent' AND discount_currency IS NULL)
    ),
    CONSTRAINT check_discount_buildings CHECK (minimum_buildings > 0),
    CONSTRAINT check_discount_duration CHECK (minimum_duration_months IS NULL OR minimum_duration_months > 0),
    CONSTRAINT check_discount_dates CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TABLE quotations (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id    UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    billing_purpose    VARCHAR(30) NOT NULL DEFAULT 'BuildingService', -- BuildingService | AIUsage
    requested_by       UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL, -- OrganizationUser yêu cầu
    issued_by          UUID REFERENCES users(id) ON DELETE RESTRICT,          -- PlatformAdmin phát hành
    quotation_number   VARCHAR(50) UNIQUE NOT NULL,
    status             quotation_status_enum NOT NULL DEFAULT 'Draft',
    quantity           INT NOT NULL DEFAULT 1,                  -- Summary count; BuildingService source is quotation_building_items
    unit_price         DECIMAL(14, 2) NOT NULL,                 -- Summary only; line prices remain authoritative for multi-building quotes
    subtotal_amount    DECIMAL(14, 2) NOT NULL,
    tax_amount         DECIMAL(14, 2) NOT NULL DEFAULT 0,
    discount_amount    DECIMAL(14, 2) NOT NULL DEFAULT 0,
    total_amount       DECIMAL(14, 2) NOT NULL,
    currency           VARCHAR(3) NOT NULL DEFAULT 'VND',
    discount_rule_id   UUID REFERENCES service_package_discount_rules(id) ON DELETE RESTRICT,
    discount_snapshot  JSONB NOT NULL DEFAULT '{}',
    price_snapshot     JSONB NOT NULL DEFAULT '{}',                -- Đơn giá/thuế/chiết khấu tại thời điểm phát hành
    terms_snapshot     JSONB NOT NULL DEFAULT '{}',                -- Điều khoản đã được chấp nhận
    valid_until        TIMESTAMPTZ NOT NULL,
    issued_at          TIMESTAMPTZ,
    accepted_at        TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_quotation_quantity CHECK (quantity > 0),
    CONSTRAINT check_quotation_billing_purpose CHECK (billing_purpose IN ('BuildingService','AIUsage')),
    CONSTRAINT check_quotation_amounts CHECK (
        unit_price >= 0
        AND subtotal_amount >= 0
        AND tax_amount >= 0
        AND discount_amount >= 0
        AND total_amount = subtotal_amount + tax_amount - discount_amount
        AND total_amount >= 0
    ),
    CONSTRAINT check_quotation_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT check_quotation_issued CHECK (
        status IN ('Draft','Cancelled') OR (issued_by IS NOT NULL AND issued_at IS NOT NULL)
    ),
    CONSTRAINT check_quotation_accepted CHECK (
        (status NOT IN ('Draft','Issued') OR accepted_at IS NULL)
        AND (status <> 'Accepted' OR accepted_at IS NOT NULL)
    )
);

CREATE TABLE payos_payment_requests (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id        UUID REFERENCES quotations(id) ON DELETE RESTRICT NOT NULL,
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    requested_by        UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    idempotency_key     VARCHAR(255) UNIQUE NOT NULL DEFAULT gen_random_uuid()::TEXT,
    order_code          BIGINT UNIQUE NOT NULL,                     -- PayOS orderCode expected
    expected_amount     DECIMAL(14, 2) NOT NULL,                    -- Amount expected from quotation
    expected_currency   VARCHAR(3) NOT NULL DEFAULT 'VND',          -- Currency expected from quotation
    checkout_url        TEXT NOT NULL,
    return_url          TEXT NOT NULL,                              -- Chỉ điều hướng UI; không xác nhận thanh toán
    cancel_url          TEXT NOT NULL,
    status              payment_request_status_enum NOT NULL DEFAULT 'Pending',
    paid_transaction_id UUID UNIQUE,                               -- FK ghép được thêm sau payment_transactions
    expires_at          TIMESTAMPTZ,
    paid_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_payos_order_code CHECK (order_code > 0),
    CONSTRAINT check_payos_expected_amount CHECK (expected_amount > 0),
    CONSTRAINT check_payos_expected_currency CHECK (expected_currency ~ '^[A-Z]{3}$'),
    CONSTRAINT check_payos_paid_fields CHECK (
        (status = 'Paid' AND paid_transaction_id IS NOT NULL AND paid_at IS NOT NULL)
        OR (status != 'Paid' AND paid_transaction_id IS NULL AND paid_at IS NULL)
    )
);

CREATE TABLE payment_transactions (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_request_id         UUID REFERENCES payos_payment_requests(id) ON DELETE RESTRICT NOT NULL,
    webhook_event_id           VARCHAR(255) UNIQUE NOT NULL, -- Khóa idempotency cho mỗi webhook PayOS
    provider_transaction_id    VARCHAR(255) UNIQUE,
    received_order_code        BIGINT NOT NULL,
    received_amount            DECIMAL(14, 2) NOT NULL,
    received_currency          VARCHAR(3) NOT NULL,
    signature_verified         BOOLEAN NOT NULL DEFAULT false,
    status                     payment_transaction_status_enum NOT NULL DEFAULT 'Received',
    raw_payload                JSONB NOT NULL,
    rejection_reason           TEXT,
    received_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    signature_verified_at      TIMESTAMPTZ,
    processed_at               TIMESTAMPTZ,
    UNIQUE (id, payment_request_id),
    CONSTRAINT check_payment_transaction_amount CHECK (received_amount > 0),
    CONSTRAINT check_payment_transaction_currency CHECK (received_currency ~ '^[A-Z]{3}$'),
    CONSTRAINT check_payment_transaction_event_id CHECK (NULLIF(BTRIM(webhook_event_id), '') IS NOT NULL),
    CONSTRAINT check_payment_transaction_state_fields CHECK (
        (
            status = 'Received'
            AND NOT signature_verified
            AND signature_verified_at IS NULL
            AND processed_at IS NULL
            AND rejection_reason IS NULL
        )
        OR (
            status = 'Verified'
            AND signature_verified
            AND signature_verified_at IS NOT NULL
            AND processed_at IS NULL
            AND rejection_reason IS NULL
        )
        OR (
            status = 'Applied'
            AND signature_verified
            AND signature_verified_at IS NOT NULL
            AND processed_at IS NOT NULL
            AND rejection_reason IS NULL
        )
        OR (
            status = 'Rejected'
            AND signature_verified
            AND signature_verified_at IS NOT NULL
            AND processed_at IS NOT NULL
            AND NULLIF(BTRIM(rejection_reason), '') IS NOT NULL
        )
    )
);

ALTER TABLE payos_payment_requests
    ADD CONSTRAINT fk_payos_paid_transaction_for_request
    FOREIGN KEY (paid_transaction_id, id)
    REFERENCES payment_transactions(id, payment_request_id) ON DELETE RESTRICT;

CREATE TABLE invoice_metadata (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id UUID REFERENCES payment_transactions(id) ON DELETE RESTRICT UNIQUE NOT NULL,
    quotation_id           UUID REFERENCES quotations(id) ON DELETE RESTRICT NOT NULL,
    organization_id        UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    invoice_number         VARCHAR(100) UNIQUE,
    legal_name             TEXT NOT NULL,
    tax_code               VARCHAR(50),
    billing_address        TEXT,
    subtotal_amount        DECIMAL(14, 2) NOT NULL,
    tax_amount             DECIMAL(14, 2) NOT NULL DEFAULT 0,
    total_amount           DECIMAL(14, 2) NOT NULL,
    currency               VARCHAR(3) NOT NULL DEFAULT 'VND',
    issued_at              TIMESTAMPTZ,
    invoice_url            TEXT,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_invoice_amounts CHECK (
        subtotal_amount >= 0
        AND tax_amount >= 0
        AND total_amount = subtotal_amount + tax_amount
    ),
    CONSTRAINT check_invoice_currency CHECK (currency ~ '^[A-Z]{3}$')
);

-- Quyền dịch vụ theo từng Building. Kỳ này độc lập với kỳ đối soát AI của tổ chức.
CREATE TABLE service_entitlements (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    building_id         UUID REFERENCES buildings(id) ON DELETE RESTRICT NOT NULL,
    service_package_id  UUID REFERENCES service_packages(id) ON DELETE RESTRICT NOT NULL,
    quotation_id        UUID REFERENCES quotations(id) ON DELETE RESTRICT,
    quotation_item_id   UUID,
    payment_transaction_id UUID REFERENCES payment_transactions(id) ON DELETE RESTRICT,
    provisioning_key    VARCHAR(255) NOT NULL UNIQUE,               -- Ổn định theo quotation/payment, không random mỗi retry
    status              VARCHAR(30) NOT NULL DEFAULT 'Active', -- Trial | Active | Expired | Suspended | Cancelled
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NOT NULL,
    price_snapshot      JSONB NOT NULL DEFAULT '{}',
    terms_snapshot      JSONB NOT NULL DEFAULT '{}',
    playtest_units_granted INT NOT NULL DEFAULT 0,
    playtest_units_used INT NOT NULL DEFAULT 0,
    created_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_service_entitlement_dates CHECK (ends_at > starts_at),
    CONSTRAINT check_service_entitlement_status CHECK (status IN ('Trial','Active','Expired','Suspended','Cancelled')),
    CONSTRAINT check_active_entitlement_payment_source CHECK (
        status <> 'Active' OR (
            quotation_id IS NOT NULL
            AND quotation_item_id IS NOT NULL
            AND payment_transaction_id IS NOT NULL
        )
    ),
    CONSTRAINT check_playtest_entitlement_units CHECK (
        playtest_units_granted >= 0 AND playtest_units_used >= 0 AND playtest_units_used <= playtest_units_granted
    ),
    UNIQUE (building_id, starts_at),
    UNIQUE (quotation_item_id, payment_transaction_id)
);

CREATE TABLE organization_notifications (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id       UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    recipient_user_id     UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    building_id           UUID REFERENCES buildings(id) ON DELETE RESTRICT NOT NULL,
    entitlement_id        UUID REFERENCES service_entitlements(id) ON DELETE RESTRICT NOT NULL,
    notification_type     VARCHAR(50) NOT NULL, -- BuildingServiceExpiring
    title                 TEXT NOT NULL,
    body                  TEXT NOT NULL,
    reference_ends_at     TIMESTAMPTZ NOT NULL,
    idempotency_key       VARCHAR(255) NOT NULL UNIQUE,
    read_at               TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_org_notification_type CHECK (notification_type IN ('BuildingServiceExpiring'))
);

CREATE TABLE notification_deliveries (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id       UUID REFERENCES organization_notifications(id) ON DELETE RESTRICT NOT NULL,
    channel               VARCHAR(20) NOT NULL, -- Web | Email
    status                VARCHAR(20) NOT NULL DEFAULT 'Pending', -- Pending | Sent | Failed
    attempts              INT NOT NULL DEFAULT 0,
    provider_message_id   TEXT,
    last_error            TEXT,
    sent_at               TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (notification_id, channel),
    CONSTRAINT check_notification_channel CHECK (channel IN ('Web','Email')),
    CONSTRAINT check_notification_delivery_status CHECK (status IN ('Pending','Sent','Failed')),
    CONSTRAINT check_notification_attempts CHECK (attempts >= 0)
);

ALTER TABLE playtest_sessions
    ADD CONSTRAINT fk_playtest_sessions_service_entitlement
    FOREIGN KEY (service_entitlement_id) REFERENCES service_entitlements(id) ON DELETE RESTRICT;

-- Payment đã Applied nhưng cấp entitlement có thể lỗi ở bước sau. Mỗi record
-- là điểm retry/reconcile bất biến cho một payment + quotation line, không phải
-- một giao dịch mới; một payment có thể có nhiều record.
CREATE TABLE payment_provisioning_records (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id UUID REFERENCES payment_transactions(id) ON DELETE RESTRICT NOT NULL,
    quotation_id          UUID REFERENCES quotations(id) ON DELETE RESTRICT NOT NULL,
    quotation_item_id     UUID NOT NULL,
    organization_id       UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    provisioning_key      VARCHAR(255) UNIQUE NOT NULL,
    status                VARCHAR(30) NOT NULL DEFAULT 'Pending',
    attempts              INT NOT NULL DEFAULT 0,
    last_error            TEXT,
    provisioned_at        TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_payment_provisioning_status CHECK (status IN ('Pending','Succeeded','NeedsReconcile')),
    CONSTRAINT check_payment_provisioning_attempts CHECK (attempts >= 0),
    UNIQUE (payment_transaction_id, quotation_item_id)
);

-- Kỳ đối soát AI của tổ chức; không suy ra từ kỳ service của Building.
CREATE TABLE ai_billing_periods (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    period_start        TIMESTAMPTZ NOT NULL,
    period_end          TIMESTAMPTZ NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'Open', -- Open | Closed | Invoiced | Paid
    settlement_quotation_id UUID REFERENCES quotations(id) ON DELETE RESTRICT UNIQUE,
    settlement_payment_transaction_id UUID REFERENCES payment_transactions(id) ON DELETE RESTRICT UNIQUE,
    unit_price_snapshot JSONB NOT NULL DEFAULT '{}',
    overage_units       INT NOT NULL DEFAULT 0,
    overage_amount      DECIMAL(14, 2) NOT NULL DEFAULT 0,
    currency            VARCHAR(3) NOT NULL DEFAULT 'VND',
    closed_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ai_period_dates CHECK (period_end > period_start),
    CONSTRAINT check_ai_period_status CHECK (status IN ('Open','Closed','Invoiced','Paid')),
    CONSTRAINT check_ai_period_amounts CHECK (overage_units >= 0 AND overage_amount >= 0 AND currency ~ '^[A-Z]{3}$'),
    UNIQUE (organization_id, period_start, period_end)
);

CREATE TABLE ai_quota_grants (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    building_id         UUID REFERENCES buildings(id) ON DELETE RESTRICT,
    trainee_user_id     UUID REFERENCES users(id) ON DELETE RESTRICT,
    audience            VARCHAR(30) NOT NULL, -- organization | trainee
    quota_kind          VARCHAR(30) NOT NULL, -- free | daily | trial
    policy_version_id   UUID,
    units_granted       INT NOT NULL,
    units_used          INT NOT NULL DEFAULT 0,
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NOT NULL,
    configured_by       UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ai_quota_audience CHECK (audience IN ('organization','trainee')),
    CONSTRAINT check_ai_quota_audience_scope CHECK (
        (audience = 'organization' AND organization_id IS NOT NULL AND trainee_user_id IS NULL)
        OR (audience = 'trainee' AND trainee_user_id IS NOT NULL AND organization_id IS NULL AND building_id IS NULL)
    ),
    CONSTRAINT check_ai_quota_kind CHECK (quota_kind IN ('free','daily','trial')),
    CONSTRAINT check_ai_quota_numbers CHECK (units_granted >= 0 AND units_used >= 0 AND units_used <= units_granted),
    CONSTRAINT check_ai_quota_dates CHECK (ends_at > starts_at)
);

-- Chính sách quota/đơn giá có version; grant và usage phải giữ lại version đã áp dụng.
CREATE TABLE ai_policy_versions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID REFERENCES organizations(id) ON DELETE CASCADE,
    audience            VARCHAR(30) NOT NULL, -- organization | trainee | common
    policy_kind         VARCHAR(30) NOT NULL, -- quota | pricing
    version_label       VARCHAR(100) NOT NULL,
    policy_snapshot     JSONB NOT NULL,
    effective_from      TIMESTAMPTZ NOT NULL,
    effective_until     TIMESTAMPTZ,
    created_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ai_policy_audience CHECK (audience IN ('organization','trainee','common')),
    CONSTRAINT check_ai_policy_kind CHECK (policy_kind IN ('quota','pricing')),
    CONSTRAINT check_ai_policy_dates CHECK (effective_until IS NULL OR effective_until > effective_from),
    UNIQUE (organization_id, audience, policy_kind, version_label)
);

CREATE TABLE ai_overage_consents (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    accepted_by         UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    accepted_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    terms_snapshot      JSONB NOT NULL,
    scope               JSONB NOT NULL DEFAULT '{}',
    UNIQUE (organization_id, accepted_by, accepted_at)
);

-- Bản ghi bền vững của một yêu cầu AI; ledger/reservation chỉ là các lớp tài chính
-- tham chiếu request này, không thay thế trạng thái xử lý và kết quả kỹ thuật.
CREATE TABLE ai_requests (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key     VARCHAR(255) NOT NULL UNIQUE,
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    building_id         UUID REFERENCES buildings(id) ON DELETE RESTRICT,
    user_id             UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    audience            VARCHAR(30) NOT NULL,
    request_type        VARCHAR(80) NOT NULL,
    source_scope        JSONB NOT NULL DEFAULT '{}',
    policy_version_id   UUID REFERENCES ai_policy_versions(id) ON DELETE RESTRICT NOT NULL,
    input_hash          VARCHAR(64) NOT NULL,
    input_reference     TEXT,
    status              VARCHAR(30) NOT NULL DEFAULT 'Accepted', -- Accepted | Processing | Succeeded | Failed | NeedsReconcile | Rejected
    result_type         VARCHAR(40), -- KnowledgeAnswer | ScenarioDraft
    result_reference    TEXT,
    response_snapshot   JSONB,
    result_hash         VARCHAR(64),
    citations           JSONB NOT NULL DEFAULT '[]',
    model_provider      VARCHAR(80),
    model_version       VARCHAR(120),
    technical_usage     JSONB NOT NULL DEFAULT '{}',
    failure_code        VARCHAR(80),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ,
    last_reconciled_at  TIMESTAMPTZ,
    CONSTRAINT check_ai_request_audience CHECK (audience IN ('organization','trainee')),
    CONSTRAINT check_ai_request_status CHECK (status IN ('Accepted','Processing','Succeeded','Failed','NeedsReconcile','Rejected')),
    CONSTRAINT check_ai_request_result_type CHECK (result_type IS NULL OR result_type IN ('KnowledgeAnswer','ScenarioDraft','InsufficientEvidence','RejectedBySafetyGate')),
    CONSTRAINT check_ai_request_input_hash CHECK (input_hash ~ '^[0-9a-fA-F]{64}$'),
    CONSTRAINT check_ai_request_result_hash CHECK (result_hash IS NULL OR result_hash ~ '^[0-9a-fA-F]{64}$'),
    CONSTRAINT check_ai_request_scope CHECK (
        (audience = 'organization' AND organization_id IS NOT NULL)
        OR (audience = 'trainee' AND organization_id IS NULL AND building_id IS NULL)
    )
);

CREATE TABLE ai_usage_ledger (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID REFERENCES ai_requests(id) ON DELETE RESTRICT UNIQUE NOT NULL, -- chống tính lượt/charge trùng khi retry
    idempotency_key     VARCHAR(255) UNIQUE NOT NULL,
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    building_id         UUID REFERENCES buildings(id) ON DELETE RESTRICT,
    user_id             UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    session_id          UUID REFERENCES sessions(id) ON DELETE SET NULL,
    audience            VARCHAR(30) NOT NULL, -- organization | trainee
    request_type        VARCHAR(80) NOT NULL, -- qa | scenario_draft | learn | debrief
    policy_version_id   UUID,
    units               INT NOT NULL DEFAULT 1,
    overage_consent_id  UUID REFERENCES ai_overage_consents(id) ON DELETE RESTRICT,
    billable            BOOLEAN NOT NULL DEFAULT false,
    unit_price_snapshot JSONB NOT NULL DEFAULT '{}',
    billing_period_id   UUID REFERENCES ai_billing_periods(id) ON DELETE RESTRICT,
    status              VARCHAR(30) NOT NULL DEFAULT 'Reserved', -- Reserved | Recorded | Failed | Reversed | NeedsReconcile
    source_scope        JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ai_usage_audience CHECK (audience IN ('organization','trainee')),
    CONSTRAINT check_ai_usage_audience_scope CHECK (
        (audience = 'organization' AND organization_id IS NOT NULL)
        OR (audience = 'trainee' AND organization_id IS NULL AND building_id IS NULL)
    ),
    CONSTRAINT check_ai_usage_overage_consent CHECK (billable = false OR overage_consent_id IS NOT NULL),
    CONSTRAINT check_ai_usage_trainee_not_billable CHECK (audience = 'organization' OR billable = false),
    CONSTRAINT check_ai_usage_units CHECK (units > 0),
    CONSTRAINT check_ai_usage_status CHECK (status IN ('Reserved','Recorded','Failed','Reversed','NeedsReconcile'))
);

CREATE TABLE ai_billing_period_items (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    billing_period_id   UUID REFERENCES ai_billing_periods(id) ON DELETE RESTRICT NOT NULL,
    usage_ledger_id     UUID REFERENCES ai_usage_ledger(id) ON DELETE RESTRICT NOT NULL,
    units               INT NOT NULL,
    unit_price_snapshot JSONB NOT NULL,
    amount              DECIMAL(14,2) NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'Included', -- Included | Removed | Adjusted
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ai_period_item_units CHECK (units > 0),
    CONSTRAINT check_ai_period_item_amount CHECK (amount >= 0),
    UNIQUE (billing_period_id, usage_ledger_id)
);

CREATE TABLE ai_billing_adjustments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    billing_period_id   UUID REFERENCES ai_billing_periods(id) ON DELETE RESTRICT NOT NULL,
    usage_ledger_id     UUID REFERENCES ai_usage_ledger(id) ON DELETE RESTRICT,
    original_item_id    UUID REFERENCES ai_billing_period_items(id) ON DELETE RESTRICT,
    adjustment_type     VARCHAR(30) NOT NULL, -- Credit | Debit | LateUsage | Correction
    units               INT NOT NULL DEFAULT 0,
    amount              DECIMAL(14,2) NOT NULL,
    reason              TEXT NOT NULL,
    created_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ai_adjustment_type CHECK (adjustment_type IN ('Credit','Debit','LateUsage','Correction')),
    CONSTRAINT check_ai_adjustment_amount CHECK (amount <> 0 OR units <> 0)
);

-- One service line identifies one concrete Building. Header quantity/unit_price
-- are summary snapshots only; lines are the source for BuildingService scope.
CREATE TABLE quotation_building_items (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id          UUID REFERENCES quotations(id) ON DELETE RESTRICT NOT NULL,
    building_id           UUID REFERENCES buildings(id) ON DELETE RESTRICT NOT NULL,
    service_package_id    UUID REFERENCES service_packages(id) ON DELETE RESTRICT NOT NULL,
    purchase_action       VARCHAR(20) NOT NULL, -- New | Renewal
    service_duration_months INT NOT NULL,
    unit_price            DECIMAL(14,2) NOT NULL,
    discount_amount       DECIMAL(14,2) NOT NULL DEFAULT 0,
    subtotal_amount       DECIMAL(14,2) NOT NULL,
    total_amount          DECIMAL(14,2) NOT NULL,
    currency              VARCHAR(3) NOT NULL,
    price_snapshot        JSONB NOT NULL DEFAULT '{}',
    terms_snapshot        JSONB NOT NULL DEFAULT '{}',
    discount_snapshot     JSONB NOT NULL DEFAULT '{}',
    line_provisioning_key VARCHAR(255) UNIQUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (quotation_id, building_id),
    UNIQUE (id, quotation_id),
    CONSTRAINT check_quotation_item_action CHECK (purchase_action IN ('New','Renewal')),
    CONSTRAINT check_quotation_item_duration CHECK (service_duration_months > 0),
    CONSTRAINT check_quotation_item_amounts CHECK (
        unit_price >= 0 AND discount_amount >= 0 AND subtotal_amount >= 0
        AND total_amount = subtotal_amount - discount_amount
        AND total_amount >= 0 AND currency ~ '^[A-Z]{3}$'
    )
);

ALTER TABLE service_entitlements
    ADD CONSTRAINT fk_entitlement_quotation_item
    FOREIGN KEY (quotation_item_id, quotation_id)
    REFERENCES quotation_building_items(id, quotation_id) ON DELETE RESTRICT;

ALTER TABLE payment_provisioning_records
    ADD CONSTRAINT fk_payment_provisioning_quotation_item
    FOREIGN KEY (quotation_item_id, quotation_id)
    REFERENCES quotation_building_items(id, quotation_id) ON DELETE RESTRICT;

CREATE TABLE enterprise_quote_requests (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id       UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    requested_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    requested_building_count INT NOT NULL,
    requested_duration_months INT,
    contact_name          TEXT NOT NULL,
    contact_email         VARCHAR(255) NOT NULL,
    contact_phone         VARCHAR(50),
    notes                 TEXT,
    status                VARCHAR(20) NOT NULL DEFAULT 'New', -- New | Contacted | Quoted | Accepted | Rejected | Cancelled
    quotation_id          UUID REFERENCES quotations(id) ON DELETE RESTRICT,
    idempotency_key       VARCHAR(255) NOT NULL UNIQUE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_enterprise_request_count CHECK (requested_building_count > 0),
    CONSTRAINT check_enterprise_request_duration CHECK (requested_duration_months IS NULL OR requested_duration_months > 0),
    CONSTRAINT check_enterprise_request_status CHECK (status IN ('New','Contacted','Quoted','Accepted','Rejected','Cancelled'))
);

-- ------------------------------------------------------------------------------
-- GROUP 8A: Public Learn editorial content
-- ------------------------------------------------------------------------------
-- Learn is a public, PlatformAdmin-managed blog/library. It is separate from
-- Unity trainings, sessions and results. A post is the stable logical identity;
-- every editable snapshot lives in learn_post_versions.

CREATE TABLE learn_situations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            VARCHAR(120) UNIQUE NOT NULL,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_by      UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_learn_situation_slug CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    CONSTRAINT check_learn_situation_name CHECK (NULLIF(BTRIM(name), '') IS NOT NULL)
);

CREATE TABLE learn_posts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug                VARCHAR(180) UNIQUE NOT NULL,
    publication_status  VARCHAR(30) NOT NULL DEFAULT 'Unpublished', -- Unpublished | Published | Hidden | Deleted
    published_version_id UUID,
    created_by          UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    revision_no         BIGINT NOT NULL DEFAULT 1,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_learn_post_slug CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    CONSTRAINT check_learn_post_revision CHECK (revision_no > 0),
    CONSTRAINT check_learn_post_publication_status CHECK (
        publication_status IN ('Unpublished','Published','Hidden','Deleted')
    )
);

CREATE TABLE learn_post_versions (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id               UUID REFERENCES learn_posts(id) ON DELETE RESTRICT NOT NULL,
    version_number        INT NOT NULL,
    content_schema_version VARCHAR(50) NOT NULL,
    content_kind          VARCHAR(20) NOT NULL, -- Article | Tip | Video
    title                 VARCHAR(255) NOT NULL,
    summary               TEXT NOT NULL,
    cover_image_url       TEXT,
    content_blocks        JSONB NOT NULL DEFAULT '[]',
    content_hash          VARCHAR(64) NOT NULL,
    status                VARCHAR(20) NOT NULL DEFAULT 'Draft', -- Draft | Published
    created_by            UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    published_by          UUID REFERENCES users(id) ON DELETE RESTRICT,
    published_at          TIMESTAMPTZ,
    revision_no           BIGINT NOT NULL DEFAULT 1,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_learn_post_version_number UNIQUE (post_id, version_number),
    CONSTRAINT uq_learn_post_version_pair UNIQUE (id, post_id),
    CONSTRAINT check_learn_version_kind CHECK (content_kind IN ('Article','Tip','Video')),
    CONSTRAINT check_learn_version_status CHECK (status IN ('Draft','Published')),
    CONSTRAINT check_learn_version_number CHECK (version_number > 0),
    CONSTRAINT check_learn_version_revision CHECK (revision_no > 0),
    CONSTRAINT check_learn_version_hash CHECK (content_hash ~ '^[0-9a-fA-F]{64}$'),
    CONSTRAINT check_learn_version_title CHECK (NULLIF(BTRIM(title), '') IS NOT NULL),
    CONSTRAINT check_learn_version_summary CHECK (NULLIF(BTRIM(summary), '') IS NOT NULL),
    CONSTRAINT check_learn_version_blocks CHECK (JSONB_TYPEOF(content_blocks) = 'array'),
    CONSTRAINT check_learn_version_review_metadata CHECK (
        (status = 'Draft' AND published_by IS NULL AND published_at IS NULL)
        OR (status = 'Published' AND published_by IS NOT NULL AND published_at IS NOT NULL)
    )
);

ALTER TABLE learn_posts
    ADD CONSTRAINT fk_learn_post_published_version
    FOREIGN KEY (published_version_id) REFERENCES learn_post_versions(id) ON DELETE RESTRICT;

CREATE TABLE learn_post_version_situations (
    post_version_id UUID REFERENCES learn_post_versions(id) ON DELETE RESTRICT NOT NULL,
    situation_id    UUID REFERENCES learn_situations(id) ON DELETE RESTRICT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_version_id, situation_id)
);

CREATE TABLE learn_bookmarks (
    trainee_user_id UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    post_id         UUID REFERENCES learn_posts(id) ON DELETE RESTRICT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (trainee_user_id, post_id)
);

CREATE TABLE knowledge_sources (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID REFERENCES organizations(id) ON DELETE CASCADE,
    visibility           VARCHAR(30) NOT NULL DEFAULT 'Common', -- Common | Organization
    title                TEXT NOT NULL,
    source_uri           TEXT,
    version_label        VARCHAR(100) NOT NULL,
    source_hash          VARCHAR(64) NOT NULL,
    jurisdiction         TEXT,
    effective_from       TIMESTAMPTZ,
    effective_until      TIMESTAMPTZ,
    approval_status      VARCHAR(30) NOT NULL DEFAULT 'Draft', -- Draft | Approved | Retired
    approved_by          UUID REFERENCES users(id) ON DELETE RESTRICT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_knowledge_visibility CHECK (visibility IN ('Common','Organization')),
    CONSTRAINT check_knowledge_status CHECK (approval_status IN ('Draft','Approved','Retired')),
    CONSTRAINT check_knowledge_tenant CHECK (visibility = 'Common' OR organization_id IS NOT NULL),
    UNIQUE (organization_id, visibility, source_hash, version_label)
);

CREATE TABLE knowledge_chunks (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id           UUID REFERENCES knowledge_sources(id) ON DELETE CASCADE NOT NULL,
    chunk_index         INT NOT NULL,
    content             TEXT NOT NULL,
    locator             JSONB NOT NULL DEFAULT '{}',
    embedding           vector, -- chiều và index phải chốt cùng embedding model production
    metadata            JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_id, chunk_index)
);

CREATE TABLE learn_post_version_sources (
    post_version_id UUID REFERENCES learn_post_versions(id) ON DELETE RESTRICT NOT NULL,
    source_id       UUID REFERENCES knowledge_sources(id) ON DELETE RESTRICT NOT NULL,
    source_role     VARCHAR(20) NOT NULL DEFAULT 'Reference', -- Primary | Reference | Transcript
    locator         JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_version_id, source_id, source_role),
    CONSTRAINT check_learn_source_role CHECK (source_role IN ('Primary','Reference','Transcript'))
);

CREATE TABLE feedback (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submitted_by    UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    session_id      UUID REFERENCES sessions(id) ON DELETE SET NULL,
    category        VARCHAR(100) NOT NULL,
    rating          INT,
    message         TEXT NOT NULL,
    status          feedback_status_enum NOT NULL DEFAULT 'Submitted',
    reviewed_by     UUID REFERENCES users(id) ON DELETE RESTRICT,
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_feedback_rating CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),
    CONSTRAINT check_feedback_message CHECK (NULLIF(BTRIM(message), '') IS NOT NULL)
);

CREATE TABLE support_tickets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number   VARCHAR(50) UNIQUE NOT NULL,
    created_by      UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    session_id      UUID REFERENCES sessions(id) ON DELETE SET NULL,
    feedback_id     UUID REFERENCES feedback(id) ON DELETE SET NULL,
    assigned_to     UUID REFERENCES users(id) ON DELETE RESTRICT,
    subject         VARCHAR(255) NOT NULL,
    description     TEXT NOT NULL,
    priority        support_priority_enum NOT NULL DEFAULT 'Normal',
    status          support_ticket_status_enum NOT NULL DEFAULT 'Open',
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_support_subject CHECK (NULLIF(BTRIM(subject), '') IS NOT NULL),
    CONSTRAINT check_support_description CHECK (NULLIF(BTRIM(description), '') IS NOT NULL),
    CONSTRAINT check_support_resolution CHECK (status != 'Resolved' OR resolved_at IS NOT NULL)
);

COMMENT ON TABLE revision_reviews IS
'Persists the ConfirmForTraining or Rejected readiness action for one revision/scenario version pair; ConfirmForTraining moves the revision to ConfirmedForTraining without locking other compatible scenario authoring, and is not certification.';
COMMENT ON TABLE release_qr_codes IS
'A QR is stable at Building scope and resolves the current list of Published Trainings. It never stores a Training or release binding. Preparation pins the selected training/release/scenario; only explicit online start requires an Active Building entitlement.';
COMMENT ON TABLE payos_payment_requests IS
'PayOS request. Paid is set only after a verified, idempotently processed webhook whose orderCode, amount and currency match the expected request; no automatic recurring debit is assumed.';
COMMENT ON COLUMN payos_payment_requests.return_url IS
'UI navigation only; returnUrl is never payment confirmation.';
COMMENT ON TABLE payment_transactions IS
'One row per PayOS webhook event. A trusted backend adapter verifies the canonicalized webhook data before DB invocation; the DB records that attestation, deduplicates webhook_event_id, and compares orderCode, amount and currency before Applied.';
COMMENT ON TABLE service_entitlements IS
'Building-scoped service rights with independent activation/expiry. Payment success grants or extends this entitlement only through a trusted idempotent backend path.';
COMMENT ON TABLE payment_provisioning_records IS
'Per-quotation-line reconcile record for an Applied PayOS transaction whose Building entitlement provisioning has not completed; one payment can have many records and retries reuse each line provisioning_key.';
COMMENT ON TABLE ai_usage_ledger IS
'Append-oriented AI usage facts by organization, building, user, audience and request type. Backend owns quota/overage calculation and request idempotency.';
COMMENT ON TABLE learn_posts IS
'Stable Learn blog identity. PlatformAdmin publishes, hides, shows, soft-deletes or restores a pointer to an immutable learn_post_versions snapshot; Hidden retains the pointer for show and RAG, while Deleted is excluded from public reads and retrieval. It is unrelated to Unity trainings or sessions.';
COMMENT ON TABLE learn_post_versions IS
'Immutable editorial snapshot after publication. Draft edits use a new or reset Draft version; publish is an explicit backend gate and published content is never edited in place.';
COMMENT ON COLUMN learn_post_versions.content_blocks IS
'Schema-versioned JSON array of text/image/external-video blocks. Provider, canonical URL and video ID are validated by the backend allowlist; arbitrary iframe/script is not accepted.';
COMMENT ON TABLE learn_post_version_sources IS
'Common knowledge sources attached to the exact Learn version. Drafts may reference a Common source before its independent approval; publish/RAG gates require an allowed Approved source.';
COMMENT ON TABLE learn_bookmarks IS
'Trainee-only personal bookmarks. It is not a course enrollment/progress table and does not imply completion.';
COMMENT ON COLUMN knowledge_sources.source_uri IS
'Canonical source URL when applicable, including an approved external video/article URL; backend validates provider and redirect policy.';

-- ==============================================================================
-- SECTION 4: INDEXES
-- ==============================================================================

CREATE INDEX idx_organizations_active ON organizations(id) WHERE is_active AND deleted_at IS NULL;
CREATE INDEX idx_users_organization ON users(organization_id);
CREATE INDEX idx_users_active_role ON users(role) WHERE is_active AND deleted_at IS NULL;
CREATE UNIQUE INDEX uq_users_username_ci ON users (pg_catalog.lower(username))
WHERE username IS NOT NULL;

CREATE INDEX idx_user_devices_user ON user_devices(user_id);
CREATE INDEX idx_auth_refresh_tokens_user ON auth_refresh_tokens(user_id, expires_at DESC);
CREATE INDEX idx_google_onboarding_active ON auth_google_onboarding_sessions(firebase_uid, expires_at)
    WHERE completed_at IS NULL;
CREATE INDEX idx_password_reset_tokens_user ON password_reset_tokens(user_id, expires_at DESC);
CREATE INDEX idx_user_devices_push_enabled ON user_devices(user_id)
WHERE fcm_token IS NOT NULL AND notifications_enabled;

CREATE INDEX idx_buildings_organization ON buildings(organization_id);
CREATE INDEX idx_buildings_created_by ON buildings(created_by);
CREATE INDEX idx_buildings_active ON buildings(organization_id) WHERE is_active AND deleted_at IS NULL;

CREATE INDEX idx_building_floors_organization ON building_floors(organization_id);
CREATE INDEX idx_building_contacts_building ON building_contacts(building_id);

CREATE INDEX idx_revisions_building ON revisions(building_id);
CREATE INDEX idx_revisions_uploaded_by ON revisions(uploaded_by);
CREATE INDEX idx_revisions_status ON revisions(status);

CREATE INDEX idx_source_documents_revision ON source_documents(revision_id);
CREATE INDEX idx_source_documents_floor ON source_documents(floor_id);
CREATE INDEX idx_source_documents_uploaded_by ON source_documents(uploaded_by);
CREATE INDEX idx_source_documents_quarantine ON source_documents(quarantine_status);

CREATE INDEX idx_annotation_sets_created_by ON annotation_sets(created_by);
CREATE INDEX idx_revision_processing_logs_revision ON revision_processing_logs(revision_id);
CREATE INDEX idx_revision_artifacts_revision ON revision_artifacts(revision_id);
CREATE INDEX idx_bim_facts_revision ON bim_facts(revision_id);
CREATE INDEX idx_bim_facts_ifc_global_id ON bim_facts(revision_id, ifc_global_id);
CREATE INDEX idx_revision_reviews_revision ON revision_reviews(revision_id);
CREATE INDEX idx_revision_reviews_scenario ON revision_reviews(scenario_version_id);
CREATE INDEX idx_revision_reviews_reviewed_by ON revision_reviews(reviewed_by);
CREATE INDEX idx_revision_reviews_annotation_set ON revision_reviews(annotation_set_id);

CREATE INDEX idx_releases_scenario ON releases(scenario_version_id);
CREATE INDEX idx_releases_building ON releases(building_id);
CREATE INDEX idx_releases_organization ON releases(organization_id);
CREATE INDEX idx_releases_published_by ON releases(published_by);
CREATE INDEX idx_releases_revoked_by ON releases(revoked_by);
CREATE INDEX idx_releases_status ON releases(status);
CREATE INDEX idx_releases_published_building ON releases(building_id, published_at DESC) WHERE status = 'Published';

CREATE INDEX idx_release_qr_codes_building ON release_qr_codes(building_id);
CREATE INDEX idx_release_qr_codes_organization ON release_qr_codes(organization_id);
CREATE INDEX idx_release_qr_codes_floor ON release_qr_codes(floor_id);
CREATE INDEX idx_release_qr_codes_created_by ON release_qr_codes(created_by);
CREATE INDEX idx_release_qr_codes_active ON release_qr_codes(qr_hash) WHERE is_active;
CREATE UNIQUE INDEX uq_release_qr_codes_active_building_canonical
    ON release_qr_codes(building_id)
    WHERE is_active;

CREATE INDEX idx_processing_jobs_revision ON processing_jobs(revision_id, created_at DESC);
CREATE INDEX idx_processing_jobs_status ON processing_jobs(status, created_at DESC);
CREATE INDEX idx_revision_processing_logs_job ON revision_processing_logs(job_id, logged_at DESC);
CREATE INDEX idx_revision_artifacts_job ON revision_artifacts(job_id);
CREATE INDEX idx_validation_runs_revision ON validation_runs(revision_id, created_at DESC);
CREATE INDEX idx_validation_runs_scenario ON validation_runs(scenario_version_id, status);
CREATE INDEX idx_validation_runs_release ON validation_runs(release_id, status);
CREATE INDEX idx_validation_issues_run ON validation_issues(validation_run_id, severity, status);
CREATE INDEX idx_scenarios_building ON scenarios(building_id, created_at DESC);
CREATE INDEX idx_scenario_versions_revision ON scenario_versions(revision_id, created_at DESC);
CREATE INDEX idx_scenario_versions_organization ON scenario_versions(organization_id);
CREATE INDEX idx_scenario_versions_created_by ON scenario_versions(created_by);
CREATE INDEX idx_scenario_drafts_scenario ON scenario_drafts(scenario_id, updated_at DESC);

CREATE INDEX idx_trainings_release ON trainings(release_id);
CREATE INDEX idx_trainings_scenario ON trainings(scenario_version_id);
CREATE INDEX idx_trainings_organization ON trainings(organization_id);
CREATE INDEX idx_trainings_created_by ON trainings(created_by);

CREATE INDEX idx_sessions_training ON sessions(training_id);
CREATE INDEX idx_sessions_release ON sessions(release_id);
CREATE INDEX idx_sessions_scenario ON sessions(scenario_version_id);
CREATE INDEX idx_sessions_organization ON sessions(organization_id);
CREATE INDEX idx_sessions_trainee ON sessions(trainee_user_id);
CREATE INDEX idx_sessions_device ON sessions(device_id);
CREATE INDEX idx_sessions_qr_code ON sessions(qr_code_id);
CREATE INDEX idx_sessions_running ON sessions(status, started_at) WHERE status IN ('Running', 'Launching');
CREATE INDEX idx_playtest_sessions_organization ON playtest_sessions(organization_id, created_at DESC);
CREATE INDEX idx_playtest_sessions_building ON playtest_sessions(building_id, created_at DESC);
CREATE INDEX idx_playtest_sessions_entitlement ON playtest_sessions(service_entitlement_id, created_at DESC);

CREATE INDEX idx_session_results_unsynced ON session_results(created_at) WHERE NOT is_synced;
CREATE INDEX idx_session_events_type ON session_events(event_type);
CREATE INDEX idx_session_events_timeline ON session_events(session_id, recorded_at);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_target ON audit_logs(target_entity, target_id);
CREATE INDEX idx_audit_logs_time ON audit_logs(created_at DESC);

CREATE INDEX idx_service_packages_created_by ON service_packages(created_by);
CREATE INDEX idx_service_packages_active ON service_packages(code) WHERE is_active;
CREATE INDEX idx_quotations_organization ON quotations(organization_id);
CREATE INDEX idx_quotations_requested_by ON quotations(requested_by);
CREATE INDEX idx_quotations_issued_by ON quotations(issued_by);
CREATE INDEX idx_payos_payment_requests_quotation ON payos_payment_requests(quotation_id);
CREATE INDEX idx_payos_payment_requests_organization ON payos_payment_requests(organization_id);
CREATE INDEX idx_payos_payment_requests_requested_by ON payos_payment_requests(requested_by);
CREATE INDEX idx_payos_payment_requests_status ON payos_payment_requests(status, created_at);
CREATE INDEX idx_payment_transactions_request ON payment_transactions(payment_request_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status, received_at);
CREATE INDEX idx_payment_provisioning_status ON payment_provisioning_records(status, updated_at DESC);
CREATE INDEX idx_invoice_metadata_quotation ON invoice_metadata(quotation_id);
CREATE INDEX idx_invoice_metadata_organization ON invoice_metadata(organization_id);
CREATE INDEX idx_service_entitlements_building ON service_entitlements(building_id, starts_at DESC);
CREATE INDEX idx_service_entitlements_active ON service_entitlements(building_id, ends_at)
WHERE status IN ('Trial','Active');
CREATE INDEX idx_ai_billing_periods_organization ON ai_billing_periods(organization_id, period_start DESC);
CREATE INDEX idx_ai_quota_grants_scope ON ai_quota_grants(organization_id, building_id, audience, starts_at, ends_at);
CREATE INDEX idx_ai_quota_grants_trainee ON ai_quota_grants(trainee_user_id, quota_kind, starts_at, ends_at);
CREATE INDEX idx_ai_usage_ledger_organization ON ai_usage_ledger(organization_id, created_at DESC);
CREATE INDEX idx_ai_usage_ledger_building ON ai_usage_ledger(building_id, created_at DESC);
CREATE INDEX idx_ai_usage_ledger_user ON ai_usage_ledger(user_id, created_at DESC);
CREATE INDEX idx_ai_usage_ledger_policy ON ai_usage_ledger(policy_version_id);
CREATE INDEX idx_knowledge_sources_scope ON knowledge_sources(organization_id, visibility, approval_status);
CREATE INDEX idx_knowledge_chunks_source ON knowledge_chunks(source_id);
CREATE INDEX idx_learn_situations_active ON learn_situations(is_active, name);
CREATE INDEX idx_learn_posts_publication ON learn_posts(publication_status, updated_at DESC);
CREATE INDEX idx_learn_versions_post_status ON learn_post_versions(post_id, status, version_number DESC);
CREATE INDEX idx_learn_version_situations_situation ON learn_post_version_situations(situation_id, post_version_id);
CREATE INDEX idx_learn_bookmarks_trainee ON learn_bookmarks(trainee_user_id, created_at DESC);
CREATE INDEX idx_learn_version_sources_source ON learn_post_version_sources(source_id, post_version_id);
CREATE UNIQUE INDEX uq_knowledge_common_hash_version
    ON knowledge_sources(visibility, source_hash, version_label)
    WHERE visibility = 'Common';
CREATE UNIQUE INDEX uq_knowledge_organization_hash_version
    ON knowledge_sources(organization_id, visibility, source_hash, version_label)
    WHERE visibility = 'Organization';
-- Chưa tạo ivfflat/HNSW index vì embedding model và số chiều production còn mở.
CREATE INDEX idx_feedback_submitted_by ON feedback(submitted_by);
CREATE INDEX idx_feedback_organization ON feedback(organization_id);
CREATE INDEX idx_feedback_session ON feedback(session_id);
CREATE INDEX idx_feedback_reviewed_by ON feedback(reviewed_by);
CREATE INDEX idx_support_tickets_created_by ON support_tickets(created_by);
CREATE INDEX idx_support_tickets_organization ON support_tickets(organization_id);
CREATE INDEX idx_support_tickets_session ON support_tickets(session_id);
CREATE INDEX idx_support_tickets_feedback ON support_tickets(feedback_id);
CREATE INDEX idx_support_tickets_assigned_to ON support_tickets(assigned_to);
CREATE INDEX idx_support_tickets_queue ON support_tickets(status, priority, created_at);
CREATE INDEX idx_quotation_items_building ON quotation_building_items(building_id, created_at DESC);
CREATE INDEX idx_quotation_items_quotation ON quotation_building_items(quotation_id, created_at);
CREATE INDEX idx_discount_rules_active ON service_package_discount_rules(service_package_id, is_active, valid_from, valid_until);
CREATE INDEX idx_command_receipts_operation ON application_command_receipts(operation_name, created_at DESC);
CREATE INDEX idx_enterprise_quote_requests_org ON enterprise_quote_requests(organization_id, created_at DESC);
CREATE INDEX idx_entitlements_expiry ON service_entitlements(organization_id, ends_at)
    WHERE status = 'Active';
CREATE INDEX idx_org_notifications_unread ON organization_notifications(recipient_user_id, read_at, created_at DESC);
CREATE INDEX idx_notification_deliveries_pending ON notification_deliveries(status, updated_at)
    WHERE status IN ('Pending','Failed');
CREATE INDEX idx_payment_provisioning_item ON payment_provisioning_records(quotation_item_id, status, updated_at DESC);

-- ==============================================================================
-- SECTION 5: TRIGGERS & RULES

-- Learn editorial actor, ETag, idempotency, audit and outbox orchestration
-- belong to the .NET application service. These database checks retain only
-- relational integrity and immutable Published snapshots; they do not trust a
-- client-controlled custom setting as an actor or action proof.
CREATE OR REPLACE FUNCTION validate_learn_editorial_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_old_post_id UUID;
    v_new_post_id UUID;
    v_old_version_status VARCHAR(20);
    v_new_version_status VARCHAR(20);
BEGIN
    IF TG_TABLE_NAME = 'learn_situations' THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    IF TG_TABLE_NAME = 'learn_posts' THEN
        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION 'Learn post history cannot be deleted';
        END IF;
        IF TG_OP = 'UPDATE' THEN
            IF NEW.id IS DISTINCT FROM OLD.id
               OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
                RAISE EXCEPTION 'Learn post identity is immutable';
            END IF;
            PERFORM 1
              FROM public.learn_post_versions
             WHERE post_id = NEW.id AND status = 'Published'
             FOR UPDATE;
            IF NEW.published_version_id IS NOT NULL THEN
                PERFORM 1
                  FROM public.learn_post_versions
                 WHERE id = NEW.published_version_id
                 FOR UPDATE;
            END IF;
            IF (OLD.published_version_id IS NOT NULL
               OR EXISTS (
                    SELECT 1 FROM public.learn_post_versions
                     WHERE post_id = NEW.id AND status = 'Published'
               ))
               AND NEW.slug IS DISTINCT FROM OLD.slug THEN
                RAISE EXCEPTION 'Published Learn post slug is immutable';
            END IF;
        END IF;
        IF NEW.publication_status NOT IN ('Unpublished','Published','Hidden','Deleted') THEN
            RAISE EXCEPTION 'Invalid Learn publication status';
        END IF;
        IF NEW.publication_status IN ('Published','Hidden') THEN
            IF NEW.published_version_id IS NULL OR NOT EXISTS (
                SELECT 1
                  FROM public.learn_post_versions AS version
                 WHERE version.id = NEW.published_version_id
                   AND version.post_id = NEW.id
                   AND version.status = 'Published'
            ) THEN
                RAISE EXCEPTION 'Published Learn post must point to its own Published version';
            END IF;
        ELSIF NEW.publication_status = 'Deleted' AND NEW.published_version_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                    FROM public.learn_post_versions AS version
                   WHERE version.id = NEW.published_version_id
                     AND version.post_id = NEW.id
                     AND version.status = 'Published'
              ) THEN
            RAISE EXCEPTION 'Deleted Learn post pointer must reference its own Published version';
        ELSIF NEW.publication_status NOT IN ('Deleted') AND NEW.published_version_id IS NOT NULL THEN
            RAISE EXCEPTION 'Unpublished Learn post cannot expose a public version pointer';
        END IF;
        IF TG_OP = 'UPDATE'
           AND OLD.published_version_id IS NOT NULL
           AND NEW.publication_status = 'Unpublished' THEN
            RAISE EXCEPTION 'A previously published Learn post must use Hidden state';
        END IF;
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'learn_post_version_situations' THEN
        v_old_post_id := NULL;
        v_new_post_id := NULL;
        v_old_version_status := NULL;
        v_new_version_status := NULL;
        IF TG_OP IN ('UPDATE', 'DELETE') THEN
            SELECT version.post_id, version.status
              INTO v_old_post_id, v_old_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = OLD.post_version_id;
        END IF;
        IF TG_OP IN ('INSERT', 'UPDATE') THEN
            SELECT version.post_id, version.status
              INTO v_new_post_id, v_new_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = NEW.post_version_id;
        END IF;
        -- Lock old and new parents in stable order before checking the link.
        PERFORM 1
          FROM public.learn_posts
         WHERE id IN (v_old_post_id, v_new_post_id)
         ORDER BY id
         FOR UPDATE;
        PERFORM 1
          FROM public.learn_post_versions
         WHERE id IN (
             CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN OLD.post_version_id ELSE NULL END,
             CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN NEW.post_version_id ELSE NULL END
         )
         ORDER BY id
         FOR UPDATE;
        -- Re-read after the locks. The pre-lock read is only a candidate
        -- lookup and must not decide whether a Published link is mutable.
        IF TG_OP IN ('UPDATE', 'DELETE') THEN
            SELECT version.post_id, version.status
              INTO v_old_post_id, v_old_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = OLD.post_version_id;
        END IF;
        IF TG_OP IN ('INSERT', 'UPDATE') THEN
            SELECT version.post_id, version.status
              INTO v_new_post_id, v_new_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = NEW.post_version_id;
        END IF;
        IF TG_OP = 'DELETE' THEN
            IF v_old_version_status = 'Published' THEN
                RAISE EXCEPTION 'Published Learn version classification is immutable';
            END IF;
            RETURN OLD;
        END IF;
        IF v_old_version_status = 'Published' OR v_new_version_status = 'Published' THEN
            RAISE EXCEPTION 'Published Learn version classification is immutable';
        END IF;
        IF TG_OP = 'UPDATE'
           AND NEW.post_version_id IS DISTINCT FROM OLD.post_version_id THEN
            RAISE EXCEPTION 'Learn version classification parent is immutable';
        END IF;
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'learn_post_versions' THEN
        IF TG_OP = 'DELETE' THEN
            IF OLD.status = 'Published' THEN
                RAISE EXCEPTION 'Published Learn version history cannot be deleted';
            END IF;
            RETURN OLD;
        END IF;
        IF TG_OP = 'UPDATE' THEN
            IF NEW.post_id IS DISTINCT FROM OLD.post_id
               OR NEW.version_number IS DISTINCT FROM OLD.version_number
               OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
                RAISE EXCEPTION 'Learn version identity is immutable';
            END IF;
            IF OLD.status = 'Published' THEN
                IF NEW.status IS DISTINCT FROM OLD.status
                   OR NEW.content_schema_version IS DISTINCT FROM OLD.content_schema_version
                   OR NEW.content_kind IS DISTINCT FROM OLD.content_kind
                   OR NEW.title IS DISTINCT FROM OLD.title
                   OR NEW.summary IS DISTINCT FROM OLD.summary
                   OR NEW.cover_image_url IS DISTINCT FROM OLD.cover_image_url
                   OR NEW.content_blocks IS DISTINCT FROM OLD.content_blocks
                   OR NEW.content_hash IS DISTINCT FROM OLD.content_hash
                   OR NEW.published_by IS DISTINCT FROM OLD.published_by
                   OR NEW.published_at IS DISTINCT FROM OLD.published_at
                   OR NEW.revision_no IS DISTINCT FROM OLD.revision_no
                   OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
                     RAISE EXCEPTION 'Published Learn version is immutable; create a new version';
                END IF;
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'learn_post_version_sources' THEN
        v_old_post_id := NULL;
        v_new_post_id := NULL;
        v_old_version_status := NULL;
        v_new_version_status := NULL;
        IF TG_OP IN ('UPDATE', 'DELETE') THEN
            SELECT version.post_id, version.status
              INTO v_old_post_id, v_old_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = OLD.post_version_id;
        END IF;
        IF TG_OP IN ('INSERT', 'UPDATE') THEN
            SELECT version.post_id, version.status
              INTO v_new_post_id, v_new_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = NEW.post_version_id;
        END IF;
        PERFORM 1
          FROM public.learn_posts
         WHERE id IN (v_old_post_id, v_new_post_id)
         ORDER BY id
         FOR UPDATE;
            PERFORM 1
          FROM public.learn_post_versions
         WHERE id IN (
             CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN OLD.post_version_id ELSE NULL END,
             CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN NEW.post_version_id ELSE NULL END
         )
         ORDER BY id
         FOR UPDATE;
        IF TG_OP IN ('UPDATE', 'DELETE') THEN
            SELECT version.post_id, version.status
              INTO v_old_post_id, v_old_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = OLD.post_version_id;
        END IF;
        IF TG_OP IN ('INSERT', 'UPDATE') THEN
            SELECT version.post_id, version.status
              INTO v_new_post_id, v_new_version_status
              FROM public.learn_post_versions AS version
             WHERE version.id = NEW.post_version_id;
        END IF;
        IF TG_OP = 'DELETE' THEN
            IF v_old_version_status = 'Published' THEN
                RAISE EXCEPTION 'Published Learn version sources are immutable';
            END IF;
            RETURN OLD;
        END IF;
        IF TG_OP = 'UPDATE'
           AND NEW.post_version_id IS DISTINCT FROM OLD.post_version_id THEN
            RAISE EXCEPTION 'Learn source link parent is immutable';
        END IF;
        IF v_old_version_status = 'Published' OR v_new_version_status = 'Published' THEN
            RAISE EXCEPTION 'Published Learn version sources are immutable';
        END IF;
        IF NOT EXISTS (
            SELECT 1
              FROM public.knowledge_sources AS source
             WHERE source.id = NEW.source_id
               AND source.visibility = 'Common'
        ) THEN
            RAISE EXCEPTION 'Learn sources must be Common knowledge sources';
        END IF;
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_learn_bookmark_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.users AS trainee
         WHERE trainee.id = NEW.trainee_user_id
           AND trainee.role = 'Trainee'
           AND trainee.is_active
           AND trainee.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Learn bookmark owner must be an active Trainee';
    END IF;
    RETURN NEW;
END;
$$;
-- ==============================================================================

-- ConfirmForTraining là action readiness nội bộ. BEFORE trigger khóa revision
-- ngắn hạn, xác thực actor/scenario/organization và AFTER trigger mới chuyển
-- ReadyForScenario -> ConfirmedForTraining hoặc giữ ConfirmedForTraining cho version mới;
-- không có nghĩa chứng nhận PCCC.
CREATE OR REPLACE FUNCTION validate_revision_review_action()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
DECLARE
    v_revision RECORD;
BEGIN
    SELECT revision.*, building.organization_id AS revision_organization_id
    INTO v_revision
    FROM public.revisions AS revision
    JOIN public.buildings AS building ON building.id = revision.building_id
    WHERE revision.id = NEW.revision_id
    FOR UPDATE OF revision;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'revision_id does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.users AS actor
        WHERE actor.id = NEW.reviewed_by
          AND actor.role = 'OrganizationUser'
          AND actor.organization_id = v_revision.revision_organization_id
          AND actor.is_active
          AND actor.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'reviewed_by must be an active OrganizationUser for the revision organization';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.scenario_versions AS scenario
        WHERE scenario.id = NEW.scenario_version_id
          AND scenario.revision_id = NEW.revision_id
          AND scenario.organization_id = v_revision.revision_organization_id
    ) THEN
        RAISE EXCEPTION 'scenario, revision and organization must be consistent';
    END IF;

    IF NEW.annotation_set_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.annotation_sets AS annotations
        WHERE annotations.id = NEW.annotation_set_id
          AND annotations.revision_id = NEW.revision_id
    ) THEN
        RAISE EXCEPTION 'annotation_set_id must belong to revision_id';
    END IF;

    IF NEW.action = 'ConfirmForTraining' AND v_revision.status NOT IN ('ReadyForScenario', 'ConfirmedForTraining') THEN
        RAISE EXCEPTION 'ConfirmForTraining requires a ReadyForScenario or ConfirmedForTraining revision';
    END IF;

    IF NEW.action = 'Rejected' AND v_revision.status NOT IN ('ReadyForScenario', 'ConfirmedForTraining') THEN
        RAISE EXCEPTION 'Rejected review requires a ReadyForScenario or ConfirmedForTraining revision';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION apply_revision_review_action()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    -- Readiness belongs to the revision/scenario-version pair. A rejected
    -- scenario must not turn shared geometry into a globally rejected
    -- revision, because another scenario version can still be ready.
    IF NEW.action = 'ConfirmForTraining' THEN
        UPDATE public.revisions
           SET status = 'ConfirmedForTraining'::public.revision_status_enum
         WHERE id = NEW.revision_id
           AND status IN ('ReadyForScenario','ConfirmedForTraining');
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION enforce_revision_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status != 'Draft' THEN
            RAISE EXCEPTION 'a revision must be created as Draft';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;

    IF NOT (
        (OLD.status = 'Draft' AND NEW.status = 'Uploaded')
        OR (OLD.status = 'Uploaded' AND NEW.status IN ('Processing', 'Failed'))
        OR (OLD.status = 'Processing' AND NEW.status IN ('NeedsFix', 'ReadyForScenario', 'Failed'))
        OR (OLD.status = 'NeedsFix' AND NEW.status IN ('Processing', 'Superseded'))
        OR (OLD.status = 'ReadyForScenario' AND NEW.status IN ('ConfirmedForTraining', 'Superseded'))
        OR (OLD.status = 'ConfirmedForTraining' AND NEW.status = 'Superseded')
        OR (OLD.status = 'Rejected' AND NEW.status = 'Superseded')
        OR (OLD.status = 'Failed' AND NEW.status IN ('Processing', 'Superseded'))
    ) THEN
        RAISE EXCEPTION 'Invalid revision transition: % -> %', OLD.status, NEW.status;
    END IF;

    IF NEW.status = 'ConfirmedForTraining' AND NOT EXISTS (
        SELECT 1
        FROM public.revision_reviews AS review
        WHERE review.revision_id = NEW.id
          AND review.action = 'ConfirmForTraining'
    ) THEN
        RAISE EXCEPTION 'ConfirmedForTraining requires a persisted ConfirmForTraining action';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION confirm_revision_for_training(
    p_revision_id UUID,
    p_scenario_version_id UUID,
    p_confirmed_by UUID,
    p_annotation_set_id UUID,
    p_review_message TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
DECLARE
    v_review_id UUID;
BEGIN
    INSERT INTO public.revision_reviews (
        revision_id,
        scenario_version_id,
        reviewed_by,
        annotation_set_id,
        action,
        review_message
    )
    VALUES (
        p_revision_id,
        p_scenario_version_id,
        p_confirmed_by,
        p_annotation_set_id,
        'ConfirmForTraining',
        p_review_message
    )
    RETURNING id INTO v_review_id;

    RETURN v_review_id;
END;
$$;

COMMENT ON FUNCTION confirm_revision_for_training(UUID, UUID, UUID, UUID, TEXT) IS
'Readiness-only action: records ConfirmForTraining for one scenario version and transitions the revision to ConfirmedForTraining; other compatible scenario versions may still be authored; it is not certification or fire-safety approval.';

CREATE OR REPLACE FUNCTION validate_scenario_version_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.revisions AS revision
        JOIN public.buildings AS building ON building.id = revision.building_id
        JOIN public.scenarios AS scenario
          ON scenario.id = NEW.scenario_id
         AND scenario.building_id = NEW.building_id
         AND scenario.organization_id = NEW.organization_id
        WHERE revision.id = NEW.revision_id
          AND revision.status IN ('ReadyForScenario', 'ConfirmedForTraining')
          AND revision.building_id = NEW.building_id
          AND building.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'scenario authoring requires a matching ReadyForScenario or ConfirmedForTraining revision, scenario, building and organization';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.users AS creator
        WHERE creator.id = NEW.created_by
          AND creator.role = 'OrganizationUser'
          AND creator.organization_id = NEW.organization_id
          AND creator.is_active
          AND creator.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'created_by must be an active OrganizationUser for the scenario organization';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'scenario versions are immutable; create a new version from the draft';
    END IF;

    RETURN NEW;
END;
$$;

-- Enforce the executable order: ConfirmForTraining -> Built release + matching
-- Training/package -> active Building service -> Published release.
CREATE OR REPLACE FUNCTION validate_release_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'INSERT'
       OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'Published') THEN
        IF NOT EXISTS (
            SELECT 1
            FROM public.revisions AS revision
            JOIN public.buildings AS building ON building.id = revision.building_id
            JOIN public.scenario_versions AS scenario
              ON scenario.id = NEW.scenario_version_id
             AND scenario.revision_id = revision.id
            WHERE revision.id = NEW.revision_id
              AND revision.status = 'ConfirmedForTraining'
              AND building.id = NEW.building_id
              AND building.organization_id = NEW.organization_id
              AND scenario.organization_id = NEW.organization_id
              AND EXISTS (
                  SELECT 1
                  FROM public.revision_reviews AS review
                   WHERE review.revision_id = revision.id
                     AND review.scenario_version_id = scenario.id
                     AND review.action = 'ConfirmForTraining'
                     AND NOT EXISTS (
                         SELECT 1
                           FROM public.revision_reviews AS newer_review
                          WHERE newer_review.revision_id = review.revision_id
                            AND newer_review.scenario_version_id = review.scenario_version_id
                            AND (
                                newer_review.reviewed_at > review.reviewed_at
                                OR (newer_review.reviewed_at = review.reviewed_at AND newer_review.id > review.id)
                            )
                     )
               )
        ) THEN
            RAISE EXCEPTION 'release requires the matching ConfirmedForTraining revision, scenario, building and organization';
        END IF;
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.status != 'Built'
           OR NEW.published_by IS NOT NULL
           OR NEW.published_at IS NOT NULL
           OR NEW.revoked_by IS NOT NULL
           OR NEW.revoked_reason IS NOT NULL THEN
            RAISE EXCEPTION 'a release must be created as Built before Training and publish';
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.revision_id IS DISTINCT FROM NEW.revision_id
       OR OLD.scenario_version_id IS DISTINCT FROM NEW.scenario_version_id
       OR OLD.building_id IS DISTINCT FROM NEW.building_id
       OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
       OR OLD.safety_thresholds IS DISTINCT FROM NEW.safety_thresholds THEN
        RAISE EXCEPTION 'release revision, scenario, building, organization and pinned thresholds are immutable';
    END IF;

    IF OLD.published_at IS NOT NULL AND (
        NEW.published_at IS DISTINCT FROM OLD.published_at
        OR NEW.published_by IS DISTINCT FROM OLD.published_by
    ) THEN
        RAISE EXCEPTION 'release publish provenance is immutable';
    END IF;

    IF OLD.status = 'Revoked' AND (
        NEW.revoked_by IS DISTINCT FROM OLD.revoked_by
        OR NEW.revoked_reason IS DISTINCT FROM OLD.revoked_reason
    ) THEN
        RAISE EXCEPTION 'release revocation provenance is immutable';
    END IF;

    IF OLD.status IS DISTINCT FROM NEW.status AND NOT (
        (OLD.status = 'Built' AND NEW.status IN ('Published', 'Revoked'))
        OR (OLD.status = 'Published' AND NEW.status IN ('Superseded', 'Revoked'))
    ) THEN
        RAISE EXCEPTION 'Invalid release transition: % -> %', OLD.status, NEW.status;
    END IF;

    IF NEW.status = 'Published' AND OLD.status != 'Published' THEN
        IF NEW.published_by IS NULL OR NEW.published_at IS NULL THEN
            RAISE EXCEPTION 'Published requires published_by and published_at';
        END IF;
        IF NOT EXISTS (
            SELECT 1
            FROM public.users AS publisher
            WHERE publisher.id = NEW.published_by
              AND publisher.role = 'OrganizationUser'
              AND publisher.organization_id = NEW.organization_id
              AND publisher.is_active
              AND publisher.deleted_at IS NULL
        ) THEN
            RAISE EXCEPTION 'published_by must be an active OrganizationUser for the release organization';
        END IF;
        IF NOT EXISTS (
            SELECT 1
            FROM public.release_packages AS package
            JOIN public.runtime_compatibility_catalog AS catalog
              ON catalog.protocol_version = package.protocol_version
             AND catalog.manifest_schema_version = package.manifest_schema_version
             AND catalog.is_active
            WHERE package.release_id = NEW.id
              AND NULLIF(pg_catalog.btrim(package.checksum_sha256), '') IS NOT NULL
              AND NULLIF(pg_catalog.btrim(package.manifest_url), '') IS NOT NULL
              AND NULLIF(pg_catalog.btrim(package.package_url), '') IS NOT NULL
              AND public.fet3d_runtime_package_is_compatible(
                    catalog.runtime_version,
                    package.min_runtime_version,
                    package.protocol_version,
                    package.manifest_schema_version,
                    package.required_capabilities,
                    catalog.id
              )
        ) OR NOT EXISTS (
            SELECT 1
            FROM public.trainings AS training
            WHERE training.release_id = NEW.id
              AND training.scenario_version_id = NEW.scenario_version_id
              AND training.organization_id = NEW.organization_id
              AND training.status = 'Active'
        ) THEN
            RAISE EXCEPTION 'publish requires a package and matching Active Training';
        END IF;
        IF NOT EXISTS (
            SELECT 1
            FROM public.release_packages AS package
            JOIN public.validation_runs AS run
              ON run.id = package.candidate_validation_run_id
             AND run.revision_id = NEW.revision_id
             AND run.scenario_version_id = NEW.scenario_version_id
             AND run.release_id = NEW.id
              AND run.scope = 'ReleasePackage'
             AND run.status = 'Passed'
             JOIN public.revision_artifacts AS artifact
               ON artifact.id = run.artifact_id
              AND artifact.sha256_hash = package.checksum_sha256
              AND artifact.metadata ->> 'manifest_sha256' = package.manifest_sha256
              AND artifact.metadata ->> 'build_target' = package.build_target
              AND artifact.metadata ->> 'min_runtime_version' = package.min_runtime_version
              AND artifact.metadata ->> 'protocol_version' = package.protocol_version
              AND artifact.metadata ->> 'manifest_schema_version' = package.manifest_schema_version
              AND artifact.metadata ? 'required_capabilities'
              AND pg_catalog.jsonb_typeof(artifact.metadata -> 'required_capabilities') = 'array'
              AND artifact.metadata -> 'required_capabilities' = package.required_capabilities
            WHERE package.release_id = NEW.id
              AND NOT EXISTS (
                  SELECT 1
                  FROM public.validation_issues AS issue
                  WHERE issue.validation_run_id = run.id
                    AND issue.severity IN ('Error','Critical')
                    AND issue.status NOT IN ('Resolved','Waived')
              )
        ) THEN
            RAISE EXCEPTION 'publish requires a passed ReleasePackage validation run with no open Error/Critical issue';
        END IF;
        IF NOT EXISTS (
            SELECT 1
            FROM public.service_entitlements AS entitlement
            WHERE entitlement.building_id = NEW.building_id
              AND entitlement.organization_id = NEW.organization_id
              AND entitlement.status = 'Active'
              AND entitlement.starts_at <= pg_catalog.now()
              AND entitlement.ends_at > pg_catalog.now()
        ) THEN
            RAISE EXCEPTION 'publish requires an online active Building service entitlement';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_service_entitlement_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'Active'))
       AND NOT EXISTS (
        SELECT 1
        FROM public.buildings AS building
        WHERE building.id = NEW.building_id
          AND building.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'service entitlement building and organization must match';
    END IF;

    IF NEW.quotation_item_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.quotation_building_items AS item
        JOIN public.quotations AS quotation ON quotation.id = item.quotation_id
        WHERE item.id = NEW.quotation_item_id
          AND item.quotation_id = NEW.quotation_id
          AND quotation.billing_purpose = 'BuildingService'
          AND quotation.organization_id = NEW.organization_id
          AND item.building_id = NEW.building_id
          AND item.service_package_id = NEW.service_package_id
          AND item.price_snapshot = NEW.price_snapshot
          AND item.terms_snapshot = NEW.terms_snapshot
    ) THEN
        RAISE EXCEPTION 'service entitlement quotation item must match Building, organization and snapshots';
    END IF;

    IF NEW.payment_transaction_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.payment_transactions AS payment
        JOIN public.payos_payment_requests AS request
          ON request.id = payment.payment_request_id
        WHERE payment.id = NEW.payment_transaction_id
          AND payment.status = 'Applied'
          AND request.quotation_id = NEW.quotation_id
          AND request.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'service entitlement payment must be the Applied transaction for its quotation';
    END IF;

    IF NEW.status = 'Active' AND (NEW.quotation_item_id IS NULL OR NEW.payment_transaction_id IS NULL
        OR NEW.provisioning_key IS DISTINCT FROM (
        'service:' || NEW.quotation_item_id::TEXT || ':' || NEW.payment_transaction_id::TEXT
    )) THEN
        RAISE EXCEPTION 'Active service entitlement requires a deterministic quotation-line provisioning key';
    END IF;

    IF TG_OP = 'UPDATE' AND (
        OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.building_id IS DISTINCT FROM NEW.building_id
        OR OLD.service_package_id IS DISTINCT FROM NEW.service_package_id
        OR OLD.quotation_id IS DISTINCT FROM NEW.quotation_id
        OR OLD.quotation_item_id IS DISTINCT FROM NEW.quotation_item_id
        OR OLD.payment_transaction_id IS DISTINCT FROM NEW.payment_transaction_id
        OR OLD.provisioning_key IS DISTINCT FROM NEW.provisioning_key
        OR OLD.starts_at IS DISTINCT FROM NEW.starts_at
        OR OLD.ends_at IS DISTINCT FROM NEW.ends_at
        OR OLD.price_snapshot IS DISTINCT FROM NEW.price_snapshot
        OR OLD.terms_snapshot IS DISTINCT FROM NEW.terms_snapshot
        OR OLD.created_by IS DISTINCT FROM NEW.created_by
    ) THEN
        RAISE EXCEPTION 'service entitlement provenance and identity are immutable';
    END IF;

    RETURN NEW;
END;
$$;



CREATE OR REPLACE FUNCTION validate_ai_quota_grant_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NEW.audience = 'organization' AND NEW.building_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.buildings AS building
        WHERE building.id = NEW.building_id
          AND building.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'organization quota grant building must belong to the grant organization';
    END IF;
    IF NEW.audience = 'trainee' AND NOT EXISTS (
        SELECT 1
        FROM public.users AS trainee
        WHERE trainee.id = NEW.trainee_user_id
          AND trainee.role = 'Trainee'
          AND trainee.is_active
          AND trainee.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'trainee quota grant must target an active Trainee';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.audience IS DISTINCT FROM NEW.audience
        OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.building_id IS DISTINCT FROM NEW.building_id
        OR OLD.trainee_user_id IS DISTINCT FROM NEW.trainee_user_id
        OR OLD.quota_kind IS DISTINCT FROM NEW.quota_kind
        OR OLD.starts_at IS DISTINCT FROM NEW.starts_at
        OR OLD.ends_at IS DISTINCT FROM NEW.ends_at
    ) THEN
        RAISE EXCEPTION 'quota grant audience, scope, kind and period are immutable';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_payment_provisioning_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.payment_transactions AS payment
        JOIN public.payos_payment_requests AS request
          ON request.id = payment.payment_request_id
        JOIN public.quotations AS quotation
          ON quotation.id = request.quotation_id
        JOIN public.quotation_building_items AS item
          ON item.id = NEW.quotation_item_id
         AND item.quotation_id = NEW.quotation_id
        WHERE payment.id = NEW.payment_transaction_id
          AND payment.status = 'Applied'
          AND request.quotation_id = NEW.quotation_id
          AND request.organization_id = NEW.organization_id
           AND quotation.billing_purpose = 'BuildingService'
           AND quotation.organization_id = NEW.organization_id
           AND item.building_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'payment provisioning record requires an Applied BuildingService payment and valid quotation line for the same organization and quotation';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.payment_transaction_id IS DISTINCT FROM NEW.payment_transaction_id
        OR OLD.quotation_id IS DISTINCT FROM NEW.quotation_id
        OR OLD.quotation_item_id IS DISTINCT FROM NEW.quotation_item_id
        OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.provisioning_key IS DISTINCT FROM NEW.provisioning_key
    ) THEN
        RAISE EXCEPTION 'payment provisioning provenance is immutable';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_organization_notification_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND (
        OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.recipient_user_id IS DISTINCT FROM NEW.recipient_user_id
        OR OLD.building_id IS DISTINCT FROM NEW.building_id
        OR OLD.entitlement_id IS DISTINCT FROM NEW.entitlement_id
        OR OLD.notification_type IS DISTINCT FROM NEW.notification_type
        OR OLD.reference_ends_at IS DISTINCT FROM NEW.reference_ends_at
    ) THEN
        RAISE EXCEPTION 'notification identity and tenant scope are immutable';
    END IF;
    IF NEW.notification_type <> 'BuildingServiceExpiring'
       OR NOT EXISTS (
            SELECT 1
              FROM public.users AS recipient
             WHERE recipient.id = NEW.recipient_user_id
               AND recipient.organization_id = NEW.organization_id
               AND recipient.role = 'OrganizationUser'
       )
       OR NOT EXISTS (
            SELECT 1
              FROM public.buildings AS building
             WHERE building.id = NEW.building_id
               AND building.organization_id = NEW.organization_id
       )
       OR NOT EXISTS (
            SELECT 1
              FROM public.service_entitlements AS entitlement
             WHERE entitlement.id = NEW.entitlement_id
               AND entitlement.organization_id = NEW.organization_id
               AND entitlement.building_id = NEW.building_id
               AND entitlement.ends_at = NEW.reference_ends_at
       ) THEN
        RAISE EXCEPTION 'expiry notification recipient, Building and entitlement must share the organization and expiry';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_training_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.releases AS release
        JOIN public.scenario_versions AS scenario
          ON scenario.id = NEW.scenario_version_id
         AND scenario.revision_id = release.revision_id
        WHERE release.id = NEW.release_id
          AND release.scenario_version_id = NEW.scenario_version_id
          AND release.organization_id = NEW.organization_id
          AND release.status IN ('Built', 'Published')
    ) THEN
        RAISE EXCEPTION 'training requires the matching Built or Published release, scenario and organization';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.users AS creator
        WHERE creator.id = NEW.created_by
          AND creator.role = 'OrganizationUser'
          AND creator.organization_id = NEW.organization_id
          AND creator.is_active
          AND creator.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'created_by must be an active OrganizationUser for the training organization';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_release_qr_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.buildings AS building
        WHERE building.id = NEW.building_id
          AND building.organization_id = NEW.organization_id
          AND building.is_active
          AND building.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'QR building must belong to an active building in the QR organization';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.users AS creator
        WHERE creator.id = NEW.created_by
          AND creator.role = 'OrganizationUser'
          AND creator.organization_id = NEW.organization_id
          AND creator.is_active
          AND creator.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'created_by must be an active OrganizationUser for the QR organization';
    END IF;

    IF NEW.floor_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.building_floors AS floor
        WHERE floor.id = NEW.floor_id
          AND floor.building_id = NEW.building_id
          AND floor.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'floor_id must belong to the QR building and organization';
    END IF;

    IF NEW.is_active AND NOT EXISTS (
        SELECT 1 FROM public.buildings AS building
        WHERE building.id = NEW.building_id AND building.is_active
    ) THEN
        RAISE EXCEPTION 'an active QR requires an active building';
    END IF;

    IF NEW.is_active
       AND NEW.expires_at IS NOT NULL
       AND NEW.expires_at <= pg_catalog.now() THEN
        RAISE EXCEPTION 'an active QR cannot already be expired';
    END IF;

    IF TG_OP = 'UPDATE' AND (
        NEW.building_id IS DISTINCT FROM OLD.building_id
        OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
        OR NEW.qr_hash IS DISTINCT FROM OLD.qr_hash
    ) THEN
        RAISE EXCEPTION 'Building QR identity and tenant are immutable; rotate by creating a new QR';
    END IF;

    RETURN NEW;
END;
$$;

-- Kiểm tra dữ liệu session preparation đã pin sau khi người chơi chọn một
-- Training từ Building QR. Entitlement online chỉ được kiểm tra bởi explicit
-- start function; session đang chạy vẫn có thể hoàn tất sau khi hết hạn.
CREATE OR REPLACE FUNCTION validate_training_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = NEW.trainee_user_id
          AND u.role = 'Trainee'
          AND u.is_active
          AND u.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'trainee_user_id must reference an active Trainee';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.user_devices d
        WHERE d.id = NEW.device_id
          AND d.user_id = NEW.trainee_user_id
    ) THEN
        RAISE EXCEPTION 'device_id must belong to trainee_user_id';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.release_qr_codes q
        JOIN public.trainings t ON t.id = NEW.training_id
        JOIN public.releases r ON r.id = NEW.release_id
        WHERE q.id = NEW.qr_code_id
          AND q.building_id = r.building_id
          AND q.organization_id = NEW.organization_id
          AND q.is_active
          AND (q.expires_at IS NULL OR q.expires_at > pg_catalog.now())
          AND t.release_id = NEW.release_id
          AND t.scenario_version_id = NEW.scenario_version_id
          AND t.organization_id = NEW.organization_id
          AND t.status = 'Active'
          AND NEW.mode::TEXT = ANY(t.allowed_modes)
          AND r.status = 'Published'
          AND r.scenario_version_id = NEW.scenario_version_id
          AND r.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'session requires the selected Active Training, Published release, scenario, organization and active Building QR';
    END IF;

    IF NULLIF(pg_catalog.btrim(NEW.package_hash), '') IS NULL
       OR NEW.package_artifact_id IS NULL OR NEW.package_validation_run_id IS NULL THEN
        RAISE EXCEPTION 'session preparation requires a verified package, artifact and validation pin';
    END IF;
    IF NULLIF(pg_catalog.btrim(NEW.manifest_sha256), '') IS NULL
       OR NULLIF(pg_catalog.btrim(NEW.build_target), '') IS NULL THEN
        RAISE EXCEPTION 'session preparation requires a manifest hash and build target';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.release_packages AS package
        WHERE package.release_id = NEW.release_id
          AND package.candidate_artifact_id = NEW.package_artifact_id
          AND package.candidate_validation_run_id = NEW.package_validation_run_id
          AND package.checksum_sha256 = NEW.package_hash
          AND package.manifest_sha256 = NEW.manifest_sha256
          AND package.build_target = NEW.build_target
          AND package.protocol_version = NEW.protocol_version
          AND package.manifest_schema_version = NEW.manifest_schema_version
    ) THEN
        RAISE EXCEPTION 'session package metadata does not match the pinned release package';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.validation_runs AS run
        JOIN public.releases AS release ON release.id = NEW.release_id
         WHERE run.id = NEW.package_validation_run_id
           AND run.release_id = NEW.release_id
           AND run.revision_id = release.revision_id
           AND run.artifact_id = NEW.package_artifact_id
           AND run.scope = 'ReleasePackage'
           AND run.status = 'Passed'
    ) THEN
        RAISE EXCEPTION 'session preparation requires the pinned passed package validation run';
    END IF;

    RETURN NEW;
END;
$$;


-- State machine bất biến cho payment provenance. Chỉ trusted SECURITY DEFINER
-- webhook function chạy dưới ledger owner mới được ghi ledger; INSERT chỉ tạo
-- Received và các bước Received -> Verified -> Applied/Rejected phải tuần tự.
CREATE OR REPLACE FUNCTION enforce_payment_transaction_state()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Payment transaction provenance is append-only';
    END IF;

    IF CURRENT_USER != 'fet3d_payos_ledger_owner' THEN
        RAISE EXCEPTION 'Payment transaction writes must use trusted PayOS webhook function';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.status != 'Received'
           OR NEW.signature_verified
           OR NEW.signature_verified_at IS NOT NULL
           OR NEW.processed_at IS NOT NULL
           OR NEW.rejection_reason IS NOT NULL THEN
            RAISE EXCEPTION 'Payment transaction must be inserted as unverified Received';
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.status IN ('Applied', 'Rejected') THEN
        IF NEW IS DISTINCT FROM OLD THEN
            RAISE EXCEPTION 'Applied or Rejected payment provenance is immutable';
        END IF;
        RETURN NEW;
    END IF;

    IF OLD.id IS DISTINCT FROM NEW.id
       OR OLD.payment_request_id IS DISTINCT FROM NEW.payment_request_id
       OR OLD.webhook_event_id IS DISTINCT FROM NEW.webhook_event_id
       OR OLD.provider_transaction_id IS DISTINCT FROM NEW.provider_transaction_id
       OR OLD.received_order_code IS DISTINCT FROM NEW.received_order_code
       OR OLD.received_amount IS DISTINCT FROM NEW.received_amount
       OR OLD.received_currency IS DISTINCT FROM NEW.received_currency
       OR OLD.raw_payload IS DISTINCT FROM NEW.raw_payload
       OR OLD.received_at IS DISTINCT FROM NEW.received_at THEN
        RAISE EXCEPTION 'Payment webhook identity and received payload are immutable';
    END IF;

    IF OLD.status = 'Received' AND NEW.status = 'Verified' THEN
        RETURN NEW;
    END IF;

    IF OLD.status = 'Verified' AND NEW.status IN ('Applied', 'Rejected') THEN
        IF NOT NEW.signature_verified
           OR NEW.signature_verified_at IS DISTINCT FROM OLD.signature_verified_at THEN
            RAISE EXCEPTION 'Verified signature provenance cannot be removed or replaced';
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Invalid payment transaction transition: % -> %', OLD.status, NEW.status;
END;
$$ LANGUAGE plpgsql;

-- Paid chỉ được ghi khi transaction của chính request đã Applied sau verified webhook
-- và ba giá trị orderCode, amount, currency khớp hoàn toàn với request mong đợi.

-- Runtime payment creation path. The backend calls PayOS outside any DB transaction,
-- then invokes this short function with the returned HTTPS checkout URL. Amount,
-- currency and organization are derived from the locked Accepted quotation; callers
-- cannot choose them or create a status other than Pending.
CREATE OR REPLACE FUNCTION create_pending_payos_payment_request(
    p_quotation_id UUID,
    p_requested_by UUID,
    p_idempotency_key TEXT,
    p_order_code BIGINT,
    p_checkout_url TEXT,
    p_return_url TEXT,
    p_cancel_url TEXT,
    p_expires_at TIMESTAMPTZ
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
    v_payment_request_id UUID;
BEGIN
    IF p_quotation_id IS NULL OR p_requested_by IS NULL THEN
        RAISE EXCEPTION 'quotation_id and requested_by are required';
    END IF;
    IF NULLIF(pg_catalog.btrim(p_idempotency_key), '') IS NULL THEN
        RAISE EXCEPTION 'payment request idempotency key is required';
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('fet3d:payos:' || pg_catalog.btrim(p_idempotency_key), 0)
    );
    SELECT request.id INTO v_payment_request_id
    FROM public.payos_payment_requests AS request
    WHERE request.idempotency_key = pg_catalog.btrim(p_idempotency_key)
    FOR UPDATE;
    IF FOUND THEN
        IF NOT EXISTS (
            SELECT 1
            FROM public.payos_payment_requests AS request
            WHERE request.id = v_payment_request_id
              AND request.quotation_id = p_quotation_id
              AND request.requested_by = p_requested_by
              AND request.order_code = p_order_code
              AND request.checkout_url = pg_catalog.btrim(p_checkout_url)
              AND request.return_url = pg_catalog.btrim(p_return_url)
              AND request.cancel_url = pg_catalog.btrim(p_cancel_url)
              AND request.expires_at IS NOT DISTINCT FROM p_expires_at
        ) THEN
            RAISE EXCEPTION 'payment request idempotency key was reused for different input';
        END IF;
        RETURN v_payment_request_id;
    END IF;
    IF p_order_code IS NULL OR p_order_code <= 0 THEN
        RAISE EXCEPTION 'orderCode must be a positive integer';
    END IF;
    IF NULLIF(pg_catalog.btrim(p_checkout_url), '') IS NULL
       OR pg_catalog.char_length(pg_catalog.btrim(p_checkout_url)) > 2048
       OR pg_catalog.btrim(p_checkout_url) !~ '^https://[^[:space:]]+$' THEN
        RAISE EXCEPTION 'checkout_url must be a non-empty HTTPS URL up to 2048 characters';
    END IF;
    IF NULLIF(pg_catalog.btrim(p_return_url), '') IS NULL
       OR pg_catalog.char_length(pg_catalog.btrim(p_return_url)) > 2048
       OR pg_catalog.btrim(p_return_url) !~ '^https://[^[:space:]]+$' THEN
        RAISE EXCEPTION 'return_url must be a non-empty HTTPS navigation URL up to 2048 characters';
    END IF;
    IF NULLIF(pg_catalog.btrim(p_cancel_url), '') IS NULL
       OR pg_catalog.char_length(pg_catalog.btrim(p_cancel_url)) > 2048
       OR pg_catalog.btrim(p_cancel_url) !~ '^https://[^[:space:]]+$' THEN
        RAISE EXCEPTION 'cancel_url must be a non-empty HTTPS navigation URL up to 2048 characters';
    END IF;
    IF p_expires_at IS NULL OR p_expires_at <= pg_catalog.now() THEN
        RAISE EXCEPTION 'expires_at must be in the future';
    END IF;

    PERFORM 1 FROM public.quotations AS quotation
     WHERE quotation.id = p_quotation_id
     FOR UPDATE;

    INSERT INTO public.payos_payment_requests (
        quotation_id,
        organization_id,
        requested_by,
        idempotency_key,
        order_code,
        expected_amount,
        expected_currency,
        checkout_url,
        return_url,
        cancel_url,
        status,
        expires_at
    )
    SELECT quotation.id,
           quotation.organization_id,
           p_requested_by,
           pg_catalog.btrim(p_idempotency_key),
           p_order_code,
           quotation.total_amount,
           quotation.currency,
           pg_catalog.btrim(p_checkout_url),
           pg_catalog.btrim(p_return_url),
           pg_catalog.btrim(p_cancel_url),
           'Pending'::public.payment_request_status_enum,
           p_expires_at
    FROM public.quotations AS quotation
    JOIN public.users AS requester ON requester.id = p_requested_by
    WHERE quotation.id = p_quotation_id
      AND quotation.status = 'Accepted'
      AND quotation.valid_until > pg_catalog.now()
      AND quotation.total_amount > 0
      AND requester.role = 'OrganizationUser'
      AND requester.organization_id = quotation.organization_id
      AND requester.is_active
      AND requester.deleted_at IS NULL
    RETURNING id INTO v_payment_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'payment request requires an unexpired Accepted quotation and active OrganizationUser in the same organization';
    END IF;

    RETURN v_payment_request_id;
END;
$$;

COMMENT ON FUNCTION create_pending_payos_payment_request(
    UUID, UUID, TEXT, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) IS
'Creates only Pending PayOS requests from an Accepted quotation after the backend completes the external PayOS call; retries use the supplied idempotency key and returnUrl remains navigation-only.';

-- TRUST BOUNDARY: before invoking this function, the backend adapter must use
-- the official PayOS SDK webhooks.verify(req.body), or the official equivalent
-- that canonicalizes webhook data by alphabetically sorting the data fields and
-- verifies the resulting signature. Do not verify against raw HTTP request bytes.
-- This SECURITY DEFINER function performs no cryptography; it records the trusted
-- adapter attestation, enforces idempotency and checks orderCode/amount/currency.
-- It accepts no caller-supplied signature flag. Only the dedicated webhook executor
-- may execute it, and that role has no direct DML on either payment table.
CREATE OR REPLACE FUNCTION apply_verified_payos_webhook(
    p_payment_request_id UUID,
    p_webhook_event_id TEXT,
    p_provider_transaction_id TEXT,
    p_received_order_code BIGINT,
    p_received_amount NUMERIC,
    p_received_currency TEXT,
    p_raw_payload JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
    v_existing       public.payment_transactions%ROWTYPE;
    v_request        public.payos_payment_requests%ROWTYPE;
    v_transaction    public.payment_transactions%ROWTYPE;
    v_verified_at    TIMESTAMPTZ;
    v_processed_at   TIMESTAMPTZ;
    v_rejection      TEXT;
BEGIN
    IF p_payment_request_id IS NULL THEN
        RAISE EXCEPTION 'payment_request_id is required';
    END IF;
    IF NULLIF(pg_catalog.btrim(p_webhook_event_id), '') IS NULL THEN
        RAISE EXCEPTION 'webhook_event_id is required';
    END IF;
    IF pg_catalog.char_length(pg_catalog.btrim(p_webhook_event_id)) > 255 THEN
        RAISE EXCEPTION 'webhook_event_id is too long';
    END IF;
    IF p_provider_transaction_id IS NOT NULL AND (
        NULLIF(pg_catalog.btrim(p_provider_transaction_id), '') IS NULL
        OR pg_catalog.char_length(pg_catalog.btrim(p_provider_transaction_id)) > 255
    ) THEN
        RAISE EXCEPTION 'provider_transaction_id must be non-empty and at most 255 characters when supplied';
    END IF;
    IF p_received_order_code IS NULL
       OR p_received_amount IS NULL
       OR p_received_currency IS NULL
       OR p_raw_payload IS NULL THEN
        RAISE EXCEPTION 'orderCode, amount, currency and raw payload are required';
    END IF;
    IF p_received_order_code <= 0 OR p_received_amount <= 0 THEN
        RAISE EXCEPTION 'orderCode and amount must be positive';
    END IF;
    IF p_received_currency !~ '^[A-Z]{3}$' THEN
        RAISE EXCEPTION 'currency must be a three-letter uppercase code';
    END IF;
    IF pg_catalog.jsonb_typeof(p_raw_payload) != 'object' THEN
        RAISE EXCEPTION 'raw payload must be a JSON object';
    END IF;

    -- Serialize identical webhook events before checking/inserting the idempotency key.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(p_webhook_event_id, 0)
    );

    SELECT transaction.*
    INTO v_existing
    FROM public.payment_transactions AS transaction
    WHERE transaction.webhook_event_id = p_webhook_event_id;

    IF FOUND THEN
        IF v_existing.payment_request_id IS DISTINCT FROM p_payment_request_id
           OR v_existing.provider_transaction_id IS DISTINCT FROM p_provider_transaction_id
           OR v_existing.received_order_code IS DISTINCT FROM p_received_order_code
           OR v_existing.received_amount IS DISTINCT FROM p_received_amount
           OR v_existing.received_currency IS DISTINCT FROM p_received_currency
           OR v_existing.raw_payload IS DISTINCT FROM p_raw_payload THEN
            RAISE EXCEPTION 'webhook_event_id was already used with different payment data';
        END IF;

        IF v_existing.status NOT IN ('Applied', 'Rejected') THEN
            RAISE EXCEPTION 'webhook_event_id exists in a non-terminal state; privileged intervention required';
        END IF;

        RETURN v_existing.id;
    END IF;

    SELECT request.*
    INTO v_request
    FROM public.payos_payment_requests AS request
    WHERE request.id = p_payment_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'payment request % does not exist', p_payment_request_id;
    END IF;
    IF v_request.status != 'Pending' THEN
        RAISE EXCEPTION 'payment request % is not Pending', p_payment_request_id;
    END IF;

    INSERT INTO public.payment_transactions (
        payment_request_id,
        webhook_event_id,
        provider_transaction_id,
        received_order_code,
        received_amount,
        received_currency,
        raw_payload
    )
    VALUES (
        p_payment_request_id,
        p_webhook_event_id,
        p_provider_transaction_id,
        p_received_order_code,
        p_received_amount,
        p_received_currency,
        p_raw_payload
    )
    RETURNING * INTO v_transaction;

    v_verified_at := pg_catalog.clock_timestamp();
    UPDATE public.payment_transactions
    SET status = 'Verified',
        signature_verified = true,
        signature_verified_at = v_verified_at
    WHERE id = v_transaction.id
    RETURNING * INTO v_transaction;

    v_processed_at := pg_catalog.clock_timestamp();
    IF v_transaction.received_order_code IS DISTINCT FROM v_request.order_code
       OR v_transaction.received_amount IS DISTINCT FROM v_request.expected_amount
       OR v_transaction.received_currency IS DISTINCT FROM v_request.expected_currency THEN
        v_rejection := pg_catalog.format(
            'Verified PayOS webhook does not match expected orderCode, amount or currency'
        );
        UPDATE public.payment_transactions
        SET status = 'Rejected',
            rejection_reason = v_rejection,
            processed_at = v_processed_at
        WHERE id = v_transaction.id;
        RETURN v_transaction.id;
    END IF;

    UPDATE public.payment_transactions
    SET status = 'Applied',
        processed_at = v_processed_at
    WHERE id = v_transaction.id;

    UPDATE public.payos_payment_requests
    SET status = 'Paid',
        paid_transaction_id = v_transaction.id,
        paid_at = v_processed_at
    WHERE id = v_request.id;

    RETURN v_transaction.id;
END;
$$;

CREATE TRIGGER validate_revision_review_before_insert
BEFORE INSERT ON revision_reviews
FOR EACH ROW EXECUTE FUNCTION validate_revision_review_action();

CREATE TRIGGER apply_revision_review_after_insert
AFTER INSERT ON revision_reviews
FOR EACH ROW EXECUTE FUNCTION apply_revision_review_action();

CREATE TRIGGER enforce_revision_status_before_write
BEFORE INSERT OR UPDATE OF status ON revisions
FOR EACH ROW EXECUTE FUNCTION enforce_revision_status_transition();

CREATE TRIGGER validate_scenario_version_before_write
BEFORE INSERT OR UPDATE OF scenario_id, revision_id, building_id, organization_id,
    version_number, name, schema_version, algorithm_version, random_seed,
    spawn_config, goal_config, fire_source_config, smoke_config, wind_config,
    interaction_anchors, npc_config, blocked_elements, guidance_level,
    safety_thresholds, time_limit_seconds,
    routing_config, scoring_config, mode_policy, scenario_hash, created_by
ON scenario_versions FOR EACH ROW EXECUTE FUNCTION validate_scenario_version_write();

CREATE TRIGGER validate_release_before_write
BEFORE INSERT OR UPDATE OF revision_id, scenario_version_id, building_id,
    organization_id, published_by, revoked_by, status, safety_thresholds,
    revoked_reason, published_at
ON releases FOR EACH ROW EXECUTE FUNCTION validate_release_write();

CREATE TRIGGER validate_service_entitlement_before_write
BEFORE INSERT OR UPDATE OF organization_id, building_id, service_package_id,
    quotation_id, payment_transaction_id, provisioning_key, status, starts_at, ends_at,
    price_snapshot, terms_snapshot, created_by, quotation_item_id
ON service_entitlements FOR EACH ROW EXECUTE FUNCTION validate_service_entitlement_write();

CREATE TRIGGER validate_training_before_write
BEFORE INSERT OR UPDATE OF release_id, scenario_version_id, organization_id,
    status, created_by
ON trainings FOR EACH ROW EXECUTE FUNCTION validate_training_write();

CREATE TRIGGER validate_release_qr_before_write
BEFORE INSERT OR UPDATE OF building_id, organization_id, floor_id, created_by,
    qr_hash, expires_at, is_active
ON release_qr_codes FOR EACH ROW EXECUTE FUNCTION validate_release_qr_code();

CREATE TRIGGER validate_session_before_write
BEFORE INSERT OR UPDATE OF training_id, release_id, scenario_version_id, organization_id,
    trainee_user_id, device_id, qr_code_id, mode, package_hash, protocol_version, manifest_schema_version
ON sessions FOR EACH ROW EXECUTE FUNCTION validate_training_session();

CREATE TRIGGER validate_ai_quota_grant_before_write
BEFORE INSERT OR UPDATE OF organization_id, building_id, trainee_user_id, audience,
    quota_kind, starts_at, ends_at
ON ai_quota_grants FOR EACH ROW EXECUTE FUNCTION validate_ai_quota_grant_write();

CREATE TRIGGER validate_payment_provisioning_before_write
BEFORE INSERT OR UPDATE OF payment_transaction_id, quotation_id, organization_id,
    quotation_item_id, provisioning_key, status
ON payment_provisioning_records FOR EACH ROW EXECUTE FUNCTION validate_payment_provisioning_write();

CREATE TRIGGER validate_organization_notification_before_write
BEFORE INSERT OR UPDATE OF organization_id, recipient_user_id, building_id,
    entitlement_id, notification_type, reference_ends_at
ON organization_notifications FOR EACH ROW EXECUTE FUNCTION validate_organization_notification_write();

CREATE TRIGGER enforce_payment_transaction_state_before_write
BEFORE INSERT OR UPDATE OR DELETE
ON payment_transactions FOR EACH ROW EXECUTE FUNCTION enforce_payment_transaction_state();

CREATE TRIGGER validate_learn_situation_before_write
BEFORE INSERT OR UPDATE ON learn_situations
FOR EACH ROW EXECUTE FUNCTION validate_learn_editorial_write();

CREATE TRIGGER validate_learn_post_before_write
BEFORE INSERT OR UPDATE OR DELETE ON learn_posts
FOR EACH ROW EXECUTE FUNCTION validate_learn_editorial_write();

CREATE TRIGGER validate_learn_post_version_before_write
BEFORE INSERT OR UPDATE OR DELETE ON learn_post_versions
FOR EACH ROW EXECUTE FUNCTION validate_learn_editorial_write();

CREATE TRIGGER validate_learn_version_situation_before_write
BEFORE INSERT OR UPDATE OR DELETE ON learn_post_version_situations
FOR EACH ROW EXECUTE FUNCTION validate_learn_editorial_write();

CREATE TRIGGER validate_learn_source_link_before_write
BEFORE INSERT OR UPDATE OR DELETE ON learn_post_version_sources
FOR EACH ROW EXECUTE FUNCTION validate_learn_editorial_write();

CREATE TRIGGER validate_learn_bookmark_before_write
BEFORE INSERT OR DELETE ON learn_bookmarks
FOR EACH ROW EXECUTE FUNCTION validate_learn_bookmark_write();

CREATE TRIGGER set_ts_learn_situations BEFORE UPDATE ON learn_situations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_learn_posts BEFORE UPDATE ON learn_posts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_learn_post_versions BEFORE UPDATE ON learn_post_versions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_ts_organizations BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_users BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_buildings BEFORE UPDATE ON buildings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_building_floors BEFORE UPDATE ON building_floors FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_building_contacts BEFORE UPDATE ON building_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_revisions BEFORE UPDATE ON revisions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_releases BEFORE UPDATE ON releases FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_scenario_versions BEFORE UPDATE ON scenario_versions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_trainings BEFORE UPDATE ON trainings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_session_results BEFORE UPDATE ON session_results FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_service_packages BEFORE UPDATE ON service_packages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_quotations BEFORE UPDATE ON quotations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_payos_payment_requests BEFORE UPDATE ON payos_payment_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_payment_provisioning_records BEFORE UPDATE ON payment_provisioning_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_invoice_metadata BEFORE UPDATE ON invoice_metadata FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_feedback BEFORE UPDATE ON feedback FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_support_tickets BEFORE UPDATE ON support_tickets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Đảm bảo Audit Log là bảng bất biến (Append-only)
CREATE RULE prevent_update_audit_logs AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
CREATE RULE prevent_delete_audit_logs AS ON DELETE TO audit_logs DO INSTEAD NOTHING;

-- ==============================================================================
-- SECTION 7: PAYOS LEDGER PRIVILEGE BOUNDARY
-- ==============================================================================
-- This bootstrap requires a migration role with CREATEROLE and ownership of the
-- objects above (normally a deployment superuser). Runtime login roles receive
-- neither table ownership nor inheritance from fet3d_payos_ledger_owner. The trusted
-- checkout adapter receives only fet3d_payos_request_executor; the independently
-- trusted webhook adapter receives only fet3d_payos_webhook_executor. A deployment
-- may grant both roles to one backend login only if it owns both adapter duties;
-- never grant either executor role to browser/mobile/user-facing logins.
DO $roles$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_payos_ledger_owner'
    ) THEN
        CREATE ROLE fet3d_payos_ledger_owner
            NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_payos_webhook_executor'
    ) THEN
        CREATE ROLE fet3d_payos_webhook_executor
            NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_payos_request_executor'
    ) THEN
        CREATE ROLE fet3d_payos_request_executor
            NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
END;
$roles$;

ALTER TABLE payos_payment_requests OWNER TO fet3d_payos_ledger_owner;
ALTER TABLE payment_transactions OWNER TO fet3d_payos_ledger_owner;
ALTER FUNCTION create_pending_payos_payment_request(
    UUID, UUID, TEXT, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) OWNER TO fet3d_payos_ledger_owner;
ALTER FUNCTION apply_verified_payos_webhook(UUID, TEXT, TEXT, BIGINT, NUMERIC, TEXT, JSONB)
    OWNER TO fet3d_payos_ledger_owner;

REVOKE ALL PRIVILEGES ON TABLE payos_payment_requests FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE payment_transactions FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE payos_payment_requests FROM fet3d_payos_request_executor;
REVOKE ALL PRIVILEGES ON TABLE payment_transactions FROM fet3d_payos_request_executor;
REVOKE ALL PRIVILEGES ON TABLE payos_payment_requests FROM fet3d_payos_webhook_executor;
REVOKE ALL PRIVILEGES ON TABLE payment_transactions FROM fet3d_payos_webhook_executor;
REVOKE ALL PRIVILEGES ON FUNCTION create_pending_payos_payment_request(
    UUID, UUID, TEXT, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION apply_verified_payos_webhook(
    UUID, TEXT, TEXT, BIGINT, NUMERIC, TEXT, JSONB
) FROM PUBLIC;

GRANT USAGE ON SCHEMA public
TO fet3d_payos_request_executor, fet3d_payos_webhook_executor, fet3d_payos_ledger_owner;
GRANT SELECT (id, organization_id, status, total_amount, currency, valid_until)
ON TABLE quotations TO fet3d_payos_ledger_owner;
-- PostgreSQL requires UPDATE privilege for SELECT ... FOR UPDATE. The ledger
-- owner is NOLOGIN and receives only this minimal column privilege; the
-- request/webhook executors do not inherit it or receive quotation DML.
GRANT UPDATE (id) ON TABLE quotations TO fet3d_payos_ledger_owner;
GRANT SELECT (id, organization_id, role, is_active, deleted_at)
ON TABLE users TO fet3d_payos_ledger_owner;
GRANT EXECUTE ON FUNCTION create_pending_payos_payment_request(
    UUID, UUID, TEXT, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) TO fet3d_payos_request_executor;
GRANT EXECUTE ON FUNCTION apply_verified_payos_webhook(
    UUID, TEXT, TEXT, BIGINT, NUMERIC, TEXT, JSONB
) TO fet3d_payos_webhook_executor;

-- ============================================================================
-- VERSION 6.7 TARGET DESIGN AMENDMENTS
-- Runtime compatibility, actor-bound start, atomic AI quota reservation,
-- durable dispatch and payment/settlement recovery. This is design DDL only;
-- it is not a migration for an existing database.
-- ============================================================================

-- Server-owned runtime catalog. Client-reported capabilities are never trusted
-- as authorization for a package.
CREATE TABLE runtime_compatibility_catalog (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    runtime_version         VARCHAR(50) NOT NULL,
    protocol_version        VARCHAR(50) NOT NULL,
    manifest_schema_version VARCHAR(50) NOT NULL,
    capabilities            JSONB NOT NULL DEFAULT '[]',
    is_active               BOOLEAN NOT NULL DEFAULT true,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_runtime_catalog_version
        CHECK (runtime_version ~ '^[0-9]+[.][0-9]+[.][0-9]+$'),
    CONSTRAINT check_runtime_catalog_protocol
        CHECK (NULLIF(pg_catalog.btrim(protocol_version), '') IS NOT NULL),
    CONSTRAINT check_runtime_catalog_manifest_schema
        CHECK (NULLIF(pg_catalog.btrim(manifest_schema_version), '') IS NOT NULL),
    CONSTRAINT check_runtime_catalog_capabilities
        CHECK (jsonb_typeof(capabilities) = 'array'),
    UNIQUE (runtime_version, protocol_version, manifest_schema_version)
);

ALTER TABLE release_packages
    ADD COLUMN required_capabilities JSONB NOT NULL DEFAULT '[]',
    ADD COLUMN build_target VARCHAR(50) NOT NULL,
    ADD CONSTRAINT check_release_package_capabilities
        CHECK (jsonb_typeof(required_capabilities) = 'array'),
    ADD CONSTRAINT check_release_package_build_target
        CHECK (NULLIF(pg_catalog.btrim(build_target), '') IS NOT NULL);

ALTER TABLE release_packages
    ALTER COLUMN required_capabilities DROP DEFAULT,
    ADD CONSTRAINT check_release_package_runtime_metadata
        CHECK (
            NULLIF(pg_catalog.btrim(protocol_version), '') IS NOT NULL
            AND NULLIF(pg_catalog.btrim(manifest_schema_version), '') IS NOT NULL
            AND min_runtime_version ~ '^[0-9]+[.][0-9]+[.][0-9]+$'
        );

ALTER TABLE sessions
    ADD COLUMN runtime_catalog_id UUID REFERENCES runtime_compatibility_catalog(id) ON DELETE RESTRICT;

ALTER TABLE sessions
    ADD COLUMN manifest_sha256 VARCHAR(64),
    ADD COLUMN build_target VARCHAR(50),
    ADD CONSTRAINT check_session_manifest_hash
        CHECK (manifest_sha256 IS NULL OR manifest_sha256 ~ '^[0-9a-fA-F]{64}$'),
    ADD CONSTRAINT check_session_build_target
        CHECK (build_target IS NULL OR NULLIF(pg_catalog.btrim(build_target), '') IS NOT NULL);

ALTER TABLE playtest_sessions
    ADD COLUMN runtime_catalog_id UUID REFERENCES runtime_compatibility_catalog(id) ON DELETE RESTRICT,
    ADD COLUMN manifest_sha256 VARCHAR(64),
    ADD COLUMN build_target VARCHAR(50),
    ADD CONSTRAINT check_playtest_manifest_hash
        CHECK (manifest_sha256 IS NULL OR manifest_sha256 ~ '^[0-9a-fA-F]{64}$'),
    ADD CONSTRAINT check_playtest_build_target
        CHECK (build_target IS NULL OR NULLIF(pg_catalog.btrim(build_target), '') IS NOT NULL);

ALTER TABLE sessions
    ALTER COLUMN protocol_version DROP DEFAULT,
    ALTER COLUMN manifest_schema_version DROP DEFAULT;
ALTER TABLE playtest_sessions
    ALTER COLUMN protocol_version DROP DEFAULT,
    ALTER COLUMN manifest_schema_version DROP DEFAULT;

CREATE OR REPLACE FUNCTION fet3d_semver_gte(p_actual TEXT, p_minimum TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog
AS $$
DECLARE
    a TEXT[];
    m TEXT[];
BEGIN
    a := pg_catalog.regexp_match(pg_catalog.btrim(p_actual), '^([0-9]+)[.]([0-9]+)[.]([0-9]+)$');
    m := pg_catalog.regexp_match(pg_catalog.btrim(p_minimum), '^([0-9]+)[.]([0-9]+)[.]([0-9]+)$');
    IF a IS NULL OR m IS NULL THEN RETURN false; END IF;
    RETURN ROW(a[1]::BIGINT, a[2]::BIGINT, a[3]::BIGINT)
        >= ROW(m[1]::BIGINT, m[2]::BIGINT, m[3]::BIGINT);
END;
$$;

CREATE OR REPLACE FUNCTION enforce_session_preparation_state()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND (
        NEW.status <> 'Created' OR NEW.start_idempotency_key IS NOT NULL
        OR NEW.launch_granted_at IS NOT NULL OR NEW.started_at IS NOT NULL
    ) THEN
         RAISE EXCEPTION 'a prepared session must start in Created state without a launch grant';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION enforce_playtest_preparation_state()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND (
        NEW.status <> 'Created' OR NEW.start_idempotency_key IS NOT NULL OR NEW.started_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'a prepared playtest must start in Created state without a start key';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_training_session_lifecycle()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status = 'Created'
       AND (
           NEW.status <> 'Created'
           OR OLD.start_idempotency_key IS DISTINCT FROM NEW.start_idempotency_key
           OR OLD.launch_granted_at IS DISTINCT FROM NEW.launch_granted_at
           OR OLD.runtime_version IS DISTINCT FROM NEW.runtime_version
           OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
           OR OLD.build_target IS DISTINCT FROM NEW.build_target
           OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
           OR OLD.runtime_catalog_id IS DISTINCT FROM NEW.runtime_catalog_id
       )
       AND (CURRENT_USER <> 'fet3d_session_owner'
            OR COALESCE(pg_catalog.current_setting('fet3d.session_start_id', true), '') <> NEW.id::TEXT) THEN
        RAISE EXCEPTION 'only actor-bound online start may launch a session';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.training_id IS DISTINCT FROM NEW.training_id
        OR OLD.release_id IS DISTINCT FROM NEW.release_id
        OR OLD.scenario_version_id IS DISTINCT FROM NEW.scenario_version_id
        OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.trainee_user_id IS DISTINCT FROM NEW.trainee_user_id
        OR OLD.device_id IS DISTINCT FROM NEW.device_id
        OR OLD.qr_code_id IS DISTINCT FROM NEW.qr_code_id
        OR OLD.mode IS DISTINCT FROM NEW.mode
        OR OLD.package_hash IS DISTINCT FROM NEW.package_hash
        OR OLD.package_artifact_id IS DISTINCT FROM NEW.package_artifact_id
        OR OLD.package_validation_run_id IS DISTINCT FROM NEW.package_validation_run_id
        OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
        OR OLD.build_target IS DISTINCT FROM NEW.build_target
        OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
        OR OLD.manifest_schema_version IS DISTINCT FROM NEW.manifest_schema_version
        OR OLD.prepare_idempotency_key IS DISTINCT FROM NEW.prepare_idempotency_key
        OR (OLD.start_idempotency_key IS NOT NULL AND OLD.start_idempotency_key IS DISTINCT FROM NEW.start_idempotency_key)
        OR (OLD.launch_granted_at IS NOT NULL AND OLD.launch_granted_at IS DISTINCT FROM NEW.launch_granted_at)
        OR (OLD.started_at IS NOT NULL AND OLD.started_at IS DISTINCT FROM NEW.started_at)
         OR ((CURRENT_USER <> 'fet3d_session_owner'
              OR COALESCE(pg_catalog.current_setting('fet3d.session_start_id', true), '') <> NEW.id::TEXT)
             AND (OLD.runtime_version IS DISTINCT FROM NEW.runtime_version
                  OR OLD.runtime_catalog_id IS DISTINCT FROM NEW.runtime_catalog_id
                  OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
                  OR OLD.build_target IS DISTINCT FROM NEW.build_target))
    ) THEN
        RAISE EXCEPTION 'session identity, package and preparation key are immutable after preparation';
    END IF;
    IF NEW.status IN ('Launching','Running') AND (NEW.launch_granted_at IS NULL OR NEW.start_idempotency_key IS NULL) THEN
        RAISE EXCEPTION 'Launching or Running requires an online start grant and idempotency key';
    END IF;
    IF NEW.status = 'Running' AND NEW.started_at IS NULL THEN
        RAISE EXCEPTION 'Running requires started_at from the Unity bridge';
    END IF;
    IF NEW.status IN ('Completed','CompletedWithSupersededRelease','ScenarioUnsurvivable','Aborted','Abandoned','Crashed')
       AND NEW.launch_granted_at IS NULL THEN
        RAISE EXCEPTION 'a session cannot complete before online start';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_playtest_session_write()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_require_active_creator BOOLEAN := true;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        v_require_active_creator := OLD.started_at IS NULL;
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM public.revisions AS revision
          JOIN public.scenario_versions AS scenario
            ON scenario.id = NEW.scenario_version_id
           AND scenario.revision_id = revision.id
           AND scenario.building_id = NEW.building_id
           AND scenario.organization_id = NEW.organization_id
         WHERE revision.id = NEW.revision_id
    ) THEN RAISE EXCEPTION 'playtest scenario version, revision, building and organization must match'; END IF;
    IF NEW.scenario_draft_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
          FROM public.scenario_drafts AS draft
          JOIN public.scenario_versions AS scenario
            ON scenario.id = NEW.scenario_version_id
           AND scenario.scenario_id = draft.scenario_id
         WHERE draft.id = NEW.scenario_draft_id
           AND draft.revision_id = NEW.revision_id
           AND draft.building_id = NEW.building_id
           AND draft.organization_id = NEW.organization_id
    ) THEN RAISE EXCEPTION 'playtest draft must match the selected scenario version, revision, building and organization'; END IF;
    IF v_require_active_creator AND NOT EXISTS (
         SELECT 1 FROM public.users AS creator
          WHERE creator.id = NEW.created_by AND creator.role = 'OrganizationUser'
            AND creator.organization_id = NEW.organization_id
            AND creator.is_active AND creator.deleted_at IS NULL
     ) THEN RAISE EXCEPTION 'playtest created_by must be an active OrganizationUser in the same tenant'; END IF;
    IF NULLIF(pg_catalog.btrim(NEW.package_hash), '') IS NULL THEN
        RAISE EXCEPTION 'playtest package_hash is required';
    END IF;
    IF NULLIF(pg_catalog.btrim(NEW.manifest_sha256), '') IS NULL
       OR NULLIF(pg_catalog.btrim(NEW.build_target), '') IS NULL THEN
        RAISE EXCEPTION 'playtest package requires a manifest hash and build target';
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM public.validation_runs AS run
          JOIN public.revision_artifacts AS artifact
            ON artifact.id = run.artifact_id
           AND artifact.sha256_hash = NEW.package_hash
           AND artifact.metadata ->> 'manifest_sha256' = NEW.manifest_sha256
           AND artifact.metadata ->> 'build_target' = NEW.build_target
         WHERE run.revision_id = NEW.revision_id
           AND run.scenario_version_id = NEW.scenario_version_id
           AND run.scope = 'PlaytestPackage' AND run.status = 'Passed'
           AND NOT EXISTS (
               SELECT 1 FROM public.validation_issues AS issue
                WHERE issue.validation_run_id = run.id
                  AND issue.severity IN ('Error','Critical')
                  AND issue.status NOT IN ('Resolved','Waived')
           )
    ) THEN RAISE EXCEPTION 'playtest package requires a matching passed validation run with no open Error/Critical issue'; END IF;
    IF TG_OP = 'INSERT' AND (
           NEW.status <> 'Created' OR NEW.start_idempotency_key IS NOT NULL OR NEW.started_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'a prepared playtest must start in Created state without a start key';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status = 'Created'
       AND (
           NEW.status <> 'Created'
           OR OLD.start_idempotency_key IS DISTINCT FROM NEW.start_idempotency_key
           OR OLD.started_at IS DISTINCT FROM NEW.started_at
           OR OLD.runtime_version IS DISTINCT FROM NEW.runtime_version
           OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
           OR OLD.build_target IS DISTINCT FROM NEW.build_target
           OR OLD.runtime_catalog_id IS DISTINCT FROM NEW.runtime_catalog_id
           OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
       )
       AND (CURRENT_USER <> 'fet3d_session_owner'
            OR COALESCE(pg_catalog.current_setting('fet3d.playtest_start_id', true), '') <> NEW.id::TEXT) THEN
        RAISE EXCEPTION 'only actor-bound online start may launch a playtest';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.building_id IS DISTINCT FROM NEW.building_id
        OR OLD.revision_id IS DISTINCT FROM NEW.revision_id
        OR OLD.scenario_draft_id IS DISTINCT FROM NEW.scenario_draft_id
        OR OLD.scenario_version_id IS DISTINCT FROM NEW.scenario_version_id
        OR OLD.service_entitlement_id IS DISTINCT FROM NEW.service_entitlement_id
        OR OLD.package_hash IS DISTINCT FROM NEW.package_hash
        OR OLD.package_artifact_id IS DISTINCT FROM NEW.package_artifact_id
        OR OLD.package_validation_run_id IS DISTINCT FROM NEW.package_validation_run_id
        OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
        OR OLD.build_target IS DISTINCT FROM NEW.build_target
        OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
        OR OLD.manifest_schema_version IS DISTINCT FROM NEW.manifest_schema_version
         OR ((CURRENT_USER <> 'fet3d_session_owner'
              OR COALESCE(pg_catalog.current_setting('fet3d.playtest_start_id', true), '') <> NEW.id::TEXT)
             AND (OLD.runtime_version IS DISTINCT FROM NEW.runtime_version
                  OR OLD.runtime_catalog_id IS DISTINCT FROM NEW.runtime_catalog_id
                  OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
                  OR OLD.build_target IS DISTINCT FROM NEW.build_target))
        OR (OLD.start_idempotency_key IS NOT NULL AND OLD.start_idempotency_key IS DISTINCT FROM NEW.start_idempotency_key)
    ) THEN RAISE EXCEPTION 'playtest identity, package and pinned scenario are immutable'; END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_session_preparation_state_before_insert
BEFORE INSERT ON sessions FOR EACH ROW EXECUTE FUNCTION enforce_session_preparation_state();

CREATE TRIGGER enforce_playtest_preparation_state_before_insert
BEFORE INSERT ON playtest_sessions FOR EACH ROW EXECUTE FUNCTION enforce_playtest_preparation_state();

-- Actor-bound online training start. The old overload is replaced by a
-- failing compatibility stub so an unscoped session id can never launch.
CREATE OR REPLACE FUNCTION start_training_session(
    p_actor_id UUID,
    p_session_id UUID,
    p_start_idempotency_key TEXT,
    p_runtime_version TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_session public.sessions%ROWTYPE;
    v_building_id UUID;
    v_catalog_id UUID;
    v_protocol_version TEXT;
    v_manifest_sha256 TEXT;
    v_build_target TEXT;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_start_idempotency_key), '') IS NULL
       OR NOT public.fet3d_semver_gte(p_runtime_version, p_runtime_version) THEN
        RAISE EXCEPTION 'valid semver runtime version and start idempotency key are required';
    END IF;

    SELECT * INTO v_session FROM public.sessions WHERE id = p_session_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'session does not exist'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.users AS actor
         WHERE actor.id = p_actor_id AND actor.id = v_session.trainee_user_id
           AND actor.role = 'Trainee' AND actor.is_active AND actor.deleted_at IS NULL
    ) THEN RAISE EXCEPTION 'actor must be the active Trainee who owns the session'; END IF;

    IF v_session.start_idempotency_key IS NOT NULL THEN
        IF v_session.start_idempotency_key = pg_catalog.btrim(p_start_idempotency_key)
           AND v_session.runtime_version = pg_catalog.btrim(p_runtime_version) THEN
            RETURN v_session.id;
        END IF;
        RAISE EXCEPTION 'session already started with a different idempotency key';
    END IF;
    IF v_session.status <> 'Created' THEN RAISE EXCEPTION 'session is not in Created state'; END IF;

    SELECT release.building_id INTO v_building_id
      FROM public.releases AS release
     WHERE release.id = v_session.release_id
       AND release.status = 'Published'
       AND release.scenario_version_id = v_session.scenario_version_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'online start requires the pinned Published release and scenario'; END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.trainings AS training
         WHERE training.id = v_session.training_id
           AND training.release_id = v_session.release_id
           AND training.scenario_version_id = v_session.scenario_version_id
           AND training.organization_id = v_session.organization_id
           AND training.status = 'Active'
           AND v_session.mode::TEXT = ANY(training.allowed_modes)
    ) THEN RAISE EXCEPTION 'online start requires the pinned Active Training and allowed mode'; END IF;

    SELECT catalog.id, catalog.protocol_version, package.manifest_sha256, package.build_target
      INTO v_catalog_id, v_protocol_version, v_manifest_sha256, v_build_target
      FROM public.release_packages AS package
      JOIN public.runtime_compatibility_catalog AS catalog
        ON catalog.manifest_schema_version = package.manifest_schema_version
       AND catalog.protocol_version = package.protocol_version
       AND catalog.runtime_version = p_runtime_version
       AND catalog.is_active
      WHERE package.release_id = v_session.release_id
        AND package.candidate_artifact_id = v_session.package_artifact_id
        AND package.candidate_validation_run_id = v_session.package_validation_run_id
        AND package.checksum_sha256 = v_session.package_hash
       AND package.manifest_sha256 = v_session.manifest_sha256
       AND package.build_target = v_session.build_target
        AND package.manifest_schema_version = v_session.manifest_schema_version
        AND EXISTS (
            SELECT 1 FROM public.validation_runs AS run
             WHERE run.id = v_session.package_validation_run_id
               AND run.release_id = v_session.release_id
               AND run.artifact_id = package.candidate_artifact_id
               AND run.status = 'Passed'
        )
        AND public.fet3d_runtime_package_is_compatible(
             p_runtime_version, package.min_runtime_version, package.protocol_version,
             package.manifest_schema_version, package.required_capabilities, catalog.id
       );
    IF NOT FOUND THEN RAISE EXCEPTION 'online start requires a compatible verified runtime package'; END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.release_qr_codes AS qr
         WHERE qr.id = v_session.qr_code_id AND qr.building_id = v_building_id
           AND qr.organization_id = v_session.organization_id AND qr.is_active
           AND (qr.expires_at IS NULL OR qr.expires_at > pg_catalog.now())
    ) THEN RAISE EXCEPTION 'online start requires a non-revoked, non-expired Building QR'; END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.service_entitlements AS entitlement
         WHERE entitlement.building_id = v_building_id
           AND entitlement.organization_id = v_session.organization_id
           AND entitlement.status = 'Active'
           AND entitlement.starts_at <= pg_catalog.now() AND entitlement.ends_at > pg_catalog.now()
    ) THEN RAISE EXCEPTION 'online start requires an active Building service entitlement'; END IF;

    PERFORM pg_catalog.set_config('fet3d.session_start_id', v_session.id::TEXT, true);
    UPDATE public.sessions
       SET start_idempotency_key = pg_catalog.btrim(p_start_idempotency_key),
           runtime_version = pg_catalog.btrim(p_runtime_version),
           protocol_version = v_protocol_version,
           manifest_sha256 = v_manifest_sha256,
           build_target = v_build_target,
           runtime_catalog_id = v_catalog_id,
           launch_granted_at = pg_catalog.clock_timestamp(),
           started_at = pg_catalog.clock_timestamp(),
           status = 'Running'
     WHERE id = v_session.id;
    RETURN v_session.id;
END;
$$;

-- Actor-bound playtest start. Trial quota is reserved atomically by the row
-- lock; an Active paid entitlement does not consume Trial playtest units.
CREATE OR REPLACE FUNCTION start_playtest_session(
    p_actor_id UUID,
    p_playtest_session_id UUID,
    p_start_idempotency_key TEXT,
    p_runtime_version TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_playtest public.playtest_sessions%ROWTYPE;
    v_entitlement public.service_entitlements%ROWTYPE;
    v_catalog_id UUID;
    v_manifest_sha256 TEXT;
    v_build_target TEXT;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_start_idempotency_key), '') IS NULL
       OR NOT public.fet3d_semver_gte(p_runtime_version, p_runtime_version) THEN
        RAISE EXCEPTION 'valid semver runtime version and start idempotency key are required';
    END IF;
    SELECT * INTO v_playtest FROM public.playtest_sessions WHERE id = p_playtest_session_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'playtest session does not exist'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.users AS actor
         WHERE actor.id = p_actor_id AND actor.id = v_playtest.created_by
           AND actor.role = 'OrganizationUser'
           AND actor.organization_id = v_playtest.organization_id
           AND actor.is_active AND actor.deleted_at IS NULL
    ) THEN RAISE EXCEPTION 'actor must be the active OrganizationUser who created the playtest'; END IF;
    IF v_playtest.start_idempotency_key IS NOT NULL THEN
        IF v_playtest.start_idempotency_key = pg_catalog.btrim(p_start_idempotency_key)
           AND v_playtest.runtime_version = pg_catalog.btrim(p_runtime_version) THEN
            RETURN v_playtest.id;
        END IF;
        RAISE EXCEPTION 'playtest already started with a different idempotency key';
    END IF;
    IF v_playtest.status <> 'Created' THEN RAISE EXCEPTION 'playtest session is not in Created state'; END IF;

    SELECT * INTO v_entitlement FROM public.service_entitlements AS entitlement
     WHERE entitlement.id = v_playtest.service_entitlement_id
       AND entitlement.organization_id = v_playtest.organization_id
       AND entitlement.building_id = v_playtest.building_id
       AND entitlement.status IN ('Trial','Active')
       AND entitlement.starts_at <= pg_catalog.now() AND entitlement.ends_at > pg_catalog.now()
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'playtest requires a current Trial or Active Building entitlement'; END IF;
    IF v_entitlement.status = 'Trial' THEN
        UPDATE public.service_entitlements
           SET playtest_units_used = playtest_units_used + 1
         WHERE id = v_entitlement.id AND playtest_units_used < playtest_units_granted;
        IF NOT FOUND THEN RAISE EXCEPTION 'Trial playtest quota is exhausted'; END IF;
    END IF;

    SELECT catalog.id, artifact.metadata ->> 'manifest_sha256', artifact.metadata ->> 'build_target'
      INTO v_catalog_id, v_manifest_sha256, v_build_target
      FROM public.validation_runs AS run
      JOIN public.revision_artifacts AS artifact
        ON artifact.id = run.artifact_id
       AND artifact.sha256_hash = v_playtest.package_hash
       AND artifact.metadata ->> 'manifest_sha256' = v_playtest.manifest_sha256
       AND artifact.metadata ->> 'build_target' = v_playtest.build_target
      JOIN public.runtime_compatibility_catalog AS catalog
        ON catalog.runtime_version = p_runtime_version
       AND catalog.is_active
       AND catalog.protocol_version = artifact.metadata ->> 'protocol_version'
       AND catalog.manifest_schema_version = artifact.metadata ->> 'manifest_schema_version'
      WHERE run.revision_id = v_playtest.revision_id
        AND run.id = v_playtest.package_validation_run_id
        AND run.artifact_id = v_playtest.package_artifact_id
        AND run.scenario_version_id = v_playtest.scenario_version_id
       AND run.scope = 'PlaytestPackage'
       AND run.status = 'Passed'
       AND artifact.metadata ? 'min_runtime_version'
       AND artifact.metadata ? 'protocol_version'
       AND artifact.metadata ? 'manifest_schema_version'
       AND artifact.metadata ? 'required_capabilities'
       AND artifact.metadata ? 'manifest_sha256'
       AND artifact.metadata ? 'build_target'
       AND pg_catalog.jsonb_typeof(artifact.metadata -> 'required_capabilities') = 'array'
       AND artifact.metadata ->> 'protocol_version' = v_playtest.protocol_version
       AND artifact.metadata ->> 'manifest_schema_version' = v_playtest.manifest_schema_version
       AND public.fet3d_runtime_package_is_compatible(
             p_runtime_version,
             artifact.metadata ->> 'min_runtime_version',
             artifact.metadata ->> 'protocol_version',
             artifact.metadata ->> 'manifest_schema_version',
             artifact.metadata -> 'required_capabilities',
             catalog.id
       );
    IF NOT FOUND THEN RAISE EXCEPTION 'playtest runtime/schema is not supported'; END IF;

    PERFORM pg_catalog.set_config('fet3d.playtest_start_id', v_playtest.id::TEXT, true);
    UPDATE public.playtest_sessions
       SET start_idempotency_key = pg_catalog.btrim(p_start_idempotency_key),
           runtime_version = pg_catalog.btrim(p_runtime_version),
           manifest_sha256 = v_manifest_sha256,
           build_target = v_build_target,
           runtime_catalog_id = v_catalog_id,
           status = 'Running',
           started_at = pg_catalog.clock_timestamp()
     WHERE id = v_playtest.id;
    RETURN v_playtest.id;
END;
$$;

-- Organization quota is pooled across Buildings. Building remains optional
-- cost/source attribution and is never a wallet boundary.
ALTER TABLE ai_quota_grants
    ADD COLUMN units_reserved INT NOT NULL DEFAULT 0,
    ADD CONSTRAINT check_ai_quota_reserved
        CHECK (units_reserved >= 0 AND units_used + units_reserved <= units_granted);

CREATE TABLE ai_usage_reservations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID REFERENCES ai_usage_ledger(request_id) ON DELETE RESTRICT UNIQUE NOT NULL,
    units           INT NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'Reserved', -- Reserved | Consumed | Released
    reserved_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at      TIMESTAMPTZ,
    CONSTRAINT check_ai_reservation_units CHECK (units > 0),
    CONSTRAINT check_ai_reservation_status CHECK (status IN ('Reserved','Consumed','Released'))
);

CREATE OR REPLACE FUNCTION reserve_ai_usage(
    p_request_id UUID, p_idempotency_key TEXT, p_user_id UUID, p_audience TEXT,
    p_organization_id UUID, p_building_id UUID, p_request_type TEXT, p_units INT,
    p_billable BOOLEAN, p_overage_consent_id UUID, p_billing_period_id UUID,
    p_unit_price_snapshot JSONB, p_source_scope JSONB DEFAULT '{}'
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_usage_id UUID;
    v_reservation_id UUID;
    v_request public.ai_requests%ROWTYPE;
    v_existing public.ai_usage_ledger%ROWTYPE;
    v_remaining INT := p_units;
    v_policy_version_id UUID;
    v_period public.ai_billing_periods%ROWTYPE;
    v_grant RECORD;
    v_take INT;
BEGIN
    IF p_request_id IS NULL
       OR NULLIF(pg_catalog.btrim(p_idempotency_key), '') IS NULL
       OR p_user_id IS NULL
       OR NULLIF(pg_catalog.btrim(p_audience), '') IS NULL
       OR p_units IS NULL OR p_units <= 0 THEN
        RAISE EXCEPTION 'AI request key and positive units are required';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(pg_catalog.btrim(p_idempotency_key), 0)
    );

    -- Accounting lock order is period (when present) -> request -> ledger /
    -- reservation -> grants in ascending id order. Do not hold this transaction
    -- while waiting for the AI provider.
    IF p_billing_period_id IS NOT NULL THEN
        SELECT * INTO v_period
          FROM public.ai_billing_periods
         WHERE id = p_billing_period_id
         FOR UPDATE;
        IF NOT FOUND OR v_period.organization_id IS DISTINCT FROM p_organization_id THEN
            RAISE EXCEPTION 'AI billing period does not belong to the request organization';
        END IF;
    END IF;

    SELECT * INTO v_request
      FROM public.ai_requests
     WHERE id = p_request_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI request does not exist'; END IF;

    SELECT * INTO v_existing
      FROM public.ai_usage_ledger
     WHERE request_id = p_request_id OR idempotency_key = pg_catalog.btrim(p_idempotency_key)
     FOR UPDATE;
    IF FOUND THEN
        IF v_existing.request_id IS DISTINCT FROM p_request_id
           OR v_existing.idempotency_key IS DISTINCT FROM pg_catalog.btrim(p_idempotency_key)
           OR v_existing.user_id IS DISTINCT FROM p_user_id
           OR v_existing.audience IS DISTINCT FROM p_audience
           OR v_existing.organization_id IS DISTINCT FROM p_organization_id
           OR v_existing.building_id IS DISTINCT FROM p_building_id
           OR v_existing.request_type IS DISTINCT FROM p_request_type
           OR v_existing.units IS DISTINCT FROM p_units
           OR v_existing.billable IS DISTINCT FROM p_billable
           OR v_existing.overage_consent_id IS DISTINCT FROM p_overage_consent_id
           OR v_existing.billing_period_id IS DISTINCT FROM p_billing_period_id
           OR v_existing.unit_price_snapshot IS DISTINCT FROM COALESCE(p_unit_price_snapshot, '{}'::JSONB)
           OR v_existing.source_scope IS DISTINCT FROM COALESCE(p_source_scope, '{}'::JSONB)
        THEN
            RAISE EXCEPTION 'AI idempotency key/request_id was reused with different input';
        END IF;
        RETURN v_existing.id;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.ai_requests AS request
         WHERE request.id = p_request_id
           AND request.idempotency_key = pg_catalog.btrim(p_idempotency_key)
           AND request.user_id = p_user_id
           AND request.audience = p_audience
           AND request.request_type = p_request_type
           AND request.organization_id IS NOT DISTINCT FROM p_organization_id
           AND request.building_id IS NOT DISTINCT FROM p_building_id
    ) THEN
        RAISE EXCEPTION 'AI usage must reference the matching durable AI request';
    END IF;

    SELECT request.policy_version_id
      INTO v_policy_version_id
      FROM public.ai_requests AS request
     WHERE request.id = p_request_id;

    INSERT INTO public.ai_usage_ledger(
        request_id, idempotency_key, organization_id, building_id, user_id,
        audience, request_type, policy_version_id, units, overage_consent_id,
        billable, unit_price_snapshot, billing_period_id, status, source_scope
    ) VALUES (
        p_request_id, pg_catalog.btrim(p_idempotency_key), p_organization_id, p_building_id, p_user_id,
        p_audience, p_request_type, v_policy_version_id, p_units, p_overage_consent_id,
        p_billable, COALESCE(p_unit_price_snapshot, '{}'::JSONB), p_billing_period_id, 'Reserved',
        COALESCE(p_source_scope, '{}'::JSONB)
    ) RETURNING id INTO v_usage_id;

    INSERT INTO public.ai_usage_reservations(request_id, units)
    VALUES (p_request_id, p_units)
    RETURNING id INTO v_reservation_id;

    IF p_billable = false THEN
        FOR v_grant IN
            SELECT grant_row.*
              FROM public.ai_quota_grants AS grant_row
             WHERE grant_row.audience = p_audience
               AND (
                   (p_audience = 'organization' AND grant_row.organization_id = p_organization_id)
                   OR (p_audience = 'trainee' AND grant_row.trainee_user_id = p_user_id)
               )
               AND grant_row.starts_at <= pg_catalog.now()
               AND grant_row.ends_at > pg_catalog.now()
               AND grant_row.units_used + grant_row.units_reserved < grant_row.units_granted
             ORDER BY grant_row.id
             FOR UPDATE
        LOOP
            v_take := LEAST(
                v_remaining,
                v_grant.units_granted - v_grant.units_used - v_grant.units_reserved
            );
            IF v_take > 0 THEN
                UPDATE public.ai_quota_grants
                   SET units_reserved = units_reserved + v_take
                 WHERE id = v_grant.id;
                INSERT INTO public.ai_usage_reservation_allocations(
                    reservation_id, quota_grant_id, units
                ) VALUES (v_reservation_id, v_grant.id, v_take);
                v_remaining := v_remaining - v_take;
            END IF;
            EXIT WHEN v_remaining = 0;
        END LOOP;
        IF v_remaining > 0 THEN
            RAISE EXCEPTION 'no available AI quota';
        END IF;
    END IF;

    UPDATE public.ai_requests
       SET status = 'Processing'
     WHERE id = p_request_id
       AND status = 'Accepted';

    RETURN v_usage_id;
END;
$$;


CREATE OR REPLACE FUNCTION settle_ai_usage(p_request_id UUID, p_status TEXT)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_request public.ai_requests%ROWTYPE;
    v_reservation public.ai_usage_reservations%ROWTYPE;
    v_usage public.ai_usage_ledger%ROWTYPE;
    v_period_id UUID;
    v_period public.ai_billing_periods%ROWTYPE;
    v_allocation RECORD;
BEGIN
    IF p_status NOT IN ('Recorded','Failed','Reversed','NeedsReconcile') THEN
        RAISE EXCEPTION 'invalid AI usage settlement status';
    END IF;

    -- Match reserve_ai_usage: period (when present) -> request -> ledger /
    -- reservation -> grants in ascending id order.
    SELECT billing_period_id INTO v_period_id
      FROM public.ai_usage_ledger
     WHERE request_id = p_request_id;
    IF v_period_id IS NOT NULL THEN
        SELECT * INTO v_period
          FROM public.ai_billing_periods
         WHERE id = v_period_id
         FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'AI billing period does not exist'; END IF;
    END IF;

    SELECT * INTO v_request
      FROM public.ai_requests
     WHERE id = p_request_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI request does not exist'; END IF;

    SELECT * INTO v_usage
      FROM public.ai_usage_ledger
     WHERE request_id = p_request_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI usage request does not exist'; END IF;

    SELECT * INTO v_reservation
      FROM public.ai_usage_reservations
     WHERE request_id = p_request_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI usage reservation does not exist'; END IF;

    IF v_usage.status IN ('Recorded','Failed','Reversed') THEN
        IF v_usage.status = p_status THEN RETURN p_request_id; END IF;
        RAISE EXCEPTION 'AI usage is already settled with a different status';
    END IF;

    IF p_status = 'NeedsReconcile' THEN
        UPDATE public.ai_usage_ledger
           SET status = 'NeedsReconcile'
         WHERE request_id = p_request_id;
        UPDATE public.ai_requests
           SET status = 'NeedsReconcile'
         WHERE id = p_request_id
           AND status IN ('Accepted','Processing');
        RETURN p_request_id;
    END IF;

    IF v_reservation.status <> 'Reserved' THEN
        RAISE EXCEPTION 'AI reservation is not available for settlement';
    END IF;

    FOR v_allocation IN
        SELECT * FROM public.ai_usage_reservation_allocations
         WHERE reservation_id = v_reservation.id
         ORDER BY quota_grant_id
         FOR UPDATE
    LOOP
        UPDATE public.ai_quota_grants
           SET units_reserved = units_reserved - v_allocation.units,
               units_used = units_used + CASE WHEN p_status = 'Recorded' THEN v_allocation.units ELSE 0 END
         WHERE id = v_allocation.quota_grant_id
           AND units_reserved >= v_allocation.units;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'AI quota reservation integrity check failed';
        END IF;
    END LOOP;

    UPDATE public.ai_usage_reservations
       SET status = CASE WHEN p_status = 'Recorded' THEN 'Consumed' ELSE 'Released' END,
           settled_at = pg_catalog.clock_timestamp()
     WHERE id = v_reservation.id;

    UPDATE public.ai_usage_ledger
       SET status = p_status
     WHERE request_id = p_request_id;

    UPDATE public.ai_requests
       SET status = CASE WHEN p_status = 'Recorded' THEN 'Succeeded' ELSE 'Failed' END,
           completed_at = pg_catalog.clock_timestamp()
     WHERE id = p_request_id
       AND status IN ('Accepted','Processing','NeedsReconcile');

    RETURN p_request_id;
END;
$$;


-- Durable DB-to-queue handoff and worker attempt provenance.
-- JSONB is PostgreSQL's canonical representation here; every producer and
-- consumer uses this helper instead of re-serializing payloads outside DB.
CREATE OR REPLACE FUNCTION fet3d_jsonb_payload_hash(p_payload JSONB)
RETURNS VARCHAR(64)
LANGUAGE sql
IMMUTABLE STRICT
SET search_path = pg_catalog, public
AS $$
    SELECT pg_catalog.encode(
        public.digest(pg_catalog.convert_to(p_payload::TEXT, 'UTF8'), 'sha256'),
        'hex'
    )
$$;

CREATE TABLE integration_outbox_events (
    idempotency_key VARCHAR(255) PRIMARY KEY,
    aggregate_type VARCHAR(80) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    schema_version VARCHAR(50) NOT NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    payload JSONB NOT NULL,
    payload_hash VARCHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending', -- Pending | Leased | Published | Failed
    attempts INT NOT NULL DEFAULT 0,
    available_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    lease_owner VARCHAR(255),
    lease_token UUID UNIQUE,
    lease_until TIMESTAMPTZ,
    published_lease_token UUID,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    CONSTRAINT check_outbox_status CHECK (status IN ('Pending','Leased','Published','Failed')),
    CONSTRAINT check_outbox_attempts CHECK (attempts >= 0),
    CONSTRAINT check_outbox_schema_version CHECK (NULLIF(pg_catalog.btrim(schema_version), '') IS NOT NULL),
    CONSTRAINT check_outbox_payload_hash CHECK (
        payload_hash ~ '^[0-9a-fA-F]{64}$'
        AND lower(payload_hash) = public.fet3d_jsonb_payload_hash(payload)
    ),
    CONSTRAINT check_outbox_lease_shape CHECK (
        (
            status = 'Leased'
            AND
            NULLIF(pg_catalog.btrim(lease_owner), '') IS NOT NULL
            AND lease_token IS NOT NULL
            AND lease_until IS NOT NULL
        )
        OR (
            status <> 'Leased'
            AND lease_owner IS NULL
            AND lease_token IS NULL
            AND lease_until IS NULL
        )
    ),
    CONSTRAINT check_outbox_published_shape CHECK (
        (status = 'Published' AND published_at IS NOT NULL AND published_lease_token IS NOT NULL)
        OR (status <> 'Published' AND published_at IS NULL)
    ),
    CONSTRAINT check_outbox_scope CHECK (
        organization_id IS NOT NULL OR aggregate_type IN ('System','Platform')
    )
);

-- Durable consumer deduplication. The row is inserted in the same PostgreSQL
-- transaction as the business effect; Redis ACK happens only after commit.
CREATE TABLE integration_event_consumptions (
    consumer_name VARCHAR(120) NOT NULL,
    event_key VARCHAR(255) REFERENCES integration_outbox_events(idempotency_key) ON DELETE RESTRICT NOT NULL,
    payload_hash VARCHAR(64) NOT NULL,
    result_reference TEXT,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (consumer_name, event_key),
    CONSTRAINT check_event_consumer_name CHECK (NULLIF(pg_catalog.btrim(consumer_name), '') IS NOT NULL),
    CONSTRAINT check_event_consumption_hash CHECK (payload_hash ~ '^[0-9a-fA-F]{64}$')
);

CREATE TABLE processing_job_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    processing_job_id UUID REFERENCES processing_jobs(id) ON DELETE CASCADE NOT NULL,
    attempt_number INT NOT NULL,
    input_hash VARCHAR(64) NOT NULL,
    toolchain_version VARCHAR(100) NOT NULL,
    lease_owner VARCHAR(255) NOT NULL,
    lease_token UUID NOT NULL UNIQUE,
    lease_until TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'Running', -- Running | Succeeded | Failed | Expired
    output_hash VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    error_message TEXT,
    UNIQUE (processing_job_id, attempt_number),
    CONSTRAINT check_job_attempt_status CHECK (status IN ('Running','Succeeded','Failed','Expired')),
    CONSTRAINT check_job_attempt_input_hash CHECK (input_hash ~ '^[0-9a-fA-F]{64}$'),
    CONSTRAINT check_job_attempt_output_hash CHECK (output_hash IS NULL OR output_hash ~ '^[0-9a-fA-F]{64}$')
);

CREATE INDEX idx_outbox_dispatch ON integration_outbox_events(status, available_at, lease_until);
CREATE INDEX idx_outbox_scope_dispatch ON integration_outbox_events(organization_id, status, available_at);
CREATE INDEX idx_event_consumptions_hash ON integration_event_consumptions(event_key, payload_hash);
CREATE INDEX idx_job_attempt_lease ON processing_job_attempts(status, lease_until);

CREATE OR REPLACE FUNCTION validate_integration_outbox_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.idempotency_key IS NULL
           OR NULLIF(pg_catalog.btrim(NEW.idempotency_key), '') IS NULL
           OR NEW.aggregate_type IS NULL
           OR NULLIF(pg_catalog.btrim(NEW.aggregate_type), '') IS NULL
           OR NEW.aggregate_id IS NULL
           OR NEW.event_type IS NULL
           OR NULLIF(pg_catalog.btrim(NEW.event_type), '') IS NULL
           OR NEW.schema_version IS NULL
           OR NULLIF(pg_catalog.btrim(NEW.schema_version), '') IS NULL
           OR NEW.payload IS NULL
           OR NEW.payload_hash IS NULL
           OR NEW.status IS DISTINCT FROM 'Pending'
           OR NEW.attempts IS DISTINCT FROM 0
           OR NEW.lease_owner IS NOT NULL
           OR NEW.lease_token IS NOT NULL
           OR NEW.lease_until IS NOT NULL
           OR NEW.published_at IS NOT NULL
           OR NEW.published_lease_token IS NOT NULL THEN
            RAISE EXCEPTION 'outbox events must be enqueued as Pending without a lease or publication';
        END IF;
        IF lower(NEW.payload_hash) IS DISTINCT FROM fet3d_jsonb_payload_hash(NEW.payload) THEN
            RAISE EXCEPTION 'outbox payload hash does not match canonical payload';
        END IF;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.idempotency_key IS DISTINCT FROM NEW.idempotency_key
           OR OLD.aggregate_type IS DISTINCT FROM NEW.aggregate_type
           OR OLD.aggregate_id IS DISTINCT FROM NEW.aggregate_id
           OR OLD.event_type IS DISTINCT FROM NEW.event_type
           OR OLD.schema_version IS DISTINCT FROM NEW.schema_version
           OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
           OR OLD.payload IS DISTINCT FROM NEW.payload
           OR OLD.payload_hash IS DISTINCT FROM NEW.payload_hash
           OR OLD.created_at IS DISTINCT FROM NEW.created_at THEN
            RAISE EXCEPTION 'outbox event identity and payload are immutable after enqueue';
        END IF;
        IF NEW.status = 'Published'
           AND (NEW.published_at IS NULL OR NEW.published_lease_token IS NULL) THEN
            RAISE EXCEPTION 'published outbox events require publication time and completed lease token';
        END IF;
        IF NEW.status <> 'Published' AND NEW.published_at IS NOT NULL THEN
            RAISE EXCEPTION 'non-published outbox events cannot have publication time';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_integration_outbox_event_immutable
BEFORE INSERT OR UPDATE ON integration_outbox_events
FOR EACH ROW EXECUTE FUNCTION validate_integration_outbox_event_mutation();

-- Verified webhook processing must not depend on the requester remaining
-- active after checkout. Request identity and quotation snapshots are frozen.
CREATE OR REPLACE FUNCTION validate_payos_paid_request()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.quotations AS quotation
         WHERE quotation.id = NEW.quotation_id
           AND quotation.organization_id = NEW.organization_id
           AND quotation.total_amount = NEW.expected_amount
           AND quotation.currency = NEW.expected_currency
    ) THEN RAISE EXCEPTION 'PayOS request must match quotation organization, amount and currency'; END IF;

    IF TG_OP = 'INSERT' AND NOT EXISTS (
        SELECT 1 FROM public.users AS requester
         WHERE requester.id = NEW.requested_by AND requester.role = 'OrganizationUser'
           AND requester.organization_id = NEW.organization_id
           AND requester.is_active AND requester.deleted_at IS NULL
    ) THEN RAISE EXCEPTION 'checkout requester must be an active OrganizationUser in the same tenant'; END IF;

    IF TG_OP = 'UPDATE' AND (
        OLD.quotation_id IS DISTINCT FROM NEW.quotation_id
        OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.requested_by IS DISTINCT FROM NEW.requested_by
        OR OLD.idempotency_key IS DISTINCT FROM NEW.idempotency_key
        OR OLD.order_code IS DISTINCT FROM NEW.order_code
        OR OLD.expected_amount IS DISTINCT FROM NEW.expected_amount
        OR OLD.expected_currency IS DISTINCT FROM NEW.expected_currency
    ) THEN RAISE EXCEPTION 'PayOS request identity and quotation snapshot are immutable'; END IF;
    IF TG_OP = 'UPDATE' AND OLD.status = 'Paid' AND NEW IS DISTINCT FROM OLD THEN
        RAISE EXCEPTION 'Paid payment truth and provenance are immutable';
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.status = 'Paid' AND OLD.status <> 'Pending' THEN
        RAISE EXCEPTION 'Only a Pending payment request can become Paid';
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.status = 'Paid' AND CURRENT_USER <> 'fet3d_payos_ledger_owner' THEN
        RAISE EXCEPTION 'Paid payment request must use the trusted PayOS webhook function';
    END IF;
    IF NEW.status = 'Paid' AND NOT EXISTS (
        SELECT 1 FROM public.payment_transactions AS payment
         WHERE payment.id = NEW.paid_transaction_id AND payment.payment_request_id = NEW.id
           AND payment.status = 'Applied' AND payment.signature_verified
           AND payment.received_order_code = NEW.order_code
           AND payment.received_amount = NEW.expected_amount
           AND payment.received_currency = NEW.expected_currency
    ) THEN RAISE EXCEPTION 'Paid requires an Applied verified webhook matching the request snapshot'; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_backend_executor') THEN
        CREATE ROLE fet3d_backend_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
END;
$$;

REVOKE ALL PRIVILEGES ON FUNCTION start_training_session(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION start_playtest_session(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION start_training_session(UUID, UUID, TEXT, TEXT) TO fet3d_backend_executor;
GRANT EXECUTE ON FUNCTION start_playtest_session(UUID, UUID, TEXT, TEXT) TO fet3d_backend_executor;

-- ============================================================================
-- VERSION 6.7 TARGET DESIGN AMENDMENTS (continuation)
-- Canonical field ownership, durable AI requests, fenced processing attempts,
-- immutable billing snapshots and server-owned runtime/session gates.
-- This section is target DDL only; it is not an executable migration.
-- ============================================================================

-- Runtime/app identity is deliberately separated for diagnostics and support.
ALTER TABLE sessions RENAME COLUMN unity_version TO unity_engine_version;
ALTER TABLE sessions
    ADD COLUMN last_heartbeat_received_at TIMESTAMPTZ,
    ADD COLUMN last_heartbeat_sequence BIGINT;
ALTER TABLE playtest_sessions
    ADD COLUMN unity_engine_version VARCHAR(50),
    ADD COLUMN last_heartbeat_received_at TIMESTAMPTZ;

-- One logical processing job has many attempts. Attempt/lease/toolchain/error
-- provenance belongs to processing_job_attempts, not processing_jobs.
ALTER TABLE processing_jobs
    DROP CONSTRAINT IF EXISTS processing_jobs_job_key_attempt_number_key,
    ADD CONSTRAINT uq_processing_jobs_logical_key UNIQUE (job_key),
    DROP COLUMN IF EXISTS attempt_number,
    DROP COLUMN IF EXISTS toolchain_version,
    DROP COLUMN IF EXISTS lease_owner,
    DROP COLUMN IF EXISTS heartbeat_at,
    DROP COLUMN IF EXISTS started_at,
    DROP COLUMN IF EXISTS finished_at,
    DROP COLUMN IF EXISTS error_message;

ALTER TABLE revision_processing_logs
    ADD COLUMN attempt_id UUID,
    DROP COLUMN IF EXISTS attempt_number;

ALTER TABLE processing_job_attempts
    ADD COLUMN output_artifact_id UUID,
    ADD COLUMN result_validation_run_id UUID;

ALTER TABLE processing_jobs
    ADD COLUMN current_attempt_id UUID;

ALTER TABLE revision_artifacts
    ADD COLUMN attempt_id UUID NOT NULL;

ALTER TABLE validation_runs
    ADD COLUMN processing_attempt_id UUID NOT NULL;

ALTER TABLE revision_processing_logs
    ALTER COLUMN attempt_id SET NOT NULL,
    ADD CONSTRAINT fk_revision_processing_logs_attempt
        FOREIGN KEY (attempt_id) REFERENCES processing_job_attempts(id) ON DELETE CASCADE;

ALTER TABLE revision_artifacts
    ADD CONSTRAINT fk_revision_artifacts_attempt
        FOREIGN KEY (attempt_id) REFERENCES processing_job_attempts(id) ON DELETE RESTRICT;

ALTER TABLE validation_runs
    ADD CONSTRAINT fk_validation_runs_attempt
        FOREIGN KEY (processing_attempt_id) REFERENCES processing_job_attempts(id) ON DELETE RESTRICT;

ALTER TABLE processing_job_attempts
    ADD CONSTRAINT fk_job_attempt_output_artifact
        FOREIGN KEY (output_artifact_id) REFERENCES revision_artifacts(id) ON DELETE RESTRICT;

ALTER TABLE processing_job_attempts
    ADD CONSTRAINT fk_job_attempt_result_validation
        FOREIGN KEY (result_validation_run_id) REFERENCES validation_runs(id) ON DELETE RESTRICT;

ALTER TABLE processing_jobs
    DROP CONSTRAINT IF EXISTS fk_processing_jobs_current_attempt;
ALTER TABLE processing_job_attempts
    ADD CONSTRAINT uq_processing_attempt_id_job UNIQUE (id, processing_job_id);
ALTER TABLE processing_jobs
    ADD CONSTRAINT fk_processing_jobs_current_attempt_job
        FOREIGN KEY (current_attempt_id, id) REFERENCES processing_job_attempts(id, processing_job_id) ON DELETE RESTRICT;

ALTER TABLE validation_runs
    DROP CONSTRAINT IF EXISTS uq_validation_run_attempt,
    ADD CONSTRAINT uq_validation_run_attempt_version
        UNIQUE (processing_attempt_id, validator_version, scope);

-- Release package is pinned to the exact artifact and manifest attestation.
ALTER TABLE release_packages
    ADD COLUMN candidate_artifact_id UUID NOT NULL,
    ADD COLUMN candidate_validation_run_id UUID NOT NULL,
    ADD COLUMN manifest_sha256 VARCHAR(64) NOT NULL,
    ADD CONSTRAINT fk_release_package_candidate_artifact
        FOREIGN KEY (candidate_artifact_id) REFERENCES revision_artifacts(id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_release_package_candidate_validation
        FOREIGN KEY (candidate_validation_run_id) REFERENCES validation_runs(id) ON DELETE RESTRICT,
    ADD CONSTRAINT check_release_package_manifest_hash
        CHECK (manifest_sha256 ~ '^[0-9a-fA-F]{64}$');

-- Every prepared/playtest session pins the exact artifact and validation run;
-- package bytes alone are not sufficient provenance when two attempts share an
-- S3 object hash.
ALTER TABLE sessions
    ADD COLUMN package_artifact_id UUID NOT NULL,
    ADD COLUMN package_validation_run_id UUID NOT NULL,
    ADD CONSTRAINT fk_session_package_artifact
        FOREIGN KEY (package_artifact_id) REFERENCES revision_artifacts(id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_session_package_validation
        FOREIGN KEY (package_validation_run_id) REFERENCES validation_runs(id) ON DELETE RESTRICT;
ALTER TABLE playtest_sessions
    ADD COLUMN package_artifact_id UUID NOT NULL,
    ADD COLUMN package_validation_run_id UUID NOT NULL,
    ADD CONSTRAINT fk_playtest_package_artifact
        FOREIGN KEY (package_artifact_id) REFERENCES revision_artifacts(id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_playtest_package_validation
        FOREIGN KEY (package_validation_run_id) REFERENCES validation_runs(id) ON DELETE RESTRICT;

-- Package/identity preparation checks are declared after the target columns and
-- foreign keys exist. Start still performs the online entitlement and runtime
-- compatibility gate; this trigger only prevents an invalid preparation row.
CREATE OR REPLACE FUNCTION validate_session_preparation_provenance()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog, public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users AS trainee
         WHERE trainee.id = NEW.trainee_user_id
           AND trainee.role = 'Trainee' AND trainee.is_active AND trainee.deleted_at IS NULL
    ) THEN RAISE EXCEPTION 'prepared session requires an active Trainee'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.user_devices AS device
         WHERE device.id = NEW.device_id AND device.user_id = NEW.trainee_user_id
    ) THEN RAISE EXCEPTION 'prepared session device must belong to the Trainee'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.trainings AS training
         WHERE training.id = NEW.training_id AND training.release_id = NEW.release_id
           AND training.scenario_version_id = NEW.scenario_version_id
           AND training.organization_id = NEW.organization_id
           AND training.status = 'Active' AND NEW.mode::TEXT = ANY(training.allowed_modes)
    ) THEN RAISE EXCEPTION 'prepared session requires a matching Active Training and mode'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.releases AS release
         WHERE release.id = NEW.release_id AND release.status = 'Published'
           AND release.scenario_version_id = NEW.scenario_version_id
           AND release.organization_id = NEW.organization_id
    ) THEN RAISE EXCEPTION 'prepared session requires a matching Published release'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.release_qr_codes AS qr
         JOIN public.releases AS release ON release.id = NEW.release_id
         WHERE qr.id = NEW.qr_code_id AND qr.building_id = release.building_id
           AND qr.organization_id = NEW.organization_id AND qr.is_active
    ) THEN RAISE EXCEPTION 'prepared session requires an active Building QR'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.release_packages AS package
          JOIN public.releases AS release ON release.id = package.release_id
          JOIN public.validation_runs AS run
            ON run.id = NEW.package_validation_run_id
           AND run.release_id = NEW.release_id
           AND run.artifact_id = NEW.package_artifact_id
           AND run.status = 'Passed'
          JOIN public.revision_artifacts AS artifact
            ON artifact.id = NEW.package_artifact_id
           AND artifact.revision_id = release.revision_id
           AND artifact.sha256_hash = NEW.package_hash
         WHERE package.release_id = NEW.release_id
           AND package.candidate_artifact_id = NEW.package_artifact_id
           AND package.candidate_validation_run_id = NEW.package_validation_run_id
           AND package.checksum_sha256 = NEW.package_hash
           AND package.manifest_sha256 = NEW.manifest_sha256
           AND package.build_target = NEW.build_target
           AND package.protocol_version = NEW.protocol_version
           AND package.manifest_schema_version = NEW.manifest_schema_version
    ) THEN RAISE EXCEPTION 'prepared session package provenance is invalid'; END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER validate_session_preparation_provenance_before_insert
BEFORE INSERT ON sessions FOR EACH ROW
EXECUTE FUNCTION validate_session_preparation_provenance();

-- Runtime compatibility metadata is mandatory; no fail-open 0.0.0/capability
-- default is allowed for a package or a playtest artifact.
ALTER TABLE release_packages
    DROP CONSTRAINT IF EXISTS check_release_package_runtime_metadata,
    ALTER COLUMN protocol_version DROP DEFAULT,
    ALTER COLUMN manifest_schema_version DROP DEFAULT,
    ALTER COLUMN required_capabilities DROP DEFAULT,
    ADD CONSTRAINT check_release_package_runtime_metadata_v2
        CHECK (
            NULLIF(pg_catalog.btrim(protocol_version), '') IS NOT NULL
            AND NULLIF(pg_catalog.btrim(manifest_schema_version), '') IS NOT NULL
            AND min_runtime_version ~ '^[0-9]+[.][0-9]+[.][0-9]+$'
            AND jsonb_typeof(required_capabilities) = 'array'
        );

-- Policy versions are referenced by both grants and usage snapshots.
ALTER TABLE ai_quota_grants
    ALTER COLUMN policy_version_id SET NOT NULL,
    ADD CONSTRAINT fk_ai_quota_grant_policy
        FOREIGN KEY (policy_version_id) REFERENCES ai_policy_versions(id) ON DELETE RESTRICT;
ALTER TABLE ai_usage_ledger
    ALTER COLUMN policy_version_id SET NOT NULL,
    ADD CONSTRAINT fk_ai_usage_policy
        FOREIGN KEY (policy_version_id) REFERENCES ai_policy_versions(id) ON DELETE RESTRICT;

-- A reservation may consume several pooled grants; the allocation table is the
-- authority and the old one-grant field is removed from the target model.
ALTER TABLE ai_usage_reservations
    DROP CONSTRAINT IF EXISTS ai_usage_reservations_quota_grant_id_fkey,
    DROP COLUMN IF EXISTS quota_grant_id;

ALTER TABLE ai_usage_ledger
    DROP CONSTRAINT IF EXISTS ai_usage_ledger_quota_grant_id_fkey,
    DROP COLUMN IF EXISTS quota_grant_id;

CREATE TABLE ai_usage_reservation_allocations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id      UUID REFERENCES ai_usage_reservations(id) ON DELETE CASCADE NOT NULL,
    quota_grant_id      UUID REFERENCES ai_quota_grants(id) ON DELETE RESTRICT NOT NULL,
    units               INT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_ai_allocation_units CHECK (units > 0),
    UNIQUE (reservation_id, quota_grant_id)
);

ALTER TABLE ai_overage_consents
    ADD CONSTRAINT check_ai_consent_terms_snapshot
        CHECK (jsonb_typeof(terms_snapshot) = 'object');

ALTER TABLE revision_reviews
    ALTER COLUMN reviewed_at SET DEFAULT NOW(),
    ALTER COLUMN reviewed_at SET NOT NULL;

-- Common sources are unique within the common corpus; organization sources
-- are unique only inside their owning organization. The partial indexes avoid
-- SQL NULL semantics allowing duplicate common documents.
CREATE UNIQUE INDEX uq_knowledge_common_source_identity
    ON knowledge_sources (source_hash, version_label)
    WHERE visibility = 'Common' AND organization_id IS NULL;
CREATE UNIQUE INDEX uq_knowledge_organization_source_identity
    ON knowledge_sources (organization_id, source_hash, version_label)
    WHERE visibility = 'Organization';

ALTER TABLE ai_billing_periods
    ADD COLUMN disputed_at TIMESTAMPTZ,
    ADD COLUMN disputed_reason TEXT,
    ADD COLUMN disputed_by UUID REFERENCES users(id) ON DELETE RESTRICT,
    DROP CONSTRAINT IF EXISTS check_ai_period_status,
    ADD CONSTRAINT check_ai_period_status_v2
        CHECK (status IN ('Open','Closed','Invoiced','Paid')),
    ADD CONSTRAINT check_ai_period_dispute_metadata
        CHECK ((disputed_at IS NULL AND disputed_reason IS NULL AND disputed_by IS NULL)
            OR (disputed_at IS NOT NULL AND NULLIF(pg_catalog.btrim(disputed_reason), '') IS NOT NULL AND disputed_by IS NOT NULL));

ALTER TABLE ai_requests
    ADD CONSTRAINT check_ai_request_citations_array
        CHECK (jsonb_typeof(citations) = 'array'),
    ADD CONSTRAINT check_ai_request_technical_usage_object
        CHECK (jsonb_typeof(technical_usage) = 'object');

ALTER TABLE scenario_drafts
    ADD CONSTRAINT fk_scenario_drafts_ai_request
        FOREIGN KEY (last_ai_request_id) REFERENCES ai_requests(id) ON DELETE SET NULL;

-- Knowledge identity is scoped to tenant; common and private copies may share
-- a source hash without colliding globally.
ALTER TABLE knowledge_sources
    DROP CONSTRAINT IF EXISTS knowledge_sources_organization_id_visibility_source_hash_version_label_key;
CREATE UNIQUE INDEX uq_knowledge_common_source
    ON knowledge_sources(source_hash, version_label)
    WHERE visibility = 'Common';
CREATE UNIQUE INDEX uq_knowledge_organization_source
    ON knowledge_sources(organization_id, source_hash, version_label)
    WHERE visibility = 'Organization';

-- NULL organization_id represents a common policy. Partial indexes prevent
-- duplicate common versions while keeping organization policies tenant-scoped.
ALTER TABLE ai_policy_versions
    DROP CONSTRAINT IF EXISTS ai_policy_versions_organization_id_audience_policy_kind_version_label_key;
CREATE UNIQUE INDEX uq_ai_common_policy_version
    ON ai_policy_versions(audience, policy_kind, version_label)
    WHERE organization_id IS NULL;
CREATE UNIQUE INDEX uq_ai_organization_policy_version
    ON ai_policy_versions(organization_id, audience, policy_kind, version_label)
    WHERE organization_id IS NOT NULL;

-- Quotation and AI-period lifecycle gates are implemented by the canonical
-- validators below. The former *_lifecycle_v2 triggers were removed because
-- they duplicated immutable-field and document-transition checks and diverged
-- from the line-based quotation model.

CREATE OR REPLACE FUNCTION validate_release_package_provenance_v2()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_release_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN v_release_id := OLD.release_id; ELSE v_release_id := NEW.release_id; END IF;
    IF TG_OP = 'DELETE' AND (
        EXISTS (SELECT 1 FROM public.releases AS release WHERE release.id = v_release_id AND release.status IN ('Published','Superseded','Revoked'))
        OR EXISTS (SELECT 1 FROM public.sessions AS session WHERE session.release_id = v_release_id)
    ) THEN
        RAISE EXCEPTION 'release package is pinned by publication or session and cannot be deleted';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.release_id IS DISTINCT FROM NEW.release_id
        OR OLD.candidate_artifact_id IS DISTINCT FROM NEW.candidate_artifact_id
        OR OLD.candidate_validation_run_id IS DISTINCT FROM NEW.candidate_validation_run_id
        OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
        OR OLD.checksum_sha256 IS DISTINCT FROM NEW.checksum_sha256
        OR OLD.manifest_url IS DISTINCT FROM NEW.manifest_url
        OR OLD.package_url IS DISTINCT FROM NEW.package_url
        OR OLD.package_size_bytes IS DISTINCT FROM NEW.package_size_bytes
        OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
        OR OLD.manifest_schema_version IS DISTINCT FROM NEW.manifest_schema_version
        OR OLD.min_runtime_version IS DISTINCT FROM NEW.min_runtime_version
        OR OLD.required_capabilities IS DISTINCT FROM NEW.required_capabilities
        OR OLD.build_target IS DISTINCT FROM NEW.build_target
    ) AND (
        EXISTS (SELECT 1 FROM public.releases AS release WHERE release.id IN (OLD.release_id, NEW.release_id) AND release.status IN ('Published','Superseded','Revoked'))
        OR EXISTS (SELECT 1 FROM public.sessions AS session WHERE session.release_id IN (OLD.release_id, NEW.release_id))
    ) THEN
        RAISE EXCEPTION 'published or pinned package metadata is immutable; create a new release';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.releases AS release
         WHERE release.id = NEW.release_id
           AND release.revision_id = (
               SELECT artifact.revision_id FROM public.revision_artifacts AS artifact
                WHERE artifact.id = NEW.candidate_artifact_id
           )
    ) THEN
        RAISE EXCEPTION 'release package artifact must belong to the release revision';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.revision_artifacts AS artifact
         WHERE artifact.id = NEW.candidate_artifact_id
           AND artifact.sha256_hash = NEW.checksum_sha256
           AND artifact.metadata ->> 'manifest_sha256' = NEW.manifest_sha256
           AND artifact.metadata ->> 'build_target' = NEW.build_target
    ) THEN
        RAISE EXCEPTION 'release package checksum must attest the pinned candidate artifact';
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM public.validation_runs AS run
          JOIN public.releases AS release ON release.id = NEW.release_id
         WHERE run.id = NEW.candidate_validation_run_id
           AND run.release_id = NEW.release_id
           AND run.revision_id = release.revision_id
           AND run.scenario_version_id = release.scenario_version_id
           AND run.artifact_id = NEW.candidate_artifact_id
           AND run.scope = 'ReleasePackage'
           AND run.status IN ('Queued','Running','Passed')
    ) THEN
        RAISE EXCEPTION 'release package must pin a valid validation run for its exact artifact and release';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER zz_validate_release_package_provenance
BEFORE INSERT OR UPDATE OR DELETE ON release_packages
FOR EACH ROW EXECUTE FUNCTION validate_release_package_provenance_v2();

CREATE OR REPLACE FUNCTION enforce_session_transition_v2()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_authorized BOOLEAN := CURRENT_USER = 'fet3d_session_owner'
        AND COALESCE(pg_catalog.current_setting('fet3d.session_start_id', true), '') = NEW.id::TEXT;
BEGIN
    IF OLD.training_id IS DISTINCT FROM NEW.training_id
       OR OLD.release_id IS DISTINCT FROM NEW.release_id
       OR OLD.scenario_version_id IS DISTINCT FROM NEW.scenario_version_id
       OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
       OR OLD.trainee_user_id IS DISTINCT FROM NEW.trainee_user_id
       OR OLD.device_id IS DISTINCT FROM NEW.device_id
       OR OLD.qr_code_id IS DISTINCT FROM NEW.qr_code_id
       OR OLD.mode IS DISTINCT FROM NEW.mode
       OR OLD.package_hash IS DISTINCT FROM NEW.package_hash
       OR OLD.package_artifact_id IS DISTINCT FROM NEW.package_artifact_id
       OR OLD.package_validation_run_id IS DISTINCT FROM NEW.package_validation_run_id
       OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
       OR OLD.manifest_schema_version IS DISTINCT FROM NEW.manifest_schema_version
       OR OLD.prepare_idempotency_key IS DISTINCT FROM NEW.prepare_idempotency_key
    THEN RAISE EXCEPTION 'session training, package and identity pins are immutable'; END IF;

    IF OLD.status = 'Created' AND (
        NEW.status <> OLD.status
        OR OLD.start_idempotency_key IS DISTINCT FROM NEW.start_idempotency_key
        OR OLD.launch_granted_at IS DISTINCT FROM NEW.launch_granted_at
        OR OLD.started_at IS DISTINCT FROM NEW.started_at
        OR OLD.runtime_version IS DISTINCT FROM NEW.runtime_version
        OR OLD.runtime_catalog_id IS DISTINCT FROM NEW.runtime_catalog_id
    ) AND NOT v_authorized THEN
        RAISE EXCEPTION 'only actor-bound online start may launch a session';
    END IF;

    IF OLD.started_at IS NOT NULL AND OLD.started_at IS DISTINCT FROM NEW.started_at THEN
        RAISE EXCEPTION 'started_at is immutable after gameplay begins';
    END IF;
    IF OLD.status IN ('Completed','CompletedWithSupersededRelease','ScenarioUnsurvivable','Aborted','Abandoned','Crashed')
       AND NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'terminal session cannot be reopened';
    END IF;
    IF OLD.status = 'Running' AND NEW.status NOT IN ('Running','Completed','CompletedWithSupersededRelease','ScenarioUnsurvivable','Aborted','Abandoned','Crashed') THEN
        RAISE EXCEPTION 'Running session has an invalid next state';
    END IF;
    IF OLD.status = 'Launching' AND NEW.status NOT IN ('Launching','Running','Aborted','Crashed') THEN
        RAISE EXCEPTION 'Launching session has an invalid next state';
    END IF;
    IF NEW.status IN ('Launching','Running') AND (NEW.launch_granted_at IS NULL OR NEW.start_idempotency_key IS NULL) THEN
        RAISE EXCEPTION 'gameplay state requires a launch grant and start key';
    END IF;
    IF NEW.status = 'Running' AND NEW.started_at IS NULL THEN
        RAISE EXCEPTION 'Running session requires started_at';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION enforce_playtest_transition_v2()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_authorized BOOLEAN := CURRENT_USER = 'fet3d_session_owner'
        AND COALESCE(pg_catalog.current_setting('fet3d.playtest_start_id', true), '') = NEW.id::TEXT;
    v_completion_authorized BOOLEAN := CURRENT_USER = 'fet3d_session_owner'
        AND COALESCE(pg_catalog.current_setting('fet3d.playtest_completion_id', true), '') = NEW.id::TEXT;
BEGIN
    IF OLD.organization_id IS DISTINCT FROM NEW.organization_id
       OR OLD.building_id IS DISTINCT FROM NEW.building_id
       OR OLD.revision_id IS DISTINCT FROM NEW.revision_id
       OR OLD.scenario_draft_id IS DISTINCT FROM NEW.scenario_draft_id
       OR OLD.scenario_version_id IS DISTINCT FROM NEW.scenario_version_id
       OR OLD.service_entitlement_id IS DISTINCT FROM NEW.service_entitlement_id
       OR OLD.created_by IS DISTINCT FROM NEW.created_by
       OR OLD.package_hash IS DISTINCT FROM NEW.package_hash
       OR OLD.package_artifact_id IS DISTINCT FROM NEW.package_artifact_id
        OR OLD.package_validation_run_id IS DISTINCT FROM NEW.package_validation_run_id
       OR (OLD.completion_idempotency_key IS DISTINCT FROM NEW.completion_idempotency_key
           AND NOT v_completion_authorized)
        OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
       OR OLD.manifest_schema_version IS DISTINCT FROM NEW.manifest_schema_version
    THEN RAISE EXCEPTION 'playtest tenant, scenario, package and creator pins are immutable'; END IF;
    IF OLD.status = 'Created' AND (
        NEW.status <> OLD.status
        OR OLD.start_idempotency_key IS DISTINCT FROM NEW.start_idempotency_key
        OR OLD.started_at IS DISTINCT FROM NEW.started_at
        OR OLD.runtime_version IS DISTINCT FROM NEW.runtime_version
        OR OLD.runtime_catalog_id IS DISTINCT FROM NEW.runtime_catalog_id
    ) AND NOT v_authorized THEN
        RAISE EXCEPTION 'only actor-bound online start may launch a playtest';
    END IF;
    IF OLD.status IN ('Completed','Aborted','Failed') AND NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'terminal playtest cannot be reopened';
    END IF;
    IF NEW.status = 'Running' AND (NEW.start_idempotency_key IS NULL OR NEW.started_at IS NULL) THEN
        RAISE EXCEPTION 'Running playtest requires an online start';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER zz_enforce_session_transition
BEFORE UPDATE ON sessions
FOR EACH ROW EXECUTE FUNCTION enforce_session_transition_v2();

CREATE TRIGGER zz_enforce_playtest_transition
BEFORE UPDATE ON playtest_sessions
FOR EACH ROW EXECUTE FUNCTION enforce_playtest_transition_v2();

CREATE OR REPLACE FUNCTION enforce_ai_request_write_v2()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND (
        NEW.status <> 'Accepted'
        OR NEW.result_type IS NOT NULL
        OR NEW.result_reference IS NOT NULL
        OR NEW.response_snapshot IS NOT NULL
        OR NEW.citations IS DISTINCT FROM '[]'::JSONB
        OR NEW.model_provider IS NOT NULL
        OR NEW.model_version IS NOT NULL
        OR NEW.technical_usage IS DISTINCT FROM '{}'::JSONB
        OR NEW.failure_code IS NOT NULL
        OR NEW.completed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'new AI requests must enter Accepted state without a result';
    END IF;
    IF TG_OP = 'INSERT' AND NOT EXISTS (
        SELECT 1
          FROM public.ai_policy_versions AS policy
         WHERE policy.id = NEW.policy_version_id
           AND policy.audience IN (NEW.audience, 'common')
           AND (policy.organization_id IS NULL OR policy.organization_id = NEW.organization_id)
           AND policy.effective_from <= pg_catalog.clock_timestamp()
           AND (policy.effective_until IS NULL OR policy.effective_until > pg_catalog.clock_timestamp())
    ) THEN
        RAISE EXCEPTION 'AI request policy version is not valid for its audience and tenant';
    END IF;
    IF TG_OP = 'INSERT' AND NEW.audience = 'organization' AND NOT EXISTS (
        SELECT 1 FROM public.users AS requester
         WHERE requester.id = NEW.user_id
           AND requester.role = 'OrganizationUser'
           AND requester.organization_id = NEW.organization_id
           AND requester.is_active
           AND requester.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'organization AI request must belong to an active OrganizationUser in the same tenant';
    END IF;
    IF TG_OP = 'INSERT' AND NEW.audience = 'trainee' AND NOT EXISTS (
        SELECT 1 FROM public.users AS trainee
         WHERE trainee.id = NEW.user_id
           AND trainee.role = 'Trainee'
           AND trainee.is_active
           AND trainee.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'trainee AI request must belong to an active Trainee';
    END IF;
    IF TG_OP = 'INSERT' AND NEW.audience = 'organization'
       AND NEW.building_id IS NOT NULL
       AND NOT EXISTS (
        SELECT 1 FROM public.buildings AS building
         WHERE building.id = NEW.building_id
           AND building.organization_id = NEW.organization_id
           AND building.is_active
           AND building.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'AI request building must belong to the same active organization';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.idempotency_key IS DISTINCT FROM NEW.idempotency_key
        OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.building_id IS DISTINCT FROM NEW.building_id
        OR OLD.user_id IS DISTINCT FROM NEW.user_id
         OR OLD.audience IS DISTINCT FROM NEW.audience
         OR OLD.request_type IS DISTINCT FROM NEW.request_type
         OR OLD.source_scope IS DISTINCT FROM NEW.source_scope
         OR OLD.policy_version_id IS DISTINCT FROM NEW.policy_version_id
         OR OLD.input_hash IS DISTINCT FROM NEW.input_hash
         OR OLD.input_reference IS DISTINCT FROM NEW.input_reference
    ) THEN
        RAISE EXCEPTION 'AI request identity, scope and input hash are immutable';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status <> NEW.status AND NOT (
        (OLD.status = 'Accepted' AND NEW.status IN ('Processing','Rejected'))
        OR (OLD.status = 'Processing' AND NEW.status IN ('Succeeded','Failed','NeedsReconcile'))
        OR (OLD.status = 'NeedsReconcile' AND NEW.status IN ('Succeeded','Failed'))
        OR (OLD.status = NEW.status)
    ) THEN
        RAISE EXCEPTION 'AI request status transition is not allowed';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status IN ('Succeeded','Failed','Rejected') AND (
        OLD.result_type IS DISTINCT FROM NEW.result_type
        OR OLD.result_reference IS DISTINCT FROM NEW.result_reference
         OR OLD.response_snapshot IS DISTINCT FROM NEW.response_snapshot
         OR OLD.result_hash IS DISTINCT FROM NEW.result_hash
        OR OLD.citations IS DISTINCT FROM NEW.citations
        OR OLD.model_provider IS DISTINCT FROM NEW.model_provider
        OR OLD.model_version IS DISTINCT FROM NEW.model_version
        OR OLD.technical_usage IS DISTINCT FROM NEW.technical_usage
        OR OLD.failure_code IS DISTINCT FROM NEW.failure_code
        OR OLD.completed_at IS DISTINCT FROM NEW.completed_at
    ) THEN
        RAISE EXCEPTION 'terminal AI request result is immutable; identical replay is a no-op';
    END IF;
    IF NEW.status = 'Succeeded' AND (
        NEW.result_type IS NULL OR NEW.response_snapshot IS NULL
        OR NEW.result_hash IS NULL
        OR pg_catalog.jsonb_typeof(NEW.citations) <> 'array'
        OR pg_catalog.jsonb_typeof(NEW.technical_usage) <> 'object'
        OR NEW.model_provider IS NULL OR NEW.model_version IS NULL
        OR NEW.completed_at IS NULL
    ) THEN
        RAISE EXCEPTION 'successful AI request requires result, model and completion evidence';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER zz_enforce_ai_request_write
BEFORE INSERT OR UPDATE ON ai_requests
FOR EACH ROW EXECUTE FUNCTION enforce_ai_request_write_v2();

CREATE OR REPLACE FUNCTION validate_ai_usage_provenance_v2()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_period public.ai_billing_periods%ROWTYPE;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.ai_requests AS request
         WHERE request.id = NEW.request_id
           AND request.user_id = NEW.user_id
           AND request.audience = NEW.audience
           AND request.request_type = NEW.request_type
           AND request.organization_id IS NOT DISTINCT FROM NEW.organization_id
           AND request.building_id IS NOT DISTINCT FROM NEW.building_id
    ) THEN
        RAISE EXCEPTION 'AI usage must match its durable request identity and tenant scope';
    END IF;
    IF NEW.policy_version_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.ai_policy_versions AS policy
         WHERE policy.id = NEW.policy_version_id
           AND (policy.audience = NEW.audience OR policy.audience = 'common')
           AND (policy.organization_id IS NULL OR policy.organization_id = NEW.organization_id)
    ) THEN
        RAISE EXCEPTION 'AI usage requires the applied quota/pricing policy version';
    END IF;

    IF NEW.audience = 'organization' THEN
        IF NEW.organization_id IS NULL OR (NEW.building_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.buildings AS building
             WHERE building.id = NEW.building_id AND building.organization_id = NEW.organization_id
        )) THEN
            RAISE EXCEPTION 'organization AI usage building must belong to the usage organization';
        END IF;
        IF NEW.billable AND (
            NEW.overage_consent_id IS NULL OR NEW.billing_period_id IS NULL
            OR pg_catalog.jsonb_typeof(NEW.unit_price_snapshot) <> 'object'
            OR NOT (NEW.unit_price_snapshot ? 'unit_price')
            OR NOT (NEW.unit_price_snapshot ? 'currency')
            OR (NEW.unit_price_snapshot ->> 'currency') !~ '^[A-Z]{3}$'
            OR (NEW.unit_price_snapshot ->> 'unit_price') !~ '^[0-9]+([.][0-9]+)?$'
        ) THEN
            RAISE EXCEPTION 'billable organization AI usage requires consent, period and price snapshot';
        END IF;
        IF NEW.overage_consent_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.ai_overage_consents AS consent
             WHERE consent.id = NEW.overage_consent_id
               AND consent.organization_id = NEW.organization_id
        ) THEN
            RAISE EXCEPTION 'AI overage consent must belong to the usage organization';
        END IF;
        IF NEW.billing_period_id IS NOT NULL THEN
            SELECT * INTO v_period
              FROM public.ai_billing_periods AS period
             WHERE period.id = NEW.billing_period_id
             FOR UPDATE;
            IF NOT FOUND
               OR v_period.organization_id IS DISTINCT FROM NEW.organization_id
               OR (TG_OP = 'INSERT' AND v_period.status <> 'Open') THEN
                RAISE EXCEPTION 'AI usage billing period must belong to the same organization';
            END IF;
        END IF;
    ELSE
        IF NEW.organization_id IS NOT NULL OR NEW.building_id IS NOT NULL
           OR NEW.billable OR NEW.overage_consent_id IS NOT NULL
           OR NEW.billing_period_id IS NOT NULL THEN
            RAISE EXCEPTION 'Trainee AI usage is user-scoped and non-billable';
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' AND (
        OLD.request_id IS DISTINCT FROM NEW.request_id
        OR OLD.idempotency_key IS DISTINCT FROM NEW.idempotency_key
        OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.building_id IS DISTINCT FROM NEW.building_id
        OR OLD.user_id IS DISTINCT FROM NEW.user_id
        OR OLD.audience IS DISTINCT FROM NEW.audience
        OR OLD.request_type IS DISTINCT FROM NEW.request_type
        OR OLD.policy_version_id IS DISTINCT FROM NEW.policy_version_id
        OR OLD.units IS DISTINCT FROM NEW.units
        OR OLD.overage_consent_id IS DISTINCT FROM NEW.overage_consent_id
        OR OLD.billable IS DISTINCT FROM NEW.billable
        OR OLD.unit_price_snapshot IS DISTINCT FROM NEW.unit_price_snapshot
        OR OLD.billing_period_id IS DISTINCT FROM NEW.billing_period_id
        OR OLD.source_scope IS DISTINCT FROM NEW.source_scope
    ) THEN
        RAISE EXCEPTION 'AI usage financial provenance is immutable';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_ai_usage_before_write ON ai_usage_ledger;
CREATE TRIGGER validate_ai_usage_before_write
BEFORE INSERT OR UPDATE ON ai_usage_ledger
FOR EACH ROW EXECUTE FUNCTION validate_ai_usage_provenance_v2();

-- Heartbeat is server-observed and monotonic; it is not an entitlement check.
CREATE OR REPLACE FUNCTION record_session_heartbeat(
    p_actor_id UUID, p_session_id UUID, p_sequence BIGINT, p_client_recorded_at TIMESTAMPTZ
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_session public.sessions%ROWTYPE;
BEGIN
    IF p_sequence IS NULL OR p_sequence < 0 THEN RAISE EXCEPTION 'heartbeat sequence must be a non-negative value'; END IF;
    SELECT * INTO v_session
      FROM public.sessions AS session
     WHERE session.id = p_session_id
       AND session.trainee_user_id = p_actor_id
       AND session.status IN ('Launching','Running')
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'heartbeat actor or active session is invalid'; END IF;
    IF v_session.last_heartbeat_sequence IS NOT NULL
       AND p_sequence <= v_session.last_heartbeat_sequence THEN
        RETURN true;
    END IF;
    UPDATE public.sessions AS session
       SET last_heartbeat_sequence = p_sequence,
           last_heartbeat_received_at = pg_catalog.clock_timestamp()
     WHERE session.id = p_session_id;
    RETURN true;
END;
$$;


-- Completion and offline event ingestion are separate from heartbeat. They
-- authorize the pinned session owner, but deliberately do not re-check current
-- entitlement or user activity after gameplay has started.
CREATE OR REPLACE FUNCTION record_session_event(
    p_actor_id UUID,
    p_session_id UUID,
    p_event_id UUID,
    p_sequence BIGINT,
    p_schema_version TEXT,
    p_event_type TEXT,
    p_event_data JSONB,
    p_recorded_at TIMESTAMPTZ
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_session public.sessions%ROWTYPE;
    v_event public.session_events%ROWTYPE;
BEGIN
    IF p_actor_id IS NULL OR p_session_id IS NULL OR p_event_id IS NULL
       OR p_sequence IS NULL OR p_sequence < 0
       OR NULLIF(pg_catalog.btrim(p_schema_version), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_event_type), '') IS NULL
       OR p_event_data IS NULL OR p_recorded_at IS NULL THEN
        RAISE EXCEPTION 'session event identity and payload are required';
    END IF;
    SELECT * INTO v_session FROM public.sessions
     WHERE id = p_session_id AND trainee_user_id = p_actor_id
       AND started_at IS NOT NULL
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'event requires the Trainee owner of a started session'; END IF;

    SELECT * INTO v_event FROM public.session_events WHERE id = p_event_id FOR UPDATE;
    IF FOUND THEN
        IF v_event.session_id = p_session_id
           AND v_event.sequence_number = p_sequence
           AND v_event.schema_version = pg_catalog.btrim(p_schema_version)
           AND v_event.event_type = pg_catalog.btrim(p_event_type)
           AND v_event.event_data = p_event_data
           AND v_event.recorded_at = p_recorded_at THEN
            RETURN true;
        END IF;
        RAISE EXCEPTION 'session event id conflicts with a different payload';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.session_events
         WHERE session_id = p_session_id AND sequence_number = p_sequence
    ) THEN
        RAISE EXCEPTION 'session event sequence conflicts with an existing event';
    END IF;
    INSERT INTO public.session_events(
        id, session_id, sequence_number, schema_version, event_type,
        event_data, recorded_at, received_at
    ) VALUES (
        p_event_id, p_session_id, p_sequence, pg_catalog.btrim(p_schema_version),
        pg_catalog.btrim(p_event_type), p_event_data, p_recorded_at,
        pg_catalog.clock_timestamp()
    );
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION complete_training_session(
    p_actor_id UUID,
    p_session_id UUID,
    p_result_idempotency_key TEXT,
    p_result_hash TEXT,
    p_result_snapshot JSONB,
    p_client_started_at TIMESTAMPTZ,
    p_client_ended_at TIMESTAMPTZ
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_session public.sessions%ROWTYPE;
    v_result public.session_results%ROWTYPE;
BEGIN
    IF p_actor_id IS NULL OR p_session_id IS NULL
       OR NULLIF(pg_catalog.btrim(p_result_idempotency_key), '') IS NULL
       OR p_result_hash IS NULL OR p_result_hash !~ '^[0-9a-fA-F]{64}$'
       OR p_result_snapshot IS NULL OR p_client_ended_at IS NULL
       OR (p_client_started_at IS NOT NULL AND p_client_started_at > p_client_ended_at) THEN
        RAISE EXCEPTION 'session result identity and payload are required';
    END IF;
    SELECT * INTO v_session FROM public.sessions
     WHERE id = p_session_id AND trainee_user_id = p_actor_id
       AND started_at IS NOT NULL
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'completion requires the Trainee owner of a started session'; END IF;

    SELECT * INTO v_result FROM public.session_results WHERE session_id = p_session_id FOR UPDATE;
    IF FOUND THEN
        IF v_result.result_idempotency_key = pg_catalog.btrim(p_result_idempotency_key)
           AND v_result.result_hash = lower(p_result_hash)
           AND v_result.result_snapshot = p_result_snapshot
           AND v_result.client_started_at IS NOT DISTINCT FROM p_client_started_at
           AND v_result.client_ended_at IS NOT DISTINCT FROM p_client_ended_at THEN
            RETURN p_session_id;
        END IF;
        RAISE EXCEPTION 'session result conflicts with an already accepted result';
    END IF;

    INSERT INTO public.session_results(
        session_id, result_idempotency_key, result_hash, result_snapshot,
        client_started_at, client_ended_at, is_synced, synced_at
    ) VALUES (
        p_session_id, pg_catalog.btrim(p_result_idempotency_key), lower(p_result_hash),
        p_result_snapshot, p_client_started_at, p_client_ended_at, true,
        pg_catalog.clock_timestamp()
    );
    IF v_session.status IN ('Launching','Running') THEN
        UPDATE public.sessions
           SET status = 'Completed', ended_at = pg_catalog.clock_timestamp()
         WHERE id = p_session_id;
    END IF;
    RETURN p_session_id;
END;
$$;

CREATE OR REPLACE FUNCTION complete_playtest_session(
    p_actor_id UUID,
    p_playtest_session_id UUID,
    p_completion_idempotency_key TEXT,
    p_terminal_status TEXT DEFAULT 'Completed'
)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_playtest public.playtest_sessions%ROWTYPE;
BEGIN
    IF p_actor_id IS NULL OR p_playtest_session_id IS NULL
       OR NULLIF(pg_catalog.btrim(p_completion_idempotency_key), '') IS NULL
       OR p_terminal_status NOT IN ('Completed','Aborted','Failed') THEN
        RAISE EXCEPTION 'playtest completion identity and terminal status are required';
    END IF;
    SELECT * INTO v_playtest FROM public.playtest_sessions
     WHERE id = p_playtest_session_id AND created_by = p_actor_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'playtest completion requires its owning OrganizationUser'; END IF;
    IF v_playtest.completion_idempotency_key IS NOT NULL THEN
        IF v_playtest.completion_idempotency_key = pg_catalog.btrim(p_completion_idempotency_key)
           AND v_playtest.status = p_terminal_status THEN
            RETURN v_playtest.id;
        END IF;
        RAISE EXCEPTION 'playtest completion key conflicts with an accepted result';
    END IF;
    IF v_playtest.status <> 'Running' THEN
        RAISE EXCEPTION 'only a started Running playtest can be completed';
    END IF;
    PERFORM pg_catalog.set_config(
        'fet3d.playtest_completion_id', p_playtest_session_id::TEXT, true
    );
    UPDATE public.playtest_sessions
       SET completion_idempotency_key = pg_catalog.btrim(p_completion_idempotency_key),
           status = p_terminal_status,
           ended_at = pg_catalog.clock_timestamp()
     WHERE id = p_playtest_session_id;
    RETURN p_playtest_session_id;
END;
$$;


-- Service roles are intentionally separate from the business-table owner.
-- AI/worker network access does not grant billing, entitlement or publication DML.
DO $service_roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_session_prepare_executor') THEN
        CREATE ROLE fet3d_session_prepare_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_session_sync_executor') THEN
        CREATE ROLE fet3d_session_sync_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_ai_service_executor') THEN
        CREATE ROLE fet3d_ai_service_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_processing_worker_executor') THEN
        CREATE ROLE fet3d_processing_worker_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
END;
$service_roles$;

REVOKE ALL PRIVILEGES ON TABLE sessions, playtest_sessions FROM PUBLIC;
REVOKE UPDATE, DELETE ON TABLE sessions, playtest_sessions FROM fet3d_backend_executor;
GRANT SELECT, INSERT ON TABLE sessions, playtest_sessions TO fet3d_session_prepare_executor;
GRANT EXECUTE ON FUNCTION start_training_session(UUID, UUID, TEXT, TEXT)
    TO fet3d_backend_executor;
GRANT EXECUTE ON FUNCTION start_playtest_session(UUID, UUID, TEXT, TEXT)
    TO fet3d_backend_executor;
GRANT EXECUTE ON FUNCTION record_session_heartbeat(UUID, UUID, BIGINT, TIMESTAMPTZ)
    TO fet3d_session_sync_executor;

REVOKE ALL PRIVILEGES ON TABLE ai_requests, ai_usage_ledger, ai_usage_reservations,
    ai_usage_reservation_allocations, ai_billing_periods, ai_billing_period_items,
    ai_billing_adjustments, ai_quota_grants, ai_overage_consents FROM PUBLIC;
REVOKE ALL PRIVILEGES ON TABLE payment_transactions, service_entitlements,
    quotations, releases, release_packages FROM fet3d_ai_service_executor, fet3d_processing_worker_executor;

-- ============================================================================
-- FINAL TARGET HARDENING — field ownership, close snapshots, worker fencing
-- and permission boundaries. This is design DDL, not an executable migration.
-- ============================================================================

CREATE OR REPLACE FUNCTION fet3d_capabilities_are_valid(p_capabilities JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog
AS $$
BEGIN
    IF p_capabilities IS NULL OR pg_catalog.jsonb_typeof(p_capabilities) <> 'array' THEN
        RETURN false;
    END IF;
    RETURN NOT EXISTS (
        SELECT 1
          FROM pg_catalog.jsonb_array_elements(p_capabilities) AS item(value)
         WHERE pg_catalog.jsonb_typeof(item.value) <> 'string'
             OR NULLIF(pg_catalog.btrim(item.value #>> '{}'), '') IS NULL
    );
END;
$$;

ALTER TABLE runtime_compatibility_catalog
    DROP CONSTRAINT IF EXISTS check_runtime_catalog_capabilities,
    ADD CONSTRAINT check_runtime_catalog_capabilities_v2
        CHECK (public.fet3d_capabilities_are_valid(capabilities));

ALTER TABLE release_packages
    DROP CONSTRAINT IF EXISTS check_release_package_capabilities,
    DROP CONSTRAINT IF EXISTS check_release_package_runtime_metadata_v2,
    ADD CONSTRAINT check_release_package_runtime_metadata_v3
        CHECK (
            NULLIF(pg_catalog.btrim(protocol_version), '') IS NOT NULL
            AND NULLIF(pg_catalog.btrim(manifest_schema_version), '') IS NOT NULL
            AND min_runtime_version ~ '^[0-9]+[.][0-9]+[.][0-9]+$'
            AND public.fet3d_capabilities_are_valid(required_capabilities)
        );

CREATE OR REPLACE FUNCTION fet3d_runtime_package_is_compatible(
    p_runtime_version TEXT,
    p_min_runtime_version TEXT,
    p_protocol_version TEXT,
    p_manifest_schema_version TEXT,
    p_required_capabilities JSONB,
    p_catalog_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SET search_path = pg_catalog
AS $$
DECLARE
    v_capabilities JSONB;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_runtime_version), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_min_runtime_version), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_protocol_version), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_manifest_schema_version), '') IS NULL
       OR p_catalog_id IS NULL
       OR NOT public.fet3d_capabilities_are_valid(p_required_capabilities) THEN
        RETURN false;
    END IF;
    SELECT catalog.capabilities INTO v_capabilities
      FROM public.runtime_compatibility_catalog AS catalog
     WHERE catalog.id = p_catalog_id
       AND catalog.is_active
       AND catalog.runtime_version = p_runtime_version
       AND catalog.protocol_version = p_protocol_version
       AND catalog.manifest_schema_version = p_manifest_schema_version
       AND public.fet3d_capabilities_are_valid(catalog.capabilities);
    IF NOT FOUND OR NOT public.fet3d_semver_gte(p_runtime_version, p_min_runtime_version) THEN
        RETURN false;
    END IF;
    RETURN NOT EXISTS (
        SELECT 1
          FROM pg_catalog.jsonb_array_elements_text(p_required_capabilities) AS required(capability)
         WHERE NOT (v_capabilities ? required.capability)
    );
END;
$$;

-- New artifact bytes may share one S3 object, but each processing attempt keeps
-- its own provenance row. The old revision/type/hash uniqueness was too broad.
ALTER TABLE revision_artifacts
    DROP CONSTRAINT IF EXISTS revision_artifacts_revision_id_artifact_type_sha256_hash_key,
    ADD CONSTRAINT uq_revision_artifact_attempt_hash
        UNIQUE (attempt_id, artifact_type, sha256_hash);

ALTER TABLE ai_billing_adjustments
    ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT,
    ADD COLUMN idempotency_key VARCHAR(255);

ALTER TABLE ai_billing_adjustments
    ALTER COLUMN organization_id SET NOT NULL,
    ALTER COLUMN idempotency_key SET NOT NULL,
    ADD CONSTRAINT uq_ai_billing_adjustment_idempotency UNIQUE (idempotency_key),
    ADD CONSTRAINT check_ai_billing_adjustment_idempotency
        CHECK (NULLIF(pg_catalog.btrim(idempotency_key), '') IS NOT NULL);

CREATE OR REPLACE FUNCTION enforce_processing_job_identity()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND (
        OLD.job_key IS DISTINCT FROM NEW.job_key
        OR OLD.revision_id IS DISTINCT FROM NEW.revision_id
        OR OLD.source_document_id IS DISTINCT FROM NEW.source_document_id
        OR OLD.scenario_version_id IS DISTINCT FROM NEW.scenario_version_id
        OR OLD.kind IS DISTINCT FROM NEW.kind
        OR OLD.input_hash IS DISTINCT FROM NEW.input_hash
    ) THEN
        RAISE EXCEPTION 'logical processing job identity and input hash are immutable; create a new job';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_processing_job_identity_before_write ON processing_jobs;
CREATE TRIGGER enforce_processing_job_identity_before_write
BEFORE UPDATE OF job_key, revision_id, source_document_id, scenario_version_id, kind, input_hash
ON processing_jobs FOR EACH ROW EXECUTE FUNCTION enforce_processing_job_identity();

CREATE OR REPLACE FUNCTION enforce_revision_artifact_immutability()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
BEGIN
    RAISE EXCEPTION 'revision artifacts are immutable; create a new artifact row for new bytes or metadata';
END;
$$;

DROP TRIGGER IF EXISTS enforce_revision_artifact_immutability_before_write ON revision_artifacts;
CREATE TRIGGER enforce_revision_artifact_immutability_before_write
BEFORE UPDATE OR DELETE ON revision_artifacts
FOR EACH ROW EXECUTE FUNCTION enforce_revision_artifact_immutability();

CREATE OR REPLACE FUNCTION enforce_release_package_pin_immutability()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_release_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN v_release_id := OLD.release_id; ELSE v_release_id := NEW.release_id; END IF;
    IF TG_OP = 'DELETE' AND EXISTS (
        SELECT 1 FROM public.releases AS release
         WHERE release.id = v_release_id
           AND release.status IN ('Published','Superseded','Revoked')
    ) THEN
        RAISE EXCEPTION 'published or historical release package cannot be deleted';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.release_id IS DISTINCT FROM NEW.release_id
        OR OLD.candidate_artifact_id IS DISTINCT FROM NEW.candidate_artifact_id
        OR OLD.candidate_validation_run_id IS DISTINCT FROM NEW.candidate_validation_run_id
        OR OLD.manifest_sha256 IS DISTINCT FROM NEW.manifest_sha256
        OR OLD.checksum_sha256 IS DISTINCT FROM NEW.checksum_sha256
        OR OLD.manifest_url IS DISTINCT FROM NEW.manifest_url
        OR OLD.package_url IS DISTINCT FROM NEW.package_url
        OR OLD.package_size_bytes IS DISTINCT FROM NEW.package_size_bytes
        OR OLD.protocol_version IS DISTINCT FROM NEW.protocol_version
        OR OLD.manifest_schema_version IS DISTINCT FROM NEW.manifest_schema_version
        OR OLD.min_runtime_version IS DISTINCT FROM NEW.min_runtime_version
        OR OLD.required_capabilities IS DISTINCT FROM NEW.required_capabilities
        OR OLD.build_target IS DISTINCT FROM NEW.build_target
    ) AND (
        EXISTS (SELECT 1 FROM public.releases AS release WHERE release.id IN (OLD.release_id, NEW.release_id) AND release.status IN ('Published','Superseded','Revoked'))
        OR EXISTS (SELECT 1 FROM public.sessions AS session WHERE session.release_id IN (OLD.release_id, NEW.release_id))
    ) THEN
        RAISE EXCEPTION 'release package pinned by publication or session; create a new release/package';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_release_package_pin_immutability_before_write ON release_packages;
CREATE TRIGGER enforce_release_package_pin_immutability_before_write
BEFORE UPDATE OR DELETE ON release_packages
FOR EACH ROW EXECUTE FUNCTION enforce_release_package_pin_immutability();

-- A closed period is an immutable membership and price snapshot. Late or
-- disputed usage is represented by an adjustment, never by editing an item.
CREATE OR REPLACE FUNCTION enforce_ai_billing_period_item_write()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_period public.ai_billing_periods%ROWTYPE;
    v_usage public.ai_usage_ledger%ROWTYPE;
    v_period_id UUID;
BEGIN
    v_period_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.billing_period_id ELSE NEW.billing_period_id END;
    SELECT * INTO v_period
      FROM public.ai_billing_periods
     WHERE id = v_period_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI billing period does not exist'; END IF;
    IF v_period.status <> 'Open' THEN
        RAISE EXCEPTION 'AI billing period items are immutable after close';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.billing_period_id IS DISTINCT FROM NEW.billing_period_id
        OR OLD.usage_ledger_id IS DISTINCT FROM NEW.usage_ledger_id
    ) THEN
        RAISE EXCEPTION 'AI period item membership is immutable; use an adjustment or a new item';
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        SELECT * INTO v_usage FROM public.ai_usage_ledger WHERE id = NEW.usage_ledger_id FOR SHARE;
        IF NOT FOUND OR v_usage.organization_id IS DISTINCT FROM v_period.organization_id
           OR v_usage.billing_period_id IS DISTINCT FROM NEW.billing_period_id
           OR NOT v_usage.billable OR v_usage.status <> 'Recorded'
           OR v_usage.units IS DISTINCT FROM NEW.units THEN
            RAISE EXCEPTION 'AI period item usage is not a confirmed billable usage in the same period';
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_ai_billing_period_item_write_before ON ai_billing_period_items;
CREATE TRIGGER enforce_ai_billing_period_item_write_before
BEFORE INSERT OR UPDATE OR DELETE ON ai_billing_period_items
FOR EACH ROW EXECUTE FUNCTION enforce_ai_billing_period_item_write();

CREATE OR REPLACE FUNCTION validate_ai_billing_period_write()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
DECLARE
    v_item_units INT;
    v_item_amount NUMERIC(14,2);
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NOT (
        (OLD.status = 'Open' AND NEW.status = 'Closed')
        OR (OLD.status = 'Closed' AND NEW.status = 'Invoiced')
        OR (OLD.status = 'Invoiced' AND NEW.status = 'Paid')
    ) THEN
        RAISE EXCEPTION 'AI billing period cannot reopen or skip its settlement lifecycle';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status = 'Closed' AND NEW.status = 'Invoiced'
       AND (OLD.settlement_quotation_id IS NOT NULL
            OR NEW.settlement_quotation_id IS NULL
            OR NEW.settlement_payment_transaction_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Closed to Invoiced requires one new AIUsage quotation and no payment';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status = 'Invoiced' AND NEW.status = 'Paid'
       AND (OLD.settlement_quotation_id IS NULL
            OR NEW.settlement_quotation_id IS DISTINCT FROM OLD.settlement_quotation_id
            OR NEW.settlement_payment_transaction_id IS NULL) THEN
        RAISE EXCEPTION 'Invoiced to Paid requires the existing quotation and one Applied payment';
    END IF;
    IF NEW.disputed_at IS NOT NULL AND NEW.status = 'Open' THEN
        RAISE EXCEPTION 'an Open AI period cannot carry dispute metadata';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.disputed_at IS NOT NULL AND (
        OLD.disputed_at IS DISTINCT FROM NEW.disputed_at
        OR OLD.disputed_reason IS DISTINCT FROM NEW.disputed_reason
        OR OLD.disputed_by IS DISTINCT FROM NEW.disputed_by
    ) THEN
        RAISE EXCEPTION 'AI dispute metadata is append-only';
    END IF;
    IF TG_OP = 'INSERT' AND (
        NEW.status <> 'Open'
        OR NEW.settlement_quotation_id IS NOT NULL
        OR NEW.settlement_payment_transaction_id IS NOT NULL
        OR NEW.closed_at IS NOT NULL
        OR NEW.unit_price_snapshot IS DISTINCT FROM '{}'::JSONB
        OR NEW.overage_units <> 0
        OR NEW.overage_amount <> 0
    ) THEN
        RAISE EXCEPTION 'new AI billing periods must start Open without settlement documents';
    END IF;

    IF NEW.settlement_quotation_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.quotations AS quotation
         WHERE quotation.id = NEW.settlement_quotation_id
            AND quotation.billing_purpose = 'AIUsage'
            AND quotation.organization_id = NEW.organization_id
            AND NOT EXISTS (
                SELECT 1 FROM public.quotation_building_items AS service_item
                WHERE service_item.quotation_id = quotation.id
           )
           AND quotation.currency = NEW.currency
           AND quotation.total_amount = NEW.overage_amount
    ) THEN
        RAISE EXCEPTION 'AI period quotation must be an issued AIUsage quotation matching the frozen snapshot';
    END IF;

    -- A quotation must be Issued/Accepted when it is attached. Once attached,
    -- a later expiry/cancellation does not erase a valid payment fact.
    IF NEW.settlement_quotation_id IS NOT NULL
       AND TG_OP = 'INSERT'
       AND NOT EXISTS (
           SELECT 1 FROM public.quotations AS quotation
            WHERE quotation.id = NEW.settlement_quotation_id
              AND quotation.status IN ('Issued','Accepted')
       ) THEN
        RAISE EXCEPTION 'AI period quotation must be Issued or Accepted when first attached';
    END IF;
    IF NEW.settlement_quotation_id IS NOT NULL
       AND TG_OP = 'UPDATE'
       AND OLD.settlement_quotation_id IS NULL
       AND NOT EXISTS (
           SELECT 1 FROM public.quotations AS quotation
            WHERE quotation.id = NEW.settlement_quotation_id
              AND quotation.status IN ('Issued','Accepted')
       ) THEN
        RAISE EXCEPTION 'AI period quotation must be Issued or Accepted when first attached';
    END IF;

    IF NEW.settlement_payment_transaction_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
          FROM public.payment_transactions AS payment
          JOIN public.payos_payment_requests AS request ON request.id = payment.payment_request_id
         WHERE payment.id = NEW.settlement_payment_transaction_id
           AND payment.status = 'Applied'
           AND request.quotation_id = NEW.settlement_quotation_id
           AND request.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'AI period payment must be Applied for its AIUsage quotation';
    END IF;

    IF NEW.status = 'Closed' THEN
        IF NEW.closed_at IS NULL OR NEW.settlement_quotation_id IS NOT NULL OR NEW.settlement_payment_transaction_id IS NOT NULL THEN
            RAISE EXCEPTION 'Closed AI periods require a close timestamp and no settlement document yet';
        END IF;
        SELECT COALESCE(SUM(units),0), COALESCE(SUM(amount),0)
          INTO v_item_units, v_item_amount
          FROM public.ai_billing_period_items
         WHERE billing_period_id = NEW.id AND status = 'Included';
        IF NEW.overage_units <> v_item_units OR NEW.overage_amount <> v_item_amount THEN
            RAISE EXCEPTION 'closed AI period totals must equal its included immutable items';
        END IF;
    END IF;
    IF NEW.status IN ('Invoiced','Paid') AND NEW.settlement_quotation_id IS NULL THEN
        RAISE EXCEPTION 'Invoiced or Paid AI periods require one AIUsage quotation';
    END IF;
    IF NEW.status = 'Invoiced' AND NEW.settlement_payment_transaction_id IS NOT NULL THEN
        RAISE EXCEPTION 'Invoiced AI periods cannot attach payment before Paid';
    END IF;
    IF NEW.status = 'Paid' AND NEW.settlement_payment_transaction_id IS NULL THEN
        RAISE EXCEPTION 'Paid AI periods require an Applied payment';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.status <> 'Open' AND (
        OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.period_start IS DISTINCT FROM NEW.period_start
        OR OLD.period_end IS DISTINCT FROM NEW.period_end
        OR OLD.unit_price_snapshot IS DISTINCT FROM NEW.unit_price_snapshot
        OR OLD.overage_units IS DISTINCT FROM NEW.overage_units
        OR OLD.overage_amount IS DISTINCT FROM NEW.overage_amount
        OR OLD.currency IS DISTINCT FROM NEW.currency
        OR OLD.closed_at IS DISTINCT FROM NEW.closed_at
    ) THEN
        RAISE EXCEPTION 'closed AI billing period snapshot and totals are immutable; use an adjustment';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION close_ai_billing_period(p_period_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_period public.ai_billing_periods%ROWTYPE;
    v_usage public.ai_usage_ledger%ROWTYPE;
    v_price NUMERIC;
    v_units INT;
    v_amount NUMERIC(14,2);
    v_price_snapshot JSONB;
BEGIN
    IF p_period_id IS NULL THEN
        RAISE EXCEPTION 'AI billing period id is required';
    END IF;
    SELECT * INTO v_period FROM public.ai_billing_periods WHERE id = p_period_id FOR UPDATE;
    IF NOT FOUND OR v_period.status <> 'Open' THEN
        RAISE EXCEPTION 'AI billing period is not open';
    END IF;

    FOR v_usage IN
        SELECT * FROM public.ai_usage_ledger
         WHERE organization_id = v_period.organization_id
           AND billing_period_id = v_period.id
           AND billable
           AND status = 'Recorded'
         ORDER BY id
         FOR UPDATE
    LOOP
        IF pg_catalog.jsonb_typeof(v_usage.unit_price_snapshot) <> 'object'
           OR NOT (v_usage.unit_price_snapshot ? 'unit_price')
           OR NOT (v_usage.unit_price_snapshot ? 'currency')
           OR v_usage.unit_price_snapshot ->> 'currency' <> v_period.currency
           OR (v_usage.unit_price_snapshot ->> 'unit_price') !~ '^[0-9]+([.][0-9]+)?$' THEN
            RAISE EXCEPTION 'recorded AI usage is missing a valid historical price/currency snapshot';
        END IF;
        v_price := (v_usage.unit_price_snapshot ->> 'unit_price')::NUMERIC;
        INSERT INTO public.ai_billing_period_items(
            billing_period_id, usage_ledger_id, units, unit_price_snapshot, amount
        ) VALUES (
            v_period.id, v_usage.id, v_usage.units, v_usage.unit_price_snapshot,
            ROUND(v_usage.units * v_price, 2)
        ) ON CONFLICT (billing_period_id, usage_ledger_id) DO NOTHING;
    END LOOP;

    SELECT COALESCE(SUM(units),0), COALESCE(SUM(amount),0)
      INTO v_units, v_amount
      FROM public.ai_billing_period_items
     WHERE billing_period_id = v_period.id AND status = 'Included';
    SELECT COALESCE(
        pg_catalog.jsonb_agg(DISTINCT item.unit_price_snapshot ORDER BY item.unit_price_snapshot),
        '[]'::JSONB
    ) INTO v_price_snapshot
      FROM public.ai_billing_period_items AS item
     WHERE item.billing_period_id = v_period.id AND item.status = 'Included';
    UPDATE public.ai_billing_periods
       SET unit_price_snapshot = v_price_snapshot,
           overage_units = v_units,
           overage_amount = v_amount,
           status = 'Closed',
           closed_at = pg_catalog.clock_timestamp()
     WHERE id = v_period.id;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION invoice_ai_billing_period(
    p_period_id UUID,
    p_quotation_id UUID
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_period public.ai_billing_periods%ROWTYPE;
BEGIN
    IF p_period_id IS NULL OR p_quotation_id IS NULL THEN
        RAISE EXCEPTION 'AI invoice period and quotation are required';
    END IF;
    SELECT * INTO v_period FROM public.ai_billing_periods WHERE id = p_period_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI billing period does not exist'; END IF;
    IF v_period.status IN ('Invoiced','Paid') THEN
        IF v_period.settlement_quotation_id = p_quotation_id THEN RETURN true; END IF;
        RAISE EXCEPTION 'AI billing period already has a different quotation';
    END IF;
    IF v_period.status <> 'Closed' THEN RAISE EXCEPTION 'only a Closed AI period can be invoiced'; END IF;
    UPDATE public.ai_billing_periods
       SET settlement_quotation_id = p_quotation_id, status = 'Invoiced'
     WHERE id = p_period_id;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION pay_ai_billing_period(
    p_period_id UUID,
    p_payment_transaction_id UUID
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_period public.ai_billing_periods%ROWTYPE;
BEGIN
    IF p_period_id IS NULL OR p_payment_transaction_id IS NULL THEN
        RAISE EXCEPTION 'AI payment period and transaction are required';
    END IF;
    SELECT * INTO v_period FROM public.ai_billing_periods WHERE id = p_period_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI billing period does not exist'; END IF;
    IF v_period.status = 'Paid' THEN
        IF v_period.settlement_payment_transaction_id = p_payment_transaction_id THEN RETURN true; END IF;
        RAISE EXCEPTION 'AI billing period already has a different payment';
    END IF;
    IF v_period.status <> 'Invoiced' THEN RAISE EXCEPTION 'only an Invoiced AI period can be paid'; END IF;
    UPDATE public.ai_billing_periods
       SET settlement_payment_transaction_id = p_payment_transaction_id, status = 'Paid'
     WHERE id = p_period_id;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION enforce_ai_policy_version_immutability()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = pg_catalog
AS $$
BEGIN
    RAISE EXCEPTION 'AI policy versions are immutable; create a new version';
END;
$$;

DROP TRIGGER IF EXISTS enforce_ai_policy_version_immutability_before_write ON ai_policy_versions;
CREATE TRIGGER enforce_ai_policy_version_immutability_before_write
BEFORE UPDATE OR DELETE ON ai_policy_versions
FOR EACH ROW EXECUTE FUNCTION enforce_ai_policy_version_immutability();

CREATE OR REPLACE FUNCTION validate_ai_billing_adjustment_write()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.ai_billing_periods AS period
         WHERE period.id = NEW.billing_period_id
           AND period.organization_id = NEW.organization_id
            AND period.status IN ('Closed','Invoiced','Paid')
    ) THEN
        RAISE EXCEPTION 'AI adjustment must target a closed period in the same organization';
    END IF;
    IF NEW.usage_ledger_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
          FROM public.ai_usage_ledger AS ledger
         WHERE ledger.id = NEW.usage_ledger_id
           AND ledger.organization_id = NEW.organization_id
           AND ledger.billing_period_id = NEW.billing_period_id
    ) THEN
        RAISE EXCEPTION 'AI adjustment usage must belong to the same organization and billing period';
    END IF;
    IF NEW.original_item_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
          FROM public.ai_billing_period_items AS item
         WHERE item.id = NEW.original_item_id
           AND item.billing_period_id = NEW.billing_period_id
    ) THEN
        RAISE EXCEPTION 'AI adjustment original item must belong to the target billing period';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        OLD.billing_period_id IS DISTINCT FROM NEW.billing_period_id
        OR OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.usage_ledger_id IS DISTINCT FROM NEW.usage_ledger_id
        OR OLD.original_item_id IS DISTINCT FROM NEW.original_item_id
        OR OLD.adjustment_type IS DISTINCT FROM NEW.adjustment_type
        OR OLD.units IS DISTINCT FROM NEW.units
        OR OLD.amount IS DISTINCT FROM NEW.amount
        OR OLD.reason IS DISTINCT FROM NEW.reason
        OR OLD.idempotency_key IS DISTINCT FROM NEW.idempotency_key
    ) THEN
        RAISE EXCEPTION 'AI billing adjustments are immutable';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_ai_billing_adjustment_before_write ON ai_billing_adjustments;
CREATE TRIGGER validate_ai_billing_adjustment_before_write
BEFORE INSERT OR UPDATE ON ai_billing_adjustments
FOR EACH ROW EXECUTE FUNCTION validate_ai_billing_adjustment_write();

-- Late usage and financial corrections use a controlled accounting contract;
-- callers do not receive direct INSERT permission on the adjustment table.
CREATE OR REPLACE FUNCTION record_ai_billing_adjustment(
    p_billing_period_id UUID,
    p_organization_id UUID,
    p_usage_ledger_id UUID,
    p_original_item_id UUID,
    p_adjustment_type TEXT,
    p_units INT,
    p_amount NUMERIC,
    p_reason TEXT,
    p_idempotency_key TEXT,
    p_created_by UUID
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_id UUID;
    v_existing public.ai_billing_adjustments%ROWTYPE;
BEGIN
    IF p_billing_period_id IS NULL OR p_organization_id IS NULL
       OR p_adjustment_type IS NULL OR p_units IS NULL OR p_amount IS NULL
       OR NULLIF(pg_catalog.btrim(p_reason), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_idempotency_key), '') IS NULL
       OR p_created_by IS NULL THEN
        RAISE EXCEPTION 'AI adjustment identity and financial fields are required';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.users AS actor
         WHERE actor.id = p_created_by
           AND actor.is_active
           AND actor.deleted_at IS NULL
           AND (actor.role = 'PlatformAdmin'
                OR (actor.role = 'OrganizationUser' AND actor.organization_id = p_organization_id))
    ) THEN
        RAISE EXCEPTION 'adjustment actor is not authorized for the organization';
    END IF;

    INSERT INTO public.ai_billing_adjustments(
        billing_period_id, organization_id, usage_ledger_id, original_item_id,
        adjustment_type, units, amount, reason, idempotency_key, created_by
    ) VALUES (
        p_billing_period_id, p_organization_id, p_usage_ledger_id, p_original_item_id,
        p_adjustment_type, p_units, p_amount, pg_catalog.btrim(p_reason),
        pg_catalog.btrim(p_idempotency_key), p_created_by
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NOT NULL THEN
        RETURN v_id;
    END IF;

    SELECT * INTO v_existing
      FROM public.ai_billing_adjustments
     WHERE idempotency_key = pg_catalog.btrim(p_idempotency_key);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'adjustment idempotency result is unavailable';
    END IF;
    IF v_existing.billing_period_id IS DISTINCT FROM p_billing_period_id
       OR v_existing.organization_id IS DISTINCT FROM p_organization_id
       OR v_existing.usage_ledger_id IS DISTINCT FROM p_usage_ledger_id
       OR v_existing.original_item_id IS DISTINCT FROM p_original_item_id
       OR v_existing.adjustment_type IS DISTINCT FROM p_adjustment_type
       OR v_existing.units IS DISTINCT FROM p_units
       OR v_existing.amount IS DISTINCT FROM p_amount
       OR v_existing.reason IS DISTINCT FROM pg_catalog.btrim(p_reason)
       OR v_existing.created_by IS DISTINCT FROM p_created_by THEN
        RAISE EXCEPTION 'adjustment idempotency key conflicts with another payload';
    END IF;
    RETURN v_existing.id;
END;
$$;

-- Rebind the early trigger names to the final functions after runtime columns
-- and target-only amendments exist; each function signature now has one owner.
DROP TRIGGER IF EXISTS validate_playtest_session_before_write ON playtest_sessions;
CREATE TRIGGER validate_playtest_session_before_write
BEFORE INSERT OR UPDATE OF organization_id, building_id, revision_id,
    scenario_draft_id, scenario_version_id, service_entitlement_id, package_hash,
    package_artifact_id, package_validation_run_id,
    manifest_sha256, build_target, protocol_version, manifest_schema_version,
    runtime_version, runtime_catalog_id, created_by,
    start_idempotency_key, status
ON playtest_sessions FOR EACH ROW EXECUTE FUNCTION validate_playtest_session_write();

DROP TRIGGER IF EXISTS validate_session_lifecycle_before_write ON sessions;
CREATE TRIGGER validate_session_lifecycle_before_write
BEFORE UPDATE OF training_id, release_id, scenario_version_id, organization_id,
    trainee_user_id, device_id, qr_code_id, mode, package_hash, manifest_sha256,
    package_artifact_id, package_validation_run_id,
    build_target, protocol_version, manifest_schema_version, prepare_idempotency_key,
    start_idempotency_key, status,
    launch_granted_at, started_at, ended_at, runtime_version, runtime_catalog_id
ON sessions FOR EACH ROW EXECUTE FUNCTION validate_training_session_lifecycle();

DROP TRIGGER IF EXISTS validate_ai_billing_period_before_write ON ai_billing_periods;
CREATE TRIGGER validate_ai_billing_period_before_write
BEFORE INSERT OR UPDATE
ON ai_billing_periods FOR EACH ROW EXECUTE FUNCTION validate_ai_billing_period_write();

DROP TRIGGER IF EXISTS validate_payos_paid_before_write ON payos_payment_requests;
CREATE TRIGGER validate_payos_paid_before_write
BEFORE INSERT OR UPDATE OF quotation_id, organization_id, requested_by, idempotency_key,
    order_code, expected_amount, expected_currency, status, paid_transaction_id, paid_at
ON payos_payment_requests FOR EACH ROW EXECUTE FUNCTION validate_payos_paid_request();

-- Worker results are intentionally structured at the contract boundary. The
-- SQL functions below are the target definitions used by the trusted worker
-- executor; clients never infer state from free-form exception text.
DROP FUNCTION IF EXISTS claim_processing_attempt(UUID, TEXT, TEXT, TEXT, INT);
CREATE FUNCTION claim_processing_attempt(
    p_job_id UUID, p_lease_owner TEXT, p_input_hash TEXT,
    p_toolchain_version TEXT, p_lease_seconds INT DEFAULT 300
)
RETURNS TABLE(result_code TEXT, attempt_id UUID, lease_token UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_job public.processing_jobs%ROWTYPE;
    v_current public.processing_job_attempts%ROWTYPE;
    v_attempt_id UUID;
    v_lease_token UUID;
    v_attempt_number INT;
    v_now TIMESTAMPTZ;
BEGIN
    IF p_job_id IS NULL OR p_lease_seconds IS NULL OR p_lease_seconds <= 0
       OR NULLIF(pg_catalog.btrim(p_lease_owner), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_toolchain_version), '') IS NULL
       OR p_input_hash IS NULL OR p_input_hash !~ '^[0-9a-fA-F]{64}$' THEN
        RETURN QUERY SELECT 'Conflict'::TEXT, NULL::UUID, NULL::UUID;
        RETURN;
    END IF;

    SELECT * INTO v_job FROM public.processing_jobs WHERE id = p_job_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'NotClaimable'::TEXT, NULL::UUID, NULL::UUID;
        RETURN;
    END IF;
    IF v_job.input_hash <> pg_catalog.btrim(p_input_hash) THEN
        RETURN QUERY SELECT 'Conflict'::TEXT, NULL::UUID, NULL::UUID;
        RETURN;
    END IF;
    IF v_job.status = 'Succeeded' THEN
        RETURN QUERY SELECT 'AlreadyCompleted'::TEXT, v_job.current_attempt_id, NULL::UUID;
        RETURN;
    END IF;
    IF v_job.status IN ('Cancelled','Failed') THEN
        RETURN QUERY SELECT 'NotClaimable'::TEXT, v_job.current_attempt_id, NULL::UUID;
        RETURN;
    END IF;

    v_now := pg_catalog.clock_timestamp();
    IF v_job.current_attempt_id IS NOT NULL THEN
        SELECT * INTO v_current
          FROM public.processing_job_attempts
         WHERE id = v_job.current_attempt_id
         FOR UPDATE;
        IF NOT FOUND THEN
            RETURN QUERY SELECT 'Conflict'::TEXT, NULL::UUID, NULL::UUID;
            RETURN;
        END IF;
        IF v_current.status = 'Running' AND v_current.lease_until IS NULL THEN
            RETURN QUERY SELECT 'Conflict'::TEXT, v_current.id, NULL::UUID;
            RETURN;
        END IF;
        IF v_current.status = 'Running' AND v_current.lease_until > v_now THEN
            RETURN QUERY SELECT 'Busy'::TEXT, v_current.id, NULL::UUID;
            RETURN;
        END IF;
        IF v_current.status = 'Succeeded' THEN
            UPDATE public.processing_jobs SET status = 'Succeeded' WHERE id = v_job.id;
            RETURN QUERY SELECT 'AlreadyCompleted'::TEXT, v_current.id, NULL::UUID;
            RETURN;
        END IF;
        IF v_current.status = 'Running' THEN
            UPDATE public.processing_job_attempts
               SET status = 'Expired', finished_at = v_now
             WHERE id = v_current.id;
        ELSIF v_current.status <> 'Expired' THEN
            RETURN QUERY SELECT 'NotClaimable'::TEXT, v_current.id, NULL::UUID;
            RETURN;
        END IF;
    END IF;
    IF v_job.status = 'Running' AND v_job.current_attempt_id IS NULL THEN
        RETURN QUERY SELECT 'Conflict'::TEXT, NULL::UUID, NULL::UUID;
        RETURN;
    END IF;

    SELECT COALESCE(MAX(attempt_number),0)+1 INTO v_attempt_number
      FROM public.processing_job_attempts
     WHERE processing_job_id = v_job.id;
    INSERT INTO public.processing_job_attempts AS attempt(
        processing_job_id, attempt_number, input_hash, toolchain_version,
        lease_owner, lease_token, lease_until, status
    ) VALUES (
        v_job.id, v_attempt_number, pg_catalog.btrim(p_input_hash),
        pg_catalog.btrim(p_toolchain_version), pg_catalog.btrim(p_lease_owner),
        gen_random_uuid(), v_now + make_interval(secs => p_lease_seconds), 'Running'
    ) RETURNING attempt.id, attempt.lease_token
      INTO v_attempt_id, v_lease_token;
    UPDATE public.processing_jobs
       SET current_attempt_id = v_attempt_id, status = 'Running'
     WHERE id = v_job.id;
    RETURN QUERY SELECT 'Claimed'::TEXT, v_attempt_id, v_lease_token;
END;
$$;

CREATE OR REPLACE FUNCTION renew_processing_attempt(
    p_attempt_id UUID, p_lease_token UUID, p_lease_seconds INT DEFAULT 300
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_job_id UUID;
    v_job public.processing_jobs%ROWTYPE;
    v_attempt public.processing_job_attempts%ROWTYPE;
    v_new_until TIMESTAMPTZ;
    v_now TIMESTAMPTZ;
BEGIN
    IF p_attempt_id IS NULL OR p_lease_token IS NULL OR p_lease_seconds IS NULL OR p_lease_seconds <= 0 THEN
        RAISE EXCEPTION 'processing lease token and duration are invalid';
    END IF;
    SELECT processing_job_id INTO v_job_id
      FROM public.processing_job_attempts WHERE id = p_attempt_id;
    SELECT * INTO v_job FROM public.processing_jobs WHERE id = v_job_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'processing job does not exist'; END IF;
    SELECT * INTO v_attempt
      FROM public.processing_job_attempts
     WHERE id = p_attempt_id
     FOR UPDATE;
    IF NOT FOUND OR v_job.current_attempt_id IS DISTINCT FROM v_attempt.id
       OR v_job.status <> 'Running'
       OR v_attempt.status <> 'Running'
       OR v_attempt.lease_token IS DISTINCT FROM p_lease_token
       OR v_attempt.lease_until IS NULL
       OR v_attempt.lease_until <= pg_catalog.clock_timestamp() THEN
        RAISE EXCEPTION 'processing attempt lease is stale or invalid';
    END IF;
    v_now := pg_catalog.clock_timestamp();
    IF v_attempt.lease_until IS NULL OR v_attempt.lease_until <= v_now THEN
        RAISE EXCEPTION 'processing attempt lease is stale or invalid';
    END IF;
    v_new_until := v_now + make_interval(secs => p_lease_seconds);
    IF v_new_until <= v_attempt.lease_until THEN
        RAISE EXCEPTION 'processing lease renewal cannot shorten the current lease';
    END IF;
    UPDATE public.processing_job_attempts SET lease_until = v_new_until WHERE id = v_attempt.id;
    RETURN true;
END;
$$;

-- The worker receives artifact/validation write access only through this
-- lease-bound gate. It cannot insert provenance rows directly or accept an
-- output that is not tied to the current job attempt.
CREATE OR REPLACE FUNCTION register_processing_output(
    p_attempt_id UUID,
    p_lease_token UUID,
    p_artifact_type TEXT,
    p_storage_key TEXT,
    p_output_hash TEXT,
    p_metadata JSONB,
    p_scope TEXT,
    p_validator_version TEXT,
    p_summary JSONB,
    p_issues JSONB DEFAULT '[]'::JSONB
)
RETURNS TABLE(output_artifact_id UUID, result_validation_run_id UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_job_id UUID;
    v_job public.processing_jobs%ROWTYPE;
    v_attempt public.processing_job_attempts%ROWTYPE;
    v_artifact public.revision_artifacts%ROWTYPE;
    v_run public.validation_runs%ROWTYPE;
    v_issue JSONB;
BEGIN
    IF p_attempt_id IS NULL OR p_lease_token IS NULL
       OR NULLIF(pg_catalog.btrim(p_artifact_type), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_storage_key), '') IS NULL
       OR p_output_hash IS NULL OR p_output_hash !~ '^[0-9a-fA-F]{64}$'
       OR p_metadata IS NULL
       OR NULLIF(pg_catalog.btrim(p_scope), '') IS NULL
       OR pg_catalog.btrim(p_scope) NOT IN ('Geometry','Scenario','PlaytestPackage','ReleasePackage')
       OR NULLIF(pg_catalog.btrim(p_validator_version), '') IS NULL
       OR p_summary IS NULL OR p_issues IS NULL
       OR pg_catalog.jsonb_typeof(p_issues) <> 'array' THEN
        RAISE EXCEPTION 'processing output identity, validation metadata or issue list is invalid';
    END IF;
    SELECT processing_job_id INTO v_job_id
      FROM public.processing_job_attempts
     WHERE id = p_attempt_id;
    SELECT * INTO v_job FROM public.processing_jobs WHERE id = v_job_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'processing job does not exist'; END IF;
    SELECT * INTO v_attempt
      FROM public.processing_job_attempts
     WHERE id = p_attempt_id AND lease_token = p_lease_token
     FOR UPDATE;
    IF NOT FOUND OR v_job.current_attempt_id IS DISTINCT FROM v_attempt.id
       OR v_job.status <> 'Running' OR v_attempt.status <> 'Running'
       OR v_attempt.lease_until IS NULL
       OR v_attempt.lease_until <= pg_catalog.clock_timestamp()
       OR v_attempt.input_hash <> v_job.input_hash THEN
        RAISE EXCEPTION 'StaleAttempt: processing output cannot be registered';
    END IF;

    SELECT * INTO v_artifact
      FROM public.revision_artifacts
     WHERE attempt_id = v_attempt.id
       AND artifact_type = pg_catalog.btrim(p_artifact_type)
       AND sha256_hash = lower(p_output_hash)
     FOR UPDATE;
    IF FOUND THEN
        IF v_artifact.storage_key <> p_storage_key OR v_artifact.metadata <> p_metadata THEN
            RAISE EXCEPTION 'processing artifact replay conflicts with its stored provenance';
        END IF;
    ELSE
        INSERT INTO public.revision_artifacts(
            revision_id, job_id, attempt_id, artifact_type, storage_key,
            sha256_hash, metadata, is_runtime_ready
        ) VALUES (
            v_job.revision_id, v_job.id, v_attempt.id, pg_catalog.btrim(p_artifact_type),
            p_storage_key, lower(p_output_hash), p_metadata, false
        ) RETURNING * INTO v_artifact;
    END IF;

    SELECT * INTO v_run
      FROM public.validation_runs
     WHERE processing_attempt_id = v_attempt.id
       AND validator_version = pg_catalog.btrim(p_validator_version)
       AND scope = pg_catalog.btrim(p_scope)
     FOR UPDATE;
    IF FOUND THEN
        IF v_run.artifact_id IS DISTINCT FROM v_artifact.id
           OR v_run.summary <> p_summary
           OR v_run.issues_hash IS DISTINCT FROM public.fet3d_jsonb_payload_hash(p_issues) THEN
            RAISE EXCEPTION 'processing validation replay conflicts with its stored provenance';
        END IF;
    ELSE
        INSERT INTO public.validation_runs(
            revision_id, scenario_version_id, processing_job_id,
            processing_attempt_id, artifact_id, scope, validator_version,
            status, summary, issues_hash, started_at, finished_at
        ) VALUES (
            v_job.revision_id, v_job.scenario_version_id, v_job.id,
            v_attempt.id, v_artifact.id, pg_catalog.btrim(p_scope), pg_catalog.btrim(p_validator_version),
            CASE WHEN jsonb_array_length(p_issues) = 0 THEN 'Passed' ELSE 'Failed' END,
            p_summary, public.fet3d_jsonb_payload_hash(p_issues),
            pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
        ) RETURNING * INTO v_run;
        FOR v_issue IN SELECT value FROM pg_catalog.jsonb_array_elements(p_issues) LOOP
            INSERT INTO public.validation_issues(
                validation_run_id, revision_id, scenario_version_id, artifact_id,
                issue_code, severity, status, message, evidence
            ) VALUES (
                v_run.id, v_job.revision_id, v_job.scenario_version_id, v_artifact.id,
                NULLIF(pg_catalog.btrim(v_issue ->> 'issue_code'), ''),
                COALESCE(v_issue ->> 'severity', 'Error'),
                COALESCE(v_issue ->> 'status', 'Open'),
                COALESCE(v_issue ->> 'message', 'processing validation issue'),
                COALESCE(v_issue -> 'evidence', '{}'::JSONB)
            );
        END LOOP;
    END IF;
    RETURN QUERY SELECT v_artifact.id, v_run.id;
END;
$$;

CREATE OR REPLACE FUNCTION accept_processing_attempt(
    p_attempt_id UUID, p_lease_token UUID, p_output_hash TEXT,
    p_output_artifact_id UUID, p_validation_run_id UUID
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_job_id UUID;
    v_job public.processing_jobs%ROWTYPE;
    v_attempt public.processing_job_attempts%ROWTYPE;
BEGIN
    IF p_attempt_id IS NULL OR p_lease_token IS NULL
       OR p_output_hash IS NULL OR p_output_hash !~ '^[0-9a-fA-F]{64}$'
       OR p_output_artifact_id IS NULL OR p_validation_run_id IS NULL THEN
        RAISE EXCEPTION 'processing result identity and hashes are required';
    END IF;
    SELECT processing_job_id INTO v_job_id
      FROM public.processing_job_attempts WHERE id = p_attempt_id;
    SELECT * INTO v_job FROM public.processing_jobs WHERE id = v_job_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'processing job does not exist'; END IF;
    SELECT * INTO v_attempt
      FROM public.processing_job_attempts
     WHERE id = p_attempt_id AND lease_token = p_lease_token
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'processing attempt token is invalid'; END IF;
    IF v_attempt.status = 'Succeeded' THEN
        IF v_attempt.output_hash = p_output_hash
           AND v_attempt.output_artifact_id = p_output_artifact_id
           AND v_attempt.result_validation_run_id = p_validation_run_id THEN
            RETURN true;
        END IF;
        RAISE EXCEPTION 'completed processing result replay conflicts with the stored result';
    END IF;
    IF v_job.current_attempt_id IS DISTINCT FROM v_attempt.id
       OR v_job.status <> 'Running'
       OR v_attempt.status <> 'Running'
       OR v_attempt.lease_until IS NULL
       OR v_attempt.lease_until <= pg_catalog.clock_timestamp() THEN
        RAISE EXCEPTION 'StaleAttempt: processing result cannot be accepted';
    END IF;
    IF v_attempt.input_hash <> v_job.input_hash THEN
        RAISE EXCEPTION 'processing attempt input hash does not match the logical job';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.revision_artifacts AS artifact
         WHERE artifact.id = p_output_artifact_id
           AND artifact.attempt_id = v_attempt.id
           AND artifact.job_id = v_job.id
           AND artifact.revision_id = v_job.revision_id
           AND artifact.sha256_hash = p_output_hash
    ) OR NOT EXISTS (
        SELECT 1 FROM public.validation_runs AS run
         WHERE run.id = p_validation_run_id
           AND run.processing_job_id = v_job.id
           AND run.processing_attempt_id = v_attempt.id
           AND run.revision_id = v_job.revision_id
           AND run.scenario_version_id IS NOT DISTINCT FROM v_job.scenario_version_id
           AND run.artifact_id = p_output_artifact_id
           AND run.status = 'Passed'
           AND NOT EXISTS (
               SELECT 1 FROM public.validation_issues AS issue
                WHERE issue.validation_run_id = run.id
                  AND issue.severity IN ('Error','Critical')
                  AND issue.status NOT IN ('Resolved','Waived')
           )
    ) THEN
        RAISE EXCEPTION 'processing result provenance is invalid';
    END IF;
    UPDATE public.processing_job_attempts
       SET output_hash = p_output_hash,
           output_artifact_id = p_output_artifact_id,
           result_validation_run_id = p_validation_run_id,
           status = 'Succeeded',
           finished_at = pg_catalog.clock_timestamp(),
           lease_until = NULL
     WHERE id = v_attempt.id;
    UPDATE public.processing_jobs SET status = 'Succeeded' WHERE id = v_job.id;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION fail_processing_attempt(
    p_attempt_id UUID, p_lease_token UUID, p_error_message TEXT
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_job_id UUID;
    v_job public.processing_jobs%ROWTYPE;
    v_attempt public.processing_job_attempts%ROWTYPE;
BEGIN
    SELECT processing_job_id INTO v_job_id FROM public.processing_job_attempts WHERE id = p_attempt_id;
    SELECT * INTO v_job FROM public.processing_jobs WHERE id = v_job_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'processing job does not exist'; END IF;
    SELECT * INTO v_attempt FROM public.processing_job_attempts
     WHERE id = p_attempt_id AND lease_token = p_lease_token FOR UPDATE;
    IF NOT FOUND OR v_job.current_attempt_id IS DISTINCT FROM v_attempt.id
       OR v_job.status <> 'Running' OR v_attempt.status <> 'Running'
       OR v_attempt.lease_until IS NULL
       OR v_attempt.lease_until <= pg_catalog.clock_timestamp() THEN
        RAISE EXCEPTION 'StaleAttempt: processing failure cannot be accepted';
    END IF;
    UPDATE public.processing_job_attempts
       SET status = 'Failed', error_message = NULLIF(pg_catalog.btrim(p_error_message), ''),
           finished_at = pg_catalog.clock_timestamp(), lease_until = NULL
     WHERE id = v_attempt.id;
    UPDATE public.processing_jobs SET status = 'Failed' WHERE id = v_job.id;
    RETURN true;
END;
$$;

-- Shared implementation for the two public backend entry points and the
-- requeue gate. It is intentionally not granted to any runtime executor.
-- The event key is serialized with a transaction-scoped advisory lock before
-- the idempotency row is inspected or created.
CREATE OR REPLACE FUNCTION enqueue_integration_outbox_event_internal(
    p_idempotency_key TEXT,
    p_aggregate_type TEXT,
    p_aggregate_id UUID,
    p_event_type TEXT,
    p_schema_version TEXT,
    p_payload JSONB,
    p_allow_system BOOLEAN,
    p_allow_requeue BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_key TEXT := NULLIF(pg_catalog.btrim(p_idempotency_key), '');
    v_aggregate_type TEXT := NULLIF(pg_catalog.btrim(p_aggregate_type), '');
    v_event_type TEXT := NULLIF(pg_catalog.btrim(p_event_type), '');
    v_schema_version TEXT := NULLIF(pg_catalog.btrim(p_schema_version), '');
    v_organization_id UUID;
    v_payload_hash VARCHAR(64);
    v_existing public.integration_outbox_events%ROWTYPE;
    v_inserted BOOLEAN := false;
    v_inserted_key TEXT;
BEGIN
    IF v_key IS NULL OR v_aggregate_type IS NULL OR p_aggregate_id IS NULL
       OR v_event_type IS NULL OR v_schema_version IS NULL OR p_payload IS NULL
       OR p_allow_system IS NULL OR p_allow_requeue IS NULL
       OR p_allow_system AND p_allow_requeue THEN
        RAISE EXCEPTION 'outbox event identity, schema and payload are required';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_key, 0));

    IF p_allow_requeue
       AND v_aggregate_type = 'ProcessingJob'
       AND v_event_type = 'ProcessingJobRequeue'
       AND v_schema_version = '1' THEN
        IF NOT p_payload @> pg_catalog.jsonb_build_object('job_id', p_aggregate_id)
           OR NULLIF(pg_catalog.btrim(p_payload ->> 'reason'), '') IS NULL THEN
            RAISE EXCEPTION 'processing requeue payload does not match aggregate';
        END IF;
        SELECT b.organization_id INTO v_organization_id
          FROM public.processing_jobs AS job
          JOIN public.revisions AS revision ON revision.id = job.revision_id
          JOIN public.buildings AS b ON b.id = revision.building_id
         WHERE job.id = p_aggregate_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'processing job aggregate does not exist';
        END IF;
    ELSIF p_allow_system
       AND v_aggregate_type IN ('System', 'Platform')
       AND v_event_type IN ('SystemNotification', 'PlatformCacheInvalidation')
       AND v_schema_version = '1' THEN
        v_organization_id := NULL;
    ELSIF NOT p_allow_system
       AND NOT p_allow_requeue
       AND v_aggregate_type = 'ProcessingJob'
       AND v_event_type = 'ProcessingJobRequested'
       AND v_schema_version = '1' THEN
        IF NOT p_payload @> pg_catalog.jsonb_build_object('job_id', p_aggregate_id) THEN
            RAISE EXCEPTION 'processing request payload does not match aggregate';
        END IF;
        SELECT b.organization_id INTO v_organization_id
          FROM public.processing_jobs AS job
          JOIN public.revisions AS revision ON revision.id = job.revision_id
          JOIN public.buildings AS b ON b.id = revision.building_id
         WHERE job.id = p_aggregate_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'processing job aggregate does not exist';
        END IF;
    ELSE
        RAISE EXCEPTION 'unsupported outbox event type, schema or enqueue authority';
    END IF;

    v_payload_hash := public.fet3d_jsonb_payload_hash(p_payload);
    INSERT INTO public.integration_outbox_events(
        idempotency_key, aggregate_type, aggregate_id, event_type, schema_version,
        organization_id, payload, payload_hash, status, attempts,
        lease_owner, lease_token, lease_until, published_at, published_lease_token
    ) VALUES (
        v_key, v_aggregate_type, p_aggregate_id, v_event_type, v_schema_version,
        v_organization_id, p_payload, v_payload_hash, 'Pending', 0,
        NULL, NULL, NULL, NULL, NULL
    ) ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING idempotency_key INTO v_inserted_key;
    v_inserted := v_inserted_key IS NOT NULL;

    SELECT * INTO v_existing
      FROM public.integration_outbox_events
     WHERE idempotency_key = v_key
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'outbox enqueue could not resolve idempotency record';
    END IF;
    IF v_existing.aggregate_type IS DISTINCT FROM v_aggregate_type
       OR v_existing.aggregate_id IS DISTINCT FROM p_aggregate_id
       OR v_existing.event_type IS DISTINCT FROM v_event_type
       OR v_existing.schema_version IS DISTINCT FROM v_schema_version
       OR v_existing.organization_id IS DISTINCT FROM v_organization_id
       OR v_existing.payload IS DISTINCT FROM p_payload
       OR lower(v_existing.payload_hash) IS DISTINCT FROM lower(v_payload_hash) THEN
        RAISE EXCEPTION 'outbox idempotency key conflicts with a different envelope';
    END IF;
    RETURN CASE WHEN v_inserted THEN 'Enqueued' ELSE 'AlreadyEnqueued' END;
END;
$$;

-- Tenant-scoped backend entry point. System/platform events and requeue events
-- are deliberately rejected here and must use their dedicated gates.
CREATE OR REPLACE FUNCTION enqueue_integration_outbox_event(
    p_idempotency_key TEXT,
    p_aggregate_type TEXT,
    p_aggregate_id UUID,
    p_event_type TEXT,
    p_schema_version TEXT,
    p_payload JSONB
)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
BEGIN
    RETURN public.enqueue_integration_outbox_event_internal(
        p_idempotency_key, p_aggregate_type, p_aggregate_id,
        p_event_type, p_schema_version, p_payload, false, false
    );
END;
$$;

-- System/platform events have no tenant scope and require a dedicated
-- executor. The function itself still enforces the server-owned allowlist.
CREATE OR REPLACE FUNCTION enqueue_system_outbox_event(
    p_idempotency_key TEXT,
    p_aggregate_type TEXT,
    p_aggregate_id UUID,
    p_event_type TEXT,
    p_schema_version TEXT,
    p_payload JSONB
)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
BEGIN
    RETURN public.enqueue_integration_outbox_event_internal(
        p_idempotency_key, p_aggregate_type, p_aggregate_id,
        p_event_type, p_schema_version, p_payload, true, false
    );
END;
$$;

-- Quotation is the immutable commercial header; BuildingService scope and
-- identity live in quotation_building_items. Issuing a quote requires the
-- line snapshot to be complete and to reconcile to the header totals.
CREATE OR REPLACE FUNCTION validate_quotation_snapshot_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_item_count INT;
    v_subtotal NUMERIC(14,2);
    v_discount NUMERIC(14,2);
    v_total NUMERIC(14,2);
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status <> 'Draft' THEN
        RAISE EXCEPTION 'new quotations must start in Draft';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NOT (
        (OLD.status = 'Draft' AND NEW.status IN ('Issued','Cancelled'))
        OR (OLD.status = 'Issued' AND NEW.status IN ('Accepted','Expired','Cancelled'))
        OR (OLD.status = 'Accepted' AND NEW.status IN ('Expired','Cancelled'))
    ) THEN
        RAISE EXCEPTION 'quotation status transition is not allowed';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.id IS DISTINCT FROM NEW.id THEN
        RAISE EXCEPTION 'quotation identity is immutable';
    END IF;

    -- Acceptance records the transition timestamp exactly once. The backend
    -- may supply it, but the database fills it when the transition omits it.
    IF TG_OP = 'UPDATE' AND OLD.status = 'Issued' AND NEW.status = 'Accepted' THEN
        IF OLD.accepted_at IS NOT NULL THEN
            RAISE EXCEPTION 'quotation has already been accepted';
        END IF;
        NEW.accepted_at := COALESCE(NEW.accepted_at, pg_catalog.clock_timestamp());
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.accepted_at IS NOT NULL
       AND NEW.accepted_at IS DISTINCT FROM OLD.accepted_at THEN
        RAISE EXCEPTION 'accepted_at is immutable after it is first recorded';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.status <> 'Draft' AND (
        OLD.organization_id IS DISTINCT FROM NEW.organization_id
        OR OLD.billing_purpose IS DISTINCT FROM NEW.billing_purpose
        OR OLD.quantity IS DISTINCT FROM NEW.quantity
        OR OLD.unit_price IS DISTINCT FROM NEW.unit_price
        OR OLD.subtotal_amount IS DISTINCT FROM NEW.subtotal_amount
        OR OLD.tax_amount IS DISTINCT FROM NEW.tax_amount
        OR OLD.discount_amount IS DISTINCT FROM NEW.discount_amount
        OR OLD.total_amount IS DISTINCT FROM NEW.total_amount
        OR OLD.currency IS DISTINCT FROM NEW.currency
        OR OLD.price_snapshot IS DISTINCT FROM NEW.price_snapshot
        OR OLD.terms_snapshot IS DISTINCT FROM NEW.terms_snapshot
        OR OLD.discount_rule_id IS DISTINCT FROM NEW.discount_rule_id
        OR OLD.discount_snapshot IS DISTINCT FROM NEW.discount_snapshot
        OR OLD.requested_by IS DISTINCT FROM NEW.requested_by
        OR OLD.quotation_number IS DISTINCT FROM NEW.quotation_number
        OR OLD.valid_until IS DISTINCT FROM NEW.valid_until
        OR OLD.issued_by IS DISTINCT FROM NEW.issued_by
        OR OLD.issued_at IS DISTINCT FROM NEW.issued_at
    ) THEN
        RAISE EXCEPTION 'issued or accepted quotation snapshot is immutable';
    END IF;

    IF NEW.billing_purpose = 'BuildingService' AND NEW.status IN ('Issued','Accepted') THEN
        SELECT count(*), COALESCE(sum(item.subtotal_amount),0),
               COALESCE(sum(item.discount_amount),0), COALESCE(sum(item.total_amount),0)
          INTO v_item_count, v_subtotal, v_discount, v_total
          FROM public.quotation_building_items AS item
         WHERE item.quotation_id = NEW.id;
        IF v_item_count = 0 THEN
            RAISE EXCEPTION 'BuildingService quotation must contain at least one Building line';
        END IF;
        IF EXISTS (
            SELECT 1 FROM public.quotation_building_items AS item
             WHERE item.quotation_id = NEW.id
               AND NULLIF(pg_catalog.btrim(item.line_provisioning_key),'') IS NULL
        ) THEN
            RAISE EXCEPTION 'Issued BuildingService quotation lines require provisioning keys';
        END IF;
        IF NEW.quantity <> v_item_count
           OR NEW.subtotal_amount <> v_subtotal
           OR NEW.discount_amount <> v_discount
           OR NEW.total_amount <> v_total + NEW.tax_amount THEN
            RAISE EXCEPTION 'quotation totals must equal its Building line snapshots';
        END IF;
    ELSIF NEW.billing_purpose = 'AIUsage' AND EXISTS (
        SELECT 1 FROM public.quotation_building_items AS item WHERE item.quotation_id = NEW.id
    ) THEN
        RAISE EXCEPTION 'AIUsage quotation cannot contain Building service lines';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_quotation_building_item_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_quotation public.quotations%ROWTYPE;
    v_building public.buildings%ROWTYPE;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.quotation_id IS DISTINCT FROM NEW.quotation_id THEN
        RAISE EXCEPTION 'quotation line cannot move between quotations';
    END IF;

    SELECT * INTO v_quotation FROM public.quotations
     WHERE id = CASE
                    WHEN TG_OP = 'DELETE' THEN OLD.quotation_id
                    ELSE NEW.quotation_id
                END
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'quotation does not exist'; END IF;
    IF v_quotation.billing_purpose <> 'BuildingService' THEN
        RAISE EXCEPTION 'quotation line requires a BuildingService quotation';
    END IF;
    IF v_quotation.status <> 'Draft' THEN
        RAISE EXCEPTION 'quotation lines can only change while quotation is Draft';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    SELECT * INTO v_building FROM public.buildings WHERE id = NEW.building_id FOR KEY SHARE;
    IF NOT FOUND OR v_building.organization_id <> v_quotation.organization_id
       OR NULLIF(pg_catalog.btrim(v_building.name),'') IS NULL
       OR NULLIF(pg_catalog.btrim(v_building.address),'') IS NULL THEN
        RAISE EXCEPTION 'quotation line requires a named Building with address in the same organization';
    END IF;
    IF TG_OP = 'UPDATE' AND v_quotation.status <> 'Draft' AND (
        OLD.building_id IS DISTINCT FROM NEW.building_id
        OR OLD.service_package_id IS DISTINCT FROM NEW.service_package_id
    ) THEN
        RAISE EXCEPTION 'quotation line identity and commercial provenance are immutable';
    END IF;
    IF NEW.currency <> v_quotation.currency THEN
        RAISE EXCEPTION 'quotation line currency must match quotation currency';
    END IF;
    RETURN NEW;
END;
$$;

-- These triggers are declared after both quotation validator functions so the
-- schema can be applied top-to-bottom without relying on a pre-existing
-- function definition. Line writes lock quotation -> line; issuing a quote
-- validates the complete line snapshot in the same transaction.
CREATE TRIGGER validate_quotation_building_item_before_write
BEFORE INSERT OR UPDATE OR DELETE ON quotation_building_items
FOR EACH ROW EXECUTE FUNCTION validate_quotation_building_item_write();

CREATE TRIGGER validate_quotation_snapshot_before_write
BEFORE INSERT OR UPDATE
ON quotations FOR EACH ROW EXECUTE FUNCTION validate_quotation_snapshot_write();

-- Controlled Learn publication gates. Editorial writes use the lock order
-- post -> version -> links. The database transaction contains the audit row
-- and the cache/index invalidation outbox event; dispatch happens after commit.
-- Learn editorial publish/hide/show/delete/restore are application-service operations.
-- The .NET service performs actor, ETag, idempotency, audit and outbox work in
-- one PostgreSQL transaction. No SQL orchestration function is exposed here.


CREATE OR REPLACE FUNCTION requeue_processing_job(
    p_job_id UUID, p_idempotency_key TEXT, p_reason TEXT
)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    v_job public.processing_jobs%ROWTYPE;
    v_existing public.integration_outbox_events%ROWTYPE;
    v_key TEXT := NULLIF(pg_catalog.btrim(p_idempotency_key), '');
    v_reason TEXT := NULLIF(pg_catalog.btrim(p_reason), '');
    v_payload JSONB;
    v_payload_hash VARCHAR(64);
    v_organization_id UUID;
    v_enqueue_result TEXT;
BEGIN
    IF p_job_id IS NULL OR v_key IS NULL OR v_reason IS NULL THEN
        RAISE EXCEPTION 'requeue job, idempotency key and reason are required';
    END IF;

    v_payload := pg_catalog.jsonb_build_object('job_id', p_job_id, 'reason', v_reason);
    v_payload_hash := public.fet3d_jsonb_payload_hash(v_payload);
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_key, 0));

    SELECT * INTO v_existing
      FROM public.integration_outbox_events
     WHERE idempotency_key = v_key
     FOR UPDATE;
    IF FOUND THEN
        SELECT b.organization_id INTO v_organization_id
          FROM public.processing_jobs AS job
          JOIN public.revisions AS revision ON revision.id = job.revision_id
          JOIN public.buildings AS b ON b.id = revision.building_id
         WHERE job.id = p_job_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'processing job does not exist';
        END IF;
        IF v_existing.aggregate_type IS DISTINCT FROM 'ProcessingJob'
           OR v_existing.aggregate_id IS DISTINCT FROM p_job_id
           OR v_existing.event_type IS DISTINCT FROM 'ProcessingJobRequeue'
           OR v_existing.schema_version IS DISTINCT FROM '1'
           OR v_existing.organization_id IS DISTINCT FROM v_organization_id
           OR v_existing.payload IS DISTINCT FROM v_payload
           OR lower(v_existing.payload_hash) IS DISTINCT FROM lower(v_payload_hash) THEN
            RAISE EXCEPTION 'requeue idempotency key conflicts with a different envelope';
        END IF;
        RETURN 'AlreadyRequeued';
    END IF;

    SELECT * INTO v_job FROM public.processing_jobs WHERE id = p_job_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'processing job does not exist'; END IF;
    IF v_job.status = 'Cancelled' OR v_job.status = 'Succeeded' THEN
        RETURN 'NotClaimable';
    END IF;
    IF v_job.status <> 'Failed' THEN
        RETURN 'Conflict';
    END IF;
    UPDATE public.processing_jobs SET status = 'Queued', current_attempt_id = NULL WHERE id = p_job_id;
    v_enqueue_result := public.enqueue_integration_outbox_event_internal(
        v_key, 'ProcessingJob', p_job_id, 'ProcessingJobRequeue', '1', v_payload, false, true
    );
    IF v_enqueue_result <> 'Enqueued' THEN
        RAISE EXCEPTION 'requeue event was not created for a new idempotency key';
    END IF;
    RETURN 'Requeued';
END;
$$;

-- Dedicated non-login owners and narrow executors. PUBLIC never receives the
-- ability to call the privileged gates or write their protected tables.
DO $final_roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_session_owner') THEN
        CREATE ROLE fet3d_session_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_ai_accounting_owner') THEN
        CREATE ROLE fet3d_ai_accounting_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_processing_owner') THEN
        CREATE ROLE fet3d_processing_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_ai_request_owner') THEN
        CREATE ROLE fet3d_ai_request_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_requeue_owner') THEN
        CREATE ROLE fet3d_requeue_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_accounting_executor') THEN
        CREATE ROLE fet3d_accounting_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
END;
$final_roles$;

ALTER FUNCTION start_training_session(UUID, UUID, TEXT, TEXT) OWNER TO fet3d_session_owner;
ALTER FUNCTION start_playtest_session(UUID, UUID, TEXT, TEXT) OWNER TO fet3d_session_owner;
ALTER FUNCTION record_session_heartbeat(UUID, UUID, BIGINT, TIMESTAMPTZ) OWNER TO fet3d_session_owner;
ALTER FUNCTION record_session_event(UUID, UUID, UUID, BIGINT, TEXT, TEXT, JSONB, TIMESTAMPTZ) OWNER TO fet3d_session_owner;
ALTER FUNCTION complete_training_session(UUID, UUID, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ) OWNER TO fet3d_session_owner;
ALTER FUNCTION complete_playtest_session(UUID, UUID, TEXT, TEXT) OWNER TO fet3d_session_owner;
ALTER FUNCTION close_ai_billing_period(UUID) OWNER TO fet3d_ai_accounting_owner;
ALTER FUNCTION invoice_ai_billing_period(UUID, UUID) OWNER TO fet3d_ai_accounting_owner;
ALTER FUNCTION pay_ai_billing_period(UUID, UUID) OWNER TO fet3d_ai_accounting_owner;
ALTER FUNCTION reserve_ai_usage(UUID, TEXT, UUID, TEXT, UUID, UUID, TEXT, INT, BOOLEAN, UUID, UUID, JSONB, JSONB) OWNER TO fet3d_ai_accounting_owner;
ALTER FUNCTION settle_ai_usage(UUID, TEXT) OWNER TO fet3d_ai_accounting_owner;
ALTER FUNCTION validate_ai_billing_adjustment_write() OWNER TO fet3d_ai_accounting_owner;
ALTER FUNCTION record_ai_billing_adjustment(UUID, UUID, UUID, UUID, TEXT, INT, NUMERIC, TEXT, TEXT, UUID) OWNER TO fet3d_ai_accounting_owner;
ALTER FUNCTION claim_processing_attempt(UUID, TEXT, TEXT, TEXT, INT) OWNER TO fet3d_processing_owner;
ALTER FUNCTION renew_processing_attempt(UUID, UUID, INT) OWNER TO fet3d_processing_owner;
ALTER FUNCTION register_processing_output(UUID, UUID, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, JSONB, JSONB) OWNER TO fet3d_processing_owner;
ALTER FUNCTION accept_processing_attempt(UUID, UUID, TEXT, UUID, UUID) OWNER TO fet3d_processing_owner;
ALTER FUNCTION fail_processing_attempt(UUID, UUID, TEXT) OWNER TO fet3d_processing_owner;
ALTER FUNCTION requeue_processing_job(UUID, TEXT, TEXT) OWNER TO fet3d_requeue_owner;

REVOKE ALL ON FUNCTION record_session_heartbeat(UUID, UUID, BIGINT, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION record_session_event(UUID, UUID, UUID, BIGINT, TEXT, TEXT, JSONB, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION complete_training_session(UUID, UUID, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION complete_playtest_session(UUID, UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION close_ai_billing_period(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION invoice_ai_billing_period(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION pay_ai_billing_period(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION validate_ai_billing_adjustment_write() FROM PUBLIC;
REVOKE ALL ON FUNCTION record_ai_billing_adjustment(UUID, UUID, UUID, UUID, TEXT, INT, NUMERIC, TEXT, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION reserve_ai_usage(UUID, TEXT, UUID, TEXT, UUID, UUID, TEXT, INT, BOOLEAN, UUID, UUID, JSONB, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION settle_ai_usage(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION claim_processing_attempt(UUID, TEXT, TEXT, TEXT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION renew_processing_attempt(UUID, UUID, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION register_processing_output(UUID, UUID, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, JSONB, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION accept_processing_attempt(UUID, UUID, TEXT, UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION fail_processing_attempt(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION requeue_processing_job(UUID, TEXT, TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION record_session_heartbeat(UUID, UUID, BIGINT, TIMESTAMPTZ) TO fet3d_session_sync_executor;
GRANT EXECUTE ON FUNCTION record_session_event(UUID, UUID, UUID, BIGINT, TEXT, TEXT, JSONB, TIMESTAMPTZ),
    complete_training_session(UUID, UUID, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ),
    complete_playtest_session(UUID, UUID, TEXT, TEXT)
    TO fet3d_session_sync_executor;
GRANT EXECUTE ON FUNCTION close_ai_billing_period(UUID),
    invoice_ai_billing_period(UUID, UUID),
    pay_ai_billing_period(UUID, UUID),
    reserve_ai_usage(UUID, TEXT, UUID, TEXT, UUID, UUID, TEXT, INT, BOOLEAN, UUID, UUID, JSONB, JSONB),
    settle_ai_usage(UUID, TEXT),
    record_ai_billing_adjustment(UUID, UUID, UUID, UUID, TEXT, INT, NUMERIC, TEXT, TEXT, UUID)
    TO fet3d_accounting_executor;
REVOKE ALL PRIVILEGES ON FUNCTION close_ai_billing_period(UUID),
    reserve_ai_usage(UUID, TEXT, UUID, TEXT, UUID, UUID, TEXT, INT, BOOLEAN, UUID, UUID, JSONB, JSONB),
    settle_ai_usage(UUID, TEXT),
    record_ai_billing_adjustment(UUID, UUID, UUID, UUID, TEXT, INT, NUMERIC, TEXT, TEXT, UUID)
    FROM fet3d_ai_service_executor;
GRANT EXECUTE ON FUNCTION claim_processing_attempt(UUID, TEXT, TEXT, TEXT, INT),
    renew_processing_attempt(UUID, UUID, INT),
    register_processing_output(UUID, UUID, TEXT, TEXT, TEXT, JSONB, TEXT, TEXT, JSONB, JSONB),
    accept_processing_attempt(UUID, UUID, TEXT, UUID, UUID),
    fail_processing_attempt(UUID, UUID, TEXT) TO fet3d_processing_worker_executor;
GRANT EXECUTE ON FUNCTION requeue_processing_job(UUID, TEXT, TEXT) TO fet3d_backend_executor;
REVOKE ALL ON FUNCTION validate_learn_editorial_write() FROM PUBLIC;

REVOKE ALL ON TABLE processing_jobs, processing_job_attempts, revision_artifacts,
    validation_runs, validation_issues FROM fet3d_processing_worker_executor;
REVOKE ALL ON TABLE ai_billing_periods, ai_billing_period_items, ai_billing_adjustments,
    ai_usage_ledger, ai_usage_reservations, ai_usage_reservation_allocations,
    ai_quota_grants FROM fet3d_ai_service_executor;

GRANT USAGE ON SCHEMA public TO fet3d_session_prepare_executor, fet3d_session_sync_executor,
    fet3d_session_owner, fet3d_ai_accounting_owner,
    fet3d_processing_owner, fet3d_ai_request_owner;
GRANT SELECT ON TABLE users, user_devices, buildings, trainings, releases,
    scenario_versions, scenario_drafts, release_packages, release_qr_codes,
    service_entitlements, validation_runs, revision_artifacts, validation_issues
    TO fet3d_session_prepare_executor;
GRANT SELECT ON TABLE users, sessions, playtest_sessions, releases, trainings,
    scenario_versions, release_packages, runtime_compatibility_catalog,
    release_qr_codes, service_entitlements, revisions, scenario_drafts, user_devices, validation_runs,
    revision_artifacts, validation_issues, ai_quota_grants
    TO fet3d_session_owner;
GRANT INSERT, UPDATE ON TABLE sessions, playtest_sessions, service_entitlements
    TO fet3d_session_owner;
GRANT SELECT, INSERT, UPDATE ON TABLE session_results, session_events, session_checkpoints
    TO fet3d_session_owner;
GRANT SELECT ON TABLE ai_requests, ai_policy_versions, ai_overage_consents,
    ai_billing_periods, ai_usage_ledger, ai_usage_reservations,
    ai_usage_reservation_allocations, ai_quota_grants, ai_billing_adjustments,
    ai_billing_period_items, buildings, users, quotations,
    quotation_building_items, payos_payment_requests, payment_transactions
    TO fet3d_ai_accounting_owner;
GRANT INSERT, UPDATE ON TABLE ai_requests, ai_usage_ledger, ai_usage_reservations,
    ai_usage_reservation_allocations, ai_quota_grants, ai_billing_periods,
    ai_billing_period_items, ai_billing_adjustments
    TO fet3d_ai_accounting_owner;
GRANT SELECT, UPDATE ON TABLE processing_jobs TO fet3d_processing_owner;
GRANT SELECT, INSERT, UPDATE ON TABLE processing_job_attempts
    TO fet3d_processing_owner;
GRANT SELECT, INSERT, UPDATE ON TABLE revision_artifacts, validation_runs, validation_issues
    TO fet3d_processing_owner;

GRANT SELECT ON TABLE users, buildings, ai_policy_versions TO fet3d_ai_request_owner;
GRANT INSERT ON TABLE ai_requests TO fet3d_ai_request_owner;
GRANT SELECT, UPDATE ON TABLE processing_jobs TO fet3d_requeue_owner;
GRANT SELECT, UPDATE ON TABLE integration_outbox_events TO fet3d_requeue_owner;
GRANT SELECT ON TABLE revisions, buildings TO fet3d_requeue_owner;

-- Controlled AI request input boundary. The backend supplies the verified
-- actor/scope and only this contract can create an Accepted request.
CREATE OR REPLACE FUNCTION create_ai_request(
    p_idempotency_key TEXT,
    p_organization_id UUID,
    p_building_id UUID,
    p_user_id UUID,
    p_audience TEXT,
    p_request_type TEXT,
    p_source_scope JSONB,
    p_policy_version_id UUID,
    p_input_hash TEXT,
    p_input_reference TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_id UUID;
    v_existing public.ai_requests%ROWTYPE;
    v_scope JSONB := COALESCE(p_source_scope, '{}'::JSONB);
BEGIN
    IF NULLIF(pg_catalog.btrim(p_idempotency_key), '') IS NULL
       OR p_user_id IS NULL
       OR NULLIF(pg_catalog.btrim(p_audience), '') IS NULL
       OR NULLIF(pg_catalog.btrim(p_request_type), '') IS NULL
       OR p_policy_version_id IS NULL
       OR p_input_hash IS NULL
       OR p_input_hash !~ '^[0-9a-fA-F]{64}$' THEN
        RAISE EXCEPTION 'AI request identity, policy and canonical input hash are required';
    END IF;
    IF p_audience NOT IN ('organization','trainee') THEN
        RAISE EXCEPTION 'AI request audience is invalid';
    END IF;
    IF p_audience = 'organization' AND p_organization_id IS NULL THEN
        RAISE EXCEPTION 'organization AI request requires an organization';
    END IF;
    IF p_audience = 'trainee' AND (p_organization_id IS NOT NULL OR p_building_id IS NOT NULL) THEN
        RAISE EXCEPTION 'trainee AI request cannot carry organization or Building scope';
    END IF;

    INSERT INTO public.ai_requests(
        idempotency_key, organization_id, building_id, user_id, audience,
        request_type, source_scope, policy_version_id, input_hash, input_reference
    ) VALUES (
        pg_catalog.btrim(p_idempotency_key), p_organization_id, p_building_id,
        p_user_id, pg_catalog.btrim(p_audience), pg_catalog.btrim(p_request_type),
        v_scope, p_policy_version_id, lower(pg_catalog.btrim(p_input_hash)), p_input_reference
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NOT NULL THEN
        RETURN v_id;
    END IF;

    SELECT * INTO v_existing
      FROM public.ai_requests
     WHERE idempotency_key = pg_catalog.btrim(p_idempotency_key);
    IF NOT FOUND THEN
        RAISE EXCEPTION 'AI request idempotency result is unavailable';
    END IF;
    IF v_existing.organization_id IS DISTINCT FROM p_organization_id
       OR v_existing.building_id IS DISTINCT FROM p_building_id
       OR v_existing.user_id IS DISTINCT FROM p_user_id
       OR v_existing.audience IS DISTINCT FROM pg_catalog.btrim(p_audience)
       OR v_existing.request_type IS DISTINCT FROM pg_catalog.btrim(p_request_type)
       OR v_existing.source_scope IS DISTINCT FROM v_scope
       OR v_existing.policy_version_id IS DISTINCT FROM p_policy_version_id
       OR lower(v_existing.input_hash) IS DISTINCT FROM lower(pg_catalog.btrim(p_input_hash))
       OR v_existing.input_reference IS DISTINCT FROM p_input_reference THEN
        RAISE EXCEPTION 'AI request idempotency key conflicts with another payload';
    END IF;
    RETURN v_existing.id;
END;
$$;

ALTER FUNCTION create_ai_request(TEXT, UUID, UUID, UUID, TEXT, TEXT, JSONB, UUID, TEXT, TEXT)
    OWNER TO fet3d_ai_request_owner;
REVOKE ALL ON FUNCTION create_ai_request(TEXT, UUID, UUID, UUID, TEXT, TEXT, JSONB, UUID, TEXT, TEXT)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_ai_request(TEXT, UUID, UUID, UUID, TEXT, TEXT, JSONB, UUID, TEXT, TEXT)
    TO fet3d_backend_executor;

-- Controlled AI result/reconcile boundary. The service returns technical
-- evidence; the backend records it here and then settles accounting separately.
CREATE OR REPLACE FUNCTION record_ai_request_result(
    p_request_id UUID,
    p_status TEXT,
    p_result_type TEXT,
    p_result_reference TEXT,
    p_response_snapshot JSONB,
    p_result_hash TEXT,
    p_citations JSONB,
    p_model_provider TEXT,
    p_model_version TEXT,
    p_technical_usage JSONB,
    p_failure_code TEXT
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_request public.ai_requests%ROWTYPE;
    v_citations JSONB := COALESCE(p_citations, '[]'::JSONB);
    v_usage JSONB := COALESCE(p_technical_usage, '{}'::JSONB);
BEGIN
    IF p_request_id IS NULL OR p_status NOT IN ('Succeeded','Failed','NeedsReconcile') THEN
        RAISE EXCEPTION 'AI result request and terminal/reconcile status are required';
    END IF;
    SELECT * INTO v_request
      FROM public.ai_requests
     WHERE id = p_request_id
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'AI request does not exist'; END IF;

    IF v_request.status IN ('Succeeded','Failed','Rejected') THEN
        IF v_request.status = p_status
           AND v_request.result_type IS NOT DISTINCT FROM p_result_type
           AND v_request.response_snapshot IS NOT DISTINCT FROM p_response_snapshot
           AND v_request.result_hash IS NOT DISTINCT FROM NULLIF(pg_catalog.btrim(p_result_hash), '')
           AND v_request.citations IS NOT DISTINCT FROM v_citations
           AND v_request.model_provider IS NOT DISTINCT FROM NULLIF(pg_catalog.btrim(p_model_provider), '')
           AND v_request.model_version IS NOT DISTINCT FROM NULLIF(pg_catalog.btrim(p_model_version), '')
           AND v_request.technical_usage IS NOT DISTINCT FROM v_usage
           AND v_request.failure_code IS NOT DISTINCT FROM NULLIF(pg_catalog.btrim(p_failure_code), '') THEN
            RETURN p_request_id;
        END IF;
        RAISE EXCEPTION 'AI result replay conflicts with the stored terminal result';
    END IF;

    IF p_status = 'Succeeded' THEN
        IF p_result_type IS NULL
           OR p_result_type NOT IN ('KnowledgeAnswer','ScenarioDraft','InsufficientEvidence','RejectedBySafetyGate')
           OR p_response_snapshot IS NULL
           OR NULLIF(pg_catalog.btrim(p_result_hash), '') IS NULL
           OR p_result_hash !~ '^[0-9a-fA-F]{64}$'
           OR pg_catalog.jsonb_typeof(v_citations) <> 'array'
           OR pg_catalog.jsonb_typeof(v_usage) <> 'object'
           OR NULLIF(pg_catalog.btrim(p_model_provider), '') IS NULL
           OR NULLIF(pg_catalog.btrim(p_model_version), '') IS NULL
           OR (p_result_type = 'ScenarioDraft' AND v_request.audience <> 'organization') THEN
            RAISE EXCEPTION 'successful AI result lacks valid evidence or audience';
        END IF;
    ELSIF p_status = 'Failed' AND NULLIF(pg_catalog.btrim(p_failure_code), '') IS NULL THEN
        RAISE EXCEPTION 'failed AI result requires a failure code';
    END IF;

    UPDATE public.ai_requests
       SET status = p_status,
           result_type = CASE WHEN p_status = 'Succeeded' THEN p_result_type ELSE NULL END,
           result_reference = CASE WHEN p_status = 'Succeeded' THEN p_result_reference ELSE NULL END,
           response_snapshot = CASE WHEN p_status = 'Succeeded' THEN p_response_snapshot ELSE NULL END,
           result_hash = CASE WHEN p_status = 'Succeeded' THEN lower(pg_catalog.btrim(p_result_hash)) ELSE NULL END,
           citations = CASE WHEN p_status = 'Succeeded' THEN v_citations ELSE '[]'::JSONB END,
           model_provider = CASE WHEN p_status = 'Succeeded' THEN pg_catalog.btrim(p_model_provider) ELSE NULL END,
           model_version = CASE WHEN p_status = 'Succeeded' THEN pg_catalog.btrim(p_model_version) ELSE NULL END,
           technical_usage = CASE WHEN p_status = 'Succeeded' THEN v_usage ELSE '{}'::JSONB END,
           failure_code = CASE WHEN p_status = 'Failed' THEN pg_catalog.btrim(p_failure_code) ELSE NULL END,
           completed_at = CASE WHEN p_status IN ('Succeeded','Failed') THEN pg_catalog.clock_timestamp() ELSE NULL END,
           last_reconciled_at = pg_catalog.clock_timestamp()
     WHERE id = p_request_id
       AND status IN ('Accepted','Processing','NeedsReconcile');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'AI request is not in an accepted processing state';
    END IF;
    RETURN p_request_id;
END;
$$;

ALTER FUNCTION record_ai_request_result(
    UUID, TEXT, TEXT, TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, JSONB, TEXT
) OWNER TO fet3d_ai_request_owner;
REVOKE ALL ON FUNCTION record_ai_request_result(
    UUID, TEXT, TEXT, TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, JSONB, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION record_ai_request_result(
    UUID, TEXT, TEXT, TEXT, JSONB, TEXT, JSONB, TEXT, TEXT, JSONB, TEXT
) TO fet3d_backend_executor;
GRANT SELECT, UPDATE ON TABLE ai_requests TO fet3d_ai_request_owner;
GRANT SELECT ON TABLE users, buildings, ai_policy_versions TO fet3d_ai_request_owner;

-- Redis Streams transport gates. PostgreSQL remains authoritative for the
-- envelope, lease fencing and durable consumer deduplication.
DO $integration_roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_integration_owner') THEN
        CREATE ROLE fet3d_integration_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_dispatcher_executor') THEN
        CREATE ROLE fet3d_dispatcher_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'fet3d_system_event_executor') THEN
        CREATE ROLE fet3d_system_event_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT NOREPLICATION NOBYPASSRLS;
    END IF;
END;
$integration_roles$;

ALTER FUNCTION fet3d_jsonb_payload_hash(JSONB) OWNER TO fet3d_integration_owner;
ALTER FUNCTION validate_integration_outbox_event_mutation() OWNER TO fet3d_integration_owner;
ALTER FUNCTION enqueue_integration_outbox_event_internal(TEXT, TEXT, UUID, TEXT, TEXT, JSONB, BOOLEAN, BOOLEAN) OWNER TO fet3d_integration_owner;
ALTER FUNCTION enqueue_integration_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB) OWNER TO fet3d_integration_owner;
ALTER FUNCTION enqueue_system_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB) OWNER TO fet3d_integration_owner;
REVOKE ALL ON FUNCTION validate_integration_outbox_event_mutation() FROM PUBLIC;

CREATE OR REPLACE FUNCTION claim_integration_outbox_event(
    p_dispatcher_id TEXT, p_lease_seconds INT DEFAULT 60
)
RETURNS TABLE(
    result_code TEXT,
    event_key VARCHAR,
    schema_version VARCHAR,
    organization_id UUID,
    aggregate_type VARCHAR,
    aggregate_id UUID,
    event_type VARCHAR,
    payload JSONB,
    payload_hash VARCHAR,
    lease_token UUID,
    lease_until TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_event public.integration_outbox_events%ROWTYPE;
    v_now TIMESTAMPTZ;
    v_locked_now TIMESTAMPTZ;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_dispatcher_id), '') IS NULL OR p_lease_seconds IS NULL OR p_lease_seconds <= 0 THEN
        RAISE EXCEPTION 'dispatcher and positive lease duration are required';
    END IF;

    v_now := pg_catalog.clock_timestamp();
    SELECT * INTO v_event
      FROM public.integration_outbox_events AS outbox
     WHERE (
            outbox.status IN ('Pending','Failed')
            AND outbox.available_at <= v_now
           )
        OR (
            outbox.status = 'Leased'
            AND outbox.lease_until IS NOT NULL
            AND outbox.lease_until <= v_now
           )
     ORDER BY outbox.available_at, outbox.created_at, outbox.idempotency_key
     LIMIT 1
     FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'NoWork'::TEXT, NULL::VARCHAR, NULL::VARCHAR, NULL::UUID,
            NULL::VARCHAR, NULL::UUID, NULL::VARCHAR, NULL::JSONB, NULL::VARCHAR,
            NULL::UUID, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    v_locked_now := pg_catalog.clock_timestamp();
    IF (v_event.status IN ('Pending','Failed') AND v_event.available_at > v_locked_now)
       OR (v_event.status = 'Leased'
           AND (v_event.lease_until IS NULL OR v_event.lease_until > v_locked_now)) THEN
        RETURN QUERY SELECT 'NoWork'::TEXT, NULL::VARCHAR, NULL::VARCHAR, NULL::UUID,
            NULL::VARCHAR, NULL::UUID, NULL::VARCHAR, NULL::JSONB, NULL::VARCHAR,
            NULL::UUID, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;

    UPDATE public.integration_outbox_events AS outbox
       SET status = 'Leased',
           attempts = outbox.attempts + 1,
           lease_owner = pg_catalog.btrim(p_dispatcher_id),
           lease_token = pg_catalog.gen_random_uuid(),
           lease_until = v_locked_now + pg_catalog.make_interval(secs => p_lease_seconds),
           last_error = NULL
     WHERE outbox.idempotency_key = v_event.idempotency_key
    RETURNING outbox.* INTO v_event;

    RETURN QUERY SELECT 'Claimed'::TEXT, v_event.idempotency_key, v_event.schema_version,
        v_event.organization_id, v_event.aggregate_type, v_event.aggregate_id,
        v_event.event_type, v_event.payload, v_event.payload_hash,
        v_event.lease_token, v_event.lease_until;
END;
$$;

CREATE OR REPLACE FUNCTION renew_integration_outbox_event(
    p_event_key VARCHAR, p_lease_token UUID, p_lease_seconds INT DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_event public.integration_outbox_events%ROWTYPE;
    v_now TIMESTAMPTZ;
    v_new_until TIMESTAMPTZ;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_event_key), '') IS NULL
       OR p_lease_token IS NULL OR p_lease_seconds IS NULL OR p_lease_seconds <= 0 THEN
        RAISE EXCEPTION 'event key, lease token and positive duration are required';
    END IF;
    SELECT * INTO v_event FROM public.integration_outbox_events
     WHERE idempotency_key = p_event_key FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'outbox event does not exist'; END IF;
    v_now := pg_catalog.clock_timestamp();
    IF v_event.status <> 'Leased' OR v_event.lease_token IS DISTINCT FROM p_lease_token
       OR v_event.lease_until IS NULL OR v_event.lease_until <= v_now THEN
        RAISE EXCEPTION 'outbox lease is stale';
    END IF;
    v_new_until := v_now + pg_catalog.make_interval(secs => p_lease_seconds);
    IF v_new_until < v_event.lease_until THEN
        v_new_until := v_event.lease_until;
    END IF;
    UPDATE public.integration_outbox_events
       SET lease_until = v_new_until
     WHERE idempotency_key = p_event_key
       AND lease_token = p_lease_token;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION mark_integration_outbox_published(
    p_event_key VARCHAR, p_lease_token UUID
)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_event public.integration_outbox_events%ROWTYPE;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_event_key), '') IS NULL OR p_lease_token IS NULL THEN
        RAISE EXCEPTION 'event key and lease token are required';
    END IF;
    SELECT * INTO v_event FROM public.integration_outbox_events
     WHERE idempotency_key = p_event_key FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'outbox event does not exist'; END IF;
    IF v_event.status = 'Published' THEN
        IF v_event.published_lease_token IS DISTINCT FROM p_lease_token THEN
            RAISE EXCEPTION 'published event token conflicts with completed delivery';
        END IF;
        RETURN 'AlreadyPublished';
    END IF;
    IF v_event.status <> 'Leased' OR v_event.lease_token IS DISTINCT FROM p_lease_token
       OR v_event.lease_until IS NULL OR v_event.lease_until <= pg_catalog.clock_timestamp() THEN
        RAISE EXCEPTION 'outbox lease is stale';
    END IF;
    UPDATE public.integration_outbox_events
       SET status = 'Published', lease_owner = NULL, lease_token = NULL,
           lease_until = NULL, published_at = pg_catalog.clock_timestamp(),
           published_lease_token = p_lease_token, last_error = NULL
     WHERE idempotency_key = p_event_key AND lease_token = p_lease_token;
    RETURN 'Published';
END;
$$;

CREATE OR REPLACE FUNCTION fail_integration_outbox_event(
    p_event_key VARCHAR, p_lease_token UUID, p_error TEXT, p_retry_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_event public.integration_outbox_events%ROWTYPE;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_event_key), '') IS NULL OR p_lease_token IS NULL
       OR NULLIF(pg_catalog.btrim(p_error), '') IS NULL THEN
        RAISE EXCEPTION 'event key, lease token and error are required';
    END IF;
    SELECT * INTO v_event FROM public.integration_outbox_events
     WHERE idempotency_key = p_event_key FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'outbox event does not exist'; END IF;
    IF v_event.status <> 'Leased' OR v_event.lease_token IS DISTINCT FROM p_lease_token
       OR v_event.lease_until IS NULL OR v_event.lease_until <= pg_catalog.clock_timestamp() THEN
        RAISE EXCEPTION 'outbox lease is stale';
    END IF;
    UPDATE public.integration_outbox_events
       SET status = 'Failed', lease_owner = NULL, lease_token = NULL, lease_until = NULL,
           last_error = pg_catalog.btrim(p_error),
           available_at = COALESCE(p_retry_at, pg_catalog.clock_timestamp())
     WHERE idempotency_key = p_event_key AND lease_token = p_lease_token;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION replay_integration_outbox_event(p_event_key VARCHAR)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_event public.integration_outbox_events%ROWTYPE;
BEGIN
    IF NULLIF(pg_catalog.btrim(p_event_key), '') IS NULL THEN
        RAISE EXCEPTION 'event key is required';
    END IF;
    SELECT * INTO v_event FROM public.integration_outbox_events
     WHERE idempotency_key = p_event_key FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'outbox event does not exist'; END IF;
    IF v_event.status = 'Leased' THEN RAISE EXCEPTION 'leased event cannot be replayed'; END IF;
    IF v_event.status = 'Pending' THEN RETURN 'AlreadyPending'; END IF;
    UPDATE public.integration_outbox_events
       SET status = 'Pending', available_at = pg_catalog.clock_timestamp(),
           lease_owner = NULL, lease_token = NULL, lease_until = NULL,
           last_error = NULL, published_at = NULL
     WHERE idempotency_key = p_event_key;
    RETURN 'Replayed';
END;
$$;

CREATE OR REPLACE FUNCTION check_integration_event_consumption(
    p_consumer_name VARCHAR,
    p_event_key VARCHAR,
    p_schema_version VARCHAR,
    p_organization_id UUID,
    p_aggregate_type VARCHAR,
    p_aggregate_id UUID,
    p_event_type VARCHAR,
    p_payload JSONB,
    p_payload_hash VARCHAR
)
RETURNS TABLE(result_code TEXT, result_reference TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_event public.integration_outbox_events%ROWTYPE;
    v_existing public.integration_event_consumptions%ROWTYPE;
    v_consumer VARCHAR := NULLIF(pg_catalog.btrim(p_consumer_name), '');
    v_key VARCHAR := NULLIF(pg_catalog.btrim(p_event_key), '');
    v_schema VARCHAR := NULLIF(pg_catalog.btrim(p_schema_version), '');
    v_hash VARCHAR := pg_catalog.lower(NULLIF(pg_catalog.btrim(p_payload_hash), ''));
BEGIN
    IF v_consumer IS NULL OR v_key IS NULL OR v_schema IS NULL OR p_aggregate_id IS NULL
       OR p_payload IS NULL OR v_hash IS NULL OR v_hash !~ '^[0-9a-fA-F]{64}$'
       OR v_hash <> public.fet3d_jsonb_payload_hash(p_payload) THEN
        RAISE EXCEPTION 'consumer envelope and valid canonical payload hash are required';
    END IF;
    SELECT * INTO v_event FROM public.integration_outbox_events
     WHERE idempotency_key = v_key FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'outbox event does not exist'; END IF;
    IF v_event.schema_version IS DISTINCT FROM v_schema
       OR v_event.organization_id IS DISTINCT FROM p_organization_id
       OR v_event.aggregate_type IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_aggregate_type), '')
       OR v_event.aggregate_id IS DISTINCT FROM p_aggregate_id
       OR v_event.event_type IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_event_type), '')
       OR v_event.payload IS DISTINCT FROM p_payload
       OR lower(v_event.payload_hash) <> v_hash THEN
        RAISE EXCEPTION 'consumer envelope does not match the outbox record';
    END IF;
    SELECT * INTO v_existing FROM public.integration_event_consumptions
     WHERE consumer_name = v_consumer AND event_key = v_key FOR UPDATE;
    IF FOUND THEN
        IF lower(v_existing.payload_hash) = v_hash THEN
            RETURN QUERY SELECT 'AlreadyProcessed'::TEXT, v_existing.result_reference;
            RETURN;
        END IF;
        RAISE EXCEPTION 'consumer event key conflicts with another payload';
    END IF;
    RETURN QUERY SELECT 'NotProcessed'::TEXT, NULL::TEXT;
END;
$$;

-- The handler calls check_* before its business effect and this function after
-- that effect, in the same transaction, before acknowledging Redis.
CREATE OR REPLACE FUNCTION record_integration_event_consumption(
    p_consumer_name VARCHAR,
    p_event_key VARCHAR,
    p_schema_version VARCHAR,
    p_organization_id UUID,
    p_aggregate_type VARCHAR,
    p_aggregate_id UUID,
    p_event_type VARCHAR,
    p_payload JSONB,
    p_payload_hash VARCHAR,
    p_result_reference TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
DECLARE
    v_check RECORD;
    v_consumer VARCHAR := NULLIF(pg_catalog.btrim(p_consumer_name), '');
    v_key VARCHAR := NULLIF(pg_catalog.btrim(p_event_key), '');
    v_hash VARCHAR := pg_catalog.lower(NULLIF(pg_catalog.btrim(p_payload_hash), ''));
BEGIN
    SELECT * INTO v_check FROM public.check_integration_event_consumption(
        v_consumer, v_key, p_schema_version, p_organization_id, p_aggregate_type,
        p_aggregate_id, p_event_type, p_payload, v_hash
    );
    IF v_check.result_code = 'AlreadyProcessed' THEN
        RETURN 'AlreadyProcessed';
    END IF;
    INSERT INTO public.integration_event_consumptions(
        consumer_name, event_key, payload_hash, result_reference
    ) VALUES (v_consumer, v_key, v_hash, p_result_reference);
    RETURN 'Recorded';
END;
$$;

ALTER FUNCTION claim_integration_outbox_event(TEXT, INT) OWNER TO fet3d_integration_owner;
ALTER FUNCTION renew_integration_outbox_event(VARCHAR, UUID, INT) OWNER TO fet3d_integration_owner;
ALTER FUNCTION mark_integration_outbox_published(VARCHAR, UUID) OWNER TO fet3d_integration_owner;
ALTER FUNCTION fail_integration_outbox_event(VARCHAR, UUID, TEXT, TIMESTAMPTZ) OWNER TO fet3d_integration_owner;
ALTER FUNCTION replay_integration_outbox_event(VARCHAR) OWNER TO fet3d_integration_owner;
ALTER FUNCTION check_integration_event_consumption(VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, UUID, VARCHAR, JSONB, VARCHAR) OWNER TO fet3d_integration_owner;
ALTER FUNCTION record_integration_event_consumption(VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, UUID, VARCHAR, JSONB, VARCHAR, TEXT) OWNER TO fet3d_integration_owner;

REVOKE ALL ON FUNCTION claim_integration_outbox_event(TEXT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION renew_integration_outbox_event(VARCHAR, UUID, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION mark_integration_outbox_published(VARCHAR, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION fail_integration_outbox_event(VARCHAR, UUID, TEXT, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION replay_integration_outbox_event(VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION check_integration_event_consumption(VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, UUID, VARCHAR, JSONB, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION record_integration_event_consumption(VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, UUID, VARCHAR, JSONB, VARCHAR, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION enqueue_integration_outbox_event_internal(TEXT, TEXT, UUID, TEXT, TEXT, JSONB, BOOLEAN, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION enqueue_integration_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION enqueue_system_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION claim_integration_outbox_event(TEXT, INT),
    renew_integration_outbox_event(VARCHAR, UUID, INT),
    mark_integration_outbox_published(VARCHAR, UUID),
    fail_integration_outbox_event(VARCHAR, UUID, TEXT, TIMESTAMPTZ)
    TO fet3d_dispatcher_executor;
GRANT EXECUTE ON FUNCTION enqueue_integration_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB),
    replay_integration_outbox_event(VARCHAR),
    check_integration_event_consumption(VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, UUID, VARCHAR, JSONB, VARCHAR),
    record_integration_event_consumption(VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, UUID, VARCHAR, JSONB, VARCHAR, TEXT)
    TO fet3d_backend_executor;
GRANT EXECUTE ON FUNCTION enqueue_system_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB)
TO fet3d_system_event_executor;
-- The NOLOGIN requeue owner calls the integration-owned helper inside its
-- SECURITY DEFINER gate. Runtime executors receive no helper EXECUTE grant.
GRANT EXECUTE ON FUNCTION enqueue_integration_outbox_event_internal(TEXT, TEXT, UUID, TEXT, TEXT, JSONB, BOOLEAN, BOOLEAN)
    TO fet3d_requeue_owner;
REVOKE ALL ON FUNCTION enqueue_integration_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB)
FROM fet3d_processing_owner;
REVOKE ALL ON FUNCTION enqueue_system_outbox_event(TEXT, TEXT, UUID, TEXT, TEXT, JSONB)
    FROM fet3d_processing_owner, fet3d_dispatcher_executor, fet3d_processing_worker_executor,
        fet3d_ai_service_executor;

GRANT USAGE ON SCHEMA public TO fet3d_integration_owner;
GRANT USAGE ON SCHEMA public TO fet3d_dispatcher_executor, fet3d_backend_executor,
    fet3d_system_event_executor, fet3d_requeue_owner;
GRANT SELECT, INSERT, UPDATE ON TABLE integration_outbox_events TO fet3d_integration_owner;
GRANT SELECT, INSERT, UPDATE ON TABLE integration_event_consumptions TO fet3d_integration_owner;
GRANT SELECT ON TABLE processing_jobs, revisions, buildings TO fet3d_integration_owner;
GRANT SELECT, REFERENCES ON TABLE organizations TO fet3d_integration_owner;
REVOKE ALL ON TABLE integration_outbox_events FROM fet3d_processing_owner;

-- Learn is exposed only through the authenticated backend. The backend must
-- enforce PlatformAdmin for editorial writes and Trainee ownership for
-- bookmarks before using these grants; browsers and mobile clients receive no
-- database credentials.
REVOKE ALL ON TABLE learn_situations, learn_posts, learn_post_versions,
    learn_post_version_situations, learn_post_version_sources, learn_bookmarks
    FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE learn_situations, learn_posts,
    learn_post_versions, learn_post_version_situations, learn_post_version_sources
    TO fet3d_backend_executor;
GRANT SELECT, INSERT, DELETE ON TABLE learn_bookmarks TO fet3d_backend_executor;
GRANT SELECT ON TABLE users, knowledge_sources, quotations, quotation_building_items,
    buildings, payment_transactions, payos_payment_requests, service_entitlements
    TO fet3d_backend_executor;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE application_command_receipts
    TO fet3d_backend_executor;
GRANT SELECT, INSERT, UPDATE ON TABLE organizations, users, buildings
    TO fet3d_backend_executor;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE user_devices
    TO fet3d_backend_executor;
GRANT SELECT, INSERT, UPDATE ON TABLE service_packages
    TO fet3d_backend_executor;
GRANT SELECT, INSERT, UPDATE ON TABLE quotations, payment_provisioning_records,
    service_entitlements TO fet3d_backend_executor;

-- The backend application service owns Learn editorial orchestration. Database
-- triggers retain snapshot/relationship invariants; actor, ETag, idempotency,
-- audit and outbox are checked by the service transaction.
GRANT INSERT ON TABLE audit_logs TO fet3d_backend_executor;

REVOKE ALL ON TABLE auth_refresh_tokens, password_reset_tokens FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE auth_refresh_tokens, password_reset_tokens
    TO fet3d_backend_executor;
REVOKE ALL ON TABLE auth_google_onboarding_sessions FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE auth_google_onboarding_sessions
    TO fet3d_backend_executor;

REVOKE ALL ON TABLE service_package_discount_rules, quotation_building_items,
    enterprise_quote_requests, organization_notifications, notification_deliveries
    FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON TABLE service_package_discount_rules,
    quotation_building_items, enterprise_quote_requests,
    organization_notifications, notification_deliveries
    TO fet3d_backend_executor;
