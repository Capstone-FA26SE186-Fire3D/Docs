# Builds the logical + physical ERD Markdown and the physical DBML from the production schema export.
# Usage: erd_lp.py <schema.json> <groups.json> <out_dir>   (writes 1-Logical.md, 2-Physical.md, Fire3D-Physical.dbml)
import json, os, re, sys
from collections import defaultdict
sys.stdout.reconfigure(encoding='utf-8')
schema_path, groups_path, out_dir = sys.argv[1:4]
out_dbml = os.path.join(out_dir, 'Fire3D-Physical.dbml')
S = json.load(open(schema_path, encoding='utf-8'))
G = json.load(open(groups_path, encoding='utf-8'))

# ---------------------------------------------------------------- physical facts
cols = defaultdict(list)
for c in S['columns']: cols[c['t']].append(c)
cons = defaultdict(list)
for k in S['cons']: cons[k['t']].append(k)
idx = defaultdict(list)
for i in S['idx']: idx[i['t']].append(i)
TABLES = [t['t'] for t in S['tables'] if t['t'] != '__EFMigrationsHistory']
RECEIPTS = sorted(t for t in TABLES if t.endswith('_command_receipts'))
PGROUPS = list(G.items()) + [('12. Biên nhận idempotency', RECEIPTS)]
GROUP_OF = {t: gi for gi, (_, ts) in enumerate(PGROUPS) for t in ts}
assert set(GROUP_OF) == set(TABLES), set(TABLES) ^ set(GROUP_OF)

def pk_cols(t): return next((k['cols'] for k in cons[t] if k['type'] == 'p'), [])
def uniques(t): return [k['cols'] for k in cons[t] if k['type'] == 'u']
def fks(t): return [k for k in cons[t] if k['type'] == 'f']
def nullable(t, c): return not next(x for x in cols[t] if x['c'] == c)['nn']

def short_type(ty):
    ty = ty.replace('character varying', 'varchar').replace('timestamp with time zone', 'timestamptz')
    ty = re.sub(r'^character\(', 'char(', ty)
    return {'integer': 'int', 'boolean': 'bool'}.get(ty, ty)

# ---------------------------------------------------------------- physical mermaid
def phys_entity(t, lines):
    pk = set(pk_cols(t)); fkc = {c for k in fks(t) for c in k['cols']}
    uk = {u[0] for u in uniques(t) if len(u) == 1}
    lines.append(f'  {t} {{')
    for c in cols[t]:
        ty = short_type(c['type']); notes = []
        m = re.match(r'numeric\((\d+),(\d+)\)', ty)
        if m: ty = 'numeric'; notes.append(f'({m.group(1)},{m.group(2)})')
        keys = [k for k, on in (('PK', c['c'] in pk), ('FK', c['c'] in fkc), ('UK', c['c'] in uk)) if on]
        if not c['nn']: notes.append('NULL')
        lines.append(f"    {ty} {c['c']}" + (f" {', '.join(keys)}" if keys else '') + (f' "{", ".join(notes)}"' if notes else ''))
    lines.append('  }')

def phys_rel(k):
    t, p = k['t'], k['ref']
    exact_unique = any(set(u) == set(k['cols']) for u in uniques(t) + [pk_cols(t)])
    child = 'o|' if exact_unique else 'o{'
    parent = '|o' if any(nullable(t, c) for c in k['cols']) else '||'
    return f'  {p} {parent}--{child} {t} : "{", ".join(k["cols"])}"'

def phys_diagram(gi):
    own = PGROUPS[gi][1]; ownset = set(own); lines = ['```mermaid', 'erDiagram']
    rels = [k for t in own for k in fks(t)] + [k for t in TABLES if t not in ownset for k in fks(t) if k['ref'] in ownset and False]
    rels.sort(key=lambda k: (k['ref'], k['t'], k['cols']))
    lines += [phys_rel(k) for k in rels]
    for t in own: phys_entity(t, lines)
    ext = sorted({k['ref'] for k in rels} - ownset)
    for t in ext:
        lines.append(f'  {t} {{')
        for c in pk_cols(t):
            lines.append(f"    {short_type(next(x for x in cols[t] if x['c'] == c)['type'])} {c} PK \"nhóm {GROUP_OF[t] + 1}\"")
        lines.append('  }')
    lines.append('```')
    return lines, len(own), len(ext), len(rels)

