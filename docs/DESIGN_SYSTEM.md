# Menya Kash — Design System & Screen Specifications

The UI/UX redesign deliverable: design rationale per screen (UX
reasoning, wireframe, hierarchy, components, animations, implementation
strategy), plus the shared design system everything is built from.
Grounded in what is actually implemented in this codebase — file paths
refer to real files.

Design pole stars: **Minimal** (whitespace, four tabs, one idea per
section), **Premium** (large cards, soft shadows, 20-24px radii,
tabular figures), **Financial First** (amounts are the largest element
in any row; income/expense/transfer are instantly distinguishable by
icon + sign + color), **Calm** (exactly one gradient in the whole app —
the balance hero; color only where it carries meaning).

---

## 1. Foundations

### Color (`lib/theme/app_theme.dart`)

| Token | Light | Dark | Job |
|---|---|---|---|
| Primary | `#7F56D9` | `#A98CE8` | brand, interactive |
| Secondary | `#F5A623` (`#9C6208` on light for text) | `#F5A623` | accent, warnings |
| Income | `#15803D` | `#4ADE80` | money in |
| Expense | `#DC2626` | `#F87171` | money out |
| Transfer | `#2563EB` | `#60A5FA` | internal movement |
| Background | `#FAFAFA` | `#1A1A19` | canvas |
| Card | `#FFFFFF` | `#232322` | surfaces |

The income/expense/transfer light steps are deepened from the spec hues
where needed so small bold text clears WCAG AA 4.5:1 on white cards;
dark steps are lightened for the dark surface. Semantic money colors
are **never** reused as chart-series colors — charts keep the
separately-validated `ChartPalette`. Identity never rests on color
alone: every amount also carries a direction icon and a +/− sign.

### Typography

Material 2021 type scale with two app-wide rules: **every amount is
tabular-figures** (`FontFeature.tabularFigures()` — columns align
digit-for-digit) and **amounts are heavier and larger than their
context line** (w700-w800 vs regular). Inter/SF Pro was requested but
this app ships no network code (`google_fonts` fetches at runtime), so
custom type requires bundling TTFs — drop Inter's files into
`assets/fonts/`, declare in `pubspec.yaml`, and set `fontFamily` in
`AppTheme`; nothing else changes. Until then the platform grotesque
(Roboto) carries the same hierarchy.

### Components (`lib/widgets/design_system.dart`, `transaction_tile.dart`)

`AppCard` (white/charcoal, radius 20, soft shadow, press-scale 0.98 in
110ms), `AmountText` (signed, colored, tabular), `SectionHeader`
(title + "See all"), `EmptyState` (icon-in-circle, message, CTA — no
screen ever renders blank), `Skeleton` + `TransactionListSkeleton`
(shimmer gradient sweep, 1.1s loop), `ProgressRing` (animated sweep,
700ms easeOutCubic), `QuickAction` (tinted-circle icon + label),
`TransactionTile` (the one transaction row used on Home and
Transactions), `ProviderLogo` (`lib/theme/provider_assets.dart` — real
logos with monogram fallback), `categoryIcon()` (keyword → glyph, name
always shown beside it). Segment controls, bottom sheets, dialogs, FAB,
and the navigation bar are themed Material 3 components — no bespoke
clones of platform primitives.

---

## 2. Navigation

**Four tabs: Home · Transactions · Budgets · Insights** (`lib/main.dart`).

*UX reasoning:* the old five destinations (Overview/Pay/Categorize/
Review) mixed daily destinations with tooling. Pay is an *action*, not
a place — it's the first Quick Action on Home (and stays one tap away).
Categorize collapsed into Transactions (categorizing IS a transaction
interaction — swipe or tap the row); the code-bank manager and the
unparsed-message Review queue are Transactions app-bar tools. Profile
hangs off Home's app bar per spec. `IndexedStack` keeps every tab's
scroll/filter state alive across switches.

---

## 3. Home (`lib/screens/home_screen.dart`)

*UX reasoning:* answer "how is my money right now?" in one glance, then
offer doorways — never duplicate the deep views.

*Wireframe:* Greeting ("Good morning, Ange") → **balance hero** (the
app's only gradient: brand purple, total balance headline, wallet rows
with provider logos, "balance unknown" honesty caption when a provider
never reports one) → Quick Actions row (Pay / Transactions / Budgets /
Insights) → "This month" (Money in / Money out cards, tap → Insights) →
Budgets preview (top-3 rings by pressure, tap → Budgets) → Recent
activity (last 5 `TransactionTile`s in a card, tap → Transactions).

*Hierarchy:* balance figure (headlineMedium w800) > section titles >
amounts > context lines. *Components:* `OverviewCard`, `QuickAction`,
`AppCard`, `ProgressRing`, `TransactionTile`, skeletons for every
async section. *Animations:* ring sweeps, card press-scale, shimmer
while loading. *Implementation:* plain `ListView` of `FutureBuilder`/
`StreamBuilder` sections over the existing services — no state
management library needed at this scale; `RefreshIndicator` re-futures
everything.

## 4. Transactions (`lib/screens/transactions_screen.dart`)

*UX reasoning:* one searchable, filterable ledger — the "every
transaction, understood" promise. Categorization is in-place, not a
separate destination.

