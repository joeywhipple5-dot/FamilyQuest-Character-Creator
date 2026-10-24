
extends Control

# Family Quest Character Creator - Godot 4.3
# Deploy the backend and enter its HTTPS URL before generating models.

var preview_root: Node3D
var model_root: Node3D
var camera: Camera3D
var status_label: Label
var server_url_input: LineEdit
var name_input: LineEdit
var prompt_input: TextEdit
var class_select: OptionButton
var gender_select: OptionButton
var kind_select: OptionButton
var generate_button: Button
var import_dialog: FileDialog

var generate_http: HTTPRequest
var status_http: HTTPRequest
var download_http: HTTPRequest

var busy := false
var current_task_id := ""
var generated_name := "FamilyQuest_Model"


func _ready() -> void:
    _build_interface()
    _show_test_model()
    _set_status("Ready. Enter your backend URL, then generate or import a GLB model.")


func _build_interface() -> void:
    var background := ColorRect.new()
    background.color = Color("#121722")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 10
    scroll.offset_top = 8
    scroll.offset_right = -10
    scroll.offset_bottom = -8
    add_child(scroll)

    var page := VBoxContainer.new()
    page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page.add_theme_constant_override("separation", 10)
    scroll.add_child(page)

    var title := Label.new()
    title.text = "FAMILY QUEST CHARACTER CREATOR"
    title.add_theme_font_size_override("font_size", 22)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "AI-assisted 3D heroes and creatures • Godot 4.3"
    subtitle.add_theme_font_size_override("font_size", 13)
    subtitle.modulate = Color("#b8c4d8")
    page.add_child(subtitle)

    _build_preview(page)

    var server_label := Label.new()
    server_label.text = "Backend HTTPS URL"
    page.add_child(server_label)

    server_url_input = LineEdit.new()
    server_url_input.placeholder_text = "https://your-deployed-backend.example"
    server_url_input.text = ""
    server_url_input.clear_button_enabled = true
    page.add_child(server_url_input)

    var selectors := GridContainer.new()
    selectors.columns = 2
    selectors.add_theme_constant_override("h_separation", 8)
    selectors.add_theme_constant_override("v_separation", 6)
    page.add_child(selectors)

    var class_box := VBoxContainer.new()
    selectors.add_child(class_box)

    var class_label := Label.new()
    class_label.text = "Hero class"
    class_box.add_child(class_label)

    class_select = OptionButton.new()
    for hero_class in ["Warrior", "Mage", "Rogue", "Druid", "Ranger"]:
        class_select.add_item(hero_class)
    class_box.add_child(class_select)

    var gender_box := VBoxContainer.new()
    selectors.add_child(gender_box)

    var gender_label := Label.new()
    gender_label.text = "Body style"
    gender_box.add_child(gender_label)

    gender_select = OptionButton.new()
    gender_select.add_item("Male")
    gender_select.add_item("Female")
    gender_select.add_item("Androgynous")
    gender_box.add_child(gender_select)

    var kind_label := Label.new()
    kind_label.text = "What are you creating?"
    page.add_child(kind_label)

    kind_select = OptionButton.new()
    kind_select.add_item("Hero character")
    kind_select.add_item("Enemy / creature")
    kind_select.add_item("Prop / object")
    kind_select.item_selected.connect(_on_kind_changed)
    page.add_child(kind_select)

    var name_label := Label.new()
    name_label.text = "Asset name"
    page.add_child(name_label)

    name_input = LineEdit.new()
    name_input.text = "New Family Quest Character"
    name_input.max_length = 100
    page.add_child(name_input)

    var prompt_label := Label.new()
    prompt_label.text = "Description"
    page.add_child(prompt_label)

    prompt_input = TextEdit.new()
    prompt_input.custom_minimum_size = Vector2(0, 92)
    prompt_input.placeholder_text = "Describe armor, materials, colors, face, equipment, silhouette, and fantasy style..."
    prompt_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    prompt_input.text = "Stylized high-quality fantasy hero, detailed layered armor and leather, readable silhouette, full body, neutral standing pose, game-ready 3D model, clean topology, no base or text."
    page.add_child(prompt_input)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    page.add_child(actions)

    generate_button = Button.new()
    generate_button.text = "Generate 3D Model"
    generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    generate_button.custom_minimum_size = Vector2(0, 48)
    generate_button.pressed.connect(_generate_model)
    actions.add_child(generate_button)

    var import_button := Button.new()
    import_button.text = "Import GLB"
    import_button.custom_minimum_size = Vector2(110, 48)
    import_button.pressed.connect(_open_import_dialog)
    actions.add_child(import_button)

    status_label = Label.new()
    status_label.text = "Ready"
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(0, 42)
    status_label.add_theme_font_size_override("font_size", 13)
    page.add_child(status_label)

    generate_http = HTTPRequest.new()
    generate_http.timeout = 90.0
    add_child(generate_http)

    status_http = HTTPRequest.new()
    status_http.timeout = 40.0
    add_child(status_http)

    download_http = HTTPRequest.new()
    download_http.timeout = 180.0
    download_http.body_size_limit = 100 * 1024 * 1024
    add_child(download_http)

    import_dialog = FileDialog.new()
    import_dialog.title = "Choose a GLB model"
    import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    import_dialog.access = FileDialog.ACCESS_FILESYSTEM
    import_dialog.filters = PackedStringArray(["*.glb ; GLB 3D models"])
    import_dialog.file_selected.connect(_load_glb)
    add_child(import_dialog)


