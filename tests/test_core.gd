## Тесты ядра: godot --headless --path . --script res://tests/test_core.gd
extends SceneTree

const Board = preload("res://core/board.gd")
const Pieces = preload("res://core/pieces.gd")
const Scoring = preload("res://core/scoring.gd")
const Jokers = preload("res://core/jokers.gd")
const RunState = preload("res://core/run_state.gd")
const Rng = preload("res://core/rng.gd")

var failed := 0
var passed := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", msg)

func piece(cells: Array, color := 0, family := "line") -> Dictionary:
	var kinds: Array = []
	for _c in cells:
		kinds.append(Pieces.KIND_NORMAL)
	return {"shape": "t", "family": family, "cells": cells, "kinds": kinds, "color": color}

func row_piece(n: int, color := 0) -> Dictionary:
	var cells: Array = []
	for x in n:
		cells.append(Vector2i(x, 0))
	return piece(cells, color)

func ctx(p: Dictionary, clear: Dictionary, b, extra := {}) -> Dictionary:
	var c := {"piece": p, "clear": clear, "board": b, "streak": 1, "jokers": [], "levels": {},
		"discards_left": 0, "pieces_left": 10, "coins": 0, "boss": ""}
	c.merge(extra, true)
	return c

func _init() -> void:
	test_rotation()
	test_place_and_clear()
	test_cross_clear()
	test_scoring_basic()
	test_pure_and_jokers()
	test_stone()
	test_rng_determinism()
	test_run_flow()
	print("passed: %d, failed: %d" % [passed, failed])
	quit(1 if failed > 0 else 0)

func test_rotation() -> void:
	var r := Pieces.rotate_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 1)
	check(Pieces.bounds(r) == Vector2i(1, 3), "палка после поворота вертикальная")
	check(Pieces.rotate_cells(Pieces.SHAPES.t4.cells, 4) == Pieces.normalize(Pieces.SHAPES.t4.cells), "4 поворота = исходная")

func test_place_and_clear() -> void:
	var b = Board.new(8)
	check(b.can_place(row_piece(5).cells, Vector2i(0, 0)), "можно поставить")
	check(not b.can_place(row_piece(5).cells, Vector2i(4, 0)), "за край нельзя")
	b.place(row_piece(5), Vector2i(0, 0))
	check(not b.can_place(row_piece(1).cells, Vector2i(2, 0)), "на занятую нельзя")
	b.place(row_piece(3), Vector2i(5, 0))
	var res: Dictionary = b.clear_full()
	check(res.lines == 1 and res.rows == [0], "строка снята")
	check(res.cleared.size() == 8, "8 клеток снято")
	check(b.is_empty(), "поле пустое")

func test_cross_clear() -> void:
	var b = Board.new(8)
	for x in 8:
		if x != 3:
			b.place(row_piece(1, x % 5), Vector2i(x, 4))
	for y in 8:
		if y != 4:
			b.place(row_piece(1, y % 5), Vector2i(3, y))
	b.place(row_piece(1), Vector2i(3, 4))
	var res: Dictionary = b.clear_full()
	check(res.lines == 2, "строка + столбец")
	check(res.cleared.size() == 15, "пересечение считается один раз")

func test_scoring_basic() -> void:
	var b = Board.new(8)
	b.place(row_piece(4, 0), Vector2i(0, 0))
	b.place(row_piece(4, 1), Vector2i(4, 0))
	var res: Dictionary = b.clear_full()
	var s := Scoring.score_move(ctx(row_piece(4, 1), res, b))
	# 8 клеток × 10 = 80 фишек; множ. 1 (1 линия) + 0.5 (серия 1) = 1.5 → 120
	check(s.chips == 80, "фишки 80, получили %d" % s.chips)
	check(is_equal_approx(s.mult, 1.5), "множитель 1.5, получили %s" % s.mult)
	check(s.score == 120, "очки 120, получили %d" % s.score)
	var empty := Scoring.score_move(ctx(row_piece(1), {"lines": 0, "cleared": [], "rows": [], "cols": [], "pure_lines": 0, "stones_hit": []}, b))
	check(empty.score == 0, "без линий нет очков")

func test_pure_and_jokers() -> void:
	var b = Board.new(8)
	b.place(row_piece(8, 2), Vector2i(0, 0))
	var res: Dictionary = b.clear_full()
	check(res.pure_lines == 1, "одноцветная линия")
	var s := Scoring.score_move(ctx(row_piece(8, 2), res, b))
	check(is_equal_approx(s.mult, 3.0), "чистая линия ×2: (1+0.5)×2=3, получили %s" % s.mult)
	var js := [Jokers.make("brick"), Jokers.make("purist"), Jokers.make("crown"), Jokers.make("fan_2")]
	s = Scoring.score_move(ctx(row_piece(8, 2), res, b, {"jokers": js}))
	# (1.5 × 3) + 4 = 8.5; корона ×2 = 17; фанат +8 = 25
	check(is_equal_approx(s.mult, 25.0), "джокеры по порядку: 25, получили %s" % s.mult)
	var mono := Scoring.score_move(ctx(row_piece(8, 2), res, b, {"boss": "mono"}))
	check(is_equal_approx(mono.mult, 1.5), "Монохром отключает чистые линии")

func test_stone() -> void:
	var b = Board.new(8)
	var p := row_piece(8, 0)
	p.kinds[0] = Pieces.KIND_STONE
	b.place(p, Vector2i(0, 0))
	var res: Dictionary = b.clear_full()
	check(res.cleared.size() == 7 and res.stones_hit.size() == 1, "камень пережил первую очистку")
	check(b.get_cell(0, 0) != null, "камень остался")
	b.place(row_piece(7, 1), Vector2i(1, 0))
	res = b.clear_full()
	var s := Scoring.score_move(ctx(row_piece(7), res, b))
	check(res.cleared.size() == 8 and s.chips == 80 + Scoring.STONE_CHIPS, "камень снят со второго раза +50")

func test_rng_determinism() -> void:
	var a = RunState.new(42)
	var c = RunState.new(42)
	check(a.bosses == c.bosses, "одинаковые боссы при одном сиде")
	check(str(a.hand) == str(c.hand), "одинаковая рука при одном сиде")

func test_run_flow() -> void:
	var run = RunState.new(7)
	check(run.phase == "play" and run.pieces_left() == 24, "раунд: 24 фигуры")
	check(run.target == 300, "цель первого раунда 300")
	check(run.target_for(2, 0) == 660, "этаж 2: 300×2.2=660")
	run.discard()
	check(run.discards_left == 2 and run.pieces_left() == 24, "сброс не тратит фигуры")
	run.round_score = 10000
	run._check_end()
	check(run.phase == "won", "победа по цели")
	var reward: Dictionary = run.last_reward
	check(reward.base == 3 and reward.hands == 7, "награда: 3 + 7 неиспользованных раздач")
	run.to_shop()
	check(run.phase == "shop" and run.offers.size() == 4, "магазин: 4 предложения")
	run.coins = 100
	check(run.buy(0), "купили джокера")
	check(run.jokers.size() == 1, "джокер в слоте")
	run.sell_joker(0)
	check(run.jokers.is_empty(), "продали")
	run.leave_shop()
	check(run.round_idx == 1 and run.phase == "play", "следующий раунд")
