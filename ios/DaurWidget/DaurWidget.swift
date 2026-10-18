import ActivityKit
import SwiftUI
import WidgetKit
import UIKit

// Daur widgets (design: design/widgets.html). The Flutter app writes the values into the App Group
// (lib/widget_sync.dart); everything visual, including the track, is drawn here as SwiftUI shapes.

private let appGroup = "group.com.siraj.daur"
private func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
  func ui(_ rgb: UInt32) -> UIColor {
    UIColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: 1)
  }
  return Color(uiColor: UIColor { traits in ui(traits.userInterfaceStyle == .dark ? dark : light) })
}
private let tartan = adaptive(0xF6F3EC, 0x172420)
private let infield = adaptive(0xEAEFE7, 0x2D3F36)
private let ink = adaptive(0x25342F, 0xEDF1E9)
private let ink2 = adaptive(0x58665F, 0xB4BFB5)
private let runner = adaptive(0x28645D, 0x9CCFC0)
private let onRunner = adaptive(0xFFFFFF, 0x153E34)
private let outline = adaptive(0x7C8B81, 0x7E9486)

private func x(_ size: CGFloat) -> Font { .system(size: size, weight: .black).width(.expanded) }
private func widgetText(_ english: String, _ bangla: String) -> String {
  UserDefaults(suiteName: appGroup)?.string(forKey: "language") == "bn" ? bangla : english
}

// MARK: - Data written by the app

struct Day {
  let language: String
  var bn: Bool { language == "bn" }
  func text(_ english: String, _ bangla: String) -> String { bn ? bangla : english }
  func captionFont(_ size: CGFloat) -> Font { bn ? .system(size: size, weight: .bold) : x(size) }
  func lapLine(of84: Bool = true) -> String {
    if bn { return "দিন \(lap)\(of84 ? " / 84" : "")\(streak > 0 ? " · \(streak) দিন টানা" : "")" }
    return "DAY \(lap)\(of84 ? " OF 84" : "")\(streak > 0 ? " · \(streak)-DAY STREAK" : "")"
  }
  let lap, meters, kcalPct, water, steps, target, mealNum, waterGoal, waterSlots, streak: Int
  let date, waterGoalText, nextName, nextWhen, kcalText, walkSub, mealTitle, mealSub, mealWhen, mealBtn, mealCap: String
  let finish, mealDone, hasSteps, burnOver: Bool
  let legs: [(name: String, sub: String, state: String)]

  static func read() -> Day {
    let d = UserDefaults(suiteName: appGroup)
    func s(_ k: String, _ def: String = "") -> String { d?.string(forKey: k) ?? def }
    func i(_ k: String, _ def: Int = 0) -> Int { d?.object(forKey: k) == nil ? def : d!.integer(forKey: k) }
    let bn = s("language", "en") == "bn"
    return Day(
      language: s("language", "en"),
      lap: i("lap_n", 1), meters: i("meters"), kcalPct: i("kcal_pct"), water: i("water_glasses"),
      steps: i("walk_steps"), target: max(1000, i("walk_target", 7000)), mealNum: i("meal_num", 100),
      waterGoal: max(1, i("water_goal", 14)), waterSlots: i("water_slots", i("water_glasses")), streak: i("streak"),
      date: s("date"), waterGoalText: s("water_goal_text", bn ? "3.5 লিটারের মধ্যে" : "of 3.5 L"), nextName: s("next_name", bn ? "Daur খুলুন" : "Open Daur"), nextWhen: s("next_when"), kcalText: s("kcal_text"),
      walkSub: s("walk_sub", bn ? "পদক্ষেপ" : "steps"), mealTitle: s("meal_title", bn ? "Daur খুলুন" : "Open Daur"), mealSub: s("meal_sub"),
      mealWhen: s("meal_when"), mealBtn: s("meal_btn", bn ? "লিখুন" : "Log"), mealCap: s("meal_cap"),
      finish: i("finish") == 1, mealDone: i("meal_done") == 1, hasSteps: d?.object(forKey: "walk_steps") != nil,
      burnOver: i("burn_over") == 1,
      legs: (1...4).map { (s("leg\($0)_name"), s("leg\($0)_sub"), s("leg\($0)_state", "todo")) })
  }