func _build_preview(parent: VBoxContainer) -> void:
    var preview_panel := Panel.new()
    preview_panel.custom_minimum_size = Vector2(0, 260)
    parent.add_child(preview_panel)

    var viewport_container := SubViewportContainer.new()
    viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_container.stretch = true
    preview_panel.add_child(viewport_container)

    var sub_viewport := SubViewport.new()
    sub_viewport.size = Vector2i(720, 420)
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_container.add_child(sub_viewport)

    preview_root = Node3D.new()
    sub_viewport.add_child(preview_root)

    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#202b3b")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#a9b8ce")
    environment.ambient_light_energy = 0.8
    world.environment = environment
    preview_root.add_child(world)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35, -35, 0)
    light.light_energy = 1.6
    preview_root.add_child(light)

    camera = Camera3D.new()
    camera.position = Vector3(0, 1.45, 5.2)
    camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
    preview_root.add_child(camera)
    camera.current = true

    model_root = Node3D.new()
    preview_root.add_child(model_root)


func _show_test_model() -> void:
    _clear_model()

    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#4b8dce")
    material.roughness = 0.72

    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.42
    body_mesh.height = 1.55
    body.mesh = body_mesh
    body.position.y = 1.0
    body.material_override = material
    model_root.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.3
    head_mesh.height = 0.6
    head.mesh = head_mesh
    head.position.y = 2.0
    head.material_override = material
    model_root.add_child(head)

    var ground := MeshInstance3D.new()
    var ground_mesh := CylinderMesh.new()
    ground_mesh.top_radius = 1.4
    ground_mesh.bottom_radius = 1.4
    ground_mesh.height = 0.08
    ground.mesh = ground_mesh
    ground.position.y = -0.04

    var ground_material := StandardMaterial3D.new()
    ground_material.albedo_color = Color("#354254")
    ground.material_override = ground_material
    model_root.add_child(ground)


func _on_kind_changed(index: int) -> void:
    class_select.disabled = index != 0
    gender_select.disabled = index != 0

    if index == 1:
        prompt_input.text = "Original fantasy enemy creature, distinctive silhouette, detailed skin and armor materials, full body, neutral standing pose, game-ready 3D model, no text."
    elif index == 2:
        prompt_input.text = "Fantasy game prop, detailed readable shape, high-quality materials, centered isolated object, game-ready 3D model, no text."
    else:
        prompt_input.text = "Stylized high-quality fantasy hero, detailed layered armor and leather, readable silhouette, full body, neutral standing pose, game-ready 3D model, no base or text."


