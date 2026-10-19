extends Control
const GameArt = preload("res://ui/game_art.gd")
const Avatar = preload("res://ui/avatar.gd")
const Ceremony = preload("res://ui/tournament_ceremony.gd")
const Arena = preload("res://games/arena.gd")
const Catalog = preload("res://core/catalog.gd")
const Rainbow = preload("res://assets/rainbow.gdshader")
const INK = Color("302245")
const SHELL_MUTED = Color("4e3f61")
const PANEL = Color("151e34")
const MUTED = Color("a4afc8")
const PURPLE = Color("b3a0ff")
var page: String = "home"
var content: VBoxContainer
var outer: MarginContainer
var responsive_grids: Array = []
var current_game: String = "sprint"
var cup_mode: bool = false
var cup_selection: Array = []
var arena: Control
var pause_overlay: Control
var selected_player: int = 0
var last_scores: Dictionary = {}
var last_winners: Array = []
var cup_done: bool = false
var menu_scroll: ScrollContainer
var swipe_index: int = -1
var swipe_start: Vector2
var swipe_dragging: bool = false
var swipe_velocity: float = 0.0
var swipe_offset: float = 0.0
var swipe_block_until: int = 0
var seat_choice_buttons: Array = []
var seat_summary: Label
var seat_continue: Button

func _ready() -> void:
	var theme_new = Theme.new()
	theme_new.default_font_size = 22
	theme = theme_new
	get_viewport().size_changed.connect(reflow)
	show_home()

func _input(event: InputEvent) -> void:
	if page == "game" or not is_instance_valid(menu_scroll):
		return
	if event is InputEventMouseButton and (menu_scroll.get_global_rect().has_point(event.position) or (not event.pressed and swipe_index == -2)):
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			swipe_velocity = 0
			swipe_offset = menu_scroll.scroll_vertical
			scroll_menu(-80 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 80)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and swipe_index == -1:
				swipe_index = -2
				swipe_start = event.position
				swipe_dragging = false
				swipe_velocity = 0
				swipe_offset = menu_scroll.scroll_vertical
			elif not event.pressed and swipe_index == -2:
				if swipe_dragging:
					swipe_block_until = Time.get_ticks_msec() + 200
					get_viewport().set_input_as_handled()
				swipe_index = -1
				swipe_dragging = false
	elif event is InputEventMouseMotion and swipe_index == -2:
		if absf(event.position.y - swipe_start.y) > 12:
			swipe_dragging = true
		if swipe_dragging:
			scroll_menu(-event.relative.y)
			swipe_velocity = clampf(-event.velocity.y, -2200, 2200)
			swipe_block_until = Time.get_ticks_msec() + 200
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		swipe_velocity = 0
		swipe_offset = menu_scroll.scroll_vertical
		scroll_menu(event.delta.y * 40)
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		if event.pressed and swipe_index == -1 and menu_scroll.get_global_rect().has_point(event.position):
			swipe_index = event.index
			swipe_start = event.position
			swipe_dragging = false
			swipe_velocity = 0
			swipe_offset = menu_scroll.scroll_vertical
		elif not event.pressed and event.index == swipe_index:
			if swipe_dragging:
				swipe_block_until = Time.get_ticks_msec() + 200
				get_viewport().set_input_as_handled()
			swipe_index = -1
			swipe_dragging = false
	elif event is InputEventScreenDrag and event.index == swipe_index:
		if not swipe_dragging and absf(event.position.y - swipe_start.y) > 12:
			swipe_dragging = true
		if swipe_dragging:
			scroll_menu(-event.relative.y)
			swipe_velocity = clampf(-event.velocity.y, -2200, 2200)
			swipe_block_until = Time.get_ticks_msec() + 200
			get_viewport().set_input_as_handled()

func scroll_menu(amount: float) -> void:
	if not is_instance_valid(menu_scroll):
		return
	var bar = menu_scroll.get_v_scroll_bar()
	swipe_offset = clampf(swipe_offset + amount, 0, maxf(0, bar.max_value - bar.page))
	menu_scroll.scroll_vertical = roundi(swipe_offset)

