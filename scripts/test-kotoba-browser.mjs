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
assert.deepEqual(errors, [], 'A failed listed voice falls back to browser selection');
assert.equal(utterances[2].voice, null);
utterances[2].onerror({error: 'language-unavailable'});
assert.deepEqual(errors.pop(), {code: 'language-unavailable', text: 'ネコ'});
voices = [{lang: 'en-US'}];
env.api.speak('イヌ');
assert.equal(utterances[3].voice, null, 'Do not force an unrelated language');
env.api.stopSpeech();
utterances[3].onerror({error: 'synthesis-failed'});
assert.deepEqual(errors, []);
// Reproduce a tablet engine failure and verify bounded recovery.
const remote = {lang: 'ja-JP', localService: false};
const local = {lang: 'ja-JP', localService: true};
voices = [remote, local];
env.api.speak('イ');
assert.equal(utterances.at(-1).voice, local, 'Prefer an on-device voice');
const failed = utterances.at(-1);
failed.onerror({error: 'synthesis-failed'});
assert.equal(utterances.at(-1).voice, remote);
failed.onerror({error: 'synthesis-failed'});
assert.equal(utterances.at(-1).voice, remote, 'Ignore duplicate errors from prior attempts');
utterances.at(-1).onerror({error: 'network'});
assert.equal(utterances.at(-1).voice, null);
assert.deepEqual(errors, []);
utterances.at(-1).onerror({error: 'synthesis-failed'});
assert.deepEqual(errors.pop(), {code: 'synthesis-failed', text: 'イ'});
env.api.speak('イ');
utterances.at(-1).onerror({error: 'synthesis-failed'});
utterances.at(-1).onend();
assert.deepEqual(errors, [], 'Successful fallback does not report the first failure');
env.api.speak('ア');
utterances.at(-1).onerror({error: 'not-allowed'});
assert.deepEqual(errors.pop(), {code: 'not-allowed', text: 'ア'});
env.api.speak('ウ');
utterances.at(-1).onerror({error: 'synthesis-failed'});
const retry = utterances.at(-1);
env.api.stopSpeech();
const stoppedCount = utterances.length;
retry.onerror({error: 'synthesis-failed'});
assert.equal(utterances.length, stoppedCount, 'Stopping also stops fallback attempts');
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