  static let sample = Day(
    language: "en",
    lap: 23, meters: 200, kcalPct: 56, water: 7, steps: 5410, target: 8000, mealNum: 300,
    waterGoal: 14, waterSlots: 7, streak: 6,
    date: "Thu 9 Oct", waterGoalText: "of 3.5 L", nextName: "Snack", nextWhen: "16:30–18:00", kcalText: "1,002 / 1,800 kcal",
    walkSub: "2,590 to go", mealTitle: "Snack", mealSub: "Gym day: banana + whey · 212 kcal",
    mealWhen: "16:30–18:00", mealBtn: "Log", mealCap: "Tomorrow · 08:00", finish: false, mealDone: false, hasSteps: true,
    burnOver: false,
    legs: [("Breakfast", "8:41 · 384 kcal", "done"), ("Lunch", "13:52 · 618 kcal", "done"),
           ("Snack", "16:30–18:00", "next"), ("Dinner", "20:00–21:00", "todo")])
}

struct DayEntry: TimelineEntry {
  let date: Date
  let day: Day
}

struct DayProvider: TimelineProvider {
  func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date(), day: .sample) }
  func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
    completion(DayEntry(date: Date(), day: context.isPreview ? .sample : .read()))
  }
  // The app pushes updates on every change; an hourly refresh is only a fallback (a new day, a new lap).
  func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
    completion(Timeline(entries: [DayEntry(date: Date(), day: .read())], policy: .after(Date().addingTimeInterval(3600))))
  }
}

// MARK: - The track, from above (402×250 design space, lane counter-clockwise from the start line)

private enum Lane {
  static let r: CGFloat = 90, straight: CGFloat = 132
  static let length = 2 * .pi * r + 2 * straight

