import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Can the phone take dictation? [hazir]; [izinYok] the microphone (or speech) permission was refused; [turkceYok] the
/// phone's recognizer has no Turkish; [kullanilamaz] there is no recognizer at all.
enum DikteHazirlik { hazir, izinYok, turkceYok, kullanilamaz }

/// Speech to text on the phone (K2.4 karar 8: the audio never leaves it, no file is kept). Behind an interface so the view
/// model and the screen are tested without a microphone; the real one is [SpeechDikteServisi].
abstract class DikteServisi {
  /// Asks for the permission the first time and checks the recognizer.
  Future<DikteHazirlik> hazirla();

  /// Starts listening. [onSonuc] gets the words so far (the whole sentence, not a piece); [son] is true once that
  /// sentence is settled. [onDurdu] is called when listening ended (a pause, [durdur], or an error) and [onHata] with the
  /// platform's error code when one came.
  Future<void> dinle({
    required void Function(String metin, bool son) onSonuc,
    required void Function() onDurdu,
    required void Function(String kod) onHata,
  });

  Future<void> durdur();
}

/// [DikteServisi] over the `speech_to_text` package, in Turkish.
class SpeechDikteServisi implements DikteServisi {
  SpeechDikteServisi({SpeechToText? motor}) : _motor = motor ?? SpeechToText();

  static const _dil = 'tr_TR';

  /// Android: the recognizer stops this long after the last word.
  static const _duraklama = Duration(seconds: 3);
  static const _enUzun = Duration(minutes: 2);

  final SpeechToText _motor;
  String? _dilKimligi;
  void Function()? _durdu;
  void Function(String kod)? _hata;

  @override
  Future<DikteHazirlik> hazirla() async {
    final tamam = await _motor.initialize(
      onError: (SpeechRecognitionError e) => _hata?.call(e.errorMsg),
      onStatus: (durum) {
        if (durum == SpeechToText.doneStatus || durum == SpeechToText.notListeningStatus) _durdu?.call();
      },
    );
    if (!tamam) return await _motor.hasPermission ? DikteHazirlik.kullanilamaz : DikteHazirlik.izinYok;
    // The locale id is "tr_TR" on Android and "tr-TR" on some phones: match on the language and country.
    final diller = await _motor.locales();
    _dilKimligi = diller.map((d) => d.localeId).where((k) => k.replaceAll('-', '_') == _dil).firstOrNull;
    return _dilKimligi == null ? DikteHazirlik.turkceYok : DikteHazirlik.hazir;
  }

  @override
  Future<void> dinle({
    required void Function(String metin, bool son) onSonuc,
    required void Function() onDurdu,
    required void Function(String kod) onHata,
  }) async {
    _durdu = onDurdu;
    _hata = onHata;
    await _motor.listen(
      onResult: (SpeechRecognitionResult r) => onSonuc(r.recognizedWords, r.finalResult),
      // On the phone when it can; Android only prefers it, so with no offline model the system's own recognizer answers.
      listenOptions: SpeechListenOptions(
        partialResults: true,
        onDevice: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        listenFor: _enUzun,
        pauseFor: _duraklama,
        localeId: _dilKimligi,
      ),
    );
  }

  @override
  Future<void> durdur() => _motor.stop();
}
