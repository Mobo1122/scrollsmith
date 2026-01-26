import SwiftUI

/// Segmented picker for habit frequency selection.
///
/// Shows daily, 3x weekly, weekly options with native segmented control.
struct FrequencyPickerView: View {
    @Binding var frequency: HabitFrequency

    var body: some View {
        Picker("Frequency", selection: $frequency) {
            ForEach(HabitFrequency.allCases, id: \.self) { freq in
                Text(freq.displayName).tag(freq)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var frequency: HabitFrequency = .daily
        var body: some View {
            FrequencyPickerView(frequency: $frequency)
                .padding()
        }
    }
    return PreviewWrapper()
}