  static var path: Path {
    var p = Path()
    p.move(to: CGPoint(x: 267, y: 215))
    p.addArc(center: CGPoint(x: 267, y: 125), radius: r, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
    p.addLine(to: CGPoint(x: 135, y: 35))
    p.addArc(center: CGPoint(x: 135, y: 125), radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
    p.closeSubpath()
    return p
  }

  /// Point [f] (0–1) of the way round the lane.
  static func point(_ f: CGFloat) -> CGPoint {
    var d = (f.truncatingRemainder(dividingBy: 1)) * length
    let arc = .pi * r
    if d <= arc { let a = .pi / 2 - d / r; return CGPoint(x: 267 + r * cos(a), y: 125 + r * sin(a)) }
    d -= arc
    if d <= straight { return CGPoint(x: 267 - d, y: 35) }
    d -= straight
    if d <= arc { let a = -.pi / 2 - d / r; return CGPoint(x: 135 + r * cos(a), y: 125 + r * sin(a)) }
    d -= arc
    return CGPoint(x: 135 + d, y: 215)
  }
}

struct TrackView: View {
  let meters: Int
  var numerals = false
  var centre: String? = nil
  var sub: String? = nil
  var centreColor: Color = ink

  var body: some View {
    let pad: CGFloat = numerals ? 46 : 10
    let box = CGRect(x: 16 - pad, y: 6 - pad, width: 370 + 2 * pad, height: 238 + 2 * pad)
    GeometryReader { geo in
      let s = min(geo.size.width / box.width, geo.size.height / box.height)
      let ox = (geo.size.width - box.width * s) / 2 - box.minX * s
      let oy = (geo.size.height - box.height * s) / 2 - box.minY * s
      let t = CGAffineTransform(translationX: ox, y: oy).scaledBy(x: s, y: s)
      let pt = { (p: CGPoint) -> CGPoint in p.applying(t) }
      let m = CGFloat(min(max(meters, 0), 400))
      ZStack {
        ForEach(0..<3) { i in
          let r = [CGRect(x: 24, y: 14, width: 354, height: 222), CGRect(x: 38, y: 28, width: 326, height: 194),
                   CGRect(x: 52, y: 42, width: 298, height: 166)][i]
          Path(roundedRect: r, cornerRadius: r.height / 2).applying(t).stroke(outline, lineWidth: 3.3 * s)
        }
        Path(roundedRect: CGRect(x: 66, y: 56, width: 270, height: 138), cornerRadius: 69).applying(t).fill(infield)
        Path(roundedRect: CGRect(x: 66, y: 56, width: 270, height: 138), cornerRadius: 69).applying(t)
          .stroke(outline, lineWidth: 3.3 * s)
        Path { p in p.move(to: pt(CGPoint(x: 267, y: 194))); p.addLine(to: pt(CGPoint(x: 267, y: 236))) }
          .stroke(ink, lineWidth: 5 * s)
        Lane.path.applying(t).trimmedPath(from: 0, to: m / 400)
          .stroke(ink, style: StrokeStyle(lineWidth: 13 * s, lineCap: .round)).widgetAccentable()
        ForEach([100, 200, 300], id: \.self) { d in
          Circle().fill(CGFloat(d) <= m ? ink : tartan).overlay(Circle().stroke(ink, lineWidth: 4 * s))
            .frame(width: 18 * s, height: 18 * s).position(pt(Lane.point(CGFloat(d) / 400)))
        }
        if numerals {
          ForEach(Array([(50, "1"), (150, "2"), (250, "3"), (350, "4")].enumerated()), id: \.offset) { _, leg in
            let q = Lane.point(CGFloat(leg.0) / 400)
            let dx = q.x - 201, dy = q.y - 125, k = max(1, hypot(dx, dy))
            let run = CGFloat(leg.0) < m, now = !run && CGFloat(leg.0) - 100 < m
            Text(leg.1).font(x(26 * s)).foregroundStyle(run ? ink : now ? runner : ink2.opacity(0.55))
              .position(pt(CGPoint(x: q.x + dx / k * 58, y: q.y + dy / k * 46)))
          }
        }
        Circle().fill(runner).overlay(Circle().stroke(tartan, lineWidth: 6 * s))
          .frame(width: 46 * s, height: 46 * s).position(pt(Lane.point(m / 400))).widgetAccentable()
        if let centre {
          VStack(spacing: 4 * s) {
            Text(centre).font(x(52 * s)).foregroundStyle(centreColor).minimumScaleFactor(0.5).lineLimit(1)
            if let sub { Text(sub).font(.system(size: 15 * s, weight: .bold)).foregroundStyle(ink2) }
          }
          .frame(width: 250 * s).position(pt(CGPoint(x: 201, y: 125)))
        }
      }
    }
  }
}

/// A lap glyph for the Live Activity: oval lane, runner [progress] of the way round.
struct LapGlyph: View {
  let progress: Double
  var body: some View {
    GeometryReader { g in
      let w = g.size.width, h = g.size.height, sw: CGFloat = 4, r = (h - 2 * sw) / 2
      let rect = CGRect(x: sw, y: sw, width: w - 2 * sw, height: h - 2 * sw)
      ZStack {
        RoundedRectangle(cornerRadius: r).path(in: rect).stroke(outline, lineWidth: sw)
        RoundedRectangle(cornerRadius: r).path(in: rect).trimmedPath(from: 0, to: progress)
          .stroke(ink, style: StrokeStyle(lineWidth: sw, lineCap: .round))
        Circle().fill(runner).frame(width: sw * 3.2, height: sw * 3.2)
          .position(RoundedRectangle(cornerRadius: r).path(in: rect).trimmedPath(from: 0, to: max(0.001, progress)).currentPoint ?? .zero)
      }
    }
  }
}

// MARK: - Today

struct TodayView: View {
  @Environment(\.widgetFamily) var family
  let day: Day

  var body: some View {
    switch family {
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          RoundedRectangle(cornerRadius: 7).trim(from: 0, to: CGFloat(day.meters) / 400).stroke(lineWidth: 3).frame(width: 40, height: 14)
          Text("\(day.meters / 100)/4").font(x(12))
        }
      }
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 1) {
        Text(day.text("DAY \(day.lap) · \(day.meters / 100)/4 meals", "দিন \(day.lap) · ৪টির মধ্যে \(day.meters / 100)টি খাবার")).font(day.captionFont(13)).widgetAccentable()
        Text("\(day.nextName) \(day.nextWhen)").font(.system(size: 13, weight: .semibold)).lineLimit(1)
        Text(day.kcalText).font(.system(size: 12)).opacity(0.75)
      }
    case .systemSmall:
      VStack(alignment: .leading, spacing: 6) {
        TrackView(meters: day.meters, centre: "\(day.meters / 100)/4")
        Text(day.nextName).font(day.captionFont(15)).foregroundStyle(ink).lineLimit(1)
        Text(day.nextWhen).font(.system(size: 12, weight: .semibold)).foregroundStyle(ink)
      }
    case .systemLarge:
      VStack(spacing: 10) {
        HStack {
          Text(day.lapLine()).font(day.captionFont(12)).tracking(day.bn ? 0 : 0.7).foregroundStyle(ink2)
          Spacer()
          Text(day.date).font(x(12)).foregroundStyle(ink2)
        }
        TrackView(meters: day.meters, numerals: true,
                  centre: day.finish ? "84/84" : "\(day.meters / 100)/4", sub: day.finish ? day.text("DAYS", "দিন") : day.text("MEALS", "খাবার"),
                  centreColor: day.finish ? runner : ink)
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
          GridRow { leg(0); leg(1) }
          GridRow { leg(2); leg(3) }
        }
      }
    default:
      HStack(spacing: 12) {
        TrackView(meters: day.meters, centre: "\(day.meters / 100)/4")
        VStack(alignment: .leading, spacing: 3) {
          Text(day.lapLine()).font(day.captionFont(11)).tracking(day.bn ? 0 : 0.7).foregroundStyle(ink2)
          Spacer(minLength: 0)
          Text(day.nextName).font(day.captionFont(19)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
          Text(day.nextWhen).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
          ProgressView(value: Double(day.kcalPct), total: 100).tint(ink).padding(.top, 8)
          Text(day.kcalText).font(.system(size: 12, weight: day.burnOver ? .bold : .regular)).foregroundStyle(day.burnOver ? runner : ink2)
        }
      }
    }
  }

  private func leg(_ i: Int) -> some View {
    let l = day.legs[i]
    return HStack(spacing: 8) {
      Text("\(i + 1)").font(x(24)).foregroundStyle(l.state == "done" ? ink : l.state == "next" ? runner : ink2)
        .frame(width: 30, alignment: .leading)
      VStack(alignment: .leading, spacing: 1) {
        Text(l.name).font(.system(size: 15, weight: .bold)).foregroundStyle(ink)
        Text(l.sub).font(.system(size: 12)).foregroundStyle(ink2).monospacedDigit()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct DaurWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DaurWidget", provider: DayProvider()) { e in
      TodayView(day: e.day).containerBackground(tartan, for: .widget).widgetURL(URL(string: "daur://open?homeWidget"))
    }
    .configurationDisplayName(Text(widgetText("Daur · Today", "Daur · আজ")))
    .description(Text(widgetText("Today's lap on the track: next meal, kcal. Large shows all four legs.", "আজকের ল্যাপ: পরের খাবার ও ক্যালরি। বড় উইজেটে চারটি খাবারই দেখুন।")))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
  }
}

