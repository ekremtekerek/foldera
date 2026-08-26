class_name ToolButton
extends Button
##
## Alt cubuktaki eylem dugmesi: vektor ikon + altinda kucuk etiket.
##
## Taslarla AYNI yuzey recetesini kullaniyor (Surface.chip) -- arayuz ile
## oyun alani ayni malzemeden yapilmis gibi duruyor. Basilinca pul gercekten
## asagi iniyor ve golgesi kisaliyor.

var icon_id := IconDraw.UNDO
var label := ""
var accent := false
var badge := -1        # >= 0 ise sag ustte sayac rozeti

var _press := 0.0
var _target := 0.0
var _hover := 0.0
var _hover_target := 0.0
var _depth := 6.0


func setup(id: int, text_label: String, is_accent := false) -> void:
	icon_id = id
	label = text_label
	accent = is_accent
	flat = true
	var blank := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, blank)
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(112, 104)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(func() -> void: _target = 1.0)
	button_up.connect(func() -> void: _target = 0.0)
	mouse_entered.connect(func() -> void: _hover_target = 1.0)
	mouse_exited.connect(func() -> void:
		_hover_target = 0.0
		_target = 0.0)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var k := 1.0 - pow(0.0009, delta)
	var np := lerpf(_press, _target, k)
	var nh := lerpf(_hover, _hover_target, k)
	if absf(np - _press) > 0.001 or absf(nh - _hover) > 0.001:
		_press = np
		_hover = nh
		queue_redraw()


func _draw() -> void:
	var dim := 0.42 if disabled else 1.0
	var body := Palette.PAPER
	if _hover > 0.01 and not disabled:
		body = body.lightened(0.05 * _hover)
	var rect := Rect2(Vector2(3, 2), size - Vector2(6, _depth + 5))
	Surface.chip(self, rect, 26.0, body, _depth, _press, 0.30, dim)

	var sink := _depth * _press
	var col := Palette.ACCENT if accent else Palette.INK
	col.a = dim
	var has_label := label != ""
	var icon_y := rect.position.y + rect.size.y * (0.38 if has_label else 0.5)
	var center := Vector2(rect.position.x + rect.size.x * 0.5, icon_y + sink)

	draw_set_transform(center, 0.0, Vector2.ONE * (1.0 - 0.06 * _press))
	IconDraw.paint(self, icon_id, size.y * 0.195, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if has_label:
		var f := UiTheme.font(UiTheme.STRONG)
		var fs := int(size.y * 0.145)
		# Cevirilerde etiket uzayabiliyor; dugmeden tasmak yerine kucul.
		while fs > 9 and f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x - 12.0:
			fs -= 1
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(rect.position.x + rect.size.x * 0.5 - tw * 0.5,
			rect.end.y - rect.size.y * 0.13 + sink),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.82 * dim))

	# Kalan sayac rozeti. Sifirken renk degistiriyor -- oyuncu dugmeye
	# basmadan once bittigini gormeli, sonra degil.
	if badge >= 0:
		var f2 := UiTheme.font(UiTheme.DISPLAY)
		var br := size.y * 0.145
		var bp := Vector2(rect.end.x - br * 0.55, rect.position.y + br * 0.75 + sink)
		var bg := Palette.ACCENT if badge > 0 else Palette.INK_SOFT
		draw_circle(bp + Vector2(0, 2), br, Color(0, 0, 0, 0.18 * dim))
		draw_circle(bp, br, Color(bg, dim))
		draw_circle(bp - Vector2(0, br * 0.25), br * 0.72, Color(1, 1, 1, 0.13 * dim))
		var txt := str(badge)
		var fs2 := int(br * 1.20)
		var tsz := f2.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		draw_string(f2, bp + Vector2(-tsz.x * 0.5, fs2 * 0.36), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 1, dim))
