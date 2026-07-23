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
var _folder_tex: Texture2D        # 📁 rendu en texture (icône dossier de la grille, échelonnable)
var _last_path := ""              # dernier dossier peuplé (pour ré-afficher quand la texture est prête)
var _last_filter := ""

enum { SORT_NAME, SORT_TYPE, SORT_SIZE, SORT_DATE }
var sort_mode := SORT_NAME        # critère de tri des modèles (dossiers toujours par nom)
var sort_ascending := true        # sens du tri (croissant / décroissant)

const _MAX_SCAN_DIRS := 4000      # garde-fou anti-gel pour la recherche récursive
const _MAX_RESULTS := 1000        # plafond de résultats affichés


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

	_render_folder_texture()   # 📁 en texture -> icône dossier échelonnable dans la grille


## Remplit la grille avec le contenu de `path`. Si `name_filter` est fourni, effectue une recherche
## RÉCURSIVE (dossier courant + sous-dossiers) par nom ; sinon liste simplement le dossier courant.
func populate(path: String, name_filter := "") -> void:
	clear()
	_index_by_path.clear()
	_baker.reset()
	_last_path = path
	_last_filter = name_filter
	var needle := name_filter.strip_edges().to_lower()

	var dirs: Array = []
	var files: Array = []
	_collect(path, needle, needle != "", dirs, files, [0])

	dirs.sort_custom(_cmp_name)          # dossiers d'abord, toujours par nom
	_sort_files(files)                   # modèles selon `sort_mode` (ordre croissant)
	if not sort_ascending:               # sens décroissant -> on inverse dossiers et modèles
		dirs.reverse()
		files.reverse()

	for d in dirs:
		var idx: int
		if _folder_tex != null:
			idx = add_item(d.name, _folder_tex)      # 📁 rendu en texture -> s'échelonne avec la taille
		else:
			idx = add_item("📁 " + d.name)           # repli tant que la texture n'est pas prête
		set_item_metadata(idx, {"type": "dir", "path": d.path})
		set_item_tooltip(idx, d.path)

	for f in files:
		var idx := add_item(f.name, _model_icon)
		set_item_metadata(idx, {"type": "file", "path": f.path})
		set_item_tooltip(idx, f.path)
		_index_by_path[f.path] = idx
		_baker.request(f.path)           # miniature 3D (async, remplace l'icône)

	entry_count = dirs.size() + files.size()
	if item_count == 0:
		var idx := add_item("(Aucun résultat)" if needle != "" else "(Aucun dossier ni modèle 3D ici)")
		set_item_disabled(idx, true)


## Récolte dossiers + modèles sous `path`. `recurse` = descend dans les sous-dossiers.
func _collect(path: String, needle: String, recurse: bool, dirs: Array, files: Array, scanned: Array) -> void:
	if scanned[0] > _MAX_SCAN_DIRS or files.size() >= _MAX_RESULTS:
		return
	scanned[0] += 1

	for f in DirAccess.get_files_at(path):
		if files.size() >= _MAX_RESULTS:
			break
		if not _is_model(f):
			continue
		if needle != "" and not (needle in f.to_lower()):
			continue
		var full := path.path_join(f)
		var entry := {name = f, path = full, size = 0, mtime = 0}
		if sort_mode == SORT_DATE:
			entry.mtime = FileAccess.get_modified_time(full)
		elif sort_mode == SORT_SIZE:
			var fa := FileAccess.open(full, FileAccess.READ)
			if fa != null:
				entry.size = fa.get_length()
				fa.close()
		files.append(entry)

	for d in DirAccess.get_directories_at(path):
		if d.begins_with("."):
			continue
		var sub := path.path_join(d)
		if needle == "" or (needle in d.to_lower()):
			dirs.append({name = d, path = sub})
		if recurse:
			_collect(sub, needle, true, dirs, files, scanned)


func _sort_files(arr: Array) -> void:
	match sort_mode:
		SORT_TYPE: arr.sort_custom(_cmp_type)
		SORT_SIZE: arr.sort_custom(_cmp_size)
		SORT_DATE: arr.sort_custom(_cmp_date)
		_: arr.sort_custom(_cmp_name)


func _cmp_name(a: Dictionary, b: Dictionary) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0

func _cmp_type(a: Dictionary, b: Dictionary) -> bool:
	var ea: String = a.name.get_extension().to_lower()
	var eb: String = b.name.get_extension().to_lower()
	if ea == eb:
		return a.name.naturalnocasecmp_to(b.name) < 0
	return ea < eb

func _cmp_size(a: Dictionary, b: Dictionary) -> bool:
	return a.size < b.size          # croissant ; l'inversion éventuelle est faite dans populate()

func _cmp_date(a: Dictionary, b: Dictionary) -> bool:
	return a.mtime < b.mtime        # croissant ; l'inversion éventuelle est faite dans populate()


## Change la taille des miniatures (px) et la largeur de colonne associée.
func set_thumb_size(px: int) -> void:
	fixed_icon_size = Vector2i(px, px)
	fixed_column_width = px * 2


## Rend le caractère 📁 dans une texture (une fois), pour que les dossiers de la grille s'affichent
## comme des icônes échelonnables via le menu Afficher.
func _render_folder_texture() -> void:
	_folder_tex = await _render_emoji("📁", 256)
	if is_inside_tree() and _last_path != "":
		populate(_last_path, _last_filter)   # ré-affiche le dossier courant avec l'icône


## Rend une chaîne (emoji) dans une texture carrée de `px` px, fond transparent.
func _render_emoji(emoji: String, px: int) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var lbl := Label.new()
	lbl.text = emoji
	lbl.add_theme_font_size_override("font_size", int(px * 0.72))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(lbl)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


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
