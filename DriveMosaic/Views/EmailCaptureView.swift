import SwiftUI

struct EmailCaptureView: View {
    var onDismiss: () -> Void

    @State private var email: String = ""
    @State private var state: SubmitState = .idle

    enum SubmitState {
        case idle, submitting, done, error
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get notified about updates")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(-0.2)
                    Text("Drop your email — no spam, just release notes.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if state == .done {
                    Label("Got it!", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .frame(width: 180)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .disabled(state == .submitting)
                        .onSubmit { submit() }

                    Button {
                        submit()
                    } label: {
                        if state == .submitting {
                            ProgressView().scaleEffect(0.6).frame(width: 40)
                        } else {
                            Text("Stay updated")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.38, green: 0.33, blue: 0.94))
                    .controlSize(.small)
                    .disabled(state == .submitting || email.isEmpty)
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.08, green: 0.08, blue: 0.11))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func submit() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else { return }

        state = .submitting
        Task {
            do {
                var request = URLRequest(url: URL(string: "https://formspree.io/f/xykbpvrn")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(["email": trimmed])
                _ = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    state = .done
                    UserDefaults.standard.set(true, forKey: "dm_email_captured")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run { state = .error }
            }
        }
    }
}
