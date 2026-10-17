extends RefCounted

const ROWS = ["アイウエオ", "カキクケコ", "サシスセソ", "タチツテト", "ナニヌネノ", "ハヒフヘホ", "マミムメモ", "ヤ ユ ヨ", "ラリルレロ", "ワ ヲ ン"]
const SMALL = "アイウエオヤユヨツ"
const SMALL_TO = "ァィゥェォャュョッ"
const VOICED = "カキクケコサシスセソタチツテトハヒフヘホウ"
const VOICED_TO = "ガギグゲゴザジズゼゾダヂヅデドバビブベボヴ"

static func hiragana(text: String) -> String:
	var result = ""
	for character in text:
		var code = character.unicode_at(0)
		result += String.chr(code - 96) if code >= 0x30a1 and code <= 0x30f6 else character
	return result

static func katakana(text: String) -> String:
	var result = ""
	for character in text:
		var code = character.unicode_at(0)
		result += String.chr(code + 96) if code >= 0x3041 and code <= 0x3096 else character
	return result

static func prolonged_sound(text: String) -> String:
	# Repeated long marks keep the preceding vowel; small kana determine it too.
	var preceding = katakana(text).trim_suffix("ー")
	while preceding.ends_with("ー"):
		preceding = preceding.left(-1)
	var last = preceding.right(1)
	var groups = ["アカサタナハマヤラワガザダバパァャヮヵ", "イキシチニヒミリヰギジヂビピィ", "ウクスツヌフムユルグズヅブプヴゥュ", "エケセテネヘメレヱゲゼデベペェヶ", "オコソトノホモヨロヲゴゾドボポォョ"]
	if not last.is_empty():
		for i in groups.size():
			if groups[i].contains(last): return "あいうえお"[i]
	# A leading mark, ン, or ッ has no vowel to prolong.
	return "ンー"

static func transform(text: String, kind: String) -> String:
	if text.is_empty(): return text
	var last = text.right(1)
	var source = katakana(last)
	var target = source
	var from = SMALL if kind == "small" else VOICED
	var to = SMALL_TO if kind == "small" else VOICED_TO
	if kind == "semi":
		from = "ハヒフヘホ"
		to = "パピプペポ"
	# Switch between voiced and semi-voiced forms directly.
	if kind != "small":
		var index = "バビブベボパピプペポ".find(source)
		if index >= 0: source = "ハヒフヘホ"[index % 5]
	var index = from.find(source)
	if index >= 0:
		target = to[index]
		if target == katakana(last): target = source
	elif to.contains(source):
		target = from[to.find(source)]
	if last != katakana(last): target = hiragana(target)
	return text.left(-1) + target
