> Architecture update, 25 October 2026: the user selected an independent Seamless backend/database. Reuse reviewed adapter/calculation code; earlier shared central-engine hosting language below is historical and superseded.

# Seamless supplier integration investigation

Research date: 23 October 2026. Internal implementation plan, not client documentation.

The client reports receiving the onboarding invitation and intends to complete it. No credential values were read, no supplier account was created, and no supplier email or registration was submitted during this investigation.

## Architecture and reuse

Supplier-approved APIs/feeds -> tenant-scoped ONYX Central Engine -> Seamless server -> storefront and authenticated staff workspace.

Reuse connector code and canonical contracts, never another retailer's credentials, prices, account tier, captured product data or private database. Existing Amrod/Barron code is a starting point, not certification of Seamless pricing. Do not fork the central engine into the website or call supplier endpoints from the browser.

Reviewed implementation:
- central-commerce-engine/amrod.py
- central-commerce-engine/barron.py
- central-commerce-engine/credential_resolver.py
- central-commerce-engine/contracts/retailer-api-guide.md
- onyx-creative-hosted/worker/client-setup.mjs
- seamless-workwear-dev/README.md and docs/intake.json

## Supplier findings

### Amrod: existing REST connector

Official documentation: https://newapidocs.amrod.co.za/
Access application linked by the documentation: https://content.amrod.co.za/new-api-access-request

The existing adapter uses UserName, Password and CustomerCode to authenticate at identity.amrod.co.za/VendorLogin. The current documentation describes one-hour bearer tokens. Match product price and stock using exact variant fullCode, not parent style or product name. The documented daily maintenance window is 00:00–01:00 South African time, with empty 204 responses: retain last good data rather than delete the catalogue. Distinguish each feed's update schedule; do not promise universal real-time stock or a blanket 30-minute refresh. Missing a daily change window requires full reconciliation.

Next: dedicated Seamless API-enabled user/customer code; confirm tier, data rights and endpoint manifest; read-only import into its own tenant; compare exact variant costs, branding/setup, promotion eligibility, stock and tax basis against the Seamless supplier account.

### Barron: existing SOAP connector

Official service operation list: https://wslive.kevro.co.za/StockFeed.asmx
Login definition: https://wslive.kevro.co.za/StockFeed.asmx?op=login
Paged branding definition: https://wslive.kevro.co.za/StockFeed.asmx?op=ListAllBrandingInformationPaged

The published service confirms category/product feeds, images, incoming stock, branding prices and paged branding information. Login parameters are TokenKey, username, psw, EntityName and entityID. The existing adapter additionally uses HTTP Basic credentials; confirm the issued account's requirements with Barron. Preserve SOAP session handling, pagination completion and duplicate-page detection. Use POST; never put credentials in query strings even where documentation shows GET examples.

INTAKE GAP: the live generic Barron form only has customer_code, api_key, api_secret, username and password. Before activation add explicit entity_id, entity_name, token_key, http_username and http_password fields, with clear optional/provider-issued instructions. Retain existing fields for compatibility; do not silently guess that customer_code means entityID or api_key means TokenKey. Replacing a saved service currently replaces its full encrypted payload; explain that behavior before requesting resubmission. No production form change has been made by this research task.

### Captivity: separate developer approval confirmed

Developer signup: https://www.captivity.co.za/developer/signup
Developer login: https://www.captivity.co.za/developer/login
Separate reseller registration: https://www.captivity.co.za/signup
Terms linked from developer signup: https://www.captivity.co.za/terms-conditions
Published web-support contact: web@captivity.co.za

The developer form requires first name, last name, display name, email, password confirmation, company name, country and acceptance of terms. Website and phone fields are present. It explicitly requires administrator approval before API access. The portal advertises product catalogue/pricing access and API-key generation. This does not establish stock, branding, order-write endpoints, request limits, approval turnaround or rights to use one developer key across unrelated reseller accounts.

Proposed applicant: ONYX Creative under ONYX Risk and Intelligence Group (Pty) Ltd, with Seamless identified as the authorised client. The account email and password must be established through an approved account-creation flow; no password should be supplied in chat. Obtain documentation after approval and confirm how Seamless's reseller account/price tier is linked. Ask about catalogue/variants, stock/incoming stock, account pricing, image rights, categories, branding costs/options, paging, deleted items, rate limits, update cadence, sandbox, permitted multi-client use and key rotation.

