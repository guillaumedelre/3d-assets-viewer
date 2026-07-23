extends Control

## Fenêtre principale façon explorateur Windows :
## barre d'outils + arbre de dossiers (gauche) + grille (centre) + aperçu 3D (droite).

var _tree: FolderTree
var _grid: AssetGrid
var _preview: ModelPreview
var _path_edit: LineEdit
var _search_edit: LineEdit
var _search_timer: Timer
var _back_btn: Button
var _fwd_btn: Button
var _up_btn: Button
var _file_dialog: FileDialog
var _status_label: Label
var _count_label: Label
var _sort_menu: MenuButton
var _view_menu: MenuButton
var _details: AssetDetails
var _view_is_details := false

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
	# Marge uniforme haut/gauche/droite = `separation` (identique à l'écart entre boutons et à
	# l'écart barre d'outils <-> grille). L'écart fenêtre -> contenu est ainsi le même partout :
	# au-dessus de la barre de chemin, à gauche du 1er bouton, et après le bouton d'aperçu.
	var pad := vbox.get_theme_constant("separation")
	vbox.offset_top = pad
	vbox.offset_left = pad
	vbox.offset_right = -pad

	# --- Barre d'action (haut) : ouvrir un dossier (gauche) | afficher/masquer l'aperçu (droite) ---
	var actionbar := HBoxContainer.new()
	actionbar.add_theme_constant_override("separation", 4)
	vbox.add_child(actionbar)

	var open_btn := Button.new()
	open_btn.text = "📂"
	open_btn.tooltip_text = "Ouvrir un dossier…"
	open_btn.pressed.connect(_open_folder_dialog)
	actionbar.add_child(open_btn)

	var explorer_btn := Button.new()
	explorer_btn.tooltip_text = "Ouvrir le dossier dans l'Explorateur Windows"
	var win_icon := _load_button_icon("res://icons/windows.svg")
	if win_icon != null:
		explorer_btn.icon = win_icon
		explorer_btn.add_theme_constant_override("icon_max_width", 18)
	else:
		explorer_btn.text = "Explorateur"
	explorer_btn.pressed.connect(_open_in_explorer)
	actionbar.add_child(explorer_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	actionbar.add_child(spacer)

	# Bouton « Trier » : champ (Nom/Type/Taille/Date) + sens (Croissant/Décroissant), en radio.
	_sort_menu = MenuButton.new()
	_sort_menu.flat = false
	_sort_menu.tooltip_text = "Trier"
	var sort_icon := _load_button_icon("res://icons/sort.svg")
	if sort_icon != null:
		_sort_menu.icon = sort_icon
		_sort_menu.add_theme_constant_override("icon_max_width", 18)
	else:
		_sort_menu.text = "Trier"
	var sp := _sort_menu.get_popup()
	sp.add_radio_check_item("Nom", 0)
	sp.add_radio_check_item("Type", 1)
	sp.add_radio_check_item("Taille", 2)
	sp.add_radio_check_item("Date", 3)
	sp.add_separator()
	sp.add_radio_check_item("Croissant", 10)
	sp.add_radio_check_item("Décroissant", 11)
	sp.set_item_checked(sp.get_item_index(0), true)    # Nom
	sp.set_item_checked(sp.get_item_index(10), true)   # Croissant
	sp.id_pressed.connect(_on_sort_menu)
	actionbar.add_child(_sort_menu)

	# Bouton « Afficher » : taille des miniatures (4 tailles façon Explorateur), en radio.
	_view_menu = MenuButton.new()
	_view_menu.flat = false
	_view_menu.tooltip_text = "Afficher"
	var view_icon := _load_button_icon("res://icons/view.svg")
	if view_icon != null:
		_view_menu.icon = view_icon
		_view_menu.add_theme_constant_override("icon_max_width", 18)
	else:
		_view_menu.text = "Afficher"
	var vp := _view_menu.get_popup()
	vp.add_radio_check_item("Très grandes icônes", 0)
	vp.add_radio_check_item("Grandes icônes", 1)
	vp.add_radio_check_item("Icônes moyennes", 2)
	vp.add_radio_check_item("Petites icônes", 3)
	vp.add_separator()
	vp.add_radio_check_item("Détails", 10)
	vp.set_item_checked(vp.get_item_index(2), true)    # Moyennes par défaut
	vp.id_pressed.connect(_on_view_menu)
	actionbar.add_child(_view_menu)

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = true
	toggle.tooltip_text = "Afficher / masquer l'aperçu"
	toggle.add_theme_constant_override("icon_max_width", 18)
	var toggle_icon := _load_button_icon("res://icons/preview.svg")
	if toggle_icon != null:
		toggle.icon = toggle_icon
	else:
		toggle.text = "▧"
	toggle.toggled.connect(_on_toggle_preview)
	actionbar.add_child(toggle)

	# --- Barre de navigation : précédent/suivant/parent | chemin | recherche ---
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

	var refresh_btn := _make_tool_button("⟳", "Actualiser (re-scanner le dossier)")
	refresh_btn.pressed.connect(_refresh)
	toolbar.add_child(refresh_btn)

	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_path_edit.placeholder_text = "Chemin du dossier…"
	_path_edit.text_submitted.connect(_on_path_submitted)
	toolbar.add_child(_path_edit)

	var copy_btn := _make_tool_button("📋", "Copier le chemin du dossier courant")
	copy_btn.pressed.connect(_copy_path)
	toolbar.add_child(copy_btn)

	_search_edit = LineEdit.new()
	_search_edit.custom_minimum_size = Vector2(240, 0)
	_search_edit.placeholder_text = "🔍 Rechercher dans ce dossier…"
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_edit)

	# Débounce : on lance la recherche (récursive) 250 ms après la dernière frappe.
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.25
	_search_timer.timeout.connect(_apply_search)
	add_child(_search_timer)

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

	# Volet central : grille et vue Détails empilées (une seule visible), à gauche de l'aperçu.
	var center := MarginContainer.new()
	center.custom_minimum_size = Vector2(280, 0)
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	hsplit2.add_child(center)

	_grid = AssetGrid.new()
	_grid.folder_activated.connect(navigate_to.bind(true))
	_grid.file_selected.connect(_on_file_selected)
	_grid.file_activated.connect(_on_file_selected)
	center.add_child(_grid)

	_details = AssetDetails.new()
	_details.visible = false
	_details.folder_activated.connect(navigate_to.bind(true))
	_details.file_selected.connect(_on_file_selected)
	_details.file_activated.connect(_on_file_selected)
	_details.sort_requested.connect(_on_details_sort)
	center.add_child(_details)

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
	_search_timer.stop()
	_search_edit.text = ""      # nouvelle navigation -> recherche remise à zéro (ne ré-émet pas text_changed)
	_path_edit.text = path
	_status_label.text = path
	_populate_view()
	_tree.reveal_path(path)     # l'arbre de gauche suit la navigation

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
	if path == _current:
		return               # sélection provoquée par reveal_path (déjà sur ce dossier) -> pas de boucle
	navigate_to(path)


