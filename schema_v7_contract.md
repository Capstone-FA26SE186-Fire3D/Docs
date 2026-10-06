# FET3D Schema v7.0 — Product Contract

`fire_evacuation_schema.sql` is the design schema for this contract. It is not evidence that a production migration has run. No commercial amount, quota unit, expiry/rollover rule, rubric threshold, or certificate rule is seeded or inferred here.

## What v7 locks down

| Area | Contract |
| --- | --- |
| Local identity | Registration follows form → OTP challenge → one-time proof → verified account → login. OTP, reset, device and email-job records are durable; normalized email is unique. |
| Organization library | PlatformAdmin maintains versioned scenario templates, rubric samples and equipment metadata. It is private operational content, not public Learn content. |
| Scenario review | An Organization author may draft a version. Submission freezes its reviewed content; a PlatformAdmin approval matching the content hash is required before a release can be published. |
| Building access | A Building is `Private` by default. A Trainee who verifies its current participation code gets an account-bound grant at the current access revision. Rotating/revoking the code or changing visibility invalidates prior grants. |
| Training start | A session start rechecks access, published/approved scenario content, an active Building entitlement and learner-seat capacity. A started session pins the entitlement, review and rubric and may reconcile after later expiry or access loss. |
| Commercial | Each Building line is 6 or 12 months and snapshots package, game service, learner limit, AI quota, price and terms. A quota-bearing line pins a tenant-valid quota policy, unit and validity that cover its grant interval before issue; committed service periods cannot overlap. Payment provisioning is idempotent, including a replay after expiry. Capacity upgrades do not retroactively recalculate seats. |
| AI quota | Organization package/top-up grants are prepaid and pooled; Trainee daily grants are separate. A request reserves available quota before billable work and settles idempotently. There is no postpaid period, overage consent or automatic debt. |
| Learner RAG | Only an approved, published and currently authorized scenario may be retrieved. Its indexed learner snapshot is exactly `name`, `objectives`, and `instructions`; drafts, rubric, answers and private BIM/IFC data are excluded. |
| Assessment | The server records rubric hash, criterion results, outcome and explanations. A completed session is not automatically a pass; v7 deliberately creates no certificate. |

## Operational gates

1. Author edits a new scenario version; submission stores the reviewed content hash.
2. PlatformAdmin approves or rejects that exact hash. A material edit requires a new version/review.
3. Publish requires the matching approved review. The index worker may create/update the learner-safe RAG snapshot only then.
4. A private Building code grants access to that Trainee account only. `access_revision` makes old grants ineffective after a security change.
5. Prepare/list checks access. Start additionally pins the approved content and allocates a unique learner seat against the active entitlement.
6. Payment webhook provisions each Building line or AI top-up once. AI work reserves then settles existing quota; failure releases reservation.
7. Every learner RAG retrieval repeats authorization. After loss of access, the learner may retain their own completed-result explanation and common knowledge, but receives no new Building/scenario retrieval.

## Main schema objects

- Auth: `registration_email_challenges`, `registration_otp_email_jobs`, `device_installations`, `local_password_reset_tokens`, `password_reset_email_jobs`.
- Library and review: `organization_library_items`, `organization_library_versions`, `scenario_content_reviews`.
- Private access and commercial capacity: `building_participation_grants`, `building_learner_seats`, `entitlement_capacity_upgrades` plus v7 columns on `buildings`, `service_entitlements`, `sessions`, quotation lines and scenario versions.
- Prepaid AI: `quotation_ai_quota_items`, v7 provenance on `ai_quota_grants`, `ai_usage_reservations` and allocation tables.
- Learner-safe index: `scenario_knowledge_documents`.

## Organization phone uniqueness

`organizations.phone` (not `phone_number`) has a unique expression index `organizations_phone_normalized_key` on `regexp_replace(phone, '[^0-9+]', '', 'g')`, excluding only NULL. Valid input is trimmed, allows separators space/hyphen/parentheses, and retains an optional leading plus and 6–15 ASCII digits. No country-code inference: `0…` and `+84…` remain different. Inactive and soft-deleted organizations reserve their phone; legacy/admin NULL phones remain valid. Personal `users.phone_number` is independent.

Email and Google organization registration return 409 `ORGANIZATION_PHONE_EXISTS` with `errors.organizationPhoneNumber`; organization PATCH uses `errors.phoneNumber`. Failed mutations do not consume proof, create owner/organization/receipt/session/audit, or increment profile revision. Corrected requests can reuse unexpired proofs. Keeping one's own number is valid; ETag semantics are unchanged.

For an existing database, additive BE migration `20261006110000_AddOrganizationPhoneUniqueness` first checks all non-NULL legacy phones with a masked read-only preflight. Invalid or duplicate canonical data blocks deployment; no automatic merge/delete/reformat or ETag change is allowed. The migration locks writes, rechecks and creates the index in one transaction. Deploy constraint-aware error mapping before the index; do not grant the API extra organization visibility. The design schema and disposable tests do not prove Supabase or a deployed binary is upgraded. [BE rollout/manual tests](../BE/docs/organization-phone-manual-test.md).

## Verification boundary

The schema has been syntax-loaded against a disposable PostgreSQL instance using a local stand-in type for `pgvector`; production still needs an environment with the actual extension and integration tests for payment webhook, session start, RAG retrieval and concurrent seat/quota reservations. The detailed design and unresolved policy values remain in [requirements](fire_evacuation_requirements.md) and [business decision analysis](phan_tich_khoang_cach_va_quyet_dinh_nghiep_vu.md).
