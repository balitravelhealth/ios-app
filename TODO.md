# Bali Travel Health — TODO

Everything you need to swap before going to production. Grouped by category, with the file path and the exact line / symbol to edit.

---

## 1. Master switch

| File | What |
|---|---|
| [BaliTravelHealth/AppFlags.swift](BaliTravelHealth/AppFlags.swift) | Set `useDummyData = false` once your backend is live. While `true`, every network client returns canned data and the login screen shows a "Continue as Test User" button. |

---

## 2. Server endpoints

All endpoints are placeholders pointing at `https://balihealth.me/...`. Swap each one for the real route, then update the JSON contract on the server to match the documented `Codable` model.

| Endpoint var | File | Used for | Expected schema |
|---|---|---|---|
| `AuthConfig.sessionEndpoint` | [BaliTravelHealth/Authentication/AuthConfig.swift](BaliTravelHealth/Authentication/AuthConfig.swift) | Sign-in / sign-up + GET to validate token on launch | See `AuthAPIClient.signIn` / `signUp` doc-comments |
| `ProfileAPIClient.endpoint` | [BaliTravelHealth/Authentication/ProfileAPIClient.swift](BaliTravelHealth/Authentication/ProfileAPIClient.swift) | Upload profile + travel info | `UserProfile` + `TravelInfo` |
| `NurseService.endpoint` | [BaliTravelHealth/Services/NurseService.swift](BaliTravelHealth/Services/NurseService.swift) | List nurses (GET) | Array of `Nurse` |
| `AppointmentAPIClient.endpoint` | [BaliTravelHealth/Services/AppointmentAPIClient.swift](BaliTravelHealth/Services/AppointmentAPIClient.swift) | Book appointment (POST) | `AppointmentRequest` → `AppointmentConfirmation` |
| `AppointmentAPIClient.activeEndpoint` | [BaliTravelHealth/Services/AppointmentAPIClient.swift](BaliTravelHealth/Services/AppointmentAPIClient.swift) | Get active appointment (GET) — return 204/404 if none | `ActiveAppointment` |

**OAuth keys**

- [BaliTravelHealth/Authentication/AuthConfig.swift](BaliTravelHealth/Authentication/AuthConfig.swift) — `googleClientID` is wired; verify the matching reversed-DNS URL Scheme is in the project's URL Types.
- Add the **Sign In with Apple** capability in Xcode → Target → Signing & Capabilities once you stop relying on the test user button.

---

## 3. Asset placeholders

### 3.1 Onboarding & travel videos

| Filename to add | Where | What |
|---|---|---|
| `palm.mp4` | App bundle (drag into `BaliTravelHealth/`) | Plays on the "Ready to travel?" screen during Bali's **dry season** (Apr–Oct) |
| `rain.mp4` | App bundle | Plays during **rainy season** (Nov–Mar) |

Loader: [BaliTravelHealth/Views/LoopingVideoPlayer.swift](BaliTravelHealth/Views/LoopingVideoPlayer.swift) — falls back to 🌴 / 🌧️ emoji until the files exist. Selection is automatic via `BaliSeason.season(for:)` on the user's arrival date.

### 3.2 Lottie checkmark

| File to add | Where | Used in |
|---|---|---|
| `appointment_confirmed.json` | App bundle | [BaliTravelHealth/Views/Home/AppointmentConfirmedView.swift](BaliTravelHealth/Views/Home/AppointmentConfirmedView.swift) — `LottieCheckmarkPlaceholder` |

Steps:
1. Add the `lottie-ios` SPM package (`https://github.com/airbnb/lottie-ios`).
2. Drop the JSON file into the bundle.
3. Replace `LottieCheckmarkPlaceholder`'s body with `LottieView(animation: .named("appointment_confirmed")).playing()`.

### 3.3 Facility hero photos

[BaliTravelHealth/Views/Home/FacilityDetailView.swift](BaliTravelHealth/Views/Home/FacilityDetailView.swift) — `heroImage`. To use real photos, drop an asset into `Assets.xcassets` whose **name matches `facility.name`** (e.g. asset named `BIMC Hospital Kuta`). Until then the placeholder card with the photo glyph is shown.

Alternative: add a `photoAssetName` property to `HealthcareFacility` and update the lookup; comment in the file flags the spot.

### 3.4 Nurse avatars

[BaliTravelHealth/Models/Nurse.swift](BaliTravelHealth/Models/Nurse.swift) — `avatarURL: URL?`. The cards use `AsyncImage`; populate `avatarURL` from the server payload. Until then the red circle + stethoscope glyph fallback shows.

### 3.5 Guide thumbnails

