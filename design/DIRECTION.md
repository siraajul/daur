# Daur: Direction

## Brief

- **App, and who it's for:** a personal 12-week fat-loss app for Siraj (109 kg at the start), built around Bengali home food: ~1,800 kcal/day, 130–150 g protein, 3–3.5 L water, 7–10k steps, gym 3–5×/week.
- **Core action (first ten seconds, every day):** tick off the meal just eaten.
- **Feel:** bold, sporty, driven.
- **What exists:** `Siraj vai Diet App (1).html`, a working single-file web app. No logo, photos or brand assets.
- **Deliverable:** high-fidelity screens, then App Store screenshot panels.
- **Name:** the user asked for a new one. Proposal: **Daur** (দৌড়, "run / race" in Bengali). It's short and sporty, and it's his language. The user can veto it.
- **Imagery:** no image-generation tool in session and no user photos, so the richness has to be drawn (SVG shape, illustration, lit objects).

## Current app

**Audit** (`shots/before/01-before-meals.png`). The scan could not see inside the iframe, so this list is by eye. It is close to the *Calm Wellness* face in slop.md:
- Teal→blue→violet gradient header (the indigo-gradient tell).
- A progress ring with a stat-chip hero: the dashboard reflex.
- Emoji as icons everywhere: 💪 🔥 💧 🍳 🍚, plus the tab bar.
- Confetti colour: 8 accent hues, one per meal and section.
- A stack of white cards with a coloured left border. Every section is a card.
- Five tabs.
- Outfit (from the default-font list), one weight family, a flat scale.
- White text on yellow and green chips fails contrast (~1.8:1).

**Inventory: keep / lose / unknown**

