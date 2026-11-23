extends Node3D

const RADIUS := 12
const REACH := 8.0
const WORLD_DIR := "user://worlds"
var blocks: Dictionary = {}
var block_meshes: Dictionary = {}
var selected_type := 0
var creative := true
var inventory := 24
var health := 100.0
var camera: Camera3D
var player: CharacterBody3D
var hud: Label
var info: Label
var health_bar: ProgressBar
var health_text: Label
var block_materials: Array[Material] = []
var current_world := ""
var menu_layer: CanvasLayer
var menu_box: VBoxContainer
var world_name_input: LineEdit
var worlds_list: VBoxContainer
var game_started := false

func _ready() -> void:
    _make_materials()
    _show_main_menu()

func _make_materials() -> void:
    for c in [Color(0.22,0.62,0.20), Color(0.42,0.27,0.14), Color(0.48,0.49,0.52), Color(0.18,0.38,0.72)]:
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        block_materials.append(m)

func _show_main_menu() -> void:
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)
    var bg := ColorRect.new()
    bg.color = Color(0.035,0.055,0.085,1)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(bg)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(center)
    menu_box = VBoxContainer.new()
    menu_box.custom_minimum_size = Vector2(440,0)
    menu_box.add_theme_constant_override("separation",12)
    center.add_child(menu_box)
    var title := Label.new()
    title.text = "VOXEL WORLD"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",40)
    menu_box.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "Create a new world or continue your adventure"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size",15)
    menu_box.add_child(subtitle)
    var divider := HSeparator.new()
    menu_box.add_child(divider)
    world_name_input = LineEdit.new()
    world_name_input.placeholder_text = "Enter a world name"
    world_name_input.text = "My World"
    menu_box.add_child(world_name_input)
    var create_button := Button.new()
    create_button.text = "CREATE NEW WORLD"
    create_button.custom_minimum_size.y = 44
    create_button.pressed.connect(_create_world_from_menu)
    menu_box.add_child(create_button)
    var load_title := Label.new()
    load_title.text = "SAVED WORLDS"
    load_title.add_theme_font_size_override("font_size",19)
    menu_box.add_child(load_title)
    worlds_list = VBoxContainer.new()
    worlds_list.add_theme_constant_override("separation",6)
    menu_box.add_child(worlds_list)
    var hint := Label.new()
    hint.text = "WASD move  •  Mouse look  •  Space jump"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size",13)
    menu_box.add_child(hint)
    _refresh_world_list()

func _refresh_world_list() -> void:
    for child in worlds_list.get_children():
        child.queue_free()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_DIR))
    var dir := DirAccess.open(WORLD_DIR)
    var found := false
    if dir:
        dir.list_dir_begin()
        var file := dir.get_next()
        while file != "":
            if not dir.current_is_dir() and file.ends_with(".json"):
                found = true
                var world_id := file.trim_suffix(".json")
                var button := Button.new()
                button.text = world_id.replace("_"," ")
                button.custom_minimum_size.y = 38
                button.pressed.connect(_load_world.bind(world_id))
                worlds_list.add_child(button)
            file = dir.get_next()
        dir.list_dir_end()
    if not found:
        var empty := Label.new()
        empty.text = "No saved worlds yet"
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty.modulate = Color(0.7,0.75,0.82)
        worlds_list.add_child(empty)

func _safe_world_id(value: String) -> String:
    var result := value.strip_edges().to_lower().replace(" ","_")
    var clean := ""
    for i in range(result.length()):
        var ch := result.substr(i,1)
        if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
            clean += ch
    return clean.left(32)

func _create_world_from_menu() -> void:
    var world_id := _safe_world_id(world_name_input.text)
    if world_id.is_empty():
        world_id = "my_world"
    _start_world(world_id, null)

func _load_world(world_id: String) -> void:
    var path := WORLD_DIR + "/" + world_id + ".json"
    if not FileAccess.file_exists(path):
        _refresh_world_list()
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if parsed is Dictionary:
        _start_world(world_id, parsed)

func _start_world(world_id: String, saved_data) -> void:
    current_world = world_id
    if menu_layer:
        menu_layer.queue_free()
        menu_layer = null
    game_started = true
    blocks.clear()
    block_meshes.clear()
    health = 100.0
    inventory = 24
    creative = true
    selected_type = 0
    _make_world()
    if saved_data is Dictionary and saved_data.has("blocks"):
        for entry in saved_data["blocks"]:
            var cell := Vector3i(int(entry["x"]),int(entry["y"]),int(entry["z"]))
            _add_block(cell,clampi(int(entry["kind"]),0,3))
        creative = bool(saved_data.get("creative",true))
        inventory = int(saved_data.get("inventory",24))
        health = float(saved_data.get("health",100.0))
    _make_player()
    _make_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_world() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55,-35,0)
    sun.light_energy = 1.15
    add_child(sun)
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.62,0.72,0.86)
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)
    for x in range(-RADIUS,RADIUS+1):
        for z in range(-RADIUS,RADIUS+1):
            _add_block(Vector3i(x,0,z),0)
            if (x * 7 + z * 11) % 37 == 0 and abs(x) > 2 and abs(z) > 2:
                for y in range(1,4):
                    _add_block(Vector3i(x,y,z),1)
                for dx in range(-1,2):
                    for dz in range(-1,2):
                        _add_block(Vector3i(x+dx,4,z+dz),0)

