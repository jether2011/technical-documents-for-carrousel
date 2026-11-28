# Yellow Signal — LinkedIn Carousel Design Contract

Based on the user-supplied **Carrossel PDF Yellow Signal** instructions. Applied to English-language technical LinkedIn content; English overrides the source skill's PT-BR default.

## Visual system
- 1080 x 1350 CSS px / 4:5 pages, all pages identical; safe margin 80px.
- Tech-dark default: background `#0F1116`, cards `#1B1F29`, borders `#2B303B`, text `#F7F5EE`, support `#B7BCC8`.
- Yellow accent `#F6C915`, with `#F0B90B`, `#D9A400` as supporting accents where needed.
- Font: **Inter** family, regular/bold/extra-bold, embedded in vector PDF where supported.
- Headline 72–96px, one highlighted line/keyword in yellow; eyebrow 24px uppercase; body 34–40px, card secondary >=32px, footer 22px; contrast >=4.5:1.
- Rounded cards radius 16–24px; generous internal spacing, a single clear idea per slide.
- Varied layouts: statement, two-column comparison, process/flow, bounded checklist, call-to-action. Avoid monotonous templating.
- No invented logos; use neutral "ENGINEERING INSIGHTS" editorial label.
- Yellow thin progress line and n/N footer on every page.

## Publishing checks
1. Write original English content and verify technical claims against official sources.
2. Script 7–10 pages (typically 9), <=8 words/title, <=30 body words/slide.
3. Generate vector PDF using source HTML/CSS or equivalent vector generator.
4. **Render all pages to images and inspect** text fit, margins, fonts, contrast and consistency.
5. Confirm PDF exists, page count/dimensions, Github RAW URL is accessible, and article.md is present.
6. Add the GitHub directory URL as the final line of the LinkedIn caption; use RAW PDF URL only as Zernio media.
7. Never publish if PDF or Markdown fails; do not claim direct native skill activation if only specifications were applied.
8. Archive source newsletter after reading/recording, keeping THE_TURTLE_CODE label and internal provenance; deduplicate by Gmail ID and Zernio post ID.

## Workflow unchanged
Daily analysis at 11:00 (post at 18:00 same day) and 20:00 (post at 08:45 next day), timezone America/Sao_Paulo. These slots belong to normal scheduled runs; a user-requested manual immediate publication is separate and must still check duplicates.
