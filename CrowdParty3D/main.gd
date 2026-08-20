extends Node3D

const SHOT_INTERVAL := 0.35
const SHOT_SPEED := 18.0
const PLAYER_SPEED := 7.0
const ARENA_SIZE := Vector2(44.0, 32.0)
const CAMERA_OFFSET := Vector3(0, 12.0, 12.0)

var player: CharacterBody3D
var camera: Camera3D
var player_facing := Vector3(0, 0, -1)
var mouse_world_position := Vector3.ZERO
var civilians: Array = []
var allies: Array = []
var enemies: Array = []
var projectiles: Array = []
var exit_area: Area3D
var exit_position := Vector3(18, 0, 12)
var player_shot_timer := 0.0
var state := "playing"
var message := "Acerte pessoas para recrutá-las e alcance a SAIDA."
var hud: Label
var banner: Label

var colors := {
    "floor": Color("#263346"),
    "wall": Color("#56677a"),
    "obstacle": Color("#b77d54"),
    "player": Color("#f4d35e"),
    "civilian": Color("#d9d1be"),
    "ally": Color("#58d68d"),
    "enemy": Color("#e56b6f"),
    "exit": Color("#7ee0a5"),
    "shot": Color("#f4d35e")
}

func _ready() -> void:
    _setup_world()
    _setup_player()
    _setup_exit()
    _setup_hud()
    _spawn_civilians()
    _spawn_enemies()
    _update_hud()

func _process(delta: float) -> void:
    if state != "playing":
        _update_camera(delta)
        return
    _update_player(delta)
    _update_camera(delta)
    _update_allies(delta)
    _update_enemies(delta)
    _update_projectiles(delta)
    player_shot_timer = maxf(0.0, player_shot_timer - delta)
    _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
        _player_shoot()
    if event is InputEventKey and event.pressed and event.keycode == KEY_R:
        get_tree().reload_current_scene()
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _update_mouse_world_position(event.position)

func _setup_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#111a27")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#c8d5e6")
    env.ambient_light_energy = 0.65
    environment.environment = env
    add_child(environment)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55, -25, 0)
    light.light_color = Color("#fff1d0")
    light.light_energy = 1.15
    light.shadow_enabled = true
    add_child(light)

    _create_box(Vector3(0, -0.6, 0), Vector3(ARENA_SIZE.x, 1, ARENA_SIZE.y), colors.floor, true)
    _create_box(Vector3(0, 1.5, -ARENA_SIZE.y / 2), Vector3(ARENA_SIZE.x, 3, 1), colors.wall, true)
    _create_box(Vector3(0, 1.5, ARENA_SIZE.y / 2), Vector3(ARENA_SIZE.x, 3, 1), colors.wall, true)
    _create_box(Vector3(-ARENA_SIZE.x / 2, 1.5, 0), Vector3(1, 3, ARENA_SIZE.y), colors.wall, true)
    _create_box(Vector3(ARENA_SIZE.x / 2, 1.5, 0), Vector3(1, 3, ARENA_SIZE.y), colors.wall, true)

    # Divisoes internas: salas fisicas com passagens entre elas.
    _create_box(Vector3(-8, 1.2, -7), Vector3(18, 2.4, 0.8), colors.wall, true)
    _create_box(Vector3(7, 1.2, 1), Vector3(0.8, 2.4, 13), colors.wall, true)
    _create_box(Vector3(-7, 1.2, 7), Vector3(12, 2.4, 0.8), colors.wall, true)

    _create_box(Vector3(-13, 0.8, -3), Vector3(3, 1.6, 2), colors.obstacle, true)
    _create_box(Vector3(-3, 0.8, -2), Vector3(2.5, 1.6, 3.5), colors.obstacle, true)
    _create_box(Vector3(3, 0.8, 8), Vector3(4, 1.6, 2), colors.obstacle, true)
    _create_box(Vector3(13, 0.8, 5), Vector3(2.5, 1.6, 4), colors.obstacle, true)
    _create_box(Vector3(12, 0.8, -8), Vector3(4, 1.6, 2), colors.obstacle, true)

func _setup_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    add_child(player)
    player.position = Vector3(-14, 0.8, 10)
    _add_actor_mesh(player, colors.player, 0.55)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.45
    shape.height = 1.5
    collision.shape = shape
    collision.position.y = 0.75
    player.add_child(collision)

    camera = Camera3D.new()
    camera.position = player.global_position + CAMERA_OFFSET
    camera.current = true
    add_child(camera)
    _update_mouse_world_position(get_viewport().get_mouse_position())

