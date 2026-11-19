import 'package:flutter/material.dart';
import 'game/shadow_engine.dart';

void main() => runApp(const ShadowWarriorApp());

class ShadowWarriorApp extends StatelessWidget {
  const ShadowWarriorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Shadow Warrior',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple,
        brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const ShadowArenaScreen(),
  );
}

class ShadowArenaScreen extends StatefulWidget {
  const ShadowArenaScreen({super.key});
  @override
  State<ShadowArenaScreen> createState() => _ShadowArenaScreenState();
}

class _ShadowArenaScreenState extends State<ShadowArenaScreen> {
  final ShadowEngine game = ShadowEngine();
  Direction facing = Direction.right;
  void redraw(void Function() fn) => setState(fn);

  Widget directionButton(Direction dir, IconData icon) => IconButton.filledTonal(
    tooltip: 'Move ${dir.name}',
    onPressed: game.status == BattleStatus.playing
        ? () => redraw(() {
            facing = dir;
            game.move(dir);
          }) : null,
    icon: Icon(icon),
  );

  @override
  Widget build(BuildContext context) {
    final hero = game.hero;
    final foe = game.enemy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SHADOW WARRIOR'),
        actions: [
          IconButton(
            tooltip: 'Restart',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => redraw(game.reset),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 530),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text('STAGE ${game.stage}/5  •  SCORE ${game.score}  •  TURN ${game.turns}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text('HERO  HP ${hero.hp}/100\nENERGY ${game.energy}/5')),
                  Expanded(child: Text('GUARDIAN  HP ${foe.hp}\nPOTIONS ${game.potions}',
                    textAlign: TextAlign.right)),
                ]),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: Column(
                    children: List.generate(ShadowEngine.size, (y) =>
                      Expanded(child: Row(children: List.generate(ShadowEngine.size, (x) {
                        final isHero = hero.x == x && hero.y == y;
                        final isEnemy = foe.x == x && foe.y == y;
                        return Expanded(child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: isHero ? Colors.deepPurple.shade400 :
                                  isEnemy ? Colors.red.shade800 :
                                  (x + y).isEven ? const Color(0xFF202535) :
                                    const Color(0xFF2B3246),
                            ),
                            child: Center(child: isHero
                                ? const Icon(Icons.person, color: Colors.white)
                                : isEnemy
                                    ? const Icon(Icons.security, color: Colors.white)
                                    : null),
                          ),
                        ));
                      })))),
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(liveRegion: true,
                  child: Text(game.message, textAlign: TextAlign.center)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  directionButton(Direction.left, Icons.arrow_left),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    directionButton(Direction.up, Icons.arrow_drop_up),
                    directionButton(Direction.down, Icons.arrow_drop_down),
                  ]),
                  directionButton(Direction.right, Icons.arrow_right),
                ]),
                Row(children: [
                  Expanded(child: FilledButton.tonalIcon(
                    onPressed: game.canStrike
                        ? () => redraw(() { game.use(Skill.strike); }) : null,
                    icon: const Icon(Icons.gavel), label: const Text('Strike'),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: FilledButton.tonalIcon(
                    onPressed: game.canDash
                        ? () => redraw(() { game.use(Skill.dash, direction: facing); }) : null,
                    icon: const Icon(Icons.bolt), label: const Text('Dash'),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: FilledButton.tonalIcon(
                    onPressed: game.canHeal
                        ? () => redraw(() { game.use(Skill.heal); }) : null,
                    icon: const Icon(Icons.healing), label: const Text('Heal'),
                  )),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Move with arrows. Strike when adjacent. Dash two tiles in the '
                  'last chosen direction (2 energy). Heal with potions. '
                  'Defeat five guardians to win.',
                  textAlign: TextAlign.center,
                ),
                if (game.status != BattleStatus.playing)
                  Padding(padding: const EdgeInsets.only(top: 12),
                    child: FilledButton(
                      onPressed: () => redraw(game.reset),
                      child: Text(game.status == BattleStatus.won
                          ? 'Play again' : 'Retry'),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
