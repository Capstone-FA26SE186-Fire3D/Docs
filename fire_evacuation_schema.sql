-- ==============================================================================
-- Project : Fire Evacuation Training 3D
-- Version : 3.2 (Full Complete Schema with Detailed Standard Inline Comments)
-- Engine  : PostgreSQL 14+
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==============================================================================
-- SECTION 1: ENUM TYPES
-- ==============================================================================

-- Phân quyền người dùng trong hệ thống Multi-tenant
CREATE TYPE user_role_enum AS ENUM (
    'PlatformAdmin',    -- Quản trị viên toàn hệ thống (Super Admin)
    'OrgOwner',         -- Chủ sở hữu/Quản trị viên cấp Tổ chức (Tenant Owner)
    'BimOperator',      -- Kỹ sư vận hành/Upload và chỉnh sửa mô hình BIM
    'FireReviewer',     -- Chuyên gia/Thẩm duyệt viên PCCC kiểm định kịch bản
    'Member'            -- Học viên/Người tham gia diễn tập thoát nạn
);

-- Định dạng file đầu vào hỗ trợ xử lý
CREATE TYPE file_type_enum AS ENUM (
    'IFC',              -- File chuẩn IFC (Industry Foundation Classes)
    'RVT',              -- File Autodesk Revit
    'DWG',              -- Bản vẽ CAD 2D/3D (AutoCAD)
    'DXF',              -- File trao đổi bản vẽ CAD 2D/3D
    'PDF'               -- Bản vẽ sơ đồ 2D dạng PDF
);

-- Vòng đời xử lý phiên bản BIM (Revision Pipeline)
CREATE TYPE revision_status_enum AS ENUM (
    'Draft',            -- Revision mới tạo, chưa upload file
    'Uploaded',         -- File đã lên server, chờ worker xử lý
    'Processing',       -- Worker đang chạy pipeline tự động
    'NeedsFix',         -- Worker xong, có issue cần Operator sửa
    'ReviewRequired',   -- Sạch issue, chờ FireReviewer duyệt
    'Approved',         -- Reviewer duyệt, chờ build package
    'Rejected',         -- Reviewer từ chối vĩnh viễn
    'Failed',           -- Worker lỗi sau tất cả lượt retry
    'Published',        -- Release đã được tạo thành công
    'Superseded'        -- Đã có revision/release mới hơn thay thế
);

-- Hành động phê duyệt của chuyên gia PCCC
CREATE TYPE review_action_enum AS ENUM (
    'Approved',         -- Đạt yêu cầu, thông qua mô hình/kịch bản
    'Rejected'          -- Không đạt, yêu cầu chỉnh sửa kèm lý do
);

-- Trạng thái bản phát hành gói 3D tòa nhà (Release)
CREATE TYPE release_status_enum AS ENUM (
    'Built',            -- Đã đóng gói bundle 3D thành công
    'Verified',         -- Đã kiểm thử tải & hiển thị tốt trên Mobile
    'Active',           -- Bản phát hành chính thức đang được sử dụng
    'Deprecated',       -- Khuyến cáo ngưng dùng (đã có bản mới hơn)
    'Revoked',          -- Bị thu hồi khẩn cấp do phát hiện lỗi nghiêm trọng
    'ArchivedWarning'   -- Lưu trữ lịch sử, chỉ dùng để đối soát
);

-- Trạng thái chiến dịch tập huấn
CREATE TYPE campaign_status_enum AS ENUM (
    'Draft',            -- Chiến dịch mới tạo, chưa mở cho học viên
    'Active',           -- Đang diễn ra, cho phép học viên vào diễn tập
    'Closed',           -- Đã kết thúc hạn diễn tập, không nhận bài mới
    'Archived'          -- Đã đóng gói lưu trữ kết quả
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
    'CompletedWithDeprecation', -- Hoàn thành nhưng bản đồ bị đổi phiên bản giữa chừng
    'ScenarioUnsurvivable',     -- Nhân vật bị kẹt/ngạt khói tử vong trong game
    'Aborted',                  -- Người chơi chủ động thoát giữa chừng
    'Abandoned',                -- Treo game quá lâu không tương tác
    'Crashed'                   -- Mất kết nối/Sập ứng dụng
);

-- Hành động ghi nhật ký hệ thống (Audit Trail)
CREATE TYPE audit_action_enum AS ENUM (
    'Upload',           -- Tải file tài liệu/bản vẽ lên
    'Approve',          -- Phê duyệt nội dung/kịch bản
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
    'Resume'            -- Khôi phục phiên chơi từ Checkpoint
);

