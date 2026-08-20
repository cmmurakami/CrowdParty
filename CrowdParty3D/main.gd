extends Node3D

const SHOT_SPEED := 18.0
const PLAYER_SPEED := 7.0
const ARENA_SIZE := Vector2(88.0, 64.0)
const CAMERA_OFFSET := Vector3(0, 12.0, 12.0)
const ACTOR_HIT_RADIUS := 0.95
const MAX_ENEMIES := 50
const HORDE_SPAWN_INTERVAL := 0.15

var player: CharacterBody3D
var camera: Camera3D
var player_facing := Vector3(0, 0, -1)
var mouse_world_position := Vector3.ZERO
var civilians: Array = []
var allies: Array = []
var enemies: Array = []
var projectiles: Array = []
var pickups: Array = []
var exit_area: Area3D
var exit_position := Vector3(38, 0, 26)
var horde_spawn_timer := 0.0
var enemies_defeated := 0
var recruits_count := 0
var weapon_mode := "confetti"
var double_shot := false
var quad_shot := false
var ceo_spawned := false
var enemies_health := {}
var countdown_remaining := 3.0
var state := "countdown"
var message := "Acerte pessoas para recrutá-las e alcance a SAIDA."
var hud: Label
var banner: Label

var colors := {
    "floor": Color("#263346"),
    "wall": Color("#56677a"),
    "obstacle": Color("#b77d54"),
    "player": Color("#35c46a"),
    "civilian": Color("#d9d1be"),
    "ally": Color("#3d8ee8"),
    "enemy": Color("#e04455"),
    "exit": Color("#7ee0a5"),
    "shot": Color("#f4d35e")
}

func _ready() -> void:
    _setup_world()
    _setup_player()
    _setup_exit()
    _setup_hud()
    _spawn_furniture()
    _spawn_weapon_upgrades()
    _spawn_civilians()
    _spawn_enemies()
    _update_hud()

func _process(delta: float) -> void:
    if state == "countdown":
        countdown_remaining -= delta
        if countdown_remaining <= 0:
            state = "playing"
            message = "Acerte pessoas para recrutá-las e alcance a SAIDA."
        _update_camera(delta)
        _update_hud()
        return
    if state != "playing":
        _update_camera(delta)
        return
    _update_player(delta)
    _update_camera(delta)
    _update_allies(delta)
    _update_enemies(delta)
    _update_projectiles(delta)
    _update_pickups()
    _update_horde_spawns(delta)
    _animate_actor_legs()
    _check_team_exit()
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
    _create_box(Vector3(-16, 1.5, -ARENA_SIZE.y / 2), Vector3(10, 3, 1), colors.wall, true)
    _create_box(Vector3(0, 1.5, -ARENA_SIZE.y / 2), Vector3(8, 3, 1), colors.wall, true)
    _create_box(Vector3(16, 1.5, -ARENA_SIZE.y / 2), Vector3(10, 3, 1), colors.wall, true)
    _spawn_windows()
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
    _create_exit_door()
    var collision := CollisionShape3D.new()
    var door_trigger := BoxShape3D.new()
    door_trigger.size = Vector3(3.8, 1.8, 2.2)
    collision.shape = door_trigger
    collision.position = Vector3(0, 0.9, 1.0)
    exit_area.add_child(collision)
    exit_area.body_entered.connect(_on_exit_body_entered)
    add_child(exit_area)

    var sign := Label3D.new()
    sign.text = "SAIDA / EXIT"
    sign.modulate = colors.exit
    sign.font_size = 48
    sign.position = Vector3(0, 4.3, 0)
    exit_area.add_child(sign)

