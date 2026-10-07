extends RefCounted
## Thin native resource request. Cancellation belongs to the owning generation.
var _path := ""

func begin(path: String) -> Error:
	if not ResourceLoader.exists(path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	_path = path
	# A cancelled owner may have left native I/O running for this same path.
	var status := ResourceLoader.load_threaded_get_status(_path)
	if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
		return OK
	return ResourceLoader.load_threaded_request(_path, "PackedScene", false)

func status() -> int:
	return ResourceLoader.load_threaded_get_status(_path)

func take_scene() -> PackedScene:
	if status() != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(_path) as PackedScene
