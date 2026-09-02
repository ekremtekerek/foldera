extends Node2D
##
## Akis, arayuz ve his (ekran sarsintisi, titresim) burada birlesir.
## Tahtanin kendisi hicbir arayuz bilmiyor -- sadece sinyal yayiyor.
##

const HEADER_H := 200.0
const FOOTER_H := 176.0

var level := 1
var board: BoardView
var world: Node2D
var _base := Vector2.ZERO
var _shake := 0.0
var _rng := RandomNumberGenerator.new()

var _root: Control
var _bg: ColorRect
var _lbl_level: Label
var _lbl_par: Label
var _dots: MoveDots
var _btn_sound: ToolButton
var _btn_undo: ToolButton
var _btn_restart: ToolButton
var _btn_hint: ToolButton
var _hud: Control

var _title: Control
var _win: Control
var _win_stars: StarRow
var _win_title: Label
var _win_sub: Label
var _toast: Label
var _toast_tween: Tween = null


func _ready() -> void:
	# Dil, arayuz kurulmadan ONCE ayarlanmali: etiketler bir kez olusturuluyor.
	Loc.apply(SaveData.lang)
	_rng.randomize()
	_build_background()

	world = Node2D.new()
	add_child(world)
	board = BoardView.new()
	world.add_child(board)
	board.solved.connect(_on_solved)
	board.fold_committed.connect(_on_fold)
	board.invalid_fold.connect(func() -> void: _flash_toast(Loc.t("TOAST_INVALID")))
	board.stuck.connect(_on_stuck)
	board.impact.connect(_add_shake)

	_build_ui()
	Ads.offer_no_ads.connect(_show_no_ads_offer)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_title()
	_install_debug_hooks()


# ------------------------------------------------------------------ yerlesim

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# ColorRect varsayilan olarak girdiyi YUTAR (mouse_filter = STOP). Tam ekran
	# oldugu icin butun dokunmalari tuketiyordu ve tahtaya hicbir sey ulasmiyordu.
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/paper_bg.gdshader")
	mat.set_shader_parameter("top_color", Palette.BG_TOP)
	mat.set_shader_parameter("bottom_color", Palette.BG_BOTTOM)
	mat.set_shader_parameter("glow_color", Palette.PAPER.lightened(0.25))
	_bg.material = mat
	layer.add_child(_bg)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var play_h := maxf(240.0, vp.y - HEADER_H - FOOTER_H)
	_base = Vector2(vp.x * 0.5, HEADER_H + play_h * 0.5)
	world.position = _base
	board.set_play_size(Vector2(vp.x, play_h))
	board.relayout()     # dondurme veya pencere boyutu degisimi seviyeyi bozmasin


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.4)
		var a := _shake * _shake * 22.0
		world.position = _base + Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))
	elif world.position != _base:
		world.position = _base


func _add_shake(strength: float) -> void:
	_shake = minf(1.0, _shake + strength)
	# Titresim hem Android hem iOS'ta var, ama PLATFORM sorulmali: Godot 4'te
	# "mobile" bir isleyici adi ve bu proje gl_compatibility kullaniyor, yani
	# o etiket cihazda da false donuyordu -- titresim hic calismamis.
	if strength > 0.3 and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(int(lerpf(12.0, 34.0, strength)))


