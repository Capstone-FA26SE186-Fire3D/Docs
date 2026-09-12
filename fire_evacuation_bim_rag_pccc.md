# Thiết Kế RAG Python Hỗ Trợ Gợi Ý Thiết Bị PCCC Từ BIM

## 1. Mục tiêu và ranh giới an toàn

Mô-đun hỗ trợ người dùng và chuyên gia được ủy quyền **xem xét** các không gian/đối tượng BIM có thể cần đánh giá thêm về thiết bị PCCC. Nó kết hợp tài liệu đã phê duyệt, facts trích xuất từ IFC, rule kiểm tra minh bạch và RAG bằng Python.

Đầu ra luôn là bản nháp cần chuyên gia review, không phải thiết kế thi công, kết luận tuân thủ, chứng nhận hay phê duyệt PCCC. Hệ thống không tự sửa IFC, không tự publish release và không đưa ra hướng dẫn ứng phó cháy thực tế.

> Đây là capability nghiên cứu/authoring tách biệt với training. Nó không thay đổi ý nghĩa `ConfirmForTraining`.

## 2. Câu hỏi hỗ trợ và câu hỏi bị từ chối

Hệ thống có thể trả lời: “Không gian nào có thuộc tính BIM còn thiếu để chuyên gia xem xét trang bị PCCC?” hoặc “Tài liệu nguồn nào liên quan đến `IfcSpace` này và giả định đang dùng là gì?”

Hệ thống phải từ chối/chuyển chuyên gia các yêu cầu: xác nhận tòa nhà đạt chuẩn, tự động quyết định số lượng/vị trí lắp đặt cuối cùng, hoặc chỉ đường thoát khi có sự cố thật.

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

Chỉ ingest tài liệu được organization phê duyệt: văn bản quy định/quy chuẩn còn hiệu lực mà tổ chức có quyền sử dụng, tiêu chuẩn nội bộ, catalogue kỹ thuật nhà sản xuất và hướng dẫn chuyên gia. Mỗi tài liệu phải có owner, phạm vi áp dụng, jurisdiction, version, ngày hiệu lực/rà soát, hash và locator trích dẫn. RAG không tự quyết định quy chuẩn nào áp dụng; reviewer cấu hình corpus theo dự án.

## 4. Kiến trúc Python

```text
IFC revision -> IFC extractor -> BIM fact store + quality flags
Approved documents -> parser/OCR -> chunker -> lexical + vector indexes
Question + BIM scope -> safety gate -> hybrid retrieval + deterministic rules
  -> grounded generator -> RecommendationDraft + audit -> human review
```

| Thành phần | Trách nhiệm |
|---|---|
| `ifc_extractor` | Đọc IFC, tạo facts bất biến theo revision và quality flags. |
| `knowledge_ingest` | Version hóa, chunk và index tài liệu đã duyệt. |
| `retrieval_service` | Hybrid retrieval có metadata filter và BIM scope. |
| `rule_engine` | Chạy predicate minh bạch; không suy luận pháp lý mơ hồ. |
| `recommendation_service` | Tổng hợp duy nhất từ evidence, BIM facts và rule results. |
| `review_service` | Lưu review, quyết định, lý do và audit. |

Python phù hợp cho extraction, ingestion, retrieval orchestration và rule evaluation. Pipeline package 3D/Unity vẫn tách biệt và chỉ đọc revision facts đã kiểm soát quyền.

## 5. Quy trình tạo khuyến nghị

1. Người dùng chọn Building revision, tầng/khu vực và corpus đã được cấu hình.
2. Service kiểm tra quyền `organizationId`, chất lượng BIM facts và trạng thái nguồn.
3. Retriever lấy đoạn liên quan bằng lexical + vector search, lọc theo version/phạm vi/jurisdiction/trạng thái duyệt.
4. Rule engine tạo cờ như “thiếu mapping exit”, “mục đích sử dụng chưa xác định” hoặc “vùng hình học cần xác minh”. Cờ không phải kết luận tuân thủ.
5. Generator chỉ tổng hợp khi có evidence, phải nêu facts, nguồn, giả định, xung đột và điều không chắc chắn.
6. Service trả draft `NeedsExpertReview`; không tự tạo annotation chính thức hay đổi IFC.
7. Chuyên gia chấp nhận, chỉnh sửa hoặc từ chối qua quy trình được cấp quyền; mọi hành động có audit.

## 6. Hợp đồng đầu ra

```json
{
  "status": "NeedsExpertReview | InsufficientEvidence | RejectedBySafetyGate",
  "recommendation": "Hạng mục cần xem xét bằng ngôn ngữ trung tính",
  "bim_anchors": [{"ifc_global_id": "...", "entity_type": "IfcSpace", "revision_id": "..."}],
  "evidence": [{"document_id": "...", "document_version": "...", "chunk_id": "...", "excerpt_locator": "section/page/paragraph", "relevance": 0.0}],
  "rule_results": [{"rule_id": "...", "outcome": "flag | pass | not_evaluable", "reason": "..."}],
  "confidence": "low | medium | high",
  "assumptions": ["..."],
  "limitations": ["Cần chuyên gia kiểm tra hiện trạng và nguồn áp dụng."],
  "source_revision_hash": "sha256:..."
}
```

Thiếu evidence, BIM anchor không hợp lệ hoặc evidence mâu thuẫn phải trả `InsufficientEvidence`. `high` chỉ là độ đầy đủ evidence trong phạm vi đã chọn, không bao giờ là mức xác nhận an toàn/tuân thủ.

## 7. Guardrails

- Chỉ dùng facts có provenance và đoạn text đã retrieve; không tự bịa điều khoản, khoảng cách hay tiêu chí lắp đặt.
- Mọi claim có citation đến document version/chunk và IFC object/revision.
- Safety gate chặn câu hỏi compliance, bố trí cuối cùng và hướng dẫn sự cố thực tế.
- Draft luôn bắt đầu `NeedsExpertReview`; chỉ người được ủy quyền quản lý review record.
- Fact store, index metadata, document và audit query phải tenant-scoped khi dữ liệu thuộc organization.
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

Mô-đun chỉ đọc Building revision/facts thuộc organization và hiển thị như công cụ authoring/research. Nó không cấp QR, không mở Unity session, không đổi `TrainingRelease`, scenario hoặc risk-aware routing. Nếu chuyên gia dùng một draft đã review, thay đổi phải đi qua workflow revision/scenario riêng và revision mới cần chạy IFC QA/readiness lại.
