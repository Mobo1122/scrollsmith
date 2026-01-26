import SwiftUI

/// Main summary display screen with format switching and Pro tier gating.
///
/// CONTEXT.md decisions:
/// - Segmented control at top: Bullets | Steps | Cards
/// - Hide unavailable segments (format data doesn't exist)
/// - Pro formats show blurred teaser for free users
/// - View Original FAB always accessible
struct SummaryDisplayView: View {
    let video: VideoDTO

    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    @State private var viewModel = SummaryViewModel()
    @State private var showPaywall = false
    @State private var paywallFormat: SummaryFormat = .steps
    @State private var showHabitExtraction = false

    private let deepLinkService = DeepLinkService()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Format picker
                formatPicker
                    .padding()

                // Content based on format
                contentView

                // Make action points button (Pro feature)
                // Videos with summaries have transcripts available for habit extraction
                if video.summaryBullets != nil {
                    makeActionPointsButton
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }

            // View Original FAB
            viewOriginalButton
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            ProPaywallSheet(requestedFormat: paywallFormat)
        }
        .sheet(isPresented: $showHabitExtraction) {
            HabitExtractionSheet(videoId: video.id)
        }
        .onAppear {
            // Set default format
            viewModel.currentFormat = viewModel.bestDefaultFormat(for: video, isPro: subscriptionViewModel.isPro)
        }
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        Picker("Format", selection: $viewModel.currentFormat) {
            // Bullets always available if data exists
            if video.summaryBullets != nil {
                Text("Bullets").tag(SummaryFormat.bullets)
            }

            // Steps - show for all, but check access on select
            if video.summarySteps != nil || !subscriptionViewModel.isPro {
                HStack {
                    Text("Steps")
                    if !subscriptionViewModel.isPro {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                    }
                }
                .tag(SummaryFormat.steps)
            }

            // Cards - show for all, but check access on select
            if video.summaryCards != nil || !subscriptionViewModel.isPro {
                HStack {
                    Text("Cards")
                    if !subscriptionViewModel.isPro {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                    }
                }
                .tag(SummaryFormat.cards)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.currentFormat) { oldValue, newValue in
            // Check Pro access when switching to Pro formats
            if !subscriptionViewModel.isPro && (newValue == .steps || newValue == .cards) {
                paywallFormat = newValue
                showPaywall = true
                // Revert to previous format
                viewModel.currentFormat = oldValue
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.currentFormat {
        case .bullets:
            if let bullets = video.parsedBullets {
                BulletSummaryView(bullets: bullets)
            } else {
                BulletSummaryView.empty
            }

        case .steps:
            if subscriptionViewModel.isPro, let checklist = video.parsedSteps {
                StepChecklistView(
                    checklist: checklist,
                    videoId: video.id,
                    sourceUrl: video.sourceUrl,
                    viewModel: viewModel
                )
            } else {
                proTeaser(for: .steps)
            }

        case .cards:
            if subscriptionViewModel.isPro, let cardsSummary = video.parsedCards {
                CardStackView(cards: cardsSummary.cards)
            } else {
                proTeaser(for: .cards)
            }
        }
    }

    // MARK: - Pro Teaser

    private func proTeaser(for format: SummaryFormat) -> some View {
        VStack(spacing: 20) {
            // Blurred preview hint
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: format == .steps ? "checklist" : "rectangle.stack")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("See more with Pro")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(format == .steps
                             ? "Get step-by-step instructions with timestamps"
                             : "Swipe through key insights as cards")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .blur(radius: 0.5)  // Subtle blur for "locked" feel

            Button {
                paywallFormat = format
                showPaywall = true
            } label: {
                Text("Unlock \(format.rawValue)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                    )
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Make Action Points Button

    private var makeActionPointsButton: some View {
        Button {
            if subscriptionViewModel.isPro {
                showHabitExtraction = true
            } else {
                paywallFormat = .steps  // Reuse paywall sheet
                showPaywall = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("Make action points")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(subscriptionViewModel.isPro ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(subscriptionViewModel.isPro ? Color.accentColor : Color(.systemGray5))
            )
            .overlay(alignment: .trailing) {
                if !subscriptionViewModel.isPro {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 12)
                }
            }
        }
    }

    // MARK: - View Original FAB

    private var viewOriginalButton: some View {
        Group {
            if let platform = DeepLinkService.Platform.from(sourceUrl: video.sourceUrl),
               deepLinkService.canDeepLink(platform) {
                Button {
                    deepLinkService.open(platform)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("View Original")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    )
                }
                .padding()
            } else if let sourceUrl = video.sourceUrl,
                      DeepLinkService.Platform.from(sourceUrl: sourceUrl) == nil ||
                      sourceUrl.hasPrefix("ph://") {
                // Camera roll - show inline player option
                NavigationLink {
                    InlineVideoPlayerView(localIdentifier: sourceUrl)
                        .navigationTitle("Video Preview")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Watch Video")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    )
                }
                .padding()
            }
        }
    }
}

// MARK: - Empty State

extension SummaryDisplayView {
    static func noSummary(video: VideoDTO) -> some View {
        ContentUnavailableView {
            Label("No Summary Yet", systemImage: "doc.text")
        } description: {
            Text("This video hasn't been summarized yet. Summaries are generated automatically after transcription.")
        }
    }
}

#Preview("With Bullets") {
    NavigationStack {
        SummaryDisplayView(
            video: VideoDTO(
                id: UUID(),
                sourceUrl: "https://youtube.com/watch?v=test123",
                summaryBullets: "[\"First insight\", \"Second insight\", \"Third insight\"]",
                summarySteps: nil,
                summaryCards: nil,
                userEditedSummary: false,
                tags: ["productivity", "habits"],
                createdAt: Date()
            )
        )
        .environmentObject(SubscriptionViewModel())
    }
}
