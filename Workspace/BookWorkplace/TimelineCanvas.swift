import SwiftUI
import AppKit

// MARK: - Общие константы

let timelineTrackHeight: CGFloat = 48
let timelineHeaderHeight: CGFloat = 44

private let dotRadius: CGFloat = 7
private let crossRadius: CGFloat = 6
private let lineStroke: CGFloat = 3
private let hitRadius: CGFloat = 12
private let arrowStep: CGFloat = 4

// MARK: - Scroll-обёртка

struct TimelineCanvasScrollView: View {
    var tracks: [TimelineTrack]
    var chapters: [Chapter]
    var onSave: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                TimelineCanvasView(tracks: tracks, chapters: chapters, onSave: onSave)
                    .frame(
                        width: max(geo.size.width, 2000),
                        height: max(
                            geo.size.height,
                            timelineHeaderHeight + CGFloat(tracks.count) * timelineTrackHeight
                        )
                    )
            }
        }
        .background(Color("Editor"))
    }
}

// MARK: - Расширение: декодирование/кодирование узлов

extension TimelineTrack {
    var nodes: [TimelineNode] {
        get { (try? JSONDecoder().decode([TimelineNode].self, from: nodesData)) ?? [] }
        set { nodesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

// MARK: - NSViewRepresentable

struct TimelineCanvasView: NSViewRepresentable {
    var tracks: [TimelineTrack]
    var chapters: [Chapter]
    var onSave: () -> Void

    func makeNSView(context: Context) -> TimelineNSCanvasView {
        let v = TimelineNSCanvasView()
        v.tracks = tracks; v.chapters = chapters; v.onSave = onSave
        return v
    }

    func updateNSView(_ v: TimelineNSCanvasView, context: Context) {
        v.tracks = tracks; v.chapters = chapters; v.onSave = onSave
        v.needsDisplay = true
    }
}

// MARK: - NSView

final class TimelineNSCanvasView: NSView {

    var tracks: [TimelineTrack] = [] { didSet { needsDisplay = true; updateTrackingArea() } }
    var chapters: [Chapter] = []     { didSet { needsDisplay = true } }
    var onSave: (() -> Void)?

    // Выбранная точка (для перемещения клавиатурой)
    private var selectedPoint: (trackIdx: Int, nodeID: UUID)?
    // Точка под курсором (для показа крестика)
    private var hoveredPoint: (trackIdx: Int, nodeID: UUID)?

    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: Tracking area

    private func updateTrackingArea() {
        if let old = trackingArea { removeTrackingArea(old) }
        let a = NSTrackingArea(rect: bounds,
                               options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
                               owner: self, userInfo: nil)
        addTrackingArea(a); trackingArea = a
    }

    override func updateTrackingAreas() { super.updateTrackingAreas(); updateTrackingArea() }

    // MARK: Y helpers

    private func trackMidY(for i: Int) -> CGFloat {
        timelineHeaderHeight + CGFloat(i) * timelineTrackHeight + timelineTrackHeight / 2
    }

    private func trackIndex(for y: CGFloat) -> Int? {
        let offset = y - timelineHeaderHeight
        guard offset >= 0 else { return nil }
        let i = Int(offset / timelineTrackHeight)
        return (i >= 0 && i < tracks.count) ? i : nil
    }

    // MARK: Draw

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        (NSColor(named: "Editor") ?? .textBackgroundColor).setFill()
        ctx.fill(bounds)

        drawChapterStrip(ctx: ctx)

        // Разделитель
        ctx.setStrokeColor((NSColor(named: "Border") ?? .separatorColor).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 0, y: timelineHeaderHeight))
        ctx.addLine(to: CGPoint(x: bounds.width, y: timelineHeaderHeight))
        ctx.strokePath()

        let accent = NSColor(named: "AccentColor") ?? .controlAccentColor

        for (i, track) in tracks.enumerated() {
            let midY = trackMidY(for: i)

            // Направляющая
            ctx.setStrokeColor((NSColor(named: "Border") ?? .separatorColor).cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: 0, y: midY))
            ctx.addLine(to: CGPoint(x: bounds.width, y: midY))
            ctx.strokePath()

            let nodes = track.nodes

            // Рисуем линии (один раз на пару, чтобы не дублировать)
            var drawnPairs = Set<UUID>()
            for node in nodes {
                guard let lid = node.linkedID,
                      let partner = nodes.first(where: { $0.id == lid }),
                      !drawnPairs.contains(node.id) else { continue }
                drawLine(ctx: ctx, fromX: node.x, toX: partner.x, y: midY, color: accent)
                drawnPairs.insert(node.id)
                drawnPairs.insert(lid)
            }

            // Рисуем точки поверх линий
            for node in nodes {
                if let sel = selectedPoint, sel.trackIdx == i, sel.nodeID == node.id {
                    drawSelection(ctx: ctx, x: node.x, y: midY)
                }
                drawDot(ctx: ctx, x: node.x, y: midY, color: accent)
                if let h = hoveredPoint, h.trackIdx == i, h.nodeID == node.id {
                    drawCross(ctx: ctx, x: node.x, y: midY)
                }
            }
        }
    }