func _create_exit_door() -> void:
    var door_panel := MeshInstance3D.new()
    var panel_mesh := BoxMesh.new()
    panel_mesh.size = Vector3(3.2, 4.0, 0.35)
    door_panel.mesh = panel_mesh
    door_panel.position = exit_position + Vector3(0, 2.0, 0)
    door_panel.material_override = _material(Color("#173b45"), true)
    add_child(door_panel)
    for frame_position in [Vector3(-1.9, 2.0, 0), Vector3(1.9, 2.0, 0)]:
        _create_box(exit_position + frame_position, Vector3(0.35, 4.4, 0.55), colors.exit, false)
    _create_box(exit_position + Vector3(0, 4.15, 0), Vector3(4.1, 0.35, 0.55), colors.exit, false)
    var handle := MeshInstance3D.new()
    var handle_mesh := SphereMesh.new()
    handle_mesh.radius = 0.12
    handle_mesh.height = 0.24
    handle.mesh = handle_mesh
    handle.position = exit_position + Vector3(0.8, 2.0, -0.25)
    handle.material_override = _material(Color("#f4d35e"), true)
    add_child(handle)

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
    banner.add_theme_color_override("font_shadow_color", Color("#111a27"))
    banner.add_theme_constant_override("shadow_offset_x", 5)
    banner.add_theme_constant_override("shadow_offset_y", 5)
    layer.add_child(banner)

func _update_player(delta: float) -> void:
    var direction := mouse_world_position - player.global_position
    direction.y = 0
    if direction.length() > 0.6:
        direction = direction.normalized()
        player_facing = direction
        _aim_actor(player, direction)
    else:
        direction = Vector3.ZERO
    player.velocity = direction * PLAYER_SPEED
    player.move_and_slide()
    player.position.y = 0.8
    for civilian in civilians.duplicate():
        if is_instance_valid(civilian) and player.global_position.distance_to(civilian.global_position) <= 1.2:
            _recruit(civilian)

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
    if state != "playing":
        return
    _actor_shoot(player, player_facing, colors.shot, "player")

func _update_allies(delta: float) -> void:
    for index in range(allies.size()):
        var ally: Dictionary = allies[index]
        var node: CharacterBody3D = ally.node
        var angle := float(index) * 1.1 + Time.get_ticks_msec() * 0.001
        var target := player.global_position + Vector3(cos(angle) * 2.0, 0.0, sin(angle) * 2.0)
        var ally_direction := target - node.global_position
        ally_direction.y = 0
        if ally_direction.length() > 0.1:
            node.velocity = ally_direction.normalized() * 5.0
            node.move_and_slide()
        else:
            node.velocity = Vector3.ZERO
        var target_enemy := _nearest_enemy(node.global_position, 14.0)
        if target_enemy:
            var direction: Vector3 = (target_enemy.global_position - node.global_position).normalized()
            direction.y = 0
            direction = direction.normalized()
            _aim_actor(node, direction)
            _actor_shoot(node, direction, colors.ally, "ally")
        allies[index] = ally

func _update_enemies(delta: float) -> void:
    for enemy in enemies.duplicate():
        if not is_instance_valid(enemy):
            enemies.erase(enemy)
            continue
        var direction: Vector3 = player.global_position - enemy.global_position
        direction.y = 0
        if direction.length() > 0.1:
            var enemy_direction := _get_enemy_direction(enemy, direction.normalized())
            enemy.velocity = enemy_direction * (2.0 + enemies.size() * 0.03)
            enemy.move_and_slide()
            _aim_actor(enemy, enemy_direction)
            for ally in allies.duplicate():
                if is_instance_valid(ally.node) and enemy.global_position.distance_to(ally.node.global_position) < 1.15:
                    _kill_ally(ally.node)
                    message = "A horda capturou um recruta."
                    break
        if enemy.global_position.distance_to(player.global_position) < 1.15:
            _lose("A horda alcancou voce.")

func _get_enemy_direction(enemy: CharacterBody3D, direct_direction: Vector3) -> Vector3:
    if not _enemy_path_blocked(enemy.global_position, direct_direction, 1.5):
        return direct_direction
    var left_direction := Vector3(-direct_direction.z, 0, direct_direction.x).normalized()
    var right_direction := -left_direction
    var left_clear := not _enemy_path_blocked(enemy.global_position, left_direction, 1.4)
    var right_clear := not _enemy_path_blocked(enemy.global_position, right_direction, 1.4)
    if left_clear and right_clear:
        var player_offset := player.global_position - enemy.global_position
        return left_direction if left_direction.dot(player_offset) > right_direction.dot(player_offset) else right_direction
    if left_clear:
        return left_direction
    if right_clear:
        return right_direction
    return -direct_direction

