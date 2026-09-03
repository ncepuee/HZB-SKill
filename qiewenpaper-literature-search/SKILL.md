---
name: qiewenpaper-literature-search
description: Use the user's logged-in 切问学术 (Qiewenpaper) account to search, compare, summarize, and retrieve academic literature through the website.
---

# 切问学术文献检索

Use this skill when the user asks for literature discovery, paper comparison, research-topic exploration, citation lookup, or paper summaries through 切问学术.

## Session and safety

- Use the existing logged-in page at `https://qiewenpaper.com/app/search` in the in-app browser. Prefer claiming an already-open matching tab instead of opening a duplicate.
- Before searching, verify that the search box is present and the account is still signed in. If the session has expired, ask the user to log in again.
- Never request, copy, save, expose, or inspect passwords, OTPs, cookies, local-storage tokens, or authorization headers. The account ID is not an API credential.
- Do not run an unrequested test search during setup. A user-requested search may consume account credits; disclose that possibility when the selected operation is materially credit-intensive.
- Do not change plans, purchase credits, upload files, or alter account settings unless the user separately requests that action and the applicable confirmation requirements are satisfied.

## Search workflow

1. Translate the request into keywords, time range, field, document type, language, and desired output. Ask only for missing choices that materially affect the result.
2. Use the site's visible search UI. Use Quick for a focused lookup and Deep when the user asks for a broad synthesis, trend analysis, or multi-step literature discovery; honor an explicit mode choice.
3. Collect paper title, authors, year, venue, DOI or other identifier, abstract/summary, source URL, and the reason each paper is relevant. Keep platform-generated summaries distinct from the paper's own abstract or full text.
4. For a literature review, deduplicate results, group them by theme or method, and state search scope and limitations. Prefer DOI, publisher, arXiv, or other primary links when available.
5. Do not write results into the Obnotes wiki unless the user asks. If asked, follow the wiki's frontmatter, wikilink, index, log, and hot-cache conventions.

## Internal API reference

The site currently uses an internal gateway and SSE search endpoints. Read [references/api.md](references/api.md) only when troubleshooting the site's calls or when the user explicitly asks about API-level behavior. These endpoints are implementation details, not a promise of a public developer API; do not use them to bypass authentication, paywalls, rate limits, or credit accounting.
