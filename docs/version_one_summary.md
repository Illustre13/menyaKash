# Menya Kash — Product Review Board Assessment

**Reviewers**: Principal PM (Fintech) · Senior UX Researcher · Staff Mobile Architect · Flutter Tech Lead · Financial Systems Architect · InfoSec Architect · Data Architect · Personal Finance Expert · Digital Banking Consultant · Rwanda Fintech & Payments Consultant

**Method**: This assessment is grounded in a direct audit of the current codebase (schema at `schemaVersion` 6, 13 tables, 130 passing tests across 22 files, 5 seeded providers, 4-tab navigation), not the aspirational feature list in the brief. Every claim below distinguishes *what exists* from *what's proposed*. Where the brief assumes something is built and it isn't, we say so.

**First finding, before anything else**: the app's `git log` calls it "Menya **Cash**," `main.dart` and in-app copy call it "Menya **Kash**." Fix this before any external-facing decision — a fintech app with two spellings of its own name in its own codebase is a trust problem before it's a typo.

---

## 1. Executive Summary

Menya Kash has a **real, working core**: offline SMS ingestion, 5 real providers parsed against actual message evidence, a two-stage capture→process pipeline with dedup, live-computed balances (never stored, never drifting), transfer-matching that correctly de-duplicates cross-provider transfers, and a genuinely pleasant 4-tab UI (Home/Transactions/Budgets/Insights) with a real design system. This is not a prototype — it's a v1 ledger.

What it is **not yet**: a "financial intelligence platform." Today it is an excellent **transaction ledger with budgets**. Every "intelligence" capability in the brief — health scores, subscription detection, forecasting, recurring-bill detection, savings opportunities — is unbuilt. That's fine. The mistake would be believing the vision statement describes the current product, or building toward "intelligence" features before the ledger's remaining gaps (encryption at rest, notifications, localization, monetization) are closed.

**The single most important strategic decision this review makes**: recommend the team explicitly commit to **"the trustworthy ledger first, intelligence second"** sequencing, and resist the pull to build differentiating AI/intelligence features while foundational trust gaps (no DB encryption, no monetization, English-only in a Kinyarwanda-market app) remain open. A financial app's first job is to be trusted with money data; only a trusted app gets to be clever with it.

Second-most important: **the offline-only architecture is a genuine, durable differentiator in Rwanda specifically** (data cost sensitivity, intermittent connectivity, justified distrust of apps that phone home with financial data) — but it is also a hard ceiling on three things the vision explicitly wants: real user accounts, real email/SMS verification, and any server-side AI advisor. The team must decide, consciously and now, whether "offline-first" is a permanent identity or a v1 constraint to graduate past. This review recommends: **permanent for the free tier, explicitly and narrowly relaxed for an opt-in paid tier**, never blurred into "offline, except when it's convenient."

---

## 2. Product Vision Validation

The vision statement — "financial intelligence platform," not "another expense tracker" — is **aspirationally correct but currently unearned**. Positioning against Mint/YNAB-class tools while shipping category buckets and progress rings invites unflattering comparison the moment a user looks for "why is this different." The differentiation that *is* real and defensible today:

- **It reads your existing financial life without you doing any data entry** — MoMo/bank SMS parsing is a genuine wedge no manual-entry tracker has in this market.
- **It never sends your transaction history anywhere** — a real, articulable trust position, not marketing copy, since there's genuinely no server to send it to.
- **It already reconciles cross-provider transfers** (BK↔MTN) — most trackers double-count this; Menya Kash doesn't, because of real engineering (`TransferLinks`), not a claim.

Recommendation: **rewrite the public-facing vision statement around what's actually differentiated today** — "the app that already knows your MoMo and bank history, without you typing a single transaction, and never sends it anywhere" — and treat "financial intelligence platform" as the *Phase 2/3 destination*, not the v1 pitch. Overclaiming in a fintech app's own positioning is a self-inflicted credibility risk.

