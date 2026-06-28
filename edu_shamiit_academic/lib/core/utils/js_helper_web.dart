// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

bool hasMediaDevices() {
  try {
    final result = js.context.callMethod(
        'eval', ["typeof navigator.mediaDevices !== 'undefined'"]);
    return result == true;
  } catch (e) {
    debugPrint('[JSHelper] Error checking media devices: $e');
    return false;
  }
}

void jsAlert(String message) {
  try {
    js.context.callMethod('alert', [message]);
  } catch (e) {
    debugPrint('[JSHelper] Error showing alert: $e');
  }
}

void startWebRingtone() {
  try {
    js.context.callMethod('eval', [
      '''
      if (!window.ringingSynth) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) {
          const ctx = new AudioContext();
          let isPlaying = false;
          let timer = null;
          
          window.ringingSynth = {
            start: function() {
              if (isPlaying) return;
              isPlaying = true;
              if (ctx.state === 'suspended') {
                ctx.resume();
              }
              
              function playRing() {
                if (!isPlaying) return;
                
                const osc1 = ctx.createOscillator();
                const osc2 = ctx.createOscillator();
                const gain = ctx.createGain();
                
                osc1.type = 'sine';
                osc1.frequency.value = 400;
                
                osc2.type = 'sine';
                osc2.frequency.value = 450;
                
                gain.gain.setValueAtTime(0, ctx.currentTime);
                gain.gain.linearRampToValueAtTime(0.15, ctx.currentTime + 0.1);
                gain.gain.setValueAtTime(0.15, ctx.currentTime + 1.8);
                gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 2.0);
                
                osc1.connect(gain);
                osc2.connect(gain);
                gain.connect(ctx.destination);
                
                osc1.start();
                osc2.start();
                
                osc1.stop(ctx.currentTime + 2.0);
                osc2.stop(ctx.currentTime + 2.0);
                
                timer = setTimeout(() => {
                  if (isPlaying) playRing();
                }, 3000);
              }
              
              playRing();
            },
            stop: function() {
              isPlaying = false;
              if (timer) {
                clearTimeout(timer);
                timer = null;
              }
            }
          };
        }
      }
      if (window.ringingSynth) {
        window.ringingSynth.start();
      }
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error starting web ringtone: $e');
  }
}

void stopWebRingtone() {
  try {
    js.context.callMethod('eval', [
      '''
      if (window.ringingSynth) {
        window.ringingSynth.stop();
      }
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error stopping web ringtone: $e');
  }
}