# ------------------------------------------------------------------ arayuz

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tema kokten asagi yayiliyor: tum yazi tipleri ve dugme varsayilanlari
	# tek yerden geliyor, her ekranda tekrar ayarlamak gerekmiyor.
	_root.theme = UiTheme.build()
	layer.add_child(_root)

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)

	# --- ust cubuk
	_lbl_level = _make_label(Loc.f("HUD_LEVEL", [1]), 30, Palette.INK_SOFT, UiTheme.DISPLAY)
	_lbl_level.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_lbl_level.offset_top = 54
	_lbl_level.offset_bottom = 96
	_lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_lbl_level)

	_dots = MoveDots.new()
	_dots.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dots.offset_top = 104
	_dots.offset_bottom = 140
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_dots)

	_lbl_par = _make_label("", 22, Palette.INK_SOFT)
	_lbl_par.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_lbl_par.offset_top = 142
	_lbl_par.offset_bottom = 176
	_lbl_par.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_lbl_par)

	_btn_sound = _make_tool(IconDraw.SOUND_ON, "", false, Vector2(84, 84))
	_btn_sound.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn_sound.offset_left = -104
	_btn_sound.offset_right = -20
	_btn_sound.offset_top = 40
	_btn_sound.offset_bottom = 124
	_btn_sound.pressed.connect(_toggle_sound)
	_hud.add_child(_btn_sound)

	var btn_home := _make_tool(IconDraw.BACK, "", false, Vector2(84, 84))
	btn_home.set_anchors_preset(Control.PRESET_TOP_LEFT)
	btn_home.offset_left = 20
	btn_home.offset_right = 104
	btn_home.offset_top = 40
	btn_home.offset_bottom = 124
	btn_home.pressed.connect(func() -> void:
		Sfx.play_ui()
		Track.level_abandon(level, board.moves)
		_show_title())

	# --- alt cubuk
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -FOOTER_H + 26
	bar.offset_bottom = -34
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(bar)

	_btn_undo = _make_tool(IconDraw.UNDO, Loc.t("BTN_UNDO"))
	_btn_undo.pressed.connect(func() -> void: board.undo())
	bar.add_child(_btn_undo)

	_btn_restart = _make_tool(IconDraw.RESTART, Loc.t("BTN_RESTART"))
	_btn_restart.pressed.connect(func() -> void:
		Sfx.play_ui()
		board.restart()
		_refresh_hud())
	bar.add_child(_btn_restart)

	_btn_hint = _make_tool(IconDraw.HINT, Loc.t("BTN_HINT"), true)
	_btn_hint.pressed.connect(_on_hint)
	bar.add_child(_btn_hint)

	_toast = _make_label("", 26, Palette.INK)
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -FOOTER_H - 74
	_toast.offset_bottom = -FOOTER_H - 24
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)

	_build_title()
	_build_win()


## Calisma aninda eklenen tam ekran modallari guvenilir sekilde yerlestirir.
##
## Dugumun kendi _ready() icinde set_anchors_preset() cagirmak YETMIYOR: o an
## ebeveyn dikdortgeni henuz oturmadigi icin kart tam ekran yerine kendi
## asgari boyutunda kalip sol uste kirpiliyor. Ebeveyne eklendikten SONRA
## hem capalari hem paylari acikca ayarliyoruz.
func _present_modal(node: Control) -> void:
	_root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# `size` DOGRUDAN atanmaz: tam ekran capalarda boyutu capalar belirler,
	# elle atamak Godot uyarisi uretir ve zaten bir sonraki duzen gecisinde
	# ezilir. Paylari sifirlamak (yukaridaki cagri) dogru yol.
	node.pivot_offset = _root.size * 0.5


func _make_label(text: String, size_px: int, col: Color, weight := UiTheme.BODY) -> Label:
	return UiTheme.label(text, size_px, col, weight)


func _make_tool(icon: int, label: String, accent := false, sz := Vector2(120, 108)) -> ToolButton:
	var b := ToolButton.new()
	b.setup(icon, label, accent)
	b.custom_minimum_size = sz
	return b


func _make_cta(text: String) -> ChipButton:
	var b := ChipButton.make(text, ChipButton.Kind.PRIMARY, 32)
	b.pressed.connect(Sfx.play_ui)
	return b


func _card(min_size: Vector2) -> CardPanel:
	return CardPanel.make(46, min_size.x)