func _setup_exit() -> void:
    exit_area = Area3D.new()
    exit_area.position = exit_position
    exit_area.name = "Exit"
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 1.5
    cylinder.bottom_radius = 1.5
    cylinder.height = 0.12
    mesh.mesh = cylinder
    mesh.material_override = _material(colors.exit, true)
    exit_area.add_child(mesh)
    var collision := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.7
    collision.shape = sphere
    collision.position.y = 0.7
    exit_area.add_child(collision)
    exit_area.body_entered.connect(_on_exit_body_entered)
    add_child(exit_area)

    var sign := Label3D.new()
    sign.text = "SAIDA"
    sign.modulate = colors.exit
    sign.font_size = 48
    sign.position.y = 1.2
    exit_area.add_child(sign)

func _setup_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(24, 20)
    hud.add_theme_font_size_override("font_size", 18)
    hud.add_theme_color_override("font_color", Color("#f5f7fa"))
    layer.add_child(hud)
    banner = Label.new()
    banner.position = Vector2(0, 300)
    banner.size = Vector2(1280, 120)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.add_theme_font_size_override("font_size", 32)
    banner.add_theme_color_override("font_color", Color("#f4d35e"))
    layer.add_child(banner)

func _update_player(delta: float) -> void:
    var direction := mouse_world_position - player.global_position
    direction.y = 0
    if direction.length() > 0.6:
        direction = direction.normalized()
        player_facing = direction
        player.rotation.y = atan2(direction.x, direction.z)
    else:
        direction = Vector3.ZERO
    player.velocity = direction * PLAYER_SPEED
    player.move_and_slide()
    player.position.y = 0.8

func _update_camera(delta: float) -> void:
    if not player or not camera:
        return
    camera.global_position = player.global_position + CAMERA_OFFSET
    camera.look_at(player.global_position + Vector3(0, 0.8, 0), Vector3.UP)

func _update_mouse_world_position(screen_position: Vector2) -> void:
    if not camera or not player:
        return
    var ray_origin := camera.project_ray_origin(screen_position)
    var ray_direction := camera.project_ray_normal(screen_position)
    if absf(ray_direction.y) < 0.001:
        return
    var distance := -ray_origin.y / ray_direction.y
    if distance >= 0:
        mouse_world_position = ray_origin + ray_direction * distance

func _player_shoot() -> void:
    if state != "playing" or player_shot_timer > 0:
        return
    _spawn_projectile(player.global_position + Vector3(0, 0.9, 0), player_facing, colors.shot)
    player_shot_timer = SHOT_INTERVAL

func _update_allies(delta: float) -> void:
    for index in range(allies.size()):
        var ally: Dictionary = allies[index]
        var node: Node3D = ally.node
        var angle := float(index) * 1.1 + Time.get_ticks_msec() * 0.001
        var target := player.global_position + Vector3(cos(angle) * 2.0, 0.0, sin(angle) * 2.0)
        node.position = node.position.lerp(target, minf(1.0, delta * 5.0))
        ally.shot_timer = maxf(0.0, float(ally.shot_timer) - delta)
        if ally.shot_timer <= 0:
            var target_enemy := _nearest_enemy(node.global_position, 14.0)
            if target_enemy:
                var direction: Vector3 = (target_enemy.global_position - node.global_position).normalized()
                _spawn_projectile(node.global_position + Vector3(0, 0.8, 0), direction, colors.ally)
                ally.shot_timer = SHOT_INTERVAL
        allies[index] = ally

func _update_enemies(delta: float) -> void:
    for enemy in enemies.duplicate():
        if not is_instance_valid(enemy):
            enemies.erase(enemy)
            continue
        var direction: Vector3 = player.global_position - enemy.global_position
        direction.y = 0
        if direction.length() > 0.1:
            enemy.position += direction.normalized() * (2.0 + enemies.size() * 0.03) * delta
            enemy.look_at(enemy.global_position + direction, Vector3.UP)
        if enemy.global_position.distance_to(player.global_position) < 1.15:
            _lose("A horda alcancou voce.")
        for ally in allies.duplicate():
            if is_instance_valid(ally.node) and enemy.global_position.distance_to(ally.node.global_position) < 0.9:
                allies.erase(ally)
                ally.node.queue_free()
                message = "Um recruta foi alcancado pela horda."
                break

