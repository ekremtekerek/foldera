class_name LanguageCard
extends Control
##
## Dil secimi. Varsayilan "sistem dili"; oyuncu isterse elle secebiliyor.
##
## Neden elle secim de gerekli: telefonun dili destegimizde yoksa oyun
## Ingilizce'ye duser. Japonca telefon kullanan biri Ingilizce yerine
## Ispanyolca'yi daha iyi biliyor olabilir -- bu ekran olmadan secemez.
##
## Her dil KENDI dilinde yaziyor ("Deutsch", "Русский"): kullanici anlamadigi
## bir dilde kendi dilini arayamaz.

signal chose(code: String)      # "" = sistem dili

var _closed := false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.16, 0.13, 0.10, 0.45)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_pick(SaveData.lang))
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := CardPanel.make(36, 520.0)
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var title := UiTheme.label(Loc.t("LANG_TITLE"), 42, Palette.INK, UiTheme.HEAVY)
	v.add_child(title)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)

	# Liste uzun; ekrana sigmayan kisim kaydirilabilir olmali.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	list.add_child(_row(Loc.t("LANG_SYSTEM"), "", SaveData.lang == ""))
	for code in Loc.SUPPORTED:
		list.add_child(_row(Loc.native_name(code), code, SaveData.lang == code))

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _row(text: String, code: String, active: bool) -> ChipButton:
	var b := ChipButton.make(text, ChipButton.Kind.SOFT if active else ChipButton.Kind.GHOST, 26)
	b.custom_minimum_size = Vector2(420, 66)
	b.max_width = 400.0
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: _pick(code))
	return b


func _pick(code: String) -> void:
	if _closed:
		return
	_closed = true
	Sfx.play_ui()
	chose.emit(code)
	queue_free()


## Testlerin secim yapabilmesi icin.
func choose(code: String) -> void:
	_pick(code)
