import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Export Service

@MainActor
enum ExportService {

    // MARK: - ZIP

    static func exportAsImpulse(_ project: WritingProject) {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("export.zip.title", comment: "Save panel title for ZIP export")
        panel.nameFieldStringValue = sanitize(project.title)
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, var url = panel.url else { return }

        // Ensure .zip extension
        if url.pathExtension.lowercased() != "zip" {
            url = url.deletingPathExtension().appendingPathExtension("zip")
        }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            let root = tmp.appendingPathComponent(sanitize(project.title))
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

            switch project.type {
            case .book, .visualNovel:
                try writeBookContents(project, into: root)
            case .screenplay:
                try writeScreenplayContents(project, into: root)
            }

            try zipDirectory(tmp, to: url)
        } catch {
            showError(error)
        }

        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - TXT

    static func exportAsTXT(_ project: WritingProject) {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("export.txt.title", comment: "Save panel title for TXT export")
        panel.nameFieldStringValue = sanitize(project.title)
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let text: String
        switch project.type {
        case .book, .visualNovel:
            text = bookPlainText(project)
        case .screenplay:
            text = screenplayPlainText(project)
        }

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showError(error)
        }
    }

    // MARK: - DOCX (plain text inside .docx container)

    static func exportAsDOCX(_ project: WritingProject) {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("export.docx.title", comment: "Save panel title for DOCX export")
        panel.nameFieldStringValue = sanitize(project.title)
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true

        guard panel.runModal() == .OK, var url = panel.url else { return }

        if url.pathExtension.lowercased() != "docx" {
            url = url.deletingPathExtension().appendingPathExtension("docx")
        }

        let text: String
        switch project.type {
        case .book, .visualNovel:
            text = bookChaptersOnlyText(project)
        case .screenplay:
            text = screenplayScenesOnlyText(project)
        }

        do {
            let docx = try buildDocx(text: text)
            try docx.write(to: url)
        } catch {
            showError(error)
        }
    }

    // MARK: - Fountain (screenplay only)

    static func exportAsFountain(_ project: WritingProject) {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("export.fountain.title", comment: "Save panel title for Fountain export")
        panel.nameFieldStringValue = sanitize(project.title)
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true

        guard panel.runModal() == .OK, var url = panel.url else { return }

        if url.pathExtension.lowercased() != "fountain" {
            url = url.deletingPathExtension().appendingPathExtension("fountain")
        }

        let text = screenplayFountainText(project)

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showError(error)
        }
    }

    // MARK: - Book file layout

    private static func writeBookContents(_ project: WritingProject, into root: URL) throws {
        let fm = FileManager.default

        // Chapters folder
        if !(project.chapters ?? []).isEmpty {
            let chaptersDir = root.appendingPathComponent(NSLocalizedString("book.chapters.folder", comment: "Chapters folder name"))
            try fm.createDirectory(at: chaptersDir, withIntermediateDirectories: true)

            let sorted = (project.chapters ?? []).sorted { $0.orderIndex < $1.orderIndex }
            for (i, chapter) in sorted.enumerated() {
                let name = "\(String(format: "%02d", i + 1)). \(sanitize(chapter.title)).txt"
                let file = chaptersDir.appendingPathComponent(name)
                try chapter.text.write(to: file, atomically: true, encoding: .utf8)
            }
        }

        // Characters
        if !(project.characters ?? []).isEmpty {
            let text = (project.characters ?? [])
                .sorted { $0.name < $1.name }
                .map { characterBlock($0) }
                .joined(separator: "\n\n")
            try text.write(to: root.appendingPathComponent(NSLocalizedString("book.characters.file", comment: "Characters file name with extension")),
                           atomically: true, encoding: .utf8)
        }

        // World building
        if let wb = project.worldBuilding {
            if !(wb.locations ?? []).isEmpty {
                let text = (wb.locations ?? [])
                    .sorted { $0.name < $1.name }
                    .map { locationBlock($0) }
                    .joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent(NSLocalizedString("book.locations.file", comment: "Locations file name with extension")),
                               atomically: true, encoding: .utf8)
            }

            if !(wb.resources ?? []).isEmpty {
                let text = (wb.resources ?? []).map { resourceBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent(NSLocalizedString("book.resources.file", comment: "Resources file name with extension")),
                               atomically: true, encoding: .utf8)
            }

            if !(wb.metaphysics ?? []).isEmpty {
                let text = (wb.metaphysics ?? []).map { metaphysicsBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent(NSLocalizedString("book.metaphysics.file", comment: "Metaphysics file name with extension")),
                               atomically: true, encoding: .utf8)
            }

            if !(wb.concepts ?? []).isEmpty {
                let text = (wb.concepts ?? []).map { conceptBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent(NSLocalizedString("book.concepts.file", comment: "Concepts file name with extension")),
                               atomically: true, encoding: .utf8)
            }

            if !(wb.structures ?? []).isEmpty {
                let text = (wb.structures ?? []).map { structureBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent(NSLocalizedString("book.structures.file", comment: "Structures file name with extension")),
                               atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Screenplay file layout

    private static func writeScreenplayContents(_ project: WritingProject, into root: URL) throws {
        let fm = FileManager.default

        // Scenes folder
        if !(project.scenes ?? []).isEmpty {
            let scenesDir = root.appendingPathComponent(NSLocalizedString("screenplay.scenes.folder", comment: "Scenes folder name"))
            try fm.createDirectory(at: scenesDir, withIntermediateDirectories: true)

            let sorted = (project.scenes ?? []).sorted { $0.orderIndex < $1.orderIndex }
            for (i, scene) in sorted.enumerated() {
                let prefix = String(format: "%02d", i + 1)
                let sceneTitle = sanitize(scene.title)

                // Role names for this scene
                let roleNames = (scene.roles ?? []).map { $0.name }.filter { !$0.isEmpty }

                for variation in scene.variations {
                    let varTitle = sanitize(variation.title)
                    let name = "\(prefix). \(sceneTitle).\(varTitle).txt"
                    let file = scenesDir.appendingPathComponent(name)

                    var content = ""
                    if !roleNames.isEmpty {
                        let rolesLine = String(
                            format: NSLocalizedString("screenplay.roles.line", comment: "Roles line: 'Роли: %@'"),
                            roleNames.joined(separator: ", ")
                        )
                        content += rolesLine + "\n\n"
                    }
                    content += variation.text
                    try content.write(to: file, atomically: true, encoding: .utf8)
                }
            }
        }

        // Roles
        if !(project.screenRoles ?? []).isEmpty {
            let text = (project.screenRoles ?? [])
                .sorted { $0.name < $1.name }
                .map { screenRoleBlock($0) }
                .joined(separator: "\n\n")
            try text.write(to: root.appendingPathComponent(NSLocalizedString("screenplay.roles.file", comment: "Roles file name with extension")),
                           atomically: true, encoding: .utf8)
        }
    }

    // MARK: - DOCX-only text helpers (chapters / scenes only)

    private static func bookChaptersOnlyText(_ project: WritingProject) -> String {
        let sorted = (project.chapters ?? []).sorted { $0.orderIndex < $1.orderIndex }
        return sorted.enumerated().map { i, chapter in
            let header = String(
                format: NSLocalizedString("book.chapter.header", comment: "Chapter header 'Глава %d: %@'"),
                i + 1, chapter.title
            )
            return "\(header)\n\n\(chapter.text)"
        }.joined(separator: "\n\n---\n\n")
    }

    private static func screenplayScenesOnlyText(_ project: WritingProject) -> String {
        let sorted = (project.scenes ?? []).sorted { $0.orderIndex < $1.orderIndex }
        return sorted.enumerated().map { i, scene in
            let vars = scene.variations
            let sceneTitle = String(
                format: NSLocalizedString("screenplay.scene.header.title", comment: "Scene header 'Сцена %d: %@'"),
                i + 1, scene.title
            )
            if vars.count == 1 {
                return "\(sceneTitle)\n\n\(vars[0].text)"
            } else {
                let variationBlocks = vars.map { v in
                    "— \(v.title) —\n\n\(v.text)"
                }.joined(separator: "\n\n")
                return "\(sceneTitle)\n\n\(variationBlocks)"
            }
        }.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Plain text helpers (for TXT / DOCX)

    private static func bookPlainText(_ project: WritingProject) -> String {
        var parts: [String] = []

        let sorted = (project.chapters ?? []).sorted { $0.orderIndex < $1.orderIndex }
        for (i, chapter) in sorted.enumerated() {
            parts.append(String(format: NSLocalizedString("book.chapter.header", comment: "Chapter header 'Глава %d: %@'"), i + 1, chapter.title) + "\n\n\(chapter.text)")
        }

        if !(project.characters ?? []).isEmpty {
            parts.append(NSLocalizedString("book.section.characters", comment: "") + "\n\n" +
                (project.characters ?? []).sorted { $0.name < $1.name }
                    .map { characterBlock($0) }.joined(separator: "\n\n"))
        }

        if let wb = project.worldBuilding {
            if !(wb.locations ?? []).isEmpty {
                parts.append(NSLocalizedString("book.section.locations", comment: "") + "\n\n" +
                    (wb.locations ?? []).sorted { $0.name < $1.name }
                        .map { locationBlock($0) }.joined(separator: "\n\n"))
            }
            if !(wb.resources ?? []).isEmpty {
                parts.append(NSLocalizedString("book.section.resources", comment: "") + "\n\n" +
                    (wb.resources ?? []).map { resourceBlock($0) }.joined(separator: "\n\n"))
            }
            if !(wb.metaphysics ?? []).isEmpty {
                parts.append(NSLocalizedString("book.section.metaphysics", comment: "") + "\n\n" +
                    (wb.metaphysics ?? []).map { metaphysicsBlock($0) }.joined(separator: "\n\n"))
            }
            if !(wb.concepts ?? []).isEmpty {
                parts.append(NSLocalizedString("book.section.concepts", comment: "") + "\n\n" +
                    (wb.concepts ?? []).map { conceptBlock($0) }.joined(separator: "\n\n"))
            }
            if !(wb.structures ?? []).isEmpty {
                parts.append(NSLocalizedString("book.section.structures", comment: "") + "\n\n" +
                    (wb.structures ?? []).map { structureBlock($0) }.joined(separator: "\n\n"))
            }
        }

        return parts.joined(separator: "\n\n---\n\n")
    }

    private static func screenplayPlainText(_ project: WritingProject) -> String {
        var parts: [String] = []

        let sorted = (project.scenes ?? []).sorted { $0.orderIndex < $1.orderIndex }
        for (i, scene) in sorted.enumerated() {
            let roleNames = (scene.roles ?? []).map { $0.name }.filter { !$0.isEmpty }
            for variation in scene.variations {
                var block = String(
                    format: NSLocalizedString("screenplay.scene.header", comment: "Scene header 'Сцена %d: %@ — %@'"),
                    i + 1, scene.title, variation.title
                )
                if !roleNames.isEmpty {
                    block += "\n" + String(
                        format: NSLocalizedString("screenplay.roles.line", comment: "Roles line: 'Роли: %@'"),
                        roleNames.joined(separator: ", ")
                    )
                }
                block += "\n\n\(variation.text)"
                parts.append(block)
            }
        }

        if !(project.screenRoles ?? []).isEmpty {
            parts.append(NSLocalizedString("screenplay.section.roles", comment: "") + "\n\n" +
                (project.screenRoles ?? []).sorted { $0.name < $1.name }
                    .map { screenRoleBlock($0) }.joined(separator: "\n\n"))
        }

        return parts.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Fountain

    private static func screenplayFountainText(_ project: WritingProject) -> String {
        var lines: [String] = []

        lines.append("Title: \(project.title)")
        lines.append("")

        let sorted = (project.scenes ?? []).sorted { $0.orderIndex < $1.orderIndex }
        for (i, scene) in sorted.enumerated() {
            // Fountain scene heading
            lines.append("INT. \(scene.title.uppercased()) - DAY")
            lines.append("")

            let roleNames = (scene.roles ?? []).map { $0.name }.filter { !$0.isEmpty }
            if !roleNames.isEmpty {
                lines.append(String(format: NSLocalizedString("screenplay.fountain.roles.comment", comment: "Fountain roles comment '/* Роли: %@ */'"), roleNames.joined(separator: ", ")))
                lines.append("")
            }

            let vars = scene.variations
            if vars.count == 1 {
                if !vars[0].text.isEmpty {
                    lines.append(vars[0].text)
                    lines.append("")
                }
            } else {
                for variation in vars {
                    lines.append("/* \(variation.title) */")
                    lines.append("")
                    if !variation.text.isEmpty {
                        lines.append(variation.text)
                        lines.append("")
                    }
                }
            }

            if i < sorted.count - 1 {
                lines.append("===")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Content block builders

    private static func characterBlock(_ c: Character) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("character.name", comment: "Name: %@"), c.name))
        if let age = c.age { lines.append(String(format: NSLocalizedString("character.age", comment: "Age: %d"), age)) }
        if !c.role.isEmpty       { lines.append(String(format: NSLocalizedString("character.role", comment: "Role: %@"), c.role)) }
        if !c.appearance.isEmpty { lines.append(String(format: NSLocalizedString("character.appearance", comment: "Appearance: %@"), c.appearance)) }
        if !c.biography.isEmpty  { lines.append(String(format: NSLocalizedString("character.biography", comment: "Biography: %@"), c.biography)) }
        if !c.abilities.isEmpty  { lines.append(String(format: NSLocalizedString("character.abilities", comment: "Abilities: %@"), c.abilities)) }
        if !c.plotRole.isEmpty   { lines.append(String(format: NSLocalizedString("character.plotRole", comment: "Plot role: %@"), c.plotRole)) }
        return lines.joined(separator: "\n")
    }

    private static func screenRoleBlock(_ r: ScreenRole) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("character.name", comment: "Name: %@"), r.name))
        if !r.role.isEmpty       { lines.append(String(format: NSLocalizedString("character.role", comment: "Role: %@"), r.role)) }
        if !r.appearance.isEmpty { lines.append(String(format: NSLocalizedString("character.appearance", comment: "Appearance: %@"), r.appearance)) }
        if !r.biography.isEmpty  { lines.append(String(format: NSLocalizedString("character.biography", comment: "Biography: %@"), r.biography)) }
        if !r.abilities.isEmpty  { lines.append(String(format: NSLocalizedString("character.abilities", comment: "Abilities: %@"), r.abilities)) }
        if !r.plotRole.isEmpty   { lines.append(String(format: NSLocalizedString("character.plotRole", comment: "Plot role: %@"), r.plotRole)) }
        return lines.joined(separator: "\n")
    }

    private static func locationBlock(_ l: WorldLocation) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("location.name", comment: "Name: %@"), l.name))
        if !l.type.isEmpty             { lines.append(String(format: NSLocalizedString("location.type", comment: "Type: %@"), l.type)) }
        if !l.shortDescription.isEmpty { lines.append(String(format: NSLocalizedString("location.shortDescription", comment: "Description: %@"), l.shortDescription)) }
        if !l.atmosphere.isEmpty       { lines.append(String(format: NSLocalizedString("location.atmosphere", comment: "Atmosphere: %@"), l.atmosphere)) }
        if !l.geography.isEmpty        { lines.append(String(format: NSLocalizedString("location.geography", comment: "Geography: %@"), l.geography)) }
        if !l.artifacts.isEmpty        { lines.append(String(format: NSLocalizedString("location.artifacts", comment: "Artifacts: %@"), l.artifacts)) }
        if !l.organizations.isEmpty    { lines.append(String(format: NSLocalizedString("location.organizations", comment: "Organizations: %@"), l.organizations)) }
        if !l.info.isEmpty             { lines.append(String(format: NSLocalizedString("location.info", comment: "Additional info: %@"), l.info)) }
        return lines.joined(separator: "\n")
    }

    private static func resourceBlock(_ r: WorldResource) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("resource.name", comment: "Name: %@"), r.name))
        if !r.details.isEmpty     { lines.append(String(format: NSLocalizedString("resource.details", comment: "Details: %@"), r.details)) }
        if !r.rules.isEmpty       { lines.append(String(format: NSLocalizedString("resource.rules", comment: "Rules: %@"), r.rules)) }
        if !r.limitations.isEmpty { lines.append(String(format: NSLocalizedString("resource.limitations", comment: "Limitations: %@"), r.limitations)) }
        return lines.joined(separator: "\n")
    }

    private static func metaphysicsBlock(_ m: MetaphysicsConcept) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("metaphysics.name", comment: "Name: %@"), m.name))
        if !m.details.isEmpty      { lines.append(String(format: NSLocalizedString("metaphysics.details", comment: "Details: %@"), m.details)) }
        if !m.implications.isEmpty { lines.append(String(format: NSLocalizedString("metaphysics.implications", comment: "Implications: %@"), m.implications)) }
        return lines.joined(separator: "\n")
    }

    private static func conceptBlock(_ c: WorldConcept) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("concept.name", comment: "Name: %@"), c.name))
        if !c.category.isEmpty { lines.append(String(format: NSLocalizedString("concept.category", comment: "Category: %@"), c.category)) }
        if !c.details.isEmpty  { lines.append(String(format: NSLocalizedString("concept.details", comment: "Details: %@"), c.details)) }
        return lines.joined(separator: "\n")
    }

    private static func structureBlock(_ s: WorldStructure) -> String {
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("structure.name", comment: "Name: %@"), s.name))
        if !s.type.isEmpty    { lines.append(String(format: NSLocalizedString("structure.type", comment: "Type: %@"), s.type)) }
        if !s.details.isEmpty { lines.append(String(format: NSLocalizedString("structure.details", comment: "Details: %@"), s.details)) }
        return lines.joined(separator: "\n")
    }

    // MARK: - ZIP (pure Swift, stored, no compression)

    private static func zipDirectory(_ sourceRoot: URL, to destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)

        var archive = Data()
        var centralDirectory = Data()
        var entryCount: UInt16 = 0

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            // Relative path inside the archive
            var relativePath = fileURL.path
            let prefix = sourceRoot.deletingLastPathComponent().path + "/"
            if relativePath.hasPrefix(prefix) {
                relativePath = String(relativePath.dropFirst(prefix.count))
            }
            if isDir { relativePath += "/" }

            guard let nameData = relativePath.data(using: .utf8) else { continue }

            let fileData: Data
            if isDir {
                fileData = Data()
            } else {
                fileData = (try? Data(contentsOf: fileURL)) ?? Data()
            }

            let crc = crc32(fileData)
            let offset = UInt32(archive.count)
            let now = dosDateTime()

            // Local file header
            var local = Data()
            local += zipUInt32(0x04034b50)       // signature
            local += zipUInt16(20)               // version needed
            local += zipUInt16(0)                // flags
            local += zipUInt16(0)                // compression (stored)
            local += zipUInt16(now.time)         // mod time
            local += zipUInt16(now.date)         // mod date
            local += zipUInt32(crc)              // crc32
            local += zipUInt32(UInt32(fileData.count)) // compressed size
            local += zipUInt32(UInt32(fileData.count)) // uncompressed size
            local += zipUInt16(UInt16(nameData.count)) // name length
            local += zipUInt16(0)                // extra length
            local += nameData
            local += fileData

            archive += local

            // Central directory entry
            var central = Data()
            central += zipUInt32(0x02014b50)     // signature
            central += zipUInt16(20)             // version made by
            central += zipUInt16(20)             // version needed
            central += zipUInt16(0)              // flags
            central += zipUInt16(0)              // compression
            central += zipUInt16(now.time)
            central += zipUInt16(now.date)
            central += zipUInt32(crc)
            central += zipUInt32(UInt32(fileData.count))
            central += zipUInt32(UInt32(fileData.count))
            central += zipUInt16(UInt16(nameData.count))
            central += zipUInt16(0)              // extra length
            central += zipUInt16(0)              // comment length
            central += zipUInt16(0)              // disk number start
            central += zipUInt16(0)              // internal attributes
            central += zipUInt32(isDir ? 0x10 : 0) // external attributes
            central += zipUInt32(offset)         // local header offset
            central += nameData

            centralDirectory += central
            entryCount += 1
        }

        // End of central directory record
        let cdOffset = UInt32(archive.count)
        let cdSize   = UInt32(centralDirectory.count)
        archive += centralDirectory

        var eocd = Data()
        eocd += zipUInt32(0x06054b50)   // signature
        eocd += zipUInt16(0)            // disk number
        eocd += zipUInt16(0)            // disk with cd
        eocd += zipUInt16(entryCount)   // entries on disk
        eocd += zipUInt16(entryCount)   // total entries
        eocd += zipUInt32(cdSize)       // cd size
        eocd += zipUInt32(cdOffset)     // cd offset
        eocd += zipUInt16(0)            // comment length
        archive += eocd

        try archive.write(to: destination)
    }

    // MARK: - ZIP helpers

    private static func zipUInt16(_ v: UInt16) -> Data {
        var val = v.littleEndian
        return Data(bytes: &val, count: 2)
    }

    private static func zipUInt32(_ v: UInt32) -> Data {
        var val = v.littleEndian
        return Data(bytes: &val, count: 4)
    }

    private static func dosDateTime() -> (time: UInt16, date: UInt16) {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let hour   = c.hour   ?? 0
        let minute = c.minute ?? 0
        let second = c.second ?? 0
        let year   = max(0, (c.year ?? 1980) - 1980)
        let month  = c.month ?? 1
        let day    = c.day   ?? 1
        let time = UInt16((hour << 11) | (minute << 5) | (second / 2))
        let date = UInt16((year  << 9) | (month  << 5) | day)
        return (time, date)
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    // MARK: - DOCX builder (minimal Open XML container)

    private static func buildDocx(text: String) throws -> Data {
        // Build a minimal .docx (Open XML) ZIP directly in memory with exact paths.

        let contentTypes = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
            "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
            "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
            "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
            "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
            "</Types>"

        let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
            "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>" +
            "</Relationships>"

        let wordRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
            "</Relationships>"

        let paragraphs = text.components(separatedBy: "\n").map { line -> String in
            let escaped = line
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<w:p><w:r><w:t xml:space=\"preserve\">\(escaped)</w:t></w:r></w:p>"
        }.joined()

        let document = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
            "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
            "<w:body>" + paragraphs + "<w:sectPr/></w:body></w:document>"

        // Build ZIP in memory with exact entry paths
        let entries: [(path: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels",         Data(rels.utf8)),
            ("word/_rels/document.xml.rels", Data(wordRels.utf8)),
            ("word/document.xml",   Data(document.utf8)),
        ]

        return buildZipInMemory(entries: entries)
    }

    private static func buildZipInMemory(entries: [(path: String, data: Data)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        let now = dosDateTime()

        for entry in entries {
            guard let nameData = entry.path.data(using: .utf8) else { continue }
            let fileData = entry.data
            let crc = crc32(fileData)
            let offset = UInt32(archive.count)

            var local = Data()
            local += zipUInt32(0x04034b50)
            local += zipUInt16(20)
            local += zipUInt16(0)
            local += zipUInt16(0)
            local += zipUInt16(now.time)
            local += zipUInt16(now.date)
            local += zipUInt32(crc)
            local += zipUInt32(UInt32(fileData.count))
            local += zipUInt32(UInt32(fileData.count))
            local += zipUInt16(UInt16(nameData.count))
            local += zipUInt16(0)
            local += nameData
            local += fileData
            archive += local

            var central = Data()
            central += zipUInt32(0x02014b50)
            central += zipUInt16(20)
            central += zipUInt16(20)
            central += zipUInt16(0)
            central += zipUInt16(0)
            central += zipUInt16(now.time)
            central += zipUInt16(now.date)
            central += zipUInt32(crc)
            central += zipUInt32(UInt32(fileData.count))
            central += zipUInt32(UInt32(fileData.count))
            central += zipUInt16(UInt16(nameData.count))
            central += zipUInt16(0)
            central += zipUInt16(0)
            central += zipUInt16(0)
            central += zipUInt16(0)
            central += zipUInt32(0)
            central += zipUInt32(offset)
            central += nameData
            centralDirectory += central
        }

        let cdOffset = UInt32(archive.count)
        let cdSize   = UInt32(centralDirectory.count)
        let entryCount = UInt16(entries.count)
        archive += centralDirectory

        var eocd = Data()
        eocd += zipUInt32(0x06054b50)
        eocd += zipUInt16(0)
        eocd += zipUInt16(0)
        eocd += zipUInt16(entryCount)
        eocd += zipUInt16(entryCount)
        eocd += zipUInt32(cdSize)
        eocd += zipUInt32(cdOffset)
        eocd += zipUInt16(0)
        archive += eocd

        return archive
    }

    // MARK: - Helpers

    private static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("export.error.title", comment: "Export error title")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
