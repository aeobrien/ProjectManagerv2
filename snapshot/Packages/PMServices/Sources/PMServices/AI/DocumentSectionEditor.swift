import Foundation

/// Finds and replaces markdown sections by header text.
public struct DocumentSectionEditor: Sendable {

    public init() {}

    /// Locate a section by its header text (case-insensitive, any `#` level).
    /// Returns the header line text and the range covering the entire section
    /// (from the start of the header line through to the next header of equal/higher level, or EOF).
    public func findSection(
        in content: String,
        headerText: String
    ) -> (headerLine: String, range: Range<String.Index>)? {
        let lines = content.components(separatedBy: "\n")
        let needle = headerText.trimmingCharacters(in: .whitespaces).lowercased()

        var sectionStart: String.Index?
        var sectionHeaderLine: String = ""
        var sectionLevel: Int = 0

        var currentIndex = content.startIndex

        for (i, line) in lines.enumerated() {
            let lineStart = currentIndex
            // Advance currentIndex past this line (and its newline, if present)
            let lineEnd: String.Index
            if i < lines.count - 1 {
                lineEnd = content.index(lineStart, offsetBy: line.count + 1) // +1 for \n
            } else {
                lineEnd = content.index(lineStart, offsetBy: line.count)
            }

            if let (level, text) = parseHeader(line) {
                if sectionStart != nil {
                    // We found the next header of equal or higher level — section ends here
                    if level <= sectionLevel {
                        return (sectionHeaderLine, sectionStart!..<lineStart)
                    }
                } else if text.lowercased() == needle {
                    sectionStart = lineStart
                    sectionHeaderLine = line
                    sectionLevel = level
                }
            }

            currentIndex = lineEnd
        }

        // If we found the section but hit EOF, it extends to the end
        if let start = sectionStart {
            return (sectionHeaderLine, start..<content.endIndex)
        }

        return nil
    }

    /// Replace a section's content (including its header line) with new content.
    /// Returns the modified document, or nil if the section was not found.
    public func replaceSection(
        in content: String,
        headerText: String,
        newContent: String
    ) -> String? {
        guard let (_, range) = findSection(in: content, headerText: headerText) else {
            return nil
        }

        var result = content
        // Ensure newContent ends with a newline if the replaced range wasn't at EOF
        var replacement = newContent
        if range.upperBound != content.endIndex && !replacement.hasSuffix("\n") {
            replacement += "\n"
        }
        result.replaceSubrange(range, with: replacement)
        return result
    }

    // MARK: - Private

    /// Parse a markdown header line, returning (level, text) or nil.
    private func parseHeader(_ line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        for ch in trimmed {
            if ch == "#" { level += 1 } else { break }
        }
        guard level > 0 else { return nil }
        let rest = trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }
        return (level, rest)
    }
}

/// Computes a line-level diff between two strings.
public struct DiffComputer: Sendable {

    public init() {}

    /// A tagged diff line.
    public struct DiffLine: Sendable, Identifiable {
        public let id = UUID()
        public enum Kind: Sendable { case context, removed, added }
        public let kind: Kind
        public let text: String

        public init(kind: Kind, text: String) {
            self.kind = kind
            self.text = text
        }
    }

    /// Compute a line-level diff with surrounding context lines.
    public func computeDiff(old: String, new: String, contextLines: Int = 3) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        // Use CollectionDifference for an ordered edit script
        let diff = newLines.difference(from: oldLines)

        // Build a set of old-line indices that were removed and new-line indices that were inserted
        var removedIndices = Set<Int>()
        var insertedIndices = Set<Int>()

        for change in diff {
            switch change {
            case .remove(let offset, _, _):
                removedIndices.insert(offset)
            case .insert(let offset, _, _):
                insertedIndices.insert(offset)
            }
        }

        // Walk through the old and new arrays together to build the output.
        // We use a simple approach: mark changed lines, then include context around them.
        struct TaggedLine {
            let kind: DiffLine.Kind
            let text: String
            let isChange: Bool
        }

        var allTagged: [TaggedLine] = []

        // Rebuild: walk old array, emitting removed/context; interleave insertions
        var newIdx = 0
        for oldIdx in 0..<oldLines.count {
            // Emit any new-only lines that come before the current alignment point
            while newIdx < newLines.count && insertedIndices.contains(newIdx) {
                allTagged.append(TaggedLine(kind: .added, text: newLines[newIdx], isChange: true))
                newIdx += 1
            }

            if removedIndices.contains(oldIdx) {
                allTagged.append(TaggedLine(kind: .removed, text: oldLines[oldIdx], isChange: true))
            } else {
                allTagged.append(TaggedLine(kind: .context, text: oldLines[oldIdx], isChange: false))
                newIdx += 1
            }
        }
        // Emit any remaining insertions at the end
        while newIdx < newLines.count {
            allTagged.append(TaggedLine(kind: .added, text: newLines[newIdx], isChange: true))
            newIdx += 1
        }

        // Now filter to only show context lines within `contextLines` of a change
        let changeIndices = Set(allTagged.indices.filter { allTagged[$0].isChange })
        guard !changeIndices.isEmpty else {
            // No changes — return empty
            return []
        }

        var visibleIndices = Set<Int>()
        for ci in changeIndices {
            let lo = max(0, ci - contextLines)
            let hi = min(allTagged.count - 1, ci + contextLines)
            for i in lo...hi {
                visibleIndices.insert(i)
            }
        }

        return visibleIndices.sorted().map { i in
            DiffLine(kind: allTagged[i].kind, text: allTagged[i].text)
        }
    }
}
