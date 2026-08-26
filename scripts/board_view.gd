class_name BoardView
extends Node2D
##
## Katlama hem GIRDI hem ANIMASYON. Parmak kagidi tutar, kat cizgisi etrafinda
## dondurur; olcek ekseni 1 -> 0 -> -1 arasinda gezerken kagit tam aynalanir.
## Tam da fizigin yaptigi sey oldugu icin taslarin nereye indigi hep dogru cikar.
##
## Birakma esigi asilmadiysa kagit geri yaylanir. Gecersiz katlamada kirmizi
## carpilar ve tok bir ses var -- ceza yok, sadece bilgi.
##

signal fold_committed(moves: int)
signal solved(moves: int)
signal stuck()
signal invalid_fold()
signal impact(strength: float)

const MAX_CELL := 190.0
const COMMIT_AT := 0.40
const AXIS_LOCK := 0.16

var model: BoardModel
var level_data := {}

## Seviyenin ULASILABILIR DURUM GRAFIGI. Seviye acilirken bir kez cikariliyor
## (birkac ms) ve seviye boyunca duruyor. Iki isi var:
##   * ipucu -> arama degil dogrudan okuma; eski IDDFS cozucusu derinlik
##     limitine takilip bos donebiliyordu, bu donmez.
##   * emniyet kemeri -> her katlamadan sonra tahtanin hala cozulebilir oldugu
##     dogrulaniyor. Seviyeler cikmazsiz uretildigi icin bu asla tetiklenmemeli;
##     tetiklenirse hata sessizce gecmesin diye var.
var graph: FoldGraph = null
var cs := 100.0
var board_offset := Vector2.ZERO
var moves := 0
var par := 3
var interactive := false

var _play_size := Vector2(720, 900)
var _paper: PaperSheet
var _overlay: OverlayLayer
var _tiles: Node2D
var _flap: Node2D
var _flap_paper: PaperSheet
var _flap_tiles: Node2D
var _confetti: Confetti
var _views := {}
var _folded := {}
var _undo: Array = []

var _dragging := false
var _start := Vector2.ZERO
var _cell := Vector2i.ZERO
var _locked := false
var _axis := 0
var _g := 1
var _side := 0
var _t := 0.0
var _need := 100.0
var _prev: Dictionary = {}
var _rustle_cd := 0.0
var _gesture: GestureHint = null
var auto_playing := false

## Jesti hangi isaretcinin sahiplendigi. Dokunma ile fare taklidi ayni jesti
## iki kez islemesin diye.
const POINTER_NONE := 0
const POINTER_TOUCH := 1
const POINTER_MOUSE := 2
var _pointer := POINTER_NONE


func _ready() -> void:
	_paper = PaperSheet.new()
	_paper.z_index = 0
	add_child(_paper)

	_overlay = OverlayLayer.new()
	_overlay.z_index = 2
	add_child(_overlay)

	_tiles = Node2D.new()
	_tiles.z_index = 4
	add_child(_tiles)

	_flap = Node2D.new()
	_flap.z_index = 10
	add_child(_flap)
	_flap_paper = PaperSheet.new()
	_flap_paper.elevated = true
	_flap.add_child(_flap_paper)
	_flap_tiles = Node2D.new()
	_flap.add_child(_flap_tiles)
	_flap.visible = false

	_confetti = Confetti.new()
	_confetti.z_index = 30
	add_child(_confetti)


func set_play_size(s: Vector2) -> void:
	_play_size = s


# ------------------------------------------------------------------ seviye

func load_level(lv: Dictionary) -> void:
	level_data = lv
	model = (lv.board as BoardModel).duplicate_board()
	par = int(lv.par)
	graph = FoldGraph.new()
	graph.audit(model)
	moves = 0
	_undo.clear()
	_folded.clear()
	_pointer = POINTER_NONE
	_kill_gesture_hint()
	_confetti.clear_all()
	_overlay.clear_all()
	_flap.visible = false

	cs = _cell_size_for(model.w, model.h)
	_overlay.cs = cs
	_set_offset(_centered(model.w, model.h))
	_refresh_paper()
	_rebuild_tiles(true)

	_paper.scale = Vector2(0.86, 0.86)
	_paper.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_paper, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_paper, "modulate:a", 1.0, 0.22)
	interactive = true