func _enemy_path_blocked(origin: Vector3, direction: Vector3, distance: float) -> bool:
    var query := PhysicsRayQueryParameters3D.create(origin + Vector3(0, 0.8, 0), origin + Vector3(0, 0.8, 0) + direction * distance)
    query.collision_mask = 5
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and hit.collider is StaticBody3D

func _update_projectiles(delta: float) -> void:
    for projectile in projectiles.duplicate():
        var node: Node3D = projectile.node
        if not is_instance_valid(node):
            projectiles.erase(projectile)
            continue
        var previous_position: Vector3 = node.global_position
        var next_position: Vector3 = previous_position + projectile.velocity * delta
        if _projectile_hits_wall(previous_position, next_position):
            projectiles.erase(projectile)
            node.queue_free()
            continue
        node.global_position = next_position
        projectile.life -= delta
        var hit := false
        if projectile.target_type == "player":
            for civilian in civilians.duplicate():
                if _projectile_hits_actor(node, civilian):
                    _recruit(civilian)
                    hit = true
                    break
        if not hit and (projectile.target_type == "player" or projectile.target_type == "ally"):
            for enemy in enemies.duplicate():
                if _projectile_hits_actor(node, enemy):
                    _damage_enemy(enemy, int(projectile.damage))
                    if float(projectile.splash_radius) > 0:
                        for nearby_enemy in enemies.duplicate():
                            if nearby_enemy != enemy and node.global_position.distance_to(nearby_enemy.global_position) <= float(projectile.splash_radius):
                                _damage_enemy(nearby_enemy, int(projectile.damage))
                    hit = true
                    break
        if hit or projectile.life <= 0:
            projectiles.erase(projectile)
            node.queue_free()
        else:
            var projectile_index := projectiles.find(projectile)
            if projectile_index >= 0:
                projectiles[projectile_index] = projectile

func _damage_enemy(enemy: Node3D, damage: int) -> void:
    var remaining_health: int = int(enemy.get_meta("health", 1)) - damage
    enemy.set_meta("health", remaining_health)
    if remaining_health <= 0:
        enemies.erase(enemy)
        enemy.queue_free()
        enemies_defeated += 1
        message = "Inimigo dispersado!"

func _actor_shoot(actor: Node3D, direction: Vector3, color: Color, target_type: String) -> void:
    if quad_shot:
        for angle in [-0.12, -0.04, 0.04, 0.12]:
            _spawn_actor_projectile(actor, direction.rotated(Vector3.UP, angle).normalized(), color, target_type, "quad_confetti")
    elif double_shot:
        var left_direction := direction.rotated(Vector3.UP, -0.08).normalized()
        var right_direction := direction.rotated(Vector3.UP, 0.08).normalized()
        _spawn_actor_projectile(actor, left_direction, color, target_type, "double_confetti")
        _spawn_actor_projectile(actor, right_direction, color, target_type, "double_confetti")
    else:
        _spawn_actor_projectile(actor, direction, color, target_type, weapon_mode)

func _spawn_actor_projectile(actor: Node3D, direction: Vector3, color: Color, target_type: String, projectile_type: String) -> void:
    var origin := actor.global_position + actor.basis * Vector3(0, 1.02, -0.92)
    var damage := 1
    var splash_radius := 0.0
    if projectile_type == "popcorn":
        damage = 2
    elif projectile_type == "toilet_roll":
        splash_radius = 2.0
    elif projectile_type == "bubble":
        damage = 3
    _spawn_projectile(origin, direction, color, target_type, damage, splash_radius)

func _spawn_projectile(origin: Vector3, direction: Vector3, color: Color, target_type: String, damage: int = 1, splash_radius: float = 0.0) -> void:
    var node := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.16
    mesh.height = 0.32
    node.mesh = mesh
    node.material_override = _material(color, true)
    node.position = origin
    add_child(node)
    projectiles.append({"node": node, "velocity": direction.normalized() * SHOT_SPEED, "life": 2.0, "target_type": target_type, "damage": damage, "splash_radius": splash_radius})

func _projectile_hits_actor(projectile: Node3D, actor: Node3D) -> bool:
    var actor_center := actor.global_position + Vector3(0, 0.45, 0)
    return projectile.global_position.distance_to(actor_center) <= ACTOR_HIT_RADIUS