func _process(delta: float) -> void:
	if page != "game" and swipe_index == -1 and is_instance_valid(menu_scroll) and absf(swipe_velocity) > 5:
		scroll_menu(swipe_velocity * delta)
		swipe_velocity *= exp(-delta * 8)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and page == "game" and is_instance_valid(arena) and not arena.paused:
		toggle_pause()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		back()

func back() -> void:
	if page == "game":
		toggle_pause()
	elif page == "library":
		show_setup()
	elif page == "setup":
		show_home()
	else:
		show_home()

func box(color: Color = PANEL, radius: int = 24) -> StyleBoxFlat:
	var b = StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.content_margin_left = 24
	b.content_margin_right = 24
	b.content_margin_top = 22
	b.content_margin_bottom = 22
	return b

func label(value: String, font_size: int = 22, color: Color = Color("f4f1ff")) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func button(value: String, callback: Callable, accent: Color = PANEL) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = 64
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", box(accent, 18))
	b.add_theme_stylebox_override("hover", box(accent.lightened(0.12), 18))
	b.add_theme_stylebox_override("pressed", box(accent.darkened(0.15), 18))
	b.add_theme_stylebox_override("disabled", box(accent.darkened(0.4), 18))
	b.add_theme_color_override("font_color", Color("11182b") if accent == PURPLE or accent == Color("6ce5bc") else Color("f4f1ff"))
	b.add_theme_color_override("font_hover_color", Color("11182b") if accent == PURPLE or accent == Color("6ce5bc") else Color.WHITE)
	b.add_theme_font_size_override("font_size", 22)
	b.mouse_entered.connect(func(): create_tween().tween_property(b, "self_modulate", Color(1.12, 1.12, 1.12), 0.12))
	b.mouse_exited.connect(func(): create_tween().tween_property(b, "self_modulate", Color.WHITE, 0.16))
	var born_at: int = Time.get_ticks_msec()
	b.pressed.connect(func():
		# A touch and its synthetic mouse event must not click through to a new page.
		if swipe_dragging or Time.get_ticks_msec() < swipe_block_until:
			return
		if OS.has_feature("mobile") and Time.get_ticks_msec() - born_at < 250:
			return
		callback.call()
	)
	return b

func column(parent: Node, gap: int = 14) -> VBoxContainer:
	var c = VBoxContainer.new()
	c.add_theme_constant_override("separation", gap)
	parent.add_child(c)
	return c

func card(parent: Node) -> VBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box())
	parent.add_child(p)
	return column(p)

func grid(parent: Node, landscape_columns: int = 2) -> GridContainer:
	var g = GridContainer.new()
	g.columns = landscape_columns if size.x > size.y else 1
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 18)
	parent.add_child(g)
	responsive_grids.append({"node": g, "wide": landscape_columns})
	return g

func base(next_page: String, title: String, subtitle: String) -> void:
	page = next_page
	arena = null
	pause_overlay = null
	responsive_grids.clear()
	menu_scroll = null
	swipe_index = -1
	swipe_dragging = false
	swipe_velocity = 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var bg = ColorRect.new()
	var rainbow_material = ShaderMaterial.new()
	rainbow_material.shader = Rainbow
	bg.material = rainbow_material
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	outer = MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)
	var scroll = ScrollContainer.new()
	menu_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	content = column(scroll, 12 if next_page == "results" else 22)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	content.add_child(top)
	var brand = label("●  4 PLAYERS GAME OFFLINE", 19, INK)
	top.add_child(brand)
	var wallet_badge = PanelContainer.new()
	wallet_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wallet_style = box(Color("30223d"), 16)
	wallet_style.set_border_width_all(2)
	wallet_style.border_color = Color("d6a43d")
	wallet_style.content_margin_left = 16
	wallet_style.content_margin_right = 16
	wallet_style.content_margin_top = 6
	wallet_style.content_margin_bottom = 6
	wallet_badge.add_theme_stylebox_override("panel", wallet_style)
	var wallet = label("●  %d GOLD" % Party.coins, 30, Color("ffd15c"))
	wallet.autowrap_mode = TextServer.AUTOWRAP_OFF
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_badge.add_child(wallet)
	top.add_child(wallet_badge)
	if next_page not in ["home", "results"]:
		content.add_child(button("‹  Back", back))
	content.add_child(label(title, 34 if next_page == "results" else 48, INK))
	content.add_child(label(subtitle, 21, SHELL_MUTED))
	reflow()
	content.modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(content, "modulate:a", 1.0, 0.28)

