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
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.lang = 'ja-JP';
        utterance.volume = 1;
        utterance.pitch = 1;
        utterance.rate = 0.85;
        const voice = synth.getVoices().find(voice => /^ja(?:[-_]|$)/i.test(voice.lang));
        // Empty lists can occur before voices load. Let the browser resolve a
        // Japanese voice using lang, without leaving the trusted input event.
        if (voice) utterance.voice = voice;
        currentSpeech = utterance;
        utterance.onend = () => {
          if (currentSpeech === utterance) currentSpeech = null;
        };
        utterance.onerror = event => {
          if (currentSpeech !== utterance) return;
          currentSpeech = null;
          if (!['canceled', 'interrupted'].includes(event.error)) {
            speechError?.(event.error || 'synthesis-failed', text);
          }
        };
        synth.speak(utterance);
      } catch (error) {
        currentSpeech = null;
        speechError?.(error.name || 'synthesis-failed', text);
      }
    },
  };
})();
