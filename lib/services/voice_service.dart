import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for voice reminders. Silent and safe to call when the
/// platform has no TTS engine (e.g. during tests).
class VoiceService {
  FlutterTts? _tts;
  bool _ready = false;

  /// Initializes the engine. Safe to call in any environment; failures are
  /// swallowed and speech is simply unavailable.
  Future<void> init() async {
    try {
      final tts = FlutterTts();
      await tts.awaitSpeakCompletion(true);
      await tts.setSpeechRate(0.45); // slow and clear for elderly users
      _tts = tts;
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> speak(String text, String localeCode) async {
    if (!_ready || text.trim().isEmpty) return;
    try {
      final tts = _tts!;
      await tts.setLanguage(localeCode == 'hi' ? 'hi-IN' : 'en-IN');
      await tts.speak(text);
    } catch (_) {
      // TTS unavailable: ignore, the notification is the reminder.
    }
  }

  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts!.stop();
    } catch (_) {}
  }
}
