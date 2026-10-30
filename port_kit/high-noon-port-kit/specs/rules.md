# High Noon: gameplay rules

This is the behaviour of the web prototype (`prototype/highnoon.html`), written out so the Godot version can match it. Numbers are in the prototype's 320×180 coordinate space; the Godot build uses 640×360, so double every position and size. Times are in seconds unless stated. When this document and the prototype disagree, the prototype is right.

## 1. Screen and input

- Landscape only, 16:9. The street's ground line is y = 160 on Main Street and y = 148 on the train.
- One input: a tap (or click) at a point fires a bullet that lands there instantly.
- Touch is more forgiving than a mouse: enemy, bottle and runner hit areas grow by 6 px on touch and 3 px with a mouse; the sign rope by 7 and 4; the coupling pin by 7 and 4.
- Keyboard (desktop testing only): Escape or P pauses, R restarts, Space or Enter fires in duels.

## 2. Bullets, cylinder and reload

- Each level gives a fixed number of bullets (`bullets` in `levels.json`). Par (`par`) is the bullet count for the second star.
- The equipped gun has a cylinder (`cyl` in `weapons.json`). When the cylinder empties and bullets remain, the gun reloads for `reload` seconds; taps during a reload do nothing except a short "Reloading" message.
- Guns differ only in cylinder, reload time and recoil. Bullet counts never change, so puzzles stay fair with any gun.

## 3. Hearts and failing

- Three hearts per attempt. An outlaw who finishes his draw ring fires and costs one heart. At zero hearts the level is lost.
- Out of ammo: when bullets reach 0 and outlaws remain, with no sign falling, no explosion in progress and no flatcar rolling away, the level is lost after 0.9 s.
- Shooting a hostage, or letting a hostage be caught in a blast or carried off on a flatcar, loses the level immediately.
- A level is won 0.7 s after the last outlaw and bottle are gone.

## 4. Outlaws

Each outlaw cycles through these states:

