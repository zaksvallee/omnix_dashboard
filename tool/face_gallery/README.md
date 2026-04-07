Place approved face gallery images here for ONYX face recognition.

Recommended layout:
- `tool/face_gallery/RESIDENT-01/front.jpg`
- `tool/face_gallery/RESIDENT-01/profile.jpg`
- `tool/face_gallery/VISITOR-44/frame-1.png`

Rules:
- The top-level folder name becomes the `face_match_id`.
- You can also place a single image directly in this folder and name it like `RESIDENT-01__front.jpg`.
- Use clear, front-facing images with one dominant face per file.
- Add 2-5 images per identity if possible, with small angle/lighting variation.

Runtime notes:
- ONYX reloads the gallery automatically when files change.
- Face recognition will remain `enabled` but `not ready` until at least one usable face image exists here.
