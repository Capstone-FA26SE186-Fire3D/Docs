# Tài Liệu Yêu Cầu Dự Án (Requirements Document)
**Dự án:** Fire Evacuation Training 3D
**Phiên bản:** v1.0
**Ngày cập nhật:** 08/08/2026
**Trạng thái:** Draft / Cần Review

---

## Mục Lục
1. [Tổng Quan Dự Án](#1-tổng-quan-dự-án)
2. [Stakeholders & Roles](#2-stakeholders--roles)
3. [Functional Requirements (Yêu Cầu Chức Năng)](#3-functional-requirements-yêu-cầu-chức-năng)
4. [Non-Functional Requirements (Yêu Cầu Phi Chức Năng)](#4-non-functional-requirements-yêu-cầu-phi-chức-năng)
5. [Ngoài Phạm Vi (Out of Scope)](#5-ngoài-phạm-vi-out-of-scope)
6. [Ràng Buộc & Giả Định (Constraints & Assumptions)](#6-ràng-buộc--giả-định)
7. [Câu Hỏi Mở (Open Questions)](#7-câu-hỏi-mở)

---

## 1. Tổng Quan Dự Án (Project Overview)
Fire Evacuation Training 3D là một nền tảng SaaS Multi-tenant đột phá, được thiết kế để chuyển đổi các mô hình BIM (IFC/RVT) và bản vẽ 2D (DWG/PDF) của các tòa nhà thành môi trường huấn luyện thoát hiểm 3D sống động trên thiết bị di động Android. 

Hệ thống phục vụ nhiều loại tổ chức (tòa nhà văn phòng, bệnh viện, trung tâm thương mại). Người dùng cuối sẽ sử dụng ứng dụng di động Flutter để quét mã QR tại các vị trí trong tòa nhà, tải xuống môi trường 3D Unity tương ứng, và thực hành các kịch bản thoát hiểm cháy nổ có sự hỗ trợ của AI định tuyến và mô phỏng đám đông (NPC).

---

## 2. Stakeholders & Roles
Hệ thống sử dụng cơ chế Role-Based Access Control (RBAC).

| Role | Mô Tả | Quyền Hạn Chính |
| :--- | :--- | :--- |
| **PlatformAdmin** | Quản trị viên cấp cao nhất của hệ thống SaaS. | Quản lý tenant (tổ chức), cấu hình hệ thống chung, xem báo cáo tổng thể. |
| **OrgOwner** | Chủ sở hữu / Quản lý của một tổ chức cụ thể (Tenant). | Quản lý thông tin tổ chức, quản lý người dùng trong tổ chức, phân quyền, tạo Campaign, xem báo cáo tổ chức. |
| **BimOperator** | Nhân sự kỹ thuật phụ trách sơ đồ/BIM của tổ chức. | Upload file BIM/2D, xem trạng thái xử lý pipeline, tạo Revision. |
| **FireReviewer** | Chuyên gia an toàn PCCC của tổ chức. | Review (xem trước 3D), Approve/Reject các Revision, tạo Campaign, cấu hình độ khó kịch bản. |
| **Member** | Người dùng nội bộ của tổ chức (nhân viên, cư dân...). | Đăng nhập app di động, quét QR, tham gia huấn luyện đầy đủ các chế độ, xem kết quả cá nhân. |
| **Guest** | Người dùng vãng lai, khách thăm quan (Không đăng nhập). | Quét QR, chỉ tham gia được môi trường 3D nếu Release cho phép `is_public=true`. Không được chơi chế độ Assessment. |

---

## 3. Functional Requirements (Yêu Cầu Chức Năng)

### FR-AUTH: Authentication & Authorization
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-AUTH-01 | Đăng nhập Web Admin | Cho phép PlatformAdmin, OrgOwner, BimOperator, FireReviewer đăng nhập Web Admin bằng Email/Password. | Must Have | JWT Bearer token |
| FR-AUTH-02 | Đăng nhập Mobile App | Cho phép Member đăng nhập Flutter app. | Must Have | |
| FR-AUTH-03 | Guest Mode | Cho phép người dùng mở Mobile app không cần đăng nhập (Guest) và sử dụng DeviceToken để định danh. | Must Have | |
| FR-AUTH-04 | Phân quyền RBAC | Hệ thống phải giới hạn chức năng dựa trên Role của người dùng (API & UI). | Must Have | |

### FR-ORG: Organization & User Management
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-ORG-01 | Quản lý Tenant | PlatformAdmin có thể tạo mới, cập nhật, vô hiệu hóa các tổ chức (Tenant). | Must Have | |
| FR-ORG-02 | Quản lý thành viên tổ chức | OrgOwner có thể thêm, sửa, xóa, cấp role cho các thành viên trong tổ chức của mình. | Must Have | |

### FR-BUILD: Building Management
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-BUILD-01 | Khởi tạo Tòa nhà | OrgOwner/BimOperator có thể tạo hồ sơ tòa nhà mới (Tên, Vị trí, Số tầng...). | Must Have | |
| FR-BUILD-02 | Quản lý Tầng (Floors) | Tổ chức cấu trúc Tòa nhà -> Tầng. | Must Have | |

### FR-BIM: BIM Upload & Processing Pipeline
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-BIM-01 | Upload File BIM | BimOperator upload file IFC/RVT/DWG/PDF qua Web. Hệ thống tạo Revision (trạng thái: Draft) và lưu gốc vào MinIO. | Must Have | Giới hạn dung lượng upload (VD: 500MB) |
| FR-BIM-02 | Bắt đầu xử lý Pipeline | Chuyển đổi trạng thái Revision từ Draft sang Processing. Kích hoạt Python worker. | Must Have | |
| FR-BIM-03 | BIM Processing Worker | Worker xử lý file (Parse IFC -> Clean Geometry -> Decimate Mesh -> Gen NavMesh -> Gen Hazard Grid -> Export GLB + Manifest). | Must Have | Chạy ngầm, timeout 30 phút, retry 2 lần |
| FR-BIM-04 | Cập nhật trạng thái xử lý | Cập nhật trạng thái Revision thành `ReviewRequired` (thành công) hoặc `Failed` (lỗi). Hiển thị log lỗi cho BimOperator. | Must Have | |

### FR-REVIEW: Review & Approval Workflow
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-REVIEW-01 | Preview 3D | FireReviewer có thể mở Web Admin xem bản preview 3D dạng GLB. | Must Have | |
| FR-REVIEW-02 | Kiểm tra kịch bản | Cho phép Reviewer kiểm tra trực quan các yếu tố: Lối thoát, Điểm tập kết, Lưới Hazard. | Should Have | |
| FR-REVIEW-03 | Phê duyệt (Approve) | FireReviewer Approve bản Revision. Hệ thống kích hoạt gen Addressables package. | Must Have | |
| FR-REVIEW-04 | Từ chối (Reject) | FireReviewer Reject Revision, bắt buộc nhập lý do. Trạng thái chuyển về Rejected. | Must Have | |

### FR-RELEASE: Release & QR Management
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-RELEASE-01 | Generate Addressables | Sau khi Approve, hệ thống tạo gói Unity Addressables, mã hóa và upload lên MinIO. | Must Have | |
| FR-RELEASE-02 | Tạo Release | Hệ thống tạo Release (Active), sinh chuỗi QR hash định danh cho phiên bản môi trường 3D. | Must Have | |
| FR-RELEASE-03 | Config Public Access | Có thể set `is_public=true/false` cho Release để kiểm soát Guest có được tham gia hay không. | Must Have | |
| FR-RELEASE-04 | Quản lý và In QR | Cung cấp giao diện để OrgOwner/BimOperator tải xuống/in QR Code hiển thị tại hiện trường. | Must Have | |

### FR-CAMPAIGN: Campaign Management
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-CAMPAIGN-01 | Tạo Campaign | OrgOwner/FireReviewer tạo Campaign dựa trên một Release. | Must Have | |
| FR-CAMPAIGN-02 | Cấu hình Campaign | Cấu hình mật độ NPC (NPC density), ngưỡng an toàn (safety thresholds), thời gian bắt đầu/kết thúc Campaign. | Must Have | |
| FR-CAMPAIGN-03 | Theo dõi tiến độ | Liệt kê danh sách các Sessions (lượt chơi) của Campaign. | Must Have | |

### FR-TRAINING: Training Session & Modes
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-TRAINING-01 | Chế độ Learn | Chế độ tự do, không hazard, highlight đường, không tính điểm. | Must Have | |
| FR-TRAINING-02 | Chế độ Guided Drill | Có hazard ngẫu nhiên, AI gợi ý đường, có NPC, có tính điểm. | Must Have | |
| FR-TRAINING-03 | Chế độ Assessment | Không gợi ý, hazard cố định theo kịch bản, chấm điểm khắt khe, không được retry. Khóa đối với Guest. | Must Have | |
| FR-TRAINING-04 | Scan QR & Xác thực | Flutter app quét QR, gọi API bằng QR Hash, trả về Signed URL tải Manifest (TTL 1-4 giờ). | Must Have | |
| FR-TRAINING-05 | Download & Init | Flutter download Addressables, gọi Unity truyền path và config. | Must Have | |
| FR-TRAINING-06 | Unity Gameplay | Unity load Scene, NavMesh, Hazard, NPC theo chế độ đã chọn. | Must Have | |
| FR-TRAINING-07 | Hand-off Kết quả | Unity kết thúc vòng chơi, trả JSON kết quả về Flutter. | Must Have | |

### FR-AI: AI Routing & NPC Behavior
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-AI-01 | Thuật toán Risk-aware A* | Tính toán đường đi tối ưu dựa trên: khoảng cách, hazard exposure, độ tắc nghẽn. | Must Have | |
| FR-AI-02 | Hazard Handling | Xử lý các loại Hazard: Lửa (không thể qua), Khói (tăng cost), Tắc nghẽn (tăng cost). | Must Have | |
| FR-AI-03 | Dynamic Replanning | Thuật toán tự động tính lại đường đi sau mỗi N giây hoặc khi hazard mới xuất hiện. | Must Have | |
| FR-AI-04 | NPC States | NPC chuyển đổi các trạng thái: Idle -> Alarmed -> PathChoosing -> Moving -> Stuck -> ReportingError. | Must Have | |
| FR-AI-05 | NPC Pathfinding & Congestion | NPC sử dụng NavMesh riêng, có thể cản đường người chơi tạo congestion. | Must Have | Số lượng NPC phụ thuộc config Campaign. |

### FR-SYNC: Offline Sync & Resilience
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-SYNC-01 | Offline Package Cache | Flutter lưu cache các Addressables package theo cơ chế LRU. Cấu hình dung lượng max. | Must Have | Giảm tải download lần sau |
| FR-SYNC-02 | Local Result Queue | Flutter lưu JSON kết quả vào SQLite/Hive nội bộ ngay sau khi chơi. | Must Have | |
| FR-SYNC-03 | Sync Results | Flutter đồng bộ dữ liệu kết quả lên Backend tự động khi có mạng. | Must Have | Offline-first approach |
| FR-SYNC-04 | Crash Recovery | Nếu Unity crash, Flutter giữ state, cho resume nếu chưa quá thời gian timeout (default 30 phút). | Should Have | |
| FR-SYNC-05 | Ghi nhận Crash | Nếu crash hoàn toàn, đánh dấu Session là `Crashed`, không tính vào điểm. | Must Have | |

### FR-ANALYTICS: Analytics & Reporting
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-ANALYTICS-01 | Dashboard Tổ chức | Hiển thị thống kê tổng quan: điểm số, số người tham gia, lỗi lối sai (wrong exits). | Must Have | |
| FR-ANALYTICS-02 | Báo cáo chi tiết | Thống kê hazard exposure, thời gian thoát hiểm theo cá nhân và theo thời gian. | Must Have | |
| FR-ANALYTICS-03 | Báo cáo Guest | Phân tích Session của Guest dựa trên DeviceToken (ẩn danh). | Should Have | |

### FR-AUDIT: Audit Log
| ID | Tên Yêu Cầu | Mô Tả | Priority | Notes |
| :--- | :--- | :--- | :--- | :--- |
| FR-AUDIT-01 | System Audit Trail | Ghi log mọi hành động nhạy cảm: Approve/Reject Revision, Upload BIM, Tạo Campaign. | Must Have | |

---

## 4. Non-Functional Requirements (Yêu Cầu Phi Chức Năng)

### NFR-PERF: Performance
- **Unity 3D Engine**: Đạt mức tối thiểu **30 FPS ổn định** trên thiết bị Android tầm trung. Chạy ổn định không crash trong ít nhất 15 phút. Có cơ chế xử lý OOM (Out Of Memory) gracefully.
- **Package Size**: Mỗi Addressables package không vượt quá **150MB** (sau khi decimate mesh và nén).
- **API Response**: 95th percentile < **500ms** cho các endpoint thông thường (như auth, quét QR, sync kết quả).
- **BIM Processing Worker**: Có khả năng scale ngang; xử lý tối đa 30 phút/file, tự động retry 2 lần nếu failed.

### NFR-SEC: Security
- **Bảo vệ File BIM gốc**: File IFC/RVT nguyên bản chỉ Backend được quyền đọc. Tuyệt đối không expose ra public link.
- **Bảo vệ Addressables Package**: Gói Addressables phải được mã hóa trước khi lên MinIO. Chỉ tải được qua Signed URL với Time-to-Live (TTL) ngắn (1-4 giờ).
- **API Security**: Sử dụng JWT Bearer authentication, validate token trên mọi request.

### NFR-AVAIL: Availability
- Hệ thống thiết kế chịu lỗi, MinIO / Postgres / Web server deploy theo cụm. Backend .NET thiết kế stateless.

### NFR-PRIVACY: Data Privacy
- **Guest Data**: Dữ liệu chơi của Guest chỉ lưu gắn với DeviceToken, hoàn toàn không thu thập/gắn định danh cá nhân (PII).
- **Multi-tenant Data Isolation**: Dữ liệu của tổ chức nào chỉ tổ chức đó truy cập được. Áp dụng TenantID ở level Database (PostgreSQL RLS hoặc qua Entity Framework Global Query Filter).

### NFR-COMPAT: Compatibility
- **Mobile**: Android (Version 10.0 trở lên).
- **Web Admin**: Tương thích các trình duyệt hiện đại (Chrome, Edge, Firefox, Safari phiên bản 2 năm gần nhất).

---

## 5. Ngoài Phạm Vi (Out of Scope)
- Hỗ trợ nền tảng iOS hoặc WebGL cho trải nghiệm người dùng cuối (Giai đoạn 1 chỉ tập trung Android).
- Tích hợp thiết bị VR/AR (Kính thực tế ảo).
- Xây dựng công cụ vẽ bản vẽ ngay trên hệ thống Web (Chỉ hỗ trợ upload file vẽ sẵn từ Revit/AutoCAD).

---

## 6. Ràng Buộc & Giả Định (Constraints & Assumptions)
- **Ràng buộc**: Quá trình giải mã Addressables và Unity handoff phải nằm hoàn toàn trong Flutter app cục bộ, không streaming hình ảnh từ server.
- **Giả định**: Các file BIM upload lên phải tuân thủ một chuẩn đặt tên (Naming Convention) nhất định để Python worker có thể tự động nhận dạng các yếu tố kiến trúc (như `IfcDoor`, `IfcStair`).
- **Giả định**: Điện thoại của người dùng cuối có tối thiểu 2GB RAM trống để chạy engine 3D.

---

## 7. Câu Hỏi Mở (Open Questions)
1. Cơ chế tính điểm trong *Assessment Mode* cụ thể sẽ trừ/cộng điểm dựa trên công thức toán học nào? (Cần FireReviewer chuyên gia cung cấp).
2. Chuẩn nén mã hóa nào (AES-128 hay AES-256) sẽ được sử dụng cho Addressables package trên app di động để cân bằng giữa bảo mật và tốc độ load?
3. Với các file RVT (Revit) độc quyền, Python worker sẽ trực tiếp parse hay cần một dịch vụ trung gian (như Autodesk Forge / APS) trước khi đẩy vào pipeline cục bộ?

---
*Tài liệu này là phiên bản nội bộ, chỉ dành cho Development Team và các Stakeholders liên quan.*