# ---------------------------------------------------------------- logical model
# Each attribute: 'Type name [PK|FK|UK]'. Types are domain types, not PostgreSQL types.
L = {}  # entity -> (vi name, physical tables, attrs)
def E(name, vi, tables, attrs): L[name] = (vi, tables, attrs.split('; '))
E('Organization', 'Tổ chức khách hàng', ['organizations'], 'ID id PK; String name; String slug UK; String address; Phone phone UK; Json metadata; Bool is_active; DateTime created_at; DateTime deleted_at')
E('User', 'Người dùng', ['users'], 'ID id PK; ID organization_id FK; Email email UK; String username UK; String full_name; Enum role; Phone phone_number UK; Date dob; String gender; Url avatar; DateTime email_verified_at; Bool is_active; DateTime last_login_at; DateTime created_at; DateTime deleted_at')
E('Device', 'Thiết bị cài app', ['user_devices', 'device_installations'], 'ID id PK; ID user_id FK; String device_uuid; String device_model; String os_version; String app_version; String push_token; Bool notifications_enabled; DateTime last_seen_at; DateTime revoked_at')
E('AuthSession', 'Phiên đăng nhập', ['auth_refresh_tokens'], 'ID id PK; ID user_id FK; ID family_id; DateTime created_at; DateTime expires_at; DateTime revoked_at')
E('Building', 'Công trình', ['buildings', 'building_locations'], 'ID id PK; ID organization_id FK; ID created_by FK; String name; String building_type; Int total_floors; Enum visibility; String address; String city; String district; Decimal latitude; Decimal longitude; Bool is_active; DateTime created_at; DateTime deleted_at')
E('BuildingContact', 'Người liên hệ của công trình', ['building_contacts'], 'ID id PK; ID building_id FK; String contact_name; String contact_role; Phone phone; Email email; Bool is_primary')
E('BuildingQrCode', 'Mã QR tham gia công trình', ['building_qr_codes'], 'ID id PK; ID building_id FK; ID created_by FK; String label; Enum status; DateTime created_at; DateTime revoked_at')
E('Revision', 'Phiên bản mô hình IFC', ['revisions'], 'ID id PK; ID building_id FK; ID uploaded_by FK; String version_label; Enum status; DateTime created_at')
E('SourceDocument', 'File IFC gốc', ['source_documents'], 'ID id PK; ID revision_id FK; String original_filename; Enum file_type; Int file_size_bytes; String sha256_hash; Enum quarantine_status; String usage_rights; String source_tool; DateTime upload_verified_at')
E('ProcessingJob', 'Lượt xử lý mô hình trên VM', ['processing_jobs'], 'ID id PK; ID revision_id FK; ID source_document_id FK; ID scenario_version_id FK; Enum kind; Enum status; DateTime started_at; DateTime finished_at; Text error_message')
E('ProcessingAttempt', 'Lần chạy của một job', ['processing_job_attempts'], 'ID id PK; ID job_id FK; Int attempt_number; String toolchain_version; Enum status; DateTime started_at; DateTime finished_at; Text error_message')
E('RevisionArtifact', 'Kết quả xử lý (GLB, navmesh, tầng...)', ['revision_artifacts'], 'ID id PK; ID revision_id FK; ID job_id FK; ID attempt_id FK; Enum artifact_type; String object_key; String sha256_hash; Int size_bytes; Bool is_runtime_ready; Json metadata')
E('ValidationRun', 'Lần kiểm tra mô hình/kịch bản', ['validation_runs'], 'ID id PK; ID revision_id FK; ID job_id FK; ID scenario_version_id FK; ID annotation_set_id FK; Enum kind; Enum outcome; Json report; DateTime created_at')
E('RevisionIssue', 'Lỗi phát hiện khi kiểm tra', ['revision_issues'], 'ID id PK; ID validation_run_id FK; Enum severity; String code; String ifc_guid; Text message')
E('BimFact', 'Thuộc tính BIM trích từ IFC', ['bim_facts'], 'ID id PK; ID revision_id FK; String ifc_global_id; String entity_type; String property_path; Json value')
E('AnnotationSet', 'Bộ chú thích trên mô hình', ['annotation_sets'], 'ID id PK; ID revision_id FK; ID created_by FK; Int version_number; Json data; String provenance')
E('EquipmentDecision', 'Quyết định thiết bị PCCC', ['revision_equipment_decisions'], 'ID id PK; ID revision_id FK; ID created_by FK; Int version_number; Json data')
E('StyleSelection', 'Lựa chọn hiển thị mô hình', ['revision_style_selections'], 'ID id PK; ID revision_id FK; ID created_by FK; Int version_number; Json data')
E('RevisionReview', 'Duyệt mô hình cho huấn luyện', ['revision_reviews'], 'ID id PK; ID revision_id FK; ID scenario_version_id FK; ID validation_run_id FK; ID annotation_set_id FK; ID reviewed_by FK; Enum action; Text review_message; DateTime reviewed_at')
E('Scenario', 'Kịch bản', ['scenarios'], 'ID id PK; ID building_id FK; ID created_by FK; String name; DateTime created_at')
E('ScenarioDraft', 'Bản nháp kịch bản', ['scenario_drafts'], 'ID id PK; ID scenario_id FK; ID revision_id FK; ID created_by FK; Int draft_number; Json state; Enum source; DateTime updated_at')
E('ScenarioVersion', 'Phiên bản kịch bản (bất biến)', ['scenario_versions'], 'ID id PK; ID scenario_id FK; ID revision_id FK; ID created_by FK; Int version_number; String name; Int time_limit_seconds; Int random_seed; Json spawn_config; Json goal_config; Json fire_source_config; Json npc_config; Json scoring_config; Json learning_objectives; Json rubric; String scenario_hash; DateTime created_at')
E('ContentReview', 'Duyệt nội dung kịch bản', ['scenario_content_reviews'], 'ID id PK; ID scenario_version_id FK; ID submitted_by FK; ID reviewed_by FK; Enum status; Text reason; DateTime submitted_at; DateTime reviewed_at')
E('RuntimeVersion', 'Phiên bản app Unity được hỗ trợ', ['runtime_compatibility_catalog'], 'ID id PK; String runtime_version; String protocol_version; String manifest_schema_version; Json capabilities; Bool is_active')
E('PlaytestSession', 'Phiên chơi thử của tổ chức', ['playtest_sessions', 'playtest_runtime_state', 'playtest_package_pins'], 'ID id PK; ID scenario_version_id FK; ID scenario_draft_id FK; ID building_id FK; ID entitlement_id FK; ID created_by FK; Enum status; String runtime_version; DateTime started_at; DateTime ended_at; Json completion')
E('PlaytestEvent', 'Sự kiện trong phiên chơi thử', ['playtest_events'], 'ID playtest_id PK, FK; ID event_id PK; Int sequence; String event_type; Json payload; DateTime occurred_at')
E('Release', 'Bản phát hành', ['releases', 'release_build_provenance'], 'ID id PK; ID revision_id FK; ID scenario_version_id FK; ID confirmation_review_id FK; ID published_by FK; ID revoked_by FK; Enum status; Json safety_thresholds; DateTime published_at; DateTime revoked_at; Text revoked_reason')
E('ReleasePackage', 'Gói Android của bản phát hành', ['release_packages'], 'ID id PK; ID release_id FK; Url package_url; String checksum_sha256; Int package_size_bytes; String min_runtime_version; String build_target')
E('Training', 'Bài huấn luyện', ['trainings'], 'ID id PK; ID release_id FK; ID organization_id FK; ID created_by FK; String name; Text description; DateTime start_date; DateTime end_date; Enum status; Enum mode; Enum allowed_modes; Int max_attempts')
E('Session', 'Phiên học của học viên', ['sessions'], 'ID id PK; ID training_id FK; ID trainee_user_id FK; ID device_id FK; ID seat_id FK; ID entitlement_id FK; Enum mode; Enum status; String app_version; DateTime started_at; DateTime ended_at; String terminal_reason')
E('SessionEvent', 'Sự kiện trong phiên học', ['session_events'], 'ID id PK; ID session_id FK; Int sequence_number; String event_type; Json event_data; Int elapsed_ms; DateTime recorded_at')
E('SessionResult', 'Kết quả chấm điểm', ['session_results'], 'ID id PK; ID session_id FK; Decimal score; Int time_taken_seconds; Int wrong_exits; Decimal hazard_exposure_score; Decimal total_distance_meters; Bool reached_exit; Enum outcome; Json criterion_results; Json metrics')
E('LearnerSeat', 'Suất học viên của dịch vụ', ['billing_learner_seats'], 'ID id PK; ID entitlement_id FK; ID trainee_id FK; ID first_session_id; DateTime allocated_at')
E('ServicePackage', 'Gói dịch vụ', ['service_packages'], 'ID id PK; ID ai_policy_version_id FK; String code UK; String name; Text description; Money unit_price; String currency; Int duration_months; Int learner_limit; Int ai_quota_units; Json features; Bool is_active')
E('DiscountRule', 'Quy tắc giảm giá', ['service_package_discount_rules'], 'ID id PK; ID service_package_id FK; String code UK; Enum discount_kind; Decimal discount_value; Int minimum_buildings; Int minimum_duration_months; DateTime valid_from; DateTime valid_until; Bool is_active')
E('QuotaPolicyVersion', 'Chính sách credit AI', ['billing_quota_policy_versions'], 'ID id PK; Enum audience; Enum policy_kind; String quota_unit; Enum rollover; DateTime effective_from; DateTime effective_until')
E('Quotation', 'Báo giá', ['quotations'], 'ID id PK; ID organization_id FK; ID requested_by FK; ID issued_by FK; ID discount_rule_id FK; String quotation_number UK; Enum status; Enum billing_purpose; Money subtotal_amount; Money discount_amount; Money tax_amount; Money total_amount; String currency; DateTime valid_until; DateTime issued_at; DateTime accepted_at')
E('QuotationBuildingItem', 'Dòng báo giá cho một công trình', ['quotation_building_items'], 'ID id PK; ID quotation_id FK; ID building_id FK; ID service_package_id FK; ID upgrade_entitlement_id FK; Enum purchase_action; Int service_duration_months; Money unit_price; Money discount_amount; Money total_amount; Int learner_limit; Int ai_quota_units; DateTime starts_at; DateTime ends_at')
E('QuotationTopupItem', 'Dòng báo giá mua thêm credit AI', ['quotation_topup_items'], 'ID id PK; ID quotation_id FK; ID policy_version_id FK; String quota_unit; Int quota_units; Money amount; DateTime starts_at; DateTime ends_at')
E('PaymentRequest', 'Yêu cầu thanh toán PayOS', ['payos_payment_requests'], 'ID id PK; ID quotation_id FK; ID requested_by FK; Int order_code UK; Money expected_amount; String expected_currency; Url checkout_url; Enum status; DateTime expires_at; DateTime paid_at')
E('PaymentTransaction', 'Giao dịch tiền đã nhận', ['payment_transactions'], 'ID id PK; ID payment_request_id FK; String provider_transaction_id UK; Money received_amount; String received_currency; Bool signature_verified; Enum status; Text rejection_reason; DateTime received_at')
E('ServiceEntitlement', 'Quyền dùng dịch vụ của công trình', ['service_entitlements'], 'ID id PK; ID building_id FK; ID service_package_id FK; ID quotation_item_id FK; ID payment_transaction_id FK; Enum status; DateTime starts_at; DateTime ends_at; Int learner_limit; Int playtest_units_granted; Int playtest_units_used')
E('EntitlementUpgrade', 'Nâng cấp dịch vụ', ['billing_entitlement_upgrades'], 'ID id PK; ID entitlement_id FK; ID quotation_item_id FK; ID payment_transaction_id FK; Int capacity_revision; Int previous_learner_limit; Int learner_limit; Int additional_quota_units; DateTime effective_from')
E('AiQuotaGrant', 'Lô credit AI được cấp', ['billing_ai_quota_grants'], 'ID id PK; ID organization_id FK; ID policy_version_id FK; ID payment_transaction_id FK; ID entitlement_id FK; ID topup_item_id FK; ID upgrade_id FK; Enum source_kind; String quota_unit; Int quota_units; DateTime starts_at; DateTime ends_at')
E('AiQuotaAllocation', 'Credit giữ/trừ cho một yêu cầu AI', ['billing_ai_quota_allocations'], 'ID id PK; ID grant_id FK; ID ai_request_id FK; Int reserved_units; Int consumed_units; Enum status; DateTime settled_at')
E('EnterpriseQuoteRequest', 'Yêu cầu báo giá doanh nghiệp', ['enterprise_quote_requests'], 'ID id PK; ID organization_id FK; ID requested_by FK; ID assigned_to FK; ID quotation_id FK; Int requested_building_count; Int requested_duration_months; String contact_name; Email contact_email; Phone contact_phone; Text notes; Enum status; DateTime closed_at')
E('EnterpriseQuoteResponse', 'Phản hồi cho yêu cầu báo giá', ['enterprise_quote_responses'], 'ID id PK; ID request_id FK; ID author_id FK; Text message; DateTime created_at')
E('AiOperationPolicy', 'Chính sách cho từng loại thao tác AI', ['ai_operation_policies'], 'ID id PK; Enum operation; String quota_unit; Int reserve_units; Int daily_units; Int max_input_chars; Int max_sources; DateTime effective_from; DateTime effective_until')
E('AiRequest', 'Yêu cầu gửi AI', ['ai_requests'], 'ID id PK; ID organization_id FK; ID actor_user_id FK; ID policy_id FK; Enum operation; Enum audience; Enum status; Json input; Json result; Int reserved_units; Int consumed_units; String model_version; DateTime created_at; DateTime completed_at')
E('KnowledgeSource', 'Nguồn tri thức (quy chuẩn, tài liệu)', ['knowledge_sources'], 'ID id PK; ID organization_id FK; ID approved_by FK; String title; Url source_uri; String version_label; Enum visibility; String jurisdiction; Enum approval_status; DateTime effective_from; DateTime effective_until')
E('KnowledgeChunk', 'Đoạn tri thức đã nhúng vector', ['knowledge_chunks'], 'ID id PK; ID source_id FK; Int chunk_index; Text content; Json locator; Vector embedding')
E('LearnSituation', 'Tình huống học (chủ đề)', ['learn_situations'], 'ID id PK; String slug UK; String name; Text description; Bool is_active')
E('LearnPost', 'Bài viết Learn', ['learn_posts'], 'ID id PK; ID published_version_id FK; ID created_by FK; String slug UK; Enum publication_status')
E('LearnPostVersion', 'Phiên bản bài viết', ['learn_post_versions'], 'ID id PK; ID post_id FK; ID created_by FK; ID published_by FK; Int version_number; String title; Text summary; Enum content_kind; Url cover_image_url; Json content_blocks; Enum status; DateTime published_at')
E('LibraryItem', 'Mục thư viện dùng chung', ['organization_library_items'], 'ID id PK; ID created_by FK; Enum kind; String code UK; Bool is_active')
E('LibraryVersion', 'Phiên bản mục thư viện', ['organization_library_versions'], 'ID id PK; ID item_id FK; ID published_by FK; Int version_number; String name; Json payload; Json required_capabilities; Enum status; DateTime published_at')
E('Feedback', 'Góp ý', ['feedback'], 'ID id PK; ID submitted_by FK; ID organization_id FK; ID session_id FK; ID reviewed_by FK; String category; Int rating; Text message; Enum status; DateTime reviewed_at')
E('SupportTicket', 'Phiếu hỗ trợ', ['support_tickets'], 'ID id PK; ID created_by FK; ID organization_id FK; ID session_id FK; ID feedback_id FK; ID assigned_to FK; String ticket_number UK; String subject; Text description; Enum priority; Enum status; DateTime resolved_at')
E('TicketMessage', 'Tin nhắn trong phiếu hỗ trợ', ['support_ticket_messages'], 'ID id PK; ID ticket_id FK; ID author_id FK; Text message; DateTime created_at')
E('Notification', 'Thông báo cho tổ chức', ['organization_notifications'], 'ID id PK; ID organization_id FK; ID recipient_user_id FK; ID building_id FK; ID entitlement_id FK; Enum notification_type; String title; Text body; DateTime read_at; DateTime created_at')
E('NotificationDelivery', 'Lần gửi thông báo qua một kênh', ['notification_deliveries'], 'ID id PK; ID notification_id FK; Enum channel; Enum status; DateTime sent_at')
E('AuditLog', 'Nhật ký thao tác', ['audit_logs'], 'ID id PK; ID user_id FK; ID organization_id FK; Enum actor_type; Enum action; String target_entity; ID target_id; Json old_values; Json new_values; String ip_address; DateTime created_at')
E('AnalyticsExport', 'Lần xuất báo cáo', ['analytics_exports'], 'ID id PK; ID actor_id FK; ID organization_id FK; String report; Json filters; Int row_count; DateTime created_at')