func _add_block(cell: Vector3i, kind: int) -> void:
    if blocks.has(cell):
        return
    blocks[cell] = kind
    var body := StaticBody3D.new()
    body.position = Vector3(cell) + Vector3(0.5,0.5,0.5)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    mesh.mesh = cube
    mesh.material_override = block_materials[kind]
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3.ONE
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    block_meshes[cell] = body

func _remove_block(cell: Vector3i) -> void:
    if not blocks.has(cell):
        return
    block_meshes[cell].queue_free()
    block_meshes.erase(cell)
    blocks.erase(cell)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0,3,0)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    collision.shape = capsule
    player.add_child(collision)
    camera = Camera3D.new()
    camera.position = Vector3(0,0.62,0)
    camera.current = true
    player.add_child(camera)
    add_child(player)

func _make_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(18,16)
    hud.add_theme_font_size_override("font_size",20)
    layer.add_child(hud)
    health_text = Label.new()
    health_text.position = Vector2(18,52)
    health_text.text = "HEALTH"
    health_text.add_theme_font_size_override("font_size",14)
    layer.add_child(health_text)
    health_bar = ProgressBar.new()
    health_bar.position = Vector2(18,76)
    health_bar.custom_minimum_size = Vector2(220,20)
    health_bar.size = Vector2(220,20)
    health_bar.min_value = 0
    health_bar.max_value = 100
    health_bar.show_percentage = false
    layer.add_child(health_bar)
    info = Label.new()
    info.position = Vector2(18,108)
    info.add_theme_font_size_override("font_size",14)
    info.text = "WASD move | Mouse look | Space jump | Left click break | Right click place | 1 Survival | 2 Creative | Esc menu"
    layer.add_child(info)
    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-8,-16)
    cross.add_theme_font_size_override("font_size",28)
    layer.add_child(cross)
    _update_hud()

func _update_hud() -> void:
    if not hud:
        return
    hud.text = ("CREATIVE" if creative else "SURVIVAL") + "   |   Blocks: " + ("∞" if creative else str(inventory)) + "   |   Selected: " + ["Grass","Dirt","Stone","Blue"][selected_type]
    health_bar.value = health
    health_text.text = "HEALTH  " + str(int(health)) + " / 100"

func _save_world() -> void:
    if not game_started or current_world.is_empty():
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_DIR))
    var saved_blocks: Array = []
    for cell in blocks:
        saved_blocks.append({"x":cell.x,"y":cell.y,"z":cell.z,"kind":blocks[cell]})
    var data := {"blocks":saved_blocks,"creative":creative,"inventory":inventory,"health":health}
    var file := FileAccess.open(WORLD_DIR + "/" + current_world + ".json",FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
    game_started = false

func _go_to_menu() -> void:
    _save_world()
    get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
    if not game_started:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            _go_to_menu()
        elif event.keycode == KEY_1:
            creative = false
            _update_hud()
        elif event.keycode == KEY_2:
            creative = true
            _update_hud()
        elif event.keycode >= KEY_3 and event.keycode <= KEY_6:
            selected_type = event.keycode - KEY_3
            _update_hud()
    if event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        elif event.button_index == MOUSE_BUTTON_LEFT:
            _break_target()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _place_target()
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        player.rotate_y(-event.relative.x * 0.002)
        camera.rotate_x(-event.relative.y * 0.002)
        camera.rotation.x = clamp(camera.rotation.x,-1.5,1.5)

func _target() -> Dictionary:
    var from := camera.global_position
    var to := from + (-camera.global_transform.basis.z * REACH)
    var query := PhysicsRayQueryParameters3D.create(from,to)
    query.exclude = [player.get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(query)

func _break_target() -> void:
    var hit := _target()
    if hit.is_empty():
        return
    var cell := Vector3i(floor(hit.position - hit.normal * 0.01))
    if blocks.has(cell):
        _remove_block(cell)
        if not creative:
            inventory += 1
            _update_hud()

func _place_target() -> void:
    if not creative and inventory <= 0:
        return
    var hit := _target()
    if hit.is_empty():
        return
    var cell := Vector3i(floor(hit.position + hit.normal * 0.51))
    if blocks.has(cell):
        return
    var player_cell := Vector3i(floor(player.global_position))
    if cell == player_cell or cell == player_cell + Vector3i.UP:
        return
    _add_block(cell,selected_type)
    if not creative:
        inventory -= 1
        _update_hud()

func _physics_process(delta: float) -> void:
    if not game_started:
        return
    if not player.is_on_floor():
        player.velocity.y -= 20.0 * delta
    if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor():
        player.velocity.y = 7.0
    var v := Vector2.ZERO
    v.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
    v.y = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
    if Input.is_key_pressed(KEY_W): v.y = 1.0
    if Input.is_key_pressed(KEY_S): v.y = -1.0
    if Input.is_key_pressed(KEY_A): v.x = -1.0
    if Input.is_key_pressed(KEY_D): v.x = 1.0
    v = v.normalized()
    var dir := player.transform.basis * Vector3(v.x,0,-v.y)
    player.velocity.x = dir.x * 6.0
    player.velocity.z = dir.z * 6.0
    player.move_and_slide()
    if player.global_position.y < -8.0:
        health = maxf(0.0,health - 25.0)
        player.global_position = Vector3(0,4,0)
        player.velocity = Vector3.ZERO
        if health <= 0.0:
            health = 100.0
        _update_hud()

func _exit_tree() -> void:
    _save_world()
