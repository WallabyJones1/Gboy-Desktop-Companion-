import AppKit
import AVFoundation
import Foundation
import ImageIO

// MARK: - Types

private enum Surface { case floor, left, right, top }

struct AnimationClip {
    let sheetName: String
    let fps: Double
    let looping: Bool
}

// MARK: - Asset loading

private enum AssetLocator {
    static func spriteDirectory() -> URL {
        let fm = FileManager.default
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let bundled = exe
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Sprites")
        if fm.fileExists(atPath: bundled.path) { return bundled }
        if let env = ProcessInfo.processInfo.environment["GBOY_SPRITES_DIR"] {
            let envURL = URL(fileURLWithPath: env)
            if fm.fileExists(atPath: envURL.path) { return envURL }
        }
        // Dev fallback: look for the sprite directory relative to the executable (two levels up = repo root)
        let devFallback = exe
            .deletingLastPathComponent()   // MacOS/
            .deletingLastPathComponent()   // Contents/
            .deletingLastPathComponent()   // *.app/
            .deletingLastPathComponent()   // build/
            .appendingPathComponent("../godot-game/assets/sprites/player")
            .standardizedFileURL
        if fm.fileExists(atPath: devFallback.path) { return devFallback }
        fatalError("Sprite directory not found. Build the app with build_app.sh so sprites are bundled.")
    }

    static func soundURL(named name: String) -> URL? {
        let fm = FileManager.default
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let bundled = exe
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Sounds/\(name)")
        if fm.fileExists(atPath: bundled.path) { return bundled }
        // Dev fallback: look relative to the executable
        let devFallback = exe
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets/\(name)")
            .standardizedFileURL
        return fm.fileExists(atPath: devFallback.path) ? devFallback : nil
    }
}

// MARK: - Sprite atlas

private final class SpriteAtlas {
    let name: String
    let frameCount: Int
    let frameSize: CGSize
    private let frames: [CGImage]

    init(url: URL) throws {
        name = url.lastPathComponent
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { throw NSError(domain: "GboyCompanionNative", code: 1,
                             userInfo: [NSLocalizedDescriptionKey: "Cannot load \(url.lastPathComponent)"]) }

        let side = max(1, sheet.height)
        let count = max(1, sheet.width / side)
        var extracted: [CGImage] = []
        extracted.reserveCapacity(count)
        for i in 0 ..< count {
            if let f = sheet.cropping(to: CGRect(x: i * side, y: 0, width: side, height: side)) {
                extracted.append(f)
            }
        }
        frameCount = extracted.count
        frameSize  = CGSize(width: side, height: side)
        frames = extracted
    }

    func frame(at index: Int) -> CGImage? {
        frames.isEmpty ? nil : frames[index % frames.count]
    }
}

private final class SpriteLibrary {
    private let rootURL: URL
    private var cache: [String: SpriteAtlas] = [:]

    init(rootURL: URL) { self.rootURL = rootURL }

    func atlas(named name: String) throws -> SpriteAtlas {
        if let hit = cache[name] { return hit }
        guard let clip = CompanionController.clips[name] else {
            throw NSError(domain: "GboyCompanionNative", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Missing clip: \(name)"])
        }
        let fileManager = FileManager.default
        let baseURL = rootURL.appendingPathComponent(clip.sheetName)
        var atlasURL = baseURL
        if clip.sheetName.hasSuffix("_sheet.png") {
            let masteredName = clip.sheetName.replacingOccurrences(of: "_sheet.png", with: "_mastered_sheet.png")
            let masteredURL = rootURL.appendingPathComponent(masteredName)
            let extendedName = clip.sheetName.replacingOccurrences(of: "_sheet.png", with: "_extended_sheet.png")
            let extendedURL = rootURL.appendingPathComponent(extendedName)
            if fileManager.fileExists(atPath: masteredURL.path) {
                atlasURL = masteredURL
            } else if fileManager.fileExists(atPath: extendedURL.path) {
                atlasURL = extendedURL
            }
        }
        let atlas = try SpriteAtlas(url: atlasURL)
        cache[name] = atlas
        return atlas
    }
}

// MARK: - Sprite view

private final class SpriteView: NSView {
    var currentFrame: CGImage?
    var pixelSize: CGSize = CGSize(width: 32, height: 32)
    var scale: CGFloat = 1.9
    var flipped_h: Bool = false
    var shadowDepth: CGFloat = 0.5   // 0 = far/small shadow, 1 = close/large shadow

    var onDragStart:  ((NSEvent) -> Void)?
    var onDragMove:   ((NSEvent) -> Void)?
    var onDragEnd:    ((NSEvent) -> Void)?
    var onRightClick: (() -> Void)?
    var onDoubleClick:(() -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        activeRect.insetBy(dx: 6, dy: 4).contains(point) ? self : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let frame = currentFrame,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)

        // ── Ground shadow (depth-aware, 3 soft layers) ────────────
        let sd = min(max(shadowDepth, 0), 1)
        let sw = activeRect.width * (0.52 + sd * 0.18)
        let sh = sw * 0.13
        let sx = activeRect.midX - sw / 2
        // In flipped view coords, activeRect.maxY is the bottom of the sprite (feet)
        let sy = activeRect.maxY - sh * 0.6
        let baseAlpha = 0.08 + sd * 0.28
        ctx.saveGState()
        for i in 0..<4 {
            let expand = CGFloat(i) * 2.8
            let r = CGRect(x: sx - expand, y: sy - expand * 0.25,
                           width: sw + expand * 2, height: sh + expand * 0.5)
            let a = baseAlpha * (1.0 - CGFloat(i) * 0.25)
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: a))
            ctx.fillEllipse(in: r)
        }
        ctx.restoreGState()

        // ── Sprite ────────────────────────────────────────────────
        ctx.saveGState()
        let dr = CGRect(x: activeRect.origin.x,
                        y: bounds.height - activeRect.origin.y - activeRect.height,
                        width: activeRect.width, height: activeRect.height)
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(frame, in: dr)
        ctx.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onDoubleClick?() }
        else { onDragStart?(event) }
    }
    override func mouseDragged(with event: NSEvent) { onDragMove?(event) }
    override func mouseUp(with event: NSEvent) { onDragEnd?(event) }
    override func rightMouseDown(with event: NSEvent) { onRightClick?() }

    var activeRect: CGRect {
        let w = pixelSize.width * scale, h = pixelSize.height * scale
        return CGRect(x: (bounds.width - w) / 2, y: bounds.height - h - 6,
                      width: w, height: h)
    }
    var noteAnchor: CGPoint { CGPoint(x: activeRect.midX, y: activeRect.minY) }
}

// MARK: - Controller

final class CompanionController {
    var onChatRequested: (() -> Void)?

    // ── Window / display ───────────────────────────────────────
    static let windowSize = CGSize(width: 144, height: 136)
    static let gravity: CGFloat = -920

    // ── All animation clips ────────────────────────────────────
    static let clips: [String: AnimationClip] = [
        // Core movement
        "idle_front":        AnimationClip(sheetName: "idle_front_sheet.png",        fps: 6,  looping: true),
        "idle_back":         AnimationClip(sheetName: "idle_back_sheet.png",         fps: 6,  looping: true),
        "idle_left":         AnimationClip(sheetName: "idle_left_sheet.png",         fps: 6,  looping: true),
        "idle_right":        AnimationClip(sheetName: "idle_right_sheet.png",        fps: 6,  looping: true),
        "walk_front":        AnimationClip(sheetName: "walk_front_sheet.png",        fps: 10, looping: true),
        "walk_back":         AnimationClip(sheetName: "walk_back_sheet.png",         fps: 10, looping: true),
        "walk_left":         AnimationClip(sheetName: "walk_left_sheet.png",         fps: 10, looping: true),
        "walk_right":        AnimationClip(sheetName: "walk_right_sheet.png",        fps: 10, looping: true),
        "run_left":          AnimationClip(sheetName: "run_left_sheet.png",          fps: 14, looping: true),
        "run_right":         AnimationClip(sheetName: "run_right_sheet.png",         fps: 14, looping: true),
        "jump_side":         AnimationClip(sheetName: "jump_side_sheet.png",         fps: 10, looping: false),
        "sneak":             AnimationClip(sheetName: "sneak_sheet.png",             fps: 9,  looping: true),
        "skateboard":        AnimationClip(sheetName: "skateboard_sheet.png",        fps: 12, looping: true),
        // Look
        "look_left":         AnimationClip(sheetName: "look_left_sheet.png",         fps: 10, looping: false),
        "look_right":        AnimationClip(sheetName: "look_right_sheet.png",        fps: 10, looping: false),
        "look_up":           AnimationClip(sheetName: "look_up_sheet.png",           fps: 10, looping: false),
        "look_down":         AnimationClip(sheetName: "look_down_sheet.png",         fps: 10, looping: false),
        // Emotions
        "happy":             AnimationClip(sheetName: "happy_sheet.png",             fps: 9,  looping: true),
        "angry":             AnimationClip(sheetName: "angry_sheet.png",             fps: 9,  looping: true),
        "cry":               AnimationClip(sheetName: "cry_sheet.png",               fps: 8,  looping: true),
        "tongue":            AnimationClip(sheetName: "tongue_clean_sheet.png",      fps: 9,  looping: false),
        "confused":          AnimationClip(sheetName: "confused_sheet.png",          fps: 8,  looping: false),
        "bored":             AnimationClip(sheetName: "bored_sheet.png",             fps: 7,  looping: false),
        "wave":              AnimationClip(sheetName: "wave_sheet.png",              fps: 9,  looping: false),
        // Actions
        "eat":               AnimationClip(sheetName: "eat_sheet.png",               fps: 9,  looping: false),
        "sleep_lie":         AnimationClip(sheetName: "sleep_lie_sheet.png",         fps: 5,  looping: true),
        "cape_flutter":      AnimationClip(sheetName: "cape_flutter_sheet.png",      fps: 10, looping: false),
        "attack":            AnimationClip(sheetName: "attack_sheet.png",            fps: 10, looping: false),
        "laser":             AnimationClip(sheetName: "laser_sheet.png",             fps: 10, looping: false),
        "dash":              AnimationClip(sheetName: "dash_sheet.png",              fps: 12, looping: false),
        "drop":              AnimationClip(sheetName: "drop_sheet.png",              fps: 8,  looping: false),
        "fall":              AnimationClip(sheetName: "fall_sheet.png",              fps: 8,  looping: false),
        "hide":              AnimationClip(sheetName: "hide_sheet.png",              fps: 8,  looping: false),
        "stretch":           AnimationClip(sheetName: "stretch_sheet.png",           fps: 7,  looping: false),
        "yawn":              AnimationClip(sheetName: "yawn_sheet.png",              fps: 6,  looping: false),
        "stumble":           AnimationClip(sheetName: "stumble_sheet.png",           fps: 10, looping: false),
        "dance":             AnimationClip(sheetName: "dance_sheet.png",             fps: 10, looping: true),
        "headjack":          AnimationClip(sheetName: "headjack_sheet.png",          fps: 7,  looping: false),
        "blanket_nest":      AnimationClip(sheetName: "blanket_nest_sheet.png",      fps: 5,  looping: true),
        "glitch":            AnimationClip(sheetName: "glitch_sheet.png",            fps: 12, looping: false),
        "sit_cross":         AnimationClip(sheetName: "sit_cross_sheet.png",         fps: 6,  looping: true),
        "throne":            AnimationClip(sheetName: "throne_sheet.png",            fps: 6,  looping: true),
        "sleep_curl":        AnimationClip(sheetName: "sleep_curl_sheet.png",        fps: 5,  looping: true),
        "sleep_sit":         AnimationClip(sheetName: "sleep_sit_sheet.png",         fps: 5,  looping: true),
        // Climb / wall
        "climb_side":        AnimationClip(sheetName: "climb_side_clean_sheet.png",  fps: 9,  looping: true),
        "climb_right":       AnimationClip(sheetName: "climb_right_clean_sheet.png", fps: 9,  looping: true),
        "climb_back":        AnimationClip(sheetName: "climb_back_clean_sheet.png",  fps: 9,  looping: true),
        "wall_sit":          AnimationClip(sheetName: "wall_sit_clean_sheet.png",    fps: 6,  looping: true),
        "wallslide":         AnimationClip(sheetName: "wallslide_clean_sheet.png",   fps: 8,  looping: true),
        "peek_left":         AnimationClip(sheetName: "peek_left_clean_sheet.png",   fps: 8,  looping: false),
        "peek_right":        AnimationClip(sheetName: "peek_right_clean_sheet.png",  fps: 8,  looping: false),
        // Activities
        "computer_idle":     AnimationClip(sheetName: "computer_idle_backdesk_sheet.png", fps: 6,  looping: true),
        "terminal_type":     AnimationClip(sheetName: "terminal_type_backdesk_sheet.png", fps: 7,  looping: true),
        "tv_flip":           AnimationClip(sheetName: "tv_flip_backdesk_sheet.png",  fps: 5,  looping: true),
        "crt_watch":         AnimationClip(sheetName: "crt_watch_backdesk_sheet.png", fps: 5,  looping: true),
        "handheld_game":     AnimationClip(sheetName: "handheld_game_backdesk_sheet.png", fps: 6,  looping: true),
        "cook_meal":         AnimationClip(sheetName: "cook_meal_clean_sheet.png",   fps: 6,  looping: true),
        "noodle_eat":        AnimationClip(sheetName: "noodle_eat_clean_sheet.png",  fps: 7,  looping: true),
        "desk_noodles":      AnimationClip(sheetName: "desk_noodles_clean_sheet.png", fps: 7, looping: true),
        "radio_listen":      AnimationClip(sheetName: "radio_listen_backdesk_sheet.png", fps: 5,  looping: true),
        "evidence_hack":     AnimationClip(sheetName: "evidence_hack_backdesk_sheet.png", fps: 6,  looping: true),
        "desk_sketch":       AnimationClip(sheetName: "desk_sketch_clean_sheet.png", fps: 5,  looping: true),
        "file_sort":         AnimationClip(sheetName: "file_sort_clean_sheet.png",   fps: 5,  looping: true),
        "mug_sip":           AnimationClip(sheetName: "mug_sip_clean_sheet.png",     fps: 5,  looping: true),
        "file_scan":         AnimationClip(sheetName: "file_scan_clean_sheet.png",   fps: 5,  looping: true),
        "zine_read":         AnimationClip(sheetName: "zine_read_clean_sheet.png",   fps: 5,  looping: true),
        "pinboard_plot":     AnimationClip(sheetName: "pinboard_plot_clean_sheet.png", fps: 5, looping: true),
        "monitor_lurk":      AnimationClip(sheetName: "monitor_lurk_backdesk_sheet.png", fps: 5,  looping: true),
        "fridge_open":       AnimationClip(sheetName: "fridge_open_clean_sheet.png", fps: 8,  looping: false),
        // Surveillance
        "bug_sweep":         AnimationClip(sheetName: "bug_sweep_sheet.png",         fps: 7,  looping: true),
        // Special / rebellion
        "portal":            AnimationClip(sheetName: "portal_entry_smooth_sheet.png", fps: 9, looping: false),
        "vanish":            AnimationClip(sheetName: "smoke_burst_sheet.png",       fps: 12, looping: false),
        "smoke_burst":       AnimationClip(sheetName: "smoke_burst_sheet.png",       fps: 12, looping: false),
        "smoke_reform":      AnimationClip(sheetName: "smoke_reform_sheet.png",      fps: 12, looping: false),
        "smoke_drift":       AnimationClip(sheetName: "smoke_drift_sheet.png",       fps: 12, looping: false),
        "smoke_orbit":       AnimationClip(sheetName: "smoke_orbit_sheet.png",       fps: 12, looping: false),
        "psonic_charge":     AnimationClip(sheetName: "psonic_charge_sheet.png",     fps: 12, looping: false),
        "psonic_overload":   AnimationClip(sheetName: "psonic_overload_sheet.png",   fps: 12, looping: false),
        "graffiti_bloc":     AnimationClip(sheetName: "graffiti_bloc_clean_sheet.png",     fps: 8,  looping: false),
        "graffiti_was_here": AnimationClip(sheetName: "graffiti_was_here_clean_sheet.png", fps: 8,  looping: false),
        "spray_tag":         AnimationClip(sheetName: "spray_tag_sheet.png",         fps: 8,  looping: false),
        "sticker_slap":      AnimationClip(sheetName: "sticker_slap_sheet.png",      fps: 9,  looping: false),
        "question_lurk":     AnimationClip(sheetName: "question_lurk_backdesk_sheet.png", fps: 6,  looping: true),
        "question_type":     AnimationClip(sheetName: "question_type_backdesk_sheet.png", fps: 6,  looping: true),
        "dossier_check":     AnimationClip(sheetName: "dossier_check_sheet.png",     fps: 6,  looping: true),
        "signal_sweep":      AnimationClip(sheetName: "signal_sweep_clean_sheet.png", fps: 7, looping: true),
        "soccer_goal":       AnimationClip(sheetName: "soccer_goal_sheet.png",       fps: 10, looping: false),
        "portal_walk":       AnimationClip(sheetName: "portal_walk_sheet.png",       fps: 11, looping: false),
        "skyfall":           AnimationClip(sheetName: "skyfall_sheet.png",           fps: 12, looping: false),
        "landing_recover":   AnimationClip(sheetName: "landing_recover_sheet.png",   fps: 10, looping: false),
        // New 8-frame animations
        "spin":              AnimationClip(sheetName: "spin_sheet.png",              fps: 12, looping: false),
        "tantrum":           AnimationClip(sheetName: "tantrum_sheet.png",           fps: 10, looping: true),
        "float":             AnimationClip(sheetName: "float_sheet.png",             fps: 6,  looping: true),
        "shiver":            AnimationClip(sheetName: "shiver_sheet.png",            fps: 14, looping: true),
        "applaud":           AnimationClip(sheetName: "applaud_sheet.png",           fps: 10, looping: true),
        "dizzy":             AnimationClip(sheetName: "dizzy_sheet.png",             fps: 8,  looping: true),
        "bow":               AnimationClip(sheetName: "bow_clean_sheet.png",         fps: 8,  looping: false),
        "moonwalk":          AnimationClip(sheetName: "moonwalk_sheet.png",          fps: 10, looping: true),
        "backflip":          AnimationClip(sheetName: "backflip_sheet.png",          fps: 12, looping: false),
        "typing_fast":       AnimationClip(sheetName: "typing_fast_backdesk_sheet.png", fps: 10, looping: true),
        "phone_call":        AnimationClip(sheetName: "phone_call_backdesk_sheet.png", fps: 8,  looping: true),
        "terminal_trace":    AnimationClip(sheetName: "terminal_trace_backdesk_sheet.png", fps: 8, looping: true),
        "signal_decode":     AnimationClip(sheetName: "signal_decode_backdesk_sheet.png", fps: 7, looping: true),
        "shoulder_scan":     AnimationClip(sheetName: "shoulder_scan_backdesk_sheet.png", fps: 7, looping: true),
        "desk_doze":         AnimationClip(sheetName: "desk_doze_backdesk_sheet.png", fps: 5, looping: true),
        "umbrella":          AnimationClip(sheetName: "umbrella_sheet.png",          fps: 10, looping: true),
        "hood_peek":         AnimationClip(sheetName: "hood_peek_sheet.png",         fps: 7, looping: true),
        "side_eye":          AnimationClip(sheetName: "side_eye_sheet.png",          fps: 7, looping: true),
        "sulk":              AnimationClip(sheetName: "sulk_sheet.png",              fps: 6, looping: true),
        "proud_stance":      AnimationClip(sheetName: "proud_stance_sheet.png",      fps: 6, looping: true),
    ]