---

## 3. Feature Audit — Keep / Postpone / Remove

### Core MVP (must exist before public launch)

| Feature | Status | Why it's MVP |
|---|---|---|
| SMS import (2-stage capture→process, dedup) | **Built** | The entire value proposition. Non-negotiable. |
| Multi-provider parsing (MTN, eKash, Airtel, BK, Equity) | **Built** | Table stakes for "Rwanda financial platform" — 5 providers is a real, defensible floor. |
| Provider selection (explicit opt-in per provider) | **Built** | Correct: scanning only what the user actually uses is both a privacy and a correctness win (fixed real bugs upstream). |
| Categories + auto-categorization by counterparty | **Built** | Without this, every screen is a wall of "Uncategorized." |
| Merchant name normalization | **Built** | Fixed a real crash and a real UX bug (garbage counterparty strings). Load-bearing, not cosmetic. |
| Transfer de-duplication across providers | **Built** | This *is* the "intelligence" the vision promises, already shipped, just not marketed as such. |
| Live-computed balances (no stored balance) | **Built** | Correct architecture — a stored balance that can drift is a fintech app's most embarrassing possible bug. |
| App lock (biometric/PIN via OS) | **Built** | Financial data on-device demands *some* lock. Correct MVP floor. |
| **Database encryption at rest** | **MISSING — must land before public launch** | See §8. This is the one built-vs-needed gap that should block a public release, not just get scheduled. |
| Basic budgets (category + monthly limit) | **Built** | Directly answers "am I overspending," one of the five dashboard questions the brief itself poses. |
| Transaction search/filter | **Built** | Baseline usability once history exceeds ~50 rows. |
| Onboarding permission education | **Built** (Permission Summary screen) | Correctly sequenced *before* the OS dialog — good pattern, keep. |

### Version 1 (important, not launch-blocking)

- **Recurring-transaction / subscription detection** — real user value (airtime auto-renewals, MoMo standing transfers), but detection needs a pattern-matching pass against real historical data the team doesn't have yet. Ship v1 without it; instrument for it.
- **Local (on-device) budget-threshold notifications** — "you're at 80% of Food" is exactly the kind of nudge that makes a budgeting feature feel alive instead of a static ring users forget to check. Fully compatible with offline-only (no network required for a local notification). **This is the highest-value, lowest-cost addition not yet built** — recommend pulling it forward into v1.0, possibly even MVP.
- **Kinyarwanda + French localization** — see §10. Not MVP-blocking for a first release to early adopters, but should not slip past v1.1; the brand name itself is Kinyarwanda.
- **Net cash-flow view (income vs. expense vs. transfer, trended)** — Insights already has the pieces (summary, trend chart); this is composition, not new plumbing.
- **I&M Bank provider** — currently "considered, not built" per the docs. Add once real sender-pattern evidence exists (same evidentiary bar the other 5 providers were held to) — do not seed it speculatively.

### Premium (paid capabilities)

- **Statement export** (PDF/Excel/CSV) — interface exists (`StatementExporter`), zero implementation. Real, chargeable utility (tax season, loan applications, landlord proof-of-income) — but only once the export is actually trustworthy (correct totals, correct date ranges).
- **Encrypted local backup / restore** — NOT cloud backup (see §9 on why "Cloud SMS Backup" as literally specified is a non-starter). A user-initiated, user-controlled, still-offline encrypted export-to-file-then-restore-on-new-phone flow is a legitimate premium feature that doesn't violate the offline promise.
- **Multi-account / family budgeting** — meaningfully more schema work (shared budgets across devices implies *some* sync, which reopens the offline question) — premium-tier-appropriate specifically because it's expensive to build correctly.
- **AI financial insights / advisor** — see §7. Real user value exists in a *narrow, on-device* form (rule-based subscription/anomaly detection) for free; anything requiring an LLM call is server-dependent and must be explicitly scoped as the one deliberate exception to offline-only, gated behind clear user consent, never silently added.

