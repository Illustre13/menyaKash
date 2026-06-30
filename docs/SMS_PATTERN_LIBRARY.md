# SMS Pattern Library

Real message-shape catalog, extracted from a genuine 8,364-message device
SMS export (`public/sms-20260713181737.xml`, gitignored — contains real
personal data) and analyzed for `docs/AUDIT_PHASE_0.md` and Phase 2 of the
parser rewrite. Every pattern below is quoted (with names/numbers redacted)
from real messages, not guessed. Fixture files with the full redacted text
live under `test/fixtures/<provider>/`.

This is the reference other engineers (or future-you) should check before
writing a new parser or debugging why a real message didn't match — if a
real message doesn't fit any shape below, that's a genuine gap, not a bug
in existing regex.

---

## MTN Mobile Money (`mtn_momo_rw`) — sender: `M-Money`

| Shape | Transaction type | Pattern | Counterparty | Reference | Balance |
|---|---|---|---|---|---|
| `received` | received | `You have received AMOUNT RWF from NAME (MASKED_PHONE) on your mobile money account at TIMESTAMP. Message from sender: TEXT. Your new balance:BAL RWF. Financial Transaction Id: ID.` | name only — **phone is masked** (`*********318`, 9 stars + last 3 digits) | `Financial Transaction Id` | `Your new balance:` |
| `sent` | sent | `*165*S*AMOUNT RWF transferred to NAME (FULL_PHONE) from ACCOUNT at TIMESTAMP . Fee was: FEE RWF. New balance: BAL RWF. ...` | name + **full** phone number | none in this shape (no TxId) | `New balance:` |
| `payment` | payment | `TxId: ID. Your payment of AMOUNT RWF to MERCHANT_NAME MERCHANT_CODE has been completed at TIMESTAMP. Your new balance: BAL RWF. Fee was FEE RWF...` | merchant name + trailing numeric code, **one unstructured blob** — this is the exact string the Phase 4 categorization bug operates on | `TxId:` | `Your new balance:` |
| `withdrawal` | withdrawal | `You NAME (MASKED_PHONE) have via agent: AGENT_NAME (AGENT_PHONE), withdrawn AMOUNT RWF from your mobile money account: ACCOUNT at TIMESTAMP and you can now collect your money in cash. Your new balance: BAL RWF. Fee paid: FEE RWF. ... Financial Transaction Id: ID.` | agent name + phone | `Financial Transaction Id` | `Your new balance:` |
| `deposit` | deposit | `*113*R*A bank deposit of AMOUNT RWF has been added to your mobile money account at TIMESTAMP. Your NEW BALANCE :BAL RWF. ...` | none (bank-initiated) | none | `Your NEW BALANCE :` |
| `bundle_purchase` / merchant debit | payment | `*164*S*Y'ello,A transaction of AMOUNT RWF by MERCHANT_NAME  on your MOMO account was successfully completed at TIMESTAMP. Message from debit receiver: TEXT. Your new balance:BAL RWF. Fee was FEE RWF. Financial Transaction Id: ID. External Transaction Id: EXT_ID.*EN#` | merchant name (double space before "on") | `Financial Transaction Id` | `Your new balance:` |
| `airtime` | airtime | `*162*TxId:ID*S*Your payment of AMOUNT RWF to Airtime with token  has been completed at TIMESTAMP. Fee was FEE RWF. Your new balance: BAL RWF . Message: - -. *EN#` | literal "Airtime" | `TxId:` | `Your new balance:` |
| `failed` | unknown/failed — **not currently modeled as a TransactionType** | `*143*R*Y'ello, the transaction with amount AMOUNT RWF for MERCHANT with message: TEXT failed at TIMESTAMP .Please Contact MobileMoney HelpLine for Assistance...` | merchant name | none | none — transaction did not complete |

**No genuine "reversed" MTN MoMo transaction message was found anywhere
in the real export.** The v1 parser had a `reversed` regex and fixture
that were pure speculation (confirmed zero matches against 8,364 real
messages) — removed in Phase 2 rather than kept as unverified dead code.
If a real reversal message is ever observed, add it here first.

**eKash rides the same `M-Money` sender** but is a distinct provider
(`ekash_rw`) per the Phase 1 disambiguator — its payment shape is
identical to MTN's `*162*TxId:...*S*` merchant-payment shape except the
merchant name is literally `eKash`:
```
*162*TxId:13559072472*S*Your payment of 500 RWF to eKash with token  has been completed at 2024-04-15 21:39:02. Fee was 20 RWF. Your new balance: 21931 RWF . Message: - ACSC. *EN#
```

## Airtel Money (`airtel_money_rw`) — senders: `AirtelMoney`, `AIRTELMONEY`

| Shape | Transaction type | Pattern | Reference | Balance |
|---|---|---|---|---|
| `received` | received | `*151*Txn ID ID*R* You have received RWF AMOUNT from NAME PHONE in MTN RWANDA.Your NEW BALANCE isRWF BAL. *EN#` | `Txn ID` | `NEW BALANCE is` |
| `sent` | sent | `*165* TXN ID ID*S*  Money successfully sent to NAME  in MTN . Amount RWF AMOUNT. CHARGES RWF FEE. Your NEW BALANCE is RWF BAL. *EN#` | `TXN ID` | `NEW BALANCE is` |
| `payment` | payment | `*161*TXN ID (ID)*S*Payment of RWF AMOUNT to MERCHANT_NAME - MERCHANT_CODE successful.Your NEW BALANCE is RWF BAL. *EN#` | `TXN ID` | `NEW BALANCE is` |
| `bundle_purchase` | airtime/payment | `*150* TXN ID ID*S Your NEW BALANCE is Rwf BAL. Purchase of Bundle of Rwf AMOUNT successful. *EN#` | `TXN ID` | appears *before* the amount in this shape — balance-then-purchase-amount, opposite field order from every other shape |

