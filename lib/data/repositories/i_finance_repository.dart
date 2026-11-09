import '../models/finance_snapshot.dart';

/// Aggregate read contract used by the presentation layer.
///
/// A SQLite/Isar/Supabase implementation only has to provide a snapshot stream
/// and the same mutation methods as the mock — no UI changes required.
abstract interface class IFinanceRepository {
  FinanceSnapshot get current;

  Stream<FinanceSnapshot> watch();

  Future<void> resetDemo();

  Future<void> startFresh();
}
