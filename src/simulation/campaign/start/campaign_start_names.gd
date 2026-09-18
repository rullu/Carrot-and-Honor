class_name CampaignStartNames
extends RefCounted

const DATA_PATH: String = "res://data/campaign/campaign_start_v1.json"
const SOFT_NAMES: Array[String] = [
    "Hazel", "Hasel", "Rowan", "Briar", "Sorrel", "Linden",
    "Mallow", "Fern", "Clover", "Thistle", "Bramble", "Moss",
]
const SOFT_WEIGHTS: Array[int] = [3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 1, 1]
const STYLES: Dictionary = {
    "western": "house", "mediterranean": "family", "northern": "lineage",
    "central": "house", "kharven": "clan", "eastern": "house",
}

var data: Dictionary


func _init() -> void:
    data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


func family(culture: String) -> String:
    for key: String in data["families"]:
        if culture in data["families"][key]["cultures"]:
            return key
    return ""


func style(culture: String, ruling: bool) -> String:
    var key: String = family(culture)
    return "dynasty" if key == "eastern" and ruling else String(STYLES.get(key, ""))


func entries(culture: String, kind: String) -> Array:
    var key: String = family(culture)
    return [] if key.is_empty() else data["families"][key][kind]


static func affinity(entry: Dictionary, culture: String) -> int:
    if culture in entry["primary"]:
        return 5
    return 1 if culture in entry["rare"] else 3


func given_name(culture: String, sex: String, random: CampaignStartRandom) -> String:
    if random.below(100) < 8:
        return SOFT_NAMES[random.weighted(SOFT_WEIGHTS)]
    var options: Array[String] = []
    var weights: Array[int] = []
    for entry: Dictionary in entries(culture, sex):
        if entry["name"] in SOFT_NAMES:
            continue
        options.append(entry["name"])
        weights.append(affinity(entry, culture))
    return "" if options.is_empty() else options[random.weighted(weights)]


func lineage_name(culture: String, used: Dictionary, random: CampaignStartRandom) -> String:
    var options: Array[String] = []
    var weights: Array[int] = []
    for entry: Dictionary in entries(culture, "lineage"):
        if used.has(entry["name"]):
            continue
        options.append(entry["name"])
        weights.append(affinity(entry, culture))
    # Exhaustion invalidates the attempt; never invent suffixes or reuse a lineage.
    return "" if options.is_empty() else options[random.weighted(weights)]


func valid_name(value: String, culture: String, kind: String) -> bool:
    if family(culture).is_empty():
        return false
    if kind != "lineage" and value in SOFT_NAMES:
        return true
    for entry: Dictionary in entries(culture, kind):
        if entry["name"] == value:
            return true
    return false