| State | What happens |
|---|---|
| hidden | Behind cover; cannot be hit. Waits, then rises. First wait: 0.7 + 0.55 × (outlaw's index) + up to 0.8. Later waits: (0.8 + up to 1.4) × the level's `pace`. |
| rise | 0.16 s to pop out. Can be hit once mostly exposed. |
| aim | The draw ring runs for the level's `aim` time (× 1.3 for hostage-takers). If it runs out, he fires: one heart lost. |
| drop | 0.16 s back into cover, then hidden again. |
| dead | Falls over and fades. |

How they peek, by `side` in the level data:
- **up**: crouched behind cover with only a hat tip showing, rising 12 px above it.
- **left / right**: slides sideways out of cover by half the cover's width plus 5.
- **hide**: never comes out on his own. Only TNT, a falling sign or losing his cover can reach him.
- **window**: rises from below the sill inside a window frame.
- **runner** (`run: [from, to]`): at the end of each wait, 55% chance to dash to the other cover over 1.5 s, fully exposed and not shooting.
- **hostage** (`hostage: x`): stands behind a townsperson and leans 13 px to a random side. He can only be hit while leaning; the hostage's body (slightly smaller on touch) is always in front of him.

If an outlaw's cover is destroyed, he stays exposed and keeps aiming, with 1.2 × the aim time.

## 5. What a shot hits, in order

1. Thrown dynamite in the air (Iron Eli).
2. A hostage's body: the level is lost.
3. The train's coupling pin (levels with `pin: true`).
4. Runners crossing in the open.
5. Cover: a TNT barrel explodes; anything else absorbs the bullet ("Wasted bullet").
6. A hanging sign's rope drops the sign; the sign board itself absorbs the bullet.
7. Outlaws (only when not hidden), first exact, then with the touch margin.
8. Bottles (tutorial).
9. Otherwise a miss: dust, a ricochet sound and a red crosshair.

## 6. The environment

- **TNT barrel:** kills every non-window outlaw whose centre is within 38 px of the barrel; loses the level if a hostage is within 38; destroys other cover within 34 (wagons survive); sets off other TNT within 34 after 0.15 s (chain reactions); clears bottles within 40.
- **Hanging sign:** shooting the rope drops it (gravity 0.35 px per frame squared). It lands on a wagon if one is below, and kills any outlaw whose centre is within 14 px of the sign's edges.
- **Coupling pin (train):** cutting it sends the flatcar rolling back, accelerating by 0.035 px per frame up to 3.2. Everything on the flatcar moves with it; outlaws on it stop fighting and count as defeated once it is 170 px away. A hostage on the flatcar loses the level once it is 50 px away.
- **Tunnels (train, `tunnel: {every, dark}`):** every `every` seconds, darkness sweeps in over 0.35 s, stays for `dark` seconds, then sweeps out over 0.35 s. In darkness only the outlaws' draw rings glow.

## 7. Duels

- Phases per round: intro (1.1 s), wait (1.5 to 3.9 s), draw, outcome (1.3 s).
- **Wait:** firing now is a foul and costs a heart. With `fakes`, the boss may twitch once to bait you.
- **Draw:** a bell and "DRAW!". You must hit the boss inside a target zone 56 × 62 px around him (6 px more on touch). A miss wastes the shot but you may fire again. He fires after `react[round]` seconds, plus 0.16 s on touch or 0.1 with a mouse to allow for aiming.
- The boss has `hp` hits; you have three hearts.
- **Twists:** `cards` (Black Jack flips a card every 0.55 to 1.05 s; draw only on the ace), `smoke` (engine smoke drifts across), `tunnelDuel` (alternate rounds in darkness, boss shown only as a silhouette), `lastStand` (from the third round the bell rings twice; only the second counts, 0.6 to 1.5 s after the first).

## 8. Iron Eli (Main Street, level 10): a three-stage boss

No checkpoints: losing anywhere sends you back to stage 1.

1. **Crack the armour.** He runs between the crate (cover 2) and the wagon (cover 3), always moving when his wait ends. Bullets ping off. The TNT blast and the falling sign each crack the armour once; both are needed, in either order, and the same tool twice does nothing. A used TNT barrel is replaced after 3 s; the sign is hung back up after 3 s if it fell without cracking him.
2. **Run him down.** Three hits. He appears in turn at window 0, the wagon, window 3 and barrel 0. Bullets are topped up to 16. After the first hit, two gunmen join (window 1 and the barrel at cover 4). After the second, each time he rises he throws a stick of dynamite instead of firing: it flies for 1.7 s on an arc towards the player, can be shot out of the air, and costs a heart if it lands. His aim time shrinks to 0.85 × then 0.7 ×.
3. **The final draw.** A duel with `hp: 2`, `react: [0.6, 0.55, 0.5]`, fakes, and the last stand from round three.

## 9. Stars, assistance and progression

- **Stars:** one for winning, one for using no more bullets than par, one for not losing a heart. Duels: one for winning, one with at least two hearts left, one with all three.
- **Assisted clears:** any help (an ad reward, a Sheriff's Pass reward, or a clue on that puzzle) caps the clear at two stars. A free retry is always an unassisted attempt.
- **Unlocks:** winning level N unlocks level N + 1 in that bounty. Capturing a bounty's boss (level 10) unlocks the next bounty's poster. Bounties without levels yet are shown as locked.
- **Desk status (home screen):** the next playable uncaptured bounty, or "All available bounties captured" with the next coming-soon outlaw. Never fall back to the first bounty.

## 10. Bounty Dollars

- Each level pays by its best star count: 0, 20, 40, 60 for 0 to 3 stars (`payouts_by_stars.json`), doubled for bosses. Replays pay only the improvement.
- Capturing a bounty's boss for the first time also pays the poster reward (`bounty` in `chapters.json`). It is never paid twice.
- Bounty Dollars buy guns (once their outlaw is captured), gun finishes and avatar parts. Nothing purchasable changes difficulty.

## 11. Second Chance (rewarded ads)

One offer per attempt, always beside a free retry:

| Situation | Offer |
|---|---|
| Arcade level, out of ammo, exactly one outlaw left | +1 bullet |
| Puzzle level, any failure | Clue (first a written hint, then a glow on the key prop) |
| Iron Eli, lost in stage 2 or 3 | Retry from that stage with full hearts |
| Iron Eli, lost in stage 1 | Nothing |
| Single-stage duel, lost | Keep the rounds won, replay the lost one |
| Shooting a hostage | Nothing on arcade levels; a clue on puzzle levels |

Using any offer makes the clear assisted. The Sheriff's Pass grants the same rewards instantly without a video, with the same limits.

## 12. The tutorial (Main Street, level 1)

1. "Tap a bottle." An arrow points at the first bottle; the outlaw stays hidden until all four bottles are gone.
2. "Wait for him to pop up."
3. When he starts aiming: "Now! Shoot!"
4. If he fires first: "Too slow. Wait again."

## 13. Feedback that makes shooting feel good

Recoil kick on the gun, a muzzle flash and smoke, a three-frame freeze and a white flash on a hit, the outlaw's hat flying off, a short haptic tap on every shot and a stronger one on a hit, a red crosshair and a ricochet sound on a miss, brass casings ejected on reload, screen shake on explosions.