## Hucre boyutu BASLANGIC tahtasina gore hesaplanir ve seviye boyunca sabit
## kalir. Boylece kagit katlandikca gercekten KUCULUYOR gorunur -- mekanigin
## en cok sey anlatan gorsel ipucu bu, hucreleri buyutmek onu yok ederdi.
func _cell_size_for(w: int, h: int) -> float:
	var avail := _play_size * 0.90
	return minf(minf(avail.x / float(w), avail.y / float(h)), MAX_CELL)


## Ekran boyutu degistiginde (dondurme, pencere) mevcut ilerlemeyi bozmadan
## yeniden olceklendirir.
func relayout() -> void:
	if model == null or level_data.is_empty():
		return
	var b0: BoardModel = level_data.board
	cs = _cell_size_for(b0.w, b0.h)
	_overlay.cs = cs
	_set_offset(_centered(model.w, model.h))
	_refresh_paper()
	_rebuild_tiles(false)


func _centered(w: int, h: int) -> Vector2:
	return -Vector2(float(w) * cs, float(h) * cs) * 0.5


func _set_offset(v: Vector2) -> void:
	board_offset = v
	_paper.position = v
	_tiles.position = v
	_overlay.position = v


func _refresh_paper() -> void:
	_paper.folded = _folded
	_paper.refresh(Rect2(Vector2.ZERO, Vector2(model.w, model.h) * cs), cs, model.w, model.h)


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _cell_center(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * cs, (float(y) + 0.5) * cs)


func _rebuild_tiles(animate := false) -> void:
	_clear(_tiles)
	_views.clear()
	var mid := Vector2(float(model.w), float(model.h)) * 0.5
	for y in model.h:
		for x in model.w:
			var code := model.get_at(x, y)
			if code == Tiles.EMPTY:
				continue
			var tv := TileView.new()
			tv.setup(code, cs)
			tv.position = _cell_center(x, y)
			_tiles.add_child(tv)
			_views[Vector2i(x, y)] = tv
			if animate:
				tv.scale = Vector2.ZERO
				var d := (Vector2(x, y) - mid).length() * 0.035
				var tw := create_tween()
				tw.tween_interval(0.10 + d)
				tw.tween_property(tv, "scale", Vector2.ONE, 0.34) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ girdi

## Ekran (viewport) koordinatini tahtanin yerel koordinatina cevirir.
func _to_local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p


func _is_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not event.pressed
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return not event.pressed
	return false


##
## Girdi. Dokunmatikte GERCEK dokunma olaylarini isliyoruz.
##
## Godot'un "fare taklidi" ayarina guvenmek kirilgan cikti: taklit yalnizca
## BIRINCI parmak icin uretiliyor ve surukleme sirasinda sorgulanan fare
## konumu bayatlayabiliyor. Telefonda basma algilaniyordu ama surukleme
## kayboluyordu.
##
## Ilk gelen isaretci jesti SAHIPLENIYOR; digeri parmak/dugme birakilana kadar
## yok sayiliyor. Boylece taklit olaylari ayni jesti ikinci kez islemiyor ve
## dokunmatik ekranli masaustunde iki yol catismiyor.
func _unhandled_input(event: InputEvent) -> void:
	if model == null:
		return

	# BIRAKMA her zaman islenir. Jestin ortasinda interactive false olursa
	# (ogretici kart acilmasi, katlamanin baslamasi) parmak kalkma olayi
	# duserdi; isaretci sahipligi asili kalir ve oyuncu bir daha HICBIR SEYE
	# dokunamazdi.
	if _is_release(event):
		if _pointer != POINTER_NONE:
			_pointer = POINTER_NONE
			if interactive and not auto_playing:
				_release()
			else:
				_abort_gesture()
		return

	if not interactive or auto_playing:
		return

	if event is InputEventScreenTouch:
		if event.index == 0 and _pointer == POINTER_NONE:
			_pointer = POINTER_TOUCH
			_press(_to_local(event.position))

	elif event is InputEventScreenDrag:
		if event.index == 0 and _pointer == POINTER_TOUCH and _dragging:
			_motion(_to_local(event.position))

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _pointer == POINTER_NONE:
			_pointer = POINTER_MOUSE
			_press(_to_local(event.position))

	elif event is InputEventMouseMotion:
		if _pointer == POINTER_MOUSE and _dragging:
			_motion(_to_local(event.position))


