class_name ChipButton
extends Button
##
## Oyunun ana dugmesi. Surface.chip ile ciziliyor: kalinligi var, basilinca
## gercekten ASAGI INIYOR ve golgesi kisaliyor.
##
## Dokunmatikte geri bildirim sesten ve renkten once GEOMETRIYLE gelmeli --
## parmak ekrani kapattigi icin oyuncu rengi degil, hareketi goruyor.
##
## Metin `text` yerine `caption` alaninda tutuluyor: Godot'un Button'i `text`
## atanirsa kendi metnini de ciziyor ve bizim ciziminizle ust uste biniyor.

enum Kind { PRIMARY, SOFT, GHOST }

var kind := Kind.PRIMARY
var caption := ""
var base_color: Color = Palette.ACCENT
var label_size := 30
var corner := 26.0
var depth := 7.0
## 0 = sinirsiz. Cevirilerde metin %30-40 uzayabiliyor; sinir verilirse
## dugme tasmak yerine yazi tipini KUCULTUYOR.
var max_width := 0.0
## Metinden bagimsiz taban genislik; caption uzarsa bunun uzerine cikilir.
var min_width := 0.0

var _press := 0.0
var _target := 0.0
var _hover := 0.0
var _hover_target := 0.0


static func make(caption_: String, kind_ := Kind.PRIMARY, size_px := 30) -> ChipButton:
	var b := ChipButton.new()
	b.kind = kind_
	b.label_size = size_px
	b.caption = caption_
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	match kind_:
		Kind.PRIMARY:
			b.base_color = Palette.ACCENT
			b.custom_minimum_size = Vector2(240, 92)
		Kind.SOFT:
			b.base_color = Palette.PAPER
			b.depth = 5.0
			b.corner = 24.0
			b.custom_minimum_size = Vector2(220, 80)
		Kind.GHOST:
			b.depth = 0.0
			b.corner = 20.0
			b.custom_minimum_size = Vector2(160, 60)
	return b


func set_caption(s: String) -> void:
	caption = s
	if is_inside_tree():
		_refresh_min_size()
	queue_redraw()


func _ready() -> void:
	# Kaplamalar bos: yuzeyi kendimiz ciziyoruz, altta ikinci bir cerceve
	# kalmasin.
	var blank := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, blank)
	button_down.connect(func() -> void: _target = 1.0)
	button_up.connect(func() -> void: _target = 0.0)
	mouse_entered.connect(func() -> void: _hover_target = 1.0)
	mouse_exited.connect(func() -> void:
		_hover_target = 0.0
		_target = 0.0)
	set_process(true)
	# Yapim sirasinda atanan caption/max_width sonrasi asgari boyut yeniden
	# hesaplanmali; aksi halde ilk duzen gecisinde eski (bos) olcu kalabiliyor.
	if min_width <= 0.0:
		min_width = custom_minimum_size.x
	_refresh_min_size()


func _font() -> Font:
	return UiTheme.font(UiTheme.DISPLAY if kind == Kind.PRIMARY else UiTheme.STRONG)


func _text_color() -> Color:
	match kind:
		Kind.PRIMARY: return Color.WHITE
		Kind.GHOST: return Palette.INK_SOFT
		_: return Palette.INK


## Dugmenin metne gore genislemesi.
##
## DIKKAT: `_get_minimum_size()` override'i Button icin ISE YARAMIYOR --
## Button asgari boyutunu C++ tarafinda kendi hesapliyor ve betikteki sanal
## fonksiyona hic bakmiyor. Bu yuzden genisligi dogrudan `custom_minimum_size`
## uzerine yaziyoruz; duzen motorunun okudugu deger bu.
func _refresh_min_size() -> void:
	var want := label_size
	if max_width > 0.0:
		want = _fit_size(max_width - _pad())
	var w := _font().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, want).x
	custom_minimum_size.x = maxf(min_width, w + _pad())


func _pad() -> float:
	return 44.0 if kind == Kind.GHOST else 70.0


func _process(delta: float) -> void:
	var k := 1.0 - pow(0.0009, delta)
	var np := lerpf(_press, _target, k)
	var nh := lerpf(_hover, _hover_target, k)
	if absf(np - _press) > 0.001 or absf(nh - _hover) > 0.001:
		_press = np
		_hover = nh
		queue_redraw()


func _draw() -> void:
	var dim := 0.4 if disabled else 1.0
	var col := base_color
	if _hover > 0.01 and not disabled:
		col = col.lightened(0.07 * _hover)

	var bottom_pad := depth + 5.0
	var rect := Rect2(Vector2(3, 2), size - Vector2(6, bottom_pad))
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return

	if kind == Kind.GHOST:
		var wash := maxf(_press, _hover * 0.55)
		if wash > 0.01:
			Surface.fill(self, rect, corner,
				Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.07 * wash))
	else:
		Surface.chip(self, rect, corner, col, depth, _press,
			0.55 if kind == Kind.PRIMARY else 0.32, dim)

	var f := _font()
	var fs := _fit_size(rect.size.x - _pad() * 0.5)
	var tsz := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := rect.position + rect.size * 0.5 \
		+ Vector2(-tsz.x * 0.5, fs * 0.34) + Vector2(0, depth * _press)
	var txt := Color(_text_color(), dim)

	# Birincil dugmede metnin altina ince bir govde golgesi -- kabartma hissi
	if kind == Kind.PRIMARY and not disabled:
		draw_string(f, at + Vector2(0, 2), caption, HORIZONTAL_ALIGNMENT_LEFT, -1,
			fs, Color(0, 0, 0, 0.20))
	draw_string(f, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt)


## Metni VERILEN genislige sigdiran yazi tipi boyutu.
##
## Onemli: olcuyu `max_width` tahminine gore degil, cizim aninda dugmenin
## GERCEK genisligine gore yapiyoruz. Duzen motoru dugmeye istedigimizden
## dar bir alan verebiliyor (ic ice container'larda sik oluyor); tahmine
## guvenmek Rusca ve Almanca metinlerin dugmeden tasmasina yol aciyordu.
func _fit_size(avail_px: float) -> int:
	if caption == "":
		return label_size
	var f := _font()
	var s := label_size
	while s > 12 and f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > avail_px:
		s -= 1
	return s
