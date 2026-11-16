extends CharacterBody2D

const Weapons = preload("res://scripts/weapons.gd")
const Projectile = preload("res://scripts/projectile.gd")

const MAX_AMMO := 3.0
const HIT_RADIUS := 22.0
const CENTER := Vector2(0, 8)

var game: Node
var team := 0
var team_color := Color.WHITE
var is_player := false
var speed_scale := 1.0
var weapon_type := 0
var w: Dictionary
var spawn_point := Vector2.ZERO

var hp := 0.0
var max_hp := 0.0
var ammo := MAX_AMMO
var alive := true
var move_input := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var respawn_timer := 0.0
var shield_timer := 0.0
var reveal_timer := 0.0
var in_grass := false
var hidden_from_enemy := false

var _cooldown := 0.0
var _calm := 0.0
var _move_vel := Vector2.ZERO
var _knock := Vector2.ZERO
var _burst := 0
var _burst_timer := 0.0
var _ball := 0
var _aim_end := Vector2.ZERO

@onready var body: Sprite2D = $Body
@onready var pivot: Node2D = $WeaponPivot


func setup(cfg: Dictionary, weapon: int, game_ref: Node, spawn: Vector2) -> void:
	game = game_ref
	team = cfg.team
	team_color = game.TEAM_COLORS[team]
	spawn_point = spawn
	_ball = randi() % Weapons.BALLS.size()
	body.texture = load(cfg.tex)
	body.region_rect = cfg.get("region", game.DEFAULT_REGION)
	body.offset.y = floorf((game.DEFAULT_REGION.size.y - body.region_rect.size.y) * 0.5)
	equip_weapon(weapon)
	_respawn()


func equip_weapon(weapon: int) -> void:
	weapon_type = weapon
	w = Weapons.DATA[weapon]
	max_hp = w.max_hp
	var sprite: Sprite2D = $WeaponPivot/Weapon
	sprite.texture = load(w.tex)
	sprite.region_rect = w.region
	sprite.offset = w.offset
	sprite.rotation = w.sprite_rot
	sprite.position = w.sprite_pos


func _physics_process(delta: float) -> void:
	if not alive:
		respawn_timer -= delta
		if respawn_timer <= 0.0 and game.is_playing():
			_respawn()
		return
	if is_player and game.is_playing():
		_read_input()

	_cooldown -= delta
	shield_timer -= delta
	reveal_timer -= delta
	_calm += delta
	ammo = minf(MAX_AMMO, ammo + delta / w.reload)
	if _calm > 3.0:
		hp = minf(max_hp, hp + max_hp * 0.14 * delta)

	if _burst > 0:
		_burst_timer -= delta
		while _burst > 0 and _burst_timer <= 0.0:
			_burst_timer += 0.055
			_burst -= 1
			_fire_bullet()
		_cooldown = maxf(_cooldown, 0.12)

	var speed: float = w.speed * speed_scale
	_move_vel = _move_vel.move_toward(move_input.limit_length(1.0) * speed, 1900.0 * delta)
	velocity = _move_vel + _knock
	move_and_slide()
	_knock = _knock.move_toward(Vector2.ZERO, 1800.0 * delta)

	if is_player:
		var start := position + CENTER
		var end: Vector2 = start + aim_dir * w.reach
		_aim_end = game.wall_ray(start, end).get("position", end) - position


func _read_input() -> void:
	move_input = Input.get_vector("left", "right", "up", "down")
	var to_mouse := get_global_mouse_position() - position - CENTER
	if to_mouse.length() > 8.0:
		aim_dir = to_mouse.normalized()
	if Input.is_action_pressed("fire"):
		try_attack()


func _process(_delta: float) -> void:
	if not alive:
		return
	if absf(aim_dir.x) > 0.12:
		body.flip_h = aim_dir.x < 0.0
	pivot.scale.y = -1.0 if aim_dir.x < 0.0 else 1.0
	pivot.rotation = aim_dir.angle()
	pivot.show_behind_parent = aim_dir.y < -0.35
	modulate.a = 0.0 if hidden_from_enemy and team != 0 else (0.7 if in_grass else 1.0)
	queue_redraw()