func _update_projectiles(delta: float) -> void:
    for projectile in projectiles.duplicate():
        var node: Node3D = projectile.node
        if not is_instance_valid(node):
            projectiles.erase(projectile)
            continue
        node.position += projectile.velocity * delta
        projectile.life -= delta
        var hit := false
        for civilian in civilians.duplicate():
            if node.global_position.distance_to(civilian.global_position) < 0.8:
                _recruit(civilian)
                hit = true
                break
        if not hit:
            for enemy in enemies.duplicate():
                if node.global_position.distance_to(enemy.global_position) < 0.8:
                    enemies.erase(enemy)
                    enemy.queue_free()
                    message = "Inimigo dispersado!"
                    hit = true
                    break
        if hit or projectile.life <= 0:
            projectiles.erase(projectile)
            node.queue_free()
        else:
            var projectile_index := projectiles.find(projectile)
            if projectile_index >= 0:
                projectiles[projectile_index] = projectile

func _spawn_projectile(origin: Vector3, direction: Vector3, color: Color) -> void:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.16
    mesh.height = 0.32
    node.mesh = mesh
    node.material_override = _material(color, true)
    node.position = origin
    add_child(node)
    projectiles.append({"node": node, "velocity": direction.normalized() * SHOT_SPEED, "life": 2.0})

func _recruit(civilian: Node3D) -> void:
    civilians.erase(civilian)
    var ally := {"node": civilian, "shot_timer": 0.0}
    civilian.get_child(0).material_override = _material(colors.ally, true)
    allies.append(ally)
    message = "+1 recrutado pelo disparo."

func _nearest_enemy(origin: Vector3, max_distance: float) -> Node3D:
    var closest: Node3D = null
    var closest_distance := max_distance
    for enemy in enemies:
        var distance: float = origin.distance_to(enemy.global_position)
        if distance < closest_distance:
            closest = enemy
            closest_distance = distance
    return closest

func _spawn_civilians() -> void:
    var positions := [Vector3(-14, 0.8, -10), Vector3(-7, 0.8, -10), Vector3(0, 0.8, -10), Vector3(-14, 0.8, 2), Vector3(-4, 0.8, 5), Vector3(11, 0.8, 8)]
    for position in positions:
        var civilian := _create_actor(position, colors.civilian, "Civilian")
        civilians.append(civilian)

func _spawn_enemies() -> void:
    var positions := [Vector3(18, 0.8, -12), Vector3(16, 0.8, 8), Vector3(4, 0.8, -12), Vector3(-18, 0.8, -5), Vector3(12, 0.8, 0)]
    for position in positions:
        enemies.append(_create_actor(position, colors.enemy, "Horde"))

func _create_actor(position: Vector3, color: Color, actor_name: String) -> Node3D:
    var actor := Node3D.new()
    actor.name = actor_name
    actor.position = position
    _add_actor_mesh(actor, color, 0.45)
    add_child(actor)
    return actor

func _add_actor_mesh(parent: Node3D, color: Color, radius: float) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    mesh.mesh = sphere
    mesh.material_override = _material(color, true)
    mesh.position.y = radius
    parent.add_child(mesh)

func _create_box(position: Vector3, size: Vector3, color: Color, solid: bool) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = position
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _material(color, false)
    body.add_child(mesh)
    if solid:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    add_child(body)
    return body

func _material(color: Color, emission: bool) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    if emission:
        material.emission_enabled = true
        material.emission = color * 0.25
    return material

func _on_exit_body_entered(body: Node3D) -> void:
    if body == player and state == "playing":
        state = "won"
        message = "Voce encontrou a saida!"

func _lose(text: String) -> void:
    if state == "playing":
        state = "lost"
        message = text

func _update_hud() -> void:
    if not hud:
        return
    hud.text = "CROWD PARTY 3D\nEquipe: %d   Horda: %d\nWASD/setas mover   ESPACO/clique atirar   R reiniciar\n%s" % [allies.size(), enemies.size(), message]
    if state == "won":
        banner.text = "VOCE ESCAPOU!\nPressione R para jogar novamente"
    elif state == "lost":
        banner.text = "A HORDA VENCEU\nPressione R para tentar novamente"
    else:
        banner.text = ""
