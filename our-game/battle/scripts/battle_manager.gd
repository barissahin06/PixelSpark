class_name BattleManager
extends RefCounted

## Manages multi-gladiator battles (up to 3v3).
## Uses a card-based turn system with stat-scaled cards and type-specific decks.
## Player selects active gladiator and target enemy before playing cards.

signal battle_started
signal turn_started(is_player_turn: bool)
signal card_played(card: CardModel, is_player: bool)
signal damage_dealt(target: String, amount: int, blocked: int)
signal battle_ended(player_won: bool, reward_gold: int)
signal animation_requested(anim_type: String, target: String)
signal gladiator_defeated(side: String, index: int)

# --- Multi-Gladiator State ---
var player_gladiators: Array[Gladiator] = [] # Up to 3
var enemies: Array[Dictionary] = [] # Each: {name, hp, max_hp, attack, dodge, type, block}

var selected_player_index: int = 0 # Currently active player gladiator
var selected_enemy_index: int = 0 # Currently targeted enemy

var player_blocks: Array[int] = [] # Per-gladiator block

var deck: Array[CardModel] = []
var hand: Array[CardModel] = []
var discard: Array[CardModel] = []

var max_hand_size: int = 5
var energy: int = 3
var max_energy: int = 3

var is_player_turn: bool = true
var battle_active: bool = false
var turn_count: int = 0

# Debuffs (per enemy)
var enemy_attack_debuffs: Array[int] = []

# Type-specific scaling coefficients
const TYPE_COEFFICIENTS := {
	"Murmillo": {"attack_mult": 1.0, "block_mult": 1.4, "energy_bonus": 0},
	"Thraex": {"attack_mult": 1.2, "block_mult": 1.0, "energy_bonus": 0},
	"Retiarius": {"attack_mult": 1.3, "block_mult": 0.8, "energy_bonus": 0},
	"Slave": {"attack_mult": 0.7, "block_mult": 0.7, "energy_bonus": 0},
}

# --- Setup ---

func start_battle(gladiators: Array[Gladiator], enemy_list: Array[Dictionary]) -> void:
	player_gladiators = gladiators
	enemies = enemy_list
	
	# Initialize per-gladiator/enemy state
	player_blocks.clear()
	enemy_attack_debuffs.clear()
	for i in range(player_gladiators.size()):
		player_blocks.append(0)
	for i in range(enemies.size()):
		enemy_attack_debuffs.append(0)
	
	selected_player_index = 0
	selected_enemy_index = 0
	
	battle_active = true
	is_player_turn = true
	turn_count = 0
	
	_build_deck()
	_shuffle_deck()
	_start_player_turn()
	
	battle_started.emit()

func _build_deck() -> void:
	deck.clear()
	hand.clear()
	discard.clear()
	
	# Build deck from primary gladiator (first selected)
	var gladiator_type = player_gladiators[0].type if player_gladiators.size() > 0 else ""
	
	for card_data in GameData.cards:
		var card_tags = card_data.tags if card_data.tags else []
		
		var copies = 2
		
		var is_type_card = false
		if "murmillo" in card_tags:
			is_type_card = true
			copies = 3 if gladiator_type == "Murmillo" else 0
		elif "retiarius" in card_tags:
			is_type_card = true
			copies = 3 if gladiator_type == "Retiarius" else 0
		elif "thraex" in card_tags:
			is_type_card = true
			copies = 3 if gladiator_type == "Thraex" else 0
		
		if not is_type_card:
			if "defense" in card_tags and gladiator_type == "Murmillo":
				copies = 3
			elif "attack" in card_tags and "basic" in card_tags and gladiator_type == "Retiarius":
				copies = 3
		
		# More cards for multi-gladiator battles
		if player_gladiators.size() > 1:
			copies += 1
		
		for i in range(copies):
			var card = CardModel.new(card_data.id, card_data.card_name, card_data.cost)
			card.attack_power = card_data.attack_power
			card.health = card_data.health
			card.description = card_data.description
			card.tags = card_data.tags if card_data.tags else []
			deck.append(card)

func _shuffle_deck() -> void:
	deck.shuffle()

# --- Selection ---

func select_player(index: int) -> void:
	if index >= 0 and index < player_gladiators.size():
		if player_gladiators[index].is_active and player_gladiators[index].current_hp > 0:
			selected_player_index = index

func select_enemy(index: int) -> void:
	if index >= 0 and index < enemies.size():
		if enemies[index]["hp"] > 0:
			selected_enemy_index = index

# --- Turn Logic ---

func _start_player_turn() -> void:
	is_player_turn = true
	turn_count += 1
	energy = max_energy + (1 if player_gladiators.size() >= 3 else 0) # Bonus energy for 3 gladiators
	
	# Reset all player blocks
	for i in range(player_blocks.size()):
		player_blocks[i] = 0
	
	_draw_cards(max_hand_size - hand.size())
	turn_started.emit(true)

