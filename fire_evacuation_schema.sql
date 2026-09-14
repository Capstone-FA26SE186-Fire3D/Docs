-- ==============================================================================
-- Project : Fire Evacuation Training 3D
-- Version : 5.0 (Phase 1 + Phase 2, three-role model)
-- Engine  : PostgreSQL 14+
-- Scope   : IFC-only authoring; authenticated Trainee QR sessions; Phase 2
--           commercial, PayOS, invoice, feedback and support records.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
    plan        VARCHAR(50) DEFAULT 'free',                  -- Gói dịch vụ đăng ký (free, premium, enterprise)
    is_active   BOOLEAN DEFAULT true,                       -- Cờ trạng thái hoạt động của tổ chức
    metadata    JSONB DEFAULT '{}',                         -- Thông tin bổ sung (logo URL, địa chỉ VP, mã số thuế...)
    created_at  TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm khởi tạo tổ chức
    updated_at  TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật thông tin tổ chức gần nhất
    deleted_at  TIMESTAMPTZ                                 -- Thời điểm xóa mềm tổ chức
);

CREATE TABLE users (
    -- Định danh và liên kết tổ chức
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh người dùng
    organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT, -- Chỉ OrganizationUser có organization

    -- Thông tin xác thực
    email           VARCHAR(255) UNIQUE NOT NULL,               -- Địa chỉ email đăng nhập
    password_hash   VARCHAR(255) NOT NULL,                      -- Mật khẩu đã mã hóa (bcrypt/argon2)
    full_name       VARCHAR(255),                               -- Họ và tên đầy đủ
    role            user_role_enum NOT NULL,                    -- Vai trò phân quyền chính

    -- Trạng thái & Lịch sử
    is_active       BOOLEAN DEFAULT true,                       -- Cờ trạng thái tài khoản
    last_login_at   TIMESTAMPTZ,                                -- Thời điểm đăng nhập thành công gần nhất
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo tài khoản
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    deleted_at      TIMESTAMPTZ,                                -- Thời điểm xóa mềm
    CONSTRAINT check_user_role_organization CHECK (
        (role = 'OrganizationUser' AND organization_id IS NOT NULL)
        OR (role IN ('PlatformAdmin', 'Trainee') AND organization_id IS NULL)
    )
);

CREATE TABLE user_devices (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh đăng ký thiết bị
    user_id        UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL, -- Tài khoản đã xác thực trên thiết bị
    device_uuid    VARCHAR(255) NOT NULL UNIQUE,                -- Mã định danh cài đặt Android duy nhất
    device_model   VARCHAR(255),                               -- Tên thiết bị Android (VD: "Samsung S23")
    os_version     VARCHAR(50),                                -- Phiên bản Android (VD: "Android 14")
    app_version    VARCHAR(50),                                -- Phiên bản ứng dụng Android/Unity khi đăng ký
    last_seen_at   TIMESTAMPTZ DEFAULT NOW(),                  -- Lần cuối cùng thiết bị kết nối Server
    created_at     TIMESTAMPTZ DEFAULT NOW()                   -- Ngày ghi nhận thiết bị lần đầu
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
    is_active       BOOLEAN DEFAULT true,                       -- Cờ trạng thái hoạt động của tòa nhà
    created_by      UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser tạo hồ sơ tòa nhà
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm khởi tạo tòa nhà
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    deleted_at      TIMESTAMPTZ                                 -- Thời điểm xóa mềm tòa nhà
);

