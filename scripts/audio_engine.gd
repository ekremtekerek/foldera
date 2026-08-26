extends Node
##
## Tum sesler CALISMA ANINDA SENTEZLENIR -- projede tek bir ses dosyasi yok.
## Sonuc: kurulum boyutu kucuk, lisans derdi yok, tamamen offline.
##
## Muzik yerine URETKEN AMBIYANS var: pentatonik bir diziden seyrek, uzun
## notalar calinir. Hicbir dongu tekrar etmez, kulagi yormaz.
##

const SR_TONE := 44100
const SR_NOISE := 22050
const POOL_SIZE := 16

## A minor pentatonik -- yanlis nota calmak imkansiz, her patlama uyumlu.
const SCALE := [220.00, 261.63, 293.66, 329.63, 392.00,
				440.00, 523.25, 587.33, 659.25, 783.99,
				880.00, 1046.50]

var sfx_on := true : set = set_sfx_on
var music_on := true : set = set_music_on

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _amb: Array[AudioStreamWAV] = []
var _amb_timer: Timer
var _rng := RandomNumberGenerator.new()

var pops: Array[AudioStreamWAV] = []
var s_lift: AudioStreamWAV
var s_drag: AudioStreamWAV
var s_snap: AudioStreamWAV
var s_deny: AudioStreamWAV
var s_star: AudioStreamWAV
var s_ui: AudioStreamWAV
var s_win: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_build()
	_amb_timer = Timer.new()
	_amb_timer.one_shot = true
	_amb_timer.timeout.connect(_ambient_tick)
	add_child(_amb_timer)
	_amb_timer.start(2.0)


# ------------------------------------------------------------------ calma

