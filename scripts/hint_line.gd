class_name HintLine
extends Node2D
## Ipucu: onerilen kat cizgisi, kagidin uzerinde kesikli olarak yanip soner.

var a := Vector2.ZERO
var b := Vector2.ZERO
var width := 4.0
var dash := 16.0


func setup(from: Vector2, to: Vector2, w: float, d: float) -> void:
	a = from
	b = to
	width = w
	dash = d
	queue_redraw()


func _draw() -> void:
	draw_dashed_line(a, b, Palette.ACCENT, width, dash, true, true)
