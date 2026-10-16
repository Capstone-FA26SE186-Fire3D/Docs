# IFC ingestion, chất lượng hiển thị và tương tác runtime — FET3D

Tài liệu này bổ sung cho [technology mục 6–8](fire-evacuation-training-technology.md#6-ifc-pipeline-tự-động) và [workflows mục 3–4](fire-evacuation-training-workflows.md#3-workflow-building-và-ifc). Nó gom kết quả spike ngày 14/10/2026 với 25 file IFC công khai thành contract đề xuất cho IFC/Blender worker, Unity build worker, BE, FE editor, Mobile và Unity runtime.

**Trạng thái:** thiết kế đích + bằng chứng spike cục bộ. Chưa có migration, API, worker production, Unity code hay benchmark Android. Mọi mục ghi "đề xuất" cần team chốt trước khi triển khai. Tài liệu không thay đổi quyết định đã chốt: IFC là source duy nhất, chủ tòa không làm thủ công trong Blender/Unity, kích thước và cấu trúc công trình được bảo toàn.

## 1. Tóm tắt quyết định đề xuất

1. Giữ **IFC là định dạng duy nhất**. File `.rvt`, `.pln`, `.skp` bị từ chối với thông báo hướng dẫn xuất IFC (mục 3).
2. Worker **chọn representation `Body` theo `RepresentationIdentifier`**, không dựa vào thứ tự representation hay tên context; thiếu Body phải tạo issue chặn.
3. **Ba nguồn vật thể tương tác**: tự động từ IFC, IFC mơ hồ cần OrganizationUser xác nhận, và vật đặt trong editor. Quy tắc: **IFC có thiết bị PCCC/nguồn nước thì pipeline tự tạo vật tương tác (gợi ý sẵn); IFC không có thì OrganizationUser tự đặt trong editor.** Mô hình 3D của thiết bị luôn lấy từ thư viện dùng chung (có thể tạo bằng công cụ AI như Tripo rồi dọn lưới), không lấy hình học thiết bị từ IFC. Trong 25 file đã thử, thiết bị PCCC rất ít, nên đặt trong editor là đường chính.
4. **Vật liệu theo thứ tự**: `IfcStyledItem` → `IfcRelAssociatesMaterial` → mặc định theo class; tên vật liệu đa ngôn ngữ ánh xạ sang **thư viện PBR dùng chung** có texture CC0; worker tự tạo UV box theo mét.
5. **Lọc và thay thế** cho runtime Android: bỏ ống/ống gió/annotation/Default Mass; thay cửa, đèn, thiết bị vệ sinh nặng bằng asset thư viện theo bounding box và giữ `GlobalId`.
6. **Tương tác theo ngữ cảnh** (gần vật + vật đang cầm + trạng thái) với hiệu ứng là tham số trong `ScenarioVersion`, không hard-code tác dụng an toàn.

## 2. Bằng chứng spike

Môi trường: Blender 5.2.1 LTS, Bonsai, IfcOpenShell 0.9.0, EEVEE; Windows 11. Script kiểm kê và file `.blend` nằm ngoài repo (máy local), không đưa source IFC bên thứ ba vào Git.

### 2.1. Kiểm kê 25 file IFC

`Tris` là số tam giác hình học Body (đã loại ống/ống gió, `IfcSpace`, opening, annotation). `Vật liệu %` là tỉ lệ phần tử có `IfcRelAssociatesMaterial`. Không file nào có `IfcImageTexture`.

| File (nguồn) | Phần mềm, schema | Tầng / phòng | Cửa | Vệ sinh tìm được | PCCC tìm được | FireExit / FireRating | Vật liệu % | Tris |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| KIT_Institute_Arch (KIT) | ArchiCAD 11, IFC2X3 | 5 / 82 | 77 | 0 | 0 (`SprinklerProtection=false`) | 3 stair True / 0 | 60 | 40k |
| AC20-FZK-Haus | ArchiCAD 20, IFC4 | 2 / 7 | 5 | 0 | 0 | stair True, door False / 0 | 95 | 22k |
| FM_ARC_DigitalHub | Revit 2019 DEU, IFC4 | 3 / 64 | 70 | 0 | 0 | 0 / 0 | 93 | 332k |
| ISSUE_159_kleine_Wohnung_R22 | Revit 2022 DEU, IFC4 | 4 / 28 | 47 | 0 | 6 bình CO₂ (`IfcBuildingElementProxy`) | 0 / 0 | 99 | 180k |
| Office_A_20110811 (NIBS) | Revit 2011, IFC2X3 | 3 / 99 | 102 | 16 (`IfcFlowTerminal`, `IfcFurnishingElement`) | 0 | 0 / 102 | 71 | 52k |
| dental_clinic (NIBS) | Revit 2011, IFC2X3 | 4 / 269 | 254 | 39 | 10 tủ bình chữa cháy (`IfcFlowTerminal`) | 0 / 254 | 77 | 172k |
| duplex (NIBS) | Revit 2011, IFC2X3 | 4 / 21 | 14 | 7 (`IfcFurnishingElement`) | 0 | 0 / 14 | 45 | 26k |
| Ifc2x3_Duplex_Plumbing | Revit 2013, IFC2X3 | 3 / 1 | 0 | 16 (`IfcFlowTerminal`) | 0 | — | 10 | 220k |
| Ifc4_Revit_ARC_FireRatingAdded | Revit 2021 ENU, IFC4 | 6 / **0** | 16 | 6 (`IfcFlowTerminal`) | 0 | 0 / 0 | 92 | 362k |
| Ifc4_Revit_MEP | Revit 2021 ENU, IFC4 | 4 / 163 | 124 | 11 (`IfcFlowTerminal`) | 6 sprinkler (`IfcFireSuppressionTerminal`) | 0 / 0 | 73 | 461k |
| ISSUE_068_ARK_NUS_skolebygg | Revit 2019 ENG, IFC2X3 | 5 / 307 | 310 | 191 | 0 | 0 / 88 | 95 | **1.42M** |
| S_Office_Integrated Design Archi | ArchiCAD 24, IFC2X3 | 7 / **0** | 65 | 0 | 0 | 0 / 0 | 78 | **1.13M** |

Đợt bổ sung ngày 15/10/2026 (13 file):

| File (nguồn) | Phần mềm, schema | Tầng / phòng | Cửa | Vệ sinh tìm được | PCCC tìm được | Vật liệu % | Tris | Ghi chú |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Ifc2x3_Duplex_Architecture | Revit 2011, IFC2X3 | 4 / 21 | 14 | 7 | 0 | 45 | 26k | Kiến trúc của bộ Duplex |
| Ifc2x3_Duplex_MEP | Revit MEP 2011, IFC2X3 | 3 / 42 | 0 | 16 (`IfcFlowTerminal`) | 1 tủ trung tâm báo cháy | 0 | 80k | Không có tường; phòng tên "… MEP Space" |
| Ifc2s3_Duplex_Electrical | Revit 2013, IFC2X3 | 3 / 1 | 0 | 0 | 1 tủ trung tâm báo cháy (`IfcDistributionControlElement`) | 19 | 30k | Bộ môn điện |
| advanced_model | Revit 2021, IFC2X3 | 4 / **0** | 124 | 11 | 6 sprinkler (`IfcFlowTerminal`) | 82 | 955k | Cùng tòa trường học với Ifc4_Revit_MEP nhưng IFC2X3 |
| AdvancedProject (MIT) | Revit 2021, IFC2X3 | 10 / 8 | 126 | 40 | 0 | 88 | **2.20M** | Cửa sổ 1.07M tam giác |
| ISSUE_098_R8_F1_MAB_AR_M3 | Revit 2022, IFC2X3 | **28** / **0** | 1 458 | 0 | 0 | 98 | **1.57M** | Cửa chiếm 946k tam giác |
| schependomlaan | ArchiCAD 18, IFC2X3 | 6 / 100 | 205 | 0 | 0 | 88 | 245k | Chung cư Hà Lan; phòng badkamer, keuken, toilet |
| ISSUE_034_HouseZ | Rhino (Asuni), IFC2X3 | 3 / 5 | 15 | 0 | 0 | **0** | 243k | Không có liên kết vật liệu; cửa sổ 227k tam giác |
| ISSUE_126_model | ArchiCAD 20, IFC2X3 | 3 / **0** | 16 | 0 | 0 | 96 | 50k | 8 tường không có Body |
| ISSUE_129_N1540 | Revit 2017 FRA, IFC2X3 | 10 / **0** | **0** | 0 | 0 | 90 | 113k | Chỉ kết cấu |
| ISSUE_021_Mini Project | Tekla 2019, IFC2X3 | 1 / **0** | **0** | 0 | 0 | 71 | 241k | Chỉ kết cấu thép |
| LargeBuilding (MIT) | Revit 2021, IFC2X3 | 2 / 8 | 18 | 0 | 0 | 88 | 35k | Phòng chỉ tên "Room" |
| TallBuilding (MIT) | Revit 2021, IFC2X3 | 5 / 3 | 5 | 0 | 0 | 98 | 5k | Khối đơn giản |

Tìm thêm ngày 15/10/2026: 3 file của `viktor-platform/ifc-sample-models` (Revit 2024/2025; `BuildingBIMModel` có 116 phòng, 100 cửa) và 4 file tìm được qua `IfcAlarm` trên GitHub (`OFF-CLN.ifc`, 3 mẫu nhà ga OpenSourceRail). Không file nào có hệ thống báo cháy thật; tổng cộng 32 file đã kiểm tra.

**Không file nào trong 25 file vừa có phòng đặt tên, thiết bị vệ sinh, đầu báo/nút báo cháy và bình chữa cháy cùng lúc.** Bộ fixture gần đủ nhất cho FET3D:

| Mục đích | File đề xuất |
| :--- | :--- |
| Một file kiến trúc có phòng, WC, sprinkler | `Ifc4_Revit_MEP` (trường học, 163 phòng) |
| Nhiều file theo bộ môn (mục 4) | Bộ Duplex: Architecture + MEP + Electrical + Plumbing |
| Bình chữa cháy có sẵn trong IFC | `ISSUE_159_kleine_Wohnung_R22` (6 bình CO₂), `dental_clinic` (10 tủ bình) |
| Lỗi mất hình, thiếu sàn | `KIT_Institute_Arch`, `dental_clinic` |
| Phải bị từ chối hoặc cảnh báo | `ISSUE_021`, `ISSUE_129` (chỉ kết cấu), `ISSUE_098`/`AdvancedProject` (vượt ngân sách) |
| Đa ngôn ngữ | KIT (Đức), NUS_skolebygg (Na Uy), schependomlaan (Hà Lan) |

Đề xuất tạo thêm **một fixture chuẩn của FET3D**: lấy `Ifc4_Revit_MEP`, dùng IfcOpenShell API thêm `IfcAlarm` (nút báo cháy), `IfcSensor` (`SMOKESENSOR`), bình chữa cháy và cờ `FireExit` cho cửa ra ngoài, rồi dùng làm bài kiểm thử end-to-end. Fixture này do team tạo nên có thể kiểm soát license.

Nguồn file: ThatOpen `engine_web-ifc/tests/ifcfiles/public`, `andrewisen/bim-whale-ifc-samples` (MIT), `youshengCode/IfcSampleFiles`, bộ NIBS Common BIM Files, mẫu KIT/FZK. Các kho không ghi rõ license cho từng file; chỉ dùng làm fixture local, **không commit vào repo**.

### 2.2. Phát hiện chính

| Phát hiện | Bằng chứng | Hệ quả cho pipeline |
| :--- | :--- | :--- |
| Representation đầu tiên thường là `Axis` | 20/25 file có Body không đứng đầu; KIT đặt Body trong context `Design` (không phải `Model`) | Bonsai mặc định chỉ dựng đường trục 2D: **cả 119 tường KIT mất hình**. Chọn Body theo identifier thì 119/119 dựng được, kể cả khoét lỗ |
| Thiếu Body | S_Office: 40 tường không có Body | Issue chặn `IFC_NO_BODY_GEOMETRY` |
| Không dùng `IfcSanitaryTerminal` | 0/25 file có occurrence `IfcSanitaryTerminal`; thiết bị vệ sinh nằm ở `IfcFlowTerminal`, `IfcFurnishingElement`, `IfcBuildingElementProxy` | Nhận diện theo class + từ khóa tên đa ngôn ngữ, có độ tin cậy |
| Gần như không có báo cháy | 0/12 có `IfcAlarm` hay đầu báo khói; chỉ 3 file có bình/tủ/sprinkler | Editor bắt buộc có bước đặt thiết bị PCCC; QA cảnh báo khi thiếu |
| Thang máy chỉ là phòng | 1/12 có `IfcTransportElement`; nhiều file chỉ có `IfcSpace` tên Elevator/Lift/Aufzug/heis | Suy ra cửa thang máy từ phòng; OrganizationUser xác nhận |
| Không có phòng | 11/25 file không có `IfcSpace` (kể cả tòa 28 tầng) | Không suy được WC/hành lang/bếp; issue và yêu cầu xuất lại có rooms |
| Tên phòng ở `LongName` | Revit: `Name` là số ("49"), `LongName` là "Corridor"; ngôn ngữ Đức, Na Uy, Anh | Đọc cả `Name` và `LongName`, từ điển đa ngôn ngữ |
| Cờ thoát hiểm hiếm | `FireExit` chỉ có ở 2 file (chủ yếu trên cầu thang); `FireRating` ở 4 file | Cửa ra ngoài được suy từ cửa trên tường ngoài tầng trệt + xác nhận |
| Màu không gắn vào hình | Revit IFC4 Reference View: 0 `IfcStyledItem` dù có 33 surface style | Đọc vật liệu qua `IfcRelAssociatesMaterial` |
| Khối nháp quy hoạch | Revit MEP có 12 proxy `Default Mass` | Loại khỏi runtime; ghi issue thông tin |
| Quá nhiều lỗ trên một tường | Bonsai bỏ qua khoét lỗ cho 50 tường của Revit MEP | Worker dùng IfcOpenShell geom trực tiếp; issue cảnh báo nếu vẫn lỗi |
| Hình học nặng không đều | Tường chỉ chiếm vài nghìn tam giác; cửa kính 2 cánh khoảng 3.7k tam giác mỗi cái, thiết bị vệ sinh/đèn/proxy chiếm phần lớn | Thay thế bằng asset thư viện, lọc MEP, chia theo tầng |
| File theo bộ môn | Duplex Plumbing không có tường, chỉ có thiết bị | Cần hỗ trợ nhiều IFC cho một revision (mục 4) |
| Mất hình không chỉ ở ArchiCAD | dental_clinic (Revit 2011): 175–203 đối tượng không có mesh sau khi Bonsai nhập; dựng lại từ Body thành công | Bước "dựng lại Body cho mọi phần tử rỗng" là bắt buộc, không riêng tường |
| Thiếu sàn dưới phòng | dental_clinic: không có sàn dưới 262 `IfcSpace` (tia dò xuống không chạm vật) | Sinh sàn từ mặt đáy `IfcSpace`, giữ đúng biên phòng; issue `IFC_NO_FLOOR_UNDER_SPACE` |
| Vật liệu nhiều lớp | Revit ghi tường là layer set, lớp đầu có thể là khung thép ("Metal - Stud Layer") → tường ngoài bị gán kim loại tối | Bỏ qua lớp ẩn (stud, air, insulation, dämm, membrane) và lấy lớp hoàn thiện ngoài/trong |
| Thứ tự luật tên vật liệu | "Ceiling Tile 600 x 600" khớp nhầm luật gạch lát trước luật trần | Luật trần (ceiling, decke, himling, akustik) phải đứng trước luật tile |
| Class phụ thuộc schema | IFC2X3 không có occurrence `IfcSanitaryTerminal`/`IfcFireSuppressionTerminal`; thiết bị là `IfcFlowTerminal` gắn type `IfcSanitaryTerminalType`/`IfcFireSuppressionTerminalType` (advanced_model: 6 sprinkler là `IfcFlowTerminal`, bản IFC4 cùng tòa là `IfcFireSuppressionTerminal`) | Phân loại phải đọc cả type object qua `IfcRelDefinesByType`, không chỉ class occurrence |
| Báo cháy chỉ có tủ trung tâm | Bộ Duplex có "Fire Alarm Control Panel"; 0/32 file có đầu báo khói hay nút báo cháy | Editor vẫn bắt buộc đặt đầu báo/nút báo; tủ trung tâm chỉ là thiết bị tham chiếu |
| `IfcAlarm`/`IfcSensor` không chắc là PCCC | Tìm trên GitHub theo `IfcAlarm`: `OFF-CLN.ifc` (MIT) có 2 `IfcAlarm` là thiết bị báo động khẩn cấp cá nhân (duress charger); mẫu nhà ga OpenSourceRail chỉ có một khối tượng trưng "life-safety kit", `IfcSensor` là cảm biến ghi đường ray | Không tự coi `IfcAlarm`/`IfcSensor` là báo cháy; cần `PredefinedType` hoặc tên/type khớp từ khóa cháy, nếu không thì đưa vào danh sách cần xác nhận |
| File chỉ kết cấu | ISSUE_021 (Tekla), ISSUE_129: không cửa, không phòng | Issue chặn `IFC_NOT_ARCHITECTURAL` |
| File rất nặng do cửa/cửa sổ | Tòa 28 tầng: cửa 946k tam giác; AdvancedProject: cửa sổ 1.07M | Thay cửa/cửa sổ bằng asset thư viện là bắt buộc trước khi chia tầng |
| Không có vật liệu | Rhino export: 0% phần tử có vật liệu | Dùng màu surface style + mặc định theo class và loại phòng |
| Cây/đồ ngoại cảnh là proxy | FM_ARC_DigitalHub: hàng cây, xe đạp là `IfcBuildingElementProxy` | Thay bằng asset ngoại cảnh hoặc ẩn trong bản Android; không tô vữa mặc định |

### 2.3. Ba mức chất lượng hiển thị đã thử

| Mức | Nội dung | Kết quả quan sát |
| :--- | :--- | :--- |
| 1 — đúng mô tả Docs trước đây | Parse, giảm polygon, gộp vật liệu | Khối màu phẳng (KIT) hoặc xám toàn bộ (Revit RV), nội thất tối |
| 2 — vật liệu procedural + đèn theo phòng | Ánh xạ tên vật liệu, đèn area theo `IfcSpace`, bầu trời | Sạch, đọc được không gian; vân gỗ sai tỉ lệ khi không có UV |
| 3 — PBR texture thật + UV box | UV box theo mét, texture CC0 (Color/Normal/Roughness/AO) | Hành lang trường học có vân gỗ, gạch bóng phản chiếu, trần có kết cấu; gần cảm giác game |

Mức 3 là mục tiêu đề xuất cho capstone. Ánh sáng cuối cùng phải bake trong Unity (mục 5.6), không dùng render Blender làm chuẩn.

Cùng một pipeline đã chạy trên 5 tòa (KIT, trường học Revit 2021, FZK-Haus, dental_clinic, FM_ARC_DigitalHub). Nguyên nhân "trông chưa thật" chia làm hai nhóm:

| Do dữ liệu IFC | Do pipeline/thiết lập hiển thị |
| :--- | :--- |
| Hình học là khối sạch: không len chân tường, khung cửa đơn giản, không chi tiết trần | Ánh xạ tên vật liệu sai thứ tự hoặc lấy nhầm lớp kết cấu (đã sửa, mục 2.2) |
| Phòng trống, gần như không có đồ vật | Texture chọn chưa hợp (ví dụ gạch caro cho hành lang bệnh viện), normal quá mạnh |
| Thiếu sàn/thiếu hình học ở một số file | Ánh sáng chưa bake, bầu trời làm ám màu, chưa có AO/decal/bụi bẩn |

Thử nghiệm "cháy ban đêm, mất điện" trên cùng hành lang FM_ARC_DigitalHub (chỉ đổi ánh sáng: đèn sự cố đỏ, đèn EXIT xanh, ánh lửa, khói thể tích) cho thấy ánh sáng và không khí quyết định phần lớn cảm giác game, tương tự các asset pack môi trường thương mại. Vì vậy Unity build worker cần preset ánh sáng theo kịch bản (ban ngày, mất điện, khói dày) bên cạnh thư viện vật liệu.

## 3. Chấp nhận IFC và hướng dẫn xuất

- Chấp nhận `.ifc` (IFC2X3, IFC4, IFC4X3). `.ifczip` là đề xuất mở rộng. Từ chối định dạng gốc với thông báo kèm link hướng dẫn.
- Không chuyển đổi RVT phía server: cần license Revit hoặc dịch vụ trả phí bên thứ ba (Autodesk Platform Services, ODA) và phải gửi model riêng tư ra ngoài.

| Phần mềm | Thiết lập khuyến nghị khi xuất |
| :--- | :--- |
| Revit | IFC4 Reference View hoặc IFC2x3 Coordination View 2.0; **Export rooms/spaces**; **Export base quantities**; Split walls and columns by level; **Include linked files** khi PCCC/nước ở model MEP; xuất từ view 3D chứa đầy đủ phần tử |
| ArchiCAD | Translator IFC4 hoặc IFC2x3 Coordination View; bật Zones → `IfcSpace`; bật property set chuẩn; giữ Surface/Material |
| Chung | Đơn vị mét hoặc milimét nhất quán; tầng đặt đúng cao độ; phòng có tên; thiết bị PCCC dùng category/loại đúng nếu có |

FE hiển thị checklist này ở màn hình upload; BE trả issue có mã (mục 5.9) để FE dẫn người dùng tới mục cần sửa.

## 4. Nhiều IFC cho một revision (đề xuất, cần chốt)

Model PCCC/nước thường nằm ở file bộ môn riêng. Đề xuất: một `BuildingRevision` nhận **một file kiến trúc bắt buộc** và **0..n file bộ môn** (MEP, plumbing, fire protection). Worker hợp nhất theo tọa độ chung, kiểm tra cùng đơn vị/gốc tọa độ/tầng, và ghi hash từng file vào provenance. Nếu team chưa chốt, giữ một file IFC và hướng dẫn "Include linked files" khi xuất. Thay đổi này ảnh hưởng FR-IFC-01, schema `IfcSource` và UI upload nên cần cập nhật requirements/SQL trong task riêng.

## 5. Pipeline chi tiết

```text
Upload IFC (1..n) -> validate MIME/size/hash -> private S3
  -> [IFC worker, Python/IfcOpenShell]
       parse units/storeys/spaces -> chọn Body -> phân loại phần tử
       -> resolve vật liệu -> lọc runtime -> facts + interactable candidates + QA issues
  -> [Blender worker]
       mesh từ Body -> UV0 box (mét) + UV1 lightmap -> ánh xạ PBR thư viện
       -> thay thế asset theo bbox -> LOD -> chia theo tầng -> GLB + material map
  -> [Unity build worker]
       import -> URP Lit materials -> collider/NavMesh -> bake lightmap/probes
       -> gắn Interactable theo catalogKey -> package theo tầng + manifest
  -> QA tổng hợp -> ReadyForScenario | NeedsFix
```

### 5.1. Parse và chọn hình học (IFC worker)

- Với mỗi `IfcProduct`, chọn representation có `RepresentationIdentifier == "Body"` ở bất kỳ context nào có `ContextType` 3D. Không chọn `Axis`, `FootPrint`, `Box`, `Annotation`.
- Thiếu Body: dùng `Box` làm placeholder để không vỡ preview nhưng ghi issue `IFC_NO_BODY_GEOMETRY` (chặn với tường/sàn/cửa/cầu thang; cảnh báo với đồ nội thất).
- Body nằm ngoài context `Model`: chấp nhận và ghi `IFC_BODY_NONSTANDARD_CONTEXT` mức thông tin.
- Ghi toolchain (IfcOpenShell version), schema, ứng dụng xuất (`IfcApplication`), đơn vị, cao độ tầng và hash nguồn vào provenance.

### 5.2. Phân loại phần tử và ứng viên tương tác

Thứ tự: class IFC → `PredefinedType` → property set → từ khóa tên (`Name`, `ObjectType`, `LongName`, tên type). Mỗi ứng viên có `confidence` và `source`.

| Mục tiêu | Class ưu tiên | Từ khóa tên (không phân biệt hoa thường) |
| :--- | :--- | :--- |
| Phòng WC/tắm | `IfcSpace` | wc, toilet, bath, restroom, sanit, bad, dusch, toalett, vaskerom, badkamer |
| Bếp | `IfcSpace` | kitchen, pantry, küche, teeküche, kjøkken, keuken |
| Hành lang | `IfcSpace` | corridor, hallway, flur, gang, korridor, gang/hal (NL) |
| Cầu thang, thang máy | `IfcStair`, `IfcStairFlight`, `IfcTransportElement`, `IfcSpace` | stair, treppe, trapp, trap; elevator, lift, aufzug, heis |
| Nguồn nước | `IfcSanitaryTerminal`, `IfcFlowTerminal`, `IfcFurnishingElement`, `IfcBuildingElementProxy` | lavatory, sink, basin, bath, tub, shower, waschbecken, badewanne, dusche, vask, servant, dusj |
| Bồn cầu (vật cản, không phải nguồn nước) | như trên | water closet, toilet, wc pan, urinal, klosett, toalett |
| Thiết bị chữa cháy | `IfcFireSuppressionTerminal`, `IfcFlowTerminal`, `IfcBuildingElementProxy` | extinguisher, fire extinguisher cabinet, hose reel, hydrant, sprinkler, feuerlöscher, slukker |
| Báo cháy | `IfcAlarm`, `IfcSensor` (`SMOKESENSOR`, `HEATSENSOR`), `IfcBuildingElementProxy` | fire alarm, manual call point, smoke detector, rauchmelder, brannalarm |
| Tủ điện, van gas | `IfcElectricDistributionBoard`, `IfcBuildingElementProxy`, `IfcValve` | panelboard, distribution board, verteiler; gas valve, gashahn |
| Cửa thoát hiểm | `IfcDoor` + `Pset_DoorCommon.FireExit`, `IsExternal` | exit, notausgang, nødutgang; suy từ cửa trên tường ngoài ở tầng có lối ra |

- `IfcSensor` chỉ là đầu báo cháy khi `PredefinedType` hoặc tên khớp khói/nhiệt; cảm biến hiện diện (occupancy) không tính.
- `confidence ≥ 0.9` (class chuẩn) được dùng tự động; thấp hơn thì hiện trong danh sách "Thiết bị cần xác nhận" ở FE.
- Từ điển từ khóa là dữ liệu cấu hình có version, không hard-code trong code worker.

### 5.3. Lọc cho runtime

- Loại khỏi geometry runtime: `IfcDuctSegment/Fitting`, `IfcPipeSegment/Fitting`, `IfcCableCarrier*`, `IfcFlowSegment/Fitting`, `IfcAnnotation`, `IfcOpeningElement`, `IfcSpace` (giữ làm dữ liệu vùng), proxy có vật liệu/tên `Default Mass`.
- Giữ dữ liệu metadata của phần tử bị loại để RAG/editor tra cứu; chỉ không đưa vào mesh Android.

### 5.4. Ngân sách hình học và thay thế asset

- Mục tiêu ban đầu (cần đo trên Android tầm trung trước khi chốt): **≤ 150k tam giác đang hiển thị**, nạp tầng hiện tại + tầng kề, ≤ 150 draw call sau batching.
- Thay thế theo bounding box, giữ `GlobalId`, vị trí, hướng và kích thước gốc: cửa (theo số cánh/kính), đèn, thiết bị vệ sinh, tủ/kệ hộp (`Kubus-Einrichtung`), bình/tủ chữa cháy. Không thay tường, sàn, trần, cầu thang, lan can.
- Phần tử vượt ngân sách nhưng không có asset thay: decimate có giới hạn sai số hình học và ghi `IFC_TRIANGLE_BUDGET_EXCEEDED`.
- LOD0/LOD1 cho phần tử lặp nhiều; occlusion culling theo phòng.

### 5.5. Vật liệu và UV

Thứ tự lấy vật liệu: `IfcStyledItem` → `IfcRelAssociatesMaterial` (layer/constituent đầu tiên có tên) → mặc định theo class (`IfcSlab` FLOOR → sàn, ROOF → mái, `IfcCovering` CEILING → trần, tường → vữa sơn).

| Khóa thư viện | Từ khóa tên vật liệu (ví dụ thực tế từ spike) | Texture CC0 (ambientCG) | Kích thước lặp |
| :--- | :--- | :--- | :--- |
| `floor.tile` | fliesen, tiles, ceramic, flis | Tiles074 | 1.2 m |
| `floor.wood` | holzdielen, dielen, parkett, wood floor | WoodFloor051 | 2.0 m |
| `floor.carpet` | teppich, carpet | Carpet016 | 1.0 m |
| `ceiling.tile` | deckenraster, ceiling tile, gipskarton (trần) | OfficeCeiling001 | 1.2 m |
| `wall.plaster` | verputz, plaster, gips, gypsum, plasterboard, malt | PaintedPlaster017 | 2.0 m |
| `wall.brick` | ziegel, brick, masonry, tegl | Bricks097 | 1.5 m |
| `wall.tile` | wc trennwand, wall tile, wandfliesen | Tiles010 | 1.0 m |
| `concrete` | beton, concrete, ortbeton, stb | Concrete034 | 2.0 m |
| `wood` | holz, wood, lamellen, eiche, esche, kiefer | Wood092 | 1.0 m |
| `stone` | naturstein, marble, granite, sandstein | Marble012 | 1.5 m |
| `metal.painted` | metall lack, paint finish, steel, stahl | Metal027 | 1.0 m |
| `metal.brushed` | chrome, aluminium, stainless | Metal009 | 0.5 m |
| `glass.clear` / `glass.frosted` | glas, glass, klart / frosted, matt | không texture, shader kính | — |

- Tên không khớp: dùng màu gốc của surface style nếu có, ghi `IFC_UNMAPPED_MATERIAL` mức thông tin để PlatformAdmin bổ sung từ điển.
- **Tránh đơn điệu giữa các tòa.** IFC không mang texture (0/25 file có `IfcImageTexture`); spike dùng một bộ 12 texture cho mọi tòa nên các tòa trông giống nhau. Thiết kế đích:
  - Mỗi khóa thư viện có 5–10 **biến thể**; chọn biến thể xác định bằng hash (`buildingId` + tên vật liệu IFC) để mỗi tòa khác nhau nhưng build lại cho kết quả giống hệt.
  - **Nhuộm texture bằng màu surface style gốc** khi IFC có màu (ví dụ "Verputz blau", "Farbe braun") để giữ ý đồ kiến trúc.
  - **Ưu tiên theo loại phòng** từ `IfcSpace`: WC → gạch ốp + sàn chống trơn; văn phòng → thảm; hành lang bệnh viện/trường → vinyl; lab/xưởng → epoxy; sảnh → đá.
  - **Preset phong cách** theo loại công trình (trường học, bệnh viện, văn phòng, nhà ở) do PlatformAdmin quản lý; OrganizationUser chọn preset và có thể đổi vật liệu theo nhóm trong editor. Lựa chọn lưu theo revision, áp dụng tự động ở Blender/Unity worker, không chỉnh tay.
- **Kết quả spike v2 (15/10/2026)** trên phòng khám, trường học, Digital Hub và Duplex: sàn/trần hoàn thiện sinh từ mặt đáy/đỉnh `IfcSpace` theo loại phòng, màu tường chọn theo tòa, len chân tường bỏ qua ô cửa, tấm đèn âm trần nhìn thấy được; mỗi tòa 15–45 giây trong Blender. Bài học:
  - Lớp hoàn thiện phải đặt ở **mặt sàn/trần thật** (dò tia từ tâm phòng), không ở đáy `IfcSpace`: Revit để đáy phòng thấp hơn mặt sàn nên lớp mới bị che.
  - Thư viện phải **tuyển chọn**: 3/4 mẫu vữa CC0 phổ biến là loại bong tróc/lộ gạch, chỉ hợp cảnh cũ nát; terrazzo hạt to và thảm đỏ cam quá nổi cho hành lang.
  - Nhận diện preset bằng regex dễ nhầm ("Student" chứa "dent", "Gruppenbüro" khớp "gruppe"); cần ranh giới từ, trọng số theo số phòng và cho OrganizationUser xác nhận preset.
  - Ốp gạch WC phải gán **theo mặt tường quay vào phòng WC**, không gán cả tường (spike ốp cả mặt hành lang).
  - Cần thêm biến thể cho bê tông/vữa của kết cấu IFC; hai tòa khác nhau vẫn giống nhau nếu tường kết cấu dùng cùng một texture.
- **Spike v3 (15/10/2026)** sửa các lỗi trên và chốt cách xử lý màu:
  - **IFC gần như không mang màu dùng được.** `IfcSurfaceStyle` chỉ là màu phẳng RGB, không có texture; trong 25 file đầy đủ chỉ KIT và FZK-Haus có màu kiến trúc thật, các file Revit xuất xám/trắng toàn bộ (phòng khám: 12 tường có style nhưng đều xám, không dùng được). Quy tắc: **IFC có màu thật thì nhuộm texture theo màu đó; không có thì dùng bộ màu phối sẵn (scheme) do PlatformAdmin duyệt, chọn xác định theo tòa, OrganizationUser đổi được trong editor.**
  - Scheme gồm 4 màu phối với nhau: tường, tường nhấn (một mặt dài của hành lang), tông gỗ cửa, len chân tường. Tránh màu bão hòa cao; đây là lý do cảnh thương mại nhìn "có gu" hơn màu ngẫu nhiên.
  - Ốp gạch WC và tường nhấn gán **theo từng mặt** (dò tia từ tâm mặt theo pháp tuyến vào phòng), không gán cả tường.
  - Nhận diện preset dùng **so khớp token nguyên từ** thay vì regex substring; phòng khám (`GEN. DENT.`, `TRICARE OFFICE`) và trường học (`Workshop`, `Student Council`) nhận đúng. Vẫn phải cho OrganizationUser xác nhận.
  - Bê tông/kết cấu có 3 biến thể chọn theo tòa; ánh sáng ấm hơn (3200–3500K), bầu trời chỉ dùng cho cửa sổ, nội thất do tấm đèn chiếu.
  - Còn thiếu để đạt mức asset pack thương mại: đồ vật (bàn ghế, biển báo, thiết bị), decal bẩn/mòn, và AO/lightmap bake trong Unity. Ba thứ này nằm ở thư viện asset và Unity build worker, không ở bước IFC.
- **UV0**: chiếu box theo trục pháp tuyến trội, đơn vị mét (texture lặp theo kích thước thật). **UV1**: unwrap riêng cho lightmap, không chồng lấn. Spike tạo UV0 cho 789 mesh duy nhất trong 1.8 giây.
- Texture: 1K cho Android mặc định, 2K cho bề mặt lớn gần camera; nén ASTC; atlas theo tầng nếu cần giảm draw call.
- Độ thật kiểu game (tham khảo các cảnh nội thất game-ready): texture chụp thật + normal/roughness, AO bake, **len chân tường và khung cửa từ asset thư viện**, decal bẩn/mài mòn nhẹ theo khu vực (kho, xưởng, nhà xe), và đồ vật nhỏ chỉ lấy từ thư viện. Không có bước artist chỉnh từng Building.

### 5.6. Ánh sáng (Unity build worker)

- Đèn: ưu tiên `IfcLightFixture` (vị trí thật); nếu không có, đặt đèn area theo `IfcSpace` với công suất chuẩn hóa theo diện tích. Spike cho thấy công suất không chuẩn hóa làm cháy sáng ảnh.
- Bake lightmap (URP), light probe theo phòng, reflection probe cho hành lang/kính; ánh sáng mặt trời theo hướng công trình nếu có `TrueNorth`.
- Biến thể "mất điện": tắt đèn thường, bật đèn sự cố và biển EXIT phát sáng; phục vụ kịch bản có sự kiện mất điện.
- Khói/lửa là VFX đọc trạng thái hazard (technology mục 7), không bake.

### 5.7. Artifact và metadata cho Unity/BE/FE

Ví dụ rút gọn `building_metadata.json` trong package (đề xuất, field cuối cùng chốt cùng contract mục 8.1 của technology):

```json
{
  "schemaVersion": "1.0",
  "revisionId": "...",
  "sources": [{"role": "architecture", "sha256": "...", "schema": "IFC4", "app": "Autodesk Revit 2021"}],
  "units": "m",
  "storeys": [{"ifcGlobalId": "...", "name": "Level 1", "elevation": 0.0, "chunk": "storey_0.glb"}],
  "spaces": [{"ifcGlobalId": "...", "name": "49d", "longName": "Corridor", "category": "corridor", "storey": "...", "bbox": [[10.2, -5.1, 0.1], [53.1, -2.0, 3.8]]}],
  "portals": [{"ifcGlobalId": "...", "type": "door", "fireExit": null, "fireRating": "EI30", "spaces": ["...", "..."], "exitInferred": false}],
  "interactables": [
    {"id": "ifc:2X8...", "ifcGlobalId": "2X8...", "catalogKey": "water.sink", "source": "ifc", "ifcClass": "IfcFlowTerminal",
     "confidence": 0.8, "confirmedBy": null, "position": [12.3, 4.5, 0.9], "rotationY": 90, "bbox": [0.48, 0.36, 0.2]}
  ],
  "materials": {"FET3D_FloorTile": {"libraryKey": "floor.tile", "ifcNames": ["Bodenbelag Fliesen 50 x 50"]}},
  "qaIssues": [{"code": "IFC_NO_FIRE_EQUIPMENT", "severity": "warning", "elements": []}]
}
```

- `interactables` từ IFC chỉ là ứng viên; sau khi OrganizationUser xác nhận, chúng thành object `Equipment` trong state `fet3d.editor/1` của `ScenarioVersion` (mục 7), không sửa artifact revision.
- Quyết định thiết bị (`Confirmed`, `Retyped` kèm `catalogKey`, `Rejected`) được BE lưu theo revision với ETag, có thể được gợi ý lại ở revision sau. Đây là nguồn để Unity gắn component theo `catalogKey` và để giải quyết `IFC_EXIT_UNKNOWN` (mục 5.9). Màn xác nhận thiết bị mở được ngay khi geometry đã accept, kể cả khi revision còn `NeedsFix`.
- Unity không nhận raw IFC; mọi định danh dùng `ifcGlobalId` để truy vết giữa editor, runtime, event và kết quả.

### 5.8. Trách nhiệm theo thành phần

| Thành phần | Việc cần làm |
| :--- | :--- |
| IFC worker (Python, repo AI/BE tùy chốt) | Mục 5.1–5.3, từ điển từ khóa có version, xuất facts + ứng viên + issue; test bằng fixture local ở mục 2.1 |
| Blender worker | UV0/UV1, ánh xạ thư viện vật liệu, thay asset theo bbox, LOD, chia tầng, GLB; ghi provenance và số tam giác từng chunk |
| Unity build worker | Import GLB, URP Lit, collider/NavMesh, bake ánh sáng, gắn component theo `catalogKey`, đóng package theo tầng |
| BE | Lưu revision/sources/issues, API danh sách thiết bị cần xác nhận, lưu xác nhận của OrganizationUser, validate object `Equipment`/`Hazard` trong state `fet3d.editor/1` của `ScenarioVersion` theo capability `{id,version}` và schema tham số từ catalog (mục 7); không thêm trường `interactions` riêng |
| FE editor | Checklist xuất IFC, màn hình xác nhận thiết bị, đặt vật dụng/thiết bị PCCC bám bề mặt, dòng thời gian sự kiện, cảnh báo thiếu nguồn nước/báo cháy |
| Mobile | Tải package theo tầng, kiểm tra hash, báo dung lượng; không xử lý IFC |
| Unity runtime | `Interactable`, `InteractionDetector`, `ActionBar`, HUD, gửi event; đọc tham số hiệu ứng từ scenario |

### 5.9. Mã issue QA đề xuất

| Mã | Mức | Khi nào | Hành động người dùng |
| :--- | :--- | :--- | :--- |
| `IFC_NO_BODY_GEOMETRY` | Chặn (kết cấu) / Cảnh báo (nội thất) | Phần tử thiếu Body | Xuất lại với 3D Body |
| `IFC_BODY_NONSTANDARD_CONTEXT` | Thông tin | Body trong context khác `Model` | Không cần |
| `IFC_NO_SPACES` | Chặn | Không có `IfcSpace` | Bật xuất rooms/zones |
| `IFC_SPACE_UNNAMED` | Cảnh báo | Phòng thiếu `Name`/`LongName` | Đặt tên phòng hoặc phân loại trong editor |
| `IFC_EXIT_UNKNOWN` | Cảnh báo, giữ `NeedsFix` tới khi có cửa thoát | Không xác định được cửa ra ngoài | Xác nhận một `IfcDoor` có sẵn là `door.exit` trong màn xác nhận thiết bị; không cần upload lại IFC |
| `IFC_NO_FIRE_EQUIPMENT` | Cảnh báo | Không có thiết bị báo cháy/chữa cháy | Đặt trong editor |
| `IFC_NO_WATER_SOURCE` | Cảnh báo | Không có nguồn nước | Đặt trong editor nếu kịch bản cần |
| `IFC_LOW_CONFIDENCE_DEVICE` | Cảnh báo | Ứng viên dưới ngưỡng tin cậy | Xác nhận hoặc bỏ |
| `IFC_UNMAPPED_MATERIAL` | Thông tin | Tên vật liệu không có trong từ điển | PlatformAdmin bổ sung từ điển |
| `IFC_EXCESSIVE_VOIDS` | Cảnh báo | Không khoét được lỗ cửa | Kiểm tra cửa/tường đó |
| `IFC_NOT_ARCHITECTURAL` | Chặn | Không có `IfcDoor` và `IfcSpace` (file chỉ kết cấu/MEP) | Tải file kiến trúc hoặc dùng làm file bộ môn phụ (mục 4) |
| `IFC_NO_FLOOR_UNDER_SPACE` | Cảnh báo | Không có sàn dưới phòng; pipeline đã sinh sàn từ đáy `IfcSpace` | Xác nhận hoặc xuất lại kèm sàn/model kết cấu |
| `IFC_TRIANGLE_BUDGET_EXCEEDED` | Cảnh báo | Chunk vượt ngân sách sau thay thế | Xuất lại ở mức chi tiết thấp hơn |
| `IFC_DEFAULT_MASS_PRESENT` | Thông tin | Có khối nháp quy hoạch | Không cần, đã loại |
| `IFC_UNSUPPORTED_FORMAT` | Chặn | Upload không phải IFC | Xuất IFC theo mục 3 |

Quy tắc riêng cho `IFC_EXIT_UNKNOWN` (chốt 16/10/2026, phương án B): worker vẫn accept geometry và báo mức cảnh báo, nhưng revision đứng ở `NeedsFix` cho tới khi OrganizationUser xác nhận ít nhất một cửa thoát qua quyết định thiết bị. Bằng chứng duy nhất là một ứng viên `IfcDoor` đã có `ifcGlobalId` được quyết định Confirmed hoặc Retyped với `catalogKey = door.exit` (capability kind `Equipment`, nên API equipment-decisions không phải nhận kind khác); không tạo cửa mới, không sửa geometry. Khi có ít nhất một `door.exit` như vậy, revision tự chuyển `ReadyForScenario`; nếu sau đó mọi `door.exit` bị Rejected, revision quay lại `NeedsFix`. `exit.final`/`exit.stair` vẫn là object `Goal` do OrganizationUser đặt trong editor của từng `ScenarioVersion`, không đi qua equipment-decisions. Kiểm tra "còn route từ spawn tới Goal thoát" vẫn thuộc validation scenario (mục 9 bước 8), không thuộc bước này.

## 6. Danh mục vật thể tương tác (catalog)

Catalog do PlatformAdmin quản lý trong Organization Library (FR-LIBRARY-01/02). Mỗi mục có `catalogKey`, asset, thao tác, điều kiện, tham số hiệu ứng và event. **Tác dụng an toàn (khăn ướt, trùm chăn, che mũi, khu vệ sinh làm nơi trú) không mặc định là đúng; con số và lời giải thích phải từ nội dung được duyệt** (features mục Runtime library).

### 6.1. Đợt 1 (capstone)

| catalogKey | Nguồn thường gặp | Thao tác | Event cho rubric |
| :--- | :--- | :--- | :--- |
| `alarm.call_point` | Editor (hiếm có trong IFC) | Nhấn báo cháy | `alarm_raised` |
| `alarm.detector` | `IfcSensor` hoặc editor | Tự kích hoạt theo khói | `detector_triggered` |
| `extinguisher.portable` | Proxy/FlowTerminal theo tên hoặc editor | Lấy bình, rút chốt, giữ để phun | `extinguisher_used`, `extinguish_attempt_large_fire` |
| `water.sink` / `water.bath` / `water.shower` | FlowTerminal/Furnishing theo tên hoặc editor | Nhúng khăn/chăn (giữ) | `item_wetted` |
| `item.towel` | Editor | Nhặt, che mũi khi ướt | `nose_covered_in_smoke` |
| `door.standard` / `door.fire` / `door.exit` | `IfcDoor` | Sờ cửa, mở, đóng | `checked_door_heat`, `closed_door` |
| `transport.elevator` | `IfcTransportElement`/`IfcSpace` hoặc editor | Gọi thang (bẫy, vẫn hiện nút) | `used_elevator` |
| `exit.stair` / `exit.final` | `IfcStair`, cửa ra ngoài | Đi vào | `reached_exit`, thời gian thoát |
| `bait.belongings` | Editor | Nhặt đồ (bẫy) | `went_back_for_belongings` |
| `npc.guide` | Editor (spawn NPC) | Gọi, dẫn đường | `npc_guided` |
| `suppression.sprinkler` | `IfcFireSuppressionTerminal`/`IfcFlowTerminal` theo type/tên hoặc editor | Tự động, không tương tác (xem 6.3) | `sprinkler_activated` (debrief/analytics) |

### 6.2. Đợt 2 (mở rộng)

`extinguisher.hose_reel`, `blanket.fire` (bếp), `item.blanket`, `power.breaker`, `gas.valve`, `door.fire_wedged`, `door.exit_locked`, `phone.emergency`, `signal.window`, `ppe.escape_hood`, `firstaid.kit`, `npc.injured`, `npc.wheelchair` + `refuge.area`, `assembly.point`, `window.openable` (liên kết mô hình gió).

### 6.3. Sprinkler (đợt 1)

`suppression.sprinkler` là thiết bị tự động, người chơi không tương tác trực tiếp:

- Nguồn: `IfcFireSuppressionTerminal` loại `SPRINKLER` (IFC4), hoặc `IfcFlowTerminal` có type `IfcFireSuppressionTerminalType` hay tên chứa "sprinkler" (IFC2X3). Trong spike chỉ `Ifc4_Revit_MEP`/`advanced_model` có (6 đầu phun cho cả tòa); KIT ghi `SprinklerProtection = false`. Không có trong IFC thì OrganizationUser đặt trong editor hoặc chọn phủ theo phòng.
- Hành vi: khi nhiệt ở ô hazard của đầu phun vượt ngưỡng, đầu phun kích hoạt; VFX nước phun và giảm tốc độ lan/cường độ lửa trong bán kính phủ. Ngưỡng, bán kính, mức giảm và thời gian kích hoạt là tham số `ScenarioVersion`, không hard-code.
- Kịch bản có thể đặt sprinkler `Active`, `Disabled` hoặc `Faulty` để tạo tình huống. Event: `sprinkler_activated` (không phải hành động của người chơi; chỉ dùng cho debrief/analytics).

## 7. Luật tương tác theo ngữ cảnh

- Nút chỉ hiện khi người chơi **ở trong vùng chạm** (mặc định 1.2 m) và vật đó là **vật gần nhất phía trước**.
- Nút phụ thuộc **vật đang cầm** và **trạng thái**: bồn nước chỉ hiện "Nhúng nước" khi đang cầm khăn/chăn khô ("Nhúng lại" khi đã ướt); bình chỉ hiện "Rút chốt" rồi mới "Phun".
- **Cầm vật không có tác dụng** cho tới khi dùng đúng cách (khăn phải ướt và bấm "Che mũi").
- Một ô tay cầm và một ô che mũi; đang cầm vật khác thì nút đổi thành "Đổi lấy…".
- Tối đa 3 nút; thao tác quan trọng là nút giữ (nhúng nước khoảng 2 giây, phun bình).
- **Bẫy vẫn hiện nút bình thường** để đánh giá được hành vi.
- Guided Drill làm nổi bật nút nên bấm và có gợi ý; Assessment hiện đủ nút, không làm nổi bật, không gợi ý (technology mục 1.2).

**Ánh xạ với contract editor hiện có:** BE/FE đã có contract `fet3d.editor/1` (BE `contracts/editor/v1`) với sáu loại object `Spawn`, `Hazard`, `Goal`, `Npc`, `BlockedElement`, `Equipment`; `Equipment`/`Hazard` mang capability `{id,version}` lấy từ `GET /api/scenario-interactions/catalog`. **`catalogKey` trong tài liệu này chính là capability id đó**; vật tương tác và sprinkler là object `Equipment`, nguồn lửa là `Hazard`. Không thêm trường `interactions` riêng: luật hành động bên dưới là metadata của capability trong catalog, tham số đặt trên từng object theo schema tham số của capability.

Ví dụ metadata capability (minh họa, field cuối cùng chốt cùng catalog):

```json
{
  "catalogKey": "water.sink",
  "actions": [
    {"id": "wet_item", "requiresHeld": ["item.towel:dry", "item.towel:wet", "item.blanket:dry"],
     "hold_s": 2.0, "effect": {"setState": "wet"}, "event": "item_wetted"}
  ]
}
```

```json
{
  "catalogKey": "item.towel",
  "params": {"smokeIntakeMultiplierWhenCovered": "<từ nội dung đã duyệt>", "dryAfter_s": "<từ nội dung đã duyệt>"},
  "actions": [{"id": "cover_nose", "requiresState": "wet", "event": "nose_covered_in_smoke"}]
}
```

## 8. HUD trạng thái

- Người chơi: Sức khỏe, Khói đã hít, Nhiệt, Thể lực; ô vật đang cầm (kèm thời gian khô của khăn); mục tiêu và đồng hồ.
- NPC: chỉ biểu tượng trạng thái trên đầu (bình thường, hoảng loạn, bị thương, bất tỉnh, đang đi theo), không có thanh máu.
- Assessment thu gọn HUD và không hiện gợi ý hay mục tiêu ẩn. Các chỉ số này là dữ liệu tập huấn mô phỏng, không phải chỉ số y khoa.

## 9. Quy trình OrganizationUser dựng kịch bản

Bổ sung cho [workflows mục 4](fire-evacuation-training-workflows.md#4-workflow-scenario-và-readiness):

1. Ngay khi geometry đã accept (revision `NeedsFix` chỉ vì thiếu cửa thoát hoặc đã `ReadyForScenario`), xem **Danh sách thiết bị phát hiện được** kèm độ tin cậy; xác nhận, sửa loại hoặc bỏ. Nếu có issue `IFC_EXIT_UNKNOWN`, chọn cửa thoát trong bước này để revision chuyển `ReadyForScenario`.
2. Khi revision đã `ReadyForScenario`, chọn template (ví dụ cháy bếp giờ hành chính, cháy điện ban đêm) hoặc trang trắng.
3. Đặt spawn người chơi, NPC theo loại và số lượng trong budget.
4. Đặt nguồn lửa (loại điện/dầu/chất rắn, tốc độ lan, thời điểm), khói, gió.
5. Lập **dòng thời gian sự kiện**: đầu báo kích hoạt hoặc bị vô hiệu, mất điện, cầu thang bị khói chặn.
6. Đặt vật dụng rời và tình huống thử thách (bình hết, cửa thoát hiểm khóa, đồ có giá trị).
7. Chọn mục tiêu và rubric; mỗi tiêu chí gắn với event ở mục 6.
8. Validation tự động: còn route thoát, vật tới được, nguồn nước trong vùng đi được, thiết bị không xuyên tường; playtest; `ConfirmForTraining`; gửi PlatformAdmin duyệt.

Editor chỉ thêm vật lên artifact; không sửa tường, cửa, sàn hay kích thước công trình.

## 10. Kiểm thử và tiêu chí nghiệm thu

- Fixture: 25 file ở mục 2.1 giữ ở máy/CI riêng (không commit vì license chưa rõ). Mỗi file có kỳ vọng về số tầng, phòng, cửa, ứng viên vệ sinh/PCCC và issue.
- IFC worker: KIT phải dựng đủ 119 tường; Revit MEP phải tìm 6 sprinkler và 11 thiết bị vệ sinh; Revit ARC và S_Office phải phát `IFC_NO_SPACES`; S_Office phát `IFC_NO_BODY_GEOMETRY`.
- Blender worker: 100% mesh runtime có UV0; ≥ 90% vật liệu có tên ánh xạ được trên bộ fixture; số tam giác mỗi chunk ghi vào provenance.
- Unity: mở hành lang đại diện ở camera third-person, đạt mục tiêu 30 FPS Android tầm trung trong phiên 15 phút (technology mục 1.2); đo lại ngân sách mục 5.4.
- Runtime tương tác: các ca ở mục 7 (bồn nước không hiện nút khi tay không; khăn khô không giảm khói; bẫy vẫn hiện nút; Assessment không làm nổi bật).

## 11. Giới hạn và quyết định còn mở

- Nhiều IFC cho một revision (mục 4) chưa chốt; ảnh hưởng requirements, SQL và UI.
- Ngân sách tam giác/draw call là mục tiêu ban đầu, phải đo trên thiết bị.
- Thư viện asset thay thế và decal cần người làm 3D tạo một lần; mô hình AI-generate (ví dụ Tripo) phải kiểm license và dọn lưới trước khi dùng.
- Texture CC0 từ ambientCG dùng được cho thương mại; vẫn ghi nguồn trong thư viện. Mô hình trên Sketchfab có license riêng từng mục, không tự đưa vào sản phẩm.
- Tác dụng của khăn ướt, chăn ướt, che mũi và nơi trú tạm cần chuyên gia PCCC duyệt nội dung; game chỉ là mô phỏng tập huấn, không phải hướng dẫn khẩn cấp thực tế.
- Kết quả spike là bằng chứng kỹ thuật cục bộ, không phải bằng chứng worker production, package Android hay hiệu năng thiết bị.

## 12. Nguồn tham khảo

- IfcOpenShell và Bonsai: https://ifcopenshell.org, https://bonsaibim.org
- Blender Lab MCP server: https://www.blender.org/lab/mcp-server/
- ambientCG (CC0 PBR): https://ambientcg.com
- buildingSMART Sample-Test-Files: https://github.com/buildingSMART/Sample-Test-Files
- ThatOpen web-ifc public test files: https://github.com/ThatOpen/engine_web-ifc/tree/main/tests/ifcfiles/public
- youshengCode IfcSampleFiles: https://github.com/youshengCode/IfcSampleFiles
