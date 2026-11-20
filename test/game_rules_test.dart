import 'package:flutter_test/flutter_test.dart';
import 'package:game_077_shadow_warrior/core/arcade.dart';
import 'package:game_077_shadow_warrior/core/level_plan.dart';
import 'package:game_077_shadow_warrior/game/fighter_engine.dart';
import 'package:game_077_shadow_warrior/game/rules.dart';

void main() {
  final rules = ShadowRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  FightSim fresh() {
    final s = FightSim(rules.build(planner.spec(2)).puzzle);
    for (var i = 0; i < 200 && s.foes.isEmpty; i++) {
      s.tick(ArcadeInput.idle);
    }
    return s;
  }

  test('a landed attack damages the foe and fills the meter', () {
    final s = fresh();
    final f = s.foes.first;
    f.x = s.p.x + 100;
    f.think = 999;
    final hp = f.hp;
    s.tick(const ArcadeInput(down: true, x: 500, y: 800, tap: true));
    for (var i = 0; i < 20; i++) {
      f.think = 999;
      s.tick(ArcadeInput.idle);
    }
    expect(f.hp, lessThan(hp));
    expect(s.meter, greaterThan(0));
  });

  test('blocking reduces damage', () {
    final a = fresh(), b = fresh();
    for (final s in [a, b]) {
      final f = s.foes.first;
      f.x = s.p.x + 110;
      f.face = -1;
      f.state = fsActive;
      f.timer = 6;
    }
    b.p.state = fsBlock;
    b.p.face = 1;
    a.tick(ArcadeInput.idle);
    b.tick(const ArcadeInput(down: true, x: 500, y: 800));
    expect(b.p.hp, greaterThan(a.p.hp));
  });

  test('swipe up jumps, a full meter enables the special', () {
    final s = fresh();
    s.tick(const ArcadeInput(swipe: 0));
    s.tick(ArcadeInput.idle);
    expect(s.p.y, greaterThan(0));
    for (var i = 0; i < 60; i++) {
      s.tick(ArcadeInput.idle);
    }
    s.meter = 100;
    s.tick(const ArcadeInput(swipe: 2));
    expect(s.p.state, fsSpecial);
    expect(s.specials, 1);
  });
}