// MARK: - Water, Next meal, Walk

private struct Pill: View {
  let label: String
  var body: some View {
    Text(label).font(.system(size: 15, weight: .bold)).foregroundStyle(onRunner)
      .padding(.horizontal, 18).frame(minHeight: 40).background(runner, in: Capsule()).widgetAccentable()
  }
}

struct DaurWaterWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DaurWaterWidget", provider: DayProvider()) { e in
      let g = e.day.water, full = g >= e.day.waterGoal, n = e.day.waterSlots
      VStack(alignment: .leading, spacing: 2) {
        Text(e.day.text("Water", "পানি")).font(.system(size: 13, weight: .medium)).foregroundStyle(ink2)
        HStack(alignment: .lastTextBaseline, spacing: 3) {
          Text(g % 4 == 0 ? "\(g / 4)" : String(format: "%g", Double(g) / 4)).font(x(34)).foregroundStyle(ink)
          Text(e.day.text("L", "লি")).font(e.day.captionFont(15)).foregroundStyle(ink)
        }
        if !full { Text(e.day.waterGoalText).font(.system(size: 12)).foregroundStyle(ink2) }
        Spacer(minLength: 4)
        HStack(alignment: .bottom, spacing: 8) {
          Grid(horizontalSpacing: 3, verticalSpacing: 4) {
            ForEach(0..<2) { r in
              GridRow {
                ForEach(0..<7) { c in
                  let i = r * 7 + c
                  UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 5, bottomTrailingRadius: 5, topTrailingRadius: 3)
                    .fill(i < n ? ink : .clear)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 5, bottomTrailingRadius: 5, topTrailingRadius: 3)
                      .stroke(i < n ? ink : i == n && !full ? runner : outline, lineWidth: i == n && !full ? 2 : 1.5))
                    .frame(height: 17)
                }
              }
            }
          }
          if !full {
            Link(destination: URL(string: "daur://water?homeWidget")!) {
              Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(onRunner)
                .frame(width: 40, height: 40).background(runner, in: Circle()).widgetAccentable()
                .accessibilityLabel(e.day.text("Add a glass of water", "এক গ্লাস পানি যোগ করুন"))
            }
          }
        }
      }
      .containerBackground(tartan, for: .widget)
    }
    .configurationDisplayName(Text(widgetText("Daur · Water", "Daur · পানি"))).description(Text(widgetText("Water today, with a + glass button.", "আজকের পানি, সঙ্গে এক গ্লাস যোগ করার বোতাম।")))
    .supportedFamilies([.systemSmall])
  }
}

