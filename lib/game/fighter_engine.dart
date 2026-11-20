import 'dart:math' as math;

import '../core/arcade.dart';
import '../core/level_plan.dart';

/// Side-view fighting engine: 1v1 duels (Stickman Fighter) or waves of
/// enemies (Shadow Warrior). Attacks have wind-up (telegraph), active and
/// recovery frames; blocking, jumping, dashing and a special move.
enum FightKind { duel, brawl }

const double kGround = 1250;
const double kReach = 150;

/// Fighter states.
const fsIdle = 0,
    fsWindup = 1,
    fsActive = 2,
    fsRecover = 3,
    fsBlock = 4,
    fsHurt = 5,
    fsDash = 6,
    fsSpecial = 7,
    fsDead = 8;

/// Enemy styles.
const stBalanced = 0, stRusher = 1, stDefender = 2, stJumper = 3, stHeavy = 4, stBoss = 5, stGrunt = 6;

class Fighter {
  double x;
  double y = 0; // height above ground
  double vx = 0, vy = 0;
  int face = 1;
  double hp;
  final double maxHp;
  int state = fsIdle;
  int timer = 0;
  int combo = 0; // 0..2
  bool queued = false;
  int cool = 0;
  int invul = 0;
  final int style;
  final double dmg;
  final double speed;
  final int windup;
  int think = 0;
  int hitFlash = 0;
  Fighter(this.x, this.hp, this.style, this.dmg, this.speed, this.windup) : maxHp = hp;
  bool get airborne => y > 0.5;
  bool get attacking => state == fsWindup || state == fsActive || state == fsSpecial;
}

class FightLevel {
  final ArcadeMeta meta;
  final FightKind kind;

  /// Opponent styles in order (duel) or wave sizes (brawl, boss last).
  final List<int> opponents;
  final List<int> waves;
  final bool boss;
  final double hpScale;
  final double dmgScale;
  final int reaction; // AI think interval
  final int arena; // background theme
  const FightLevel(
    this.meta,
    this.kind,
    this.opponents,
    this.waves,
    this.boss,
    this.hpScale,
    this.dmgScale,
    this.reaction,
    this.arena,
  );
}

FightLevel generateFight(FightKind kind, LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final d = spec.difficulty;
  final r = _Lcg(spec.seed);
  final boss = m.goal && (spec.has('boss') || (spec.levelId > 0 && spec.levelId % 5 == 0));
  final styles = [stBalanced, stRusher, stDefender, stJumper, stHeavy];
  final pool = styles.take((1 + d ~/ 2).clamp(1, 5)).toList();
  final opp = <int>[];
  final waves = <int>[];
  if (m.goal) {
    if (kind == FightKind.duel) {
      final n = (1 + d ~/ 4).clamp(1, 3);
      for (var i = 0; i < n; i++) {
        opp.add(pool[r.next(pool.length)]);
      }
      if (boss) opp.add(stBoss);
    } else {
      final n = (2 + d ~/ 3).clamp(2, 5);
      for (var i = 0; i < n; i++) {
        waves.add((2 + d ~/ 2 + i).clamp(2, 9));
      }
    }
  }
  return FightLevel(m, kind, opp, waves, boss, 1 + d * 0.1, 0.8 + d * 0.05, (26 - d * 2).clamp(8, 26), r.next(4));
}

class _Lcg {
  int s;
  _Lcg(int seed) : s = seed & 0x7fffffff;
  int next(int n) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return (s >> 8) % n;
  }
}

class FightSim extends ArcadeSim {
  final FightLevel level;
  final Fighter p = Fighter(300, 100, -1, 9, 7.5, 6);
  final List<Fighter> foes = [];
  double meter = 0; // special 0..100
  int stage = 0; // opponent index or wave index
  int toSpawn = 0;
  bool bossSpawned = false;
  int gap = 0;
  int holdTicks = 0;
  int pendingTap = 0;
  bool lastDown = false;
  int kos = 0, perfectBlocks = 0, specials = 0, combos = 0, stagesWon = 0;
  int lastEvent = 0; // 1 hit, 2 ko, 3 block, 4 hurt, 5 special
  int sinceHit = 0;
  final List<(double, double, int)> sparks = [];

