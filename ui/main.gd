## Экран игры. Всё рисуется в _draw, ввод — в _gui_input. Правила — в core/run_state.gd.
extends Control

const RunState = preload("res://core/run_state.gd")
const Pieces = preload("res://core/pieces.gd")
const Jokers = preload("res://core/jokers.gd")

const W := 720.0
const BG := Color("1b1d2b")
const PANEL := Color("262a3d")
const PANEL_HI := Color("323750")
const TEXT := Color("eef0f8")
const MUTED := Color("9aa0b8")
const ACCENT := Color("f5c84c")
const CHIPS_C := Color("4f8cf7")
const MULT_C := Color("e8505b")
const COLORS := [Color("e8505b"), Color("4f8cf7"), Color("4cc38a"), Color("f5c84c"), Color("a66cf0")]

const BOARD_TOP := 380.0
const BOARD_PX := 608.0
const HAND_TOP := 1030.0
const HAND_H := 170.0
const DRAG_LIFT := 150.0

var run
var font: Font
var buttons: Array = [] # [{rect, cb, enabled}]
var drag_i := -1
var drag_pos := Vector2.ZERO
var hover_origin := Vector2i(-1, -1)
var selected_joker := -1
var flashes: Array = [] # [{pos: Vector2i, color, t}]
var popups: Array = [] # [{text, sub, t}]
var shake := 0.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	new_run()

func new_run(seed_value: int = 0) -> void:
	run = RunState.new(seed_value)
	selected_joker = -1
	queue_redraw()

# ---------- геометрия ----------

func cell_px() -> float:
	return BOARD_PX / run.board.size

func board_rect() -> Rect2:
	return Rect2((W - BOARD_PX) / 2.0, BOARD_TOP, BOARD_PX, BOARD_PX)

func hand_slot_rect(i: int) -> Rect2:
	var w := (W - 40.0) / 3.0
	return Rect2(20.0 + i * w, HAND_TOP, w, HAND_H)

func joker_rect(i: int) -> Rect2:
	var w := (W - 40.0 - 4 * 10.0) / 5.0
	return Rect2(20.0 + i * (w + 10.0), 240.0, w, 120.0)

## Клетка-«якорь» фигуры под пальцем (фигура рисуется над пальцем, центром).
func origin_for(piece: Dictionary, pos: Vector2) -> Vector2i:
	var cp := cell_px()
	var b := Pieces.bounds(piece.cells)
	var top_left := pos - Vector2(0, DRAG_LIFT) - Vector2(b.x, b.y) * cp / 2.0
	var rel := (top_left - board_rect().position) / cp
	return Vector2i(roundi(rel.x), roundi(rel.y))

# ---------- ввод ----------

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = _to_design(event.position)
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		pos = _to_design(event.position)
		moved = true
	elif event is InputEventScreenTouch:
		pos = _to_design(event.position)
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		pos = _to_design(event.position)
		moved = true
	else:
		return
	if pressed:
		_on_press(pos)
	elif moved and drag_i >= 0:
		drag_pos = pos
		hover_origin = origin_for(run.hand[drag_i], pos)
		queue_redraw()
	elif released and drag_i >= 0:
		_drop(pos)

