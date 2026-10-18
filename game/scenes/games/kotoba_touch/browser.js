// Keep Godot input processing inside the browser gesture for TTS.
(() => {
  if (globalThis.kotobaTouch) return;
  let flushInput = null;
  let speechError = null;
  let currentSpeech = null;
  const stopSpeech = () => {
    // Invalidate before cancel(), which may synchronously emit an error.
    currentSpeech = null;
    globalThis.speechSynthesis?.cancel();
  };
  // Run after Godot's canvas listeners have queued the event, but before the
  // browser leaves the trusted gesture. A later animation frame loses this
  // context on Safari, so speech from a Godot button can otherwise be blocked.
  for (const type of ['mousedown', 'mouseup', 'touchstart', 'touchend', 'keydown', 'keyup']) {
    globalThis.addEventListener?.(type, event => {
      if (event.isTrusted) flushInput?.();
    });
  }
  globalThis.kotobaTouch = {
    setInputCallback(callback) { flushInput = callback; },
    setSpeechErrorCallback(callback) { speechError = callback; },
    stopSpeech,
    speak(text) {
      stopSpeech();
      const synth = globalThis.speechSynthesis;
      if (!synth || !globalThis.SpeechSynthesisUtterance) {
        speechError?.('unsupported', text);
        return;
      }
      try {
        const voices = synth.getVoices()
          .filter(voice => /^ja(?:[-_]|$)/i.test(voice.lang))
          .sort((a, b) => Number(b.localService === true) - Number(a.localService === true));
        // A listed voice can still be unavailable on a tablet. Try each Japanese
        // voice once, then let the browser select its own voice for ja-JP.
        const candidates = [...voices, null];
        let next = 0;
        const attempt = () => {
          const utterance = new SpeechSynthesisUtterance(text);
          utterance.lang = 'ja-JP';
          utterance.volume = 1;
          utterance.pitch = 1;
          utterance.rate = 0.85;
          const voice = candidates[next++];
          if (voice) utterance.voice = voice;
          currentSpeech = utterance;
          utterance.onend = () => {
            if (currentSpeech === utterance) currentSpeech = null;
          };
          utterance.onerror = event => {
            if (currentSpeech !== utterance) return;
            currentSpeech = null;
            if (['synthesis-failed', 'synthesis-unavailable', 'voice-unavailable',
              'language-unavailable', 'network'].includes(event.error) && next < candidates.length) {
              attempt();
              return;
            }
            if (!['canceled', 'interrupted'].includes(event.error)) {
              speechError?.(event.error || 'synthesis-failed', text);
            }
          };
          try {
            synth.speak(utterance);
          } catch (error) {
            utterance.onerror({error: error.name || 'synthesis-failed'});
          }
        };
        attempt();
      } catch (error) {
        currentSpeech = null;
        speechError?.(error.name || 'synthesis-failed', text);
      }
    },
  };
})();
