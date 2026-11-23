extends CharacterBody3D

const SPEED := 7.0
const JUMP_VELOCITY := 5.5
const MOUSE_SENSITIVITY := 0.002
var gravity: float = 18.0
var camera: Camera3D
var pitch := 0.0

func _ready() -> void:
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.45
    capsule.height = 1.8
    shape.shape = capsule
    add_child(shape)
    camera = Camera3D.new()
    camera.position = Vector3(0, 0.65, 0)
    camera.current = true
    add_child(camera)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        pitch = clamp(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
        camera.rotation.x = pitch
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseButton and event.pressed:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var input_dir := Vector2.ZERO
    if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
    if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
    if Input.is_key_pressed(KEY_W): input_dir.y += 1.0
    if Input.is_key_pressed(KEY_S): input_dir.y -= 1.0
    input_dir = input_dir.normalized()
    var direction := (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
    velocity.x = direction.x * SPEED
    velocity.z = direction.z * SPEED
    move_and_slide()