## Yarim kalmis jesti sessizce toparlar: kagit yerine doner, hicbir katlama
## uygulanmaz.
func _abort_gesture() -> void:
	_dragging = false
	if _locked:
		_locked = false
		_set_t(0.0)
		_restore_flap()


## Ilk kez oynayana jesti sessizce gosterir: cozumun ilk hamlesini yapan
## parmak hareketi, dokunulur dokunulmaz kaybolur.
func show_gesture_hint() -> void:
	_kill_gesture_hint()
	if model == null:
		return
	var mv := hint()
	if mv.is_empty():
		return
	var axis: int = mv[0]
	var g: int = mv[1]
	var cell := Vector2i(g - 1, model.h / 2) if axis == 0 else Vector2i(model.w / 2, g - 1)
	var dir := Vector2(1.0, 0.0) if axis == 0 else Vector2(0.0, 1.0)
	var a := board_offset + _cell_center(cell.x, cell.y)
	_gesture = GestureHint.new()
	_gesture.z_index = 20
	_gesture.setup(a, a + dir * cs, cs * 0.24)
	add_child(_gesture)


func _kill_gesture_hint() -> void:
	if _gesture != null and is_instance_valid(_gesture):
		_gesture.queue_free()
	_gesture = null


func _press(p: Vector2) -> void:
	_kill_gesture_hint()
	var rel := p - board_offset
	var cx := int(floor(rel.x / cs))
	var cy := int(floor(rel.y / cs))
	if cx < 0 or cy < 0 or cx >= model.w or cy >= model.h:
		return
	_dragging = true
	_locked = false
	_start = p
	_cell = Vector2i(cx, cy)
	_t = 0.0


func _motion(p: Vector2) -> void:
	var d := p - _start
	if not _locked:
		if d.length() < cs * AXIS_LOCK:
			return
		if not _decide(d):
			_dragging = false
			return
	var proj := 0.0
	if _axis == 0:
		proj = d.x if _side == 0 else -d.x
	else:
		proj = d.y if _side == 0 else -d.y
	var nt := clampf(proj / _need, 0.0, 1.0)
	_rustle_cd -= get_process_delta_time()
	if absf(nt - _t) > 0.04 and _rustle_cd <= 0.0:
		Sfx.play_drag(absf(nt - _t) * 8.0)
		_rustle_cd = 0.09
	_set_t(nt)


## Jesti kat cizgisine cevirir: parmagini koydugun kareye kadarki kagit,
## kaydirdigin yone dogru katlanir.
func _decide(d: Vector2) -> bool:
	var horizontal := absf(d.x) > absf(d.y)
	var axis := 0 if horizontal else 1
	var i := _cell.x if horizontal else _cell.y
	var n := model.w if horizontal else model.h
	var forward := (d.x > 0.0) if horizontal else (d.y > 0.0)
	var g := 0
	var side := 0
	if forward:
		g = i + 1
		side = 0
		if g > n - 1:
			return false
	else:
		g = i
		side = 1
		if g < 1:
			return false

	_axis = axis
	_g = g
	_side = side
	_prev = model.fold(axis, g, side)
	var touch := (_start - board_offset).x if horizontal else (_start - board_offset).y
	_need = maxf(cs * 0.75, absf(float(g) * cs - touch) * 2.0)
	_build_flap()
	_locked = true
	Sfx.play_lift()
	return true


# ------------------------------------------------------------------ kanat

func _flap_is_moving(i: int) -> bool:
	return (i < _g) if _side == 0 else (i >= _g)


func _crease_vec() -> Vector2:
	return Vector2(float(_g) * cs, 0.0) if _axis == 0 else Vector2(0.0, float(_g) * cs)


