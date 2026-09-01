extends SceneTree
## Headless mantik testleri:  godot --headless --script res://tests/test_logic.gd

var failed := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failed += 1
		print("  FAIL: ", msg)


func _initialize() -> void:
	print("\n=== FOLDERA mantik testleri ===\n")
	t_encoding()
	t_merge()
	t_fold_basics()
	t_mirror_equivalence()
	t_generator()
	t_random_play()
	t_hint_wallet()
	t_ad_policy()
	t_store_gate()
	t_localization()
	t_device_language()
	t_kurulum()
	print("\n%d kontrol, %d hata" % [checks, failed])
	quit(1 if failed > 0 else 0)


func t_encoding() -> void:
	print("- kodlama")
	for k in [Tiles.K_NORMAL, Tiles.K_LOCK, Tiles.K_WILD]:
		for c in Tiles.COLOR_COUNT:
			var code := Tiles.make(k, c)
			check(Tiles.kind(code) == k and Tiles.color(code) == c, "kodlama %d/%d" % [k, c])
	check(Tiles.kind(Tiles.EMPTY) == Tiles.K_EMPTY, "bos hucre kind 0")
	check(Tiles.LOCK == Tiles.make(Tiles.K_LOCK, 0), "LOCK sabiti")
	check(Tiles.WILD == Tiles.make(Tiles.K_WILD, 0), "WILD sabiti")


func t_merge() -> void:
	print("- birlesme kurallari")
	var r := Tiles.make(Tiles.K_NORMAL, 0)
	var g := Tiles.make(Tiles.K_NORMAL, 1)
	check(Tiles.merge(Tiles.EMPTY, Tiles.EMPTY) == Tiles.EMPTY, "bos+bos")
	check(Tiles.merge(r, Tiles.EMPTY) == r, "tas+bos")
	check(Tiles.merge(Tiles.EMPTY, r) == r, "bos+tas")
	check(Tiles.merge(r, r) == Tiles.EMPTY, "ayni renk patlar")
	check(Tiles.merge(r, g) == Tiles.ILLEGAL, "farkli renk yasak")
	check(Tiles.merge(r, Tiles.LOCK) == Tiles.ILLEGAL, "mandal ustune tas yasak")
	check(Tiles.merge(Tiles.LOCK, Tiles.EMPTY) == Tiles.LOCK, "mandal bosa kayabilir")
	check(Tiles.merge(Tiles.LOCK, Tiles.LOCK) == Tiles.ILLEGAL, "mandal+mandal yasak")
	check(Tiles.merge(Tiles.WILD, g) == Tiles.EMPTY, "joker her renkle patlar")
	check(Tiles.merge(Tiles.WILD, Tiles.LOCK) == Tiles.ILLEGAL, "joker mandali acamaz")
	check(Tiles.merge(r, g) == Tiles.merge(g, r), "birlesme simetrik")


