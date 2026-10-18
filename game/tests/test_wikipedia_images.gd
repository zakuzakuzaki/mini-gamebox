extends SceneTree

const Images = preload("res://scenes/games/kotoba_touch/wikipedia_images.gd")
var failures = 0

class MockImages extends "res://scenes/games/kotoba_touch/wikipedia_images.gd":
	var responses: Array = []
	var index = 0
	var urls: Array[String] = []
	var mismatch = false
	var delayed = false
	var oversized = false
	func _request(url: String, _job: Dictionary, _limit: int) -> Dictionary:
		urls.append(url)
		if delayed: await get_tree().process_frame
		if oversized: return {"oversized": true}
		if index >= responses.size(): return {}
		var entry: Dictionary = responses[index]
		index += 1
		if _url_parts(url) != _url_parts(entry.url): mismatch = true
		if entry.get("network", false): return {}
		if entry.has("json"): return {"body": JSON.stringify(entry.json).to_utf8_buffer()}
		return {"body": PackedByteArray(entry.get("bytes", []))}
	func _url_parts(url: String) -> Dictionary:
		var parts = {"path": url.get_slice("?", 0)}
		for pair in url.get_slice("?", 1).split("&", false):
			parts[pair.get_slice("=", 0).uri_decode()] = pair.get_slice("=", 1).uri_decode()
		return parts