func reflow() -> void:
	if not is_instance_valid(outer):
		return
	var margin: int = 12 if page in ["game", "results"] else 28 if size.x < 1000 else 48
	var inset = Vector4i(margin, margin, margin, margin)
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var window = DisplayServer.window_get_size()
		var scale_factor: float = size.x / maxf(1, window.x)
		inset.x = maxi(margin, int(safe.position.x * scale_factor))
		inset.y = maxi(margin, int(safe.position.y * scale_factor))
		inset.z = maxi(margin, int((window.x - safe.end.x) * scale_factor))
		inset.w = maxi(margin, int((window.y - safe.end.y) * scale_factor))
	outer.add_theme_constant_override("margin_left", inset.x)
	outer.add_theme_constant_override("margin_top", inset.y)
	outer.add_theme_constant_override("margin_right", inset.z)
	outer.add_theme_constant_override("margin_bottom", inset.w)
	for entry in responsive_grids:
		if is_instance_valid(entry.node):
			entry.node.columns = entry.wide if size.x > size.y else int(entry.get("portrait", 1))

func avatar(parent: Node, id: int, skin: String, height: float = 100) -> Control:
	var a = Avatar.new()
	a.tint = Party.COLORS[id]
	a.skin = skin
	a.custom_minimum_size = Vector2(100, height)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.animate = true
	parent.add_child(a)
	return a

func show_home() -> void:
	base("home", "Small games.\nBig rivalries.", "Your people. One screen. No internet needed.")
	# Keep the introduction beside the actions in landscape, stacked in portrait.
	var heading = content.get_child(1)
	var subtitle = content.get_child(2)
	content.remove_child(heading)
	content.remove_child(subtitle)
	var home_grid = grid(content, 2)
	var intro = column(home_grid, 18)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(heading)
	intro.add_child(subtitle)
	var hero = card(intro)
	var pals = HBoxContainer.new()
	hero.add_child(pals)
	for i in range(4):
		var pal = avatar(pals, i, Party.equipped[i], 135)
		pal.custom_minimum_size.x = 70
	hero.add_child(label("THE WHOLE CREW IS INVITED", 18, PURPLE))
	hero.add_child(label("1–4 players · friends & bots", 28))
	hero.add_child(label("Quick rounds, friendly competition, and a little gold for the winner.", 21, MUTED))
	var actions = column(home_grid, 18)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(button("Let's play   →", func(): cup_mode = false; show_setup(), PURPLE))
	actions.add_child(button("Build a tournament", func(): cup_mode = true; show_setup()))
	actions.add_child(button("Player skins", show_shop))
	actions.add_child(button("Settings & how to play", show_settings))
	actions.add_child(label("OFFLINE BY DESIGN · NO ADS · NO ACCOUNTS", 16, SHELL_MUTED))

