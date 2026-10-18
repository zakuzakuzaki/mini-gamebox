extends Node

signal result_ready(result: Dictionary)

const API = "https://ja.wikipedia.org/w/api.php"
const PROPERTIES = {"prop": "pageimages|pageprops|categories", "cllimit": "max", "clshow": "!hidden",
	"piprop": "name|thumbnail", "pilicense": "any", "pilimit": "max", "pithumbsize": "400"}
const GENERAL_TOPICS = ["動物", "植物", "生物", "食品", "人物"]
var cache: Dictionary = {}
var serial = 0
var last_start = -1500
var requests: Dictionary = {}

class ImageBatch extends RefCounted:
	signal done
	var remaining = 0
	var values: Array = []

func cancel() -> void:
	serial += 1
	# Complete pending awaits as well as cancelling the underlying HTTP transfer.
	for request in requests.keys():
		request.cancel_request()
		request.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())

func _exit_tree() -> void:
	cancel()

func search(word: String) -> void:
	cancel()
	if word.is_empty(): return
	if cache.has(word):
		_publish(cache[word], word)
		return
	var now = Time.get_ticks_msec()
	if now - last_start < 1500:
		_publish({"status": "wait"}, word)
		return
	last_start = now
	var job = {"id": serial, "deadline": now + 15000, "failed": false}
	var value = await _lookup(word, job)
	if job.id != serial: return
	if not value.get("partial", false) and value.status != "network":
		if cache.size() >= 32: cache.erase(cache.keys()[0])
		cache[word] = value
	_publish(value, word)

func _publish(value: Dictionary, word: String) -> void:
	var result = value.duplicate()
	result.word = word
	result_ready.emit(result)

func _request(url: String, job: Dictionary, limit: int) -> Dictionary:
	if job.id != serial or job.failed: return {}
	var remaining = job.deadline - Time.get_ticks_msec()
	if remaining <= 0:
		job.failed = true
		return {}
	var request = HTTPRequest.new()
	request.timeout = float(remaining) / 1000.0
	request.body_size_limit = limit
	request.max_redirects = 0
	add_child(request)
	requests[request] = true
	var error = request.request(url)
	var response: Array = []
	if error == OK: response = await request.request_completed
	requests.erase(request)
	request.queue_free()
	if job.id != serial: return {}
	if error != OK or response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return {"oversized": error == OK and response[0] == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED}
	return {"body": response[3]}

func _query(params: Dictionary, job: Dictionary) -> Dictionary:
	if job.id != serial or job.failed: return {}
	var query = {"action": "query", "format": "json", "formatversion": "2", "origin": "*", "maxlag": "5"}
	query.merge(params, true)
	var parts: PackedStringArray = []
	for key in query: parts.append(str(key).uri_encode() + "=" + str(query[key]).uri_encode())
	var response = await _request(API + "?" + "&".join(parts), job, 4000000)
	var parser = JSON.new()
	var data = null
	if response.has("body") and parser.parse(response.body.get_string_from_utf8()) == OK:
		data = parser.data
	if not data is Dictionary or data.has("error") or (not data.has("query") and not data.has("batchcomplete")):
		job.failed = true
		return {}
	var result: Dictionary = data.get("query", {})
	result["nextLinks"] = data.get("continue", {}).get("gplcontinue", "")
	return result

func _pages(params: Dictionary, job: Dictionary) -> Dictionary:
	var query = PROPERTIES.duplicate()
	query.merge(params, true)
	return await _query(query, job)

func _article(title: String, job: Dictionary) -> Dictionary:
	var data = await _pages({"titles": title, "redirects": "1"}, job)
	var pages: Array = data.get("pages", [])
	return pages[0] if pages.size() == 1 else {}

static func normalize(text: String) -> String:
	var result = ""
	for character in text:
		var code = character.unicode_at(0)
		result += String.chr(code + 96) if code >= 0x3041 and code <= 0x3096 else character
	return result

static func sort_reading(text: String) -> String:
	var result = normalize(text)
	# Equivalent to removing kana voicing after Unicode decomposition.
	var voiced = "ガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポヴヷヸヹヺ"
	var plain = "カキクケコサシスセソタチツテトハヒフヘホハヒフヘホウワヰヱヲ"
	for i in voiced.length(): result = result.replace(voiced[i], plain[i])
	result = result.replace("\u3099", "").replace("\u309a", "")
	var small = "ァィゥェォッャュョヮヵヶ"
	var large = "アイウエオツヤユヨワカケ"
	for i in small.length(): result = result.replace(small[i], large[i])
	return result

