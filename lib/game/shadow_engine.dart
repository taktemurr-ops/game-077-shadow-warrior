import 'dart:math';

enum Direction { up, down, left, right }
enum BattleStatus { playing, won, lost }
enum Skill { strike, dash, heal }

class Fighter {
  int x;
  int y;
  int hp;
  final int maxHp;
  Fighter(this.x, this.y, this.hp) : maxHp = hp;
}

class ShadowEngine {
  static const int size = 7;
  final Random random;
  late Fighter hero;
  late Fighter enemy;
  int stage = 1;
  int turns = 0;
  int score = 0;
  int energy = 3;
  int potions = 2;
  BattleStatus status = BattleStatus.playing;
  String message = 'Defeat the guardian to advance.';

  ShadowEngine({Random? random}) : random = random ?? Random() { reset(); }

  void reset() {
    hero = Fighter(1, 3, 100);
    enemy = Fighter(5, 3, 35);
    stage = 1; turns = 0; score = 0; energy = 3; potions = 2;
    status = BattleStatus.playing;
    message = 'Move with the arrows. Strike when adjacent.';
  }

  int get distance => (hero.x - enemy.x).abs() + (hero.y - enemy.y).abs();
  bool get canStrike => status == BattleStatus.playing && distance == 1;
  bool get canDash => status == BattleStatus.playing && energy >= 2;
  bool get canHeal => status == BattleStatus.playing &&
      potions > 0 && hero.hp < hero.maxHp;

  (int, int) _delta(Direction dir) => switch (dir) {
    Direction.up => (0, -1),
    Direction.down => (0, 1),
    Direction.left => (-1, 0),
    Direction.right => (1, 0),
  };
  bool _inside(int x, int y) => x >= 0 && x < size && y >= 0 && y < size;
  bool _enemyAt(int x, int y) => x == enemy.x && y == enemy.y;

  bool move(Direction direction) {
    if (status != BattleStatus.playing) return false;
    final (dx, dy) = _delta(direction);
    final nx = hero.x + dx, ny = hero.y + dy;
    if (!_inside(nx, ny) || _enemyAt(nx, ny)) return false;
    hero.x = nx; hero.y = ny;
    message = 'Shadow step.';
    _enemyTurn();
    return true;
  }

  bool use(Skill skill, {Direction direction = Direction.right}) {
    if (status != BattleStatus.playing) return false;
    switch (skill) {
      case Skill.strike:
        if (!canStrike) return false;
        enemy.hp = max(0, enemy.hp - 20);
        message = 'Blade strike: 20 damage.';
        if (enemy.hp == 0) {
          _clearStage();
          return true;
        }
        break;
      case Skill.dash:
        if (!canDash) return false;
        final (dx, dy) = _delta(direction);
        // Dash cannot jump over or land on the enemy.
        for (var step = 1; step <= 2; step++) {
          final nx = hero.x + dx * step, ny = hero.y + dy * step;
          if (!_inside(nx, ny) || _enemyAt(nx, ny)) return false;
        }
        hero.x += dx * 2; hero.y += dy * 2;
        energy -= 2;
        message = 'Shadow dash.';
        break;
      case Skill.heal:
        if (!canHeal) return false;
        potions--;
        hero.hp = min(hero.maxHp, hero.hp + 30);
        message = 'Potion restores health.';
        break;
    }
    _enemyTurn();
    return true;
  }

  void _clearStage() {
    score += 100 * stage + hero.hp;
    if (stage == 5) {
      status = BattleStatus.won;
      message = 'All five guardians defeated. Victory!';
      return;
    }
    stage++;
    hero.x = 1; hero.y = 3;
    enemy = Fighter(5, 3, 35 + (stage - 1) * 15);
    energy = min(5, energy + 2);
    if (stage.isEven) potions++;
    message = 'Stage $stage: a stronger guardian approaches.';
  }

  void _enemyTurn() {
    if (status != BattleStatus.playing) return;
    turns++;
    energy = min(5, energy + 1);
    if (distance == 1) {
      hero.hp = max(0, hero.hp - (5 + stage * 2));
      message += ' Guardian hits you.';
    } else {
      final dx = (hero.x - enemy.x).sign;
      final dy = (hero.y - enemy.y).sign;
      final candidates = random.nextBool()
          ? [(enemy.x + dx, enemy.y), (enemy.x, enemy.y + dy)]
          : [(enemy.x, enemy.y + dy), (enemy.x + dx, enemy.y)];
      for (final point in candidates) {
        final (x, y) = point;
        if (_inside(x, y) && (x != hero.x || y != hero.y) &&
            (x != enemy.x || y != enemy.y)) {
          enemy.x = x; enemy.y = y;
          break;
        }
      }
      message += ' Guardian advances.';
    }
    if (hero.hp == 0) {
      status = BattleStatus.lost;
      message = 'Defeated. Retry the arena.';
    }
  }
}
