class_name Confetti
extends Node2D
##
## Elle yazilmis kagit-kirpinti patlamasi. GPUParticles yerine bu:
## kirpintilar donerken YASSILAsir (abs(cos)) -- gercek kagidin cirpinisi.
## Ayni anda tum tahtanin parcaciklarini tek bir dugum yonetir.
##

const GRAVITY := 1500.0
const DRAG := 0.985

var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _rot: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _max: PackedFloat32Array = PackedFloat32Array()
var _col: PackedColorArray = PackedColorArray()
var _flut: PackedFloat32Array = PackedFloat32Array()

var _rings: Array = []   # {pos, t, dur, r0, r1, color}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(true)


func burst(at: Vector2, col: Color, cell: float, count := 16) -> void:
	_rings.append({"pos": at, "t": 0.0, "dur": 0.42, "r0": cell * 0.22, "r1": cell * 0.95, "color": col})
	for i in count:
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(0.55, 1.0) * cell * 7.0
		_pos.append(at + Vector2(cos(a), sin(a)) * cell * 0.12)
		_vel.append(Vector2(cos(a), sin(a) * 0.85 - 0.55) * sp)
		_rot.append(_rng.randf() * TAU)
		_spin.append(_rng.randf_range(-11.0, 11.0))
		_size.append(cell * _rng.randf_range(0.090, 0.185))
		var lt := _rng.randf_range(0.55, 0.95)
		_life.append(lt)
		_max.append(lt)
		_flut.append(_rng.randf_range(7.0, 14.0))
		_col.append(col.lightened(_rng.randf_range(-0.05, 0.28)))


func clear_all() -> void:
	_pos.clear(); _vel.clear(); _rot.clear(); _spin.clear()
	_size.clear(); _life.clear(); _max.clear(); _col.clear(); _flut.clear()
	_rings.clear()
	queue_redraw()


func _process(delta: float) -> void:
	var d := minf(delta, 0.05)
	var i := _pos.size() - 1
	while i >= 0:
		_life[i] -= d
		if _life[i] <= 0.0:
			_swap_remove(i)
			i -= 1
			continue
		var v := _vel[i]
		v.y += GRAVITY * d
		v *= DRAG
		_vel[i] = v
		_pos[i] += v * d
		_rot[i] += _spin[i] * d
		i -= 1

	var j := _rings.size() - 1
	while j >= 0:
		_rings[j].t += d
		if _rings[j].t >= _rings[j].dur:
			_rings.remove_at(j)
		j -= 1

	if not _pos.is_empty() or not _rings.is_empty():
		queue_redraw()


func _swap_remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]; _vel[i] = _vel[last]; _rot[i] = _rot[last]
	_spin[i] = _spin[last]; _size[i] = _size[last]; _life[i] = _life[last]
	_max[i] = _max[last]; _col[i] = _col[last]; _flut[i] = _flut[last]
	_pos.resize(last); _vel.resize(last); _rot.resize(last); _spin.resize(last)
	_size.resize(last); _life.resize(last); _max.resize(last); _col.resize(last); _flut.resize(last)


func _draw() -> void:
	for r in _rings:
		var k: float = r.t / r.dur
		var e := 1.0 - pow(1.0 - k, 3.0)
		var c: Color = r.color
		c.a = (1.0 - k) * 0.55
		draw_arc(r.pos, lerpf(r.r0, r.r1, e), 0, TAU, 36, c, maxf(2.0, r.r0 * 0.35) * (1.0 - k * 0.6), true)

	for i in _pos.size():
		var k: float = _life[i] / _max[i]
		var c: Color = _col[i]
		c.a = clampf(k * 1.6, 0.0, 1.0)
		var s: float = _size[i]
		# cirpinma: kagit kendi ekseninde donerken yassilasir
		var fx: float = absf(cos(_flut[i] * (_max[i] - _life[i]))) * 0.85 + 0.15
		var co := cos(_rot[i])
		var si := sin(_rot[i])
		var p := _pos[i]
		var quad := PackedVector2Array()
		for q in [Vector2(-s * fx, -s), Vector2(s * fx, -s), Vector2(s * fx, s), Vector2(-s * fx, s)]:
			quad.append(p + Vector2(q.x * co - q.y * si, q.x * si + q.y * co))
		draw_colored_polygon(quad, c)