func _build_title() -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_title)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Palette.BG_TOP.r, Palette.BG_TOP.g, Palette.BG_TOP.b, 0.96)
	_title.add_child(dim)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	_title.add_child(v)

	var mark := LogoMark.new()
	mark.custom_minimum_size = Vector2(0, 220)
	v.add_child(mark)

	var t := _make_label("FOLDERA", 104, Palette.INK, UiTheme.HEAVY)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var s := _make_label(Loc.t("APP_TAGLINE"), 28, Palette.INK_SOFT, UiTheme.BODY)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 46)
	v.add_child(spacer)

	var play := _make_cta(Loc.t("BTN_PLAY"))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void:
		level = maxi(1, SaveData.unlocked)
		_start_level())
	v.add_child(play)

	var lang := ChipButton.make("", ChipButton.Kind.GHOST, 24)
	lang.name = "Lang"
	lang.max_width = 420.0
	lang.pressed.connect(func() -> void:
		Sfx.play_ui()
		_show_language_picker())
	v.add_child(lang)

	var shop := ChipButton.make("", ChipButton.Kind.GHOST, 24)
	shop.name = "Shop"
	shop.pressed.connect(func() -> void:
		Sfx.play_ui()
		_show_no_ads_offer())
	v.add_child(shop)

	# "Satin alimlari geri yukle" -- Google bu akisin KULLANICI TARAFINDAN
	# ulasilabilir olmasini zorunlu tutuyor. Acilista sessiz geri yukleme
	# zaten calisiyor, ama cihaz degistiren kullaniciya elle deneyebilecegi
	# bir dugme de gerekiyor.
	var restore := ChipButton.make("", ChipButton.Kind.GHOST, 22)
	restore.name = "Restore"
	restore.pressed.connect(func() -> void:
		Sfx.play_ui()
		Store.restore()
		_flash_toast(Loc.t("TOAST_RESTORE_SENT")))
	v.add_child(restore)

	var stats := _make_label("", 24, Palette.INK_SOFT)
	stats.name = "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)


func _build_win() -> void:
	_win = Control.new()
	_win.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win.visible = false
	_root.add_child(_win)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.16, 0.13, 0.10, 0.40)
	_win.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win.add_child(center)

	var card := _card(Vector2(520, 0))
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)

	_win_stars = StarRow.new()
	_win_stars.custom_minimum_size = Vector2(400, 92)
	v.add_child(_win_stars)

	_win_title = _make_label("", 58, Palette.INK, UiTheme.HEAVY)
	_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_win_title)

	_win_sub = _make_label("", 26, Palette.INK_SOFT)
	_win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_win_sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	v.add_child(spacer)

	var next := _make_cta(Loc.t("BTN_CONTINUE"))
	next.name = "WinNext"
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(_next_level)
	v.add_child(next)

	var again := ChipButton.make(Loc.t("BTN_REPLAY"), ChipButton.Kind.GHOST, 24)
	again.name = "WinReplay"
	again.pressed.connect(func() -> void:
		Sfx.play_ui()
		_start_level())
	v.add_child(again)


func _show_title() -> void:
	# Riza secilmeden hicbir reklam istegi atilmamali -- once bu ekran.
	if SaveData.consent == "":
		_ask_consent()
		return
	_title.visible = true
	_win.visible = false
	_hud.visible = false
	board.interactive = false
	var stats: Label = _title.find_child("Stats", true, false)
	if stats:
		var n := SaveData.total_stars()
		stats.text = Loc.f("TITLE_STATS", [n, SaveData.total_folds]) if n > 0 else ""
	var lang_btn: ChipButton = _title.find_child("Lang", true, false)
	if lang_btn:
		lang_btn.set_caption(Loc.t("LANG_SYSTEM") if SaveData.lang == "" else Loc.native_name(SaveData.lang))
	var shop: ChipButton = _title.find_child("Shop", true, false)
	if shop:
		# Teklif kapisi: sahte magaza uretim derlemesinde hicbir sey satmaz.
		shop.visible = Store.offers_enabled() and not SaveData.ads_removed
		shop.set_caption(Loc.f("TITLE_NO_ADS", [Store.price_of("no_ads")]))
	# Geri yukleme yalnizca gercek magaza baglıyken anlamli.
	var restore_btn: ChipButton = _title.find_child("Restore", true, false)
	if restore_btn:
		restore_btn.visible = not Store.using_stub()
		restore_btn.set_caption(Loc.t("BTN_RESTORE"))
		shop.set_caption(Loc.f("TITLE_NO_ADS", [Store.price_of("no_ads")]))
	_title.modulate.a = 0.0
	create_tween().tween_property(_title, "modulate:a", 1.0, 0.25)


func _ask_consent() -> void:
	_title.visible = false
	_hud.visible = false
	var c := ConsentScreen.new()
	_present_modal(c)
	c.decided.connect(func(mode: String) -> void:
		SaveData.consent = mode
		SaveData.save_data()
		Track.log_event("consent", {"mode": mode})
		if Ads.provider != null:
			Ads.provider.initialize(mode)
		_show_title())