func t_fold_basics() -> void:
	print("- katlama geometrisi")
	var r := Tiles.make(Tiles.K_NORMAL, 0)
	var g := Tiles.make(Tiles.K_NORMAL, 1)

	# 4x1:  [r . . r]  -> ortadan katla -> [. .]  (iki r ust uste gelir)
	var b := BoardModel.new(4, 1, PackedInt32Array([r, Tiles.EMPTY, Tiles.EMPTY, r]))
	var res := b.fold(0, 2, 0)
	check(res.ok, "ortadan katlama gecerli")
	check(res.w == 2 and res.h == 1, "4x1 -> 2x1")
	check(res.pops.size() == 1, "bir cift patladi")
	check(BoardModel.new(res.w, res.h, res.cells).is_solved(), "tahta temizlendi")

	# genislik formulu: yeni_n == max(g, n-g), her zaman kucuk
	for n in range(2, 9):
		for cg in range(1, n):
			for side in [0, 1]:
				var bb := BoardModel.new(n, 1)
				var rr := bb.fold(0, cg, side)
				check(rr.ok, "bos tahta her zaman katlanir n=%d g=%d" % [n, cg])
				check(rr.w == maxi(cg, n - cg), "genislik n=%d g=%d" % [n, cg])
				check(rr.w < n, "kagit her katlamada kuculur n=%d g=%d" % [n, cg])

	# cakisma: farkli renkler ust uste gelemez
	var c := BoardModel.new(2, 1, PackedInt32Array([r, g]))
	check(not c.fold(0, 1, 0).ok, "farkli renk katlamasi reddedilir")
	check(c.fold(0, 1, 0).conflicts.size() == 1, "cakisma isaretlendi")

	# gecersiz kat cizgisi
	check(not b.fold(0, 0, 0).ok, "g=0 gecersiz")
	check(not b.fold(1, 1, 0).ok, "tek satirda yatay kat yok")

	# tas asla tahtanin disina tasmaz
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for iter in 400:
		var w := rng.randi_range(1, 6)
		var hh := rng.randi_range(1, 6)
		var data := PackedInt32Array()
		for i in w * hh:
			data.append(Tiles.EMPTY if rng.randf() < 0.5 else Tiles.make(Tiles.K_NORMAL, rng.randi_range(0, 2)))
		var bd := BoardModel.new(w, hh, data)
		for cr in bd.creases():
			for side in [0, 1]:
				var rs := bd.fold(cr[0], cr[1], side)
				if not rs.ok:
					continue
				check(rs.w >= 1 and rs.h >= 1, "gecerli boyut")
				check(rs.w <= bd.w and rs.h <= bd.h, "hicbir eksen buyumez")
				check(rs.w < bd.w or rs.h < bd.h, "en az bir eksen kuculur")
				for m in rs.moves:
					var t: Vector2i = m.to
					check(t.x >= 0 and t.x < rs.w and t.y >= 0 and t.y < rs.h, "hedef tahta icinde")


func t_mirror_equivalence() -> void:
	print("- side 0 / side 1 ayna esdegerligi")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for iter in 200:
		var w := rng.randi_range(2, 6)
		var data := PackedInt32Array()
		for i in w:
			data.append(Tiles.EMPTY if rng.randf() < 0.4 else Tiles.make(Tiles.K_NORMAL, rng.randi_range(0, 2)))
		var b := BoardModel.new(w, 1, data)
		for cg in range(1, w):
			var a := b.fold(0, cg, 0)
			var c := b.fold(0, cg, 1)
			check(a.ok == c.ok, "iki yon ayni gecerlilige sahip")
			if not a.ok:
				continue
			var av: Array = Array(a.cells)
			var cv: Array = Array(c.cells)
			cv.reverse()
			check(av == cv, "side1 == side0'in aynasi (w=%d g=%d)" % [w, cg])


