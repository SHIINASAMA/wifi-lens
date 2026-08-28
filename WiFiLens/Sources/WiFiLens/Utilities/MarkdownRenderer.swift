//
//  MarkdownRenderer.swift
//  WiFi Lens
//
//  Renders a Markdown subset into a styled NSAttributedString for the What's
//  New sheet: headings, lists, block quotes, code blocks, inline emphasis and
//  links. Tables, thematic breaks, and other block constructs are intentionally
//  not rendered; they are dropped rather than styled.
//
//  This mirrors the technique used by Sparkle's `SUTextViewReleaseNotesView`:
//  Foundation's Markdown parser strips structural newlines and only records
//  inline emphasis plus an `NSPresentationIntent` attribute per block. The
//  system does not automatically re-introduce paragraph breaks, so this type
//  walks the presentation intents and rebuilds a fully styled attributed string
//  with explicit fonts, paragraph styles, list bullets and monospaced code.
//

import AppKit
import Foundation

/// Renders Markdown text into a ready-to-display `NSAttributedString`.
enum MarkdownRenderer {

    /// Renders a Markdown string into a styled attributed string.
    ///
    /// - Parameters:
    ///   - markdown: The Markdown source.
    ///   - pointSize: The base body font size.
    /// - Returns: A styled attributed string. If Markdown parsing fails, falls
    ///   back to a plain-text attributed string so the notes still display.
    static func render(_ markdown: String, pointSize: CGFloat = 13) -> NSAttributedString {
        do {
            let original = try NSAttributedString(markdown: markdown, options: .init(), baseURL: nil)
            return formatMarkdown(original, defaultFontPointSize: pointSize)
        } catch {
            return NSAttributedString(
                string: markdown,
                attributes: [.font: NSFont.systemFont(ofSize: pointSize)]
            )
        }
    }

    // MARK: - Presentation intent handling

    // `NSPresentationIntent` is marked `NS_REFINED_FOR_SWIFT`, so its members are
    // not nameable from Swift. These small helpers read the raw Objective-C
    // properties via Key-Value Coding instead. The underlying class is a public,
    // documented Foundation type, so the keys are stable.

    private static func intValue(_ intent: AnyObject?, _ key: String) -> Int {
        (intent?.value(forKey: key) as? NSNumber)?.intValue ?? 0
    }

    private static func intentKind(_ intent: AnyObject?) -> Int {
        intValue(intent, "intentKind")
    }

    private static func headerLevel(_ intent: AnyObject?) -> Int {
        intValue(intent, "headerLevel")
    }

    private static func indentationLevel(_ intent: AnyObject?) -> Int {
        intValue(intent, "indentationLevel")
    }

    private static func ordinal(_ intent: AnyObject?) -> Int {
        intValue(intent, "ordinal")
    }

    private static func identity(_ intent: AnyObject?) -> Int {
        intValue(intent, "identity")
    }

    private static func parentIntent(_ intent: AnyObject?) -> AnyObject? {
        intent?.value(forKey: "parentIntent") as AnyObject?
    }

    // Raw `NSPresentationIntentKind` values. `NSPresentationIntent` is
    // `NS_REFINED_FOR_SWIFT`, so its kind cannot be named from Swift and the
    // properties must be read via Key-Value Coding. The numeric cases below
    // mirror Foundation's `NSPresentationIntentKind` order in NSAttributedString.h
    // and are SDK-coupled: if that enum changes ordering, this mapping must be
    // updated.
    private enum Kind: Int {
        case paragraph = 0
        case header = 1
        case orderedList = 2
        case unorderedList = 3
        case listItem = 4
        case codeBlock = 5
        case blockQuote = 6
        case thematicBreak = 7
        case table = 8
        case tableHeaderRow = 9
        case tableRow = 10
        case tableCell = 11
    }

    /// Reconstructs block-level formatting over the parsed attributed string.
    private static func formatMarkdown(
        _ original: NSAttributedString,
        defaultFontPointSize pointSize: CGFloat
    ) -> NSAttributedString {
        let paragraphFont = NSFont.systemFont(ofSize: pointSize)
        let monospacedFont = NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)

        let output = NSMutableAttributedString()

        let newline = NSAttributedString(string: "\n")

        // The system bullet glyph renders too small in the system font, so use a
        // font where it reads larger at the same point size (as Sparkle does).
        let bulletFont = NSFont(name: "Menlo Regular", size: pointSize) ?? paragraphFont
        let listBullet = NSAttributedString(string: "•", attributes: [.font: bulletFont])

        let tab = NSAttributedString(string: "\t", attributes: [.font: paragraphFont])

        var visitedListItemIntents = Set<Int>()

