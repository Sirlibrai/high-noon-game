# HIGH NOON: Design Brief v2 (puzzle-first)

**For:** Claude Code, working in the existing Godot 4 project.
**Supersedes:** `port_kit/specs/rules.md` and the earlier "Version 1.0" brief wherever they conflict. The HTML prototype remains a reference for feel and existing systems, not the target.

**The promise:** Every bullet counts. Every outlaw has a weakness. The smartest gunslinger wins.

---

## 1. How to use this brief

1. Read this brief, the current Godot project, `port_kit/style/style_guide.md` and the scale guide image.
2. Do **not** move away from Godot, rebuild the project, or change the art direction.
3. Produce a short gap analysis: what already exists in the Godot build, what changes, what is new.
4. Propose the smallest safe plan for Milestone 1 (section 12), then implement it after approval.
5. Never silently change a puzzle to make it easier to build. If a puzzle is unreliable or unsolvable, say why and propose a fair alternative.

---

## 2. Identity: a puzzle game disguised as a Western shooter

- **Campaign:** puzzle-first. Roughly 80% observation and planning, 20% execution and timing. Most levels have a clever solution that the player discovers: "I see it, that's how I beat them."
- **One duel per bounty:** the bounty's final boss ends in a reaction duel, as the dramatic climax. Everything before it is a puzzle.
- **Survival:** the reflex mode. Waves of outlaws, high scores, pure shooting skill. (The v1.0 brief called this "Arcade"; the office already has a target for it labelled Survival.)
- **Daily Bounty:** one hand-made puzzle a day.

---

## 3. Core campaign rules

### Observation start
- Levels begin in a **safe observation state**: outlaws are visible and may move along their routes, but they do not attack until the player's first shot.
- Levels that are deliberately timed must say so clearly on the intro card (for example "They're already shooting").
- Enemy behaviour in the campaign is **deterministic**: fixed routes, fixed timings, no randomness. The same level always plays the same way.

### Ammunition
- Every level has a fixed bullet allowance, and at least one valid solution within it.
- Bullets are never sold and never given by ads in the campaign.

### Hearts
- Three hearts. An outlaw telegraphs every attack with a visible draw ring. Tutorial levels have no attacks.

### Failure
- Out of bullets with the objective incomplete; all hearts lost; a civilian harmed; the objective becoming impossible.
- Free, instant retry, always.

### Stars
| Star | Condition |
|---|---|
| 1 | Complete the level |
| 2 | Complete without losing a heart |
| 3 | Use no more bullets than par, with no hints or assistance |

