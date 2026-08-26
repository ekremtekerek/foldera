class_name GestureHint
extends Node2D
##
## Ogretici parmak. Metin yerine HAREKET gosteriyoruz: bir dokunus noktasi
## kagidi tutup karsiya suruklerken izini birakiyor. Ilk dokunusta kayboluyor.
##
## Nokta HEM acik kagit HEM koyu tas uzerinden geciyor. Tek renkli bir daire
## birinde kayboluyor, digerinde leke gibi duruyor; bu yuzden acik govde +
## koyu halka kullaniyoruz -- ikisi de her zeminde okunuyor.
##
## Hyper-casual kural: oyuncu ilk saniyelerde ne yapacagini anlamazsa oyunu
## kapatir. Bu yuzden ipucu otomatik, sessiz ve kendiliginden yok oluyor.

var from := Vector2.ZERO
var to := Vector2.ZERO
var radius := 28.0
var _t := 0.0


func setup(a: Vector2, b: Vector2, r: float) -> void:
	from = a
	to = b
	radius = r
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t = fmod(_t + delta * 0.50, 1.0)
	queue_redraw()


func _draw() -> void:
	var k := clampf((_t - 0.12) / 0.62, 0.0, 1.0)
	var eased := k * k * (3.0 - 2.0 * k)
	var p := from.lerp(to, eased)
	var fade := (1.0 - smoothstep(0.80, 1.0, _t)) * smoothstep(0.0, 0.12, _t)
	if fade <= 0.01:
		return

	# iz: once koyu kenar, sonra acik govde -> her zeminde gorunur
	if eased > 0.02:
		draw_line(from, p, Color(0.20, 0.14, 0.08, 0.18 * fade), radius * 0.72, true)
		draw_line(from, p, Color(1, 1, 1, 0.34 * fade), radius * 0.46, true)

	draw_circle(p + Vector2(0, radius * 0.14), radius * 1.04, Color(0.20, 0.14, 0.08, 0.20 * fade))
	draw_circle(p, radius, Color(1, 1, 1, 0.82 * fade))
	draw_circle(p, radius, Color(0.24, 0.17, 0.10, 0.45 * fade), false,
		maxf(2.0, radius * 0.13), true)
	draw_circle(p - Vector2(0, radius * 0.26), radius * 0.52, Color(1, 1, 1, 0.55 * fade))