CREATE TABLE building_locations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh vị trí địa lý
    building_id UUID REFERENCES buildings(id) ON DELETE CASCADE UNIQUE NOT NULL, -- Khóa ngoại trỏ đến tòa nhà (1-1)

    -- Địa chỉ hành chính & GPS
    address     TEXT,                                       -- Địa chỉ chi tiết số nhà, tên đường
    city        VARCHAR(255),                               -- Tên Tỉnh/Thành phố
    district    VARCHAR(255),                               -- Tên Quận/Huyện
    latitude    DECIMAL(10, 8),                             -- Vĩ độ GPS (Latitude)
    longitude   DECIMAL(11, 8),                             -- Kinh độ GPS (Longitude)
    geojson     JSONB,                                      -- Ranh giới khu đất dạng GeoJSON
    created_at  TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo
    updated_at  TIMESTAMPTZ DEFAULT NOW()                   -- Thời điểm cập nhật gần nhất
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
    storage_url        TEXT NOT NULL,                              -- Đường dẫn lưu Cloud Storage (S3/MinIO)
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
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh log pipeline
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE NOT NULL, -- ID phiên bản IFC đang xử lý
    step           processing_step_enum NOT NULL,              -- Bước đang chạy (CleanGeometry, GenNavMesh, ExportGLB...)
    status         processing_step_status_enum NOT NULL,       -- Kết quả bước (Started, Success, Failed)
    message        TEXT,                                       -- Chi tiết lỗi hoặc log từ Python Worker
    duration_ms    INT,                                        -- Thời gian xử lý (milisecond)
    attempt_number INT DEFAULT 1,                              -- Số lần thử lại (Retry attempt)
    logged_at      TIMESTAMPTZ DEFAULT NOW()                   -- Thời gian ghi log
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
    checksum_sha256     VARCHAR(64),                                -- Mã checksum SHA256 để Client verify trước khi unpack
    package_size_bytes  BIGINT,                                     -- Dung lượng gói tải xuống (Bytes)
    min_runtime_version VARCHAR(20),                                -- Phiên bản app Unity tối thiểu cần để đọc gói này
    created_at          TIMESTAMPTZ DEFAULT NOW()                   -- Ngày đóng gói hoàn tất
);

CREATE TABLE release_qr_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh điểm quét QR
    release_id      UUID REFERENCES releases(id) ON DELETE CASCADE NOT NULL, -- ID bản phát hành tòa nhà liên kết
    training_id     UUID NOT NULL,                             -- Một Training duy nhất; FK thêm sau khi trainings được tạo
    organization_id UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức quản lý (Multi-tenant isolation)
    floor_id        UUID REFERENCES building_floors(id),        -- ID tầng dán mã QR
    created_by      UUID REFERENCES users(id) NOT NULL,         -- OrganizationUser tạo mã QR

    -- Cấu hình mã QR
    qr_hash         VARCHAR(255) UNIQUE NOT NULL,               -- Chuỗi mã hóa tĩnh duy nhất in trên QR
    label           VARCHAR(255),                               -- Tên vị trí dán ("Cột A1 - Sảnh Tầng 2")
    expires_at      TIMESTAMPTZ,                                -- Ngày hết hạn của mã QR
    is_active       BOOLEAN NOT NULL DEFAULT true,              -- Mọi Trainee xác thực dùng được khi QR active và release Published
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo
    CONSTRAINT check_release_qr_hash CHECK (NULLIF(BTRIM(qr_hash), '') IS NOT NULL)
);

-- ------------------------------------------------------------------------------
-- GROUP 5: Scenario & Training
-- ------------------------------------------------------------------------------

CREATE TABLE scenario_versions (
    id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh kịch bản PCCC
    revision_id                       UUID REFERENCES revisions(id) NOT NULL,     -- Revision IFC hợp lệ dùng để author scenario
    organization_id                   UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức tạo kịch bản
    version_number                    INT NOT NULL DEFAULT 1,                     -- Phiên bản kịch bản (1, 2, 3...)
    name                              VARCHAR(255) NOT NULL,                      -- Tên kịch bản ("Cháy phòng Server tầng 3")

    -- Cấu hình mô phỏng đám cháy & NPC
    fire_source_config                JSONB DEFAULT '{}',                        -- Vị trí, thời điểm bắt đầu
    npc_config                        JSONB DEFAULT '{}',                        -- Archetypes, mật độ, hành vi
    blocked_elements                  JSONB DEFAULT '[]',                        -- Cửa/cầu thang bị chặn theo thời gian
    guidance_level                    VARCHAR(50) DEFAULT 'full',                -- Full | partial | none

    -- Ngưỡng an toàn & Cấu hình tính điểm
    safety_thresholds                 JSONB DEFAULT '{}',                        -- Ngưỡng chịu đựng khói/nhiệt độ của người chơi
    replan_interval_seconds           INT DEFAULT 5,                             -- Tần suất tính lại đường đi Risk-aware A* (giây)
    score_wrong_exit_penalty          INT DEFAULT 10,                            -- Điểm trừ khi chạy nhầm vào cửa bị khóa
    score_hazard_per_second_penalty   DECIMAL(5, 2) DEFAULT 0.50,                -- Điểm trừ cho mỗi giây đứng trong khói
    score_time_bonus_threshold_seconds INT DEFAULT 120,                           -- Mốc thời gian (giây) để thưởng điểm thoát nhanh

    -- Readiness được ghi bằng revision_reviews.action = ConfirmForTraining và revision.status
    created_by                        UUID REFERENCES users(id) NOT NULL,        -- OrganizationUser tạo kịch bản
    created_at                        TIMESTAMPTZ DEFAULT NOW(),                 -- Thời điểm tạo
    updated_at                        TIMESTAMPTZ DEFAULT NOW(),                 -- Thời điểm cập nhật gần nhất
    UNIQUE (revision_id, version_number)
);

