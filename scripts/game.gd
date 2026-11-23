extends Node3D

const RADIUS := 12
const REACH := 8.0
var blocks: Dictionary = {}
var block_meshes: Dictionary = {}
var selected_type := 0
var creative := true
var inventory := 24
var camera: Camera3D
var player: CharacterBody3D
var hud: Label
var info: Label
var block_materials: Array[Material] = []

func _ready() -> void:
    _make_materials()
    _make_world()
    _make_player()
    _make_hud()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_materials() -> void:
    for c in [Color(0.22,0.62,0.20), Color(0.42,0.27,0.14), Color(0.48,0.49,0.52), Color(0.18,0.38,0.72)]:
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        block_materials.append(m)

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
            var h := 0
            _add_block(Vector3i(x,h,z),0)
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
    info = Label.new()
    info.position = Vector2(18,54)
    info.add_theme_font_size_override("font_size",15)
    info.text = "WASD move  |  Mouse look  |  Space jump  |  Left click break  |  Right click place  |  1 Survival  |  2 Creative  |  Esc unlock"
    layer.add_child(info)
    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-8,-16)
    cross.add_theme_font_size_override("font_size",28)
    layer.add_child(cross)
    _update_hud()

func _update_hud() -> void:
    hud.text = ("CREATIVE" if creative else "SURVIVAL") + "   |   Blocks: " + ("∞" if creative else str(inventory)) + "   |   Selected: " + ["Grass","Dirt","Stone","Blue"][selected_type]

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
