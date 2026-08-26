class_name FoldSolver
extends RefCounted
##
## Bir tahtanin kac katlamada temizlenebilecegini bulur (iterative deepening).
## Ayna esdegerligi sayesinde sadece side 0 taranir -> dallanma yariya iner.
##

const NODE_CAP := 150000

var nodes := 0
var path: Array = []
var _visited := {}
var bailed := false


func min_folds(b: BoardModel, limit: int) -> int:
	if b.is_solved():
		return 0
	bailed = false
	for d in range(1, limit + 1):
		nodes = 0
		_visited = {}
		path = []
		if _dfs(b, d):
			return d
		if nodes >= NODE_CAP:
			bailed = true
			return -1
	return -1


## Kabul edilebilir alt sinir: tek katlamada en fazla 2*ortusme kadar tas gidebilir.
func _hopeless(b: BoardModel, depth: int) -> bool:
	var best := maxi((b.w / 2) * b.h, (b.h / 2) * b.w)
	if best == 0:
		return true
	return b.tiles_left() > 2 * best * depth


func _dfs(b: BoardModel, depth: int) -> bool:
	if b.is_solved():
		return true
	if depth <= 0:
		return false
	nodes += 1
	if nodes >= NODE_CAP:
		return false
	if _hopeless(b, depth):
		return false
	var k := b.key() + "|" + str(depth)
	if _visited.has(k):
		return false
	_visited[k] = true
	for c in b.creases():
		var r := b.fold(c[0], c[1], 0)
		if not r.ok:
			continue
		path.append(c)
		if _dfs(BoardModel.new(r.w, r.h, r.cells), depth - 1):
			return true
		path.pop_back()
	return false