# Many-to-many relationships in the logical model and the junction table that resolves each one physically.
MN = [('User', 'Building', 'được tham gia', 'building_participation_grants'),
      ('LearnPostVersion', 'LearnSituation', 'gắn tình huống', 'learn_post_version_situations'),
      ('LearnPostVersion', 'KnowledgeSource', 'trích nguồn', 'learn_post_version_sources'),
      ('User', 'LearnPost', 'lưu bookmark', 'learn_bookmarks')]

# Logical domains: (title, intro, own entities, relationships 'A card B : label').
D = []
def DOM(title, intro, ents, rels): D.append((title, intro, ents.split(), [r.strip() for r in rels.strip().split('\n')]))
DOM('Tổ chức, người dùng & công trình', 'Ai dùng hệ thống, thuộc tổ chức nào, và tổ chức có những công trình nào. Học viên (Trainee) không thuộc tổ chức; họ được **tham gia** công trình qua mã QR, đó là quan hệ nhiều-nhiều.',
    'Organization User Device AuthSession Building BuildingContact BuildingQrCode', '''
    Organization |o--o{ User : "có thành viên"
    Organization ||--o{ Building : "sở hữu"
    User ||--o{ Building : "tạo"
    User ||--o{ Device : "cài app trên"
    User ||--o{ AuthSession : "đăng nhập"
    Building ||--o{ BuildingContact : "có người liên hệ"
    Building ||--o{ BuildingQrCode : "phát mã QR"
    User }o--o{ Building : "được tham gia"''')
