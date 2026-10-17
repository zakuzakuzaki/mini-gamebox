// Shared by JavaScriptBridge and the Node contract tests. No network on installation.
(() => {
  if (globalThis.kotobaTouch) return;
  const API = 'https://ja.wikipedia.org/w/api.php';
  const PAGE_PROPERTIES = {prop: 'pageimages|pageprops|categories', cllimit: 'max', clshow: '!hidden',
    piprop: 'name|thumbnail', pilicense: 'any', pilimit: 'max', pithumbsize: '400'};
  const cache = new Map();
  let serial = 0, controller, result = null, lastStart = -Infinity;
  const normalize = text => text.replace(/[ぁ-ゖ]/g, c => String.fromCharCode(c.charCodeAt(0) + 96));
  // Japanese DEFAULTSORT commonly removes voicing and expands small kana.
  // Use this only for sort-key matching; never alter the displayed/spoken word.
  const sortReading = text => normalize(text).normalize('NFD').replace(/[\u3099\u309a]/g, '')
    .replace(/[ァィゥェォッャュョヮヵヶ]/g, c => 'アイウエオツヤユヨワカケ'['ァィゥェォッャュョヮヵヶ'.indexOf(c)]);
  const missing = status => ({status});
  async function query(params, signal) {
    const url = new URL(API);
    url.search = new URLSearchParams({action: 'query', format: 'json', formatversion: '2', origin: '*', maxlag: '5', ...params});
    const response = await fetch(url, {signal, credentials: 'omit', referrerPolicy: 'no-referrer'});
    if (!response.ok) throw new Error('http');
    const data = await response.json();
    if (data.error || (!data.query && !Object.hasOwn(data, 'batchcomplete'))) throw new Error('api');
    return {...data.query, nextLinks: data.continue?.gplcontinue || ''};
  }
  async function article(title, signal) {
    const data = await query({titles: title, redirects: '1', ...PAGE_PROPERTIES}, signal);
    const pages = data.pages;
    if (!Array.isArray(pages) || pages.length !== 1) return null;
    return pages[0];
  }
  function familiarity(page) {
    const categories = (page.categories || []).map(c => c.title.replace(/^Category:/, ''));
    // Topic ranking, not a content-safety classifier. A person/brand named after an
    // animal must not inherit priority just because another category mentions animals.
    if (categories.some(c => /人物|歌手|俳優|芸人|音楽グループ|バンド|映画|漫画|小説|楽曲|企業|ブランド|架空|キャラクター/.test(c))) return -1;
    if (categories.some(c => /(?:動物|哺乳類|鳥類|魚類|貝類|昆虫|爬虫類|両生類|軟体動物|甲殻類|植物|樹木|花卉|果物|野菜|イヌ科|ネコ科|ウサギ科|ウマ科|ウシ科|タカ科)$/.test(c))) return 3;
    if (categories.some(c => /(?:食品|食材|料理|菓子|パン|飲料|果実|食用魚|水産物)$/.test(c)) &&
        !categories.some(c => /酒|飲酒/.test(c))) return 2;
    if (categories.some(c => /(?:日用品|生活用品|文房具|玩具|遊具|家具|食器|調理器具|衣類|衣服|履物|楽器|書物|書籍|乗り物|車両|自動車|自転車)$/.test(c))) return 1;
    return 0;
  }
  const hasImage = page => Boolean(page?.pageimage && page?.thumbnail?.source);
  const sameReading = (page, word) => sortReading(page.pageprops?.defaultsort || '') === sortReading(word) ||
    normalize(page.title) === normalize(word);
  async function resolveMeaning(page, word, signal) {
    const pages = new Map();
    let continuation = '';
    // Some disambiguation pages (カイ, for example) have more than fifty links.
    // Follow link pagination, while bounding both traffic and total work.
    for (let batch = 0; batch < 3; batch++) {
      const data = await query({titles: page.title, generator: 'links', gplnamespace: '0', gpllimit: '50',
        ...(continuation ? {gplcontinue: continuation} : {}), redirects: '1', ...PAGE_PROPERTIES}, signal);
      for (const candidate of data.pages || []) pages.set(candidate.pageid || candidate.title, candidate);
      continuation = data.nextLinks;
      if (!continuation) return chooseReading([...pages.values()], word, true);
    }
    return [];
  }
  function chooseReading(pages, word, linked = false) {
    const generalTopics = new Set(['動物', '植物', '生物', '食品', '人物']);
    const candidates = pages.filter(candidate => candidate.ns === 0 && !candidate.missing &&
      !Object.hasOwn(candidate.pageprops || {}, 'disambiguation') &&
      (sameReading(candidate, word) || (linked && (
        (normalize(word).length >= 2 && normalize(candidate.title).startsWith(normalize(word))) ||
        (familiarity(candidate) > 0 && !generalTopics.has(candidate.title))))) &&
      (!/[（(]/.test(candidate.title) || familiarity(candidate) > 0));
    // Disambiguation links establish a relation even for a different formal name
    // (サカナ -> 魚類). Full-text search results still require the same reading.
    const rank = candidate => [familiarity(candidate), Number(sameReading(candidate, word)), -[...candidate.title].length];
    const compare = (a, b) => {
      const left = rank(a), right = rank(b);
      for (let i = 0; i < left.length; i++) if (left[i] !== right[i]) return right[i] - left[i];
      return 0;
    };
    candidates.sort(compare);
    return candidates;
  }
  async function searchReading(word, signal) {
    const reading = normalize(word).replace(/[ァ-ヶ]/g, c => String.fromCharCode(c.charCodeAt(0) - 96));
    const data = await query({generator: 'search', gsrsearch: `"${reading}"`, gsrnamespace: '0', gsrlimit: '50',
      gsrprop: '', ...PAGE_PROPERTIES}, signal);
    const pages = data.pages || [];
    let chosen = chooseReading(pages, word);
    // Search rankings can be filled with works named after an everyday object.
    // A matching 花火 (…の曲) provides the base title 花火 without a local dictionary.
    if (!chosen.length || !hasImage(chosen[0]) || familiarity(chosen[0]) <= 0) {
      const bases = [...new Set(pages.filter(page => !page.missing && sameReading(page, word) && /[（(]/.test(page.title))
        .map(page => page.title.replace(/\s*[（(].*$/, '').trim()))].slice(0, 5);
      if (bases.length) {
        const baseData = await query({titles: bases.join('|'), redirects: '1', ...PAGE_PROPERTIES}, signal);
        chosen = chooseReading([...pages, ...(baseData.pages || [])]
          .filter((page, index, all) => all.findIndex(other => other.title === page.title) === index), word);
      }
    }
    // Search can find a kanji disambiguation title (ニク -> 肉).
    // Resolve it just like an exact-title hit instead of discarding it.
    const meanings = pages.filter(page => page.ns === 0 && !page.missing &&
      sameReading(page, word) && Object.hasOwn(page.pageprops || {}, 'disambiguation')).slice(0, 3);
    for (const page of meanings) chosen.push(...await resolveMeaning(page, word, signal));
    return chooseReading(chosen, word, true);
  }
  async function lookup(word, signal) {
    let page = await article(word, signal);
    const canonical = normalize(word);
    if ((!page || page.missing) && canonical !== word) page = await article(canonical, signal);
    let pages;
    if (!page || page.missing) {
      pages = await searchReading(canonical, signal);
      if (!pages.length) return missing('not_found');
    } else {
      if (page.ns !== 0) return missing('ambiguous');
      if (Object.hasOwn(page.pageprops || {}, 'disambiguation')) {
        pages = await resolveMeaning(page, canonical, signal);
        if (!pages.length) return missing('ambiguous');
      } else pages = [page];
      if (!hasImage(pages[0]) || familiarity(pages[0]) < 0) {
        const alternatives = await searchReading(canonical, signal);
        pages = [...alternatives, ...pages];
      }
    }
    const seen = new Set();
    const candidates = pages.filter(candidate => {
      if (!hasImage(candidate) || seen.has(candidate.pageimage)) return false;
      seen.add(candidate.pageimage);
      return true;
    }).slice(0, 6);
    if (!candidates.length) return missing('no_image');
    // Two downloads at a time; preserve ranking even when responses arrive out of order.
    const values = new Array(candidates.length);
    let next = 0;
    await Promise.all([0, 1].map(async () => {
      while (next < candidates.length) {
        const index = next++;
        try { values[index] = await loadImage(candidates[index], signal); }
        catch { values[index] = missing('network'); }
      }
    }));
    const images = values.filter(value => value.status === 'image');
    if (!images.length) return values.find(value => value.status === 'network') || values[0];
    return {...images[0], images, partial: values.some(value => value.status === 'network')};
  }
  async function loadImage(page, signal) {
    const imageUrl = new URL(page.thumbnail.source);
    if (imageUrl.protocol !== 'https:' || !['upload.wikimedia.org', 'thumb.wikimedia.org'].includes(imageUrl.hostname)) return missing('no_image');
    const response = await fetch(imageUrl, {signal, credentials: 'omit', referrerPolicy: 'no-referrer'});
    if (!response.ok) throw new Error('image');
    if (Number(response.headers.get('content-length')) > 2_000_000) return missing('no_image');
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.length > 2_000_000) return missing('no_image');
    let binary = '';
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return {status: 'image', image: btoa(binary), article_url: `https://ja.wikipedia.org/wiki/${encodeURIComponent(page.title)}`};
  }
  globalThis.kotobaTouch = {
    speak(text) {
      try {
        if (!globalThis.speechSynthesis || !globalThis.SpeechSynthesisUtterance) return false;
        speechSynthesis.cancel();
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.lang = 'ja-JP';
        utterance.rate = 0.85;
        const voice = speechSynthesis.getVoices().find(v => /^ja(?:-|$)/i.test(v.lang));
        if (voice) utterance.voice = voice;
        speechSynthesis.speak(utterance);
        return true;
      } catch { return false; }
    },
    cancel() {
      serial++;
      controller?.abort();
      result = null;
      try { globalThis.speechSynthesis?.cancel(); } catch {}
    },
    search(word) {
      const id = ++serial;
      controller?.abort();
      controller = null;
      result = null;
      if (!word) return;
      if (cache.has(word)) { result = {...cache.get(word), word}; return; }
      // Prevent repeated taps or rapid edits from creating request bursts.
      if (Date.now() - lastStart < 1500) { result = {status: 'wait', word}; return; }
      lastStart = Date.now();
      controller = new AbortController();
      const signal = controller.signal;
      const timeout = setTimeout(() => controller?.signal === signal && controller.abort(), 15000);
      lookup(word, signal).then(value => {
        if (id !== serial) return;
        if (cache.size >= 32) cache.delete(cache.keys().next().value);
        if (!value.partial && value.status !== 'network') cache.set(word, value);
        result = {...value, word};
      }).catch(() => {
        if (id === serial) result = {status: 'network', word};
      }).finally(() => clearTimeout(timeout));
    },
    take() {
      const value = result;
      result = null;
      return value ? JSON.stringify(value) : '';
    },
  };
})();
