# Google Play feature graphic — selected raster and vector alternative

Reviewed 2026-11-01. Candidate artwork only; no store upload or publishing performed.

The owner selected the original AI-generated design after comparing it with the vector recreation. Use `feature-graphic-preferred-1024x500.png` for Google Play. `feature-graphic-preferred-original.png` preserves the original 1794×876 artwork. Both retain the detailed gradients and two-line primary tagline shown in the selected banner. There is no equivalent editable SVG for this design.

## Removed previous files

- `feature-graphic.png`: the green wordmark replaces the approved navy/gradient artwork; “Your phone number is your email” is not one of the registered brand messages. The rounded icon tile and its shadow also give this composition a different treatment from the unframed brand lockup. Its pale mint/cyan background is compatible with the brand, but does not correct the wordmark and copy differences.
- `feature-graphic-1024x500.png`: uses the approved vector logo, primary tagline, ice background, and emerald/cyan accents. It is already brand-consistent. The proposed change improves hierarchy and whitespace; the existing colors are not a defect. Its long horizontal lockup leaves less room for a prominent product message.

## Alternative vector recreation

- Editable, self-contained source: `feature-graphic-v2.svg`.
- Uses the original `assets/brand/source/wordmark.svg` and `mark-full-color.svg` paths and gradients. IDs are namespaced only to avoid SVG collisions; the artwork is not redrawn, stretched, clipped, or recolored.
- Copy: “Your number. Your inbox.” and “Email, reimagined with your number.” Both are approved messages in the platform branding specification.
- Headline and supporting copy use outlined Inter from the website's local `InterVariable.woff2`, at weights 800 and 450. The SVG needs no font download.
- Text: navy `#0F172A` and slate `#475569`. Background: ice `#F5F7EB`, cyan tint `#D7F6FB`, and low-opacity emerald `#10B981` / cyan `#06B6D4` accents. Original logo gradients retain their approved blue highlights. The darker mobile button gradient is for interactive controls and is not a requirement for decorative backgrounds.
- Removes the repeated small N from the generated layout, keeping one unframed mark. Adds no invented app UI, feature claims, phone numbers, badges, or calls to download.
- Keeps essential lettering and mark away from the outer edges. Visually inspected at the exported size.
- The previous `feature-graphic.png`, `feature-graphic-1024x500.png`, and `feature-graphic.svg` have been removed. The app's shared brand masters remain unchanged.

Google currently requires 1024 × 500 pixels and JPEG or 24-bit PNG without alpha: <https://support.google.com/googleplay/android-developer/answer/9866151?hl=en>. The final PNG was checked for dimensions and PNG encoding. This is format verification, not Google approval. Google also recommends prioritizing the value proposition, avoiding icon duplication and fine detail, and keeping key content away from crop zones.

Re-export the self-contained source with librsvg:

```sh
rsvg-convert -w 1024 -h 500 docs/store/play/feature-graphic-v2.svg -o docs/store/play/feature-graphic-v2-1024x500.png
```

`tool/branding/generate_play_feature_graphic.py` exports the selected original raster to `feature-graphic-preferred-1024x500.png`. It does not generate this vector alternative or the removed layout.

## Generation provenance

The selected raster was created with the built-in image generation tool using the approved feature graphic and September brand board as references. A separate vector alternative was composed from the existing vector masters and outlined local Inter. The SVG is the reproducible source for that alternative only; the owner prefers the AI-generated raster's richer finish.

Initial concept prompt:

> Use case: ads-marketing. Create ONE refined Google Play feature graphic for NumberInbox, as a finished flat rectangular banner, target exactly 1024 x 500 pixels, aspect ratio 2.048:1, fully opaque RGB, no outer border. Input image 1 is the authoritative production N/@ logo and outlined NumberInbox wordmark: reproduce the recognizable mark geometry, white @, native green-cyan-blue gradients and exact wordmark shape faithfully. Input image 2 is supporting brand/style reference only, not content to reproduce. Do NOT reproduce the brand board, phones, UI, color swatches, tiny labels or page panels. New composition: elegant white #FFFFFF background, very subtle pale emerald/cyan atmospheric accents confined to the far right edge, lots of intentional whitespace. Left 60 percent: approved NumberInbox wordmark at upper-left with generous clear space, Number in deep navy #0F172A, Inbox in the production blue-to-cyan-to-emerald gradient. Under it, large crisp deep navy modern sans serif headline on two lines, exact text: 'Your number.' then 'Your inbox.'. Under headline a smaller but clearly readable approved primary tagline on two lines, exact text: 'Email, reimagined' then 'with your number.' in slate #475569. Right 35 percent: one large unframed N/@ mark matching image 1 perfectly, comfortably centered vertically, fully visible, not cropped, no circle, no rounded square container, no fake 3D or recoloring. Keep all essential artwork and lettering at least 60px from outer edges. Brand decorative colors #10B981 emerald and #06B6D4 cyan, logo's native blue highlights permitted. Mood minimal, premium, approachable, consistent with a real email product. Exact casing NumberInbox. No green text, no extra slogans, no claimed security features, no phone numbers, no store badges, no download buttons, no ratings, no watermarks. Do not distort or stretch the mark. Professional optical alignment, clean bold typography, beautiful spacing. This is a feature/banner graphic, not a simulated app screenshot. Deliver only the single full-bleed banner.

Final adjustments after the concept: use the exact vector wordmark and mark, remove the duplicate N, use the approved ice-to-cyan background instead of pure white, and keep the primary tagline on one readable line.
