import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: CompanionController?
    private var statusItem: NSStatusItem?
    private var aiService: CompanionAIService?
    private var chatWindow: ChatWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            controller = try CompanionController()
            controller?.onChatRequested = { [weak self] in
                self?.openChat()
            }
            controller?.launch()
            configureAI()
            configureStatusItem()
        } catch {
            fputs("Failed to launch native companion: \(error.localizedDescription)\n", stderr)
            NSApp.terminate(nil)
        }
    }

    // MARK: - Menu

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Gboy"

        let menu = NSMenu()

        menu.addItem(withTitle: "Feed",        action: #selector(feed),        keyEquivalent: "f")
        menu.addItem(withTitle: "Sleep",       action: #selector(sleep),       keyEquivalent: "s")
        menu.addItem(withTitle: "Play",        action: #selector(play),        keyEquivalent: "p")
        menu.addItem(.separator())

        let playItem = NSMenuItem(title: "Play Scenes", action: nil, keyEquivalent: "")
        playItem.submenu = buildPlayMenu()
        menu.addItem(playItem)

        if aiService != nil {
            menu.addItem(.separator())
            let aiItem = NSMenuItem(title: "AI", action: nil, keyEquivalent: "")
            aiItem.submenu = buildAIMenu()
            menu.addItem(aiItem)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Pause / Resume", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    private func buildPlayMenu() -> NSMenu {
        let m = NSMenu(title: "Play")

        let directedItem = NSMenuItem(title: "Directed Sequences", action: nil, keyEquivalent: "")
        let directedMenu = NSMenu(title: "Directed Sequences")
        directedMenu.addItem(scene("Walk Around", "walk"))
        directedMenu.addItem(scene("Run Around", "run"))
        directedMenu.addItem(scene("Skate Route", "skate"))
        directedMenu.addItem(scene("Hack Session", "hackSession"))
        directedMenu.addItem(scene("Spy Run", "spyRun"))
        directedMenu.addItem(scene("Graffiti Run", "graffiti"))
        directedMenu.addItem(scene("Signal Sweep", "signal"))
        directedMenu.addItem(scene("Portal Sequence", "portal"))
        directedMenu.addItem(scene("Charged Burst", "chargedBlast"))
        directedMenu.addItem(scene("Destroy Cursor", "destroyCursor"))
        directedItem.submenu = directedMenu
        m.addItem(directedItem)

        for (title, names) in sceneLibraryGroups() {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = buildSceneGroupMenu(title: title, sceneNames: names)
            m.addItem(item)
        }

        return m
    }

    private func sceneLibraryGroups() -> [(String, [String])] {
        let definitions: [(String, [String])] = [
            ("Movement", [
                "idle_front", "idle_back", "idle_left", "idle_right",
                "walk_front", "walk_back", "walk_left", "walk_right",
                "run_left", "run_right", "jump_side", "sneak", "skateboard",
                "dash", "drop", "fall"
            ]),
            ("Looks And Mood", [
                "look_left", "look_right", "look_up", "look_down",
                "happy", "angry", "cry", "tongue", "confused", "bored", "wave",
                "hood_peek", "side_eye", "sulk", "proud_stance",
                "stretch", "yawn", "stumble", "float", "shiver", "dizzy", "tantrum"
            ]),
            ("Play And Style", [
                "dance", "moonwalk", "backflip", "spin", "applaud", "bow", "soccer_goal"
            ]),
            ("Food And Rest", [
                "eat", "sleep_lie", "blanket_nest", "sleep_curl", "sleep_sit",
                "sit_cross", "throne", "cook_meal", "noodle_eat", "desk_noodles",
                "fridge_open", "mug_sip", "phone_call", "umbrella", "desk_doze"
            ]),
            ("Desk And Signal", [
                "computer_idle", "terminal_type", "typing_fast", "terminal_trace",
                "signal_decode", "shoulder_scan", "question_type", "question_lurk",
                "monitor_lurk", "evidence_hack", "file_scan", "file_sort",
                "desk_sketch", "pinboard_plot", "dossier_check", "signal_sweep",
                "bug_sweep", "crt_watch", "tv_flip", "handheld_game",
                "radio_listen", "zine_read"
            ]),
            ("Wall And Graffiti", [
                "climb_side", "climb_right", "climb_back",
                "wall_sit", "wallslide", "peek_left", "peek_right",
                "graffiti_bloc", "graffiti_was_here", "spray_tag", "sticker_slap"
            ]),
            ("Smoke And Power", [
                "cape_flutter", "attack", "laser", "headjack", "glitch", "hide",
                "portal", "vanish", "smoke_burst", "smoke_reform", "smoke_drift",
                "smoke_orbit", "psonic_charge", "psonic_overload",
                "portal_walk", "skyfall", "landing_recover"
            ]),
        ]

        let allClips = Set(CompanionController.clips.keys)
        var seen = Set<String>()
        var groups: [(String, [String])] = []

        for (title, names) in definitions {
            let filtered = names.filter { allClips.contains($0) && !seen.contains($0) }
            seen.formUnion(filtered)
            if !filtered.isEmpty {
                groups.append((title, filtered))
            }
        }

        let leftovers = allClips.subtracting(seen).sorted()
        if !leftovers.isEmpty {
            groups.append(("More", leftovers))
        }

        return groups
    }

    private func buildSceneGroupMenu(title: String, sceneNames: [String]) -> NSMenu {
        let menu = NSMenu(title: title)
        for sceneName in sceneNames {
            menu.addItem(scene(sceneTitle(for: sceneName), sceneName))
        }
        return menu
    }

    private func sceneTitle(for key: String) -> String {
        let exact: [String: String] = [
            "tv_flip": "TV Flip",
            "crt_watch": "CRT Watch",
            "psonic_charge": "Psonic Charge",
            "psonic_overload": "Psonic Overload",
            "hood_peek": "Hood Peek",
            "side_eye": "Side Eye",
            "desk_doze": "Desk Doze",
            "question_lurk": "Question Lurk",
            "question_type": "Question Type",
            "signal_decode": "Signal Decode",
            "signal_sweep": "Signal Sweep",
            "terminal_trace": "Terminal Trace",
            "terminal_type": "Terminal Type",
            "file_scan": "File Scan",
            "file_sort": "File Sort",
            "mug_sip": "Mug Sip",
            "phone_call": "Phone Call",
            "portal_walk": "Portal Walk",
            "skyfall": "Skyfall",
            "landing_recover": "Landing Recover"
        ]
        if let exactTitle = exact[key] {
            return exactTitle
        }

        return key
            .split(separator: "_")
            .map { part in
                switch part.lowercased() {
                case "tv": return "TV"
                case "crt": return "CRT"
                default: return part.prefix(1).uppercased() + part.dropFirst()
                }
            }
            .joined(separator: " ")
    }

    private func buildAIMenu() -> NSMenu {
        let menu = NSMenu(title: "AI")
        menu.addItem(withTitle: "Open Chat", action: #selector(openChat), keyEquivalent: "c")
        let presetsItem = NSMenuItem(title: "Provider Presets", action: nil, keyEquivalent: "")
        presetsItem.submenu = buildProviderPresetMenu()
        menu.addItem(presetsItem)
        menu.addItem(withTitle: "Edit Character File", action: #selector(editCharacterFile), keyEquivalent: "")
        menu.addItem(withTitle: "Edit Provider File", action: #selector(editProviderFile), keyEquivalent: "")
        menu.addItem(withTitle: "Edit Memory File", action: #selector(editMemoryFile), keyEquivalent: "")
        menu.addItem(withTitle: "Reload AI Files", action: #selector(reloadAI), keyEquivalent: "r")
        return menu
    }

    private func buildProviderPresetMenu() -> NSMenu {
        let menu = NSMenu(title: "Provider Presets")
        menu.addItem(providerPresetItem("Use Ollama", "provider.ollama.example.json"))
        menu.addItem(providerPresetItem("Use OpenAI", "provider.openai.example.json"))
        menu.addItem(providerPresetItem("Use Claude", "provider.claude.example.json"))
        menu.addItem(providerPresetItem("Use OpenAI-Compatible", "provider.openai-compatible.example.json"))
        return menu
    }

    /// Helper: builds a menu item that calls triggerScene(_:) with the given key.
    private func scene(_ title: String, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(playScene(_:)), keyEquivalent: "")
        item.representedObject = key
        item.target = self
        return item
    }

    private func providerPresetItem(_ title: String, _ fileName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(applyProviderPreset(_:)), keyEquivalent: "")
        item.representedObject = fileName
        item.target = self
        return item
    }

    private func configureAI() {
        do {
            let service = try CompanionAIService()
            let window = ChatWindowController()
            window.onSend = { [weak self] message in
                self?.sendChatMessage(message)
            }
            window.loadHistory(service.recentTurns(limit: 40))
            aiService = service
            chatWindow = window
        } catch {
            fputs("AI unavailable: \(error.localizedDescription)\n", stderr)
        }
    }

    private func sendChatMessage(_ message: String) {
        guard let aiService, let chatWindow else { return }

        chatWindow.appendUser(message)
        chatWindow.setThinking(true, detail: "Checking memory and live knowledge...")

        aiService.send(userMessage: message) { [weak self] result in
            guard let self else { return }
            self.chatWindow?.setThinking(false)

            switch result {
            case .success(let response):
                self.chatWindow?.appendAssistant(response.reply)
                let preferredScene = aiService.sceneForEmotion(response.emotion, sceneHint: response.scene)
                self.controller?.applyAIResponse(response, preferredScene: preferredScene)
            case .failure(let error):
                self.chatWindow?.appendSystem("Provider error: \(error.localizedDescription)")
            }
        }
    }

    private func openFile(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Actions

    @objc private func feed()        { controller?.feed() }
    @objc private func sleep()       { controller?.sleep() }
    @objc private func play()        { controller?.play() }
    @objc private func togglePause() { controller?.togglePause() }
    @objc private func quit()        { NSApp.terminate(nil) }
    @objc private func openChat() {
        guard let chatWindow else { return }
        chatWindow.showWindowAndFocus()
        if let aiService {
            chatWindow.loadHistory(aiService.recentTurns(limit: 40))
        }
    }

    @objc private func editCharacterFile() {
        openFile(aiService?.characterFileURL)
    }

    @objc private func editProviderFile() {
        openFile(aiService?.providerFileURL)
    }

    @objc private func editMemoryFile() {
        openFile(aiService?.memoryFileURL)
    }

    @objc private func applyProviderPreset(_ sender: NSMenuItem) {
        guard let fileName = sender.representedObject as? String,
              let aiService else { return }
        do {
            try aiService.applyBundledProviderPreset(named: fileName)
            chatWindow?.appendSystem("Applied provider preset: \(sender.title)")
            openFile(aiService.providerFileURL)
        } catch {
            chatWindow?.appendSystem("Preset failed: \(error.localizedDescription)")
        }
    }

    @objc private func reloadAI() {
        do {
            try aiService?.reload()
            if let aiService {
                chatWindow?.loadHistory(aiService.recentTurns(limit: 40))
            }
            chatWindow?.appendSystem("AI files reloaded.")
        } catch {
            chatWindow?.appendSystem("Reload failed: \(error.localizedDescription)")
        }
    }

    @objc private func playScene(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        controller?.triggerScene(key)
    }
}

// MARK: - Entry point

if CommandLine.arguments.contains("--smoke-test") {
    do {
        try CompanionController.smokeTest()
        exit(0)
    } catch {
        fputs("Smoke test failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
