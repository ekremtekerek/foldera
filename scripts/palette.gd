class_name Palette
##
## Kagit-zanaati yon: sicak krem zemin, mat ve doygunlugu dusuk renkler.
## Her renk AYNI ZAMANDA bir SEKIL tasir -> renk korlugunde de oynanabilir.
##

const BG_TOP    := Color("f7f1e8")
const BG_BOTTOM := Color("ebe0cf")
const PAPER     := Color("fdfaf4")
const PAPER_EDGE:= Color("e2d6c2")
const SHADOW    := Color(0.42, 0.34, 0.24, 0.20)
const INK       := Color("332d27")
const INK_SOFT  := Color("8b8073")
const ACCENT    := Color("e4664f")
const GOOD      := Color("4fb07a")
const BAD       := Color("d9534f")

const COLORS := [
	Color("e4664f"),  # 0 mercan     -> daire
	Color("2ba39a"),  # 1 turkuaz    -> ucgen
	Color("efab33"),  # 2 kehribar   -> kare
	Color("6f66c6"),  # 3 mor        -> arti
	Color("df809f"),  # 4 gul        -> altigen
	Color("74ab63"),  # 5 adacayi    -> yildiz
]

const LOCK_BODY := Color("4a4751")
const LOCK_FACE := Color("6c6878")
const WILD_BODY := Color("fbfaff")
const WILD_FACE := Color("8f86d8")

const SHAPE_CIRCLE   := 0
const SHAPE_TRIANGLE := 1
const SHAPE_SQUARE   := 2
const SHAPE_PLUS     := 3
const SHAPE_HEX      := 4
const SHAPE_STAR     := 5


static func body(code: int) -> Color:
	match Tiles.kind(code):
		Tiles.K_LOCK: return LOCK_BODY
		Tiles.K_WILD: return WILD_BODY
		_: return COLORS[Tiles.color(code) % COLORS.size()]


static func face(code: int) -> Color:
	match Tiles.kind(code):
		Tiles.K_LOCK: return LOCK_FACE
		Tiles.K_WILD: return WILD_FACE
		_: return Color(1, 1, 1, 0.92)


## Tas govdesinin alt kenarindaki koyu serit -- kagit kalinligi hissi.
static func edge(code: int) -> Color:
	return body(code).darkened(0.20)


static func shape_for(code: int) -> int:
	match Tiles.kind(code):
		Tiles.K_LOCK: return -1
		Tiles.K_WILD: return -2
		_: return Tiles.color(code) % COLORS.size()


static func shape_points(shape: int, r: float) -> PackedVector2Array:
	match shape:
		SHAPE_CIRCLE:   return _regular(28, r, 0.0)
		SHAPE_TRIANGLE: return _regular(3, r * 1.16, -PI / 2.0)
		SHAPE_SQUARE:   return _regular(4, r * 1.02, PI / 4.0)
		SHAPE_HEX:      return _regular(6, r * 1.06, -PI / 2.0)
		SHAPE_PLUS:     return _plus(r * 1.14, r * 0.40)
		SHAPE_STAR:     return _star(r * 1.22, r * 0.52, 5)
	return _regular(28, r, 0.0)


static func _regular(n: int, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func _plus(r: float, t: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-t, -r), Vector2(t, -r), Vector2(t, -t), Vector2(r, -t),
		Vector2(r, t), Vector2(t, t), Vector2(t, r), Vector2(-t, r),
		Vector2(-t, t), Vector2(-r, t), Vector2(-r, -t), Vector2(-t, -t),
	])


static func _star(outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		var a := -PI / 2.0 + PI * float(i) / float(points)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
