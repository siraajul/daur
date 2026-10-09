# Daur

Personal 12-week fat-loss tracker for Siraj. Based on `Siraj vai Diet App (1).html`; design in `design/`
(open `design/gallery.html`, spec in `design/DIRECTION.md`).

Concept: each day is one 400 m lap and each meal is a 100 m leg. The 12 weeks are 84 laps.

## Run

```bash
flutter pub get
flutter run -d <android-device>   # Android phone (USB debugging on)
flutter run -d chrome             # web
flutter run -d <iphone>           # iOS (needs signing, see below)
```

Install on your Android phone without a cable: `flutter build apk --release`, then copy
`build/app/outputs/flutter-apk/app-release.apk` to the phone and open it.

## Steps from Google Fit, Samsung Health and other apps

- **Android:** read through Health Connect, which is built into Android 14+. On Android 9–13, install
  *Health Connect* from the Play Store. In Google Fit, Samsung Health or Fitbit, turn on sync to Health Connect.
  The first launch asks for Activity recognition and Health Connect step access.
- **iOS:** read through Apple Health. In Xcode, open `ios/Runner.xcworkspace` → Runner → *Signing & Capabilities*.
  Pick your team, then add **HealthKit**. The permission texts are already in `Info.plist`.
- **Web:** no health store. Tap the pencil on the Walk row to type steps in.

## Code (`lib/`, flat)

| File | What |
|---|---|
| `main.dart` | App: navbar for core (Today · Gym · Progress), drawer for the rest, back handling, day rollover on resume |
| `theme.dart` | Design tokens: tartan red / oxblood, runner yellow, Unbounded display font |
| `plan.dart` | The plan: meals and options (kcal / protein), gym list, food guide, rules, milestones |
| `store.dart` | All state in `shared_preferences`, keyed by **local** date (the old app flipped days at 06:00) |
| `steps.dart` | Today's steps from Health Connect / Apple Health |
| `track.dart` | The track painter; logging a meal animates the runner one leg |
| `today.dart`, `gym.dart`, `food.dart`, `progress.dart` | The screens |

`flutter test` checks the store: local day key, step build-up, meal totals, weigh-in per day, reload.

## Screens

| Screen | File |
|---|---|
| Today: track, meals, extras, water and walk rows | `today.dart` |
| Meal sheet: planned option × portion, "something else" (search, recent, custom), skip, extras, undo | `meal_sheet.dart`, `foods.dart` |
| Water detail: 14 glasses, this week | `water_walk.dart` |
| Walk detail: steps vs this week's target, build-up, this week from Health Connect | `water_walk.dart` |
| Gym: sets × reps · kg per exercise | `gym.dart` |
| Exercise, rest timer, treadmill | `workout.dart` |
| Progress (weigh-ins, weekly check, 84-lap season) | `progress.dart` |
| Food database (drawer): 201 Dhaka foods + your own (add / edit / delete, kcal per serving) | `food_db.dart`, `foods.dart`, data `design/dhaka-foods.json` |
| Onboarding (3 screens) | `onboarding.dart` |
| Coach cards: first-win tip, one hint a day, welcome back, lap 28 / 31 / 84 check-ins | `coach.dart` |
| Local reminders: meals, water, weigh-in, walk, check-ins; Log / Skip / + Glass from the notification | `reminders.dart`, `reminders_screen.dart` |
| Home-screen widgets + Live Activities | `widget_sync.dart`, `live.dart`, `android/…/DaurWidgets.kt`, `TrackArt.kt`, `ios/DaurWidget/` |
| Drawer: Food guide, The 10 rules, Water, Walk, Treadmill, cut start date | `food.dart`, `water_walk.dart`, `workout.dart` |