func _draw() -> void:
	if not alive:
		return

	if is_player and game.is_playing():
		var tint := Color(1, 1, 1, 0.16 if can_attack() or _burst > 0 else 0.07)
		if weapon_type == Weapons.Type.SWORD:
			var reach: float = w.reach + 14.0
			var half := deg_to_rad(w.arc * 0.5)
			draw_arc(CENTER, reach * 0.5, aim_dir.angle() - half, aim_dir.angle() + half, 16, tint, reach)
		else:
			draw_line(CENTER, _aim_end, tint, 28.0)
			draw_line(CENTER, _aim_end, Color(1, 1, 1, tint.a * 1.8), 2.0)


func can_attack() -> bool:
	return alive and _cooldown <= 0.0 and ammo >= 1.0 and _burst <= 0


func try_attack() -> void:
	if not can_attack():
		return
	ammo -= 1.0
	_cooldown = w.cooldown
	_calm = 0.0
	reveal_timer = 0.8
	match weapon_type:
		Weapons.Type.GUN:
			_burst = 4
			_burst_timer = 0.0
		Weapons.Type.SWORD:
			_slash()
		Weapons.Type.LAUNCHER:
			_fire_ball(aim_dir.rotated(-0.06))
			_fire_ball(aim_dir.rotated(0.06))


func _launch(dir: Vector2, damage: float, speed: float, reach: float) -> Projectile:
	var p := Projectile.new()
	p.game = game
	p.shooter = self
	p.team = team
	p.damage = damage
	p.velocity = dir * speed
	p.life = reach / speed
	var tip := position + CENTER + aim_dir * float(w.muzzle)
	var hit: Dictionary = game.wall_ray(position + CENTER, tip)
	p.position = tip if hit.is_empty() else hit.position - aim_dir * 4.0
	game.effects.add_child(p)
	return p


func _fire_bullet() -> void:
	var dir := aim_dir.rotated(randf_range(-1.0, 1.0) * deg_to_rad(1.5))
	var p := _launch(dir, w.damage, w.proj_speed, w.reach)
	p.color = Color(0.75, 0.95, 1.0) if team == 0 else Color(1.0, 0.6, 0.35)


func _fire_ball(dir: Vector2) -> void:
	var p := _launch(dir, w.damage, w.proj_speed, w.reach)
	p.bounces = 3
	p.make_ball(Weapons.BALLS[_ball])
	_ball = (_ball + 1) % Weapons.BALLS.size()


func _slash() -> void:
	_knock += aim_dir * 240.0
	for e in game.fighters:
		var to: Vector2 = e.position - position
		if not e.alive or e.team == team or to.length() > w.reach + HIT_RADIUS:
			continue
		if to.length() > 34.0 and absf(aim_dir.angle_to(to)) > deg_to_rad(w.arc * 0.5):
			continue
		if game.has_los(position, e.position):
			e.take_damage(w.damage, self, aim_dir * 320.0)
	game.fx_slash(position + CENTER, aim_dir, w.reach + 14.0, w.arc, team_color)


func take_damage(amount: float, attacker, knock := Vector2.ZERO) -> void:
	if not alive or shield_timer > 0.0 or not game.is_playing():
		return
	amount = minf(amount, hp)
	hp -= amount
	_calm = 0.0
	reveal_timer = maxf(reveal_timer, 0.6)
	_knock += knock
	if not is_instance_valid(attacker):
		attacker = null
	if hp <= 0.0:
		alive = false
		visible = false
		respawn_timer = 4.0
		_burst = 0
		_knock = Vector2.ZERO
		_move_vel = Vector2.ZERO
		game.on_died(self, attacker)


func _respawn() -> void:
	position = spawn_point
	hp = max_hp
	ammo = MAX_AMMO
	alive = true
	visible = true
	shield_timer = 2.5
	reveal_timer = 0.0
	_cooldown = 0.0
	_calm = 0.0
	aim_dir = Vector2.RIGHT if team == 0 else Vector2.LEFT
