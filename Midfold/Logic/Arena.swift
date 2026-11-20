import CoreGraphics

/// Geometry of a face-to-face duel: the screen is split at the fold (or the middle) and each half is turned
/// toward the player sitting on that side. Pure math so it can be unit-tested.
struct ArenaLayout: Equatable {
    struct Side: Equatable {
        var rect: CGRect        // in arena coordinates
        var rotation: Double    // degrees, clockwise; content's top points toward the fold
        /// Size of the player's own (rotated) canvas.
        var localSize: CGSize {
            abs(rotation.truncatingRemainder(dividingBy: 180)) == 90
                ? CGSize(width: rect.height, height: rect.width) : rect.size
        }
    }

    var size: CGSize
    var fold: CGRect            // the dividing line (may be zero width)
    var vertical: Bool          // fold runs top-to-bottom → players sit left and right
    var sides: [Side]

    /// `division` is the iPhone Duo fold in arena coordinates, if the system reports one.
    init(size: CGSize, division: CGRect?) {
        self.size = size
        let usable: CGRect? = division.flatMap { d in
            let inside = CGRect(origin: .zero, size: size).insetBy(dx: -1, dy: -1).contains(d)
            return inside && (d.width > 0 || d.height > 0) ? d : nil
        }
        if let d = usable {
            vertical = d.height >= d.width
        } else {
            vertical = size.width > size.height
        }
        if let d = usable {
            fold = vertical
                ? CGRect(x: d.minX, y: 0, width: d.width, height: size.height)
                : CGRect(x: 0, y: d.minY, width: size.width, height: d.height)
        } else {
            fold = vertical
                ? CGRect(x: size.width / 2, y: 0, width: 0, height: size.height)
                : CGRect(x: 0, y: size.height / 2, width: size.width, height: 0)
        }
        if vertical {
            sides = [
                Side(rect: CGRect(x: 0, y: 0, width: fold.minX, height: size.height), rotation: 90),
                Side(rect: CGRect(x: fold.maxX, y: 0, width: size.width - fold.maxX, height: size.height), rotation: -90),
            ]
        } else {
            sides = [
                Side(rect: CGRect(x: 0, y: fold.maxY, width: size.width, height: size.height - fold.maxY), rotation: 0),
                Side(rect: CGRect(x: 0, y: 0, width: size.width, height: fold.minY), rotation: 180),
            ]
        }
    }

    /// Which player's half a touch landed in, and where in that player's own (rotated) canvas.
    func locate(_ p: CGPoint) -> (player: Player, local: CGPoint)? {
        for (i, s) in sides.enumerated() where s.rect.contains(p) {
            return (i, Self.toLocal(p, side: s))
        }
        return nil
    }

    static func toLocal(_ p: CGPoint, side s: Side) -> CGPoint {
        let r = s.rect
        switch Int(s.rotation) {
        case 90: return CGPoint(x: p.y - r.minY, y: r.maxX - p.x)
        case -90: return CGPoint(x: r.maxY - p.y, y: p.x - r.minX)
        case 180: return CGPoint(x: r.maxX - p.x, y: r.maxY - p.y)
        default: return CGPoint(x: p.x - r.minX, y: p.y - r.minY)
        }
    }

    static func toArena(_ l: CGPoint, side s: Side) -> CGPoint {
        let r = s.rect
        switch Int(s.rotation) {
        case 90: return CGPoint(x: r.maxX - l.y, y: r.minY + l.x)
        case -90: return CGPoint(x: r.minX + l.y, y: r.maxY - l.x)
        case 180: return CGPoint(x: r.maxX - l.x, y: r.maxY - l.y)
        default: return CGPoint(x: r.minX + l.x, y: r.minY + l.y)
        }
    }
}

/// Square grid placed in a player's canvas, leaving room for a header strip at the top. The top of each canvas
/// faces the fold, so the header (score, status) sits next to the fold and the grid sits near the player.
struct GridLayout: Equatable {
    var frame: CGRect
    var columns: Int

    init(canvas: CGSize, columns: Int, header: CGFloat = 64, footer: CGFloat = 24, padding: CGFloat = 16) {
        self.columns = columns
        let availW = canvas.width - padding * 2
        let availH = canvas.height - header - footer
        let side = max(0, min(availW, availH))
        frame = CGRect(x: (canvas.width - side) / 2, y: header + (availH - side) / 2, width: side, height: side)
    }

    var cellSize: CGFloat { frame.width / CGFloat(columns) }

    func cellRect(_ i: Int) -> CGRect {
        let c = i % columns, r = i / columns
        return CGRect(x: frame.minX + CGFloat(c) * cellSize, y: frame.minY + CGFloat(r) * cellSize,
                      width: cellSize, height: cellSize)
    }

    func cell(at p: CGPoint) -> Int? {
        guard frame.contains(p) else { return nil }
        let c = min(columns - 1, Int((p.x - frame.minX) / cellSize))
        let r = min(columns - 1, Int((p.y - frame.minY) / cellSize))
        return r * columns + c
    }
}