##
## En kritik test. Eskiden burada sadece "seviyenin BIR cozumu var mi" diye
## bakiliyordu; oyuncunun gecerli ama olumcul bir katlama yapip cozumsuz bir
## tahtada kalabilmesi gozden kaciyordu. Artik her seviyenin ULASILABILIR
## BUTUN DURUMLARI denetleniyor.
##
func t_generator() -> void:
	var n := LevelGen.bank_size()
	print("- seviye bankasi (%d seviye)" % n)
	check(n >= 500, "banka yuklendi (%d seviye)" % n)

	# Once denetleyicinin kendisi: cozumu OLAN ama icinde cikmaz BULUNAN elle
	# kurulmus tahta "kirli" cikmali. Bu kontrol olmadan bozuk bir audit()
	# her seye temiz der ve asagidaki 500 kontrolun hepsi bosa duser.
	var trap := BoardModel.new(4, 4, PackedInt32Array(
		[0, 0, 0, 16, 0, 0, 16, 0, 18, 16, 0, 18, 16, 16, 16, 0]))
	var ta := FoldGraph.new().audit(trap)
	check(ta.solvable, "tuzak tahtanin bir cozumu var")
	check(not ta.clean, "tuzak tahta KIRLI isaretlendi (cikmaz: %d)" % int(ta.dead))

	var t0 := Time.get_ticks_msec()
	var total_par := 0
	var total_states := 0
	var uniq := 0
	for level in range(1, n + 1):
		var lv := LevelGen.generate(level)
		var b: BoardModel = lv.board
		var par: int = lv.par
		total_par += par
		check(b.w >= 3 and b.h >= 3, "seviye %d tahta boyutu %dx%d" % [level, b.w, b.h])
		check(b.tiles_left() >= 4, "seviye %d yeterli tas" % level)
		check(par >= 1, "seviye %d par >= 1" % level)
		var g := FoldGraph.new()
		var a := g.audit(b)
		# ASIL GARANTI: ulasilabilen hicbir durum cikmaz degil. Yani oyuncu
		# hangi sirayla katlarsa katlasin tahta cozulebilir kalir.
		check(a.clean, "seviye %d CIKMAZSIZ (cikmaz durum: %d)" % [level, int(a.dead)])
		check(int(a.par) == par, "seviye %d bankadaki par grafikle uyusuyor" % level)
		total_states += int(a.states)
		if g.optimal_first_count(b) == 1:
			uniq += 1
	print("  %d seviye %d ms, ortalama par %.2f, ortalama durum %.1f, tek cozum %d/%d" % [
		n, Time.get_ticks_msec() - t0, float(total_par) / n, float(total_states) / n, uniq, n])

	# Capraz kontrol: grafik ile BAGIMSIZ IDDFS cozucusu ayni par degerini
	# bulmali. Iki ayri uygulama ayni hatayi yapmaz.
	for level in range(1, 121):
		var lv2 := LevelGen.generate(level)
		var solver := FoldSolver.new()
		var found := solver.min_folds(lv2.board, int(lv2.par))
		check(found == int(lv2.par), "seviye %d capraz kontrol (cozucu %d, banka %d)" % [
			level, found, int(lv2.par)])

	# Banka disi seviye: calisma anindaki uretim ayni garantiyi vermeli
	var beyond := n + 7
	var t1 := Time.get_ticks_msec()
	var lv3 := LevelGen.generate(beyond)
	var dt3 := Time.get_ticks_msec() - t1
	check(FoldGraph.new().audit(lv3.board).clean, "banka disi seviye %d de cikmazsiz" % beyond)
	print("  banka disi seviye %d ms icinde uretildi" % dt3)

	# Son care tahtasi (uretim tamamen basarisiz olursa) da temiz olmali
	var lr := LevelGen._last_resort(1, LevelGen.difficulty(1))
	check(FoldGraph.new().audit(lr.board).clean, "son care tahtasi cikmazsiz")


func t_hint_wallet() -> void:
	print("- ipucu cuzdani")
	var w := HintWallet.new()
	check(w.refresh("2026-01-01"), "ilk gun kontenjan acilir")
	check(w.total() == HintWallet.DAILY_FREE, "gun basi %d bedava" % HintWallet.DAILY_FREE)
	check(not w.refresh("2026-01-01"), "ayni gun tekrar yenilenmez")

	# bedava kontenjan ONCE harcanmali -- satin alinan gun sonunda kaybolmasin
	w.grant(2)
	check(w.total() == HintWallet.DAILY_FREE + 2, "satin alinan eklenir")
	for i in HintWallet.DAILY_FREE:
		check(w.spend(), "bedava ipucu harcanir")
	check(w.free_left == 0 and w.purchased == 2, "once bedava tukendi, satin alinan durdu")

	check(w.refresh("2026-01-02"), "yeni gun kontenjani yeniler")
	check(w.purchased == 2, "gun degisimi satin alinani SILMEZ")
	check(w.total() == HintWallet.DAILY_FREE + 2, "toplam dogru")

	# tukenme
	var e := HintWallet.new()
	e.refresh("2026-01-01")
	while e.spend():
		pass
	check(not e.can_spend(), "tukenince harcanamaz")
	check(e.total() == 0, "bakiye sifir")
	check(not e.spend(), "bos cuzdan false doner")

	# kalicilik
	var a := HintWallet.new()
	a.refresh("2026-03-05")
	a.spend()
	a.grant(7)
	var b := HintWallet.new()
	b.from_dict(a.to_dict())
	check(b.day == a.day and b.free_left == a.free_left and b.purchased == a.purchased,
		"kaydet/yukle turu bozulmaz")
	# bozuk veriye dayaniklilik
	var c := HintWallet.new()
	c.from_dict({"free_left": 999, "purchased": -5})
	check(c.free_left <= HintWallet.DAILY_FREE, "bozuk kayit kontenjani sismez")
	check(c.purchased >= 0, "negatif bakiye olusmaz")


