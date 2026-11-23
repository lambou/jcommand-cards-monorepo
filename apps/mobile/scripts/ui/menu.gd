extends Control
## Start screen: pick the number of bots and their difficulty.

signal start_requested(bots: int, difficulty: String)

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
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.33, 0.21)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 34)
	add_child(box)

	var title := Label.new()
	title.text = "J-COMMAND"
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.02))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_heading("Opponents"))
	box.add_child(_choice_row(["1", "2", "3"], 1, func(i): bots = i + 1))
	box.add_child(_heading("Difficulty"))
	box.add_child(_choice_row(["Easy", "Normal"], 1, func(i): difficulty = ["easy", "normal"][i]))

	var play := Button.new()
	play.text = "PLAY"
	play.add_theme_font_size_override("font_size", 72)
	play.custom_minimum_size = Vector2(560, 150)
	play.pressed.connect(func(): start_requested.emit(bots, difficulty))
	box.add_child(play)

	var how := Button.new()
	how.text = "How to play"
	how.add_theme_font_size_override("font_size", 44)
	how.custom_minimum_size = Vector2(560, 100)
	how.pressed.connect(_show_rules)
	box.add_child(how)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.add_theme_font_size_override("font_size", 44)
	settings_btn.custom_minimum_size = Vector2(560, 100)
	settings_btn.pressed.connect(_show_settings)
	box.add_child(settings_btn)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 48)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _choice_row(labels: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (i == selected)
		b.add_theme_font_size_override("font_size", 56)
		b.custom_minimum_size = Vector2(190, 120)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row


func _show_rules() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 50)
	overlay.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var text := Label.new()
	text.text = RULES_TEXT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(900, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 38)
	scroll.add_child(text)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 48)
	close.custom_minimum_size = Vector2(0, 110)
	close.pressed.connect(overlay.queue_free)
	col.add_child(close)
	add_child(overlay)


func _show_settings() -> void:
	var p := SettingsPanel.new()
	p.closed.connect(p.queue_free)
	add_child(p)