| Item | Verdict |
|---|---|
| 4 meals a day with time windows (Breakfast 8–9, Lunch 1–2:30, Snack 4:30–6, Dinner 8–9) | keep |
| 2–4 swappable options per meal, with the exact items listed | keep |
| Tick a meal done; daily progress | keep (core action) |
| Per-meal "avoid" notes | keep |
| Water: 14 × 250 ml glasses, 3.5 L target | keep |
| Targets: 1,800 kcal · 130–150 g protein · 3–3.5 L · 7–10k steps | keep |
| Gym checklist: add / remove / tick / clear / restore defaults | keep |
| Walking target + optional cardio note | keep |
| Food guide: good fish, good veg, rice rule, "keep rare" lists, junk-food rule | keep (moves into a Food tab) |
| Weight log, latest, last-7 average, lost so far, last 10 entries | keep |
| Milestones: Start 109 / M1 105–106 / M2 102–103 / M3 99–101 | keep |
| Weekly check rules (0.6–0.9 kg/wk etc.) | keep |
| 10 non-negotiables | keep |
| Light/dark theme | keep (follows the system) |
| Header subtitle "109 kg · ~1,800 kcal/day · lose 3+ kg/month" | lose (the targets live where they're measured) |
| The 🌓 theme toggle button | lose (follows the system setting) |

**Assets harvested:** the meal plans, food lists, rules and milestones are reused word for word as content.

**Decisions for the user:**
1. **New name:** Daur (was "Siraj vai Diet App").
2. **Tabs go from 5 to 4:** Today · Gym · Food · Progress. Water stops being its own tab and becomes a strip on Today, because it's logged while you're there.
3. **Hero metric:** the day's meals ("2 of 4 meals") instead of a % ring. Calories and protein are now **counted per meal**. The old app only counted ticks, so this is new data the plan didn't have (estimated per option).

**History row for the current look:** `media | light | rounded | violet | colour-material`.

## Exploration (`shots/explore/sheet.png`)

| | Concept | Family | Ground | Type | Accent | Richness |
|---|---|---|---|---|---|---|
| A | "Daur is a race bib": meals are its tear-off food tabs | printed | light (cool grey) | SF Pro Expanded Black | cobalt | shape |
| B | "Daur is a 400 m track": each day is one lap, each meal is 100 m | place | colour-field (tartan red) | Big Shoulders Display (condensed) | runner yellow on red | illustration |
| C | "Daur is a loaded barbell": each meal is a plate, thickness = kcal | object | dark (rubber floor) | SF Pro Rounded Heavy | competition yellow | 3d-object |

**Winner: B, the track.** It's the most *Daur*: a day is a lap, the 12-week cut is 84 laps, and "200 m of 400" says how the day is going faster than any ring. It's loud, sporty and unlike any diet app.

- **A lost:** the bib is a strong object, but it's a printed form on cool grey with one ink colour, which is this skill's known rut. The lower half of the screen had nothing to say.
- **C lost:** the barbell is good art, but plates-as-meals needs a legend, and black + yellow + rounded reads like a gym-equipment brand rather than his daily plan.
- **Merged in from C:** each meal's kcal shown as data on its leg.

**Change from the exploration:** the display type moves from Big Shoulders (condensed) to **SF Pro Expanded Black**, which is wide and planted like painted lane numbers. Reason: the history check. B with a condensed face matched *Sortorium* (place / dark / condensed / yellow / illustration) on 3 of 5 columns. With expanded type it differs on 3 (ground, type, hue). Expanded also has tabular figures for rolling numbers, which Big Shoulders lacks.

**History check:** `place | colour-field | expanded | red | illustration`
- KeenCares: differs on 4 · GeekCRM: 4 · Bravo Secure: 4 · Sortorium: 3 · Sortorium simple: 4 · the current app (media/light/rounded/violet/colour-material): 5. Passes.

## The category default we refuse

The top diet and fitness apps share these defaults:
- **MyFitnessPal:** blue-on-white food-diary table with macro donuts.
- **Apple Fitness / Whoop:** black ground with neon activity rings, neon green or lime.
- **Noom / Lifesum:** cream-and-pastel wellness with food photos and a greeting.

The skeleton they share is a calorie ring, a 2×2 macro tile grid and a "Recent" list. The colour clichés are neon green on black, and rings in red, green and blue.

**Daur refuses all of these:**
- no rings or donuts, no macro tile grid
- no neon on black, no pastel cream
- no greeting
- no emoji food icons
- no confetti colour per meal

Progress is distance around a running track, told in metres and laps.

## Tokens

The colour-field system has one ground, the track. It means "you're on the track today". It stays the same on every tab, and sheets are lane-line white.

| Role | Light | Dark ("night session") |
|---|---|---|
| ground (tartan) | `#AD3B26` | `#3D140C` |
| infield (inside the oval, grouped areas) | `#98321F` | `#2C0E08` |
| ink (on field) | `#FFF8F3` | `#FFF1EA` |
| ink-2 | `#FFD9CC` (4.67:1) | `#E8B3A3` |
| lane / rule | `rgba(255,248,243,.55)` / `.28` | `.38` / `.20` |
| accent (runner yellow): the runner, the current leg, the primary action | `#FFD23F`, text on it `#3A1208` | `#F5CB45` |
| sheet (lane-line white) | `#FFF6EF`, ink `#2A0E07`, ink-2 `#7A4A3C` | `#1F0B07`, ink `#FFF1EA`, ink-2 `#D9A898` |

- **Yellow is the accent's one role: "you are here / do this next".** It is never used as small text on red (4.2:1). It's used as a fill, as large numerals (≥ 3:1), or as a dot.
- The system tint is ink: the selected tab is white on a lighter glass.
- No semantic red or green. Weight loss is shown as a signed number.

**Type:**
- **SF Pro Expanded Black** (`font-stretch:150%`, 900) for lap numerals, metres and hero figures. Tabular figures.
- **SF Pro Text** for everything else.

| Step | Size | Use |
|---|---|---|
| Hero | 104 | metres, kg lost; tracking −3% |
| Title | 28 | Expanded 800, −1% |
| Leg numeral | 22 | Expanded 900 |
| Body / row title | 17 | 600 / 400 |
| Secondary | 15 | 400 |
| Meta | 13 | 500 |
| Caps label | 11 | Expanded 800, +6% |

**Layout:**
- Margin 20, spacing scale 4 / 8 / 12 / 20 / 32 / 48.
- Radius family: capsule buttons, chips 10, sheets 34 (concentric with the 55 display corner).
- No cards on the field. Grouping comes from hairline rules and space.

## Richness: art direction

**Illustration, one hand:** a running track seen from directly above, drawn in 1.5 pt lane-line white on tartan.
- Dots for the 100 m marks. A yellow runner dot with a ground-coloured ring.
- No perspective, no gradients, no texture.

The same hand draws every graphic in the app:
- Progress: the 84-lap season is a field of tiny ovals.
- Gym: sets as lane ticks.
- First run: an empty track with the runner on the start line.

## Signature: "Run the leg"

The core action (log a meal) is moving the runner one leg around the track.

- **Trigger:** tap *Log snack*, **or** drag the yellow runner forward along the lane. The drag tracks 1:1 along the path and rubber-bands past the next mark.
- **Frame 1 (0 ms):** the press scales the button to 0.97, with a `.selection` haptic.
- **Frame 2 (0–420 ms):** the runner sprints along the lane on `spring(0.45, bounce 0.1)`. The lane stroke draws behind it (dashoffset), and the infield numeral rolls `200 → 300` (`.numericText`).
- **Frame 3 (420 ms):** the dot docks on the 300 m mark with `.impact(.medium)`. The leg's row flips from "by 18:00" to the logged time "17:12".
- **Frame 4 (4th meal only):** at 400 m the lane closes the loop. The lap label becomes *Lap 23 done* with `.success`, and the lap's oval fills on the Progress season grid.
- **Reduced motion:** the runner cross-fades to the next mark and the number swaps without rolling. Haptics are kept.

## Content

The cut started **Wed 17 Sep 2025** (day 1) and runs 84 days, ending Tue 9 Dec. Today is **Thu 9 Oct, day 23**. Each meal's kcal and protein are estimated per option from the plan:
- **Breakfast:** eggs + roti 384 / 22 g · eggs + oats 402 / 24 g · omelette 356 / 17 g
- **Lunch:** chicken 640 / 52 g · fish 618 / 46 g
- **Snack:** banana 95 / 1 g · guava + egg 140 / 8 g · apple + almonds 165 / 4 g · gym day 212 / 25 g
- **Dinner:** chicken 538 / 49 g · fish 512 / 44 g · eggs 430 / 27 g · Bengali 560 / 42 g

**1. Today (17:12, light).**
- Top: `LAP 23` (of 84) · `Thu 9 Oct`.
- Track: the runner at the 200 m mark. Infield `200 m` / `of 400 · 2 meals in`.
- Legs:
  - `100` Breakfast · Eggs + roti · 384 kcal · `8:41`
  - `200` Lunch · Rui + 1 cup rice · 618 kcal · `13:52`
  - `300` Snack · Gym day: banana + whey · 212 kcal · `by 18:00` *(now)*
  - `400` Dinner · Chicken + potol · 538 kcal · `20:00`
- Totals: `So far 1,002 of 1,800 kcal · 68 of 140 g protein`.
- Water: `1.75 of 3.5 L`, 7 of 14 glasses, a `+` button.
- CTA: `Log snack` · `212 kcal`.

**2. Meal sheet: Snack (17:12, over Today).**
- Title: `300 m · Snack` · `4:30–6:00 PM`.
- Options:
  - Banana: 1 small banana, black tea, no sugar · 95 kcal · 1 g
  - Guava + egg: 1 guava, 1 boiled egg · 140 kcal · 8 g
  - Apple + almonds: 1 apple, 10 almonds · 165 kcal · 4 g
  - **Gym day** *(selected)*: 1 banana, 1 scoop whey with water · 212 kcal · 25 g
- Note: `Keep it small. No chanachur, biscuits, singara, samosa, cake, soft drinks or sweet tea.`
- CTA: `Log snack`.

**3. Gym (19:34).**
- Title: `Gym` · `Session 11 · Thursday`. Hero: `5 of 9`.
- Done (3 lane ticks each): Chest press, Lat pulldown, Seated row, Shoulder press, Leg press.
- Next: Romanian deadlift. Then Biceps curl, Triceps pushdown, Core / plank.
- Row: `Add exercise`.
- Walking: `6,184 steps of 8,000` · `Cardio optional: 20–30 min`.
- Menu: Clear ticks / Restore default list.

**4. Progress (7:06, morning).**
- Hero: `−2.2 kg`. Line: `106.8 kg this morning · 7-day average 107.1`.
- Weekly check: `Down 0.7 kg this week. Stay at 1,800 kcal.`
- Season grid of 84 laps: 17 full, 4 at three-quarters, 1 at half (day 12, a dawat), today in progress, 61 to come.
- Milestones: `Month 1 · 105–106 · 16 Oct` · `Month 2 · 102–103 · 15 Nov` · `Month 3 · 99–101 · 9 Dec`.
- Weigh-ins: Thu 9 Oct 106.8 · Wed 8 Oct 107.0 · Mon 6 Oct 107.3 · Sat 4 Oct 107.1 · Thu 2 Oct 107.6.
- CTA: `Log weight`.

**5. Signature storyboard:** 200 m → sprint → docked at 300 m with `17:12` → (at the last meal) `Lap 23 done`.

**6. Today, dark (20:41).**
- Three legs done (snack `17:12`). The runner is at 300 m and dinner is now, `by 21:00`.
- `So far 1,214 of 1,800 kcal · 93 g`. Water 2.75 L (11 glasses).
- CTA: `Log dinner` · `538 kcal`.

**7. First run (7:52, Wed 17 Sep).**
- `LAP 1` of 84. An empty track, the runner on the start line, `0 m`.
- Copy: `Day 1 starts with breakfast. Eggs + roti, 8:00–9:00.`
- Starting weight field: `109.0 kg`. CTA: `Start lap 1`.

**8. App icon:** the oval track from above, three white lanes on tartan, with a yellow runner dot on the top-left bend.

**Not designed:** the Food tab (the guide lists: good fish and veg, rice rule, keep-rare lists, junk-food rule, 10 non-negotiables) and the add-exercise sheet. Both reuse the Gym list pattern.

## Gym tracking (added after round 3, unscored)

- **Gym session (19:41):** each exercise shows its plan or progress as sets × reps · weight. Examples: "3 × 10 · 40 kg", "Set 2 of 3 · 10 × 40 kg", "3 × 45 s". Set ticks sit on the right. The header shows "14 of 27 sets · 31 min". Treadmill is an optional cardio row.
- **Exercise / log a set (Romanian deadlift):**
  - Sets list: 1 done at 19:38, 2 now, 3 planned.
  - Steppers: reps ±1 and weight ±2.5 kg.
  - "Last time, Mon 6 Oct: 3 × 10 at 37.5 kg. Up 2.5 kg today."
  - CTA: "Log set 2 · 10 × 40 kg".
- **Rest timer (full-screen mode):** the runner laps the track over the 1:30 rest. "0:52" in the infield, ±15 s, CTA "Start set 2". Haptic at 0:00.
- **Treadmill (full-screen mode):** 18:24 of 25:00. Speed 5.8 km/h and incline 6 % have steppers. 1.74 km, ≈ 165 kcal. Every 400 m is a lap of the track. Pause, plus "End cardio · 18 min".
- On short phones the exercise screen drops its hero, hurdle rail and "last time" line. The set list and steppers stay.

## Water and Food guide (added after round 3, unscored)

These close the last "keep" items from the original app.

- **Water** (pushed from Today's water row):
  - Header `1.75 of 3.5 L`. 14 glasses of 250 ml; 7 are filled and the 8th is outlined in yellow as the next action.
  - "This week" bars: Fri 2.5 · Sat 2.75 · Sun 3.0 · Mon 2.5 · Tue 3.25 · Wed 3.0 · Today 1.75. This is new data; the original reset each day without history.
  - The original's advice: build up from 2.5 L, drink more on gym days, follow a doctor's fluid limit.
  - CTA `Drink a glass · glass 8 of 14`. Undo and Reset today live in the "…" menu.
- **Food tab, page 1:**
  - Rice is not banned: 1 cup at lunch, ½ at dinner, no second serving.
  - Fish and vegetable chips. "Sometimes" items (pangas, ilish) have dashed edges.
  - The dal and oil note.
- **Food tab, page 2 (scrolled):**
  - Keep rare (hurdle glyph): Fried, Fast food, Heavy Bengali, Drinks, Snacks.
  - The junk-food rule with a `7 days to month 2` countdown.
- **Food tab, page 3 (scrolled):** the 10 non-negotiables in a numbered 2-column grid, with the protein and sleep note.
- **Walk** (pushed from Today's walk row, 17:20):
  - Header `5,410 steps`, with the subtitle "Week 4 · target 8,000 steps". A straight lane with 1k marks, and the runner at 5.4k.
  - `2,590 to go, about 25 minutes of brisk walking` · 3.9 km · ≈ 210 kcal.
  - The build-up from the plan, with this week's step highlighted: weeks 1–2 at 7,000 · weeks 3–4 at 8,000 (now) · weeks 5–12 at 9,000–10,000.
  - This week's bars against a dashed 8k target line.
  - CTA `Start a walk · 25 min to target`.
  - Today's walk row now reads "of 8,000 steps" (this week's target) instead of "of 7–10k".
