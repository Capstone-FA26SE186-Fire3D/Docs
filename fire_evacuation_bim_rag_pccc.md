# Thiết Kế RAG Python Hỗ Trợ Gợi Ý Thiết Bị PCCC Từ BIM

## 1. Mục tiêu và ranh giới an toàn

Mô-đun hỗ trợ người dùng và chuyên gia được ủy quyền **xem xét** các không gian/đối tượng BIM có thể cần đánh giá thêm về thiết bị PCCC. Nó kết hợp tài liệu đã phê duyệt, facts trích xuất từ IFC, rule kiểm tra minh bạch và RAG bằng Python.

Đầu ra được tách thành `KnowledgeAnswer` hoặc `ScenarioDraft`. `KnowledgeAnswer` trả lời kiến thức cho `Trainee`/`OrganizationUser` với citation nguồn chung đã duyệt; chỉ `ScenarioDraft` mới mang trạng thái `NeedsUserEdit`. Không đầu ra nào là thiết kế thi công, kết luận tuân thủ, chứng nhận hay phê duyệt PCCC. Hệ thống không tự sửa IFC, editor, route, scoring, runtime state, không tự publish release và không đưa ra hướng dẫn ứng phó cháy thực tế.

> Đây là capability nghiên cứu/authoring tách biệt với training. Nó không thay đổi ý nghĩa `ConfirmForTraining`.

## 2. Hai nhóm người dùng và ranh giới quyền

Trợ lý cho `OrganizationUser` có thể trả lời: “Không gian nào có thuộc tính BIM còn thiếu để chuyên gia xem xét trang bị PCCC?”, “Tài liệu nguồn nào liên quan đến `IfcSpace` này?” hoặc tạo **bản nháp kịch bản** để người dùng chỉnh trong editor web. Bản nháp không tự sửa editor, IFC, scenario đã phát hành hoặc quyền dịch vụ.

Trợ lý cho `Trainee` chỉ hỏi đáp kiến thức PCCC, giải thích bài học và kết quả cá nhân ngoài gameplay. Trainee không được truy cập tài liệu nội bộ của organization chỉ vì đã quét QR; nguồn được phép là kho kiến thức chung đã duyệt và dữ liệu cá nhân được cấp quyền.

Hệ thống phải từ chối/chuyển chuyên gia các yêu cầu: xác nhận tòa nhà đạt chuẩn, tự động quyết định số lượng/vị trí lắp đặt cuối cùng, chỉ đường thoát khi có sự cố thật, hoặc tự bịa phòng/vị trí/thiết bị khi IFC thiếu facts. Khi không có nguồn phù hợp, phải nói rõ giới hạn thay vì trả lời có vẻ chắc chắn.

## 3. Dữ liệu đầu vào

### BIM

IFC là đầu vào model tự động duy nhất. Python extractor tạo facts quan sát được: `IfcBuildingStorey`, `IfcSpace`, `IfcDoor`, `IfcStair`, exit đã mapping, containment, hình học tính được, thuộc tính sử dụng và cờ chất lượng. Không được suy đoán semantic còn thiếu.

```json
{
  "fact_id": "bimfact_...",
  "revision_id": "...",
  "ifc_global_id": "...",
  "entity_type": "IfcSpace",
  "property_path": "Pset_SpaceCommon.OccupancyType",
  "value": "...",
  "source_hash": "sha256:...",
  "quality_flags": ["missing_exit_mapping"]
}
```

### Kho tri thức

Chỉ ingest tài liệu đã được phê duyệt trong đúng scope: kho `Common` do PlatformAdmin/owner được ủy quyền quản lý và kho `Organization` do tổ chức quản lý. Mỗi tài liệu phải có owner, phạm vi áp dụng, jurisdiction, version, ngày hiệu lực/rà soát, hash và locator trích dẫn. RAG không tự quyết định quy chuẩn nào áp dụng; người có quyền cấu hình corpus theo dự án.

