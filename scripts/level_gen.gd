class_name LevelGen
##
## Seviyeler GERIYE DOGRU uretilir: bos bir tahtadan baslanip N kez "acilir".
## Her acilis, ileri yonde gecerli bir katlamanin tam tersi -> uretilen
## tahtanin en az bir cozumu OLDUGU garanti.
##
## AMA BU YETMIYOR. "Bir cozumu var" ile "her yol cozume gider" ayni sey degil.
## Oyuncu gecerli ama yanlis bir kat cizgisi secince esleri bir daha
## kavusturamayacagi bir tahtada kalabiliyordu -- olcum: 80 seviyenin 61
## tanesinde en az bir cikmaz vardi. Bulmacada cikmaz kabul edilemez; geri al
## dugmesi bunun ozru olamaz.
##
## Cozum: her aday FoldGraph ile TAM denetimden geciyor. Tahtadan ulasilabilen
## butun durumlar cikariliyor ve her birinin hala cozulebilir oldugu
## dogrulaniyor. Tek bir cikmaz varsa aday eleniyor. Yayinlanan her seviye su
## ozelligi tasiyor: HANGI SIRAYLA KATLARSAN KATLA, tahta temizlenebilir kalir.
## Oyuncu kaybedemez; maharet en KISA cozumu bulmakta (uc yildiz).
##
## Denetim ucuz (aday basina birkac ms) ama temiz aday orani ~%6. Bu yuzden
## seviyeler DERLEME ANINDA uretilip levels/levels.txt icine yaziliyor
## (tools/bake_levels.gd). Cihazda arama yok, seviye acilisi anlik. Bankanin
## otesindeki seviyelerde ayni denetim calisma aninda yapiliyor.
##

const BANK_PATH := "res://levels/levels.txt"

## Seviye icerigi oyunun ADINDAN bagimsiz olsun diye sabit etiket. Isim
## degisirse seviyeler kaymaz, kayitli ilerleme bozulmaz.
const SEED_TAG := "fold-v2"

const RUNTIME_ATTEMPTS := 4000

static var _bank: Dictionary = {}
static var _bank_ready := false


static func difficulty(level: int) -> Dictionary:
	var l := maxi(1, level)
	var cfg := {
		"folds": 2, "max_w": 3, "max_h": 3, "colors": 2,
		"locks": 0, "wild_chance": 0.0, "plant": 0.62, "min_tiles": 4,
	}
	if l <= 3:
		pass
	elif l <= 6:
		cfg.folds = 2; cfg.max_w = 4; cfg.max_h = 4; cfg.colors = 3; cfg.min_tiles = 6
	elif l <= 10:
		cfg.folds = 3; cfg.max_w = 4; cfg.max_h = 4; cfg.colors = 3; cfg.min_tiles = 8
	elif l <= 15:
		cfg.folds = 3; cfg.max_w = 5; cfg.max_h = 4; cfg.colors = 3; cfg.locks = 1; cfg.min_tiles = 8
	elif l <= 22:
		cfg.folds = 3; cfg.max_w = 5; cfg.max_h = 5; cfg.colors = 4; cfg.locks = 1
		cfg.wild_chance = 0.05; cfg.min_tiles = 10
	elif l <= 32:
		cfg.folds = 4; cfg.max_w = 5; cfg.max_h = 5; cfg.colors = 4; cfg.locks = 1
		cfg.wild_chance = 0.06; cfg.min_tiles = 12
	elif l <= 45:
		cfg.folds = 4; cfg.max_w = 6; cfg.max_h = 5; cfg.colors = 4; cfg.locks = 2
		cfg.wild_chance = 0.06; cfg.min_tiles = 12
	else:
		cfg.folds = 5; cfg.max_w = 6; cfg.max_h = 6; cfg.colors = 5; cfg.locks = 2
		cfg.wild_chance = 0.05; cfg.min_tiles = 14
	return cfg


static func generate(level: int) -> Dictionary:
	var cfg := difficulty(level)
	var baked := from_bank(level)
	if not baked.is_empty():
		baked["cfg"] = cfg
		return baked
	return generate_clean(level, cfg)