func _start_level() -> void:
	_title.visible = false
	_win.visible = false
	_hud.visible = true
	SaveData.refresh_hints()
	var lv := LevelGen.generate(level)
	board.load_level(lv)
	_refresh_hud()
	Track.level_start(level, board.par)
	await _teach_for_level(lv)
	_coach()


## Bu seviyede ILK KEZ gorulen bir seyi aciklar. Seviye numarasina degil
## tahtanin gercek icerigine bakiyoruz -- uretec rastgele oldugu icin mandal
## her oyuncuda ayni seviyede cikmiyor.
func _teach_for_level(lv: Dictionary) -> void:
	var b: BoardModel = lv.board
	var keys: Array[String] = []
	var has_lock := false
	var has_wild := false
	for code in b.cells:
		var k := Tiles.kind(code)
		if k == Tiles.K_LOCK:
			has_lock = true
		elif k == Tiles.K_WILD:
			has_wild = true
	if has_lock and not SaveData.has_seen("lock"):
		keys.append("lock")
	if has_wild and not SaveData.has_seen("wild"):
		keys.append("wild")
	if level >= 4 and not SaveData.has_seen("tools"):
		keys.append("tools")
	for k2 in keys:
		await _show_teach(k2)


func _show_teach(key: String, restore := true) -> void:
	board.interactive = false
	var card := TeachCard.make(key)
	_present_modal(card)
	Track.log_event("teach_shown", {"key": key, "level": level})
	await card.dismissed
	SaveData.mark_seen(key)
	if restore:
		board.interactive = true


func _refresh_hud() -> void:
	_lbl_level.text = Loc.f("HUD_LEVEL", [level])
	_dots.set_state(board.moves, board.par)
	_lbl_par.text = Loc.f("HUD_PAR", [board.par])
	_btn_undo.disabled = not board.can_undo()
	_btn_sound.icon_id = IconDraw.SOUND_ON if Sfx.sfx_on else IconDraw.SOUND_OFF
	_btn_sound.queue_redraw()
	_btn_hint.badge = SaveData.hints.total()
	_btn_hint.queue_redraw()


func _on_fold(_m: int) -> void:
	_refresh_hud()
	_coach()


func _on_solved(moves: int) -> void:
	var star := LevelGen.stars(moves, board.par)
	SaveData.record(level, star)
	Track.level_complete(level, moves, board.par, star)
	Sfx.play_win()
	_add_shake(0.25)

	# Yildizlarin ne oldugunu ilk kez GORDUGU anda anlatiyoruz, menude degil.
	if not SaveData.has_seen("stars"):
		await _show_teach("stars", false)

	_win.visible = true
	_win.modulate.a = 0.0
	_win_stars.reveal = 0.0
	_win_title.text = Loc.t(["", "RANK_1", "RANK_2", "RANK_3"][star])
	if star >= 3:
		_win_sub.text = Loc.f("WIN_PERFECT", [moves])
	else:
		_win_sub.text = Loc.f("WIN_SUB", [moves, board.par])
	var tw := create_tween()
	tw.tween_property(_win, "modulate:a", 1.0, 0.22)
	for i in star:
		tw.tween_callback(func() -> void: Sfx.play_star(i))
		tw.parallel().tween_property(_win_stars, "reveal", float(i + 1), 0.30) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.10)


## DEVAM: once gecis reklami (politika izin veriyorsa), sonra sonraki seviye.
## Reklam odul aninda DEGIL, oyuncu ilerlemeye karar verdikten sonra cikiyor --
## yildizlarin gorunduğu ani reklamla bolmek en cok sinir bozan kalip.
func _next_level() -> void:
	var finished := level
	level += 1
	await Ads.maybe_show_interstitial(finished)
	_start_level()


func _on_hint() -> void:
	if not board.interactive:
		return
	Sfx.play_ui()
	SaveData.refresh_hints()
	if not SaveData.hints.can_spend():
		await _show_hint_offer()
		return
	var mv := board.hint()
	if mv.is_empty():
		_flash_toast(Loc.t("TOAST_NO_SOLUTION"))
		return
	# Ipucu YALNIZCA gosterilecek bir hamle varsa harcanir.
	SaveData.hints.spend()
	SaveData.save_data()
	Track.log_event("hint_used", {"level": level, "left": SaveData.hints.total()})
	board.highlight_hint(mv)
	_refresh_hud()


