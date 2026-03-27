import SwiftUI
import AppKit

// MARK: - Общие константы

let timelineTrackHeight: CGFloat = 70
let timelineHeaderHeight: CGFloat = 52
/// Ширина одной колонки главы в логических координатах
let chapterColumnWidth: CGFloat = 300

// MARK: - Абстрактный элемент колонки таймлайна

/// Минимальный тип для отображения колонок в шапке канваса.
/// Конвертируйте Chapter или ScreenScene через .asTimelineColumn.
struct TimelineColumnItem: Identifiable {
    let id: UUID
    let title: String
}

private let crossRadius: CGFloat = 6
private let lineStroke: CGFloat = 3
private let hitRadius: CGFloat = 12
private let arrowStep: CGFloat = 1

// MARK: - Scroll-обёртка

struct TimelineCanvasScrollView: View {
    var tracks: [TimelineTrack]
    var columns: [TimelineColumnItem]
    var scale: CGFloat = 1.0
    var onSave: () -> Void
    /// Вызывается при выборе/снятии выбора узла: (trackIdx, nodeID) или nil
    var onSelectNode: ((Int, UUID)?) -> Void = { _ in }

    @AppStorage("timelineDotRadius") private var dotRadiusSetting: Double = 7

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                // Минимум: количество колонок * ширина * scale. Если пусто — 5 пустых колонок.
                let colCount = max(columns.count, 5)
                let canvasW = max(geo.size.width, CGFloat(colCount) * chapterColumnWidth * scale)
                let canvasH = max(geo.size.height, timelineHeaderHeight + CGFloat(tracks.count) * timelineTrackHeight)
                ZStack(alignment: .topLeading) {
                    // Основной NSView (без полосы колонок — только разделители и треки)
                    TimelineCanvasView(
                        tracks: tracks, columns: columns,
                        scale: scale,
                        dotRadius: CGFloat(dotRadiusSetting),
                        onSave: onSave, onSelectNode: onSelectNode
                    )
                    .frame(width: canvasW, height: canvasH)

                    // SwiftUI-полоса колонок поверх
                    ColumnHeaderStrip(columns: columns, scale: scale, totalColumns: colCount)
                        .frame(width: canvasW, height: timelineHeaderHeight)
                        .allowsHitTesting(false)
                }
                .frame(width: canvasW, height: canvasH)
            }
        }
        .background(Color("Editor"))
    }
}

// MARK: - SwiftUI-полоса колонок с Liquid Glass

struct ColumnHeaderStrip: View {
    var columns: [TimelineColumnItem]
    var scale: CGFloat
    var totalColumns: Int = 5
    var emptyLabel: LocalizedStringKey = "Нет элементов"

    var body: some View {
        let colW = chapterColumnWidth * scale
        let chipH: CGFloat = 34
        let chipInset: CGFloat = 6

        ZStack(alignment: .topLeading) {
            Color("PrimaryAccent")

            if columns.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color("SecondaryText").opacity(0.4))
                    .frame(height: timelineHeaderHeight)
                    .padding(.leading, 16)
            } else {
                ForEach(Array(columns.enumerated()), id: \.element.id) { idx, column in
                    let colStartX = CGFloat(idx) * colW

                    if idx > 0 {
                        Rectangle()
                            .fill(Color("Border"))
                            .frame(width: 0.5, height: timelineHeaderHeight)
                            .offset(x: colStartX)
                    }

                    Text(column.title.isEmpty ? "Без названия" : column.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color("PrimaryText"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 10)
                        .frame(
                            width: max(colW - chipInset * 2, 40),
                            height: chipH,
                            alignment: .leading
                        )
                        .glassEffect(.regular, in: .capsule)
                        .offset(
                            x: colStartX + chipInset,
                            y: (timelineHeaderHeight - chipH) / 2
                        )
                }
            }
        }
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
    var columns: [TimelineColumnItem]
    var scale: CGFloat = 1.0
    var dotRadius: CGFloat = 7
    var onSave: () -> Void
    var onSelectNode: ((Int, UUID)?) -> Void = { _ in }

    func makeNSView(context: Context) -> TimelineNSCanvasView {
        let v = TimelineNSCanvasView()
        v.tracks = tracks; v.columns = columns
        v.scale = scale
        v.dotRadius = dotRadius
        v.onSave = onSave; v.onSelectNode = onSelectNode
        return v
    }

    func updateNSView(_ v: TimelineNSCanvasView, context: Context) {
        v.tracks = tracks; v.columns = columns
        v.scale = scale
        v.dotRadius = dotRadius
        v.onSave = onSave; v.onSelectNode = onSelectNode
        v.needsDisplay = true
    }
}

// MARK: - NSView

final class TimelineNSCanvasView: NSView {

    var tracks: [TimelineTrack] = []      { didSet { needsDisplay = true; updateTrackingArea() } }
    var columns: [TimelineColumnItem] = [] { didSet { needsDisplay = true } }
    var scale: CGFloat = 1.0         { didSet { needsDisplay = true } }
    var dotRadius: CGFloat = 7       { didSet { needsDisplay = true } }
    var onSave: (() -> Void)?
    var onSelectNode: ((Int, UUID)?) -> Void = { _ in }

    /// Конвертирует логическую X-координату узла в экранную
    private func screenX(_ logicalX: CGFloat) -> CGFloat { logicalX * scale }
    /// Конвертирует экранную X-координату в логическую
    private func logicalX(_ screenX: CGFloat) -> CGFloat { screenX / scale }

