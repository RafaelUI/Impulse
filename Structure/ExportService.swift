import Foundation
import AppKit

// MARK: - Export Service

enum ExportService {

    // MARK: - ZIP (.impulse)

    static func exportAsImpulse(_ project: WritingProject) {
        let panel = NSSavePanel()
        panel.title = "Экспортировать как .impulse"
        panel.nameFieldStringValue = sanitize(project.title)
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, var url = panel.url else { return }

        // Ensure .impulse extension
        if url.pathExtension.lowercased() != "impulse" {
            url = url.deletingPathExtension().appendingPathExtension("impulse")
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
        panel.title = "Экспортировать как TXT"
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
        panel.title = "Экспортировать как DOCX"
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
            text = bookPlainText(project)
        case .screenplay:
            text = screenplayPlainText(project)
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
        panel.title = "Экспортировать как Fountain"
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
        if !project.chapters.isEmpty {
            let chaptersDir = root.appendingPathComponent("Главы")
            try fm.createDirectory(at: chaptersDir, withIntermediateDirectories: true)

            let sorted = project.chapters.sorted { $0.orderIndex < $1.orderIndex }
            for (i, chapter) in sorted.enumerated() {
                let name = "\(String(format: "%02d", i + 1)). \(sanitize(chapter.title)).txt"
                let file = chaptersDir.appendingPathComponent(name)
                try chapter.text.write(to: file, atomically: true, encoding: .utf8)
            }
        }

        // Characters
        if !project.characters.isEmpty {
            let text = project.characters
                .sorted { $0.name < $1.name }
                .map { characterBlock($0) }
                .joined(separator: "\n\n")
            try text.write(to: root.appendingPathComponent("Персонажи.txt"),
                           atomically: true, encoding: .utf8)
        }

        // World building
        if let wb = project.worldBuilding {
            if !wb.locations.isEmpty {
                let text = wb.locations
                    .sorted { $0.name < $1.name }
                    .map { locationBlock($0) }
                    .joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent("Локации.txt"),
                               atomically: true, encoding: .utf8)
            }

            if !wb.resources.isEmpty {
                let text = wb.resources.map { resourceBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent("Ресурсы.txt"),
                               atomically: true, encoding: .utf8)
            }

            if !wb.metaphysics.isEmpty {
                let text = wb.metaphysics.map { metaphysicsBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent("Метафизика.txt"),
                               atomically: true, encoding: .utf8)
            }

            if !wb.concepts.isEmpty {
                let text = wb.concepts.map { conceptBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent("Концепции.txt"),
                               atomically: true, encoding: .utf8)
            }

            if !wb.structures.isEmpty {
                let text = wb.structures.map { structureBlock($0) }.joined(separator: "\n\n")
                try text.write(to: root.appendingPathComponent("Структуры.txt"),
                               atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Screenplay file layout

    private static func writeScreenplayContents(_ project: WritingProject, into root: URL) throws {
        let fm = FileManager.default

        // Scenes folder
        if !project.scenes.isEmpty {
            let scenesDir = root.appendingPathComponent("Сцены")
            try fm.createDirectory(at: scenesDir, withIntermediateDirectories: true)

            let sorted = project.scenes.sorted { $0.orderIndex < $1.orderIndex }
            for (i, scene) in sorted.enumerated() {
                let prefix = String(format: "%02d", i + 1)
                let sceneTitle = sanitize(scene.title)

                // Role names for this scene
                let roleNames = scene.roles.map { $0.name }.filter { !$0.isEmpty }

                for variation in scene.variations {
                    let varTitle = sanitize(variation.title)
                    let name = "\(prefix). \(sceneTitle).\(varTitle).txt"
                    let file = scenesDir.appendingPathComponent(name)

                    var content = ""
                    if !roleNames.isEmpty {
                        content += "Роли: \(roleNames.joined(separator: ", "))\n\n"
                    }
                    content += variation.text
                    try content.write(to: file, atomically: true, encoding: .utf8)
                }
            }
        }

        // Roles
        if !project.screenRoles.isEmpty {
            let text = project.screenRoles
                .sorted { $0.name < $1.name }
                .map { screenRoleBlock($0) }
                .joined(separator: "\n\n")
            try text.write(to: root.appendingPathComponent("Роли.txt"),
                           atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Plain text helpers (for TXT / DOCX)

    private static func bookPlainText(_ project: WritingProject) -> String {
        var parts: [String] = []

        let sorted = project.chapters.sorted { $0.orderIndex < $1.orderIndex }
        for (i, chapter) in sorted.enumerated() {
            parts.append("Глава \(i + 1): \(chapter.title)\n\n\(chapter.text)")
        }

        if !project.characters.isEmpty {
            parts.append("=== ПЕРСОНАЖИ ===\n\n" +
                project.characters.sorted { $0.name < $1.name }
                    .map { characterBlock($0) }.joined(separator: "\n\n"))
        }

        if let wb = project.worldBuilding {
            if !wb.locations.isEmpty {
                parts.append("=== ЛОКАЦИИ ===\n\n" +
                    wb.locations.sorted { $0.name < $1.name }
                        .map { locationBlock($0) }.joined(separator: "\n\n"))
            }
            if !wb.resources.isEmpty {
                parts.append("=== РЕСУРСЫ ===\n\n" +
                    wb.resources.map { resourceBlock($0) }.joined(separator: "\n\n"))
            }
            if !wb.metaphysics.isEmpty {
                parts.append("=== МЕТАФИЗИКА ===\n\n" +
                    wb.metaphysics.map { metaphysicsBlock($0) }.joined(separator: "\n\n"))
            }
            if !wb.concepts.isEmpty {
                parts.append("=== КОНЦЕПЦИИ ===\n\n" +
                    wb.concepts.map { conceptBlock($0) }.joined(separator: "\n\n"))
            }
            if !wb.structures.isEmpty {
                parts.append("=== СТРУКТУРЫ ===\n\n" +
                    wb.structures.map { structureBlock($0) }.joined(separator: "\n\n"))
            }
        }

        return parts.joined(separator: "\n\n---\n\n")
    }

    private static func screenplayPlainText(_ project: WritingProject) -> String {
        var parts: [String] = []

        let sorted = project.scenes.sorted { $0.orderIndex < $1.orderIndex }
        for (i, scene) in sorted.enumerated() {
            let roleNames = scene.roles.map { $0.name }.filter { !$0.isEmpty }
            for variation in scene.variations {
                var block = "Сцена \(i + 1): \(scene.title) — \(variation.title)"
                if !roleNames.isEmpty {
                    block += "\nРоли: \(roleNames.joined(separator: ", "))"
                }
                block += "\n\n\(variation.text)"
                parts.append(block)
            }
        }

        if !project.screenRoles.isEmpty {
            parts.append("=== РОЛИ ===\n\n" +
                project.screenRoles.sorted { $0.name < $1.name }
                    .map { screenRoleBlock($0) }.joined(separator: "\n\n"))
        }

        return parts.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Fountain

    private static func screenplayFountainText(_ project: WritingProject) -> String {
        var lines: [String] = []

        lines.append("Title: \(project.title)")
        lines.append("")

        let sorted = project.scenes.sorted { $0.orderIndex < $1.orderIndex }
        for (i, scene) in sorted.enumerated() {
            // Fountain scene heading
            lines.append("INT. \(scene.title.uppercased()) - DAY")
            lines.append("")

            let roleNames = scene.roles.map { $0.name }.filter { !$0.isEmpty }
            if !roleNames.isEmpty {
                lines.append("/* Роли: \(roleNames.joined(separator: ", ")) */")
                lines.append("")
            }

            // Use active variation text
            let activeIndex = min(scene.activeVariationIndex, scene.variations.count - 1)
            let variation = scene.variations[max(0, activeIndex)]
            if !variation.text.isEmpty {
                lines.append(variation.text)
                lines.append("")
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
        lines.append("Имя: \(c.name)")
        if let age = c.age { lines.append("Возраст: \(age)") }
        if !c.role.isEmpty       { lines.append("Роль: \(c.role)") }
        if !c.appearance.isEmpty { lines.append("Внешность: \(c.appearance)") }
        if !c.biography.isEmpty  { lines.append("Биография: \(c.biography)") }
        if !c.abilities.isEmpty  { lines.append("Способности: \(c.abilities)") }
        if !c.plotRole.isEmpty   { lines.append("Роль в сюжете: \(c.plotRole)") }
        return lines.joined(separator: "\n")
    }

    private static func screenRoleBlock(_ r: ScreenRole) -> String {
        var lines: [String] = []
        lines.append("Имя: \(r.name)")
        if !r.role.isEmpty       { lines.append("Роль: \(r.role)") }
        if !r.appearance.isEmpty { lines.append("Внешность: \(r.appearance)") }
        if !r.biography.isEmpty  { lines.append("Биография: \(r.biography)") }
        if !r.abilities.isEmpty  { lines.append("Способности: \(r.abilities)") }
        if !r.plotRole.isEmpty   { lines.append("Роль в сюжете: \(r.plotRole)") }
        return lines.joined(separator: "\n")
    }

    private static func locationBlock(_ l: WorldLocation) -> String {
        var lines: [String] = []
        lines.append("Название: \(l.name)")
        if !l.type.isEmpty             { lines.append("Тип: \(l.type)") }
        if !l.shortDescription.isEmpty { lines.append("Описание: \(l.shortDescription)") }
        if !l.atmosphere.isEmpty       { lines.append("Атмосфера: \(l.atmosphere)") }
        if !l.geography.isEmpty        { lines.append("География: \(l.geography)") }
        if !l.artifacts.isEmpty        { lines.append("Артефакты: \(l.artifacts)") }
        if !l.organizations.isEmpty    { lines.append("Организации: \(l.organizations)") }
        if !l.info.isEmpty             { lines.append("Доп. информация: \(l.info)") }
        return lines.joined(separator: "\n")
    }

    private static func resourceBlock(_ r: WorldResource) -> String {
        var lines: [String] = []
        lines.append("Название: \(r.name)")
        if !r.details.isEmpty     { lines.append("Описание: \(r.details)") }
        if !r.rules.isEmpty       { lines.append("Правила: \(r.rules)") }
        if !r.limitations.isEmpty { lines.append("Ограничения: \(r.limitations)") }
        return lines.joined(separator: "\n")
    }

    private static func metaphysicsBlock(_ m: MetaphysicsConcept) -> String {
        var lines: [String] = []
        lines.append("Название: \(m.name)")
        if !m.details.isEmpty      { lines.append("Описание: \(m.details)") }
        if !m.implications.isEmpty { lines.append("Последствия: \(m.implications)") }
        return lines.joined(separator: "\n")
    }

    private static func conceptBlock(_ c: WorldConcept) -> String {
        var lines: [String] = []
        lines.append("Название: \(c.name)")
        if !c.category.isEmpty { lines.append("Категория: \(c.category)") }
        if !c.details.isEmpty  { lines.append("Описание: \(c.details)") }
        return lines.joined(separator: "\n")
    }

    private static func structureBlock(_ s: WorldStructure) -> String {
        var lines: [String] = []
        lines.append("Название: \(s.name)")
        if !s.type.isEmpty    { lines.append("Тип: \(s.type)") }
        if !s.details.isEmpty { lines.append("Описание: \(s.details)") }
        return lines.joined(separator: "\n")
    }

    // MARK: - ZIP

    private static func zipDirectory(_ sourceRoot: URL, to destination: URL) throws {
        // Remove existing file if any
        try? FileManager.default.removeItem(at: destination)

        var error: NSError?
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceRoot,
                               options: .forUploading,
                               error: &coordinatorError) { zippedURL in
            do {
                try FileManager.default.copyItem(at: zippedURL, to: destination)
            } catch {
                // captured below
            }
        }
        if let e = coordinatorError ?? error {
            throw e
        }
    }

    // MARK: - DOCX builder (minimal Open XML container)

    private static func buildDocx(text: String) throws -> Data {
        // A minimal .docx is a ZIP containing a few XML files.
        // We build it manually using a temporary directory + NSFileCoordinator zip.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let docxTmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".docx")

        defer { try? FileManager.default.removeItem(at: tmp) }
        defer { try? FileManager.default.removeItem(at: docxTmp) }

        let fm = FileManager.default
        try fm.createDirectory(at: tmp.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: tmp.appendingPathComponent("word/_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: tmp.appendingPathComponent("word"), withIntermediateDirectories: true)

        // [Content_Types].xml
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml"  ContentType="application/xml"/>
          <Override PartName="/word/document.xml"
                    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
        try contentTypes.write(to: tmp.appendingPathComponent("[Content_Types].xml"),
                               atomically: true, encoding: .utf8)

        // _rels/.rels
        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
            Target="word/document.xml"/>
        </Relationships>
        """
        try rels.write(to: tmp.appendingPathComponent("_rels/.rels"),
                       atomically: true, encoding: .utf8)

        // word/_rels/document.xml.rels
        let wordRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """
        try wordRels.write(to: tmp.appendingPathComponent("word/_rels/document.xml.rels"),
                           atomically: true, encoding: .utf8)

        // word/document.xml — convert plain text lines to <w:p> paragraphs
        let paragraphs = text.components(separatedBy: "\n").map { line -> String in
            let escaped = line
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<w:p><w:r><w:t xml:space=\"preserve\">\(escaped)</w:t></w:r></w:p>"
        }.joined(separator: "\n")

        let document = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
        \(paragraphs)
          </w:body>
        </w:document>
        """
        try document.write(to: tmp.appendingPathComponent("word/document.xml"),
                           atomically: true, encoding: .utf8)

        // Zip the tmp folder into docxTmp
        try zipDirectory(tmp, to: docxTmp)

        return try Data(contentsOf: docxTmp)
    }

    // MARK: - Helpers

    private static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    private static func showError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Ошибка экспорта"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
