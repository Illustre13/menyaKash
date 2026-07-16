# i-momo — Phase 0 Audit

Conducted against the real codebase (`lib/`, `test/`, `android/`) and a real
8,364-message SMS export (`public/sms-20260713181737.xml`, a genuine device
backup — treat as sensitive, already gitignored). All findings below are
evidenced by direct code reads or direct quotes from real SMS text, not
assumptions. No code was changed in this pass.

---

## 1. Current Architecture

**Stack:** Flutter (Material 3), `drift` for local SQLite, `telephony` for SMS
read/listen, `flutter_contacts` for the Pay screen's contact picker,
`url_launcher`-style `tel:` intent for USSD dialing, `fl_chart` for charts.
Fully offline — no `INTERNET` permission declared anywhere, verified in the
manifest.

**State management:** plain `StatefulWidget` + `setState` throughout. No
Provider/Riverpod/Bloc. `HomeShell` (in `main.dart`) is a single composition
root that constructs one instance each of `AppDatabase`, `MomoParserRegistry`,
`SmsIngestService`, `CategorizationService`, `AnalyticsService`,
`ContactsService`, and passes them down via constructor parameters — manual
DI, no service locator or DI framework.

**Navigation:** single `MaterialApp` route (`home: HomeShell`), no named
routes. Bottom `NavigationBar`, 4 destinations, `IndexedStack` keeps all four
screens alive simultaneously (Overview / Pay / Categorize / Review).
`CategorizeScreen` nests a second `TabBar` (4 tabs). Modals use
`showModalBottomSheet`/`showDialog`, not routes.

**Data flow today (SMS → DB row):**

```
SMS arrives (historical scan or live listener)
  → SmsIngestService._ingestOne(sender, body, receivedAt)
  → MomoParserRegistry.process() — loops parsers, checks ownsSender(sender)
  → MtnRwandaParser.tryParse() — regex match against ONE hardcoded template family
  → match  → Transactions row (rawSmsBody kept verbatim, counterparty as one opaque string)
  → no match → UnparsedMessages row (body kept verbatim)
```

No dedup, no cross-provider matching, no raw-event/normalized-transaction
separation — SMS text is parsed directly into a `Transactions` row in one
step. This is exactly the risk the spec's Phase 1 names.

**Schema (drift, `schemaVersion = 1`, no migrations yet):**

- `Categories(id, name UNIQUE)`
- `CategoryCodes(id, code UNIQUE, displayName?, categoryId → Categories, CASCADE)`
- `Transactions(id, provider TEXT, type ENUM, amount, fee, counterparty?, txRef?, balanceAfter?, timestamp, rawSmsBody, categoryId? → Categories)`
- `UnparsedMessages(id, sender, body, receivedAt, resolved)`

`provider` is a bare string (`'mtn_rw'`), not a foreign key to any providers
table — there is no `financial_providers` table today. There is no
`Accounts`/`Wallets` table. `Transactions` and `CategoryCodes` are joined only
by string equality on `counterparty == code`, not a real FK.

---

## 2. Current Features (working today, verified by code read)

- SMS onboarding: permission request → historical scan with live progress →
  live listener for new messages. No login, no account, no auth of any kind.
- Rule-based parsing for **one** MTN Rwanda message template family (see §4).
- Manual categorization: per-transaction, bulk-similar-transaction apply,
  a "Frequent codes" phonebook ranked by usage, category rename/delete.
- Dashboard: period selector (week/month/quarter/year) with prev/next nav,
  pie/bar toggle for category spend, monthly trend line, period-over-period
  delta badge.
- Pay screen: contact picker, frequent-code quick-pick, manual entry, all
  feeding a USSD string builder that hands off to the native dialer (never
  auto-sends).
- Purple/orange brand theme (`#7F56D9` / `#F5A623`) applied via
  `ColorScheme.fromSeed`, consistently used across all four screens.
- Web dev-preview target (`main_web.dart`) with seeded fake data, for UI
  iteration without an Android device.

---

## 3. Known Issues (confirmed against real data)

### 3.1 The parser recognizes one format; real traffic has at least five

The current `MtnRwandaParser` regexes were written from **placeholder
guesses** — the code's own comments say so (`mtn_rwanda_parser.dart:6-31`:
"NOT built from verbatim MTN Rwanda SMS... until verified"). The real SMS
export proves this is not a minor gap. Real MTN/`M-Money` traffic alone
contains at least five structurally different message shapes:

