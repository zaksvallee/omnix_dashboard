# Client brand and taxonomy increment — 23 October 2026

Read both pages of the supplied typography/colour PDF and visually reviewed all seven pages of the category PDF. Source originals are retained under references with Library identity. Fonts are self-hosted from Google Fonts' official google/fonts repository, with OFL notices retained in public/fonts.

Applied palette: Brand Yellow #FED009, Forge Black #111111, Clean White #FFFFFF, Steel Silver #B4B4B4. Inter 800 for headings; Inter 700 for labels/navigation; Barlow 600 body. Secondary neutral surfaces and darker text colours support readable contrast; silver is a border/decorative token, not small body text on white. The typography sample's italic headline is illustrative; the supplied written hierarchy is implemented with upright Inter Extra Bold.

The category model contains seven departments and 297 total nodes, including nested display sizes/skins. Client labels are preserved, including 'Stationary Sets' and both Headwear/Hospitality placements; any editorial correction needs a deliberate source change. IDs include the complete ancestor path so repeated names (Footwear, Accessories, Skins) do not collide. Root filters include descendants. Full hierarchy is selectable from a labelled native select for keyboard/mobile use. Discovery examples are mapped to appropriate branches; these assignments are preview examples, not supplier classification or stock.

Implemented locally: src/categories.mjs, catalogue descendant filtering, department navigation, full category selector, brand tokens and self-hosted fonts. Existing discovery status and no-payment behavior remain explicit. No supplier credentials were used, and no live inventory, server-side quote persistence, CRM, artwork workflow or checkout is claimed by this increment.

Supplier research is in supplier-integration-plan.md. Captivity registration still needs the approved account-creation flow; Barron intake and the backend credential resolver remain outstanding. Videos and remaining supplied imagery still need review. The existing hero uses a network asset and is not yet final art direction.

Verification: automated catalogue/HTTP-handler tests, taxonomy parent/identity/filter tests and local font route checks. Frontend browser/mobile layout testing and deployment remain pending. Existing Seamless production and ONYX live onboarding have not been modified by this increment.
