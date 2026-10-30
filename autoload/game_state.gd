extends Node
## Game data loaded from the port kit, plus the prototype's rule functions
## (applyWin, starsFor, offerFor, chapterOpenFor, huntStatusFor, buyItem).

const KIT := "res://port_kit/high-noon-port-kit/"
const DATA_DIR := KIT + "data/"
const MUSIC_DIR := KIT + "audio/music/"
const GEOMETRY := "res://data/geometry.json"

## chapters.json names a scene; levels.json keys its level lists differently.
const SCENE_LEVEL_KEY := {"street": "main_street", "train": "train"}
## Boss ids in levels.json -> sprite name prefixes in art/sprites.
const BOSS_SPRITES := {"BOSS": "black_jack", "BOSS_B": "iron_eli", "SMOKEY": "smokey_pete", "COLE": "cole_haggerty"}
## Levels built for the feel-test milestone, as [chapter, level].
## Chapters ported so far (Main Street). The train comes with the parity milestone.
const BUILT_CHAPTERS := [0]

var chapters: Array = []
var level_lists: Dictionary = {}
var scenes: Dictionary = {}
var cover_sizes: Dictionary = {}
var weapons: Array = []
var weapons_by_id: Dictionary = {}
var payouts: Array = []
var ranks: Array = []
var trophies: Array = []
var avatar_options: Variant = null
## Hitboxes, peek distances and radii (game-owned data, not from the kit).
var geometry: Dictionary = {}

var touch_mode := OS.has_feature("mobile")


func _ready() -> void:
	chapters = _load("chapters")
	level_lists = _load("levels")
	scenes = _load("scenes")
	cover_sizes = _load("cover_sizes")
	weapons = _load("weapons")
	payouts = _load("payouts_by_stars")
	ranks = _load("ranks")
	trophies = _load("trophies")
	avatar_options = _load("avatar_options")
	geometry = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY))
	for w in weapons:
		weapons_by_id[w.id] = w


func _load(name: String) -> Variant:
	var path := DATA_DIR + name + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed != null, "Could not parse " + path)
	return parsed


var progress: Dictionary:
	get:
		return SaveManager.data.progress


func save() -> void:
	SaveManager.save_game()


# ---------- data lookups ----------

func levels_for(ci: int) -> Variant:
	var ch: Dictionary = chapters[ci]
	if not ch.playable or ch.scene == null:
		return null
	return level_lists.get(SCENE_LEVEL_KEY.get(ch.scene, ""), null)


func level(ci: int, li: int) -> Dictionary:
	return levels_for(ci)[li]


func scene_for(ci: int) -> Dictionary:
	return scenes[chapters[ci].scene]


func equipped_weapon() -> Dictionary:
	return weapons_by_id[progress.inv.equip.gun]


func is_built(ci: int, li: int) -> bool:
	var lvls: Variant = levels_for(ci)
	return BUILT_CHAPTERS.has(ci) and lvls != null and li >= 0 and li < lvls.size()


## Playtest mode opens every level, like the prototype's #playtest (a saved setting).
func playtest() -> bool:
	return SaveManager.get_setting("playtest", true)


func level_open(ci: int, li: int) -> bool:
	return is_built(ci, li) and (playtest() or li + 1 <= int(chapter_progress(progress, ci).unlocked))


## Puzzle clue level: 0 none, 1 written clue, 2 the key prop glows (rules.md §11).
func hint_level(ci: int, li: int) -> int:
	return int(progress.get("hints", {}).get("%d:%d" % [ci, li], 0))


func raise_hint_level(ci: int, li: int) -> void:
	if not progress.has("hints"):
		progress.hints = {}
	progress.hints["%d:%d" % [ci, li]] = mini(2, hint_level(ci, li) + 1)
	save()


# ---------- rules (ported from the prototype; see specs/reference_code_from_prototype.js) ----------

static func chapter_progress(pg: Dictionary, c: int) -> Dictionary:
	while pg.ch.size() <= c:
		pg.ch.append(null)
	if pg.ch[c] == null:
		pg.ch[c] = {"unlocked": 1, "stars": {}}
	return pg.ch[c]


static func stars_in(pg: Dictionary, c: int, l: int) -> int:
	if c >= pg.ch.size() or pg.ch[c] == null:
		return 0
	return int(pg.ch[c].stars.get(str(l), 0))


func apply_win(pg: Dictionary, c: int, l: int, stars: int, o: Dictionary) -> Dictionary:
	var ch := chapter_progress(pg, c)
	var before := stars_in(pg, c, l)
	var best := maxi(before, stars)
	var pay := (int(payouts[best]) - int(payouts[before])) * (2 if o.boss else 1)
	var capture_now: bool = o.last and before == 0
	if capture_now:
		pay += int(o.bounty)
	ch.stars[str(l)] = best
	ch.unlocked = maxi(int(ch.unlocked), mini(int(o.count), l + 2))
	pg.bucks += pay
	pg.stats.earned += pay
	if before == 0:
		pg.stats.levels += 1
		if o.boss:
			pg.stats.bosses += 1
	if stars == 3 and before < 3:
		pg.stats.perfect += 1
	return {"pay": pay, "capture_now": capture_now, "before": before, "best": best}


static func stars_for(lv: Dictionary, o: Dictionary) -> int:
	var s: int
	if lv.get("duel", false):
		s = 1 + (1 if o.hearts >= 2 else 0) + (1 if o.hearts == 3 else 0)
	else:
		s = 1 + (1 if o.used <= lv.par else 0) + (0 if o.damaged else 1)
	return mini(2, s) if o.get("assisted", false) else s


static func buy_item(pg: Dictionary, cost: int, give: Callable) -> bool:
	if cost < 0 or pg.bucks < cost:
		return false
	pg.bucks -= cost
	give.call(pg)
	return true


static func offer_for(lv: Dictionary, reason: String, alive: int, used: bool, stage: int = 1) -> Variant:
	if used:
		return null
	if reason == "hostage":
		return "hint" if lv.get("puzzle", false) else null
	if lv.get("eli", false):
		return "checkpoint" if stage >= 2 and reason != "ammo" else null
	if lv.get("duel", false):
		return null if reason == "ammo" else "continue"
	if lv.get("puzzle", false):
		return "hint"
	if reason == "ammo" and alive == 1:
		return "bullet"
	return null


func collected_in(pg: Dictionary, i: int) -> bool:
	var lvls: Variant = levels_for(i)
	return lvls != null and stars_in(pg, i, lvls.size() - 1) > 0


func chapter_open_for(pg: Dictionary, i: int, playtest: bool) -> bool:
	return levels_for(i) != null and (playtest or i == 0 or collected_in(pg, i - 1))


func hunt_status_for(pg: Dictionary, playtest: bool) -> Dictionary:
	for i in chapters.size():
		if levels_for(i) == null:
			return {"done": true, "next": i, "ch": null}
		if not collected_in(pg, i):
			return {"ch": i, "done": false, "next": null} if chapter_open_for(pg, i, playtest) else {"done": true, "next": i, "ch": null}
	return {"done": true, "next": null, "ch": null}