static func _matches(text: String, pattern: String) -> bool:
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex.search(text) != null

static func familiarity(page: Dictionary) -> int:
	var categories = ""
	for category in page.get("categories", []): categories += str(category.title).trim_prefix("Category:") + "\n"
	if _matches(categories, "人物|歌手|俳優|芸人|音楽グループ|バンド|映画|漫画|小説|楽曲|企業|ブランド|架空|キャラクター"): return -1
	if _matches(categories, "(?m)(動物|哺乳類|鳥類|魚類|貝類|昆虫|爬虫類|両生類|軟体動物|甲殻類|植物|樹木|花卉|果物|野菜|イヌ科|ネコ科|ウサギ科|ウマ科|ウシ科|タカ科)$"): return 3
	if _matches(categories, "(?m)(食品|食材|料理|菓子|パン|飲料|果実|食用魚|水産物)$") and not _matches(categories, "酒|飲酒"): return 2
	if _matches(categories, "(?m)(日用品|生活用品|文房具|玩具|遊具|家具|食器|調理器具|衣類|衣服|履物|楽器|書物|書籍|乗り物|車両|自動車|自転車)$"): return 1
	return 0

static func _is_spelling_page(page: Dictionary) -> bool:
	return page.get("categories", []).any(func(category): return category.get("title", "") == "Category:誤表記")

static func _has_image(page: Dictionary) -> bool:
	return not str(page.get("pageimage", "")).is_empty() and page.get("thumbnail") is Dictionary and not str(page.thumbnail.get("source", "")).is_empty()

static func _same_reading(page: Dictionary, word: String) -> bool:
	return sort_reading(page.get("pageprops", {}).get("defaultsort", "")) == sort_reading(word) or normalize(page.get("title", "")) == normalize(word)

static func _base_title(title: String) -> String:
	return title.replace("（", "(").get_slice("(", 0).strip_edges()

static func choose_reading(pages: Array, word: String, linked = false) -> Array:
	var candidates: Array = []
	for page in pages:
		if page.get("ns", -1) != 0 or page.has("missing") or page.get("pageprops", {}).has("disambiguation"): continue
		var title: String = page.get("title", "")
		var related = linked and ((normalize(word).length() >= 2 and normalize(title).begins_with(normalize(word))) or (familiarity(page) > 0 and not title in GENERAL_TOPICS))
		if not _same_reading(page, word) and not related: continue
		# Explicit same-name links are valid even for people and fictional characters.
		var same_name_link = linked and normalize(_base_title(title)) == normalize(word)
		if _matches(title, "[（(]") and familiarity(page) <= 0 and not same_name_link: continue
		candidates.append(page)
	candidates.sort_custom(func(a, b):
		var left = [familiarity(a), int(_same_reading(a, word)), -_base_title(a.title).length() if linked else -a.title.length()]
		var right = [familiarity(b), int(_same_reading(b, word)), -_base_title(b.title).length() if linked else -b.title.length()]
		for i in left.size():
			if left[i] != right[i]: return left[i] > right[i]
		return false)
	return candidates

func _resolve_meaning(page: Dictionary, word: String, job: Dictionary) -> Array:
	var pages: Dictionary = {}
	var continuation = ""
	for batch in 3:
		var params = {"titles": page.title, "generator": "links", "gplnamespace": "0", "gpllimit": "50", "redirects": "1"}
		if not continuation.is_empty(): params.gplcontinue = continuation
		var data = await _pages(params, job)
		for candidate in data.get("pages", []): pages[candidate.get("pageid", candidate.title)] = candidate
		continuation = data.get("nextLinks", "")
		if continuation.is_empty(): return choose_reading(pages.values(), word, true)
	return []

