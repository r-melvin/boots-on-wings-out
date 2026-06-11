extends RefCounted

static var _cache: Dictionary = {}

static func get_tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = _load_tex(path)
	return _cache[path]

static func _load_tex(path: String) -> Texture2D:
	# Imported resource: present in editor after first import and in exported pcks.
	if ResourceLoader.exists(path):
		return load(path)
	# Fallback for fresh checkouts before the importer has run: raw PNG bytes.
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("tex_loader: failed to load '%s'" % path)
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		push_error("tex_loader: invalid png '%s'" % path)
		return null
	return ImageTexture.create_from_image(img)
