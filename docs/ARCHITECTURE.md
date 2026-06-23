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
            IngestSvc["SmsIngestService\nlib/sms/\n(emits ScanProgress)"]
            ParserReg["MomoParserRegistry\nlib/parsers/"]
            CatSvc["CategorizationService\nlib/categorization/\n(bulk-similar, CRUD)"]
            AnalyticsSvc["AnalyticsService\nlib/analytics/\n(Period-scoped)"]
        end

        subgraph Infra["Platform integration"]
            Telephony["telephony plugin\n(SMS read + listener)"]
            PermHandler["permission_handler\n(READ_SMS / RECEIVE_SMS)"]
            UrlLauncher["url_launcher\n(tel: intent)"]
        end

        DB[("AppDatabase\nSQLite via drift\nlib/data/")]

        Onboarding --> IngestSvc
        Dashboard --> AnalyticsSvc
        Categorize --> CatSvc
        Review --> DB
        Ussd --> UrlLauncher

        IngestSvc --> Telephony
        IngestSvc --> PermHandler
        IngestSvc --> ParserReg
        IngestSvc --> DB
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

## 4. Data flow — ingesting one SMS

```mermaid
sequenceDiagram
    autonumber
    participant OS as Android SMS Provider
    participant Ingest as SmsIngestService
    participant Reg as MomoParserRegistry
    participant Parser as MtnRwandaParser
    participant DB as AppDatabase (SQLite)

    OS->>Ingest: new SMS (sender, body, inbox date)
    Ingest->>Reg: isKnownSender(sender)?
    alt sender not recognized
        Reg-->>Ingest: false
        Ingest--xIngest: ignored (not MoMo)
    else sender recognized
        Reg-->>Ingest: true
        Ingest->>Reg: process(sender, body, receivedAt)
        Reg->>Parser: tryParse(body, receivedAt)
        Note over Parser: timestamp = date embedded in body,<br/>else receivedAt (SMS inbox date),<br/>else DateTime.now() as last resort
        alt regex matches a known template
            Parser-->>Reg: ParsedTransaction
            Reg-->>Ingest: ParseOutcome.parsed
            Ingest->>DB: findCategoryByCode(counterparty)
            DB-->>Ingest: Category? (nullable)
            Ingest->>DB: INSERT INTO transactions (...)
        else no template matches
            Parser-->>Reg: null
            Reg-->>Ingest: ParseOutcome.unparsed
            Ingest->>DB: INSERT INTO unparsed_messages (...)
        end
    end
```

The `receivedAt` fallback matters most during the historical scan: a
message from 8 months ago must be dated 8 months ago, not "now," or
every periodic report (§6a) would bucket all historical spend into
whichever period the scan happened to run in.

## 4a. Initial setup — onboarding + full-history ingestion

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant Home as HomeShell
    participant OB as OnboardingScreen
    participant Ingest as SmsIngestService
    participant DB as AppDatabase

    Home->>Ingest: hasPermissions()?
    alt already granted (returning user)
        Ingest-->>Home: true
        Home->>Ingest: startLiveListener()
        Home->>U: go straight to Dashboard
    else first run
        Ingest-->>Home: false
        Home->>OB: show OnboardingScreen
        OB->>U: explain on-device-only SMS access
        U->>OB: taps Continue
        OB->>Ingest: requestPermissions()
        alt permission denied
            Ingest-->>OB: false
            OB->>U: show retry screen
        else permission granted
            Ingest-->>OB: true
            OB->>Ingest: scanHistoricalInbox() [stream]
            loop for each message in inbox
                Ingest-->>OB: ScanProgress(processed, total, matched)
                OB->>U: update progress UI
            end
            Ingest->>Ingest: startLiveListener()
            OB->>Home: onComplete()
            Home->>U: go to Dashboard — full history already loaded
        end
    end
