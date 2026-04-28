# MTN Rwanda fixtures — REPLACE WITH REAL DATA

The `.txt` files in this folder are **placeholders**, written to match the
general MTN MoMo SMS shape (amount, counterparty, TxId, running balance)
seen in comparable providers. They are NOT verified against real MTN
Rwanda wording — public research could not source verbatim message text.

Before trusting `MtnRwandaParser` on a real device:

1. Open the Messages app on a phone with real MTN MoMo history.
2. Copy the exact text of one message per transaction type (redact
   phone numbers/amounts if sharing outside your own device).
3. Overwrite the matching `.txt` file here with the real text.
4. Run `flutter test test/parsers/mtn_rwanda_parser_test.dart` and fix
   the regexes in `lib/parsers/mtn_rwanda_parser.dart` until it's green.
5. Also confirm the real sender ID/short code and update
   `MtnRwandaParser.knownSenders`.

Each file's content is a single raw SMS body, exactly as received.
