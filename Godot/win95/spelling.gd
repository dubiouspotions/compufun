class_name Spelling
## The word list that Word's spell check uses: every word in the CMU Pronouncing Dictionary that the
## live voice ships (voices/live/cmudict.txt.gz), about 126,000. It loads at the first check.

const DICTIONARY_PATH := "res://voices/live/cmudict.txt.gz"

static var _words: Dictionary[String, bool] = {}
static var _loaded := false  # tried once; a failure leaves the list empty and every word right


## True when [param word] is spelt right: it is in the list, whatever its case, or it holds a digit.
## An empty word is right.
static func is_known(word: String) -> bool:
	if word.is_empty() or _has_digit(word):
		return true
	if not _loaded:
		_loaded = true
		_load()
	return _words.is_empty() or _words.has(word.to_lower().replace("’", "'"))


## The ranges [start, end) of the misspelt words in [param text]. A word is a run of letters and
## apostrophes; apostrophes at its ends don't count.
static func misspelt(text: String) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var i := 0
	var n := text.length()
	while i < n:
		if not _in_word(text[i]):
			i += 1
			continue
		var start := i
		while i < n and _in_word(text[i]):
			i += 1
		var stop := i
		while start < stop and _is_apostrophe(text[start]):
			start += 1
		while stop > start and _is_apostrophe(text[stop - 1]):
			stop -= 1
		if stop > start and not is_known(text.substr(start, stop - start)):
			found.append(Vector2i(start, stop))
	return found


static func _load() -> void:
	var gz := FileAccess.get_file_as_bytes(DICTIONARY_PATH)
	if gz.is_empty():
		push_error("Spelling: can't read %s: %s; every word counts as right" % [DICTIONARY_PATH, error_string(FileAccess.get_open_error())])
		return
	var text := gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	if text.is_empty():
		push_error("Spelling: %s did not unzip; every word counts as right" % DICTIONARY_PATH)
		return
	for line: String in text.split("\n", false):
		var word := line.get_slice("\t", 0)
		var variant := word.find("(")
		_words[word.substr(0, variant) if variant > 0 else word] = true


static func _in_word(c: String) -> bool:
	return c.to_lower() != c.to_upper() or _is_apostrophe(c)


static func _is_apostrophe(c: String) -> bool:
	return c == "'" or c == "’"


static func _has_digit(word: String) -> bool:
	for c: String in word:
		if c.is_valid_int():
			return true
	return false
