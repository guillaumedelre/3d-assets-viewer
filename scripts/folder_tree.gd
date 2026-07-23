class_name FolderTree
extends Tree

## Volet de navigation gauche : arbre de dossiers rempli paresseusement
## (un niveau à la fois) pour éviter de scanner tout le disque.

signal folder_selected(path: String)

var _folder_icon: Texture2D
var _home_icon: Texture2D
var _disk_icon: Texture2D
var _network_icon: Texture2D
var _drive_items := {}          # "X:" -> TreeItem (pour marquer les lecteurs réseau après coup)


func _ready() -> void:
	hide_root = true
	columns = 1
	allow_reselect = true
	_folder_icon = _load_icon("res://icons/folder.svg")
	_home_icon = _load_icon("res://icons/home.svg")
	_disk_icon = _load_icon("res://icons/disk.svg")
	_network_icon = _load_icon("res://icons/network.svg")
	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)
	item_collapsed.connect(_on_item_collapsed)


## (Re)construit les racines : Accueil + lecteurs Windows disponibles.
func build_roots() -> void:
	clear()
	_drive_items.clear()
	var root := create_item()

	var home := OS.get_environment("USERPROFILE")
	if home != "" and DirAccess.dir_exists_absolute(home):
		_add_folder_item(root, "Accueil", home.replace("\\", "/"), _home_icon)

	for i in range(26):
		var letter := char("A".unicode_at(0) + i)
		var drive := "%s:/" % letter
		if DirAccess.dir_exists_absolute(drive):
			_drive_items[letter + ":"] = _add_folder_item(root, drive, drive, _disk_icon)

	# Distingue les lecteurs réseau (différé pour ne pas retarder l'affichage initial).
	_mark_network_drives.call_deferred()


## Marque d'une icône « réseau » les lecteurs distants (Windows, DriveType=4).
func _mark_network_drives() -> void:
	for dev in _query_network_drives():
		if _drive_items.has(dev):
			var item: TreeItem = _drive_items[dev]
			if _network_icon != null:
				item.set_icon(0, _network_icon)
			item.set_text(0, "%s/  (réseau)" % dev)


## Lettres des lecteurs réseau (ex. ["Z:", "Y:"]), via PowerShell. Vide hors Windows / en cas d'échec.
func _query_network_drives() -> PackedStringArray:
	var res := PackedStringArray()
	if OS.get_name() != "Windows":
		return res
	var out := []
	var code := OS.execute("powershell", [
		"-NoProfile", "-NonInteractive", "-Command",
		"Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=4' | ForEach-Object { $_.DeviceID }"
	], out, false)
	if code == 0 and out.size() > 0:
		for line in String(out[0]).split("\n", false):
			var dev := line.strip_edges().to_upper()
			if dev.length() == 2 and dev.ends_with(":"):
				res.append(dev)
	return res


func _add_folder_item(parent: TreeItem, text: String, path: String, icon: Texture2D = null) -> TreeItem:
	var item := create_item(parent)
	item.set_metadata(0, path)
	item.set_meta("loaded", false)
	if icon != null:
		# Racine spéciale (Accueil, lecteur) : on garde son icône.
		item.set_text(0, text)
		item.set_icon(0, icon)
		item.set_icon_max_width(0, 18)
	else:
		# Dossier : caractère 📁 (fermé) / 📂 (ouvert) au lieu d'une icône.
		item.set_meta("is_folder", true)
		item.set_meta("fname", text)
		item.set_text(0, "📁 " + text)
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


## Met à jour le caractère d'un dossier selon qu'il est ouvert (📂) ou fermé (📁).
func _update_folder_glyph(item: TreeItem) -> void:
	if not item.get_meta("is_folder", false):
		return
	var glyph := "📂 " if not item.collapsed else "📁 "
	item.set_text(0, glyph + str(item.get_meta("fname", "")))


func _on_item_collapsed(item: TreeItem) -> void:
	_update_folder_glyph(item)
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
	_update_folder_glyph(item)
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


## Déplie l'arbre jusqu'à `path` (chargement synchrone des ancêtres) puis le sélectionne / le montre.
## Utilisé pour que l'arbre « suive » la navigation faite ailleurs (grille, chemin, historique).
func reveal_path(path: String) -> void:
	var norm := path.replace("\\", "/")
	if norm.length() < 3 or norm.substr(1, 2) != ":/":
		return
	var drive := norm.substr(0, 3)                     # "X:/"
	var item := _child_with_path(get_root(), drive)
	if item == null:
		return

	var rest := norm.substr(3).trim_suffix("/")        # ex. "Users/gdelr/Documents"
	var acc := drive                                   # "X:/"
	if rest != "":
		for seg in rest.split("/", false):
			_ensure_children_loaded(item)
			item.set_collapsed(false)
			_update_folder_glyph(item)                 # ancêtre déplié -> 📂
			acc = acc.path_join(seg)
			var child := _child_with_path(item, acc)
			if child == null:
				break                                  # dossier inaccessible -> on s'arrête là
			item = child

	set_selected(item, 0)
	scroll_to_item(item)


func _ensure_children_loaded(item: TreeItem) -> void:
	if item.get_meta("loaded", false):
		return
	item.set_meta("loaded", true)
	_populate_children(item)


func _child_with_path(parent: TreeItem, path: String) -> TreeItem:
	for child in parent.get_children():
		if child.get_metadata(0) == path:
			return child
	return null


func _load_icon(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var t := load(res_path)
		if t is Texture2D:
			return t
	return null
