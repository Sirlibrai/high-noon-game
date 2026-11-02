extends Node
## Game data loaded from the port kit, plus the prototype's rule functions
## (applyWin, starsFor, offerFor, chapterOpenFor, huntStatusFor, buyItem).

const KIT := "res://port_kit/high-noon-port-kit/"
const DATA_DIR := KIT + "data/"
const MUSIC_DIR := KIT + "audio/music/"
const GEOMETRY := "res://data/geometry.json"
const CHAPTERS_EXTRA := "res://data/chapters.json"
## The game's own campaign levels (data/levels/<key>.json) replace the kit's list for that scene.
const CAMPAIGN_DIR := "res://data/levels/"

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
## The prototype's cover sizes, before geometry.json scales them: levels.json positions are measured with these.
var kit_cover_sizes: Dictionary = {}
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
	var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHAPTERS_EXTRA))  # the posters' names and titles
	for i in mini(chapters.size(), extra.chapters.size()):
		chapters[i].merge(extra.chapters[i], true)
	level_lists = _load("levels")
	for key in level_lists.keys():
		var own: String = CAMPAIGN_DIR + str(key) + ".json"
		if FileAccess.file_exists(own):
			level_lists[key] = JSON.parse_string(FileAccess.get_file_as_string(own))[key]
	scenes = _load("scenes")
	cover_sizes = _load("cover_sizes")
	weapons = _load("weapons")
	payouts = _load("payouts_by_stars")
	ranks = _load("ranks")
	trophies = _load("trophies")
	avatar_options = _load("avatar_options")
	geometry = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY))
	# The painted scenes' ground lines and windows (geometry.json) replace the prototype's.
	var overrides: Dictionary = geometry.get("scenes", {})
	for key in overrides:
		if scenes.has(key):
			scenes[key].merge(overrides[key], true)
	kit_cover_sizes = cover_sizes.duplicate(true)
	# Cover at the painted plane's scale (geometry.json) replaces the prototype's sizes.
	for key in geometry.get("cover_sizes", {}):
		if cover_sizes.has(key):
			cover_sizes[key] = geometry.cover_sizes[key]
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


## Stars (brief v2 §3): one for the clear, one for losing no heart, one for par with no hints or
## assistance. Assistance caps a clear at two. Duels count hearts, as they have no par.
static func stars_for(lv: Dictionary, o: Dictionary) -> int:
	var assisted: bool = o.get("assisted", false)
	var s: int
	if lv.get("duel", false):
		s = 1 + (1 if o.hearts >= 2 else 0) + (1 if o.hearts == 3 else 0)
	else:
		s = 1 + (0 if o.damaged else 1) + (1 if o.used <= lv.par and not assisted else 0)
	return mini(2, s) if assisted else s


static func buy_item(pg: Dictionary, cost: int, give: Callable) -> bool:
	if cost < 0 or pg.bucks < cost:
		return false
	pg.bucks -= cost
	give.call(pg)
	return true


static func offer_for(lv: Dictionary, reason: String, _alive: int, used: bool, stage: int = 1) -> Variant:
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
	return null  # bullets are never sold or given by ads (brief v2 §3)


func collected_in(pg: Dictionary, i: int) -> bool:
	var lvls: Variant = levels_for(i)
	return lvls != null and stars_in(pg, i, lvls.size() - 1) > 0


func chapter_open_for(pg: Dictionary, i: int, playtest: bool) -> bool:
	return levels_for(i) != null and (playtest or i == 0 or collected_in(pg, i - 1))


func caught_count(pg: Dictionary) -> int:
	return range(chapters.size()).filter(func(i): return collected_in(pg, i)).size()


func chapter_stars(pg: Dictionary, i: int) -> int:
	var lvls: Variant = levels_for(i)
	if lvls == null:
		return 0
	var total := 0
	for k in lvls.size():
		total += stars_in(pg, i, k)
	return total


## The poster the office board shows in the middle (currentHunt): the hunt, or the next bounty coming.
func current_hunt(pg: Dictionary, playtest: bool) -> int:
	var h := hunt_status_for(pg, playtest)
	if h.ch != null:
		return h.ch
	return h.next if h.next != null else chapters.size() - 1


## A wanted poster's state: "captured", "open" (can be hunted), "locked" (has levels, not reached yet)
## or "soon" (no levels yet).
func poster_state(pg: Dictionary, i: int, playtest: bool) -> String:
	if levels_for(i) == null:
		return "soon"
	if not chapter_open_for(pg, i, playtest):
		return "locked"
	return "captured" if collected_in(pg, i) else "open"


## What the desk ledger shows (rules.md §9): continue the next uncaptured bounty, or everything
## available is captured and the next outlaw is coming soon. Never falls back to the first bounty.
func desk_status(pg: Dictionary, playtest: bool) -> Dictionary:
	var st := hunt_status_for(pg, playtest)
	var caught := caught_count(pg)
	if st.ch != null:
		var lvls: Array = levels_for(st.ch)
		var li := mini(int(chapter_progress(pg.duplicate(true), st.ch).unlocked), lvls.size()) - 1
		return {"hunting": true, "ch": st.ch, "level": li, "title": "Continue hunt", "subtitle": "Level %d: %s" % [li + 1, lvls[li].name],
			"caught": caught, "reward": chapters[st.ch].reward}
	var next: Variant = st.next
	return {"hunting": false, "ch": null, "level": null, "title": "All available bounties captured",
		"subtitle": ("%s arrives soon" % chapters[next].who) if next != null else "The frontier is yours", "caught": caught, "reward": null}


func hunt_status_for(pg: Dictionary, playtest: bool) -> Dictionary:
	for i in chapters.size():
		if levels_for(i) == null:
			return {"done": true, "next": i, "ch": null}
		if not collected_in(pg, i):
			return {"ch": i, "done": false, "next": null} if chapter_open_for(pg, i, playtest) else {"done": true, "next": i, "ch": null}
	return {"done": true, "next": null, "ch": null}
