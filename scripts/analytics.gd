extends Node
##
## Analitik (autoload: Track). Su an tamamen YEREL -- hicbir sey disari
## gonderilmiyor. Amaci bir SDK bagimliligi eklemeden once dogru olaylari
## dogru alanlarla toplamak; sonradan Firebase/GameAnalytics'e baglamak
## `_sink()` fonksiyonunu degistirmekten ibaret kaliyor.
##
## En kritik olcum HUNI: oyuncular hangi seviyede biraktiriyor. Bunun icin
## level_start / level_complete / level_abandon uclusu sart -- sadece
## level_complete toplamak kac kisinin takilip kaldigini GIZLER.

const PATH := "user://events.jsonl"
const MAX_BUFFER := 400

var enabled := true
var session_id := ""
var _buffer: Array = []
var _session_start := 0
var _level_start := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_id = "%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	_session_start = Time.get_ticks_msec()
	log_event("session_start", {
		"unlocked": SaveData.unlocked,
		"total_stars": SaveData.total_stars(),
		"ads_removed": SaveData.ads_removed,
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		log_event("session_end", {"seconds": _elapsed(_session_start)})
		flush()


func log_event(name: String, props: Dictionary = {}) -> void:
	if not enabled:
		return
	var e := {
		"t": Time.get_datetime_string_from_system(true),
		"s": session_id,
		"e": name,
	}
	for k in props:
		e[k] = props[k]
	_buffer.append(e)
	if _buffer.size() >= MAX_BUFFER:
		flush()
	if OS.is_debug_build():
		print("[track] ", name, "  ", props)


## Seviye huni yardimcilari -- sureyi de otomatik olcuyor.
func level_start(level: int, par: int) -> void:
	_level_start = Time.get_ticks_msec()
	log_event("level_start", {"level": level, "par": par})


func level_complete(level: int, moves: int, par: int, stars: int) -> void:
	log_event("level_complete", {
		"level": level, "moves": moves, "par": par, "stars": stars,
		"seconds": _elapsed(_level_start),
	})


func level_abandon(level: int, moves: int) -> void:
	if _level_start == 0:
		return
	log_event("level_abandon", {
		"level": level, "moves": moves, "seconds": _elapsed(_level_start),
	})
	_level_start = 0


func _elapsed(from_msec: int) -> float:
	return snappedf(float(Time.get_ticks_msec() - from_msec) / 1000.0, 0.1)


func flush() -> void:
	if _buffer.is_empty():
		return
	_sink(_buffer)
	_buffer.clear()


## Tek cikis noktasi. Uzak bir servise baglamak icin burasi degistirilir.
func _sink(events: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	for e in events:
		f.store_line(JSON.stringify(e))
	f.close()
