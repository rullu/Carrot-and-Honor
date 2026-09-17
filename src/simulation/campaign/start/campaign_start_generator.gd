class_name CampaignStartGenerator
extends RefCounted

const VERSION: int = 1
const MAX_ATTEMPTS: int = 64
const AGE_BANDS: Array = [[18, 24], [25, 39], [40, 59], [60, 85]]
const AGE_WEIGHTS: Array[int] = [10, 32, 45, 13]
const MARITAL_WEIGHTS: Array[int] = [35, 55, 9, 1]
const CHILD_WEIGHTS: Array[int] = [42, 26, 18, 9, 4, 1]

var world: CampaignStartWorld
var _random: CampaignStartRandom
var _key: String
var _id_counter: int
var _days: int
var _characters: Array[CharacterState] = []
var _dynasties: Array[DynastyState] = []
var _used_lineages: Dictionary = {}


func _init(authorities: CampaignStartWorld = null) -> void:
    world = authorities if authorities != null else CampaignStartWorld.new()


func generate(campaign_seed: String, days_per_year: int, generator_version: int = VERSION,
        attempt_limit: int = MAX_ATTEMPTS) -> Dictionary:
    var errors: PackedStringArray = world.errors.duplicate()
    if campaign_seed.is_empty():
        errors.append("campaign_seed must be a nonempty opaque string.")
    # All pre-start birthdays must fit the exact JSON integer envelope, including
    # coherence ancestors. This is a technical bound, not a calendar decision.
    if days_per_year <= 0 or days_per_year > 4294967296 / 256:
        errors.append("days_per_year must be positive and within the v1 exact tick sampling range.")
    if generator_version != VERSION:
        errors.append("Unsupported generator_version.")
    if attempt_limit < 1 or attempt_limit > MAX_ATTEMPTS:
        errors.append("Attempt limit must be between 1 and %d." % MAX_ATTEMPTS)
    if not errors.is_empty():
        return {"cast": null, "errors": errors, "attempts": 0, "rejections": []}
    var rejections: Array = []
    for attempt: int in attempt_limit:
        var cast: Dictionary = generate_attempt(campaign_seed, days_per_year, attempt)
        errors = CampaignStartValidator.validate(cast, world)
        var category: String = "hard"
        if errors.is_empty():
            category = "soft"
            errors = CampaignStartValidator.soft_sanity(cast)
        if errors.is_empty():
            return {"cast": cast, "errors": errors, "attempts": attempt + 1, "rejections": rejections}
        rejections.append({"attempt": attempt, "category": category, "errors": Array(errors)})
    return {"cast": null, "errors": PackedStringArray([
        "Campaign generation exhausted %d deterministic attempts: %s" % [attempt_limit, str(errors)]
    ]), "attempts": attempt_limit, "rejections": rejections}


# Public diagnostic seam: raw attempts still require both validation passes.
func generate_attempt(campaign_seed: String, days_per_year: int, attempt: int) -> Dictionary:
    _key = JSON.stringify([campaign_seed, VERSION, world.binding, days_per_year,
        JSON.stringify(world.names.data, "", true, true).sha256_text(), attempt], "", true, true)
    _random = CampaignStartRandom.new(_key)
    _id_counter = 0
    _days = days_per_year
    _characters = []
    _dynasties = []
    _used_lineages = {}
    var realms: Array[RealmState] = []
    for id: String in world.realm_ids:
        var realm: RealmState = world.realm_setup(id)
        var band: Array = AGE_BANDS[_random.weighted(AGE_WEIGHTS)]
        var ruler_age: int = _random.between(band[0], band[1])
        var ruler: CharacterState = _character(realm, realm.official_culture, realm.official_religion,
            _lineage(realm.official_culture, realm.official_religion, true),
            "male" if _random.below(100) < 80 else "female", ruler_age, true)
        realm.current_ruler_id = ruler.character_id
        # Very young rulers transfer widow/remarriage probability to unmarried.
        var marital_weights: Array[int] = MARITAL_WEIGHTS.duplicate()
        if ruler_age < 25:
            marital_weights = [43, 55, 2, 0]
        var status: int = _random.weighted(marital_weights)
        var spouses: Array[CharacterState] = []
        if status != 0:
            spouses.append(_spouse(realm, ruler, status == 1, ruler_age))
        if status == 3:
            spouses.append(_spouse(realm, ruler, true, ruler_age))
        var children: Array[CharacterState] = []
        if status != 0:
            for child_index: int in _random.weighted(CHILD_WEIGHTS):
                var spouse: CharacterState = spouses[_random.below(spouses.size())]
                var child: CharacterState = _character(realm, ruler.personal_culture, ruler.personal_religion,
                    ruler.dynasty_id, _sex(), 0, true)
                child.birth_tick = _random.between(maxi(ruler.birth_tick, spouse.birth_tick) + 16 * _days, 0)
                child.parent_ids = [ruler.character_id, spouse.character_id]
                child.parent_ids.sort()
                children.append(child)
        children.sort_custom(CampaignStartValidator.birth_order)
        if id != "R008" and not children.is_empty():
            realm.recognized_heir_id = children[0].character_id
        _relatives(realm, ruler, ruler_age)
        realms.append(realm)
    return {"campaign_seed": campaign_seed, "generator_version": VERSION, "days_per_year": _days,
        "world_binding": world.binding, "realm_setups": realms,
        "character_setups": _characters, "dynasty_setups": _dynasties}