| Shape                                       | Real example (redacted)                                                                                                                                                                                                                                                                               |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P2P transfer                                | `*165*S*5000 RWF transferred to NAME (250XXXXXXXXX) from 15568442 at 2024-04-15 19:54:02 . Fee was: 100 RWF. New balance: 27551 RWF.`                                                                                                                                                               |
| Merchant payment                            | `TxId: 13571597197. Your payment of 9,283 RWF to HOPITAL LA CROIX DU SUD Ltd 100126 has been completed at 2024-04-16 20:29:00. Your new balance: 11,828 RWF. Fee was 0 RWF.`                                                                                                                        |
| Alt payment (eKash/Airtime, same shortcode) | `*162*TxId:13559072472*S*Your payment of 500 RWF to eKash with token  has been completed at 2024-04-15 21:39:02. Fee was 20 RWF. Your new balance: 21931 RWF . Message: - ACSC. *EN#`                                                                                                               |
| Agent withdrawal                            | `You NAME (*********188) have via agent: Ruth IMANISHIMWE (250791519401), withdrawn 5000 RWF from your mobile money account: 15568442 at 2025-03-08 08:52:01 and you can now collect your money in cash. Your new balance: 2832 RWF. Fee paid: 250 RWF. ... Financial Transaction Id: 19394210820.` |
| Bundle/data purchase                        | `*164*S*Y'ello,A transaction of 500 RWF by Data Bundle MTN on your MOMO account was successfully completed at 2025-06-24 19:20:36. ... Your new balance:2360 RWF. Fee was 0 RWF. Financial Transaction Id: 21338708265. External Transaction Id: 17507856022188973.*EN#`                            |

None of these match the currently-coded regex family. **The parser will
misclassify or fail on the large majority of real MTN Rwanda SMS.** This is
the single highest-priority correctness issue in the app.

Sender-name reality is also broader than coded: `knownSenders` is
`{'M-Money', 'MTN', 'MoMo'}`, but the real export shows the *same* `M-Money`
shortcode carries MoMo P2P, MoMo merchant payments, **and eKash** payments
(a different product riding the same sender ID) — sender alone cannot
distinguish provider/product; message-body pattern matching must.

### 3.2 Multi-provider reality confirmed — Airtel, BK, Equity, MoKash, eKash all present

Real distinct financial senders found in the export: `M-Money`, `AirtelMoney`
/ `AIRTELMONEY`, `BKeBANK`, `EQUITYBANK`, `MoKash`/`MoMo`, `Ekash`/`eKash`,
`BK BANK`, `BRD`. Only one (`M-Money`, and only partially) has any parser
today. Confirmed real Airtel Money format:

```
*151*Txn ID CI240415.2137.A06010*R* You have received RWF 500 from NAME 250XXXXXXXXX in MTN RWANDA.Your NEW BALANCE isRWF 3320. *EN#
```

Confirmed real Equity Bank format:

```
20000.00 RWF was successfully sent to NAME 250XXXXXXXXX. MTN Ref. 541077019015. Ref. 541077019015 on 17/04/24 at 19:24:13 CAT. Charges 0.00 RWF
```

