class_name AssetGrid
extends ItemList

## Grille de fichiers façon explorateur : dossiers puis modèles 3D (.glb/.gltf).

signal folder_activated(path: String)   # double-clic / Entrée sur un dossier
signal file_selected(path: String)      # clic simple sur un fichier
signal file_activated(path: String)     # double-clic / Entrée sur un fichier

const MODEL_EXTENSIONS := [".glb", ".gltf", ".fbx", ".obj"]

var _folder_icon: Texture2D
var _model_icon: Texture2D
var _baker: ThumbnailBaker
var _index_by_path := {}          # chemin -> index de l'item (miniatures)
var entry_count := 0              # nb de dossiers + modèles affichés (hors placeholder « vide »)


func _ready() -> void:
	icon_mode = ItemList.ICON_MODE_TOP
	fixed_icon_size = Vector2i(64, 64)
	fixed_column_width = 128
	max_columns = 0            # autant de colonnes que la largeur le permet
	same_column_width = true
	icon_scale = 1.0
	max_text_lines = 2
	select_mode = ItemList.SELECT_SINGLE
	allow_reselect = true

	_folder_icon = _load_icon("res://icons/folder.svg", Color("ffb300"))
	_model_icon = _load_icon("res://icons/model.svg", Color("2196f3"))

	_baker = ThumbnailBaker.new()
	add_child(_baker)
	_baker.thumbnail_ready.connect(_on_thumbnail_ready)

	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)


## Remplit la grille avec le contenu de `path`.
func populate(path: String) -> void:
	clear()
	_index_by_path.clear()
	_baker.reset()

	var dirs := DirAccess.get_directories_at(path)
	dirs.sort()
	for d in dirs:
		if d.begins_with("."):
			continue
		var idx := add_item(d, _folder_icon)
		set_item_metadata(idx, {"type": "dir", "path": path.path_join(d)})

	var files := DirAccess.get_files_at(path)
	files.sort()
	for f in files:
		if not _is_model(f):
			continue
		var full := path.path_join(f)
		var idx := add_item(f, _model_icon)
		set_item_metadata(idx, {"type": "file", "path": full})
		_index_by_path[full] = idx
		_baker.request(full)          # miniature 3D (async, remplace l'icône)

	# À ce stade item_count = dossiers + modèles (le placeholder n'est pas encore ajouté).
	entry_count = item_count
	if item_count == 0:
		var idx := add_item("(Aucun dossier ni modèle 3D ici)")
		set_item_disabled(idx, true)


func _is_model(file_name: String) -> bool:
	var lower := file_name.to_lower()
	for ext in MODEL_EXTENSIONS:
		if lower.ends_with(ext):
			return true
	return false


func _on_item_selected(index: int) -> void:
	var meta = get_item_metadata(index)
	if meta is Dictionary and meta.get("type") == "file":
		file_selected.emit(meta["path"])


func _on_item_activated(index: int) -> void:
	var meta = get_item_metadata(index)
	if not (meta is Dictionary):
		return
	if meta.get("type") == "dir":
		folder_activated.emit(meta["path"])
	elif meta.get("type") == "file":
		file_activated.emit(meta["path"])


func _on_thumbnail_ready(path: String, texture: Texture2D) -> void:
	# Ignore les miniatures arrivées après un changement de dossier.
	if not _index_by_path.has(path):
		return
	var idx: int = _index_by_path[path]
	if idx < item_count and get_item_metadata(idx).get("path") == path:
		set_item_icon(idx, texture)


## Charge une icône SVG du projet ; repli sur un carré uni si l'import n'a pas
## encore été effectué (premier lancement sans ouverture de l'éditeur).
func _load_icon(res_path: String, fallback: Color) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var tex := load(res_path)
		if tex is Texture2D:
			return tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(fallback)
	return ImageTexture.create_from_image(img)
