// Reference only: the prototype's rule functions and self-tests, for checking the Godot port.

// ---- selftest ----
function selftest() {
    bgMode = 'office'; MUS.play('office');
    state = 'menu';
    const R = [];
    const ok = (name, cond, detail = '') => R.push([name, !!cond, detail]);
    const fresh = () => ({bucks: 0, ch: [], stats: {shots: 0, hits: 0, kills: 0, levels: 0, perfect: 0, bosses: 0, earned: 0}, inv: {guns: {peacemaker: true}, fins: {'peacemaker:0': true}, equip: {gun: 'peacemaker', fin: 0}}});
    // progression and payouts
    let pg = fresh(); let r = applyWin(pg, 0, 0, 2, {boss: false, last: false, bounty: 1000, count: 10});
    ok('Winning level 1 unlocks level 2', pg.ch[0].unlocked === 2);
    ok('Two stars pay $40', r.pay === 40, 'paid ' + r.pay);
    r = applyWin(pg, 0, 0, 3, {boss: false, last: false, bounty: 1000, count: 10});
    ok('Improving to three stars pays only the $20 difference', r.pay === 20, 'paid ' + r.pay);
    r = applyWin(pg, 0, 0, 1, {boss: false, last: false, bounty: 1000, count: 10});
    ok('A worse replay pays nothing and keeps three stars', r.pay === 0 && pg.ch[0].stars[0] === 3);
    ok('Perfect clears counted once', pg.stats.perfect === 1);
    r = applyWin(pg, 0, 9, 1, {boss: true, last: true, bounty: 1000, count: 10});
    ok('Capturing Iron Eli pays the $1,000 poster reward plus boss pay', r.pay === 1040 && r.captureNow, 'paid ' + r.pay);
    r = applyWin(pg, 0, 9, 2, {boss: true, last: true, bounty: 1000, count: 10});
    ok('The poster reward is never paid twice', r.pay === 40, 'paid ' + r.pay);
    ok('Earnings ledger matches the wallet', pg.stats.earned === pg.bucks);
    // production unlocks
    const pg2 = fresh();
    ok('Production: the train is locked before Iron Eli is captured', !chapterOpenFor(pg2, 1, false));
    applyWin(pg2, 0, 9, 1, {boss: true, last: true, bounty: 1000, count: 10});
    ok('Production: capturing Iron Eli opens the train', chapterOpenFor(pg2, 1, false));
    ok('Production: posters without levels stay locked', !chapterOpenFor(pg2, 2, false) && !chapterOpenFor(pg2, 2, true));
    // campaign status: the desk must never send you back to a captured outlaw
    const hs = fresh();
    let st = huntStatusFor(hs, false);
    ok('New save: Continue hunt goes to Iron Eli', st.ch === 0);
    applyWin(hs, 0, 9, 1, {boss: true, last: true, bounty: 1000, count: 10});
    st = huntStatusFor(hs, false);
    ok('Iron Eli captured: Continue hunt goes to the Coal Gang', st.ch === 1);
    applyWin(hs, 1, 9, 1, {boss: true, last: true, bounty: 1500, count: 10});
    st = huntStatusFor(hs, false);
    ok('Both captured: all bounties captured, nothing to continue', st.done && st.ch == null);
    ok('Both captured: Digger McCall is next, coming soon', st.next === 2 && !CHAPTERS[2].levels);
    ok('Both captured: playtest mode agrees', huntStatusFor(hs, true).ch == null);
    ok('Captured bounties stay replayable from the board', chapterOpenFor(hs, 0, false) && chapterOpenFor(hs, 1, false));
    const hs2 = fresh(); applyWin(hs2, 1, 9, 1, {boss: true, last: true, bounty: 1500, count: 10});
    ok('Playtest: train captured first still sends you to Iron Eli', huntStatusFor(hs2, true).ch === 0);
    // inventory and saving
    const pg3 = fresh(); pg3.bucks = 600;
    ok('Cannot buy what you cannot afford', !buyItem(pg3, 900, p => { p.inv.guns.legend = true; }) && pg3.bucks === 600);
    ok('Buying deducts the price', buyItem(pg3, 500, p => { p.inv.guns.quickdraw = true; }) && pg3.bucks === 100);
    pg3.avatar = {name: 'Test', hat: 2}; pg3.hints = {'0:1': 2};
    const back = JSON.parse(JSON.stringify(pg3));
    ok('Owned guns survive a save and reload', back.inv.guns.quickdraw === true && back.bucks === 100);
    ok('Avatar and unlocked hints survive a save and reload', back.avatar.hat === 2 && back.hints['0:1'] === 2);
    // second chance rules
    const arcade = {}, puzzle = {puzzle: true}, bossL = {duel: true};
    ok('Arcade, out of ammo with one outlaw left: +1 bullet', offerFor(arcade, 'ammo', 1, false) === 'bullet');
    ok('Arcade, two outlaws left: no ad offer', offerFor(arcade, 'ammo', 2, false) === null);
    ok('Puzzle levels never offer bullets, only clues', offerFor(puzzle, 'ammo', 1, false) === 'hint');
    ok('Single-stage duels offer to keep your rounds', offerFor(bossL, 'shot', 0, false) === 'continue');
    ok('Iron Eli, lost in stage 1: no ad offer', offerFor({eli: true}, 'shot', 1, false, 1) === null);
    ok('Iron Eli, lost in stage 2 or 3: retry from that stage', offerFor({eli: true}, 'shot', 1, false, 2) === 'checkpoint' && offerFor({eli: true, duel: true}, 'shot', 0, false, 3) === 'checkpoint');
    ok('A clean perfect run earns three stars', starsFor({par: 3}, {used: 3, damaged: false}) === 3 && starsFor({duel: true}, {hearts: 3}) === 3);
    ok('Any assistance caps a clear at two stars', starsFor({par: 3}, {used: 3, damaged: false, assisted: true}) === 2 && starsFor({duel: true}, {hearts: 3, assisted: true}) === 2);
    ok('Assistance never lowers a one-star clear', starsFor({par: 3}, {used: 9, damaged: true, assisted: true}) === 1);
    ok('Shooting a hostage in an arcade level offers nothing', offerFor(arcade, 'hostage', 1, false) === null);
    ok('Only one offer per attempt', offerFor(arcade, 'ammo', 1, true) === null);
    // level data
    const all = [...LEVELS.map((l, i) => [0, i, l]), ...TRAIN.map((l, i) => [1, i, l])];
    for (const [c, i, l] of all) {
      const name = `${c ? 'Train' : 'Main Street'} ${i + 1}, ${l.name}`;
      if (l.duel) { ok(name + ': duel set up', BOSSES[l.boss] && l.react.length >= 1); continue; }
      const sc = CHAPTERS[c].scene, n = l.enemies.length + (l.bottles || []).length;
      const problems = [];
      if (l.bullets < l.par) problems.push('par above bullets');
      if (!l.puzzle && !l.eli && l.bullets < n) problems.push('fewer bullets than targets');
      for (const d of l.enemies) {
        if (d.w != null && !sc.windows[d.w]) problems.push('bad window');
        if (d.c != null && !l.covers[d.c]) problems.push('bad cover');
      }
      for (const [t, x] of l.covers) if (x < 0 || x + COVER[t][0] > 270) problems.push(t + ' behind the gun');
      if (l.puzzle && !(l.hint && l.hintTarget)) problems.push('puzzle without hint');
      ok(name + ': data valid', !problems.length, problems.join(', '));
    }
    const passed = R.filter(x => x[1]).length;
    track('selftest', {passed, total: R.length});
    show(`<div class="topline"><button class="back" data-act="playtest">‹ Playtest tools</button></div><h2>Self-tests: ${passed} of ${R.length} passed</h2>
      <ul class="tests">${R.map(([n, p, d]) => `<li class="${p ? 'pass' : 'failt'}">${p ? '✓' : '✗'} ${n}${d && !p ? ` <i>(${d})</i>` : ''}</li>`).join('')}</ul>`);
    ov.firstElementChild.classList.add('wide');
  }

