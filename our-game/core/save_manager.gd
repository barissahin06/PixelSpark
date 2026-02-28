extends Node

## SaveManager — handles saving and loading game state to user://save.json

const SAVE_PATH := "user://save.json"

func save_game() -> bool:
	var save_data := {
		"version": 1,
		"current_day": GameManager.current_day,
		"gold": GameManager.gold,
		"food": GameManager.food,
		"days_to_next_battle": GameManager.days_to_next_battle,
		"last_market_refresh_day": GameManager.last_market_refresh_day,
		"slave_market": GameManager.slave_market.duplicate(true),
		"roster": _serialize_roster(),
		"upgrades": _serialize_upgrades(),
	}
	
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Cannot open save file for writing!")
		return false
	
	file.store_string(json_string)
	file.close()
	print("Game saved to %s" % SAVE_PATH)
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_error("SaveManager: No save file found!")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Cannot open save file for reading!")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		push_error("SaveManager: Failed to parse save file!")
		return false
	
	var data = json.data
	if data is not Dictionary:
		push_error("SaveManager: Save data is not a Dictionary!")
		return false
	
	# Restore state
	GameManager.current_day = int(data.get("current_day", 1))
	GameManager.gold = int(data.get("gold", 100))
	GameManager.food = int(data.get("food", 50))
	GameManager.days_to_next_battle = int(data.get("days_to_next_battle", 5))
	GameManager.last_market_refresh_day = int(data.get("last_market_refresh_day", 0))
	GameManager.slave_market = data.get("slave_market", [])
	
	# Restore roster
	GameManager.roster.clear()
	var roster_data = data.get("roster", [])
	for glad_data in roster_data:
		if glad_data is Dictionary:
			var glad = _deserialize_gladiator(glad_data)
			GameManager.roster.append(glad)
	
	# Restore upgrades
	var upgrade_data = data.get("upgrades", {})
	if upgrade_data is Dictionary:
		_deserialize_upgrades(upgrade_data)
	
	print("Game loaded from %s" % SAVE_PATH)
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# --- Serialization Helpers ---

func _serialize_roster() -> Array:
	var result := []
	for g in GameManager.roster:
		result.append({
			"g_name": g.g_name,
			"type": g.type,
			"level": g.level,
			"max_hp": g.max_hp,
			"current_hp": g.current_hp,
			"max_stamina": g.max_stamina,
			"current_stamina": g.current_stamina,
			"attack_damage": g.attack_damage,
			"dodge_chance": g.dodge_chance,
			"traits": g.traits.duplicate(),
			"is_active": g.is_active,
			"hunger": g.hunger,
			"current_action": g.current_action,
			"action_duration_left": g.action_duration_left,
			"training_target": g.training_target,
		})
	return result

func _deserialize_gladiator(data: Dictionary) -> Gladiator:
	var g = Gladiator.new()
	g.g_name = str(data.get("g_name", "Unknown"))
	g.type = str(data.get("type", "Slave"))
	g.level = int(data.get("level", 1))
	g.max_hp = int(data.get("max_hp", 100))
	g.current_hp = int(data.get("current_hp", 100))
	g.max_stamina = int(data.get("max_stamina", 10))
	g.current_stamina = int(data.get("current_stamina", 10))
	g.attack_damage = int(data.get("attack_damage", 10))
	g.dodge_chance = float(data.get("dodge_chance", 5.0))
	g.is_active = bool(data.get("is_active", true))
	g.hunger = int(data.get("hunger", 100))
	g.current_action = str(data.get("current_action", "idle"))
	g.action_duration_left = int(data.get("action_duration_left", 0))
	g.training_target = str(data.get("training_target", ""))
	
	var traits = data.get("traits", [])
	for t in traits:
		g.traits.append(str(t))
	
	return g

func _serialize_upgrades() -> Dictionary:
	var lu = GameManager.ludus_upgrades
	if lu == null:
		return {}
	return {
		"built_upgrades": lu.built_upgrades.duplicate(),
		"building_upgrade": lu.building_upgrade,
		"build_days_left": lu.build_days_left,
	}

func _deserialize_upgrades(data: Dictionary) -> void:
	var lu = GameManager.ludus_upgrades
	if lu == null:
		GameManager.ludus_upgrades = LudusUpgrades.new()
		lu = GameManager.ludus_upgrades
	
	lu.built_upgrades.clear()
	var built = data.get("built_upgrades", [])
	for u in built:
		lu.built_upgrades.append(str(u))
	lu.building_upgrade = str(data.get("building_upgrade", ""))
	lu.build_days_left = int(data.get("build_days_left", 0))
