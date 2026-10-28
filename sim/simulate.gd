## Баланс-симулятор: godot --headless --path . --script res://sim/simulate.gd -- [кол-во забегов]
extends SceneTree

const Bot = preload("res://sim/bot.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 50
	var reached := {}
	var lost_on_boss := {}
	var wins := 0
	var t0 := Time.get_ticks_msec()
	for k in n:
		var r: Dictionary = Bot.play_run(1000 + k)
		if r.won:
			wins += 1
		reached[r.round] = reached.get(r.round, 0) + 1
		if r.boss != "" and not r.won:
			lost_on_boss[r.boss] = lost_on_boss.get(r.boss, 0) + 1
	print("Забегов: %d, побед: %d (%.0f%%), %.1f с" % [n, wins, 100.0 * wins / n, (Time.get_ticks_msec() - t0) / 1000.0])
	var keys := reached.keys()
	keys.sort()
	var cum := n
	for r in keys:
		print("  дошли до раунда %2d: %3d%%   (закончили здесь: %d)" % [r, int(100.0 * cum / n), reached[r]])
		cum -= reached[r]
	print("Проигрыши на боссах: ", lost_on_boss)
	quit()
