import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source = await readFile(new URL('../game/scenes/games/kotoba_touch/browser.js', import.meta.url), 'utf8');
const listeners = new Map();
const context = vm.createContext({addEventListener: (type, callback) => listeners.set(type, callback)});
vm.runInContext(source, context);
const env = {api: context.kotobaTouch, listeners, context};
// Buffered Godot input must produce speech inside the browser gesture, not
// on the next animation frame. Cover touch, mouse, keyboard and scene cleanup.
let inGesture = false, count = 0;
env.api.setInputCallback(() => {
  assert.ok(inGesture, 'Godot input must flush inside the trusted event');
  count++;
});
for (const type of ['mousedown', 'mouseup', 'touchstart', 'touchend', 'keydown', 'keyup']) {
  env.listeners.get(type)({isTrusted: false});
  inGesture = true;
  env.listeners.get(type)({isTrusted: true});
  inGesture = false;
}
assert.equal(count, 6);
env.api.setInputCallback(null);
env.listeners.get('touchend')({isTrusted: true});
assert.equal(count, 6, 'Leaving the scene releases the Godot callback');
vm.runInContext(source, env.context);
assert.equal(env.listeners.size, 6, 'Reopening the game does not duplicate listeners');

console.log('Kotoba browser input checks passed');
