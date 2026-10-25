# Seamless Workwear independent development build

Read ../PROJECT-INDEX.txt and ../04-build/BUILD-PLAN.txt. The user confirmed an independent backend on 25 October 2026.

Requires Node >=22.13. Run `npm test`, then `npm run smoke` and `npm start`. Development server listens on 127.0.0.1:4318. Actual source is here; the legacy seamless-workwear-dev path is a compatibility symlink.

Implemented: brand/category browsing, requested apparel colour/size quantities, unpriced quote requests saved in independent SQLite, private token-scoped status lookup, staff review queue with revision history and stale-update checks. Retry with the same request token and payload returns the same request. Source catalogue entries remain clearly labelled discovery examples. Requested sizes/colours are preferences, not verified stock variants.

Database: runtime/seamless.sqlite, private mode 0600, ignored by Git. Do not commit/attach this database. Production hosting, backups and retention are pending.

Staff review: `/staff`. Supply a random access key of at least 32 characters in the process environment as SEAMLESS_STAFF_TOKEN before starting. The .env.example is a configuration example only; npm start does not automatically load it. Never commit the real key. Browser holds it in memory and clears the input. With no key configured, staff endpoints fail closed. This development key is not individual staff login/RBAC.

Saved requests: contact email is unverified. Access token is saved in browser-tab session storage where available. It grants access to that request; the database keeps only its hash. No quote email is sent, no supplier order is made and no payment is collected. An unpriced request is not a formal commercial quotation or order. Staff review cannot release production or mark payment successful.

Pending: videos/assets and browser layout QA, authorised supplier feeds, authoritative pricing/stock, durable commercial quote snapshots, real identity/RBAC, CRM tasks, artwork approval, payment/email/AI integrations and launch operations. The ONYX onboarding vault remains separate and unchanged. No Seamless production/DNS changes.

Source delivery: run `sh 10-operations/push-verified.sh` from the project root, or use the full path. The helper requires normal GitHub/network access, Git metadata writes and loopback listeners. This restricted session passes unit/handler tests but cannot complete real HTTP smoke or source push.
