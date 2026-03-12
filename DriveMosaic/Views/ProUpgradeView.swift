import SwiftUI

/// Modal sheet presenting the Pro upgrade flow: purchase CTA + license key activation.
struct ProUpgradeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var licenseKeyInput = ""
    @State private var showKeyField = false

    var body: some View {
        let license = appState.licenseManager

        VStack(spacing: 0) {
            if license.isPro {
                // Already Pro — show status
                proStatusView(license: license)
            } else {
                // Upgrade pitch
                upgradePitchView(license: license)
            }
        }
        .frame(width: 400, height: license.isPro ? 280 : 480)
        .background(Color(red: 0.08, green: 0.08, blue: 0.11))
    }

    // MARK: - Pro Status View

    @ViewBuilder
    private func proStatusView(license: LicenseManager) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("DriveMosaic Pro")
                .font(.system(size: 24, weight: .bold))

            Text("All features unlocked. Thank you for your support!")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack(spacing: 12) {
                Button("Deactivate License") {
                    license.deactivate()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .foregroundStyle(.secondary)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Upgrade Pitch View

    @ViewBuilder
    private func upgradePitchView(license: LicenseManager) -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 28)

                Text("Upgrade to Pro")
                    .font(.system(size: 24, weight: .bold))

                Text("$4.99 — one-time purchase")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "trash.fill", color: .red,
                           title: "Delete to Trash",
                           subtitle: "Clean up space directly from DriveMosaic")
                featureRow(icon: "doc.on.doc.fill", color: .orange,
                           title: "Duplicate Detection",
                           subtitle: "Find identical files wasting space (coming soon)")
                featureRow(icon: "square.and.arrow.up.fill", color: .blue,
                           title: "Export Reports",
                           subtitle: "CSV/PDF scan reports for IT admins (coming soon)")
            }
            .padding(.horizontal, 24)

            Spacer()

            // Action buttons
            VStack(spacing: 10) {
                // Purchase button
                Button {
                    NSWorkspace.shared.open(LicenseManager.purchaseURL)
                } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Purchase Pro — $4.99")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)

                // License key toggle
                if showKeyField {
                    licenseKeyEntryView(license: license)
                } else {
                    Button("I already have a license key") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showKeyField = true
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)

            // Dismiss
            Button("Maybe Later") {
                dismiss()
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 20)
        }
    }

    // MARK: - License Key Entry

    @ViewBuilder
    private func licenseKeyEntryView(license: LicenseManager) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Enter license key", text: $licenseKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity)

                Button("Activate") {
                    Task {
                        await license.activate(key: licenseKeyInput)
                        if license.isPro {
                            // Small delay so user sees the success state
                            try? await Task.sleep(for: .seconds(1))
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty
                          || license.validationState == .validating)
            }

            // Validation feedback
            switch license.validationState {
            case .validating:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Validating...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            case .invalid(let message):
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            case .valid:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                    Text("License activated!")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
            case .none:
                EmptyView()
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
