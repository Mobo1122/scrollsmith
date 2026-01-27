import SwiftUI
import Charts

/// GitHub-style contribution calendar showing habit completion history.
struct StreakCalendarView: View {
    let completions: [Date]
    let weeksToShow: Int

    init(completions: [Date], weeksToShow: Int = 12) {
        self.completions = completions
        self.weeksToShow = weeksToShow
    }

    var body: some View {
        Chart(gridData) { item in
            RectangleMark(
                xStart: .value("Week", item.week),
                xEnd: .value("Week", item.week + 1),
                yStart: .value("Day", item.dayOfWeek),
                yEnd: .value("Day", item.dayOfWeek + 1)
            )
            .foregroundStyle(item.completed ? Color.green.opacity(0.8) : Color.gray.opacity(0.15))
            .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [1, 3, 5, 7]) { value in
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text(dayLabel(for: day))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 100)
    }

    private var gridData: [GridItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var items: [GridItem] = []

        // Find the start of this week
        let weekdayToday = calendar.component(.weekday, from: today)
        let startOfThisWeek = calendar.date(byAdding: .day, value: -(weekdayToday - 1), to: today)!

        for weekOffset in (0..<weeksToShow).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: startOfThisWeek)!

            for dayOfWeek in 1...7 {
                let date = calendar.date(byAdding: .day, value: dayOfWeek - 1, to: weekStart)!

                // Don't show future dates
                if date > today { continue }

                let completed = completions.contains { completion in
                    calendar.isDate(completion, inSameDayAs: date)
                }

                items.append(GridItem(
                    date: date,
                    week: weeksToShow - weekOffset,
                    dayOfWeek: dayOfWeek,
                    completed: completed
                ))
            }
        }
        return items
    }

    private func dayLabel(for weekday: Int) -> String {
        switch weekday {
        case 1: return "S"
        case 3: return "T"
        case 5: return "T"
        case 7: return "S"
        default: return ""
        }
    }

    struct GridItem: Identifiable {
        let date: Date
        let week: Int
        let dayOfWeek: Int
        let completed: Bool

        var id: String { "\(week)-\(dayOfWeek)" }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let completions = (0..<30).compactMap { offset -> Date? in
        if [0, 1, 3, 5, 7, 10, 12, 14, 15, 17, 20, 21, 22, 25, 28].contains(offset) {
            return calendar.date(byAdding: .day, value: -offset, to: today)
        }
        return nil
    }

    return VStack {
        Text("Last 12 Weeks")
            .font(.headline)
        StreakCalendarView(completions: completions)
            .padding()
    }
}