Developer approval and Seamless's reseller status are separate questions. A developer account alone does not prove permission to redistribute trade data across all ONYX tenants.

### G Fox and Salty: integration contract unconfirmed

Official sites reviewed: https://www.gfox.co.za/ and https://saltybushwear.com/
Salty's published contact: info@salty.co.za (https://saltybushwear.com/).

No public API contract or developer signup was verified in this investigation. The web retrieval surface returned 403 for G Fox; a separate ordinary public-page request succeeded but exposed no useful integration links. This is not proof that no API exists. Salty's public retail site/catalogue is not evidence of a wholesale integration entitlement.

Ask each supplier/account representative for an approved API or scheduled CSV/XML/SFTP export, account-specific pricing, exact variant identifiers, stock/freshness, images/use permission, tax basis and branding data where offered. If only approved files exist, implement a versioned file adapter into the same canonical model. Do not invent endpoint URLs, copy public retail pricing into trade costs, or substitute scraping for an agreed feed. Keep unsupported items unavailable for checkout/manual quote review until evidence is sufficient.

## Credential and engine activation gap

The onboarding portal encrypts submissions and exposes saved status only. Its current implementation has no scoped worker credential-consumption/decryption path. Saving a key is not connecting a supplier. Implement a backend-only resolver bound to project, supplier, purpose and authorised job; never expose decryption through HTTP, staff UI, browser storage, logs or model context. Check the envelope key version and AAD, preserve separate recovery, and audit metadata only. Do not retrieve submitted real keys merely to inspect the onboarding form.

## Build sequence

1. Read the client category PDF and walkthrough videos; replace temporary navigation only after confirming their actual requirements. Asset transfers/browser QA were previously blocked; newer network-enabled tooling may unblock them, but they have not been re-reviewed in this investigation.
2. Establish the Seamless tenant and website-server integration identity; maintain separate runtime storage, retailer policies and account bindings. Reuse the central v2 catalogue/configuration/cart API contract, including null/held prices and scoped permissions.
3. Correct provider-specific intake, add the private worker resolver, then prove Amrod and Barron authentication/read-only imports with Seamless credentials. Register Captivity and await its documented approval/permissions in parallel. Obtain G Fox/Salty integration packs.
4. Normalise parent/variant identity, category mapping, images, source timestamps, stock, tax basis, branding methods/positions/dimensions, quantity bands, setup scope and inclusive eligibility. Quarantine incomplete/conflicting records. Stage and reconcile before atomically publishing accepted snapshots; retain the last good snapshot on failed/empty refreshes.
5. Implement apparel colour/size quantity matrices and aggregate style quantities; let the central engine authoritatively calculate prices and valid branding. Client-side totals are previews only. Preserve supplier/account-specific exceptions and minimum-margin holds.
6. Build a shared basket with durable immutable quote revisions and checkout review; quotes have expiry and stock availability is not a reservation. Recheck expired/changed prices and stock before acceptance/payment. Bulky/outlying freight goes to review; standard delivery values require explicit commercial configuration.
7. Implement customer accounts and staff CRM, enquiry ownership, quote/invoice records and operational order states. Upload artwork at quote/order; version proofs and capture explicit approval. Release production only after payment/approved terms, proof approval and operational checks. Keep supplier purchasing manual until a separately verified order API/workflow exists.
8. Integrate Ozow test mode with signed/verified callbacks and idempotent reconciliation; configure Resend domain/reply routing and delivery events. Add the OpenAI assistant behind scoped tools after its credential setup, with grounded catalogue answers and staff handoff. Google account IDs are onboarding references; OAuth permissions, budgets and marketing automation remain separate decisions.
9. Complete mobile/customer/staff acceptance, monitoring, backup/restore evidence and cutover checks before live commerce. No live website, DNS, merchant configuration or supplier purchase was changed by this research.

## Current decision

Begin foundation and customer/staff workflows while account access is pending. Prioritise Amrod/Barron integration reuse and Captivity approval. Do not promise five live APIs or automatic supplier ordering before the missing supplier contracts are verified. The current Seamless folder remains an isolated discovery prototype; this research adds a build plan, not completed commerce or new connectors.