-- Các bước trong Pipeline xử lý tự động file BIM/3D
CREATE TYPE processing_step_enum AS ENUM (
    'Quarantine',       -- Bước 1: Quét virus & mã độc
    'Parse',            -- Bước 2: Đọc cấu trúc hình học & thuộc tính IFC/DWG
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
    created_at  TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm khởi tạo tổ chức
    updated_at  TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật thông tin tổ chức gần nhất
    deleted_at  TIMESTAMPTZ                                 -- Thời điểm xóa mềm tổ chức
);

CREATE TABLE users (
    -- Định danh và liên kết tổ chức
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh người dùng
    organization_id UUID REFERENCES organizations(id) ON DELETE RESTRICT, -- ID tổ chức chứa người dùng (PlatformAdmin thì NULL)
    
    -- Thông tin xác thực
    email           VARCHAR(255) UNIQUE NOT NULL,               -- Địa chỉ email đăng nhập
    password_hash   VARCHAR(255) NOT NULL,                      -- Mật khẩu đã mã hóa (bcrypt/argon2)
    full_name       VARCHAR(255),                               -- Họ và tên đầy đủ
    role            user_role_enum NOT NULL,                    -- Vai trò phân quyền (PlatformAdmin, OrgOwner, BimOperator...)
    
    -- Trạng thái & Lịch sử
    is_active       BOOLEAN DEFAULT true,                       -- Cờ trạng thái tài khoản
    last_login_at   TIMESTAMPTZ,                                -- Thời điểm đăng nhập thành công gần nhất
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo tài khoản
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    deleted_at      TIMESTAMPTZ,                                -- Thời điểm xóa mềm
    CONSTRAINT check_org_role CHECK (
        (role = 'PlatformAdmin' AND organization_id IS NULL)
        OR (role != 'PlatformAdmin' AND organization_id IS NOT NULL)
    )
);

CREATE TABLE user_devices (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh đăng ký thiết bị
    user_id        UUID REFERENCES users(id) ON DELETE SET NULL, -- ID người dùng đăng nhập gần nhất (NULL nếu chưa đăng nhập)
    device_uuid    VARCHAR(255) NOT NULL UNIQUE,                -- Mã định danh phần cứng duy nhất (IMEI/AndroidID/IDFV)
    device_model   VARCHAR(255),                               -- Tên dòng máy/model (VD: "iPad Air 5", "Samsung S23")
    os_version     VARCHAR(50),                                -- Hệ điều hành và phiên bản (VD: "iOS 17.2", "Android 14")
    app_version    VARCHAR(50),                                -- Phiên bản ứng dụng Mobile/Unity
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
    created_by      UUID REFERENCES users(id),                  -- ID tài khoản tạo hồ sơ tòa nhà
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm khởi tạo tòa nhà
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    deleted_at      TIMESTAMPTZ                                 -- Thời điểm xóa mềm tòa nhà
);

CREATE TABLE building_locations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh vị trí địa lý
    building_id UUID REFERENCES buildings(id) ON DELETE CASCADE UNIQUE, -- Khóa ngoại trỏ đến tòa nhà (1-1)
    
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
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh tầng
    building_id     UUID REFERENCES buildings(id) ON DELETE CASCADE, -- ID tòa nhà chứa tầng này
    organization_id UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức sở hữu tòa nhà (Cô lập dữ liệu)
    floor_number    INT NOT NULL,                               -- Số thứ tự tầng (-1 = Hầm 1, 1 = Tầng 1)
    floor_name      VARCHAR(100),                               -- Tên gợi nhớ tầng ("Tầng Trệt", "Tầng Kỹ Thuật")
    floor_plan_url  TEXT,                                       -- Đường dẫn URL sơ đồ tầng 2D gốc
    area_sqm        DECIMAL(10, 2),                             -- Diện tích sàn (m2)
    created_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    UNIQUE (building_id, floor_number)
);

CREATE TABLE building_contacts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh liên hệ
    building_id  UUID REFERENCES buildings(id) ON DELETE CASCADE, -- ID tòa nhà liên quan
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
    building_id    UUID REFERENCES buildings(id),              -- ID tòa nhà gắn với phiên bản BIM
    uploaded_by    UUID REFERENCES users(id),                  -- ID kỹ sư BIM/người thực hiện upload
    version_label  VARCHAR(100),                               -- Nhãn phiên bản ("v1.0-Arch", "v2.1-Final")
    primary_type   file_type_enum,                             -- Định dạng file chính (IFC, RVT, DWG...)
    status         revision_status_enum NOT NULL DEFAULT 'Draft', -- Trạng thái tiến trình pipeline
    created_at     TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo phiên bản
    updated_at     TIMESTAMPTZ DEFAULT NOW()                   -- Thời điểm cập nhật gần nhất
);