*Wireframe:* search field → segment filters (All / In / Out / To
review) → day-grouped feed ("Today", "Yesterday", full dates) of
`TransactionTile`s. Swipe right reveals a purple **Categorize** action;
tap opens the same category bottom sheet (list with icons, current
choice checked, inline "New category…" creation). App bar: code-bank
manager, Review queue.

*Hierarchy:* amount (colored, signed) ≥ merchant > category·account·
time context line. *Components:* `TransactionTile`, `Dismissible`
(confirmDismiss always returns false — rows are acted on, never
deleted; history is a ledger), bottom sheet, `EmptyState` per filter,
`TransactionListSkeleton`. *Animations:* swipe reveal, sheet slide-up.
*Implementation:* `watchAll()` stream + lookup maps fetched once
(category/account/provider names, provider codes, transfer ids) so the
feed renders with zero per-row queries; categorizing by counterparty
writes the standing code mapping so future SMS auto-categorize.

## 5. Budgets (`lib/screens/budgets_screen.dart`, `lib/budgets/budget_service.dart`)

*UX reasoning:* budgets answer "am I okay?" — a ring says that faster
than a table. Health has three honest states: fine (green), almost
(amber, ≥80%), over (red) — with icon + label, never color alone.

*Wireframe:* month summary card (overall ring + spent-of-budget +
"left to spend") → one card per budget (ring with category glyph,
spent/limit, animated linear echo bar, warning chip) → extended FAB
"New budget" → bottom sheet (category picker of unbudgeted categories,
RWF limit; edit adds Remove).

*Data honesty:* spend is computed live per calendar month from
`Transactions` (outbound types, transfer-linked rows excluded — same
semantics as Insights, so the two tabs can never disagree), never
stored — the same single-source-of-truth rule as account balances.
Schema: `Budgets` table (one per category, v6 migration), fully
unit-tested (`test/budgets/budget_service_test.dart`).

*Animations:* ring + bar sweep on load (700ms), FAB → sheet.

## 6. Insights (`lib/screens/insights_screen.dart`)

*UX reasoning:* the analytics home — period-scoped "where did it go,"
with the already-validated chart system (dataviz-checked `ChartPalette`,
capped slices + "Other" fold, legends with percentage secondary
encoding).

*Wireframe:* period granularity segments (Week/Month/Quarter/Year) →
prev/next period navigator → Money in/out/Balance stat tiles + delta
badge vs previous period → category donut/bar toggle → categorization
progress ("85% categorized — N need review", taps through to
Transactions) → 6-month trend line → **Top merchants** (ranked
single-hue bars — magnitude, so sequential color, per the color
formula).

*Implementation:* the former dashboard analytics, re-homed; top
merchants reuses `AnalyticsService.topCounterparties` (already
transfer-aware). All charts keep their hover/touch layers.

## 7. Pay (`lib/screens/pay_screen.dart`, pushed from Home)

Amount-first (large centered RWF entry — the number is the decision),
then recipient (Contact / Frequent / Manual in soft cards), then **Pay
now** (direct USSD via ACTION_CALL, network shows its own
confirmation) with "Open dialer instead" as the manual fallback, both
honestly described. Recipient normalization and merchant/phone
detection per Phase 9 remain underneath.

## 8. Onboarding (`lib/screens/onboarding/`)

Welcome (brand mark, value prop) → Appearance (Light/Dark/System, live
apply) → Terms & Privacy (expandable sections, icons) → Account Setup
(email, verification-service abstraction, skippable) → Security (app
lock via local_auth, only persisted after a real successful prompt) →
Providers (branded selectable cards, logos) → Permission summary
(cards explaining SMS/Contacts/Phone *before* any OS dialog) → SMS scan
(live progress counts). Each step persists immediately — force-quitting
mid-flow loses nothing.

## 9. Profile & Settings (`lib/screens/profile/`)

Profile: avatar block, identity fields, security status row, Connected
Accounts (provider logos + live balances + rename). Settings sections:
Appearance (theme), Security (app lock), Financial Providers (logo
toggles), Data (Export Statement / Backup SMS / Local Backup — stubbed
entries backed by the prep-only `lib/premium/` architecture).
Deliberately omitted: Notifications (nothing to notify about in a
fully-offline app — adding the section now would be a lie), Achievements
/ Financial score / Subscription (future features; we don't ship fake
rows).

---

## 10. Accessibility & platform

Dynamic text: all text uses theme styles, no fixed-height rows that
clip. Tap targets: rows ≥44px, `Dismissible` swipes have tap
equivalents (every swipe action is also reachable by tapping the row).
Screen readers: icons paired with text labels throughout; direction
icons + signs mean color is never the only channel. Contrast: every
semantic color step chosen against its real surface (see §1); the one
hard-committed surface (purple hero) uses white ink validated at
4.96:1. Dark mode is a designed palette (own steps), not an automatic
inversion.

## 11. Deferred (honest debt)

- **Inter font**: needs bundled TTFs (no runtime fetching in this app).
- **Illustrations**: icon-in-tinted-circle compositions stand in;
  bespoke illustration assets can replace them 1:1 inside `EmptyState`
  and onboarding headers when supplied.
- **Savings goals** (Budgets) and **cash-flow/net-income cards**
  (Insights): natural next iterations on `BudgetService`/`AnalyticsService`.
- **Staggered list-entrance animations**: press/sweep/shimmer shipped;
  entrance choreography is polish that should be profiled on real
  hardware first (this app already fought one jank battle and won).
