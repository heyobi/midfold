import SwiftUI

/// Paper confetti, feathers and sparkles. World coordinates (x along the course, y in screen heights).
struct Particle {
    enum Kind { case paper, sparkle, feather }
    var x: Double, y: Double, vx: Double, vy: Double
    var life: Double, maxLife: Double
    var spin: Double, angle: Double
    var size: Double
    var kind: Kind
    var hue: Int
}

struct Theme {
    var skyTop: Color, skyBottom: Color
    var far: Color, mid: Color, near: Color
    var wall: Color, wallShade: Color, cap: Color
    var dark: Bool

    static func of(_ w: World) -> Theme {
        switch w {
        case .meadow:
            return Theme(skyTop: Color(red: 0.42, green: 0.66, blue: 0.96), skyBottom: Color(red: 1.0, green: 0.86, blue: 0.70),
                         far: Color(red: 0.62, green: 0.80, blue: 0.70), mid: Color(red: 0.42, green: 0.70, blue: 0.48),
                         near: Color(red: 0.26, green: 0.56, blue: 0.36),
                         wall: Palette.paper, wallShade: Color(red: 0.86, green: 0.82, blue: 0.74), cap: Color(red: 0.95, green: 0.45, blue: 0.35), dark: false)
        case .cliffs:
            return Theme(skyTop: Color(red: 0.30, green: 0.62, blue: 0.70), skyBottom: Color(red: 0.98, green: 0.80, blue: 0.56),
                         far: Color(red: 0.55, green: 0.62, blue: 0.70), mid: Color(red: 0.42, green: 0.46, blue: 0.56),
                         near: Color(red: 0.30, green: 0.32, blue: 0.40),
                         wall: Color(red: 0.86, green: 0.88, blue: 0.92), wallShade: Color(red: 0.70, green: 0.73, blue: 0.80), cap: Color(red: 0.25, green: 0.50, blue: 0.85), dark: false)
        case .caves:
            return Theme(skyTop: Color(red: 0.10, green: 0.07, blue: 0.20), skyBottom: Color(red: 0.24, green: 0.12, blue: 0.34),
                         far: Color(red: 0.20, green: 0.14, blue: 0.32), mid: Color(red: 0.14, green: 0.10, blue: 0.24),
                         near: Color(red: 0.08, green: 0.06, blue: 0.14),
                         wall: Color(red: 0.32, green: 0.26, blue: 0.46), wallShade: Color(red: 0.24, green: 0.19, blue: 0.36), cap: Color(red: 0.45, green: 0.95, blue: 0.85), dark: true)
        }
    }
}

