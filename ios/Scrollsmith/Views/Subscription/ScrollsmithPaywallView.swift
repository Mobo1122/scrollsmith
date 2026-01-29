import SwiftUI
import RevenueCat

/// Custom paywall view for Scrollsmith Pro subscriptions.
///
/// Fetches offerings from RevenueCat and displays subscription options.
/// Handles purchases through the RevenueCat SDK with custom UI.
struct ScrollsmithPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    @State private var packages: [Package] = []
    @State private var selectedPackage: Package?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero Section
                heroSection

                // Benefits List
                benefitsSection

                // Package Selection
                if !packages.isEmpty {
                    packageSelection
                }

                // Purchase Button
                purchaseButton

                // Restore + Terms
                footerSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Theme.Background.primary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .tint(Theme.accent)
            }
        }
        .task {
            await loadPackages()
        }
        .overlay {
            if isLoading {
                loadingOverlay
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Pro Badge
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.proGradient)

            Text("Scrollsmith Pro")
                .font(Typography.title)
                .foregroundColor(Theme.Text.primary)

            Text("Unlock the full potential of your video summaries")
                .font(Typography.body)
                .foregroundColor(Theme.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefitRow(
                icon: "infinity",
                title: "Unlimited Videos",
                description: "Process as many videos as you want"
            )

            benefitRow(
                icon: "checklist",
                title: "Step-by-Step Checklists",
                description: "Actionable steps with timestamps"
            )

            benefitRow(
                icon: "rectangle.stack",
                title: "Swipeable Cards",
                description: "Quick-reference card summaries"
            )

            benefitRow(
                icon: "bolt.fill",
                title: "Habit Extraction",
                description: "Turn videos into daily habits"
            )

            benefitRow(
                icon: "book.closed",
                title: "Playbook Builder",
                description: "Create themed collections"
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Background.secondary)
        )
    }

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundColor(Theme.Text.primary)

                Text(description)
                    .font(Typography.footnote)
                    .foregroundColor(Theme.Text.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Package Selection

    private var packageSelection: some View {
        VStack(spacing: 12) {
            ForEach(packages.sorted { packageSortOrder($0) < packageSortOrder($1) }, id: \.identifier) { package in
                PackageCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    savingsText: savingsText(for: package)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPackage = package
                    }
                }
            }
        }
    }

    /// Sort packages: yearly first (better value), then monthly
    private func packageSortOrder(_ package: Package) -> Int {
        switch package.packageType {
        case .annual: return 0
        case .monthly: return 1
        default: return 2
        }
    }

    /// Calculate savings for yearly plan compared to monthly
    private func savingsText(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }

        // Find monthly package for comparison
        guard let monthlyPackage = packages.first(where: { $0.packageType == .monthly }) else {
            return nil
        }

        let monthlyAnnualized = NSDecimalNumber(decimal: monthlyPackage.storeProduct.price * 12).doubleValue
        let yearlyPrice = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue

        guard monthlyAnnualized > yearlyPrice else { return nil }

        let savings = ((monthlyAnnualized - yearlyPrice) / monthlyAnnualized) * 100
        return "Save \(Int(savings.rounded()))%"
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                            .font(Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedPackage != nil ? Theme.accent : Color.gray.opacity(0.3))
                )
                .foregroundColor(.white)
            }
            .disabled(selectedPackage == nil || isPurchasing)

            if let error = errorMessage {
                Text(error)
                    .font(Typography.footnote)
                    .foregroundColor(Theme.Semantic.error)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.accent)
            }

            Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(Typography.footnote)
                .foregroundColor(Theme.Text.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://scrollsmith.app/terms")!)
                    .font(Typography.footnote)
                    .foregroundColor(Theme.Text.secondary)

                Text("•")
                    .foregroundColor(Theme.Text.tertiary)

                Link("Privacy Policy", destination: URL(string: "https://scrollsmith.app/privacy")!)
                    .font(Typography.footnote)
                    .foregroundColor(Theme.Text.secondary)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Theme.Background.primary.opacity(0.8)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(Theme.accent)

                Text("Loading plans...")
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Text.secondary)
            }
        }
    }

    // MARK: - Actions

    private func loadPackages() async {
        isLoading = true
        errorMessage = nil

        do {
            packages = try await SubscriptionService.shared.fetchPackages()

            // Auto-select yearly (best value) if available
            if let yearly = packages.first(where: { $0.packageType == .annual }) {
                selectedPackage = yearly
            } else {
                selectedPackage = packages.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func purchase() async {
        guard let package = selectedPackage else { return }

        isPurchasing = true
        errorMessage = nil

        do {
            let success = try await SubscriptionService.shared.purchase(package)

            if success {
                await subscriptionViewModel.handlePurchaseSuccess()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    private func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil

        do {
            let restored = try await SubscriptionService.shared.restorePurchases()

            if restored {
                await subscriptionViewModel.handlePurchaseSuccess()
                dismiss()
            } else {
                errorMessage = "No previous purchases found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }
}

// MARK: - Package Card Component

private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let savingsText: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(packageTitle)
                        .font(Typography.headline)
                        .foregroundColor(Theme.Text.primary)

                    if let savings = savingsText {
                        Text(savings)
                            .font(Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Theme.accent)
                            )
                    }
                }

                Text(priceDescription)
                    .font(Typography.subheadline)
                    .foregroundColor(Theme.Text.secondary)
            }

            Spacer()

            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundColor(isSelected ? Theme.accent : Theme.Text.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
                )
        )
    }

    private var packageTitle: String {
        switch package.packageType {
        case .annual:
            return "Yearly"
        case .monthly:
            return "Monthly"
        default:
            return package.storeProduct.localizedTitle
        }
    }

    private var priceDescription: String {
        let price = package.storeProduct.localizedPriceString

        switch package.packageType {
        case .annual:
            // Calculate monthly equivalent
            let yearlyPrice = package.storeProduct.price
            let monthlyEquivalent = yearlyPrice / 12

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = package.storeProduct.priceFormatter?.locale

            if let monthlyString = formatter.string(from: NSDecimalNumber(decimal: monthlyEquivalent)) {
                return "\(price)/year (\(monthlyString)/mo)"
            }
            return "\(price)/year"

        case .monthly:
            return "\(price)/month"

        default:
            return price
        }
    }
}

#Preview {
    NavigationStack {
        ScrollsmithPaywallView()
            .environmentObject(SubscriptionViewModel())
    }
}
