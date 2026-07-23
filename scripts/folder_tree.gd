class_name FolderTree
extends Tree

## Volet de navigation gauche : arbre de dossiers rempli paresseusement
## (un niveau à la fois) pour éviter de scanner tout le disque.

signal folder_selected(path: String)

var _folder_icon: Texture2D
var _home_icon: Texture2D
var _disk_icon: Texture2D


func _ready() -> void:
	hide_root = true
	columns = 1
	allow_reselect = true
	_folder_icon = _load_icon("res://icons/folder.svg")
	_home_icon = _load_icon("res://icons/home.svg")
	_disk_icon = _load_icon("res://icons/disk.svg")
	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)
	item_collapsed.connect(_on_item_collapsed)


## (Re)construit les racines : Accueil + lecteurs Windows disponibles.
func build_roots() -> void:
	clear()
	var root := create_item()

	var home := OS.get_environment("USERPROFILE")
	if home != "" and DirAccess.dir_exists_absolute(home):
		_add_folder_item(root, "Accueil", home.replace("\\", "/"), _home_icon)

	for i in range(26):
		var drive := "%s:/" % char("A".unicode_at(0) + i)
		if DirAccess.dir_exists_absolute(drive):
			_add_folder_item(root, drive, drive, _disk_icon)


func _add_folder_item(parent: TreeItem, text: String, path: String, icon: Texture2D = null) -> TreeItem:
	var item := create_item(parent)
	item.set_text(0, text)
	var ic: Texture2D = icon if icon != null else _folder_icon
	if ic != null:
		item.set_icon(0, ic)
		item.set_icon_max_width(0, 18)
	item.set_metadata(0, path)
	item.set_meta("loaded", false)
	# Un enfant placeholder fait apparaître la flèche de dépliage.
	if _has_subdirs(path):
		item.set_collapsed(true)
		var placeholder := create_item(item)
		placeholder.set_text(0, "…")
		placeholder.set_selectable(0, false)
	return item


func _has_subdirs(path: String) -> bool:
	for d in DirAccess.get_directories_at(path):
		if not d.begins_with("."):
			return true
	return false


func _on_item_collapsed(item: TreeItem) -> void:
	if item.collapsed:
		return
	if item.get_meta("loaded", false):
		return
	item.set_meta("loaded", true)
	# La création d'items est interdite pendant l'émission du signal
	# (l'arbre est « bloqué ») : on diffère le remplissage à la frame suivante.
	_populate_children.call_deferred(item)


func _populate_children(item: TreeItem) -> void:
	# Retire le placeholder puis insère les vrais sous-dossiers.
	for child in item.get_children():
		child.free()

	var path: String = item.get_metadata(0)
	var dirs := DirAccess.get_directories_at(path)
	dirs.sort()
	for d in dirs:
		if d.begins_with("."):
			continue
		_add_folder_item(item, d, path.path_join(d))


func _on_item_selected() -> void:
	var item := get_selected()
	if item == null:
		return
	var path = item.get_metadata(0)
	if path is String:
		folder_selected.emit(path)


## Double-clic (ou Entrée) : déplie / replie le dossier.
func _on_item_activated() -> void:
	var item := get_selected()
	if item == null:
		return
	item.set_collapsed(not item.collapsed)
	# Assure le remplissage au dépliage si le signal item_collapsed ne l'a pas fait.
	if not item.collapsed and not item.get_meta("loaded", false):
		item.set_meta("loaded", true)
		_populate_children.call_deferred(item)


## Sélectionne (sans réémettre) l'item correspondant à `path` s'il est visible.
func select_path(path: String) -> void:
	var item := _find_item(get_root(), path)
	if item != null:
		set_selected(item, 0)


func _find_item(from: TreeItem, path: String) -> TreeItem:
	if from == null:
		return null
	for child in from.get_children():
		if child.get_metadata(0) == path:
			return child
		var found := _find_item(child, path)
		if found != null:
			return found
	return null


func _load_icon(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var t := load(res_path)
		if t is Texture2D:
			return t
	return null
