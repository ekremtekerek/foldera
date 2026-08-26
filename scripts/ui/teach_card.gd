class_name TeachCard
extends Control
##
## Ogretici kart. Yeni bir tas tipi ilk kez ekrana geldiginde bir kez cikar.
##
## Kural: METINDEN ONCE RESIM. Kartin ustunde her zaman kucuk bir ornek var --
## iki tas, aralarinda bir isaret, sonuc. Oyuncu metni okumasa bile kurali
## anliyor. Metin sadece dogruluyor.
##
## Ogreticiler oyunu DURDURUYOR ama yalnizca bir kez: gorulen kart
## SaveData.seen icine yaziliyor.

signal dismissed()

const DEMO_MERGE := "merge"     # iki tas + sonuc
const DEMO_STARS := "stars"
const DEMO_TOOLS := "tools"

var demo := DEMO_MERGE
var left_code := 0
var right_code := 0
var result_ok := true           # true = patlar, false = yasak


static func make(key: String) -> TeachCard:
	var c := TeachCard.new()
	match key:
		"lock":
			c.demo = DEMO_MERGE
			c.left_code = Tiles.LOCK
			c.right_code = Tiles.make(Tiles.K_NORMAL, 0)
			c.result_ok = false
			c._title = Loc.t("TEACH_LOCK_TITLE")
			c._body = Loc.t("TEACH_LOCK_BODY")
		"wild":
			c.demo = DEMO_MERGE
			c.left_code = Tiles.WILD
			c.right_code = Tiles.make(Tiles.K_NORMAL, 1)
			c.result_ok = true
			c._title = Loc.t("TEACH_WILD_TITLE")
			c._body = Loc.t("TEACH_WILD_BODY")
		"stars":
			c.demo = DEMO_STARS
			c._title = Loc.t("TEACH_STARS_TITLE")
			c._body = Loc.t("TEACH_STARS_BODY")
		"tools":
			c.demo = DEMO_TOOLS
			c._title = Loc.t("TEACH_TOOLS_TITLE")
			c._body = Loc.t("TEACH_TOOLS_BODY")
		_:
			c._title = key
	return c


var _title := ""
var _body := ""
var _canvas: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.16, 0.13, 0.10, 0.45)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := CardPanel.make(46, 560.0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	card.add_child(v)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, 150)
	_canvas.draw.connect(_draw_demo)
	v.add_child(_canvas)

	v.add_child(_label(_title, 46, Palette.INK, UiTheme.HEAVY))
	v.add_child(_label(_body, 26, Palette.INK_SOFT))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)

	var ok := ChipButton.make(Loc.t("BTN_GOT_IT"), ChipButton.Kind.PRIMARY, 30)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.max_width = 440.0
	ok.pressed.connect(func() -> void:
		Sfx.play_ui()
		dismissed.emit()
		queue_free())
	v.add_child(ok)

	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	pivot_offset = size * 0.5
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _label(text: String, size_px: int, col: Color, weight := UiTheme.BODY) -> Label:
	var l := UiTheme.label(text, size_px, col, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _draw_demo() -> void:
	var c := _canvas.size * 0.5
	match demo:
		DEMO_MERGE: _draw_merge(c)
		DEMO_STARS: _draw_stars(c)
		DEMO_TOOLS: _draw_tools(c)


## iki tas + ok + sonuc. Kurali tek bakista anlatan sey bu satir.
func _draw_merge(c: Vector2) -> void:
	var cell := 104.0
	var gap := cell * 1.22
	_tile(_canvas, Vector2(c.x - gap, c.y), left_code, cell)
	_tile(_canvas, Vector2(c.x, c.y), right_code, cell)

	# aradaki artı: "ust uste gelirse"
	var plus := Palette.INK_SOFT
	var px := c.x - gap * 0.5
	var s := cell * 0.12
	_canvas.draw_line(Vector2(px - s, c.y), Vector2(px + s, c.y), plus, 4.0, true)
	_canvas.draw_line(Vector2(px, c.y - s), Vector2(px, c.y + s), plus, 4.0, true)

	var ax := c.x + gap * 0.5
	_canvas.draw_line(Vector2(ax - s * 1.2, c.y), Vector2(ax + s * 1.2, c.y), plus, 4.0, true)
	_canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(ax + s * 1.9, c.y),
		Vector2(ax + s * 0.7, c.y - s * 0.7),
		Vector2(ax + s * 0.7, c.y + s * 0.7),
	]), plus)

	var rp := Vector2(c.x + gap, c.y)
	if result_ok:
		var g := Palette.GOOD
		_canvas.draw_arc(rp, cell * 0.34, 0, TAU, 40, g, 6.0, true)
		for i in 8:
			var a := TAU * float(i) / 8.0
			var d := Vector2(cos(a), sin(a))
			_canvas.draw_line(rp + d * cell * 0.44, rp + d * cell * 0.60, g, 5.0, true)
	else:
		var b := Palette.BAD
		var d2 := cell * 0.26
		_canvas.draw_arc(rp, cell * 0.36, 0, TAU, 40, b, 6.0, true)
		_canvas.draw_line(rp + Vector2(-d2, -d2), rp + Vector2(d2, d2), b, 7.0, true)
		_canvas.draw_line(rp + Vector2(d2, -d2), rp + Vector2(-d2, d2), b, 7.0, true)


