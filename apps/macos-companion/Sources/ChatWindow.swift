import AppKit

final class ChatWindowController: NSWindowController, NSTextFieldDelegate {
    var onSend: ((String) -> Void)?

    private let transcriptView = NSTextView(frame: .zero)
    private let inputField = NSTextField(frame: .zero)
    private let sendButton = NSButton(title: "Send", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "Ready")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Gboy Chat"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndFocus() {
        window?.makeKeyAndOrderFront(nil)
        window?.displayIfNeeded()
        refreshTranscriptLayout(scrollToBottom: true)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(inputField)
    }

    func loadHistory(_ turns: [ChatTurn]) {
        transcriptView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        turns.forEach { turn in
            switch turn.role.lowercased() {
            case "user":
                appendUser(turn.content)
            case "assistant":
                appendAssistant(turn.content)
            default:
                appendSystem(turn.content)
            }
        }
        refreshTranscriptLayout(scrollToBottom: true)
    }

    func appendUser(_ text: String) {
        appendLine(prefix: "YOU", text: text, color: NSColor(calibratedRed: 0.83, green: 0.92, blue: 0.99, alpha: 1.0))
    }

    func appendAssistant(_ text: String) {
        appendLine(prefix: "GBOY", text: text, color: NSColor(calibratedRed: 0.91, green: 0.86, blue: 0.62, alpha: 1.0))
    }

    func appendSystem(_ text: String) {
        appendLine(prefix: "SYS", text: text, color: NSColor(calibratedRed: 0.64, green: 0.84, blue: 0.72, alpha: 1.0))
    }

    func setThinking(_ thinking: Bool, detail: String? = nil) {
        let label = detail ?? (thinking ? "Thinking..." : "Ready")
        statusLabel.stringValue = label
        sendButton.isEnabled = !thinking
        inputField.isEnabled = !thinking
    }

    @objc private func sendMessage() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.stringValue = ""
        onSend?(text)
    }

    func control(_ control: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            sendMessage()
            return true
        }
        return false
    }

    private func configureWindow() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1.0).cgColor

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        transcriptView.translatesAutoresizingMaskIntoConstraints = false
        transcriptView.isEditable = false
        transcriptView.isSelectable = true
        transcriptView.isRichText = false
        transcriptView.drawsBackground = true
        transcriptView.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.14, alpha: 1.0)
        transcriptView.textColor = .white
        transcriptView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        transcriptView.textContainerInset = NSSize(width: 10, height: 12)
        transcriptView.minSize = NSSize(width: 0, height: 0)
        transcriptView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        transcriptView.isHorizontallyResizable = false
        transcriptView.isVerticallyResizable = true
        transcriptView.autoresizingMask = [.width]
        transcriptView.textContainer?.widthTracksTextView = true
        transcriptView.textContainer?.heightTracksTextView = false
        transcriptView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = transcriptView

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = NSColor(calibratedRed: 0.72, green: 0.79, blue: 0.92, alpha: 1.0)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.delegate = self
        inputField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        inputField.placeholderString = "Type to Gboy..."
        inputField.focusRingType = .none
        inputField.bezelStyle = .roundedBezel
        inputField.target = self
        inputField.action = #selector(sendMessage)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.bezelStyle = .rounded
        sendButton.target = self
        sendButton.action = #selector(sendMessage)

        contentView.addSubview(scrollView)
        contentView.addSubview(statusLabel)
        contentView.addSubview(inputField)
        contentView.addSubview(sendButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            statusLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            inputField.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            inputField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            sendButton.leadingAnchor.constraint(equalTo: inputField.trailingAnchor, constant: 10),
            sendButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 82),

            scrollView.bottomAnchor.constraint(equalTo: inputField.topAnchor, constant: -48)
        ])
    }

    private func appendLine(prefix: String, text: String, color: NSColor) {
        let content = NSMutableAttributedString()
        let header = NSAttributedString(
            string: "\(prefix) ",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
                .foregroundColor: color
            ]
        )
        let body = NSAttributedString(
            string: text + "\n\n",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white
            ]
        )
        content.append(header)
        content.append(body)

        transcriptView.textStorage?.append(content)
        refreshTranscriptLayout(scrollToBottom: true)
    }

    private func refreshTranscriptLayout(scrollToBottom: Bool) {
        guard let textContainer = transcriptView.textContainer,
              let layoutManager = transcriptView.layoutManager else { return }
        layoutManager.ensureLayout(for: textContainer)
        transcriptView.invalidateIntrinsicContentSize()
        transcriptView.layoutSubtreeIfNeeded()
        transcriptView.enclosingScrollView?.layoutSubtreeIfNeeded()
        if scrollToBottom {
            transcriptView.scrollToEndOfDocument(nil)
        }
    }
}