func _on_file_selected(path: String) -> void:
	_preview.show_model(path)
	_status_label.text = path


func _on_path_submitted(text: String) -> void:
	navigate_to(text)


func _on_search_changed(_text: String) -> void:
	_search_timer.start()   # (re)lance le débounce ; _apply_search fera la recherche


func _apply_search() -> void:
	# Recherche récursive dans le dossier courant (dossiers + modèles), en direct.
	_populate_view()


func _refresh() -> void:
	_populate_view()


## Peuple la vue active (grille ou Détails) avec le dossier + recherche courants.
func _populate_view() -> void:
	if _view_is_details:
		_details.populate(_current, _search_edit.text, _grid.sort_mode, _grid.sort_ascending)
		_count_label.text = _format_count(_details.entry_count)
	else:
		_grid.populate(_current, _search_edit.text)
		_count_label.text = _format_count(_grid.entry_count)


func _open_in_explorer() -> void:
	if DirAccess.dir_exists_absolute(_current):
		OS.shell_open(_current)


func _copy_path() -> void:
	DisplayServer.clipboard_set(_current)
	_status_label.text = "Chemin copié : " + _current


func _on_sort_menu(id: int) -> void:
	if id < 10:                        # champ de tri (0..3)
		_grid.sort_mode = id
	else:                              # sens (10 = croissant, 11 = décroissant)
		_grid.sort_ascending = (id == 10)
	_sync_sort_menu()
	_refresh()


## Reflète l'état de tri courant (_grid.sort_mode / sort_ascending) dans les coches du menu Trier.
func _sync_sort_menu() -> void:
	var sp := _sort_menu.get_popup()
	for fid in [0, 1, 2, 3]:
		sp.set_item_checked(sp.get_item_index(fid), fid == _grid.sort_mode)
	sp.set_item_checked(sp.get_item_index(10), _grid.sort_ascending)
	sp.set_item_checked(sp.get_item_index(11), not _grid.sort_ascending)


## Tri déclenché par un clic sur un en-tête de colonne de la vue Détails.
func _on_details_sort(mode: int, ascending: bool) -> void:
	_grid.sort_mode = mode
	_grid.sort_ascending = ascending
	_sync_sort_menu()
	_refresh()


func _on_view_menu(id: int) -> void:
	var vp := _view_menu.get_popup()
	if id == 10:                       # vue Détails (tableau)
		if not _view_is_details:
			_view_is_details = true
			_grid.visible = false
			_details.visible = true
		_populate_view()
	else:                              # vue icônes (taille)
		_grid.set_thumb_size([128, 96, 64, 48][id])
		if _view_is_details:
			_view_is_details = false
			_details.visible = false
			_grid.visible = true
			_populate_view()
	for i in [0, 1, 2, 3, 10]:
		vp.set_item_checked(vp.get_item_index(i), i == id)


func _open_folder_dialog() -> void:
	if DirAccess.dir_exists_absolute(_current):
		_file_dialog.current_dir = _current
	_file_dialog.popup_centered(Vector2i(900, 640))


func _on_dir_chosen(dir: String) -> void:
	navigate_to(dir)