func _build_flap() -> void:
	var cv := _crease_vec()
	_flap.position = board_offset + cv
	_flap.scale = Vector2.ONE
	_flap.modulate = Color.WHITE
	_flap.visible = true
	_clear(_flap_tiles)

	var full := Vector2(model.w, model.h) * cs
	var stat_rect := Rect2()
	var flap_rect := Rect2()
	if _axis == 0:
		var gx := float(_g) * cs
		if _side == 0:
			stat_rect = Rect2(gx, 0.0, full.x - gx, full.y)
			flap_rect = Rect2(-gx, 0.0, gx, full.y)
		else:
			stat_rect = Rect2(0.0, 0.0, gx, full.y)
			flap_rect = Rect2(0.0, 0.0, full.x - gx, full.y)
	else:
		var gy := float(_g) * cs
		if _side == 0:
			stat_rect = Rect2(0.0, gy, full.x, full.y - gy)
			flap_rect = Rect2(0.0, -gy, full.x, gy)
		else:
			stat_rect = Rect2(0.0, 0.0, full.x, gy)
			flap_rect = Rect2(0.0, 0.0, full.x, full.y - gy)
	_paper.folded = _folded
	_paper.refresh(stat_rect, cs, model.w, model.h)
	_flap_paper.folded = {}
	_flap_paper.refresh(flap_rect, cs, model.w, model.h)

	var ghosts: Array = []
	for y in model.h:
		for x in model.w:
			var i := x if _axis == 0 else y
			var key := Vector2i(x, y)
			var tv: TileView = _views.get(key)
			if tv == null:
				continue
			var partner := _partner(x, y)
			var pcode := Tiles.EMPTY
			if partner.x >= 0:
				pcode = model.get_at(partner.x, partner.y)
			var merged := Tiles.merge(model.get_at(x, y), pcode)
			if pcode != Tiles.EMPTY:
				if merged == Tiles.ILLEGAL:
					tv.conflict = true
					tv.set_glow(1.0, Palette.BAD)
				elif merged == Tiles.EMPTY:
					tv.conflict = false
					tv.set_glow(1.0, Palette.GOOD)
			if not _flap_is_moving(i):
				continue
			_tiles.remove_child(tv)
			_flap_tiles.add_child(tv)
			tv.position = _cell_center(x, y) - cv
			if partner.x >= 0 and pcode == Tiles.EMPTY:
				ghosts.append({"pos": _cell_center(partner.x, partner.y), "color": Palette.INK_SOFT})
	_overlay.set_ghosts(ghosts)
	_set_t(0.0)


## Bir hucrenin katlandiginda uzerine gelecegi ESKI koordinat (yoksa x = -1).
func _partner(x: int, y: int) -> Vector2i:
	if _axis == 0:
		var m := 2 * _g - 1 - x
		return Vector2i(m, y) if m >= 0 and m < model.w else Vector2i(-1, -1)
	var my := 2 * _g - 1 - y
	return Vector2i(x, my) if my >= 0 and my < model.h else Vector2i(-1, -1)


func _set_t(t: float) -> void:
	_t = clampf(t, 0.0, 1.0)
	var s := 1.0 - 2.0 * _t
	var bulge := 1.0 + 0.030 * sin(PI * _t)
	var full := Vector2(model.w, model.h) * cs

	# Kabarma kagidin havalandigi hissini veriyor. Ama olcek kat cizgisinden
	# uygulandigi icin duz birakilirsa kagit TEK YONE uzar ve tabakanin
	# disina tasar; dik eksende merkezi sabit tutmak icin geri kaydiriyoruz.
	var grow := (bulge - 1.0) * 0.5
	var recenter := Vector2(0.0, -grow * full.y) if _axis == 0 else Vector2(-grow * full.x, 0.0)
	_flap.position = board_offset + _crease_vec() + recenter
	_flap.scale = Vector2(s, bulge) if _axis == 0 else Vector2(bulge, s)
	# Kagit profilden goruldugunde govde golgesi de yok olmali, yoksa ince
	# kagit seridi metal bir cubuk gibi duruyor.
	_flap_paper.shadow_k = absf(s)
	_flap_paper.queue_redraw()
	var shade := 1.0 - 0.36 * sin(PI * _t)
	_flap.modulate = Color(shade, shade * 0.995, shade * 0.985, 1.0)

	var r := Rect2()
	if _axis == 0:
		var gx := float(_g) * cs
		var fw := gx if _side == 0 else (full.x - gx)
		if _side == 0:
			r = Rect2(gx, 0.0, fw * _t, full.y)
		else:
			r = Rect2(gx - fw * _t, 0.0, fw * _t, full.y)
	else:
		var gy := float(_g) * cs
		var fh := gy if _side == 0 else (full.y - gy)
		if _side == 0:
			r = Rect2(0.0, gy, full.x, fh * _t)
		else:
			r = Rect2(0.0, gy - fh * _t, full.x, fh * _t)
	_overlay.set_shadow(r, sin(PI * _t) * 0.55)