This Equity message is a **real, confirmed instance of the exact transfer
problem the spec's Phase 3 describes**: it references `MTN Ref. 541077019015`
— an Equity-side bank debit that corresponds to a same-amount MTN-side credit
elsewhere, with a shared reference number available for matching. Today,
each would land as two unrelated `Transactions` rows (if Equity were even
parsed, which it isn't) — double-counted as income + expense instead of one
internal transfer.

### 3.3 Categorization stores merchant name and account code as one opaque string — confirmed real-world failure

Traced end-to-end (parser → `ParsedTransaction.counterparty` →
`Transactions.counterparty` → `CategoryCodes.code`): the entire matched
free-text span is stored as one string, never split. Real examples from the
export that would hit exactly this bug:

- `"HOPITAL LA CROIX DU SUD Ltd 100126"`
- `"RITE PHARMACY LTD 902850"`
- `"Pacifique 08077"` (a person's name concatenated with a code)

Two transactions to the same real-world merchant with even slightly
different trailing formatting would never be recognized as the same
counterparty by exact-match lookup (`CategoryCodes.code` has a `UNIQUE`
constraint on the raw string). The existing loose-match helper
(`_significantToken` in `CategorizationService`) only ever operates
in-memory for bulk-apply suggestions — it is never persisted, so the
underlying stored key is still the flawed opaque blob.

### 3.4 Pay screen recipient bug — root cause confirmed, not just suspected

`UssdBuilder`/`PayScreen`/`ContactsService` were read in full: **zero
normalization exists anywhere** between "user picks a recipient" and "string
goes into the USSD command." `ContactsService.loadContactsWithPhoneNumbers()`
uses `flutter_contacts`' raw `Phone.number` (never `normalizedNumber`), and
`PayScreen._recipient` passes that string straight into
`UssdBuilder.sendMoney(phoneNumber: recipient, ...)` with only a `.trim()`
applied anywhere in the chain. A contact number stored with spaces, dashes,
a `+250` prefix, a leading `0`, or — per the reported 22-digit failure case —
a completely wrong field value from the contacts provider, is passed through
unchanged into the dialed string. This is confirmed as a normalization gap,
not a one-off glitch.

Also note: `UssdBuilder.payMerchant`'s code comment mislabels the constant —
the `*182*8*1*...` prefix is the merchant-payment path, and send-money is
actually `*182*1*1*...`; this doesn't cause the reported bug but is worth
fixing for clarity while touching this file.

### 3.5 No deduplication — re-running historical scan double-inserts

`scanHistoricalInbox()`'s own doc comment admits it: "already-ingested
messages aren't deduplicated against here... meant for the empty-database
first run." There is no unique constraint on `Transactions` (not on `txRef`,
not on `(provider, txRef)`, not on a body hash). Real MTN messages do carry a
`TxId`/`Financial Transaction Id` that could anchor a uniqueness constraint,
but nothing does today.

### 3.6 Everything runs on the UI isolate — matches the reported jank

No `compute()`, no `Isolate.spawn`, anywhere in the ingestion path.
`scanHistoricalInbox()` is an `async*` generator that loops potentially
thousands of messages on the main isolate, running regex parsing and
`await`ed DB inserts per message. Against a real 8,364-message inbox (this
export's actual size), this is a substantial, unavoidable-as-written source
of dropped frames — consistent with the reported "Skipped 32 frames."

### 3.7 No account/wallet concept — `balanceAfter` is already ambiguous with one provider

`AnalyticsService.summary()` reports "current balance" as the most recent
non-null `balanceAfter` across *all* transactions, provider-agnostic. This is
already fragile with MTN-only data (a withdrawal's balance and a merchant
payment's balance interleave correctly only because they share one wallet);
the moment Airtel/Equity/BK data is parsed, this single number would
silently conflate multiple real-world balances into one meaningless figure.

### 3.8 No authentication, no biometric lock, no account/provider linking UI

Confirmed by full reads of `main.dart` and `onboarding_screen.dart`: the only
"identity" concept in the entire app is Android's own SMS permission grant.
There is no user account, no email/OTP, no `local_auth` integration, no
"connect your bank" flow of any kind — all of Phase 5/6/7 in the spec is
greenfield, not a modification of something existing.

---

## 4. Technical Debt

| Item                         | Detail                                                                                                                                                                                                                                                                                      |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Parser coverage              | 1 provider (MTN, partial), 1 template family recognized out of ≥5 confirmed real ones                                                                                                                                                                                                      |
| Provider modeling            | String tag only, no table, no validation against a known-provider list                                                                                                                                                                                                                      |
| Counterparty modeling        | Opaque unstructured string, name+code conflated, no merchant normalization                                                                                                                                                                                                                  |
| Transfer/duplicate detection | None; no unique constraints; no cross-provider correlation                                                                                                                                                                                                                                  |
| Account/wallet modeling      | None; single global "balance" concept already fragile                                                                                                                                                                                                                                       |
| Threading                    | 100% main-isolate; scan of a real-sized inbox will jank                                                                                                                                                                                                                                     |
| Auth/identity                | None exists; all onboarding/security/provider-linking work is net-new                                                                                                                                                                                                                       |
| USSD recipient handling      | No normalization layer; passes raw OS contact data through unchanged                                                                                                                                                                                                                        |
| DB migrations                | `schemaVersion = 1` with no migration path defined — any schema change from here needs a real migration strategy, not just editing the table classes                                                                                                                                     |
| Unmaintained deps            | `telephony` package is archived/unmaintained upstream (already flagged in existing docs); required manual patches to its own `build.gradle` (namespace, JVM target, `compileSdk`) to build at all on current tooling — a real ongoing maintenance risk for a load-bearing dependency |

---

## 5. Recommended Sequencing

Given the scope of the full spec (11 phases spanning data architecture,
multi-provider parsing, transfer intelligence, full auth/onboarding rebuild,
provider-linking UI, profile/settings, dashboard redesign, a confirmed USSD
bug, performance work, and premium-feature scaffolding), and given this audit
now has **real evidence** rather than assumptions, the recommended next steps
in priority order are:

1. **Fix the Pay/USSD recipient bug (spec Phase 9)** — small, isolated,
   high-value, no data-model risk. Add a phone-number normalization step
   between contact selection and `UssdBuilder`.
2. **Build the real SMS pattern library (spec Phase 2, step 2.2)** — now
   unblocked; this audit already extracted real examples for MTN P2P,
   merchant payment, alternate payment, agent withdrawal, bundle purchase,
   and Airtel/Equity formats. Turn these into fixtures + regex before
   touching the data model, so the parser rewrite has a real test harness
   from day one.
3. **Data architecture rewrite (spec Phase 1)** — raw SMS event storage,
   provider table, provider-detection layer. This is the correct foundation
   and should happen before Phase 3/4 rework, per the spec's own ordering —
   confirmed necessary by this audit, not just theoretically correct.
4. **Categorization redesign (spec Phase 4)** — split merchant name from
   account code; this is now proven necessary with real examples, not
   hypothetical.
5. **Transfer/duplicate intelligence (spec Phase 3)** — needs the provider
   table and normalized transactions from step 3 first; the Equity↔MTN
   `Ref.` correlation example found in this audit is a concrete test case.
6. Everything else (auth/onboarding rebuild, provider-linking UI,
   profile/settings, dashboard redesign, performance/isolate work, premium
   scaffolding) — genuinely large, independent workstreams; sequence after
   the data foundation is solid, one phase at a time with a checkpoint after
   each, per the spec's own stated process.

No code has been changed in this audit. Next step is your call on which
numbered item above to start on.
