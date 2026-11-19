import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_077_shadow_warrior/game/shadow_engine.dart';

void main() {
  group('ShadowEngine', () {
    test('initializes gameplay', () {
      final g = ShadowEngine(random: Random(1));
      expect(g.stage, 1);
      expect(g.hero.hp, 100);
      expect(g.enemy.hp, 35);
      expect(g.distance, 4);
    });
    test('movement rejects invalid target and succeeds in bounds', () {
      final g = ShadowEngine(random: Random(1));
      expect(g.move(Direction.up), true);
      expect(g.hero.y, 2);
      expect(g.turns, 1);
      g.hero.y = 0;
      expect(g.move(Direction.up), false);
      expect(g.hero.y, 0);
    });
    test('strike requires adjacency and advances stage', () {
      final g = ShadowEngine(random: Random(1));
      expect(g.use(Skill.strike), false);
      g.enemy.x = 2;
      g.enemy.y = 3;
      g.enemy.hp = 10;
      expect(g.use(Skill.strike), true);
      expect(g.stage, 2);
      expect(g.score, greaterThan(100));
      expect(g.enemy.hp, 50);
    });
    test('dash costs energy and cannot jump over enemy', () {
      final g = ShadowEngine(random: Random(2));
      expect(g.use(Skill.dash, direction: Direction.right), true);
      expect(g.hero.x, 3);
      expect(g.energy, 2);
      g.enemy.x = 4;
      g.enemy.y = 3;
      expect(g.use(Skill.dash, direction: Direction.right), false);
    });
    test('heal consumes a potion and clamps to max', () {
      final g = ShadowEngine(random: Random(3));
      expect(g.use(Skill.heal), false);
      g.hero.hp = 90;
      expect(g.use(Skill.heal), true);
      expect(g.hero.hp, 100);
      expect(g.potions, 1);
    });
    test('victory disables further input', () {
      final g = ShadowEngine(random: Random(4));
      g.stage = 5;
      g.enemy.x = 2;
      g.enemy.y = 3;
      g.enemy.hp = 1;
      expect(g.use(Skill.strike), true);
      expect(g.status, BattleStatus.won);
      expect(g.move(Direction.up), false);
    });
    test('defeat disables actions', () {
      final g = ShadowEngine(random: Random(5));
      g.hero.hp = 1;
      g.enemy.x = 2;
      g.enemy.y = 3;
      expect(g.use(Skill.strike), true);
      expect(g.status, BattleStatus.lost);
      expect(g.use(Skill.heal), false);
    });
  });
}