-- Review và release pin scenario đã sẵn sàng; FK được khai báo sau đối tượng đích.
ALTER TABLE revision_reviews
    ADD CONSTRAINT fk_revision_reviews_scenario_version
    FOREIGN KEY (scenario_version_id) REFERENCES scenario_versions(id) ON DELETE RESTRICT;

ALTER TABLE releases
    ADD CONSTRAINT fk_releases_scenario_version
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

-- QR được tạo sau Training và chỉ được active sau khi release Published.
ALTER TABLE release_qr_codes
    ADD CONSTRAINT fk_release_qr_codes_training
    FOREIGN KEY (training_id) REFERENCES trainings(id) ON DELETE RESTRICT;

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

    -- Trạng thái phiên
    mode                session_mode_enum NOT NULL,                -- Chế độ (Learn | Guided | Assessment)
    status              session_status_enum NOT NULL DEFAULT 'Created', -- Trạng thái (Created, Running, Completed, Crashed...)
    started_at          TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm Bắt đầu trên App
    ended_at            TIMESTAMPTZ                                 -- Thời điểm Kết thúc phiên
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
    created_at            TIMESTAMPTZ DEFAULT NOW(),           -- Ngày tạo kết quả
    updated_at            TIMESTAMPTZ DEFAULT NOW()            -- Ngày cập nhật kết quả
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
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh sự kiện
    session_id  UUID REFERENCES sessions(id) ON DELETE CASCADE NOT NULL, -- ID phiên diễn tập
    event_type  VARCHAR(100) NOT NULL,                      -- Loại sự kiện ('PICKUP_EXTINGUISHER', 'ENTER_SMOKE_ZONE'...)
    event_data  JSONB DEFAULT '{}',                         -- Dữ liệu chi tiết dạng JSON
    recorded_at TIMESTAMPTZ NOT NULL                        -- Mốc thời gian xảy ra sự kiện
);

-- ------------------------------------------------------------------------------
-- GROUP 7: Audit & Security
-- ------------------------------------------------------------------------------

CREATE TABLE audit_logs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh nhật ký hệ thống
    user_id       UUID,                                       -- ID tài khoản thực hiện thao tác
    action        audit_action_enum NOT NULL,                 -- Hành động (Upload, Approve, Reject, Delete...)
    target_entity VARCHAR(100) NOT NULL,                      -- Bảng/Thực thể bị tác động ('revisions', 'users'...)
    target_id     UUID,                                       -- ID của bản ghi bị tác động
    old_values    JSONB,                                      -- Dữ liệu cũ trước khi sửa
    new_values    JSONB,                                      -- Dữ liệu mới sau khi sửa
    ip_address    INET,                                       -- Địa chỉ IP người thực hiện
    user_agent    TEXT,                                       -- Thông tin thiết bị/trình duyệt
    created_at    TIMESTAMPTZ DEFAULT NOW()                   -- Thời điểm ghi nhật ký
);

-- ------------------------------------------------------------------------------
-- GROUP 8: Phase 2 Commercial, Payment, Feedback & Support
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