func _recruit(civilian: Node3D) -> void:
    civilians.erase(civilian)
    var ally := {"node": civilian}
    _set_actor_color(civilian, colors.ally)
    allies.append(ally)
    recruits_count += 1
    message = "+1 recrutado pelo disparo."

func _kill_ally(ally_node: CharacterBody3D) -> void:
    for ally in allies.duplicate():
        if ally.node == ally_node:
            allies.erase(ally)
            break
    ally_node.collision_layer = 0
    ally_node.collision_mask = 0
    var fall_tween := create_tween()
    fall_tween.set_parallel(true)
    fall_tween.tween_property(ally_node, "rotation_degrees:z", 88.0, 0.35)
    fall_tween.tween_property(ally_node, "position:y", 0.15, 0.35)
    fall_tween.set_parallel(false)
    fall_tween.tween_interval(0.25)
    fall_tween.tween_callback(ally_node.queue_free)

func _projectile_hits_wall(from_position: Vector3, to_position: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(from_position, to_position)
    query.exclude = [player]
    query.collision_mask = 1
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and hit.collider is StaticBody3D

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
    var positions := [Vector3(-30, 0.8, -24), Vector3(-22, 0.8, -20), Vector3(-14, 0.8, -10), Vector3(-7, 0.8, -10), Vector3(0, 0.8, -10), Vector3(10, 0.8, -18), Vector3(22, 0.8, -20), Vector3(30, 0.8, -16), Vector3(-30, 0.8, -2), Vector3(-14, 0.8, 2), Vector3(-4, 0.8, 5), Vector3(8, 0.8, 4), Vector3(18, 0.8, 2), Vector3(30, 0.8, 4), Vector3(-26, 0.8, 18), Vector3(-12, 0.8, 20), Vector3(4, 0.8, 18), Vector3(20, 0.8, 20)]
    for position in positions:
        var civilian := _create_actor(position, colors.civilian, "Civilian")
        civilians.append(civilian)

func _spawn_furniture() -> void:
    var table_positions := [Vector3(-12, 0, -7), Vector3(-4, 0, -11), Vector3(4, 0, -5), Vector3(-12, 0, 6), Vector3(2, 0, 5), Vector3(12, 0, 9)]
    for position in table_positions:
        _create_table_and_chairs(position)

func _create_table_and_chairs(position: Vector3) -> void:
    _create_box(position + Vector3(0, 1.1, 0), Vector3(3.2, 0.25, 1.8), colors.obstacle, true, 4)
    for offset in [Vector3(-1.25, 0.5, -0.65), Vector3(1.25, 0.5, -0.65), Vector3(-1.25, 0.5, 0.65), Vector3(1.25, 0.5, 0.65)]:
        _create_box(position + offset, Vector3(0.2, 1.0, 0.2), colors.obstacle, true, 4)
    for offset in [Vector3(-2.1, 0.45, 0), Vector3(2.1, 0.45, 0)]:
        _create_box(position + offset, Vector3(0.9, 0.15, 0.9), colors.wall, true, 4)
        _create_box(position + offset + Vector3(0, -0.45, 0), Vector3(0.12, 0.8, 0.12), colors.wall, true, 4)

func _spawn_weapon_upgrades() -> void:
    _create_pickup(Vector3(-24, 0.45, -18), "popcorn", Color("#f6c453"))
    _create_pickup(Vector3(-2, 0.45, 16), "double_confetti", Color("#ed6bd1"))
    _create_pickup(Vector3(20, 0.45, -4), "toilet_roll", Color("#f4f1e8"))
    _create_pickup(Vector3(30, 0.45, 18), "bubble", Color("#76d7ea"))
    _create_pickup(Vector3(-30, 0.45, 10), "quad_confetti", Color("#ff7fbd"))

func _create_pickup(position: Vector3, upgrade_type: String, color: Color) -> void:
    var pickup := Node3D.new()
    pickup.position = position
    pickup.set_meta("upgrade_type", upgrade_type)
    if upgrade_type == "popcorn":
        _add_pickup_sphere(pickup, Vector3(-0.24, 0.15, 0), 0.22, Color("#fff0a3"))
        _add_pickup_sphere(pickup, Vector3(0.18, 0.18, 0.08), 0.25, color)
        _add_pickup_sphere(pickup, Vector3(0.02, 0.42, -0.04), 0.2, Color("#ffe07a"))
    elif upgrade_type == "toilet_roll":
        var roll := MeshInstance3D.new()
        var roll_mesh := CylinderMesh.new()
        roll_mesh.top_radius = 0.34
        roll_mesh.bottom_radius = 0.34
        roll_mesh.height = 0.42
        roll.mesh = roll_mesh
        roll.material_override = _material(color, true)
        roll.rotation_degrees.z = 90
        pickup.add_child(roll)
        var inner := MeshInstance3D.new()
        var inner_mesh := CylinderMesh.new()
        inner_mesh.top_radius = 0.12
        inner_mesh.bottom_radius = 0.12
        inner_mesh.height = 0.44
        inner.mesh = inner_mesh
        inner.material_override = _material(Color("#bd8a58"), true)
        inner.rotation_degrees.z = 90
        pickup.add_child(inner)
    elif upgrade_type == "bubble":
        _add_pickup_sphere(pickup, Vector3.ZERO, 0.5, color)
    else:
        var confetti_angles := [-0.5, -0.17, 0.17, 0.5] if upgrade_type == "quad_confetti" else [-0.3, 0.3]
        for index in range(confetti_angles.size()):
            var tube := MeshInstance3D.new()
            var tube_mesh := CylinderMesh.new()
            tube_mesh.top_radius = 0.07
            tube_mesh.bottom_radius = 0.07
            tube_mesh.height = 0.7
            tube.mesh = tube_mesh
            tube.material_override = _material(Color.from_hsv(float(index) / confetti_angles.size(), 0.8, 1.0), true)
            tube.position = Vector3(confetti_angles[index], 0.15, 0)
            tube.rotation_degrees.z = confetti_angles[index] * 55.0
            pickup.add_child(tube)
    add_child(pickup)
    pickups.append({"node": pickup, "type": upgrade_type})

func _add_pickup_sphere(parent: Node3D, sphere_position: Vector3, radius: float, color: Color) -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    mesh.mesh = sphere
    mesh.material_override = _material(color, true)
    mesh.position = sphere_position
    parent.add_child(mesh)

func _update_pickups() -> void:
    for pickup in pickups.duplicate():
        var node: Node3D = pickup.node
        if not is_instance_valid(node):
            pickups.erase(pickup)
            continue
        node.rotation.y += 0.025
        if player.global_position.distance_to(node.global_position) <= 1.2:
            _apply_upgrade(str(pickup.type))
            pickups.erase(pickup)
            node.queue_free()

func _apply_upgrade(upgrade_type: String) -> void:
    if upgrade_type == "quad_confetti":
        quad_shot = true
        double_shot = false
        message = "Upgrade: rajada quadrupla para toda a equipe."
    elif upgrade_type == "popcorn":
        weapon_mode = "popcorn"
        double_shot = false
        quad_shot = false
        message = "Upgrade: pipoca! Dano dobrado."
    elif upgrade_type == "double_confetti":
        double_shot = true
        quad_shot = false
        message = "Upgrade: confete duplo para toda a equipe."
    elif upgrade_type == "toilet_roll":
        weapon_mode = "toilet_roll"
        double_shot = false
        quad_shot = false
        message = "Upgrade: rolo de papel! Atinge inimigos proximos."
    elif upgrade_type == "bubble":
        weapon_mode = "bubble"
        double_shot = false
        quad_shot = false
        message = "Upgrade: bolha pesada!"

func _spawn_windows() -> void:
    for x in [-10.0, 0.0, 10.0]:
        var opening := MeshInstance3D.new()
        var opening_mesh := BoxMesh.new()
        opening_mesh.size = Vector3(4.0, 2.0, 0.08)
        opening.mesh = opening_mesh
        opening.material_override = _material(Color("#172333"), true)
        opening.position = Vector3(x, 1.8, -31.48)
        add_child(opening)
        for frame_x in [x - 2.1, x + 2.1]:
            _create_box(Vector3(frame_x, 1.8, -31.42), Vector3(0.22, 2.4, 0.3), colors.obstacle, false)
        _create_box(Vector3(x, 3.0, -31.42), Vector3(4.4, 0.22, 0.3), colors.obstacle, false)
        _create_box(Vector3(x, 0.6, -31.42), Vector3(4.4, 0.22, 0.3), colors.obstacle, false)

func _update_horde_spawns(delta: float) -> void:
    horde_spawn_timer -= delta
    if horde_spawn_timer > 0 or enemies.size() >= MAX_ENEMIES:
        return
    var spawn_position := _get_horde_spawn_position()
    enemies.append(_create_enemy(spawn_position))
    horde_spawn_timer = HORDE_SPAWN_INTERVAL

func _get_horde_spawn_position() -> Vector3:
    if randf() < 0.7:
        var exit_offsets := [Vector3(-2.5, 0.8, 0), Vector3(0, 0.8, 2.5), Vector3(2.5, 0.8, 0)]
        return exit_position + exit_offsets[randi() % exit_offsets.size()]
    var window_x: float = [-10.0, 0.0, 10.0][randi() % 3]
    return Vector3(window_x, 0.8, -30.7)

func _spawn_enemies() -> void:
    var positions := [exit_position + Vector3(0, 0.8, -3.0), Vector3(-10, 0.8, -30.7), Vector3(0, 0.8, -30.7), Vector3(10, 0.8, -30.7), Vector3(18, 0.8, -12), Vector3(16, 0.8, 8), Vector3(4, 0.8, -12), Vector3(-18, 0.8, -5), Vector3(12, 0.8, 0), Vector3(-18, 0.8, 12), Vector3(0, 0.8, 14), Vector3(18, 0.8, 12), Vector3(-20, 0.8, -12)]
    enemies.append(_create_enemy(positions[0], "ceo"))
    for index in range(1, positions.size()):
        enemies.append(_create_enemy(positions[index]))

func _create_enemy(position: Vector3, forced_type: String = "") -> CharacterBody3D:
    var enemy_types := ["pawn", "pawn", "pawn", "pawn", "pawn", "section_chief", "manager", "director"]
    var enemy_type: String = forced_type if forced_type != "" else enemy_types[randi() % enemy_types.size()]
    if enemy_type == "ceo":
        ceo_spawned = true
    return _create_actor(position, colors.enemy, "Horde", enemy_type)

func _create_actor(position: Vector3, color: Color, actor_name: String, enemy_type: String = "civilian") -> CharacterBody3D:
    var actor := CharacterBody3D.new()
    actor.name = actor_name
    actor.position = position
    var actor_scale := 1.0
    var health := 1
    var display_name := "Funcionario / Employee"
    if enemy_type == "pawn":
        display_name = "Peao / Pawn"
    elif enemy_type == "section_chief":
        display_name = "Chefe de Setor / Section Chief"
        health = 3
        actor_scale = 1.2
    elif enemy_type == "manager":
        display_name = "Gerente / Manager"
        health = 6
        actor_scale = 1.4
    elif enemy_type == "director":
        display_name = "Diretor / Director"
        health = 12
        actor_scale = 2.0
    elif enemy_type == "ceo":
        display_name = "Diretor Executivo / CEO"
        health = 48
        actor_scale = 4.0
    _add_actor_mesh(actor, color, 0.45, "hammer" if enemy_type != "civilian" else "confetti", actor_scale, enemy_type)
    actor.scale = Vector3.ONE * actor_scale
    actor.set_meta("health", health)
    actor.set_meta("enemy_type", enemy_type)
    actor.set_meta("display_name", display_name)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.45
    collision.shape = shape
    collision.position.y = 0.75
    actor.add_child(collision)
    actor.collision_layer = 2
    actor.collision_mask = 5
    add_child(actor)
    return actor

func _add_actor_mesh(parent: Node3D, color: Color, radius: float, weapon_type: String = "confetti", actor_scale: float = 1.0, enemy_type: String = "civilian") -> void:
    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.3
    body_mesh.height = 0.85
    body.mesh = body_mesh
    body.name = "Body"
    body.material_override = _material(color, true)
    body.position.y = 0.95
    parent.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = radius * 0.78
    head_mesh.height = radius * 1.56
    head.mesh = head_mesh
    head.name = "Head"
    head.material_override = _material(Color("#f2b38c"), true)
    head.position.y = 1.72
    if enemy_type == "section_chief":
        head.scale = Vector3(1.15, 0.9, 1.15)
    elif enemy_type == "manager":
        head.scale = Vector3(1.25, 0.8, 1.25)
    elif enemy_type == "director":
        head.scale = Vector3(1.35, 0.75, 1.35)
    elif enemy_type == "ceo":
        head.scale = Vector3(1.5, 0.7, 1.5)
    parent.add_child(head)

    if enemy_type != "pawn" and enemy_type != "civilian":
        var hat := MeshInstance3D.new()
        var hat_mesh := CylinderMesh.new()
        hat_mesh.top_radius = 0.25 + actor_scale * 0.04
        hat_mesh.bottom_radius = 0.38 + actor_scale * 0.05
        hat_mesh.height = 0.22 + actor_scale * 0.03
        hat.mesh = hat_mesh
        hat.name = "RankHat"
        hat.position.y = 2.12
        hat.material_override = _material(Color("#24364b") if enemy_type != "ceo" else Color("#d5a928"), true)
        parent.add_child(hat)
        if enemy_type == "ceo":
            var crest := MeshInstance3D.new()
            var crest_mesh := BoxMesh.new()
            crest_mesh.size = Vector3(0.28, 0.5, 0.12)
            crest.mesh = crest_mesh
            crest.name = "CEOCrest"
            crest.position = Vector3(0, 2.38, 0)
            crest.material_override = _material(Color("#f4d35e"), true)
            parent.add_child(crest)

    var left_leg := _create_limb("LeftLeg", Vector3(-0.18, 0.35, 0.0), 0.13, 0.68, color)
    left_leg.rotation_degrees.z = -8
    parent.add_child(left_leg)
    var right_leg := _create_limb("RightLeg", Vector3(0.18, 0.35, 0.08), 0.13, 0.68, color)
    right_leg.rotation_degrees.z = 8
    parent.add_child(right_leg)

    var left_arm := _create_limb("LeftArm", Vector3(-0.42, 1.05, -0.02), 0.1, 0.62, color)
    left_arm.rotation_degrees.z = -42
    parent.add_child(left_arm)
    var right_arm := _create_limb("RightArm", Vector3(0.42, 1.05, -0.02), 0.1, 0.62, color)
    right_arm.rotation_degrees.z = 42
    parent.add_child(right_arm)

    if weapon_type == "hammer":
        var hammer_handle := MeshInstance3D.new()
        var handle_mesh := CylinderMesh.new()
        handle_mesh.top_radius = 0.06
        handle_mesh.bottom_radius = 0.06
        handle_mesh.height = 0.55
        hammer_handle.mesh = handle_mesh
        hammer_handle.name = "ToyHammerHandle"
        hammer_handle.material_override = _material(Color("#f0a35b"), true)
        hammer_handle.position = Vector3(0.43, 1.18, -0.18)
        hammer_handle.rotation_degrees.x = 65
        parent.add_child(hammer_handle)
        var hammer_head := MeshInstance3D.new()
        var hammer_mesh := BoxMesh.new()
        hammer_mesh.size = Vector3(0.38, 0.22, 0.22)
        hammer_head.mesh = hammer_mesh
        hammer_head.name = "ToyHammerHead"
        hammer_head.material_override = _material(Color("#ffcf4a"), true)
        hammer_head.position = Vector3(0.43, 1.42, -0.38)
        parent.add_child(hammer_head)
    else:
        var confetti_gun := MeshInstance3D.new()
        var gun_mesh := BoxMesh.new()
        gun_mesh.size = Vector3(0.16, 0.16, 0.48)
        confetti_gun.mesh = gun_mesh
        confetti_gun.name = "ConfettiGun"
        confetti_gun.material_override = _material(Color("#ffd166"), true)
        confetti_gun.position = Vector3(0.42, 1.12, -0.3)
        parent.add_child(confetti_gun)

func _aim_actor(actor: Node3D, direction: Vector3) -> void:
    actor.rotation.y = atan2(-direction.x, -direction.z)

func _create_limb(limb_name: String, limb_position: Vector3, limb_radius: float, limb_height: float, color: Color) -> MeshInstance3D:
    var limb := MeshInstance3D.new()
    var limb_mesh := CapsuleMesh.new()
    limb_mesh.radius = limb_radius
    limb_mesh.height = limb_height
    limb.mesh = limb_mesh
    limb.name = limb_name
    limb.material_override = _material(color, true)
    limb.position = limb_position
    return limb

func _set_actor_color(actor: Node3D, color: Color) -> void:
    for part_name in ["Body", "LeftLeg", "RightLeg", "LeftArm", "RightArm"]:
        var part := actor.get_node_or_null(part_name) as MeshInstance3D
        if part:
            part.material_override = _material(color, true)

func _animate_actor_legs() -> void:
    var moving_actors: Array[Node3D] = [player]
    for ally in allies:
        moving_actors.append(ally.node)
    for enemy in enemies:
        moving_actors.append(enemy)
    var time := Time.get_ticks_msec() * 0.012
    for index in range(moving_actors.size()):
        var actor := moving_actors[index]
        if not is_instance_valid(actor):
            continue
        var left_leg := actor.get_node_or_null("LeftLeg") as Node3D
        var right_leg := actor.get_node_or_null("RightLeg") as Node3D
        if left_leg and right_leg:
            var stride := sin(time + float(index) * 0.8) * 0.45
            left_leg.rotation.x = stride
            right_leg.rotation.x = -stride
        if actor.has_meta("enemy_type"):
            var hammer_head := actor.get_node_or_null("ToyHammerHead") as Node3D
            var hammer_handle := actor.get_node_or_null("ToyHammerHandle") as Node3D
            if hammer_head and hammer_handle:
                var hammer_swing := sin(time * 1.8 + float(index)) * 0.65
                hammer_head.rotation.x = hammer_swing
                hammer_handle.rotation.x = 1.13 + hammer_swing

func _create_box(position: Vector3, size: Vector3, color: Color, solid: bool, collision_layer: int = 1) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = position
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = _material(color, false)
    body.add_child(mesh)
    if solid:
        body.collision_layer = collision_layer
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
    _check_team_exit()

func _check_team_exit() -> void:
    if state != "playing" or not player:
        return
    if player.global_position.distance_to(exit_position) > 2.2:
        return
    for ally in allies:
        if is_instance_valid(ally.node) and ally.node.global_position.distance_to(exit_position) > 2.2:
            return
    state = "won"
    message = "Sucesso! Toda a equipe alcancou a saida."

func _lose(text: String) -> void:
    if state == "playing":
        state = "lost"
        message = text

func _update_hud() -> void:
    if not hud:
        return
    var weapon_name := "Confete"
    if quad_shot:
        weapon_name = "Rajada quadrupla"
    elif double_shot:
        weapon_name = "Confete duplo"
    elif weapon_mode == "popcorn":
        weapon_name = "Pipoca"
    elif weapon_mode == "toilet_roll":
        weapon_name = "Rolo de papel"
    elif weapon_mode == "bubble":
        weapon_name = "Bolha"
    hud.text = "CROWD PARTY 3D\nRecrutas: %d   Inimigos vivos: %d   Mortos: %d\nArma: %s\nMouse mover/apontar   Clique ou ESPACO atirar   R reiniciar   ESC liberar mouse\n%s" % [recruits_count, enemies.size(), enemies_defeated, weapon_name, message]
    if state == "countdown":
        banner.text = str(maxi(1, ceili(countdown_remaining)))
        banner.add_theme_font_size_override("font_size", 112)
    elif state == "won":
        banner.add_theme_font_size_override("font_size", 36)
        banner.text = "SUCESSO!\nRecrutas: %d   Inimigos mortos: %d\nPressione R para jogar novamente" % [recruits_count, enemies_defeated]
    elif state == "lost":
        banner.add_theme_font_size_override("font_size", 48)
        banner.text = "A HORDA VENCEU\nPressione R para tentar novamente"
    else:
        banner.add_theme_font_size_override("font_size", 32)
        banner.text = ""
