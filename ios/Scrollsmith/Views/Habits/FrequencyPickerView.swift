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
    @Previewable @State var frequency: HabitFrequency = .daily
    FrequencyPickerView(frequency: $frequency)
        .padding()
}
