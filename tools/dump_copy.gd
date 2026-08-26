extends SceneTree
##
## Magaza metinlerini JSON'a dokerr:
##   godot --headless --path . --script res://tools/dump_copy.gd
##
## Tek kaynak store_copy.gd; Play API betigi (Node) o dosyayi okuyamadigi icin
## buradan JSON uretiliyor. Metni iki yerde tutmuyoruz.
##
const COPY := preload("res://tools/store_copy.gd")
const OUT := "res://store/copy.json"

func _initialize() -> void:
	var out := {}
	for code in COPY.LISTING:
		out[code] = {
			"title": COPY.LISTING[code].title,
			"short": COPY.LISTING[code].short,
			"full": COPY.LISTING[code].full,
		}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("yazilamadi: " + OUT)
		quit(1)
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("%d dil -> %s" % [out.size(), OUT])
	quit(0)
