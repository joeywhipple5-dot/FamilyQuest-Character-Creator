extends Control

var preview_root: Node3D
var model_root: Node3D
var camera: Camera3D
var status_label: Label
var file_dialog: FileDialog
var rotate_enabled := true
var last_touch := Vector2.ZERO
var touch_dragging := false
var camera_pivot: Node3D

func _ready() -> void:
    _build_ui()
    _build_viewport()
    _show_test_model()
    _set_status("Ready. Import a .glb model to preview it.")

func _build_ui() -> void:
    var background := ColorRect.new()
    background.color = Color("#151b27")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var header := Label.new()
    header.text = "FAMILY QUEST | CHARACTER CREATOR"
    header.position = Vector2(22, 14)
    header.size = Vector2(900, 42)
    header.add_theme_font_size_override("font_size", 25)
    add_child(header)

    var import_button := Button.new()
    import_button.text = "Import .glb Model"
    import_button.position = Vector2(24, 100)
    import_button.size = Vector2(250, 55)
    import_button.pressed.connect(_open_file_picker)
    add_child(import_button)

    status_label = Label.new()
    status_label.text = "Loading..."
    status_label.position = Vector2(24, 600)
    status_label.size = Vector2(900, 60)
    add_child(status_label)

    file_dialog = FileDialog.new()
    file_dialog.title = "Choose a GLB model"
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    file_dialog.filters = PackedStringArray(["*.glb ; GLB models"])
    file_dialog.file_selected.connect(_load_glb)
    add_child(file_dialog)
func _build_viewport() -> void:
    var panel := Panel.new()
    panel.position = Vector2(24, 175)
    panel.size = Vector2(900, 400)
    add_child(panel)

    var viewport_container := SubViewportContainer.new()
    viewport_container.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    panel.add_child(viewport_container)

    var sub_viewport := SubViewport.new()
    sub_viewport.size = Vector2i(900, 400)
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_container.add_child(sub_viewport)

    preview_root = Node3D.new()
    sub_viewport.add_child(preview_root)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment_node.environment = environment
    preview_root.add_child(environment_node)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35, -35, 0)
    light.light_energy = 1.5
    preview_root.add_child(light)

    camera = Camera3D.new()
    camera.position = Vector3(0, 1.5, 5)
    camera.look_at(Vector3(0, 1, 0), Vector3.UP)
    preview_root.add_child(camera)
    camera.current = true

    model_root = Node3D.new()
    preview_root.add_child(model_root)


func _show_test_model() -> void:
    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.45
    body_mesh.height = 1.8
    body.mesh = body_mesh
    body.position.y = 1.0

    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#4b8dce")
    body.material_override = material
    model_root.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.32
    head_mesh.height = 0.64
    head.mesh = head_mesh
    head.position.y = 2.05
    head.material_override = material
    model_root.add_child(head)


func _open_file_picker() -> void:
    file_dialog.popup_centered(
        Vector2i(800, 600)
    )


func _load_glb(path: String) -> void:
    var document := GLTFDocument.new()
    var state := GLTFState.new()

    var result := document.append_from_file(path, state)

    if result != OK:
        _set_status("Import failed. Check that the file is a valid GLB.")
        return

    var imported_scene := document.generate_scene(state)

    if imported_scene == null:
        _set_status("Could not create a scene from this GLB.")
        return

    for child in model_root.get_children():
        model_root.remove_child(child)
        child.free()

    model_root.add_child(imported_scene)
    _set_status("GLB loaded successfully: " + path.get_file())


func _set_status(message: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = message