## 4. Kiến trúc Python

```text
IFC revision -> IFC worker -> BIM fact store + quality flags
Approved documents -> parser/OCR -> chunker -> Supabase PostgreSQL + pgvector
`.NET API` identity/quota/scope -> Azure AI/RAG FastAPI -> hybrid retrieval + deterministic rules
  -> provider adapter -> selected LLM provider
  -> grounded answer/scenario draft + citations + audit -> human review or Trainee response
```

| Thành phần | Trách nhiệm |
|---|---|
| `ifc_extractor` | Đọc IFC, tạo facts bất biến theo revision và quality flags. |
| `knowledge_ingest` | Version hóa, chunk và index tài liệu đã duyệt. |
| `retrieval_service` | Hybrid retrieval có metadata filter và BIM scope. |
| `rule_engine` | Chạy predicate minh bạch; không suy luận pháp lý mơ hồ. |
| `recommendation_service` | Tổng hợp duy nhất từ evidence, BIM facts và rule results. |
| `review_service` | Lưu review, quyết định, lý do và audit. |
| `scenario_draft_service` | Tạo cấu hình kịch bản có schema; OrganizationUser phải chỉnh/xác nhận trong editor trước khi lưu hoặc publish. |
| `ai_usage_service` | Trả usage kỹ thuật/request status cho backend; `.NET` reserve/chốt quota, overage, consent và đơn giá, không để AI hoặc frontend tự tính tiền. |

AI/RAG service chạy Python/FastAPI riêng trên Azure; Container Apps là phương án triển khai đề xuất. IFC/Blender worker dùng Python/IfcOpenShell nhưng chạy job/process độc lập với chat. Dữ liệu quan hệ, chunk metadata và embedding nằm trong Supabase PostgreSQL; `pgvector` là vector store chuẩn, không dùng ChromaDB trong kiến trúc đích. Pipeline package 3D/Unity vẫn tách biệt và chỉ đọc revision facts đã kiểm soát quyền.

Production client gọi `.NET API`, không gọi trực tiếp AI service. Backend gửi request ID, idempotency key, canonical input hash, audience, scope, source/revision version và context tối thiểu; AI trả status, citations, model/version và usage kỹ thuật. Timeout được tra cứu theo request ID; retry cùng idempotency key không tạo response/usage thứ hai. AI service không có quyền sửa editor, publish, entitlement hoặc billing ledger.

LLM production chưa chọn giữa OpenAI API và Google Gemini API (khóa/cấu hình qua Google AI Studio). `recommendation_service` phải gọi qua provider adapter, giữ cùng output schema/safety gate và chỉ bật một provider production sau evaluation. Không tự fallback sang provider còn lại nếu chưa có cấu hình và phê duyệt dữ liệu tương ứng. ChromaDB là hiện trạng/prototype cũ, không phải vector store đích.

## 5. Quy trình tạo khuyến nghị

1. Người dùng chọn Building revision, tầng/khu vực, audience và corpus đã được cấu hình.
2. Service kiểm tra quyền `organizationId`/phạm vi Trainee, chất lượng BIM facts và trạng thái nguồn.
3. Retriever lấy đoạn liên quan bằng lexical + vector search, lọc theo version/phạm vi/jurisdiction/trạng thái duyệt.
4. Rule engine tạo cờ như “thiếu mapping exit”, “mục đích sử dụng chưa xác định” hoặc “vùng hình học cần xác minh”. Cờ không phải kết luận tuân thủ.
5. Generator chỉ tổng hợp khi có evidence, phải nêu facts, nguồn, giả định, xung đột và điều không chắc chắn.
6. Với OrganizationUser, chỉ yêu cầu tạo cấu hình scenario mới trả `ScenarioDraft` ở trạng thái `NeedsUserEdit`; người dùng phải chỉnh và xác nhận trong editor. Câu hỏi kiến thức của OrganizationUser trả `KnowledgeAnswer`. Với Trainee, service luôn trả `KnowledgeAnswer` có dẫn chứng trong phạm vi được phép. Expert review là policy/assignment khi cần, không tạo thêm system role.
7. Backend ghi request idempotency, usage/quota và audit; retry không trừ lượt hai lần.
8. Chuyên gia chấp nhận, chỉnh sửa hoặc từ chối qua quy trình được cấp quyền; mọi hành động có audit.

