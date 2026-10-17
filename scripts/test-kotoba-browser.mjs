import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = await readFile(new URL('../game/scenes/games/kotoba_touch/browser.js', import.meta.url), 'utf8');
const cat = {pageid: 1215264, ns: 0, title: 'ネコ', pageimage: 'Cat_poster_1.jpg', thumbnail: {source: 'https://thumb.wikimedia.org/cat.jpg'}};
function environment(handler) {
  const requests = [], speech = [], timers = new Map();
  let now = 10000, timerId = 0;
  const context = vm.createContext({URL, URLSearchParams, AbortController, Uint8Array,
    Date: {now: () => now}, btoa,
    setTimeout: fn => {timers.set(++timerId, fn); return timerId;}, clearTimeout: id => timers.delete(id),
    SpeechSynthesisUtterance: function(text) { this.text = text; },
    speechSynthesis: {cancel: () => speech.push('cancel'), getVoices: () => [{lang: 'ja-JP'}], speak: u => speech.push(u)},
    fetch: async (url, init) => {
      const parsed = new URL(url);
      requests.push(parsed);
      return handler(parsed, init);
    },
  });
  vm.runInContext(source, context);
  return {api: context.kotobaTouch, requests, speech, timers, advance: () => now += 2000, context};
}
const response = query => ({ok: true, json: async () => ({query})});
const settle = async env => {
  for (let i = 0; i < 40; i++) {
    await new Promise(resolve => setImmediate(resolve));
    const result = env.api.take();
    if (result) return JSON.parse(result);
  }
  throw new Error('No result');
};
let env = environment(async () => response({pages: [{missing: true}]}));
assert.equal(env.requests.length, 0);
env.api.speak('ネ'); env.api.speak('コ'); env.api.speak('ネコ');
assert.deepEqual(env.speech.filter(x => x !== 'cancel').map(x => [x.text, x.lang, x.rate]), [['ネ','ja-JP',0.85],['コ','ja-JP',0.85],['ネコ','ja-JP',0.85]]);
assert.equal(env.speech.filter(x => x === 'cancel').length, 3);
env.context.speechSynthesis = null;
assert.equal(env.api.speak('ねこ'), false);

// Exact title, kana normalization, missing images, cache and throttling.
env = environment(async url => response({pages: [{...cat, thumbnail: null}]}));
env.api.search('ネコ');
assert.equal((await settle(env)).status, 'no_image');
assert.equal(env.requests.length, 2);
assert.equal(env.requests[0].searchParams.get('origin'), '*');
assert.equal(env.requests[0].searchParams.get('titles'), 'ネコ');
env.api.search('ネコ');
assert.equal((await settle(env)).status, 'no_image');
assert.equal(env.requests.length, 2);
env.api.search('イヌ');
assert.equal((await settle(env)).status, 'wait');

env = environment(async url => response({pages: [url.searchParams.get('titles') === 'ネコ' ? {...cat, thumbnail: null} : {missing: true}]}));
env.api.search('ねコ');
assert.equal((await settle(env)).status, 'no_image');
assert.deepEqual(env.requests.map(u => u.searchParams.get('titles')), ['ねコ', 'ネコ', null]);

env = environment(async url => response(url.searchParams.has('srsearch') ? {search: [{title: 'a'}, {title: 'b'}]} : {pages: [{missing: true}]}));
env.api.search('アアアア');
assert.equal((await settle(env)).status, 'not_found');
assert.equal(env.requests.length, 2);

env = environment(async () => response({pages: [{...cat, pageprops: {disambiguation: ''}}]}));
env.api.search('ネコ');
assert.equal((await settle(env)).status, 'ambiguous');
assert.equal(env.requests.length, 2);

