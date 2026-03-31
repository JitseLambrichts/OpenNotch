import Foundation
import FlyingFox

/// Lightweight HTTP server serving the settings web UI and config API on localhost:7331.
final class SettingsServer: @unchecked Sendable {

    private var serverTask: Task<Void, Never>?
    private let port: UInt16 = 7331

    func start() {
        serverTask = Task.detached { [weak self] in
            guard let self = self else { return }

            let server = HTTPServer(
                address: .loopback(port: self.port),
                logger: .disabled
            )

            // API routes — closure variants use `handler:` label
            await server.appendRoute("GET /api/config",  handler: self.handleGetConfig)
            await server.appendRoute("PUT /api/config",  handler: self.handlePutConfig)

            // Static assets
            await server.appendRoute("GET /",            handler: self.handleIndex)
            await server.appendRoute("GET /styles.css",  handler: self.handleCSS)
            await server.appendRoute("GET /app.js",      handler: self.handleJS)

            NSLog("[SettingsServer] Starting on http://localhost:\(self.port)")
            do {
                try await server.run()
            } catch {
                NSLog("[SettingsServer] Failed: \(error)")
            }
        }
    }

    func stop() {
        serverTask?.cancel()
        serverTask = nil
    }

    // MARK: – API Handlers

    @Sendable private func handleGetConfig(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let data = ConfigManager.shared.configJSON() else {
            return HTTPResponse(statusCode: .internalServerError,
                                body: "Failed to serialize config".data(using: .utf8)!)
        }
        return HTTPResponse(
            statusCode: .ok,
            headers: HTTPHeaders([.contentType: "application/json",
                                  HTTPHeader("Access-Control-Allow-Origin"): "*"]),
            body: data
        )
    }

    @Sendable private func handlePutConfig(_ request: HTTPRequest) async throws -> HTTPResponse {
        let body = try await request.bodyData
        do {
            let newConfig = try JSONDecoder().decode(AppConfig.self, from: body)
            await MainActor.run { ConfigManager.shared.updateConfig(newConfig) }
            return HTTPResponse(
                statusCode: .ok,
                headers: HTTPHeaders([.contentType: "application/json"]),
                body: #"{"status":"ok"}"#.data(using: .utf8)!
            )
        } catch {
            let msg = #"{"error":"\#(error.localizedDescription)"}"#
            return HTTPResponse(
                statusCode: .badRequest,
                headers: HTTPHeaders([.contentType: "application/json"]),
                body: msg.data(using: .utf8)!
            )
        }
    }

    // MARK: – Static File Handlers

    @Sendable private func handleIndex(_ request: HTTPRequest) async throws -> HTTPResponse {
        serveResource(name: "index", ext: "html", contentType: "text/html; charset=utf-8")
    }

    @Sendable private func handleCSS(_ request: HTTPRequest) async throws -> HTTPResponse {
        serveResource(name: "styles", ext: "css", contentType: "text/css")
    }

    @Sendable private func handleJS(_ request: HTTPRequest) async throws -> HTTPResponse {
        serveResource(name: "app", ext: "js", contentType: "application/javascript")
    }

    private func serveResource(name: String, ext: String, contentType: String) -> HTTPResponse {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "WebUI"),
              let data = try? Data(contentsOf: url) else {
            return HTTPResponse(statusCode: .notFound,
                                body: "Not Found".data(using: .utf8)!)
        }
        return HTTPResponse(
            statusCode: .ok,
            headers: HTTPHeaders([.contentType: contentType]),
            body: data
        )
    }
}
