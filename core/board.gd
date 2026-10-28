## Поле N×N. Клетка — null или {"c": цвет, "k": вид, "hp": прочность}.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")

var size: int
var cells: Array = []

func _init(n: int = 8) -> void:
	size = n
	cells.resize(n * n)
	cells.fill(null)

func get_cell(x: int, y: int):
	return cells[y * size + x]

func set_cell(x: int, y: int, v) -> void:
	cells[y * size + x] = v

func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size

func filled_count() -> int:
	var n := 0
	for c in cells:
		if c != null:
			n += 1
	return n

func is_empty() -> bool:
	return filled_count() == 0

func can_place(piece_cells: Array, origin: Vector2i) -> bool:
	for c in piece_cells:
		var p: Vector2i = origin + c
		if not inside(p.x, p.y) or get_cell(p.x, p.y) != null:
			return false
	return true

func fits_anywhere(piece_cells: Array) -> bool:
	for y in size:
		for x in size:
			if can_place(piece_cells, Vector2i(x, y)):
				return true
	return false

func place(piece: Dictionary, origin: Vector2i) -> void:
	for i in piece.cells.size():
		var p: Vector2i = origin + piece.cells[i]
		var kind: int = piece.kinds[i]
		set_cell(p.x, p.y, {"c": piece.color, "k": kind, "hp": 2 if kind == Pieces.KIND_STONE else 1})

## Полные строки и столбцы.
func full_lines() -> Dictionary:
	var rows: Array = []
	var cols: Array = []
	for y in size:
		var full := true
		for x in size:
			if get_cell(x, y) == null:
				full = false
				break
		if full:
			rows.append(y)
	for x in size:
		var full := true
		for y in size:
			if get_cell(x, y) == null:
				full = false
				break
		if full:
			cols.append(x)
	return {"rows": rows, "cols": cols}

func _line_cells(is_row: bool, i: int) -> Array:
	var out: Array = []
	for j in size:
		out.append(Vector2i(j, i) if is_row else Vector2i(i, j))
	return out

## Очищает полные линии. Возвращает описание для подсчёта очков:
## cleared — снятые клетки [{pos, c, k}], stones_hit — камни, получившие трещину,
## pure_lines — линии одного цвета, rows/cols — индексы.
func clear_full() -> Dictionary:
	var fl := full_lines()
	var res := {"rows": fl.rows, "cols": fl.cols, "cleared": [], "stones_hit": [], "pure_lines": 0, "lines": fl.rows.size() + fl.cols.size()}
	if res.lines == 0:
		return res
	var touched := {}
	var lines: Array = []
	for y in fl.rows:
		lines.append(_line_cells(true, y))
	for x in fl.cols:
		lines.append(_line_cells(false, x))
	for line in lines:
		var color = get_cell(line[0].x, line[0].y).c
		var pure := true
		for p in line:
			touched[p] = true
			if get_cell(p.x, p.y).c != color:
				pure = false
		if pure:
			res.pure_lines += 1
	for p in touched:
		var cell: Dictionary = get_cell(p.x, p.y)
		if cell.k == Pieces.KIND_STONE and cell.hp > 1:
			cell.hp -= 1
			res.stones_hit.append(p)
			continue
		res.cleared.append({"pos": p, "c": cell.c, "k": cell.k})
		set_cell(p.x, p.y, null)
	return res

## Случайные камни (босс «Камнепад»).
func drop_stones(rng, count: int) -> void:
	var free: Array = []
	for y in size:
		for x in size:
			if get_cell(x, y) == null:
				free.append(Vector2i(x, y))
	rng.shuffle(free)
	for i in mini(count, free.size()):
		set_cell(free[i].x, free[i].y, {"c": rng.randi_range(0, Pieces.COLORS - 1), "k": Pieces.KIND_STONE, "hp": 2})

func clone():
	var b = get_script().new(size)
	for i in cells.size():
		b.cells[i] = null if cells[i] == null else cells[i].duplicate()
	return b
