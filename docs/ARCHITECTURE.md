# i-momo Architecture

This document is the detailed design reference for the codebase in
`../lib`. See the top-level [README.md](../README.md) for setup steps.

## 1. Design principles

1. **Offline by construction, not by convention.** No `INTERNET` /
   `ACCESS_NETWORK_STATE` permission is declared in
   `android/app/src/main/AndroidManifest.xml`. If the app can't declare
   the permission, it can't open a socket — this is enforced at the
   platform level, not just by not writing network code.
2. **Rule-based classification, not ML.** MoMo SMS follows fixed
   templates per transaction type, so a regex parser per provider is
   deterministic, instant, needs no training data, and is trivial to
   extend when a new message format appears.
3. **Fail safe, not silent.** Any message from a known MoMo sender that
   no parser recognizes is stored in `UnparsedMessages` and surfaced in
   the Review screen — never silently dropped or guessed at.
4. **User-driven categorization, no seed data.** The `CategoryCodes`
   table starts empty. The first time a merchant/till code is seen, the
   user labels it once; every future transaction from that code is
   auto-categorized from then on. Categorizing one transaction also
   offers to bulk-apply the same category to other uncategorized
   transactions that look like the same counterparty (loose name match,
   not just exact code equality), and any categorization — including
   ones made automatically from the code bank — can be edited later.
5. **Pluggable providers.** Adding MTN Uganda, Airtel Rwanda, etc. means
   writing one new `MomoParser` implementation and registering it — no
   changes anywhere else in the pipeline.
6. **Full history from minute one.** Onboarding requests SMS permission
   with a plain-language explanation, then streams progress while every
   MoMo message already in the inbox is scanned and classified — so
   the periodic tracker has real history to show immediately rather
   than only accumulating from first launch onward.
7. **Reports are periodic, not just a rolling window.** The dashboard is
   scoped to a navigable Week / Month / Quarter / Year window (see
   `Period` in §6a) with prev/next navigation and a period-over-period
   delta, rather than only ever showing "all time" or a fixed last-N-days
   range.

## 2. System context

```mermaid
C4Context
    title System context — i-momo

    Person(user, "User", "Rwandan MoMo customer tracking personal spending")
    System(app, "i-momo", "Offline Flutter app: Android SMS inbox -> local classification -> analytics")
    System_Ext(smsProvider, "Android SMS Provider", "OS-level inbox, historical + BroadcastReceiver for new SMS")
    System_Ext(telco, "MTN / Airtel network", "Sends MoMo transaction notification SMS to the user's number")
    System_Ext(dialer, "Native Android Dialer", "Receives a tel: intent with a prefilled USSD string")

    Rel(telco, smsProvider, "Delivers MoMo SMS to")
    Rel(smsProvider, app, "Read via telephony plugin (READ_SMS / RECEIVE_SMS)")
    Rel(user, app, "Views dashboard, categorizes transactions, reviews unparsed messages")
    Rel(user, dialer, "Confirms and sends USSD code")
    Rel(app, dialer, "Hands off *182...# string via tel: intent")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

No arrow ever leaves the phone. The only two external actors are the
OS-level SMS provider (read-only) and the native dialer (write-only,
user-confirmed).

## 3. Container / module view

```mermaid
flowchart TB
    subgraph Device["Android device — everything below runs on-device"]
        subgraph UI["Presentation — lib/screens/"]
            Onboarding["OnboardingScreen\n(permission + scan progress)"]
            Dashboard["DashboardScreen\n(Week/Month/Quarter/Year)"]
            Categorize["CategorizeScreen\n(Uncategorized / All / Manage)"]
            Review["ReviewUnparsedScreen"]
            Ussd["UssdScreen"]
        end

        subgraph Domain["Domain services"]
            IngestSvc["SmsIngestService\nlib/sms/\n(capture + store only, emits ScanProgress)"]
            Detector["ProviderDetector\nlib/providers/\n(sender+body -> provider)"]
            Processor["SmsProcessor\nlib/sms/\n(pending sms_messages -> transactions)"]
            ParserReg["MomoParserRegistry\nlib/parsers/\n(routes by provider code)"]
            CatSvc["CategorizationService\nlib/categorization/\n(bulk-similar, CRUD)"]
            AnalyticsSvc["AnalyticsService\nlib/analytics/\n(Period-scoped)"]
        end

        subgraph Infra["Platform integration"]
            Telephony["telephony plugin\n(SMS read + listener)"]
            PermHandler["permission_handler\n(READ_SMS / RECEIVE_SMS)"]
            UrlLauncher["url_launcher\n(tel: intent)"]
        end

        DB[("AppDatabase\nSQLite via drift\nlib/data/\n+ financial_providers, sms_messages")]

        Onboarding --> IngestSvc
        Dashboard --> AnalyticsSvc
        Categorize --> CatSvc
        Review --> DB
        Ussd --> UrlLauncher

        IngestSvc --> Telephony
        IngestSvc --> PermHandler
        IngestSvc --> Detector
        IngestSvc --> DB
        Processor --> Detector
        Processor --> ParserReg
        Processor --> DB
        CatSvc --> DB
        AnalyticsSvc --> DB
    end

    SmsRadio(["📡 Incoming SMS"]) --> Telephony
    UrlLauncher -.-> NativeDialer["📞 Native dialer"]
```

`HomeShell` (in `main.dart`) is the gate between the two: it checks
`SmsIngestService.hasPermissions()` once at startup, shows
`OnboardingScreen` only when permission hasn't been granted yet, and
otherwise resumes the live listener and goes straight to the bottom-nav
shell (Dashboard / Categorize / Review / Dial).

## 4. Data flow — ingesting one SMS (v2 pipeline, Phase 1)

**This replaced a direct SMS→Transaction pipeline** that shipped in v1.
The v1 shape — parse-and-insert in one step, with no permanent,
provider-attributed record of the raw evidence — was audited and found
to be the wrong architecture (see `docs/AUDIT_PHASE_0.md` §1, §3.5,
§3.6): it made re-scans double-insert (no dedup key existed), made a
parser bug unrecoverable without re-reading the phone's SMS inbox
again, and gave "provider" no real identity beyond a free-text string.

The pipeline is now a strict two-stage split, matching the "SMS → Raw
Event → Provider Parser → Normalized Transaction" shape:

```mermaid
sequenceDiagram
    autonumber
    participant OS as Android SMS Provider
    participant Ingest as SmsIngestService
    participant Det as ProviderDetector
    participant DB as AppDatabase (SQLite)
    participant Proc as SmsProcessor
    participant Reg as MomoParserRegistry
    participant Parser as e.g. MtnRwandaParser

    Note over Ingest,DB: Stage 1 — capture & store (never parses)
    OS->>Ingest: new SMS (sender, body, inbox date)
    Ingest->>Det: detect(sender, body)
    alt sender matches no known FinancialProviders sender pattern
        Det-->>Ingest: null
        Ingest--xIngest: ignored, nothing stored
    else sender recognized (possibly ambiguous — see §8a)
        Det-->>Ingest: ProviderDetection(provider, confidence)
        Ingest->>Ingest: hashSmsMessage(sender, body, receivedAt)
        alt hash already exists in sms_messages
            Ingest--xIngest: skip — dedup, not a double-insert (fixes v1 §3.5)
        else new hash
            Ingest->>DB: INSERT INTO sms_messages (status='pending')
        end
    end

    Note over Proc,DB: Stage 2 — detect + parse + write (separate, replayable)
    Proc->>DB: SELECT * FROM sms_messages WHERE status='pending'
    loop for each pending row
        Proc->>Det: detect(sender, body)
        Proc->>Reg: processForProvider(providerCode, body, receivedAt)
        Reg->>Parser: tryParse(body, receivedAt)
        alt regex matches a known template
            Parser-->>Reg: ParsedTransaction
            Proc->>DB: INSERT INTO transactions (sms_message_id, provider_id, ...)
            Proc->>DB: UPDATE sms_messages SET status='matched'
        else no template matches
            Parser-->>Reg: null
            Proc->>DB: INSERT INTO unparsed_messages (sms_message_id, ...)
            Proc->>DB: UPDATE sms_messages SET status='unrecognized'
        end
    end
