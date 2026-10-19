extends Node

const COLORS = [Color("b3a0ff"), Color("6ce5bc"), Color("ffb276"), Color("73c9ff")]
const SKINS = [
	{"id": "classic", "name": "Party pals", "price": 0},
	{"id": "cat", "name": "Space cats", "price": 60},
	{"id": "robot", "name": "Tiny robots", "price": 90},
	{"id": "royal", "name": "Royal crew", "price": 120},
	{"id": "ninja", "name": "Night ninjas", "price": 150},
	{"id": "alien", "name": "Moon visitors", "price": 180},
	{"id": "rabbit", "name": "Rabbit", "price": 30},
	{"id": "koala", "name": "Koala", "price": 45},
	{"id": "panda", "name": "Panda", "price": 60},
	{"id": "capybara", "name": "Capybara", "price": 75},
]
const SAVE_PATH = "user://party_save.json"
var save_path: String = SAVE_PATH
var coins: int = 0
var owned: Array = ["classic"]
var equipped: Array = ["classic", "classic", "classic", "classic"]
var slots: Array = ["Human", "Bot", "Off", "Off"]
var difficulty: int = 1
var sound: bool = true
var music_enabled: bool = true
var tournament: bool = false
var round_index: int = 0
var standings: Dictionary = {}
var round_points: Dictionary = {}
var schedule: Array = []
var awarded_rounds: Dictionary = {}
var cup_awarded: bool = false
var cup_winners: Array = []
var last_reward: int = 0
var save_error: bool = false

func _ready() -> void:
	# Keep the development laptop profile inside this project; Android uses user://.
	if OS.has_feature("editor"):
		save_path = "res://builds/laptop_party_save.json"
	load_progress()

func players() -> Array:
	var result: Array = []
	for i in range(4):
		if slots[i] != "Off":
			result.append({"id": i, "name": "Player %d" % (i + 1), "bot": slots[i] == "Bot", "skin": NetPlay.skins[i] if NetPlay.active else equipped[i], "color": COLORS[i]})
	return result

func valid_setup() -> bool:
	return slots.has("Human") and players().size() >= 1

func start_session(game_id: String, cup: bool) -> void:
	tournament = cup
	round_index = 0
	standings.clear()
	round_points.clear()
	awarded_rounds.clear()
	cup_awarded = false
	cup_winners.clear()
	for p in players():
		standings[p.id] = 0
	schedule = [game_id]
	if cup:
		var others: Array = ["sprint", "signal", "pairs", "burger", "darkspots", "obby", "snake", "dance"]
		others.erase(game_id)
		others.shuffle()
		schedule.append(others[0])
		schedule.append(others[1])
	last_reward = 0

func record_round(scores: Dictionary, award_win: bool = true) -> Array:
	if awarded_rounds.has(round_index):
		return awarded_rounds[round_index]
	round_points.clear()
	var ids: Array = scores.keys()
	ids.sort_custom(func(a, b): return scores[a] > scores[b])
	if ids.is_empty():
		return []
	var winners: Array = []
	for id in ids:
		if scores[id] == scores[ids[0]]:
			winners.append(id)
		var higher: int = 0
		for other in ids:
			if scores[other] > scores[id]:
				higher += 1
		round_points[id] = (ids.size() - higher) * 10
		standings[id] = int(standings.get(id, 0)) + round_points[id]
	if not award_win:
		winners.clear()
	last_reward = 0
	for id in winners:
		if slots[id] == "Human" and (not NetPlay.active or id == NetPlay.local_id):
			last_reward += 15
	coins += last_reward
	awarded_rounds[round_index] = winners
	save_progress()
	return winners

func finish_cup() -> Array:
	if cup_awarded:
		return cup_winners
	var best: int = -1
	var winners: Array = []
	for id in standings:
		if standings[id] > best:
			best = standings[id]
			winners = [id]
		elif standings[id] == best:
			winners.append(id)
	last_reward = 0
	for id in winners:
		if slots[id] == "Human" and (not NetPlay.active or id == NetPlay.local_id):
			last_reward += 40
	coins += last_reward
	cup_awarded = true
	cup_winners = winners
	save_progress()
	return winners

func buy_skin(id: String) -> bool:
	for skin in SKINS:
		if skin.id == id and not owned.has(id) and coins >= skin.price:
			coins -= skin.price
			owned.append(id)
			save_progress()
			return true
	return false

func save_progress() -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	save_error = file == null
	if file:
		file.store_string(JSON.stringify({"version": 1, "coins": coins, "owned": owned, "equipped": equipped, "difficulty": NetPlay.saved_difficulty if NetPlay.active else difficulty, "sound": sound, "music": music_enabled}))

func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK:
		return
	var value = parser.data
	if not value is Dictionary:
		return
	coins = maxi(0, int(value.get("coins", 0)))
	owned = ["classic"]
	for skin in SKINS:
		if value.get("owned", []) is Array and value.get("owned", []).has(skin.id) and not owned.has(skin.id):
			owned.append(skin.id)
	var saved = value.get("equipped", [])
	if saved is Array and saved.size() == 4:
		for i in range(4):
			equipped[i] = saved[i] if owned.has(saved[i]) else "classic"
	difficulty = clampi(int(value.get("difficulty", 1)), 0, 2)
	sound = bool(value.get("sound", true))
	music_enabled = bool(value.get("music", sound))