### Enterprise (future roadmap, not now)

- Business expense management, multi-employee expense approval, receipt OCR for reimbursement — real market (Rwanda SME bookkeeping is underserved), but a different product surface (multi-user, roles, approval flows) that shouldn't be bolted onto a personal-finance data model. If pursued, treat as a **separate app/SKU** sharing the parsing engine, not a mode inside Menya Kash.

### Remove — features that should never exist as specified

- **"Cloud SMS Backup" backing up SMS + call logs, per the original UI-sprint spec.** Already correctly flagged and dropped once in this project's history (Phase 11 decision) for the exact right reason: it requires `INTERNET` permission and a remote backend, which categorically contradicts the offline mandate, and "backing up call logs" in a financial app has no plausible user-value justification — it reads as scope creep toward a data-harvesting posture the brand is explicitly built to reject. **This review reaffirms: do not resurrect this feature under any name.** If backup is wanted, it is the encrypted local file flow in the Premium section above.
- **"Financial score" / gamified scoring as a headline feature.** Personal Finance Expert's note: a single opaque "score" invites the same criticism credit-scoring apps get (what does 720 *mean*, why did it drop) without the regulatory infrastructure a real score needs. The *underlying signals* (categorized %, budget adherence, spend trend direction) are all already computable and already shown as separate, legible metrics — that's strictly better UX than compressing them into one number. Do not build a composite score.
- **In-app Subscription/billing UI shown before there is anything to subscribe to.** Already correctly avoided (`profile_screen.dart` explicitly omits it) — keep avoiding it. A visible "Subscription" row with nothing behind it erodes trust faster than not having the row.

---

## 4. Information Architecture

Current sitemap (as built):

```
HomeShell (bottom nav, 4 tabs)
├── Home           — balance hero, quick actions, month glance, budget preview, recent activity
├── Transactions    — searchable feed, filters, swipe-to-categorize
│     ├── Manage codes (app bar) → Categorize (code bank)
│     └── Review unrecognized (app bar) → Review Unparsed
├── Budgets         — progress rings, add/edit sheet
└── Insights        — period analytics, category charts, trend, top merchants

Reached from Home's app bar:
└── Profile
      └── Settings
            ├── Appearance (theme)
            ├── Security (app lock)
            ├── Financial Providers (connected services)
            └── Data (Export / Backup — stubbed)

Reached from Home quick action:
└── Pay (USSD builder)
```

**Assessment: this is the right shape and should not be substantially restructured.** Four tabs is correct for the product's actual daily-use surface (the brief's own suggested sitemap matches what's built). The one navigation smell: **"Manage codes" and "Review unrecognized" living behind Transactions' app bar are power-user tools masquerading as a normal menu item.** A first-time user has no way to know what "unrecognized messages" even means. Recommendation: keep them exactly where they are (they genuinely are Transactions-adjacent, not deserving their own tab) but **badge the Review-unparsed icon with a count** when non-zero — right now a user has no signal that anything needs their attention there, so real data-quality issues (a provider changed its SMS format) go silently unnoticed indefinitely.

Profile/Settings organization is sound and matches the brief's suggested sections. One gap: there is no "Help/Support" or "About" entry anywhere in Settings — for a financial app asking for SMS/contacts/phone permissions, a visible privacy-policy link and app-version/build info should be non-negotiable Settings citizens, not an afterthought.

---

## 5. Screen-by-Screen UX Critique

**Home** — Correctly answers "how much do I have" and "what happened recently" in one screen without overcrowding. The gradient balance hero is the app's one deliberate visual flourish and earns its place (money should look important). *Improvement*: the budget preview shows top-3 rings with no indication of *how many total* budgets exist beyond those 3 — a "+2 more" affordance would prevent the preview from reading as the complete picture.