func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	if not _locked:
		return
	if _t >= COMMIT_AT and bool(_prev.get("ok", false)):
		_commit()
	else:
		_cancel(_t >= COMMIT_AT)


func _cancel(was_invalid: bool) -> void:
	interactive = false
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_t, _t, 0.0, maxf(0.12, _t * 0.30))
	tw.tween_callback(func() -> void:
		if was_invalid:
			Sfx.play_deny()
			impact.emit(0.55)
			invalid_fold.emit()
		_restore_flap()
		interactive = true)


func _restore_flap() -> void:
	for c in _flap_tiles.get_children():
		_flap_tiles.remove_child(c)
		_tiles.add_child(c)
	for k in _views:
		var tv: TileView = _views[k]
		tv.conflict = false
		tv.set_glow(0.0, Palette.GOOD)
		tv.position = _cell_center(k.x, k.y)
	_flap.visible = false
	_flap.scale = Vector2.ONE
	_flap.modulate = Color.WHITE
	_overlay.clear_all()
	_refresh_paper()


func _commit() -> void:
	interactive = false
	_undo.append({
		"w": model.w, "h": model.h, "cells": model.cells.duplicate(),
		"folded": _folded.duplicate(), "moves": moves,
	})
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_t, _t, 1.0, maxf(0.09, (1.0 - _t) * 0.26))
	tw.tween_callback(_after_flip)


func _after_flip() -> void:
	Sfx.play_snap()
	impact.emit(0.32)

	# katlanan kenar kagidin uzerinde kalici iz birakir
	if _axis == 0:
		_folded["l" if _side == 0 else "r"] = true
	else:
		_folded["t" if _side == 0 else "b"] = true

	var shift: int = _prev.shift
	var comp := Vector2(float(shift) * cs, 0.0) if _axis == 0 else Vector2(0.0, float(shift) * cs)
	var pops: Array = (_prev.pops as Array).duplicate()

	_clear(_flap_tiles)
	_flap.visible = false
	_flap.scale = Vector2.ONE
	_flap.modulate = Color.WHITE
	_overlay.clear_all()

	model.apply(_prev)
	moves += 1
	SaveData.total_folds += 1
	_set_offset(board_offset + comp)     # sabit taraf ekranda hic ziplamaz
	_refresh_paper()
	_rebuild_tiles(false)

	if pops.is_empty():
		_settle()
		return

	var seq := create_tween()
	for i in pops.size():
		var at: Vector2i = pops[i].at
		var code: int = pops[i].code
		var world := board_offset + _cell_center(at.x, at.y)
		var step := i
		seq.tween_callback(func() -> void:
			_confetti.burst(world, Palette.body(code), cs, 24)
			Sfx.play_pop(step)
			impact.emit(0.16 + 0.05 * float(step)))
		seq.tween_interval(0.055)
	seq.tween_callback(_settle)


func _settle() -> void:
	var target := _centered(model.w, model.h)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_offset, board_offset, target, 0.34)
	tw.tween_callback(func() -> void:
		fold_committed.emit(moves)
		# Gosterim modunda yildiz kazandirmiyoruz: cozumu oyuncu degil oyun
		# oynadi. Ayni sekilde "takildin" teklifi de tekrar acilmamali.
		if model.is_solved():
			if not auto_playing:
				solved.emit(moves)
		else:
			interactive = not auto_playing
			if not auto_playing and not _still_solvable():
				stuck.emit())


