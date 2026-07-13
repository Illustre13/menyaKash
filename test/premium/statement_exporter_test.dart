import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/premium/statement_exporter.dart';

/// This is prep-only architecture (spec Phase 11) — there's no real
/// export logic to test. This just documents the intended placeholder
/// behavior: the type exists and compiles, but calling it is a clear
/// "not built yet" signal, not a silent no-op.
void main() {
  test('UnimplementedStatementExporter.export always throws UnimplementedError', () {
    const exporter = UnimplementedStatementExporter(StatementFormat.pdf);
    expect(
      () => exporter.export(transactions: const [], destinationPath: '/tmp/out.pdf'),
      throwsA(isA<UnimplementedError>()),
    );
  });
}