struct DaurMealWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DaurMealWidget", provider: DayProvider()) { e in
      MealView(day: e.day).containerBackground(tartan, for: .widget)
    }
    .configurationDisplayName(Text(widgetText("Daur · Next meal", "Daur · পরের খাবার"))).description(Text(widgetText("Your next leg, with a Log button.", "আপনার পরের খাবার, সঙ্গে লিখে রাখার বোতাম।")))
    .supportedFamilies([.systemMedium, .accessoryRectangular])
  }
}

struct MealView: View {
  @Environment(\.widgetFamily) var family
  let day: Day
  var body: some View {
    if family == .accessoryRectangular {
      VStack(alignment: .leading, spacing: 1) {
        Text("\(day.mealNum / 100)/4 · \(day.mealTitle)").font(day.captionFont(13)).widgetAccentable()
        Text(day.mealWhen).font(.system(size: 13, weight: .semibold))
        Text(day.mealSub).font(.system(size: 12)).opacity(0.75).lineLimit(1)
      }
    } else {
      let leg = day.mealNum / 100
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top) {
          HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text("\(day.mealNum / 100)/4").font(x(60)).foregroundStyle(day.mealDone ? ink : runner).widgetAccentable()
            Text(day.text("m", "মি")).font(day.captionFont(18)).foregroundStyle(day.mealDone ? ink : runner)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(day.lapLine(of84: false)).font(day.captionFont(12)).tracking(day.bn ? 0 : 0.7).foregroundStyle(ink2)
            Text(day.mealWhen).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink2)
          }
        }
        if day.mealDone {
          HStack(spacing: 6) {
            Circle().fill(runner).frame(width: 8, height: 8)
            Text(day.mealCap).font(.system(size: 13, weight: .bold)).foregroundStyle(ink)
          }
        } else {
          HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { i in
              RoundedRectangle(cornerRadius: 4)
                .fill(i < leg ? ink : i == leg ? .clear : ink.opacity(0.22))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(i == leg ? runner : .clear, lineWidth: 2))
                .frame(height: 7)
            }
          }
          .frame(width: 150)
        }
        Spacer(minLength: 6)
        HStack(alignment: .bottom, spacing: 12) {
          VStack(alignment: .leading, spacing: 3) {
            Text(day.mealTitle).font(day.captionFont(20)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(day.mealSub).font(.system(size: 13)).foregroundStyle(ink2).lineLimit(1)
          }
          Spacer(minLength: 0)
          if !day.mealDone {
            Link(destination: URL(string: "daur://meal?homeWidget")!) { Pill(label: day.mealBtn) }
          }
        }
      }
    }
  }
}

