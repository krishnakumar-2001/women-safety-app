import 'package:speech_to_text/speech_to_text.dart';

class VoiceTriggerService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isManualActive = false;
  final Function onTriggered;

  VoiceTriggerService({required this.onTriggered});

  Future<void> startListening() async {
    _isManualActive = true;
    _isListening = true;
    _initAndListen();
  }

  Future<void> _initAndListen() async {
    if (!_isManualActive) return;

    bool available = await _speech.initialize(
      onStatus: (status) {
        print('STT Status: $status');
        // If it stops but we still want it active, restart
        if (status == 'done' || status == 'notListening') {
          if (_isManualActive) {
            _initAndListen();
          }
        }
      },
      onError: (errorNotification) {
        print('STT Error: $errorNotification');
        // Restart on error as well to ensure persistence
        if (_isManualActive) {
          Future.delayed(const Duration(seconds: 1), () => _initAndListen());
        }
      },
    );

    if (available && _isManualActive) {
      _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase();
          print('Recognized: $words');
          if (words.contains('help me') || words.contains('emergency') || words.contains('save me')) {
            onTriggered();
            // We keep listening even after trigger in case of another emergency
          }
        },
        listenFor: const Duration(minutes: 5), // Max session length
        pauseFor: const Duration(seconds: 10), // Wait before timeout
        cancelOnError: false,
        partialResults: true,
        listenMode: ListenMode.confirmation, // Better accuracy
      );
    }
  }

  void stopListening() {
    _isManualActive = false;
    _isListening = false;
    _speech.stop();
  }

  void toggleListening() {
    if (_isManualActive) {
      stopListening();
    } else {
      startListening();
    }
  }

  bool get isListening => _isManualActive;
}
