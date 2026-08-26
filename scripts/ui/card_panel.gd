class_name CardPanel
extends PanelContainer
##
## Kart yuzeyi (kazandin ekrani, ogretici, teklif). Godot'un StyleBoxFlat'i
## degrade yapamadigi icin yuzeyi Surface ile kendimiz ciziyoruz; stylebox
## yalnizca ic paylari tasiyor.
##
## Container'in kendi _draw'i cocuklardan ONCE calisiyor, yani icerik
## yuzeyin uzerinde kaliyor.

var radius := 40.0
var elevation := 1.0
var base: Color = Palette.PAPER


static func make(pad := 44, min_width := 560.0) -> CardPanel:
	var p := CardPanel.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad - 4
	sb.content_margin_bottom = pad - 6
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(min_width, 0)
	return p


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	Surface.panel(self, Rect2(Vector2.ZERO, size), radius, base, elevation)
	# ust kenarda ince ic isik -- kartin kenarini keskinlestirir
	Surface.rim(self, Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), radius,
		Color(1, 1, 1, 0.6), 2.0)
