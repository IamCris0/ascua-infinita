extends Translation
## English for a game written in Spanish. Texts are looked up whole; texts the
## code composes ("CÁMARA 7", "Logro · Primera brasa") are matched against the
## templates their pieces come from, and each %s piece is translated in turn.
## locale/en.json is kept in step with the code by tools/i18n/extract.py.

const SOURCE = "res://locale/en.json"
const CACHE_LIMIT = 4000

var exact: Dictionary = {}
# The same texts in capitals, in lowercase and capitalised, as the code
# sometimes changes their case before showing them.
var cased: Dictionary = {}
var templates: Array = []
var english: Dictionary = {}
var english_templates: Array = []
var cache: Dictionary = {}
# Spanish texts that reached the screen without a translation (for reports).
var missing: Dictionary = {}

static var instance

## Unregisters it; done on exit so the engine never keeps a freed script.
static func uninstall() -> void:
	if instance != null:
		TranslationServer.remove_translation(instance)
		instance = null

## Registers the English translation once and returns it.
static func install():
	if instance == null:
		instance = load("res://scripts/i18n.gd").new()
		instance.locale = "en"
		instance.load_source(SOURCE)
		TranslationServer.add_translation(instance)
	return instance


func load_source(path: String) -> void:
	var text = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text) if not text.is_empty() else null
	if not data is Dictionary:
		push_error("No se pudo leer " + path)
		return
	var pairs: Dictionary = data.get("texts", {}).duplicate()
	pairs.merge(data.get("templates", {}), true)
	for source in pairs:
		var target: String = pairs[source]
		if target.is_empty():
			continue
		if _placeholders(source).is_empty():
			exact[source] = target
			english[target] = true
		else:
			var compiled = _compile(source, target)
			# A template made only of placeholders would match anything.
			if compiled.weight > 0:
				templates.append(compiled)
				english_templates.append(_compile(target, target))
	for source in exact:
		var target: String = exact[source]
		for pair in [[source.to_upper(), target.to_upper()], [source.to_lower(), target.to_lower()], [source.capitalize(), target.capitalize()]]:
			if not exact.has(pair[0]) and not cased.has(pair[0]):
				cased[pair[0]] = pair[1]
				english[pair[1]] = true
	# The most specific templates (most literal text) are tried first.
	templates.sort_custom(func(a, b): return a.weight > b.weight)
	english_templates.sort_custom(func(a, b): return a.weight > b.weight)

static func _placeholders(text: String) -> Array:
	var found: Array = []
	var re = RegEx.create_from_string("%(%|[-+0-9.]*[dfs])")
	for m in re.search_all(text):
		if m.get_string() != "%%":
			found.append(m.get_string())
	return found

## A template becomes an anchored pattern; its longest literal piece is checked
## first so most texts skip the regular expression.
func _compile(source: String, target: String) -> Dictionary:
	var pattern := "^"
	var kinds: Array = []
	var literal := ""
	var longest := ""
	var re = RegEx.create_from_string("%(%|[-+0-9.]*[dfs])")
	var last := 0
	var weight := 0
	for m in re.search_all(source):
		literal = source.substr(last, m.get_start() - last)
		pattern += _escape(literal)
		weight += literal.length()
		if literal.length() > longest.length():
			longest = literal
		var spec = m.get_string()
		if spec == "%%":
			pattern += "%"
		elif spec.ends_with("s"):
			pattern += "(.+?)"
			kinds.append("s")
		elif spec.ends_with("f"):
			pattern += "(-?[0-9]+(?:[.,][0-9]+)?)"
			kinds.append("n")
		else:
			pattern += "(-?[0-9]+)"
			kinds.append("n")
		last = m.get_end()
	literal = source.substr(last)
	pattern += _escape(literal) + "$"
	weight += literal.length()
	if literal.length() > longest.length():
		longest = literal
	var compiled = RegEx.new()
	compiled.compile(pattern)
	return {"regex": compiled, "anchor": longest, "kinds": kinds, "target": target, "weight": weight}

static func _escape(text: String) -> String:
	var out := ""
	for c in text:
		if "\\^$.|?*+()[]{}".contains(c):
			out += "\\"
		out += c
	return out

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var source := String(src_message)
	if cache.has(source):
		return cache[source]
	var result = translate_text(source)
	if cache.size() > CACHE_LIMIT:
		cache.clear()
	cache[source] = result
	return result

## Whole text, then templates; untranslated Spanish is remembered.
func translate_text(source: String) -> String:
	if source.is_empty() or exact.has(source):
		return exact.get(source, source)
	if cased.has(source):
		return cased[source]
	if not _has_letters(source) or _is_number(source):
		return source
	# Spacing around a text is kept as it is.
	var core = source.strip_edges()
	if core != source:
		var start = source.find(core)
		return source.substr(0, start) + translate_text(core) + source.substr(start + core.length())
	var lines = source.split("\n")
	if lines.size() > 1:
		var parts: Array = []
		for line in lines:
			parts.append(translate_text(line))
		return "\n".join(parts)
	var templated = _from_templates(source, templates)
	if templated != null:
		return templated
	if not english.has(source) and _from_templates(source, english_templates) == null:
		missing[source] = true
	return source

func _from_templates(source: String, list: Array):
	for t in list:
		if not t.anchor.is_empty() and not source.contains(t.anchor):
			continue
		var m: RegExMatch = t.regex.search(source)
		if m == null:
			continue
		var values: Array = []
		for i in range(t.kinds.size()):
			var piece = m.get_string(i + 1)
			values.append(translate_text(piece) if t.kinds[i] == "s" else piece)
		return _fill(t.target, values)
	return null

## Puts the values back in the order of the template's placeholders.
static func _fill(target: String, values: Array) -> String:
	var re = RegEx.create_from_string("%(%|[-+0-9.]*[dfs])")
	var out := ""
	var last := 0
	var index := 0
	for m in re.search_all(target):
		out += target.substr(last, m.get_start() - last)
		if m.get_string() == "%%":
			out += "%"
		elif index < values.size():
			out += str(values[index])
			index += 1
		last = m.get_end()
	return out + target.substr(last)

static func _has_letters(text: String) -> bool:
	for c in text:
		var code = c.unicode_at(0)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 192 and code <= 591 and code != 215 and code != 247):
			return true
	return false

## Amounts such as "107.5k" or "2.31e15", and version numbers.
static func _is_number(text: String) -> bool:
	var re = RegEx.create_from_string("^[-+×]?[0-9][0-9.,]*(e[0-9]+|[kMBT])?$|^v[0-9][0-9a-z.-]*$")
	return re.search(text) != null