DOM('Mô hình IFC & xử lý', 'Mỗi công trình có nhiều phiên bản mô hình IFC. Một phiên bản được xử lý trên VM thành các kết quả (GLB, navmesh, danh sách tầng), được kiểm tra, rồi được duyệt cho huấn luyện.',
    'Revision SourceDocument ProcessingJob ProcessingAttempt RevisionArtifact ValidationRun RevisionIssue BimFact AnnotationSet EquipmentDecision StyleSelection RevisionReview', '''
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
    User ||--o{ RevisionReview : "duyệt"''')
DOM('Kịch bản & chơi thử', 'Kịch bản gắn với một công trình. Người soạn sửa bản nháp nhiều lần, rồi chốt thành **phiên bản bất biến**. Tổ chức chơi thử phiên bản đó trước khi phát hành.',
    'Scenario ScenarioDraft ScenarioVersion ContentReview RuntimeVersion PlaytestSession PlaytestEvent', '''
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
    PlaytestSession ||--o{ PlaytestEvent : "ghi sự kiện"''')
DOM('Phát hành, huấn luyện & phiên học', 'Phiên bản kịch bản đã duyệt được **phát hành** thành gói Android. Tổ chức tạo **bài huấn luyện** từ bản phát hành; học viên vào bài, mỗi lần chơi là một **phiên**, kết thúc thì được chấm điểm. Mỗi học viên chiếm một **suất** của dịch vụ công trình.',
    'Release ReleasePackage Training Session SessionEvent SessionResult LearnerSeat', '''
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
    LearnerSeat |o--o{ Session : "được dùng cho"''')
