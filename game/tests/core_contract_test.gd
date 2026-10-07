extends SceneTree

const JOURNAL = preload("res://app/command_journal.gd")
const CLOCK = preload("res://app/game_clock.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL core ", label)

func command(id: String, payload := {"slot":0}) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.test",
		"actor_id":"actor.player",
		"action":"inventory.select",
		"expected_revision":0,
		"payload":payload
	}

func success(id: String, revision := 1) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"ok":true,
		"error_code":"",
		"is_retryable":false,
		"has_changes":true,
		"revision":revision,
		"event_ids":["event."+id]
	}

func _initialize() -> void:
	var journal = JOURNAL.new()
	var calls := 0
	var handler := func(c: Dictionary) -> Dictionary:
		calls += 1
		return success(c.command_id)
	var probe := command("cmd-probe")
	check(JOURNAL._valid_command(probe), "valid command shape accepted")
	check(JOURNAL._valid_result(success("cmd-probe"), "cmd-probe"), "valid result shape accepted")
	check(handler.is_valid(), "lambda handler is callable")
	var first := journal.execute(command("cmd-1"), handler)
	check(first.ok and calls == 1 and journal.receipt_count() == 1, "first command commits receipt: "+str(first)+" calls="+str(calls)+" receipts="+str(journal.receipt_count()))
	var replay := journal.execute(command("cmd-1"), handler)
	check(replay == first and calls == 1, "same id same request replays without handler: "+str(replay)+" calls="+str(calls))
	var conflict := journal.execute(command("cmd-1",{"slot":1}), handler)
	check(not conflict.ok and conflict.error_code == "COMMAND_ID_CONFLICT" and calls == 1, "same id different request conflicts: "+str(conflict)+" calls="+str(calls))
	var bad := command("cmd-bad")
	bad["unexpected"] = true
	check(journal.execute(bad, handler).error_code == "COMMAND_INVALID", "unknown base field rejected")
	var malformed := journal.execute(command("cmd-result"), func(c): return {"ok":true})
	check(not malformed.ok and malformed.error_code == "COMMAND_RESULT_INVALID" and journal.receipt_count() == 1, "malformed handler result not journaled")
	journal.clear()
	check(journal.receipt_count() == 0, "receipt journal clears with session")

	var clock = CLOCK.new()
	check(clock.current_day() == 1 and clock.minute_of_day() == CLOCK.DAY_START_MINUTE, "clock starts day one at configured start")
	check(clock.acquire_pause(&"inventory") and clock.acquire_pause(&"settings") and clock.pause_owner_count() == 2, "independent pause owners")
	check(clock.advance(10).error_code == "CLOCK_PAUSED" and clock.game_minute == CLOCK.DAY_START_MINUTE, "paused clock does not advance")
	check(clock.release_pause(&"inventory") and clock.is_paused(), "owner only releases own pause")
	check(clock.release_pause(&"settings") and not clock.is_paused(), "last owner resumes clock")
	var advance := clock.advance(1200)
	check(advance.ok and advance.crossed_days == [2] and clock.current_day() == 2, "advance reports crossed day")
	var rest := clock.rest_to_next_day_start()
	check(rest.ok and rest.crossed_days == [3] and clock.current_day() == 3 and clock.minute_of_day() == CLOCK.DAY_START_MINUTE, "rest reaches next day start once")
	check(not clock.release_pause(&"missing"), "unknown pause owner cannot release")
	check(not clock.reset(-1) and clock.current_day() == 3, "invalid reset rejected without mutation")

	print("CORE_PASS checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
