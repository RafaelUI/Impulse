import SwiftUI

// MARK: - Hex Color

private extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

// MARK: - Model

struct ConstellationNode: Identifiable, Equatable {
    let id: UUID
    let chapter: String
    let score: Float
    let snippet: String
    let type: SearchResultType
    var position: CGPoint = .zero

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - Orbital Layout

private let kMaxOrbit: CGFloat = 220
private let kMinOrbit: CGFloat = 50

private func orbitalLayout(nodes: [ConstellationNode]) -> [ConstellationNode] {
    guard !nodes.isEmpty else { return [] }
    var pts = nodes
    let n    = pts.count
    let minD: CGFloat = 52

    for i in 0 ..< n {
        let base   = CGFloat(Double(i) / Double(n) * .pi * 2)
        let jitter = CGFloat(Double.random(in: -0.4 ... 0.4))
        let radius = (1.0 - CGFloat(pts[i].score)) * kMaxOrbit + kMinOrbit
        pts[i].position = CGPoint(x: cos(base + jitter) * radius,
                                  y: sin(base + jitter) * radius)
    }

    for _ in 0 ..< 60 {
        for i in 0 ..< n {
            for j in (i + 1) ..< n {
                let dx = pts[i].position.x - pts[j].position.x
                let dy = pts[i].position.y - pts[j].position.y
                let d  = max(hypot(dx, dy), 0.01)
                guard d < minD else { continue }
                let push = (minD - d) * 0.5
                let nx = dx / d * push, ny = dy / d * push
                pts[i].position.x += nx; pts[i].position.y += ny
                pts[j].position.x -= nx; pts[j].position.y -= ny
            }
        }
    }
    return pts
}

// MARK: - ConstellationView

struct ConstellationView: View {
    let query: String
    let nodes: [ConstellationNode]
    var onSelect: (ConstellationNode) -> Void = { _ in }

    @State private var panOffset: CGSize = .zero
    @State private var dragBase:  CGSize = .zero
    @State private var scale:     CGFloat = 1.0
    @State private var scaleBase: CGFloat = 1.0

    @State private var laid:      [ConstellationNode] = []
    @State private var viewSize:  CGSize = .zero
    @State private var hoveredID: UUID?  = nil
    @State private var appeared:  Bool   = false
    @State private var animStart: Double = 0

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color("PrimaryAccent").ignoresSafeArea()

                TimelineView(.animation) { tl in
                    Canvas { ctx, sz in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        viewport(&ctx, size: sz)
                        rings(&ctx)
                        edges(&ctx, t: t)
                        resultNodes(&ctx, t: t)
                        queryNode(&ctx, t: t)
                    }
                    .onContinuousHover(perform: onHover)
                }

