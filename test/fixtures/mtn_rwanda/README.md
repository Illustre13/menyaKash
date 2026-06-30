# MTN MoMo Rwanda fixtures — real data (redacted)

Every `.txt` file here is **real MTN Rwanda MoMo SMS text**, sourced from a
genuine 8,364-message device export analyzed in `docs/AUDIT_PHASE_0.md`
(§3.1). Names, phone numbers, account numbers, and transaction IDs have
been redacted/replaced with placeholders — the wording, punctuation, and
field order are exactly as received.

Real MTN Rwanda MoMo traffic uses **at least six distinct message shapes**
(see `docs/AUDIT_PHASE_0.md` §3.1 and `docs/SMS_PATTERN_LIBRARY.md` for the
full catalog):

| File | Real shape |
|---|---|
| `received.txt` | P2P transfer in: `*165*S*AMOUNT RWF transferred to NAME (PHONE) from ACCOUNT at TIMESTAMP...` |
| `sent.txt` | Same `*165*S*` shape, sender's own transfer out |
| `payment.txt` | `TxId: N. Your payment of AMOUNT RWF to MERCHANT CODE has been completed at TIMESTAMP...` |
| `payment_alt.txt` | `*162*TxId:N*S*Your payment of AMOUNT RWF to eKash with token...` — note: this is actually the **eKash** provider on the same `M-Money` shortcode, kept here only as a disambiguation-boundary fixture (see `ProviderDetector`) |
| `withdrawal.txt` | `You NAME (masked) have via agent: AGENT (PHONE), withdrawn AMOUNT RWF from your mobile money account...` |
| `deposit.txt` | `*113*R*A bank deposit of AMOUNT RWF has been added to your mobile money account at TIMESTAMP...` |
| `bundle_purchase.txt` | `*164*S*Y'ello,A transaction of AMOUNT RWF by Data Bundle MTN on your MOMO account was successfully completed...` |
| `failed.txt` | `*143*R*Y'ello, the transaction with amount AMOUNT RWF for MERCHANT with message: ... failed at TIMESTAMP...` |
| `airtime.txt` | `*162*TxId:N*S*Your payment of AMOUNT RWF to Airtime with token...` |

If a new real message shape shows up that doesn't match any of these,
add it as a new fixture here and extend `MtnRwandaParser` rather than
guessing — the whole point of this fixture set existing is that nothing
in `MtnRwandaParser` is speculative anymore.