```

Two consequences of this split that weren't possible in v1:

- **Reprocessing.** Fixing `MtnRwandaParser`'s regex and re-running
  `SmsProcessor.processPending()` (or a future "reprocess unrecognized"
  action) re-derives transactions from stored evidence — no phone, no
  re-scan, no risk of the user having deleted the original SMS since.
- **Provider identity is real.** `sms_messages.provider_id` and
  `transactions.provider_id` are foreign keys into `financial_providers`
  (§8), not a free-text tag — see §8a for how one sender can resolve to
  different providers depending on body content (the confirmed real
  `M-Money` → MTN MoMo vs. eKash case).

The `receivedAt` fallback (body date → SMS inbox date → `DateTime.now()`
as last resort) still matters most during the historical scan: a
message from 8 months ago must be dated 8 months ago, not "now," or
every periodic report (§6a) would bucket all historical spend into
whichever period the scan happened to run in. That logic is unchanged,
just now lives inside each `MomoParser.tryParse` as before.

## 4a. Initial setup — onboarding + full-history ingestion

As of Phases 5-7, onboarding is a six-step flow (`OnboardingFlowScreen`)
rather than the single SMS-permission screen this diagram originally
described — see §8c for the full flow and why SMS setup now runs last
instead of first. The historical-scan mechanics below are unchanged:

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant Home as HomeShell
    participant SMS as SmsSetupScreen
    participant Ingest as SmsIngestService

    Note over U,Home: By this point the user has already completed<br/>Welcome, Terms, Account Setup, Security Setup,<br/>and Provider Selection (§8c) — this is step 6 of 6.
    SMS->>U: explain on-device-only SMS access
    U->>SMS: taps Continue
    SMS->>Ingest: requestPermissions()
    alt permission denied
        Ingest-->>SMS: false
        SMS->>U: show retry screen
    else permission granted
        Ingest-->>SMS: true
        SMS->>Ingest: scanHistoricalInbox() [stream]
        loop for each message in inbox
            Ingest-->>SMS: ScanProgress(processed, total, matched)
            SMS->>U: update progress UI
        end
        Ingest->>Ingest: startLiveListener()
        SMS->>Home: onComplete()
        Home->>U: go to Dashboard — full history already loaded
    end
```

`scanHistoricalInbox()` is a `Stream<ScanProgress>` rather than a single
`Future<int>` specifically so the onboarding screen can render live
counts instead of an indeterminate spinner while potentially thousands
of messages are scanned.

A returning user's "already onboarded?" check (`HomeShell`) no longer
depends on this screen's permission state at all — see §8c.

## 5. Sequence — categorizing a new merchant code, with bulk-similar

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant Screen as CategorizeScreen
    participant Svc as CategorizationService
    participant DB as AppDatabase

    Screen->>Svc: watchUncategorized()
    Svc->>DB: SELECT * FROM transactions WHERE category_id IS NULL
    DB-->>Screen: stream of uncategorized transactions
    U->>Screen: taps "Categorize" on a transaction
    Screen->>U: show category picker (existing chips + "new category" field)
    U->>Screen: picks or creates a category
    Screen->>Svc: categorizeCounterparty(code, categoryId)
    Svc->>DB: INSERT/UPDATE category_codes (code -> categoryId)
    Svc->>DB: UPDATE transactions SET category_id WHERE counterparty = code
    Note over DB: Every future transaction from this same code<br/>is auto-categorized on ingest from now on.

    Screen->>Svc: findSimilarUncategorized(justCategorizedTx)
    Svc->>DB: SELECT uncategorized WHERE loose-name-match(counterparty)
    DB-->>Svc: candidate list
    alt similar transactions found
        Svc-->>Screen: SimilarGroup(anchor, similar[])
        Screen->>U: "Apply to N similar transactions?"
        alt user confirms
            U->>Screen: Apply to all
            Screen->>Svc: categorizeGroup(group, categoryId)
            Svc->>DB: assignCodeToCategory for each distinct counterparty string
            Svc->>DB: UPDATE transactions SET category_id for every tx in group
        else user declines
            U->>Screen: Just this one
        end
    else no similar transactions
        Svc-->>Screen: null (no prompt shown)
    end
```

"Loose-name-match" is a case-insensitive comparison of the leading
alphabetic token of the counterparty string (e.g. "SUPERMARKET" from
both "SUPERMARKET LTD (Code: 55123)" and "SUPERMARKET LTD - TILL 2"),
not exact string equality — that's what lets one categorization catch
near-duplicate counterparty spellings instead of only exact repeats. It
deliberately returns nothing for purely numeric counterparties (bare
phone numbers), so unrelated P2P transfers never get grouped by
coincidence.

## 5a. Editing an existing categorization

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant Screen as CategorizeScreen (All tab)
    participant Svc as CategorizationService
    participant DB as AppDatabase

    Screen->>Svc: watchAll()
    Svc->>DB: SELECT * FROM transactions ORDER BY timestamp DESC
    DB-->>Screen: stream of every transaction, with current category shown
    U->>Screen: taps "Edit" on an already-categorized transaction
    Screen->>U: show category picker
    U->>Screen: picks a different category
    Screen->>Svc: categorizeSingleTransaction(txId, newCategoryId)
    Svc->>DB: UPDATE transactions SET category_id WHERE id = txId
    Note over DB: This overwrites just the one transaction —<br/>it does not change the counterparty's code-bank mapping,<br/>so future auto-categorized transactions are unaffected.
```

Category management itself (rename/delete) is a third tab on the same
screen and talks directly to the `categories` table; deleting a category
sets `category_id` back to `NULL` on every transaction that referenced
it (nullable FK, not a cascade delete) rather than deleting those
transactions.

## 6. Entity-relationship diagram (v3, Phases 1-4)

`FINANCIAL_PROVIDERS`, `PROVIDER_SENDERS`, and `SMS_MESSAGES` are new in
v2 (§8, §8a). `ACCOUNTS`, `MERCHANTS`, and `TRANSFER_LINKS` are new in v3
(§8b). `TRANSACTIONS.provider` (a bare string in v1) became
`TRANSACTIONS.provider_id`, a real foreign key.

