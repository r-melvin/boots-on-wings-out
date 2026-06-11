extends RefCounted

static var _cache: Dictionary = {}

static func get_tex(path: String) -> ImageTexture:
	if not _cache.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_cache[path] = ImageTexture.create_from_image(img)
	return _cache[path]
