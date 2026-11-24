extends Control
## Start screen: pick the number of bots and their difficulty.

signal start_requested(bots: int, difficulty: String)

const UI := preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

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

ENDING
In a 2-player game you cannot finish on an Ace, and a last 7 or Lion only wins if the opponent cannot answer it."""

var bots := 2
var difficulty := "normal"


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
	box.add_child(UI.button("PLAY", UI.Variant.PRIMARY, func(): start_requested.emit(bots, difficulty), true))
	box.add_child(UI.button("How to play", UI.Variant.SECONDARY, _show_rules))
	box.add_child(UI.button("Settings", UI.Variant.TERTIARY, _show_settings))


func _show_rules() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(UI.background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UI.MARGIN_SCREEN)
	overlay.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UI.SPACE_M)
	margin.add_child(col)
	col.add_child(UI.title("How to play"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var card := UI.panel()
	card[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card[0])
	card[1].add_child(UI.body(RULES_TEXT, 900))
	var close := UI.button("Close", UI.Variant.SECONDARY, overlay.queue_free)
	close.custom_minimum_size.x = 0
	col.add_child(close)
	add_child(overlay)


func _show_settings() -> void:
	var p := SettingsPanel.new()
	p.closed.connect(p.queue_free)
	add_child(p)
