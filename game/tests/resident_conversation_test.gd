extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const CONVERSATIONS = preload("res://systems/resident_conversation_state.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL resident_conversation ",label)

func _initialize() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads")
	if not loaded.ok:
		finish()
		return
	var state := CONVERSATIONS.new(loaded.data)
	check(state.is_configured(),"conversation domain configures")

	var invited: Dictionary = state.invite("conversation.grocer-maker","resident.grocer","resident.maker","space.village")
	check(invited.ok and invited.conversation.state=="invited","invite reserves two residents")
	check(state.conversation_for_actor("resident.grocer").conversation_id=="conversation.grocer-maker","grocer occupancy points to active conversation")
	var busy: Dictionary = state.invite("conversation.grocer-neighbor","resident.grocer","resident.neighbor","space.village")
	check(not busy.ok and busy.error_code=="CONVERSATION_PARTICIPANT_BUSY","occupied resident cannot join a second conversation")

	var approaching: Dictionary = state.mark_approaching("conversation.grocer-maker")
	check(approaching.ok and approaching.conversation.state=="approaching","invite advances to approaching")
	var bad_repeat: Dictionary = state.mark_approaching("conversation.grocer-maker")
	check(not bad_repeat.ok and bad_repeat.error_code=="CONVERSATION_STATE_INVALID","state transition cannot be replayed out of order")
	var participating: Dictionary = state.begin_participation("conversation.grocer-maker")
	check(participating.ok and participating.conversation.state=="participating","approaching advances to participating")
	var ended: Dictionary = state.end("conversation.grocer-maker")
	check(ended.ok and ended.conversation.state=="ended","participating conversation ends")
	check(state.conversation_for_actor("resident.grocer").is_empty() and state.conversation_for_actor("resident.maker").is_empty(),"end releases both participants")

	var cancel_invite: Dictionary = state.invite("conversation.cancel","resident.grocer","resident.neighbor","space.village")
	check(cancel_invite.ok,"released resident can be invited again")
	var cancelled: Dictionary = state.cancel("conversation.cancel")
	check(cancelled.ok and cancelled.conversation.state=="cancelled","cancel releases invited conversation")
	check(state.conversation_for_actor("resident.neighbor").is_empty(),"cancel clears invitee occupancy")

	check(state.invite("conversation.leave","resident.grocer","resident.maker","space.shop").ok,"shop conversation starts")
	var released_space: Array = state.release_space("space.shop")
	check(released_space==["conversation.leave"],"leaving space releases conversations in that space")
	check(state.projection().conversations.is_empty(),"space release clears occupancy")

	check(state.invite("conversation.actor-release","actor.player","resident.neighbor","space.village").ok,"player can share deterministic conversation occupancy")
	var released_actor: Array = state.release_actor("actor.player")
	check(released_actor==["conversation.actor-release"] and state.conversation_for_actor("resident.neighbor").is_empty(),"actor release frees the other participant too")

	check(state.invite("conversation.one","resident.grocer","resident.maker","space.village").ok,"first disjoint conversation starts")
	check(state.invite("conversation.two","actor.player","resident.neighbor","space.village").ok,"second disjoint conversation starts")
	check(state.projection().conversations.size()==2,"disjoint actors may hold separate conversations")
	check(state.clear_all()==2 and state.projection().conversations.is_empty(),"session reset clears every transient occupancy")

	var unknown: Dictionary = state.invite("conversation.unknown","resident.missing","resident.neighbor","space.village")
	check(not unknown.ok and unknown.error_code=="CONVERSATION_PARTICIPANT_INVALID","unknown actor cannot occupy conversation")
	var self_invite: Dictionary = state.invite("conversation.self","resident.neighbor","resident.neighbor","space.village")
	check(not self_invite.ok and self_invite.error_code=="CONVERSATION_PARTICIPANT_INVALID","resident cannot converse with itself")
	var bad_space: Dictionary = state.invite("conversation.bad-space","resident.grocer","resident.maker","village")
	check(not bad_space.ok and bad_space.error_code=="CONVERSATION_SPACE_INVALID","conversation space must be a real space id")

	finish()

func finish() -> void:
	print("RESIDENT_CONVERSATION_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
