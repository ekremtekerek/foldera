class_name UiTheme
##
## Yazi tipi ve tema. Sistem yazi tipi bir oyunu aninda "uygulama" gibi
## gosteriyor; Nunito yuvarlak sonlanmalari sayesinde kagit-zanaati diline
## uyuyor ve tam Turkce kapsamasi var (ğ ı ş İ ç ö ü).
##
## Tek bir DEGISKEN yazi tipi dosyasi tasiyoruz (277 KB) ve agirliklari ondan
## turetiyoruz -- ayri ayri Bold/Black dosyalari tasimaktan hem kucuk hem esnek.
## Lisans: SIL OFL, fonts/OFL.txt (ticari kullanima acik).

const FONT_PATH := "res://fonts/Nunito.ttf"

## OpenType 'wght' ekseninin sayisal etiketi.
const TAG_WEIGHT := 0x77676874

enum { BODY = 600, STRONG = 700, DISPLAY = 800, HEAVY = 900 }

static var _cache := {}
static var _base: FontFile = null


static func font(weight: int = BODY) -> Font:
	if _cache.has(weight):
		return _cache[weight]
	if _base == null:
		_base = load(FONT_PATH)
	if _base == null:
		return ThemeDB.fallback_font
	var f := FontVariation.new()
	f.base_font = _base
	f.variation_opentype = {TAG_WEIGHT: weight}
	_cache[weight] = f
	return f


## Uygulama geneli tema. Kok Control'e atanip asagi yayiliyor.
static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(BODY)
	t.default_font_size = 26

	# NOT: Button kaplamalarini tema genelinde BOSALTMIYORUZ. Kendi
	# dugmelerimiz (ChipButton / ToolButton) bunu kendileri yapiyor; tema
	# geneline uygulamak ConfirmationDialog gibi yerlerdeki normal dugmeleri
	# de gorunmez yapardi.

	t.set_color("font_color", "Button", Palette.INK)
	t.set_color("font_hover_color", "Button", Palette.INK)
	t.set_color("font_pressed_color", "Button", Palette.INK)
	t.set_font("font", "Button", font(STRONG))

	t.set_color("font_color", "Label", Palette.INK)
	t.set_font("font", "Label", font(BODY))
	return t


## Baslik / govde ayrimini tek yerden veren yardimci.
static func label(text: String, size_px: int, col: Color, weight := BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
