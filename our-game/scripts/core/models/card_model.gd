class_name CardModel
extends Resource

# Türleri açıkça belirtiyoruz (Static Typing)
# Bu sayede Godot, 'cost' değişkenine yanlışlıkla yazı (string) atarsan seni uyarır.

var id: String
var card_name: String
var cost: int
var attack_power: int
var health: int
var description: String
var icon: Texture2D # Eğer resim tutuyorsa

# Fonksiyon parametrelerine ve dönüş değerine de tür eklemek en iyisidir
func _init(p_id: String, p_name: String, p_cost: int) -> void:
	id = p_id
	card_name = p_name
	cost = p_cost

# Örnek bir getter fonksiyonu
func get_full_title() -> String:
	return id + ": " + card_name

# Dictionary verisinden CardModel oluşturan statik fonksiyon
static func from_dict(data: Dictionary) -> CardModel:
	var p_id = data.get("id", "") as String
	var p_name = data.get("card_name", "Bilinmeyen Kart") as String
	var p_cost = data.get("cost", 0) as int

	var card = CardModel.new(p_id, p_name, p_cost)
	
	if data.has("attack_power"): card.attack_power = data["attack_power"]
	if data.has("health"): card.health = data["health"]
	if data.has("description"): card.description = data["description"]
	
	return card
