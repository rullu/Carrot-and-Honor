class_name EconomyProvenance
extends RefCounted

const FIELDS: Dictionary = {"generator_version": "positive_int", "content_version": "positive_int", "content_hash": "id", "config_hash": "id", "config": "object"}
var generator_version: int = 1
var content_version: int = 1
var content_hash: String = ""
var config_hash: String = ""
var config: EconomyConfig


func to_data() -> Dictionary:
    return {"generator_version": generator_version, "content_version": content_version,
        "content_hash": content_hash, "config_hash": config_hash, "config": config.to_data() if config != null else null}


static func from_data(data: Dictionary) -> EconomyProvenance:
    var result: EconomyProvenance = EconomyProvenance.new()
    result.generator_version = int(data["generator_version"])
    result.content_version = int(data["content_version"])
    result.content_hash = data["content_hash"]
    result.config_hash = data["config_hash"]
    result.config = EconomyConfig.from_data(data["config"])
    return result