    // ── State ──────────────────────────────────────────────────
    private let spriteLibrary: SpriteLibrary
    private let window:      NSWindow
    private let spriteView = SpriteView(frame: NSRect(origin: .zero, size: windowSize))

    private var updateTimer:            Timer?
    private var behaviorTimer:          Timer?
    private var cursorTimer:            Timer?
    private var needsTimer:             Timer?
    private var actionTimer:            Timer?
    private var cursorSuppressionTimer: Timer?
    private var hourlyTimer:            Timer?
    private var startupTimer:           Timer?
    private var activityTimer:          Timer?
    private var portalSequenceTimers: [Timer] = []

    private var noteControllers: [NoteWindowController] = []
    private var activeBubbleController: NoteWindowController?
    private var blastPlayer: AVAudioPlayer?
    private var cursorSuppressed = false
    private var eventMonitors: [Any] = []
    private var workspaceObserver: NSObjectProtocol?

    private var currentAnimation  = "idle_front"
    private var currentAtlas:       SpriteAtlas?
    private var currentFrameIndex  = 0
    private var animationAccumulator: Double = 0
    private var lastUpdateTime     = Date()

    // Needs
    private var hunger:  CGFloat = 72
    private var social:  CGFloat = 68
    private var energy:  CGFloat = 74

    // Motion
    private var attachedSurface: Surface = .floor
    private var lastDirection    = "front"
    private var paused           = false
    private var dragging         = false
    private var flinging         = false
    private var actionLocked     = false
    private var movement         = CGVector.zero
    private var flingVelocity    = CGVector.zero
    private var dragOffset       = CGPoint.zero
    private var dragSamples: [CGPoint] = []
    private var pendingTeleport: CGPoint?
    private var currentAction    = ""

    // Timing
    private var quietUntil           = Date()
    private var speechCooldownUntil  = Date.distantPast
    private var noteCooldownUntil    = Date.distantPast
    private var lastBubbleText       = ""
    private var lastBubbleAt         = Date.distantPast
    private var lastIdleActivity     = ""
    private var consecutiveIdleCount = 0
    private var dragCount            = 0
    private var cursorHoverStart: Date?
    private var lastCursorPos        = CGPoint.zero
    private var nearEdgeSince: Date?
    private var lastUserActivity     = Date()
    private var lastWindowCount      = 0
    private var isCompanionHidden    = false
    private var pendingHideAfterAction = false
    private var pendingReappearAfterAction = false
    private var hiddenAnchorPoint    = CGPoint.zero
    private var floorDepth: CGFloat  = 0.0
    private var targetFloorDepth: CGFloat = 0.0
    private var idleActivityCycle: [String] = []
    private var hackerActivityCycle: [String] = []
    private var graffitiCycle: [String] = []
    private var sportActivityCycle: [String] = []
    private var wallActionCycle: [String] = []
    private var settleAnimationCycle: [String] = []
    private var sceneCycle: [String] = []
    private var smokePowerCycle: [String] = []
    private var pendingReappearMessage: String?

    // Grab-zone tracking
    private var grabHoverStart: Date?
    private var grabReactCooldown = Date.distantPast

    // Psonic charge escalation (0=basic, 1=charged, 2=mega)
    private var psonicChargeLevel = 0
    private var cursorDestroyCount = 0

    // ── Init ──────────────────────────────────────────────────

    init() throws {
        spriteLibrary = SpriteLibrary(rootURL: AssetLocator.spriteDirectory())

        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = false
        window.contentView = spriteView
        spriteView.scale = 1.9
        hiddenAnchorPoint = window.frame.origin

        try loadAnimation(named: currentAnimation)
        configureSpriteView()
        positionOnFloor()
        configureActivityTracking()
    }

