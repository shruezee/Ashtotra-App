import SwiftUI

/// Daily prayer tracking: streak, this week, a month calendar, and what you did each day.
struct JourneyView: View {
    @Environment(PracticeLog.self) private var log
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    StatTile(value: "\(log.streak())", label: log.streak() == 1 ? "day streak" : "days streak")
                    StatTile(value: "\(log.totalPracticeDays)", label: "days of prayer")
                    StatTile(value: "\(log.totalMeditationMinutes)", label: "min meditated")
                    StatTile(value: "\(log.totalCompletions)", label: "108-name malas")
                }
                Card(title: "This week") {
                    WeekStrip(selectedDay: $selectedDay)
                }
                Card(title: month.formatted(.dateTime.month(.wide).year())) {
                    monthGrid
                }
                dayDetail
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Your practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var monthGrid: some View {
        let days = daysInMonth()
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        return VStack(spacing: 10) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Previous month")
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("Next month")
                    .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
            }
            .font(.headline)
            .foregroundStyle(Theme.saffron)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[(i + calendar.firstWeekday - 1) % 7])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(days, id: \.self) { day in
                    DayRing(day: day, selected: calendar.isDate(day, inSameDayAs: selectedDay), showNumber: true)
                        .onTapGesture { selectedDay = day }
                }
            }
        }
    }

    private var dayDetail: some View {
        let activities = log.activities(on: selectedDay)
        let minutes = log.meditationMinutes(on: selectedDay)
        let checklist = DailyChecklist(date: selectedDay)
        let title = calendar.isDateInToday(selectedDay) ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return Card(title: title) {
            Text("\(checklist.doneCount(in: activities)) of \(checklist.items.count) daily practices")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.saffron)
            if activities.isEmpty {
                Text(selectedDay > .now ? "This day is still to come." : "Nothing recorded for this day.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activities.sorted(), id: \.self) { activity in
                    Label(Self.describe(activity, minutes: minutes), systemImage: Self.symbol(for: activity))
                        .frame(minHeight: 32, alignment: .leading)
                }
            }
        }
    }

    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) { month = next }
    }

    /// Readable text for an activity string from `PracticeLog`.
    static func describe(_ activity: String, minutes: Int) -> String {
        let parts = activity.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("routine", let id?): return PrayerBook.shared.routines.first { $0.id == id }?.title ?? id
        case ("prayer", let id?): return PrayerBook.shared.prayer(id: id)?.title ?? id
        case ("chant", let id?): return "108 names of \(Library.shared.collection(id: id)?.title ?? id)"
        case ("meditation", _): return "Meditated \(minutes) \(minutes == 1 ? "minute" : "minutes")"
        default: return activity
        }
    }

    static func symbol(for activity: String) -> String {
        switch activity.split(separator: ":").first {
        case "routine": "sun.horizon.fill"
        case "prayer": "book.closed.fill"
        case "chant": "circle.dotted"
        case "meditation": "leaf.fill"
        default: "checkmark"
        }
    }
}

/// The current week as seven rings that fill with each day's practice.
struct WeekStrip: View {
    @Binding var selectedDay: Date
    private let calendar = Calendar.current

    var body: some View {
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start)!
                VStack(spacing: 6) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(calendar.isDateInToday(day) ? Theme.saffron : .secondary)
                        .accessibilityHidden(true)
                    DayRing(day: day, selected: calendar.isDate(day, inSameDayAs: selectedDay), showNumber: false)
                        .onTapGesture { selectedDay = day }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct DayRing: View {
    @Environment(PracticeLog.self) private var log
    let day: Date
    let selected: Bool
    let showNumber: Bool

    var body: some View {
        let checklist = DailyChecklist(date: day)
        let activities = log.activities(on: day)
        let progress = checklist.progress(in: activities)
        let future = day > .now && !Calendar.current.isDateInToday(day)
        ZStack {
            Circle().stroke(Theme.saffron.opacity(future ? 0.06 : 0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1 ? Color.green : Theme.saffron, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showNumber {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.caption.weight(selected ? .bold : .regular))
                    .monospacedDigit()
            } else if progress >= 1 {
                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.green)
            }
        }
        .frame(width: 36, height: 36)
        .padding(3)
        .background(selected ? Theme.saffron.opacity(0.15) : .clear, in: .circle)
        .contentShape(.circle)
        .accessibilityElement()
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue("\(checklist.doneCount(in: activities)) of \(checklist.items.count) practices")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