```mermaid
erDiagram
    CATEGORIES ||--o{ CATEGORY_CODES : "labels"
    CATEGORIES ||--o{ TRANSACTIONS : "categorizes"
    CATEGORIES ||--o{ MERCHANTS : "categorizes"
    FINANCIAL_PROVIDERS ||--o{ PROVIDER_SENDERS : "known senders"
    FINANCIAL_PROVIDERS ||--o{ SMS_MESSAGES : "attributed to"
    FINANCIAL_PROVIDERS ||--o{ TRANSACTIONS : "attributed to"
    FINANCIAL_PROVIDERS ||--o{ ACCOUNTS : "backs"
    ACCOUNTS ||--o{ TRANSACTIONS : "moves money in/out of"
    MERCHANTS ||--o{ TRANSACTIONS : "resolved counterparty"
    SMS_MESSAGES ||--o| TRANSACTIONS : "evidence for"
    SMS_MESSAGES ||--o| UNPARSED_MESSAGES : "evidence for"
    TRANSACTIONS ||--o| TRANSFER_LINKS : "from side"
    TRANSACTIONS ||--o| TRANSFER_LINKS : "to side"

    CATEGORIES {
        int id PK
        string name UK
    }

    CATEGORY_CODES {
        int id PK
        string code UK "till code, merchant code, or phone number"
        string display_name "nullable, user-editable"
        int category_id FK
    }

    FINANCIAL_PROVIDERS {
        int id PK
        string code UK "mtn_momo_rw, ekash_rw, airtel_money_rw, bk_bank_rw, equity_bank_rw"
        string display_name "MTN Mobile Money, eKash, ..."
        string category "mobile_money | bank"
    }

    PROVIDER_SENDERS {
        int id PK
        string sender_pattern "e.g. M-Money, EQUITYBANK"
        int provider_id FK
    }

    SMS_MESSAGES {
        int id PK
        string sender
        string body
        string sms_hash UK "sha256(sender|body|receivedAt) — dedup key"
        int provider_id FK "nullable"
        string processing_status "pending | matched | unrecognized"
        datetime received_at
        datetime created_at
    }

    ACCOUNTS {
        int id PK
        int provider_id FK
        string label "e.g. 'My MTN Mobile Money' — no stored balance column, see §8b"
    }

    MERCHANTS {
        int id PK
        string name "e.g. 'HOPITAL LA CROIX DU SUD Ltd' — code stripped"
        string normalized_name UK "uppercased, punctuation-stripped matching key"
        int category_id FK "nullable"
    }

    TRANSFER_LINKS {
        int id PK
        int from_transaction_id FK "the debit side"
        int to_transaction_id FK "the credit side"
        string confidence "confirmed | probable"
        string match_reason "human-readable explanation, not a silent link"
        datetime created_at
    }

    TRANSACTIONS {
        int id PK
        int sms_message_id FK "nullable — null only for v1-migrated rows with no reconstructable link"
        int provider_id FK "nullable"
        int account_id FK "nullable — null only for pre-v3 rows with no resolvable provider"
        int merchant_id FK "nullable — new Phase 4 plumbing, not yet wired to any screen"
        string type "received, sent, payment, withdrawal, deposit, airtime, bank_transfer, reversed, unknown"
        real amount
        real fee
        string counterparty "nullable"
        string tx_ref "nullable"
        real balance_after "nullable"
        datetime timestamp
        string raw_sms_body
        int category_id FK "nullable"
    }

    UNPARSED_MESSAGES {
        int id PK
        int sms_message_id FK "nullable, same v1-migration caveat"
        string sender
        string body
        datetime received_at
        bool resolved
    }
```

`PROVIDER_SENDERS.sender_pattern` is deliberately many-to-one with
`FINANCIAL_PROVIDERS`, not one-to-one: the confirmed real case is MTN
Rwanda's `M-Money` shortcode, which is a registered sender for *both*
`mtn_momo_rw` and `ekash_rw` (see §8a). `SMS_MESSAGES` is the permanent
evidence table — `TRANSACTIONS`/`UNPARSED_MESSAGES` link back to it via
`sms_message_id`, but that link is nullable specifically to accommodate
rows migrated from v1, where no sender was ever stored on a transaction
and the original SMS text (`raw_sms_body`) is the only surviving trace
(the migration backfills a best-effort `SMS_MESSAGES` row for these too,
using the transaction's resolved provider's first known sender as a
documented approximation — see `AppDatabase._backfillSmsMessagesFromV1`
in `lib/data/database.dart`).

`ACCOUNTS` has no balance column at all — see §8b for why an account's
current balance is always computed from `TRANSACTIONS.balance_after`,
never stored. `TRANSFER_LINKS` connects two `TRANSACTIONS` rows without
ever deleting or merging either one; both remain the real evidence of
what each provider actually reported. `MERCHANTS` is additive alongside
`CATEGORY_CODES` — see §8b for why the existing categorization screens
were deliberately left reading from `CATEGORY_CODES` rather than
migrated in the same change that introduced `MERCHANTS`.

## 6a. The periodic tracker — `Period` model

The dashboard scopes every query to a navigable `Period` (see
`lib/analytics/period.dart`) rather than a fixed "last N days" window.
A `Period` pairs a `PeriodGranularity` (week/month/quarter/year) with a
concrete `[start, end)` range and knows how to shift itself forward or
backward one unit at a time — that's what powers the dashboard's ◀ / ▶
navigation and the "vs previous period" delta.

```mermaid
classDiagram
    class PeriodGranularity {
        <<enumeration>>
        week
        month
        quarter
        year
    }

    class Period {
        +PeriodGranularity granularity
        +DateTime start
        +DateTime end
        +Period.containing(granularity, now)$
        +Period previous
        +Period next
        +bool containsCurrent(now)
        +String label()
    }

    class AnalyticsService {
        +summary(Period? period) SpendSummary
        +summaryWithComparison(Period period) PeriodComparison
        +spendByCategory(Period? period) List~CategorySpend~
        +topCounterparties(Period? period) List~MapEntry~
    }

    class PeriodComparison {
        +Period period
        +SpendSummary current
        +SpendSummary previous
        +double? outChangeRatio
    }

    Period o-- PeriodGranularity
    AnalyticsService ..> Period : scoped by
    AnalyticsService ..> PeriodComparison : produces
    PeriodComparison o-- Period
```

Week starts Monday (`DateTime.monday`); quarters are calendar quarters
(Q1 = Jan–Mar, etc.), not fiscal quarters. `end` is always exclusive, so
every scoped query is `timestamp >= period.start AND timestamp < period.end` — this is what makes `previous`/`next` composable without
off-by-one boundary bugs (a transaction at exactly midnight on a month
boundary belongs to exactly one of the two adjacent periods, never both
or neither).

`summaryWithComparison` runs the same query twice — once for the
selected period, once for `period.previous` — and exposes
`outChangeRatio` so the dashboard can render "23% more spent than last
month" without the UI layer doing date math itself.

## 7. Transaction type state/classification model

