# DroneArenaVision — App Store Submission Checklist

App: **Spatial Drone Delivery** · ID `6753620194` · bundle `org.dicyaninlabs.DroneArena`
Platform: **visionOS** · Version **1.0** (`2744aa6e-e86e-4b0f-b3cc-c81420bb2fc4`) · State: PREPARE_FOR_SUBMISSION

## Done (pushed live via asc)
- [x] App name / subtitle / privacy policy URL
- [x] Description, keywords, promotional text, marketing & support URLs (en-US)
- [x] Primary category GAMES · subcategories Simulation + Casual
- [x] Age rating declaration (all none/false → 4+)
- [x] Content rights: does not use third-party content
- [x] Price schedule: $4.99 (USA base), starting today

## Remaining before you can submit
- [ ] **Fresh build** — every uploaded build is expired (>90 days, Oct–Nov 2025).
      Archive & upload a new visionOS build, then: `asc versions attach-build --version-id 2744aa6e-... --build-id <NEW>`
- [ ] **Screenshots** — none uploaded. visionOS requires at least one Apple Vision Pro screenshot (3840×2160).
      Upload: `asc screenshots upload --version-localization 90f6f300-fa61-43d5-8ece-23ec0f9756a1 --path ./screenshots --device-type APPLE_VISION_PRO`
      (Generate with the `/aso-appstore-screenshots` skill.)
- [ ] **Availability** — confirm territories in ASC UI (CLI inline-create has a bug; price schedule base territory is set).
- [x] Copyright: 2026 Dicyanin Labs
- [ ] **Review contact / sign-in info** in App Review Details if needed.

## Verify URLs (placeholders — replace if the real ones differ)
- Privacy: https://dicyaninlabs.org/dronearena/privacy
- Support: https://dicyaninlabs.org/dronearena/support
- Marketing: https://dicyaninlabs.org/dronearena

## Submit when ready
`asc validate --app 6753620194 --version 1.0 --platform VISION_OS` then submit for review.

## Submission dry run (2026-09-30, asc 5.8.0, review submission be60eed4-76f6-4769-b04f-734655ad1a01)
- [x] Availability: all 175 territories + new territories
- [x] Review details: contact Hunter Harris, notes (no login required)
- [x] Encryption: usesNonExemptEncryption=false on builds; ITSAppUsesNonExemptEncryption=NO in HelicopterGame/Info2.plist
- [ ] App Privacy (data usages): publish in ASC web UI, or `asc web auth login` then `asc web privacy apply/publish`
- [ ] High Motion label (hasHighMotionLabel): set in ASC web UI, version page. Not in public API
- [ ] Screenshots: APP_APPLE_VISION_PRO
- [ ] Build: attach new build (build 10 expires 2026-10-18)
Then: `asc review items-add --submission be60eed4-76f6-4769-b04f-734655ad1a01 --item-type appStoreVersions --item-id 2744aa6e-e86e-4b0f-b3cc-c81420bb2fc4` and `asc review submissions-submit --id be60eed4-76f6-4769-b04f-734655ad1a01 --confirm`
