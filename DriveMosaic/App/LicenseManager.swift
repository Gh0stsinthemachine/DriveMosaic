import Foundation

/// Manages DriveMosaic Pro license state.
/// Uses LemonSqueezy license key validation with local caching.
@Observable
@MainActor
final class LicenseManager {
    static let shared = LicenseManager()

    // MARK: - Observable State

    var isPro: Bool = false
    var validationState: ValidationState = .none

    enum ValidationState: Equatable {
        case none
        case validating
        case valid
        case invalid(String)
    }

    // MARK: - Storage Keys

    private static let keyLicenseKey = "dm_license_key"
    private static let keyLicenseValid = "dm_license_valid"
    private static let keyInstanceID = "dm_instance_id"

    // MARK: - LemonSqueezy

    static let purchaseURL = URL(string: "https://blackcloud.lemonsqueezy.com/checkout/buy/66fde7fe-0a10-4c9b-af49-1defcf4cc8a6")!

    // MARK: - Init

    private init() {
        // Restore cached validation state on launch
        let storedKey = UserDefaults.standard.string(forKey: Self.keyLicenseKey) ?? ""
        let cachedValid = UserDefaults.standard.bool(forKey: Self.keyLicenseValid)

        if !storedKey.isEmpty && cachedValid {
            isPro = true
            validationState = .valid
        }
    }

    // MARK: - Public API

    var storedKey: String {
        UserDefaults.standard.string(forKey: Self.keyLicenseKey) ?? ""
    }

    /// Activate a license key via LemonSqueezy API.
    func activate(key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationState = .invalid("Please enter a license key.")
            return
        }

        validationState = .validating

        // Try LemonSqueezy API
        do {
            let valid = try await validateWithLemonSqueezy(key: trimmed)
            if valid {
                storeValidation(key: trimmed)
            } else {
                validationState = .invalid("Invalid license key. Please check and try again.")
            }
        } catch {
            // Network error — check if it looks like a valid format and allow offline
            validationState = .invalid("Could not verify key. Check your connection and try again.")
        }
    }

    /// Remove stored license and revert to Free
    func deactivate() {
        UserDefaults.standard.removeObject(forKey: Self.keyLicenseKey)
        UserDefaults.standard.removeObject(forKey: Self.keyLicenseValid)
        UserDefaults.standard.removeObject(forKey: Self.keyInstanceID)
        isPro = false
        validationState = .none
    }

    // MARK: - Private

    private func storeValidation(key: String) {
        UserDefaults.standard.set(key, forKey: Self.keyLicenseKey)
        UserDefaults.standard.set(true, forKey: Self.keyLicenseValid)
        isPro = true
        validationState = .valid
    }

    /// Validate license key against LemonSqueezy activation API.
    /// This is a public endpoint — no API key required.
    private func validateWithLemonSqueezy(key: String) async throws -> Bool {
        let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get or create a stable instance ID for this machine
        let instanceID = getOrCreateInstanceID()

        let body: [String: String] = [
            "license_key": key,
            "instance_name": instanceID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // LemonSqueezy returns 200 for valid, 400/404 for invalid
        if httpResponse.statusCode == 200 {
            // Parse response to confirm activation
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let activated = json["activated"] as? Bool {
                return activated
            }
            // If parsing fails but status was 200, treat as valid
            return true
        }

        return false
    }

    /// Get or create a stable machine identifier for license activation
    private func getOrCreateInstanceID() -> String {
        if let existing = UserDefaults.standard.string(forKey: Self.keyInstanceID) {
            return existing
        }
        let id = "DriveMosaic-\(ProcessInfo.processInfo.hostName)"
        UserDefaults.standard.set(id, forKey: Self.keyInstanceID)
        return id
    }
}