- Any assistance (a clue, an ad reward, a Sheriff's Pass reward) caps the clear at two stars. A free retry is always an unassisted attempt.
- Par is set per level so that the clever solution earns the third star. Alternative solutions that meet par also earn it.

### Hints
- Two steps per puzzle level: first a written clue, then a glow on the key object. Authored for each level.

---

## 4. Story: Dustwater

- **Town:** Dustwater, once a prosperous trading town. Iron Eli's gang robbed the bank, drove out the sheriff and took over the saloon.
- **Bounty:** $2,500. Poster: "WANTED: IRON ELI. DEAD OR ALIVE. $2,500. Dustwater's got a problem. And you're the solution."
- Storytelling is light: one line on each level's intro card, one line on its result screen, a parting line from each boss. No long cutscenes.

---

## 5. Bounty 1: the Iron Eli Gang (Main Street, 10 levels)

| # | Level | Bullets | Par | Objective | Intended solution and lesson |
|---|---|---|---|---|---|
| 1 | Target Practice | 3 | 2 | Knock down 3 bottles | Tutorial, no enemies. Bottles can be shot one by one (3 bullets). Shooting a hanging bucket drops it onto two bottles at once, which earns par. Prompts: "Tap to shoot.", "Every bullet counts.", "Sometimes there's a smarter shot." |
| 2 | Powder Keg | 1 | 1 | 2 outlaws | Both stand beside a TNT barrel. One shot at the TNT. Lesson: hazards defeat groups. |
| 3 | Crossfire | 3 | 3 | 3 outlaws | One in an upstairs window (ducks below the sill), one behind a barrel (rises to aim), one crossing the street (pauses at a fixed spot). Each has a predictable vulnerability window. Lesson: observe before shooting. |
| 4 | Chain Reaction | 1 | 1 | 3 outlaws | A sign hangs above a TNT barrel. Shoot its chain: the sign falls, hits the barrel, the blast clears all three. Lesson: chain reactions. |
| 5 | Black Jack (mini-boss) | 3 | 3 | Black Jack and 2 henchmen | Three phases, see section 6. |
| 6 | The Wrong Barrel | 1 | 1 | 2 guards | Three barrels, only one is TNT, marked by its fuse and lettering. Must be discoverable by looking, never a guess. |
| 7 | Moving Target | 1 | 1 | 2 patrolling outlaws | Both patrol fixed routes and pass the TNT together at regular intervals. Fire when both are inside the blast. Forgiving window. Lesson: timing and position. |
| 8 | The Hostage | 2 | 2 | 1 outlaw holding a bank clerk | Shoot a hanging lantern (or bell) beside them: the outlaw flinches away from the clerk. Then shoot him. Lesson: order matters. |
| 9 | No Second Chances | 2 | 2 | 4 outlaws | Two by a TNT barrel, two nearby. The first explosion sends the second pair running for cover under a hanging sign; drop it on them. Lesson: plan the whole solution before firing. |
| 10 | Iron Eli (final boss) | 4 | 4 | Iron Eli | Three stages, see section 6. |

Each level's intro card shows one story line; its result screen shows the next beat (for example level 2: "The blast alerts the gang's lookouts.").

---

## 6. The bosses

### Black Jack (level 5, mini-boss)
Black Jack is Iron Eli's lieutenant: black hat, red waistcoat, an ace in his hatband, theatrical. The v1.0 brief's "Red Jack" is the same character; keep the name Black Jack.

1. **The henchmen:** two henchmen beside a TNT barrel. One shot clears them.
2. **Break the cover:** Black Jack hides behind a crate under a hanging lantern hook (or sign). Shoot the chain; the falling object smashes the crate.
3. **The ace:** exposed, Black Jack flips cards on a barrel. He is only vulnerable while the ace is showing, a generous window of about 2 seconds. This is a timing test that rewards patience, not a twitch duel. Shooting on another card wastes the bullet.

Parting line: "Eli's waiting at the bank. You won't get near him."

### Iron Eli (level 10, final boss)
No checkpoints: losing restarts the fight from the beginning (free). The optional ad offers a retry from the stage reached, which caps the clear at two stars.

1. **The last guards:** two henchmen by a TNT barrel. One shot.
2. **The iron defence:** Eli wears a breastplate that bullets can't penetrate. He moves between cover on a fixed pattern. Crack the armour twice, once with a second TNT barrel when he passes it and once with the hanging sign when he stands beneath it. Each tool works once on him, so both are needed.
3. **The final draw:** the bounty's one duel. Best of three, with a generous aim zone. From the third round, the bell rings twice and only the second ring counts.

Victory: Eli's poster gets the CAPTURED stamp, "BOUNTY COLLECTED: $2,500", the townspeople return, the next poster unlocks and a new gun appears at the Gunsmith.

The existing Godot Iron Eli (thrown dynamite, reinforcements, a three-hit chase) is reflex-heavy. Rework it to the version above, reusing its armour, duel and stage systems.

---

## 7. Gunsmith and economy

- Guns are **earned**: each final boss unlocks a gun at the Gunsmith, which the player then buys with Bounty Dollars. Real money never buys a gun or a gameplay advantage.
- The first unlocked gun must be affordable from Iron Eli's $2,500 with money to spare, so the first purchase happens straight away.
- Guns may feel different (reload speed, recoil, presentation), but campaign puzzles normalise anything that could break them: bullet counts never change, and no gun makes a puzzle impossible or trivial.
- **Bounty Dollars** come from levels (by stars, improvements only), bosses, the Daily Bounty and Survival milestones. A boss's bounty is paid once.
- Real-money purchases are **cosmetic only**: gun finishes, engravings, grips, muzzle effects, reload animations, later visual filters. They never change damage, accuracy, ammunition, hit areas, timings, blast radii or puzzles, and never obscure targets.

---

## 8. Modes

| | Campaign | Daily Bounty | Survival |
|---|---|---|---|
| Style | Puzzles, one duel per bounty | One hand-made or validated puzzle per day, same for everyone, fixed date boundary | Waves of outlaws, reflexes |
| Free retries | Unlimited | One ranked attempt, then unranked practice | No |
| Hints | Ad or Pass, caps stars | Ad or Pass, makes the attempt unranked | No |
| Continues | Boss stage retry only | No | One revive per run, scored separately |
| Leaderboard | No | Yes, unassisted only | Yes, no-continue runs only |

Never generate a daily puzzle without proving it is solvable.

---

## 9. Monetisation

- **Rewarded ads only, always optional:** clues; the boss stage retry; one Survival revive per run; and "double your bounty" offered after a win (capped at a few per day).
- **No interstitial ads,** no ads during puzzles, no ads required to play the Daily Bounty.
- **Sheriff's Pass:** a one-time purchase that turns rewarded offers into instant taps, with the same limits and the same two-star cap, plus a cosmetic thank-you.
- **Cosmetic purchases** as in section 7.
- Never: paid bullets, paid boss shortcuts, artificial difficulty to drive ads, misleading prices.
- Build these behind the existing mock ad provider; real ad and payment SDKs come later.

---

## 10. Presentation

- **Art:** the painted storybook style, following `style_guide.md`.
- **Scale guide:**
  - Standing outlaws about 22% of screen height, barrels about 13%.
  - Window outlaws 70% of the window, upper body only, cropped at the sill.
  - Outlaws behind cover drawn behind it, with only head, hat and gun showing.
  - The revolver about 20%, tucked into the corner.
  - Scale gameplay distances with it.
- **Grounding:** soft contact shadows under every character and prop.
- **Hanging objects** must visibly hang from something (a beam, a bracket) by visible chains or rope.
- **HUD:** painted wooden panels, a Western display font licensed for commercial use, the avatar portrait, hearts, bullets, Bounty Dollars, the level name, and one pause button for Resume, Restart, Sound, Music and Levels. No pixel-art leftovers anywhere, including intro cards and result screens.
- **Sheriff's Office:** keep the current design and hotspots. Add the warm "lit when chosen" effect: the room is softly dim, and a tapped object brightens briefly before its screen opens. One tap, never two, and no reliance on hover.
- **Feedback:** muzzle flash, recoil, glass shattering, wood splintering, explosions with a visible blast radius, hit reactions, short reloads, clear sounds. Nothing slow enough to delay play.

---

## 11. Technical requirements

- Godot 4, GDScript, landscape only, the existing art-swappable structure (manifest, `geometry.json`, swappable sprites, skins hooks).
- Levels stay data-driven. Extend the level format with:
  - **Objectives** (eliminate all, eliminate specific targets, protect civilians).
  - **Triggers and chain reactions:** an object falling onto TNT detonates it; a distraction makes an outlaw move; an explosion sends survivors to new positions.
  - **Patrol routes** with fixed timings.
  - **Boss stages,** the observation start, story lines, par and authored hints.
- One shared engine for Campaign, Daily Bounty and Survival, with mode rules configurable.
- Saves stay local for now with the logic separate from storage, ready for iCloud.
- Safe areas, touch hit areas aligned with visuals, smooth on iPhone.

### Tests
- Every level loads, and its intended solution wins at par.
- Deterministic timings: the same inputs always produce the same result.
- Triggers and chain reactions fire reliably; cover blocks shots correctly; civilians are protected.
- Boss stages transition correctly; restart is from stage 1.
- Bounties pay once; the next poster and the gun unlock; purchases deduct correctly; saves survive restarts.
- Cosmetics never change gameplay; assisted clears never exceed two stars; assisted scores never enter leaderboards.
- Report clearly what was tested automatically and what still needs playing on a phone.

---

## 12. Milestones

1. **Puzzle foundation:** the observation start, the new level format (objectives, triggers, patrols, story lines), the new star rules and levels 1 to 4. Success: players understand the puzzle idea and enjoy the first four levels.
2. **Black Jack:** the three-phase mini-boss.
3. **The full bounty:** levels 6 to 10, the reworked Iron Eli, Dustwater's story beats, the CAPTURED stamp and the $2,500 bounty.
4. **Gunsmith progression:** capturing Eli unlocks a gun; buy it and equip it straight away.
5. **The train bounty:** redesign the Coal Gang's ten levels puzzle-first in the same way before porting them.
6. **Retention:** Survival and the Daily Bounty.
7. **Commercial systems:** rewarded ads, the Sheriff's Pass, cosmetic purchases, analytics.
8. **Polish and TestFlight.**

New art (Black Jack, Iron Eli, the hostage, the bucket, lantern and other new props) is produced alongside Milestones 1 to 3, using the existing recipe. Placeholders are fine until it arrives.
