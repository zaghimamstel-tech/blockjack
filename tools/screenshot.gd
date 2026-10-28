## Скриншоты экранов для проверки вёрстки: xvfb-run godot --path . --script res://tools/screenshot.gd -- out_dir
extends SceneTree

const Bot = preload("res://sim/bot.gd")

func _init() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	root.size = Vector2i(720, 1280)
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.new_run(1000)
	await _shot(main, out + "/1_play.png")
	for _k in 6:
		var m: Dictionary = Bot.best_move(main.run)
		if m.is_empty():
			break
		main.run.place(m.i, m.origin)
	# Показать перетаскивание
	for i in 3:
		if main.run.is_usable(i):
			main.drag_i = i
			main.drag_pos = Vector2(360, 900)
			main.hover_origin = main.origin_for(main.run.hand[i], main.drag_pos)
			break
	main.popups.append({"text": "+240", "sub": "80 × 3", "t": 1.0, "log": []})
	await _shot(main, out + "/2_drag.png")
	main.drag_i = -1
	main.popups.clear()
	while main.run.phase == "play":
		var m: Dictionary = Bot.best_move(main.run)
		if m.is_empty():
			if not main.run.discard():
				break
		else:
			main.run.place(m.i, m.origin)
	await _shot(main, out + "/3_won.png")
	main.run.to_shop()
	main.run.coins = 20
	main.run.buy(0)
	main.selected_joker = 0
	await _shot(main, out + "/4_shop.png")
	quit()

func _shot(main, path: String) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
