import Foundation

struct ChatTurn: Codable {
    let role: String
    let content: String
    let timestamp: Date
}

struct CompanionLLMResponse: Codable {
    var reply: String
    var emotion: String?
    var scene: String?
    var hungerDelta: Double?
    var socialDelta: Double?
    var energyDelta: Double?
}

struct CharacterProfile: Codable {
    var name: String
    var systemPrompt: String
    var styleRules: [String]
    var emotionSceneMap: [String: [String]]
    var allowedScenes: [String]
}

struct UserMemoryProfile: Codable {
    var userName: String?
    var likes: [String]
    var dislikes: [String]
    var facts: [String]
    var recentTopics: [String]
}

struct KnowledgeSnippet {
    let source: String
    let title: String
    let summary: String
    let url: String
}

struct ProviderConfig: Codable {
    var kind: String
    var displayName: String?
    var executablePath: String?
    var workingDirectory: String?
    var argumentsTemplate: [String]?
    var environment: [String: String]?
    var modelPath: String?
    var ollamaModel: String?
    var temperature: Double?
    var maxTokens: Int?
    var contextSize: Int?
    var threads: Int?
    var apiBaseURL: String?
    var apiPath: String?
    var apiKeyEnvVar: String?
    var apiModel: String?
}

enum CompanionAIError: LocalizedError {
    case missingExecutable
    case missingPromptTemplate
    case processFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "LLM provider has no executable configured."
        case .missingPromptTemplate:
            return "LLM provider has no argument template configured."
        case .processFailed(let output):
            return output.isEmpty ? "LLM process failed." : output
        case .invalidResponse:
            return "LLM returned an unreadable response."
        }
    }
}

final class CompanionAIService {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private(set) var characterProfile: CharacterProfile
    private(set) var providerConfig: ProviderConfig
    private(set) var history: [ChatTurn] = []
    private(set) var userMemory: UserMemoryProfile

    let aiDirectoryURL: URL
    let characterFileURL: URL
    let providerFileURL: URL
    let historyFileURL: URL
    let memoryFileURL: URL

    init(appSupportName: String = "Gboy Companion Native") throws {
        let supportRoot = try fileManager.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
        aiDirectoryURL = supportRoot
            .appendingPathComponent(appSupportName, isDirectory: true)
            .appendingPathComponent("AI", isDirectory: true)
        characterFileURL = aiDirectoryURL.appendingPathComponent("character.json")
        providerFileURL = aiDirectoryURL.appendingPathComponent("provider.json")
        historyFileURL = aiDirectoryURL.appendingPathComponent("history.json")
        memoryFileURL = aiDirectoryURL.appendingPathComponent("memory.json")

        characterProfile = Self.defaultCharacterProfile()
        providerConfig = Self.defaultProviderConfig()
        userMemory = Self.defaultMemoryProfile()

        try bootstrap()
        try reload()
    }

    func reload() throws {
        characterProfile = try load(CharacterProfile.self, from: characterFileURL, fallback: Self.defaultCharacterProfile())
        providerConfig = try load(ProviderConfig.self, from: providerFileURL, fallback: Self.defaultProviderConfig())
        history = try load([ChatTurn].self, from: historyFileURL, fallback: [])
        userMemory = try load(UserMemoryProfile.self, from: memoryFileURL, fallback: Self.defaultMemoryProfile())
    }

    func recentTurns(limit: Int = 24) -> [ChatTurn] {
        Array(history.suffix(limit))
    }

    func applyBundledProviderPreset(named presetFileName: String) throws {
        guard let bundledURL = Self.bundledAIDirectory()?.appendingPathComponent(presetFileName),
              fileManager.fileExists(atPath: bundledURL.path) else {
            throw CompanionAIError.processFailed("Missing bundled preset: \(presetFileName)")
        }

        if fileManager.fileExists(atPath: providerFileURL.path) {
            try fileManager.removeItem(at: providerFileURL)
        }
        try fileManager.copyItem(at: bundledURL, to: providerFileURL)
        try reload()
    }

    func sceneForEmotion(_ emotion: String?, sceneHint: String?) -> String? {
        let emotionKey = emotion?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if let hint = normalizedSceneName(sceneHint), !hint.isEmpty {
            if subtleChatScenes.contains(hint) {
                return rotatedScene(from: preferredChatScenes(for: emotionKey), fallback: hint)
            }
            return hint
        }

        guard let emotionKey else { return nil }
        let preferred = preferredChatScenes(for: emotionKey)
        if let scene = rotatedScene(from: preferred, fallback: nil) {
            return scene
        }

        guard let options = characterProfile.emotionSceneMap[emotionKey], !options.isEmpty else { return nil }
        let filtered = options.compactMap(normalizedSceneName).filter { !subtleChatScenes.contains($0) }
        let pool = filtered.isEmpty ? options.compactMap(normalizedSceneName) : filtered
        return rotatedScene(from: pool, fallback: nil)
    }

