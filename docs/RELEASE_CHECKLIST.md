# Game-077 release requirements

Current repository contains a playable offline **prototype** and unit tests, not a production-complete game.

## Implemented
- 7x7 arena, hero movement, directional dash, sword strikes, enemy chase and attacks
- Five-stage campaign with score and escalating guardian HP
- Energy replenishment, consumable health potions, victory and retry
- Deterministic unit tests for gameplay states
- Flutter analyze/test/debug Android APK CI workflow

## Not verified or not implemented
- Passing CI run, real Android device QA, iOS build/device QA
- Gesture controls, adaptive visual/audio effects, performance and accessibility polish
- Additional modes, save/load progression, difficulty balancing and localization
- Real advertising SDK with consent checks and appropriate age/privacy requirements
- StoreKit/Google Play Billing with receipt verification, refund and restore flows
- Signed Android App Bundle and signed iOS IPA with release certificates
- Privacy policy, store screenshots, listing metadata, store review

Do not claim production readiness until these release gates are completed and evidenced.
