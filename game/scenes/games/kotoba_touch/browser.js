// Keep Godot input processing inside the browser gesture for TTS.
(() => {
  if (globalThis.kotobaTouch) return;
  let flushInput = null;
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
  };
})();
