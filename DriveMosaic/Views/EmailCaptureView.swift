import SwiftUI

/// Modal gate shown on first launch. User must submit an email to unlock scanning.
struct EmailCaptureView: View {
    var onComplete: () -> Void

    @State private var email: String = ""
    @State private var state: SubmitState = .idle

    enum SubmitState {
        case idle, submitting, done, error(String)
    }

    var body: some View {
        VStack(spacing: 28) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.22, green: 0.20, blue: 0.45).opacity(0.6))
                    .frame(width: 64, height: 64)
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.6, green: 0.55, blue: 1.0), Color(red: 0.38, green: 0.33, blue: 0.94)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            // Headline
            VStack(spacing: 8) {
                Text("Welcome to DriveMosaic")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .tracking(-0.3)

                Text("Enter your email to get started.\nWe'll send you release notes — nothing else.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Email field
            VStack(spacing: 10) {
                TextField("your@email.com", text: $email)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .disabled(state == .submitting || state == .done)
                    .onSubmit { submit() }

                if case .error(let msg) = state {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.85))
                }
            }

            // CTA button
            Button {
                submit()
            } label: {
                Group {
                    if state == .submitting {
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(height: 18)
                    } else if state == .done {
                        Label("Let's go!", systemImage: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Text("Start using DriveMosaic →")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.38, green: 0.33, blue: 0.94))
            .disabled(email.isEmpty || state == .submitting || state == .done)
            .animation(.easeInOut(duration: 0.15), value: state == .submitting)

            Text("No spam. Unsubscribe anytime.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 12)
    }

    private func submit() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            state = .error("Please enter a valid email address.")
            return
        }

        state = .submitting
        Task {
            do {
                var request = URLRequest(url: URL(string: "https://formspree.io/f/xykbpvrn")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(["email": trimmed])
                let (_, response) = try await URLSession.shared.data(for: request)
                let ok = (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
                await MainActor.run {
                    if ok {
                        UserDefaults.standard.set(true, forKey: "dm_email_captured")
                        state = .done
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onComplete() }
                    } else {
                        state = .error("Couldn't save your email. Try again.")
                    }
                }
            } catch {
                await MainActor.run { state = .error("Network error. Check your connection.") }
            }
        }
    }
}

// Make SubmitState Equatable for the animation value check
extension EmailCaptureView.SubmitState: Equatable {
    static func == (lhs: EmailCaptureView.SubmitState, rhs: EmailCaptureView.SubmitState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.submitting, .submitting), (.done, .done): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
