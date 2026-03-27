import SwiftUI

struct PaywallView: View {
    let storeManager: StoreManager
    var onDismiss: (() -> Void)?

    private var isPurchased: Bool {
        #if DEBUG
        storeManager.effectiveProUnlocked || storeManager.purchaseState == .purchased
        #else
        storeManager.proUnlocked || storeManager.purchaseState == .purchased
        #endif
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            featureList
            Divider()
            purchaseButton
            footerButtons
        }
        .padding(20)
        .frame(width: 300)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("Kuma Notify Pro")
                .font(.title3.bold())
            if let product = storeManager.proProduct {
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("One-time purchase")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            proFeatureRow("server.rack", "Unlimited servers & status pages")
            proFeatureRow("line.3.horizontal.decrease", "Filters, search & grouped monitors")
            proFeatureRow("chart.xyaxis.line", "Sparklines & uptime by period")
            proFeatureRow("clock.arrow.circlepath", "Incident history & export")
            proFeatureRow("pin.fill", "Pin & hide monitors")
            proFeatureRow("bell.badge", "Advanced notifications & DND")
            proFeatureRow("gauge.with.needle", "Polling from 10s")
        }
        .padding(.horizontal, 4)
    }

    private var purchaseButton: some View {
        Group {
            if isPurchased {
                Label("Purchased", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("paywall.purchasedLabel")
            } else if let message = storeManager.productLoadErrorMessage,
                      storeManager.proProduct == nil {
                VStack(spacing: 4) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        Task { await storeManager.refreshStatus() }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            } else {
                switch storeManager.purchaseState {
                case .purchasing:
                    ProgressView()
                        .controlSize(.small)
                case .purchased:
                    EmptyView()
                case .failed(let message):
                    VStack(spacing: 4) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                        upgradeButton
                    }
                case .idle:
                    upgradeButton
                }
            }
        }
    }

    private var upgradeButton: some View {
        Button {
            Task { await storeManager.purchasePro() }
        } label: {
            Text("Upgrade to Pro")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(storeManager.proProduct == nil)
        .accessibilityIdentifier("paywall.upgradeButton")
    }

    private var footerButtons: some View {
        HStack {
            Button("Restore Purchase") {
                Task { await storeManager.restorePurchases() }
            }
            .buttonStyle(.link)
            .font(.caption)
            .accessibilityIdentifier("paywall.restoreButton")

            Spacer()

            if let onDismiss {
                Button("Not Now") { onDismiss() }
                    .buttonStyle(.link)
                    .font(.caption)
                    .accessibilityIdentifier("paywall.dismissButton")
            }
        }
    }

    // MARK: - Helpers

    private func proFeatureRow(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)
                .frame(width: 20)
            Text(text)
                .font(.callout)
        }
    }
}
