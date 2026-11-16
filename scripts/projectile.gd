extends Node2D

var game: Node
var shooter: Node
var team := 0
var velocity := Vector2.ZERO
var damage := 0.0
var life := 0.0
var bounces := 0
var radius := 5.0
var hit_radius := 14.0
var knock := 140.0
var color := Color.WHITE


func make_ball(ball: Dictionary) -> void:
	radius = 7.0
	hit_radius = 16.0
	knock = 220.0
	color = ball.color
	var sprite := Sprite2D.new()
	sprite.texture = load(ball.tex)
	sprite.region_enabled = true
	sprite.region_rect = ball.region
	add_child(sprite)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return

	var from := position
	var step := velocity * delta
	var to := from + step
	var hit: Dictionary = game.wall_ray(from, to + step.normalized() * radius)
	if not hit.is_empty():
		if bounces <= 0 or hit.normal == Vector2.ZERO:
			queue_free()
			return
		bounces -= 1
		velocity = velocity.bounce(hit.normal)
		to = hit.position + hit.normal * (radius + 1.0)

	for e in game.fighters:
		if not e.alive or e.team == team:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.position, from, to)
		if ((e.position - closest) * Vector2(1, 0.8)).length() <= hit_radius + e.HIT_RADIUS:
			e.take_damage(damage, shooter, velocity.normalized() * knock)
			queue_free()
			return
	position = to


func _draw() -> void:
	if get_child_count():
		return
	var dir := velocity.normalized()
	draw_line(-dir * 22.0, Vector2.ZERO, Color(color, 0.35), 7.0)
	draw_line(-dir * 14.0, Vector2.ZERO, color, 4.0)
	draw_circle(Vector2.ZERO, 3.5, Color.WHITE)
