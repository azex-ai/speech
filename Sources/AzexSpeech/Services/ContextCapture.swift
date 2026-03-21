import AppKit
import ApplicationServices

enum ContextCapture {
    /// Get text content from the frontmost application window (skips our own app).
    static func captureActiveWindow() -> (appName: String, text: String)? {
        let myPID = ProcessInfo.processInfo.processIdentifier
        // Find the first running app that isn't us and is active/visible
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != myPID && !$0.isTerminated }
            .sorted { ($0.isActive ? 0 : 1) < ($1.isActive ? 0 : 1) }

        guard let frontApp = apps.first else { return nil }
        let pid = frontApp.processIdentifier
        let appName = frontApp.localizedName ?? "Unknown"

        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        var texts: [String] = []
        if let window = focusedWindow {
            // swiftlint:disable:next force_cast
            extractText(from: window as! AXUIElement, texts: &texts, depth: 0, maxDepth: 10, count: 0, maxCount: 300)
        }

        let fullText = texts.joined(separator: "\n")
        return fullText.isEmpty ? nil : (appName, fullText)
    }

    /// Extract proper nouns / technical terms from text
    static func extractHotwords(from text: String) -> [String] {
        var hotwords = Set<String>()

        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            guard cleaned.count >= 2 else { continue }

            // CamelCase (e.g. EigenLayer, DeepSeek)
            if cleaned.first?.isUppercase == true
                && cleaned.contains(where: { $0.isLowercase })
                && cleaned.count > 3
            {
                hotwords.insert(cleaned)
            }

            // $-prefixed (e.g. $SOL, $ETH)
            if cleaned.hasPrefix("$") && cleaned.count > 1 {
                hotwords.insert(cleaned)
            }

            // ALL_CAPS with at least 2 chars (e.g. TVL, DeFi, LLM)
            if cleaned == cleaned.uppercased()
                && cleaned.count >= 2
                && cleaned.rangeOfCharacter(from: .letters) != nil
            {
                hotwords.insert(cleaned)
            }
        }

        return Array(hotwords).sorted()
    }

    // MARK: - Private

    private static func extractText(
        from element: AXUIElement,
        texts: inout [String],
        depth: Int,
        maxDepth: Int,
        count: Int,
        maxCount: Int
    ) {
        guard depth < maxDepth, count < maxCount else { return }

        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        if let str = value as? String, !str.isEmpty, str.count >= 3 {
            texts.append(str)
        }

        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        if let str = title as? String, !str.isEmpty, str.count >= 3 {
            texts.append(str)
        }

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childArray = children as? [AXUIElement] {
            var currentCount = count
            for child in childArray {
                guard currentCount < maxCount else { break }
                extractText(
                    from: child, texts: &texts, depth: depth + 1,
                    maxDepth: maxDepth, count: currentCount, maxCount: maxCount
                )
                currentCount += 1
            }
        }
    }
}
