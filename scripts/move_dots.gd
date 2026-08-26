class_name MoveDots
extends Control
##
## Kalan katlama gostergesi. Par kadar nokta koyu murekkep; par asilirsa
## kehribar rengi ekstra noktalar belirir -- oyun BITMEZ, sadece yildiz duser.
## Hyper-casual kural: basarisizlik yok, sadece daha iyisini yapma davetiyesi.
##
## Noktalar da taslarla ayni malzemeden: dolu olanlar kalinligi olan kucuk
## pullar, bos olanlar kagida acilmis yuvalar.

var used := 0
var par := 3
var _pulse := 0.0


func set_state(u: int, p: int) -> void:
	if u > used:
		_pulse = 1.0
	used = u
	par = p
	custom_minimum_size = Vector2(float(maxi(par, used)) * 36.0 + 24.0, 36.0)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.4)
		queue_redraw()


func _draw() -> void:
	var total := maxi(par, used)
	var gap := 36.0
	var r := 9.0
	var x0 := (size.x - float(total - 1) * gap) * 0.5
	for i in total:
		var p := Vector2(x0 + float(i) * gap, size.y * 0.5)
		var over := i >= par
		var col: Color = Palette.ACCENT if over else Palette.INK
		if i < used:
			var k := r
			if i == used - 1:
				k = r * (1.0 + 0.5 * _pulse)
			_filled(p, k, col)
		else:
			_socket(p, r, col)


## Dolu: kalinligi ve ust parlakligi olan kucuk pul.
func _filled(at: Vector2, r: float, col: Color) -> void:
	draw_circle(at + Vector2(0, r * 0.42), r, Color(0.25, 0.18, 0.10, 0.16))
	draw_circle(at + Vector2(0, r * 0.22), r, col.darkened(0.32))
	draw_circle(at, r, col)
	draw_circle(at - Vector2(0, r * 0.28), r * 0.66, Color(1, 1, 1, 0.20))


## Bos: kagida acilmis yuva -- ustte koyu, altta acik (ters isik).
func _socket(at: Vector2, r: float, col: Color) -> void:
	draw_circle(at, r, Color(col.r, col.g, col.b, 0.10))
	draw_arc(at, r, PI * 0.15, PI * 0.95, 18, Color(1, 1, 1, 0.55), 2.4, true)
	draw_arc(at, r, PI * 1.05, PI * 1.95, 18, Color(col.r, col.g, col.b, 0.28), 2.6, true)
