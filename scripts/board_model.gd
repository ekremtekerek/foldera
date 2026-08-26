class_name BoardModel
extends RefCounted
##
## FOLDERA saf mantik katmani. Hicbir gorsel bagimliligi yok -> headless test edilebilir.
##
## Kagit her katlamada KUCULUR. Katlama ekseni ve kat cizgisi (crease) secilir:
##   axis 0 -> dikey kat cizgisi, sutunlar hareket eder
##   axis 1 -> yatay kat cizgisi, satirlar hareket eder
##   g      -> kat cizgisinin indeksi (g-1 ile g arasindaki oluk), 1..n-1
##   side 0 -> DUSUK taraf ([0, g-1]) karsiya katlanir
##   side 1 -> YUKSEK taraf ([g, n-1]) karsiya katlanir
##
## side 1 sonucu, side 0 sonucunun tam aynasidir; oyuncuya iki yon de sunulur
## (dogal jest icin) ama cozucu sadece side 0'i tarar.

var w: int
var h: int
var cells: PackedInt32Array


func _init(width: int = 1, height: int = 1, data: PackedInt32Array = PackedInt32Array()) -> void:
	w = width
	h = height
	if data.size() == width * height:
		cells = data.duplicate()
	else:
		cells = PackedInt32Array()
		cells.resize(width * height)
		cells.fill(Tiles.EMPTY)


func get_at(x: int, y: int) -> int:
	return cells[y * w + x]


func set_at(x: int, y: int, code: int) -> void:
	cells[y * w + x] = code


func duplicate_board() -> BoardModel:
	return BoardModel.new(w, h, cells)


func key() -> String:
	return "%dx%d:%s" % [w, h, cells.to_byte_array().hex_encode()]


func tiles_left() -> int:
	var n := 0
	for c in cells:
		if Tiles.is_clearable(c):
			n += 1
	return n


func is_solved() -> bool:
	return tiles_left() == 0


## Bu tahtada yapilabilecek tum kat cizgileri: [axis, g]
func creases() -> Array:
	var out: Array = []
	for g in range(1, w):
		out.append([0, g])
	for g in range(1, h):
		out.append([1, g])
	return out


## Kat sonrasi indeks kaymasi: yeni_indeks = eski_indeks - shift
static func shift_for(n: int, g: int, side: int) -> int:
	return g if side == 0 else mini(0, 2 * g - n)


##
## Katlamayi hesaplar. Tahtayi DEGISTIRMEZ -- sonucu Dictionary olarak dondurur,
## boylece gorunum katmani once "on izleme" yapip sonra uygulayabilir.
##
##  ok         : katlama gecerli mi
##  w,h,cells  : yeni tahta
##  shift      : eksen boyunca indeks kaymasi (ekranda ziplama olmasin diye)
##  moves      : [{from:Vector2i, to:Vector2i, code:int}]  hareket eden dolu hucreler
##  stays      : [{from:Vector2i, to:Vector2i, code:int}]  sabit kalan dolu hucreler
##  pops       : [{at:Vector2i, code:int}]                 patlayan ciftler (yeni koordinat)
##  conflicts  : [Vector2i]                                 cakisan hucreler (eski koordinat, hareket eden)
##
func fold(axis: int, g: int, side: int) -> Dictionary:
	var n := w if axis == 0 else h
	var res := {
		"ok": false, "reason": "", "axis": axis, "g": g, "side": side,
		"w": w, "h": h, "cells": PackedInt32Array(), "shift": 0,
		"moves": [], "stays": [], "pops": [], "conflicts": [],
	}
	if g < 1 or g > n - 1:
		res.reason = "crease"
		return res

	var new_n := maxi(g, n - g)
	var shift := shift_for(n, g, side)
	var nw := new_n if axis == 0 else w
	var nh := h if axis == 0 else new_n

	var out := PackedInt32Array()
	out.resize(nw * nh)
	out.fill(Tiles.EMPTY)

	var moves: Array = []
	var stays: Array = []
	var pops: Array = []
	var conflicts: Array = []

	# 1) Once sabit kalan tarafi yerlestir
	for y in h:
		for x in w:
			var i := x if axis == 0 else y
			var moving := (i < g) if side == 0 else (i >= g)
			if moving:
				continue
			var ni := i - shift
			var nx := ni if axis == 0 else x
			var ny := y if axis == 0 else ni
			var code := get_at(x, y)
			out[ny * nw + nx] = code
			if code != Tiles.EMPTY:
				stays.append({"from": Vector2i(x, y), "to": Vector2i(nx, ny), "code": code})

	# 2) Sonra katlanan tarafi aynalayarak uzerine bindir
	for y in h:
		for x in w:
			var i := x if axis == 0 else y
			var moving := (i < g) if side == 0 else (i >= g)
			if not moving:
				continue
			var ni := (2 * g - 1 - i) - shift
			var nx := ni if axis == 0 else x
			var ny := y if axis == 0 else ni
			var code := get_at(x, y)
			if code != Tiles.EMPTY:
				moves.append({"from": Vector2i(x, y), "to": Vector2i(nx, ny), "code": code})
			var under: int = out[ny * nw + nx]
			var merged := Tiles.merge(code, under)
			if merged == Tiles.ILLEGAL:
				conflicts.append(Vector2i(x, y))
				continue
			if merged == Tiles.EMPTY and code != Tiles.EMPTY and under != Tiles.EMPTY:
				pops.append({"at": Vector2i(nx, ny), "code": code})
			out[ny * nw + nx] = merged

	if not conflicts.is_empty():
		res.conflicts = conflicts
		res.reason = "conflict"
		return res

	res.ok = true
	res.w = nw
	res.h = nh
	res.cells = out
	res.shift = shift
	res.moves = moves
	res.stays = stays
	res.pops = pops
	return res


## Katlamayi uygular (fold() sonucunu alarak).
func apply(res: Dictionary) -> void:
	w = res.w
	h = res.h
	cells = (res.cells as PackedInt32Array).duplicate()


func debug_string() -> String:
	const SYM := ["_", "a", "b", "c", "d", "e", "f"]
	var s := ""
	for y in h:
		for x in w:
			var c := get_at(x, y)
			var k := Tiles.kind(c)
			if k == Tiles.K_EMPTY:
				s += " ."
			elif k == Tiles.K_LOCK:
				s += " #"
			elif k == Tiles.K_WILD:
				s += " *"
			else:
				s += " " + SYM[Tiles.color(c) + 1]
		s += "\n"
	return s