func _id(prefix: String) -> String:
    _id_counter += 1
    return prefix + "_" + (_key + ":id:" + str(_id_counter)).sha256_text().left(32)


func _sex() -> String:
    return "male" if _random.below(2) == 0 else "female"


func _lineage(culture: String, religion: Dictionary, ruling: bool) -> String:
    var dynasty: DynastyState = DynastyState.new()
    dynasty.dynasty_id = _id("dynasty")
    dynasty.lineage_name = world.names.lineage_name(culture, _used_lineages, _random)
    dynasty.lineage_style = world.names.style(culture, ruling)
    dynasty.origin_culture = culture
    dynasty.origin_religion = religion.duplicate(true)
    _used_lineages[dynasty.lineage_name] = true
    _dynasties.append(dynasty)
    return dynasty.dynasty_id


func _character(realm: RealmState, culture: String, religion: Dictionary, dynasty_id: String,
        sex: String, age: int, alive: bool) -> CharacterState:
    var character: CharacterState = CharacterState.new()
    character.character_id = _id("character")
    character.given_name = world.names.given_name(culture, sex, _random)
    character.sex = sex
    character.birth_tick = -age * _days - _random.below(_days)
    character.alive = alive
    character.dynasty_id = dynasty_id
    character.realm_id = realm.realm_id
    character.personal_culture = culture
    character.personal_religion = religion.duplicate(true)
    _characters.append(character)
    return character


func _spouse(realm: RealmState, ruler: CharacterState, alive: bool, age: int) -> CharacterState:
    # Weight each actual footprint identity by 5 for ruler culture, 1 otherwise.
    # Religion travels with explicit canonical data, never a culture lookup.
    var identities: Array[Dictionary] = world.identities(realm.realm_id)
    var weights: Array[int] = []
    for identity: Dictionary in identities:
        weights.append(5 if identity["culture"] == ruler.personal_culture else 1)
    var chosen: Dictionary = identities[_random.weighted(weights)]
    var spouse: CharacterState = _character(realm, chosen["culture"], chosen["religion"],
        _lineage(chosen["culture"], chosen["religion"], false),
        "female" if ruler.sex == "male" else "male", _random.between(maxi(18, age - 8), mini(85, age + 8)), alive)
    ruler.partner_ids.append(spouse.character_id)
    ruler.partner_ids.sort()
    spouse.partner_ids = [ruler.character_id]
    return spouse


func _relatives(realm: RealmState, ruler: CharacterState, ruler_age: int) -> void:
    var sibling: bool = _random.below(100) < 35
    var living_parent: bool = _random.below(100) < 20 and ruler_age <= 69
    var branch: bool = _random.below(100) < 5
    if not sibling and not living_parent and not branch:
        return
    # A single known lineage parent is sufficient; missing parent facts do not
    # assert illegitimacy. No decorative deceased second parent is invented.
    var parent_age: int = ruler_age + _random.between(16, 30)
    if living_parent:
        parent_age = mini(parent_age, 85)
    var parent: CharacterState = _character(realm, ruler.personal_culture, ruler.personal_religion,
        ruler.dynasty_id, _sex(), parent_age, living_parent)
    parent.birth_tick = mini(parent.birth_tick, ruler.birth_tick - 16 * _days)
    if parent.age_years(0, _days) > 85:
        parent.alive = false
    ruler.parent_ids = [parent.character_id]
    if sibling:
        var relative: CharacterState = _character(realm, ruler.personal_culture, ruler.personal_religion,
            ruler.dynasty_id, _sex(), 0, true)
        relative.birth_tick = _random.between(maxi(parent.birth_tick + 16 * _days, -85 * _days), 0)
        relative.parent_ids = [parent.character_id]
    if branch:
        # One deceased grandparent is needed to encode the aunt/uncle connection.
        # Grandparents otherwise have no independent generation roll.
        var grandparent: CharacterState = _character(realm, ruler.personal_culture, ruler.personal_religion,
            ruler.dynasty_id, _sex(), parent_age + 25, false)
        grandparent.birth_tick = parent.birth_tick - 25 * _days
        parent.parent_ids = [grandparent.character_id]
        var aunt: CharacterState = _character(realm, ruler.personal_culture, ruler.personal_religion,
            ruler.dynasty_id, _sex(), 0, true)
        aunt.birth_tick = parent.birth_tick + _random.between(-5, 5) * _days
        aunt.alive = aunt.age_years(0, _days) <= 85
        aunt.parent_ids = [grandparent.character_id]
        var cousin: CharacterState = _character(realm, ruler.personal_culture, ruler.personal_religion,
            ruler.dynasty_id, _sex(), 0, true)
        cousin.birth_tick = _random.between(maxi(aunt.birth_tick + 16 * _days, -85 * _days), 0)
        cousin.parent_ids = [aunt.character_id]
