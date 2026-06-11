extends RefCounted

static var _cache: Dictionary = {}

static func get_tex(path: String) -> ImageTexture:
	if not _cache.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			push_error("tex_loader: failed to load '%s'" % path)
			return null
		_cache[path] = ImageTexture.create_from_image(img)
	return _cache[path]