## 6. Hợp đồng đầu ra

```json
{
  "response_type": "KnowledgeAnswer | ScenarioDraft",
  "status": "Answered | NeedsUserEdit | InsufficientEvidence | RejectedBySafetyGate",
  "recommendation": "Hạng mục cần xem xét bằng ngôn ngữ trung tính",
  "bim_anchors": [{"ifc_global_id": "...", "entity_type": "IfcSpace", "revision_id": "..."}],
  "citations": [{"document_id": "...", "document_version": "...", "chunk_id": "...", "excerpt_locator": "section/page/paragraph", "relevance": 0.0}],
  "rule_results": [{"rule_id": "...", "outcome": "flag | pass | not_evaluable", "reason": "..."}],
  "confidence": "low | medium | high",
  "audience": "organization | trainee",
  "request_id": "uuid",
  "usage": {"provider_units": 1, "input_tokens": 0, "output_tokens": 0, "model_version": "..."},
  "assumptions": ["..."],
  "limitations": ["Cần chuyên gia kiểm tra hiện trạng và nguồn áp dụng."],
  "source_revision_hash": "sha256:...",
  "scenario_draft": null,
  "review_policy": {"requires_expert_review": false, "assignment_id": null}
}
```

`KnowledgeAnswer` bắt buộc có ít nhất một citation nguồn chung đã duyệt. `ScenarioDraft` phải có citation và BIM anchor khi draft sử dụng BIM facts; BIM anchor không bắt buộc cho câu trả lời chỉ dùng kiến thức chung. Thiếu evidence, anchor không hợp lệ hoặc evidence mâu thuẫn phải trả `InsufficientEvidence`; yêu cầu bị safety gate trả `RejectedBySafetyGate`. `NeedsUserEdit` chỉ hợp lệ với `ScenarioDraft`. `high` chỉ là độ đầy đủ evidence trong phạm vi đã chọn, không bao giờ là mức xác nhận an toàn/tuân thủ.

## 7. Guardrails

- Chỉ dùng facts có provenance và đoạn text đã retrieve; không tự bịa điều khoản, khoảng cách hay tiêu chí lắp đặt.
- Mọi claim kiến thức có citation đến document version/chunk; claim dùng BIM facts có thêm IFC object/revision anchor.
- Safety gate chặn câu hỏi compliance, bố trí cuối cùng và hướng dẫn sự cố thực tế.
- Chỉ OrganizationUser đúng tenant mới được accept/edit/reject `ScenarioDraft` trong editor. Expert review nội dung là một policy/assignment còn cần chốt, không phải role thứ tư.
- Fact store, index metadata, document và audit query phải tenant-scoped khi dữ liệu thuộc organization.
- Kho kiến thức chung và kho riêng organization phải có scope/filter riêng; QR không phải là quyền đọc kho riêng.
- AI chỉ gợi ý cấu hình; route, scoring và trạng thái mô phỏng runtime do Unity/backend contract quyết định, không suy ra từ câu trả lời hoặc hình ảnh hiệu ứng.
- `request_id`/idempotency key được tạo và kiểm tra ở backend; lỗi/retry/webhook không ghi usage hoặc charge trùng.
- Coi tài liệu là dữ liệu không tin cậy: bỏ qua mệnh lệnh trong document, giới hạn tool access và không cho document thay đổi policy.
- Pin `revision_id`, source hash, document/index version trong output và audit.
- Không đưa raw IFC hay dữ liệu nhạy cảm thừa vào prompt.