CREATE TABLE quotations (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id    UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    service_package_id UUID REFERENCES service_packages(id) ON DELETE RESTRICT NOT NULL,
    requested_by       UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL, -- OrganizationUser yêu cầu
    issued_by          UUID REFERENCES users(id) ON DELETE RESTRICT,          -- PlatformAdmin phát hành
    quotation_number   VARCHAR(50) UNIQUE NOT NULL,
    status             quotation_status_enum NOT NULL DEFAULT 'Draft',
    quantity           INT NOT NULL DEFAULT 1,
    unit_price         DECIMAL(14, 2) NOT NULL,
    subtotal_amount    DECIMAL(14, 2) NOT NULL,
    tax_amount         DECIMAL(14, 2) NOT NULL DEFAULT 0,
    discount_amount    DECIMAL(14, 2) NOT NULL DEFAULT 0,
    total_amount       DECIMAL(14, 2) NOT NULL,
    currency           VARCHAR(3) NOT NULL DEFAULT 'VND',
    valid_until        TIMESTAMPTZ NOT NULL,
    issued_at          TIMESTAMPTZ,
    accepted_at        TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT check_quotation_quantity CHECK (quantity > 0),
    CONSTRAINT check_quotation_amounts CHECK (
        unit_price >= 0
        AND subtotal_amount = unit_price * quantity
        AND tax_amount >= 0
        AND discount_amount >= 0
        AND total_amount = subtotal_amount + tax_amount - discount_amount
        AND total_amount >= 0
    ),
    CONSTRAINT check_quotation_currency CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT check_quotation_issued CHECK (
        status = 'Draft' OR (issued_by IS NOT NULL AND issued_at IS NOT NULL)
    )
);

