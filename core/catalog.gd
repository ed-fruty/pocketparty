extends RefCounted
const GAMES = [
	{"id": "sprint", "title": "Star Sprint", "tag": "01 / SPEED", "description": "Tap your color. First to 80 steps, or most steps after 18 seconds, wins.", "meta": "18 seconds · simultaneous", "color": Color("6ce5bc"), "script": preload("res://games/arena.gd"), "unit": "steps"},
	{"id": "signal", "title": "Signal Snap", "tag": "02 / REFLEX", "description": "Wait for green, then tap! Jump the signal and lose 100 points.", "meta": "5 signals · simultaneous", "color": Color("b3a0ff"), "script": preload("res://games/arena.gd"), "unit": "pts"},
	{"id": "pairs", "title": "Pair Peek", "tag": "03 / MEMORY", "description": "Turn over two cards. Find a matching pair! Take turns; most pairs wins.", "meta": "8 pairs · take turns", "color": Color("73c9ff"), "script": preload("res://games/pair_peek.gd"), "unit": "pairs"},
	{"id": "burger", "title": "BurgerTower", "tag": "04 / BALANCE", "description": "Drop buns and toppings onto your plate. Build the tallest standing burger before time runs out!", "meta": "30 seconds + settling · physics", "color": Color("ffb276"), "script": preload("res://games/burger_tower.gd"), "unit": "cm"},
	{"id": "darkspots", "title": "Darkspots", "tag": "05 / TIMING", "description": "Tap when the spinning circle enters the gold range. Each hit earns 5 points and moves the range, giving it a different length. Most points in 20 seconds wins.", "meta": "20 seconds · simultaneous", "color": Color("f6d36f"), "script": preload("res://games/darkspots.gd"), "unit": "pts"},
	{"id": "obby", "title": "Obby Run", "tag": "06 / SURVIVAL", "description": "Run automatically! Jump over orange blocks and duck under gold bars. Hit an obstacle and you are out. Last runner standing wins.", "meta": "35 seconds · jump + duck", "color": Color("ff8fb8"), "script": preload("res://games/obby_run.gd"), "unit": "m"},
	{"id": "snake", "title": "Snake Clash", "tag": "07 / FEAST", "description": "Drag to steer your colored snake. Eat pizza to grow, then eat smaller snakes! Become the biggest snake to start a 10-second hunt. A new biggest snake restarts the timer!", "meta": "Grow first · 10-second leader hunt", "color": Color("a1df78"), "script": preload("res://games/snake_clash.gd"), "unit": "length"},
	{"id": "dance", "title": "Let's Dance!", "tag": "08 / COPYCAT", "description": "One chosen player creates five moves. Watch the dance, then everyone else repeats every move in order. Perfect copies win; the leader wins if nobody can copy it!", "meta": "One leader · copy every move", "color": Color("f7a4d2"), "script": preload("res://games/lets_dance.gd"), "unit": "moves"},
]
static func entry(id: String) -> Dictionary:
	for game in GAMES:
		if game.id == id:
			return game
	return GAMES[0]
