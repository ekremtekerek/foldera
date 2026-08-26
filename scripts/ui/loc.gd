class_name Loc
##
## Yerellestirme. Tum kullanici metinleri locale/katla.csv icinde; kodda
## yalnizca anahtar var.
##
## Dil secimi varsayilan olarak TELEFONUN dilini takip ediyor. Oyuncu isterse
## elle degistirebiliyor -- sistem dili destegimizde olmayan bir dilse
## (ornegin Japonca) oyuncu Ingilizce yerine bildigi baska bir dili secebilsin
## diye bu secim onemli.
##
## DESTEKLENEN diller Nunito'nun kapsadigi yazi sistemleriyle sinirli:
## Latin, Latin Ext, Kiril, Vietnamca. Arapca / Cince / Japonca / Korece /
## Hintce / Yunanca icin ek yazi tipi (Noto ailesi) gerekiyor; Arapca ayrica
## sagdan-sola yerlesim istiyor. README'de ayrintili.

const SUPPORTED := ["en", "tr", "es", "pt", "de", "fr", "it", "ru", "pl", "nl", "id", "vi", "uk"]

## Her dilin KENDI dilindeki adi. Dil listesinde "German" degil "Deutsch"
## yazmali: kullanici anlamadigi bir dilde kendi dilini arayamaz.
const NATIVE_NAME := {
	"en": "English",
	"tr": "Türkçe",
	"es": "Español",
	"pt": "Português",
	"de": "Deutsch",
	"fr": "Français",
	"it": "Italiano",
	"ru": "Русский",
	"pl": "Polski",
	"nl": "Nederlands",
	"id": "Bahasa Indonesia",
	"vi": "Tiếng Việt",
	"uk": "Українська",
}


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func f(key: String, args: Array) -> String:
	return TranslationServer.translate(key) % args


## Bir dil kodunu desteklenen bir koda cevirir.
##
## Cihaz "pt_BR" bildirse bile Godot bize "pt" veriyor; desteklemedigimiz bir
## dil gelirse Ingilizce'ye dusuyoruz. Ayri fonksiyon olmasinin sebebi TEST:
## OS'un dilini degistiremeyiz ama bu fonksiyonu her kodla cagirabiliriz.
static func pick(lang: String) -> String:
	var short := lang.substr(0, 2).to_lower()
	return short if SUPPORTED.has(short) else "en"


## Telefonun dili destekleniyorsa onu, degilse Ingilizce.
static func resolve_system() -> String:
	return pick(OS.get_locale_language())


## code == "" ise cihazin dilini kullanir.
static func apply(code: String) -> void:
	var use := code if SUPPORTED.has(code) else resolve_system()
	TranslationServer.set_locale(use)


static func current() -> String:
	var c := TranslationServer.get_locale()
	# Godot tam kodu ("pt_BR") dondurebilir; iki harfe indiriyoruz.
	var short := c.substr(0, 2)
	return short if SUPPORTED.has(short) else "en"


static func native_name(code: String) -> String:
	return str(NATIVE_NAME.get(code, code))
