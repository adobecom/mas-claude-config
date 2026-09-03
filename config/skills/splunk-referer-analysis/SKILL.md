---
name: splunk-referer-analysis
description: Analyze a Splunk LANA CSV export for one referer URL and decide whether the errors are an authoring issue or a code issue, with direct calls to action.
---

Analyze the Splunk LANA export attached / referenced in the request and classify the
errors on that referer page as an **authoring** issue (content fragment misconfigured)
or a **code** issue (io pipeline / merch-card / mas.js bug), then give direct,
actionable calls to action.

Input: `$ARGUMENTS` — a path to the CSV export (or it is attached to the message).

## What the data is

Each row is a client-side LANA event. The payload lives in `_raw` → JSON →
`log_message`, a `¦`-separated list of `key=value` pairs (`¶` precedes `page=` and
`facts=`). `facts` is a JSON array of per-fragment telemetry: `aem-fragment:status`,
`aem-fragment:serverTiming` (cdn-cache HIT/MISS/REVALIDATE), `aem-fragment:stale`,
`aem-fragment:retryCount`, `aem-fragment:etag`. The `message` field holds the
merch-card error text.

## Workflow

1. **Parse.** Run the bundled parser (do not re-implement it):
   ```sh
   python3 "$(dirname skill)/parse_lana.py" <csv>
   ```
   It emits JSON: event count, time range, referer(s), locales, an id-normalized
   message histogram, `card_ids`, `culprit_fragment_ids` (ids named inside the error
   text — the fragments to fix), and `fetched_fragments` (per-fragment fetch health).

2. **Classify** each dominant message with the decision table below.

3. **Verify** the top culprit fragment(s) against production before asserting a cause —
   fetch the live payload and inspect the field the code actually reads:
   ```sh
   curl -s "https://www.adobe.com/mas/io/fragment?id=<id>&api_key=wcms-commerce-ims-ro-user-milo&locale=<locale>" | python3 -m json.tool
   ```
   Compare the `etag` to the one in the report; check `fields.variant`, fetch status,
   `path`, `model`, and **`tags`**. A 200 + cdn HIT + stable etag means delivery is
   healthy and the fault is in the content or the client.

4. **Check whether the culprit is a variation** (see "Variations must never be served
   directly" below). This changes both the root cause and who owns the fix.

5. **Report** in the output format below. Lead with the verdict.

## Variations must never be served directly

**Core rule: a variation — promotion or grouped — must never be accessed directly.**
A variation is a partial overlay meant to be merged onto its base card; only the base
carries the card layout (`fields.variant`). So a variation served standalone has no
variant and hydration throws `no template found in payload`. **The missing variant is
the symptom; the root cause is that a variation is being rendered on its own** —
typically because MEP / personalization (or a hand-built link) points at the variation
id instead of the base card id.

Signals that the culprit fragment is a variation (from the live fetch, step 3):

- `path` sits under a `/promotions/<campaign>/` folder → **promotion variation**.
- `tags` include `mas:promotion/*` (promo) and/or `mas:pzn/*` (personalization target).
- Grouped variations follow the same rule — same fix, different origin.
- Corroborating (from the parser): `referer_query_keys` show campaign/paid-media
  markers (`sdid`, `mv2`, `gclid`, `mep`, …), consistent with a promo/MEP landing.

When these signals are present with a missing variant, classify the root cause as
**"a variation is being served directly"**, not "author forgot the layout". The fix is
to stop pointing at the variation (point MEP / the link at the base card so the overlay
merges correctly), and the recurring-risk note applies: any promo/grouped variation
reachable by a direct id is one MEP mistarget away from this same failure.

## Decision table

Ground truth for the merch-card messages is `web-components/src/hydrate.js`.

| Message / signal | Meaning | Verdict |
|---|---|---|
| `no template found in payload <id>` + culprit is a **variation** (promo/grouped — see signals above) | a variation is being rendered standalone; it has no variant because the base does | **AUTHORING** — a variation is being served directly (MEP/link points at the variation, not the base card) |
| `no template found in payload <id>` + culprit is a **base card** | `fields.variant` is empty on the base fragment (`if (!variant) throw`) | **AUTHORING** — base card published with no card layout selected |
| `variant mapping not found for <id>` | `fields.variant` is set but has no registered layout | **MIXED** — typo variant = authoring; brand-new variant = code (missing mapping) |
| `Fragment is undefined` / `is missing 'fields'` | fetch returned empty/blank payload | **CODE / pipeline** (or deleted id) — check fetch status |
| `AEM fragment cannot be loaded` | fetch failed | inspect `fetched_fragments.status` (below) |
| `MERCH-CARD/MAS-FIELD did not initialize … timeout` | element never upgraded / hydration never ran | **CODE / client** (script load, timing) — usually secondary to a primary error |
| fetch `status` 404 | fragment unpublished / deleted / wrong id | **AUTHORING** — broken reference; publish or fix the ref |
| fetch `status` 401/403 | auth / api_key | **CODE / config** |
| fetch `status` 5xx / 504 / timeout | io pipeline failure | **CODE / pipeline** — see [[project_fragment_504_floor_state_metadata]], [[project_mwpw_203268_iowww_perf]] |
| high `retryCount` / `stale=true` / many `REVALIDATE` | cache thrash / origin unhealthy | **CODE / pipeline** |
| `status` 200 + cdn HIT + a client error message | delivery healthy | **AUTHORING or client CODE** per the message |

## Output format

**Do the classification and verification with the full technical picture, but tailor
the report to the audience of the verdict.**

### When the verdict is AUTHORING

The reader is a content author, not an engineer. Strip all technical detail — no code
paths, field names, etags, cache/status codes, fragment ids, or internal file names.
Say plainly what is wrong on which page and what a person must do to fix it. Keep it
short and human.

```
## <page URL> — content needs a fix

Users on this page are seeing broken cards (<N> errors, <start>–<end>).

**What's wrong:** <one plain sentence — e.g. "A card on this page was published
without a card layout chosen, so it can't display.">

**What to do:**
1. <imperative human step — open <page/promo name> in Studio and choose the card layout>
2. <republish so shoppers see it>
3. <check the other cards in the same set for the same gap, if relevant>

Owner: <team/person who authors this content, if known>
```

No MWPW code ticket for an authoring verdict. Do not mention `hydrate.js`, `variant`,
etags, or HTTP codes.

### When the verdict is CODE or MIXED

The reader is an engineer. Include the evidence:

```
## Splunk referer analysis — <referer base URL>
**Window:** <start> → <end> · **Events:** <N> (<severity>) · **Locale(s):** <...>
**Verdict:** CODE | MIXED — <one-line root cause>

### Evidence
- Dominant message: "<msg>" (<count>/<N>)
- Fetch health: <status / cdn / stale / retryCount / etag>
- Suspect area: <io/www, hydrate.js, mas-commerce-service, …>

### Calls to action
1. <concrete engineering step>
2. Propose a MWPW ticket (offer to run the `mwpw-ticket` skill).
```