```mermaid
stateDiagram-v2
    [*] --> RawSms: SMS received from known sender
    RawSms --> Matched: regex matches a template
    RawSms --> Unparsed: no template matches

    Unparsed --> Reviewed: user marks reviewed in Review screen
    Reviewed --> [*]

    Matched --> Received
    Matched --> Sent
    Matched --> Payment
    Matched --> Withdrawal
    Matched --> Deposit
    Matched --> Airtime
    Matched --> BankTransfer
    Matched --> Reversed

    Received --> Uncategorized: counterparty unknown
    Payment --> Uncategorized: counterparty unknown
    Sent --> Uncategorized: counterparty unknown

    Received --> Categorized: counterparty in code bank
    Payment --> Categorized: counterparty in code bank
    Sent --> Categorized: counterparty in code bank

    Uncategorized --> Categorized: user assigns category once
    Categorized --> [*]
```

## 8. Parser extensibility pattern (v2)

**Who owns a sender and who parses a body are now two separate
concerns** — v1's `MomoParser` did both (`knownSenders` +
`ownsSender()` + `tryParse()`), which broke the moment one sender
carried more than one provider's traffic (§8a). In v2, `ProviderDetector`
(lib/providers/) owns sender resolution; `MomoParser` only knows its own
`providerCode` and how to read that provider's body format.

```mermaid
classDiagram
    class MomoParser {
        <<interface>>
        +String providerCode
        +ParsedTransaction? tryParse(body, receivedAt)
    }

    class MtnRwandaParser {
        +providerCode = "mtn_momo_rw"
        +tryParse(body, receivedAt) ParsedTransaction?
    }

    class AirtelMoneyParser {
        <<planned>>
        +providerCode = "airtel_money_rw"
        +tryParse(body, receivedAt) ParsedTransaction?
    }

    class MomoParserRegistry {
        +List~MomoParser~ parsers
        +processForProvider(providerCode, body, receivedAt) ParseOutcome
    }

    class ParsedTransaction {
        +TransactionType type
        +double amount
        +double fee
        +String? counterparty
        +String? txRef
        +double? balanceAfter
        +DateTime timestamp
    }

    MomoParser <|.. MtnRwandaParser
    MomoParser <|.. AirtelMoneyParser
    MomoParserRegistry o-- MomoParser : holds many
    MomoParser ..> ParsedTransaction : produces
```

To add a provider: seed a `FinancialProviders` row + its
`ProviderSenders` patterns (`AppDatabase._seedProviders`), implement
`MomoParser` with a matching `providerCode`, add fixture SMS + unit
tests under `test/fixtures/<provider>/`, and add one line to
`MomoParserRegistry`'s constructor. `SmsIngestService`, `SmsProcessor`,
the categorization logic, and analytics never need to change.

## 8a. Provider disambiguation — one sender, multiple providers

Confirmed real case (`docs/AUDIT_PHASE_0.md` §3.2, §3.1): MTN Rwanda's
`M-Money` shortcode carries both genuine MTN MoMo traffic and eKash
traffic — two different providers sharing one sender ID. Sender alone
cannot distinguish them; `ProviderDetector.detect` resolves the tie by
body content:

```mermaid
flowchart TD
    A["sender = 'M-Money'"] --> B{"How many providers list<br/>M-Money as a known sender?"}
    B -->|"1"| C["Return that provider,<br/>confidence 1.0"]
    B -->|"2 (mtn_momo_rw, ekash_rw)"| D{"Run each candidate's<br/>registered body disambiguator"}
    D -->|"body contains 'ekash'<br/>(case-insensitive)"| E["Return ekash_rw,<br/>confidence 0.9"]
    D -->|"no 'ekash' mention"| F["Return mtn_momo_rw,<br/>confidence 0.9"]
    D -->|"no disambiguator matches<br/>(shouldn't happen given the two above,<br/>but is the generic fallback)"| G["Return first candidate,<br/>confidence 0.5 — flagged low-confidence<br/>rather than trusted blindly"]
```

Disambiguators are registered per provider code in
`lib/providers/provider_detector_factory.dart`, kept separate from the
generic `ProviderDetector` class so provider-specific body heuristics
live next to the provider they describe, not baked into the detection
engine itself. Adding a new ambiguous-sender case later (e.g. if a bank
shares a shortcode with a partner service) means adding one
`registerDisambiguator` call there — no changes to `ProviderDetector`,
`SmsIngestService`, or `SmsProcessor`.

## 8b. Multi-provider parsing, transfer matching, and merchant normalization (Phases 2-4)

**Phase 2 — real pattern library.** `MtnRwandaParser`'s regex was
rewritten entirely from real message text (a genuine 8,364-message SMS
export analyzed in `docs/AUDIT_PHASE_0.md`), replacing a placeholder
version that matched zero real messages. Four new parsers were added
against the same real evidence: `EkashParser`, `AirtelMoneyParser`,
`EquityBankParser`, `BkBankParser` — each registered in
`MomoParserRegistry` alongside `MtnRwandaParser`, routed by
`providerCode` exactly as described in §8. The full catalog of real
message shapes per provider — including confirmed real inconsistencies
like Airtel's `sent` message having three different field-naming
variants, and BK changing its own `TRANSFER` message format between an
older Kinyarwanda version and a newer English one — is documented in
`docs/SMS_PATTERN_LIBRARY.md`, which is the reference to check before
writing a new parser or debugging an unmatched real message.

**Phase 3 — accounts and transfer matching.**

```mermaid
flowchart LR
    subgraph Ledger["Existing per-message pipeline (SmsProcessor)"]
        A["BK SMS: 'TRANSFER - MTN mobile money...'"] --> B["Transactions row #1\ntype=bankTransfer, account=BK"]
        C["MTN SMS: 'You have received...'"] --> D["Transactions row #2\ntype=received, account=MTN MoMo"]
    end

    subgraph Matching["TransferMatchingEngine — runs after ingestion, not per-message"]
        B --> E{"Same amount?<br/>Within 5 min?<br/>Different accounts?"}
        D --> E
        E -->|"shared txRef matches"| F["TransferLinks row\nconfidence=confirmed"]
        E -->|"amount+time only"| G["TransferLinks row\nconfidence=probable"]
        E -->|"no match"| H["Both rows stand alone\n(real independent transactions)"]
    end

    F --> I["AnalyticsService excludes both\nlinked rows from income/expense"]
    G --> I
```

Two schema additions back this: `Accounts` (one row per seeded
`FinancialProviders` row today, e.g. "My MTN Mobile Money" — deliberately
carries **no stored balance column**; `AccountsService.currentBalance`
always computes it fresh from the most recent `Transactions.balanceAfter`
for that account, so there is never a second source of truth that could
drift from the real ledger) and `TransferLinks` (connects two
`Transactions` rows without deleting or merging either — both remain
the real evidence of what each provider actually reported).