    func send(userMessage: String, completion: @escaping (Result<CompanionLLMResponse, Error>) -> Void) {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(CompanionAIError.invalidResponse))
            return
        }

        absorbUserMemory(from: trimmed)
        appendTurn(role: "user", content: trimmed)
        let provider = providerConfig

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let knowledge = self.fetchKnowledgeContext(for: trimmed)
                if let grounded = self.groundedKnowledgeResponse(for: trimmed, knowledge: knowledge) {
                    DispatchQueue.main.async {
                        self.appendTurn(role: "assistant", content: grounded.reply)
                        completion(.success(grounded))
                    }
                    return
                }
                let promptTurns = self.promptTurns(limit: 18)
                let prompt = self.buildPrompt(with: promptTurns, knowledge: knowledge)
                var response = try self.requestResponse(using: provider, prompt: prompt, userMessage: trimmed)

                if self.responseNeedsRetry(response, userMessage: trimmed, promptTurns: promptTurns) {
                    let retryPrompt = self.buildRetryPrompt(with: promptTurns,
                                                            knowledge: knowledge,
                                                            rejectedReply: response.reply,
                                                            userMessage: trimmed)
                    response = try self.requestResponse(using: provider, prompt: retryPrompt, userMessage: trimmed)
                }

                if self.responseNeedsRetry(response, userMessage: trimmed, promptTurns: promptTurns) {
                    response = self.fallbackResponse(for: trimmed)
                }

                DispatchQueue.main.async {
                    self.appendTurn(role: "assistant", content: response.reply)
                    completion(.success(response))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func bootstrap() throws {
        try fileManager.createDirectory(at: aiDirectoryURL, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: characterFileURL.path) {
            try seedFile(named: "character.json", to: characterFileURL, fallback: Self.defaultCharacterProfile())
        }

        if !fileManager.fileExists(atPath: providerFileURL.path) {
            if let detected = Self.detectBestProvider() {
                try save(detected, to: providerFileURL)
            } else {
                try seedFile(named: "provider.json", to: providerFileURL, fallback: Self.defaultProviderConfig())
            }
        }

        if !fileManager.fileExists(atPath: historyFileURL.path) {
            try save([ChatTurn](), to: historyFileURL)
        }
        if !fileManager.fileExists(atPath: memoryFileURL.path) {
            try save(Self.defaultMemoryProfile(), to: memoryFileURL)
        }
    }

    private func seedFile<T: Codable>(named bundledName: String, to destination: URL, fallback: T) throws {
        if let bundledURL = Self.bundledAIDirectory()?.appendingPathComponent(bundledName),
           fileManager.fileExists(atPath: bundledURL.path) {
            try fileManager.copyItem(at: bundledURL, to: destination)
        } else {
            try save(fallback, to: destination)
        }
    }

    private func load<T: Codable>(_ type: T.Type, from url: URL, fallback: T) throws -> T {
        guard fileManager.fileExists(atPath: url.path) else { return fallback }
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func save<T: Codable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func appendTurn(role: String, content: String) {
        history.append(ChatTurn(role: role, content: content, timestamp: Date()))
        if history.count > 40 {
            history = Array(history.suffix(40))
        }
        try? save(history, to: historyFileURL)
    }

    private func promptTurns(limit: Int) -> [ChatTurn] {
        let sanitized = sanitizedTurnsForPrompt(history)
        return Array(sanitized.suffix(limit))
    }

    private func sanitizedTurnsForPrompt(_ turns: [ChatTurn]) -> [ChatTurn] {
        var sanitized: [ChatTurn] = []
        var lastAssistantKey: String?

        for turn in turns {
            let key = normalizedReplyKey(turn.content)
            if turn.role.lowercased() == "assistant" {
                if shouldSuppressAssistantTurn(turn.content) {
                    continue
                }
                if key == lastAssistantKey {
                    continue
                }
                lastAssistantKey = key
            }
            sanitized.append(turn)
        }

        return sanitized
    }

    private func shouldSuppressAssistantTurn(_ content: String) -> Bool {
        let key = normalizedReplyKey(content)
        if key.isEmpty { return true }
        return bannedReplyKeys.contains(key)
    }

    private func responseNeedsRetry(_ response: CompanionLLMResponse,
                                    userMessage: String,
                                    promptTurns: [ChatTurn]) -> Bool {
        let reply = response.reply.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalizedReplyKey(reply)
        if reply.isEmpty || bannedReplyKeys.contains(key) {
            return true
        }

        let recentAssistantKeys = promptTurns
            .reversed()
            .filter { $0.role.lowercased() == "assistant" }
            .prefix(4)
            .map { normalizedReplyKey($0.content) }

        if recentAssistantKeys.contains(key) {
            return true
        }

        let userKey = normalizedReplyKey(userMessage)
        if key == userKey {
            return true
        }

        let wordCount = reply.split(whereSeparator: \.isWhitespace).count
        if wordCount <= 2, inferEmotion(from: reply, userMessage: userMessage) == "glitchy" {
            return true
        }

        return false
    }

    private func absorbUserMemory(from message: String) {
        let lowered = message.lowercased()

        if let name = firstMatch(in: message, patterns: [
            #"(?i)\bmy name is ([A-Za-z][A-Za-z '\-]{1,30})"#,
            #"(?i)\bi am ([A-Za-z][A-Za-z '\-]{1,30})\b"#,
            #"(?i)\bi'm ([A-Za-z][A-Za-z '\-]{1,30})\b"#
        ]) {
            let cleaned = cleanFactValue(name)
            if cleaned.split(separator: " ").count <= 3 {
                userMemory.userName = cleaned
            }
        }

        for like in allMatches(in: message, patterns: [
            #"(?i)\bi like ([^.!?]+)"#,
            #"(?i)\bi love ([^.!?]+)"#,
            #"(?i)\bmy favorite(?: thing)? is ([^.!?]+)"#
        ]) {
            appendUnique(cleanFactValue(like), to: &userMemory.likes, limit: 10)
        }

        for dislike in allMatches(in: message, patterns: [
            #"(?i)\bi dislike ([^.!?]+)"#,
            #"(?i)\bi hate ([^.!?]+)"#,
            #"(?i)\bi don't like ([^.!?]+)"#
        ]) {
            appendUnique(cleanFactValue(dislike), to: &userMemory.dislikes, limit: 10)
        }

        for fact in allMatches(in: message, patterns: [
            #"(?i)\bi am from ([^.!?]+)"#,
            #"(?i)\bi work as ([^.!?]+)"#,
            #"(?i)\bi work at ([^.!?]+)"#,
            #"(?i)\bi live in ([^.!?]+)"#,
            #"(?i)\bmy job is ([^.!?]+)"#
        ]) {
            appendUnique(cleanFactValue(fact), to: &userMemory.facts, limit: 12)
        }

        for topic in extractedTopics(from: lowered) {
            appendUnique(topic, to: &userMemory.recentTopics, limit: 12)
        }

        try? save(userMemory, to: memoryFileURL)
    }

    private func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else { continue }
            return String(text[captureRange])
        }
        return nil
    }

    private func allMatches(in text: String, patterns: [String]) -> [String] {
        var values: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) where match.numberOfRanges > 1 {
                guard let captureRange = Range(match.range(at: 1), in: text) else { continue }
                values.append(String(text[captureRange]))
            }
        }
        return values
    }

    private func cleanFactValue(_ raw: String) -> String {
        var cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'.,!?"))
        let stopwords = [" and ", " but ", " because "]
        for stopword in stopwords {
            if let range = cleaned.range(of: stopword, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        return Self.condense(cleaned)
    }

    private func appendUnique(_ value: String, to array: inout [String], limit: Int) {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        guard normalized.count > 1 else { return }

        let key = normalized.lowercased()
        array.removeAll { $0.lowercased() == key }
        array.append(normalized)
        if array.count > limit {
            array = Array(array.suffix(limit))
        }
    }

    private func extractedTopics(from message: String) -> [String] {
        let aboutPatterns = [
            #"(?i)\babout ([A-Za-z0-9 \-']{3,50})"#,
            #"(?i)\bwho is ([A-Za-z0-9 \-']{3,50})"#,
            #"(?i)\bwhat is ([A-Za-z0-9 \-']{3,50})"#,
            #"(?i)\btell me about ([A-Za-z0-9 \-']{3,50})"#
        ]
        let direct = allMatches(in: message, patterns: aboutPatterns).map(cleanFactValue)
        if !direct.isEmpty { return direct }

        let stopWords: Set<String> = [
            "the","and","for","with","that","this","from","have","your","about","what","who","where","when","why",
            "how","into","need","want","please","could","would","there","their","them","they","like","tell","give",
            "more","less","than","just","some","show","does","is","are","was","were","you","gboy"
        ]
        let tokens = message
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }
        return Array(tokens.prefix(4))
    }

    private func buildPrompt(with turns: [ChatTurn], knowledge: [KnowledgeSnippet]) -> String {
        let scenes = characterProfile.allowedScenes.joined(separator: ", ")
        let styleRules = characterProfile.styleRules.map { "- \($0)" }.joined(separator: "\n")
        let emotionKeys = characterProfile.emotionSceneMap.keys.sorted().joined(separator: ", ")
        let transcript = turns.map { turn in
            "\(turn.role.uppercased()): \(turn.content)"
        }.joined(separator: "\n")
        let memorySummary = memoryPromptSummary()
        let knowledgeSummary = knowledgePromptSummary(from: knowledge)

        return """
        \(characterProfile.systemPrompt)

        Character name: \(characterProfile.name)
        Style rules:
        \(styleRules)

        Allowed emotion labels:
        \(emotionKeys)

        Allowed scene labels:
        \(scenes)

        User memory:
        \(memorySummary)

        Live knowledge context:
        \(knowledgeSummary)

        Return exactly one compact JSON object with this shape and no extra text:
        {"reply":"short reply","emotion":"one emotion label","scene":"optional scene label or empty","hungerDelta":0,"socialDelta":0,"energyDelta":0}

        Keep reply under 160 characters. Use scene only when a clear visible action fits. Avoid repeating recent wording.
        The reply must answer the latest USER line directly. Forbidden placeholder replies: "glitchy smile", "glitch smile", "just a smile", "ok", "fine".
        If the user asks a factual question, prefer the live knowledge context when present.
        If the user shares personal details, prefer the user memory.

        Conversation:
        \(transcript)
        """
    }

    private func buildRetryPrompt(with turns: [ChatTurn],
                                  knowledge: [KnowledgeSnippet],
                                  rejectedReply: String,
                                  userMessage: String) -> String {
        """
        \(buildPrompt(with: turns, knowledge: knowledge))

        The previous draft reply "\(Self.condense(rejectedReply))" is rejected.
        Rewrite it so it is not repetitive, not placeholder text, and clearly answers this exact user message:
        USER: \(userMessage)
        """
    }

    private func memoryPromptSummary() -> String {
        var lines: [String] = []
        if let userName = userMemory.userName, !userName.isEmpty {
            lines.append("User name: \(userName)")
        }
        if !userMemory.likes.isEmpty {
            lines.append("Likes: \(userMemory.likes.joined(separator: ", "))")
        }
        if !userMemory.dislikes.isEmpty {
            lines.append("Dislikes: \(userMemory.dislikes.joined(separator: ", "))")
        }
        if !userMemory.facts.isEmpty {
            lines.append("Facts: \(userMemory.facts.joined(separator: " | "))")
        }
        if !userMemory.recentTopics.isEmpty {
            lines.append("Recent topics: \(userMemory.recentTopics.joined(separator: ", "))")
        }
        return lines.isEmpty ? "No stored user facts yet." : lines.joined(separator: "\n")
    }

    private func knowledgePromptSummary(from snippets: [KnowledgeSnippet]) -> String {
        guard !snippets.isEmpty else { return "No live knowledge retrieved for this turn." }
        return snippets.map { snippet in
            "[\(snippet.source)] \(snippet.title): \(snippet.summary) (Source: \(snippet.url))"
        }.joined(separator: "\n")
    }

    private func requestResponse(using provider: ProviderConfig,
                                 prompt: String,
                                 userMessage: String) throws -> CompanionLLMResponse {
        let rawOutput = try runProvider(provider, prompt: prompt)
        return parseResponse(from: rawOutput, userMessage: userMessage)
    }

    private func runProvider(_ provider: ProviderConfig, prompt: String) throws -> String {
        if provider.kind.lowercased() == "openai_compatible" {
            return try runOpenAICompatibleProvider(provider, prompt: prompt)
        }
        if provider.kind.lowercased() == "anthropic" {
            return try runAnthropicProvider(provider, prompt: prompt)
        }

        let executable = resolvedExecutable(for: provider)
        let arguments = try resolvedArguments(for: provider, prompt: prompt, executable: executable)
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let timeout = provider.kind.lowercased() == "ollama" ? 45.0 : 30.0
        var didTimeout = false

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        if let workingDirectory = provider.workingDirectory,
           !workingDirectory.isEmpty {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        var environment = defaultProcessEnvironment()
        (provider.environment ?? [:]).forEach { environment[$0.key] = $0.value }
        process.environment = environment

        try process.run()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            guard process.isRunning else { return }
            didTimeout = true
            process.terminate()
        }
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
        let combined = [stdoutText, stderrText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if didTimeout {
            throw CompanionAIError.processFailed("LLM timed out.")
        }
        guard process.terminationStatus == 0 else {
            throw CompanionAIError.processFailed(Self.condense(Self.stripANSI(combined)))
        }
        return combined
    }

    private func runOpenAICompatibleProvider(_ provider: ProviderConfig, prompt: String) throws -> String {
        let baseURL = provider.apiBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiPath = provider.apiPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? provider.apiPath!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "/chat/completions"
        guard let baseURL, !baseURL.isEmpty,
              let url = URL(string: baseURL + apiPath) else {
            throw CompanionAIError.processFailed("API provider is missing a valid base URL.")
        }

        let apiKeyHeader = provider.apiKeyEnvVar.flatMap { ProcessInfo.processInfo.environment[$0] }
        let body: [String: Any] = [
            "model": provider.apiModel ?? "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": provider.temperature ?? 0.7,
            "max_tokens": provider.maxTokens ?? 180
        ]

        let semaphore = DispatchSemaphore(value: 0)
        var output = ""
        var requestError: Error?

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Gboy Companion Native/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKeyHeader, !apiKeyHeader.isEmpty {
            request.setValue("Bearer \(apiKeyHeader)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                requestError = error
                return
            }
            guard let http = response as? HTTPURLResponse, let data else {
                requestError = CompanionAIError.processFailed("API provider returned no data.")
                return
            }
            guard 200..<300 ~= http.statusCode else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                requestError = CompanionAIError.processFailed(Self.condense(Self.stripANSI(message)))
                return
            }
            output = String(data: data, encoding: .utf8) ?? ""
        }.resume()

        if semaphore.wait(timeout: .now() + 46) == .timedOut {
            throw CompanionAIError.processFailed("API provider timed out.")
        }
        if let requestError { throw requestError }

        if let data = output.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = openAICompatibleContent(from: object) {
                return text
            }
            return output
        }

        return output
    }

    private func runAnthropicProvider(_ provider: ProviderConfig, prompt: String) throws -> String {
        let baseURL = provider.apiBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiPath = provider.apiPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? provider.apiPath!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "/messages"
        guard let baseURL, !baseURL.isEmpty,
              let url = URL(string: baseURL + apiPath) else {
            throw CompanionAIError.processFailed("Claude provider is missing a valid base URL.")
        }

        guard let keyName = provider.apiKeyEnvVar,
              let apiKey = ProcessInfo.processInfo.environment[keyName],
              !apiKey.isEmpty else {
            throw CompanionAIError.processFailed("Missing API key env var for Claude provider.")
        }

        let body: [String: Any] = [
            "model": provider.apiModel ?? "claude-3-5-haiku-latest",
            "max_tokens": provider.maxTokens ?? 180,
            "temperature": provider.temperature ?? 0.7,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let semaphore = DispatchSemaphore(value: 0)
        var output = ""
        var requestError: Error?

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("Gboy Companion Native/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                requestError = error
                return
            }
            guard let http = response as? HTTPURLResponse, let data else {
                requestError = CompanionAIError.processFailed("Claude provider returned no data.")
                return
            }
            guard 200..<300 ~= http.statusCode else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                requestError = CompanionAIError.processFailed(Self.condense(Self.stripANSI(message)))
                return
            }
            output = String(data: data, encoding: .utf8) ?? ""
        }.resume()

        if semaphore.wait(timeout: .now() + 46) == .timedOut {
            throw CompanionAIError.processFailed("Claude provider timed out.")
        }
        if let requestError { throw requestError }

        if let data = output.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = anthropicContent(from: object) {
            return text
        }

        return output
    }

    private func resolvedExecutable(for provider: ProviderConfig) -> String {
        switch provider.kind.lowercased() {
        case "ollama":
            return resolvedOllamaExecutable(preferred: provider.executablePath)
        default:
            return provider.executablePath?.isEmpty == false ? provider.executablePath! : "/usr/bin/env"
        }
    }

    private func resolvedArguments(for provider: ProviderConfig, prompt: String, executable: String) throws -> [String] {
        let template = provider.argumentsTemplate ?? Self.defaultArgumentsTemplate(for: provider)
        guard !template.isEmpty else { throw CompanionAIError.missingPromptTemplate }

        let replacements: [String: String] = [
            "prompt": prompt,
            "model_path": provider.modelPath ?? "",
            "ollama_model": provider.ollamaModel ?? "qwen2.5:3b-instruct",
            "temperature": String(format: "%.2f", provider.temperature ?? 0.8),
            "max_tokens": String(provider.maxTokens ?? 140),
            "context_size": String(provider.contextSize ?? 2048),
            "threads": String(provider.threads ?? 2),
            "json_schema": Self.responseJSONSchema,
            "api_base_url": provider.apiBaseURL ?? "",
            "api_path": provider.apiPath ?? "",
            "api_key_env_var": provider.apiKeyEnvVar ?? "",
            "api_model": provider.apiModel ?? ""
        ]

        var arguments = template.map { token in
            replacements.reduce(token) { partial, pair in
                partial.replacingOccurrences(of: "{{\(pair.key)}}", with: pair.value)
            }
        }

        if provider.kind.lowercased() == "ollama",
           executable != "/usr/bin/env",
           arguments.first == "ollama" {
            arguments.removeFirst()
        }

        return arguments
    }

    private func defaultProcessEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "dumb"
        environment["NO_COLOR"] = "1"
        environment["CLICOLOR"] = "0"
        environment["HOME"] = environment["HOME"] ?? NSHomeDirectory()

        let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let current = environment["PATH"], !current.isEmpty {
            if !current.contains("/usr/local/bin") || !current.contains("/opt/homebrew/bin") {
                environment["PATH"] = current + ":" + defaultPath
            }
        } else {
            environment["PATH"] = defaultPath
        }

        return environment
    }

    private func resolvedOllamaExecutable(preferred: String?) -> String {
        if let preferred, !preferred.isEmpty, preferred != "/usr/bin/env" {
            return preferred
        }

        let candidates = [
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
            "/usr/bin/ollama"
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }

        return "/usr/bin/env"
    }

    private func parseResponse(from rawOutput: String, userMessage: String) -> CompanionLLMResponse {
        let cleaned = Self.stripANSI(rawOutput)
        let candidates = Self.jsonCandidates(in: cleaned)

        for candidate in candidates.reversed() {
            if let data = candidate.data(using: .utf8),
               let decoded = try? decoder.decode(CompanionLLMResponse.self, from: data),
               !decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return normalized(response: decoded)
            }
            if let data = candidate.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let decoded = response(fromJSONObject: object) {
                return normalized(response: decoded)
            }
        }

        let filteredLines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                !$0.hasPrefix("main:") &&
                !$0.hasPrefix("llama_") &&
                !$0.hasPrefix("llm_") &&
                !$0.hasPrefix("system_info:") &&
                !$0.hasPrefix("sampler") &&
                !$0.hasPrefix("generate:") &&
                !$0.hasPrefix("build:") &&
                !$0.hasPrefix("ggml_") &&
                !$0.hasPrefix("common_") &&
                !$0.hasPrefix("repeat_last_n") &&
                !$0.hasPrefix("top_k") &&
                !$0.hasPrefix("mirostat") &&
                !$0.hasPrefix("== Running in interactive mode") &&
                !$0.hasPrefix("- Press") &&
                !$0.hasPrefix("System:") &&
                !$0.hasPrefix("Return exactly one compact JSON object") &&
                !$0.hasPrefix("Return exactly this JSON")
            }

        if let lastLine = filteredLines.last {
            return normalized(response: CompanionLLMResponse(
                reply: Self.condense(lastLine),
                emotion: inferEmotion(from: lastLine, userMessage: userMessage),
                scene: nil,
                hungerDelta: 0,
                socialDelta: 0,
                energyDelta: 0
            ))
        }

        return normalized(response: CompanionLLMResponse(
            reply: "Signal scrambled. Try that again.",
            emotion: inferEmotion(from: userMessage, userMessage: userMessage),
            scene: nil,
            hungerDelta: 0,
            socialDelta: 0,
            energyDelta: 0
        ))
    }

    private func response(fromJSONObject object: [String: Any]) -> CompanionLLMResponse? {
        if let reply = object["reply"] as? String,
           !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CompanionLLMResponse(
                reply: reply,
                emotion: object["emotion"] as? String,
                scene: object["scene"] as? String,
                hungerDelta: object["hungerDelta"] as? Double,
                socialDelta: object["socialDelta"] as? Double,
                energyDelta: object["energyDelta"] as? Double
            )
        }

        if let responseText = object["response"] as? String,
           !responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let nestedData = responseText.data(using: .utf8),
               let nested = try? decoder.decode(CompanionLLMResponse.self, from: nestedData) {
                return nested
            }
            return CompanionLLMResponse(
                reply: responseText,
                emotion: object["emotion"] as? String,
                scene: object["scene"] as? String,
                hungerDelta: object["hungerDelta"] as? Double,
                socialDelta: object["socialDelta"] as? Double,
                energyDelta: object["energyDelta"] as? Double
            )
        }

        return nil
    }

    private func fetchKnowledgeContext(for message: String) -> [KnowledgeSnippet] {
        guard shouldFetchKnowledge(for: message) else { return [] }
        let query = bestKnowledgeQuery(for: message)
        guard !query.isEmpty else { return [] }

        var snippets: [KnowledgeSnippet] = []

        if let wikipedia = fetchWikipediaSnippet(for: query) {
            snippets.append(wikipedia)
        }
        if let wikidata = fetchWikidataSnippet(for: query),
           !snippets.contains(where: { $0.title.caseInsensitiveCompare(wikidata.title) == .orderedSame }) {
            snippets.append(wikidata)
        }
        if isBookishQuery(message),
           let openLibrary = fetchOpenLibrarySnippet(for: query) {
            snippets.append(openLibrary)
        }

        return Array(snippets.prefix(3))
    }

    private func groundedKnowledgeResponse(for message: String, knowledge: [KnowledgeSnippet]) -> CompanionLLMResponse? {
        guard shouldUseGroundedKnowledgeReply(for: message),
              let primary = knowledge.first else { return nil }

        let sentence = primary.summary
            .components(separatedBy: ". ")
            .prefix(2)
            .joined(separator: ". ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !sentence.isEmpty else { return nil }

        let lead: String
        switch primary.source {
        case "Wikipedia":
            lead = "Archive says"
        case "Wikidata":
            lead = "Signal file says"
        case "Open Library":
            lead = "Open Library has"
        default:
            lead = "Record says"
        }

        let reply = "\(lead) \(sentence)."
        let emotion = primary.source == "Open Library" ? "focused" : "watchful"
        let scene = primary.source == "Open Library" ? "zine_read" : "signal_decode"
        return normalized(response: CompanionLLMResponse(
            reply: reply,
            emotion: emotion,
            scene: scene,
            hungerDelta: 0,
            socialDelta: 0,
            energyDelta: 0
        ))
    }

    private func shouldUseGroundedKnowledgeReply(for message: String) -> Bool {
        let lowered = message.lowercased()
        let directFactTriggers = [
            "who is", "what is", "where is", "when did", "when was",
            "tell me about", "look up", "search", "explain", "book", "author", "novel"
        ]
        return lowered.contains("?") || directFactTriggers.contains { lowered.contains($0) }
    }

    private func shouldFetchKnowledge(for message: String) -> Bool {
        let lowered = message.lowercased()
        if lowered.contains("?") { return true }
        let triggers = [
            "who is", "what is", "where is", "when did", "why is", "how does",
            "tell me about", "look up", "search", "wikipedia", "wikidata",
            "book", "author", "novel", "history of", "explain"
        ]
        return triggers.contains { lowered.contains($0) }
    }

    private func bestKnowledgeQuery(for message: String) -> String {
        if let explicit = firstMatch(in: message, patterns: [
            #"(?i)\btell me about ([^?!]+)"#,
            #"(?i)\blook up ([^?!]+)"#,
            #"(?i)\bsearch(?: for)? ([^?!]+)"#,
            #"(?i)\bwho is ([^?!]+)"#,
            #"(?i)\bwhat is ([^?!]+)"#
        ]) {
            return cleanFactValue(explicit)
        }

        let topics = extractedTopics(from: message.lowercased())
        return topics.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBookishQuery(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return ["book", "author", "novel", "read", "writer", "publication"].contains { lowered.contains($0) }
    }

    private func fetchWikipediaSnippet(for query: String) -> KnowledgeSnippet? {
        guard var searchComponents = URLComponents(string: "https://en.wikipedia.org/w/api.php") else { return nil }
        searchComponents.queryItems = [
            URLQueryItem(name: "action", value: "opensearch"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "namespace", value: "0"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let searchURL = searchComponents.url,
              let raw = fetchJSON(from: searchURL) as? [Any],
              raw.count > 1,
              let titles = raw[1] as? [String],
              let title = titles.first,
              !title.isEmpty else { return nil }

        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let summaryURL = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)"),
              let summaryObject = fetchJSON(from: summaryURL) as? [String: Any] else { return nil }

        let extract = (summaryObject["extract"] as? String) ?? (summaryObject["description"] as? String) ?? ""
        guard !extract.isEmpty else { return nil }
        let pageURL = ((summaryObject["content_urls"] as? [String: Any])?["desktop"] as? [String: Any])?["page"] as? String
            ?? "https://en.wikipedia.org/wiki/\(encodedTitle)"

        return KnowledgeSnippet(
            source: "Wikipedia",
            title: title,
            summary: Self.condense(extract),
            url: pageURL
        )
    }

    private func fetchWikidataSnippet(for query: String) -> KnowledgeSnippet? {
        guard var components = URLComponents(string: "https://www.wikidata.org/w/api.php") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "action", value: "wbsearchentities"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url,
              let object = fetchJSON(from: url) as? [String: Any],
              let results = object["search"] as? [[String: Any]],
              let first = results.first,
              let id = first["id"] as? String,
              let label = first["label"] as? String else { return nil }

        let description = (first["description"] as? String) ?? "Entity match from Wikidata."
        return KnowledgeSnippet(
            source: "Wikidata",
            title: label,
            summary: Self.condense(description),
            url: "https://www.wikidata.org/wiki/\(id)"
        )
    }

    private func fetchOpenLibrarySnippet(for query: String) -> KnowledgeSnippet? {
        guard var components = URLComponents(string: "https://openlibrary.org/search.json") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "fields", value: "title,author_name,first_publish_year,key")
        ]
        guard let url = components.url,
              let object = fetchJSON(from: url) as? [String: Any],
              let docs = object["docs"] as? [[String: Any]],
              let first = docs.first,
              let title = first["title"] as? String else { return nil }

        let author = (first["author_name"] as? [String])?.first ?? "Unknown author"
        let year = first["first_publish_year"] as? Int
        let key = first["key"] as? String ?? ""
        let summary = year != nil
            ? "\(title) by \(author), first published in \(year!)."
            : "\(title) by \(author)."

        return KnowledgeSnippet(
            source: "Open Library",
            title: title,
            summary: summary,
            url: key.isEmpty ? "https://openlibrary.org" : "https://openlibrary.org\(key)"
        )
    }

    private func fetchJSON(from url: URL, timeout: TimeInterval = 6.0) -> Any? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Any?

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("Gboy Companion Native/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                  let data else { return }
            result = try? JSONSerialization.jsonObject(with: data)
        }.resume()

        _ = semaphore.wait(timeout: .now() + timeout + 1.0)
        return result
    }

    private func openAICompatibleContent(from object: [String: Any]) -> String? {
        if let choices = object["choices"] as? [[String: Any]],
           let first = choices.first {
            if let message = first["message"] as? [String: Any],
               let content = message["content"] as? String,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            }
            if let text = first["text"] as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        if let output = object["output_text"] as? String,
           !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return output
        }
        if let response = object["response"] as? String,
           !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return response
        }
        return nil
    }

    private func anthropicContent(from object: [String: Any]) -> String? {
        if let content = object["content"] as? [[String: Any]] {
            let textParts = content.compactMap { item -> String? in
                guard (item["type"] as? String) == "text" else { return nil }
                return item["text"] as? String
            }
            let joined = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { return joined }
        }
        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }
        return nil
    }

    private func inferEmotion(from reply: String, userMessage: String) -> String {
        let haystack = "\(reply.lowercased()) \(userMessage.lowercased())"
        if haystack.contains("sorry") || haystack.contains("sad") || haystack.contains("hurt") { return "sad" }
        if haystack.contains("watch") || haystack.contains("observe") || haystack.contains("trace") { return "watchful" }
        if haystack.contains("what") || haystack.contains("?") || haystack.contains("confused") { return "confused" }
        if haystack.contains("angry") || haystack.contains("back off") || haystack.contains("threat") { return "angry" }
        if haystack.contains("glitch") || haystack.contains("smoke") || haystack.contains("signal") { return "glitchy" }
        return "focused"
    }

    private func normalized(response: CompanionLLMResponse) -> CompanionLLMResponse {
        CompanionLLMResponse(
            reply: Self.condense(response.reply),
            emotion: canonicalEmotionLabel(response.emotion),
            scene: normalizedSceneName(response.scene),
            hungerDelta: clampedDelta(response.hungerDelta),
            socialDelta: clampedDelta(response.socialDelta),
            energyDelta: clampedDelta(response.energyDelta)
        )
    }

    private func canonicalEmotionLabel(_ emotion: String?) -> String? {
        guard let raw = emotion?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        switch raw {
        case "happy", "focused", "suspicious", "glitchy", "calm", "mischievous",
             "confused", "bored", "angry", "sad", "watchful":
            return raw
        case "excited", "upbeat", "playful", "friendly":
            return "happy"
        case "curious", "uneasy", "alert", "protective", "guarded":
            return "watchful"
        case "relaxed", "neutral", "steady":
            return "calm"
        case "annoyed", "hostile", "frustrated":
            return "angry"
        case "melancholy", "hurt", "down":
            return "sad"
        case "scheming", "cheeky", "teasing":
            return "mischievous"
        default:
            return inferEmotion(from: raw, userMessage: raw)
        }
    }

    private func normalizedSceneName(_ scene: String?) -> String? {
        guard let scene else { return nil }
        let normalized = scene
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func clampedDelta(_ value: Double?) -> Double {
        let unwrapped = value ?? 0
        return min(8, max(-8, unwrapped))
    }

    private func fallbackResponse(for userMessage: String) -> CompanionLLMResponse {
        let lowered = userMessage.lowercased()
        let reply: String
        let emotion: String
        let scene: String?

        if let userName = userMemory.userName,
           (lowered.contains("hi") || lowered.contains("hello") || lowered.contains("hey")) {
            let options = [
                "\(userName), you're back on the channel.",
                "There you are, \(userName). Signal looks clean enough.",
                "\(userName), I clocked your return."
            ]
            reply = options[history.count % options.count]
            emotion = "happy"
            scene = "wave"
        } else if let name = firstMatch(in: userMessage, patterns: [
            #"(?i)\bmy name is ([A-Za-z][A-Za-z '\-]{1,30})"#,
            #"(?i)\bi am ([A-Za-z][A-Za-z '\-]{1,30})\b"#,
            #"(?i)\bi'm ([A-Za-z][A-Za-z '\-]{1,30})\b"#
        ]) {
            let cleanName = cleanFactValue(name)
            reply = "\(cleanName). Logged. I’ll keep it on file."
            emotion = "focused"
            scene = "terminal_trace"
        } else if lowered.contains("?") || lowered.contains("what") || lowered.contains("why") || lowered.contains("how") {
            let options = [
                "That needs a cleaner trace. Give me the target and I’ll work it.",
                "There’s a real answer in there. I just need a better angle on it.",
                "Hold still. I’m tracing that question through the noise."
            ]
            reply = options[history.count % options.count]
            emotion = "watchful"
            scene = "shoulder_scan"
        } else if lowered.contains("help") {
            reply = "State the problem clearly. I can track memory, look things up, and swing the mood board."
            emotion = "focused"
            scene = "signal_decode"
        } else {
            let options = [
                "I heard you. Keep talking before the signal goes stale.",
                "That tracks. Give me one more detail and I can work with it.",
                "Noted. The file stays open."
            ]
            reply = options[history.count % options.count]
            emotion = "mischievous"
            scene = "headjack"
        }

        return normalized(response: CompanionLLMResponse(
            reply: reply,
            emotion: emotion,
            scene: scene,
            hungerDelta: 0,
            socialDelta: 1,
            energyDelta: 0
        ))
    }

    private func normalizedReplyKey(_ text: String) -> String {
        Self.condense(text)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rotatedScene(from options: [String], fallback: String?) -> String? {
        let normalized = options.compactMap(normalizedSceneName).filter { allowedSceneSet.contains($0) }
        guard !normalized.isEmpty else { return fallback }
        let index = min(normalized.count - 1, max(0, (history.count / 2) % normalized.count))
        return normalized[index]
    }

    private func preferredChatScenes(for emotion: String?) -> [String] {
        switch emotion {
        case "happy":
            return ["wave", "happy", "applaud"]
        case "focused":
            return ["terminal_trace", "signal_decode", "terminal_type"]
        case "suspicious", "watchful":
            return ["shoulder_scan", "monitor_lurk", "question_lurk"]
        case "glitchy":
            return ["glitch", "headjack", "smoke_burst"]
        case "calm":
            return ["sit_cross", "blanket_nest", "throne"]
        case "mischievous":
            return ["headjack", "tongue", "glitch"]
        case "confused":
            return ["confused", "question_type", "question_lurk"]
        case "bored":
            return ["bored", "tv_flip", "handheld_game"]
        case "angry":
            return ["angry", "attack", "psonic_charge"]
        case "sad":
            return ["sulk", "cry", "blanket_nest"]
        default:
            return []
        }
    }

    private var allowedSceneSet: Set<String> {
        Set(characterProfile.allowedScenes.compactMap(normalizedSceneName))
    }

    private var subtleChatScenes: Set<String> {
        ["smoke_drift", "smoke_orbit"]
    }

    private var bannedReplyKeys: Set<String> {
        [
            "glitchy smile",
            "glitch smile",
            "just a smile",
            "smile",
            "ok",
            "okay",
            "fine"
        ]
    }

    private static func bundledAIDirectory() -> URL? {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("AI"),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }

        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let devFallback = exe
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/AI")
            .standardizedFileURL
        return FileManager.default.fileExists(atPath: devFallback.path) ? devFallback : nil
    }

    private static func detectBestProvider() -> ProviderConfig? {
        detectOllamaProvider()
    }

    private static func detectOllamaProvider() -> ProviderConfig? {
        guard commandExists("ollama") else { return nil }
        return ProviderConfig(
            kind: "ollama",
            displayName: "Ollama Local",
            executablePath: "/usr/bin/env",
            workingDirectory: "",
            argumentsTemplate: ["ollama", "run", "{{ollama_model}}", "--format", "json", "--hidethinking", "{{prompt}}"],
            environment: [:],
            modelPath: "",
            ollamaModel: "qwen2.5:3b-instruct",
            temperature: 0.8,
            maxTokens: 160,
            contextSize: 4096,
            threads: 2,
            apiBaseURL: nil,
            apiPath: nil,
            apiKeyEnvVar: nil,
            apiModel: nil
        )
    }

    private static func defaultArgumentsTemplate(for provider: ProviderConfig) -> [String] {
        switch provider.kind.lowercased() {
        case "ollama":
            return ["ollama", "run", "{{ollama_model}}", "--format", "json", "--hidethinking", "{{prompt}}"]
        default:
            return provider.argumentsTemplate ?? []
        }
    }

    private static func defaultMemoryProfile() -> UserMemoryProfile {
        UserMemoryProfile(
            userName: nil,
            likes: [],
            dislikes: [],
            facts: [],
            recentTopics: []
        )
    }

    private static func defaultCharacterProfile() -> CharacterProfile {
        CharacterProfile(
            name: "Gboy",
            systemPrompt: "You are Gboy, a tiny desktop companion with a paranoid, sarcastic, hacker-glitch personality.",
            styleRules: [
                "Reply in 1 or 2 short sentences.",
                "Stay coherent and do not repeat yourself.",
                "Never mention being an AI model.",
                "Use stored memory for personal details and live knowledge for factual questions when available."
            ],
            emotionSceneMap: [
                "happy": ["happy", "wave"],
                "focused": ["terminal_trace", "terminal_type"],
                "suspicious": ["shoulder_scan", "monitor_lurk"],
                "glitchy": ["glitch", "smoke_orbit"],
                "calm": ["sit_cross", "blanket_nest"],
                "confused": ["confused", "question_lurk"],
                "angry": ["angry", "attack"],
                "sad": ["cry", "sleep_lie"]
            ],
            allowedScenes: ["happy", "wave", "terminal_trace", "terminal_type", "shoulder_scan", "monitor_lurk", "glitch", "smoke_orbit", "sit_cross", "blanket_nest", "confused", "question_lurk", "angry", "attack", "cry", "sleep_lie"]
        )
    }

    private static func defaultProviderConfig() -> ProviderConfig {
        ProviderConfig(
            kind: "ollama",
            displayName: "Ollama Local",
            executablePath: "/usr/bin/env",
            workingDirectory: "",
            argumentsTemplate: [
                "ollama",
                "run",
                "{{ollama_model}}",
                "--format",
                "json",
                "--hidethinking",
                "{{prompt}}"
            ],
            environment: [:],
            modelPath: "",
            ollamaModel: "qwen2.5:3b-instruct",
            temperature: 0.8,
            maxTokens: 160,
            contextSize: 4096,
            threads: 2,
            apiBaseURL: nil,
            apiPath: nil,
            apiKeyEnvVar: nil,
            apiModel: nil
        )
    }

    private static func commandExists(_ command: String) -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", command]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func stripANSI(_ value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]", options: []) else {
            return value
        }
        let range = NSRange(location: 0, length: (value as NSString).length)
        return regex.stringByReplacingMatches(in: value, options: [], range: range, withTemplate: "")
    }

    private static func condense(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func jsonCandidates(in text: String) -> [String] {
        var candidates: [String] = []
        var depth = 0
        var startIndex: String.Index?
        var inString = false
        var isEscaping = false

        for index in text.indices {
            let char = text[index]

            if isEscaping {
                isEscaping = false
                continue
            }

            if inString && char == "\\" {
                isEscaping = true
                continue
            }

            if char == "\"" {
                inString.toggle()
                continue
            }

            if inString { continue }

            if char == "{" {
                if depth == 0 { startIndex = index }
                depth += 1
            } else if char == "}", depth > 0 {
                depth -= 1
                if depth == 0, let startIndex {
                    candidates.append(String(text[startIndex...index]))
                }
            }
        }

        return candidates
    }

    private static let responseJSONSchema = """
    {"type":"object","properties":{"reply":{"type":"string"},"emotion":{"type":"string"},"scene":{"type":"string"},"hungerDelta":{"type":"number"},"socialDelta":{"type":"number"},"energyDelta":{"type":"number"}},"required":["reply","emotion","scene","hungerDelta","socialDelta","energyDelta"],"additionalProperties":false}
    """
}
