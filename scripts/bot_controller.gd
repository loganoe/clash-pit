extends Node

@onready var f = get_parent()
var _sidestep := Vector2.ZERO
var _wall_normal := Vector2.ZERO


func _physics_process(_delta: float) -> void:
	f.move_input = Vector2.ZERO
	if not f.alive or not f.game.is_playing():
		_sidestep = Vector2.ZERO
		return

	var target = null
	var nearest := INF
	for enemy in f.game.fighters:
		if not enemy.alive or enemy.team == f.team:
			continue
		var distance: float = f.position.distance_squared_to(enemy.position)
		if distance < nearest:
			nearest = distance
			target = enemy

	if target == null:
		_sidestep = Vector2.ZERO
		return
	f.aim_dir = f.position.direction_to(target.position)
	f.try_attack()

	var stop_distance: float = maxf(60.0, f.w.reach * 0.7)
	if nearest <= stop_distance * stop_distance:
		_sidestep = Vector2.ZERO
		return

	if f.get_slide_collision_count() > 0:
		var normal: Vector2 = f.get_slide_collision(0).get_normal()
		if _sidestep == Vector2.ZERO or normal != _wall_normal:
			_wall_normal = normal
			_sidestep = normal.orthogonal()
			if _sidestep.dot(f.aim_dir) < 0.0:
				_sidestep = -_sidestep
	elif _sidestep != Vector2.ZERO and not f.test_move(f.global_transform, -_wall_normal * 2.0):
		_sidestep = Vector2.ZERO
	f.move_input = _sidestep if _sidestep != Vector2.ZERO else f.aim_dir
