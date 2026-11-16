extends RefCounted

const FONT: FontFile = preload("res://ui/clash_pixel.fnt")
const U := 2.0

const INK := Color(0.102, 0.086, 0.125)
const WELL := Color(0.227, 0.204, 0.259)
const PAPER := Color(0.945, 0.89, 0.741)
const PAPER_LIGHT := Color(1.0, 0.969, 0.878)
const BLUE := Color(0.184, 0.498, 0.839)
const RED := Color(0.839, 0.251, 0.184)
const GREEN := Color(0.247, 0.62, 0.184)
const GOLD := Color(0.949, 0.698, 0.114)
const GOLD_DARK := Color(0.71, 0.486, 0.055)
const ORANGE := Color(0.91, 0.475, 0.102)

static func setup() -> void:
	var font: FontFile = FONT
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE


static func snap(value: float) -> float:
	return roundf(value / U) * U


static func text(ci: CanvasItem, pos: Vector2, msg: String, scale: int, color: Color, outline := Color.TRANSPARENT) -> void:
	var base := (pos + Vector2(0, 7 * scale)).round()
	if outline.a > 0.0:
		var o := float(mini(scale, 4))
		for d in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
			ci.draw_string(FONT, base + d * o, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * scale, outline)
	ci.draw_string(FONT, base, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * scale, color)


static func text_centered(ci: CanvasItem, center_x: float, top: float, msg: String, scale: int, color: Color, outline := Color.TRANSPARENT) -> void:
	var width := FONT.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * scale).x - scale
	text(ci, Vector2(snap(center_x - width * 0.5), top), msg, scale, color, outline)


static func panel(ci: CanvasItem, r: Rect2, fill := PAPER, square_corners := false) -> void:
	if square_corners:
		ci.draw_rect(r, INK)
	else:
		ci.draw_rect(r.grow_individual(-U, 0, -U, 0), INK)
		ci.draw_rect(r.grow_individual(0, -U, 0, -U), INK)
	var inner := r.grow(-U)
	ci.draw_rect(inner, fill)
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, U)), fill.lightened(0.4))
	ci.draw_rect(Rect2(inner.position.x, inner.end.y - U, inner.size.x, U), fill.darkened(0.16))


static func button(ci: CanvasItem, r: Rect2, label: String, scale: int) -> void:
	panel(ci, r, GOLD_DARK)
	var hovered := r.has_point(ci.get_local_mouse_position())
	var face := r.grow_individual(-U, -U, -U, -U * 3.0)
	ci.draw_rect(face, GOLD.lightened(0.3) if hovered else GOLD)
	text_centered(ci, face.get_center().x, snap(face.get_center().y - 3.5 * scale), label, scale, INK)


static func bar(ci: CanvasItem, r: Rect2, frac: float, fill: Color) -> void:
	ci.draw_rect(r, INK)
	var inner := r.grow(-U)
	ci.draw_rect(inner, WELL)
	ci.draw_rect(Rect2(inner.position, Vector2(snap(inner.size.x * clampf(frac, 0.0, 1.0)), inner.size.y)), fill)