func _draw_stars(c: Vector2) -> void:
	var step := 100.0
	for i in 3:
		var p := Vector2(c.x + step * (float(i) - 1.0), c.y)
		var pts := PackedVector2Array()
		for v in Palette.shape_points(Palette.SHAPE_STAR, 38.0):
			pts.append(p + v)
		_canvas.draw_colored_polygon(pts, Palette.COLORS[2])


func _draw_tools(c: Vector2) -> void:
	var ids := [IconDraw.UNDO, IconDraw.RESTART, IconDraw.HINT]
	var step := 130.0
	for i in ids.size():
		var p := Vector2(c.x + step * (float(i) - 1.0), c.y)
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.BG_BOTTOM
		for corner in ["corner_radius_top_left", "corner_radius_top_right",
				"corner_radius_bottom_left", "corner_radius_bottom_right"]:
			box.set(corner, 24)
		_canvas.draw_style_box(box, Rect2(p - Vector2(48, 48), Vector2(96, 96)))
		_canvas.draw_set_transform(p, 0.0, Vector2.ONE)
		IconDraw.paint(_canvas, ids[i], 30.0, Palette.INK if i < 2 else Palette.ACCENT)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Oyundaki tas gorunumunun aynisini kucuk olcekte cizer -- kart ile tahta
## arasinda gorsel fark olmamali, yoksa oyuncu ayni sey oldugunu anlamaz.
func _tile(ci: CanvasItem, at: Vector2, code: int, cell: float) -> void:
	var s := cell * 0.88
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.body(code)
	var r := int(cell * 0.22)
	for corner in ["corner_radius_top_left", "corner_radius_top_right",
			"corner_radius_bottom_left", "corner_radius_bottom_right"]:
		box.set(corner, r)
	box.border_width_bottom = maxi(2, int(cell * 0.045))
	box.border_color = Palette.edge(code)
	box.shadow_color = Palette.SHADOW
	box.shadow_size = int(cell * 0.10)
	box.shadow_offset = Vector2(0, cell * 0.05)
	ci.draw_style_box(box, Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)))

	var shape := Palette.shape_for(code)
	if shape >= 0:
		var pts := PackedVector2Array()
		for v in Palette.shape_points(shape, s * 0.26):
			pts.append(at + v)
		ci.draw_colored_polygon(pts, Palette.face(code))
	elif shape == -1:
		var cc := s * 0.30
		for p in [Vector2(-cc, -cc), Vector2(cc, -cc), Vector2(-cc, cc), Vector2(cc, cc)]:
			ci.draw_circle(at + p, s * 0.045, Color(1, 1, 1, 0.18))
		ci.draw_circle(at, s * 0.20, Palette.LOCK_FACE)
		ci.draw_circle(at + Vector2(-s * 0.06, -s * 0.06), s * 0.055, Color(1, 1, 1, 0.50))
	else:
		var pts2 := PackedVector2Array()
		for i in 8:
			var rad := s * 0.34 if i % 2 == 0 else s * 0.08
			var a := -PI / 2.0 + TAU * float(i) / 8.0
			pts2.append(at + Vector2(cos(a), sin(a)) * rad)
		ci.draw_colored_polygon(pts2, Palette.WILD_FACE)


## Testlerin karti kapatabilmesi icin. Dugmeye basmakla ayni yolu izler.
func dismiss() -> void:
	dismissed.emit()
	queue_free()