func _draw_cards(count: int) -> void:
	for i in range(count):
		if deck.is_empty():
			deck = discard.duplicate()
			discard.clear()
			_shuffle_deck()
		
		if not deck.is_empty():
			hand.append(deck.pop_back())

func can_play_card(index: int) -> bool:
	if not is_player_turn or not battle_active:
		return false
	if index < 0 or index >= hand.size():
		return false
	return hand[index].cost <= energy

func play_card(index: int) -> bool:
	if not can_play_card(index):
		return false
	
	var card = hand[index]
	energy -= card.cost
	hand.remove_at(index)
	
	var active_glad = get_selected_player()
	if not active_glad:
		return false
	
	var coeff = TYPE_COEFFICIENTS.get(active_glad.type, {"attack_mult": 1.0, "block_mult": 1.0, "energy_bonus": 0})
	
	# Apply card effects to selected enemy
	var actual_damage = 0
	if card.attack_power > 0:
		var scaled = card.scaled_attack(active_glad)
		scaled = int(scaled * coeff["attack_mult"])
		
		var trait_mult = TraitSystem.get_damage_modifier(active_glad)
		scaled = int(scaled * trait_mult)
		
		var pierce = card.has_tag("pierce")
		var enemy = enemies[selected_enemy_index]
		
		if randf() * 100.0 < enemy["dodge"]:
			actual_damage = 0
			animation_requested.emit("dodge", "enemy_%d" % selected_enemy_index)
		else:
			if pierce:
				var effective_block = int(enemy["block"] * 0.5)
				var blocked = mini(effective_block, scaled)
				enemy["block"] -= blocked
				actual_damage = scaled - blocked
			else:
				var blocked = mini(enemy["block"], scaled)
				enemy["block"] -= blocked
				actual_damage = scaled - blocked
			
			enemy["hp"] -= actual_damage
			animation_requested.emit("hit", "enemy_%d" % selected_enemy_index)
		
		damage_dealt.emit("enemy", actual_damage, 0)
	
	if card.health > 0:
		var scaled_blk = card.scaled_block(active_glad)
		scaled_blk = int(scaled_blk * coeff["block_mult"])
		player_blocks[selected_player_index] += scaled_blk
	
	# Special card effects
	if card.id == "card_rally":
		_draw_cards(1)
	
	if card.id == "card_crowd_roar" or card.has_tag("energy"):
		energy += 1
	
	if card.id == "card_net_toss" or card.has_tag("debuff"):
		enemy_attack_debuffs[selected_enemy_index] += 5
	
	card_played.emit(card, true)
	discard.append(card)
	
	# Check if targeted enemy is dead
	if enemies[selected_enemy_index]["hp"] <= 0:
		enemies[selected_enemy_index]["hp"] = 0
		gladiator_defeated.emit("enemy", selected_enemy_index)
		# Auto-select next alive enemy
		_auto_select_next_enemy()
	
	# Check win: all enemies dead
	if _all_enemies_dead():
		_end_battle(true)
		return true
	
	return true

func end_player_turn() -> void:
	if not is_player_turn or not battle_active:
		return
	
	is_player_turn = false
	turn_started.emit(false)
	
	_execute_enemy_turn()

func _execute_enemy_turn() -> void:
	# Reset all enemy blocks
	for i in range(enemies.size()):
		if enemies[i]["hp"] > 0:
			enemies[i]["block"] = 0
	
	# Each surviving enemy attacks
	for ei in range(enemies.size()):
		var enemy = enemies[ei]
		if enemy["hp"] <= 0:
			continue
		
		# Pick random alive player gladiator to attack
		var alive_players = []
		for pi in range(player_gladiators.size()):
			if player_gladiators[pi].is_active and player_gladiators[pi].current_hp > 0:
				alive_players.append(pi)
		
		if alive_players.is_empty():
			break
		
		var target_pi = alive_players[randi() % alive_players.size()]
		
		# Smart AI
		var hp_pct = float(enemy["hp"]) / float(enemy["max_hp"]) if enemy["max_hp"] > 0 else 1.0
		var roll = randf()
		
		var action = "attack"
		if hp_pct < 0.3 and roll < 0.4:
			action = "block"
		elif player_blocks[target_pi] > 10 and roll < 0.35:
			action = "power_attack"
		elif roll < 0.15:
			action = "double_strike"
		
		var debuff = enemy_attack_debuffs[ei]
		enemy_attack_debuffs[ei] = 0
		
		match action:
			"block":
				enemy["block"] += int(enemy["attack"] * 0.8)
				var light_dmg = int(enemy["attack"] * 0.4) + randi_range(-2, 2)
				light_dmg -= debuff
				light_dmg = maxi(light_dmg, 1)
				_apply_enemy_hit(ei, target_pi, light_dmg)
			
			"power_attack":
				var power_dmg = int(enemy["attack"] * 1.5) + randi_range(-2, 3)
				power_dmg -= debuff
				power_dmg = maxi(power_dmg, 2)
				player_blocks[target_pi] = int(player_blocks[target_pi] * 0.5)
				_apply_enemy_hit(ei, target_pi, power_dmg)
			
			"double_strike":
				var hit_dmg = int(enemy["attack"] * 0.6) + randi_range(-1, 2)
				hit_dmg -= debuff
				hit_dmg = maxi(hit_dmg, 1)
				_apply_enemy_hit(ei, target_pi, hit_dmg)
				if battle_active and player_gladiators[target_pi].current_hp > 0:
					_apply_enemy_hit(ei, target_pi, hit_dmg)
			
			_: # Normal attack
				var base_damage = enemy["attack"] + randi_range(-2, 3)
				base_damage -= debuff
				base_damage = maxi(base_damage, 1)
				_apply_enemy_hit(ei, target_pi, base_damage)
		
		# Check if target player died
		if player_gladiators[target_pi].current_hp <= 0:
			player_gladiators[target_pi].current_hp = 0
			player_gladiators[target_pi].is_active = false
			gladiator_defeated.emit("player", target_pi)
	
	# Check lose: all player gladiators dead
	if _all_players_dead():
		_end_battle(false)
		return
	
	# Auto-select first alive player
	_auto_select_next_player()
	
	# Back to player
	_start_player_turn()

