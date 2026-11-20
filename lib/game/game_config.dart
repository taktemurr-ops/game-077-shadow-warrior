import 'package:flutter/material.dart';

import '../app/arcade_stage.dart';
import '../app/game_api.dart';
import '../core/game_rules.dart';
import 'fighter_engine.dart';
import 'fight_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-077-shadow-warrior',
  title: const ['Gölge Savaşçı', 'Shadow Warrior', 'Schattenkrieger', 'Guerrero Sombra', 'Guerrier de l\'Ombre'],
  tagline: const ['Gölgelerden gelen düşmanlara karşı tek başına!', 'Alone against the warriors of shadow!', 'Allein gegen die Schatten!', '¡Solo contra las sombras!', 'Seul contre les ombres !'],
  seedColor: const Color(0xFF3C096C),
  icon: Icons.nightlight,
  rules: ShadowRules(),
  buildPlay: (ctx) => ArcadeStage(
    ctx: ctx,
    create: () => FightSim((ctx.generated as GeneratedLevel<FightLevel>).puzzle),
    paint: paintFight,
    sound: fightSound,
    boosterIcon: Icons.local_fire_department,
    boosterLabel: (l) => l == 'tr' ? 'Öfke' : 'Rage',
    howTo: const ['Sol/sağ kenara basılı tut: yürü. Ortaya dokun: vur, basılı tut: blok. Yukarı kaydır: zıpla, aşağı kaydır: özel hareket.', 'Hold the left/right edge to walk. Tap the middle to strike, hold it to block. Swipe up to jump, down for the special.', 'Ränder halten: gehen. Mitte tippen: schlagen, halten: blocken.', 'Bordes: caminar. Centro: golpear, mantener: bloquear.', 'Bords : marcher. Centre : frapper, maintenir : bloquer.'],
  ),
  tutorial: const [
    TutorialStep(Icons.groups, ['Düşmanlar iki yandan gelir; arkanı kolla.', 'Enemies come from both sides; watch your back.', 'Feinde von beiden Seiten.', 'Enemigos por ambos lados.', 'Ennemis des deux côtés.']),
    TutorialStep(Icons.shield, ['! işaretini görünce blok yap.', 'Block when you see the ! sign.', 'Bei ! blocken.', 'Bloquea con !', 'Bloquez au signal !']),
    TutorialStep(Icons.south, ['Özel hareket iki yöne de vurur.', 'The special hits both directions.', 'Spezial trifft beide Seiten.', 'El especial golpea a ambos lados.', 'Le spécial frappe des deux côtés.']),
  ],
);