**Transactions** — Swipe-to-categorize is the single best UX decision in the app; it turns a chore into a one-gesture action. *Improvement*: the day-grouped feed has no way to jump to a specific month/date — for a user who's been on the app 6+ months, scrolling to March becomes a real friction point. A lightweight date-jump (even just a month picker in the app bar) belongs in v1.1.

**Budgets** — Progress rings + three-state color coding (green/amber/red, always icon+label per the accessibility pass) is well-executed and matches how Personal Finance Expert would want budget health communicated — status, not just a number. *Improvement*: budgets are monthly-only with no rollover concept (unspent budget doesn't carry to next month, overspend doesn't carry as debt) — this is a reasonable v1 simplification, but should be a documented product decision, not a silent limitation users discover by being confused.

**Insights** — Correctly reuses the validated chart system (accessible palette, capped slices, legends). *Improvement*: "Top merchants" is a good addition but sits at the bottom of a long scroll — Digital Banking Consultant's note: in Rwanda specifically, "who am I actually paying most" (often a specific MoMo agent or shop) is frequently *more* actionable to users than category breakdowns, since categorization requires the user's own labeling effort while merchant identity is automatic. Consider promoting Top Merchants higher, possibly onto Home.

**Onboarding** (Welcome → Appearance → Terms → Account Setup → Security → Providers → Permission Summary → SMS Setup) — 7 steps is long but each step is justified and none is filler; the Permission Summary step specifically (explaining *why* before the OS asks) is a genuinely above-average pattern most apps skip. *Improvement*: Account Setup collects an email/phone that is **never verified** (see §8) — the screen should say so plainly ("we don't verify this — it's just how you refer to yourself") rather than implying verification is happening, which is currently a subtle honesty gap between what the UI suggests and what the code does.

**Settings → Data section** — Three stubbed rows (Export/Backup SMS/Local Backup) all show "coming soon." UX Researcher's flag: **a settings screen with 3 non-functional rows out of a small total set damages trust disproportionately** — a user who taps "Export Statement" expecting their bank-issued PDF equivalent and gets a snackbar will doubt the rest of the app. Recommendation: either hide these rows entirely until real, or visibly badge them "Coming in v1.1" so the non-functionality is expected, not discovered.

---

## 6. Transaction Intelligence — Optimal Model

Current model per-transaction: merchant (via `Merchants`), provider (via `FinancialProviders`), account, category, raw SMS body (preserved), timestamp, amount/fee, balance-after, transfer-link status. This is a **solid financial-ledger core**. Assessed against the brief's proposed field list:

| Field | Recommendation | Reasoning |
|---|---|---|
| Merchant, Provider, Account, Category | **Keep — already correct** | Core identity fields, all real and evidence-based. |
| Confidence Score | **Add, narrowly** | Not a user-facing number — an internal field on `Transactions` or `SmsMessages` marking "parsed with full field match" vs. "parsed but a field was defaulted/missing." This directly improves the Review-unparsed workflow (triage by confidence) without inventing a new user-facing metric (avoiding the "financial score" trap from §3). |
| Notes | **Add in v1.1** | Cheap schema addition (nullable text column), real value for the "why did I spend this" recall use case. Low risk, defer only for sequencing, not because it's wrong. |
| Tags | **Postpone to Premium/v2** | Multi-tag taxonomy is real complexity (many-to-many, tag management UI, tag-based filtering) for a use case categories mostly already cover. Don't build until categories prove insufficient. |
| Attachments / Receipt photos | **Postpone to Premium** | Camera permission + local image storage is a meaningfully new capability surface, valuable mainly for the Enterprise/expense-reimbursement use case (§3), not core personal use. |
| Location | **Remove from consideration entirely** | No SMS ever contains location data — this would require requesting device location permission for a feature with weak personal-finance justification and a real privacy cost. InfoSec Architect: this is exactly the kind of permission creep that undermines the "we only ask for what we need" trust position. Do not build. |
| Recurring | **Add in v1 (detection, not manual tagging)** | Per §3 — detect from real transaction-history patterns (same counterparty + similar amount + regular interval), don't ask users to manually flag transactions as recurring, which is busywork they won't do. |