DOM('Báo giá, thanh toán & dịch vụ', 'Tổ chức nhận **báo giá** (mỗi dòng là một công trình hoặc một lần mua thêm credit AI), trả tiền qua **PayOS**. Tiền về thì sinh ra **quyền dùng dịch vụ** cho công trình và **credit AI** cho tổ chức.',
    'ServicePackage DiscountRule QuotaPolicyVersion Quotation QuotationBuildingItem QuotationTopupItem PaymentRequest PaymentTransaction ServiceEntitlement EntitlementUpgrade AiQuotaGrant AiQuotaAllocation EnterpriseQuoteRequest EnterpriseQuoteResponse', '''
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
    EnterpriseQuoteRequest }o--o| Quotation : "dẫn tới"''')
DOM('AI & kho tri thức', 'Mỗi yêu cầu AI theo một **chính sách thao tác** và giữ trước credit từ các lô credit của tổ chức. Câu trả lời dựa trên **kho tri thức** (quy chuẩn PCCC) đã cắt đoạn và nhúng vector.',
    'AiOperationPolicy AiRequest KnowledgeSource KnowledgeChunk', '''
    AiOperationPolicy ||--o{ AiRequest : "áp cho"
    User ||--o{ AiRequest : "hỏi"
    Organization |o--o{ AiRequest : "trả credit"
    AiRequest ||--o{ AiQuotaAllocation : "giữ credit"
    Organization |o--o{ KnowledgeSource : "sở hữu"
    User |o--o{ KnowledgeSource : "duyệt"
    KnowledgeSource ||--o{ KnowledgeChunk : "được cắt thành"''')
DOM('Learn & thư viện', 'Bài viết Learn có nhiều phiên bản; một phiên bản gắn nhiều **tình huống** và trích nhiều **nguồn tri thức** (nhiều-nhiều). Học viên **lưu bookmark** bài viết. Thư viện dùng chung cũng quản lý theo phiên bản.',
    'LearnSituation LearnPost LearnPostVersion LibraryItem LibraryVersion', '''
    LearnPost ||--o{ LearnPostVersion : "có phiên bản"
    LearnPost |o--o| LearnPostVersion : "đang xuất bản"
    User ||--o{ LearnPostVersion : "viết"
    LearnPostVersion }o--o{ LearnSituation : "gắn tình huống"
    LearnPostVersion }o--o{ KnowledgeSource : "trích nguồn"
    User }o--o{ LearnPost : "lưu bookmark"
    LibraryItem ||--o{ LibraryVersion : "có phiên bản"
    User ||--o{ LibraryItem : "tạo"''')
DOM('Hỗ trợ, thông báo & audit', 'Góp ý và phiếu hỗ trợ (có thể gắn với một phiên học), thông báo nhắc hạn dịch vụ gửi qua nhiều kênh, và nhật ký thao tác.',
    'Feedback SupportTicket TicketMessage Notification NotificationDelivery AuditLog AnalyticsExport', '''
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
    User ||--o{ AnalyticsExport : "xuất"''')

DOMAIN_OF = {e: i for i, (_, _, es, _) in enumerate(D) for e in es}
assert set(DOMAIN_OF) == set(L), set(L) ^ set(DOMAIN_OF)

EXCLUDED = [
    ('Mã/OTP tạm thời và hàng đợi gửi email', ['auth_google_onboarding_sessions', 'registration_email_challenges', 'registration_otp_email_jobs', 'local_password_reset_tokens', 'password_reset_email_jobs', 'email_verification_tokens', 'email_verification_jobs']),
    ('Phiên tải file và dọn object trên S3', ['avatar_upload_intents', 'avatar_object_cleanups', 'ifc_upload_intents', 'ifc_upload_attempts', 'ifc_object_cleanup', 'learn_media_images', 'knowledge_source_files']),
    ('Outbox, giao job qua Redis/HTTP, kết quả tạm của worker', ['integration_outbox_events', 'integration_event_consumptions', 'processing_delivery_receipts', 'processing_stream_deliveries', 'processing_stream_state', 'processing_stream_rejections', 'processing_stream_retry_receipts', 'processing_candidate_outputs']),
    ('Bước chuẩn bị trước khi vào phiên', ['training_session_preparations', 'playtest_handoffs']),
    ('Quy trình thanh toán nhiều bước (checkout, giữ chỗ, webhook, cấp quyền)', ['billing_checkout_operations', 'billing_service_reservations', 'billing_upgrade_reservations', 'payos_webhook_inbox', 'payment_provisioning_records']),
    ('Biên nhận chống gửi lặp (Idempotency-Key)', RECEIPTS),
]
mapped = {t for _, ts, _ in L.values() for t in ts} | {m[3] for m in MN}
excluded = {t for _, ts in EXCLUDED for t in ts}
assert mapped.isdisjoint(excluded) and mapped | excluded == set(TABLES), set(TABLES) ^ (mapped | excluded)

def log_entity(e, lines, ref_only=False):
    vi, _, attrs = L[e]
    lines.append(f'  {e} {{')
    if ref_only:
        lines.append(f'    ID id PK "mục A{DOMAIN_OF[e] + 1}"')
    else:
        for a in attrs:
            ty, name, *keys = a.split(' ', 2)
            lines.append(f'    {ty} {name}' + (f' {keys[0]}' if keys else ''))
    lines.append('  }')

