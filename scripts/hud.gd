extends CanvasLayer

const Game = preload("res://scripts/game.gd")
const Weapons = preload("res://scripts/weapons.gd")
const UI = preload("res://scripts/pixel_ui.gd")

@onready var game = get_parent()
var _canvas := Control.new()
var _icons := Weapons.DATA.map(func(wd): return load(wd.tex))
var _selected := 0
var _buttons := {}
var _banner := ""
var _banner_color := Color.WHITE
var _banner_left := 0.0


func _ready() -> void:
	UI.setup()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(delta: float) -> void:
	if not get_tree().paused:
		_banner_left -= delta
	_canvas.queue_redraw()


func banner(text: String, color: Color) -> void:
	_banner = text
	_banner_color = color
	_banner_left = 1.5


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in _buttons:
			if _buttons[id].has_point(_canvas.get_local_mouse_position()):
				_press(id)
				return
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		match game.state:
			Game.State.MENU:
				if key in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
					_selected = wrapi(_selected + (1 if key in [KEY_RIGHT, KEY_D] else -1), 0, 3)
				elif key == KEY_ENTER:
					_press("fight")
			Game.State.PLAYING:
				if key == KEY_ESCAPE:
					get_tree().paused = not get_tree().paused
				elif key == KEY_Q and get_tree().paused:
					game.show_menu()
			Game.State.RESULTS:
				if key == KEY_ENTER:
					game.show_menu()


func _press(id) -> void:
	if id is int:
		_selected = id
		if game.is_playing() and not game.player.alive:
			game.player.equip_weapon(id)
	elif id == "fight":
		game.start_match(_selected)
	else:
		game.show_menu()


func _draw_hud() -> void:
	_buttons.clear()
	var vs := _canvas.size
	var mid := UI.snap(vs.x * 0.5)
	match game.state:
		Game.State.MENU:
			_draw_menu(vs)
		Game.State.RESULTS:
			var won: bool = game.scores[0] > game.scores[1]
			var r := Rect2(mid - 200, UI.snap(vs.y * 0.5 - 110.0), 400, 220)
			UI.panel(_canvas, r)
			UI.text_centered(_canvas, mid, r.position.y + 20, "VICTORY" if won else "DEFEAT", 8, UI.BLUE if won else Color.RED, UI.INK if won else Color.TRANSPARENT)
			UI.text_centered(_canvas, mid, r.position.y + 96, "%d - %d" % game.scores, 4, UI.INK)
			_button(Rect2(mid - 104, r.end.y - 64, 208, 48), "again", "PLAY AGAIN", 2)
		_:
			_draw_match(vs, mid)


func _button(r: Rect2, id: String, label: String, scale: int) -> void:
	_buttons[id] = r
	UI.button(_canvas, r, label, scale)


func _draw_match(vs: Vector2, mid: float) -> void:
	var c := _canvas
	var xf := get_viewport().get_canvas_transform()
	for f in game.fighters:
		if not f.alive or f.team != 0 and f.modulate.a < 0.5:
			continue
		var p: Vector2 = (xf * (f.position + Vector2(0, -40))).round()
		var bar := Rect2(p.x - 30, p.y - 10, 60, 10)
		UI.bar(c, bar, f.hp / f.max_hp, UI.GREEN if f.is_player else game.TEAM_COLORS[f.team])
		if f.is_player:
			for i in 3:
				UI.bar(c, Rect2(bar.position.x + i * 21.0, bar.end.y + 2, 18, 6), f.ammo - i, UI.ORANGE)

	var r := Rect2(mid - 100, 8, 200, 44)
	UI.panel(c, r, UI.PAPER, true)
	for team in 2:
		UI.text_centered(c, mid - 66 + team * 132, 20, str(game.scores[team]), 3, game.TEAM_COLORS[team])

	var y := UI.snap(vs.y * 0.24)
	if _banner_left > 0.0:
		UI.text_centered(c, mid, y, _banner, 8 if _banner.length() <= 10 else 4, _banner_color, Color.TRANSPARENT if _banner == "KNOCKED OUT" else UI.INK)
	if not game.player.alive:
		for i in 3:
			var slot := Rect2(mid - 224 + i * 160, UI.snap(vs.y - 132.0), 128, 112)
			var region: Rect2 = Weapons.DATA[i].region
			_buttons[i] = slot
			c.draw_texture_rect_region(_icons[i], Rect2((slot.get_center() - region.size).round(), region.size * 2), region)
	if get_tree().paused:
		UI.text_centered(c, mid, y + 80, "PAUSED", 6, UI.PAPER_LIGHT, UI.INK)
		UI.text_centered(c, mid, y + 150, "ESC  RESUME     Q  QUIT", 2, UI.PAPER_LIGHT, UI.INK)


func _draw_menu(vs: Vector2) -> void:
	var c := _canvas
	var r := Rect2(UI.snap((vs.x - 704.0) * 0.5), maxf(96.0, UI.snap((vs.y - 220.0) * 0.5)), 704, 220)
	UI.text(c, r.position - Vector2(0, 80), "CLASH PIT", 8, UI.PAPER_LIGHT, UI.INK)
	UI.panel(c, r)

	for i in 3:
		var card := Rect2(r.position.x + 8 + i * 232, r.position.y + 8, 224, 140)
		var region: Rect2 = Weapons.DATA[i].region
		_buttons[i] = card
		if i == _selected:
			c.draw_rect(card, UI.INK)
		c.draw_texture_rect_region(_icons[i], Rect2((card.get_center() - region.size - Vector2(0, 12)).round(), region.size * 2), region)
		UI.text_centered(c, card.get_center().x, card.end.y - 28, Weapons.DATA[i].name, 2, UI.PAPER_LIGHT if i == _selected else UI.INK)

	_button(Rect2(Vector2(r.get_center().x - 104, r.end.y - 64), Vector2(208, 48)), "fight", "FIGHT", 3)
