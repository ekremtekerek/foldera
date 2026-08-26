extends SceneTree

func _initialize() -> void:
	for level in [1, 2, 5, 9, 14, 20, 28, 40, 50]:
		var lv := LevelGen.generate(level)
		var b: BoardModel = lv.board
		print("--- Seviye %d   %dx%d   par=%d   tas=%d" % [level, b.w, b.h, lv.par, b.tiles_left()])
		print(b.debug_string())
	quit()