func play(stream: AudioStreamWAV, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null or not sfx_on:
		return
	_raw(stream, volume_db, pitch)


func _raw(stream: AudioStreamWAV, volume_db: float, pitch: float) -> void:
	var p: AudioStreamPlayer = null
	for i in POOL_SIZE:
		var cand: AudioStreamPlayer = _pool[(_next + i) % POOL_SIZE]
		if not cand.playing:
			p = cand
			_next = (_next + i + 1) % POOL_SIZE
			break
	if p == null:
		p = _pool[_next]
		_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Zincirdeki n. patlama -> dizide bir ust nota. Combo yaptikca melodi yukselir.
func play_pop(step: int) -> void:
	if not sfx_on:
		return
	var i := clampi(step, 0, pops.size() - 1)
	play(pops[i], -5.0, 1.0)


func play_drag(strength: float) -> void:
	if not sfx_on:
		return
	play(s_drag, lerpf(-26.0, -12.0, clampf(strength, 0.0, 1.0)), _rng.randf_range(0.92, 1.12))


func play_snap() -> void:
	play(s_snap, -6.0, _rng.randf_range(0.96, 1.05))


func play_lift() -> void:
	play(s_lift, -14.0, _rng.randf_range(0.95, 1.08))


func play_deny() -> void:
	play(s_deny, -7.0)


func play_star(i: int) -> void:
	play(s_star, -6.0, 1.0 + 0.22 * i)


func play_ui() -> void:
	play(s_ui, -13.0)


func play_win() -> void:
	play(s_win, -6.0)


func set_sfx_on(v: bool) -> void:
	sfx_on = v


func set_music_on(v: bool) -> void:
	music_on = v


func _ambient_tick() -> void:
	if music_on and not _amb.is_empty():
		_raw(_amb[_rng.randi_range(0, _amb.size() - 1)], _rng.randf_range(-27.0, -20.0),
			_rng.randf_range(0.99, 1.01))
	_amb_timer.start(_rng.randf_range(3.4, 7.5))


# ------------------------------------------------------------------ sentez

func _build() -> void:
	for f in SCALE:
		pops.append(_wav(_norm(_bell(f, 0.55, 1.0, 9.0, 0.75), 0.85), SR_TONE))

	# Uzun, yumusak ambiyans notalari (yavas atak, uzun kuyruk)
	for f in [110.0, 164.81, 220.0, 261.63, 329.63, 392.0]:
		_amb.append(_wav(_norm(_bell(f, 3.2, 1.0, 1.15, 0.16, 0.65), 0.8), SR_TONE))

	s_drag = _wav(_norm(_paper(0.30, 0.55, 4711), 0.7), SR_NOISE)
	s_lift = _wav(_norm(_paper(0.18, 0.75, 991), 0.7), SR_NOISE)
	s_snap = _wav(_norm(_snap(), 0.95), SR_NOISE)
	s_deny = _wav(_norm(_deny(), 0.85), SR_NOISE)
	s_star = _wav(_norm(_bell(1318.51, 0.5, 1.0, 8.0, 1.0), 0.8), SR_TONE)
	s_ui = _wav(_norm(_bell(880.0, 0.10, 1.0, 34.0, 0.35), 0.7), SR_TONE)
	s_win = _wav(_norm(_win(), 0.9), SR_TONE)


## Marimba/zil karakterinde ton: temel + az sayida ustharmonik, ussel sonum.
func _bell(freq: float, dur: float, amp: float, decay: float, bright: float,
		attack := 0.004) -> PackedFloat32Array:
	var n := int(dur * SR_TONE)
	var out := PackedFloat32Array()
	out.resize(n)
	var w := TAU * freq / float(SR_TONE)
	for i in n:
		var t := float(i) / float(SR_TONE)
		var p := w * float(i)
		var v := sin(p) \
			+ 0.30 * bright * sin(p * 2.0) \
			+ 0.15 * bright * sin(p * 3.01) \
			+ 0.06 * bright * sin(p * 5.43)
		out[i] = v * exp(-t * decay) * minf(1.0, t / attack) * amp
	return out


## Kagit hisirtisi: filtrelenmis gurultu + hizli genlik kirilmalari (lif hissi).
func _paper(dur: float, bright: float, seed_v: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(dur * SR_NOISE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var prev := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / float(SR_NOISE)
		var wn := rng.randf() * 2.0 - 1.0
		lp += (wn - lp) * (0.18 + 0.55 * bright)
		hp = 0.90 * (hp + lp - prev)
		prev = lp
		var env := pow(sin(PI * clampf(t / dur, 0.0, 1.0)), 1.15)
		var crinkle := 0.40 + 0.60 * absf(sin(TAU * 43.0 * t) * sin(TAU * 17.0 * t))
		out[i] = hp * env * crinkle
	return out


## Kat cizgisinin oturmasi: keskin transient + kisa kagit patlamasi + hafif govde.
func _snap() -> PackedFloat32Array:
	var buf := _paper(0.14, 0.95, 20260825)
	var n := buf.size()
	for i in n:
		var t := float(i) / float(SR_NOISE)
		var click := exp(-t * 300.0) * sin(TAU * 2600.0 * t) * 0.55
		var body := exp(-t * 42.0) * sin(TAU * 190.0 * t) * 0.30
		buf[i] = buf[i] * 1.1 + click + body
	return buf


## Gecersiz katlama: bogum sesi, alcak ve kisa -- cezalandirici degil, uyarici.
func _deny() -> PackedFloat32Array:
	var n := int(0.20 * SR_NOISE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in n:
		var t := float(i) / float(SR_NOISE)
		var f := lerpf(150.0, 96.0, clampf(t / 0.16, 0.0, 1.0))
		var env := exp(-t * 20.0)
		out[i] = (sin(TAU * f * t) * 0.85 + (rng.randf() * 2.0 - 1.0) * 0.12) * env
	return out


## Seviye bitisi: yukselen pentatonik arpej -- cozum hissini kapatir.
func _win() -> PackedFloat32Array:
	var notes := [SCALE[3], SCALE[5], SCALE[7], SCALE[9]]
	var total := int(1.5 * SR_TONE)
	var out := PackedFloat32Array()
	out.resize(total)
	for k in notes.size():
		var tone := _bell(notes[k], 1.2, 0.85 - 0.09 * k, 3.6, 0.7)
		var off := int(k * 0.085 * SR_TONE)
		for i in tone.size():
			var j := off + i
			if j < total:
				out[j] += tone[i]
	return out


# ------------------------------------------------------------------ yardimci

func _norm(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for v in buf:
		m = maxf(m, absf(v))
	if m < 0.000001:
		return buf
	var k := peak / m
	for i in buf.size():
		buf[i] *= k
	return buf


func _wav(buf: PackedFloat32Array, sr: int) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = sr
	st.stereo = false
	st.data = data
	return st
