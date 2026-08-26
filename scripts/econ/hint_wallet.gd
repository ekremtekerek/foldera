class_name HintWallet
extends RefCounted
##
## Ipucu cuzdani. Iki ayri kova var ve SIRA onemli:
##   free_left  -- her gun yenilenen bedava kontenjan, once bu harcanir
##   purchased  -- odullu reklam veya satin alma ile gelen, ASLA sifirlanmaz
##
## Bedava kontenjani once harcamak oyuncunun lehine: gun sonunda kaybolacak
## olan once gider, parasini verdigi durur. Tersi yapilirsa oyuncu satin
## aldigini gun degisiminde bosa harcamis hisseder.
##
## Godot dugumune bagli degil -> headless test edilebilir.

const DAILY_FREE := 3

var day := ""              # "YYYY-AA-GG"
var free_left := DAILY_FREE
var purchased := 0


## Gun degistiyse bedava kontenjani yeniler. Yenileme olduysa true doner.
func refresh(today: String) -> bool:
	if day == today:
		return false
	day = today
	free_left = DAILY_FREE
	return true


func total() -> int:
	return free_left + purchased


func can_spend() -> bool:
	return total() > 0


func spend() -> bool:
	if free_left > 0:
		free_left -= 1
		return true
	if purchased > 0:
		purchased -= 1
		return true
	return false


func grant(n: int) -> void:
	purchased += maxi(0, n)


func to_dict() -> Dictionary:
	return {"day": day, "free_left": free_left, "purchased": purchased}


func from_dict(d: Dictionary) -> void:
	day = str(d.get("day", ""))
	free_left = clampi(int(d.get("free_left", DAILY_FREE)), 0, DAILY_FREE)
	purchased = maxi(0, int(d.get("purchased", 0)))
