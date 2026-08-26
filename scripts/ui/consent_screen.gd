class_name ConsentScreen
extends Control
##
## Ilk acilista bir kez cikan riza ekrani (KVKK / GDPR).
##
## Uc kural burada bilerek uygulandi:
##   1. Reddetmek kabul etmek kadar kolay -- iki secenek de ayni agirlikta
##      gorunuyor. "Kabul et" buyuk yesil, "reddet" kucuk gri OLMAMALI;
##      hem KVKK hem GDPR bunu "gecerli riza" saymiyor.
##   2. Reddedince oyun CALISMAYA DEVAM ediyor. Sadece reklamlar
##      kisisellestirilmiyor.
##   3. Secim sonradan degistirilebilir (ayarlardan tekrar acilabilir).
##
## AdMob'un UMP modulu Avrupa'da bu ekrani kendisi gosteriyor; bu ekran ise
## her yerde calisan ve secimi bize de kaydeden kendi katmanimiz.

signal decided(mode: String)      # "personalized" | "limited"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.BG_TOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size = Vector2(600, 0)
	center.add_child(v)

	v.add_child(_label(Loc.t("PRIVACY_TITLE"), 46, Palette.INK, UiTheme.HEAVY))

	# Paragraflar AYRI anahtarlar. Tek metne gomulu satir sonlari cevirilerde
	# yanlis yere denk geliyor; ayri etiketler her dilde dogru akiyor.
	for key in ["PRIVACY_P1", "PRIVACY_P2", "PRIVACY_P3"]:
		v.add_child(_label(Loc.t(key), 24, Palette.INK_SOFT))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	v.add_child(gap)

	# Iki secenek de ayni gorsel agirlikta -- gecerli riza icin sart.
	v.add_child(_choice(Loc.t("PRIVACY_ALLOW"), "personalized"))
	v.add_child(_choice(Loc.t("PRIVACY_DENY"), "limited"))

	v.add_child(_label(Loc.t("PRIVACY_NOTE"), 20, Color(Palette.INK_SOFT, 0.75)))


func _label(text: String, size_px: int, col: Color, weight := UiTheme.BODY) -> Label:
	var l := UiTheme.label(text, size_px, col, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Iki secenek de AYNI gorsel agirlikta. "Kabul et" buyuk renkli, "reddet"
## kucuk gri olsaydi ne KVKK ne GDPR bunu gecerli riza sayardi.
func _choice(text: String, mode: String) -> ChipButton:
	var b := ChipButton.make(text, ChipButton.Kind.SOFT, 26)
	b.custom_minimum_size = Vector2(520, 86)
	b.max_width = 560.0
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		Sfx.play_ui()
		decided.emit(mode)
		queue_free())
	return b