`TransferMatchingEngine.findAndLinkTransfers()` is **not** run inline
per-message inside `SmsProcessor` — the matching counterpart of a
transfer may not have arrived yet when the first side is processed, so
it runs as an explicit batch step in `main.dart`, right after the
historical scan completes and again on every subsequent app launch
where SMS permission is already granted. It's idempotent: already-linked
transactions are excluded from the search on every run (also enforced by
`TransferLinks`'s own unique key), so calling it repeatedly never
creates duplicate links.

The confirmed real evidence this was built against (not a hypothetical):
an Equity `sent` message with `MTN Ref. 541077019015` and an MTN
`received` message with `Financial Transaction Id: 13583914317` whose
body explicitly says "Transfer from ... Equity B2C" — same amount, 3
seconds apart, on both sides of one real transfer. `AnalyticsService`'s
`summary()`/`spendByCategory()`/`monthlySpend()`/`topCounterparties()`
all now exclude linked transaction ids from their totals — before this
fix, a matched transfer pair was counted as unrelated income *and*
expense, inflating both sides of the ledger for the same real movement
of money.

**Phase 4 — merchant name/code split.** Confirmed real bug
(`docs/AUDIT_PHASE_0.md` §3.3): `"HOPITAL LA CROIX DU SUD Ltd 100126"`
and similar counterparty strings store a merchant name and its trailing
till/account code as one opaque, uncategorizable blob. `Merchants`
(new table: `name`, `normalizedName`, `categoryId`) and
`MerchantNormalizationService` fix this — `extractMerchantName` strips a
trailing 4+-digit code (optionally dash-separated), and `normalize`
collapses casing/punctuation/whitespace so "Family Bakery Ltd" and
"FAMILY BAKERY LTD." resolve to the same row instead of two.

This is added **alongside**, not in place of, the existing
`CategoryCodes`-based flow — every `Transactions` row `SmsProcessor`
writes now also gets a `merchantId` (via `MerchantNormalizationService`)
and an `accountId` (via `AccountsService.ensureAccountForProvider` —
see §8c for why this changed from a lookup-only method once Phases 5-7
made `Accounts` creation conditional on user selection), but
the Categorize/Pay/Frequent-codes screens still read from `counterparty`

+ `CategoryCodes` exactly as before. Wiring those screens over to query
  `Merchants` instead is a deliberately separate follow-up — this phase
  built and tested the correct plumbing without risking the already-shipped
  UI in the same change.

## 8c. Onboarding redesign, provider setup, profile & settings (Phases 5-7)

**The offline mandate meets a spec written for a networked app.** The
original spec for this work asked for email/SMS OTP verification during
onboarding and a "Sync Settings" entry in the Data section. Both imply
an outbound network call — a mail relay or SMS gateway for OTP delivery,
a remote counterpart for sync — which directly contradicts this app's
architectural mandate: no `INTERNET` permission is declared anywhere,
and no network-capable package (`http`, `dio`, any OTP/SMS-gateway SDK)
exists in `pubspec.yaml`. Two resolutions, both decided explicitly with
the user rather than built silently or dropped silently:

1. **Email confirmation, not real OTP delivery.** `AccountSetupScreen`
   generates a random 6-digit code and displays it on the device's own
   screen; the user re-types it to confirm. Nothing is ever sent
   anywhere — there is no real inbox-ownership proof happening, only a
   typo/attention check, and the screen's copy says so explicitly
   ("This code was generated on your device... it was not sent
   anywhere") rather than implying real delivery. A **Skip** button is
   always available and moves straight to Security Setup. Phone-number
   verification is explicitly out of scope for this pass.
2. **"Sync Settings" → "Local Backup."** `SettingsScreen`'s Data section
   reframes this as export/import of a local backup file via device
   storage only. The label and every related identifier say "backup,"
   never "sync," so nothing in the UI or code implies a network
   capability that doesn't exist. (Export Statement / Backup SMS /
   Local Backup are currently stubbed with a "coming soon" message —
   the schema and services this phase added don't yet include file
   export logic; building that is separate follow-up work.)

**Onboarding flow.** `OnboardingFlowScreen` replaces the old
single-purpose `OnboardingScreen` with six steps: Welcome → Terms &
Privacy → Account Setup → Security Setup → Provider Selection → SMS
Setup (§4a). Each step persists its own result immediately (via
`UserProfileService`/`ProviderSelectionService`) rather than threading
state through every screen to write once at the end, so a user who
force-quits mid-flow doesn't lose earlier steps on next launch. SMS
setup — the most sensitive permission ask — deliberately runs last,
after identity and security setup have established some trust, rather
than first as it did before this phase.

**Two new tables**, `UserProfile` (the single local identity — name,
email, phone, `avatarPath`, `appLockEnabled`, `onboardingCompletedAt`)
and `UserFinancialSources` (which `FinancialProviders` rows the user has
explicitly selected). Neither existed before Phase 5; `UserProfile` has
no password/credential column of any kind — `appLockEnabled` gates
access via the OS's own biometric/PIN/pattern prompt (`local_auth`),
never a secret this app stores or checks itself.

```mermaid
flowchart LR
    subgraph Before["Before Phase 6"]
        A["AppDatabase.onCreate"] --> B["_seedDefaultAccounts()\nunconditional: one Accounts row\nper EVERY FinancialProviders row"]
    end
    subgraph After["From schemaVersion 4"]
        C["User selects providers\n(ProviderSelectionScreen / Settings)"] --> D["UserFinancialSources row written"]
        D --> E["AccountsService.ensureAccountForProvider()"]
        E --> F["Accounts row created\n— only for selected providers"]
        G["SmsProcessor matches a real\ntransaction for provider X"] --> E
    end
```

**`Accounts` creation is now selection-driven, not automatic** — this
is a real behavior change, not additive plumbing like Phase 4's
`Merchants` table was. `_seedDefaultAccounts()` (the old unconditional
one-row-per-provider seed) is kept only for the v3→v4 migration's
grandfather path (below); a fresh install's `onCreate` no longer calls
it at all. The new gate is `AccountsService.ensureAccountForProvider`,
called from two places:

- `ProviderSelectionService.selectProviders` — the explicit path, when
  a user picks a provider on the onboarding screen or in Settings.
- `SmsProcessor._processOne` — a real matched transaction for a
  provider is itself sufficient evidence the user uses it, so an
  account is created on demand rather than the transaction being
  written with a null `accountId`. This was a genuine bug caught while
  wiring this phase: `SmsProcessor` originally still called the
  lookup-only `defaultAccountForProvider`, which now correctly returns
  null for any provider the user hasn't gotten to yet in the setup
  screen — silently orphaning every one of that provider's real
  transactions until the user happened to select it.

Deselecting a provider later (Settings' "Connected Services" toggle)
removes only the `UserFinancialSources` row — it never deletes the
`Accounts` row or touches `Transactions`, since a user's real history
must survive them turning a provider card off.

**Migration (schemaVersion 3 → 4).** `onUpgrade`'s `from < 4` block
creates both new tables, then grandfathers existing users: any pre-v4
install already has `Accounts` rows (from the old unconditional seed),
so rather than force them back through the new six-step flow, one
`UserProfile` row is inserted with `onboardingCompletedAt` already set,
and `UserFinancialSources` is backfilled from whatever providers those
existing accounts already reference — so Settings' Connected Services
correctly shows their real existing usage as pre-selected instead of
everything appearing off. `HomeShell`'s "already onboarded?" check
changed accordingly: from "is SMS permission currently granted"
(a proxy that conflated permission state with setup completion) to
"does `UserProfile.onboardingCompletedAt` exist" — a returning user who
denies SMS access is no longer forced to repeat the whole onboarding
flow every launch, only the SMS step itself.

**Profile & Settings (Phase 7).** Not a fifth bottom-nav destination —
an infrequent destination doesn't warrant crowding the existing
four-item bar. `DashboardScreen`'s `AppBar` gained a person-icon action
that pushes `ProfileScreen` as a full route. `ProfileScreen` shows
identity fields, a Security shortcut into `SettingsScreen`, and
Connected Accounts (reusing `AccountsService.allAccountSummaries()` and
`renameAccount`, both of which already existed from Phase 3 but had no
UI entry point until now). The spec's Profile "Subscription" row is
omitted entirely — there is no billing/IAP system anywhere in this
offline app, and a fake static badge for a feature that doesn't exist
isn't worth the maintenance surface until a real premium feature
(later phase) needs one.

## 8d. Dashboard redesign (Phase 8)

`DashboardScreen` gained three sections, each extracted to its own file
under `lib/screens/dashboard/` (mirrors the `lib/screens/profile/`
sub-folder convention):

- **Overview Card** (`overview_card.dart`) — total balance summed
  across every `AccountSummary.currentBalance`. Sums only non-null
  balances and shows an explicit caption when any account's balance is
  unknown (e.g. Equity's real SMS never reports a running balance —
  see docs/SMS_PATTERN_LIBRARY.md) rather than silently treating null
  as zero, which would understate the real total without saying so.
- **Wallet Breakdown** (`wallet_breakdown.dart`) — one row per account.
  Wires `AccountsService.allAccountSummaries()` into the dashboard for
  the first time; that method already existed correctly since Phase 3
  but was never called from any screen until now.
- **Categorization progress** (`categorization_progress.dart`) — "X%
  categorized / Y need review," replacing the old plain "All
  Uncategorized" framing. Backed by a new
  `AnalyticsService.categorizationRatio({Period? period})`, which
  counts **transactions**, not summed amounts — the spec's own framing
  describes a review workload ("how many taps are left"), not a spend
  magnitude, so one large uncategorized rent payment shouldn't look
  worse than ten small uncategorized purchases. Deliberately includes
  transfer-linked transactions in the denominator (unlike
  `summary`/`spendByCategory`, which exclude them) — a transfer never
  needs a spending category, but it's still a real ledger row that
  should count toward "how much of my data is triaged." Tapping the
  bar (when anything needs review) switches to the Categorize tab via
  a `HomeShell`-owned callback, since `DashboardScreen` doesn't own the
  bottom-nav index itself.

Both the Overview Card and Wallet Breakdown read "now" data
(`allAccountSummaries()`), independent of the dashboard's week/month/
quarter/year period selector — wallet balances don't reset each
period the way spend totals do, so they're placed above the period
controls rather than inside the period-scoped section.

## 9. USSD quick-dial flow (no session automation)

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant Screen as PayScreen
    participant Norm as PhoneNormalizer
    participant Builder as UssdBuilder
    participant Dialer as UssdDialer
    participant OS as Native Android Dialer

    U->>Screen: picks a recipient (contact / frequent code / manual) + amount
    U->>Screen: taps "Open dialer to pay"
    alt merchant/till payment
        Screen->>Builder: payMerchant(tillCode, amount)
    else phone recipient
        Screen->>Norm: normalizeRwandanMobile(rawRecipient)
        alt not a valid Rwandan number
            Norm-->>Screen: null
            Screen->>U: show error, do not dial
        else valid
            Norm-->>Screen: canonical 0XXXXXXXXX
            Screen->>Builder: sendMoney(normalizedPhone, amount)
        end
    end
    Builder-->>Screen: "*182*1*1*<phone>*<amount>#" (assert-guarded)
    Screen->>Dialer: dial(ussdCode)
    Dialer->>OS: launchUrl(tel:*182*1*1*...#)
    OS-->>U: dialer opens, code prefilled
    Note over U,OS: User manually confirms/sends.<br/>App never reads the USSD response<br/>or automates the session (no Accessibility Service).
```

## 9a. Pay/USSD phone-normalization fix (Phase 9)

**Confirmed real bug, root cause.** A reported broken dialer code —
`*182*8*1*627434673883892627492*100#` — traced to **two** distinct
gaps, both now fixed:

1. **No normalization anywhere in the recipient path.** The contact
   picker (`ContactsService.loadContactsWithPhoneNumbers`) only did
   `.trim()`; manual entry and frequent-code selection did nothing at
   all. A malformed or merged Android contact record (common when a
   contact is synced from multiple accounts — WhatsApp, SIM, Google)
   could reach `UssdBuilder.sendMoney` completely unsanitized.
2. **The Frequent-code picker hardcoded `_isMerchantPayment = true`
   for every selection** (`pay_screen.dart`), regardless of whether the
   selected code was actually a merchant till code or a free-text P2P
   counterparty string (`CodeUsage.code` is `Transactions.counterparty`
   verbatim — for a person-to-person transfer, that's a phone-shaped
   string, not a till code). Forcing the `payMerchant` path
   (`*182*8*1*...#` — the exact prefix in the reported bug) for a
   phone-shaped code sent an unvalidated string down the wrong builder
   method entirely.

**Fix.** New `lib/ussd/phone_normalizer.dart`: `PhoneNormalizer` (one
owner, static methods matching `UssdBuilder`'s style) recognizes the
real Rwandan mobile shapes (`0XXXXXXXXX`, 9-digit with no leading 0,
`+250XXXXXXXXX`, `250XXXXXXXXX`) and returns the canonical 10-digit
form, or `null` for anything else — including the actual reported
garbage string. `PayScreen._pay()` is the one place all three
`_PayTarget` paths converge before dialing, so it's the single
normalization call site: on `null`, a snackbar error is shown and
nothing is dialed. The Frequent-code picker's merchant-vs-phone
decision now checks `PhoneNormalizer.normalizeRwandanMobile(code) ==
null` instead of assuming merchant unconditionally.
`UssdBuilder.sendMoney` also gained a defensive `assert` (stripped in
release, so it can't itself introduce a new release-mode failure path)
as a second line of guard against any future call site bypassing
normalization. `ContactsService` itself is deliberately untouched —
normalizing at load time would hide the real underlying contact data
from the picker and duplicate the check already done in `_pay()`.

## 10. Performance: the historical SMS scan (Phase 10)

**Confirmed real jank.** "Skipped N frames" during onboarding's
historical scan, on a real ~8,364-message device inbox. Root cause:
the entire scan ran on the main isolate — per-message dedup query,
provider detection (2 DB queries), regex parsing, category lookup,
account/merchant resolution, an insert, and an update — roughly 6-8
sequential awaited database round-trips per message, serializing
against Flutter's event loop for thousands of messages.

**Constraint.** `drift_flutter`'s `driftDatabase()` already runs actual
SQL execution on drift's own background executor — the jank isn't raw
query cost, it's the sheer *count* of round-trips plus CPU-bound
parsing work running directly on the main isolate between them. A new
isolate can't share the existing `AppDatabase` connection, so database
writes have to stay on the main isolate; the fix is cutting how much
work happens per round-trip and moving the CPU work off-thread, not
relocating the database itself.

```mermaid
flowchart TB
    subgraph Main["Main isolate"]
        A["Snapshot FinancialProviders/ProviderSenders once\n(plain ProviderSnapshot DTOs)"]
        B["Snapshot existing SmsMessages.smsHash once\n(in-memory Set)"]
        C["Chunk raw inbox (400 msgs/chunk)"]
        G["SmsProcessor.processBatch(chunk)\n— one drift transaction per chunk,\naccount/merchant lookups cached per chunk"]
        H["yield ScanProgress per chunk"]
    end
    subgraph Isolate["Background isolate (compute)"]
        D["parseChunk(): sender-match + regex parse\nper message, using only the snapshots\n— no DB handle, no live service objects"]
    end
    A --> C
    B --> C
    C -->|"compute(parseChunk, ...)"| D
    D -->|"List&lt;ParsedSmsResult&gt; (plain data)"| G
    G --> H
    H -->|"next chunk"| C
```

**What moved and what didn't.** Sender-pattern matching, the MTN/eKash
body disambiguation rule, regex parsing, and SHA-256 hashing (all pure
CPU work) now run inside `compute(parseChunk, ...)` in
`lib/sms/isolate_parsing.dart`, using only the `ProviderSnapshot`/
`RawSmsSnapshot` plain-data types — no drift row, connection, or
service object ever crosses the isolate boundary, since `compute()`
requires its argument to be independent of the main isolate's state.
Database writes stay on the main isolate (a second isolate can't reuse
`AppDatabase`'s connection) but are restructured: `SmsMessages` rows
are still inserted individually (not batched) because
`Transactions.smsMessageId`/`UnparsedMessages.smsMessageId` need each
row's real generated id to link back to — drift's `batch()` API
doesn't return per-row ids synchronously, so batching that specific
insert would silently drop the evidence link the rest of this app
depends on. The transaction/unparsed-message writes that follow *are*
batched via `SmsProcessor.processBatch`, since those don't need each
other's ids — that's where the real round-trip savings come from,
since those are the two writes that happen once per message. Account
and merchant resolution are cached per batch call, so repeat lookups
for the same provider/counterparty within a chunk are free in-memory
hits after the first.

The live SMS listener (`SmsIngestService.startLiveListener`, one
message at a time) is untouched — this restructuring only applies to
the bulk historical scan, where the message count actually makes the
main-isolate cost visible.

`_scanChunkSize = 400` (messages per `compute()` call) — large enough
to amortize isolate spawn/message-passing overhead, small enough that
the progress UI updates roughly every 1-2 seconds of scan time.
Tuned against the real ~8,364-message export this project has used
throughout; revisit if on-device profiling suggests otherwise.

## 11. Premium architecture preparation (Phase 11 — prep only)

Per spec, this phase prepares architecture for a future paid Statement
Export feature without implementing it. New `lib/premium/` module
(`statement_exporter.dart`): a `StatementFormat` enum (`pdf`, `excel`,
`csv`), an abstract `StatementExporter` interface with no network
parameter of any kind by design, and `UnimplementedStatementExporter`
(throws `UnimplementedError`) so Settings' existing "Export Statement"
stub (Phase 7) has a real-if-disabled type behind it. No concrete
`PdfStatementExporter`/etc. and no new `pubspec.yaml` dependency
(`pdf`/`excel`/`csv`) — those are implementation-phase work, out of
scope here.

**Cloud SMS Backup prep was dropped entirely**, by explicit user
decision — not built as an unused interface. The spec's second paid
feature ("Cloud SMS Backup," encrypted cloud storage of SMS + call
logs) is a categorical exception to this app's hard no-`INTERNET`-
permission architecture, the same conflict Phase 5's OTP requirement
hit. Unlike Phase 5 (where an on-screen, non-delivered confirmation
code was an honest local substitute preserving the intended UX), there
is no honest local substitute for "cloud backup" — a local encrypted
export is a fundamentally different feature (see "Local Backup" in
Phase 7's Settings), not a stand-in for sync-to-cloud. Rather than
half-build a `BackupTransport`-shaped interface nobody asked to have
exist yet, this was scoped out; if a real cloud feature is ever
pursued, that requires a separate, explicit product conversation, not
something a prep-only phase should quietly pave the way for.

## 12. Why these tradeoffs

| Decision                                                                                   | Alternative considered                                                                   | Why rejected                                                                                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Regex parser, no ML                                                                        | On-device TFLite classifier                                                              | MoMo SMS is template-structured; ML adds training-data, model-size, and debuggability overhead for a problem regex already solves deterministically                                                                                                                                                                                                     |
| No seed data for categories                                                                | Ship a starter merchant→category bank                                                   | User explicitly wants full control; a wrong auto-guess is worse than one extra tap the first time a code is seen                                                                                                                                                                                                                                        |
| `tel:` intent hand-off for USSD                                                          | Accessibility Service session automation                                                 | Automating USSD sessions is fragile across OEM dialers/Android versions and closer to a permissions/security gray area for marginal convenience gain                                                                                                                                                                                                    |
| drift/SQLite over a NoSQL/file store                                                       | Flat file (JSON/CSV)                                                                     | Analytics needs grouped aggregation (`SUM ... GROUP BY category`) — SQL is the right tool, and drift adds compile-time query safety                                                                                                                                                                                                                  |
| Fail-to-review-queue over best-effort guess                                                | Regex with loose fallback matching                                                       | A wrong transaction type/amount silently corrupts analytics; an unparsed message sitting in a queue is visible and fixable                                                                                                                                                                                                                              |
| Embedded-date-then-inbox-date-then-now fallback chain                                      | Always use`DateTime.now()` at ingest time (the original implementation)                | Historical scan would date every past transaction to the scan moment, collapsing months of history into one period and making the periodic tracker meaningless for anything but freshly-arriving messages                                                                                                                                               |
| Loose substring bulk-categorize, confirmed per-batch                                       | Auto-apply silently whenever a substring matches                                         | A silent auto-apply on a fuzzy (not exact) match risks mis-categorizing an unrelated transaction that happens to share a word; a confirmation dialog costs one tap and eliminates that risk                                                                                                                                                             |
| Nullable FK + reassign-to-NULL on category delete                                          | Cascade-delete transactions when their category is deleted                               | A transaction is a fact (money moved); deleting the label it wore should never destroy the record of the money movement itself                                                                                                                                                                                                                          |
| Streamed`ScanProgress` for onboarding                                                    | Fire-and-forget scan behind a plain spinner (the original implementation)                | A historical inbox can be thousands of messages; an indeterminate spinner gives no signal the app hasn't hung, whereas live counts confirm forward progress                                                                                                                                                                                             |
| Two-stage capture-then-process pipeline (Phase 1)                                          | Keep v1's single-step SMS→Transaction parse                                             | Audited and confirmed as the wrong shape (`docs/AUDIT_PHASE_0.md` §1): no way to re-derive transactions after a parser fix without re-reading the phone's inbox, no dedup key, "provider" was a free string. Splitting capture (`SmsIngestService`) from parsing (`SmsProcessor`) makes reprocessing possible and gives provider a real identity |
| SHA-256 hash of`sender\|body\|receivedAt` as the dedup key                                 | A unique constraint on`txRef` alone                                                    | Not every real message carries a usable reference number (confirmed real MTN formats vary — some have`TxId`, some don't; see §3.2 in the audit), but every message has a sender, body, and timestamp, so the hash is always computable and still collision-safe in practice                                                                         |
| Real drift`onUpgrade` migration with backfill, not a destructive reset                   | Bump`schemaVersion` and let drift wipe/recreate                                        | This app's whole purpose is being a financial history; a schema change silently deleting a user's existing transaction history on their next app update would be a serious regression, not just an inconvenience                                                                                                                                        |
| Sender→provider is many-to-many via`ProviderSenders`, disambiguated by body content     | Assume one sender = one provider (v1's implicit assumption)                              | Confirmed false by real data: MTN Rwanda's`M-Money` shortcode carries both MoMo and eKash traffic. A body-content disambiguator (registered per ambiguous sender) is the minimum mechanism that actually resolves this correctly                                                                                                                      |
| Independent per-field regex extraction, not one sequential template per provider (Phase 2) | One strict left-to-right regex per message shape                                         | Confirmed real Airtel`sent` messages alone have three different field-naming variants (`Amount RWF X. CHARGES RWF Y`, no-space/no-RWF, `Amt`/`Fee`/`BAL`); a sequential pattern only ever matches the variant it was written against                                                                                                          |
| Account balance computed on read, never stored (Phase 3.2)                                 | A`balance` column on `Accounts`, updated on every transaction insert                 | Two sources of truth for the same number — a stored balance could silently drift from what the transaction history actually shows if a transaction is ever edited or deleted; for a financial ledger, history must remain the only source of truth                                                                                                     |
| Transfer matching as an explicit batch stage, not inline per-message (Phase 3.1)           | Check for a transfer match immediately inside`SmsProcessor` as each message is written | The matching counterpart of a transfer may not have arrived yet when the first side is processed (real evidence: the two sides of the same transfer arrived via different SMS, seconds apart) — a batch pass after ingestion is the only ordering that can see both sides reliably                                                                     |
| `TransferLinks` connects two `Transactions` rows; never merges or deletes either       | Replace both rows with one synthetic "transfer" transaction                              | Each row is the real evidence of what its own provider actually reported (its own txRef, its own exact wording) — collapsing them into one synthetic row would destroy that evidence for the sake of a slightly simpler analytics query                                                                                                                |
| `Merchants` added alongside `CategoryCodes`, existing screens left untouched (Phase 4) | Migrate Categorize/Pay/Frequent-codes screens to`Merchants` in the same change         | The categorization bug (merchant name + code stored as one opaque string) is real and confirmed, but the existing screens already work correctly against`CategoryCodes` today; introducing new plumbing and rewiring working, shipped UI in one change multiplies the blast radius of any mistake for no compounding benefit                          |
| On-screen generated code instead of real email/SMS OTP delivery (Phase 5) | Add an `http`/OTP-gateway dependency to actually send codes | Directly violates the no-`INTERNET`-permission architectural mandate; a locally-generated, on-screen-displayed code preserves the code-entry UX shape while being honest that nothing is verified remotely |
| "Local Backup" (export/import a file) instead of "Sync Settings" (Phase 7) | Build a real sync mechanism, or keep the "Sync" label with no backing feature | The spec's wording implies a remote counterpart this app cannot have by design; renaming to match what the feature actually does (a local file) avoids a label that lies about capability |
| `Accounts` created only for user-selected providers, not auto-seeded for every registry row (Phase 6) | Keep the old unconditional one-account-per-provider seed and treat provider selection as purely cosmetic | The spec's "Select Financial Providers" screen should mean something — an unconditional seed would make the selection UI a no-op; the tradeoff is `SmsProcessor` must create an account on demand (`ensureAccountForProvider`) for any provider with a real matched transaction, so a user's actual usage is never silently orphaned even if they haven't visited the selection screen for that provider yet |
| Each onboarding step persists immediately, not just at flow completion (Phase 5) | Thread all onboarding state through to one write at the final step | A user who force-quits mid-flow (e.g. after Account Setup but before Provider Selection) keeps what they already entered on next launch instead of losing it and starting over |
| Trailing-4+-digit-code stripping as the merchant/code split heuristic                      | Split on the last whitespace-separated token unconditionally                             | A trailing short number (1-3 digits) is more likely to be part of a name (e.g. a unit number) than an account code in the confirmed real examples; a 4-digit floor matches every real code observed (`096957`, `902850`, `08077`, `20231`) without over-stripping shorter tokens                                                                |
| Categorization progress counts transactions, not summed amounts (Phase 8) | Weight the ratio by spend amount | The spec's own framing ("X% categorized / Y need review") describes a review workload, not a spend-magnitude metric — one large uncategorized rent payment shouldn't make the meter look worse than ten small uncategorized purchases when the real task (tap the category picker) is identical either way |
| `PhoneNormalizer` as the single owner, called once at the `PayScreen._pay()` convergence point (Phase 9) | Normalize inside `ContactsService` at load time | Would only fix the contact-picker path, leaving manual entry and frequent-code selection still vulnerable — the confirmed real bug also came from `_isMerchantPayment` being hardcoded true for every frequent code, not just from unnormalized phone strings; normalizing at load time would also hide the real underlying contact record from the picker |
| Isolate-safe plain-data snapshots (`ProviderSnapshot`/`RawSmsSnapshot`) instead of passing live service objects into `compute()` (Phase 10) | Share the existing `AppDatabase`/`ProviderDetector` instances with a spawned isolate | `compute()` requires its argument to be independent of the main isolate's state; a drift connection is bound to the isolate that created it, so a live service object couldn't safely cross the boundary at all — plain DTOs captured once up front are the only isolate-safe option |
| `SmsMessages` rows inserted individually even in the batched scan path, only `Transactions`/`UnparsedMessages` are truly batched (Phase 10) | Batch all three inserts together for maximum round-trip reduction | `Transactions.smsMessageId`/`UnparsedMessages.smsMessageId` need each `SmsMessages` row's real generated id to link back to, and drift's `batch()` API doesn't return per-row ids synchronously — batching that specific insert would silently drop the evidence link the rest of this app depends on |
| Cloud SMS Backup prep dropped entirely, not built as an unused interface (Phase 11) | Design a transport-agnostic `BackupTransport` interface now, implement nothing | Unlike Phase 5's OTP (where an honest local substitute preserved the intended UX), there is no honest local substitute for "cloud backup" — a local encrypted export is a different feature, not a stand-in; half-building an interface for a feature that categorically conflicts with the no-network mandate risks looking like tacit permission to build the network path later without a separate, explicit product decision |
