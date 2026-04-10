Place approved face gallery images here for ONYX face recognition.

Recommended layout:
- `tool/face_gallery/SITE-MS-VALLEE-RESIDENCE/MSVALLEE_RESIDENT_ZAKS/MSVALLEE_RESIDENT_ZAKS_1.jpg`
- `tool/face_gallery/SITE-MS-VALLEE-RESIDENCE/MSVALLEE_RESIDENT_ZAKS/MSVALLEE_RESIDENT_ZAKS_2.jpg`
- `tool/face_gallery/SITE-MS-VALLEE-RESIDENCE/MSVALLEE_REGULAR_VISITOR_CLEANER/MSVALLEE_REGULAR_VISITOR_CLEANER_1.jpg`

Legacy layouts also still work:
- `tool/face_gallery/RESIDENT-01/front.jpg`
- `tool/face_gallery/VISITOR-44/frame-1.png`

Rules:
- In the site-scoped layout, the second folder name becomes the `face_match_id`.
- In the legacy flat layout, the top-level folder name becomes the `face_match_id`.
- You can also place a single image directly in this folder and name it like `RESIDENT-01__front.jpg`.
- Use clear, front-facing images with one dominant face per file.
- Add 2-5 images per identity if possible, with small angle/lighting variation.

Runtime notes:
- ONYX reloads the gallery automatically when files change.
- Face recognition will remain `enabled` but `not ready` until at least one usable face image exists here.