// Wikipedia thumbnails display without fetching or checking rights metadata.
// Missing author/license/source, attribution requirements, and restrictions cannot block them.
for (const title of ['イヌ', 'モモ']) {
  env = environment(async url => {
    if (url.hostname === 'thumb.wikimedia.org') return {
      ok: true, headers: new Headers(), arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer,
    };
    assert.notEqual(url.searchParams.get('prop'), 'imageinfo', 'No metadata gate or extra request');
    assert.equal(url.searchParams.get('pilicense'), 'any', 'Include all Wikipedia page images');
    return response({pages: [{...cat, title}]});
  });
  env.api.search(title);
  const image = await settle(env);
  assert.equal(image.status, 'image');
  assert.equal(image.image, 'AQID');
  assert.equal(image.article_url, 'https://ja.wikipedia.org/wiki/' + encodeURIComponent(title));
  assert.equal(env.requests.length, 2);
}

// Disambiguation: prefer the base term with a matching reading, not a celebrity or station.
const hawk = {...cat, pageid: 76252, title: '鷹', pageprops: {defaultsort: 'たか'}};
const meanings = [hawk, {...hawk, pageid: 2, title: '高駅'}, {...hawk, pageid: 3, title: 'タカ (通貨)'}];
const disambiguation = {...cat, title: 'タカ', pageprops: {disambiguation: ''}};
function hawkResponse(url, candidates) {
  if (url.hostname === 'thumb.wikimedia.org') return {ok: true, headers: new Headers(), arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer};
  return response({pages: url.searchParams.has('generator') ? candidates : [disambiguation]});
}
env = environment(async url => hawkResponse(url, meanings));
env.api.search('タカ');
assert.equal((await settle(env)).status, 'image');
assert.equal(env.requests[1].searchParams.get('generator'), 'links');
// Display available images even when homonyms have the same rank.
env = environment(async url => hawkResponse(url, [hawk, {...hawk, pageid: 999, title: '別', thumbnail: null}]));
env.api.search('タカ');
assert.equal((await settle(env)).images.length, 1);
// A candidate with a different reading is not used.
env = environment(async url => hawkResponse(url, [{...hawk, pageprops: {defaultsort: 'わし'}}]));
env.api.search('タカ');
assert.equal((await settle(env)).status, 'ambiguous');

// Familiar topics outrank names, works, or shorter abstract meanings.
const categories = (...names) => names.map(title => ({title: `Category:${title}`}));
const candidate = (title, reading, file, categoryNames, pageid) => ({...cat, title, pageid, pageimage: file,
  pageprops: {defaultsort: reading}, categories: categories(...categoryNames)});
const fish = candidate('魚類', 'きよるい', 'Fish.jpg', ['魚類'], 10);
const shell = candidate('貝', 'かい', 'Shell.jpg', ['貝類'], 11);
async function checkMeaning(word, pages, expectedFile, paginated = false) {
  env = environment(async url => {
    if (url.hostname === 'thumb.wikimedia.org') return {ok: true, headers: new Headers(), arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer};
    if (url.searchParams.get('generator') === 'links') {
      assert.equal(url.searchParams.get('gpllimit'), '50', 'Keep batches within pageimages limit');
      assert.equal(url.searchParams.get('pilimit'), 'max');
      if (paginated && !url.searchParams.has('gplcontinue')) return {ok: true, json: async () => ({
        query: {pages: [candidate('Χ', 'かい', 'Letter.jpg', ['ギリシア文字'], 1)]},
        continue: {gplcontinue: 'next-page', continue: 'gplcontinue||'},
      })};
      if (paginated) assert.equal(url.searchParams.get('gplcontinue'), 'next-page');
      return response({pages});
    }
    return response({pages: [{...disambiguation, title: word}]});
  });
  env.api.search(word);
  const result = await settle(env);
  assert.equal(result.status, 'image');
  assert.equal(result.images[0].article_url, 'https://ja.wikipedia.org/wiki/' + encodeURIComponent(pages.find(page => page.pageimage === expectedFile).title));
  assert.ok(result.images.length >= 2);
  assert.notEqual(result.images[0].article_url, result.images[1].article_url);
}
await checkMeaning('サカナ', [fish,
  candidate('動物', 'どうぶつ', 'Animal.jpg', ['動物'], 12),
  candidate('肴', 'さかな', 'Food.jpg', ['食品', '飲酒文化'], 13),
  candidate('さかなクン', 'さかなくん', 'Person.jpg', ['存命人物', '魚類'], 14)], 'Fish.jpg');
