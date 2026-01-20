import SwiftUI

struct ContentView: View {
    @State private var healthStatus: String = "Not checked"
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Scrollsmith")
                .font(.largeTitle)
                .bold()

            Text("Foundation Phase Test")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Backend Health:")
                    .font(.headline)

                Text(healthStatus)
                    .foregroundColor(healthStatus.contains("healthy") ? .green : .primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            Button(action: {
                Task {
                    await checkHealth()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    Text("Check Backend Health")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)

            Spacer()
        }
        .padding()
    }

    @MainActor
    func checkHealth() async {
        isLoading = true
        healthStatus = "Checking..."

        do {
            let response = try await APIClient.shared.healthCheck()
            healthStatus = "✓ Status: \(response.status)\n✓ Database: \(response.database)"
        } catch {
            healthStatus = "✗ Error: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

#Preview {
    ContentView()
}
