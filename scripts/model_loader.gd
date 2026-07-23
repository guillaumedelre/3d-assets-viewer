class_name ModelLoader

## Chargement de scènes 3D à l'exécution, tous formats confondus :
##  - glTF / GLB : via GLTFDocument
##  - FBX (Unity inclus) : via FBXDocument (moteur ufbx intégré à Godot)
##  - OBJ : parseur maison (aucun chargeur OBJ runtime dans Godot)
##
## Renvoie le nœud racine de la scène (Node3D) ou null en cas d'échec.

const EXTENSIONS := ["glb", "gltf", "fbx", "obj"]


static func is_supported(path: String) -> bool:
	return path.get_extension().to_lower() in EXTENSIONS


static func load_scene(path: String) -> Node:
	match path.get_extension().to_lower():
		"glb", "gltf":
			return _load_document(GLTFDocument.new(), GLTFState.new(), path)
		"fbx":
			return _load_document(FBXDocument.new(), FBXState.new(), path)
		"obj":
			return _load_obj(path)
	return null


# --- glTF / FBX (API GLTFDocument / FBXDocument identiques) -------------------

static func _load_document(doc, state, path: String) -> Node:
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


# --- OBJ (parseur runtime) ---------------------------------------------------

static func _load_obj(path: String) -> Node:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var base_dir := path.get_base_dir()

	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()

	var materials := {}          # nom -> StandardMaterial3D
	var builders := {}           # nom de matériau -> SurfaceTool
	var order := []              # ordre de création des surfaces
	var current_mtl := ""
	var had_normals := false

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"v":
				if parts.size() >= 4:
					positions.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()))
			"vt":
				var v := parts[2].to_float() if parts.size() > 2 else 0.0
				uvs.append(Vector2(parts[1].to_float(), 1.0 - v))   # origine UV inversée vs Godot
			"vn":
				if parts.size() >= 4:
					normals.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()))
					had_normals = true
			"mtllib":
				_parse_mtl(base_dir.path_join(line.substr(7).strip_edges()), materials, base_dir)
			"usemtl":
				current_mtl = line.substr(7).strip_edges()
			"f":
				_add_face(_get_builder(builders, order, current_mtl), parts, positions, uvs, normals)
	f.close()

	if builders.is_empty():
		return null

	var mesh := ArrayMesh.new()
	for name in order:
		var st: SurfaceTool = builders[name]
		if not had_normals:
			st.generate_normals()
		st.commit(mesh)
		var mat: StandardMaterial3D = materials.get(name)
		if mat == null:
			mat = StandardMaterial3D.new()
		# Double-face : le winding des OBJ n'est pas fiable d'un exporteur à
		# l'autre ; sans ça, des faces « manquent » (éliminées par le culling).
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var root := Node3D.new()
	root.name = path.get_file().get_basename()
	root.add_child(mi)
	return root


static func _get_builder(builders: Dictionary, order: Array, name: String) -> SurfaceTool:
	if not builders.has(name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		builders[name] = st
		order.append(name)
	return builders[name]


static func _add_face(st: SurfaceTool, parts: PackedStringArray, positions: PackedVector3Array, uvs: PackedVector2Array, normals: PackedVector3Array) -> void:
	var verts := []
	for i in range(1, parts.size()):
		verts.append(_parse_vertex(parts[i], positions.size(), uvs.size(), normals.size()))
	# Triangulation en éventail (gère quads et n-gones convexes).
	# Ordre inversé (v0, v[i+1], v[i]) : le winding OBJ (anti-horaire) est
	# opposé à la convention de face avant de Godot (horaire).
	for i in range(1, verts.size() - 1):
		for idx in [verts[0], verts[i + 1], verts[i]]:
			if idx.y >= 0 and idx.y < uvs.size():
				st.set_uv(uvs[idx.y])
			if idx.z >= 0 and idx.z < normals.size():
				st.set_normal(normals[idx.z])
			if idx.x >= 0 and idx.x < positions.size():
				st.add_vertex(positions[idx.x])


## "v/vt/vn" -> Vector3i(vi, ti, ni) en indices 0-based (-1 si absent).
static func _parse_vertex(token: String, vcount: int, tcount: int, ncount: int) -> Vector3i:
	var c := token.split("/")
	var vi := _resolve(c[0], vcount)
	var ti := _resolve(c[1], tcount) if c.size() > 1 else -1
	var ni := _resolve(c[2], ncount) if c.size() > 2 else -1
	return Vector3i(vi, ti, ni)


static func _resolve(s: String, count: int) -> int:
	if s.is_empty():
		return -1
	var idx := s.to_int()
	if idx > 0:
		return idx - 1
	if idx < 0:
		return count + idx        # indices négatifs relatifs
	return -1


# --- Matériaux .mtl -----------------------------------------------------------

static func _parse_mtl(mtl_path: String, materials: Dictionary, base_dir: String) -> void:
	var f := FileAccess.open(mtl_path, FileAccess.READ)
	if f == null:
		return
	var current: StandardMaterial3D = null
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"newmtl":
				current = StandardMaterial3D.new()
				materials[line.substr(6).strip_edges()] = current
			"Kd":
				if current != null and parts.size() >= 4:
					current.albedo_color = Color(parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
			"d":
				if current != null and parts.size() >= 2:
					var a := parts[1].to_float()
					if a < 1.0:
						current.albedo_color.a = a
						current.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"map_Kd":
				if current != null and parts.size() >= 2:
					var tex := _load_texture(base_dir, parts[parts.size() - 1])
					if tex != null:
						current.albedo_texture = tex
	f.close()


static func _load_texture(base_dir: String, rel: String) -> Texture2D:
	rel = rel.replace("\\", "/")
	var tex_path := rel if rel.is_absolute_path() else base_dir.path_join(rel)
	if not FileAccess.file_exists(tex_path):
		tex_path = base_dir.path_join(rel.get_file())     # repli : nom seul dans le dossier
		if not FileAccess.file_exists(tex_path):
			return null
	var img := Image.load_from_file(tex_path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