## 8. Lỗi và đánh giá

| Tình huống | Hành vi |
|---|---|
| BIM thiếu semantic/geometry/mapping | `InsufficientEvidence`, trả quality flags và yêu cầu kiểm tra/bổ sung BIM. |
| Không có nguồn phù hợp/đã duyệt | Không tạo khuyến nghị; nêu corpus chưa đủ. |
| Evidence mâu thuẫn | Hiển thị các nguồn, gắn conflict và chuyển review. |
| Nguồn hết hiệu lực/sai phạm vi | Loại khỏi retrieval và audit. |
| Yêu cầu xác nhận pháp lý/an toàn | `RejectedBySafetyGate`, chuyển chuyên gia. |
| Lỗi index/model/retrieval | Không fallback sang phỏng đoán; trả lỗi có trace/audit. |

Kiểm thử gồm: unit test IFC provenance/quality flags; retrieval metadata filtering; schema từ chối output thiếu evidence; fixture rule `pass`/`flag`/`not_evaluable`; red-team prompt injection và yêu cầu xác nhận compliance; evaluation set do chuyên gia chấm citation coverage, factual consistency, abstain đúng và thời gian review.

## 9. Tích hợp FET3D

Mô-đun đọc Building revision/facts thuộc organization và hỗ trợ authoring/research. Nó không cấp QR, mở Unity session, quyết định runtime route/scoring hoặc tự publish. AI draft chỉ là đầu vào cho editor; sau khi người dùng xác nhận, scenario version mới phải chạy validation/readiness và được gắn với release bất biến. RAG không phải công cụ chuyển IFC thành mô hình; IFC pipeline và Unity build worker xử lý artifact riêng.

## 10. Contract AI–BE và recovery

Production client gọi `.NET API`; BE kiểm tra Firebase identity, audience, tenant, Building scope, policy version, quota/consent và idempotency trước khi gọi FastAPI trên Azure. FastAPI chỉ nhận scope đã được cấp và trả `request_id`, `KnowledgeAnswer` hoặc `ScenarioDraft`, trạng thái, citations/source version, BIM anchor khi có, model/version và usage kỹ thuật. AI không trả overage, đơn giá, charge hoặc quyết định publish.

Request mới phải vào `Accepted` không có result. Cùng idempotency key và canonical input hash trả lại request cũ; cùng key khác input bị từ chối. Timeout chuyển `NeedsReconcile`; BE gọi endpoint trạng thái trước khi retry, không tự hoàn quota rồi gọi LLM lần hai. Tài khoản bị khóa sau khi request đã được tiếp nhận không làm mất khả năng ghi nhận kết quả hợp lệ.

IFC/Blender và Unity build không chạy trong request chat. Logical job giữ input hash; worker attempt giữ lease/token/toolchain và artifact/validation provenance. Lease còn hiệu lực không được claim lại; kết quả từ attempt cũ bị chặn. Đây là thiết kế mục tiêu, chưa phải bằng chứng prototype FastAPI đã có tenant authorization hoặc pgvector production.

### 10.1. Bất biến request, policy và đối soát

Request chỉ được tạo ở `Accepted` với identity, scope, input hash và policy version đã kiểm tra; không nhận sẵn result, citation, model hoặc usage để bỏ qua processing. Khi result đã terminal, replay cùng evidence là no-op, evidence khác là conflict. Policy version và giá snapshot không update lịch sử; policy mới phải tạo version mới.

Quota reservation và settlement do `.NET`/database accounting sở hữu, khóa theo một thứ tự: `billing period nếu có → request → ledger/reservation → grant theo id tăng dần`. FastAPI chỉ trả usage kỹ thuật, request ID, model/version và evidence nguồn; không reserve/settle, đóng kỳ hoặc quyết định overage. Period AI chỉ đóng sau khi usage billable đã xác nhận; items sau close không chỉnh sửa, usage muộn đi qua adjustment.