                if let hid = hoveredID,
                   let node = laid.first(where: { $0.id == hid }) {
                    ConstellationTooltip(node: node)
                        .position(tooltipPos(node.position))
                        .allowsHitTesting(false)
                        .animation(.spring(duration: 0.16), value: hoveredID)
                        .zIndex(10)
                }
            }
            .onAppear {
                viewSize = geo.size
                relayout(geo.size)
                startAnimation()
            }
            .onChange(of: geo.size) { _, s in
                viewSize = s
                relayout(s)
            }
            .onChange(of: nodes) { _, _ in
                relayout(viewSize)
                startAnimation()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    panOffset = CGSize(
                        width:  dragBase.width  + v.translation.width,
                        height: dragBase.height + v.translation.height
                    )
                }
                .onEnded { v in
                    dragBase = CGSize(
                        width:  dragBase.width  + v.translation.width,
                        height: dragBase.height + v.translation.height
                    )
                    panOffset = dragBase
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in scale = min(max(scaleBase * v.magnification, 0.25), 4.0) }
                .onEnded   { _ in scaleBase = scale }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                guard let hid = hoveredID,
                      let hit = laid.first(where: { $0.id == hid }) else { return }
                onSelect(hit)
            }
        )
        .clipped()
    }

    // MARK: - Animation

    private func startAnimation() {
        appeared  = false
        animStart = 0
        Task {
            await Task.yield()
            animStart = Date().timeIntervalSinceReferenceDate
            appeared  = true
        }
    }

    // MARK: - Viewport

    private func viewport(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.translateBy(
            x: size.width  / 2 + panOffset.width,
            y: size.height / 2 + panOffset.height
        )
        ctx.scaleBy(x: scale, y: scale)
    }

    // MARK: - Draw: Rings (70 % ≈ "близко", 90 % ≈ "далеко")

    private func rings(_ ctx: inout GraphicsContext) {
        let total = kMaxOrbit + kMinOrbit
        for (f, label) in [(CGFloat(0.70), "близко"), (CGFloat(0.90), "далеко")] {
            let r = total * f
            ctx.stroke(
                Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)),
                with: .color(Color("SecondaryText").opacity(0.12)),
                style: StrokeStyle(lineWidth: 0.5, dash: [4, 10])
            )
            ctx.draw(
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color("SecondaryText").opacity(0.25)),
                at: CGPoint(x: r + 8, y: 0)
            )
        }
    }

    // MARK: - Draw: Edges

    private func edges(_ ctx: inout GraphicsContext, t: Double) {
        guard appeared, animStart > 0 else { return }
        let elapsed = t - animStart

        for (i, n) in laid.enumerated() where n.score > 0.5 {
            let delay    = Double(i) * 0.06
            let prog     = CGFloat(springEase(max(0, elapsed - delay) / 0.6))
            guard prog > 0.05 else { continue }
            let end = CGPoint(x: n.position.x * prog, y: n.position.y * prog)
            var p = Path(); p.move(to: .zero); p.addLine(to: end)
            ctx.stroke(p,
                with: .color(nodeColor(for: n.type).opacity(Double(n.score) * 0.38 * Double(min(prog, 1)))),
                style: StrokeStyle(lineWidth: 0.6))
        }
    }

    // MARK: - Draw: Result Nodes

    private func resultNodes(_ ctx: inout GraphicsContext, t: Double) {
        guard appeared, animStart > 0 else { return }
        let elapsed = t - animStart

        for (i, n) in laid.enumerated() {
            let delay   = Double(i) * 0.06
            let rawProg = CGFloat(springEase(max(0, elapsed - delay) / 0.6))
            guard rawProg > 0.01 else { continue }

            let fadeIn = CGFloat(min(max(0, elapsed - delay) / 0.2, 1.0))
            let pos    = CGPoint(x: n.position.x * rawProg, y: n.position.y * rawProg)
            let baseR  = nodeR(n.score)
            let r      = baseR * (0.3 + 0.7 * min(rawProg, 1.0))
            let col    = nodeColor(for: n.type)
            let hov    = n.id == hoveredID

            // Glow: score > 0.6 → one circle; score < 0.4 → none
            if n.score > 0.6 {
                var gc = ctx
                gc.addFilter(.blur(radius: 9))
                gc.fill(Path(ellipseIn: box(pos, r * 2.2)),
                    with: .color(col.opacity(Double(n.score) * 0.25 * Double(fadeIn))))
            }

            // Hover ring
            if hov {
                var hc = ctx
                hc.addFilter(.blur(radius: 4))
                hc.stroke(Path(ellipseIn: box(pos, r + 6)),
                    with: .color(.white.opacity(0.45)), lineWidth: 1.5)
            }

            ctx.fill(Path(ellipseIn: box(pos, r)),
                with: .color(col.opacity((hov ? 1.0 : 0.85) * Double(fadeIn))))

            // Low-score nodes: thicker outline, no fill glow
            let strokeOpacity = n.score < 0.4
                ? 0.32 * Double(fadeIn)
                : (hov ? 0.65 : 0.18) * Double(fadeIn)
            ctx.stroke(Path(ellipseIn: box(pos, r)),
                with: .color(.white.opacity(strokeOpacity)),
                lineWidth: hov ? 1.5 : (n.score < 0.4 ? 1.0 : 0.75))

            // Label fades in during final third of animation
            if rawProg > 0.65 {
                let lf = Double(min((rawProg - 0.65) / 0.35, 1.0)) * Double(fadeIn)
                ctx.draw(
                    Text(n.chapter)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72 * lf)),
                    at: CGPoint(x: pos.x, y: pos.y + r + 11))
            }
        }
    }

    // MARK: - Draw: Query Node

    private func queryNode(_ ctx: inout GraphicsContext, t: Double) {
        let pulse = CGFloat(sin(t * 2.0) * 0.5 + 0.5)
        let qr: CGFloat = 16 + pulse * 5

        // Outer glow: opacity 0.15, radius * 3
        var gc1 = ctx
        gc1.addFilter(.blur(radius: 10))
        gc1.fill(Path(ellipseIn: box(.zero, qr * 3)),
            with: .color(Color("AccentColor").opacity(0.15 + Double(pulse) * 0.05)))

        // Inner glow: opacity 0.35, radius * 1.5
        var gc2 = ctx
        gc2.addFilter(.blur(radius: 5))
        gc2.fill(Path(ellipseIn: box(.zero, qr * 1.5)),
            with: .color(Color("AccentColor").opacity(0.35 + Double(pulse) * 0.10)))

        // Pulse ring
        ctx.stroke(Path(ellipseIn: box(.zero, qr + 6 + pulse * 10)),
            with: .color(Color("AccentColor").opacity(0.10 + Double(pulse) * 0.12)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 6]))

        // Core
        ctx.fill(Path(ellipseIn: box(.zero, qr)), with: .color(Color("AccentColor")))
        ctx.stroke(Path(ellipseIn: box(.zero, qr)),
            with: .color(.white.opacity(0.5)), lineWidth: 1.5)

        let disp = query.count > 20 ? String(query.prefix(18)) + "…" : query
        if !disp.isEmpty {
            ctx.draw(
                Text(disp)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white),
                at: .zero)
        }
    }

    // MARK: - Layout

    private func relayout(_ size: CGSize) {
        guard !nodes.isEmpty else { laid = []; return }
        laid = orbitalLayout(nodes: nodes)
    }

    // MARK: - Hover

    private func onHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let loc):
            let w   = viewToWorld(loc)
            let hit = laid.first { hypot($0.position.x - w.x, $0.position.y - w.y) < nodeR($0.score) + 12 }
            withAnimation(.easeInOut(duration: 0.1)) { hoveredID = hit?.id }
        case .ended:
            withAnimation(.easeOut(duration: 0.2)) { hoveredID = nil }
        }
    }

    // MARK: - Coordinates

    private func viewToWorld(_ pt: CGPoint) -> CGPoint {
        let cx = viewSize.width  / 2 + panOffset.width
        let cy = viewSize.height / 2 + panOffset.height
        return CGPoint(x: (pt.x - cx) / scale, y: (pt.y - cy) / scale)
    }

    private func worldToView(_ pt: CGPoint) -> CGPoint {
        CGPoint(
            x: pt.x * scale + viewSize.width  / 2 + panOffset.width,
            y: pt.y * scale + viewSize.height / 2 + panOffset.height
        )
    }

    private func tooltipPos(_ worldPt: CGPoint) -> CGPoint {
        let base = worldToView(worldPt)
        let w: CGFloat = 260, h: CGFloat = 110
        var x = base.x + 18
        var y = base.y - h / 2
        if x + w > viewSize.width  - 8 { x = base.x - w - 18 }
        x = max(8, min(x, viewSize.width  - w - 8))
        y = max(8, min(y, viewSize.height - h - 8))
        return CGPoint(x: x + w / 2, y: y + h / 2)
    }

    // MARK: - Style

    private func nodeR(_ score: Float) -> CGFloat { 7 + CGFloat(score) * 9 }

    private func nodeColor(for type: SearchResultType) -> Color {
        switch type {
        case .chapter:                               return Color(hex: "#c9a84c")
        case .character:                             return Color(hex: "#8ab4c9")
        case .worldConcept, .worldResource,
             .worldStructure:                        return Color(hex: "#9a7fb5")
        case .metaphysics:                           return Color(hex: "#c97070")
        case .scene, .screenRole:                    return Color(hex: "#7a8c7a")
        }
    }

    // Cubic ease-out + slight sine overshoot (~6 % at peak) for spring feel
    private func springEase(_ t: Double) -> Double {
        let t = max(0, min(t, 1.0))
        return 1.0 - pow(1.0 - t, 3.0) + sin(t * .pi) * 0.12
    }

    private func box(_ center: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
    }
}