**Confirmed real inconsistency, not a hypothesis:** the `sent` shape alone
has at least three field-name variants across different real messages —
`Amount RWF X. CHARGES RWF Y`, `Amount XCHARGES RWF Y` (no space, no
"RWF" before the number), and `Amt RWF X. Fee RWF Y. BAL RWF Z`. The
parser's field extraction must be independent-per-field (already the
pattern used in `MtnRwandaParser`), not a single sequential template,
specifically because of this — a strict left-to-right regex would break
on whichever variant it wasn't written against.

## Equity Bank (`equity_bank_rw`) — sender: `EQUITYBANK`

| Shape | Transaction type | Pattern | Counterparty | Reference |
|---|---|---|---|---|
| `sent` (to MTN MoMo number) | bankTransfer | `AMOUNT RWF was successfully sent to NAME PHONE. MTN Ref. REF. Ref. REF on DATE at TIME CAT. Charges FEE RWF` | name + full phone | `MTN Ref.` — **this is the cross-provider correlation key for transfer matching (Phase 3)** | 
| `sent` (to masked account) | bankTransfer | `AMOUNT RWF has been successfully sent to NAME MASKED_ACCOUNT. Ref. REF on DATE at TIME CAT. Transaction charge FEE RWF, SMS alert charge FEE2 RWF` | name + masked account (`4********7268`) | `Ref.` |
| `received` | received | `You have received AMOUNT RWF from NAME MASKED_ACCOUNT to your Equity account MASKED_ACCOUNT. Ref. REF on DATE at TIME CAT` | name + masked account | `Ref.` |

Equity has no `balanceAfter` field in any confirmed shape — unlike every
MTN/Airtel shape, none of these messages report a running balance.
`ParsedTransaction.balanceAfter` will be `null` for every Equity
transaction; this is expected, not a parser gap.

## Bank of Kigali (`bk_bank_rw`) — sender: `BKeBANK`

| Shape | Transaction type | Pattern | Reference |
|---|---|---|---|
| `transfer_to_momo` (Kinyarwanda, older) | bankTransfer | `TRANSFER - MTN mobile money  Konti ihabwa amafr: PHONE  Konti ivaho amafr: ACCOUNT  Umubare:RWF AMOUNT  Igikorwa #: REF  Status: STATUS Itariki: DATE  Aho byakorewe:MOBILE` | `Igikorwa #:` |
| `transfer_to_momo_v2` (English, newer) | bankTransfer | `TRANSFER - MTN mobile money Credited account: PHONE  Debited account: ACCOUNT  Amount: RWF AMOUNT Transaction Charge: RWF FEE Event #: REF  Status: STATUS Date: DATE  Channel:MOBILE Available Balance: RWF BAL ...` | `Event #:` |
| `deposit` | deposit | `Deposit Ref#:REF. NAME has deposited RWF AMOUNT to (RECIPIENT_NAME-ACCOUNT). Agent AGENT_NAME at LOCATION. Date: DATE. Status: SUCCESSFUL` | `Deposit Ref#:` |

**Confirmed: BK changed its own TRANSFER message format between the
Kinyarwanda/`Igikorwa #` version and the English/`Event #` version** —
both appear in the same real export at different dates. A parser
targeting only one will silently miss the other; both are modeled as
separate regex alternatives in `BkBankParser`, not assumed to be the
same shape with cosmetic differences.

`TRANSFER - Bank of ...` and `TRANSFER - I&M BANK ...` variants were
also observed (transfers to other banks, not MTN) but not yet
fixture-covered or parsed — flagged here as a known gap for a future
pass, not silently ignored.

## eKash (`ekash_rw`) — sender: `M-Money` (shared with MTN MoMo)

See MTN section above — eKash's only confirmed real shape is the
`*162*TxId:...*S*...to eKash with token...` payment format. No eKash
`received`/`withdrawal`/`deposit` shape was found in the real export.

## Cross-provider transfer-matching evidence (Phase 3)

Two real, concrete linkage examples found in the export, used as the
basis for `TransferMatchingEngine`'s test fixtures:

1. **BK → MTN MoMo (same person, own accounts):** A BK `TRANSFER - MTN
   mobile money` message (`Igikorwa #: FTCM24124SVR7GLGS`, amount
   100000, `2024-05-03 11:39`) has no directly-observed MTN-side receipt
   in the sampled range, but the BK message's `Credited account` field
   is the MTN MoMo phone number itself — the same correlation signal
   (amount + approximate timestamp + the BK message explicitly naming
   "MTN mobile money") that Phase 3 spec's own example describes.
2. **Equity → MTN MoMo (confirmed both sides present):** An Equity `sent`
   message (`MTN Ref. 541077019015`, amount 20000, `17/04/24 19:24:13`)
   and an MTN `received` message (`Financial Transaction Id: 13583914317`,
   amount 20000, `2024-04-17 19:24:16`, `Message from sender: Transfer
   from ... Equity B2C`) are the same real-world transfer, three seconds
   apart, both referencing "Equity"/"MTN" explicitly. **This is the
   strongest real evidence available** — same amount, same day, three
   seconds apart, explicit cross-provider mention on both sides.
