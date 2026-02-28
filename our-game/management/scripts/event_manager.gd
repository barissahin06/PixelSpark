class_name EventManager
extends RefCounted

## Manages random events that trigger when the day advances.
## Events are loaded from events.json and provide meaningful choices.

const EVENTS_PATH := "res://events.json"

signal event_triggered(event_data: Dictionary)
signal event_resolved(result_text: String)

var events: Array = []
var _pending_event: Dictionary = {}

func _init() -> void:
	_load_events()

func _load_events() -> void:
	events.clear()
	var raw = JsonLoader.load_json(EVENTS_PATH, [])
	if raw is Array:
		events = raw

func try_trigger_event() -> bool:
	## Returns true if an event was triggered (40% chance per day)
	if events.is_empty():
		return false
	
	if randf() > 0.4:
		return false
	
	_pending_event = events[randi() % events.size()]
	event_triggered.emit(_pending_event)
	return true

func get_pending_event() -> Dictionary:
	return _pending_event

func resolve_choice(choice_key: String) -> String:
	## Applies the chosen effect and returns a result description string.
	if _pending_event.is_empty():
		return ""
	
	var choice: Dictionary = _pending_event.get(choice_key, {})
	if choice.is_empty():
		return "Nothing happened."
	
	var gold_change: int = int(choice.get("gold", 0))
	var effect: String = str(choice.get("effect", "none"))
	var value: int = int(choice.get("value", 0))
	var result := ""
	
	# Apply gold
	if gold_change != 0:
		GameManager.gold += gold_change
		if gold_change > 0:
			result += "+%d Gold. " % gold_change
		else:
			result += "%d Gold. " % gold_change
	
	# Apply effects
	match effect:
		"attack_boost":
			var targets = _get_active_gladiators()
			if targets.size() > 0:
				var target = targets[randi() % targets.size()]
				target.attack_damage += value
				result += "%s gained +%d Attack!" % [target.g_name, value]
			else:
				result += "No gladiators to boost."
		
		"attack_boost_all":
			for g in _get_active_gladiators():
				g.attack_damage += value
			result += "All gladiators gained +%d Attack!" % value
		
		"heal_one":
			var targets = _get_active_gladiators()
			if targets.size() > 0:
				var target = targets[randi() % targets.size()]
				target.current_hp = target.max_hp
				result += "%s was fully healed!" % target.g_name
			else:
				result += "No gladiators to heal."
		
		"food_boost":
			GameManager.food += value
			result += "+%d Food!" % value
		
		"risky_food":
			GameManager.food += value
			result += "+%d Food! " % value
			# 50% chance of injury
			if randf() < 0.5:
				var targets = _get_active_gladiators()
				if targets.size() > 0:
					var target = targets[randi() % targets.size()]
					target.current_hp -= 15
					if target.current_hp <= 0:
						target.current_hp = 0
						target.is_active = false
					result += "But %s was injured (-15 HP)!" % target.g_name
			else:
				result += "The robbery went smoothly!"
		
		"free_slave":
			GameManager.add_gladiator("slave_base")
			result += "A new Slave joined your ludus!"
		
		"random_damage":
			var targets = _get_active_gladiators()
			if targets.size() > 0:
				var target = targets[randi() % targets.size()]
				target.current_hp -= value
				if target.current_hp <= 0:
					target.current_hp = 0
					target.is_active = false
				result += "%s took %d damage!" % [target.g_name, value]
			else:
				result += "No gladiators affected."
		
		"none":
			if result.is_empty():
				result = "Nothing happened."
	
	_pending_event = {}
	event_resolved.emit(result)
	return result

func _get_active_gladiators() -> Array[Gladiator]:
	var active: Array[Gladiator] = []
	for g in GameManager.roster:
		if g.is_active:
			active.append(g)
	return active