static func stars(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= par + 1:
		return 2
	return 1


# ------------------------------------------------------------- seviye bankasi

static func _load_bank() -> void:
	if _bank_ready:
		return
	_bank_ready = true
	if not FileAccess.file_exists(BANK_PATH):
		push_warning("Seviye bankasi bulunamadi: " + BANK_PATH)
		return
	var f := FileAccess.open(BANK_PATH, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var p := line.split(" ", false)
		if p.size() != 5:
			continue
		_bank[int(p[0])] = [int(p[1]), int(p[2]), int(p[3]), p[4]]


static func bank_size() -> int:
	_load_bank()
	return _bank.size()


static func from_bank(level: int) -> Dictionary:
	_load_bank()
	if not _bank.has(level):
		return {}
	var e: Array = _bank[level]
	var bytes: PackedByteArray = (e[3] as String).hex_decode()
	var cells := PackedInt32Array()
	cells.resize(bytes.size())
	for i in bytes.size():
		cells[i] = bytes[i]
	if cells.size() != int(e[0]) * int(e[1]):
		push_warning("Bozuk banka satiri, seviye %d" % level)
		return {}
	return {"board": BoardModel.new(int(e[0]), int(e[1]), cells), "par": int(e[2]), "level": level}


# --------------------------------------------------------------- aday uretimi

## Tek bir deterministik aday. Ucuz elemelerden gecemezse null.
static func candidate(level: int, attempt: int, cfg: Dictionary) -> BoardModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/%d" % [SEED_TAG, level, attempt])
	var b := _seed_board(cfg, rng)
	for i in int(cfg.folds):
		var axis := _pick_axis(b, cfg, rng)
		if axis < 0:
			return null
		b = _unfold(b, axis, _pick_flap(b, axis, cfg, rng), cfg, rng)
	if b.w < 3 or b.h < 3:
		return null
	if b.tiles_left() < int(cfg.min_tiles):
		return null
	return b


##
## Derleme anindaki aday puani. Buyuk = daha iyi bulmaca.
##   * cok durum        -> oyuncunun onunde gercek secim var
##   * par hedefte      -> zorluk egrisi tutuyor
##   * tek en kisa yol  -> uc yildiz sansa degil akla kaliyor
##
static func score(a: Dictionary, first: int, cfg: Dictionary) -> int:
	var s := int(a.states) * 4
	if int(a.par) == int(cfg.folds):
		s += 60
	elif int(a.par) == int(cfg.folds) - 1:
		s += 20
	if first == 1:
		s += 45
	elif first == 2:
		s += 12
	return s


##
## Calisma anindaki uretim (banka disi seviyeler): ILK temiz adayi alir.
## Puanlama yapmaz -- amac hiz; kalite bankada.
##
static func generate_clean(level: int, cfg: Dictionary) -> Dictionary:
	var loose: Dictionary = {}
	for attempt in RUNTIME_ATTEMPTS:
		var b := candidate(level, attempt, cfg)
		if b == null:
			continue
		var a := FoldGraph.new().audit(b)
		if not a.clean:
			continue
		var lv := {"board": b, "par": int(a.par), "level": level, "cfg": cfg}
		if int(a.par) >= int(cfg.folds) - 1:
			return lv
		if loose.is_empty():
			loose = lv
	if not loose.is_empty():
		return loose
	return _last_resort(level, cfg)


##
## Son care. Buraya pratikte hic girilmiyor (temiz aday orani ~%6, 4000
## denemede kacirma olasiligi sifira yakin) ama oyunun cozumsuz bir tahta
## acma ihtimali TEORIDE bile kalmasin diye var: elle kurulmus, temizligi
## testle dogrulanan tahta.
##
static func _last_resort(level: int, cfg: Dictionary) -> Dictionary:
	push_warning("Seviye %d icin temiz aday bulunamadi, yedek tahta" % level)
	var b := BoardModel.new(3, 3)
	var col := Tiles.make(Tiles.K_NORMAL, 0)
	b.set_at(0, 1, col)
	b.set_at(2, 1, col)
	var a := FoldGraph.new().audit(b)
	return {"board": b, "par": maxi(1, int(a.par)), "level": level, "cfg": cfg}


# ---------------------------------------------------------------- ic isleyis

static func _seed_board(cfg: Dictionary, rng: RandomNumberGenerator) -> BoardModel:
	var fw := rng.randi_range(1, 2)
	var fh := rng.randi_range(1, 2)
	var b := BoardModel.new(fw, fh)
	var slots: Array[Vector2i] = []
	for y in fh:
		for x in fw:
			slots.append(Vector2i(x, y))
	# rng ile Fisher-Yates (Array.shuffle global RNG kullanir, deterministik degil)
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	var locks := mini(int(cfg.locks), slots.size())
	for i in locks:
		b.set_at(slots[i].x, slots[i].y, Tiles.LOCK)
	return b


static func _pick_axis(b: BoardModel, cfg: Dictionary, rng: RandomNumberGenerator) -> int:
	var room0 := int(cfg.max_w) - b.w
	var room1 := int(cfg.max_h) - b.h
	if room0 < 1 and room1 < 1:
		return -1
	if room0 < 1:
		return 1
	if room1 < 1:
		return 0
	# dar kalan ekseni buyutmeye egilimli ol -> dengeli, kare-ye yakin tahtalar
	return 0 if rng.randf() < float(room0) / float(room0 + room1) else 1


static func _pick_flap(b: BoardModel, axis: int, cfg: Dictionary, rng: RandomNumberGenerator) -> int:
	var n := b.w if axis == 0 else b.h
	var max_n := int(cfg.max_w) if axis == 0 else int(cfg.max_h)
	var hi := mini(n, max_n - n)
	var lo := maxi(1, int(ceil(hi * 0.6)))
	return rng.randi_range(lo, hi)


## Katlamanin tersi: tahtayi `axis` ekseninde `f` kadar acar.
## Ileri katlama (crease g = f, side 0) tam olarak eski tahtayi geri verir.
static func _unfold(b: BoardModel, axis: int, f: int, cfg: Dictionary, rng: RandomNumberGenerator) -> BoardModel:
	var n := b.w if axis == 0 else b.h
	var new_n := n + f
	var nw := new_n if axis == 0 else b.w
	var nh := b.h if axis == 0 else new_n
	var nb := BoardModel.new(nw, nh)
	var other := b.h if axis == 0 else b.w

	for o in other:
		for i in n:
			var code := b.get_at(i, o) if axis == 0 else b.get_at(o, i)
			var ia := i + f          # sabit kalan taraf
			var ib := f - 1 - i      # katlanan taraf (sadece i < f icin var)
			var has_partner := i < f

			if not has_partner:
				_put(nb, axis, ia, o, code)
				continue

			if code == Tiles.EMPTY:
				# Bos sonuc = ya iki taraf da bostu, ya da BIR CIFT PATLADI.
				if rng.randf() < float(cfg.plant):
					var c0 := rng.randi_range(0, int(cfg.colors) - 1)
					var a := Tiles.make(Tiles.K_NORMAL, c0)
					var bb := a
					if rng.randf() < float(cfg.wild_chance):
						if rng.randf() < 0.5:
							a = Tiles.WILD
						else:
							bb = Tiles.WILD
					_put(nb, axis, ia, o, a)
					_put(nb, axis, ib, o, bb)
				# aksi halde ikisi de bos kalir
			else:
				# Dolu sonuc = tas iki taraftan BIRINDE, digeri bos.
				if rng.randf() < 0.5:
					_put(nb, axis, ia, o, code)
				else:
					_put(nb, axis, ib, o, code)
	return nb


static func _put(b: BoardModel, axis: int, i: int, o: int, code: int) -> void:
	if axis == 0:
		b.set_at(i, o, code)
	else:
		b.set_at(o, i, code)
