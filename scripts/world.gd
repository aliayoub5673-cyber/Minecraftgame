extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const BLOCK_SIZE := 2.0
const WORLD_RADIUS := 14

func _ready() -> void:
    _make_lighting()
    _make_ground()
    _make_player()

func _make_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -35, 0)
    sun.light_energy = 1.2
    add_child(sun)
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.65, 0.8)
    environment.ambient_light_energy = 0.7
    env.environment = environment
    add_child(env)

func _make_ground() -> void:
    for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
        for z in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
            var block := StaticBody3D.new()
            block.position = Vector3(x * BLOCK_SIZE, -1.0, z * BLOCK_SIZE)
            var mesh := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
            mesh.mesh = box
            var material := StandardMaterial3D.new()
            material.albedo_color = Color(0.24, 0.62, 0.22) if (x + z) % 2 == 0 else Color(0.20, 0.55, 0.18)
            mesh.material_override = material
            block.add_child(mesh)
            var collision := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = box.size
            collision.shape = shape
            block.add_child(collision)
            add_child(block)

func _make_player() -> void:
    var player := CharacterBody3D.new()
    player.set_script(PlayerScript)
    player.position = Vector3(0, 3, 0)
    add_child(player)