def log_diagram(di):
    _, _, ents, rels = D[di]
    lines = ['```mermaid', 'erDiagram'] + ['  ' + r for r in rels]
    used = {w for r in rels for w in (r.split()[0], r.split()[2])}
    for e in ents: log_entity(e, lines)
    for e in sorted(used - set(ents)): log_entity(e, lines, ref_only=True)
    lines.append('```')
    return lines

# ---------------------------------------------------------------- markdown
out = []
def emit(*xs): out.extend(xs)
n_fk = sum(len(fks(t)) for t in TABLES)
n_cols = sum(len(cols[t]) for t in TABLES)
emit('# Fire3D — Mô hình dữ liệu Logical & Physical', '',
     f'Sinh từ schema PostgreSQL thật trên production (Supabase Singapore, đối chiếu ngày 27/10/2026, 136 migration; đã bỏ trước bảng `revision_processing_logs` và 2 enum của nó, xóa ở đợt dọn dẹp cùng ngày). '
     f'**Logical:** {len(L)} thực thể, {len(MN)} quan hệ nhiều-nhiều. '
     f'**Physical:** {len(TABLES)} bảng, {n_cols} cột, {n_fk} khóa ngoại, {len(S["enums"])} kiểu enum '
     f'(chưa tính bảng hệ thống `__EFMigrationsHistory` của EF Core).', '')
HEAD_LEN = len(out)

emit('## Ký hiệu bản số', '', 'Mọi sơ đồ dùng ký hiệu chân chim (crow\'s foot) của Mermaid:', '',
     '| Ký hiệu | Nghĩa |', '|---|---|',
     '| `\\|\\|--o{` | Một – nhiều (bên một bắt buộc, bên nhiều có thể 0) |',
     '| `\\|o--o{` | Không/một – nhiều (khóa ngoại cho phép NULL) |',
     '| `\\|\\|--o\\|` | Một – không/một (quan hệ 1:1, phía con có ràng buộc UNIQUE) |',
     '| `\\|\\|--\\|\\|` | Một – đúng một |',
     '| `}o--o{` | Nhiều – nhiều (chỉ có ở logical; physical tách thành bảng trung gian) |', '')

emit('## Logical khác Physical ở đâu', '',
     '| | Logical (phần A) | Physical (phần B) |', '|---|---|---|',
     '| Mục đích | Mô tả **nghiệp vụ**: có những đối tượng nào và chúng liên quan ra sao | Mô tả **cách lưu thật** trong PostgreSQL |',
     f'| Phạm vi | {len(L)} thực thể nghiệp vụ; bỏ các bảng kỹ thuật (hàng đợi, outbox, biên nhận, giữ chỗ...) | Đủ {len(TABLES)} bảng |',
     '| Tên | Thực thể dạng `PascalCase` (`ServiceEntitlement`) | Bảng dạng `snake_case` số nhiều (`service_entitlements`) |',
     '| Kiểu dữ liệu | Kiểu miền: `ID`, `String`, `Money`, `DateTime`, `Enum`, `Json`... | Kiểu PostgreSQL: `uuid`, `varchar(64)`, `numeric(14,2)`, `timestamptz`, enum riêng, `jsonb`, `vector` |',
     '| Nhiều – nhiều | Vẽ thẳng `}o--o{` | Tách thành bảng trung gian có khóa chính ghép (xem dưới) |',
     '| Quan hệ 1:1 phụ | Gộp vào thực thể chính (vị trí công trình nằm trong `Building`) | Bảng riêng, khóa ngoại có UNIQUE (`building_locations.building_id`) |',
     '| Cột kỹ thuật | Bỏ: hash token, lease, `revision`/ETag, idempotency key, snapshot giá | Có đủ |',
     '| Khóa ngoại | Chỉ khóa ngoại nghiệp vụ, mỗi quan hệ một khóa | Nhiều khóa ngoại **ghép** mang theo `organization_id` để database tự chặn dữ liệu chéo tổ chức (ví dụ `scenario_versions(scenario_id, building_id, organization_id)`) |', '',
     '**Quan hệ nhiều-nhiều và bảng trung gian tương ứng:**', '',
     '| Logical | Bảng trung gian (physical) | Khóa chính |', '|---|---|---|')
for a, b, lab, jt in MN:
    emit(f'| `{a}` }}o--o{{ `{b}` ({lab}) | `{jt}` | ({", ".join(pk_cols(jt))}) |')
emit('')

emit('## Phần A — Mô hình logical', '',
     '### A0. Tổng quan', '',
     'Chỉ các thực thể trên trục chính, chưa có thuộc tính. Dùng làm trang đầu của phần logical.', '',
     '```mermaid', 'erDiagram')
OVERVIEW = '''Organization |o--o{ User : "có thành viên"
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
User ||--o{ AiRequest : "hỏi"'''
emit(*['  ' + r for r in OVERVIEW.split('\n')], '```', '')

for i, (title, intro, ents, rels) in enumerate(D):
    emit(f'### A{i + 1}. {title}', '', intro, '')
    emit(*log_diagram(i))
    ext = sorted({w for r in rels for w in (r.split()[0], r.split()[2])} - set(ents))
    note = f'*{len(ents)} thực thể, {len(rels)} quan hệ.'
    if ext: note += ' Thực thể chỉ có `id`: ' + ', '.join(f'`{e}`' for e in ext) + ' (vẽ đầy đủ ở mục khác).'
    emit(note + '*', '')

emit('### Từ điển thực thể', '', 'Cột "Bảng physical" cho biết thực thể logical được lưu ở bảng nào. Thực thể có hai bảng trở lên là chỗ physical tách quan hệ 1:1 ra bảng riêng.', '',
     '| Mục | Thực thể | Nghĩa | Bảng physical |', '|---|---|---|---|')
