extends GdUnitTestSuite

## Tests du chargeur multi-format (ModelLoader) : détection de format et parseur OBJ.
## Les OBJ sont écrits dans user:// à la volée (pas de fixtures importées par l'éditeur).

# --- Détection de format --------------------------------------------------

func test_is_supported_accepts_known_formats() -> void:
	assert_bool(ModelLoader.is_supported("model.glb")).is_true()
	assert_bool(ModelLoader.is_supported("model.gltf")).is_true()
	assert_bool(ModelLoader.is_supported("model.fbx")).is_true()
	assert_bool(ModelLoader.is_supported("model.obj")).is_true()

func test_is_supported_is_case_insensitive() -> void:
	assert_bool(ModelLoader.is_supported("Model.GLB")).is_true()
	assert_bool(ModelLoader.is_supported("Model.Obj")).is_true()

func test_is_supported_rejects_other_extensions() -> void:
	assert_bool(ModelLoader.is_supported("texture.png")).is_false()
	assert_bool(ModelLoader.is_supported("model.stl")).is_false()
	assert_bool(ModelLoader.is_supported("sans_extension")).is_false()

# --- Disponibilité runtime du FBX (dépendance moteur ufbx) ----------------

func test_fbx_runtime_classes_are_available() -> void:
	assert_bool(ClassDB.class_exists("FBXDocument")).is_true()
	assert_bool(ClassDB.class_exists("FBXState")).is_true()

# --- Parseur OBJ ----------------------------------------------------------

func test_obj_triangulates_quad_into_two_triangles() -> void:
	# Un quad -> 2 triangles = 6 sommets (triangulation en éventail).
	var path := _write_obj("quad", "v -1 0 -1\nv 1 0 -1\nv 1 0 1\nv -1 0 1\nvn 0 1 0\nf 1//1 4//1 3//1\nf 1//1 3//1 2//1\n")
	var mi := _first_mesh(auto_free(ModelLoader.load_scene(path)))
	assert_object(mi).is_not_null()
	assert_int(mi.mesh.get_surface_count()).is_equal(1)
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_int(verts.size()).is_equal(6)

func test_obj_uses_file_normals() -> void:
	var path := _write_obj("qn", "v -1 0 -1\nv 1 0 -1\nv 1 0 1\nv -1 0 1\nvn 0 1 0\nf 1//1 4//1 3//1\nf 1//1 3//1 2//1\n")
	var mi := _first_mesh(auto_free(ModelLoader.load_scene(path)))
	var normals: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_float(normals[0].y).is_greater(0.9)   # normale du fichier = +Y

func test_obj_generated_normals_point_up_after_winding_fix() -> void:
	# Triangle orienté vers le haut, SANS normales : valide l'inversion du winding
	# + generate_normals. Sans le fix, la normale générée pointerait vers le bas.
	var path := _write_obj("tri", "v 0 0 0\nv 0 0 1\nv 1 0 0\nf 1 2 3\n")
	var mi := _first_mesh(auto_free(ModelLoader.load_scene(path)))
	var normals: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_float(normals[0].y).is_greater(0.5)

func test_obj_material_is_double_sided() -> void:
	var path := _write_obj("dbl", "v 0 0 0\nv 0 0 1\nv 1 0 0\nf 1 2 3\n")
	var mi := _first_mesh(auto_free(ModelLoader.load_scene(path)))
	var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
	assert_object(mat).is_not_null()
	assert_int(mat.cull_mode).is_equal(BaseMaterial3D.CULL_DISABLED)

func test_obj_handles_negative_indices() -> void:
	var path := _write_obj("neg", "v 0 0 0\nv 0 0 1\nv 1 0 0\nf -3 -2 -1\n")
	var mi := _first_mesh(auto_free(ModelLoader.load_scene(path)))
	assert_object(mi).is_not_null()
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_int(verts.size()).is_equal(3)

func test_load_scene_returns_null_for_missing_file() -> void:
	assert_object(ModelLoader.load_scene("user://__inexistant__.obj")).is_null()

# --- helpers --------------------------------------------------------------

func _write_obj(tag: String, content: String) -> String:
	var path := "user://gdunit_%s.obj" % tag
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	return path

func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh != null:
		return node
	for c in node.get_children():
		var r := _first_mesh(c)
		if r != null:
			return r
	return null