func _search_reading(word: String, job: Dictionary) -> Array:
	var reading = ""
	for character in normalize(word):
		var code = character.unicode_at(0)
		reading += String.chr(code - 96) if code >= 0x30a1 and code <= 0x30f6 else character
	var data = await _pages({"generator": "search", "gsrsearch": '"' + reading + '"', "gsrnamespace": "0", "gsrlimit": "50", "gsrprop": ""}, job)
	var pages: Array = data.get("pages", [])
	var chosen = choose_reading(pages, word)
	if chosen.is_empty() or not _has_image(chosen[0]) or familiarity(chosen[0]) <= 0:
		var bases: PackedStringArray = []
		for page in pages:
			if page.has("missing") or not _same_reading(page, word) or not _matches(page.title, "[（(]"): continue
			var base = str(page.title).replace("（", "(").get_slice("(", 0).strip_edges()
			if not base in bases: bases.append(base)
			if bases.size() == 5: break
		if not bases.is_empty():
			var base_data = await _pages({"titles": "|".join(bases), "redirects": "1"}, job)
			var unique: Dictionary = {}
			for page in pages + base_data.get("pages", []):
				if not unique.has(page.title): unique[page.title] = page
			chosen = choose_reading(unique.values(), word)
	var meanings = 0
	for page in pages:
		if page.get("ns", -1) != 0 or page.has("missing") or not _same_reading(page, word) or not page.get("pageprops", {}).has("disambiguation"): continue
		chosen.append_array(await _resolve_meaning(page, word, job))
		meanings += 1
		if meanings == 3: break
	return choose_reading(chosen, word, true)

func _lookup(word: String, job: Dictionary) -> Dictionary:
	var page = await _article(word, job)
	var canonical = normalize(word)
	if (page.is_empty() or page.has("missing")) and canonical != word: page = await _article(canonical, job)
	var pages: Array = []
	if page.is_empty() or page.has("missing"):
		pages = await _search_reading(canonical, job)
		if pages.is_empty(): return {"status": "network" if job.failed else "not_found"}
	else:
		if page.get("ns", -1) != 0: return {"status": "ambiguous"}
		if page.get("pageprops", {}).has("disambiguation") or _is_spelling_page(page):
			pages = await _resolve_meaning(page, canonical, job)
			if pages.is_empty(): return {"status": "network" if job.failed else "ambiguous"}
		else: pages = [page]
		if not _has_image(pages[0]) or familiarity(pages[0]) < 0:
			pages = (await _search_reading(canonical, job)) + pages
	var text_candidates = _text_candidates(pages)
	if job.failed: return _text_result(text_candidates, true)
	var seen: Dictionary = {}
	var candidates: Array = []
	for candidate in pages:
		if not _has_image(candidate) or seen.has(candidate.pageimage): continue
		seen[candidate.pageimage] = true
		candidates.append(candidate)
		if candidates.size() == 6: break
	if candidates.is_empty(): return _text_result(text_candidates)
	var values: Array = []
	for offset in range(0, candidates.size(), 2):
		var batch = ImageBatch.new()
		batch.remaining = mini(2, candidates.size() - offset)
		batch.values.resize(batch.remaining)
		for index in batch.values.size(): _download(candidates[offset + index], job, batch, index)
		if batch.remaining > 0: await batch.done
		values.append_array(batch.values)
	var images = values.filter(func(value): return value.status == "image")
	var partial = values.any(func(value): return value.status == "network")
	if images.is_empty(): return _text_result(text_candidates, partial)
	var result: Dictionary = images[0].duplicate()
	result.candidates = text_candidates
	result.images = images
	result.partial = partial
	return result

static func _text_candidates(pages: Array) -> Array:
	var candidates: Array = []
	var seen: Dictionary = {}
	for page in pages:
		var title: String = page.get("title", "")
		if title.is_empty() or seen.has(title) or page.has("missing") or page.get("ns", -1) != 0 or page.get("pageprops", {}).has("disambiguation"): continue
		seen[title] = true
		candidates.append({"title": title, "article_url": "https://ja.wikipedia.org/wiki/" + title.uri_encode()})
		if candidates.size() == 3: break
	return candidates

static func _text_result(candidates: Array, partial = false) -> Dictionary:
	if candidates.is_empty(): return {"status": "network" if partial else "no_image"}
	return {"status": "text", "candidates": candidates, "partial": partial}

func _download(page: Dictionary, job: Dictionary, batch: ImageBatch, index: int) -> void:
	batch.values[index] = await _load_image(page, job)
	batch.remaining -= 1
	if batch.remaining == 0: batch.done.emit()

func _load_image(page: Dictionary, job: Dictionary) -> Dictionary:
	var url: String = page.thumbnail.source
	if not (url.begins_with("https://upload.wikimedia.org/") or url.begins_with("https://thumb.wikimedia.org/")): return {"status": "no_image"}
	var response = await _request(url, job, 2000000)
	if response.get("oversized", false): return {"status": "no_image"}
	if not response.has("body"): return {"status": "network"}
	return {"status": "image", "image": Marshalls.raw_to_base64(response.body), "title": str(page.title), "article_url": "https://ja.wikipedia.org/wiki/" + str(page.title).uri_encode()}
