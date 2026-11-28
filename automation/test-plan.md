# E2E acceptance
1. Read existing scheduled/published posts including manual posts; reject occupied or expired slot and daily limit.
2. Read genuine newsletters and reconcile paginated label counts and catalog.
3. Verify topic novelty, official sources and code.
4. Render HTML/CSS, inspect every PDF page, record hashes.
5. Commit both article.md and carousel.pdf and read back bytes.
6. Schedule RAW PDF in Zernio, verify account, caption, media, time and ID.
7. Record hashed provenance in the public catalog and label/archive genuine emails only after success prerequisites.
8. Persist SUCCESS only after all readbacks.
Negative cases: occupied slot, expired slot, renderer missing, overflow, GitHub failure, ambiguous schedule response, archive failure. Never claim a live E2E pass from a mock or preflight.