CREATE TABLE payos_payment_requests (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id        UUID REFERENCES quotations(id) ON DELETE RESTRICT NOT NULL,
    organization_id     UUID REFERENCES organizations(id) ON DELETE RESTRICT NOT NULL,
    requested_by        UUID REFERENCES users(id) ON DELETE RESTRICT NOT NULL,
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
'Persists the ConfirmForTraining or Rejected readiness action for one revision/scenario pair; ConfirmForTraining moves ReadyForScenario to ConfirmedForTraining and is not certification.';
COMMENT ON TABLE release_qr_codes IS
'Each QR pins exactly one release_id and one training_id. An effective active QR also requires an unexpired code, Active Training, Published release and matching scenario/organization.';
COMMENT ON TABLE payos_payment_requests IS
'Phase 2 PayOS request. Paid is set only after a verified, idempotently processed webhook whose orderCode, amount and currency match the expected request.';
COMMENT ON COLUMN payos_payment_requests.return_url IS
'UI navigation only; returnUrl is never payment confirmation.';
COMMENT ON TABLE payment_transactions IS
'One row per PayOS webhook event. A trusted backend adapter verifies the canonicalized webhook data before DB invocation; the DB records that attestation, deduplicates webhook_event_id, and compares orderCode, amount and currency before Applied.';

-- ==============================================================================
-- SECTION 4: INDEXES
-- ==============================================================================

CREATE INDEX idx_organizations_active ON organizations(id) WHERE is_active AND deleted_at IS NULL;
CREATE INDEX idx_users_organization ON users(organization_id);
CREATE INDEX idx_users_active_role ON users(role) WHERE is_active AND deleted_at IS NULL;

CREATE INDEX idx_user_devices_user ON user_devices(user_id);

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

CREATE INDEX idx_release_qr_codes_release ON release_qr_codes(release_id);
CREATE INDEX idx_release_qr_codes_training ON release_qr_codes(training_id);
CREATE INDEX idx_release_qr_codes_organization ON release_qr_codes(organization_id);
CREATE INDEX idx_release_qr_codes_floor ON release_qr_codes(floor_id);
CREATE INDEX idx_release_qr_codes_created_by ON release_qr_codes(created_by);
CREATE INDEX idx_release_qr_codes_active ON release_qr_codes(qr_hash) WHERE is_active;

CREATE INDEX idx_scenario_versions_organization ON scenario_versions(organization_id);
CREATE INDEX idx_scenario_versions_created_by ON scenario_versions(created_by);

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

CREATE INDEX idx_session_results_unsynced ON session_results(created_at) WHERE NOT is_synced;
CREATE INDEX idx_session_events_type ON session_events(event_type);
CREATE INDEX idx_session_events_timeline ON session_events(session_id, recorded_at);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_target ON audit_logs(target_entity, target_id);
CREATE INDEX idx_audit_logs_time ON audit_logs(created_at DESC);

CREATE INDEX idx_service_packages_created_by ON service_packages(created_by);
CREATE INDEX idx_service_packages_active ON service_packages(code) WHERE is_active;
CREATE INDEX idx_quotations_organization ON quotations(organization_id);
CREATE INDEX idx_quotations_service_package ON quotations(service_package_id);
CREATE INDEX idx_quotations_requested_by ON quotations(requested_by);
CREATE INDEX idx_quotations_issued_by ON quotations(issued_by);
CREATE INDEX idx_payos_payment_requests_quotation ON payos_payment_requests(quotation_id);
CREATE INDEX idx_payos_payment_requests_organization ON payos_payment_requests(organization_id);
CREATE INDEX idx_payos_payment_requests_requested_by ON payos_payment_requests(requested_by);
CREATE INDEX idx_payos_payment_requests_status ON payos_payment_requests(status, created_at);
CREATE INDEX idx_payment_transactions_request ON payment_transactions(payment_request_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status, received_at);
CREATE INDEX idx_invoice_metadata_quotation ON invoice_metadata(quotation_id);
CREATE INDEX idx_invoice_metadata_organization ON invoice_metadata(organization_id);
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

-- ==============================================================================
-- SECTION 5: TRIGGERS & RULES
-- ==============================================================================

-- ConfirmForTraining là action readiness nội bộ. BEFORE trigger khóa revision
-- ngắn hạn, xác thực actor/scenario/organization và AFTER trigger mới chuyển
-- ReadyForScenario -> ConfirmedForTraining; không có nghĩa chứng nhận PCCC.
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

    IF NEW.action = 'ConfirmForTraining' AND v_revision.status != 'ReadyForScenario' THEN
        RAISE EXCEPTION 'ConfirmForTraining requires a ReadyForScenario revision';
    END IF;

    IF NEW.action = 'Rejected' AND v_revision.status != 'ReadyForScenario' THEN
        RAISE EXCEPTION 'Rejected review requires a ReadyForScenario revision';
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
    UPDATE public.revisions
    SET status = CASE NEW.action
        WHEN 'ConfirmForTraining' THEN 'ConfirmedForTraining'::public.revision_status_enum
        ELSE 'Rejected'::public.revision_status_enum
    END
    WHERE id = NEW.revision_id;

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
        OR (OLD.status = 'NeedsFix' AND NEW.status IN ('Processing', 'Rejected', 'Superseded'))
        OR (OLD.status = 'ReadyForScenario' AND NEW.status IN ('ConfirmedForTraining', 'Rejected', 'Superseded'))
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

    IF NEW.status = 'Rejected' AND NOT EXISTS (
        SELECT 1
        FROM public.revision_reviews AS review
        WHERE review.revision_id = NEW.id
          AND review.action = 'Rejected'
    ) THEN
        RAISE EXCEPTION 'Rejected requires a persisted review action';
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
'Readiness-only action: records ConfirmForTraining and transitions ReadyForScenario to ConfirmedForTraining; it is not certification or fire-safety approval.';

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
        WHERE revision.id = NEW.revision_id
          AND revision.status = 'ReadyForScenario'
          AND building.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'scenario authoring requires a matching ReadyForScenario revision and organization';
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

    IF TG_OP = 'UPDATE' AND OLD.created_by IS DISTINCT FROM NEW.created_by THEN
        RAISE EXCEPTION 'scenario created_by is immutable';
    END IF;

    RETURN NEW;
END;
$$;

-- Enforce the executable order: ConfirmForTraining -> Built release + matching
-- Training/package -> Published release -> active QR bound to that Training.
CREATE OR REPLACE FUNCTION validate_release_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
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
          )
    ) THEN
        RAISE EXCEPTION 'release requires the matching ConfirmedForTraining revision, scenario, building and organization';
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

    IF EXISTS (
        SELECT 1
        FROM public.release_qr_codes AS qr
        WHERE qr.release_id = OLD.id
          AND qr.is_active
          AND (qr.expires_at IS NULL OR qr.expires_at > pg_catalog.now())
    ) AND NEW.status != 'Published' THEN
        RAISE EXCEPTION 'deactivate active QR codes before changing Published release status';
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
            WHERE package.release_id = NEW.id
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

    IF TG_OP = 'UPDATE' AND EXISTS (
        SELECT 1
        FROM public.release_qr_codes AS qr
        WHERE qr.training_id = OLD.id
          AND qr.is_active
          AND (qr.expires_at IS NULL OR qr.expires_at > pg_catalog.now())
    ) AND (
        NEW.release_id IS DISTINCT FROM OLD.release_id
        OR NEW.scenario_version_id IS DISTINCT FROM OLD.scenario_version_id
        OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
        OR NEW.status != 'Active'
    ) THEN
        RAISE EXCEPTION 'deactivate active QR codes before changing their Training binding or status';
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
        FROM public.trainings AS training
        JOIN public.releases AS release ON release.id = training.release_id
        JOIN public.scenario_versions AS scenario ON scenario.id = training.scenario_version_id
        WHERE training.id = NEW.training_id
          AND training.release_id = NEW.release_id
          AND training.organization_id = NEW.organization_id
          AND release.id = NEW.release_id
          AND release.organization_id = NEW.organization_id
          AND release.scenario_version_id = training.scenario_version_id
          AND scenario.revision_id = release.revision_id
          AND scenario.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'QR, Training, release, scenario and organization must be consistent';
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
        JOIN public.releases AS release ON release.building_id = floor.building_id
        WHERE floor.id = NEW.floor_id
          AND floor.organization_id = NEW.organization_id
          AND release.id = NEW.release_id
    ) THEN
        RAISE EXCEPTION 'floor_id must belong to the QR release building and organization';
    END IF;

    IF NEW.is_active AND NOT EXISTS (
        SELECT 1
        FROM public.trainings AS training
        JOIN public.releases AS release ON release.id = training.release_id
        WHERE training.id = NEW.training_id
          AND training.status = 'Active'
          AND release.id = NEW.release_id
          AND release.status = 'Published'
    ) THEN
        RAISE EXCEPTION 'an active QR requires its matching Active Training and Published release';
    END IF;

    IF NEW.is_active
       AND NEW.expires_at IS NOT NULL
       AND NEW.expires_at <= pg_catalog.now() THEN
        RAISE EXCEPTION 'an active QR cannot already be expired';
    END IF;

    RETURN NEW;