struct DaurWalkWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DaurWalkWidget", provider: DayProvider()) { e in
      let d = e.day
      let f = min(1, Double(d.steps) / Double(d.target))
      VStack(alignment: .leading, spacing: 2) {
        Text(d.text("Walk", "হাঁটা")).font(.system(size: 13, weight: .medium)).foregroundStyle(ink2)
        Text(d.hasSteps ? d.steps.formatted() : "–").font(x(32)).foregroundStyle(ink).minimumScaleFactor(0.6).lineLimit(1)
        Text(d.walkSub).font(.system(size: 12)).foregroundStyle(ink2).lineLimit(1)
        Spacer(minLength: 6)
        GeometryReader { g in
          let w = g.size.width, xpos = { (v: Double) in 6 + v * (w - 12) }
          ZStack(alignment: .topLeading) {
            Rectangle().fill(outline).frame(height: 1)
            Rectangle().fill(outline).frame(height: 1).offset(y: 28)
            ForEach(1...(d.target / 1000), id: \.self) { k in
              Rectangle().fill(k * 1000 <= d.steps ? ink : ink.opacity(0.22))
                .frame(width: 1.6, height: k % 4 == 0 ? 18 : 6).offset(x: xpos(Double(k * 1000) / Double(d.target)), y: 5)
            }
            Capsule().fill(ink).frame(width: max(4, xpos(f) - 6), height: 4).offset(x: 6, y: 13)
            Circle().fill(runner).overlay(Circle().stroke(tartan, lineWidth: 2)).frame(width: 16, height: 16)
              .offset(x: xpos(f) - 8, y: 7).widgetAccentable()
          }
        }
        .frame(height: 30)
      }
      .containerBackground(tartan, for: .widget)
    }
    .configurationDisplayName(Text(widgetText("Daur · Walk", "Daur · হাঁটা"))).description(Text(widgetText("Steps today against this week's target.", "এই সপ্তাহের লক্ষ্যের তুলনায় আজকের পদক্ষেপ।")))
    .supportedFamilies([.systemSmall])
  }
}

// MARK: - Live Activity: rest timer and treadmill (Lock Screen + Dynamic Island)

// Name must be exactly this for the live_activities plugin.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  public struct ContentState: Codable, Hashable {}
  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String { "\(id)_\(key)" }
}

private struct WorkoutLive {
  let kind, title, sub, language: String
  let end, start: Date
  let paused: Bool
  let elapsed: Int
  let total: Double

  init(_ a: LiveActivitiesAppAttributes) {
    let d = UserDefaults(suiteName: appGroup)
    language = d?.string(forKey: a.prefixedKey("language")) ?? d?.string(forKey: "language") ?? "en"
    kind = d?.string(forKey: a.prefixedKey("kind")) ?? "rest"
    title = d?.string(forKey: a.prefixedKey("title")) ?? "Daur"
    sub = d?.string(forKey: a.prefixedKey("sub")) ?? ""
    end = Date(timeIntervalSince1970: d?.double(forKey: a.prefixedKey("end")) ?? 0)
    start = Date(timeIntervalSince1970: d?.double(forKey: a.prefixedKey("start")) ?? 0)
    paused = (d?.integer(forKey: a.prefixedKey("paused")) ?? 0) == 1
    elapsed = d?.integer(forKey: a.prefixedKey("elapsed")) ?? 0
    total = max(1, d?.double(forKey: a.prefixedKey("total")) ?? 90)
  }

