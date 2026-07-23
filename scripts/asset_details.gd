class_name AssetDetails
extends Tree

## Vue « Détails » du volet central : tableau façon Explorateur (Nom / Modifié le / Type / Taille),
## avec une miniature en tête de chaque ligne et des en-têtes de colonnes cliquables pour trier.

signal folder_activated(path: String)   # double-clic / Entrée sur un dossier
signal file_selected(path: String)      # clic simple sur un fichier
signal file_activated(path: String)     # double-clic / Entrée sur un fichier
signal sort_requested(mode: int, ascending: bool)   # clic sur un en-tête de colonne

var entry_count := 0

var _baker: ThumbnailBaker
var _folder_tex: Texture2D        # 📁 rendu en texture (icône dossier)
var _index_by_path := {}          # chemin -> TreeItem (pour poser la miniature à son arrivée)
var _sort_mode := ModelScan.SORT_NAME
var _sort_ascending := true
var _last := {}                   # derniers paramètres de populate (ré-affichage quand 📁 est prêt)

# Correspondance colonne -> critère de tri, et libellés des colonnes.
var _cols := {0: ModelScan.SORT_NAME, 1: ModelScan.SORT_DATE, 2: ModelScan.SORT_TYPE, 3: ModelScan.SORT_SIZE}
var _names := {0: "Nom", 1: "Modifié le", 2: "Type", 3: "Taille"}


func _ready() -> void:
	columns = 4
	column_titles_visible = true
	hide_root = true
	select_mode = Tree.SELECT_ROW
	allow_reselect = true
	set_column_expand(0, true)
	set_column_expand(1, false)
	set_column_expand(2, false)
	set_column_expand(3, false)
	set_column_custom_minimum_width(1, 150)
	set_column_custom_minimum_width(2, 80)
	set_column_custom_minimum_width(3, 90)
	_update_column_titles()

	_baker = ThumbnailBaker.new()
	add_child(_baker)
	_baker.thumbnail_ready.connect(_on_thumbnail_ready)

	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)
	column_title_clicked.connect(_on_column_title_clicked)

	_render_folder_texture()   # 📁 en texture pour l'icône des dossiers


func populate(path: String, name_filter: String, sort_mode: int, ascending: bool) -> void:
	clear()
	_index_by_path.clear()
	_baker.reset()
	_sort_mode = sort_mode
	_sort_ascending = ascending
	_last = {path = path, filter = name_filter, mode = sort_mode, asc = ascending}
	_update_column_titles()

	var root := create_item()
	var data := ModelScan.collect(path, name_filter, sort_mode, ascending)

	for d in data.dirs:
		var it := create_item(root)
		it.set_text(0, str(d.name))
		it.set_text(2, "Dossier")
		if _folder_tex != null:
			it.set_icon(0, _folder_tex)
		it.set_icon_max_width(0, 22)
		it.set_metadata(0, {"type": "dir", "path": d.path})

	for f in data.files:
		var it := create_item(root)
		it.set_text(0, str(f.name))
		it.set_text(1, _human_date(f.mtime))
		it.set_text(2, str(f.name).get_extension().to_upper())
		it.set_text(3, _human_size(f.size))
		it.set_icon_max_width(0, 22)
		it.set_tooltip_text(0, str(f.path))
		it.set_metadata(0, {"type": "file", "path": f.path})
		_index_by_path[f.path] = it
		_baker.request(f.path)          # miniature 3D (async)

	entry_count = data.dirs.size() + data.files.size()
	if entry_count == 0:
		var it := create_item(root)
		it.set_text(0, "(Aucun résultat)" if name_filter.strip_edges() != "" else "(Aucun dossier ni modèle 3D ici)")
		it.set_selectable(0, false)


func _on_thumbnail_ready(path: String, texture: Texture2D) -> void:
	if _index_by_path.has(path):
		var it: TreeItem = _index_by_path[path]
		if is_instance_valid(it):
			it.set_icon(0, texture)
			it.set_icon_max_width(0, 22)


## Clic sur un en-tête : trie par cette colonne (croissant), re-clic sur la même colonne = décroissant.
func _on_column_title_clicked(column: int, _mouse_button: int) -> void:
	if not _cols.has(column):
		return
	var field: int = _cols[column]
	var asc := true
	if field == _sort_mode:
		asc = not _sort_ascending
	sort_requested.emit(field, asc)


## Affiche ▲ / ▼ sur la colonne de tri active.
func _update_column_titles() -> void:
	var arrow := "  ▲" if _sort_ascending else "  ▼"
	for col in _names:
		var title: String = _names[col]
		if _cols[col] == _sort_mode:
			title += arrow
		set_column_title(col, title)


func _human_size(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.1f Mo" % (bytes / 1048576.0)
	if bytes >= 1024:
		return "%.0f Ko" % (bytes / 1024.0)
	return "%d o" % bytes


func _human_date(unix: int) -> String:
	if unix <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]


func _on_item_selected() -> void:
	var it := get_selected()
	if it == null:
		return
	var meta = it.get_metadata(0)
	if meta is Dictionary and meta.get("type") == "file":
		file_selected.emit(meta["path"])


func _on_item_activated() -> void:
	var it := get_selected()
	if it == null:
		return
	var meta = it.get_metadata(0)
	if not (meta is Dictionary):
		return
	if meta.get("type") == "dir":
		folder_activated.emit(meta["path"])
	elif meta.get("type") == "file":
		file_activated.emit(meta["path"])


## Rend le caractère 📁 dans une texture (une fois), pour l'icône des dossiers.
func _render_folder_texture() -> void:
	_folder_tex = await _render_emoji("📁", 128)
	if is_inside_tree() and not _last.is_empty():
		populate(_last.path, _last.filter, _last.mode, _last.asc)


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
