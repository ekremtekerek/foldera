class_name AdProvider
extends Node
##
## Reklam saglayicisi arayuzu. Oyun kodu SADECE bunu taniyor; AdMob, Unity Ads
## veya baska bir ag arasinda gecis tek dosya degisikligi.
##
## Butun goster fonksiyonlari es zamanli (await edilebilir) ve HER ZAMAN doner
## -- reklam dolmadiysa, hata verdiyse veya kullanici kapattiysa bile. Oyun
## akisi reklamin sonucunu beklerken asla kilitlenmemeli.

signal state_changed()

var consent := ""          # "" | "personalized" | "limited"

##
## Son yukleme hatasi ve basarisiz deneme sayisi.
##
## "Reklam izle dugmesi hic cikmadi" ile "reklam doldurulmadi" disaridan
## AYIRT EDILEMIYOR: ikisi de sessiz. Oysa ilki bir kod hatasi, ikincisi
## yeni bir uygulamada tamamen normal. Sebebi saklamazsak her seferinde
## bastan tahmin yurutmek zorunda kaliyoruz.
var son_hata := ""
var basarisiz := 0


func provider_name() -> String:
	return "none"


func initialize(consent_mode: String) -> void:
	consent = consent_mode


## Reklam hazir mi. Hazir degilse cagiran taraf reklami ATLAMALI, beklememeli.
func is_interstitial_ready() -> bool:
	return false


func is_rewarded_ready() -> bool:
	return false


## Gosterildi mi (yuklenemediyse false).
func show_interstitial() -> bool:
	return false


## Odul hak edildi mi (kullanici erken kapattiysa false).
func show_rewarded() -> bool:
	return false


func preload_all() -> void:
	pass
