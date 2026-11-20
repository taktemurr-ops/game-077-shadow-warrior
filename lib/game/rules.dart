import '../core/arcade.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'fighter_engine.dart';

class ShadowRules extends ArcadeRules<FightLevel> {
  @override
  String get gameId => 'game-077-shadow-warrior';

  @override
  List<String> get optionalMechanics => const ['boss'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('knockouts', 'Nakavt', 'Knockouts', scale: 50),
        GameStat('combos', 'Üçlü kombo', 'Triple combos', scale: 60),
        GameStat('rounds_won', 'Kazanılan raund', 'Rounds won', scale: 20),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('knockouts', 'knockouts', [12, 25, 50]),
        MissionTemplate('combos', 'combos', [7, 15, 30], coinReward: 80),
      ];

  @override
  FightLevel generate(LevelSpec spec) => generateFight(FightKind.brawl, spec);

  @override
  ArcadeMeta metaOf(FightLevel l) => l.meta;

  @override
  ArcadeSim createSim(FightLevel l) => FightSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => fightBot(sim);
}

ArcadeRules createRules() => ShadowRules();
