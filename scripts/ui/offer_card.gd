class_name OfferCard
extends Control
##
## Genel amacli teklif karti. Uc yerde kullaniliyor:
##   * ipucu bitti      -> odullu reklam / ipucu paketi
##   * takildin         -> odullu reklam ile cozumu gor
##   * reklamsiz teklif -> IAP
##
## Tasarim kurali: KAPATMAK HER ZAMAN KOLAY olmali ve reddetme secenegi asla
## gizlenmemeli. Kapatmasi zor teklifler kisa vadede donusum artirir, uzun
## vadede magaza puanini ve retention'i dusurur.

signal chose(action: String)

var _title := ""
var _body := ""
var _actions: Array = []       # [{id, label, primary: bool, note: String}]
var _closed := false


static func make(title: String, body: String, actions: Array) -> OfferCard:
	var c := OfferCard.new()
	c._title = title
	c._body = body
	c._actions = actions
	return c


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.16, 0.13, 0.10, 0.45)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		# disariya dokununca kapanir -- reddetmenin en kolay yolu
		if e is InputEventMouseButton and e.pressed:
			_choose("dismiss"))
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := CardPanel.make(46, 560.0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)

	v.add_child(_label(_title, 44, Palette.INK, UiTheme.HEAVY))
	if _body != "":
		v.add_child(_label(_body, 26, Palette.INK_SOFT))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)

	for a in _actions:
		var primary: bool = bool(a.get("primary", false))
		var b := ChipButton.make(str(a.label),
			ChipButton.Kind.PRIMARY if primary else ChipButton.Kind.GHOST,
			30 if primary else 26)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.max_width = 460.0        # kart genisligi 560; tasma yerine kucult
		var id := str(a.id)
		b.pressed.connect(func() -> void: _choose(id))
		v.add_child(b)

		if str(a.get("note", "")) != "":
			v.add_child(_label(str(a.note), 20, Color(Palette.INK_SOFT, 0.8)))

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _label(text: String, size_px: int, col: Color, weight := UiTheme.BODY) -> Label:
	var l := UiTheme.label(text, size_px, col, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _choose(id: String) -> void:
	if _closed:
		return
	_closed = true
	Sfx.play_ui()
	chose.emit(id)
	queue_free()


## Testlerin secim yapabilmesi icin. Dugmeye basmakla ayni yolu izler.
func choose(id: String) -> void:
	_choose(id)