---

## 7. Financial Intelligence — MVP / Phase 2 / Premium Split

| Capability | Placement | Why |
|---|---|---|
| Monthly categorization-progress % | **Built (MVP)** | Already shipped, already the right shape. |
| Budget health (ring, 3-state) | **Built (MVP)** | Already shipped. |
| Recurring bill / subscription detection | **Phase 2** | Needs a real detection pass against transaction history; do this once there's a meaningful user base generating real recurring patterns to validate against, not from day one on empty data. |
| Spending-category trends (this month vs. last 3) | **Phase 2** | Cheap composition on top of existing `AnalyticsService` queries — low engineering cost, real value, natural v1.1 candidate. |
| Cash-flow prediction / forecasting | **Premium, later** | Genuinely hard to do honestly (requires enough history + a model users can trust) — shipping a bad forecast is worse than no forecast. Don't rush this. |
| Unexpected-spending alerts | **Phase 2, via local notifications** | Directly pairs with the budget-threshold-alert recommendation in §3 — same infrastructure, ship together. |
| Merchant insights ("you spend most at X") | **Phase 2** | Top Merchants already exists in Insights; "insight" framing (a sentence, not just a bar chart) is copy work more than engineering work. |
| Spending heatmaps / seasonal analysis | **Premium** | Real value for power users, genuinely low value for a first-time or casual user — correctly gated behind paid tier as a "for people who want to go deep" feature. |
| "Financial habits" summary / composite score | **Remove** | Per §3 — the composite-score framing specifically should not be built; the underlying signals should be, separately. |
| AI financial recommendations | **Premium, explicitly network-gated** | The one place a server dependency might be justified — but must be an opt-in, clearly-labeled exception to the offline promise, never silently blended into the free experience. |

---

## 8. Security Review

**What's built and correct**: OS-delegated app lock (`local_auth`, falls through to whatever biometric/PIN/pattern the device has configured, not biometric-only), gated so the enabled flag is only ever persisted after a real successful authentication round-trip — this is genuinely careful engineering, not a checkbox.

**What's missing and must be fixed before public launch**:

