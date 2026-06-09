extends Node

signal card_unlocked(card_id: String)
signal currency_changed(type: String, amount: int)
signal chapter_completed(book_id: String, chapter_id: int)
signal battle_started(mode: String)
signal battle_ended(result: Dictionary)
signal scene_change_requested(scene_path: String)
