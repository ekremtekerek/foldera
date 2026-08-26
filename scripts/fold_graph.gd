class_name FoldGraph
extends RefCounted
##
## Bir tahtadan ULASILABILEN butun durumlari cikarir ve her birini
## "hala cozulebilir" / "cikmaz" diye isaretler.
##
## Neden var: katlama geri donusu olmayan bir hamle. Yanlis kat cizgisi es
## taslari bir daha kavusamayacak sekilde ayirabilir; o zaman oyuncu cozumsuz
## bir tahtada kalir. Bulmaca oyununda bu kabul edilemez. Seviye uretimi bu
## grafigi cikarip icinde TEK BIR cikmaz bile olan seviyeleri eliyor -- yani
## cikmaz oyuncuya hic gosterilmiyor, engellenmiyor: hic var olmuyor.
##
## Grafik dogal olarak DAG: her katlama kagidi kucultur (yeni_n <= n-1), bu
## yuzden dongu olusamaz, derinlik de log2(w)+log2(h) ile sinirli.
##
## Ayna esdegerligi iki kat kazanc saglar:
##   * side 1 katlamasi, side 0 katlamasinin tam aynasi  -> sadece side 0 taranir
##   * tahtanin yatay/dikey aynasi cozulebilirligi degistirmez
## Durumlari 4 aynanin sozlukte en kucugu ile anahtarliyoruz.
##

## Guvenlik freni. Normal seviyelerde birkac yuz durum gorulur; buna carpmak
## uretimin kontrolden ciktigi anlamina gelir, o seviye elenir.
const STATE_CAP := 20000

var visited := {}        ## kanonik anahtar -> cozulebilir mi (bool)
var depth := {}          ## kanonik anahtar -> en kisa cozum uzunlugu (-1: cikmaz)
var overflow := false


# ------------------------------------------------------------- kanonik anahtar

static func _variant_key(b: BoardModel, fx: bool, fy: bool) -> String:
	var out := PackedByteArray()
	out.resize(b.w * b.h)
	var i := 0
	for y in b.h:
		var sy := (b.h - 1 - y) if fy else y
		for x in b.w:
			var sx := (b.w - 1 - x) if fx else x
			out[i] = b.cells[sy * b.w + sx]
			i += 1
	return "%d.%d." % [b.w, b.h] + out.hex_encode()


static func canonical(b: BoardModel) -> String:
	var best := _variant_key(b, false, false)
	for v in [[true, false], [false, true], [true, true]]:
		var s := _variant_key(b, v[0], v[1])
		if s < best:
			best = s
	return best


# --------------------------------------------------------------------- denetim

##
## Seviyeyi bastan sona gezer. Donen sozluk:
##   clean    : hicbir ulasilabilir durum cikmaz degil  <- seviye kabul olcutu
##   par      : gercek en kisa cozum (tam sayim, tahminsiz)
##   states   : incelenen farkli durum sayisi
##   dead     : cikmaz durum sayisi
##   overflow : STATE_CAP asildi, sonuc guvenilmez
##
func audit(b: BoardModel) -> Dictionary:
	visited = {}
	depth = {}
	overflow = false
	var ok := _walk(b)
	var dead := 0
	for k in visited:
		if not visited[k]:
			dead += 1
	return {
		"solvable": ok,
		"clean": ok and dead == 0 and not overflow,
		"par": depth.get(canonical(b), -1),
		"states": visited.size(),
		"dead": dead,
		"overflow": overflow,
	}


## Tam gezinti -- KISA DEVRE YOK. Cikmaz sayabilmek icin her dal gezilmeli.
func _walk(b: BoardModel) -> bool:
	var key := canonical(b)
	if visited.has(key):
		return visited[key]
	if visited.size() >= STATE_CAP:
		overflow = true
		return false
	visited[key] = false
	depth[key] = -1
	if b.is_solved():
		visited[key] = true
		depth[key] = 0
		return true
	var best := -1
	for c in b.creases():
		var r := b.fold(c[0], c[1], 0)
		if not r.ok:
			continue
		var child := BoardModel.new(r.w, r.h, r.cells)
		if not _walk(child):
			continue
		var d: int = depth[canonical(child)]
		if best < 0 or d + 1 < best:
			best = d + 1
	visited[key] = best >= 0
	depth[key] = best
	return best >= 0


# ------------------------------------------------------------- hizli sorgular

## Kisa devreli: sadece "cozulebilir mi" sorusu. Oyun icindeki emniyet kemeri.
func reachable_solution(b: BoardModel) -> bool:
	if b.is_solved():
		return true
	var key := canonical(b)
	if visited.has(key):
		return visited[key]
	if visited.size() >= STATE_CAP:
		overflow = true
		return false
	visited[key] = false
	for c in b.creases():
		var r := b.fold(c[0], c[1], 0)
		if not r.ok:
			continue
		if reachable_solution(BoardModel.new(r.w, r.h, r.cells)):
			visited[key] = true
			return true
	return false


static func is_solvable(b: BoardModel) -> bool:
	return FoldGraph.new().reachable_solution(b)


##
## En kisa cozume goturen ILK kat cizgisi: [axis, g] ya da bos dizi.
## Grafik zaten cikarildigi icin ipucu ARAMA yapmiyor -- dogrudan okuma.
## Eski IDDFS cozucusu derinlik limitine takilip bos donebiliyordu; bu donmez.
##
func best_move(b: BoardModel) -> Array:
	if b.is_solved():
		return []
	if not depth.has(canonical(b)):
		audit(b)
	var best := -1
	var pick: Array = []
	for c in b.creases():
		var r := b.fold(c[0], c[1], 0)
		if not r.ok:
			continue
		var d: int = depth.get(canonical(BoardModel.new(r.w, r.h, r.cells)), -1)
		if d < 0:
			continue
		if best < 0 or d < best:
			best = d
			pick = [c[0], c[1]]
	return pick


##
## Par'a goturen KAC farkli ilk kat cizgisi var. 1 ise en kisa cozum tektir --
## bulmacanin dogru cevabi belirgin olur. Seviye secerken bunu tercih
## ediyoruz; aksi halde uc yildiz sansa kalir.
##
func optimal_first_count(b: BoardModel) -> int:
	var key := canonical(b)
	if not depth.has(key):
		audit(b)
	var par: int = depth.get(key, -1)
	if par <= 0:
		return 0
	var n := 0
	for c in b.creases():
		var r := b.fold(c[0], c[1], 0)
		if not r.ok:
			continue
		if int(depth.get(canonical(BoardModel.new(r.w, r.h, r.cells)), -1)) == par - 1:
			n += 1
	return n