  FightSim(this.level) : super(level.meta, lives: 3) {
    _nextStage();
  }

  int get totalStages =>
      level.kind == FightKind.duel ? level.opponents.length : level.waves.length + (level.boss ? 1 : 0);

  Fighter _make(int style, double x) {
    final h = level.hpScale, dm = level.dmgScale;
    return switch (style) {
      stRusher => Fighter(x, 70 * h, style, 7 * dm, 6.5, 16),
      stDefender => Fighter(x, 95 * h, style, 9 * dm, 4.5, 22),
      stJumper => Fighter(x, 75 * h, style, 8 * dm, 6, 18),
      stHeavy => Fighter(x, 130 * h, style, 15 * dm, 3.5, 30),
      stBoss => Fighter(x, 260 * h, style, 14 * dm, 5, 24),
      stGrunt => Fighter(x, 30 * h, style, 6 * dm, 5, 22),
      _ => Fighter(x, 85 * h, style, 9 * dm, 5.5, 20),
    };
  }

  void _nextStage() {
    stage++;
    p.hp = p.maxHp;
    if (level.kind == FightKind.duel) {
      if (meta.goal) {
        if (stage > level.opponents.length) return;
        foes.add(_make(level.opponents[stage - 1], 760));
      } else {
        final styles = [stBalanced, stRusher, stDefender, stJumper, stHeavy];
        final s = stage % 6 == 0 && !meta.zen ? stBoss : styles[rng.nextInt(math.min(5, 1 + stage ~/ 2))];
        foes.add(_make(s, 760));
      }
      p.x = 260;
      return;
    }
    if (meta.goal) {
      if (stage <= level.waves.length) {
        toSpawn = level.waves[stage - 1];
      } else if (level.boss && !bossSpawned) {
        bossSpawned = true;
        foes.add(_make(stBoss, 900));
        toSpawn = 2;
      }
    } else {
      toSpawn = 3 + stage;
      if (stage % 5 == 0 && !meta.zen) foes.add(_make(stBoss, 900));
    }
  }