##
## Reklam hazir degilse bekletip oyuncuya durumu SOYLUYORUZ.
##
## Once hazir olmayan reklam sessizce false donuyordu: oyuncu dugmeye
## basiyor, hicbir sey olmuyor, oyun bozuk gorunuyordu. Yeni bir
## uygulamada doluluk gecikmesi normal bir durum ve bunu soylemek
## gizlemekten iyi -- oyuncu birazdan tekrar deneyebilecegini bilir.
func _rewarded_hazirla() -> bool:
	if Ads.rewarded_ready():
		return true
	_hold_toast(Loc.t("TOAST_AD_LOADING"))
	if await Ads.await_rewarded():
		_toast.modulate.a = 0.0
		return true
	# Mesajin sonuna KISA BIR ASAMA KODU ekleniyor. Cirkin ama gecici degil:
	# "reklam gelmedi" raporu su ana kadar uc ayri arizayi ayni cumleyle
	# tarif etti (riza takildi / SDK takildi / doluluk yok) ve her turunda
	# bastan tahmin yurutmek zorunda kaldik. Bu kod oyuncudan gelen tek
	# cumleyi dogrudan olcume ceviriyor.
	_flash_toast("%s (%s)" % [Loc.t("TOAST_AD_NONE"), Ads.asama()])
	return false


func _show_hint_offer() -> void:
	Track.log_event("hint_exhausted", {"level": level})
	var actions: Array = []
	# Odul metni dugmenin UZERINDE degil ALTINDA: "REKLAM IZLE · +3 IPUCU"
	# gibi birlesik etiketler bazi dillerde iki katina cikip karti tasiriyor.
	# Kosul `rewarded_ready()` DEGIL: reklam o an yuklu olmasa da secenek
	# gorunmeli. Aksi halde ipuclari bitince cikan kartta hicbir cikis yolu
	# olmuyor ve oyun bozuk gorunuyor -- ilk oyuncuda tam olarak bu oldu.
	if Ads.rewarded_possible():
		actions.append({
			"id": "ad", "label": Loc.t("BTN_WATCH_AD"), "primary": true,
			"note": Loc.t("TOAST_HINTS_ADDED"),
		})
	if Store.offers_enabled():
		actions.append({"id": "buy", "label": Loc.f("HINT_BUY_PACK", [Store.price_of("hints_10")])})
	actions.append({"id": "dismiss", "label": Loc.t("BTN_CLOSE")})
	var card := OfferCard.make(Loc.t("HINT_EMPTY_TITLE"), Loc.t("HINT_EMPTY_BODY"), actions)
	_present_modal(card)
	var choice: String = await card.chose
	match choice:
		"ad":
			if await _rewarded_hazirla():
				if await Ads.show_rewarded("hint"):
					SaveData.hints.grant(3)
					SaveData.save_data()
					_flash_toast(Loc.t("TOAST_HINTS_ADDED"))
		"buy":
			await Store.purchase("hints_10")
	_refresh_hud()


## Tahtada gecerli katlama kalmadi. Ceza yok: geri al, yeniden basla veya
## odullu reklam karsiligi cozumu izle.
func _on_stuck() -> void:
	Track.log_event("stuck", {"level": level, "moves": board.moves})
	var actions: Array = []
	if Ads.rewarded_possible():
		actions.append({
			"id": "solve", "label": Loc.t("BTN_WATCH_AD"), "primary": true,
			"note": Loc.t("NOTE_SEE_SOLUTION"),
		})
	actions.append({"id": "undo", "label": Loc.t("STUCK_UNDO")})
	actions.append({"id": "restart", "label": Loc.t("STUCK_RESTART")})
	var card := OfferCard.make(Loc.t("STUCK_TITLE"), "", actions)
	_present_modal(card)
	var choice: String = await card.chose
	match choice:
		"solve":
			if await _rewarded_hazirla() and await Ads.show_rewarded("solution"):
				board.restart()
				await get_tree().create_timer(0.7).timeout
				await board.play_solution()
				_flash_toast(Loc.t("TOAST_NOW_YOU_TRY"))
		"undo":
			board.undo()
		"restart":
			board.restart()
	_refresh_hud()


