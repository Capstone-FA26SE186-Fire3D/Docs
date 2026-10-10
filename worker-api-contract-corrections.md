# Selected BE worker and mutation corrections

This implementation changes the selected worker/API safety contracts without implementing learner lifecycle or training analytics. Baseline descriptions and schema design alone do not certify a deployed binary.

- Legacy pending-registration cleanup uses a bounded restricted-owner SQL gate, preserving verified accounts and accounts/organizations with business or audit references. OTP-before-registration has no unverified account to delete. API has no general DELETE on users/organizations.
- Avatar finalize/delete enqueues cleanup transactionally. Runtime uses enqueue/claim/reference/renew/complete/retry gates; the reference owner sees protective rows under RLS. S3 is called outside DB transactions. Protected jobs stay queued; stale leases cannot acknowledge newer claims. NotFound is success; temporary failures retry. Logs omit raw object keys and provider payloads.
- Technical confirmation/rejection and content submit/approve/reject, catalog/discount/quota-policy and enterprise mutations recheck lifecycle, actor and an owned live JWT family under locks. Family is internal and excluded from canonical receipt hashes. The old family-less readiness gate fails closed; caller permissions are checked before replay.
- Editor preview signs a five-minute URL only after S3 HEAD confirms the recorded artifact size. Missing/mismatch returns NotReady; provider access/timeout/service failure returns503 PREVIEW_STORAGE_UNAVAILABLE. HEAD does not certify SHA-256, QA or publication.
- Annotation anchors use accepted current Geometry provenance. GET/PUT expose ETag; PUT requires If-Match with428/400/412 semantics. No fabricated BIM facts table is introduced to satisfy tests.
- New readiness/approval audit records expose allowlisted status, exact-pair IDs, actor and times. Reasons, content/rubric hashes, PII, tokens and raw JSON are excluded. Legacy records without the recognized audit contract remain metadata-only; no backfill.
- OpenAPI required headers and success response headers are declared on endpoints, eliminating controller allowlists that omitted annotations. The route inventory is source metadata, not an acceptance checklist.

Rollout the four forward BE migrations (pending cleanup, Avatar cleanup, live readiness family, readiness audit) before the matching API/worker binary. Grants revoke old direct account/queue writes; do not leave old workers running. Runtime/executor identities receive only their gate/read/write scope, never ledger DML or superuser. Non-superuser migration transfer must restore temporary membership and schema CREATE rights.

Docker PostgreSQL/Redis and fake S3/worker tests certify only the tested source/database contracts. Supabase/Azure rollout, real provider/toolchain, frontend and learner acceptance are separate. Publishing already has an explicit paid-service/approval/readiness/package gate with a default-off feature flag; it is not an unconditional503 placeholder. Trial cannot publish. Operations analytics does not substitute for learner plays/completion/duration.

BE manual: `docs/api-worker-contract-manual-test.md`; permissions: `docs/worker-permissions.md`; inventory: `docs/api-route-inventory.md`. These new gates have not been applied to Supabase in this batch.