END;
$$;

-- Chỉ kiểm tra tính nhất quán dữ liệu sở hữu của training/release; không so khớp
-- organization của Trainee. Eligibility chỉ là Trainee active + QR active gắn
-- một Training Active duy nhất + release Published.
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
        JOIN public.trainings t ON t.id = q.training_id
        JOIN public.releases r ON r.id = q.release_id
        WHERE q.id = NEW.qr_code_id
          AND q.training_id = NEW.training_id
          AND q.release_id = NEW.release_id
          AND q.organization_id = NEW.organization_id
          AND q.is_active
          AND (q.expires_at IS NULL OR q.expires_at > pg_catalog.now())
          AND t.release_id = NEW.release_id
          AND t.scenario_version_id = NEW.scenario_version_id
          AND t.organization_id = NEW.organization_id
          AND t.status = 'Active'
          AND NEW.mode::TEXT = ANY(t.allowed_modes)
          AND r.id = NEW.release_id
          AND r.status = 'Published'
          AND r.scenario_version_id = NEW.scenario_version_id
          AND r.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'session requires the QR-pinned Active Training, Published release, scenario, organization and allowed mode';
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
CREATE OR REPLACE FUNCTION validate_payos_paid_request()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND (
        OLD.order_code != NEW.order_code
        OR OLD.expected_amount != NEW.expected_amount
        OR OLD.expected_currency != NEW.expected_currency
    ) THEN
        RAISE EXCEPTION 'PayOS expected orderCode, amount and currency are immutable';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.status = 'Paid' AND (
        NEW.status != 'Paid'
        OR NEW.paid_transaction_id IS DISTINCT FROM OLD.paid_transaction_id
        OR NEW.paid_at IS DISTINCT FROM OLD.paid_at
    ) THEN
        RAISE EXCEPTION 'Paid payment truth and provenance are immutable';
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status = 'Paid' AND OLD.status != 'Paid'
       AND OLD.status != 'Pending' THEN
        RAISE EXCEPTION 'Only a Pending payment request can become Paid';
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status = 'Paid' AND OLD.status != 'Paid'
       AND CURRENT_USER != 'fet3d_payos_ledger_owner' THEN
        RAISE EXCEPTION 'Paid payment request must use trusted PayOS webhook function';
    END IF;

    IF NEW.status = 'Paid' AND NOT EXISTS (
        SELECT 1
        FROM public.payment_transactions pt
        WHERE pt.id = NEW.paid_transaction_id
          AND pt.payment_request_id = NEW.id
          AND pt.status = 'Applied'
          AND pt.signature_verified
          AND pt.received_order_code = NEW.order_code
          AND pt.received_amount = NEW.expected_amount
          AND pt.received_currency = NEW.expected_currency
    ) THEN
        RAISE EXCEPTION 'Paid requires an Applied verified webhook matching orderCode, amount and currency';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Runtime payment creation path. The backend calls PayOS outside any DB transaction,
