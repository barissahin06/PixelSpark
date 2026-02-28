class_name LudusUpgrades
extends RefCounted

## Manages ludus building upgrades with gold costs, build durations, and passive effects.

# Upgrade definitions
const UPGRADE_DEFS := {
	"showers": {
		"name": "Showers",
		"description": "Gladiators recover +3 extra HP per day.",
		"cost": 30,
		"build_days": 3,
		"icon": "🚿",
		"requires": "",
	},
	"private_rooms": {
		"name": "Private Rooms",
		"description": "Roster capacity increased by +5.",
		"cost": 50,
		"build_days": 4,
		"icon": "🏠",
		"requires": "",
	},
	"ludus_doctor_1": {
		"name": "Ludus Doctor",
		"description": "Healing cost reduced by 2 gold.",
		"cost": 25,
		"build_days": 2,
		"icon": "⚕",
		"requires": "",
	},
	"ludus_doctor_2": {
		"name": "Master Physician",
		"description": "Healing now restores full HP.",
		"cost": 50,
		"build_days": 4,
		"icon": "💊",
		"requires": "ludus_doctor_1",
	},
	"farm_yard": {
		"name": "Farm Yard",
		"description": "+3 passive gold income per day.",
		"cost": 40,
		"build_days": 3,
		"icon": "🌾",
		"requires": "",
	},
	"armory": {
		"name": "Armory",
		"description": "All gladiators gain +3 base ATK.",
		"cost": 60,
		"build_days": 5,
		"icon": "⚔",
		"requires": "",
	},
}

# State
var built_upgrades: Array[String] = []
var building_upgrade: String = ""
var build_days_left: int = 0

func is_built(upgrade_id: String) -> bool:
	return built_upgrades.has(upgrade_id)

func is_building(upgrade_id: String) -> bool:
	return building_upgrade == upgrade_id

func is_anything_building() -> bool:
	return building_upgrade != ""

func can_build(upgrade_id: String, available_gold: int) -> bool:
	if is_built(upgrade_id):
		return false
	if is_anything_building():
		return false
	if not UPGRADE_DEFS.has(upgrade_id):
		return false
	
	var def = UPGRADE_DEFS[upgrade_id]
	if available_gold < def["cost"]:
		return false
	
	# Check prerequisites
	var req = str(def.get("requires", ""))
	if req != "" and not is_built(req):
		return false
	
	return true

func start_build(upgrade_id: String) -> int:
	## Returns the gold cost, or -1 if cannot build
	if not UPGRADE_DEFS.has(upgrade_id):
		return -1
	
	var def = UPGRADE_DEFS[upgrade_id]
	building_upgrade = upgrade_id
	build_days_left = def["build_days"]
	return def["cost"]

func pass_day():
	if building_upgrade == "":
		return
	
	build_days_left -= 1
	if build_days_left <= 0:
		_complete_upgrade()

func _complete_upgrade():
	if building_upgrade != "":
		built_upgrades.append(building_upgrade)
		print("Ludus upgrade completed: %s" % building_upgrade)
		
		# Armory: apply ATK bonus to all existing gladiators
		if building_upgrade == "armory":
			for g in GameManager.roster:
				g.attack_damage += 3
		
		building_upgrade = ""
		build_days_left = 0

# --- Effect Getters ---

func get_daily_hp_regen_bonus() -> int:
	## Showers: +3 HP regen per day
	return 3 if is_built("showers") else 0

func get_roster_capacity_bonus() -> int:
	## Private Rooms: +5 roster capacity
	return 5 if is_built("private_rooms") else 0

func get_heal_cost_reduction() -> int:
	## Ludus Doctor: -2 gold heal cost
	return 2 if is_built("ludus_doctor_1") else 0

func get_daily_gold_income() -> int:
	## Farm Yard: +3 gold per day
	return 3 if is_built("farm_yard") else 0

func get_upgrade_status(upgrade_id: String) -> String:
	if is_built(upgrade_id):
		return "built"
	elif is_building(upgrade_id):
		return "building"
	else:
		return "available"

func get_all_upgrades() -> Array:
	## Returns an array of dictionaries with id, name, cost, status, etc.
	var result = []
	for id in UPGRADE_DEFS:
		var def = UPGRADE_DEFS[id]
		var status = get_upgrade_status(id)
		result.append({
			"id": id,
			"name": def["name"],
			"description": def["description"],
			"cost": def["cost"],
			"build_days": def["build_days"],
			"icon": def["icon"],
			"requires": def.get("requires", ""),
			"status": status,
			"days_left": build_days_left if status == "building" else 0,
		})
	return result