    // MARK: Draw helpers

    private func drawChapterStrip(ctx: CGContext) {
        let stripH = timelineHeaderHeight
        (NSColor(named: "PrimaryAccent") ?? .controlBackgroundColor).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: stripH))

        guard !chapters.isEmpty else {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: (NSColor(named: "SecondaryText") ?? .secondaryLabelColor).withAlphaComponent(0.4)
            ]
            NSAttributedString(string: "Глав пока нет", attributes: attrs)
                .draw(at: CGPoint(x: 16, y: (stripH - 14) / 2))
            return
        }

        let accent = NSColor(named: "AccentColor") ?? .controlAccentColor
        var x: CGFloat = 16
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: accent
        ]
        for chapter in chapters {
            let title = chapter.title.isEmpty ? "Без названия" : chapter.title
            let str = NSAttributedString(string: title, attributes: attrs)
            let chipW = str.size().width + 20
            let chipH = str.size().height + 8
            let chipY = (stripH - chipH) / 2
            let chipRect = CGRect(x: x, y: chipY, width: chipW, height: chipH)
            let path = CGPath(roundedRect: chipRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.setFillColor(accent.withAlphaComponent(0.1).cgColor)
            ctx.addPath(path); ctx.fillPath()
            ctx.setStrokeColor(accent.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(0.5)
            ctx.addPath(path); ctx.strokePath()
            str.draw(at: CGPoint(x: x + 10, y: chipY + 4))
            x += chipW + 6
        }
    }

    private func drawLine(ctx: CGContext, fromX: CGFloat, toX: CGFloat, y: CGFloat, color: NSColor) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineStroke)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: fromX, y: y))
        ctx.addLine(to: CGPoint(x: toX, y: y))
        ctx.strokePath()
    }

    private func drawDot(ctx: CGContext, x: CGFloat, y: CGFloat, color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius,
                                   width: dotRadius * 2, height: dotRadius * 2))
    }

    private func drawSelection(ctx: CGContext, x: CGFloat, y: CGFloat) {
        let r = dotRadius + 5
        ctx.setFillColor(NSColor.systemGray.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private func drawCross(ctx: CGContext, x: CGFloat, y: CGFloat) {
        let cy = y - dotRadius - crossRadius - 3
        ctx.setFillColor(NSColor.systemGray.withAlphaComponent(0.75).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - crossRadius, y: cy - crossRadius,
                                   width: crossRadius * 2, height: crossRadius * 2))
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5); ctx.setLineCap(.round)
        let d = crossRadius * 0.5
        ctx.move(to: CGPoint(x: x - d, y: cy - d)); ctx.addLine(to: CGPoint(x: x + d, y: cy + d)); ctx.strokePath()
        ctx.move(to: CGPoint(x: x + d, y: cy - d)); ctx.addLine(to: CGPoint(x: x - d, y: cy + d)); ctx.strokePath()
    }

    // MARK: Hit testing

    private func findNode(at pt: CGPoint) -> (trackIdx: Int, nodeID: UUID)? {
        guard let tIdx = trackIndex(for: pt.y) else { return nil }
        let midY = trackMidY(for: tIdx)
        guard abs(pt.y - midY) <= hitRadius else { return nil }
        for node in tracks[tIdx].nodes {
            if abs(pt.x - node.x) <= hitRadius { return (tIdx, node.id) }
        }
        return nil
    }

    private func findCrossHit(at pt: CGPoint) -> (trackIdx: Int, nodeID: UUID)? {
        guard let tIdx = trackIndex(for: pt.y) else { return nil }
        let midY = trackMidY(for: tIdx)
        let crossY = midY - dotRadius - crossRadius - 3
        for node in tracks[tIdx].nodes {
            if abs(pt.x - node.x) <= crossRadius + 4, abs(pt.y - crossY) <= crossRadius + 4 {
                return (tIdx, node.id)
            }
        }
        return nil
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        // Крестик → удаление
        if let cross = findCrossHit(at: pt) {
            deleteNode(trackIdx: cross.trackIdx, nodeID: cross.nodeID)
            return
        }

        // Попадание по точке → выделение
        if let hit = findNode(at: pt) {
            selectedPoint = (hit.trackIdx, hit.nodeID)
            window?.makeFirstResponder(self)
            needsDisplay = true
            return
        }

        // Снимаем выделение при клике по пустому месту
        if selectedPoint != nil { selectedPoint = nil; needsDisplay = true }
    }

    override func rightMouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        guard let tIdx = trackIndex(for: pt.y) else { return }
        let midY = trackMidY(for: tIdx)
        guard abs(pt.y - midY) <= hitRadius else { return }

        // Создаём две точки со взаимной ссылкой
        let defaultSpan: CGFloat = 80
        var nodeA = TimelineNode(x: pt.x - defaultSpan / 2)
        var nodeB = TimelineNode(x: pt.x + defaultSpan / 2)
        nodeA.linkedID = nodeB.id
        nodeB.linkedID = nodeA.id

        let track = tracks[tIdx]
        var nodes = track.nodes
        nodes.append(nodeA)
        nodes.append(nodeB)
        track.nodes = nodes
        onSave?()
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        if let hit = findNode(at: pt) {
            if hoveredPoint?.trackIdx != hit.trackIdx || hoveredPoint?.nodeID != hit.nodeID {
                hoveredPoint = (hit.trackIdx, hit.nodeID)
                needsDisplay = true
            }
        } else if hoveredPoint != nil {
            hoveredPoint = nil; needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredPoint != nil { hoveredPoint = nil; needsDisplay = true }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        guard let sel = selectedPoint else { super.keyDown(with: event); return }
        let leftArrow = 123; let rightArrow = 124
        guard event.keyCode == UInt16(leftArrow) || event.keyCode == UInt16(rightArrow) else {
            super.keyDown(with: event); return
        }
        let delta: CGFloat = event.keyCode == UInt16(leftArrow) ? -arrowStep : arrowStep

        let track = tracks[sel.trackIdx]
        var nodes = track.nodes
        guard let idx = nodes.firstIndex(where: { $0.id == sel.nodeID }) else { return }
        nodes[idx].x += delta
        track.nodes = nodes
        onSave?()
        needsDisplay = true
    }

    // MARK: Delete

    /// Удаляет узел и разрывает связь у партнёра (партнёр остаётся, но уже без linkedID)
    private func deleteNode(trackIdx: Int, nodeID: UUID) {
        let track = tracks[trackIdx]
        var nodes = track.nodes
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }) else { return }

        // Находим партнёра и снимаем с него ссылку
        if let lid = nodes[idx].linkedID,
           let partnerIdx = nodes.firstIndex(where: { $0.id == lid }) {
            nodes[partnerIdx].linkedID = nil
        }

        nodes.remove(at: idx)
        track.nodes = nodes

        if selectedPoint?.nodeID == nodeID { selectedPoint = nil }
        if hoveredPoint?.nodeID == nodeID { hoveredPoint = nil }

        onSave?()
        needsDisplay = true
    }

    // MARK: Intrinsic size

    override var intrinsicContentSize: NSSize {
        let h = timelineHeaderHeight + max(CGFloat(tracks.count) * timelineTrackHeight, timelineTrackHeight)
        return NSSize(width: NSView.noIntrinsicMetric, height: h)
    }
}
