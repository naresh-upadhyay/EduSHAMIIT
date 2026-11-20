// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void playAudioTestChime() {
  try {
    final ctx = js.context.hasProperty('AudioContext')
        ? js.JsObject(js.context['AudioContext'] as js.JsFunction, [])
        : (js.context.hasProperty('webkitAudioContext')
            ? js.JsObject(js.context['webkitAudioContext'] as js.JsFunction, [])
            : null);
    if (ctx == null) return;

    try {
      if (ctx['state'] == 'suspended') {
        ctx.callMethod('resume');
      }
    } catch (_) {}

    final now = (ctx['currentTime'] as num?)?.toDouble() ?? 0.0;
    // Harmonic musical chord chime: C5 (523.25 Hz), E5 (659.25 Hz), G5 (783.99 Hz), C6 (1046.50 Hz)
    final notes = [523.25, 659.25, 783.99, 1046.50];

    for (int i = 0; i < notes.length; i++) {
      final osc = ctx.callMethod('createOscillator');
      final gain = ctx.callMethod('createGain');

      osc.callMethod('connect', [gain]);
      gain.callMethod('connect', [ctx['destination']]);

      osc['type'] = 'sine';
      osc['frequency']['value'] = notes[i];

      final startTime = now + (i * 0.12);
      final stopTime = startTime + 0.45;

      gain['gain'].callMethod('setValueAtTime', [0.0, startTime]);
      gain['gain'].callMethod('linearRampToValueAtTime', [0.22, startTime + 0.03]);
      gain['gain'].callMethod('exponentialRampToValueAtTime', [0.001, stopTime]);

      osc.callMethod('start', [startTime]);
      osc.callMethod('stop', [stopTime]);
    }
  } catch (_) {}
}