for i, (_, _, ents, _) in enumerate(D):
    for e in ents:
        vi, ts, _ = L[e]
        emit(f'| A{i + 1} | `{e}` | {vi} | ' + '<br>'.join(f'`{t}`' for t in ts) + ' |')
emit('')
emit('### Bảng không đưa vào logical', '',
     f'{len(excluded)} bảng dưới đây có trong physical nhưng không phải đối tượng nghiệp vụ: chúng phục vụ chống gửi lặp, hàng đợi worker, hoặc các bước trung gian. Vẽ logical thì bỏ; vẽ physical thì có (phần B).', '',
     '| Loại | Bảng |', '|---|---|')
for why, ts in EXCLUDED: emit(f'| {why} | ' + ', '.join(f'`{t}`' for t in ts) + ' |')
emit('')

emit('## Phần B — Mô hình physical', '',
     '### Quy ước', '',
     '- Mỗi cột ghi `kiểu tên khóa "ghi chú"`. Khóa: `PK` khóa chính, `FK` khóa ngoại, `UK` UNIQUE một cột. Ghi chú `NULL` là cột cho phép NULL; cột không ghi là **NOT NULL**. `numeric` ghi độ chính xác trong ghi chú, ví dụ `"(14,2)"`.',
     '- Viết tắt kiểu: `timestamptz` = `timestamp with time zone`, `varchar(n)` = `character varying(n)`, `int` = `integer`, `bool` = `boolean`.',
     '- Nhãn trên đường nối là **cột khóa ngoại** ở bảng con. Bản số suy ra từ schema: khóa ngoại NULL được thì phía cha là `|o`; khóa ngoại trùng một UNIQUE thì phía con là `o|` (1:1).',
     '- Bảng thuộc nhóm khác chỉ vẽ cột khóa chính, ghi chú số nhóm. Ký hiệu bản số giải thích ở `1-Logical.md`.',
     '- UNIQUE nhiều cột, index một phần (có `WHERE`) và CHECK có đủ trong `Fire3D-Physical.dbml`.', '',
     '### Kiểu enum', '', '| Enum | Giá trị |', '|---|---|')
for e in sorted(S['enums'], key=lambda e: e['name']): emit(f"| `{e['name']}` | {', '.join(e['vals'])} |")
emit('')
DEL = {'c': 'CASCADE', 'n': 'SET NULL', 'r': 'RESTRICT', 'a': 'NO ACTION'}
for gi, (title, ts) in enumerate(PGROUPS):
    num, name = title.split('. ', 1)
    emit(f'### B{num}. {name}', '')
    lines, n_own, n_ext, n_rel = phys_diagram(gi)
    emit(*lines)
    emit(f'*{n_own} bảng, {n_rel} khóa ngoại' + (f', {n_ext} bảng ở nhóm khác.*' if n_ext else '.*'), '')
    comp = [(t, u) for t in ts for u in uniques(t) if len(u) > 1]
    casc = [(k['t'], k['ref'], k['del']) for t in ts for k in fks(t) if k['del'] in 'cn']
    if comp: emit('- **UNIQUE nhiều cột:** ' + '; '.join(f'`{t}({", ".join(u)})`' for t, u in comp))
    if casc: emit('- **Xóa dây chuyền:** ' + '; '.join(f'`{t}` → `{r}` ON DELETE {DEL[d]}' for t, r, d in casc))
    if comp or casc: emit('')
emit('### Bảng hệ thống', '', '`__EFMigrationsHistory(MigrationId varchar(150) PK, ProductVersion varchar(32))`: EF Core ghi migration đã áp. Không vẽ vào ERD.', '')
def slug(h): return re.sub(r'[^\w\- ]', '', h.lower()).replace(' ', '-')
def toc(body):
    return ['## Mục lục', ''] + [f"- [{l[3:]}](#{slug(l[3:])})" for l in body if l.startswith('## ')] + ['']
def flatten(body, drop):
    return ['## ' + l[4:] if l.startswith('### ') else l for l in body if l != drop]
cut = out.index('## Phần B — Mô hình physical')
logical = flatten(out[HEAD_LEN:cut], '## Phần A — Mô hình logical')
logical = [l.replace('(phần A)', '(file này)').replace('(phần B)', '(`2-Physical.md`)') for l in logical]
physical = flatten(out[cut:], '## Phần B — Mô hình physical')
def write(name, title, body):
    text = [title, '', '> Bắt đầu từ [0-Ke-hoach-ve.md](0-Ke-hoach-ve.md): danh sách hình cần vẽ, các bước và checklist.', ''] + out[2:HEAD_LEN] + toc(body) + body
    open(os.path.join(out_dir, name), 'w', encoding='utf-8', newline='\n').write('\n'.join(text))
write('1-Logical.md', '# Fire3D — Mô hình dữ liệu Logical', logical)
write('2-Physical.md', '# Fire3D — Mô hình dữ liệu Physical', physical)

# ---------------------------------------------------------------- DBML
def q(s): return "'''" + s.replace('\\', '\\\\') + "'''"
def dbml_type(ty):
    ty = ty.replace('character varying', 'varchar').replace('timestamp with time zone', 'timestamptz')
    ty = re.sub(r'^character\(', 'char(', ty)
    return f'"{ty}"' if re.search(r'[\[\] ]', ty) else ty
def dbml_default(expr):
    if re.fullmatch(r'-?\d+(\.\d+)?|true|false', expr): return expr
    m = re.fullmatch(r"'([^']*)'::(text|character varying)", expr)
    if m: return "'" + m.group(1) + "'"
    return '`' + expr + '`'
import unicodedata
def ascii_slug(name, sep):
    plain = unicodedata.normalize('NFD', name.replace('đ', 'd').replace('Đ', 'D'))
    plain = ''.join(ch for ch in plain if not unicodedata.combining(ch))
    return re.sub(r'[^A-Za-z0-9]+', sep, plain).strip(sep).lower()
