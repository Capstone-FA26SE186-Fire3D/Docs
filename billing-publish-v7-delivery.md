# Billing v7, publication and operational reporting — delivery contract

This records the product decisions for BE branch `feature/publish-billing-v7-reporting`. Source/Docker acceptance is distinct from a deployment or real provider/runtime acceptance. It supplements v7 requirements, workflow and technology; it does not declare the whole target schema or learner pipeline implemented.

## Commercial policy

- New catalog packages are six or twelve calendar months. `unitPrice` means monthly VND price; subtotal is price times duration before discount. Admin configures price, positive learner limit, nonnegative AI quota and explicit quota unit/policy. Nothing seeds real business values.
- Quota policy versions are immutable, audience organization, kind quota. Positive quota requires a policy covering the entire service interval. An unused remainder expires with its grant; it never rolls over to Renewal.
- Issue freezes price/revision/capacity/quota/policy/terms plus absolute UTC `[startsAt,endsAt)` per quotation line. New starts at an Admin-selected future time; continuing Renewal starts at the last committed end; expired Renewal needs a future start. EndsAt adds calendar months in UTC. Payment deadline cannot exceed the earliest line start. Catalog edits do not modify an Issued snapshot.
- Upgrade, top-up, AI reserve/consume, learner seat allocation, reminders, revenue and refunds are separate backlog. Capturing learnerLimit does not allocate a learner seat.

## Checkout and provisioning

Before contacting PayOS, PostgreSQL reserves each Building interval. Reserved/Consumed intervals cannot overlap; local timeouts alone do not free them. Provider-confirmed unpaid cancellation/expiry can release a reservation. Durable existing legacy checkout recovery stays enabled; incomplete legacy quote/package snapshots cannot start a new checkout.

Verified money remains Paid/Applied even when provisioning cannot proceed. Snapshot service period, capacity and optional pooled organization quota grant commit with line status/audit under stable payment/line provenance. Grants keep their own interval and do not change historic entitlements. Duplicate delivery/retry does not add grants. Late money outside the agreed period or with a released/invalid reservation remains visible as NeedsReconcile; BE never silently moves dates or refunds it.

The current BE uses dedicated immutable `billing_quota_policy_versions` and `billing_ai_quota_grants` for this limited commercial scope. These do not implement the target AI request/reserve/settle pipeline. Legacy entitlements do not acquire invented seats/quota.

## Publication

Publishing is an explicit gated transition Built → Published. OrganizationUser acts in its tenant; PlatformAdmin uses administrative scope. The transaction rechecks live family and lifecycle, matching active Training, currently effective paid Building service, exact approved scenario/rubric hashes, revision–version–validation–annotation confirmation, current accepted package/manifest attempt and runtime compatibility. Trial alone cannot publish.

Publication/receipt/audit commit together; an authorized Published replay has no further effects. Revoked cannot be republished. Business prerequisites return409; disabled rollout returns503; success204. `Publishing:Enabled` defaults false until migration/grants/binary smoke tests pass. A valid legacy paid entitlement can authorize publishing without synthesized quota/seats. Publication does not certify real Unity execution or authorize learner launch.

## Read views and rollout

Audit is PlatformAdmin-only, immutable, with named action/target filters, stable pagination and safe allowlisted changes. Unknown legacy audit returns metadata and empty changes. No raw JSON, credentials, tokens, signed URLs, PII or support content is exposed.

Operations analytics use one read-only PostgreSQL RepeatableRead snapshot including authorization and one asOf. Platform reports account/organization/Building status plus historical creation and processing/ticket distributions; organization reports tenant Building/processing and only caller-created tickets, with no account aggregate. UTC `[from,to)`, default30/max90days, known empty buckets zero. These are not learner play/completion or revenue metrics.

Migrations are additive and preserve data. Duplicate/overlap preflight failure stops rollout; no data is reset or silently merged. Update every API/worker instance before enabling v7 sales, then enable publish after gate smoke tests. Docker/fake-provider tests do not prove Supabase, PayOS/webhook, S3, Unity or frontend acceptance. Source API inventory is generated from OpenAPI.
