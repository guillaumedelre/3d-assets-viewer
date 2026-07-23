class_name ModelScan
extends RefCounted

## Scan partagé (dossiers + modèles) utilisé par la vue Détails (et réutilisable ailleurs).
## Récursif dès qu'un filtre de recherche est fourni ; renvoie aussi taille et date des fichiers.

const EXTENSIONS := [".glb", ".gltf", ".fbx", ".obj"]
const _MAX_SCAN_DIRS := 4000
const _MAX_RESULTS := 1000

enum { SORT_NAME, SORT_TYPE, SORT_SIZE, SORT_DATE }


static func is_model(file_name: String) -> bool:
	var lower := file_name.to_lower()
	for ext in EXTENSIONS:
		if lower.ends_with(ext):
			return true
	return false


## Renvoie { "dirs": [{name, path}], "files": [{name, path, size, mtime}] }, filtré + trié.
static func collect(path: String, name_filter: String, sort_mode: int, ascending: bool) -> Dictionary:
	var needle := name_filter.strip_edges().to_lower()
	var dirs: Array = []
	var files: Array = []
	_walk(path, needle, needle != "", dirs, files, [0])
	dirs.sort_custom(_cmp_name)
	_sort_files(files, sort_mode)
	if not ascending:
		dirs.reverse()
		files.reverse()
	return {"dirs": dirs, "files": files}


static func _walk(path: String, needle: String, recurse: bool, dirs: Array, files: Array, scanned: Array) -> void:
	if scanned[0] > _MAX_SCAN_DIRS or files.size() >= _MAX_RESULTS:
		return
	scanned[0] += 1

	for f in DirAccess.get_files_at(path):
		if files.size() >= _MAX_RESULTS:
			break
		if not is_model(f):
			continue
		if needle != "" and not (needle in f.to_lower()):
			continue
		var full := path.path_join(f)
		var size := 0
		var fa := FileAccess.open(full, FileAccess.READ)
		if fa != null:
			size = fa.get_length()
			fa.close()
		files.append({name = f, path = full, size = size, mtime = FileAccess.get_modified_time(full)})

	for d in DirAccess.get_directories_at(path):
		if d.begins_with("."):
			continue
		var sub := path.path_join(d)
		if needle == "" or (needle in d.to_lower()):
			dirs.append({name = d, path = sub})
		if recurse:
			_walk(sub, needle, true, dirs, files, scanned)


static func _sort_files(arr: Array, mode: int) -> void:
	match mode:
		SORT_TYPE: arr.sort_custom(_cmp_type)
		SORT_SIZE: arr.sort_custom(_cmp_size)
		SORT_DATE: arr.sort_custom(_cmp_date)
		_: arr.sort_custom(_cmp_name)


static func _cmp_name(a: Dictionary, b: Dictionary) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0

static func _cmp_type(a: Dictionary, b: Dictionary) -> bool:
	var ea: String = a.name.get_extension().to_lower()
	var eb: String = b.name.get_extension().to_lower()
	if ea == eb:
		return a.name.naturalnocasecmp_to(b.name) < 0
	return ea < eb

static func _cmp_size(a: Dictionary, b: Dictionary) -> bool:
	return a.size < b.size

static func _cmp_date(a: Dictionary, b: Dictionary) -> bool:
	return a.mtime < b.mtime
