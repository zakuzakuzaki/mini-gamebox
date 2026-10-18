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

// Voice enumeration must not prevent a Japanese utterance from being submitted.
let voices = [], utterances = [], errors = [];
context.SpeechSynthesisUtterance = class {
  constructor(text) { this.text = text; this.voice = null; }
};
context.speechSynthesis = {
  getVoices: () => voices,
  speak: utterance => utterances.push(utterance),
  cancel: () => utterances.at(-1)?.onerror({error: 'interrupted'}),
};
env.api.setSpeechErrorCallback((code, text) => errors.push({code, text}));
env.api.speak('カ');
assert.equal(utterances.length, 1);
assert.equal(utterances[0].lang, 'ja-JP');
assert.equal(utterances[0].voice, null);
assert.equal(utterances[0].rate, 0.85);
voices = [{lang: 'en-US'}, {lang: 'ja_JP'}];
env.api.speak('ネコ');
assert.equal(utterances[1].voice, voices[1], 'Re-query voices after delayed loading');
assert.deepEqual(errors, [], 'Replacing speech ignores cancellation');
utterances[0].onerror({error: 'synthesis-failed'});
assert.deepEqual(errors, [], 'Stale errors cannot affect a newer utterance');
utterances[1].onerror({error: 'language-unavailable'});
assert.deepEqual(errors.pop(), {code: 'language-unavailable', text: 'ネコ'});
voices = [{lang: 'en-US'}];
env.api.speak('イヌ');
assert.equal(utterances[2].voice, null, 'Do not force an unrelated language');
env.api.stopSpeech();
utterances[2].onerror({error: 'synthesis-failed'});
assert.deepEqual(errors, []);
context.speechSynthesis.speak = () => { throw new Error('failed'); };
env.api.speak('ウシ');
assert.equal(errors.pop().code, 'Error');
delete context.speechSynthesis;
env.api.speak('トリ');
assert.equal(errors.pop().code, 'unsupported');
env.api.setSpeechErrorCallback(null);
env.api.speak('トリ');
assert.deepEqual(errors, [], 'Leaving the scene releases the error callback');
console.log('Kotoba browser speech checks passed');