func _to_design(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()

func _scale() -> float:
	return minf(size.x / W, size.y / 1280.0)

func _offset() -> Vector2:
	return (size - Vector2(W, 1280.0) * _scale()) / 2.0

func _on_press(pos: Vector2) -> void:
	for b in buttons:
		if b.rect.has_point(pos):
			if b.enabled:
				b.cb.call()
				queue_redraw()
			return
	if run.phase != "play" and run.phase != "shop":
		return
	for i in run.jokers.size():
		if joker_rect(i).has_point(pos):
			selected_joker = -1 if selected_joker == i else i
			queue_redraw()
			return
	selected_joker = -1
	if run.phase == "play":
		for i in 3:
			if hand_slot_rect(i).has_point(pos) and run.is_usable(i):
				drag_i = i
				drag_pos = pos
				hover_origin = origin_for(run.hand[i], pos)
				break
	queue_redraw()

func _drop(pos: Vector2) -> void:
	var i := drag_i
	drag_i = -1
	var origin := origin_for(run.hand[i], pos)
	var res: Dictionary = run.place(i, origin)
	if not res.is_empty() and res.clear.lines > 0:
		for c in res.clear.cleared:
			flashes.append({"pos": c.pos, "color": COLORS[c.c], "t": 0.5})
		var big: bool = res.clear.lines >= 3
		shake = 0.25 if big else 0.0
		popups.append({"text": "+%d" % res.score, "sub": "%d × %s" % [res.chips, Jokers._fmt(res.mult)], "t": 1.4, "log": res.log})
	queue_redraw()

func _process(delta: float) -> void:
	if flashes.is_empty() and popups.is_empty() and shake <= 0.0:
		return
	for f in flashes:
		f.t -= delta
	flashes = flashes.filter(func(f): return f.t > 0.0)
	for p in popups:
		p.t -= delta
	popups = popups.filter(func(p): return p.t > 0.0)
	shake = maxf(0.0, shake - delta)
	queue_redraw()

# ---------- отрисовка ----------

func _draw() -> void:
	buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var s := _scale()
	var off := _offset()
	if shake > 0.0:
		off += Vector2(randf_range(-6, 6), randf_range(-6, 6)) * shake * 4.0
	draw_set_transform(off, 0.0, Vector2(s, s))
	match run.phase:
		"shop":
			_draw_hud()
			_draw_jokers()
			_draw_shop()
		_:
			_draw_hud()
			_draw_jokers()
			_draw_board()
			_draw_hand()
			_draw_popups()
			if run.phase == "won":
				_draw_won()
			elif run.phase == "lost":
				_draw_end("Забег окончен", "Дошли до раунда %d из 15" % run.round_number())
			elif run.phase == "run_won":
				_draw_end("Победа!", "Все 5 этажей пройдены")
	_draw_joker_info()

func text(pos: Vector2, t: String, sz: int, color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos, t, align, width, sz, color)

func button(r: Rect2, label: String, cb: Callable, enabled := true, color := ACCENT) -> void:
	draw_rect(r, color if enabled else PANEL, true)
	if not enabled:
		draw_rect(r, PANEL_HI, false, 2.0)
	var tc := (BG if color == ACCENT else TEXT) if enabled else MUTED
	text(Vector2(r.position.x, r.position.y + r.size.y / 2.0 + 10.0), label, 28, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	buttons.append({"rect": r, "cb": cb, "enabled": enabled})

func _draw_hud() -> void:
	var b: String = run.boss()
	var title := "Этаж %d · %s" % [run.floor_num, RunState.ROUND_NAMES[run.round_idx]]
	if b != "":
		title += ": " + RunState.BOSSES[b].name
	text(Vector2(20, 50), title, 30, MULT_C if b != "" else TEXT)
	if b != "":
		text(Vector2(20, 84), RunState.BOSSES[b].desc, 22, MUTED)
	# Монета рисуется кругом: в веб-шрифте нет символа «●».
	var coins_s := str(run.coins)
	var cw := font.get_string_size(coins_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	text(Vector2(20, 50), coins_s, 32, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, W - 40)
	draw_circle(Vector2(W - 20 - cw - 22, 39), 12, ACCENT)
	draw_circle(Vector2(W - 20 - cw - 22, 39), 7, Color("b8892a"))
	if run.phase == "shop":
		return
	# Счёт и цель
	var r := Rect2(20, 104, W - 40, 116)
	draw_rect(r, PANEL)
	text(Vector2(40, 150), "Очки", 22, MUTED)
	text(Vector2(40, 200), str(run.round_score), 48, TEXT)
	text(Vector2(250, 150), "Цель", 22, MUTED)
	text(Vector2(250, 200), str(run.target), 48, ACCENT)
	var progress := clampf(float(run.round_score) / run.target, 0.0, 1.0)
	draw_rect(Rect2(40, 210, 380, 6), PANEL_HI)
	draw_rect(Rect2(40, 210, 380 * progress, 6), ACCENT)
	text(Vector2(460, 150), "Фигур", 22, MUTED)
	text(Vector2(460, 200), str(run.pieces_left()), 40, TEXT)
	text(Vector2(580, 150), "Серия", 22, MUTED)
	text(Vector2(580, 200), "×%d" % run.streak if run.streak > 0 else "—", 40, MULT_C if run.streak > 1 else TEXT)

func _draw_jokers() -> void:
	for i in RunState.MAX_JOKERS:
		var r := joker_rect(i)
		if i < run.jokers.size():
			var j: Dictionary = run.jokers[i]
			var rar: String = Jokers.DEFS[j.id].rarity
			var c: Color = {"common": PANEL_HI, "uncommon": Color("2f5a8a"), "rare": Color("7a3b8f")}[rar]
			draw_rect(r, c)
			if i == selected_joker:
				draw_rect(r, ACCENT, false, 3.0)
			_wrap(Vector2(r.position.x + 6, r.position.y + 30), Jokers.DEFS[j.id].name, _fit_size(Jokers.DEFS[j.id].name, 20, r.size.x - 12), r.size.x - 12, TEXT, 3)
		else:
			draw_rect(r, PANEL)
			text(Vector2(r.position.x, r.position.y + 70), "пусто", 20, PANEL_HI, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func _draw_joker_info() -> void:
	if selected_joker < 0 or selected_joker >= run.jokers.size():
		return
	var j: Dictionary = run.jokers[selected_joker]
	var r := Rect2(20, 370, W - 40, 170)
	draw_rect(r, Color("111320"))
	draw_rect(r, ACCENT, false, 2.0)
	text(Vector2(40, 410), Jokers.DEFS[j.id].name, 30, ACCENT)
	_wrap(Vector2(40, 450), Jokers.describe(j), 24, W - 280, TEXT, 3)
	var idx: int = selected_joker
	button(Rect2(W - 220, 470, 180, 54), "Продать +%d" % Jokers.sell_price(j.id), func():
		run.sell_joker(idx)
		selected_joker = -1)
	if idx > 0:
		button(Rect2(W - 220, 390, 85, 54), "<", func():
			run.move_joker(idx, idx - 1)
			selected_joker = idx - 1, true, PANEL_HI)
	if idx < run.jokers.size() - 1:
		button(Rect2(W - 125, 390, 85, 54), ">", func():
			run.move_joker(idx, idx + 1)
			selected_joker = idx + 1, true, PANEL_HI)

## Размер шрифта, при котором самое длинное слово влезает в ширину.
func _fit_size(t: String, sz: int, width: float) -> int:
	for word in t.split(" "):
		while sz > 12 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width:
			sz -= 1
	return sz

## Простой перенос строк по словам.
func _wrap(pos: Vector2, t: String, sz: int, width: float, color: Color, max_lines := 4) -> void:
	var line := ""
	var y := pos.y
	var n := 0
	for word in t.split(" "):
		var cand := word if line == "" else line + " " + word
		if font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > width and line != "":
			text(Vector2(pos.x, y), line, sz, color)
			y += sz + 6
			n += 1
			line = word
			if n >= max_lines:
				return
		else:
			line = cand
	if line != "":
		text(Vector2(pos.x, y), line, sz, color)

func _draw_cell(r: Rect2, color: Color, kind: int, hp: int = 1, alpha := 1.0) -> void:
	var c := color
	c.a = alpha
	var inner := r.grow(-2.0)
	if kind == Pieces.KIND_STONE:
		c = Color(0.55, 0.56, 0.62, alpha)
	draw_rect(inner, c)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.18)), Color(1, 1, 1, 0.18 * alpha))
	match kind:
		Pieces.KIND_GOLD:
			draw_circle(inner.get_center(), inner.size.x * 0.22, Color(ACCENT, alpha))
			draw_circle(inner.get_center(), inner.size.x * 0.13, Color(Color("b8892a"), alpha))
		Pieces.KIND_GLASS:
			draw_rect(inner.grow(-inner.size.x * 0.2), Color(1, 1, 1, 0.35 * alpha))
			draw_line(inner.position + inner.size * Vector2(0.25, 0.7), inner.position + inner.size * Vector2(0.7, 0.25), Color(1, 1, 1, 0.8 * alpha), 3.0)
		Pieces.KIND_STONE:
			draw_rect(inner, Color(0.3, 0.3, 0.35, alpha), false, 3.0)
			if hp < 2:
				draw_line(inner.position + inner.size * Vector2(0.2, 0.15), inner.position + inner.size * Vector2(0.55, 0.55), Color(0.15, 0.15, 0.2, alpha), 3.0)
				draw_line(inner.position + inner.size * Vector2(0.55, 0.55), inner.position + inner.size * Vector2(0.8, 0.9), Color(0.15, 0.15, 0.2, alpha), 3.0)

func _draw_board() -> void:
	var br := board_rect()
	var cp := cell_px()
	draw_rect(br.grow(8.0), PANEL)
	var n: int = run.board.size
	# Подсветка: куда встанет фигура и какие линии закроются.
	var ghost := {}
	var ghost_ok := false
	var will_clear := {}
	if drag_i >= 0:
		var piece: Dictionary = run.hand[drag_i]
		ghost_ok = run.board.can_place(piece.cells, hover_origin)
		for c in piece.cells:
			ghost[hover_origin + c] = true
		if ghost_ok:
			var b = run.board.clone()
			b.place(piece, hover_origin)
			var fl: Dictionary = b.full_lines()
			for y in fl.rows:
				for x in n:
					will_clear[Vector2i(x, y)] = true
			for x in fl.cols:
				for y in n:
					will_clear[Vector2i(x, y)] = true
	for y in n:
		for x in n:
			var r := Rect2(br.position + Vector2(x, y) * cp, Vector2(cp, cp))
			var cell = run.board.get_cell(x, y)
			var p := Vector2i(x, y)
			if cell == null:
				draw_rect(r.grow(-2.0), Color("20233a"))
			else:
				_draw_cell(r, COLORS[cell.c], cell.k, cell.hp)
			if will_clear.has(p):
				draw_rect(r.grow(-2.0), Color(1, 1, 1, 0.22))
			if ghost.has(p) and ghost_ok:
				var piece: Dictionary = run.hand[drag_i]
				_draw_cell(r, COLORS[piece.color], Pieces.KIND_NORMAL, 1, 0.45)
	for f in flashes:
		var r := Rect2(br.position + Vector2(f.pos) * cp, Vector2(cp, cp))
		var k: float = f.t / 0.5
		draw_rect(r.grow(-2.0 + 6.0 * (1.0 - k)), Color(1, 1, 1, 0.8 * k))

func _draw_piece(piece: Dictionary, top_left: Vector2, cp: float, alpha := 1.0) -> void:
	for i in piece.cells.size():
		var c: Vector2i = piece.cells[i]
		_draw_cell(Rect2(top_left + Vector2(c) * cp, Vector2(cp, cp)), COLORS[piece.color], piece.kinds[i], 2, alpha)

func _draw_hand() -> void:
	for i in 3:
		var r := hand_slot_rect(i)
		var piece = run.hand[i] if i < run.hand.size() else null
		if piece == null or i == drag_i:
			continue
		var cp := 30.0
		var b := Pieces.bounds(piece.cells)
		var tl := r.get_center() - Vector2(b.x, b.y) * cp / 2.0
		if not run.is_usable(i):
			draw_rect(Rect2(r.get_center() - Vector2(50, 50), Vector2(100, 100)), PANEL)
			text(Vector2(r.position.x, r.get_center().y + 14), "?", 44, MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			continue
		var fits: bool = run.board.fits_anywhere(piece.cells)
		_draw_piece(piece, tl, cp, 1.0 if fits else 0.3)
	# Кнопка сброса руки
	var can: bool = run.can_discard()
	button(Rect2(20, 1210, 300, 60), "Сбросить руку (%d)" % run.discards_left, func(): run.discard(), can, PANEL_HI if not _stuck() else ACCENT)
	if _stuck() and can:
		text(Vector2(340, 1250), "Ничего не влезает — сбросьте руку", 22, ACCENT)
	if drag_i >= 0:
		var piece: Dictionary = run.hand[drag_i]
		var cp := cell_px()
		var b := Pieces.bounds(piece.cells)
		var tl := drag_pos - Vector2(0, DRAG_LIFT) - Vector2(b.x, b.y) * cp / 2.0
		_draw_piece(piece, tl, cp, 0.9)

func _stuck() -> bool:
	for i in run.hand.size():
		if run.is_usable(i) and run.board.fits_anywhere(run.hand[i].cells):
			return false
	return true

func _draw_popups() -> void:
	for p in popups:
		var k: float = clampf(p.t / 1.4, 0.0, 1.0)
		var y := BOARD_TOP + BOARD_PX / 2.0 - 40.0 * (1.0 - k)
		var a := minf(1.0, k * 2.0)
		draw_rect(Rect2(140, y - 70, W - 280, 130), Color(0, 0, 0, 0.6 * a))
		text(Vector2(0, y), p.text, 56, Color(ACCENT, a), HORIZONTAL_ALIGNMENT_CENTER, W)
		text(Vector2(0, y + 44), p.sub, 30, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, W)

func _overlay(h: float) -> Rect2:
	draw_rect(Rect2(0, 0, W, 1280), Color(0, 0, 0, 0.7))
	var r := Rect2(60, 640 - h / 2.0, W - 120, h)
	draw_rect(r, PANEL)
	draw_rect(r, ACCENT, false, 2.0)
	return r

func _draw_won() -> void:
	var r := _overlay(520)
	var rw: Dictionary = run.last_reward
	text(Vector2(0, r.position.y + 70), "Раунд пройден!", 44, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, W)
	var y := r.position.y + 150
	for row in [["За раунд", rw.base], ["Неиспользованные раздачи", rw.hands], ["Проценты (1 за 5 монет)", rw.interest], ["Джокеры", rw.jokers]]:
		if row[1] == 0 and row[0] == "Джокеры":
			continue
		text(Vector2(r.position.x + 40, y), row[0], 28, TEXT)
		text(Vector2(r.position.x + 40, y), "+%d" % row[1], 28, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 80)
		y += 50
	text(Vector2(r.position.x + 40, y + 20), "Итого", 32, TEXT)
	text(Vector2(r.position.x + 40, y + 20), "+%d мон." % rw.total, 32, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 80)
	var last: bool = run.floor_num == RunState.FLOORS and run.round_idx == 2
	button(Rect2(r.position.x + 40, r.end.y - 100, r.size.x - 80, 70), "Дальше" if last else "В магазин", func(): run.to_shop())

func _draw_end(title: String, sub: String) -> void:
	var r := _overlay(360)
	text(Vector2(0, r.position.y + 90), title, 48, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, W)
	text(Vector2(0, r.position.y + 150), sub, 28, TEXT, HORIZONTAL_ALIGNMENT_CENTER, W)
	button(Rect2(r.position.x + 40, r.end.y - 110, r.size.x - 80, 70), "Новый забег", func(): new_run())

func _draw_shop() -> void:
	text(Vector2(0, 160), "Магазин", 44, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, W)
	if not run.jokers.is_empty():
		text(Vector2(0, 450), "Нажмите на джокера выше, чтобы продать или переставить", 20, MUTED, HORIZONTAL_ALIGNMENT_CENTER, W)
	for i in run.offers.size():
		var o: Dictionary = run.offers[i]
		var r := Rect2(20 + (i % 2) * 350, 560 + (i / 2) * 270, 330, 255)
		draw_rect(r, PANEL)
		var title := ""
		var desc := ""
		var kind := ""
		match o.type:
			"joker":
				title = Jokers.DEFS[o.id].name
				desc = Jokers.describe(Jokers.make(o.id))
				kind = {"common": "Джокер", "uncommon": "Джокер · необычный", "rare": "Джокер · редкий"}[Jokers.DEFS[o.id].rarity]
			"upgrade":
				title = "%s: ур. %d" % [Pieces.FAMILY_NAMES[o.family], run.levels.get(o.family, 0) + 1]
				desc = "+15 фишек, когда линию закрывает эта фигура"
				kind = "Улучшение фигуры"
			"pack":
				title = "Набор: " + RunState.KIND_NAMES[o.kind]
				desc = {Pieces.KIND_GOLD: "Чаще будут золотые клетки: +3 монеты при снятии",
					Pieces.KIND_GLASS: "Чаще будут стеклянные клетки: ×2 к множителю при снятии",
					Pieces.KIND_STONE: "Чаще будут камни: снимаются со второго раза, +50 фишек"}[o.kind]
				kind = "Набор клеток"
		text(Vector2(r.position.x + 20, r.position.y + 36), kind, 20, MUTED)
		_wrap(Vector2(r.position.x + 20, r.position.y + 72), title, 28, r.size.x - 40, TEXT, 1)
		_wrap(Vector2(r.position.x + 20, r.position.y + 112), desc, 21, r.size.x - 40, MUTED, 3)
		var idx: int = i
		if o.sold:
			text(Vector2(r.position.x, r.end.y - 30), "Куплено", 26, MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		else:
			button(Rect2(r.position.x + 20, r.end.y - 70, r.size.x - 40, 52), "Купить за %d" % o.price, func(): run.buy(idx), run.can_buy(idx))
	button(Rect2(20, 1110, 330, 70), "Обновить за %d" % run.reroll_price, func(): run.reroll(), run.coins >= run.reroll_price, PANEL_HI)
	button(Rect2(370, 1110, 330, 70), "Следующий раунд", func(): run.leave_shop())
	var nf: int = run.floor_num + (1 if run.round_idx == 2 else 0)
	var nr: int = (run.round_idx + 1) % 3
	var t: int = run.target_for(nf, nr)
	var note := "Дальше: %s, цель %d" % [RunState.ROUND_NAMES[nr], t]
	if nr == 2:
		note += " · босс «%s»" % RunState.BOSSES[run.bosses[nf - 1]].name
	text(Vector2(0, 1235), note, 22, MUTED, HORIZONTAL_ALIGNMENT_CENTER, W)
