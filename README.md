# Shadow Warrior (Game-077)

Original Flutter / Dart offline turn-based action arena prototype for Android and iOS.

## Implemented
- Seven-by-seven movement arena, directional controls and shadow dash
- Melee strike, guardian AI, healing potions and energy management
- Five progressive stages, stage rewards, score, death and replay
- Rules-engine unit tests and GitHub Actions analyze/test/debug Android APK workflow

## Developer setup
```bash
flutter create --platforms=android,ios .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Status
**Prototype only, not a final production deliverable.** Successful CI and physical-device testing have not been verified. See `docs/RELEASE_CHECKLIST.md` for missing features and release prerequisites, including signed Android/iOS builds, production ads and in-app purchases.
