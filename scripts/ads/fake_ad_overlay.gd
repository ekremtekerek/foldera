class_name FakeAdOverlay
extends CanvasLayer
##
## Sahte reklam ekrani. Gorunusu KASITLI olarak "test" damgali -- kimse bunu
## gercek reklam sanip yayinlamasin.
##
## Amaci sadece dekor degil: gercek reklamin oyun akisina yaptigi seyi birebir
## taklit ediyor (ekrani kaplama, geri sayim, erken kapatma). Boylece odaklanma
## kaybi, ses kesilmesi ve odul iptali gibi durumlar Android olmadan da test
## edilebiliyor.

signal closed(earned: bool)

const COUNTDOWN_INTERSTITIAL := 4.0
const COUNTDOWN_REWARDED := 6.0

var _left := 0.0
var _rewarded := false
var _can_close := false
var _panel: Control
var _timer_lbl: Label
var _action: Button
var _skip: Button


func _init() -> void:
	layer = 100


func open(rewarded: bool) -> void:
	_rewarded = rewarded
	_left = COUNTDOWN_REWARDED if rewarded else COUNTDOWN_INTERSTITIAL
	_build()
	set_process(true)


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.05, 0.07, 0.92)
	add_child(dim)

	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_theme_constant_override("separation", 22)
	add_child(_panel)

	_panel.add_child(_label(Loc.t("AD_TEST_TAG"), 34, Color(1, 1, 1, 0.55)))
	_panel.add_child(_label(Loc.t("AD_REWARDED") if _rewarded else Loc.t("AD_INTERSTITIAL"), 46, Color.WHITE))
	_timer_lbl = _label("", 30, Color(1, 1, 1, 0.70))
	_panel.add_child(_timer_lbl)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	_panel.add_child(gap)

	_action = Button.new()
	_action.custom_minimum_size = Vector2(320, 84)
	_action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_font_size_override("font_size", 30)
	_action.text = Loc.t("AD_CLAIM") if _rewarded else Loc.t("AD_CLOSE")
	_action.disabled = true
	_action.pressed.connect(func() -> void: _finish(_rewarded))
	_panel.add_child(_action)

	if _rewarded:
		_skip = Button.new()
		_skip.flat = true
		_skip.focus_mode = Control.FOCUS_NONE
		_skip.text = Loc.t("AD_SKIP")
		_skip.add_theme_font_size_override("font_size", 24)
		_skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_skip.pressed.connect(func() -> void: _finish(false))
		_panel.add_child(_skip)


func _label(text: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l


func _process(delta: float) -> void:
	if _can_close:
		return
	_left = maxf(0.0, _left - delta)
	_timer_lbl.text = "%d" % int(ceil(_left)) if _left > 0.0 else ""
	if _left <= 0.0:
		_can_close = true
		_action.disabled = false


func _finish(earned: bool) -> void:
	set_process(false)
	closed.emit(earned)
	queue_free()