SIMPLE_IDX = re.compile(r'CREATE (UNIQUE )?INDEX (\S+) ON \S+ USING (\w+) \(([^()]*)\)$')
db = ['// Fire3D physical model, generated from the production PostgreSQL schema (Supabase Singapore, checked 2026-10-27, 136 migrations; revision_processing_logs and its two enums already left out, dropped by the same-day cleanup).',
      '// Paste into https://dbdiagram.io . Tables are grouped like 2-Physical.md (B1-B12).', '',
      "Project fire3d {\n  database_type: 'PostgreSQL'\n}", '']
for e in sorted(S['enums'], key=lambda e: e['name']):
    db.append(f"Enum {e['name']} {{"); db += [f'  "{v}"' for v in e['vals']]; db += ['}', '']
tblock = {}
for t in TABLES:
    db, outer = [], db
    pk = pk_cols(t); singles = {u[0] for u in uniques(t) if len(u) == 1}
    checks = defaultdict(list); tnotes = []
    for k in cons[t]:
        if k['type'] == 'c':
            (checks[k['cols'][0]] if k['cols'] and len(k['cols']) == 1 else tnotes).append(k['def'])
        elif k['type'] == 'x': tnotes.append(k['name'] + ': ' + k['def'])
    db.append(f'Table {t} {{')
    for c in cols[t]:
        st = []
        if len(pk) == 1 and c['c'] == pk[0]: st.append('pk')
        elif c['nn']: st.append('not null')
        if c['c'] in singles: st.append('unique')
        if c['def']: st.append('default: ' + dbml_default(c['def']))
        if checks.get(c['c']): st.append('note: ' + q('; '.join(checks[c['c']])))
        db.append(f"  \"{c['c']}\" {dbml_type(c['type'])}" + (f" [{', '.join(st)}]" if st else ''))
    ilines = []
    if len(pk) > 1: ilines.append(f"    ({', '.join(pk)}) [pk]")
    for u in uniques(t):
        if len(u) > 1: ilines.append(f"    ({', '.join(u)}) [unique]")
    cname = {k['name'] for k in cons[t]}
    for i in idx[t]:
        if i['pk'] or i['name'] in cname: continue
        m = SIMPLE_IDX.match(i['def'])
        parts = [p.strip() for p in m.group(4).split(',')] if m else []
        if m and all(re.fullmatch(r'"?\w+"?', p) for p in parts):
            st = (['unique'] if i['uniq'] else []) + [f"name: '{i['name']}'"] + ([f"type: {m.group(3)}"] if m.group(3) in ('hash',) else [])
            ilines.append(f"    ({', '.join(parts)}) [{', '.join(st)}]")
        else:
            tnotes.append(i['def'].replace(' ON public.', ' ON '))
    if ilines: db += ['', '  indexes {'] + ilines + ['  }']
    if tnotes: db += ['', '  Note: ' + q('\n'.join(tnotes))]
    db += ['}', '']
    tblock[t], db = db, outer
    db += tblock[t]
def ref_line(k):
    d = {'c': 'cascade', 'n': 'set null', 'r': 'restrict', 'a': 'no action'}[k['del']]
    lhs = f"{k['t']}.{k['cols'][0]}" if len(k['cols']) == 1 else f"{k['t']}.({', '.join(k['cols'])})"
    rhs = f"{k['ref']}.{k['refcols'][0]}" if len(k['refcols']) == 1 else f"{k['ref']}.({', '.join(k['refcols'])})"
    return f"Ref {k['name']}: {lhs} > {rhs} [delete: {d}]"
for t in TABLES:
    for k in fks(t):
        db.append(ref_line(k))
db.append('')
for gi, (title, ts) in enumerate(PGROUPS):
    num, name = title.split('. ', 1)
    gname = 'B' + num.zfill(2) + '_' + ascii_slug(name, '_')
    db += [f'TableGroup {gname} {{'] + [f'  {t}' for t in ts] + ['}', '']
open(out_dbml, 'w', encoding='utf-8', newline='\n').write('\n'.join(db))

# One DBML per group: its own tables in full, tables of other groups reduced to the key columns its foreign keys use.
group_dir = os.path.join(out_dir, 'dbml-theo-nhom'); os.makedirs(group_dir, exist_ok=True)
for gi, (title, ts) in enumerate(PGROUPS):
    num, name = title.split('. ', 1)
    rels = [k for t in ts for k in fks(t)]
    ext = defaultdict(list)
    for k in rels:
        if k['ref'] not in ts:
            for c in pk_cols(k['ref']) + k['refcols']:
                if c not in ext[k['ref']]: ext[k['ref']].append(c)
    def coltype(t, c): return next(x['type'] for x in cols[t] if x['c'] == c)
    used = {c['type'] for t in ts for c in cols[t]} | {coltype(t, c) for t, cs in ext.items() for c in cs}
    g = [f'// Fire3D physical model, group B{num}.',
         '// Paste into https://dbdiagram.io . Gray tables belong to other groups and only show the columns referenced here.', '']
    for e in sorted(S['enums'], key=lambda e: e['name']):
        if e['name'] in used: g += [f"Enum {e['name']} {{"] + [f'  "{v}"' for v in e['vals']] + ['}', '']
    for t in ts: g += tblock[t]
    for t, cs in sorted(ext.items()):
        pk = pk_cols(t)
        g.append(f"Table {t} [headercolor: #9E9E9E, note: 'nhóm B{GROUP_OF[t] + 1}'] {{")
        g += [f'  "{c}" {dbml_type(coltype(t, c))}' + (' [pk]' if pk == [c] else '') for c in cs]
        g += ['}', '']
    g += [ref_line(k) for k in rels] + ['']
    fname = 'B' + num.zfill(2) + '-' + ascii_slug(name, '-') + '.dbml'
    open(os.path.join(group_dir, fname), 'w', encoding='utf-8', newline='\n').write('\n'.join(g))
print('md lines', len(out), 'dbml lines', len(db), 'entities', len(L), 'tables', len(TABLES))