func t_ad_policy() -> void:
	print("- reklam frekans politikasi")
	var base := {
		"level": 20, "levels_since_ad": 3, "seconds_since_ad": 120.0,
		"seconds_since_reward": 9999.0, "ads_removed": false,
	}
	check(AdPolicy.should_show_interstitial(base), "kosullar saglaninca gosterilir")

	# ilk seviyeler korumali
	for lv in range(1, AdPolicy.FIRST_FREE_LEVELS + 1):
		var s := base.duplicate()
		s.level = lv
		check(not AdPolicy.should_show_interstitial(s), "seviye %d reklamsiz" % lv)
	var s11 := base.duplicate()
	s11.level = AdPolicy.FIRST_FREE_LEVELS + 1
	check(AdPolicy.should_show_interstitial(s11), "koruma bittikten sonra gosterilir")

	# seviye araligi
	for n in range(0, AdPolicy.EVERY_N_LEVELS):
		var s2 := base.duplicate()
		s2.levels_since_ad = n
		check(not AdPolicy.should_show_interstitial(s2), "%d seviye sonra hala erken" % n)

	# zaman tavani: hizli biten seviyeler reklam yagmuruna donmemeli
	var fast := base.duplicate()
	fast.seconds_since_ad = AdPolicy.MIN_GAP_SECONDS - 1.0
	check(not AdPolicy.should_show_interstitial(fast), "90 sn dolmadan reklam yok")

	# gonullu reklam ustune zorunlu reklam bindirilmez
	var after_reward := base.duplicate()
	after_reward.seconds_since_reward = 5.0
	check(not AdPolicy.should_show_interstitial(after_reward), "odullu sonrasi bekleme var")

	# satin alma her seyi kapatir
	var paid := base.duplicate()
	paid.ads_removed = true
	check(not AdPolicy.should_show_interstitial(paid), "reklamsiz satin alma kapatir")
	var paid2 := base.duplicate()
	paid2.ads_removed = true
	paid2.levels_since_ad = 99
	paid2.seconds_since_ad = 99999.0
	check(not AdPolicy.should_show_interstitial(paid2), "reklamsiz kosullardan bagimsiz kapali")

	# reklamsiz teklifi
	check(not AdPolicy.should_offer_no_ads(0, false, false), "hic reklam gormeden teklif yok")
	check(AdPolicy.should_offer_no_ads(AdPolicy.OFFER_AFTER_INTERSTITIALS, false, false),
		"esik asilinca teklif gelir")
	check(not AdPolicy.should_offer_no_ads(99, false, true), "teklif iki kere gosterilmez")
	check(not AdPolicy.should_offer_no_ads(99, true, false), "satin alana teklif gosterilmez")