func _generate_model() -> void:
    if busy:
        return

    var base_url := server_url_input.text.strip_edges().trim_suffix("/")
    if base_url.is_empty() or not (base_url.begins_with("https://") or base_url.begins_with("http://localhost")):
        _set_status("Enter your deployed backend HTTPS URL first.")
        return

    var description := prompt_input.text.strip_edges()
    if description.length() < 5:
        _set_status("Enter a longer description for the model.")
        return

    var kind := kind_select.get_item_text(kind_select.selected)
    var final_prompt := description

    if kind == "Hero character":
        final_prompt += ", class: " + class_select.get_item_text(class_select.selected)
        final_prompt += ", body style: " + gender_select.get_item_text(gender_select.selected)
    elif kind == "Enemy / creature":
        final_prompt += ", original enemy creature for the Family Quest fantasy RPG"
    else:
        final_prompt += ", prop for the Family Quest fantasy RPG"

    generated_name = name_input.text.strip_edges()
    if generated_name.is_empty():
        generated_name = "FamilyQuest_Model"

    busy = true
    generate_button.disabled = true
    _set_status("Submitting model generation request...")

    var payload := {
        "prompt": final_prompt,
        "name": generated_name
    }

    var headers := PackedStringArray(["Content-Type: application/json"])
    var request_error := generate_http.request(
        base_url + "/generate",
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(payload)
    )

    if request_error != OK:
        _finish_busy("Could not start the request. Check the backend URL and connection.")
        return

    var response: Array = await generate_http.request_completed
    var response_code: int = response[1]
    var body: PackedByteArray = response[3]
    var parsed = JSON.parse_string(body.get_string_from_utf8())

    if response[0] != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        _finish_busy("Generation request failed (HTTP " + str(response_code) + "). Check that the backend is deployed and configured.")
        return

    if not (parsed is Dictionary) or not parsed.has("task_id"):
        _finish_busy("Backend response did not include a task ID.")
        return

    current_task_id = str(parsed["task_id"])
    _set_status("Generation started. Task: " + current_task_id)

    for attempt in range(60):
        await get_tree().create_timer(3.0).timeout

        var status_error := status_http.request(
            base_url + "/status/" + current_task_id,
            PackedStringArray(),
            HTTPClient.METHOD_GET
        )

        if status_error != OK:
            _finish_busy("Could not check generation progress.")
            return

        var status_response: Array = await status_http.request_completed
        var status_code: int = status_response[1]
        var status_body: PackedByteArray = status_response[3]
        var status_data = JSON.parse_string(status_body.get_string_from_utf8())

        if status_response[0] != HTTPRequest.RESULT_SUCCESS or status_code < 200 or status_code >= 300 or not (status_data is Dictionary):
            _finish_busy("Could not read generation status (HTTP " + str(status_code) + ").")
            return

        var state := str(status_data.get("status", "unknown")).to_lower()
        var progress := int(status_data.get("progress", 0))
        _set_status("Generating model: " + str(progress) + "% • " + state)

        if state == "success":
            await _download_generated_model(base_url, current_task_id)
            return

        if state == "failed" or state == "cancelled" or state == "canceled":
            _finish_busy("Model generation did not complete: " + state)
            return

    _finish_busy("Generation is taking longer than expected. Task ID: " + current_task_id)


func _download_generated_model(base_url: String, task_id: String) -> void:
    _set_status("Model ready. Downloading GLB...")

    var error := download_http.request(
        base_url + "/download/" + task_id,
        PackedStringArray(),
        HTTPClient.METHOD_GET
    )

    if error != OK:
        _finish_busy("Could not start model download.")
        return

    var response: Array = await download_http.request_completed
    var code: int = response[1]
    var bytes: PackedByteArray = response[3]

    if response[0] != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or bytes.is_empty():
        _finish_busy("Model download failed (HTTP " + str(code) + ").")
        return

    var safe_name := generated_name.to_snake_case().validate_filename()
    if safe_name.is_empty():
        safe_name = "family_quest_model"

    var path := "user://" + safe_name + ".glb"
    var file := FileAccess.open(path, FileAccess.WRITE)

    if file == null:
        _finish_busy("Downloaded model, but could not save it to app storage.")
        return

    file.store_buffer(bytes)
    file.close()

    _load_glb(path)
    _finish_busy("Model downloaded and saved in app storage: " + path)


func _open_import_dialog() -> void:
    import_dialog.popup_centered(Vector2i(800, 600))


func _load_glb(path: String) -> void:
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var result := document.append_from_file(path, state)

    if result != OK:
        _set_status("Could not import this GLB. Check the file format.")
        return

    var imported_scene := document.generate_scene(state)

    if imported_scene == null:
        _set_status("Godot could not create a scene from this GLB.")
        return

    _clear_model()
    model_root.add_child(imported_scene)
    _frame_model(imported_scene)
    _set_status("GLB loaded: " + path.get_file())


func _frame_model(imported_scene: Node3D) -> void:
    var bounds := AABB()
    var found_mesh := false
    var meshes := imported_scene.find_children("*", "MeshInstance3D", true, false)

    for node in meshes:
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh != null:
            var mesh_bounds := mesh_node.mesh.get_aabb()
            var transformed := mesh_node.global_transform * Transform3D(Basis.IDENTITY, mesh_bounds.position)
            var world_box := AABB(transformed.origin, mesh_bounds.size)

            if not found_mesh:
                bounds = world_box
                found_mesh = true
            else:
                bounds = bounds.merge(world_box)

    if found_mesh:
        var center := bounds.get_center()
        imported_scene.position -= center
        camera.position = Vector3(
            0,
            maxf(bounds.size.y * 0.55, 1.0),
            maxf(bounds.size.length() * 0.9, 3.0)
        )
        camera.look_at(Vector3.ZERO, Vector3.UP)


func _clear_model() -> void:
    if not is_instance_valid(model_root):
        return

    for child in model_root.get_children():
        model_root.remove_child(child)
        child.queue_free()


func _finish_busy(message: String) -> void:
    busy = false

    if is_instance_valid(generate_button):
        generate_button.disabled = false

    _set_status(message)


func _set_status(message: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = message