func _apply_enemy_hit(_enemy_index: int, player_index: int, damage: int) -> void:
	var glad = player_gladiators[player_index]
	
	if randf() * 100.0 < glad.dodge_chance:
		damage_dealt.emit("player", 0, 0)
		animation_requested.emit("dodge", "player_%d" % player_index)
		return
	
	var reduction = TraitSystem.get_damage_reduction(glad)
	var reduced_damage = int(damage * (1.0 - reduction))
	reduced_damage = maxi(reduced_damage, 1)
	
	var blocked = mini(player_blocks[player_index], reduced_damage)
	player_blocks[player_index] -= blocked
	var actual = reduced_damage - blocked
	glad.current_hp -= actual
	damage_dealt.emit("player", actual, blocked)
	animation_requested.emit("hit", "player_%d" % player_index)

func _end_battle(player_won: bool) -> void:
	battle_active = false
	var reward_gold = 0
	
	if player_won:
		reward_gold = randi_range(15, 40) * enemies.size() # More reward for more enemies
		GameManager.gold += reward_gold
		GameManager.battles_won += 1
	
	battle_ended.emit(player_won, reward_gold)

# --- Helpers ---

func _all_enemies_dead() -> bool:
	for e in enemies:
		if e["hp"] > 0:
			return false
	return true

func _all_players_dead() -> bool:
	for g in player_gladiators:
		if g.is_active and g.current_hp > 0:
			return false
	return true

func _auto_select_next_enemy() -> void:
	for i in range(enemies.size()):
		if enemies[i]["hp"] > 0:
			selected_enemy_index = i
			return

func _auto_select_next_player() -> void:
	for i in range(player_gladiators.size()):
		if player_gladiators[i].is_active and player_gladiators[i].current_hp > 0:
			selected_player_index = i
			return

func get_selected_player() -> Gladiator:
	if selected_player_index >= 0 and selected_player_index < player_gladiators.size():
		return player_gladiators[selected_player_index]
	return null

func get_selected_enemy() -> Dictionary:
	if selected_enemy_index >= 0 and selected_enemy_index < enemies.size():
		return enemies[selected_enemy_index]
	return {}

# --- Getters for UI ---

func get_player_hp(index: int = -1) -> int:
	var idx = index if index >= 0 else selected_player_index
	if idx >= 0 and idx < player_gladiators.size():
		return player_gladiators[idx].current_hp
	return 0

func get_player_max_hp(index: int = -1) -> int:
	var idx = index if index >= 0 else selected_player_index
	if idx >= 0 and idx < player_gladiators.size():
		return player_gladiators[idx].max_hp
	return 1

func get_enemy_hp(index: int = -1) -> int:
	var idx = index if index >= 0 else selected_enemy_index
	if idx >= 0 and idx < enemies.size():
		return enemies[idx]["hp"]
	return 0

func get_enemy_max_hp(index: int = -1) -> int:
	var idx = index if index >= 0 else selected_enemy_index
	if idx >= 0 and idx < enemies.size():
		return enemies[idx]["max_hp"]
	return 1

func get_player_block(index: int = -1) -> int:
	var idx = index if index >= 0 else selected_player_index
	if idx >= 0 and idx < player_blocks.size():
		return player_blocks[idx]
	return 0

func get_enemy_block(index: int = -1) -> int:
	var idx = index if index >= 0 else selected_enemy_index
	if idx >= 0 and idx < enemies.size():
		return enemies[idx]["block"]
	return 0
