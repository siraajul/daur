# Mobile onboarding: research and a recommendation for Daur

Researched 2026-10-09 with standard web search. Evidence labels:
- **[measured]**: a controlled study, peer-reviewed analysis, or first-party product data with a stated metric.
- **[vendor]**: a vendor or analytics-company claim. Usually no methodology is given.
- **[teardown]**: third-party screen captures or reviews. Opinion, and tied to whichever app version was captured.
- **[guideline]**: platform documentation (Apple or Google).

I couldn't load Apple's HIG pages directly, because they render with JavaScript. HIG quotes therefore come from a verbatim Markdown mirror of the current pages ([onboarding mirror](https://raw.githubusercontent.com/tmaasen/apple-dev-mcp/main/content/universal/onboarding.md), [privacy mirror](https://raw.githubusercontent.com/tmaasen/apple-dev-mcp/main/content/universal/privacy.md)) and from an older quoted version ([kde.hateblo.jp](https://kde.hateblo.jp/entry/2020/06/24/013143)). The canonical pages are [HIG Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) and [HIG Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy).

---

## PART 1: Taxonomy of mobile onboarding

| # | Type | What it is | Works when | Fails when | Strong real example |
|---|---|---|---|---|---|
| 1 | **Benefits-oriented (value carousel)** | 1–3 swipeable slides that say *why* the app is worth using, not how to use it. Material calls it "Top User Benefits": "a brief autoplay carousel… highlighting up to three benefits" ([Material](https://m1.material.io/growth-communications/onboarding.html)); Smashing gives the same definition ([Smashing 2014](https://www.smashingmagazine.com/2014/08/mobile-onboarding-beginners-guide)). | The concept is new or unusual and needs a mental model before the UI makes sense. | It runs past 3 slides, makes generic claims ("stay organised"), or stands between the user and the content. Material: max three illustrations, and "Don't combine Top User Benefits with Self Select". | Lose It!'s welcome screen: one screen of icons (goals, logging, barcode, workouts, charts) before setup starts ([Lazyweb teardown](https://lazyweb.com/canvas/flows/lose-it/onboarding)) [teardown]. |
| 2 | **Function-oriented (feature walkthrough / tour)** | Up-front slides or overlays that show *how* to use features ([Smashing](https://www.smashingmagazine.com/2014/08/mobile-onboarding-beginners-guide)). | The interaction is unfamiliar and can't be discovered (custom gestures). | Almost always, for simple apps. NN/g tested deck-of-cards tutorials on 70 users and 4 apps. Task success was 91% with the tutorial and 94% without (not significant). Tutorial readers rated the tasks *harder*: 4.92 vs 5.49 on a 7-point scale, p = 0.047. They were not faster ([NN/g](https://www.nngroup.com/articles/mobile-tutorials/)) [measured]. NN/g: "Think twice about creating a tutorial for simple applications." | Nike Run Club teaches its coaching through a "First Run" guided run, a tour you take by doing rather than slides ([Logicity guide](https://logicity.in/en/blog/5-nike-run-club-hacks-for-smarter-training)) [teardown]. |
| 3 | **Progressive / contextual (just-in-time tips, coach marks)** | One tip at a time, shown when the user reaches the relevant UI. Apple: "Consider providing a collection of context-specific tips instead of a single onboarding flow" ([HIG mirror](https://raw.githubusercontent.com/tmaasen/apple-dev-mcp/main/content/universal/onboarding.md)) [guideline]. | Features are secondary or advanced and only matter in a certain moment. | Tips pile up, several fire on one screen, or a tip blocks the action it describes. | Apple's own TipKit framework exists for exactly this pattern: one tip per feature, with display rules ([TipKit](https://developer.apple.com/documentation/tipkit)). |
| 4 | **Interactive / learn-by-doing** | The first real task, done inside the real UI with light guidance. HIG: "Teach through interactivity" [guideline]. | The core action is short and gives instant feedback. | The first task is long, needs data the user doesn't have yet, or gets faked with "static screenshots that appear interactive" (old HIG wording, [kde.hateblo.jp](https://kde.hateblo.jp/entry/2020/06/24/013143)). | Duolingo puts users into a short translation exercise before any sign-up ([Appcues](https://goodux.appcues.com/blog/duolingo-user-onboarding)) [teardown]. |
| 5 | **Account / personalisation questionnaire** | Questions about goal, body stats, preferences and schedule, used to tailor the plan. Material calls it "Self-Select": "Each screen should have fewer than ten choices" ([Material](https://m1.material.io/growth-communications/onboarding.html)). | Each answer visibly changes what you get, and the plan cannot work without it. | Questions feed nothing visible, sensitive questions come with no reason given, or the quiz is a paywall funnel. HIG: "Postpone nonessential setup flows or customization steps" and "Provide reasonable default settings" [guideline]. | Fitbod asks for goal, experience and equipment, and the first workout reflects all three ([Fitbod help](https://help.fitbod.me/hc/en-us/articles/30721771750039-Getting-Started-with-Fitbod-A-New-User-s-Guide)). Noom is the extreme case: up to 113 screens and 10–15 minutes ([RevenueCat](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel)) [teardown]. |
| 6 | **Permission priming (pre-permission screen)** | Your own screen explains the benefit, then opens the one-shot OS dialog. | It's shown right before the feature that needs the permission, and declining is easy. | It's asked at launch, before any value, or bundled with other permissions. On Android a second "Deny" becomes a permanent denial ([Android](https://developer.android.com/training/permissions/requesting)). In Health Connect two cancels lock the app out ([HC docs](https://developer.android.com/guide/health-and-fitness/health-connect/get-started)). | Nike Run Club's help explains *why* it needs Location and iOS Motion & Fitness before the first run ([Nike help](https://www.nike.com/ie/help/a/nrc-start-run)). |
| 7 | **Empty-state onboarding** | The first-run empty screen becomes the tutorial: what goes here, why, and a button to start. NN/g's three rules are to communicate system status, provide learning cues, and provide "direct pathways for key tasks" ([NN/g](https://www.nngroup.com/articles/empty-state-interface-design/)). | Every list or graph starts empty, as in trackers. | The screen is just blank, or shows a mascot with no action. | NN/g's examples: an empty dashboard or alerts pane that explains itself and links to the first action ([NN/g](https://www.nngroup.com/articles/empty-state-interface-design/)). |
| 8 | **Deferred / lazy setup (gradual engagement)** | Use the app now and fill in details when they're needed. Luke Wroblewski's "Sign Up Forms Must Die": make people "successful right away" ([LukeW slides](https://static.lukew.com/SignUpForms_10052010.pdf)). | Defaults are good enough to start. | A wrong default silently corrupts results, for example the wrong start date on a fixed plan. | Duolingo: lessons before an account, with account prompts later ([Appcues](https://www.appcues.com/blog/gradual-engagement-mobile-app-first-screen)) [teardown]. |
| 9 | **Checklist / setup progress** | A visible "3 of 5 done" list. It draws on the *endowed-progress effect*: car-wash cards that came with 2 of 10 stamps pre-filled were completed by 34% of customers, against 19% for blank 8-stamp cards ([Nunes & Drèze 2006, summary](https://thinkinsights.net/consulting/endowed-progress-effect)) [measured]. | Setup has several independent optional parts. | There's only one real task, or the list nags forever. | Lose It! shows a plan-setup step list (Weight Goal → Calorie Budget → Schedule → Strategy) before the questions ([Lazyweb](https://lazyweb.com/canvas/flows/lose-it/onboarding)) [teardown]. |
| 10 | **"Aha moment" / time-to-value design** | Find the action that predicts retention and design the first session to reach it fast. | The aha is a concrete, measurable action. | The team optimises a vanity step instead. | Facebook's "7 friends in 10 days" activation heuristic ([secondary write-up](https://scratch-puffin-363.notion.site/Facebook-s-7-friends-activation-story-a-PM-case-study-33dec508b5118053bff8e0233fedd0f3)). It's widely retold, and I found no primary source. |
| 11 | **Reverse trial / paywall onboarding** *(noted only)* | A long quiz and a projection graph, then a paywall. In a Lazyweb sample of 129 flows, flows with a paywall averaged 17.2 steps (median 14) vs 12.4 (median 10) without, and the paywall sat at median step 11 ([Lazyweb](https://www.lazyweb.com/research/are-onboarding-flows-with-a-paywall-longer)) [teardown dataset]. | — | — | Not relevant to Daur (no store listing, no paywall). |

### What the platforms say

**Apple HIG: Onboarding** [guideline] ([mirror](https://raw.githubusercontent.com/tmaasen/apple-dev-mcp/main/content/universal/onboarding.md))
- If onboarding is necessary, "design a flow that's fast, fun, and optional". Ideally people learn the app "simply by experiencing it".
- "Teach through interactivity." "Consider providing a collection of context-specific tips instead of a single onboarding flow."
- "Postpone nonessential setup flows or customization steps." "Provide reasonable default settings so most people can immediately start interacting."
- Earlier editions had the headings "Get to the action quickly", "give people a way to skip them", "Stick to the essentials in tutorials" and "Make learning fun and discoverable" ([kde.hateblo.jp](https://kde.hateblo.jp/entry/2020/06/24/013143)). The phrase "get to the content quickly" is a paraphrase of these.
- On permissions, the onboarding page allows integrating a request into onboarding if it's needed to function, because that "gives you the opportunity to show people why". Otherwise "present a permission request when people first access the specific function that relies on private data."

**Apple HIG: Privacy** [guideline] ([mirror](https://raw.githubusercontent.com/tmaasen/apple-dev-mcp/main/content/universal/privacy.md))
- "Request permission only when your app clearly needs access." "Avoid requesting permission at launch unless the data or resource is required for your app to function."
- A custom pre-alert screen should "Include only one button and make it clear that it opens the system alert". Don't add other actions, don't offer incentives, and don't label your own button "Allow".
- Purpose strings should be "a brief, complete sentence that's straightforward, specific."
- **HealthKit:** an app *cannot tell* whether read access was denied. A denial looks like an empty store ([Cocoacasts](https://cocoacasts.com/more-about-managing-permissions-with-healthkit); [Apple docs](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)). Users fix it under Settings › Privacy & Security › Health, and there's no public deep link to that screen ([Apple forums](https://developer.apple.com/forums/thread/842499)).
- **Live Activities:** "give people control over beginning and ending". Use them only for tasks with a defined start and end, under 8 hours, with no sensitive health details on the Lock Screen ([HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities); [9to5Mac summary](https://9to5mac.com/2022/09/26/iphone-14-pro-live-activities-guidelines/)).

**Material (Android) onboarding** [guideline] ([Material 1](https://m1.material.io/growth-communications/onboarding.html))
- Three models: Self-Select, Quickstart ("Start the user directly in the app") and Top User Benefits.
- "Show onboarding to first-time users. Don't show it to returning users."

**Android runtime permissions** [guideline] ([developer.android.com](https://developer.android.com/training/permissions/requesting))
- "Ask for a permission in context, when the user starts to interact with the feature that requires it."
- "Don't block the user." Always offer cancel. If denied, "gracefully degrade".
- Denying twice is a permanent denial (`USER_FIXED`). "Don't link to system settings in an effort to convince the user to change their decision."

**Android 13+ notifications (POST_NOTIFICATIONS)** [guideline] ([notification permission](https://developer.android.com/develop/ui/views/notifications/notification-permission))
- "let them familiarize themselves with your app"; "you might wait until the third or fourth time the user launches your app".
- Trigger the prompt from a user action, such as tapping a bell, following someone, or placing an order.

**Exact alarms on Android 14+** [guideline]: `SCHEDULE_EXACT_ALARM` is denied by default, and Google recommends inexact alarms where possible ([Android 14 change](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)). Meal reminders don't need minute precision.

**Health Connect** [guideline]
- Request only the data types you use. Ask in context, and re-check granted permissions over time because users can revoke them ([get started](https://developer.android.com/guide/health-and-fitness/health-connect/get-started)).
- The manifest must provide a privacy-policy / rationale activity (`ACTION_SHOW_PERMISSIONS_RATIONALE`; on Android 14+ an activity-alias for `VIEW_PERMISSION_USAGE`).
- **If the user cancels twice, the app is locked out.** Show a screen with a "Manage access" link into Health Connect ([HC permissions UI](https://developer.android.com/health-and-fitness/health-connect/ui/permissions)).
- An optional onboarding activity (`SHOW_ONBOARDING`) "may be launched more than once" ([HC onboarding](https://developer.android.com/health-and-fitness/health-connect/ui/onboard-users)).
- By default an app can read only 30 days of history before its *first* grant ([read data](https://developer.android.com/health-and-fitness/health-connect/read-data)).

**Android widgets** [guideline] ([widget discovery](https://developer.android.com/design/ui/mobile/guides/widgets/discovery-promotion))
- "Present the pin widget option… after a user successfully completes a task that has a corresponding widget or when a user repeatedly accesses a feature."
- Use "subtle visual hints". The prompt "should never block or hinder the user's primary actions."
- Pinning uses `requestPinAppWidget()` and requires a check of `isRequestPinAppWidgetSupported()` first ([dev guide](https://developer.android.com/develop/ui/views/appwidgets/discoverability)).

**Android 16+ Live Updates**: progress-centric notifications (`ProgressStyle`) promoted to status-bar chips, the Android counterpart to Live Activities ([ProAndroidDev](https://proandroiddev.com/live-updates-in-android-16-exploring-the-next-evolution-of-notifications-1a5cf5de2068)). This is a secondary source; I didn't fetch Google's own page.

---

## PART 2: Fitness and nutrition apps

### What leading apps do

| App | Up-front asks | How targets are computed | Flow length | Permission placement | First win |
|---|---|---|---|---|---|
| **MyFitnessPal** | Goals (up to 3), past barriers, habits, lifestyle, activity level, sex, birthdate, height, current and goal weight ([Lazyweb](https://lazyweb.com/canvas/flows/myfitnesspal/onboarding); [UX Collective](https://uxdesign.cc/how-myfitnesspal-became-myfitnessenemy-ffc49b481534)) | Calorie goal from stats, activity and goal pace (formula not public) | ~18–25 steps; account created late, then a Premium paywall ([Screensdesign](https://screensdesign.com/showcase/myfitnesspal-calorie-counter)) [teardown] | Not documented in the teardowns | Meal planner / diary after the paywall. The reviewer calls the length a friction risk |
| **Noom** | Goal (with an "I haven't decided" option), units, age band, height, weight, sex, medical conditions, 10 behaviour sliders, event, pace | Projection graph to a goal date; unhealthy goals blocked | Up to 113 screens, 10–15 min; email gate about 1/3 in; price after ~100 screens ([RevenueCat](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel)) [teardown]. 40–50 questions per [Rocketship HQ](https://www.rocketshiphq.com/?p=5491) | After the web funnel | The reviewer never saw the real app before paying, the main criticism |
| **Lose It!** | Goal weight (kg/lb/st picker), calorie-counting history, nutrition strategy, intermittent fasting | Calorie budget plus a "calorie schedule" (higher weekends) | ~70 steps in Lazyweb's capture, with a step list up front ([Lazyweb](https://lazyweb.com/canvas/flows/lose-it/onboarding); [Reteno](https://gallery.reteno.com/flows/app-screens-lose-it)) [teardown] | App Tracking Transparency prompt right after welcome, an anti-pattern for a health app | Plan summary with projected date |
| **Lifesum / Yazio** | Conversational goal quiz | Calorie and macro plan | Lifesum about 14 steps; "Unlock Pro" at about screen 9 for both ([Lifesum](https://screensdesign.com/showcase/lifesum-food-calorie-tracker); [Yazio](https://screensdesign.com/apps/yazio-calorie-counter-diet/)) [teardown] | Lifesum asks for notifications at 0:15, which the reviewer calls "premature" | Plan summary |
| **Cronometer** | Age, sex, height, weight; activity slider; weight goal and rate | **Mifflin-St Jeor** BMR + baseline activity; a synced tracker gradually replaces baseline activity ([Cronometer support](https://support.cronometer.com/hc/en-us/articles/360021677792)). The CEO warns about double-counting when a tracker is linked ([forum](https://forums.cronometer.com/discussion/comment/1166)) | Short | — | Diary |
| **MacroFactor** | Demographics, body stats, activity, goal and rate | Starts from an equation, then **learns expenditure from logged intake and weight trend**. Good estimates arrive in about 14–30 days. Users can import 30 days of history or enter a known TDEE ([Stronger by Science welcome](https://www.strongerbyscience.com/welcome-to-macrofactor/); [help: static vs dynamic](https://help.macrofactorapp.com/en/articles/64-how-to-change-your-expenditure-estimate-from-dynamic-to-static)) | Medium | — | First weigh-in and log; the value compounds over weeks |
| **Strava** | Name, birthday, gender ([Screensdesign](https://screensdesign.com/articles/strava-onboarding-design/)) | — | Short | Location when recording | Gets users "to their first recorded activity fast" ([UXCam](https://uxcam.com/blog/10-apps-with-great-user-onboarding/)) [teardown]. 30-day retention reported at 16% iOS / 8% Android (Apptopia via [Alchemer](https://www.alchemer.com/resources/blog/tough-love-tuesday-stravas-missed-opportunity-to-drive-mobile-app-retention-and-gain-actionable-product-feedback/)) [vendor, undated] |
| **Nike Run Club** | Height and weight, with a default if you'd rather not share | Pace and calories from body stats | Mostly account creation; a reviewer says it misses orienting users to Guided Runs ([Screensdesign](https://screensdesign.com/showcase/nike-run-club-running-coach)) | Location and iOS Motion & Fitness, explained in help ([Nike](https://www.nike.com/ie/help/a/nrc-start-run)) | The "First Run" guided run teaches by doing |
| **Apple Fitness** | Age, weight (plus sex and height via Health) | Suggests Move-goal presets, editable later ([iGeeksBlog](https://www.igeeksblog.com/how-to-use-fitness-app-on-iphone/); [CNN](https://amp.cnn.com/cnn/cnn-underscored/electronics/apple-watch-activity)) | A few screens | Notifications at the end of setup; Motion via system settings | The ring starts filling with zero effort, because data is passive |
| **Fitbod** | Goal, experience, equipment, split / days | Algorithm sets intensity from experience ([Fitbod](https://help.fitbod.me/hc/en-us/articles/360004429814-How-Fitbod-Creates-Your-Workout)) | Medium; everything editable later in Gym Profile | — | A complete first workout with sets, reps and weights |
| **Ladder** | Team-matching quiz (goals, equipment, demographics) | Coach-programmed plan | "1 click and 3 screens" to the next section ([UX Collective](https://uxdesign.cc/how-ladder-onboards-and-keeps-users-engaged-5716dd1c9f3e); [Garage Gym Reviews](https://www.garagegymreviews.com/ladder-app-review)) [teardown] | — | Press play on a coached workout |
| **Duolingo** (habit cross-reference) | Language, reason, daily goal | — | Lesson within a few taps; account later ([Appcues](https://goodux.appcues.com/blog/duolingo-user-onboarding)) | Notifications after the first lesson | First lesson. **7-day streak → 3.6× more likely to finish the course; 2.4× more likely to return the next day** ([Duolingo blog](https://blog.duolingo.com/how-duolingo-streak-builds-habit); [improving the streak](https://blog.duolingo.com/improving-the-streak)) [first-party, no methodology] |

### Patterns worth copying, and patterns to skip

1. **Commercial apps use long quizzes because of the paywall, not because the plan needs the data.** In Lazyweb's sample, flows with a paywall run about 40% longer (17.2 vs 12.4 steps) [teardown dataset]. Without a paywall, the HIG and Material advice (short, defaults, defer) wins.
2. **Equation-based targets are rough.** Mifflin-St Jeor was the most accurate of the common equations in Frankenfield 2005, predicting RMR within 10% of measured for more people than the others. The review still warns of "noteworthy errors" for individuals ([PubMed 15883556](https://pubmed.ncbi.nlm.nih.gov/15883556/)) [measured]. That's why MacroFactor recalibrates from the weight trend after 2–4 weeks. Cronometer also warns about double-counting when step trackers are added on top of an activity level.
3. **Early outcomes predict long-term success, so the first month deserves the attention.** In Look AHEAD (n = 2,290), losing ≥2% at month 1 or ≥3% at month 2 meant 4.8× and 8.4× higher odds of ≥5% loss at year 1 ([UMN record](https://experts.umn.edu/en/publications/weight-change-in-the-first-2-months-of-a-lifestyle-intervention-p/)) [measured]. In a UK service, each 1% lost in month 1 raised the odds of long-term success ([Healio, conference abstract](https://www.healio.com/news/endocrinology/20220921/early-weight-loss-in-behavioral-weight-management-programs-predicts-long-term-success)).
4. **Self-monitoring correlates with weight loss**, though the evidence is weak and no minimum "dose" has been established ([Burke et al. 2011 review](https://pubmed.ncbi.nlm.nih.gov/21185970/)) [measured]. In Noom's 35,921-user cohort, 77.9% lost weight, and more frequent input correlated with more loss ([Chin 2016](https://pmc.ncbi.nlm.nih.gov/articles/PMC5098151)). A 2021 JMIR study of 11,252 users tied outcomes to meals logged and weigh-ins ([JMIR mHealth 2021](https://mhealth.jmir.org/2021/11/e30622)). Both are observational and Noom-affiliated.
5. **Logging drops on weekends.** An observational study suggests weekend prompts ([Pellegrini 2018 summary](https://www.nutritioninsight.com/news/dietary-self-monitoring-on-smartphone-impacted-by-day-of-week-but-not-season-of-year.html)). A micro-randomised trial of meal-logging reminder types is still recruiting ([NCT07555262](https://clinicaltrials.gov/study/NCT07555262)), so reminder framing is still unproven.
6. **Health & Fitness retention is poor across the industry**: about 20–27% at Day 1 and about 3–4% at Day 30 ([Phiture](https://phiture.com/mobilegrowthstack/managing-retention-rate-benchmarks-and-expectations/); [Braze/AppsFlyer](https://www.braze.com/resources/articles/mobile-app-retention); [Adjust](https://www.adjust.com/blog/what-makes-a-good-retention-rate/)) [vendor]. For a one-user app the relevant risk is the same: the habit lapsing in weeks 1–3.
7. **Onboarding length vs completion** [vendor/anecdotal]: UXCam reportedly finds median completion falls below 60% for flows longer than 5 screens ([Sonar](https://trysonar.app/blog/app-onboarding-that-protects-day-1-retention)). Per-screen loss estimates range from 5% to 20% ([Affective](https://weareaffective.com/learning-centre/how-can-i-check-if-my-onboarding-flow-is-too-long)). These numbers are not reliable; I use them only as a direction.
8. **Push priming**: vendors claim priming lifts opt-in "2–3×" ([Plotline](https://www.plotline.so/blog/how-to-improve-push-notification-opt-in-rates)) [vendor, uncontrolled]. Google's own guidance matters more for Daur: ask from a user action, after a few launches.
9. **Habits take time to form, and the timeline matches Daur's plan.** Lally et al. ran a daily health behaviour for **84 days**, the same length as Daur's cut. Median time to automaticity was 66 days (range 18–254). Missing one day barely mattered; longer gaps hurt ([UCL](https://www.ucl.ac.uk/news/2009/aug/how-long-does-it-take-form-habit); [critical summary](https://www.thebehavioralscientist.com/articles/how-long-to-form-a-habit)) [measured, small n]. Duolingo's streak freeze applies the same idea.
10. **Planned diet breaks have trial support.** In MATADOR, men with obesity did 2-week blocks of dieting alternated with 2 weeks at maintenance. They lost more and regained less than continuous dieters (about 8 kg more at 6 months after) ([Byrne 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC5803575)) [measured, n = 51]. This informs what to offer at week 12.

---

## PART 3: Recommendation for Daur

### 3.1 Which onboarding types fit a one-user personal app

| Type | Fit for Daur | Why |
|---|---|---|
| Benefits carousel | **One screen only** (exists) | The track metaphor needs a mental model. There's nothing to sell beyond that. |
| Feature tour | **Drop** | NN/g found no benefit. The app has one owner, and the drawer and widgets are better taught in context. |
| Progressive tips | **Yes, the main tool** | Widgets, drawer, Live Activity / Live Update, junk rule and month-2 change all have a natural moment. |
| Learn-by-doing | **Yes: the first meal log *is* the onboarding finish** | The core loop is one tap plus a pick, and the payoff (runner runs 100 m) is instant. |
| Questionnaire | **Minimal** | The targets are *prescribed* by the plan (`plan.dart` constants), not derived from BMR. Asking height and age would compute a second number that competes with the plan. |
| Permission priming | **Yes, three separate moments** | Steps, notifications for live sessions, and notifications for reminders, each primed at its own moment. |
| Empty states | **Yes** | Progress graph, Gym log and Walk row all start empty. |
| Deferred setup | **Yes** | Reminder times, gym days and backups can all wait. |
| Checklist | **No** | There are only about 3 optional set-up items. A checklist would nag the only user. |
| Aha / time-to-value | **Yes**: aha = "I logged a meal and the runner moved 100 m", target under 60 s from first launch | |
| Re-onboarding | **Yes, the biggest gap** | A fixed 84-lap plan has three known turning points (lap 31 junk rule, about lap 28 calibration, lap 84 finish) plus unplanned pauses. |

### 3.2 Audit of the current 3 pages (`lib/onboarding.dart`)

**Keep**
- **Page 1 concept, with the animated track.** It's the right benefits-oriented screen: one idea, one screen.
- **Page 2 "Earlier…" date picker.** It's essential, because a wrong Day 1 shifts every lap.
- **Page 2 weigh-in tip** ("after the bathroom, before breakfast").
- **Page 3 steps priming copy.** "It only reads steps, and nothing leaves your phone" is specific, as HIG asks for.
- **Notification permission requested when a rest timer or treadmill first goes live.** This already matches Google's "trigger from a user action" guidance.

**Missing**
1. **No first win.** Onboarding ends with "Start lap N" on a static targets list. The aha (runner runs 100 m) only happens if the user finds the meal card alone. Onboarding should end *on* the meal card that's due now.
2. **Day 1 in the past gives a wrong current weight.** If Day 1 was three weeks ago, "Starting weight" is day-1 weight, and the app has no today weight. Progress then starts from a stale point. Fix: when Day 1 ≠ today, label the stepper "Weight on day 1" and add an optional "Today's weight" row.
3. **No handling for Health Connect cancel or lockout.** Two cancels lock Daur out for good. "Try again" should stop after one cancel, and after a lockout should become "Open Health Connect" (Manage access). On iOS, a denial is invisible, so the Walk row needs a "Seeing 0? Check Health access" hint.
4. **No re-onboarding** at lap 31 (the junk allowance goes from 0 to 1/week; `store.junkAllowance`), at the end of week 12, or after a gap.
5. **No contextual widget prompt.** It's only in the drawer today.

**Unnecessary or inconsistent**
- **Water target mismatch.** The page 3 targets list says "Water 3–3.5 L", while the plan has `waterGlasses = 14` (3.5 L) and the brief says 3.5 L. Pick one.
- **The full targets list on page 3 is a passive read-only table** that Today already shows. Shrink it to one line so page 3 is about one decision: connect steps or not.
- **The top-right "Skip" on pages 1–2 is fine,** but make clear that skip still means Day 1 = today and 109.0 kg (state it in the CTA).

### 3.3 Ask vs default

| Item | Decision | Reason |
|---|---|---|
| Day 1 date | **Ask** (default today) | It drives everything, and only the user knows it. |
| Starting weight | **Ask** (default 109.0) | Anchors Progress. |
| Today's weight, only if Day 1 is in the past | **Ask, optional** | Seeds the trend. |
| Height, age, sex | **Don't ask** | Targets are prescribed. BMR equations carry individual error (Frankenfield 2005). Calibrate from the real weight trend at about lap 28 instead (MacroFactor's logic, done by hand). Add later only if auto-adjusting targets is ever wanted. |
| Units | **Don't ask**; fixed kg, L, m, kcal | One metric user. Adding a toggle only adds code. |
| Meal times | **Default to the plan windows** (08:00–09:00, 13:00–14:30, 16:30–18:00, 20:00–21:00) | Ask only when reminders are first switched on, as editable times. |
| Gym days | **Don't ask up front** | Target is "3–5 per week", counted from logged sessions. Ask, optionally, only if gym reminders are switched on. |
| Reminder times | **Deferred** to the reminders opt-in on day 2 | Google: wait a few launches, trigger from an action. |
| Steps source | **Ask (page 3), skippable** | It's a core daily target and the user is already in setup mode. The HIG allows an onboarding request when you can show why. |
| Notifications | **Never during onboarding** | |
| Diet preferences | **Don't ask** | The meal options *are* the plan. |
| Backup / export | **Don't ask** in onboarding; one hint at lap 7 | Data stays on the phone, so losing the phone loses 84 days. This is a data-loss risk worth one hint. *(Only if an export exists; otherwise note it as a gap.)* |

### 3.4 Where each permission is primed

| Permission | When | Prime copy | If declined |
|---|---|---|---|
| **Health Connect `READ_STEPS`** (Android) / **HealthKit step count read** (iOS) | Page 3, the user taps **Connect** | Existing copy. Add: "Only steps. Read on this phone, never sent anywhere." | Android, 1st cancel: show "Not connected. You can connect from the Walk row." Stop auto-retrying. 2nd cancel = lockout: show "Health Connect has blocked further requests. Open Health Connect → Daur to allow steps" with a **Manage access** button. iOS: you can't detect denial, so if steps = 0 after 15:00, show the Walk row hint "Seeing 0? Settings › Privacy & Security › Health › Daur." |
| **Motion / Activity Recognition** | **Not needed** | Steps come through Health Connect or HealthKit, not a raw pedometer. Don't declare `ACTIVITY_RECOGNITION` or `NSMotionUsageDescription` unless you add on-device counting. | — |
| **POST_NOTIFICATIONS: live sessions** | First time a rest timer or treadmill starts (existing) | "Show the timer on your lock screen while you lift?" One button: "Continue" (opens the system dialog). | The timer still runs in-app. No nag. |
| **POST_NOTIFICATIONS: meal reminders** | **Day 2**, right after the user logs a meal (a user action, after at least 2 launches) | Inline card: "Want a nudge when a meal window opens? Breakfast 08:00 · Lunch 13:00 · Snack 16:30 · Dinner 20:00. Change times anytime." Buttons: "Set reminders" / "No thanks". If notifications are already granted from a live session, skip the OS step. | Card never returns. A toggle stays in the drawer. |
| **Exact alarms** | **Don't request** | Use inexact scheduling (`setAndAllowWhileIdle` or WorkManager). A few minutes of drift is fine for meals. | — |
| **Widget pin** (not a permission, but a system sheet) | After the first full lap (4th meal logged), on the "Lap 1 done" moment | See H4 below. | Never shown again; drawer item stays. |

### 3.5 First win in under a minute

Estimated times: page 1 ~8 s, page 2 ~12 s, page 3 ~10 s, first log ~20 s. Total about 50 s.

1. "Start lap N" lands on **Today** with the meal card for *the current or next window* highlighted. Before 11:00 that's Breakfast; 11:00–15:00 Lunch; and so on. After 21:30 the card reads "Already eaten today? Log any meal."
2. One coach mark, anchored to that card: **"Tap Breakfast and pick what you had. Your runner runs the first 100 m."** It dismisses on tap anywhere.
3. The meal sheet opens with plan option 1 preselected → **"Log"**.
4. The runner animates 0 → 100 m, with a light haptic and the line **"Lap 1 · 100 of 400 m"**. That's the aha.
5. Nothing else is shown on day 1 except the "Lap done" moment if 4 meals get logged.

### 3.6 Ordered spec

**Screen 1: Concept** *(benefits-oriented, one screen)*
- Title: **"Every meal moves you 100 m."**
- Body: "Four meals make one 400 m lap. Your 12-week cut is 84 laps. Ate something off-plan? Log what you really ate; the calories stay honest."
- Visual: the animated track. *Optional:* tap the runner and it runs a leg (a 2-second taste of the interaction).
- CTA: **Next**. Top-right: **Skip** → Today with Day 1 = today, 109.0 kg, steps not connected (state this in a toast: "Started today at 109.0 kg. Change in the drawer.").

**Screen 2: Where you start** *(minimal questionnaire)*
- Title: **"Where you start"**
- Day 1 row: [**Today**] [**Earlier…**] (date picker, help text "Day 1 of the 12-week cut", no future dates).
- Line: "Today is lap N of 84."
- Stepper label: **"Starting weight"** if Day 1 = today; **"Weight on day 1"** if earlier. Default 109.0, step 0.1, hold to accelerate.
- If Day 1 is earlier: an extra optional row **"Today's weight (optional)"**, collapsed as "+ Add today's weight".
- Tip: "Weigh after the bathroom, before breakfast."
- CTA: **Next · 109.0 kg**. Skip keeps the defaults.

**Screen 3: Steps** *(permission priming, one decision)*
- Title: **"Steps from your phone"**
- Body (Android): "Daur can read your steps from Health Connect, where Google Fit, Samsung Health and Fitbit sync. Only steps, read on this phone, never sent anywhere."
- Body (iOS): same, with "Apple Health".
- Body (web): "The browser can't count steps. Type them on the Walk row when you like." No button.
- Primary: **Connect** (opens the Health Connect / HealthKit sheet for steps only). Secondary text button: **Later**.
- States: Connected ("Connected · 4,210 steps today"); Not connected after one cancel ("You can connect from the Walk row."); Locked out ("Open Health Connect" button).
- Footer, one line: "Daily: ~1,800 kcal · 130–150 g protein · 3.5 L water · 7,000 steps · gym 3–5×/week".
- CTA: **Start lap N** → Today, first-win coach mark (3.5).

**Contextual hints**
Rules for all hints:
- At most one per day.
- Each is shown once, and dismissing it is permanent.
- Each is an inline card or a single anchored tooltip, never a modal sequence.
- Everything a hint teaches is also reachable from the drawer.
- Store seen hints in a `seenHints` set in `Store`.

| ID | Trigger | Surface | Copy | Action |
|---|---|---|---|---|
| H1 | First Today screen after onboarding | Tooltip on the due meal card | "Tap Breakfast and pick what you had. Your runner runs the first 100 m." | — |
| H2 | First time Today has any empty row (Water / Walk) | Empty-state text in the row | Water: "Tap + for each 250 ml glass. 14 glasses = 3.5 L." Walk (not connected): "Type steps, or connect Health Connect." | Inline link |
| H3 | Day 2, after the first meal is logged | Inline card below the meal | Meal reminders (3.4) | Set reminders / No thanks |
| H4 | First lap completed (4 meals in a day) | The "Lap 1 done" moment, then a card | Android: "Log water and meals from your home screen." **Add widget** (uses `requestPinAppWidget`; hidden if unsupported). iOS: "Add the Daur widget: long-press the home screen → + → Daur." | Add widget / Not now |
| H5 | First treadmill or rest-timer start (after the existing notification prime) | Snackbar | iOS: "It's on your Lock Screen and Dynamic Island now." Android 16+: "It's in your status bar now; pull down to pause." | — |
| H6 | Day 3 (any open), if the drawer has never been opened | Small dot on the menu icon plus a one-time tooltip | "Food guide, the 10 rules, water, walk and treadmill live here." | Opening the drawer clears it |
| H7 | First time a keep-rare (junk) food is added in month 1 | Inline line in the meal sheet (already partly there via `junkStatus`) | "Month 1: junk stays near zero. The full rule is in Food guide." | Link to Food guide |
| H8 | iOS, Health connected, steps = 0 at 15:00 | Walk row | "Seeing 0? Check Settings › Privacy & Security › Health › Daur." | — |
| H9 | Each day the step target steps up (7k → 10k ramp) | Walk row, that day only | "New target from today: 8,000 steps." | — |
| H10 | Lap 7 | Card on Progress | "Week 1 done. Your data lives only on this phone." (+ "Export a backup" if an export exists) | — |

**Re-onboarding**

| Moment | Trigger | What happens | Copy |
|---|---|---|---|
| **Pause / return** | App opened with ≥2 full days unlogged | Sheet. No reset; missed laps stay grey, honest and not punished (per Lally, single misses barely matter; long gaps do). Offer a weigh-in. | "Welcome back. You missed 3 days, and that's fine. Today is lap 23. Weigh in this morning?" [Weigh in] [Just log today] |
| **Wrong Day 1** | Anytime, from drawer | Re-opens Screen 2, prefilled | "Change Day 1? Laps will re-line up." |
| **Calibration check** | Lap 28, if ≥4 weigh-ins | Card on Progress comparing the 4-week trend to the expected pace. No automatic target change, because the plan is prescribed. (Evidence: early loss predicts outcome; equations need about 2–4 weeks to correct.) | On pace: "Down 3.4 kg in 4 weeks. Right on plan." Slow: "Down 0.8 kg in 4 weeks. Worth checking portions or steps; targets stay as planned unless you change them." |
| **Month 2 rule change** | First open on lap 31 (`junkAllowance` 0 → 1) | One card on Today | "Month 2 starts today. You may have one controlled meal a week: 1 burger, or 2 slices of pizza, or a small biryani. Never a whole cheat day." [Got it] [See the rule] |
| **Health access lost** | Resume, if the granted set no longer includes steps | Walk row state, not a modal | "Steps disconnected. Reconnect?" |
| **Finish line** | Lap 84 complete | Full-screen moment: total kg lost, laps run, meals logged. Then one choice. | **"84 laps. You finished the cut."** Options: [**Another 12 weeks**] → Screen 2 prefilled (Day 1 = tomorrow, weight = latest); [**Two weeks at maintenance**] → maintenance mode with a target the user sets (MATADOR-style diet break); [**Just keep logging**] |
| **New phone / reinstall** | First launch with no data | Normal onboarding. Health Connect history is limited to 30 days before the new grant. | — |

### 3.7 Kept out on purpose
- **Not added: tour, checklist, units, BMR inputs, accounts, ATT, exact alarms, motion permission.** Each would add code or friction with no payoff for a single user on a prescribed plan.
- **Ceiling:** if Daur ever auto-adjusts targets, add height, age and sex then (Mifflin-St Jeor) and recalibrate from the trend.

---

## Sources (all URLs cited above)
Apple: [HIG Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) · [onboarding mirror](https://raw.githubusercontent.com/tmaasen/apple-dev-mcp/main/content/universal/onboarding.md) · [HIG Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) · [privacy mirror](https://raw.githubusercontent.com/tmaasen/apple-dev-mcp/main/content/universal/privacy.md) · [older HIG text](https://kde.hateblo.jp/entry/2020/06/24/013143) · [HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities) · [TipKit](https://developer.apple.com/documentation/tipkit) · [HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) · [Cocoacasts HealthKit](https://cocoacasts.com/more-about-managing-permissions-with-healthkit)
Google: [Material onboarding](https://m1.material.io/growth-communications/onboarding.html) · [Runtime permissions](https://developer.android.com/training/permissions/requesting) · [Notification permission](https://developer.android.com/develop/ui/views/notifications/notification-permission) · [Exact alarms](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms) · [Health Connect get started](https://developer.android.com/guide/health-and-fitness/health-connect/get-started) · [HC permissions UI](https://developer.android.com/health-and-fitness/health-connect/ui/permissions) · [HC onboarding](https://developer.android.com/health-and-fitness/health-connect/ui/onboard-users) · [HC read data / history](https://developer.android.com/health-and-fitness/health-connect/read-data) · [Widget discovery (design)](https://developer.android.com/design/ui/mobile/guides/widgets/discovery-promotion) · [Widget pinning](https://developer.android.com/develop/ui/views/appwidgets/discoverability) · [Android 16 Live Updates](https://proandroiddev.com/live-updates-in-android-16-exploring-the-next-evolution-of-notifications-1a5cf5de2068)
UX research: [NN/g tutorials](https://www.nngroup.com/articles/mobile-tutorials/) · [NN/g empty states](https://www.nngroup.com/articles/empty-state-interface-design/) · [Smashing](https://www.smashingmagazine.com/2014/08/mobile-onboarding-beginners-guide) · [LukeW](https://static.lukew.com/SignUpForms_10052010.pdf) · [Endowed progress](https://thinkinsights.net/consulting/endowed-progress-effect) · [Facebook 7 friends](https://scratch-puffin-363.notion.site/Facebook-s-7-friends-activation-story-a-PM-case-study-33dec508b5118053bff8e0233fedd0f3) · [Lazyweb paywall data](https://www.lazyweb.com/research/are-onboarding-flows-with-a-paywall-longer)
Apps: [MFP Screensdesign](https://screensdesign.com/showcase/myfitnesspal-calorie-counter) · [MFP Lazyweb](https://lazyweb.com/canvas/flows/myfitnesspal/onboarding) · [MFP UX Collective](https://uxdesign.cc/how-myfitnesspal-became-myfitnessenemy-ffc49b481534) · [Noom RevenueCat](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel) · [Noom Rocketship](https://www.rocketshiphq.com/?p=5491) · [Lose It Lazyweb](https://lazyweb.com/canvas/flows/lose-it/onboarding) · [Lose It Reteno](https://gallery.reteno.com/flows/app-screens-lose-it) · [Lifesum](https://screensdesign.com/showcase/lifesum-food-calorie-tracker) · [Yazio](https://screensdesign.com/apps/yazio-calorie-counter-diet/) · [Cronometer](https://support.cronometer.com/hc/en-us/articles/360021677792) · [Cronometer forum](https://forums.cronometer.com/discussion/comment/1166) · [MacroFactor welcome](https://www.strongerbyscience.com/welcome-to-macrofactor/) · [MacroFactor help](https://help.macrofactorapp.com/en/articles/64-how-to-change-your-expenditure-estimate-from-dynamic-to-static) · [Strava Screensdesign](https://screensdesign.com/articles/strava-onboarding-design/) · [UXCam](https://uxcam.com/blog/10-apps-with-great-user-onboarding/) · [Alchemer Strava](https://www.alchemer.com/resources/blog/tough-love-tuesday-stravas-missed-opportunity-to-drive-mobile-app-retention-and-gain-actionable-product-feedback/) · [Nike help](https://www.nike.com/ie/help/a/nrc-start-run) · [NRC Screensdesign](https://screensdesign.com/showcase/nike-run-club-running-coach) · [Apple Fitness iGeeks](https://www.igeeksblog.com/how-to-use-fitness-app-on-iphone/) · [CNN Activity](https://amp.cnn.com/cnn/cnn-underscored/electronics/apple-watch-activity) · [Fitbod getting started](https://help.fitbod.me/hc/en-us/articles/30721771750039-Getting-Started-with-Fitbod-A-New-User-s-Guide) · [Fitbod workout](https://help.fitbod.me/hc/en-us/articles/360004429814-How-Fitbod-Creates-Your-Workout) · [Ladder UX](https://uxdesign.cc/how-ladder-onboards-and-keeps-users-engaged-5716dd1c9f3e) · [Ladder review](https://www.garagegymreviews.com/ladder-app-review) · [Duolingo Appcues](https://goodux.appcues.com/blog/duolingo-user-onboarding) · [Gradual engagement](https://www.appcues.com/blog/gradual-engagement-mobile-app-first-screen) · [Duolingo streak](https://blog.duolingo.com/how-duolingo-streak-builds-habit) · [Duolingo improving streak](https://blog.duolingo.com/improving-the-streak)
Evidence: [Frankenfield 2005](https://pubmed.ncbi.nlm.nih.gov/15883556/) · [Burke 2011](https://pubmed.ncbi.nlm.nih.gov/21185970/) · [Chin 2016 Noom](https://pmc.ncbi.nlm.nih.gov/articles/PMC5098151) · [JMIR 2021 Noom](https://mhealth.jmir.org/2021/11/e30622) · [Look AHEAD early loss](https://experts.umn.edu/en/publications/weight-change-in-the-first-2-months-of-a-lifestyle-intervention-p/) · [Healio early loss](https://www.healio.com/news/endocrinology/20220921/early-weight-loss-in-behavioral-weight-management-programs-predicts-long-term-success) · [MATADOR](https://pmc.ncbi.nlm.nih.gov/articles/PMC5803575) · [Lally UCL](https://www.ucl.ac.uk/news/2009/aug/how-long-does-it-take-form-habit) · [Lally critique](https://www.thebehavioralscientist.com/articles/how-long-to-form-a-habit) · [Weekend logging](https://www.nutritioninsight.com/news/dietary-self-monitoring-on-smartphone-impacted-by-day-of-week-but-not-season-of-year.html) · [Reminder trial](https://clinicaltrials.gov/study/NCT07555262) · [Retention: Phiture](https://phiture.com/mobilegrowthstack/managing-retention-rate-benchmarks-and-expectations/) · [Braze](https://www.braze.com/resources/articles/mobile-app-retention) · [Adjust](https://www.adjust.com/blog/what-makes-a-good-retention-rate/) · [Plotline push](https://www.plotline.so/blog/how-to-improve-push-notification-opt-in-rates) · [Sonar onboarding](https://trysonar.app/blog/app-onboarding-that-protects-day-1-retention) · [Affective](https://weareaffective.com/learning-centre/how-can-i-check-if-my-onboarding-flow-is-too-long)