func check(value: bool, description: String) -> void:
	if not value:
		push_error(description)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/wikipedia_fixtures.json"))
	for fixture in fixtures:
		var service = MockImages.new()
		service.responses = fixture.responses
		root.add_child(service)
		var received: Array = []
		service.result_ready.connect(func(value): received.append(value))
		await service.search(fixture.word)
		var comparable: Dictionary = received[0].duplicate()
		if comparable.status == "image": comparable.erase("candidates")
		check(received.size() == 1 and comparable == fixture.expected, "Legacy search parity: " + fixture.word + " actual=" + JSON.stringify(received))
		check(not service.mismatch and service.index == fixture.responses.size(), "Request parity: " + fixture.word)
		var count = service.urls.size()
		await service.search(fixture.word)
		check(service.urls.size() == count and received.back() == received[0], "Cache: " + fixture.word)
		await service.search("別のことば")
		check(received.back().status == "wait" and service.urls.size() == count, "Throttle: " + fixture.word)
		service.free()
	# Keep successful thumbnails when another download fails, but retry next time.
	for fixture in fixtures:
		if fixture.expected.get("images", []).size() < 2: continue
		var partial_service = MockImages.new()
		partial_service.responses = fixture.responses.duplicate(true)
		partial_service.responses[-1]["network"] = true
		partial_service.delayed = true
		root.add_child(partial_service)
		var partial_results: Array = []
		partial_service.result_ready.connect(func(value): partial_results.append(value))
		await partial_service.search(fixture.word)
		check(partial_results.size() == 1 and partial_results[0].status == "image" and partial_results[0].partial, "Keep successful images on partial failure")
		check(partial_service.cache.is_empty(), "Partial results are not cached")
		partial_service.free()
		break
	# Missing thumbnails still produce up to three distinct, ranked article titles.
	var text_service = MockImages.new()
	root.add_child(text_service)
	var pages: Array = []
	for title in ["猫", "ねこ", "ネコ", "猫科", "ネコ"]:
		pages.append({"ns": 0, "title": title, "pageprops": {"defaultsort": "ねこ"}})
	text_service.responses = [{"url": "", "json": {"query": {"pages": [{"missing": true}]}}},
		{"url": "", "json": {"query": {"pages": pages}}}]
	var text_results: Array = []
	text_service.result_ready.connect(func(value): text_results.append(value))
	await text_service.search("ネコ")
	check(text_results[0].status == "text" and text_results[0].candidates.size() == 3, "Missing images retain at most three candidates")
	check(text_results[0].candidates.map(func(value): return value.title) == ["猫", "ねこ", "ネコ"], "Text candidates preserve ranking and remove duplicates")
	text_service.free()
	# A thumbnail network failure keeps its title and remains retryable.
	var failed_image = MockImages.new()
	root.add_child(failed_image)
	failed_image.responses = fixtures[4].responses.duplicate(true)
	failed_image.responses[-1]["network"] = true
	text_results.clear()
	failed_image.result_ready.connect(func(value): text_results.append(value))
	await failed_image.search("イヌ")
	check(text_results[0].status == "text" and text_results[0].candidates[0].title == "イヌ", "Download failure retains article title")
	check(text_results[0].partial and failed_image.cache.is_empty(), "Image download failure can be retried")
	failed_image.free()
	var failed_search = MockImages.new()
	root.add_child(failed_search)
	failed_search.responses = [fixtures[0].responses[0]]
	text_results.clear()
	failed_search.result_ready.connect(func(value): text_results.append(value))
	await failed_search.search("ネコ")
	check(text_results[0].status == "text" and text_results[0].candidates[0].title == "ネコ", "Failed additional search retains exact match")
	check(failed_search.cache.is_empty(), "Incomplete search is not cached")
	failed_search.free()
	# A disambiguation page's same-name links must survive parenthetical qualifiers.
	for word in ["ナミ", "なみ"]:
		var nami = MockImages.new()
		root.add_child(nami)
		var links: Array = []
		for title in ["ナミ (ONE PIECE)", "ナミ (歌手)", "ナミ (タレント)", "ナミ (競走馬)"]:
			links.append({"ns": 0, "title": title, "pageprops": {"defaultsort": "なみ"},
				"categories": [] if title.ends_with("競走馬)") else [{"title": "Category:人物"}]})
		links.append({"ns": 0, "title": "ナミに似た名前 (作品)", "pageprops": {"defaultsort": "べつ"}})
		var exact = {"url": "", "json": {"query": {"pages": [{"ns": 0, "title": "ナミ", "pageprops": {"disambiguation": ""}}]}}}
		nami.responses = [exact, {"url": "", "json": {"query": {"pages": links}}}, {"url": "", "json": {"batchcomplete": true}}]
		var nami_results: Array = []
		nami.result_ready.connect(func(value): nami_results.append(value))
		await nami.search(word)
		check(nami_results[0].status == "text", "Nami same-name candidates survive filtering: " + word)
		check(nami_results[0].candidates.map(func(value): return value.title) == ["ナミ (競走馬)", "ナミ (ONE PIECE)", "ナミ (歌手)"], "Qualifier length does not bury same-name candidates")
		nami.free()
	# A spelling-note page is not an HTTP/API redirect; follow its article links.
	for word in ["ドラエモン", "どらえもん"]:
		var spelling = MockImages.new()
		root.add_child(spelling)
		spelling.responses = [
			{"url": "", "json": {"query": {"pages": [{"ns": 0, "title": "ドラエモン", "categories": [{"title": "Category:誤表記"}]}]}}},
			{"url": "", "json": {"query": {"pages": [{"ns": 0, "title": "ドラえもん", "pageimage": "Example.jpg", "thumbnail": {"source": "https://thumb.wikimedia.org/example.jpg"}}, {"ns": 0, "title": "無関係"}]}}},
			{"url": "https://thumb.wikimedia.org/example.jpg", "bytes": [1, 2, 3]}]
		var spelling_results: Array = []
		spelling.result_ready.connect(func(value): spelling_results.append(value))
		await spelling.search(word)
		check(spelling_results[0].status == "image" and spelling_results[0].title == "ドラえもん", "Spelling note resolves to the official article: " + word)
		check(spelling_results[0].candidates.size() == 1 and spelling_results[0].candidates[0].title == "ドラえもん", "Spelling note itself is not a candidate")
		spelling.free()
	var offline = MockImages.new()
	root.add_child(offline)
	var results: Array = []
	offline.result_ready.connect(func(value): results.append(value))
	await offline.search("ネコ")
	check(results.back().status == "network" and offline.cache.is_empty(), "Network errors are not cached")
	offline.last_start = -1500
	await offline.search("ネコ")
	check(offline.urls.size() == 2, "Network errors can be retried")
	offline.free()
	var canceled = MockImages.new()
	root.add_child(canceled)
	canceled.delayed = true
	canceled.result_ready.connect(func(value): results.append(value))
	results.clear()
	canceled.search("古い")
	canceled.last_start = -1500
	canceled.search("新しい")
	await process_frame
	await process_frame
	check(results.size() == 1 and results[0].word == "新しい", "Late old results cannot replace latest search")
	results.clear()
	canceled.last_start = -1500
	canceled.search("取り消し")
	canceled.cancel()
	await process_frame
	await process_frame
	check(results.is_empty(), "Cancel suppresses result")
	canceled.free()
	var images = MockImages.new()
	root.add_child(images)
	var job = {"id": 0, "deadline": Time.get_ticks_msec() + 15000, "failed": false}
	var rejected = await images._load_image({"thumbnail": {"source": "https://upload.wikimedia.org.evil.test/a"}}, job)
	check(rejected.status == "no_image" and images.urls.is_empty(), "Reject non-Wikimedia host")
	images.oversized = true
	var large = await images._load_image({"thumbnail": {"source": "https://upload.wikimedia.org/a"}}, job)
	check(large.status == "no_image", "Reject oversized image")
	images.free()
	print("Wikipedia image checks passed (28 legacy cases, cache, throttle, network, cancellation, image limits)" if failures == 0 else "Wikipedia image checks FAILED")
	quit(1 if failures else 0)
