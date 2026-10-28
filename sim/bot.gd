## Жадный бот: перебирает все ходы текущей руки и выбирает лучший по очкам + форме поля.
extends RefCounted

const Scoring = preload("res://core/scoring.gd")

## Оценка поля: штраф за занятость и за «дыры» (пустые клетки, зажатые с 3–4 сторон).
static func board_eval(b) -> float:
	var holes := 0
	for y in b.size:
		for x in b.size:
			if b.get_cell(x, y) != null:
				continue
			var blocked := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if not b.inside(p.x, p.y) or b.get_cell(p.x, p.y) != null:
					blocked += 1
			if blocked >= 3:
				holes += 1
	return -2.0 * b.filled_count() - 6.0 * holes

static func best_move(run) -> Dictionary:
	var best := {}
	var best_val := -INF
	for i in run.hand.size():
		if not run.is_usable(i):
			continue
		var piece: Dictionary = run.hand[i]
		for y in run.board.size:
			for x in run.board.size:
				var o := Vector2i(x, y)
				if not run.board.can_place(piece.cells, o):
					continue
				var b = run.board.clone()
				b.place(piece, o)
				var clear: Dictionary = b.clear_full()
				var js: Array = []
				for j in run.jokers:
					js.append(j.duplicate(true))
				var s := Scoring.score_move({
					"piece": piece, "clear": clear, "board": b,
					"streak": run.streak + 1 if clear.lines > 0 else 0,
					"jokers": js, "levels": run.levels, "discards_left": run.discards_left,
					"pieces_left": run.pieces_left() - 1, "coins": run.coins, "boss": run.boss(),
				})
				var val: float = s.score * 0.5 + board_eval(b) * 3.0
				if val > best_val:
					best_val = val
					best = {"i": i, "origin": o}
	return best

## Магазин: джокеры по возможности, затем улучшение самого частого семейства.
static func shop(run) -> void:
	for _pass in 3:
		for i in run.offers.size():
			var o: Dictionary = run.offers[i]
			if o.type == "joker" and run.can_buy(i):
				run.buy(i)
		for i in run.offers.size():
			if run.offers[i].type == "upgrade" and run.can_buy(i) and run.coins - run.offers[i].price >= 4:
				run.buy(i)
		if run.coins >= run.reroll_price + 8 and run.jokers.size() < run.MAX_JOKERS:
			run.reroll()
		else:
			break

## Полный забег. Возвращает {won, floor, round, score_log}.
static func play_run(seed_value: int) -> Dictionary:
	var RunState = load("res://core/run_state.gd")
	var run = RunState.new(seed_value)
	var guard := 0
	while guard < 5000:
		guard += 1
		match run.phase:
			"play":
				var m: Dictionary = best_move(run)
				if m.is_empty():
					if not run.discard():
						break
				else:
					run.place(m.i, m.origin)
			"won":
				run.to_shop()
			"shop":
				shop(run)
				run.leave_shop()
			_:
				break
	return {"won": run.phase == "run_won", "round": run.round_number(), "floor": run.floor_num,
		"boss": run.boss(), "jokers": run.jokers.map(func(j): return j.id), "phase": run.phase}