// MARK: - Tooltip

private struct ConstellationTooltip: View {
    let node: ConstellationNode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(node.chapter.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: "#c9a84c"))
                Spacer()
                Text("\(Int(node.score * 100))%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(hex: "#7a6530"))
            }
            if !node.snippet.isEmpty {
                Text(node.snippet)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#d4cfc4"))
                    .lineLimit(3)
            }
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#7a6530"), Color(hex: "#c9a84c")],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 1.5)
                .scaleEffect(x: CGFloat(node.score), anchor: .leading)
        }
        .padding(14)
        .frame(width: 260)
        .background(Color(hex: "#1e1e1b"))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2a2a26"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.5), radius: 16)
        .transition(.opacity.combined(with: .scale(0.95)))
    }
}

// MARK: - Preview

#Preview {
    let sample: [ConstellationNode] = [
        .init(id: UUID(), chapter: "Пролог",        score: 0.92, snippet: "Всё начинается здесь...",      type: .chapter),
        .init(id: UUID(), chapter: "Глава 1",       score: 0.78, snippet: "Герой встречает магию...",     type: .chapter),
        .init(id: UUID(), chapter: "Арагорн",       score: 0.67, snippet: "Северянин, наследник...",      type: .character),
        .init(id: UUID(), chapter: "Глава 2",       score: 0.55, snippet: "Город полон тайн...",          type: .chapter),
        .init(id: UUID(), chapter: "Маги",          score: 0.50, snippet: "Система магии мира...",        type: .worldResource),
        .init(id: UUID(), chapter: "Глава 3",       score: 0.44, snippet: "Старый враг...",               type: .chapter),
        .init(id: UUID(), chapter: "Предательство", score: 0.38, snippet: "Взгляд со стороны...",         type: .metaphysics),
        .init(id: UUID(), chapter: "Глава 4",       score: 0.29, snippet: "Путь домой...",                type: .chapter),
    ]
    ConstellationView(query: "магия и предательство", nodes: sample, onSelect: { _ in })
        .frame(width: 700, height: 560)
}