CREATE TABLE source_documents (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh file gốc
    revision_id        UUID REFERENCES revisions(id) ON DELETE CASCADE, -- ID phiên bản BIM chứa file này
    floor_id           UUID REFERENCES building_floors(id) ON DELETE SET NULL, -- ID tầng tương ứng (nếu là bản vẽ 2D tầng lẻ)
    uploaded_by        UUID REFERENCES users(id),                  -- ID người tải file lên
    
    -- Metadata file & Lưu trữ
    original_filename  VARCHAR(500) NOT NULL,                      -- Tên file gốc ban đầu ("MatBang_Tang1.dwg")
    file_type          file_type_enum NOT NULL,                    -- Loại định dạng file (IFC, RVT, DWG, PDF...)
    file_size_bytes    BIGINT,                                     -- Dung lượng file (Bytes)
    storage_url        TEXT NOT NULL,                              -- Đường dẫn lưu Cloud Storage (S3/MinIO)
    mime_type          VARCHAR(100),                               -- Định dạng MIME
    sha256_hash        VARCHAR(64),                                -- Mã checksum SHA256 chống trùng lặp
    
    -- Kiểm tra an toàn & bản quyền
    quarantine_status  quarantine_status_enum NOT NULL DEFAULT 'Pending', -- Trạng thái quét Virus/Mã độc
    quarantine_note    TEXT,                                       -- Ghi chú chi tiết từ dịch vụ antivirus
    usage_rights       TEXT,                                       -- Quy định quyền sử dụng tài liệu
    source_tool        VARCHAR(255),                               -- Phần mềm tạo file ("Revit 2024", "AutoCAD 2023")
    created_at         TIMESTAMPTZ DEFAULT NOW()                   -- Ngày tải file lên
);

CREATE TABLE annotation_sets (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh bộ chú thích
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE, -- ID phiên bản BIM chứa đánh dấu
    version_number INT NOT NULL DEFAULT 1,                     -- Số thứ tự phiên bản chú thích (1, 2, 3...)
    data           JSONB NOT NULL DEFAULT '{}',                -- Tọa độ vòi chữa cháy, bình PCCC, lối thoát hiểm
    provenance     VARCHAR(50) DEFAULT 'operator',             -- Nguồn gốc ('operator' = con người, 'ai' = tự động)
    created_by     UUID REFERENCES users(id),                  -- ID người tạo chú thích
    created_at     TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm tạo
    UNIQUE (revision_id, version_number)
);

CREATE TABLE revision_processing_logs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh log pipeline
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE, -- ID phiên bản BIM đang chạy tự động
    step           processing_step_enum NOT NULL,              -- Bước đang chạy (CleanGeometry, GenNavMesh, ExportGLB...)
    status         processing_step_status_enum NOT NULL,       -- Kết quả bước (Started, Success, Failed)
    message        TEXT,                                       -- Chi tiết lỗi hoặc log từ Python Worker
    duration_ms    INT,                                        -- Thời gian xử lý (milisecond)
    attempt_number INT DEFAULT 1,                              -- Số lần thử lại (Retry attempt)
    logged_at      TIMESTAMPTZ DEFAULT NOW()                   -- Thời gian ghi log
);

CREATE TABLE revision_reviews (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh lượt duyệt mô hình
    revision_id    UUID REFERENCES revisions(id) ON DELETE CASCADE, -- ID phiên bản BIM được duyệt
    reviewed_by    UUID REFERENCES users(id),                  -- ID chuyên gia PCCC / FireReviewer
    action         review_action_enum NOT NULL,                -- Kết quả duyệt (Approved, Rejected)
    review_message TEXT,                                       -- Nhận xét chuyên môn hoặc lý do yêu cầu sửa
    reviewed_at    TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm duyệt
    CONSTRAINT check_reject_message CHECK (
        action != 'Rejected' OR (review_message IS NOT NULL AND review_message != '')
    )
);

-- ------------------------------------------------------------------------------
-- GROUP 4: Release Management
-- ------------------------------------------------------------------------------