##
## Emniyet kemeri. Seviyeler CIKMAZSIZ uretiliyor (LevelGen + FoldGraph), yani
## buranin false donmesi imkansiz olmali -- eskiden gecerli ama olumcul bir
## katlama tahtayi cozumsuz birakabiliyordu, artik oyle bir tahta uretilmiyor.
## Kontrol yine de duruyor: bir gun uretim bozulursa oyuncu dilsiz bir tahtada
## kalmasin. Grafik bellekte oldugu icin maliyeti tek anahtar aramasi.
##
func _still_solvable() -> bool:
	if model.is_solved():
		return true
	if graph != null:
		var d: int = graph.depth.get(FoldGraph.canonical(model), -2)
		if d >= 0:
			return true
		if d == -1:
			push_warning("CIKMAZ tahta -- seviye %d, hamle %d" % [
				int(level_data.get("level", 0)), moves])
			return false
	return FoldGraph.is_solvable(model)


# ------------------------------------------------------------------ komutlar

func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> void:
	if _undo.is_empty() or not interactive:
		return
	var snap: Dictionary = _undo.pop_back()
	model = BoardModel.new(snap.w, snap.h, snap.cells)
	_folded = snap.folded
	moves = snap.moves
	_pointer = POINTER_NONE
	_kill_gesture_hint()
	_confetti.clear_all()
	_set_offset(_centered(model.w, model.h))
	_refresh_paper()
	_rebuild_tiles(false)
	Sfx.play_ui()
	fold_committed.emit(moves)


func restart() -> void:
	if not level_data.is_empty():
		load_level(level_data)


## Cozumu bastan sona kendisi oynar -- odullu reklamin karsiligi.
## Sonunda seviye yeniden baslar: oyuncu izledi, simdi kendisi yapacak.
func play_solution() -> void:
	if model == null or auto_playing:
		return
	auto_playing = true
	interactive = false
	_pointer = POINTER_NONE
	_kill_gesture_hint()
	var guard := 12
	while not model.is_solved() and guard > 0:
		var mv := hint()
		if mv.is_empty():
			break
		await _auto_fold(mv[0], mv[1])
		guard -= 1
	await get_tree().create_timer(0.7).timeout
	auto_playing = false
	restart()


## Gercek jestin yaptigi yolun aynisini izlenebilir bir hizda oynatir --
## ayri bir "animasyon" kodu yazmiyoruz, ayni kod yolu kullaniliyor ki
## gosterilen sey oyuncunun yapacagi seyle birebir ayni olsun.
func _auto_fold(axis: int, g: int) -> void:
	var cell := Vector2i(g - 1, model.h / 2) if axis == 0 else Vector2i(model.w / 2, g - 1)
	var dir := Vector2(1.0, 0.0) if axis == 0 else Vector2(0.0, 1.0)
	var p := board_offset + _cell_center(cell.x, cell.y)
	_press(p)
	_motion(p + dir * cs * 0.4)
	if not _locked:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_t, _t, 1.0, 0.55)
	await tw.finished
	_dragging = false
	_commit()
	await fold_committed


## En kisa cozume goturen ilk kat cizgisi: [axis, g].
## Grafik seviye acilirken cikarildigi icin bu bir ARAMA degil, tablo okumasi.
func hint() -> Array:
	if model == null or graph == null:
		return []
	return graph.best_move(model)


## Onerilen kat cizgisini kagidin uzerinde yanip sonen kesikli cizgi olarak gosterir.
func highlight_hint(mv: Array) -> void:
	if mv.is_empty() or model == null:
		return
	var axis: int = mv[0]
	var g: int = mv[1]
	var full := Vector2(model.w, model.h) * cs
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	if axis == 0:
		from = Vector2(float(g) * cs, -cs * 0.10)
		to = Vector2(float(g) * cs, full.y + cs * 0.10)
	else:
		from = Vector2(-cs * 0.10, float(g) * cs)
		to = Vector2(full.x + cs * 0.10, float(g) * cs)
	var line := HintLine.new()
	line.setup(from, to, maxf(3.0, cs * 0.05), cs * 0.18)
	line.position = board_offset
	line.z_index = 8
	add_child(line)
	var tw := create_tween()
	tw.set_loops(3)
	tw.tween_property(line, "modulate:a", 0.18, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(line, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(line.queue_free)
