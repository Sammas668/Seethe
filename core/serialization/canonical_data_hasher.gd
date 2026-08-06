class_name CanonicalDataHasher
extends RefCounted


static func sha256_hex(value: Variant) -> String:
	var context := HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(canonical_string(value).to_utf8_buffer())
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func canonical_string(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if bool(value) else "false"
		TYPE_INT:
			return str(int(value))
		TYPE_FLOAT:
			return String.num(float(value), 17)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(value))
		TYPE_VECTOR2I:
			var vector_value := Vector2i(value)
			return "{\"$vector2i\":[%d,%d]}" % [vector_value.x, vector_value.y]
		TYPE_RECT2I:
			var rect_value := Rect2i(value)
			return "{\"$rect2i\":[%d,%d,%d,%d]}" % [
				rect_value.position.x,
				rect_value.position.y,
				rect_value.size.x,
				rect_value.size.y,
			]
		TYPE_ARRAY:
			var entries: Array[String] = []
			for entry: Variant in value as Array:
				entries.append(canonical_string(entry))
			return "[" + ",".join(entries) + "]"
		TYPE_DICTIONARY:
			return _canonical_dictionary(value as Dictionary)
		TYPE_OBJECT:
			var object_value: Object = value as Object
			if object_value != null and object_value.has_method("to_dictionary"):
				return canonical_string(object_value.call("to_dictionary"))
			return JSON.stringify(str(value))
		_:
			return JSON.stringify(str(value))


static func _canonical_dictionary(value: Dictionary) -> String:
	var keys: Array[String] = []
	var original_key_by_text: Dictionary = {}
	for raw_key: Variant in value.keys():
		var key_text: String = String(raw_key)
		keys.append(key_text)
		original_key_by_text[key_text] = raw_key
	keys.sort()
	var entries: Array[String] = []
	for key_text: String in keys:
		var raw_key: Variant = original_key_by_text.get(key_text)
		entries.append(
			JSON.stringify(key_text) + ":" + canonical_string(value.get(raw_key))
		)
	return "{" + ",".join(entries) + "}"