CREATE TABLE releases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh bản phát hành
    revision_id     UUID REFERENCES revisions(id) UNIQUE,       -- ID phiên bản BIM tương ứng đã duyệt
    building_id     UUID REFERENCES buildings(id),              -- ID tòa nhà phát hành
    organization_id UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức quản lý bản phát hành
    
    -- Phê duyệt & Thu hồi
    approved_by     UUID REFERENCES users(id),                  -- ID quản trị viên duyệt phát hành
    revoked_by      UUID REFERENCES users(id),                  -- ID người thu hồi bản phát hành (nếu có lỗi)
    status          release_status_enum NOT NULL DEFAULT 'Built', -- Trạng thái (Built, Active, Revoked...)
    revoked_reason  TEXT,                                       -- Lý do thu hồi/hủy bỏ
    published_at    TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm xuất bản
    updated_at      TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm cập nhật gần nhất
    CONSTRAINT check_revoke_fields CHECK (
        (status NOT IN ('Revoked', 'ArchivedWarning'))
        OR (revoked_reason IS NOT NULL AND revoked_reason != '' AND revoked_by IS NOT NULL)
    )
);

CREATE TABLE release_packages (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh gói tài nguyên đã biên dịch
    release_id          UUID REFERENCES releases(id) ON DELETE CASCADE UNIQUE, -- ID bản phát hành tương ứng (1-1)
    manifest_url        TEXT NOT NULL,                              -- Đường dẫn file manifest JSON
    package_url         TEXT NOT NULL,                              -- Đường dẫn tải file Zip/AssetBundle 3D
    checksum_sha256     VARCHAR(64),                                -- Mã checksum SHA256 để Client verify trước khi unpack
    package_size_bytes  BIGINT,                                     -- Dung lượng gói tải xuống (Bytes)
    min_runtime_version VARCHAR(20),                                -- Phiên bản app Unity tối thiểu cần để đọc gói này
    created_at          TIMESTAMPTZ DEFAULT NOW()                   -- Ngày đóng gói hoàn tất
);

CREATE TABLE release_qr_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh điểm quét QR
    release_id      UUID REFERENCES releases(id) ON DELETE CASCADE, -- ID bản phát hành tòa nhà liên kết
    organization_id UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức quản lý (Multi-tenant)
    floor_id        UUID REFERENCES building_floors(id),        -- ID tầng dán mã QR
    created_by      UUID REFERENCES users(id),                  -- ID người tạo mã QR
    
    -- Cấu hình mã QR
    qr_hash         VARCHAR(255) UNIQUE NOT NULL,               -- Chuỗi mã hóa tĩnh duy nhất in trên QR
    label           VARCHAR(255),                               -- Tên vị trí dán ("Cột A1 - Sảnh Tầng 2")
    is_public       BOOLEAN DEFAULT false,                      -- Cờ cho phép quét tự do không cần login
    expires_at      TIMESTAMPTZ,                                -- Ngày hết hạn của mã QR
    is_active       BOOLEAN DEFAULT true,                       -- Cờ bật/tắt mã QR
    created_at      TIMESTAMPTZ DEFAULT NOW()                   -- Thời điểm tạo
);

-- ------------------------------------------------------------------------------
-- GROUP 5: Campaign, Scenario & Assignment
-- ------------------------------------------------------------------------------

CREATE TABLE scenario_versions (
    id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh kịch bản PCCC
    release_id                        UUID REFERENCES releases(id),              -- ID bản phát hành tòa nhà áp dụng
    organization_id                   UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức tạo kịch bản
    version_number                    INT NOT NULL DEFAULT 1,                     -- Phiên bản kịch bản (1, 2, 3...)
    name                              VARCHAR(255),                               -- Tên kịch bản ("Cháy phòng Server tầng 3")
    
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
    
    -- Phê duyệt
    is_approved                       BOOLEAN DEFAULT false,                     -- Cờ duyệt kịch bản từ FireReviewer
    approved_by                       UUID REFERENCES users(id),                 -- ID người duyệt
    approved_at                       TIMESTAMPTZ,                               -- Thời điểm duyệt
    created_by                        UUID REFERENCES users(id),                 -- ID người tạo kịch bản
    created_at                        TIMESTAMPTZ DEFAULT NOW(),                 -- Thời điểm tạo
    updated_at                        TIMESTAMPTZ DEFAULT NOW(),                 -- Thời điểm cập nhật gần nhất
    UNIQUE (release_id, version_number)
);