-- then invokes this short function with the returned HTTPS checkout URL. Amount,
-- currency and organization are derived from the locked Accepted quotation; callers
-- cannot choose them or create a status other than Pending.
CREATE OR REPLACE FUNCTION create_pending_payos_payment_request(
    p_quotation_id UUID,
    p_requested_by UUID,
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

    INSERT INTO public.payos_payment_requests (
        quotation_id,
        organization_id,
        requested_by,
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
    UUID, UUID, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) IS
'Creates only Pending PayOS requests from an Accepted quotation after the backend completes the external PayOS call; returnUrl remains navigation-only.';

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
BEFORE INSERT OR UPDATE OF revision_id, organization_id, version_number, name,
    fire_source_config, npc_config, blocked_elements, guidance_level,
    safety_thresholds, replan_interval_seconds, score_wrong_exit_penalty,
    score_hazard_per_second_penalty, score_time_bonus_threshold_seconds, created_by
ON scenario_versions FOR EACH ROW EXECUTE FUNCTION validate_scenario_version_write();

CREATE TRIGGER validate_release_before_write
BEFORE INSERT OR UPDATE OF revision_id, scenario_version_id, building_id,
    organization_id, published_by, revoked_by, status, safety_thresholds,
    revoked_reason, published_at
ON releases FOR EACH ROW EXECUTE FUNCTION validate_release_write();

CREATE TRIGGER validate_training_before_write
BEFORE INSERT OR UPDATE OF release_id, scenario_version_id, organization_id,
    status, created_by
ON trainings FOR EACH ROW EXECUTE FUNCTION validate_training_write();

CREATE TRIGGER validate_release_qr_before_write
BEFORE INSERT OR UPDATE OF release_id, training_id, organization_id, floor_id,
    created_by, qr_hash, expires_at, is_active
ON release_qr_codes FOR EACH ROW EXECUTE FUNCTION validate_release_qr_code();

CREATE TRIGGER validate_session_before_write
BEFORE INSERT OR UPDATE OF training_id, release_id, scenario_version_id, organization_id,
    trainee_user_id, device_id, qr_code_id, mode
ON sessions FOR EACH ROW EXECUTE FUNCTION validate_training_session();

CREATE TRIGGER enforce_payment_transaction_state_before_write
BEFORE INSERT OR UPDATE OR DELETE
ON payment_transactions FOR EACH ROW EXECUTE FUNCTION enforce_payment_transaction_state();

CREATE TRIGGER validate_payos_paid_before_write
BEFORE INSERT OR UPDATE OF order_code, expected_amount, expected_currency,
    status, paid_transaction_id, paid_at
ON payos_payment_requests FOR EACH ROW EXECUTE FUNCTION validate_payos_paid_request();

CREATE TRIGGER set_ts_organizations BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_users BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_buildings BEFORE UPDATE ON buildings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER set_ts_building_locations BEFORE UPDATE ON building_locations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
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
    UUID, UUID, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
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
    UUID, UUID, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION apply_verified_payos_webhook(
    UUID, TEXT, TEXT, BIGINT, NUMERIC, TEXT, JSONB
) FROM PUBLIC;

GRANT USAGE ON SCHEMA public
TO fet3d_payos_request_executor, fet3d_payos_webhook_executor, fet3d_payos_ledger_owner;
GRANT SELECT (id, organization_id, status, total_amount, currency, valid_until)
ON TABLE quotations TO fet3d_payos_ledger_owner;
GRANT SELECT (id, organization_id, role, is_active, deleted_at)
ON TABLE users TO fet3d_payos_ledger_owner;
GRANT EXECUTE ON FUNCTION create_pending_payos_payment_request(
    UUID, UUID, BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) TO fet3d_payos_request_executor;
GRANT EXECUTE ON FUNCTION apply_verified_payos_webhook(
    UUID, TEXT, TEXT, BIGINT, NUMERIC, TEXT, JSONB
) TO fet3d_payos_webhook_executor;