/// Draws one frame of the flight.
enum Renderer {
    struct Frame {
        var sim: FlightSim
        var particles: [Particle]
        var shake: CGSize
        var clock: Double       // wall-clock seconds, for idle animation
    }

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, frame f: Frame) {
        let sim = f.sim
        let theme = Theme.of(sim.spec.world)
        let h = Double(size.height), w = Double(size.width)
        // Horizontal scale: at least 1.3 screen heights of course are visible, even on a portrait phone.
        let sx = min(h, w / 1.3)
        let cam = sim.x - FlightSim.birdX
        func X(_ wx: Double) -> Double { (wx - cam) * sx + Double(f.shake.width) }
        func Y(_ wy: Double) -> Double { wy * h + Double(f.shake.height) }

        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                 with: .linearGradient(Gradient(colors: [theme.skyTop, theme.skyBottom]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        drawBackdrop(&ctx, w: w, h: h, cam: cam * sx, theme: theme, world: sim.spec.world, clock: f.clock)

        // Wind zones: drifting streaks.
        for wz in sim.winds {
            let x0 = X(wz.x), x1 = X(wz.x + wz.width)
            guard x1 > 0, x0 < w else { continue }
            ctx.fill(Path(CGRect(x: x0, y: 0, width: x1 - x0, height: h)),
                     with: .color((wz.force < 0 ? Color.white : Color(red: 0.2, green: 0.3, blue: 0.6)).opacity(0.10)))
            let dir = wz.force < 0 ? -1.0 : 1.0
            for k in 0..<10 {
                let lx = x0 + (x1 - x0) * (Double(k) + 0.5) / 10
                let phase = (f.clock * 0.6 * dir + Double(k) * 0.37).truncatingRemainder(dividingBy: 1)
                let ly = (phase < 0 ? phase + 1 : phase) * h
                var p = Path()
                p.move(to: CGPoint(x: lx, y: ly)); p.addLine(to: CGPoint(x: lx, y: ly + 0.07 * h * dir))
                ctx.stroke(p, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }

        // Obstacles.
        for o in sim.obstacles {
            let x0 = X(o.x - o.width / 2), x1 = X(o.x + o.width / 2)
            guard x1 > -20, x0 < w + 20 else { continue }
            let c = o.center(at: sim.t)
            let top = Y(c - o.gap / 2), bottom = Y(c + o.gap / 2)
            let tunnel = o.kind == .tunnel
            let ww = x1 - x0 + (tunnel ? 1 : 0)
            for r in [CGRect(x: x0, y: -40, width: ww, height: top + 40), CGRect(x: x0, y: bottom, width: ww, height: h - bottom + 40)] {
                ctx.fill(Path(roundedRect: r, cornerRadius: tunnel ? 0 : 7), with: .color(theme.wall))
                if !tunnel {
                    ctx.fill(Path(CGRect(x: r.midX, y: r.minY, width: r.width / 2, height: r.height)), with: .color(theme.wallShade))
                    var crease = Path(); crease.move(to: CGPoint(x: r.midX, y: r.minY)); crease.addLine(to: CGPoint(x: r.midX, y: r.maxY))
                    ctx.stroke(crease, with: .color(.black.opacity(0.18)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
            }
            // Caps on the edges of the gap; moving gates get a dashed track.
            let capH = 0.018 * h
            ctx.fill(Path(roundedRect: CGRect(x: x0 - 4, y: top - capH, width: ww + 8, height: capH), cornerRadius: 4), with: .color(theme.cap))
            ctx.fill(Path(roundedRect: CGRect(x: x0 - 4, y: bottom, width: ww + 8, height: capH), cornerRadius: 4), with: .color(theme.cap))
            if case .mover(let a, _, _) = o.kind {
                var track = Path()
                track.move(to: CGPoint(x: (x0 + x1) / 2, y: Y(o.center - a)))
                track.addLine(to: CGPoint(x: (x0 + x1) / 2, y: Y(o.center + a)))
                ctx.stroke(track, with: .color(theme.cap.opacity(0.8)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 6]))
            }
        }

        // Finish banner.
        if !sim.spec.endless {
            let fx = X(sim.spec.length)
            if fx > -40 && fx < w + 40 {
                for i in 0..<20 {
                    let cell = h / 20
                    for j in 0..<2 {
                        let dark = (i + j) % 2 == 0
                        ctx.fill(Path(CGRect(x: fx + Double(j) * cell * 0.6, y: Double(i) * cell, width: cell * 0.6, height: cell)),
                                 with: .color(dark ? Palette.ink.opacity(0.85) : .white.opacity(0.9)))
                    }
                }
            }
        }

        // Stars.
        for s in sim.stars where !s.taken {
            let cx = X(s.x), cy = Y(s.y)
            guard cx > -30, cx < w + 30 else { continue }
            let r = 0.032 * h * (1 + 0.08 * sin(f.clock * 5))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 1.8, y: cy - r * 1.8, width: r * 3.6, height: r * 3.6)),
                     with: .color(Palette.sun.opacity(0.22)))
            ctx.fill(starPath(center: CGPoint(x: cx, y: cy), radius: r, rotation: f.clock * 1.2), with: .color(Palette.sun))
        }

        // Particles.
        for p in f.particles {
            let px = X(p.x), py = Y(p.y)
            let a = max(0, p.life / p.maxLife)
            let s = p.size * h
            switch p.kind {
            case .sparkle:
                ctx.fill(starPath(center: CGPoint(x: px, y: py), radius: s, rotation: p.angle), with: .color(Palette.sun.opacity(a)))
            case .paper, .feather:
                var tri = Path()
                tri.move(to: CGPoint(x: 0, y: -s)); tri.addLine(to: CGPoint(x: s * 0.8, y: s * 0.6)); tri.addLine(to: CGPoint(x: -s * 0.8, y: s * 0.6))
                tri.closeSubpath()
                let colors: [Color] = [.white, Palette.sun, Color(red: 0.95, green: 0.5, blue: 0.4), Color(red: 0.6, green: 0.8, blue: 1)]
                let col = p.kind == .feather ? Color.white : colors[p.hue % colors.count]
                ctx.fill(tri.applying(CGAffineTransform(translationX: px, y: py).rotated(by: p.angle)), with: .color(col.opacity(a)))
            }
        }

        drawBird(&ctx, at: CGPoint(x: X(sim.x), y: Y(sim.y)), size: FlightSim.radius * h * 1.25, sim: sim, clock: f.clock)
    }

    static func starPath(center c: CGPoint, radius r: Double, rotation: Double) -> Path {
        var p = Path()
        for i in 0..<10 {
            let rr = i % 2 == 0 ? r : r * 0.45
            let a = rotation + Double(i) * .pi / 5 - .pi / 2
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// Parallax layers: far, mid and near silhouettes moving at different speeds.
    static func drawBackdrop(_ ctx: inout GraphicsContext, w: Double, h: Double, cam: Double, theme: Theme, world: World, clock: Double) {
        if world == .cliffs || world == .meadow {
            // Paper clouds.
            for i in 0..<5 {
                let span = w + 300
                var cx = (Double(i) * 260 - cam * 0.08 - clock * 6).truncatingRemainder(dividingBy: span)
                if cx < -150 { cx += span }
                let cy = h * (0.12 + 0.07 * Double(i % 3))
                for (dx, r) in [(0.0, 34.0), (30.0, 26.0), (-30.0, 22.0)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + dx - r, y: cy - r * 0.7, width: r * 2, height: r * 1.4)), with: .color(.white.opacity(0.75)))
                }
            }
        }
        let layers: [(Double, Double, Double, Color)] = [(0.15, 0.72, 0.10, theme.far), (0.35, 0.80, 0.08, theme.mid), (0.7, 0.90, 0.05, theme.near)]
        for (k, layer) in layers.enumerated() {
            let (factor, base, amp, color) = layer
            var path = Path()
            let off = cam * factor
            if world == .caves {
                // Stalactites from the top and stalagmites from the bottom.
                for (top, sign) in [(true, 1.0), (false, -1.0)] {
                    var p = Path()
                    let y0 = top ? 0.0 : h
                    p.move(to: CGPoint(x: 0, y: y0))
                    var x = -((off).truncatingRemainder(dividingBy: 60))
                    var i = Int(off / 60)
                    while x <= w + 60 {
                        let len = (0.04 + amp * Double(abs((i * 7919 + k * 31) % 13)) / 13) * h * (1 + Double(k) * 0.4)
                        p.addLine(to: CGPoint(x: x, y: y0))
                        p.addLine(to: CGPoint(x: x + 30, y: y0 + sign * len))
                        p.addLine(to: CGPoint(x: x + 60, y: y0))
                        x += 60; i += 1
                    }
                    p.addLine(to: CGPoint(x: w, y: y0))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(color.opacity(0.9)))
                }
                continue
            }
            path.move(to: CGPoint(x: 0, y: h))
            var x = 0.0
            while x <= w + 30 {
                let u = (x + off) / (world == .cliffs ? 90 : 160)
                let yy: Double
                if world == .cliffs {
                    let frac = u - floor(u)
                    let peak = Double(abs((Int(floor(u)) * 7919 + k * 17) % 11)) / 11
                    yy = h * (base - amp * (0.4 + peak) * (1 - abs(frac - 0.5) * 2))
                } else {
                    yy = h * (base - amp * (0.5 + 0.5 * sin(u * 2.1 + Double(k))))
                }
                path.addLine(to: CGPoint(x: x, y: yy))
                x += 15
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            ctx.fill(path, with: .color(color))
        }
    }

    /// Kip, a folded-paper bird. Wings beat after each flap, the body squashes and stretches with speed, and it
    /// tilts with its climb. Blinks while hurt.
    static func drawBird(_ ctx: inout GraphicsContext, at c: CGPoint, size s: Double, sim: FlightSim, clock: Double) {
        if sim.isHurt && Int(clock * 16) % 2 == 0 { return }
        let tilt = min(0.6, max(-0.55, sim.vy * 0.55))
        let stretch = 1 + min(0.18, abs(sim.vy) * 0.15)
        var wing = 0.0
        if let f = sim.lastFlap {
            let since = sim.t - f.t
            if since < 0.32 { wing = sin(min(1, since / 0.32) * .pi) * (0.6 + 0.6 * f.strength) }
        }
        if sim.phase == .ready { wing = 0.35 * sin(clock * 6) }
        var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: tilt)
        t = t.scaledBy(x: stretch, y: 1 / stretch)

        // Back wing (behind the body), darker.
        func wingPath(_ lift: Double, back: Bool) -> Path {
            var p = Path()
            let tipY = -s * (0.9 - 1.9 * lift) * (back ? 0.85 : 1)
            p.move(to: CGPoint(x: -s * 0.25, y: -s * 0.05))
            p.addLine(to: CGPoint(x: s * (back ? 0.15 : 0.05), y: tipY))
            p.addLine(to: CGPoint(x: s * 0.45, y: -s * 0.05))
            p.closeSubpath()
            return p
        }
        ctx.fill(wingPath(wing, back: true).applying(t), with: .color(Color(red: 0.80, green: 0.78, blue: 0.74)))
        // Body: a folded diamond with a crease, a pointed head and a tail.
        var body = Path()
        body.move(to: CGPoint(x: -s * 1.05, y: -s * 0.25))      // tail tip
        body.addLine(to: CGPoint(x: -s * 0.35, y: s * 0.05))
        body.addLine(to: CGPoint(x: s * 0.55, y: s * 0.35))
        body.addLine(to: CGPoint(x: s * 0.95, y: -s * 0.15))     // head
        body.addLine(to: CGPoint(x: s * 1.25, y: -s * 0.05))     // beak
        body.addLine(to: CGPoint(x: s * 0.80, y: -s * 0.35))
        body.addLine(to: CGPoint(x: s * 0.10, y: -s * 0.30))
        body.closeSubpath()
        ctx.fill(body.applying(t), with: .color(.white))
        var belly = Path()
        belly.move(to: CGPoint(x: -s * 0.35, y: s * 0.05))
        belly.addLine(to: CGPoint(x: s * 0.55, y: s * 0.35))
        belly.addLine(to: CGPoint(x: s * 0.70, y: s * 0.02))
        belly.closeSubpath()
        ctx.fill(belly.applying(t), with: .color(Color(red: 0.88, green: 0.86, blue: 0.82)))
        var beak = Path()
        beak.move(to: CGPoint(x: s * 0.95, y: -s * 0.15)); beak.addLine(to: CGPoint(x: s * 1.25, y: -s * 0.05)); beak.addLine(to: CGPoint(x: s * 0.98, y: s * 0.02))
        beak.closeSubpath()
        ctx.fill(beak.applying(t), with: .color(Palette.sun))
        ctx.fill(Path(ellipseIn: CGRect(x: s * 0.66, y: -s * 0.24, width: s * 0.14, height: s * 0.14)).applying(t), with: .color(Palette.ink))
        // Front wing.
        ctx.fill(wingPath(wing, back: false).applying(t), with: .color(.white))
        var crease = Path()
        crease.move(to: CGPoint(x: -s * 0.25, y: -s * 0.05)); crease.addLine(to: CGPoint(x: s * 0.45, y: -s * 0.05))
        ctx.stroke(crease.applying(t), with: .color(Color(red: 0.7, green: 0.68, blue: 0.64)), lineWidth: 1.5)
    }
}