func show_library() -> void:
	base("library", "Pick & play.", "Tap a preview to play. Or collect games for your own tournament.")
	var roster_line = HBoxContainer.new()
	roster_line.add_theme_constant_override("separation", 8)
	content.add_child(roster_line)
	for p in Party.players():
		var seat = column(roster_line, 0)
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avatar(seat, p.id, p.skin, 56)
		var l = label("P%d%s" % [p.id + 1, " · BOT" if p.bot else ""], 16, p.color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seat.add_child(l)
	var mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	content.add_child(mode_row)
	mode_row.add_child(button("Quick play", func(): cup_mode = false; show_library(), PURPLE if not cup_mode else PANEL))
	mode_row.add_child(button("Build tournament", func(): cup_mode = true; show_library(), PURPLE if cup_mode else PANEL))
	var games = grid(content, 4)
	games.columns = 4 if size.x > size.y else 2
	responsive_grids.back().portrait = 2
	for entry in Catalog.GAMES:
		game_preview(games, entry)
	if cup_mode:
		content.add_child(label("%d games selected · tap previews to add or remove" % cup_selection.size(), 20, INK))
		if not cup_selection.is_empty():
			var titles = PackedStringArray()
			for id in cup_selection:
				titles.append(Catalog.entry(id).title)
			content.add_child(label(" → ".join(titles), 18, SHELL_MUTED))
		var start = button("Start tournament   →", start_selected_cup, PURPLE)
		start.disabled = cup_selection.size() < 2
		content.add_child(start)
	else:
		content.add_child(label("YOUR CREW IS READY · TAP ANY GAME TO START", 16, SHELL_MUTED))

func game_preview(parent: Node, entry: Dictionary) -> void:
	var chosen: bool = cup_selection.has(entry.id) and cup_mode
	var tile = button("", func():
		if cup_mode:
			if cup_selection.has(entry.id):
				cup_selection.erase(entry.id)
			else:
				cup_selection.append(entry.id)
			show_library()
		else:
			current_game = entry.id
			Party.start_session(current_game, false)
			launch_round()
	, entry.color.darkened(0.58))
	var frame = box(entry.color.darkened(0.58), 20)
	frame.set_border_width_all(4 if chosen else 2)
	frame.border_color = Color("ffd577") if chosen else Color(1, 1, 1, 0.8)
	tile.add_theme_stylebox_override("normal", frame)
	tile.set_meta("game_id", entry.id)
	tile.custom_minimum_size = Vector2(0, 205)
	parent.add_child(tile)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	tile.add_child(margin)
	var c = column(margin, 5)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art = GameArt.new()
	art.game_id = entry.id
	art.custom_minimum_size.y = 115
	c.add_child(art)
	var title = label(entry.title, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(title)
	var detail = label("%d · selected" % (cup_selection.find(entry.id) + 1) if chosen else entry.tag.split("/")[1].strip_edges(), 15, Color("ffd577") if chosen else Color("e0e9f6"))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(detail)

func start_selected_cup() -> void:
	if cup_selection.size() < 2 or not Party.valid_setup():
		return
	current_game = cup_selection[0]
	Party.start_session(current_game, true)
	Party.schedule = cup_selection.duplicate()
	launch_round()

func show_setup() -> void:
	base("setup", "Who's in?", "Set each seat to Human, Bot, or Off. At least one human must join.")
	var seats = grid(content, 2)
	# Portrait uses two compact seat columns as well.
	responsive_grids.back().wide = 2
	seats.columns = 2
	responsive_grids.pop_back()
	seat_choice_buttons.clear()
	for i in range(4):
		var c = card(seats)
		c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avatar(c, i, Party.equipped[i], 90)
		c.add_child(label("Player %d" % (i + 1), 24, Party.COLORS[i]))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		c.add_child(row)
		var group = ButtonGroup.new()
		group.allow_unpress = false
		for mode in ["Human", "Bot", "Off"]:
			var choice = button(mode, func(): choose_seat_mode(i, mode))
			choice.set_meta("seat_id", i)
			choice.set_meta("seat_mode", mode)
			choice.toggle_mode = true
			choice.button_group = group
			choice.custom_minimum_size = Vector2(0, 52)
			choice.add_theme_font_size_override("font_size", 18)
			var idle = box(Color("26324a"), 12)
			idle.set_border_width_all(1)
			idle.border_color = Color("63718c")
			idle.content_margin_left = 8
			idle.content_margin_right = 8
			idle.content_margin_top = 12
			idle.content_margin_bottom = 12
			var selected = idle.duplicate()
			selected.bg_color = Party.COLORS[i]
			selected.border_color = Color.WHITE
			selected.set_border_width_all(2)
			choice.add_theme_stylebox_override("normal", idle)
			choice.add_theme_stylebox_override("hover", idle)
			choice.add_theme_stylebox_override("pressed", selected)
			choice.add_theme_stylebox_override("hover_pressed", selected)
			choice.add_theme_color_override("font_pressed_color", INK)
			choice.add_theme_color_override("font_hover_pressed_color", INK)
			choice.set_pressed_no_signal(Party.slots[i] == mode)
			row.add_child(choice)
			seat_choice_buttons.append(choice)
	seat_summary = label("%d active seats · %d humans" % [Party.players().size(), Party.slots.count("Human")], 22, INK)
	content.add_child(seat_summary)
	seat_continue = button("Choose your games   →", show_library, PURPLE)
	seat_continue.disabled = not Party.valid_setup()
	content.add_child(seat_continue)
	content.add_child(label("Pair Peek: tap two cards per turn. Keyboard: arrows + Space. Other games: tap your own pad, or use P1 A · P2 L · P3 Z · P4 M.", 18, SHELL_MUTED))

func choose_seat_mode(seat_id: int, mode: String) -> void:
	Party.slots[seat_id] = mode
	for choice in seat_choice_buttons:
		if choice.get_meta("seat_id") == seat_id:
			choice.set_pressed_no_signal(choice.get_meta("seat_mode") == mode)
	seat_summary.text = "%d active seats · %d humans" % [Party.players().size(), Party.slots.count("Human")]
	seat_continue.disabled = not Party.valid_setup()

func launch_round() -> void:
	current_game = Party.schedule[Party.round_index]
	base("game", Catalog.entry(current_game).title, "Round %d / %d  ·  %s" % [Party.round_index + 1, Party.schedule.size(), "Take turns · tap two cards" if current_game == "pairs" else "Tap your own color"])
	# Games use all remaining height without a scrolling playfield.
	var scroll = content.get_parent()
	scroll.remove_child(content)
	outer.remove_child(scroll)
	scroll.queue_free()
	outer.add_child(content)
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	content.add_theme_constant_override("separation", 0)
	arena = Catalog.entry(current_game).script.new()
	arena.game_id = current_game
	arena.roster = Party.players()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.custom_minimum_size.y = 300
	arena.finished.connect(round_finished)
	content.add_child(arena)
	var pause_button = button("Ⅱ", toggle_pause)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var compact = pause_button.get_theme_stylebox(state).duplicate()
		compact.content_margin_left = 4
		compact.content_margin_right = 4
		compact.content_margin_top = 4
		compact.content_margin_bottom = 4
		pause_button.add_theme_stylebox_override(state, compact)
	pause_button.custom_minimum_size = Vector2(48, 42)
	pause_button.size = Vector2(48, 42)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pause_button.position = Vector2(arena.size.x / 2 + 113, 8)
	arena.add_child(pause_button)
	arena.resized.connect(func(): pause_button.position = Vector2(arena.size.x / 2 + 113, 8))

func toggle_pause() -> void:
	if not is_instance_valid(arena):
		return
	arena.paused = not arena.paused
	if not arena.paused:
		if is_instance_valid(pause_overlay):
			pause_overlay.queue_free()
		return
	pause_overlay = PanelContainer.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_theme_stylebox_override("panel", box(Color(0.035, 0.047, 0.09, 0.98)))
	add_child(pause_overlay)
	var center = CenterContainer.new()
	pause_overlay.add_child(center)
	var c = column(center, 24)
	c.custom_minimum_size.x = 360
	c.add_child(label("Take a breather.", 38))
	c.add_child(button("Resume game", toggle_pause, PURPLE))
	c.add_child(button("Leave match", show_home))

func round_finished(scores: Dictionary) -> void:
	last_scores = scores
	var no_winner: bool = false
	if is_instance_valid(arena):
		if current_game == "obby":
			no_winner = arena.living_ids().is_empty()
		elif current_game == "dance":
			no_winner = not arena.has_winner()
	last_winners = Party.record_round(scores, not no_winner)
	cup_done = false
	call_deferred("show_results")

func winner_names(ids: Array) -> String:
	var names = PackedStringArray()
	for id in ids:
		names.append("Player %d%s" % [id + 1, " (bot)" if Party.slots[id] == "Bot" else ""])
	return " & ".join(names)

func show_results() -> void:
	if cup_done:
		show_cup_ceremony()
		return
	base("results", "Cup champions!" if cup_done else "Round over!" if last_winners.is_empty() else "That's a wrap!", ("Try repeating every dance move in order!" if current_game == "dance" else "Everyone is out. Try jumping or ducking earlier!") if last_winners.is_empty() else winner_names(last_winners) + (" share the win." if last_winners.size() > 1 else " takes the win."))
	var panels = grid(content, 2)
	var summary = card(panels)
	summary.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var winners = HBoxContainer.new()
	summary.add_child(winners)
	for id in last_winners:
		avatar(winners, id, Party.equipped[id], 64)
	summary.add_child(label("+%d gold" % Party.last_reward, 28, Color("ffd577")))
	summary.add_child(label("Shared wallet · bot wins earn no gold", 16, MUTED))
	var c = card(panels)
	c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 8)
	var ids = last_scores.keys() if not cup_done else Party.standings.keys()
	var values = last_scores if not cup_done else Party.standings
	ids.sort_custom(func(a, b): return values[a] > values[b])
	if Party.tournament:
		c.add_child(label("ROUND %d / %d · TOURNAMENT POINTS" % [Party.round_index + 1, Party.schedule.size()], 18, Color("ffd577")))
	for id in ids:
		c.add_child(label("Player %d%s     %d %s" % [id + 1, " · BOT" if Party.slots[id] == "Bot" else "", values[id], Catalog.entry(current_game).unit], 21, Party.COLORS[id]))
		if Party.tournament:
			c.add_child(label("+%d points   ·   %d total" % [Party.round_points.get(id, 0), Party.standings.get(id, 0)], 18, Color("ffd577")))
	var actions = grid(content, 2)
	if Party.tournament and not cup_done:
		actions.add_child(button("Next round   →" if Party.round_index < Party.schedule.size() - 1 else "Award the cups   →", next_round, PURPLE))
	else:
		actions.add_child(button("Play again   ↻", func(): Party.start_session(current_game, Party.tournament); launch_round(), PURPLE))
	actions.add_child(button("More games", show_library))
	if Party.save_error:
		content.add_child(label("Progress could not be saved on this device.", 18, Color("ffb276")))

func show_cup_ceremony() -> void:
	base("results", "Tournament champions!" if last_winners.size() > 1 else "Tournament champion!", winner_names(last_winners) + (" share first place!" if last_winners.size() > 1 else " takes the cup!"))
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ceremony = Ceremony.new()
	ceremony.name = "TournamentCeremony"
	ceremony.roster = Party.players()
	ceremony.winners = last_winners.duplicate()
	ceremony.totals = Party.standings.duplicate()
	ceremony.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ceremony.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(ceremony)
	var ranked: Array = Party.standings.keys()
	ranked.sort_custom(func(a, b): return Party.standings[a] > Party.standings[b])
	var table = grid(content, mini(4, ranked.size()))
	responsive_grids.back().portrait = mini(2, ranked.size())
	table.columns = mini(4, ranked.size()) if size.x > size.y else mini(2, ranked.size())
	for id in ranked:
		var cell = card(table)
		cell.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		var compact = box(Color("302942") if last_winners.has(id) else PANEL, 14)
		compact.content_margin_top = 8
		compact.content_margin_bottom = 8
		compact.content_margin_left = 12
		compact.content_margin_right = 12
		cell.get_parent().add_theme_stylebox_override("panel", compact)
		cell.add_child(label("P%d%s%s" % [id + 1, " BOT" if Party.slots[id] == "Bot" else "", " · WINNER" if last_winners.has(id) else ""], 17, Party.COLORS[id]))
		cell.add_child(label("%d points" % Party.standings[id], 22, Color("ffd577") if last_winners.has(id) else Color.WHITE))
	var actions = grid(content, 2)
	actions.add_child(button("New tournament   →", func(): cup_mode = true; show_library(), PURPLE))
	actions.add_child(button("More games", show_library))
	content.add_child(label("+%d gold · tournament bonus" % Party.last_reward, 18, INK))
	if Party.save_error:
		content.add_child(label("Progress could not be saved on this device.", 18, Color("ffb276")))

func standings_text() -> String:
	var result = PackedStringArray()
	for id in Party.standings:
		result.append("P%d: %d" % [id + 1, Party.standings[id]])
	return " · ".join(result)

func next_round() -> void:
	if Party.round_index < Party.schedule.size() - 1:
		Party.round_index += 1
		launch_round()
	else:
		last_winners = Party.finish_cup()
		cup_done = true
		show_results()

func show_shop(message: String = "") -> void:
	var saved_scroll: int = menu_scroll.scroll_vertical if page == "shop" and is_instance_valid(menu_scroll) else 0
	base("shop", "Dress for the party.", "Win rounds to collect gold. Pick a player, then equip a look.")
	var picker = HBoxContainer.new()
	content.add_child(picker)
	for i in range(4):
		picker.add_child(button("P%d" % (i + 1), func(): selected_player = i; show_shop(), PURPLE if i == selected_player else PANEL))
	if message != "":
		content.add_child(label(message, 20, Color("ffd577")))
	var skins = grid(content, 3)
	responsive_grids.back().portrait = 2
	skins.columns = 3 if size.x > size.y else 2
	for skin in Party.SKINS:
		var c = card(skins)
		c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		avatar(c, selected_player, skin.id, 120)
		c.add_child(label(skin.name, 25))
		var owned: bool = Party.owned.has(skin.id)
		var active: bool = Party.equipped[selected_player] == skin.id
		c.add_child(label("Owned" if owned else "%d gold" % skin.price, 20, Color("ffd577")))
		var b = button("Equipped" if active else "Equip" if owned else "Unlock", func():
			if Party.owned.has(skin.id):
				Party.equipped[selected_player] = skin.id
				Party.save_progress()
				show_shop()
			elif Party.buy_skin(skin.id):
				show_shop("Unlocked! Tap Equip to wear your new look.")
			else:
				show_shop("Keep playing — you need %d more gold." % (skin.price - Party.coins))
		, PURPLE if owned else PANEL)
		b.disabled = active
		c.add_child(b)

	call_deferred("restore_shop_scroll", saved_scroll)

func restore_shop_scroll(value: int) -> void:
	await get_tree().process_frame
	if page == "shop" and is_instance_valid(menu_scroll):
		menu_scroll.scroll_vertical = value
		swipe_offset = value

func show_settings() -> void:
	base("settings", "Make it your party.", "A few simple rules, then you're ready.")
	var c = card(content)
	c.add_child(label("Bot difficulty", 28))
	var pick = OptionButton.new()
	pick.custom_minimum_size.y = 64
	for text in ["Easy · relaxed", "Normal · competitive", "Hard · quick reflexes"]:
		pick.add_item(text)
	pick.select(Party.difficulty)
	pick.item_selected.connect(func(index): Party.difficulty = index; Party.save_progress())
	c.add_child(pick)
	c.add_child(label("Audio", 28))
	c.add_child(button("Music: " + ("on" if Party.music_enabled else "off"), func(): Music.set_enabled(not Party.music_enabled); show_settings(), PURPLE if Party.music_enabled else PANEL))
	c.add_child(label("Relaxed music · loops offline", 18, MUTED))
	c.add_child(button("Sound effects: " + ("on" if Party.sound else "off"), func(): Party.sound = not Party.sound; Party.save_progress(); show_settings(), PURPLE if Party.sound else PANEL))
	var rules = card(content)
	rules.add_child(label("How it works", 28, PURPLE))
	rules.add_child(label("• Choose any mix of 1–4 active seats, with at least one human. Solo humans can play without bots.\n\n• Each player taps their colored pad. Pair Peek shares a board: flip two cards, then pass the turn. A match earns one pair. Phones support simultaneous touches. Rotate whenever you like.\n\n• Round winners earn 15 gold each. Cup champions earn a bonus 40 gold. Ties share the win.\n\n• Build a tournament by selecting 2–8 previews. Games run in the order you pick them. Cup points: 10 × (active players − players with a higher score). Highest total wins.\n\n• Skins, gold, sound, and difficulty save locally. No network, account, or purchases required.", 21, MUTED))
	content.add_child(button("Privacy policy", show_privacy))
	content.add_child(label("4 PLAYERS GAME OFFLINE  /  PROTOTYPE 0.2", 16, SHELL_MUTED))

func show_privacy() -> void:
	base("privacy", "Privacy policy", "4 Players Game Offline · FrutyLabs")
	var policy = FileAccess.get_file_as_string("res://PRIVACY_POLICY.md")
	var body = card(content)
	body.add_child(label(policy.replace("**", "").replace("`", "").replace("## ", "").replace("# ", ""), 20, Color.WHITE))
	content.add_child(button("Open policy online", func(): OS.shell_open("https://raw.githubusercontent.com/ed-fruty/pocketparty/main/PRIVACY_POLICY.md")))
	content.add_child(button("Contact support", func(): OS.shell_open("mailto:ed.fruty@gmail.com")))
