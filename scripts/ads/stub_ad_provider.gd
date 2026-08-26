class_name StubAdProvider
extends AdProvider
##
## Gercek SDK olmadan tam akisi calistiran saglayici. Sadece "hep basarili"
## demiyor -- gercek reklam agi gibi davraniyor:
##
##   * yukleme gecikmesi var (reklam her an hazir degil)
##   * bazen doluluk yok (fill rate < %100) -> gosterim atlanir
##   * odullu reklam erken kapatilabilir -> odul verilmez
##
## Bu kotu durumlarin oyunda dogru ele alindigini Android olmadan test
## edebilmek icin. `instant` modunda (soak testi) beklemeden sonuc doner.

const LOAD_SECONDS := 1.2
const FILL_RATE := 0.92

var instant := false
var force_fill := false     # testte belirlenimci davranis icin

var _interstitial_ready := false
var _rewarded_ready := false
var _rng := RandomNumberGenerator.new()


func provider_name() -> String:
	return "stub"


func initialize(consent_mode: String) -> void:
	super.initialize(consent_mode)
	_rng.randomize()
	preload_all()


func preload_all() -> void:
	_load("interstitial")
	_load("rewarded")


func _load(kind: String) -> void:
	if instant:
		_set_ready(kind, force_fill or _rng.randf() < FILL_RATE)
		return
	await get_tree().create_timer(LOAD_SECONDS).timeout
	_set_ready(kind, force_fill or _rng.randf() < FILL_RATE)


func _set_ready(kind: String, ready: bool) -> void:
	if kind == "interstitial":
		_interstitial_ready = ready
	else:
		_rewarded_ready = ready
	state_changed.emit()


func is_interstitial_ready() -> bool:
	return _interstitial_ready


func is_rewarded_ready() -> bool:
	return _rewarded_ready


func show_interstitial() -> bool:
	if not _interstitial_ready:
		_load("interstitial")
		return false
	_interstitial_ready = false
	var shown := await _present(false)
	_load("interstitial")
	return shown


func show_rewarded() -> bool:
	if not _rewarded_ready:
		_load("rewarded")
		return false
	_rewarded_ready = false
	var earned := await _present(true)
	_load("rewarded")
	return earned


func _present(rewarded: bool) -> bool:
	if instant:
		return true
	var overlay := FakeAdOverlay.new()
	get_tree().root.add_child(overlay)
	overlay.open(rewarded)
	var earned: bool = await overlay.closed
	return earned
