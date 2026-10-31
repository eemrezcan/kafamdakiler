import '../data/models/enums.dart';

/// Value of a day in [0, 1], same rule as the server (plan: "Hedef"):
/// - EnAz: `min(1, miktar / hedef)`
/// - EnCok: 1 while `miktar <= hedef`, else 0
/// - EvetHayir: 1 once ticked
///
/// Used for the optimistic screen update while a write is still queued.
double gunDegeri({
  required Olcu olcu,
  required HedefYonu hedefYonu,
  required double? hedef,
  required double miktar,
}) {
  if (olcu == Olcu.evetHayir) return miktar >= 1 ? 1 : 0;
  final h = hedef ?? 0;
  if (hedefYonu == HedefYonu.enCok) return miktar <= h ? 1 : 0;
  if (h <= 0) return 0;
  final oran = miktar / h;
  return oran > 1 ? 1 : oran;
}