CREATE TABLE campaigns (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh chiến dịch
    release_id          UUID REFERENCES releases(id),              -- ID bản phát hành tòa nhà diễn ra tập huấn
    scenario_version_id UUID REFERENCES scenario_versions(id),    -- ID kịch bản PCCC áp dụng
    organization_id     UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức phát động chiến dịch
    name                VARCHAR(255) NOT NULL,                      -- Tên chiến dịch ("Diễn tập PCCC Q3/2026")
    description         TEXT,                                       -- Mô tả chi tiết yêu cầu
    start_date          TIMESTAMPTZ,                                -- Ngày bắt đầu
    end_date            TIMESTAMPTZ,                                -- Ngày kết thúc
    status              campaign_status_enum NOT NULL DEFAULT 'Draft', -- Trạng thái (Draft, Active, Closed...)
    max_attempts        INT DEFAULT 1,                              -- Số lần diễn tập tối đa cho mỗi học viên
    created_by          UUID REFERENCES users(id),                  -- ID người tạo chiến dịch
    created_at          TIMESTAMPTZ DEFAULT NOW(),                  -- Ngày tạo
    updated_at          TIMESTAMPTZ DEFAULT NOW(),                  -- Ngày cập nhật gần nhất
    CONSTRAINT check_campaign_dates CHECK (end_date IS NULL OR end_date > start_date)
);

CREATE TABLE assignments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh bài tập huấn
    campaign_id     UUID REFERENCES campaigns(id) ON DELETE CASCADE, -- ID chiến dịch chứa bài tập
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE, -- ID học viên được giao bài
    organization_id UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức quản lý (Multi-tenant)
    max_attempts    INT DEFAULT 1,                              -- Số lần diễn tập tối đa của riêng học viên này
    attempts_used   INT DEFAULT 0,                              -- Số lần học viên đã thực hiện thực tế
    due_date        TIMESTAMPTZ,                                -- Hạn chót phải hoàn thành
    assigned_at     TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm giao bài
    completed_at    TIMESTAMPTZ,                                -- Thời điểm hoàn thành đạt yêu cầu
    UNIQUE (campaign_id, user_id),
    CONSTRAINT check_attempts CHECK (attempts_used <= max_attempts)
);

-- ------------------------------------------------------------------------------
-- GROUP 6: Session & Results
-- ------------------------------------------------------------------------------

CREATE TABLE sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh phiên diễn tập
    campaign_id         UUID REFERENCES campaigns(id),             -- ID chiến dịch (NULL nếu là Ad-hoc QR drill)
    scenario_version_id UUID REFERENCES scenario_versions(id) NOT NULL, -- ID kịch bản PCCC được tải vào phiên
    organization_id     UUID REFERENCES organizations(id) NOT NULL, -- ID tổ chức sở hữu phiên
    
    -- Định danh người chơi & thiết bị
    user_id             UUID REFERENCES users(id),                 -- ID học viên (NULL nếu là Guest)
    guest_token         VARCHAR(255),                              -- Token tạm thời của Guest không có tài khoản
    device_id           UUID REFERENCES user_devices(id),          -- ID thiết bị phần cứng đang chơi
    qr_code_id          UUID REFERENCES release_qr_codes(id),      -- ID điểm dán QR khởi chạy phiên (nếu quét QR)
    assignment_id       UUID REFERENCES assignments(id),           -- ID bài tập tương ứng được giao (nếu có)
    
    -- Trạng thái phiên
    mode                session_mode_enum NOT NULL,                -- Chế độ (Learn | Guided | Assessment)
    status              session_status_enum NOT NULL DEFAULT 'Created', -- Trạng thái (Created, Running, Completed, Crashed...)
    started_at          TIMESTAMPTZ DEFAULT NOW(),                  -- Thời điểm Bắt đầu trên App
    ended_at            TIMESTAMPTZ,                                -- Thời điểm Kết thúc phiên
    CONSTRAINT check_user_or_guest CHECK (user_id IS NOT NULL OR guest_token IS NOT NULL)
);