await checkMeaning('カイ', [shell, candidate('Χ', 'かい', 'Letter.jpg', ['ギリシア文字'], 1)], 'Shell.jpg', true);
await checkMeaning('モモ', [candidate('桃', 'もも', 'Peach.jpg', ['果物'], 21),
  candidate('モモ', 'もも', 'Novel.jpg', ['小説'], 22)], 'Peach.jpg');
await checkMeaning('パン', [candidate('パン (食品)', 'ぱん', 'Bread.jpg', ['食品'], 31),
  candidate('潘', 'ぱん', 'Name.jpg', ['姓'], 32)], 'Bread.jpg');
await checkMeaning('イス', [candidate('椅子', 'いす', 'Chair.jpg', ['家具'], 41),
  candidate('イス', 'いす', 'Character.jpg', ['架空のキャラクター'], 42)], 'Chair.jpg');
// Kana search finds 肉 as a disambiguation page; follow it to 食肉.
for (const word of ['にく', 'ニク']) {
  env = environment(async url => {
    if (url.hostname === 'thumb.wikimedia.org') return {ok: true, headers: new Headers(),
      arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer};
    if (url.searchParams.get('generator') === 'search') return response({pages: [
      {ns: 0, title: '肉', pageprops: {defaultsort: 'にく', disambiguation: ''}},
    ]});
    if (url.searchParams.get('generator') === 'links') {
      assert.equal(url.searchParams.get('titles'), '肉');
      return response({pages: [candidate('食肉', 'しよくにく', 'Meat.jpg', ['肉料理'], 301)]});
    }
    return response({pages: [{missing: true}]});
  });
  env.api.search(word);
  const result = await settle(env);
  assert.equal(result.status, 'image');
  assert.equal(decodeURIComponent(result.article_url), 'https://ja.wikipedia.org/wiki/食肉');
}

// A linked full name can expand the entered nickname without a word dictionary.
for (const word of ['ミッキー', 'みっきー']) {
  env = environment(async url => {
    if (url.hostname === 'thumb.wikimedia.org') return {ok: true, headers: new Headers(),
      arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer};
    if (url.searchParams.get('generator') === 'links') return response({pages: [
      candidate('ミッキーマウス', 'みつきい まうす', 'Mouse.png', ['架空のキャラクター'], 401),
      candidate('ピアノ奏者', 'ひあのそうしや', 'Unrelated.jpg', ['人物'], 402),
    ]});
    if (url.searchParams.get('generator') === 'search') return response({pages: []});
    return response({pages: [{...disambiguation, title: 'ミッキー'}]});
  });
  env.api.search(word);
  const result = await settle(env);
  assert.equal(result.status, 'image');
  assert.equal(result.images.length, 1);
  assert.equal(decodeURIComponent(result.article_url), 'https://ja.wikipedia.org/wiki/ミッキーマウス');
}

// The alias relaxation is only for links on the disambiguation page, not arbitrary search hits.
env = environment(async url => response({pages: url.searchParams.has('generator') ? [fish] : [{missing: true}]}));
env.api.search('ナイコトバ');
assert.equal((await settle(env)).status, 'not_found');
// Stop after three batches instead of choosing from an incomplete list or looping forever.
env = environment(async url => url.searchParams.get('generator') === 'links'
  ? {ok: true, json: async () => ({query: {pages: [shell]}, continue: {gplcontinue: 'more'}})}
  : response({pages: [disambiguation]}));
env.api.search('カイ');
assert.equal((await settle(env)).status, 'ambiguous');
assert.equal(env.requests.length, 4);

