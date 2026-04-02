import AppKit

private let emphasizedStickyTexts: Set<String> = [
    "GBOY WAS HERE",
    "LONG LIVE THE BLOC",
]

private func noteFont(for text: String, style: NoteStyle) -> NSFont {
    let emphasized = style == .sticky && emphasizedStickyTexts.contains(text.uppercased())
    let size: CGFloat = emphasized ? 14 : 13
    let weight: NSFont.Weight = emphasized ? .bold : .semibold
    return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
}

private func noteWidth(for text: String, style: NoteStyle) -> CGFloat {
    if style == .sticky && emphasizedStickyTexts.contains(text.uppercased()) {
        return 320
    }
    return style == .sticky ? 220 : 210
}

private func noteMinHeight(for text: String, style: NoteStyle) -> CGFloat {
    if style == .sticky && emphasizedStickyTexts.contains(text.uppercased()) {
        return 74
    }
    return 54
}

enum NoteStyle {
    case bubble
    case sticky
    case alert

    var backgroundColor: NSColor {
        switch self {
        case .bubble:
            return NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.16, alpha: 0.94)
        case .sticky:
            return NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.58, alpha: 0.96)
        case .alert:
            return NSColor(calibratedRed: 0.17, green: 0.06, blue: 0.06, alpha: 0.95)
        }
    }

    var borderColor: NSColor {
        switch self {
        case .bubble:
            return NSColor(calibratedRed: 0.95, green: 0.89, blue: 0.66, alpha: 1.0)
        case .sticky:
            return NSColor(calibratedRed: 0.72, green: 0.56, blue: 0.12, alpha: 1.0)
        case .alert:
            return NSColor(calibratedRed: 0.97, green: 0.38, blue: 0.30, alpha: 1.0)
        }
    }

    var textColor: NSColor {
        switch self {
        case .bubble, .alert:
            return .white
        case .sticky:
            return NSColor(calibratedRed: 0.15, green: 0.12, blue: 0.05, alpha: 1.0)
        }
    }
}

final class NoteContentView: NSView {
    let text: String
    let style: NoteStyle

    init(frame frameRect: NSRect, text: String, style: NoteStyle) {
        self.text = text
        self.style = style
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 2
        layer?.backgroundColor = style.backgroundColor.cgColor
        layer?.borderColor = style.borderColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: noteFont(for: text, style: style),
            .foregroundColor: style.textColor,
            .paragraphStyle: paragraph,
        ]

        let inset = bounds.insetBy(dx: 14, dy: 12)
        (text as NSString).draw(in: inset, withAttributes: attrs)
    }
}

final class NoteWindowController: NSWindowController {
    private var closeTimer: Timer?
    private let noteSize: CGSize

    init(text: String, origin: CGPoint, style: NoteStyle, duration: TimeInterval) {
        let constrainedWidth = noteWidth(for: text, style: style)
        let measureRect = NSRect(x: 0, y: 0, width: constrainedWidth - 28, height: 1000)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: noteFont(for: text, style: style),
            .paragraphStyle: paragraph,
        ]
        let measured = (text as NSString).boundingRect(with: measureRect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
        let size = CGSize(width: constrainedWidth, height: max(noteMinHeight(for: text, style: style), ceil(measured.height) + 28))
        self.noteSize = size

        let window = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.contentView = NoteContentView(frame: NSRect(origin: .zero, size: size), text: text, style: style)

        super.init(window: window)

        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 1
        }

        closeTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.closeAnimated()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func nudgeUp(_ offset: CGFloat = 12) {
        guard let window else { return }
        window.setFrameOrigin(CGPoint(x: window.frame.origin.x, y: window.frame.origin.y + offset))
    }

    func closeAnimated() {
        closeTimer?.invalidate()
        closeTimer = nil
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.close()
        })
    }

    var frameSize: CGSize {
        noteSize
    }
}