  /// How far round the lap: rest = time used; fast = share of the goal; treadmill = within the 400 m.
  var progress: Double {
    kind == "rest"
      ? min(1, max(0, 1 - end.timeIntervalSinceNow / total))
      : kind == "fast" ? min(1, max(0, -start.timeIntervalSinceNow / total)) : 0.25
  }

  var label: String {
    if language == "bn" { return kind == "rest" ? "বিশ্রাম" : kind == "fast" ? "উপবাস" : "ট্রেডমিল" }
    return kind == "rest" ? "Rest" : kind == "fast" ? "Fasting" : "Treadmill"
  }

  /// The lap glyph, or for a fast a bar that fills to the goal on its own (no updates needed).
  @ViewBuilder var gauge: some View {
    if kind == "fast" {
      ProgressView(timerInterval: start...max(end, start.addingTimeInterval(1)), countsDown: false) {
        EmptyView()
      } currentValueLabel: {
        EmptyView()
      }
      .tint(runner)
    } else {
      LapGlyph(progress: progress)
    }
  }

  @ViewBuilder var clock: some View {
    if kind == "rest" {
      Text(timerInterval: Date()...max(end, Date()), countsDown: true)
    } else if paused {
      Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
    } else {
      Text(start, style: .timer)
    }
  }

  var glyph: some View {
    Group {
      if kind == "fast" {
        Image(systemName: "hourglass").foregroundStyle(ink)
      } else if kind == "rest" {
        RoundedRectangle(cornerRadius: 6).stroke(ink, lineWidth: 2).frame(width: 20, height: 12)
          .overlay(alignment: .topLeading) { Circle().fill(runner).frame(width: 6, height: 6).offset(x: 2, y: -2) }
      } else {
        VStack(spacing: 6) { Rectangle().frame(width: 20, height: 1.6); Rectangle().frame(width: 20, height: 1.6) }
          .foregroundStyle(ink).overlay { Circle().fill(runner).frame(width: 6, height: 6) }
      }
    }
  }
}

struct DaurLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      let w = WorkoutLive(context.attributes)
      HStack(spacing: 12) {
        w.gauge.frame(width: 64, height: 42)
        VStack(alignment: .leading, spacing: 2) {
          Text(w.label).font(.system(size: 20, weight: .bold)).foregroundStyle(ink)
          Text(w.sub).font(.system(size: 13)).foregroundStyle(ink2).lineLimit(2)
        }
        Spacer(minLength: 4)
        w.clock.font(x(32)).monospacedDigit().foregroundStyle(runner).multilineTextAlignment(.trailing).frame(maxWidth: 120)
      }
      .padding(16)
      .activityBackgroundTint(tartan)
      .activitySystemActionForegroundColor(ink)
    } dynamicIsland: { context in
      let w = WorkoutLive(context.attributes)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) { w.gauge.frame(width: 72, height: 46) }
        DynamicIslandExpandedRegion(.center) {
          Text(w.label).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
        }
        DynamicIslandExpandedRegion(.trailing) { w.clock.font(x(28)).monospacedDigit().foregroundStyle(runner) }
        DynamicIslandExpandedRegion(.bottom) { Text(w.sub).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
      } compactLeading: {
        w.glyph
      } compactTrailing: {
        w.clock.monospacedDigit().frame(maxWidth: 52).foregroundStyle(runner)
      } minimal: {
        w.glyph
      }
      .widgetURL(URL(string: "daur://open?homeWidget"))
    }
  }
}

@main
struct DaurWidgets: WidgetBundle {
  var body: some Widget {
    DaurWidget()
    DaurWaterWidget()
    DaurMealWidget()
    DaurWalkWidget()
    DaurLiveActivity()
  }
}
