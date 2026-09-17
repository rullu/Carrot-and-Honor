class_name CampaignTestSuite
extends SceneTree


var _failures: int = 0
var _checks: int = 0


func check(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error(message)


func ok(result: Dictionary, message: String) -> void:
    check(result["ok"], message + ": " + str(result["errors"]))


func rejected(session: CampaignSession, action: Callable, message: String) -> void:
    var before: String = canonical(session.export_data())
    var revision: int = session.revision()
    var result: Dictionary = action.call()
    check(not result["ok"] and not result["errors"].is_empty(), message + " rejected with diagnostics")
    check(canonical(session.export_data()) == before, message + " leaves all authoritative state unchanged")
    check(session.revision() == revision, message + " does not publish a revision")


func invalid(data: Variant, message: String) -> void:
    var result: Dictionary = CampaignCodec.decode_data(data)
    check(result["state"] == null and not result["errors"].is_empty(), message)


func canonical(data: Dictionary) -> String:
    return JSON.stringify(data, "", true, true)


func finish(label: String) -> void:
    if _failures > 0:
        push_error("%s FAIL: %d / %d checks failed." % [label, _failures, _checks])
        quit(1)
    else:
        print("%s PASS: %d checks." % [label, _checks])
        quit(0)
