class_name ModelPreview
extends PanelContainer

## Volet droit : aperçu 3D interactif (orbite + zoom) d'un modèle glTF/GLB
## chargé à l'exécution.

var _sub_viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model_root: Node3D
var _header: Label
var _info_grid: GridContainer
var _placeholder: Label

# État de la caméra orbitale.
var _yaw := 0.6
var _pitch := -0.35
var _distance := 3.0
var _min_distance := 0.05
var _max_distance := 100.0
var _dragging := false


func _ready() -> void:
	custom_minimum_size = Vector2(320, 0)
	_build_ui()
	_update_camera()
	_show_placeholder(true)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	_header = Label.new()
	_header.text = "Aperçu"
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", 15)
	_header.clip_text = true
	vbox.add_child(_header)

	# Zone d'aperçu (le SubViewport + le placeholder se superposent).
	var area := Control.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(0, 240)
	area.clip_contents = true
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.gui_input.connect(_on_preview_input)
	vbox.add_child(area)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(vpc)

	_sub_viewport = SubViewport.new()
	_sub_viewport.transparent_bg = false
	_sub_viewport.own_world_3d = true          # monde isolé (aperçu ≠ miniatures)
	_sub_viewport.msaa_3d = Viewport.MSAA_4X
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_sub_viewport)

	_build_3d_rig()

	_placeholder = Label.new()
	_placeholder.text = "Sélectionnez un modèle\n.glb .gltf .fbx .obj"
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_placeholder.modulate = Color(1, 1, 1, 0.6)
	area.add_child(_placeholder)

	var hint := Label.new()
	hint.text = "Glisser : pivoter   •   Molette : zoomer"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.5)
	vbox.add_child(hint)

	# Tableau clé/valeur des informations du modèle.
	var info_wrap := MarginContainer.new()
	info_wrap.add_theme_constant_override("margin_left", 10)
	info_wrap.add_theme_constant_override("margin_right", 10)
	info_wrap.add_theme_constant_override("margin_top", 6)
	info_wrap.add_theme_constant_override("margin_bottom", 8)
	vbox.add_child(info_wrap)

	_info_grid = GridContainer.new()
	_info_grid.columns = 2
	_info_grid.custom_minimum_size = Vector2(0, 100)
	_info_grid.add_theme_constant_override("h_separation", 16)
	_info_grid.add_theme_constant_override("v_separation", 5)
	info_wrap.add_child(_info_grid)


func _build_3d_rig() -> void:
	var world := Node3D.new()
	_sub_viewport.add_child(world)

	var env := WorldEnvironment.new()
	env.environment = _make_environment()
	world.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -40, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 130, 0)
	fill.light_energy = 0.4
	world.add_child(fill)

	_pivot = Node3D.new()
	world.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.fov = 45.0
	_camera.current = true
	_pivot.add_child(_camera)

	_model_root = Node3D.new()
	world.add_child(_model_root)


func _make_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.11, 0.12, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.63, 0.68)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return e


## Charge et affiche le modèle situé à `path`.
func show_model(path: String) -> void:
	_clear_model()

	var scene := ModelLoader.load_scene(path)
	if scene == null:
		_set_error(path, "Impossible de charger ce fichier (format non supporté ou fichier invalide).")
		return

	_model_root.add_child(scene)
	_show_placeholder(false)
	_header.text = path.get_file()
	_frame_model(scene)
	_update_info(path, scene)


func _clear_model() -> void:
	for c in _model_root.get_children():
		_model_root.remove_child(c)
		c.queue_free()


## Cadre la caméra automatiquement sur la boîte englobante du modèle.
func _frame_model(scene: Node) -> void:
	var aabb := _compute_aabb(scene)
	var size := aabb.size
	var radius: float = maxf(size.length() * 0.5, 0.001)

	_pivot.position = aabb.position + size * 0.5   # cible = centre du modèle
	_distance = radius / tan(deg_to_rad(_camera.fov * 0.5)) * 1.25
	_min_distance = radius * 0.15
	_max_distance = radius * 12.0
	_camera.near = clampf(radius * 0.01, 0.001, 1.0)
	_camera.far = (_distance + radius) * 6.0
	_yaw = 0.6
	_pitch = -0.35
	_update_camera()


func _compute_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for vi in _gather_visuals(node):
		var box: AABB = vi.global_transform * vi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


func _gather_visuals(node: Node, acc: Array = []) -> Array:
	if node is VisualInstance3D:
		acc.append(node)
	for child in node.get_children():
		_gather_visuals(child, acc)
	return acc


func _update_info(path: String, scene: Node) -> void:
	var meshes := 0
	var vertices := 0
	for vi in _gather_visuals(scene):
		if vi is MeshInstance3D and vi.mesh != null:
			meshes += 1
			for s in vi.mesh.get_surface_count():
				var arr: Array = vi.mesh.surface_get_arrays(s)
				if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
					vertices += arr[Mesh.ARRAY_VERTEX].size()

	var aabb := _compute_aabb(scene)
	var dims := aabb.size

	_clear_info()
	_add_info_row("Taille", _human_size(_file_size(path)))
	_add_info_row("Maillages", str(meshes))
	_add_info_row("Sommets", _thousands(vertices))
	_add_info_row("Largeur", "%.3f" % dims.x)
	_add_info_row("Hauteur", "%.3f" % dims.y)
	_add_info_row("Profondeur", "%.3f" % dims.z)


## Construit une ligne « clé / valeur » du tableau d'informations.
func _add_info_row(key: String, value: String, value_color := Color.WHITE) -> void:
	var k := Label.new()
	k.text = key
	k.modulate = Color(1, 1, 1, 0.55)
	_info_grid.add_child(k)

	var v := Label.new()
	v.text = value
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if value_color != Color.WHITE:
		v.modulate = value_color
	_info_grid.add_child(v)


func _clear_info() -> void:
	for c in _info_grid.get_children():
		_info_grid.remove_child(c)
		c.queue_free()


func _set_error(path: String, message: String) -> void:
	_header.text = "⚠ " + path.get_file()
	_clear_info()
	_add_info_row("Erreur", message, Color(1.0, 0.42, 0.42))
	_show_placeholder(false)


func _show_placeholder(visible_: bool) -> void:
	_placeholder.visible = visible_
	if visible_:
		_header.text = "Aperçu"
		_clear_info()


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var length := f.get_length()
	f.close()
	return length


func _human_size(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.1f Mo" % (bytes / 1048576.0)
	if bytes >= 1024:
		return "%.1f Ko" % (bytes / 1024.0)
	return "%d o" % bytes


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out


# --- Caméra orbitale ---------------------------------------------------------

func _update_camera() -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, _distance)
	_camera.rotation = Vector3.ZERO


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_distance = clampf(_distance * 0.9, _min_distance, _max_distance)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_distance = clampf(_distance * 1.1, _min_distance, _max_distance)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch - event.relative.y * 0.01, -1.5, 1.5)
		_update_camera()
