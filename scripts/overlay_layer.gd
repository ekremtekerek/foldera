class_name OverlayLayer
extends Node2D
##
## Iki isi birden goruyor:
##  1) Kanadin altina dusen hareketli golge -- katlamaya derinlik veren sey.
##  2) Taslarin NEREYE inecegini gosteren kesikli hayaletler.
## Ikisi de ayni cizim gecisinde, ekstra dugum maliyeti yok.
##

var cs := 100.0
var shadow_rect := Rect2()
var shadow_alpha := 0.0
var ghosts: Array = []      # [{pos: Vector2, color: Color}]


func set_shadow(r: Rect2, a: float) -> void:
	shadow_rect = r
	shadow_alpha = a
	queue_redraw()


func set_ghosts(list: Array) -> void:
	ghosts = list
	queue_redraw()


func clear_all() -> void:
	shadow_alpha = 0.0
	ghosts = []
	queue_redraw()


func _draw() -> void:
	if shadow_alpha > 0.002 and shadow_rect.size.x > 0.5 and shadow_rect.size.y > 0.5:
		var box := StyleBoxFlat.new()
		# Golgenin cogu BULANIK kisimdan gelsin: dolgu neredeyse seffaf, genis bir
		# stylebox golgesi yumusak gecisi veriyor. Aksi halde hedef bolge sert
		# kenarli gri bir dikdortgen gibi goruluyor.
		box.bg_color = Color(0.24, 0.18, 0.12, shadow_alpha * 0.16)
		var rad := int(cs * 0.12)
		box.corner_radius_top_left = rad
		box.corner_radius_top_right = rad
		box.corner_radius_bottom_left = rad
		box.corner_radius_bottom_right = rad
		box.shadow_color = Color(0.24, 0.18, 0.12, shadow_alpha * 0.30)
		box.shadow_size = int(cs * 0.42)
		box.shadow_offset = Vector2(cs * 0.05, cs * 0.09)
		draw_style_box(box, shadow_rect)

	for gh in ghosts:
		var p: Vector2 = gh.pos
		var c: Color = gh.color
		var s := cs * 0.44
		var fill := c
		fill.a = 0.10
		draw_rect(Rect2(p - Vector2(s, s), Vector2(s * 2, s * 2)), fill, true)
		var line := c
		line.a = 0.55
		var w := maxf(1.5, cs * 0.022)
		var d := cs * 0.10
		draw_dashed_line(p + Vector2(-s, -s), p + Vector2(s, -s), line, w, d, true)
		draw_dashed_line(p + Vector2(s, -s), p + Vector2(s, s), line, w, d, true)
		draw_dashed_line(p + Vector2(s, s), p + Vector2(-s, s), line, w, d, true)
		draw_dashed_line(p + Vector2(-s, s), p + Vector2(-s, -s), line, w, d, true)
