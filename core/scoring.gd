## Подсчёт очков хода: фишки × множитель.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")
const Jokers = preload("res://core/jokers.gd")

const CHIPS_PER_CELL := 10
const STONE_CHIPS := 50
const LEVEL_CHIPS := 15
const GOLD_COINS := 3

static func line_mult(lines: int) -> float:
	if lines <= 0:
		return 0.0
	return [1.0, 2.0, 4.0, 8.0][mini(lines, 4) - 1]

## ctx: piece, clear (из Board.clear_full), board (после очистки), streak (с учётом этого хода),
## jokers, levels {семейство: уровень}, discards_left, pieces_left, coins, boss.
static func score_move(ctx: Dictionary) -> Dictionary:
	var clear: Dictionary = ctx.clear
	var s := {"chips": 0, "mult": 0.0, "coins": 0, "score": 0, "log": []}
	if clear.lines == 0:
		return s
	s.chips = CHIPS_PER_CELL * clear.cleared.size()
	s.log.append(["Клетки", "%d × %d фишек" % [clear.cleared.size(), CHIPS_PER_CELL]])
	var lvl: int = ctx.levels.get(ctx.piece.family, 0)
	if lvl > 0:
		s.chips += LEVEL_CHIPS * lvl
		s.log.append([Pieces.FAMILY_NAMES[ctx.piece.family] + " ур. %d" % lvl, "+%d фишек" % (LEVEL_CHIPS * lvl)])
	s.mult = line_mult(clear.lines)
	s.log.append(["Линии: %d" % clear.lines, "множ. %s" % Jokers._fmt(s.mult)])
	if ctx.streak > 0:
		s.mult += 0.5 * ctx.streak
		s.log.append(["Серия %d" % ctx.streak, "+%s множ." % Jokers._fmt(0.5 * ctx.streak)])
	for c in clear.cleared:
		match c.k:
			Pieces.KIND_STONE:
				s.chips += STONE_CHIPS
				s.log.append(["Камень", "+%d фишек" % STONE_CHIPS])
			Pieces.KIND_GOLD:
				s.coins += GOLD_COINS
				s.log.append(["Золото", "+%d мон." % GOLD_COINS])
			Pieces.KIND_GLASS:
				s.mult *= 2.0
				s.log.append(["Стекло", "×2 множ."])
	if clear.pure_lines > 0 and ctx.boss != "mono":
		var k := 3.0 if Jokers.has(ctx.jokers, "purist") else 2.0
		s.mult *= pow(k, clear.pure_lines)
		s.log.append(["Чистые линии: %d" % clear.pure_lines, "×%s множ." % Jokers._fmt(pow(k, clear.pure_lines))])
	for j in ctx.jokers:
		Jokers.on_score(j, s, ctx)
	s.score = int(floor(s.chips * s.mult))
	return s
