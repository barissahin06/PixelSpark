class_name BattleManager
extends RefCounted

## Manages a single battle encounter between a player gladiator and an enemy.
## Uses a card-based turn system with stat-scaled cards and type-specific decks.

signal battle_started
signal turn_started(is_player_turn: bool)
signal card_played(card: CardModel, is_player: bool)
signal damage_dealt(target: String, amount: int, blocked: int)
signal battle_ended(player_won: bool, reward_gold: int)
signal animation_requested(anim_type: String, target: String)

# --- Battle State ---
var player_gladiator: Gladiator = null
var enemy_name: String = ""
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_attack: int = 0
var enemy_dodge: float = 0.0
var enemy_type: String = ""  # For sprite display

var player_block: int = 0
var enemy_block: int = 0

var deck: Array[CardModel] = []
var hand: Array[CardModel] = []
var discard: Array[CardModel] = []

var max_hand_size: int = 5
var energy: int = 3
var max_energy: int = 3

var is_player_turn: bool = true
var battle_active: bool = false
var turn_count: int = 0

# Debuffs
var enemy_attack_debuff: int = 0  # Net Toss: reduce enemy attack next turn

# Type-specific scaling coefficients
const TYPE_COEFFICIENTS := {
	"Murmillo": {"attack_mult": 1.0, "block_mult": 1.4, "energy_bonus": 0},
	"Thraex": {"attack_mult": 1.2, "block_mult": 1.0, "energy_bonus": 0},
	"Retiarius": {"attack_mult": 1.3, "block_mult": 0.8, "energy_bonus": 0},
	"Slave": {"attack_mult": 0.7, "block_mult": 0.7, "energy_bonus": 0},
}

# --- Setup ---

func start_battle(gladiator: Gladiator, p_enemy_name: String, p_enemy_hp: int, p_enemy_attack: int, p_enemy_dodge: float, p_enemy_type: String = "Gladiator") -> void:
	player_gladiator = gladiator
	enemy_name = p_enemy_name
	enemy_max_hp = p_enemy_hp
	enemy_hp = p_enemy_hp
	enemy_attack = p_enemy_attack
	enemy_dodge = p_enemy_dodge
	enemy_type = p_enemy_type
	
	battle_active = true
	is_player_turn = true
	turn_count = 0
	player_block = 0
	enemy_block = 0
	enemy_attack_debuff = 0
	
	_build_deck()
	_shuffle_deck()
	_start_player_turn()
	
	battle_started.emit()

func _build_deck() -> void:
	deck.clear()
	hand.clear()
	discard.clear()
	
	var gladiator_type = player_gladiator.type if player_gladiator else ""
	
	for card_data in GameData.cards:
		var card_tags = card_data.tags if card_data.tags else []
		
		# Determine how many copies of this card to add
		var copies = 2  # Default: 2 copies
		
		# Type-specific cards: only add if matching type (or no type tag)
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
		
		# Type affinity bonuses for generic cards
		if not is_type_card:
			if "defense" in card_tags and gladiator_type == "Murmillo":
				copies = 3  # Murmillo gets extra defense cards
			elif "attack" in card_tags and "basic" in card_tags and gladiator_type == "Retiarius":
				copies = 3  # Retiarius gets extra basic attacks
		
		for i in range(copies):
			var card = CardModel.new(card_data.id, card_data.card_name, card_data.cost)
			card.attack_power = card_data.attack_power
			card.health = card_data.health
			card.description = card_data.description
			card.tags = card_data.tags if card_data.tags else []
			deck.append(card)

func _shuffle_deck() -> void:
	deck.shuffle()

# --- Turn Logic ---

func _start_player_turn() -> void:
	is_player_turn = true
	turn_count += 1
	energy = max_energy
	player_block = 0  # Block resets each turn
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
	
	var coeff = TYPE_COEFFICIENTS.get(player_gladiator.type, {"attack_mult": 1.0, "block_mult": 1.0, "energy_bonus": 0})
	
	# Apply card effects
	var actual_damage = 0
	if card.attack_power > 0:
		# Scaled attack with type coefficient
		var scaled = card.scaled_attack(player_gladiator)
		scaled = int(scaled * coeff["attack_mult"])
		
		# Apply trait damage modifier (e.g. berserker)
		var trait_mult = TraitSystem.get_damage_modifier(player_gladiator)
		scaled = int(scaled * trait_mult)
		
		# Pierce mechanic for Sica Slash
		var pierce = card.has_tag("pierce")
		
		# Check enemy dodge
		if randf() * 100.0 < enemy_dodge:
			actual_damage = 0  # Dodged!
			animation_requested.emit("dodge", "enemy")
		else:
			if pierce:
				# Ignore 50% of block
				var effective_block = int(enemy_block * 0.5)
				var blocked = mini(effective_block, scaled)
				enemy_block -= blocked
				actual_damage = scaled - blocked
			else:
				var blocked = mini(enemy_block, scaled)
				enemy_block -= blocked
				actual_damage = scaled - blocked
			
			enemy_hp -= actual_damage
			animation_requested.emit("hit", "enemy")
		
		damage_dealt.emit("enemy", actual_damage, 0)
	
	if card.health > 0:
		var scaled_blk = card.scaled_block(player_gladiator)
		scaled_blk = int(scaled_blk * coeff["block_mult"])
		player_block += scaled_blk
	
	# Special card effects
	if card.id == "card_rally":
		_draw_cards(1)
	
	if card.id == "card_crowd_roar" or card.has_tag("energy"):
		energy += 1
	
	if card.id == "card_net_toss" or card.has_tag("debuff"):
		enemy_attack_debuff += 5  # Reduce enemy attack next turn
	
	card_played.emit(card, true)
	discard.append(card)
	
	# Check win
	if enemy_hp <= 0:
		enemy_hp = 0
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
	enemy_block = 0  # Reset enemy block
	
	# Simple AI: attack with base damage (minus debuffs)
	var base_damage = enemy_attack + randi_range(-3, 3)
	base_damage -= enemy_attack_debuff
	base_damage = maxi(base_damage, 1)
	enemy_attack_debuff = 0  # Debuff wears off
	
	# Check player dodge
	if randf() * 100.0 < player_gladiator.dodge_chance:
		damage_dealt.emit("player", 0, 0)  # Dodged
		animation_requested.emit("dodge", "player")
	else:
		# Apply trait damage reduction (e.g. iron_skin)
		var reduction = TraitSystem.get_damage_reduction(player_gladiator)
		var reduced_damage = int(base_damage * reduction)
		
		var blocked = mini(player_block, reduced_damage)
		player_block -= blocked
		var actual = reduced_damage - blocked
		player_gladiator.current_hp -= actual
		damage_dealt.emit("player", actual, blocked)
		animation_requested.emit("hit", "player")
	
	# Check lose
	if player_gladiator.current_hp <= 0:
		player_gladiator.current_hp = 0
		player_gladiator.is_active = false
		_end_battle(false)
		return
	
	# Back to player
	_start_player_turn()

func _end_battle(player_won: bool) -> void:
	battle_active = false
	var reward_gold = 0
	
	if player_won:
		reward_gold = randi_range(15, 40)
		GameManager.gold += reward_gold
	
	battle_ended.emit(player_won, reward_gold)

# --- Getters for UI ---

func get_player_hp() -> int:
	return player_gladiator.current_hp if player_gladiator else 0

func get_player_max_hp() -> int:
	return player_gladiator.max_hp if player_gladiator else 1

func get_enemy_hp() -> int:
	return enemy_hp

func get_enemy_max_hp() -> int:
	return enemy_max_hp