  bool get stageDone => foes.isEmpty && toSpawn == 0;

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    sinceHit++;
    for (var i = sparks.length - 1; i >= 0; i--) {
      final s = sparks[i];
      if (s.$3 <= 1) {
        sparks.removeAt(i);
      } else {
        sparks[i] = (s.$1, s.$2, s.$3 - 1);
      }
    }
    _control(input);
    _spawn();
    _physics(p);
    for (final f in [...foes]) {
      _ai(f);
      _physics(f);
    }
    _resolve(p, foes);
    for (final f in [...foes]) {
      _resolve(f, [p]);
    }
    // keep fighters apart
    for (final f in foes) {
      final dx = f.x - p.x;
      if (dx.abs() < 70 && !f.airborne && !p.airborne) {
        final push = (70 - dx.abs()) / 2 * (dx >= 0 ? 1 : -1);
        f.x += push;
        p.x -= push;
      }
    }
    for (var i = 0; i < foes.length; i++) {
      for (var j = i + 1; j < foes.length; j++) {
        final dx = foes[j].x - foes[i].x;
        if (dx.abs() < 60) {
          final push = (60 - dx.abs()) / 2 * (dx >= 0 ? 1 : -1);
          foes[j].x += push;
          foes[i].x -= push;
        }
      }
    }
    p.x = clampD(p.x, 60, kWorldW - 60);
    for (final f in foes) {
      f.x = clampD(f.x, 50, kWorldW - 50);
    }
    if (gap > 0) {
      if (--gap == 0) _nextStage();
    } else if (stageDone && !over) {
      stagesWon++;
      score += 200 * stage;
      if (meta.goal && stage >= totalStages) {
        win();
      } else {
        gap = 80;
      }
    }
  }

  void _spawn() {
    if (level.kind != FightKind.brawl || toSpawn == 0) return;
    final onScreen = foes.length;
    final cap = 2 + meta.difficulty ~/ 4;
    if (onScreen < cap && ticks % 50 == 0) {
      final left = rng.chance(0.5);
      foes.add(_make(meta.difficulty >= 6 && rng.chance(0.25) ? stRusher : stGrunt, left ? 40 : kWorldW - 40));
      toSpawn--;
    }
  }

  void _control(ArcadeInput input) {
    if (p.state == fsHurt || p.state == fsDead) return;
    final mid = input.hasPointer && input.x > 300 && input.x < 700;
    final side = input.hasPointer && !mid ? (input.x <= 300 ? -1 : 1) : 0;
    var move = input.dirX != 0 ? input.dirX : (input.down ? side : 0);
    // swipes
    if (input.swipe == 0 && !p.airborne && p.state != fsBlock) {
      p.vy = 26;
      p.state = fsIdle;
    } else if (input.swipe == 2 && meter >= 100 && !p.attacking) {
      meter = 0;
      p.state = fsSpecial;
      p.timer = 34;
      specials++;
      lastEvent = 5;
    } else if ((input.swipe == 1 || input.swipe == 3) && !input.down && p.state != fsDash && p.cool == 0) {
      p.state = fsDash;
      p.timer = 14;
      p.invul = 14;
      p.vx = (input.swipe == 1 ? 1 : -1) * 22;
      p.cool = 30;
    }
    // block: hold the middle (or keyboard down)
    final holding = (input.down && mid) || input.dirY == 1;
    holdTicks = holding ? holdTicks + 1 : 0;
    // Keyboard / no pointer: attack at once. Touch: on release, unless the
    // touch became a swipe (jump / special) or a hold (block).
    var attackPress = input.tap && !input.hasPointer;
    if (input.tap && mid) pendingTap = 1;
    if (pendingTap > 0) {
      if (input.swipe >= 0) {
        pendingTap = 0;
      } else if (!input.down) {
        pendingTap = 0;
        attackPress = true;
      } else if (++pendingTap > 10) {
        pendingTap = 0;
      }
    }
    if (attackPress) {
      if (p.state == fsIdle || p.state == fsBlock) {
        _startAttack(p, 0);
      } else if (p.state == fsActive || p.state == fsRecover || p.state == fsWindup) {
        p.queued = true;
      }
    }
    if (holdTicks > 10 && !p.attacking && !p.airborne && p.state != fsDash) {
      p.state = fsBlock;
    } else if (p.state == fsBlock && holdTicks == 0) {
      p.state = fsIdle;
    }
    if (p.state == fsIdle || (p.airborne && p.state != fsDash)) {
      if (move != 0) {
        p.vx = move * p.speed;
        p.face = move;
      } else if (!p.airborne) {
        p.vx = 0;
      }
    }
    if (!p.attacking && p.state != fsDash && move == 0) {
      final t = nearestFoe(p);
      if (t != null) p.face = t.x >= p.x ? 1 : -1;
    }
    lastDown = input.down;
  }

  void _startAttack(Fighter f, int comboIdx) {
    f.state = fsWindup;
    f.combo = comboIdx;
    f.timer = f == p ? 5 : (comboIdx == 0 ? f.windup : 10);
    f.queued = false;
    f.vx = 0;
  }

  Fighter? nearestFoe(Fighter of) {
    Fighter? best;
    var bd = 1e9;
    for (final f in foes) {
      final d = (f.x - of.x).abs();
      if (d < bd) {
        bd = d;
        best = f;
      }
    }
    return best;
  }

  void _physics(Fighter f) {
    if (f.cool > 0) f.cool--;
    if (f.invul > 0) f.invul--;
    if (f.hitFlash > 0) f.hitFlash--;
    f.x += f.vx;
    if (f.airborne || f.vy > 0) {
      f.y += f.vy;
      f.vy -= 1.6;
      if (f.y <= 0) {
        f.y = 0;
        f.vy = 0;
      }
    }
    switch (f.state) {
      case fsWindup:
        if (--f.timer <= 0) {
          f.state = fsActive;
          f.timer = 6;
          f.vx = f.face * (f.combo == 2 ? 8 : 4);
        }
      case fsActive:
        f.vx *= 0.8;
        if (--f.timer <= 0) {
          f.state = fsRecover;
          f.timer = f == p ? 8 : 18;
          f.vx = 0;
        }
      case fsRecover:
        if (--f.timer <= 0) {
          if (f.queued && f.combo < 2) {
            _startAttack(f, f.combo + 1);
          } else {
            f.state = fsIdle;
            f.combo = 0;
          }
        }
      case fsHurt:
        f.vx *= 0.85;
        if (--f.timer <= 0) f.state = fsIdle;
      case fsDash:
        f.vx *= 0.88;
        if (--f.timer <= 0) {
          f.state = fsIdle;
          f.vx = 0;
        }
      case fsSpecial:
        f.vx = f.face * 3;
        if (--f.timer <= 0) {
          f.state = fsIdle;
          f.vx = 0;
        }
      default:
        break;
    }
  }

  /// Applies [a]'s active hits to [targets].
  void _resolve(Fighter a, List<Fighter> targets) {
    final special = a.state == fsSpecial && a.timer == 16;
    if (!(a.state == fsActive && a.timer == 5) && !special) return;
    final reach = special ? kReach * 2.2 : (a.style == stHeavy || a.style == stBoss ? kReach * 1.15 : kReach);
    for (final t in [...targets]) {
      final dx = (t.x - a.x) * a.face;
      if (special ? dx.abs() > reach : (dx < -20 || dx > reach)) continue;
      if ((t.y - a.y).abs() > 110) continue;
      if (t.invul > 0 || t.state == fsDead) continue;
      var dmg = a == p
          ? (special ? 36.0 : (a.combo == 2 ? 13.0 : 8.0)) * (1 + (meta.difficulty - 1) ~/ 3 * 0.12)
          : a.dmg * (a.combo == 2 ? 1.4 : 1);
      final blocked = t.state == fsBlock && ((a.x - t.x) * t.face >= 0) && !special;
      if (blocked) {
        dmg *= 0.15;
        t.vx = a.face * 6;
        if (t == p) {
          meter = math.min(100, meter + 12);
          perfectBlocks++;
          lastEvent = 3;
        }
        sparks.add(((a.x + t.x) / 2, kGround - t.y - 120, 8));
      } else {
        t.state = fsHurt;
        t.timer = a.combo == 2 || special ? 22 : 12;
        t.vx = a.face * (a.combo == 2 || special ? 16 : 7);
        t.hitFlash = 6;
        t.combo = 0;
        t.queued = false;
        sparks.add((t.x, kGround - t.y - 130, 12));
      }
      if (t == p) {
        if (!blocked) lastEvent = 4;
        if (shield > 0 || meta.zen) continue;
        p.hp -= dmg;
        if (p.hp <= 0) {
          p.hp = p.maxHp;
          hit();
        }
      } else {
        t.hp -= dmg;
        sinceHit = 0;
        if (!blocked) {
          meter = math.min(100, meter + 7);
          score += 10;
          lastEvent = 1;
          if (a.combo == 2) combos++;
        }
        if (t.hp <= 0) {
          foes.remove(t);
          kos++;
          lastEvent = 2;
          score += t.style == stBoss ? 800 : (t.style == stGrunt ? 30 : 150);
        }
      }
    }
  }

  void _ai(Fighter f) {
    if (f.state == fsHurt || f.attacking || f.state == fsRecover) return;
    final dx = p.x - f.x;
    final dist = dx.abs();
    f.face = dx >= 0 ? 1 : -1;
    if (f.think > 0) {
      f.think--;
    } else {
      f.think = level.reaction + rng.nextInt(10);
      // Decide.
      final aggressive = switch (f.style) {
        stRusher => 0.8,
        stDefender => 0.35,
        stHeavy => 0.5,
        stGrunt => 0.4,
        stBoss => 0.7,
        _ => 0.55,
      };
      if (dist < kReach * 0.95 && rng.chance(aggressive)) {
        _startAttack(f, 0);
        if (f.style == stRusher || f.style == stBoss) f.queued = rng.chance(0.5);
        return;
      }
      if (p.attacking && dist < kReach * 1.2 && (f.style == stDefender || f.style == stBoss) && rng.chance(0.5)) {
        f.state = fsBlock;
        f.timer = 30;
        return;
      }
      if (f.style == stJumper && !f.airborne && rng.chance(0.3)) {
        f.vy = 24;
      }
    }
    if (f.state == fsBlock) {
      if (--f.timer <= 0) f.state = fsIdle;
      f.vx = 0;
      return;
    }
    // Approach to striking distance (grunts wait their turn).
    final want = kReach * 0.8;
    if (dist > want) {
      f.vx = f.face * f.speed;
    } else if (dist < 60) {
      f.vx = -f.face * f.speed * 0.6;
    } else {
      f.vx = 0;
    }
  }

  @override
  void onLifeLost() {
    p.state = fsIdle;
    for (final f in foes) {
      f.x = clampD(f.x + (f.x >= p.x ? 260 : -260), 50, kWorldW - 50);
      f.state = fsIdle;
    }
  }

  /// Booster: fill the special meter and heal.
  @override
  bool useBooster() {
    if (over) return false;
    meter = 100;
    p.hp = math.min(p.maxHp, p.hp + 40);
    shield = 180;
    return true;
  }

  @override
  double get progress {
    if (totalStages == 0) return 0;
    double inStage;
    if (level.kind == FightKind.duel) {
      final f = foes.isEmpty ? null : foes.first;
      inStage = f == null ? 1 : 1 - f.hp / f.maxHp;
    } else {
      final size = stage <= level.waves.length ? level.waves[stage - 1] : 3;
      inStage = 1 - (toSpawn + foes.length) / math.max(1, size);
    }
    return ((stage - 1) + inStage.clamp(0.0, 1.0)) / totalStages;
  }

  @override
  String get goalText => meta.goal ? '$stage/$totalStages' : 'R$stage';

  @override
  Map<String, int> get stats => {
    'knockouts': kos,
    'perfect_blocks': perfectBlocks,
    'specials_used': specials,
    'combos': combos,
    'rounds_won': stagesWon,
  };

  @override
  int get stars => lifeStars(this, 3);
}