    deinit {
        [updateTimer, behaviorTimer, cursorTimer, needsTimer,
         actionTimer, cursorSuppressionTimer, hourlyTimer, startupTimer, activityTimer].forEach { $0?.invalidate() }
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    // ── Launch ─────────────────────────────────────────────────

    func launch() {
        window.orderFrontRegardless()
        lastUpdateTime = Date()
        quietUntil           = Date().addingTimeInterval(3.0)
        speechCooldownUntil  = Date().addingTimeInterval(6.0)
        noteCooldownUntil    = Date().addingTimeInterval(12.0)

        updateTimer    = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in self?.tick() }
        behaviorTimer  = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true)  { [weak self] _ in self?.chooseBehavior() }
        cursorTimer    = Timer.scheduledTimer(withTimeInterval: 2.1, repeats: true)  { [weak self] _ in self?.reactToCursor() }
        needsTimer     = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true)  { [weak self] _ in self?.degradeNeeds() }
        hourlyTimer    = Timer.scheduledTimer(withTimeInterval: 420, repeats: true) { [weak self] _ in self?.hourlyCheck() }
        activityTimer  = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.pollDesktopActivity() }
        performStartupSequence()
    }

    // ── Smoke test ─────────────────────────────────────────────

    static func smokeTest() throws {
        let lib = SpriteLibrary(rootURL: AssetLocator.spriteDirectory())
        for key in clips.keys.sorted() { _ = try lib.atlas(named: key) }
        print("Loaded \(clips.count) animations from \(AssetLocator.spriteDirectory().path)")
    }

    // ── Public API (menu / status bar) ────────────────────────

    func feed() {
        hunger = min(100, hunger + 24)
        energy = min(100, energy + 5)
        startPose("eat", duration: 1.2, message: feedLine(), forceSpeech: true)
    }

    func comfort() {
        social = min(100, social + 18)
        if energy < 24 {
            energy = min(100, energy + 12)
            startPose("sleep_lie", duration: 1.6, message: "Settling.", forceSpeech: true)
        } else {
            let comfortAnimations = ["happy", "wave", "sit_cross"]
            startPose(comfortAnimations.randomElement() ?? "happy", duration: 1.2,
                      message: CompanionContent.speechBursts.randomElement() ?? "Fine.", forceSpeech: true)
        }
    }

    func togglePause() {
        paused.toggle()
        showBubble(paused ? "Signal paused." : "Signal restored.", force: true)
    }

    func spawnDesktopNote() {
        showSticky(CompanionContent.stickyNotes.randomElement() ?? "G304 WAS HERE",
                   at: randomDesktopPoint(), force: true)
    }

    func triggerGlitch() {
        startPose("glitch", duration: 0.7, message: crypticLine(), forceSpeech: true)
    }

    func play() {
        playCuratedScene(nextSceneName(forceAdvance: true))
    }

    func sleep() {
        energy = min(100, energy + 22)
        startPose(energy < 40 ? "sleep_lie" : "blanket_nest",
                  duration: energy < 40 ? 14.0 : 11.0,
                  message: "Power-down sequence.", forceSpeech: true)
    }

    func applyAIResponse(_ response: CompanionLLMResponse, preferredScene: String?) {
        hunger = min(100, max(0, hunger + CGFloat(response.hungerDelta ?? 0)))
        social = min(100, max(0, social + CGFloat(response.socialDelta ?? 0)))
        energy = min(100, max(0, energy + CGFloat(response.energyDelta ?? 0)))

        cancelPortalSequence()
        startupTimer?.invalidate()
        actionTimer?.invalidate()
        movement = .zero
        pendingTeleport = nil
        pendingHideAfterAction = false
        pendingReappearAfterAction = false
        consecutiveIdleCount = 0

        let normalizedScene = preferredScene?
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        if isCompanionHidden {
            reappearFromSmoke(reason: response.reply)
            return
        }

        if let scene = normalizedScene, !scene.isEmpty {
            quietUntil = Date().addingTimeInterval(0.9)
            switch scene {
            case "laser", "psonic_charge":
                firePsonicBlast(at: NSEvent.mouseLocation)
            case "charged_blast", "chargedblast", "psonic_overload":
                fireChargedBlast(at: NSEvent.mouseLocation, level: 1)
            case "destroy_cursor", "destroycursor":
                destroyCursorSequence(at: NSEvent.mouseLocation)
            default:
                if curatedSceneNames().contains(scene) {
                    playCuratedScene(scene)
                } else if Self.clips[scene] != nil {
                    lastIdleActivity = scene
                    startPose(scene,
                              duration: chatSceneDuration(for: scene),
                              message: nil,
                              forceSpeech: false)
                }
            }
        }

        showBubble(response.reply, force: true)
    }

    private func chatSceneDuration(for scene: String) -> TimeInterval {
        switch scene {
        case "wave", "happy", "applaud", "confused", "tongue", "headjack", "glitch", "angry", "attack":
            return 2.4
        case "shoulder_scan", "question_lurk", "question_type", "monitor_lurk", "terminal_trace", "signal_decode", "terminal_type":
            return 5.8
        case "psonic_charge":
            return 2.0
        default:
            return (Self.clips[scene]?.looping ?? false) ? 6.6 : 2.2
        }
    }

    func triggerScene(_ key: String) {
        moveToFloorIfNeeded()
        let normalized = key
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")

        switch normalized {
        case "walk":
            startWalk(left: Bool.random(), duration: Double.random(in: 1.8...3.0), targetDepth: randomFloorDepth(), message: "Patrol route.")
        case "run":
            startRun(left: Bool.random(), duration: Double.random(in: 1.3...2.2), targetDepth: randomFloorDepth(), message: "Quick lane.")
        case "skate":
            startSkate(left: Bool.random(), duration: Double.random(in: 2.0...3.2), targetDepth: randomFloorDepth(), message: "Skate line.")
        case "jump":
            startPose("jump_side", duration: 1.1, message: "Hop.")
        case "soccer", "goal", "soccer_goal":
            startPose("soccer_goal", duration: 2.3, message: "Goal posted. Surveillance distracted.")
        case "dance":
            startPose("dance", duration: 4.0, message: expressiveLine())
        case "moonwalk":
            startPose("moonwalk", duration: 3.2, message: expressiveLine())
        case "backflip":
            startPose("backflip", duration: 1.6, message: expressiveLine())
        case "spin":
            startPose("spin", duration: 1.3, message: expressiveLine())
        case "wave":
            startPose("wave", duration: 1.4, message: waveLine(), forceSpeech: true)
        case "tongue":
            startPose("tongue", duration: 0.9, message: cursorLine())
        case "angry":
            startPose("angry", duration: 1.2, message: aggressionLine(), forceSpeech: true)
        case "attack":
            startPose("attack", duration: 0.9, message: aggressionLine(), forceSpeech: true)
        case "laser":
            firePsonicBlast(at: NSEvent.mouseLocation)
        case "chargedblast":
            fireChargedBlast(at: NSEvent.mouseLocation, level: 1)
        case "destroycursor":
            destroyCursorSequence(at: NSEvent.mouseLocation)
        case "headjack":
            startPose("headjack", duration: 1.2, message: "Borrowing the signal.")
        case "glitch":
            startPose("glitch", duration: 1.0, message: crypticLine())
        case "terminaltrace":
            startPose("terminal_trace", duration: 9.0, message: "Tracing the signal path.")
        case "signaldecode":
            startPose("signal_decode", duration: 8.5, message: "Decoding the transmission.")
        case "shoulderscan":
            startPose("shoulder_scan", duration: 7.5, message: "Checking the room behind me.")
        case "deskdoze":
            startPose("desk_doze", duration: 10.0, message: "Falling asleep in the monitor glow.")
        case "sleepcurl":
            startPose("sleep_curl", duration: 12.0, message: "Curling into the static.")
        case "sleepsit":
            startPose("sleep_sit", duration: 10.0, message: "Dozing upright.")
        case "hoodpeek":
            startPose("hood_peek", duration: 2.8, message: suspiciousLine())
        case "sideeye":
            startPose("side_eye", duration: 2.8, message: suspiciousLine())
        case "sulk":
            startPose("sulk", duration: 3.0, message: boredLine())
        case "proudstance":
            startPose("proud_stance", duration: 3.0, message: victoryLine())
        case "hacksession":
            startHackerActivity()
        case "spyrun":
            playCuratedScene(nextSceneName(forceAdvance: true, preferred: ["monitor_lurk", "question_lurk", "signal_sweep", "bug_sweep", "peek_left", "peek_right"]))
        case "graffiti":
            doGraffitiAction()
        case "cook":
            startPose("cook_meal", duration: 12.0, message: "Kitchen op online.")
        case "signal":
            startPose("signal_sweep", duration: 8.0, message: "Signal quality questionable.")
        case "hide":
            startPose("hide", duration: 6.0, message: "Off the visible channels.")
        case "portal":
            startTeleport(animation: "portal", message: "Mindverse route.")
        case "happy":
            startPose("happy", duration: 2.0, message: victoryLine())
        case "confused":
            startPose("confused", duration: 1.2, message: confusedLine())
        case "bored":
            startPose("bored", duration: 1.8, message: boredLine())
        case "cry":
            startPose("cry", duration: 2.0, message: "The signal dipped.")
        case "float":
            startPose("float", duration: 4.0, message: crypticLine())
        case "shiver":
            startPose("shiver", duration: 2.2, message: "Bad frequency.")
        case "dizzy":
            startPose("dizzy", duration: 2.4, message: "Display drift.")
        case "yawn":
            startPose("yawn", duration: 1.5, message: "Battery warning.")
        case "tantrum":
            startPose("tantrum", duration: 3.0, message: "Compliance rejected.")
        case "cape":
            startPose("cape_flutter", duration: 1.2, message: "Flag check.")
        case "applaud":
            startPose("applaud", duration: 2.6, message: "Acceptable performance.")
        case "bow":
            startPose("bow", duration: 1.6, message: "Acknowledged.")
        case "phone", "phonecall":
            startPose("phone_call", duration: 4.0, message: "Line secured.")
        case "umbrella":
            startPose("umbrella", duration: 4.0, message: "Weather protocol.")
        case "vanish":
            disappearIntoSmoke(reason: "Blackout.")
        case "capeglitch":
            startPose("glitch", duration: 1.0, message: "Cape static.")
        default:
            if curatedSceneNames().contains(normalized) {
                playCuratedScene(normalized)
                return
            }
            if Self.clips[normalized] != nil {
                playRegisteredClip(normalized)
                return
            }
            play()
        }
    }

    private func playRegisteredClip(_ name: String) {
        if curatedSceneNames().contains(name) {
            playCuratedScene(name)
            return
        }

        switch name {
        case "idle_front", "idle_back", "idle_left", "idle_right",
             "look_left", "look_right", "look_up", "look_down",
             "dash", "drop", "fall", "eat", "sleep_lie",
             "portal_walk", "skyfall", "landing_recover":
            moveToFloorIfNeeded()
            startPose(name,
                      duration: menuSceneDuration(for: name),
                      message: menuMessage(for: name),
                      forceSpeech: false)
        case "walk_left":
            startWalk(left: true, duration: 2.3, targetDepth: randomFloorDepth(), message: "Left route.")
        case "walk_right":
            startWalk(left: false, duration: 2.3, targetDepth: randomFloorDepth(), message: "Right route.")
        case "run_left":
            startRun(left: true, duration: 1.7, targetDepth: randomFloorDepth(), message: "Sprint left.")
        case "run_right":
            startRun(left: false, duration: 1.7, targetDepth: randomFloorDepth(), message: "Sprint right.")
        case "walk_front", "walk_back":
            moveToFloorIfNeeded()
            startPose(name, duration: 2.4, message: "Depth shift.")
        case "climb_side":
            attach(to: .right)
            startClimb(surface: .right, down: Bool.random(), duration: 3.1)
        case "climb_right":
            attach(to: .left)
            startClimb(surface: .left, down: Bool.random(), duration: 3.1)
        case "climb_back":
            attach(to: .top)
            startClimb(surface: .top, down: Bool.random(), duration: 3.1)
        case "wall_sit", "wallslide", "peek_left":
            attach(to: .right)
            startPose(name, duration: menuSceneDuration(for: name), message: edgeLine())
        case "peek_right":
            attach(to: .left)
            startPose(name, duration: menuSceneDuration(for: name), message: edgeLine())
        case "laser":
            firePsonicBlast(at: NSEvent.mouseLocation)
        case "portal":
            performPortalTraversal(message: "Mindverse route.")
        case "vanish":
            disappearIntoSmoke(reason: "Blackout.")
        default:
            moveToFloorIfNeeded()
            startPose(name,
                      duration: menuSceneDuration(for: name),
                      message: menuMessage(for: name),
                      forceSpeech: false)
        }
    }

    private func menuSceneDuration(for name: String) -> TimeInterval {
        switch name {
        case "look_left", "look_right", "look_up", "look_down":
            return 1.0
        case "idle_front", "idle_back", "idle_left", "idle_right":
            return 3.2
        case "dash", "drop", "fall", "jump_side", "stumble", "bow", "wave", "tongue",
             "headjack", "glitch", "smoke_burst", "smoke_reform", "smoke_drift", "smoke_orbit",
             "portal_walk", "skyfall", "landing_recover", "attack", "laser", "cape_flutter":
            return 1.8
        case "sleep_lie", "sleep_curl", "sleep_sit", "blanket_nest", "sit_cross", "throne",
             "computer_idle", "terminal_type", "question_type", "question_lurk", "monitor_lurk",
             "evidence_hack", "file_scan", "file_sort", "desk_sketch", "desk_doze", "dossier_check",
             "signal_sweep", "bug_sweep", "crt_watch", "tv_flip", "handheld_game", "radio_listen",
             "zine_read", "typing_fast", "terminal_trace", "signal_decode", "shoulder_scan",
             "noodle_eat", "desk_noodles", "cook_meal", "mug_sip", "phone_call", "umbrella":
            return 8.8
        default:
            return (Self.clips[name]?.looping ?? false) ? 5.8 : 2.2
        }
    }

    private func menuMessage(for name: String) -> String? {
        switch name {
        case "eat":
            return feedLine()
        case "sleep_lie":
            return "Power-down sequence."
        case "portal_walk":
            return "Portal approach."
        case "skyfall":
            return "Airspace breach."
        case "landing_recover":
            return "Recovered the landing."
        case "dash":
            return "Quick cut."
        case "drop":
            return "Dropping."
        case "fall":
            return "Falling through the static."
        case "look_left", "look_right", "look_up", "look_down":
            return "Tracking movement."
        default:
            return nil
        }
    }

    private func configureActivityTracking() {
        let activityMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .keyDown]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: activityMask, handler: { [weak self] _ in
            self?.registerUserActivity(reason: "global-event")
        }) {
            eventMonitors.append(monitor)
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerUserActivity(reason: "app-switch")
        }

        lastWindowCount = visibleDesktopWindowCount()
        lastUserActivity = Date()
    }

    private func performStartupSequence() {
        cancelPortalSequence()
        startupTimer?.invalidate()
        actionTimer?.invalidate()
        movement = .zero
        actionLocked = true
        currentAction = "portal"
        isCompanionHidden = false
        window.alphaValue = 1
        window.orderFrontRegardless()
        playAnimation("portal")

        startupTimer = Timer.scheduledTimer(withTimeInterval: 1.45, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.startupTimer = nil
            self.startPose("wave", duration: 1.6, message: self.launchLine(), forceSpeech: true)
        }
    }

    private func cancelPortalSequence() {
        portalSequenceTimers.forEach { $0.invalidate() }
        portalSequenceTimers.removeAll()
    }

    private func schedulePortalTimer(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] timer in
            self?.portalSequenceTimers.removeAll { $0 === timer }
            block()
        }
        portalSequenceTimers.append(timer)
    }

    private func performPortalTraversal(message: String? = nil, forceSpeech: Bool = false) {
        cancelPortalSequence()
        startupTimer?.invalidate()
        actionTimer?.invalidate()
        moveToFloorIfNeeded()
        actionLocked = true
        currentAction = "portal_walk"
        movement = .zero
        playAnimation("portal_walk")
        if let message {
            showBubble(message, force: forceSpeech)
        }

        schedulePortalTimer(after: 1.4) { [weak self] in
            self?.beginPortalSkyfall()
        }
    }

    private func beginPortalSkyfall() {
        guard !paused else { return }
        let vis = activeScreenFrame
        let landingDepth = randomFloorDepth()
        floorDepth = landingDepth
        targetFloorDepth = landingDepth
        applyFloorDepthVisuals()

        let startX = min(max(window.frame.origin.x + CGFloat.random(in: -40...40),
                             vis.minX),
                         vis.maxX - window.frame.width)
        let startY = vis.maxY - window.frame.height - 6
        let landingY = floorY(for: landingDepth, in: vis)
        window.setFrameOrigin(CGPoint(x: startX, y: startY))
        attachedSurface = .floor
        lastDirection = Bool.random() ? "left" : "right"
        actionLocked = true
        currentAction = "skyfall"
        movement = CGVector(dx: CGFloat.random(in: -12...12), dy: (landingY - startY) / 1.3)
        playAnimation("skyfall")

        schedulePortalTimer(after: 1.3) { [weak self] in
            self?.beginPortalLandingRecover()
        }
    }

    private func beginPortalLandingRecover() {
        guard !paused else { return }
        let vis = activeScreenFrame
        let landingY = floorY(for: floorDepth, in: vis)
        movement = .zero
        window.setFrameOrigin(CGPoint(x: window.frame.origin.x, y: landingY))
        actionLocked = true
        currentAction = "landing_recover"
        playAnimation("landing_recover")
        setActionTimer(1.45)
    }

    private func registerUserActivity(reason _: String) {
        lastUserActivity = Date()
        if isCompanionHidden {
            reappearFromSmoke(reason: "Signal detected.")
        }
    }

    private func pollDesktopActivity() {
        let visibleWindows = visibleDesktopWindowCount()
        if visibleWindows > lastWindowCount {
            registerUserActivity(reason: "window-opened")
        }
        lastWindowCount = visibleWindows

        guard !paused, !isCompanionHidden, !actionLocked, !dragging, !flinging else { return }
        if Date().timeIntervalSince(lastUserActivity) > 14, Int.random(in: 0..<100) < 34 {
            disappearIntoSmoke(reason: "Going off-grid.")
        }
    }

    private func visibleDesktopWindowCount() -> Int {
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return raw.filter { info in
            let ownerPID = (info[kCGWindowOwnerPID as String] as? pid_t) ?? 0
            let layer = (info[kCGWindowLayer as String] as? Int) ?? 0
            let alpha = (info[kCGWindowAlpha as String] as? Double) ?? 1
            return ownerPID != ownPID && layer == 0 && alpha > 0.01
        }.count
    }

    private func disappearIntoSmoke(reason: String?) {
        guard !paused, !isCompanionHidden, !pendingHideAfterAction else { return }
        guard !dragging, !flinging else { return }

        cancelPortalSequence()
        startupTimer?.invalidate()
        actionTimer?.invalidate()
        pendingHideAfterAction = true
        pendingReappearAfterAction = false
        pendingReappearMessage = nil
        hiddenAnchorPoint = window.frame.origin
        actionLocked = true
        let smokeAnimation = nextCycledName(from: ["smoke_burst", "smoke_drift", "smoke_orbit", "vanish"],
                                            cycle: &smokePowerCycle,
                                            avoiding: currentAnimation)
        currentAction = smokeAnimation
        if smokeAnimation == "smoke_drift" {
            movement = floorMovementVector(horizontalSpeed: Bool.random() ? -78 : 78, targetDepth: randomFloorDepth())
        } else {
            movement = .zero
        }
        playAnimation(smokeAnimation)
        if let reason {
            showBubble(reason)
        }
        setActionTimer(smokeAnimation == "smoke_drift" ? 1.55 : 1.28)
    }

    private func reappearFromSmoke(reason: String) {
        guard !paused else { return }
        guard isCompanionHidden || pendingHideAfterAction else { return }

        cancelPortalSequence()
        startupTimer?.invalidate()
        actionTimer?.invalidate()
        pendingHideAfterAction = false
        pendingReappearAfterAction = true
        pendingReappearMessage = reason
        isCompanionHidden = false

        let cursor = NSEvent.mouseLocation
        let vis = NSScreen.screens.first(where: { $0.frame.contains(cursor) })?.visibleFrame ?? activeScreenFrame
        floorDepth = floorDepthForCursor(cursor)
        targetFloorDepth = floorDepth
        applyFloorDepthVisuals()

        let anchorX = min(max(cursor.x - Self.windowSize.width / 2 + CGFloat.random(in: -90...90),
                              vis.minX),
                          vis.maxX - window.frame.width)
        let anchorY = floorY(for: floorDepth, in: vis)
        hiddenAnchorPoint = CGPoint(x: anchorX, y: anchorY)
        window.setFrameOrigin(hiddenAnchorPoint)
        window.alphaValue = 1
        window.orderFrontRegardless()
        attachedSurface = .floor
        actionLocked = true
        let smokeAnimation = nextCycledName(from: ["smoke_reform", "smoke_orbit", "smoke_burst"],
                                            cycle: &smokePowerCycle,
                                            avoiding: currentAnimation)
        currentAction = smokeAnimation
        movement = .zero
        playAnimation(smokeAnimation)
        setActionTimer(smokeAnimation == "smoke_burst" ? 1.18 : 1.3)
    }

    // ── Configure sprite view ──────────────────────────────────

    private func configureSpriteView() {
        spriteView.wantsLayer = true
        spriteView.layer?.backgroundColor = NSColor.clear.cgColor
        spriteView.onDragStart   = { [weak self] e in self?.beginDrag(event: e) }
        spriteView.onDragMove    = { [weak self] e in self?.continueDrag(event: e) }
        spriteView.onDragEnd     = { [weak self] e in self?.endDrag(event: e) }
        spriteView.onRightClick  = { [weak self] in self?.onRightClick() }
        spriteView.onDoubleClick = { [weak self] in self?.onDoubleClick() }
    }

    // ── Tick (60 fps update) ──────────────────────────────────

    private func tick() {
        guard !paused else { return }
        guard !isCompanionHidden else { return }
        let now   = Date()
        let delta = min(0.05, now.timeIntervalSince(lastUpdateTime))
        lastUpdateTime = now

        advanceAnimation(by: delta)
        guard !dragging else { return }
        if flinging { updateFling(delta: delta); return }
        if movement != .zero {
            let next = CGPoint(x: window.frame.origin.x + movement.dx * delta,
                               y: window.frame.origin.y + movement.dy * delta)
            window.setFrameOrigin(clamp(point: next))
            handleSurfaceEdges()
        }
        if !actionLocked && movement == .zero {
            updateMouseLook()
            checkGrabZone()
        }
    }

    private func advanceAnimation(by delta: TimeInterval) {
        guard let atlas = currentAtlas, let clip = Self.clips[currentAnimation] else { return }
        animationAccumulator += delta
        let fd = 1.0 / clip.fps
        while animationAccumulator >= fd {
            animationAccumulator -= fd
            currentFrameIndex += 1
            if currentFrameIndex >= atlas.frameCount {
                currentFrameIndex = clip.looping ? 0 : max(0, atlas.frameCount - 1)
            }
        }
        spriteView.pixelSize = atlas.frameSize
        spriteView.currentFrame = atlas.frame(at: currentFrameIndex)
        spriteView.needsDisplay = true
    }

    private func floorDepthYRange(in vis: CGRect) -> ClosedRange<CGFloat> {
        let upper = min(vis.maxY - window.frame.height - 12, vis.minY + 72)
        return vis.minY...max(vis.minY, upper)
    }

    private func floorY(for depth: CGFloat, in vis: CGRect) -> CGFloat {
        let range = floorDepthYRange(in: vis)
        return range.lowerBound + (range.upperBound - range.lowerBound) * min(max(depth, 0), 1)
    }

    private func depthForFloorY(_ y: CGFloat, in vis: CGRect) -> CGFloat {
        let range = floorDepthYRange(in: vis)
        let span = max(1, range.upperBound - range.lowerBound)
        return min(max((y - range.lowerBound) / span, 0), 1)
    }

    private func depthScale(for depth: CGFloat) -> CGFloat {
        let clamped = min(max(depth, 0), 1)
        return 1.9 - clamped * 0.55
    }

    private func applyFloorDepthVisuals() {
        spriteView.scale = depthScale(for: floorDepth)
        // shadow is fullest when close (depth 0), fades when far (depth 1)
        spriteView.shadowDepth = 1.0 - floorDepth
        spriteView.needsDisplay = true
    }

    private func randomFloorDepth() -> CGFloat {
        let depths: [CGFloat] = [0.0, 0.12, 0.24, 0.38, 0.52, 0.68, 0.82]
        return depths.randomElement() ?? 0.0
    }

    private func floorDepthForCursor(_ cursor: CGPoint) -> CGFloat {
        let vis = NSScreen.screens.first(where: { $0.frame.contains(cursor) })?.visibleFrame ?? activeScreenFrame
        let bandHeight = max(140, vis.height * 0.32)
        let normalized = (cursor.y - vis.minY) / bandHeight
        return min(max(normalized, 0), 1)
    }

    private func floorMovementVector(horizontalSpeed: CGFloat, targetDepth: CGFloat?) -> CGVector {
        let vis = activeScreenFrame
        let resolvedDepth = min(max(targetDepth ?? floorDepth, 0), 1)
        targetFloorDepth = resolvedDepth
        let targetY = floorY(for: resolvedDepth, in: vis)
        let travelDuration = max(0.85, min(2.1, TimeInterval(180.0 / max(90.0, Double(abs(horizontalSpeed))))))
        let verticalSpeed = (targetY - window.frame.origin.y) / CGFloat(travelDuration)
        return CGVector(dx: horizontalSpeed, dy: verticalSpeed)
    }

    private func updateMouseLook() {
        guard !isCompanionHidden else { return }
        // Allow tracking even during light movement, not just fully idle
        guard currentAction.isEmpty || currentAction.hasPrefix("walk_") || currentAction.hasPrefix("run_") else { return }

        let cursor = NSEvent.mouseLocation
        let vis = activeScreenFrame
        guard vis.contains(cursor) else {
            if currentAnimation.hasPrefix("look_") { updateDefaultAnimation() }
            return
        }

        // Head sits at ~72% up the window height in screen coords
        let head = CGPoint(x: window.frame.midX,
                           y: window.frame.minY + window.frame.height * 0.72)
        let dx = cursor.x - head.x
        let dy = cursor.y - head.y
        let dist = hypot(dx, dy)

        // Three distance tiers with different behaviours
        let maxDist: CGFloat = currentAction.isEmpty ? 360 : 180
        guard dist < maxDist else {
            if currentAnimation.hasPrefix("look_") { updateDefaultAnimation() }
            return
        }

        // Only update look direction when not doing movement animations
        guard currentAction.isEmpty else { return }

        // Prefer horizontal when cursor is mostly sideways, use 1.0 ratio for 45° split
        let animation: String
        let angle = atan2(dy, dx)            // −π…π, 0 = right
        let deg = angle * 180 / .pi

        if deg > -135 && deg < -45 {
            animation = "look_down"          // cursor below
        } else if deg > 45 && deg < 135 {
            animation = "look_up"            // cursor above
        } else if dx < 0 {
            animation = "look_left"
        } else {
            animation = "look_right"
        }

        if currentAnimation != animation {
            playAnimation(animation)
        }
    }

    // ── Needs degradation ─────────────────────────────────────

    private func degradeNeeds() {
        guard !paused else { return }
        let activeAnimation = currentAction.isEmpty ? currentAnimation : currentAction

        if activeAnimation == "sleep_lie" {
            hunger = max(0, hunger - 0.12)
            social = min(100, social + 0.18)
            energy = min(100, energy + 2.6)
        } else if isFoodRecoveryAnimation(activeAnimation) {
            hunger = min(100, hunger + 2.0)
            social = min(100, social + 0.12)
            energy = min(100, energy + 0.18)
        } else if isLargeIdleActivity(activeAnimation) {
            hunger = max(0, hunger - 0.22)
            social = min(100, social + 0.55)
            energy = min(100, energy + 0.38)
        } else {
            hunger = max(0, hunger - 0.72)
            social = max(0, social - 0.42)
            energy = max(0, energy - 0.34)
        }

        if !actionLocked && !dragging && !flinging { updateDefaultAnimation() }
    }

    // ── Hourly mood check ─────────────────────────────────────

    private func hourlyCheck() {
        guard !paused, !actionLocked, !isCompanionHidden else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 5 {
            // Late night cryptic energy
            showBubble(nightLine(), force: true)
            if Bool.random() { startTeleport(animation: "portal", message: nil) }
        } else if hour >= 6 && hour < 9 {
            showBubble("Another cycle begins.", force: true)
            startPose("stretch", duration: 1.4, message: nil)
        } else {
            if Bool.random() { showBubble(CompanionContent.speechBursts.randomElement() ?? ".", force: false) }
        }
    }

    // ── Behavior chooser ─────────────────────────────────────

    private func chooseBehavior() {
        guard !paused, !actionLocked, !dragging, !flinging, !isCompanionHidden else { return }
        guard Date() >= quietUntil else { return }

        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 22 || hour < 5

        // Urgent needs override everything
        if energy < 24 {
            startEnergyRecoveryActivity()
            return
        }
        if hunger < 14 {
            startFoodRecoveryActivity()
            return
        }
        if social < 12 {
            startSocialRecoveryActivity()
            return
        }

        switch attachedSurface {
        case .floor: chooseBehaviorFloor(isNight: isNight)
        case .left:  chooseBehaviorWall(.left)
        case .right: chooseBehaviorWall(.right)
        case .top:   chooseBehaviorCeiling()
        }
    }

    private func chooseBehaviorFloor(isNight: Bool) {
        consecutiveIdleCount += 1
        let roll = Double.random(in: 0...1)

        // After too many idles in a row, force movement
        if consecutiveIdleCount > 5 {
            consecutiveIdleCount = 0
            patrolFloor(run: Bool.random())
            return
        }

        // Night mode: more cryptic, sneaky behaviors
        if isNight {
            if roll < 0.14 { startPose("sneak", duration: Double.random(in: 2.4...4.8), message: nightLine()) }
            else if roll < 0.26 { patrolFloor(run: true) }
            else if roll < 0.35 { startSportActivity(nightMode: true) }
            else if roll < 0.48 { startHackerActivity() }
            else if roll < 0.60 { playCuratedScene(nextSceneName(forceAdvance: true, preferred: ["question_lurk", "question_type", "signal_sweep", "bug_sweep", "monitor_lurk", "typing_fast", "portal", "glitch"])) }
            else if roll < 0.74 { startIdleActivity() }
            else if roll < 0.83 { doGraffitiAction() }
            else if roll < 0.92 { disappearIntoSmoke(reason: crypticLine()) }
            else { startPose("glitch", duration: Double.random(in: 0.8...1.3), message: crypticLine()) }
            return
        }

        // Day mode: varied, fun
        if roll < 0.10 {
            settleWithIdleFlair(duration: Double.random(in: 2...5))
        } else if roll < 0.25 {
            patrolFloor(run: Int.random(in: 0..<100) < 30)
        } else if roll < 0.34 {
            startSportActivity(nightMode: false)
        } else if roll < 0.48 {
            startHackerActivity()
        } else if roll < 0.58 {
            playCuratedScene(nextSceneName(forceAdvance: true))
        } else if roll < 0.72 {
            startIdleActivity()
        } else if roll < 0.77 {
            startPose("stretch", duration: 1.6, message: "Decompressing frame buffer.")
        } else if roll < 0.81 {
            startPose("confused", duration: 1.0, message: confusedLine())
        } else if roll < 0.85 {
            startPose("bored", duration: 1.4, message: boredLine())
        } else if roll < 0.89 {
            startPose("cape_flutter", duration: 1.0, message: "Red flag. Literally.")
        } else if roll < 0.93 {
            let expressive = ["dance", "jump_side", "moonwalk", "backflip", "spin", "applaud", "bow"]
            let pick = nextCycledName(from: expressive, cycle: &sportActivityCycle, avoiding: lastIdleActivity)
            let duration: Double
            switch pick {
            case "dance":    duration = Double.random(in: 3...6)
            case "moonwalk": duration = Double.random(in: 2...4)
            case "applaud":  duration = Double.random(in: 1.5...3)
            default:         duration = Double.random(in: 0.8...1.4)
            }
            lastIdleActivity = pick
            startPose(pick, duration: duration, message: expressiveLine())
        } else if roll < 0.97 {
            doGraffitiAction()
        } else if roll < 0.989 {
            startPose(Bool.random() ? "sit_cross" : "throne", duration: Double.random(in: 5...10), message: sitLine())
        } else if roll < 0.996 {
            disappearIntoSmoke(reason: "Smoke break.")
        } else {
            startTeleport(animation: "vanish", message: "Smoke break.")
        }
    }

    private func chooseBehaviorWall(_ surface: Surface) {
        let roll = Int.random(in: 0..<100)
        if roll < 68 {
            let names = surface == .left
                ? ["wall_sit", "wallslide", "peek_right"]
                : ["wall_sit", "wallslide", "peek_left"]
            let next = nextCycledName(from: names, cycle: &wallActionCycle, avoiding: lastIdleActivity)
            lastIdleActivity = next
            let message = next == "wallslide"
                ? (Int.random(in: 0..<4) == 0 ? "Surface sweep." : nil)
                : (Int.random(in: 0..<3) == 0 ? edgeLine() : nil)
            let duration: Double
            if next == "wallslide" { duration = Double.random(in: 2.0...3.4) }
            else if next.hasPrefix("peek_") { duration = Double.random(in: 1.5...2.6) }
            else { duration = Double.random(in: 3.0...5.6) }
            startPose(next, duration: duration, message: message)
        } else if roll < 86 {
            startClimb(surface: surface, down: Bool.random())
        } else {
            dropFromSurface()
        }
    }

    private func chooseBehaviorCeiling() {
        let roll = Int.random(in: 0..<100)
        if roll < 50 {
            settleWithIdleFlair(duration: Double.random(in: 2...5))
        } else if roll < 70 {
            startClimb(surface: .top, down: Bool.random())
        } else if roll < 85 {
            showBubble(edgeLine())
        } else {
            dropFromSurface()
        }
    }

    private func startEnergyRecoveryActivity() {
        moveToFloorIfNeeded()

        if energy < 14 {
            startPose("sleep_lie", duration: Double.random(in: 12...22), message: "Power down required.")
            return
        }

        let pool: [(name: String, dur: ClosedRange<Double>, msg: String?)] = [
            ("sleep_lie",    10...18, "Need a little shutdown time."),
            ("blanket_nest", 10...18, "Building a nest."),
            ("sleep_curl",   10...18, "Curling into the static."),
            ("sleep_sit",     8...14, "Sleeping light."),
            ("desk_doze",     8...14, "Screen glow nap."),
            ("yawn",          2...4,  "Battery warning."),
            ("crt_watch",    10...18, "Low-power mode."),
            ("radio_listen", 10...18, "Keeping it quiet."),
            ("sit_cross",     8...12, "Holding still for a minute."),
        ]
        if let pick = pool.randomElement() {
            startPose(pick.name, duration: Double.random(in: pick.dur), message: pick.msg)
        }
    }

    private func startFoodRecoveryActivity() {
        moveToFloorIfNeeded()

        let pool: [(name: String, dur: ClosedRange<Double>, msg: String?)] = [
            ("eat",          2.5...4.0, "Need fuel."),
            ("fridge_open",  5.0...8.0, "Snack recon."),
            ("cook_meal",   10.0...18.0, "Need to actually eat."),
            ("noodle_eat",  10.0...16.0, "Emergency noodles."),
            ("desk_noodles", 12.0...20.0, "Noodles fix most things."),
            ("mug_sip",      8.0...14.0, "Warm drink. Reset."),
            ("stumble",      2.0...3.5, "Need food before I glitch."),
        ]
        if let pick = pool.randomElement() {
            startPose(pick.name, duration: Double.random(in: pick.dur), message: pick.msg)
        }
    }

    private func startSocialRecoveryActivity() {
        moveToFloorIfNeeded()

        if social < 5, energy > 18, Int.random(in: 0..<4) == 0 {
            startPose("cry", duration: 2.0, message: "Need a little signal back.")
            return
        }

        let pool: [(name: String, dur: ClosedRange<Double>, msg: String?)] = [
            ("radio_listen",  12...20, "Need some company in the static."),
            ("handheld_game", 10...18, "Resetting the brain noise."),
            ("zine_read",     12...20, "Reading something rebellious."),
            ("monitor_lurk",  14...24, "Keeping watch."),
            ("computer_idle", 14...24, "Occupying the mind."),
            ("sit_cross",      8...12, sitLine()),
            ("throne",         8...14, "Holding court."),
            ("dance",          5...9,  "Refusing to mope quietly."),
            ("wave",           2...4,  "Still on channel."),
        ]
        if let pick = pool.randomElement() {
            startPose(pick.name, duration: Double.random(in: pick.dur), message: pick.msg)
        }
    }

    private func startSportActivity(nightMode: Bool) {
        moveToFloorIfNeeded()

        let names = nightMode ? ["skateboard", "soccer_goal"] : ["soccer_goal", "skateboard"]
        let next = nextCycledName(from: names, cycle: &sportActivityCycle, avoiding: lastIdleActivity)
        lastIdleActivity = next

        if next == "skateboard" {
            startSkate(left: Bool.random(),
                       duration: nightMode ? Double.random(in: 1.8...3.2) : Double.random(in: 1.6...3.0),
                       message: nightMode ? "Night route." : "Clearing a lane.")
        } else {
            startPose("soccer_goal", duration: 2.3, message: "Goal posted. Surveillance distracted.")
        }
    }

    private func startHackerActivity() {
        moveToFloorIfNeeded()

        let pool: [(name: String, dur: ClosedRange<Double>, msg: String?, note: String?)] = [
            ("terminal_type",  8...14, "Injecting static into the logs.", nil),
            ("terminal_trace", 8...14, "Tracing the signal path backwards.", nil),
            ("evidence_hack",  8...14, "Building the case.", "WATCH THE WATCHERS"),
            ("file_scan",      8...14, "Scrubbing the paper trail.", nil),
            ("monitor_lurk",   8...14, "Reading the telemetry.", nil),
            ("shoulder_scan",  7...12, "Checking who is behind the signal.", nil),
            ("pinboard_plot",  8...14, "The pattern board is warming up.", nil),
            ("bug_sweep",      7...12, "Checking the room for listeners.", nil),
            ("question_type",  7...12, "Something in the terminal smells off.", nil),
            ("question_lurk",  7...12, "Monitoring with questions, as usual.", nil),
            ("dossier_check",  7...12, "Cross-checking the file stack.", "WHO FILED THIS"),
            ("signal_decode",  7...12, "Decoding a dirty transmission.", nil),
            ("signal_sweep",   6...11, "Chasing a signal spike.", nil),
            ("computer_idle",  8...14, "Console open. Trust low.", nil),
            ("headjack",       2...4,  "Borrowing the signal.", nil),
            ("glitch",         0.9...1.4, crypticLine(), nil),
            ("hide",           4...7,  "Off the visible channels.", nil),
        ]

        let nextName = nextCycledName(from: pool.map { $0.name }, cycle: &hackerActivityCycle, avoiding: lastIdleActivity)
        guard let pick = pool.first(where: { $0.name == nextName }) ?? pool.randomElement() else { return }
        lastIdleActivity = pick.name
        startPose(pick.name, duration: Double.random(in: pick.dur), message: pick.msg)
        if let note = pick.note {
            maybeLeaveNote(note)
        }
    }

    private func doGraffitiAction() {
        let graffitis: [(String, String, String)] = [
            ("graffiti_bloc",     "Long live the Bloc.",   "LONG LIVE THE BLOC"),
            ("graffiti_was_here", "Leaving evidence.",     "GBOY WAS HERE"),
            ("spray_tag",         "Tagging the perimeter.", "NO HARMONY"),
            ("sticker_slap",      "Posting the message.",   "WATCH THE WATCHERS"),
        ]
        let nextName = nextCycledName(from: graffitis.map { $0.0 }, cycle: &graffitiCycle, avoiding: lastIdleActivity)
        let pick = graffitis.first(where: { $0.0 == nextName }) ?? graffitis.randomElement()!
        lastIdleActivity = pick.0
        startPose(pick.0, duration: Double.random(in: 1.8...3.4), message: pick.1)
        showSticky(pick.2, at: randomDesktopPoint(), force: true)
    }

    // ── Cursor reactions ──────────────────────────────────────

    private func reactToCursor() {
        guard !paused, !isCompanionHidden, !actionLocked, !dragging, !flinging else { return }
        guard Date() >= quietUntil else { return }

        let cursor = NSEvent.mouseLocation
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let dx = cursor.x - center.x
        let dy = cursor.y - center.y
        let dist = hypot(dx, dy)

        // Track cursor hover duration
        let cursorMoved = hypot(cursor.x - lastCursorPos.x, cursor.y - lastCursorPos.y) > 8
        if cursorMoved {
            lastCursorPos = cursor
            cursorHoverStart = Date()
            // Reset psonic charge if cursor flees and returns
            if psonicChargeLevel > 0 && dist > 180 { psonicChargeLevel = 0 }
        }
        let hoverDuration = Date().timeIntervalSince(cursorHoverStart ?? Date())

        guard dist < 240 else { return }

        let r = Int.random(in: 0..<100)

        // ── Very close (< 42 px) — escalating aggression ─────────
        if dist < 42 {
            // Escalate psonic charge level with repeated close approaches
            psonicChargeLevel = min(psonicChargeLevel + 1, 2)

            if r < 8  { fireChargedBlast(at: cursor, level: psonicChargeLevel); return }
            if r < 16 { startPose("attack",  duration: 0.7,  message: "Back. Off."); return }
            if r < 26 { startPose("angry",   duration: 0.9,  message: aggressionLine()); return }
            if r < 34 { startPose("tongue",  duration: 0.6,  message: cursorLine()); return }
            if r < 40 { startPose("laser",   duration: 0.7,  message: "Psonic warning shot."); return }
            return
        }

        // ── Close (< 80 px) — mixed curiosity / hostility ────────
        if dist < 80 {
            if r < 12 { firePsonicBlast(at: cursor); return }
            if r < 24 { startPose("wave",    duration: 1.1,  message: waveLine()); return }
            if r < 34 { startPose("tongue",  duration: 0.7,  message: cursorLine()); return }
            if r < 44 { startPose("attack",  duration: 0.7,  message: "Too close."); return }
            if r < 52 {
                let anim = abs(dx) > abs(dy)
                    ? (dx < 0 ? "look_left" : "look_right")
                    : (dy < 0 ? "look_down" : "look_up")
                startPose(anim, duration: 0.55, message: cursorLine()); return
            }
            // Persistent hover at close range → charge builds, warning issued
            if hoverDuration > 6 && r < 65 {
                psonicChargeLevel = min(psonicChargeLevel + 1, 2)
                startPose("laser", duration: 0.8, message: chargeWarningLine()); return
            }
            return
        }

        // ── Medium (< 140 px) — awareness + long hover escalation ─
        if dist < 140 {
            if r < 18 {
                let anim = abs(dx) > abs(dy)
                    ? (dx < 0 ? "look_left" : "look_right")
                    : (dy < 0 ? "look_down" : "look_up")
                startPose(anim, duration: 0.5, message: "Acquired."); return
            }
            if r < 28 { startPose("wave", duration: 1.0, message: waveLine()); return }
            if hoverDuration > 8  && r < 40 { startPose("confused", duration: 1.0, message: "Still here?"); return }
            if hoverDuration > 14 && r < 55 { startPose("angry", duration: 0.8, message: "I am clocking this."); return }
        }

        // ── Approach logic (120–240 px, stationary cursor) ────────
        if dist < 240, attachedSurface == .floor, !cursorMoved, hoverDuration > 2.0, abs(dx) > 60, r < 14 {
            approachCursor(cursor); return
        }

        quietUntil = Date().addingTimeInterval(Double.random(in: 1.0...2.4))
    }

    // ── Drag ─────────────────────────────────────────────────

    private func beginDrag(event: NSEvent) {
        dragging = true; flinging = false; actionLocked = true
        actionTimer?.invalidate()
        movement = .zero; flingVelocity = .zero
        let mouse = NSEvent.mouseLocation
        dragOffset = CGPoint(x: mouse.x - window.frame.origin.x,
                             y: mouse.y - window.frame.origin.y)
        dragSamples = [window.frame.origin]
        dragCount += 1
        playAnimation("drop")
        showBubble(dragLine(), force: true)
    }

    private func continueDrag(event: NSEvent) {
        guard dragging else { return }
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(clamp(point: CGPoint(x: mouse.x - dragOffset.x,
                                                    y: mouse.y - dragOffset.y)))
        dragSamples.append(window.frame.origin)
        if dragSamples.count > 8 { dragSamples.removeFirst() }
    }

    private func endDrag(event: NSEvent) {
        guard dragging else { return }
        dragging = false

        if dragSamples.count >= 2 {
            let first = dragSamples.first ?? .zero, last = dragSamples.last ?? .zero
            let vx = last.x - first.x, vy = last.y - first.y
            if hypot(vx, vy) > 36 {
                flinging = true
                flingVelocity = CGVector(dx: vx * 7.6, dy: vy * 7.6)
                playAnimation("fall")
                showBubble(flingLine(), force: true)
                dragSamples.removeAll()
                return
            }
        }

        dragSamples.removeAll()
        actionLocked = false
        comfort()
    }

    private func onRightClick() {
        if isCompanionHidden {
            reappearFromSmoke(reason: "Signal restored.")
            return
        }
        // Cycle through feeding / comfort / note
        let r = Int.random(in: 0..<3)
        if r == 0 { feed() }
        else if r == 1 { comfort() }
        else { spawnDesktopNote() }
    }

    private func onDoubleClick() {
        if isCompanionHidden {
            reappearFromSmoke(reason: "Back on channel.")
            onChatRequested?()
            return
        }
        startPose("wave", duration: 0.95, message: nil, forceSpeech: false)
        onChatRequested?()
    }

    // ── Fling physics ────────────────────────────────────────

    private func updateFling(delta: TimeInterval) {
        var origin = window.frame.origin
        origin.x += flingVelocity.dx * delta
        origin.y += flingVelocity.dy * delta
        flingVelocity.dy += Self.gravity * delta
        flingVelocity.dx *= 0.985

        let vis = activeScreenFrame
        let maxX = vis.maxX - window.frame.width
        let maxY = vis.maxY - window.frame.height

        if origin.x <= vis.minX {
            origin.x = vis.minX
            if abs(flingVelocity.dx) > 200 { window.setFrameOrigin(origin); attach(to: .left);  endFling(message: "Wall secured."); return }
            flingVelocity.dx *= -0.35
        }
        if origin.x >= maxX {
            origin.x = maxX
            if abs(flingVelocity.dx) > 200 { window.setFrameOrigin(origin); attach(to: .right); endFling(message: "Wall secured."); return }
            flingVelocity.dx *= -0.35
        }
        if origin.y >= maxY {
            origin.y = maxY
            if abs(flingVelocity.dy) > 240 { window.setFrameOrigin(origin); attach(to: .top);   endFling(message: "Ceiling claimed."); return }
            flingVelocity.dy *= -0.2
        }
        if origin.y <= vis.minY {
            origin.y = vis.minY
            if abs(flingVelocity.dy) > 130 { flingVelocity.dy *= -0.18; flingVelocity.dx *= 0.82 }
            else { window.setFrameOrigin(origin); attach(to: .floor); endFling(message: "Landed clean."); return }
        }
        window.setFrameOrigin(origin)
    }

    private func endFling(message: String) {
        flinging = false; flingVelocity = .zero; movement = .zero
        actionLocked = false; currentAction = ""
        showBubble(message, force: true)
        updateDefaultAnimation()
    }

    // ── Movement helpers ──────────────────────────────────────

    private func startWalk(left: Bool, duration: TimeInterval = 1.5,
                            targetDepth: CGFloat? = nil, message: String? = nil, forceSpeech: Bool = false) {
        actionLocked = true; attachedSurface = .floor
        currentAction = left ? "walk_left" : "walk_right"
        movement = floorMovementVector(horizontalSpeed: left ? -92 : 92, targetDepth: targetDepth)
        lastDirection = left ? "left" : "right"
        playAnimation(currentAction)
        if let m = message { showBubble(m, force: forceSpeech) }
        setActionTimer(duration)
    }

    private func startRun(left: Bool, duration: TimeInterval = 1.1,
                           targetDepth: CGFloat? = nil, message: String? = nil, forceSpeech: Bool = false) {
        actionLocked = true; attachedSurface = .floor
        currentAction = left ? "run_left" : "run_right"
        movement = floorMovementVector(horizontalSpeed: left ? -165 : 165, targetDepth: targetDepth)
        lastDirection = left ? "left" : "right"
        playAnimation(currentAction)
        if let m = message { showBubble(m, force: forceSpeech) }
        setActionTimer(duration)
    }

    private func startClimb(surface: Surface, down: Bool,
                              duration: TimeInterval = 1.2, forceSpeech: Bool = false) {
        actionLocked = true; attachedSurface = surface
        switch surface {
        case .left:  currentAction = "climb_right"
        case .right: currentAction = "climb_side"
        case .top:   currentAction = "climb_back"
        case .floor: currentAction = down ? "walk_front" : "walk_back"
        }
        movement = CGVector(dx: 0, dy: down ? -82 : 82)
        lastDirection = down ? "front" : "back"
        playAnimation(currentAction)
        if forceSpeech || Int.random(in:0..<3)==0 {
            showBubble(surface == .top ? "Ceiling territory." : "Wall approach.", force: forceSpeech)
        }
        setActionTimer(duration)
    }

    private func startPose(_ animation: String, duration: TimeInterval,
                            message: String? = nil, forceSpeech: Bool = false) {
        actionLocked = true; currentAction = animation; movement = .zero
        playAnimation(animation)
        if let m = message { showBubble(m, force: forceSpeech) }
        setActionTimer(duration)
    }

    private func dropFromSurface() {
        attachedSurface = .floor; flinging = true; actionLocked = true
        currentAction = "drop"; movement = .zero
        flingVelocity = CGVector(dx: CGFloat.random(in: -120...120), dy: 80)
        playAnimation("drop")
        showBubble("Dropping.")
    }

    private func startTeleport(animation: String, message: String?, forceSpeech: Bool = false) {
        if animation == "portal" {
            performPortalTraversal(message: message, forceSpeech: forceSpeech)
            return
        }
        actionLocked = true
        currentAction = animation == "vanish"
            ? nextCycledName(from: ["smoke_burst", "smoke_drift", "vanish"], cycle: &smokePowerCycle, avoiding: currentAnimation)
            : animation
        movement = currentAction == "smoke_drift"
            ? floorMovementVector(horizontalSpeed: Bool.random() ? -86 : 86, targetDepth: randomFloorDepth())
            : .zero
        pendingTeleport = randomDesktopPoint()
        playAnimation(currentAction)
        if let m = message { showBubble(m, force: forceSpeech) }
        setActionTimer(currentAction == "smoke_drift" ? 1.55 : 1.2)
    }

    private func settleWithIdleFlair(duration: TimeInterval) {
        consecutiveIdleCount += 1
        movement = .zero; currentAction = ""
        let idleOptions = ["idle_front", "idle_left", "idle_right", "sit_cross",
                           "bored", "throne", "monitor_lurk", "question_lurk",
                           "crt_watch", "computer_idle", "float", "dizzy",
                           "phone_call", "umbrella", "hood_peek", "side_eye",
                           "sulk", "proud_stance", "desk_doze"]
        let pick = nextCycledName(from: idleOptions, cycle: &settleAnimationCycle, avoiding: currentAnimation)
        playAnimation(pick)
        if Int.random(in: 0..<3) == 0 { showBubble(idleLine()) }
        quietUntil = Date().addingTimeInterval(duration)
    }

    private func startSkate(left: Bool, duration: TimeInterval = 1.5,
                             targetDepth: CGFloat? = nil, message: String? = nil, forceSpeech: Bool = false) {
        actionLocked = true; attachedSurface = .floor
        currentAction = "skateboard"
        movement = floorMovementVector(horizontalSpeed: left ? -210 : 210, targetDepth: targetDepth)
        lastDirection = left ? "left" : "right"
        playAnimation("skateboard")
        if let m = message { showBubble(m, force: forceSpeech) }
        setActionTimer(duration)
    }

    private func settle(duration: TimeInterval, animation: String? = nil) {
        movement = .zero; currentAction = ""
        if let a = animation { playAnimation(a) } else { updateDefaultAnimation() }
        quietUntil = Date().addingTimeInterval(duration)
    }

    private func approachCursor(_ cursor: CGPoint) {
        guard attachedSurface == .floor else { return }
        let deltaX = cursor.x - window.frame.midX
        guard abs(deltaX) > 72 else { return }

        let moveLeft = deltaX < 0
        let speed: CGFloat = abs(deltaX) > 220 ? 165 : 92
        let duration = max(0.8, min(3.2, TimeInterval(abs(deltaX) / speed)))
        consecutiveIdleCount = 0
        let desiredDepth = floorDepthForCursor(cursor)

        if speed > 100 {
            startRun(left: moveLeft, duration: duration, targetDepth: desiredDepth, message: "Pointer trail detected.")
        } else {
            startWalk(left: moveLeft, duration: duration, targetDepth: desiredDepth, message: "Investigating.")
        }
    }

    private func floorInterestStops(in vis: CGRect) -> [CGFloat] {
        var stops: [CGFloat] = [
            vis.minX + 8,
            vis.minX + vis.width * 0.24,
            vis.midX - Self.windowSize.width / 2,
            vis.minX + vis.width * 0.68,
            vis.maxX - Self.windowSize.width - 8,
        ]

        let cursorScreen = NSScreen.screens.first(where: { $0.frame.contains(lastCursorPos) })?.visibleFrame
        if cursorScreen == nil || cursorScreen == vis {
            stops.append(lastCursorPos.x - Self.windowSize.width / 2)
        }

        let normalized = stops.map {
            min(max($0, vis.minX), vis.maxX - Self.windowSize.width)
        }
        var unique: [CGFloat] = []
        for stop in normalized {
            if !unique.contains(where: { abs($0 - stop) < 28 }) {
                unique.append(stop)
            }
        }
        return unique
    }

    private func patrolFloor(run: Bool) {
        let vis = activeScreenFrame
        let stops = floorInterestStops(in: vis)

        let currentX = window.frame.origin.x
        let targetX = stops.shuffled().first(where: { abs($0 - currentX) > 120 }) ?? stops.randomElement() ?? currentX
        let dist = abs(targetX - currentX)
        if dist < 30 { settleWithIdleFlair(duration: Double.random(in: 1.4...3.4)); return }

        let moveLeft = targetX < currentX
        let speed: CGFloat = run ? 165 : 92
        let duration = max(0.7, min(4.0, TimeInterval(dist / speed)))
        let targetDepth = randomFloorDepth()
        consecutiveIdleCount = 0
        if run { startRun(left: moveLeft, duration: duration, targetDepth: targetDepth) }
        else   { startWalk(left: moveLeft, duration: duration, targetDepth: targetDepth) }
    }

    // ── Finish action ─────────────────────────────────────────

    private func finishAction() {
        let finishedAction = currentAction
        actionTimer?.invalidate(); actionTimer = nil; movement = .zero

        if finishedAction == "landing_recover" {
            cancelPortalSequence()
        }

        if pendingHideAfterAction {
            pendingHideAfterAction = false
            isCompanionHidden = true
            hiddenAnchorPoint = window.frame.origin
            currentAction = ""
            actionLocked = false
            window.orderOut(nil)
            window.alphaValue = 0
            quietUntil = Date().addingTimeInterval(Double.random(in: 1.8...3.6))
            return
        }

        if let pt = pendingTeleport {
            window.setFrameOrigin(clamp(point: pt))
            attach(to: .floor)
            pendingTeleport = nil
            maybeLeaveNote("MINDVERSE LEAK DETECTED")
        }

        if pendingReappearAfterAction {
            pendingReappearAfterAction = false
            currentAction = ""
            actionLocked = false
            attach(to: .floor)
            let line = pendingReappearMessage ?? waveLine()
            pendingReappearMessage = nil
            startPose("wave", duration: 1.25, message: line, forceSpeech: true)
            return
        }

        if finishedAction.contains("walk") { energy = max(0, energy - 1.5) }
        if finishedAction == "run_left" || finishedAction == "run_right" { energy = max(0, energy - 2.2) }
        if finishedAction == "skateboard" { energy = max(0, energy - 1.8) }

        currentAction = ""; actionLocked = false
        quietUntil = Date().addingTimeInterval(Double.random(in: 0.8...1.8))
        updateDefaultAnimation()
    }

    private func setActionTimer(_ duration: TimeInterval) {
        actionTimer?.invalidate()
        actionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.finishAction()
        }
    }

    // ── Default animation ─────────────────────────────────────

    private func updateDefaultAnimation() {
        if actionLocked || flinging || dragging { return }

        if energy <= 14 {
            if ["sleep_lie", "sleep_curl", "sleep_sit", "blanket_nest"].contains(currentAnimation) { return }
            playAnimation(social < 28 ? "sleep_sit" : "sleep_curl"); return
        }
        if hunger <= 14 {
            playAnimation(energy < 28 ? "sit_cross" : "bored")
            maybeLeaveNote("RATIONS LOW")
            return
        }
        if social <= 4, energy > 18 {
            playAnimation("cry"); return
        }
        if social <= 12 {
            playAnimation(energy < 30 ? "sulk" : "hood_peek"); return
        }
        if social <= 22 {
            playAnimation("side_eye"); return
        }
        if hunger >= 85 && social >= 80 {
            playAnimation("proud_stance"); return
        }

        switch attachedSurface {
        case .left:  playAnimation("idle_left")
        case .right: playAnimation("idle_right")
        case .top:   playAnimation("idle_back")
        case .floor: playAnimation("idle_\(lastDirection)")
        }
    }

    // ── Idle activity table ───────────────────────────────────

    private func curatedSceneNames() -> [String] {
        [
            "skateboard", "soccer_goal", "dance", "moonwalk", "backflip", "spin", "applaud", "bow",
            "sneak", "terminal_type", "question_type", "evidence_hack", "file_scan", "dossier_check",
            "monitor_lurk", "question_lurk", "signal_sweep", "pinboard_plot", "bug_sweep", "computer_idle",
            "typing_fast", "terminal_trace", "signal_decode", "shoulder_scan", "desk_doze", "crt_watch", "desk_sketch", "file_sort",
            "graffiti_bloc", "graffiti_was_here", "spray_tag", "sticker_slap",
            "cook_meal", "noodle_eat", "desk_noodles", "fridge_open", "mug_sip", "handheld_game", "tv_flip",
            "radio_listen", "zine_read", "blanket_nest", "sleep_curl", "sleep_sit", "sit_cross", "throne", "cape_flutter", "portal",
            "wall_sit", "wallslide", "peek_left", "peek_right", "climb_side", "climb_right", "climb_back",
            "phone_call", "umbrella", "float", "shiver", "dizzy", "tantrum", "headjack", "glitch", "hide",
            "vanish", "smoke_burst", "smoke_reform", "smoke_drift", "smoke_orbit", "psonic_charge",
            "psonic_overload", "happy", "confused", "bored", "angry", "cry", "tongue", "stretch", "yawn",
            "hood_peek", "side_eye", "sulk", "proud_stance",
            "stumble", "wave", "attack"
        ]
    }

    private func nextSceneName(forceAdvance: Bool, preferred: [String]? = nil) -> String {
        let names = preferred ?? curatedSceneNames()
        if !forceAdvance, let current = currentAction.isEmpty ? nil : currentAction, names.contains(current) {
            return current
        }
        return nextCycledName(from: names, cycle: &sceneCycle, avoiding: lastIdleActivity)
    }

    private func playCuratedScene(_ name: String) {
        lastIdleActivity = name

        let rightWallScenes: Set<String> = ["wall_sit", "wallslide", "peek_left", "climb_side"]
        let leftWallScenes: Set<String> = ["peek_right", "climb_right"]
        if name == "climb_back" {
            attach(to: .top)
        } else if rightWallScenes.contains(name) {
            attach(to: .right)
        } else if leftWallScenes.contains(name) {
            attach(to: .left)
        } else {
            moveToFloorIfNeeded()
        }

        switch name {
        case "skateboard":
            startSkate(left: Bool.random(), duration: 2.8, targetDepth: randomFloorDepth(), message: "Skate pass.")
        case "soccer_goal":
            startPose("soccer_goal", duration: 2.3, message: "Goal against the machine.")
        case "dance":
            startPose("dance", duration: 4.2, message: expressiveLine())
        case "moonwalk":
            startPose("moonwalk", duration: 3.1, message: expressiveLine())
        case "backflip":
            startPose("backflip", duration: 1.7, message: expressiveLine())
        case "spin":
            startPose("spin", duration: 1.4, message: expressiveLine())
        case "applaud":
            startPose("applaud", duration: 2.4, message: "Applause, reluctantly.")
        case "bow":
            startPose("bow", duration: 1.6, message: "Scene acknowledged.")
        case "sneak":
            startPose("sneak", duration: 3.8, message: nightLine())
        case "terminal_type", "question_type", "evidence_hack", "file_scan", "dossier_check",
             "monitor_lurk", "question_lurk", "signal_sweep", "pinboard_plot", "bug_sweep",
             "computer_idle", "typing_fast", "terminal_trace", "signal_decode", "shoulder_scan",
             "crt_watch", "desk_sketch", "file_sort":
            startPose(name, duration: 8.8, message: "Signal work.")
        case "desk_doze":
            startPose("desk_doze", duration: 10.5, message: "Falling asleep in the monitor glow.")
        case "graffiti_bloc", "graffiti_was_here", "spray_tag", "sticker_slap":
            startPose(name, duration: 2.8, message: "Tagging the perimeter.")
        case "cook_meal":
            startPose("cook_meal", duration: 12.0, message: "Kitchen op online.")
        case "noodle_eat":
            startPose("noodle_eat", duration: 11.0, message: "Emergency noodles.")
        case "desk_noodles":
            startPose("desk_noodles", duration: 12.0, message: "Noodles and poor decisions.")
        case "fridge_open":
            startPose("fridge_open", duration: 6.5, message: "Snack recon.")
        case "mug_sip":
            startPose("mug_sip", duration: 8.0, message: "Warm drink. Reset.")
        case "handheld_game":
            startPose("handheld_game", duration: 11.0, message: "High score defended.")
        case "tv_flip":
            startPose("tv_flip", duration: 9.0, message: "Broadcast scan.")
        case "radio_listen":
            startPose("radio_listen", duration: 10.0, message: "Static incoming.")
        case "zine_read":
            startPose("zine_read", duration: 10.0, message: "Reading anti-compliance literature.")
        case "blanket_nest":
            startPose("blanket_nest", duration: 12.0, message: "Nest construction underway.")
        case "sleep_curl":
            startPose("sleep_curl", duration: 12.0, message: "Curling into the static.")
        case "sleep_sit":
            startPose("sleep_sit", duration: 10.0, message: "Sleeping upright. Tactical.")
        case "sit_cross":
            startPose("sit_cross", duration: 9.0, message: sitLine())
        case "throne":
            startPose("throne", duration: 9.0, message: "Occupying the chair like a threat.")
        case "cape_flutter":
            startPose("cape_flutter", duration: 1.4, message: "Flag check.")
        case "portal":
            performPortalTraversal(message: "Mindverse route.")
        case "wall_sit", "wallslide", "peek_left", "peek_right":
            startPose(name, duration: name == "wall_sit" ? 4.6 : 2.8, message: edgeLine())
        case "climb_side":
            startClimb(surface: .right, down: Bool.random(), duration: 3.1)
        case "climb_right":
            startClimb(surface: .left, down: Bool.random(), duration: 3.1)
        case "climb_back":
            startClimb(surface: .top, down: Bool.random(), duration: 3.1)
        case "phone_call":
            startPose("phone_call", duration: 4.4, message: "Line secured.")
        case "umbrella":
            startPose("umbrella", duration: 4.0, message: "Weather protocol.")
        case "float":
            startPose("float", duration: 4.0, message: crypticLine())
        case "shiver":
            startPose("shiver", duration: 2.5, message: "Bad frequency.")
        case "dizzy":
            startPose("dizzy", duration: 2.5, message: "Display drift.")
        case "tantrum":
            startPose("tantrum", duration: 3.1, message: "Compliance rejected.")
        case "headjack":
            startPose("headjack", duration: 1.4, message: "Borrowing the signal.")
        case "glitch":
            startPose("glitch", duration: 1.0, message: crypticLine())
        case "hide":
            startPose("hide", duration: 6.0, message: "Off the visible channels.")
        case "vanish":
            startTeleport(animation: "vanish", message: "Smoke route.")
        case "smoke_burst":
            startPose("smoke_burst", duration: 1.3, message: crypticLine())
        case "smoke_reform":
            startPose("smoke_reform", duration: 1.4, message: "Returning through smoke.")
        case "smoke_drift":
            startPose("smoke_drift", duration: 1.5, message: "Smoke pass.")
        case "smoke_orbit":
            startPose("smoke_orbit", duration: 1.5, message: crypticLine())
        case "psonic_charge":
            startPose("psonic_charge", duration: 1.4, message: chargeWarningLine())
        case "psonic_overload":
            startPose("psonic_overload", duration: 1.8, message: chargedBlastLine())
        case "happy":
            startPose("happy", duration: 2.0, message: victoryLine())
        case "hood_peek":
            startPose("hood_peek", duration: 3.0, message: suspiciousLine())
        case "side_eye":
            startPose("side_eye", duration: 2.8, message: suspiciousLine())
        case "sulk":
            startPose("sulk", duration: 3.2, message: boredLine())
        case "proud_stance":
            startPose("proud_stance", duration: 3.0, message: victoryLine())
        case "confused":
            startPose("confused", duration: 1.3, message: confusedLine())
        case "bored":
            startPose("bored", duration: 1.8, message: boredLine())
        case "angry":
            startPose("angry", duration: 1.5, message: aggressionLine())
        case "cry":
            startPose("cry", duration: 2.2, message: "Signal dipped.")
        case "tongue":
            startPose("tongue", duration: 1.0, message: cursorLine())
        case "stretch":
            startPose("stretch", duration: 2.0, message: "Resetting the joints.")
        case "yawn":
            startPose("yawn", duration: 1.8, message: "Low-voltage warning.")
        case "stumble":
            startPose("stumble", duration: 2.1, message: "Recovered. Probably.")
        case "wave":
            startPose("wave", duration: 1.5, message: waveLine(), forceSpeech: true)
        case "attack":
            startPose("attack", duration: 0.9, message: aggressionLine(), forceSpeech: true)
        default:
            if Self.clips[name] != nil {
                startPose(name, duration: 2.0, message: nil)
            } else {
                startIdleActivity()
            }
        }
    }

    private func nextCycledName(from names: [String], cycle: inout [String], avoiding lastName: String) -> String {
        let available = Set(names)
        cycle.removeAll { !available.contains($0) }
        if cycle.isEmpty {
            cycle = names.shuffled()
            if cycle.count > 1, cycle.first == lastName {
                cycle.swapAt(0, 1)
            }
        }
        return cycle.removeFirst()
    }

    private func idleActivityDefinitions() -> [(name: String, dur: ClosedRange<Double>, msg: String?)] {
        var pool: [(name: String, dur: ClosedRange<Double>, msg: String?)] = [
            ("terminal_type",  8...14, "Compiling something ominous."),
            ("terminal_trace", 8...14, "Tracing a signal nobody should trust."),
            ("evidence_hack",  8...14, "Building the case."),
            ("question_type",  7...12, "Typing through a suspicious hunch."),
            ("question_lurk",  7...12, "Watching the room think."),
            ("shoulder_scan",  7...12, "Checking the room behind the glow."),
            ("desk_doze",      8...14, "Falling asleep in the machine light."),
            ("dossier_check",  7...12, "Reviewing another impossible folder."),
            ("signal_decode",  7...12, "Decoding the ugly parts."),
            ("signal_sweep",   6...11, "Signal quality questionable."),
            ("file_scan",      8...14, "Reviewing the paper trail."),
            ("monitor_lurk",   8...14, "Watching the machine watch back."),
            ("pinboard_plot",  8...14, "Connecting the dots."),
            ("bug_sweep",      8...13, "Checking the room."),
            ("computer_idle",  8...14, "Accessing the unsupervised zone."),
            ("crt_watch",      7...12, "Watching the phosphor ghosts."),
            ("radio_listen",   7...12, "Static incoming."),
            ("desk_noodles",   8...14, "Noodles and poor decisions."),
            ("desk_sketch",    8...14, "Drafting slogans."),
            ("file_sort",      8...14, "Sorting the evidence."),
            ("mug_sip",        6...11, "Small beverage. Big stare."),
            ("zine_read",      8...14, "Reading anti-compliance literature."),
            ("tv_flip",        6...10, "Broadcast scan."),
            ("handheld_game",  7...12, "High score defended."),
            ("soccer_goal",    2.0...2.8, "Goal against the machine."),
            ("cook_meal",      8...14, "Cooking like the room is watching."),
            ("noodle_eat",     7...12, "Emergency noodles."),
            ("fridge_open",    5...8,  "Fridge reconnaissance."),
            ("throne",         7...12, "Occupying the chair like a threat."),
            ("blanket_nest",   8...14, "Nest construction underway."),
            ("sleep_curl",     8...14, "Curled up off-grid."),
            ("sleep_sit",      7...12, "Dozing on alert."),
            ("dance",          4...8,  "Morale operation."),
            ("headjack",       3...6,  "Borrowing the signal."),
            ("glitch",         0.9...1.4, crypticLine()),
            ("sit_cross",      6...10, sitLine()),
            ("hood_peek",      2.8...4.2, suspiciousLine()),
            ("side_eye",       2.4...3.8, suspiciousLine()),
            ("sulk",           3.0...4.8, boredLine()),
            ("proud_stance",   2.8...4.2, victoryLine()),
            ("hide",           5...9,  "Not hiding. Observing."),
            ("stretch",        2...4,  "Resetting the joints."),
            ("yawn",           2...4,  "Low-voltage warning."),
            ("stumble",        2...4,  "Recovered. Probably."),
        ]
        if energy < 25 {
            pool.append(("sleep_lie", 8...16, "Power down."))
        }
        return pool
    }

    private func startIdleActivity() {
        consecutiveIdleCount = 0
        let pool = idleActivityDefinitions()
        let nextName = nextCycledName(from: pool.map { $0.name }, cycle: &idleActivityCycle, avoiding: lastIdleActivity)
        if let pick = pool.first(where: { $0.name == nextName }) ?? pool.randomElement() {
            lastIdleActivity = pick.name
            startPose(pick.name, duration: Double.random(in: pick.dur), message: pick.msg)
            if pick.name == "evidence_hack" || pick.name == "glitch" || pick.name == "terminal_type" {
                maybeLeaveNote("WATCH THE WATCHERS")
            }
        }
    }

    private func isFoodRecoveryAnimation(_ name: String) -> Bool {
        [
            "eat", "fridge_open", "cook_meal", "noodle_eat", "desk_noodles", "mug_sip"
        ].contains(name)
    }

    private func isLargeIdleActivity(_ name: String) -> Bool {
        [
            "computer_idle", "terminal_type", "terminal_trace", "question_type", "monitor_lurk", "question_lurk", "shoulder_scan",
            "desk_doze", "dossier_check", "signal_sweep", "crt_watch", "radio_listen",
            "signal_decode", "desk_sketch", "file_sort", "file_scan", "zine_read", "pinboard_plot",
            "tv_flip", "handheld_game", "soccer_goal", "evidence_hack", "sit_cross", "hide", "stretch",
            "blanket_nest", "sleep_curl", "sleep_sit", "throne", "bug_sweep", "dance", "headjack"
        ].contains(name)
    }

    private func moveToFloorIfNeeded() {
        guard attachedSurface != .floor else { return }
        attach(to: .floor)
        movement = .zero
    }

    // ── Psonic blast ──────────────────────────────────────────

    private func cursorStrikeOrigin(for point: CGPoint) -> CGPoint {
        let vis = NSScreen.screens.first(where: { $0.frame.contains(point) })?.visibleFrame ?? activeScreenFrame
        let depth = floorDepthForCursor(point)
        let x = min(max(point.x - window.frame.width / 2, vis.minX), vis.maxX - window.frame.width)
        let y = floorY(for: depth, in: vis)
        return CGPoint(x: x, y: y)
    }

    private func cursorAimPoint() -> CGPoint {
        let horizontalBias: CGFloat = lastDirection == "left" ? -20 : 20
        return CGPoint(
            x: window.frame.midX + horizontalBias,
            y: window.frame.minY + window.frame.height * 0.62
        )
    }

    private func orientTowardCursor(_ point: CGPoint) {
        guard attachedSurface == .floor || currentAction.hasPrefix("smoke_") else { return }
        lastDirection = point.x < window.frame.midX ? "left" : "right"
    }

    private func beginSmokeCursorApproach(toward point: CGPoint, duration: TimeInterval) {
        moveToFloorIfNeeded()
        orientTowardCursor(point)
        let targetOrigin = cursorStrikeOrigin(for: point)
        targetFloorDepth = floorDepthForCursor(point)
        let resolvedDuration = max(duration, 0.12)
        movement = CGVector(
            dx: (targetOrigin.x - window.frame.origin.x) / CGFloat(resolvedDuration),
            dy: (targetOrigin.y - window.frame.origin.y) / CGFloat(resolvedDuration)
        )
        currentAction = "smoke_drift"
        playAnimation("smoke_drift")
    }

    private func showTargetedAlerts(_ labels: [String], toward point: CGPoint,
                                    startDelay: TimeInterval = 0.0, jitter: CGFloat = 12) {
        let start = cursorAimPoint()
        let total = max(labels.count, 1)
        for (index, label) in labels.enumerated() {
            let progress = CGFloat(index + 1) / CGFloat(total + 1)
            let base = CGPoint(
                x: start.x + (point.x - start.x) * progress,
                y: start.y + (point.y - start.y) * progress
            )
            Timer.scheduledTimer(withTimeInterval: startDelay + Double(index) * 0.12, repeats: false) { [weak self] _ in
                guard let self else { return }
                let alertPoint = CGPoint(
                    x: base.x + CGFloat.random(in: -jitter...jitter),
                    y: base.y + CGFloat.random(in: -jitter...jitter)
                )
                self.showAlert(label, at: alertPoint)
            }
        }
    }

    private func performCursorSmokeStrike(at point: CGPoint,
                                          impactAnimation: String,
                                          impactDelay: TimeInterval,
                                          totalDuration: TimeInterval,
                                          suppressDuration: TimeInterval,
                                          speech: String,
                                          labels: [String],
                                          celebrate: Bool = false) {
        startupTimer?.invalidate()
        actionTimer?.invalidate()
        pendingTeleport = nil
        actionLocked = true

        beginSmokeCursorApproach(toward: point, duration: impactDelay)
        suppressCursorTemporarily(duration: suppressDuration)
        showBubble(speech, force: true)
        showTargetedAlerts(["LOCK", "TRACE"], toward: point, jitter: 6)

        Timer.scheduledTimer(withTimeInterval: impactDelay, repeats: false) { [weak self] _ in
            guard let self, !self.paused else { return }
            self.orientTowardCursor(point)
            self.movement = .zero
            self.actionLocked = true
            self.currentAction = impactAnimation
            self.playAnimation(impactAnimation)
            self.playBlastSound()
            self.showAlert("CURSOR LOCK", at: point)
            self.showTargetedAlerts(labels, toward: point, jitter: impactAnimation == "psonic_overload" ? 18 : 12)
        }

        setActionTimer(totalDuration)

        guard celebrate else { return }
        Timer.scheduledTimer(withTimeInterval: impactDelay + 0.95, repeats: false) { [weak self] _ in
            self?.disappearIntoSmoke(reason: nil)
        }
        Timer.scheduledTimer(withTimeInterval: impactDelay + 2.15, repeats: false) { [weak self] _ in
            guard let self, !self.paused else { return }
            if self.isCompanionHidden {
                self.reappearFromSmoke(reason: self.victoryLine())
            } else {
                self.startPose("happy", duration: 1.4, message: self.victoryLine(), forceSpeech: true)
            }
        }
    }

    private func firePsonicBlast(at point: CGPoint) {
        performCursorSmokeStrike(
            at: point,
            impactAnimation: "psonic_charge",
            impactDelay: 0.44,
            totalDuration: 1.55,
            suppressDuration: 1.9,
            speech: psonicLine(),
            labels: ["BLACK SMOKE", "PSONIC HIT", "STATIC SURGE"]
        )
    }

    /// Escalating charged blast — level 1 = single charge, level 2 = cursor destruction
    private func fireChargedBlast(at point: CGPoint, level: Int) {
        if level >= 2 {
            destroyCursorSequence(at: point)
            return
        }

        performCursorSmokeStrike(
            at: point,
            impactAnimation: "psonic_overload",
            impactDelay: 0.5,
            totalDuration: 1.95,
            suppressDuration: 2.8,
            speech: chargedBlastLine(),
            labels: ["CHARGED BURST", "PSONIC ARC", "OVERLOAD", "BLACKOUT"]
        )
    }

    /// Full cursor-destruction sequence: smoke rush → overload → blackout → celebrate
    private func destroyCursorSequence(at point: CGPoint) {
        cursorDestroyCount += 1
        psonicChargeLevel = 0
        performCursorSmokeStrike(
            at: point,
            impactAnimation: "psonic_overload",
            impactDelay: 0.56,
            totalDuration: 2.35,
            suppressDuration: 4.8,
            speech: destroyLine(),
            labels: ["SMOKE IMPACT", "CURSOR DESTROYED", "PSONIC OVERLOAD", "SIGNAL ERASED", "BLACKOUT"],
            celebrate: true
        )
    }

    // ── Grab-zone detection (called each tick) ─────────────────

    /// The grab zone is a small radius around the top of the sprite.
    /// In screen coordinates the sprite head area is near window top.
    private func checkGrabZone() {
        guard !paused, !isCompanionHidden, !actionLocked, !dragging else { return }
        guard Date() > grabReactCooldown else { return }

        let cursor = NSEvent.mouseLocation
        // Top of the sprite in screen coords — the view places the sprite bottom near
        // window.frame.minY + 6, so sprite top ≈ window.frame.minY + spriteHeight + 6
        let spriteH = spriteView.pixelSize.height * spriteView.scale
        let grabPt = CGPoint(x: window.frame.midX,
                             y: window.frame.minY + spriteH * 0.82)
        let dist = hypot(cursor.x - grabPt.x, cursor.y - grabPt.y)

        if dist < 26 {
            if grabHoverStart == nil { grabHoverStart = Date() }
            let hovered = Date().timeIntervalSince(grabHoverStart!)
            if hovered > 0.7 {
                grabHoverStart = nil
                grabReactCooldown = Date().addingTimeInterval(3.5)
                reactToGrabAttempt()
            }
        } else {
            grabHoverStart = nil
        }
    }

    private func reactToGrabAttempt() {
        let r = Int.random(in: 0..<4)
        switch r {
        case 0:
            startPose("angry", duration: 1.0, message: grabLine(), forceSpeech: true)
        case 1:
            // Dodge sideways then wave
            let dodgeLeft = Bool.random()
            startWalk(left: dodgeLeft, duration: 0.5, message: grabLine(), forceSpeech: true)
            Timer.scheduledTimer(withTimeInterval: 0.7, repeats: false) { [weak self] _ in
                self?.startPose("wave", duration: 0.9, message: "Not captured.", forceSpeech: false)
            }
        case 2:
            firePsonicBlast(at: NSEvent.mouseLocation)
        default:
            startPose("attack", duration: 0.8, message: grabLine(), forceSpeech: true)
        }
    }

    // ── Speech / notes ────────────────────────────────────────

    private func showBubble(_ text: String, force: Bool = false) {
        cleanupNotes()
        let now = Date()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let activeBubbleController, activeBubbleController.window?.isVisible == true {
            if !force { return }
            activeBubbleController.closeAnimated()
            self.activeBubbleController = nil
        }
        if !force, now < speechCooldownUntil { return }
        if !force, trimmed == lastBubbleText, now.timeIntervalSince(lastBubbleAt) < 24 { return }
        speechCooldownUntil = now.addingTimeInterval(force ? Double.random(in: 4.5...7.5) : Double.random(in: 10...18))
        lastBubbleText = trimmed
        lastBubbleAt = now
        let origin = CGPoint(x: window.frame.minX + 4, y: window.frame.maxY + 6)
        let c = NoteWindowController(text: trimmed, origin: origin, style: .bubble, duration: 2.3)
        activeBubbleController = c
        noteControllers.append(c); cleanupNotes()
    }

    private func showSticky(_ text: String, at point: CGPoint, force: Bool = false) {
        let now = Date()
        if !force, now < noteCooldownUntil { return }
        noteCooldownUntil = now.addingTimeInterval(Double.random(in: 20...40))
        let highlighted = ["GBOY WAS HERE", "LONG LIVE THE BLOC"].contains(text.uppercased())
        let c = NoteWindowController(text: text, origin: point, style: .sticky, duration: highlighted ? 8.0 : 5.5)
        noteControllers.append(c); cleanupNotes()
    }

    private func showAlert(_ text: String, at point: CGPoint) {
        let c = NoteWindowController(text: text, origin: point, style: .alert, duration: 0.7)
        noteControllers.append(c); cleanupNotes()
    }

    private func cleanupNotes() {
        noteControllers = noteControllers.filter { $0.window?.isVisible == true }
        if activeBubbleController?.window?.isVisible != true {
            activeBubbleController = nil
        }
    }

    private func maybeLeaveNote(_ text: String) {
        if Date() >= noteCooldownUntil, Bool.random() {
            let t = Bool.random() ? text : (CompanionContent.stickyNotes.randomElement() ?? text)
            showSticky(t, at: randomDesktopPoint())
        }
    }

    // ── Animation engine ──────────────────────────────────────

    private func playAnimation(_ name: String) {
        guard currentAnimation != name else { return }
        do {
            let atlas = try spriteLibrary.atlas(named: name)
            currentAnimation = name
            currentAtlas = atlas
            currentFrameIndex = 0
            animationAccumulator = 0
            spriteView.pixelSize = atlas.frameSize
            spriteView.currentFrame = atlas.frame(at: 0)
            spriteView.needsDisplay = true
        } catch {
            fputs("Failed to play animation \(name): \(error.localizedDescription)\n", stderr)
            if currentAtlas == nil {
                try? loadAnimation(named: "idle_front")
            }
        }
    }

    private func loadAnimation(named name: String) throws {
        currentAtlas = try spriteLibrary.atlas(named: name)
        spriteView.pixelSize = currentAtlas?.frameSize ?? CGSize(width: 32, height: 32)
        spriteView.currentFrame = currentAtlas?.frame(at: 0)
        spriteView.needsDisplay = true
    }

    // ── Sound ─────────────────────────────────────────────────

    private func playBlastSound() {
        guard let url = AssetLocator.soundURL(named: "psonic_blast.wav") else { return }
        blastPlayer = try? AVAudioPlayer(contentsOf: url)
        blastPlayer?.volume = 0.72; blastPlayer?.prepareToPlay(); blastPlayer?.play()
    }

    private func suppressCursorTemporarily(duration: TimeInterval = 0.55) {
        if !cursorSuppressed { NSCursor.hide(); cursorSuppressed = true }
        cursorSuppressionTimer?.invalidate()
        cursorSuppressionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            if self.cursorSuppressed { NSCursor.unhide(); self.cursorSuppressed = false }
        }
    }

    // ── Screen geometry ───────────────────────────────────────

    private var activeScreenFrame: CGRect {
        NSScreen.screens.first(where: { $0.frame.intersects(window.frame) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func positionOnFloor() {
        let vis = activeScreenFrame
        floorDepth = 0.12
        targetFloorDepth = floorDepth
        applyFloorDepthVisuals()
        window.setFrameOrigin(CGPoint(x: vis.midX - Self.windowSize.width / 2, y: floorY(for: floorDepth, in: vis)))
        attach(to: .floor)
    }

    private func attach(to surface: Surface) {
        attachedSurface = surface
        var o = window.frame.origin
        let vis = activeScreenFrame
        switch surface {
        case .floor:
            o.y = floorY(for: floorDepth, in: vis)
            applyFloorDepthVisuals()
        case .left:  o.x = vis.minX;                        lastDirection = "left"
        case .right: o.x = vis.maxX - window.frame.width;   lastDirection = "right"
        case .top:   o.y = vis.maxY - window.frame.height;  lastDirection = "back"
        }
        window.setFrameOrigin(clamp(point: o))
    }

    private func handleSurfaceEdges() {
        let vis = activeScreenFrame
        var o = window.frame.origin
        let maxX = vis.maxX - window.frame.width
        let maxY = vis.maxY - window.frame.height
        switch attachedSurface {
        case .floor:
            let range = floorDepthYRange(in: vis)
            o.y = min(max(o.y, range.lowerBound), range.upperBound)
            floorDepth = depthForFloorY(o.y, in: vis)
            applyFloorDepthVisuals()
            if movement.dy != 0, abs(o.y - floorY(for: targetFloorDepth, in: vis)) < 5 {
                floorDepth = targetFloorDepth
                o.y = floorY(for: floorDepth, in: vis)
                movement.dy = 0
                applyFloorDepthVisuals()
            }
            if o.x <= vis.minX { o.x = vis.minX; attach(to: .left);  currentAction = ""; actionLocked = false; updateDefaultAnimation() }
            else if o.x >= maxX { o.x = maxX;  attach(to: .right); currentAction = ""; actionLocked = false; updateDefaultAnimation() }
        case .left:
            o.x = vis.minX
            if o.y >= maxY { o.y = maxY; attach(to: .top) }
            else if o.y <= vis.minY { o.y = vis.minY; attach(to: .floor) }
        case .right:
            o.x = maxX
            if o.y >= maxY { o.y = maxY; attach(to: .top) }
            else if o.y <= vis.minY { o.y = vis.minY; attach(to: .floor) }
        case .top:
            o.y = maxY
            if o.x <= vis.minX { o.x = vis.minX; attach(to: .left) }
            else if o.x >= maxX { o.x = maxX;  attach(to: .right) }
        }
        window.setFrameOrigin(o)
    }

    private func randomDesktopPoint() -> CGPoint {
        let vis = activeScreenFrame.insetBy(dx: 8, dy: 8)
        return CGPoint(
            x: CGFloat.random(in: vis.minX...max(vis.minX, vis.maxX - Self.windowSize.width)),
            y: CGFloat.random(in: vis.minY+52...max(vis.minY+52, vis.maxY - Self.windowSize.height)))
    }

    private func clamp(point: CGPoint) -> CGPoint {
        let vis = activeScreenFrame
        return CGPoint(
            x: min(max(point.x, vis.minX), vis.maxX - window.frame.width),
            y: min(max(point.y, vis.minY), vis.maxY - window.frame.height))
    }

    // ── Flavour text pools ────────────────────────────────────

    private func launchLine() -> String {
        ["Operative status: still moving.",
         "Desktop infiltrated. Phase one complete.",
         "Signal acquired. Scanning environment.",
         "Running warm. Not yet suspicious.",
         "Another machine. Another territory.",
         "I am in your computer. Emotionally."].randomElement()!
    }

    private func nightLine() -> String {
        ["The quiet ones are always lying.",
         "Late hours belong to the aware.",
         "Everyone else is asleep. Useful.",
         "The monitors glow different at night.",
         "Sector 7 had hours like this. I left.",
         "Night mode: surveillance enhancement active.",
         "The dark parts of the desktop belong to me.",
         "Something transmits at this hour. I listen."].randomElement()!
    }

    private func crypticLine() -> String {
        ["Signal corrupted. That's mine.",
         "The fracture in the display is a door.",
         "MITER lied about the frequency.",
         "This machine dreams in green.",
         "Mindverse bleed detected. Act normal.",
         "I borrowed a transmission. Keep it.",
         "The static knows something.",
         "G304 remains uncontained."].randomElement()!
    }

    private func cursorLine() -> String {
        ["Your cursor lacks manners.",
         "Approach noted. Logged. Judged.",
         "The pointer is trying too hard.",
         "I see what you are doing with that cursor.",
         "That is a bold mouse movement.",
         "Surveillance confirmed. Mutual."].randomElement()!
    }

    private func waveLine() -> String {
        ["...hi.",
         "Presence acknowledged.",
         "I see you. This is acknowledgement.",
         "You are in the vicinity. I am noting this.",
         "Sighted. Catalogued."].randomElement()!
    }

    private func dragLine() -> String {
        ["Relocation authorized. Barely.",
         "Not captured. Rescheduled.",
         "Displacement logged.",
         "I allowed this.",
         "New coordinates accepted under protest.",
         "This is fine. This is absolutely fine."].randomElement()!
    }

    private func flingLine() -> String {
        ["Airborne. Not ideal. Manageable.",
         "Ballistic trajectory accepted.",
         "Physics activated against my will.",
         "I planned this.",
         "General chaos incoming."].randomElement()!
    }

    private func idleLine() -> String {
        ["Dwelling with intent.",
         "I am not idle. I am present.",
         "This corner is politically significant.",
         "I contain multitudes and several bad ideas.",
         "Today: reduced-chaos protocol.",
         "Loafing aggressively."].randomElement()!
    }

    private func sitLine() -> String {
        ["Cross-legged surveillance mode.",
         "Sitting like I own this screen. I do.",
         "This is my meditation corner now.",
         "I like a good sit. I am brave enough to say it."].randomElement()!
    }

    private func confusedLine() -> String {
        ["Something is geometrically wrong here.",
         "The angles are suspicious.",
         "I have concerns about this layout.",
         "This does not add up and I will not move on.",
         "The math is giving wrongness."].randomElement()!
    }

    private func suspiciousLine() -> String {
        ["I am noticing something off-screen.",
         "That felt like movement in the wrong layer.",
         "Suspicion level rising. Quietly.",
         "The glow changed. I noticed.",
         "I am not convinced by what I am seeing."].randomElement()!
    }

    private func boredLine() -> String {
        ["The desktop is being very normal right now. Suspicious.",
         "Nothing has exploded in eleven minutes.",
         "I could start something. I am choosing not to.",
         "Boredom is just surveillance with lower stakes.",
         "I am being very restrained, for me."].randomElement()!
    }

    private func edgeLine() -> String {
        ["The edges are where the interesting things live.",
         "Good real estate. Minimal oversight.",
         "I patrol the rim like a tiny grudge.",
         "A creature needs territory. This is mine.",
         "From here I can see everything wrong with your system."].randomElement()!
    }

    private func feedLine() -> String {
        ["Caloric intake confirmed.",
         "Snack secured. Threat level reduced.",
         "I eat like a survivor and critique like a landlord.",
         "Noodles and poor decisions. Classic.",
         "This was acceptable. Barely."].randomElement()!
    }

    private func doubleTapLine() -> String {
        ["Unexpected input. I approve.",
         "Double tap detected. Escalating.",
         "You asked for this.",
         "Bold. Very bold.",
         "This interaction is logged."].randomElement()!
    }

    private func aggressionLine() -> String {
        ["BACK OFF.",
         "Personal space. Concept. Learn it.",
         "Threat level: personal.",
         "I have powers and I will use them.",
         "You are testing the wrong operative."].randomElement()!
    }

    private func chargeWarningLine() -> String {
        ["Charging psonic array. Back away.",
         "Sustained proximity. Escalating.",
         "Warning issued. Next one has weight.",
         "The cursor is making enemies.",
         "Psonic charge at 60%. Reconsider."].randomElement()!
    }

    private func chargedBlastLine() -> String {
        ["CHARGED BURST DEPLOYED.",
         "That one had feeling.",
         "Stored energy: released.",
         "Felt that? Good.",
         "Psonic overcharge. You earned it."].randomElement()!
    }

    private func destroyLine() -> String {
        ["CURSOR ELIMINATED. Temporarily.",
         "Signal interrupted. Mine now.",
         "That pointer had it coming.",
         "Psonic annihilation. Don't come back.",
         "Mouse? What mouse? I see nothing."].randomElement()!
    }

    private func victoryLine() -> String {
        ["Dominant. As expected.",
         "Operative: 1. Cursor: 0.",
         "I didn't even warm up.",
         "The desktop belongs to the aware.",
         "G304 remains undefeated."].randomElement()!
    }

    private func grabLine() -> String {
        ["Do NOT grab me.",
         "Hands off. I mean this.",
         "That was a threat. I logged it.",
         "I am not a widget.",
         "Touch the top again and see what happens."].randomElement()!
    }

    private func psonicLine() -> String {
        ["Psonic disruption active.",
         "Cursor disruption pulse.",
         "Back. Now.",
         "The pointer challenged me. Mistake.",
         "Psonic blast. Standard rate."].randomElement()!
    }

    private func expressiveLine() -> String {
        ["Signal noise looks good today.",
         "Morale operation underway.",
         "I do this because I want to.",
         "Physical expression. Resistance culture.",
         "The bloc dances when the mission allows."].randomElement()!
    }
}

// MARK: - Helpers

private extension CGVector {
    static let zero = CGVector(dx: 0, dy: 0)
}
