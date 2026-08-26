extends SceneTree
##
## Seviye bankasini uretir:  godot --headless --path . --script res://tools/bake_levels.gd
##
## Her seviye icin yuzlerce aday uretilir, hepsi FoldGraph ile TAM denetimden
## gecirilir ve icinde CIKMAZ olan adaylar elenir. Kalanlar arasindan en iyi
## bulmaca secilir (cok secenek + tek en kisa cozum + hedef par).
##
## Bu is cihazda degil BURADA yapiliyor: aday basina birkac ms, seviye basina
## yuzlerce aday. Oyuncunun telefonunda sadece hazir tahta okunuyor.
##

const COUNT := 500
const ATTEMPTS := 300
const OUT := "res://levels/levels.txt"


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var lines := PackedStringArray()
	lines.append("# FOLDERA seviye bankasi -- tools/bake_levels.gd ile uretilmistir")
	lines.append("# bicim: seviye w h par hucreler(hex)")
	lines.append("# GARANTI: her satir cikmazsiz -- hangi sirayla katlanirsa katlansin cozulur")

	var uniq := 0
	var sum_states := 0
	var sum_par := 0
	var thin := 0
	for level in range(1, COUNT + 1):
		var cfg := LevelGen.difficulty(level)
		var best := {}
		var best_score := -1
		var clean := 0
		for attempt in ATTEMPTS:
			var b := LevelGen.candidate(level, attempt, cfg)
			if b == null:
				continue
			var g := FoldGraph.new()
			var a := g.audit(b)
			if not a.clean:
				continue
			clean += 1
			var first := g.optimal_first_count(b)
			var sc := LevelGen.score(a, first, cfg)
			if sc > best_score:
				best_score = sc
				best = {"b": b, "a": a, "first": first}
		if best.is_empty():
			push_error("Seviye %d icin temiz aday YOK" % level)
			quit(1)
			return
		var b2: BoardModel = best.b
		var a2: Dictionary = best.a
		if int(best.first) == 1:
			uniq += 1
		if int(a2.states) < 6:
			thin += 1
		sum_states += int(a2.states)
		sum_par += int(a2.par)
		var bytes := PackedByteArray()
		bytes.resize(b2.cells.size())
		for i in b2.cells.size():
			bytes[i] = b2.cells[i]
		lines.append("%d %d %d %d %s" % [level, b2.w, b2.h, int(a2.par), bytes.hex_encode()])
		if level % 50 == 0:
			print("  %d/%d  (temiz aday %d/%d)" % [level, COUNT, clean, ATTEMPTS])

	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("Yazilamadi: " + OUT)
		quit(1)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n%d seviye -> %s  (%.1f KB)" % [
		COUNT, OUT, float(FileAccess.get_file_as_bytes(OUT).size()) / 1024.0])
	print("tek en kisa cozum: %d/%d   ortalama durum %.1f   ortalama par %.2f   dar tahta %d" % [
		uniq, COUNT, float(sum_states) / COUNT, float(sum_par) / COUNT, thin])
	print("sure %.1f sn" % [(Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
