import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/utils/aliskanlik_gunu.dart';

void main() {
  // Istanbul is a fixed UTC+3, so "04:59 Istanbul" is 01:59 UTC.
  DateTime istanbul(int y, int ay, int g, int sa, int dk) =>
      DateTime.utc(y, ay, g, sa, dk).subtract(const Duration(hours: 3));

  test('04:59 belongs to the previous day', () {
    expect(aliskanlikGunu(istanbul(2026, 10, 31, 4, 59)), DateTime.utc(2026, 10, 30));
  });

  test('05:00 belongs to the same day', () {
    expect(aliskanlikGunu(istanbul(2026, 10, 31, 5, 0)), DateTime.utc(2026, 10, 31));
  });

  test('23:59 and 00:00 stay on the same habit day', () {
    expect(aliskanlikGunu(istanbul(2026, 10, 31, 23, 59)), DateTime.utc(2026, 10, 31));
    expect(aliskanlikGunu(istanbul(2026, 11, 1, 0, 0)), DateTime.utc(2026, 10, 31));
  });

  test('works across month and year boundaries', () {
    expect(aliskanlikGunu(istanbul(2027, 1, 1, 3, 30)), DateTime.utc(2026, 12, 31));
  });

  test('local DateTime input is converted by instant, not by wall clock', () {
    final yerel = istanbul(2026, 10, 31, 4, 59).toLocal();
    expect(aliskanlikGunu(yerel), DateTime.utc(2026, 10, 30));
  });

  test('tarihMetni and tarihCoz round trip', () {
    expect(tarihMetni(DateTime.utc(2026, 3, 5)), '2026-03-05');
    expect(tarihCoz('2026-03-05'), DateTime.utc(2026, 3, 5));
  });
}