[BaliTravelHealth/Models/Guide.swift](BaliTravelHealth/Models/Guide.swift) — each `Guide` has `imageName: String?`. Either:
- Drop an asset matching the name and set `imageName: "..."` on the entry, **or**
- Replace the whole `Guide.placeholders` array with real entries.

The list view falls back to a tinted SF symbol thumbnail if the asset isn't found.

### 3.6 Login / setup imagery

Already present — `BthIcon`, `JalakBali`, `GoogleIcon`, `BaliHeader`, `NusaPenidaHeader`, `SetupBackground`, `UbudHeader`. No action needed unless you want to swap art.

---

## 4. Logic placeholders (need real implementations)

### 4.1 Advice engine

[BaliTravelHealth/Services/AdviceProvider.swift](BaliTravelHealth/Services/AdviceProvider.swift) — `fetchAdvice(phase:for:travel:)` currently returns `[]`.

Branch on `TravelPhase.preTravel` / `.postTravel` to return `[Advice]`. Used by both [PreTravelView.swift](BaliTravelHealth/Views/Home/PreTravelView.swift) and [PostTravelView.swift](BaliTravelHealth/Views/Home/PostTravelView.swift).

### 4.2 Pre-travel tools

Routed in [BaliTravelHealth/Views/Home/PreTravelView.swift](BaliTravelHealth/Views/Home/PreTravelView.swift). Replace the `PreTravelToolPlaceholder` destination with real screens:

- `PreTravelTool.riskAssessment` — Health Risk Assessment flow. **When the user finishes**, call `profileStore.setHealthRiskAssessmentCompleted(true)` so the Profile screen flips its Health Pass card from *"Please take Health Risk Assessment first"* to *"Cleared for Bali!"*.
- `PreTravelTool.vaccineRecord` — Vaccination record / upload flow.

### 4.3 Post-travel tools

[BaliTravelHealth/Views/Home/PostTravelView.swift](BaliTravelHealth/Views/Home/PostTravelView.swift) — `PostTravelTool.healthScreening` placeholder.

### 4.4 Basic Life Support (BLS)

[BaliTravelHealth/Views/Home/DuringTravelView.swift](BaliTravelHealth/Views/Home/DuringTravelView.swift) — `BasicLifeSupportItem.all` is the seed list (CPR, Choking, Bleeding, Burns, Fractures, Shock). Each row pushes a `BasicLifeSupportPlaceholder`. Replace the placeholder destination view with real step-by-step content.

### 4.5 All Facilities screen

[BaliTravelHealth/Views/Home/DuringTravelView.swift](BaliTravelHealth/Views/Home/DuringTravelView.swift) — `AllFacilitiesPlaceholder` is a basic list. Add filtering / search / map view as needed.

### 4.6 Health Pass / Risk Assessment toggle

[BaliTravelHealth/Authentication/ProfileStore.swift](BaliTravelHealth/Authentication/ProfileStore.swift) — `setHealthRiskAssessmentCompleted(_:)` is the integration point. Call it from the future HRA flow.

### 4.7 Guide detail content

[BaliTravelHealth/Views/GuideView.swift](BaliTravelHealth/Views/GuideView.swift) — `GuideDetailPlaceholder`. Wire to real step-by-step guide content (consider a `Guide.body` markdown field).

### 4.8 Confirmed-appointment screen

[BaliTravelHealth/Views/Home/AppointmentConfirmedView.swift](BaliTravelHealth/Views/Home/AppointmentConfirmedView.swift) — already a polished animated screen, but the Lottie placeholder is the only piece left (see §3.2).

### 4.9 Home cards

[BaliTravelHealth/Views/Home/HomeView.swift](BaliTravelHealth/Views/Home/HomeView.swift) — every menu item now routes to a real screen (Pre / During / Post / Nursing). The `HomeMenuPlaceholder` default branch is unreachable today; safe to delete once you're confident.

---

## 5. Configuration / Info.plist

| Key | File | Status |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | `project.pbxproj` (`INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`) | ✅ set — adjust the copy if the marketing tone changes |
| `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` | not set | only needed if you add photo upload (e.g. vaccine record) |
| Sign in with Apple capability | not enabled | required when `AppFlags.useDummyData == false` |
| Google URL Scheme | unverified | reversed `googleClientID` must be in URL Types |

---

## 6. Pre-flight before App Store

- [ ] `AppFlags.useDummyData = false`
- [ ] Replace every endpoint URL listed in §2
- [ ] Drop in the MP4s, Lottie JSON, facility/nurse/guide imagery from §3
- [ ] Replace the `*Placeholder` destination views from §4
- [ ] Enable Sign in with Apple capability
- [ ] Verify Google URL Scheme is registered
- [ ] Re-test the full flow end-to-end on a physical device with real network

---

_Generated 2026-05-05. Update this file as items get checked off — keep it as the single source of truth for outstanding work._
