extends Control

## Fenêtre principale façon explorateur Windows :
## barre d'outils + arbre de dossiers (gauche) + grille (centre) + aperçu 3D (droite).

var _tree: FolderTree
var _grid: AssetGrid
var _preview: ModelPreview
var _path_edit: LineEdit
var _back_btn: Button
var _fwd_btn: Button
var _up_btn: Button
var _file_dialog: FileDialog
var _status_label: Label
var _count_label: Label

var _current := ""
var _history: Array[String] = []
var _hist_index := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_tree.build_roots()

	var start := OS.get_environment("USERPROFILE").replace("\\", "/")
	if start == "" or not DirAccess.dir_exists_absolute(start):
		start = "C:/"
	navigate_to(start)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(vbox)

	# --- Barre d'outils ---
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	vbox.add_child(toolbar)

	_back_btn = _make_tool_button("◀", "Précédent")
	_back_btn.pressed.connect(_go_back)
	toolbar.add_child(_back_btn)

	_fwd_btn = _make_tool_button("▶", "Suivant")
	_fwd_btn.pressed.connect(_go_forward)
	toolbar.add_child(_fwd_btn)

	_up_btn = _make_tool_button("▲", "Dossier parent")
	_up_btn.pressed.connect(_go_up)
	toolbar.add_child(_up_btn)

	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_path_edit.placeholder_text = "Chemin du dossier…"
	_path_edit.text_submitted.connect(_on_path_submitted)
	toolbar.add_child(_path_edit)

	var open_btn := Button.new()
	open_btn.text = "Ouvrir un dossier…"
	open_btn.pressed.connect(_open_folder_dialog)
	toolbar.add_child(open_btn)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = true
	toggle.tooltip_text = "Afficher / masquer l'aperçu"
	toggle.custom_minimum_size = Vector2(38, 0)
	toggle.add_theme_constant_override("icon_max_width", 18)
	var icon := _load_button_icon("res://icons/preview.svg")
	if icon != null:
		toggle.icon = icon
	else:
		toggle.text = "▧"
	toggle.toggled.connect(_on_toggle_preview)
	toolbar.add_child(toggle)

	# --- Zone principale : arbre | (grille | aperçu) ---
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_horizontal = SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = SIZE_EXPAND_FILL
	hsplit.split_offset = 220
	vbox.add_child(hsplit)

	_tree = FolderTree.new()
	_tree.custom_minimum_size = Vector2(180, 0)
	_tree.folder_selected.connect(_on_tree_folder_selected)
	hsplit.add_child(_tree)

	var hsplit2 := HSplitContainer.new()
	hsplit2.size_flags_horizontal = SIZE_EXPAND_FILL
	hsplit2.split_offset = 620
	hsplit.add_child(hsplit2)

	_grid = AssetGrid.new()
	_grid.custom_minimum_size = Vector2(280, 0)
	_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_grid.folder_activated.connect(navigate_to.bind(true))
	_grid.file_selected.connect(_on_file_selected)
	_grid.file_activated.connect(_on_file_selected)
	hsplit2.add_child(_grid)

	_preview = ModelPreview.new()
	hsplit2.add_child(_preview)

	# --- Barre de statut (bas) : chemin | nombre d'éléments | version ---
	vbox.add_child(HSeparator.new())

	var statusbar := HBoxContainer.new()
	statusbar.add_theme_constant_override("separation", 8)
	vbox.add_child(statusbar)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_status_label.clip_text = true
	_status_label.text = "Prêt"
	statusbar.add_child(_status_label)

	statusbar.add_child(VSeparator.new())

	_count_label = Label.new()
	_count_label.custom_minimum_size = Vector2(120, 0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.tooltip_text = "Nombre de dossiers et modèles dans le dossier courant"
	statusbar.add_child(_count_label)

	statusbar.add_child(VSeparator.new())

	var version_label := Label.new()
	version_label.text = "v" + AppVersion.VERSION
	version_label.tooltip_text = "Version de l'application"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	statusbar.add_child(version_label)

	# --- Sélecteur de dossier natif ---
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.title = "Choisir un dossier à explorer"
	_file_dialog.dir_selected.connect(_on_dir_chosen)
	add_child(_file_dialog)


func _make_tool_button(text: String, tooltip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(38, 0)
	return b


func _load_button_icon(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var t := load(res_path)
		if t is Texture2D:
			return t
	return null


func _on_toggle_preview(shown: bool) -> void:
	_preview.visible = shown


# --- Navigation --------------------------------------------------------------

func navigate_to(path: String, record := true) -> void:
	path = path.replace("\\", "/")
	if not DirAccess.dir_exists_absolute(path):
		return

	_current = path
	_grid.populate(path)
	_path_edit.text = path
	_status_label.text = path
	_count_label.text = _format_count(_grid.entry_count)

	if record:
		if _hist_index < _history.size() - 1:
			_history = _history.slice(0, _hist_index + 1)
		_history.append(path)
		_hist_index = _history.size() - 1

	_update_nav_buttons()


func _go_back() -> void:
	if _hist_index > 0:
		_hist_index -= 1
		navigate_to(_history[_hist_index], false)


func _go_forward() -> void:
	if _hist_index < _history.size() - 1:
		_hist_index += 1
		navigate_to(_history[_hist_index], false)


func _go_up() -> void:
	var parent := _current.get_base_dir()
	if parent != "" and parent != _current:
		navigate_to(parent)


func _update_nav_buttons() -> void:
	_back_btn.disabled = _hist_index <= 0
	_fwd_btn.disabled = _hist_index >= _history.size() - 1
	var parent := _current.get_base_dir()
	_up_btn.disabled = parent == "" or parent == _current


func _format_count(n: int) -> String:
	if n == 0:
		return "Aucun élément"
	if n == 1:
		return "1 élément"
	return "%d éléments" % n


# --- Signaux -----------------------------------------------------------------

func _on_tree_folder_selected(path: String) -> void:
	navigate_to(path)


func _on_file_selected(path: String) -> void:
	_preview.show_model(path)
	_status_label.text = path


func _on_path_submitted(text: String) -> void:
	navigate_to(text)


func _open_folder_dialog() -> void:
	if DirAccess.dir_exists_absolute(_current):
		_file_dialog.current_dir = _current
	_file_dialog.popup_centered(Vector2i(900, 640))


func _on_dir_chosen(dir: String) -> void:
	navigate_to(dir)
