import SwiftUI
import Security

// MARK: – Keychain

enum ClaudeUsageKeychain {
    private static let service = "com.opennotch.app"
    private static let account = "claude-session-cookie"

    @discardableResult
    static func save(_ cookie: String) -> OSStatus {
        delete()
        guard let data = cookie.data(using: .utf8) else { return errSecParam }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil)
    }

    @discardableResult
    static func delete() -> OSStatus {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        return SecItemDelete(query as CFDictionary)
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func hasCookie() -> Bool { load() != nil }
}

// MARK: – API Models

private struct ClaudeOrg: Decodable {
    let uuid: String
}

private struct ClaudeUsageResponse: Decodable {
    let five_hour: FiveHour
    struct FiveHour: Decodable {
        let utilization: Double
        let resets_at: String?
    }
}

private enum ClaudeAPIError: Error {
    case unauthorized
    case httpError(Int)
    case noOrg
}

// MARK: – Service

enum ClaudeUsageStatus: Equatable {
    case idle, loading, noCookie
    case error(String)
}

@Observable
final class ClaudeUsageService {

    static let shared = ClaudeUsageService()

    private(set) var utilization: Double = 0
    private(set) var resetsAt: Date?
    private(set) var status: ClaudeUsageStatus = .noCookie
    private(set) var lastError: String?

    private var timer: Timer?

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task { await refresh() }
    }

    func cookieDidChange() {
        Task { await refresh() }
    }

    func refresh() async {
        guard let cookie = ClaudeUsageKeychain.load(), !cookie.isEmpty else {
            await MainActor.run { self.status = .noCookie; self.lastError = nil }
            return
        }
        await MainActor.run { self.status = .loading }
        do {
            let orgId = try await resolveOrgId(cookie: cookie)
            let (util, resets) = try await fetchUsage(orgId: orgId, cookie: cookie)
            await MainActor.run {
                self.utilization = util / 100.0
                self.resetsAt = resets
                self.status = .idle
                self.lastError = nil
            }
        } catch ClaudeAPIError.unauthorized {
            await MainActor.run { self.status = .error("Cookie expired"); self.lastError = "Cookie expired" }
        } catch ClaudeAPIError.httpError(let code) {
            let msg = "HTTP \(code)"
            await MainActor.run { self.status = .error(msg); self.lastError = msg }
        } catch {
            await MainActor.run { self.status = .error("Network error"); self.lastError = error.localizedDescription }
        }
    }

    private func resolveOrgId(cookie: String) async throws -> String {
        if let cached = await MainActor.run(body: { ConfigManager.shared.config.claudeUsage?.organizationId }) {
            return cached
        }
        let orgId = try await fetchOrgId(cookie: cookie)
        await MainActor.run {
            var config = ConfigManager.shared.config
            if config.claudeUsage == nil { config.claudeUsage = ClaudeUsageConfig() }
            config.claudeUsage!.organizationId = orgId
            ConfigManager.shared.updateConfig(config)
        }
        return orgId
    }

    private func fetchOrgId(cookie: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://claude.ai/api/organizations")!)
        setHeaders(on: &req, cookie: cookie)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validateHTTP(resp)
        let orgs = try JSONDecoder().decode([ClaudeOrg].self, from: data)
        guard let first = orgs.first else { throw ClaudeAPIError.noOrg }
        return first.uuid
    }

    private func fetchUsage(orgId: String, cookie: String) async throws -> (Double, Date?) {
        var req = URLRequest(url: URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!)
        setHeaders(on: &req, cookie: cookie)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try validateHTTP(resp)
        let usage = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        let resets = usage.five_hour.resets_at.flatMap { ISO8601DateFormatter().date(from: $0) }
        return (usage.five_hour.utilization, resets)
    }

    private func setHeaders(on req: inout URLRequest, cookie: String) {
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        req.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw ClaudeAPIError.httpError(-1) }
        if http.statusCode == 401 || http.statusCode == 403 { throw ClaudeAPIError.unauthorized }
        if http.statusCode != 200 { throw ClaudeAPIError.httpError(http.statusCode) }
    }
}

// MARK: – View

struct ClaudeUsageBarView: View {
    @Environment(\.appearance) private var appearance
    @State private var service = ClaudeUsageService.shared

    var body: some View {
        switch service.status {
        case .noCookie:
            EmptyView()
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 9))
                Text(msg)
                    .font(appearance.font(size: 10))
            }
            .foregroundStyle(.white.opacity(0.35))
        default:
            HStack(spacing: 8) {
                Circle()
                    .fill(appearance.color)
                    .frame(width: 7, height: 7)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(height: 2)
                        Capsule()
                            .fill(appearance.color)
                            .frame(width: max(0, geo.size.width * service.utilization), height: 2)
                            .animation(.easeOut(duration: 0.5), value: service.utilization)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 6)

                Circle()
                    .fill(service.utilization >= 0.999 ? appearance.color : .white.opacity(0.4))
                    .frame(width: 5, height: 5)
                    .animation(.easeOut(duration: 0.2), value: service.utilization)

                Text("\(Int(service.utilization * 100))%")
                    .font(appearance.font(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)

                Button {
                    Task { await service.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(service.status == .loading ? 0.3 : 0.6))
                        .rotationEffect(.degrees(service.status == .loading ? 360 : 0))
                }
                .buttonStyle(.plain)
                .disabled(service.status == .loading)
                .animation(service.status == .loading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: service.status)
            }
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.01)) // Helps with hit testing if needed
        }
    }
}