```

`scanHistoricalInbox()` is a `Stream<ScanProgress>` rather than a single
`Future<int>` specifically so the onboarding screen can render live
counts instead of an indeterminate spinner while potentially thousands
of messages are scanned.

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

## 6. Entity-relationship diagram

```mermaid
erDiagram
    CATEGORIES ||--o{ CATEGORY_CODES : "labels"
    CATEGORIES ||--o{ TRANSACTIONS : "categorizes"

    CATEGORIES {
        int id PK
        string name UK
    }

    CATEGORY_CODES {
        int id PK
        string code UK "till code, merchant code, or phone number"
        int category_id FK
    }

    TRANSACTIONS {
        int id PK
        string provider "mtn_rw, airtel_rw, ..."
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
        string sender
        string body
        datetime received_at
        bool resolved
    }
```

`UNPARSED_MESSAGES` has no foreign key relationship — it's a holding
queue, not part of the transaction graph, until a human (or an updated
parser) resolves it.

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
every scoped query is `timestamp >= period.start AND timestamp <
period.end` — this is what makes `previous`/`next` composable without
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

## 8. Parser extensibility pattern

```mermaid
classDiagram
    class MomoParser {
        <<interface>>
        +String providerId
        +Set~String~ knownSenders
        +bool ownsSender(sender)
        +ParsedTransaction? tryParse(body, receivedAt)
    }

    class MtnRwandaParser {
        +providerId = "mtn_rw"
        +knownSenders = {M-Money, MTN, MoMo}
        +tryParse(body, receivedAt) ParsedTransaction?
    }

    class AirtelRwandaParser {
        <<planned>>
        +providerId = "airtel_rw"
        +tryParse(body, receivedAt) ParsedTransaction?
    }

    class MomoParserRegistry {
        +List~MomoParser~ parsers
        +isKnownSender(sender) bool
        +process(sender, body, receivedAt) ParseOutcome
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
    MomoParser <|.. AirtelRwandaParser
    MomoParserRegistry o-- MomoParser : holds many
    MomoParser ..> ParsedTransaction : produces
```

To add a provider: implement `MomoParser`, add fixture SMS + unit tests
under `test/fixtures/<provider>/`, and add one line to
`MomoParserRegistry`'s constructor. `SmsIngestService`, the database
schema, categorization, and analytics never need to change.

## 9. USSD quick-dial flow (no session automation)

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant Screen as UssdScreen
    participant Builder as UssdBuilder
    participant Dialer as UssdDialer
    participant OS as Native Android Dialer

    U->>Screen: selects action (Send / Pay / Airtime / Balance) + fills fields
    U->>Screen: taps "Open dialer"
    Screen->>Builder: sendMoney(phone, amount) etc.
    Builder-->>Screen: "*182*1*1*<phone>*<amount>#"
    Screen->>Dialer: dial(ussdCode)
    Dialer->>OS: launchUrl(tel:*182*1*1*...#)
    OS-->>U: dialer opens, code prefilled
    Note over U,OS: User manually confirms/sends.<br/>App never reads the USSD response<br/>or automates the session (no Accessibility Service).
```

## 10. Why these tradeoffs

| Decision | Alternative considered | Why rejected |
|---|---|---|
| Regex parser, no ML | On-device TFLite classifier | MoMo SMS is template-structured; ML adds training-data, model-size, and debuggability overhead for a problem regex already solves deterministically |
| No seed data for categories | Ship a starter merchant→category bank | User explicitly wants full control; a wrong auto-guess is worse than one extra tap the first time a code is seen |
| `tel:` intent hand-off for USSD | Accessibility Service session automation | Automating USSD sessions is fragile across OEM dialers/Android versions and closer to a permissions/security gray area for marginal convenience gain |
| drift/SQLite over a NoSQL/file store | Flat file (JSON/CSV) | Analytics needs grouped aggregation (`SUM ... GROUP BY category`) — SQL is the right tool, and drift adds compile-time query safety |
| Fail-to-review-queue over best-effort guess | Regex with loose fallback matching | A wrong transaction type/amount silently corrupts analytics; an unparsed message sitting in a queue is visible and fixable |
| Embedded-date-then-inbox-date-then-now fallback chain | Always use `DateTime.now()` at ingest time (the original implementation) | Historical scan would date every past transaction to the scan moment, collapsing months of history into one period and making the periodic tracker meaningless for anything but freshly-arriving messages |
| Loose substring bulk-categorize, confirmed per-batch | Auto-apply silently whenever a substring matches | A silent auto-apply on a fuzzy (not exact) match risks mis-categorizing an unrelated transaction that happens to share a word; a confirmation dialog costs one tap and eliminates that risk |
| Nullable FK + reassign-to-NULL on category delete | Cascade-delete transactions when their category is deleted | A transaction is a fact (money moved); deleting the label it wore should never destroy the record of the money movement itself |
| Streamed `ScanProgress` for onboarding | Fire-and-forget scan behind a plain spinner (the original implementation) | A historical inbox can be thousands of messages; an indeterminate spinner gives no signal the app hasn't hung, whereas live counts confirm forward progress |