    // Выбранная точка (для перемещения клавиатурой)
    private var selectedPoint: (trackIdx: Int, nodeID: UUID)?
    // Точка под курсором (для показа крестика)
    private var hoveredPoint: (trackIdx: Int, nodeID: UUID)?
    // Drag перемещения точки мышью
    private var dragState: (trackIdx: Int, nodeID: UUID, offsetX: CGFloat)?

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

        drawColumnBackgrounds(ctx: ctx)

        // Горизонтальный разделитель под полосой глав
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
                drawLine(ctx: ctx, fromX: screenX(node.x), toX: screenX(partner.x), y: midY, color: accent)
                drawnPairs.insert(node.id)
                drawnPairs.insert(lid)
            }

            // Рисуем точки поверх линий
            for node in nodes {
                if let sel = selectedPoint, sel.trackIdx == i, sel.nodeID == node.id {
                    drawSelection(ctx: ctx, x: screenX(node.x), y: midY)
                }
                drawDot(ctx: ctx, x: screenX(node.x), y: midY, color: accent)
                if let h = hoveredPoint, h.trackIdx == i, h.nodeID == node.id {
                    drawCross(ctx: ctx, x: screenX(node.x), y: midY)
                }
            }
        }
    }

    // MARK: Draw helpers

    /// Рисует только структурные элементы колонок: фон и вертикальные разделители.
    /// Заголовки колонок рисуются в SwiftUI-слое (ColumnHeaderStrip).
    private func drawColumnBackgrounds(ctx: CGContext) {
        guard !columns.isEmpty else { return }
        let colW = chapterColumnWidth * scale
        let totalH = bounds.height
        let accent = NSColor(named: "AccentColor") ?? .controlAccentColor
        let borderColor = (NSColor(named: "Border") ?? .separatorColor).cgColor

        for (idx, _) in columns.enumerated() {
            let colStartX = CGFloat(idx) * colW

            // Чередующийся лёгкий фон нечётных колонок
            if idx % 2 == 1 {
                ctx.setFillColor(accent.withAlphaComponent(0.035).cgColor)
                ctx.fill(CGRect(x: colStartX, y: timelineHeaderHeight, width: colW, height: totalH - timelineHeaderHeight))
            }

            // Вертикальный разделитель (кроме первой колонки)
            if idx > 0 {
                ctx.setStrokeColor(borderColor)
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: colStartX, y: timelineHeaderHeight))
                ctx.addLine(to: CGPoint(x: colStartX, y: totalH))
                ctx.strokePath()
            }
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
        let lx = logicalX(pt.x)
        let nodes = tracks[tIdx].nodes
        // Сначала ищем точку
        for node in nodes {
            if abs(lx - node.x) <= hitRadius / scale { return (tIdx, node.id) }
        }
        // Потом — попадание по линии между двумя связанными точками
        var checked = Set<UUID>()
        for node in nodes {
            guard let lid = node.linkedID, !checked.contains(node.id),
                  let partner = nodes.first(where: { $0.id == lid }) else { continue }
            checked.insert(node.id); checked.insert(lid)
            let minX = min(node.x, partner.x)
            let maxX = max(node.x, partner.x)
            if lx >= minX && lx <= maxX {
                return (tIdx, node.id)
            }
        }
        return nil
    }

    private func findCrossHit(at pt: CGPoint) -> (trackIdx: Int, nodeID: UUID)? {
        guard let tIdx = trackIndex(for: pt.y) else { return nil }
        let midY = trackMidY(for: tIdx)
        let crossY = midY - dotRadius - crossRadius - 3
        let lx = logicalX(pt.x)
        for node in tracks[tIdx].nodes {
            if abs(lx - node.x) <= (crossRadius + 4) / scale, abs(pt.y - crossY) <= crossRadius + 4 {
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

        // Попадание по точке → выделяем + готовимся к drag
        if let hit = findNode(at: pt) {
            selectedPoint = (hit.trackIdx, hit.nodeID)
            let nodeX = tracks[hit.trackIdx].nodes.first(where: { $0.id == hit.nodeID })?.x ?? logicalX(pt.x)
            // offsetX хранится в логических координатах
            dragState = (hit.trackIdx, hit.nodeID, logicalX(pt.x) - nodeX)
            window?.makeFirstResponder(self)
            onSelectNode((hit.trackIdx, hit.nodeID))
            needsDisplay = true
            return
        }

        // Снимаем выделение при клике по пустому месту
        if selectedPoint != nil {
            selectedPoint = nil
            onSelectNode(nil)
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag = dragState else { return }
        let pt = convert(event.locationInWindow, from: nil)
        let newX = logicalX(pt.x) - drag.offsetX

        let track = tracks[drag.trackIdx]
        var nodes = track.nodes
        guard let idx = nodes.firstIndex(where: { $0.id == drag.nodeID }) else { return }
        nodes[idx].x = newX
        track.nodes = nodes
        // Не вызываем onSave() на каждом событии drag — только при mouseUp
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard dragState != nil else { return }
        dragState = nil
        onSave?()
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        guard let tIdx = trackIndex(for: pt.y) else { return }
        let midY = trackMidY(for: tIdx)
        guard abs(pt.y - midY) <= hitRadius else { return }

        // Создаём две точки со взаимной ссылкой (событие с диапазоном)
        let defaultSpan: CGFloat = 80
        let lx = logicalX(pt.x)
        var nodeA = TimelineNode(x: lx - defaultSpan / 2)
        var nodeB = TimelineNode(x: lx + defaultSpan / 2)
        nodeA.linkedID = nodeB.id; nodeA.eventType = .range
        nodeB.linkedID = nodeA.id; nodeB.eventType = .range
        // (NodeEventType.range — событие с диапазоном)

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