/// Autopilot: blocks telegraphed attacks, punishes recovery, uses the
/// special when full, otherwise closes the distance.
ArcadeInput fightBot(ArcadeSim sim) {
  final g = sim as FightSim;
  final p = g.p;
  final t = g.nearestFoe(p);
  if (t == null) return const ArcadeInput();
  final dist = (t.x - p.x).abs();
  final dir = t.x >= p.x ? 1 : -1;
  // Threat: any foe winding up / active near us.
  var threat = false;
  for (final f in g.foes) {
    final d = (f.x - p.x).abs();
    final facing = (p.x - f.x) * f.face >= 0;
    if (facing && d < kReach * 1.35 && (f.state == fsWindup || f.state == fsActive)) threat = true;
  }
  if (threat) {
    if (p.attacking && p.state == fsWindup && p.timer <= 2) {
      // our hit lands first
    } else {
      return const ArcadeInput(down: true, x: 500, y: 800); // hold middle = block
    }
  }
  if (g.meter >= 100 && dist < kReach * 2 && !p.attacking) {
    return const ArcadeInput(swipe: 2);
  }
  if (dist < kReach * 0.9) {
    if (p.state == fsIdle || p.state == fsRecover || p.state == fsActive) {
      return const ArcadeInput(tap: true);
    }
    return const ArcadeInput();
  }
  // walk toward
  return ArcadeInput(down: true, x: dir > 0 ? 900 : 100, y: 800);
}