// Hiragana may resolve to an unrelated katakana article without a picture (ほん -> ホン).
for (const word of ['ほん', 'ホン']) {
  env = environment(async url => {
    if (url.hostname === 'thumb.wikimedia.org') return {ok: true, headers: new Headers(), arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer};
      if (url.searchParams.get('generator') === 'search') {
      assert.equal(url.searchParams.get('gsrsearch'), '"ほん"');
      return response({pages: [{...cat, title: '本', pageprops: {defaultsort: 'ほん'}}, {...cat, title: '絵本', pageprops: {defaultsort: 'えほん'}}]});
    }
    return response({pages: [url.searchParams.get('titles') === 'ほん' ? {missing: true} : {...cat, title: 'ホン', thumbnail: null}]});
  });
  env.api.search(word);
  assert.equal((await settle(env)).status, 'image');
}
// DEFAULTSORT strips voicing and may expand small kana; input/speech stay intact.
for (const [word, sortKey, title] of [['はなび', 'はなひ', '花火'], ['ハナビ', 'はなひ', '花火'],
    ['ぱんだ', 'はんた', 'パンダ'], ['ジュース', 'しゆーす', '飲料']]) {
  env = environment(async url => {
    if (url.hostname === 'thumb.wikimedia.org') return {ok: true, headers: new Headers(), arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer};
      return response({pages: url.searchParams.get('generator') === 'search'
      ? [{...cat, title, pageprops: {defaultsort: sortKey}}] : [{missing: true}]});
  });
  env.api.speak(word);
  env.api.search(word);
  const result = await settle(env);
  assert.equal(result.status, 'image');
  assert.equal(result.word, word);
  assert.equal(env.speech.at(-1).text, word);
}

// Search may return only songs: derive the base article rather than registering 花火 locally.
env = environment(async url => {
  if (url.hostname === 'thumb.wikimedia.org') return {ok: true, headers: new Headers(), arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer};
  if (url.searchParams.get('generator') === 'search') return response({pages: [
    candidate('花火 (歌手の曲)', 'はなひ', 'Song.jpg', ['楽曲'], 201),
    candidate('花火 (別の曲)', 'はなひ', 'Song2.jpg', ['楽曲'], 202),
    candidate('線香花火 (曲)', 'せんこうはなひ', 'Other.jpg', ['楽曲'], 203),
  ]});
  if (url.searchParams.get('titles') === '花火') return response({pages: [candidate('花火', 'はなひ', 'Fireworks.jpg', ['玩具'], 204)]});
  return response({pages: [{missing: true}]});
});
env.api.search('はなび');
assert.equal((await settle(env)).status, 'image');
assert.equal(env.requests.filter(url => url.searchParams.get('titles') === '花火').length, 1);
assert.ok(env.requests.some(url => url.hostname === 'thumb.wikimedia.org'));

// An empty MediaWiki generator response is a missing word, not a network error.
env = environment(async url => url.searchParams.has('generator')
  ? {ok: true, json: async () => ({batchcomplete: true})} : response({pages: [{missing: true}]}));
env.api.search('ナイコトバ');
assert.equal((await settle(env)).status, 'not_found');

// Deliberately ignore AbortSignal in the mock to force out-of-order completion.
let finishOld;
env = environment(async url => {
  if (url.searchParams.get('titles') === 'フルイ') return new Promise(resolve => {finishOld = resolve;});
  return response({pages: [{...cat, thumbnail: null}]});
});
env.api.search('フルイ'); env.advance(); env.api.search('アタラシイ');
assert.equal((await settle(env)).word, 'アタラシイ');
finishOld(response({pages: [cat]}));
await new Promise(resolve => setTimeout(resolve, 10));
assert.equal(env.api.take(), '');
env.advance(); env.api.search('フルイ'); env.api.cancel();
finishOld(response({pages: [{...cat, thumbnail: null}]}));
await new Promise(resolve => setImmediate(resolve));
assert.equal(env.api.take(), '');

env = environment(async () => {throw new Error('offline');});
env.api.search('ネコ');
assert.equal((await settle(env)).status, 'network');
env.api.speak('コ');
assert.equal(env.speech.at(-1).text, 'コ');
env.advance(); env.api.search('ネコ');
assert.equal((await settle(env)).status, 'network');
assert.equal(env.requests.length, 2, 'Network errors are retryable, not cached');

env = environment((_url, {signal}) => new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(new Error('timeout')))));
env.api.search('ネコ');
for (const timer of env.timers.values()) timer();
assert.equal((await settle(env)).status, 'network');
console.log('Kotoba browser checks passed');