// ---- applyWin ----
function applyWin(pg, c, l, stars, o) {
    const ch = pg.ch[c] = pg.ch[c] || {unlocked: 1, stars: {}};
    const before = ch.stars[l] || 0, best = Math.max(before, stars);
    let pay = (PAY[best] - PAY[before]) * (o.boss ? 2 : 1);
    const captureNow = o.last && before === 0;
    if (captureNow) pay += o.bounty;
    ch.stars[l] = best;
    ch.unlocked = Math.max(ch.unlocked, Math.min(o.count, l + 2));
    pg.bucks += pay; pg.stats.earned += pay;
    if (!before) { pg.stats.levels++; if (o.boss) pg.stats.bosses++; }
    if (stars === 3 && before < 3) pg.stats.perfect++;
    return {pay, captureNow, before, best};
  }

// ---- starsFor ----
function starsFor(level, o) {
    let s = level.duel ? 1 + (o.hearts >= 2 ? 1 : 0) + (o.hearts === 3 ? 1 : 0) : 1 + (o.used <= level.par ? 1 : 0) + (!o.damaged ? 1 : 0);
    return o.assisted ? Math.min(2, s) : s;
  }

// ---- offerFor ----
function offerFor(level, reason, alive, used, stage = 1) {
    if (used) return null;
    if (reason === 'hostage') return level.puzzle ? 'hint' : null;
    if (level.eli) return stage >= 2 && reason !== 'ammo' ? 'checkpoint' : null;
    if (level.duel) return reason === 'ammo' ? null : 'continue';
    if (level.puzzle) return 'hint';
    if (reason === 'ammo' && alive === 1) return 'bullet';
    return null;
  }

// ---- huntStatusFor ----
function huntStatusFor(pg, pt) {
    for (let i = 0; i < CHAPTERS.length; i++) {
      if (!CHAPTERS[i].levels) return {done: true, next: i};
      if (!collectedIn(pg, i)) return chapterOpenFor(pg, i, pt) ? {ch: i} : {done: true, next: i};
    }
    return {done: true, next: null};
  }