func _show_no_ads_offer() -> void:
	# Gercek Billing yokken uretim derlemesi satin alma teklifi GOSTERMEZ.
	if not Store.offers_enabled():
		return
	var card := OfferCard.make(Loc.t("NOADS_TITLE"), Loc.t("NOADS_BODY"), [
		{
			"id": "buy", "primary": true,
			"label": Loc.f("BTN_BUY_PRICE", [Store.price_of("no_ads")]),
		},
		{"id": "dismiss", "label": Loc.t("BTN_NOT_NOW")},
	])
	_present_modal(card)
	if await card.chose == "buy":
		await Store.purchase("no_ads")
		_refresh_hud()



func _toggle_sound() -> void:
	Sfx.sfx_on = not Sfx.sfx_on
	Sfx.music_on = Sfx.sfx_on
	SaveData.save_data()
	Sfx.play_ui()
	_refresh_hud()




func _flash_toast(text: String) -> void:
	_toast.text = text
	_toast_tween = _yeni_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.14)
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


##
## SONUCA KADAR EKRANDA KALAN mesaj.
##
## "Reklam hazirlaniyor" bir `_flash_toast` idi: 2 saniye sonra soluyor.
## Ama bekleme 8 saniye suruyor. Arada 6 saniye BOS EKRAN kaliyordu ve
## oyuncu ekrana bakmayi birakiyordu -- sonucu bildiren ikinci mesaj,
## yani asama kodunu tasiyan tek tesahis, hic gorulmuyordu. Oyuncunun
## bildirdigi "hazirlaniyor diyor ama reklam cikmiyor" tam olarak buydu:
## reklam gelmedigi icin degil, CEVABI KIMSE GORMEDIGI icin.
##
## Bekleme mesaji artik sonuc gelene kadar duruyor.
func _hold_toast(text: String) -> void:
	_toast.text = text
	_toast_tween = _yeni_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.14)


## Onceki tween SURUYOR olabilir; oldurmeden yenisini kurmak iki animasyonu
## ayni ozellik uzerinde yaristiriyor ve mesaj rastgele saydamlikta kaliyor.
func _yeni_tween() -> Tween:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	return create_tween()


## Hata ayiklama surucularini takar:
##   godot --path . -- shots   gorsel dogrulama kareleri
##   godot --path . -- soak    uctan uca oynanis testi
##
## Etiket -> dosya eslemesi ACIK tutuluyor. Dosya adini etiketten turetmek
## ("%s_runner.gd") sessizce yanlis yol uretiyordu: "shots" etiketi
## shots_runner.gd ariyor ama dosya shot_runner.gd.
const DEBUG_RUNNERS := {
	"shots": "res://tests/shot_runner.gd",
	"soak": "res://tests/soak_runner.gd",
	"store": "res://tools/store_shots.gd",
	"reel": "res://tools/reel_runner.gd",
}


func _install_debug_hooks() -> void:
	if not OS.is_debug_build():
		return
	var args := OS.get_cmdline_user_args()
	for tag in DEBUG_RUNNERS:
		if not args.has(tag):
			continue
		var path: String = DEBUG_RUNNERS[tag]
		var script: Script = load(path) if ResourceLoader.exists(path) else null
		if script == null:
			push_warning("Hata ayiklama surucusu yuklenemedi: " + path)
			continue
		add_child(script.new())


func _coach() -> void:
	if SaveData.total_folds >= 6 or board.moves > 0:
		return
	_lbl_par.text = Loc.t("COACH_DRAG")
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(board) and board.moves == 0 and board.interactive:
		board.show_gesture_hint()


## Dil degisimi tum etiketleri etkiliyor ve etiketler bir kez olusturuluyor.
## Tek tek guncellemek yerine sahneyi yeniden yukluyoruz: dil secimi baslik
## ekraninda oldugu icin kaybedilecek bir oyun durumu yok.
func _show_language_picker() -> void:
	var card := LanguageCard.new()
	_present_modal(card)
	var code: String = await card.chose
	if code == SaveData.lang:
		return
	SaveData.lang = code
	SaveData.save_data()
	Track.log_event("language_set", {"lang": code if code != "" else "system"})
	get_tree().reload_current_scene()