        let intentKey = NSAttributedString.Key("NSPresentationIntent")
        original.enumerateAttribute(intentKey, in: NSRange(location: 0, length: original.length)) { value, range, _ in
            guard let intent = value as AnyObject? else { return }

            // Treat every line as its own paragraph so indentation/tabs and spacing
            // are applied per line (important for multi-line code blocks).
            (original.string as NSString).enumerateSubstrings(in: range, options: .byLines) { _, lineRange, _, _ in
                // Re-insert the structural newline Foundation stripped away.
                if output.length > 0 {
                    output.append(newline)
                }

                let fragment = original.attributedSubstring(from: lineRange)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacingBefore = 0
                paragraphStyle.paragraphSpacing = 0
                paragraphStyle.headIndent = 0
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.tabStops = []
                paragraphStyle.defaultTabInterval = paragraphFont.pointSize * 1.38

                let previousLength = output.length

                processFragment(
                    fragment,
                    output: output,
                    paragraphStyle: paragraphStyle,
                    canProcessListItem: true,
                    visitedListItemIntents: &visitedListItemIntents,
                    intent: intent,
                    inputParagraphFont: paragraphFont,
                    monospacedFont: monospacedFont,
                    tab: tab,
                    listBullet: listBullet
                )

                output.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: previousLength, length: output.length - previousLength)
                )
            }
        }

        return output
    }

    /// Recursively applies formatting for an intent and its ancestors.
    ///
    /// This is a Swift port of Sparkle's
    /// `processMarkdownFragmentAttributedString`. It processes parents before the
    /// current intent so list bullets / indentation are emitted ahead of the text.
    private static func processFragment(
        _ fragment: NSAttributedString,
        output: NSMutableAttributedString,
        paragraphStyle: NSMutableParagraphStyle,
        canProcessListItem: Bool,
        visitedListItemIntents: inout Set<Int>,
        intent: AnyObject,
        inputParagraphFont: NSFont,
        monospacedFont: NSFont,
        tab: NSAttributedString,
        listBullet: NSAttributedString
    ) {
        let kind = Kind(rawValue: intentKind(intent)) ?? .paragraph
        var font = inputParagraphFont
        var isListItem = false

        switch kind {
        case .header:
            switch headerLevel(intent) {
            case 1: font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.5)
            case 2: font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.3)
            case 3: font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.2)
            default: font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.1)
            }
        case .listItem:
            isListItem = true
        default:
            break
        }

        if let parent = parentIntent(intent) {
            processFragment(
                fragment,
                output: output,
                paragraphStyle: paragraphStyle,
                canProcessListItem: canProcessListItem && !isListItem,
                visitedListItemIntents: &visitedListItemIntents,
                intent: parent,
                inputParagraphFont: font,
                monospacedFont: monospacedFont,
                tab: tab,
                listBullet: listBullet
            )
        }

        switch kind {
        case .header:
            let spacing = font.pointSize * 0.8
            paragraphStyle.paragraphSpacingBefore += spacing
            paragraphStyle.paragraphSpacing += spacing

            let header = NSMutableAttributedString(attributedString: fragment)
            header.addAttribute(.font, value: font, range: NSRange(location: 0, length: header.length))
            output.append(header)

        case .paragraph:
            let parentIsListItem = parentIntent(intent).map { intentKind($0) == Kind.listItem.rawValue } ?? false
            if parentIsListItem {
                // List-item children keep tighter spacing and no leading gap.
                paragraphStyle.paragraphSpacing += font.pointSize * 0.3
            } else {
                let spacing = font.pointSize * 0.5
                paragraphStyle.paragraphSpacing += spacing
                paragraphStyle.paragraphSpacingBefore += spacing
            }

            let content = NSMutableAttributedString(attributedString: fragment)
            content.addAttribute(.font, value: font, range: NSRange(location: 0, length: content.length))
            output.append(content)

        case .listItem:
            if canProcessListItem {
                let firstLineIndent = CGFloat(indentationLevel(intent)) * font.pointSize * 1.5
                paragraphStyle.firstLineHeadIndent += firstLineIndent

                let defaultTabInterval = paragraphStyle.defaultTabInterval
                paragraphStyle.headIndent += ceil(firstLineIndent / defaultTabInterval) * defaultTabInterval

                let itemIdentity = identity(intent)
                let alreadyVisited = visitedListItemIntents.contains(itemIdentity)
                let usesBullet = parentIntent(intent).map { intentKind($0) == Kind.unorderedList.rawValue } ?? true

                if !alreadyVisited {
                    if usesBullet {
                        output.append(listBullet)
                    } else {
                        let ordinalText = "\(ordinal(intent))."
                        output.append(NSAttributedString(string: ordinalText, attributes: [.font: font]))
                    }
                    visitedListItemIntents.insert(itemIdentity)
                }

                output.append(tab)
            }

        case .blockQuote:
            paragraphStyle.firstLineHeadIndent += paragraphStyle.defaultTabInterval
            paragraphStyle.headIndent += paragraphStyle.defaultTabInterval

        case .codeBlock:
            paragraphStyle.paragraphSpacing += font.pointSize * 0.25
            output.append(tab)
            paragraphStyle.headIndent += paragraphStyle.defaultTabInterval

            let code = NSMutableAttributedString(attributedString: fragment)
            code.addAttributes(
                [.font: monospacedFont, .foregroundColor: NSColor.labelColor],
                range: NSRange(location: 0, length: code.length)
            )
            output.append(code)

        case .orderedList, .unorderedList, .thematicBreak, .table, .tableHeaderRow, .tableRow, .tableCell:
            // Ordered/unordered list containers and tables drive no direct glyphs;
            // thematic breaks and tables are intentionally not rendered (mirrors
            // Sparkle, which found decorations complex with no changelog benefit).
            break
        }
    }
}