## Yerellestirme, kullaniciya EN HIZLI sizan hata turu: eksik bir anahtar
## ekranda ham "BTN_PLAY" yazisi olarak gorunur, bozuk bir bicim belirteci
## ise cokme uretir. Ucunu de burada yakaliyoruz.
func t_localization() -> void:
	print("- yerellestirme")
	var f := FileAccess.open("res://locale/foldera.csv", FileAccess.READ)
	check(f != null, "ceviri dosyasi acilabiliyor")
	if f == null:
		return

	var header := f.get_csv_line()
	var locales: Array = Array(header).slice(1)
	check(locales.size() >= 10, "en az 10 dil var (bulunan: %d)" % locales.size())
	for code in Loc.SUPPORTED:
		check(locales.has(code), "Loc.SUPPORTED icindeki %s dili tabloda var" % code)
	for code in locales:
		check(Loc.SUPPORTED.has(code), "tablodaki %s dili Loc.SUPPORTED icinde" % code)
		check(Loc.NATIVE_NAME.has(code), "%s dilinin kendi dilindeki adi tanimli" % code)

	var keys := {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		var key: String = row[0]
		check(not keys.has(key), "anahtar tekrar etmiyor: %s" % key)
		check(row.size() == header.size(),
			"%s: %d sutun bekleniyordu, %d bulundu" % [key, header.size(), row.size()])
		var en_fmt := -1
		for i in range(1, mini(row.size(), header.size())):
			var text: String = row[i]
			var code: String = locales[i - 1]
			check(text.strip_edges() != "", "%s / %s cevirisi bos degil" % [key, code])
			# CSV'de kacisli satir sonu Label'da duz "\n" olarak gorunur
			check(not text.contains("\n"), "%s / %s kacisli satir sonu icermiyor" % [key, code])
			# Bicim belirteclerinin SAYISI tum dillerde ayni olmali, yoksa
			# Loc.f() ya cokerr ya da yanlis deger basar.
			var n := _count_format(text)
			if i == 1:
				en_fmt = n
			else:
				check(n == en_fmt,
					"%s / %s bicim belirteci sayisi ingilizceyle ayni (%d vs %d)"
						% [key, code, n, en_fmt])
		keys[key] = true
	f.close()
	check(keys.size() > 40, "beklenen sayida anahtar var (%d)" % keys.size())

	# Kodda kullanilan her anahtar tabloda olmali.
	var used := {}
	_collect_loc_keys("res://scripts", used)
	check(used.size() > 30, "kodda anahtar kullanimi bulundu (%d)" % used.size())
	for k in used:
		check(keys.has(k), "kodda kullanilan '%s' anahtari cevirilerde tanimli" % k)


func _count_format(s: String) -> int:
	var n := 0
	for spec in ["%d", "%s", "%f"]:
		n += s.count(spec)
	return n


func _collect_loc_keys(dir_path: String, out: Dictionary) -> void:
	var re := RegEx.new()
	# Ham dize (r"") kullaniyoruz: normal dizede ters bolu kacislari iki kez
	# kacmak gerekiyor ve regex okunmaz hale geliyor.
	re.compile(r'Loc\.[tf]\("([A-Z0-9_]+)"')
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			_collect_loc_keys(full, out)
		elif name.ends_with(".gd"):
			var src := FileAccess.get_file_as_string(full)
			for m in re.search_all(src):
				out[m.get_string(1)] = true
		name = d.get_next()
	d.list_dir_end()


## Cihazin diline gore acilma zinciri. Bu, kullanicinin oyunu ILK actiginda
## gordugu sey -- yanlissa herkes Ingilizce (ya da Turkce) goruyor.
func t_device_language() -> void:
	print("- cihaz dili")
	print("    OS.get_locale()          = ", OS.get_locale())
	print("    OS.get_locale_language() = ", OS.get_locale_language())
	print("    cozumlenen dil           = ", Loc.resolve_system())

	# Desteklenen diller oldugu gibi gecer
	for code in Loc.SUPPORTED:
		check(Loc.pick(code) == code, "%s destekleniyor, oldugu gibi kalir" % code)

	# Bolgesel varyantlar taban dile iner
	check(Loc.pick("pt_BR") == "pt", "pt_BR -> pt")
	check(Loc.pick("en_US") == "en", "en_US -> en")
	check(Loc.pick("de_AT") == "de", "de_AT -> de")
	check(Loc.pick("ru_RU") == "ru", "ru_RU -> ru")

	# Desteklemedigimiz diller Ingilizce'ye duser (ham anahtar DEGIL)
	for code in ["ja", "zh_CN", "ko", "ar", "hi", "th", "el", "sv"]:
		check(Loc.pick(code) == "en", "%s -> en (destegimizde yok)" % code)

	check(Loc.pick("") == "en", "bos kod -> en")
	check(Loc.pick("EN") == "en", "buyuk harf kod -> en")

	# Cihazin gercek dili her zaman gecerli bir secenege cozulmeli
	check(Loc.SUPPORTED.has(Loc.resolve_system()), "cihaz dili gecerli bir dile cozuluyor")

	# Zincirin tamami: kayitli tercih yokken cihaz dili uygulanmali ve
	# ceviriler GERCEKTEN gelmeli (anahtarin kendisi degil).
	var before := TranslationServer.get_locale()
	Loc.apply("")
	check(Loc.current() == Loc.resolve_system(), "tercih yokken cihaz dili uygulanir")
	check(Loc.t("BTN_PLAY") != "BTN_PLAY", "cihaz dilinde ceviri geliyor")

	# Elle secim cihaz dilini ezmeli
	Loc.apply("de")
	check(Loc.current() == "de", "elle secim uygulanir")
	check(Loc.t("BTN_PLAY") == "SPIELEN", "elle secilen dilin metni geliyor")

	# Her dilde ornek anahtarlar cevrilmis olmali
	for code in Loc.SUPPORTED:
		Loc.apply(code)
		for key in ["BTN_PLAY", "BTN_UNDO", "HINT_EMPTY_TITLE", "TEACH_LOCK_BODY"]:
			check(Loc.t(key) != key, "%s dilinde %s cevrilmis" % [code, key])
	TranslationServer.set_locale(before)


##
## Cikmazsizlik garantisinin BAGIMSIZ dogrulamasi. Grafik denetimi yalnizca
## side 0 katlamalarini tariyor ve side 1'in aynasi oldugunu VARSAYIYOR. Burada
## rastgele oyuncu iki tarafi da kullanarak oynuyor: hicbir oyun cikmaza
## dusmemeli. Ayni zamanda oyunun kolaylasip kolaylasmadigini olcuyor --
## kaybedemiyor olmak, dusunmeden kazaniyor olmak demek degil.
##
func t_random_play() -> void:
	print("- rastgele oyun (cikmaz avi + zorluk olcumu)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	const RUNS := 4
	var star_hist := [0, 0, 0, 0]
	var sum_ratio := 0.0
	var n := LevelGen.bank_size()
	for level in range(1, n + 1):
		var lv := LevelGen.generate(level)
		for r in RUNS:
			var b: BoardModel = (lv.board as BoardModel).duplicate_board()
			var mv := 0
			while not b.is_solved() and mv < 40:
				var legal: Array = []
				for c in b.creases():
					for side in 2:
						var res := b.fold(c[0], c[1], side)
						if res.ok:
							legal.append(res)
				if legal.is_empty():
					break
				b.apply(legal[rng.randi_range(0, legal.size() - 1)])
				mv += 1
			# ASIL IDDIA: nasil oynarsan oyna tahta temizlenir
			check(b.is_solved(), "seviye %d rastgele oyun %d bitirildi (%d hamle)" % [level, r, mv])
			if b.is_solved():
				star_hist[LevelGen.stars(mv, int(lv.par))] += 1
				sum_ratio += float(mv) / float(lv.par)
	var total := n * RUNS
	print("  %d oyun: 1 yildiz %%%.0f, 2 yildiz %%%.0f, 3 yildiz %%%.0f, hamle/par %.2f" % [
		total, 100.0 * star_hist[1] / total, 100.0 * star_hist[2] / total,
		100.0 * star_hist[3] / total, sum_ratio / float(total)])
	# Kaybedilemeyen oyun, dusunulmeden kazanilan oyun degil: rastgele oynayan
	# uc yildizi nadiren almali, yoksa yildiz sistemi anlamsizlasir.
	check(star_hist[3] < total / 3, "rastgele oyun uc yildizi zor aliyor (%d/%d)" % [star_hist[3], total])


## Sahte odeme akisinin uretime sizmasi ENGELLENDI mi.
##
## Karar tablosu tam olarak dort satir; dordunu de sabitliyoruz ki ileride
## biri kosulu tersine cevirdiginde test dussun.
func t_store_gate() -> void:
	print("- satin alma kapisi")
	# Autoload adi `--script` kosusunda derleyiciye gorunmuyor; betigi dogrudan
	# yukleyip statik fonksiyonu cagiriyoruz.
	var S := load("res://scripts/store/store_service.gd")
	# sahte magaza + uretim  -> teklif YOK  (asil korudugumuz durum)
	check(not S.offers_allowed(true, true), "sahte magaza uretimde teklif sunmaz")
	# sahte magaza + test derlemesi -> teklif VAR (ic testte akis denenebilsin)
	check(S.offers_allowed(true, false), "sahte magaza testte teklif sunar")
	# gercek Billing -> her iki derlemede de teklif VAR
	check(S.offers_allowed(false, true), "gercek Billing uretimde teklif sunar")
	check(S.offers_allowed(false, false), "gercek Billing testte teklif sunar")


## KURULUM DENETIMI.
##
## Buradaki her satir, YASANMIS ve SESSIZ bir arizanin karsiligi. Ortak
## ozellikleri sunlar: oyun derleniyor, aciliyor, oynaniyor -- ve tek bir
## hata mesaji vermeden yanlis calisiyor. Hicbiri oynayarak fark
## edilemiyor, cogu ancak magazada ya da AdMob panosunda haftalar sonra
## goruluyor.
##
## O yuzden denetim bir kontrol listesi degil, TEST. Kontrol listesi
## unutuluyor; test dusuyor.
func t_kurulum() -> void:
	print("- kurulum denetimi")

	# 1) EKRAN YONU. `handheld/orientation` bir TAM SAYI enum: 0=YATAY
	# (varsayilan), 1=DIKEY. Metin ("portrait") yazilirsa sessizce yok
	# sayiliyor ve oyun telefonda yatay aciliyor. Fusera'da bu ancak
	# cihazda fark edildi.
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == 1,
		"ekran yonu DIKEY (tam sayi 1)")

	# 2) ETC2/ASTC olmadan Android disa aktarimi dokulari reddediyor.
	check(bool(ProjectSettings.get_setting(
		"rendering/textures/vram_compression/import_etc2_astc", false)),
		"ETC2/ASTC doku sikistirmasi acik")

	# 3) EKLENTI KAYDI. `project.godot` bir ConfigFile ve yorum karakteri
	# TEK noktali virgul. `##` ile yorum yazilirsa Godot bolum basliklarini
	# ayristiramiyor, [editor_plugins] sessizce kayboluyor ve reklam +
	# satin alma derlemeye HIC girmiyor. Belirti, derleme gunlugundeki bir
	# satirin YOKLUGU. Fusera'da tam olarak bu oldu.
	var eklenti := PackedStringArray(ProjectSettings.get_setting(
		"editor_plugins/enabled", PackedStringArray()))
	for yol in ["res://addons/admob/plugin.cfg",
			"res://addons/GodotGooglePlayBilling/plugin.cfg"]:
		check(eklenti.has(yol), "eklenti kayitli: %s" % yol)

	# 4) AdMob UYGULAMA KIMLIGI.
	#
	# Ayarin `project.godot`ta GORUNMEMESI tek basina hata degil: eklenti
	# ayari Google'in TEST uygulama kimligiyle kayitliyor ve Godot,
	# varsayilanina esit olan hicbir ayari dosyaya yazmiyor. Disa aktarimda
	# ayni varsayilan yeniden geliyor, yani manifest dogru dolduruluyor.
	#
	# ONEMLI OLAN SU: canli reklam birimleri doldurulmussa uygulama kimligi
	# de GERCEK olmali. Aksi halde istekler Google'in test uygulamasina
	# gidiyor -- birimler canli, oyun calisiyor, panoda tek istek yok.
	var test_app_id := "ca-app-pub-3940256099942544~3347511713"
	var pg := FileAccess.get_file_as_string("res://project.godot")
	var gercek_kimlik := pg.contains("general/android/app_id=") \
		and not pg.contains(test_app_id)
	if AdMobAdProvider.canli_birimler_hazir():
		check(gercek_kimlik,
			"canli birim varken AdMob uygulama kimligi de gercek olmali")
	else:
		print("  NOT: AdMob uygulama kimligi TEST kimligi -- canli birimlerle"
			+ " birlikte guncellenecek")

	# 5) IKONLAR. Yollar `export_presets.cfg`ten OKUNUYOR, teste sabit
	# yazilmiyor: asil risk bir on ayarin VAR OLMAYAN dosyayi gostermesi.
	# Bos birakilan alan ise Godot'un varsayilan robot simgesiyle
	# derlenmesine yol aciyor ve bu, magaza listesinde fark edilmiyor.
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	var re_ikon := RegEx.create_from_string(
		r'launcher_icons/[a-z0-9_]+="(res://[^"]+)"')
	var gorulen := {}
	for m in re_ikon.search_all(ep):
		var yol := m.get_string(1)
		if gorulen.has(yol):
			continue
		gorulen[yol] = true
		check(ResourceLoader.exists(yol), "on ayardaki ikon var: %s" % yol)
	check(gorulen.size() >= 3,
		"on ayarda ikon yollari tanimli (%d)" % gorulen.size())
	# 6) REKLAM BASLATMA ZINCIRI -- bu oyunun en pahali sessiz hatasi.
	#
	# Fusera'da riza akisi yoktu; yerine `if consent_mode != "": _init_sdk()`
	# vardi. `Save.consent` ilk kurulumda "" ve hicbir yerde doldurulmuyor,
	# yani MobileAds.initialize() HIC cagrilmiyor: tek reklam istegi
	# cikmiyor, kod dogru gorunuyor, gelir sifir.
	var kod := _kodu_oku("res://scripts/ads/admob_ad_provider.gd")
	check(kod != "", "reklam saglayicisi okunabiliyor")
	check(not kod.contains('consent_mode != ""'),
		"SDK baslatma bos bir riza dizesine BAGLI DEGIL")
	check(kod.contains("_request_consent()"), "UMP riza akisi cagriliyor")
	# Iki gozcu: biri riza akisi hic donmezse, digeri SDK baslatma geri
	# cagrisi hic donmezse devreye giriyor. Foldera'da ikincisi eksikti ve
	# panoda iki gun boyunca "istek: 0" goruldu.
	check(kod.contains("func _gozcu_baslat"), "riza gozcusu var")
	check(kod.contains("func _yukleme_gozcusu"), "yukleme gozcusu var")
	check(kod.count("preload_all()") >= 2,
		"preload_all hem SDK geri cagrisindan hem gozcuden cagriliyor")

	# 7) CANLI BIRIM KAPISI. Bos birim kimligiyle AdMob istegi sessizce
	# basarisiz oluyor; "liveads" etiketli bir derlemede bu, gelirin
	# tamaminin kaybi demek ve baska hicbir belirtisi yok.
	check(kod.contains("canli_birimler_hazir()"),
		"canli birim kapisi yerinde")

	# 8) ANDROID DERLEME SABLONU. `android/` varsa icinde `.gdignore`
	# BULUNMALI: yoksa duzenleyici o dizini normal proje icerigi saniyor,
	# ilk derleme geciyor, ikincisi kendi ciktisini yeniden icine alip kat
	# kat derinlesen yollarda cokuyor. Hata mesaji eksik bir dosyadan soz
	# ettigi icin asil nedeni gostermiyor.
	var kok := ProjectSettings.globalize_path("res://")
	if DirAccess.dir_exists_absolute(kok + "android"):
		check(FileAccess.file_exists(kok + "android/.gdignore"),
			"android/.gdignore var")
	else:
		print("  NOT: android/ yok -- derleme sablonu henuz kurulmamis")


## Kaynak dosyayi YORUM SATIRLARI ATILMIS halde okur.
##
## Sart: bu dosyalarin aciklamalari eski hatalari ORNEK OLARAK iceriyor,
## yani ham metinde arama yapmak kendi aciklamamizi hata sanip yanlis
## alarm veriyor. Denetimin ilk halinde tam olarak bu oldu.
func _kodu_oku(yol: String) -> String:
	if not FileAccess.file_exists(yol):
		return ""
	var out := ""
	for satir in FileAccess.get_file_as_string(yol).split("\n"):
		if satir.strip_edges().begins_with("#"):
			continue
		out += satir + "\n"
	return out
