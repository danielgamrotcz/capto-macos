import AppKit
import SwiftUI

struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Napište poznámku..."
    var onCommandReturn: () -> Void = {}
    var onEscape: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NoteNSTextView()
        textView.onCommandReturn = onCommandReturn
        textView.onEscape = onEscape
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator

        // Zero out all internal insets for precise control
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Placeholder label — positioned at (0, 0) matching the text origin
        let placeholderLabel = NSTextField(labelWithString: placeholder)
        placeholderLabel.font = .systemFont(ofSize: 14)
        placeholderLabel.textColor = .tertiaryLabelColor
        placeholderLabel.backgroundColor = .clear
        placeholderLabel.isBezeled = false
        placeholderLabel.isEditable = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
        ])

        context.coordinator.placeholderLabel = placeholderLabel

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor
        weak var textView: NSTextView?
        weak var placeholderLabel: NSTextField?

        init(_ parent: NoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
            placeholderLabel?.isHidden = !textView.string.isEmpty
        }
    }
}

// MARK: - Custom NSTextView for key handling

final class NoteNSTextView: NSTextView {
    var onCommandReturn: () -> Void = {}
    var onEscape: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.keyCode == 36 {
            onCommandReturn()
            return
        }
        if event.keyCode == 53 {
            onEscape()
            return
        }
        super.keyDown(with: event)
    }
}
