extends Control
## Start screen: pick the number of bots and their difficulty.

signal start_requested(bots: int, difficulty: String)
signal resume_requested(path: String)
signal replay_requested(path: String)

const UI := preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const LeaderboardPanel := preload("res://scripts/ui/leaderboard_panel.gd")
const HistoryPanel := preload("res://scripts/ui/history_panel.gd")
const Recorder := preload("res://scripts/game/recorder.gd")

const RULES_TEXT := """GOAL
Be the first to play all your cards.

YOUR TURN
Play a card of the required suit, or tap the bank to draw one card (that ends your turn).

SPECIAL CARDS
7 - next player draws 2. A 7 can be played on any Lion.
Lion - next player draws 4. Red Lion goes on red cards, black on black. After a Lion, play any card of its color.
Penalties stack: answer a 7 or Lion with another 7 or Lion (any suit) to pass the total on.
2 - goes on anything and slides under the pile; nothing changes.
J - you choose the next suit. A J can go on another J.
Ace (Stop) - skips the next player. An Ace can go on another Ace.

SCORING
Points for your finishing place, multiplied for more opponents and for Normal difficulty. Finish without ever drawing from the bank (a CLEAN FINISH) for 3000 bonus points. Forced penalty draws do not count against you.

ENDING
In a 2-player game you cannot finish on an Ace, and a last 7 or Lion only wins if the opponent cannot answer it."""

var bots := 2
var difficulty := "normal"
var notice := "" # shown above the buttons, e.g. why a game could not be resumed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background())

	var box := UI.column()
	add_child(box)
	box.add_child(UI.title("J-COMMAND", UI.FONT_DISPLAY))
	box.add_child(UI.tagline("Shed your cards. Stop the others."))
	box.add_child(UI.spacer(20))

	var card := UI.panel()
	box.add_child(card[0])
	card[1].add_child(UI.heading("Opponents"))
	card[1].add_child(UI.choice_row(["1", "2", "3"], 1, func(i): bots = i + 1))
	card[1].add_child(UI.spacer(6))
	card[1].add_child(UI.heading("Difficulty"))
	card[1].add_child(UI.choice_row(["Easy", "Normal"], 1, func(i): difficulty = ["easy", "normal"][i]))

	box.add_child(UI.spacer(10))
	if notice != "":
		box.add_child(UI.hint(notice, 900))
	var saved := Recorder.in_progress()
	if not saved.is_empty():
		var path: String = saved["path"]
		box.add_child(UI.button("Resume game", UI.Variant.PRIMARY, func(): resume_requested.emit(path), true))
	box.add_child(UI.button("PLAY", UI.Variant.PRIMARY, func(): start_requested.emit(bots, difficulty), true))
	box.add_child(UI.button("Leaderboard", UI.Variant.SECONDARY, _show_leaderboard))
	box.add_child(UI.button("History", UI.Variant.SECONDARY, _show_history))
	box.add_child(UI.button("How to play", UI.Variant.SECONDARY, _show_rules))
	box.add_child(UI.button("Settings", UI.Variant.TERTIARY, _show_settings))


func _show_rules() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(UI.background())
	var page := UI.scroll_page("How to play", "Close", overlay.queue_free)
	overlay.add_child(page["scroll"])
	overlay.add_child(page["header"])
	overlay.add_child(page["footer"])
	page["content"].add_child(UI.body(RULES_TEXT, 900))
	add_child(overlay)


func _show_leaderboard() -> void:
	var p := LeaderboardPanel.new()
	p.closed.connect(p.queue_free)
	add_child(p)


func _show_history() -> void:
	var p := HistoryPanel.new()
	p.closed.connect(p.queue_free)
	p.replay_requested.connect(func(path): replay_requested.emit(path))
	add_child(p)


func _show_settings() -> void:
	var p := SettingsPanel.new()
	p.closed.connect(p.queue_free)
	add_child(p)
