class_name ThumbnailBaker
extends Node

## Génère (« brûle ») des miniatures 3D des modèles glTF/GLB via un SubViewport
## hors-écran, en file d'attente asynchrone, avec cache mémoire + disque.

signal thumbnail_ready(path: String, texture: Texture2D)

const SIZE := 128
const CACHE_DIR := "user://thumbnails"

var _queue: Array[String] = []
var _busy := false
var _cache := {}                # clé -> Texture2D (mémoire)

var _sub_viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model_root: Node3D


func _ready() -> void:
	_ensure_rig()


func _ensure_rig() -> void:
	if _sub_viewport != null:
		return
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(SIZE, SIZE)
	_sub_viewport.transparent_bg = true
	_sub_viewport.own_world_3d = true          # monde isolé (n'interfère pas avec l'aperçu)
	_sub_viewport.msaa_3d = Viewport.MSAA_4X
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sub_viewport)

	var world := Node3D.new()
	_sub_viewport.add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.65, 0.68, 0.72)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -40, 0)
	key.light_energy = 1.3
	world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 130, 0)
	fill.light_energy = 0.4
	world.add_child(fill)

	_pivot = Node3D.new()
	world.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.current = true
	_pivot.add_child(_camera)

	_model_root = Node3D.new()
	world.add_child(_model_root)


## Demande la miniature de `path`. Émet `thumbnail_ready` immédiatement si en
## cache (mémoire ou disque), sinon met en file d'attente.
func request(path: String) -> void:
	var key := _key(path)
	if _cache.has(key):
		thumbnail_ready.emit(path, _cache[key])
		return

	var disk := _disk_path(path)
	if FileAccess.file_exists(disk):
		var img := Image.load_from_file(disk)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_cache[key] = tex
			thumbnail_ready.emit(path, tex)
			return

	if not _queue.has(path):
		_queue.append(path)
	_process_queue()


## Vide la file d'attente (à l'ouverture d'un nouveau dossier).
func reset() -> void:
	_queue.clear()


func _process_queue() -> void:
	if _busy:
		return
	_busy = true
	while not _queue.is_empty():
		var path: String = _queue.pop_front()
		var tex: Texture2D = await _bake(path)
		if tex != null:
			_cache[_key(path)] = tex
			thumbnail_ready.emit(path, tex)
	_busy = false


func _bake(path: String) -> Texture2D:
	_ensure_rig()
	for c in _model_root.get_children():
		_model_root.remove_child(c)
		c.queue_free()

	var scene := ModelLoader.load_scene(path)
	if scene == null:
		return null

	_model_root.add_child(scene)
	_frame(scene)

	await get_tree().process_frame            # laisse la scène se stabiliser
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var img := _sub_viewport.get_texture().get_image()

	_model_root.remove_child(scene)
	scene.queue_free()

	if img == null or img.is_empty():
		return null
	img.save_png(_disk_path(path))            # « brûle » sur disque
	return ImageTexture.create_from_image(img)


## Cadre la caméra sur le modèle avec un angle 3/4.
func _frame(scene: Node) -> void:
	var aabb := _compute_aabb(scene)
	var size := aabb.size
	var radius: float = maxf(size.length() * 0.5, 0.001)

	_pivot.position = aabb.position + size * 0.5
	_pivot.rotation = Vector3(deg_to_rad(-25.0), deg_to_rad(35.0), 0.0)
	var dist := radius / tan(deg_to_rad(_camera.fov * 0.5)) * 1.15
	_camera.position = Vector3(0.0, 0.0, dist)
	_camera.near = clampf(radius * 0.01, 0.001, 1.0)
	_camera.far = (dist + radius) * 6.0


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


func _key(path: String) -> String:
	return "%d_%d" % [hash(path), FileAccess.get_modified_time(path)]


func _disk_path(path: String) -> String:
	return "%s/%s.png" % [CACHE_DIR, _key(path)]