CREATE TABLE session_results (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh kết quả bài tập
    session_id            UUID REFERENCES sessions(id) ON DELETE CASCADE UNIQUE, -- ID phiên diễn tập (1-1)
    
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
    session_id               UUID REFERENCES sessions(id) ON DELETE CASCADE, -- ID phiên diễn tập
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

CREATE TABLE session_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- Khóa chính định danh sự kiện
    session_id  UUID REFERENCES sessions(id) ON DELETE CASCADE, -- ID phiên diễn tập
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

-- ==============================================================================
-- SECTION 4: INDEXES
-- ==============================================================================

CREATE INDEX idx_org_active ON organizations(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_org    ON users(organization_id);
CREATE INDEX idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role   ON users(role);

CREATE INDEX idx_devices_user ON user_devices(user_id);
CREATE INDEX idx_devices_uuid ON user_devices(device_uuid);

CREATE INDEX idx_buildings_org    ON buildings(organization_id);
CREATE INDEX idx_buildings_active ON buildings(deleted_at) WHERE deleted_at IS NULL;

CREATE INDEX idx_floors_building ON building_floors(building_id);
CREATE INDEX idx_floors_org      ON building_floors(organization_id);

CREATE INDEX idx_contacts_building ON building_contacts(building_id);

CREATE INDEX idx_revisions_building ON revisions(building_id);
CREATE INDEX idx_revisions_status   ON revisions(status);

CREATE INDEX idx_source_docs_revision   ON source_documents(revision_id);
CREATE INDEX idx_source_docs_floor      ON source_documents(floor_id);
CREATE INDEX idx_source_docs_quarantine ON source_documents(quarantine_status);

CREATE INDEX idx_annotations_revision ON annotation_sets(revision_id);
CREATE INDEX idx_proc_logs_revision   ON revision_processing_logs(revision_id);
CREATE INDEX idx_reviews_revision     ON revision_reviews(revision_id);

CREATE INDEX idx_releases_revision ON releases(revision_id);
CREATE INDEX idx_releases_building ON releases(building_id);
CREATE INDEX idx_releases_org      ON releases(organization_id);
CREATE INDEX idx_releases_status   ON releases(status);

CREATE UNIQUE INDEX idx_qr_hash   ON release_qr_codes(qr_hash);
CREATE INDEX idx_qr_release       ON release_qr_codes(release_id);
CREATE INDEX idx_qr_org           ON release_qr_codes(organization_id);

CREATE INDEX idx_scenario_release  ON scenario_versions(release_id);
CREATE INDEX idx_scenario_org      ON scenario_versions(organization_id);

CREATE INDEX idx_campaigns_release  ON campaigns(release_id);
CREATE INDEX idx_campaigns_scenario ON campaigns(scenario_version_id);
CREATE INDEX idx_campaigns_org      ON campaigns(organization_id);

CREATE INDEX idx_assignments_campaign ON assignments(campaign_id);
CREATE INDEX idx_assignments_user     ON assignments(user_id);

CREATE INDEX idx_sessions_campaign   ON sessions(campaign_id);
CREATE INDEX idx_sessions_scenario   ON sessions(scenario_version_id);
CREATE INDEX idx_sessions_user       ON sessions(user_id);
CREATE INDEX idx_sessions_guest      ON sessions(guest_token);
CREATE INDEX idx_sessions_org        ON sessions(organization_id);

CREATE INDEX idx_results_session  ON session_results(session_id);
CREATE INDEX idx_results_unsynced ON session_results(is_synced) WHERE is_synced = false;

CREATE INDEX idx_checkpoints_session ON session_checkpoints(session_id);

CREATE INDEX idx_events_session ON session_events(session_id);
CREATE INDEX idx_events_type    ON session_events(event_type);

CREATE INDEX idx_audit_user   ON audit_logs(user_id);
CREATE INDEX idx_audit_target ON audit_logs(target_entity, target_id);

-- ==============================================================================
-- SECTION 5: TRIGGERS & RULES
-- ==============================================================================

CREATE TRIGGER set_ts_organizations BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_users BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_buildings BEFORE UPDATE ON buildings FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_building_locations BEFORE UPDATE ON building_locations FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_building_floors BEFORE UPDATE ON building_floors FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_building_contacts BEFORE UPDATE ON building_contacts FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_revisions BEFORE UPDATE ON revisions FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_releases BEFORE UPDATE ON releases FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_scenario_versions BEFORE UPDATE ON scenario_versions FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_campaigns BEFORE UPDATE ON campaigns FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
CREATE TRIGGER set_ts_session_results BEFORE UPDATE ON session_results FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

-- Đảm bảo Audit Log là bảng bất biến (Append-only)
CREATE RULE prevent_update_audit_logs AS ON UPDATE TO audit_logs DO INSTEAD NOTHING;
CREATE RULE prevent_delete_audit_logs AS ON DELETE TO audit_logs DO INSTEAD NOTHING;