1. **No encryption at rest for the sqlite database.** This is the single most serious finding in this review. The entire threat model of "app lock protects your financial history" evaporates the moment someone has filesystem access (a rooted device, a debug-enabled build, a lost/stolen phone with ADB left on, or simply another app with storage-scoped access on an older Android version) — the raw transaction history, including exact amounts and counterparty names, sits in a plain-text-readable sqlite file. **Recommendation: adopt SQLCipher (or drift's equivalent encrypted-at-rest support) before any public release.** This is not a "nice to have for v2" — for an app whose entire premise is "trust us with your financial SMS," shipping without at-rest encryption is a material, nameable gap that a security-literate user or journalist would find immediately.
2. **No in-app PIN fallback.** Security is entirely capped by whatever lock the OS device has configured — a user with no device lock screen literally cannot enable app lock (correctly handled with an error rather than a crash, but it's a real capability gap, not just an edge case). Recommendation: v1.1, add an app-specific PIN as a fallback for devices with no OS lock, so "app lock" isn't conditional on unrelated device hygiene.
3. **Unverified email/phone displayed as if they mean something.** Per §5 — not a security hole exactly, but an honesty gap that InfoSec/UX both flag: the UI should never imply verification occurred when it didn't.
4. **Permission model is otherwise good** — SMS/Contacts/Phone are all explained *before* the OS asks (Permission Summary screen), each is scoped to a specific real feature, and the app requests nothing it doesn't use (no location, no camera, no storage-beyond-app-scope). This is a genuinely above-average permission posture and should be preserved as new features are added — every future permission request should go through the same "explain first" pattern.

**Overall verdict: current security is *not* sufficient for public launch as-is**, specifically because of finding #1. Everything else in this section is real but secondary; at-rest encryption is the blocking item.

---

## 9. Offline Architecture — Sustainability

**Database**: drift/sqlite, single-file, no encryption (see §8), schema versioned with real migrations that backfill rather than destroy data across 6 versions — this migration discipline is a genuine engineering strength and should be maintained as a hard rule going forward (never a destructive schema reset).

**Caching**: not applicable in the traditional sense — there's no remote data to cache, which is architecturally simpler than a synced app, not a gap.

**Synchronization**: **does not exist, by design**, and this is correct for the free tier. The moment "sync across devices" is wanted (family budgeting, multi-device use), the team must decide: build a genuine peer-to-peer/local-network sync (technically hard, stays offline) or a server-mediated sync (easy, breaks the offline promise). Recommend peer-to-peer (e.g., local Wi-Fi/Bluetooth transfer, QR-code-mediated one-time export/import) as the offline-compatible answer, reserved for Premium multi-device scenarios, rather than defaulting to "just add a server" the first time sync is requested.

**Imports**: the 2-stage capture→process pipeline with SHA-256 dedup and isolate-based batch processing (confirmed: historical scans don't block the UI thread) is well-architected and already solved the "re-scanning double-inserts" and "8000-message scan janks the UI" problems for real, not hypothetically.

**Conflict handling**: not applicable today (no sync = no conflicts). Becomes relevant only if/when multi-device sync is built — flag now so it's designed in from the start rather than retrofitted.

**Data portability**: currently **the user cannot get their own data out of the app at all** — Export Statement is stubbed, Local Backup is stubbed. For a financial record-keeping app, "you can never leave with your own data" is a real risk (regulatory, in some jurisdictions, and reputational everywhere) even if nothing malicious is happening — it *looks* like lock-in. **Recommend prioritizing a basic CSV export (even before the polished PDF/Excel premium version) into the MVP or immediate v1.1**, specifically as a trust signal independent of its monetization value.

**Overall verdict: the offline architecture is sustainable and well-executed for what it currently does.** The sustainability risk is not technical — it's that the vision document wants capabilities (accounts, verification, AI advisor, cloud backup) that are categorically incompatible with "sustainable offline architecture," and the team needs a standing decision rule (proposed in §1) rather than deciding permission-boundary questions feature-by-feature.

---

## 10. Rwanda Ecosystem Fit

**What's right**: the 5 seeded providers (MTN MoMo, eKash, Airtel Money, BK, Equity) are evidence-based against a real 8,364-message export, not assumptions — this is exactly the right rigor for a market where SMS formats change without notice and being wrong about parsing is worse than not supporting a provider at all.

**What's missing, in priority order**:

1. **Localization.** The app is English-only. The brand name "Menya" is Kinyarwanda. This is the most visible mismatch in the entire review — a Rwanda-market financial app whose product name signals local-language fluency but whose UI doesn't speak the language. Recommend Kinyarwanda as the first localization target (not French) — Kinyarwanda is the language of daily financial life for the target user (market vendors, moto drivers, family transfers) in a way French, while official, often isn't for this specific transactional/informal-economy use case. French second. Both are `intl`-package-compatible additions; the `NumberFormat`/`DateFormat` usage already in place is a reasonable head start, but zero string-level i18n scaffolding (`.arb` files, `flutter_localizations`) exists yet — this is greenfield work, not a small patch.
2. **I&M Bank, SACCOs, Urwego** — correctly *not* built yet (no fabricated sender patterns), but SACCOs specifically deserve product research attention: SACCO membership is extremely widespread in Rwanda's financial-inclusion story, arguably more relevant to "financial intelligence for Rwanda" than a 6th commercial bank would be. Recommend the *next* provider-research effort (once real SMS evidence can be gathered) prioritize a representative SACCO over I&M, if forced to choose.
3. **Regulatory awareness**: BNR (National Bank of Rwanda) increasingly regulates fintech/PSP data handling. The app's current position (no data leaves the device, ever) is the *simplest possible regulatory posture* — actively preserve this as a feature, not just an implementation detail, in any future compliance conversation. The moment any network capability is added (even opt-in Premium AI), get real legal guidance on what obligations that triggers under Rwanda's data protection law, before building it, not after.
4. **Financial inclusion angle**: the vision's "future eKash integration" is already partially real (eKash is one of the 5 seeded providers today) — this is worth foregrounding in messaging, since it's a genuine, shipped capability, not a roadmap promise.

---

## 11. Monetization Strategy

**Current state: zero monetization surface exists.** No IAP package, no billing integration, no payment-gateway code (Stripe/Flutterwave/Paypack — all absent), not even a paywall stub. `StatementExporter` is the only scaffolded "premium" hook, and it doesn't work yet.

**What users would plausibly pay for**, ranked by Digital Banking Consultant + Personal Finance Expert judgment on willingness-to-pay in this specific market:

1. **Statement export (PDF)** — highest confidence. Real, recurring need (loan applications, tax filing, landlord income proof) with a clear moment of need and a clear substitute cost (a bank/MoMo-issued statement often costs a real fee or a branch visit) — genuinely easy to justify a small price against.
2. **Encrypted local backup/restore across phone upgrades** — people upgrade phones and lose app data constantly; solving "I got a new phone and lost 2 years of spending history" is a real pain point with clear willingness to pay, and it's achievable *without* breaking the offline promise (see §3).
3. **Multi-device/family budgeting** — lower confidence in this specific market at this stage (household financial *joint* tracking is culturally and technically harder), but directionally correct for a later premium tier.
4. **AI advisor** — highest *aspirational* interest, lowest near-term confidence — needs a working core product with real retained users before this is worth building, and needs the offline-exception conversation from §1 resolved first.
5. **Receipt OCR / business expense tooling** — treat as Enterprise-tier (§3), not a consumer premium feature; different buyer, different willingness-to-pay logic.

**Recommendation**: ship Free (current + Notes + basic recurring detection + local notifications) and Premium (CSV/PDF export + encrypted local backup) as the entire v1.1 monetization surface. Resist adding a third tier or an AI feature until the first two premium features have proven users will actually pay — sequencing discipline matters more than feature breadth here.

---

## 12. Scalability — Can Menya Kash Become...

| Direction | Verdict | Reasoning |
|---|---|---|
| Personal Finance Platform | **Yes — this is what it already is** | Confirm and deepen, don't pivot away from it. |
| Business Finance / Expense Management | **Yes, as a separate product surface** | Shares the parsing engine; needs multi-user/role model this data schema doesn't have and shouldn't be forced to have. |
| Tax Assistant | **Plausible, Phase 2/3** | Statement export is the natural first step toward this; full tax-assistant functionality needs Rwanda-specific tax-category mapping research before building. |
| Financial Coach | **Yes, but only after §7's Phase 2 intelligence features land** | "Coach" implies proactive, personalized guidance — can't be built before basic pattern detection exists. |
| Investment Tracker | **No, not on this architecture** | Investments aren't SMS-notified the way MoMo/bank transactions are; this would require an entirely different data-ingestion story (manual entry or a different integration), diluting the "we read your SMS automatically" differentiator. Would need to be justified as a genuinely separate product. |
| Loan Tracker | **Yes, and closer than it looks** | MoMo/bank loan disbursement and repayment already show up as ordinary transactions (`withdrawal`/`payment` types) — a "loans" lens on existing data (filter by counterparty pattern) is mostly a UI feature, not new plumbing. Good Phase 2 candidate. |
| Insurance Manager | **No** | No natural data source (insurance premiums might appear as generic payments, but "manage my policy" implies data the app has no way to obtain). Out of scope. |
| Digital Wallet Companion | **Yes — arguably the most natural evolution** | The Pay screen (USSD builder) is already a step toward this; deepening it (saved payees, payment templates, spend-limit warnings *before* paying, not just after) is a strong, low-risk Phase 2 direction that builds on existing code rather than new architecture. |

**Ideal roadmap ordering**: Personal Finance Platform (now) → Loan Tracker lens + deepened Wallet Companion (Phase 2, both low-cost extensions of existing data/features) → Financial Coach (Phase 2/3, needs intelligence features first) → Tax Assistant (Phase 3) → Business Finance (separate product, whenever there's a reason to build it) → Investment/Insurance (not on this roadmap; revisit only if a genuinely new data-ingestion strategy is developed).

---

## 13. Technical Debt

| Severity | Item |
|---|---|
| **Critical** | No database encryption at rest (§8) — blocks public launch. |
| **High** | Zero i18n scaffolding despite Rwanda-market/Kinyarwanda-brand positioning (§10). |
| **High** | Zero data-export capability — users cannot get their own data out (§9). |
| **Medium** | No in-app PIN fallback; security capped by device-level lock configuration (§8). |
| **Medium** | Settings' 3 stubbed Data rows create a trust gap the moment a user taps one (§5). |
| **Medium** | Widget/UI test coverage is likely thin relative to the 130 passing tests concentrated on parsing/matching services — worth an explicit audit of what's *not* covered (screen-level interaction tests). |
| **Low** | Review-unparsed queue has no unread/count badge — real data-quality signals go unnoticed (§4). |
| **Low** | Brand name spelling inconsistency ("Menya Cash" in commit history vs. "Menya Kash" in-app) — trivial to fix, embarrassing to leave. |

No item above rises to "architecture needs to be rethought" — the debt is real but entirely addressable without a rewrite, which is itself a positive signal about the codebase's health.

---

## 14. Prioritized Product Roadmap

**Phase 1 — MVP (current + must-fix before public launch)**
- Everything already built, **plus**: database encryption at rest, basic CSV export, brand-name spelling reconciliation.

**Phase 2 — v1.1**
- Local budget-threshold notifications, in-app PIN fallback, Notes field on transactions, month/date-jump in Transactions, Review-unparsed badge count, hide-or-badge the still-stubbed Settings rows, Kinyarwanda localization (first pass).

**Version 2**
- Recurring/subscription detection, spending-category trend composition, unexpected-spending local alerts, French localization, PDF/Excel export (Premium), encrypted local backup/restore (Premium), Loan Tracker lens.

**Version 3**
- Multi-device/family budgeting (peer-to-peer sync, Premium), deepened Digital Wallet Companion (saved payees, pre-payment spend warnings), Tax Assistant groundwork, SACCO provider research and integration.

**Long-term vision**
- AI financial advisor as an explicit, opt-in, clearly-labeled exception to offline-only (never default-on), Business Finance as a separate product surface sharing the parsing engine, Open Banking API integration once/if Rwanda's regulatory environment makes it viable.

---

## Closing note from the board

The team should read this review's overall tone correctly: **the core engineering is genuinely good** — the transfer-matching, the live-computed balances, the migration discipline, the evidence-based provider parsing, the permission-education pattern. The gaps identified here are not signs of a weak product; they're the normal, expected gaps of a v1 that correctly prioritized "make the ledger real and correct" before "make the ledger clever and monetized." The recommendation is sequencing discipline, not a course correction: close the trust gaps (encryption, export, localization) before chasing the intelligence features the vision statement is excited about. A trusted, honest ledger that Rwandans actually use daily is a far stronger foundation for "financial intelligence platform" than a clever feature bolted onto an app people are quietly unsure they should trust with their MoMo history.
