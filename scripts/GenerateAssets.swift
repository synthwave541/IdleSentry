import Cocoa
import AppKit

// MARK: - APP ICON GENERATION

enum IconStyle {
    case standard
    case clear
    case tinted
}

func drawAppIcon(size: CGFloat, style: IconStyle = .standard) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    let scale = size / 1024.0
    let cx = size / 2.0
    let cy = size / 2.0
    
    if style == .standard {
        // Draw macOS Squircle path
        let margin: CGFloat = 82 * scale
        let contentSize: CGFloat = 860 * scale
        let rect = NSRect(x: margin, y: margin, width: contentSize, height: contentSize)
        
        // Draw Shadow for base squircle
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
        shadow.shadowBlurRadius = 25 * scale
        
        NSGraphicsContext.current?.saveGraphicsState()
        shadow.set()
        
        // Background Squircle
        let r = 225 * scale
        let path = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
        
        // Base gradient (Deep dark space-gray/navy theme)
        let color1 = NSColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1.0)
        let color2 = NSColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
        let baseGradient = NSGradient(starting: color1, ending: color2)
        baseGradient?.draw(in: path, angle: -45)
        
        NSGraphicsContext.current?.restoreGraphicsState()
        
        // Inner border highlight
        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        let highlightColor = NSColor(white: 1.0, alpha: 0.12)
        highlightColor.setStroke()
        path.lineWidth = 4 * scale
        path.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
    
    // --- DRAW SHIELD (Perfectly Centered) ---
    let scx = cx
    let scy = cy
    let sW = 420.0 * scale
    let sH = 480.0 * scale
    
    let shieldPath = NSBezierPath()
    // Start at top middle (slight dip)
    shieldPath.move(to: NSPoint(x: scx, y: scy + sH/2 - 20*scale))
    // Curve to top-right corner
    shieldPath.curve(to: NSPoint(x: scx + sW/2, y: scy + sH/2),
                     controlPoint1: NSPoint(x: scx + sW/4, y: scy + sH/2 - 10*scale),
                     controlPoint2: NSPoint(x: scx + sW/2 - 25*scale, y: scy + sH/2))
    // Straight line down to mid height
    shieldPath.line(to: NSPoint(x: scx + sW/2, y: scy))
    // Curve to bottom tip
    shieldPath.curve(to: NSPoint(x: scx, y: scy - sH/2),
                     controlPoint1: NSPoint(x: scx + sW/2, y: scy - sH/4),
                     controlPoint2: NSPoint(x: scx + sW/4, y: scy - sH/2 + 50*scale))
    // Curve from bottom tip to left mid height
    shieldPath.curve(to: NSPoint(x: scx - sW/2, y: scy),
                     controlPoint1: NSPoint(x: scx - sW/4, y: scy - sH/2 + 50*scale),
                     controlPoint2: NSPoint(x: scx - sW/2, y: scy - sH/4))
    // Straight line up to top-left corner
    shieldPath.line(to: NSPoint(x: scx - sW/2, y: scy + sH/2))
    // Curve to top middle (slight dip)
    shieldPath.curve(to: NSPoint(x: scx, y: scy + sH/2 - 20*scale),
                     controlPoint1: NSPoint(x: scx - sW/2 + 25*scale, y: scy + sH/2),
                     controlPoint2: NSPoint(x: scx - sW/4, y: scy + sH/2 - 10*scale))
    shieldPath.close()
    
    // Set colors based on style
    let shieldGradColor1: NSColor
    let shieldGradColor2: NSColor
    let shieldStrokeColor: NSColor
    let clockColor: NSColor
    let pinColor: NSColor
    let khColor: NSColor
    let clockBGColor: NSColor
    
    if style == .tinted {
        // Grayscale / template colors for tinting
        shieldGradColor1 = NSColor(white: 1.0, alpha: 0.35)
        shieldGradColor2 = NSColor(white: 1.0, alpha: 0.15)
        shieldStrokeColor = NSColor(white: 1.0, alpha: 0.85)
        clockColor = NSColor(white: 1.0, alpha: 0.95)
        pinColor = NSColor(white: 1.0, alpha: 1.0)
        khColor = NSColor(white: 1.0, alpha: 0.7)
        clockBGColor = NSColor(white: 0.0, alpha: 0.8)
    } else {
        // Standard colored version (used for standard and clear)
        shieldGradColor1 = NSColor(red: 0.16, green: 0.22, blue: 0.38, alpha: 0.95)
        shieldGradColor2 = NSColor(red: 0.08, green: 0.10, blue: 0.20, alpha: 0.95)
        shieldStrokeColor = NSColor(red: 0.3, green: 0.55, blue: 0.95, alpha: 0.95)
        clockColor = NSColor(red: 1.0, green: 0.65, blue: 0.1, alpha: 0.95)
        pinColor = NSColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
        khColor = NSColor(red: 0.3, green: 0.55, blue: 0.95, alpha: 0.8)
        clockBGColor = NSColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1.0)
    }
    
    let shieldGradient = NSGradient(starting: shieldGradColor1, ending: shieldGradColor2)
    
    NSGraphicsContext.current?.saveGraphicsState()
    // Shield shadow (only for standard and clear)
    if style != .tinted {
        let shieldShadow = NSShadow()
        shieldShadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shieldShadow.shadowOffset = NSSize(width: -4 * scale, height: -8 * scale)
        shieldShadow.shadowBlurRadius = 16 * scale
        shieldShadow.set()
    }
    
    shieldGradient?.draw(in: shieldPath, angle: -45)
    NSGraphicsContext.current?.restoreGraphicsState()
    
    // Outer shield border
    NSGraphicsContext.current?.saveGraphicsState()
    shieldStrokeColor.setStroke()
    shieldPath.lineWidth = 12 * scale
    shieldPath.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
    
    // Draw Sleek Keyhole in the center of the Shield (representing privacy/locking)
    let khCircle = NSBezierPath(ovalIn: NSRect(x: scx - 18*scale, y: scy + 10*scale, width: 36*scale, height: 36*scale))
    khColor.setFill()
    khCircle.fill()
    
    let khSlit = NSBezierPath()
    khSlit.move(to: NSPoint(x: scx - 12*scale, y: scy + 16*scale))
    khSlit.line(to: NSPoint(x: scx + 12*scale, y: scy + 16*scale))
    khSlit.line(to: NSPoint(x: scx + 6*scale, y: scy - 20*scale))
    khSlit.line(to: NSPoint(x: scx - 6*scale, y: scy - 20*scale))
    khSlit.close()
    khSlit.fill()
    
    // --- DRAW CLOCK BADGE (Tiny on Bottom-Right corner of shield) ---
    let ccx = cx + 220.0 * scale
    let ccy = cy - 200.0 * scale
    let cR = 85.0 * scale
    
    // Outer glow ring shadow
    NSGraphicsContext.current?.saveGraphicsState()
    if style != .tinted {
        let clockShadow = NSShadow()
        clockShadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        clockShadow.shadowOffset = NSSize(width: 3 * scale, height: -3 * scale)
        clockShadow.shadowBlurRadius = 10 * scale
        clockShadow.set()
    }
    
    // Cutout / Dark Background for Clock to stand out from shield
    let clockBG = NSBezierPath(ovalIn: NSRect(x: ccx - cR, y: ccy - cR, width: cR * 2, height: cR * 2))
    clockBGColor.setFill()
    clockBG.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    
    // Clock outer ring stroke
    clockColor.setStroke()
    clockBG.lineWidth = 8 * scale
    clockBG.stroke()
    
    // Clock tick marks
    let ticks = NSBezierPath()
    let tickPadding = 5.0 * scale
    let tickLength = 15.0 * scale
    
    // 12 o'clock
    ticks.move(to: NSPoint(x: ccx, y: ccy + cR - tickPadding))
    ticks.line(to: NSPoint(x: ccx, y: ccy + cR - tickLength))
    
    // 6 o'clock
    ticks.move(to: NSPoint(x: ccx, y: ccy - cR + tickPadding))
    ticks.line(to: NSPoint(x: ccx, y: ccy - cR + tickLength))
    
    // 3 o'clock
    ticks.move(to: NSPoint(x: ccx + cR - tickPadding, y: ccy))
    ticks.line(to: NSPoint(x: ccx + cR - tickLength, y: ccy))
    
    // 9 o'clock
    ticks.move(to: NSPoint(x: ccx - cR + tickPadding, y: ccy))
    ticks.line(to: NSPoint(x: ccx - cR + tickLength, y: ccy))
    
    ticks.lineWidth = 5 * scale
    ticks.lineCapStyle = .round
    clockColor.setStroke()
    ticks.stroke()
    
    // Clock hands
    let handsPath = NSBezierPath()
    // Center to 12 (Minute hand)
    handsPath.move(to: NSPoint(x: ccx, y: ccy))
    handsPath.line(to: NSPoint(x: ccx, y: ccy + 50*scale))
    
    // Center to 2:30 (Hour hand)
    handsPath.move(to: NSPoint(x: ccx, y: ccy))
    handsPath.line(to: NSPoint(x: ccx + 32*scale, y: ccy - 18*scale))
    
    handsPath.lineWidth = 6 * scale
    handsPath.lineCapStyle = .round
    clockColor.setStroke()
    handsPath.stroke()
    
    // Center pin
    let pinPath = NSBezierPath(ovalIn: NSRect(x: ccx - 8*scale, y: ccy - 8*scale, width: 16*scale, height: 16*scale))
    pinColor.setFill()
    pinPath.fill()
    
    NSGraphicsContext.current?.restoreGraphicsState()
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: path))
    }
}

func generateIconStyle(style: IconStyle, outputName: String) {
    let fm = FileManager.default
    let iconsetDir = "\(outputName).iconset"
    
    try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true, attributes: nil)
    
    let sizes: [(String, CGFloat)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    print("Drawing \(outputName) sizes...")
    for (filename, size) in sizes {
        let img = drawAppIcon(size: size, style: style)
        savePNG(image: img, path: "\(iconsetDir)/\(filename)")
    }
    
    print("Compiling \(outputName).icns using iconutil...")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", iconsetDir, "-o", "\(outputName).icns"]
    try? task.run()
    task.waitUntilExit()
    
    // Clean up iconset folder
    try? fm.removeItem(atPath: iconsetDir)
    print("\(outputName).icns generated successfully!")
}

func generateAppIcon() {
    generateIconStyle(style: .standard, outputName: "AppIcon")
    generateIconStyle(style: .clear, outputName: "AppIcon-clear")
    generateIconStyle(style: .tinted, outputName: "AppIcon-tinted")
}

func generateDmgBackground() {
    let width: CGFloat = 600
    let height: CGFloat = 380

    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()

    // 1. Background gradient (clean light gray/white macOS theme)
    let bgRect = NSRect(x: 0, y: 0, width: width, height: height)
    let startColor = NSColor(white: 0.96, alpha: 1.0)
    let endColor = NSColor(white: 0.90, alpha: 1.0)
    let gradient = NSGradient(starting: startColor, ending: endColor)
    gradient?.draw(in: bgRect, angle: -45)

    // 2. Draw modern translucent card panels for drag and drop (dark borders/fills for light theme)
    let cardWidth: CGFloat = 116
    let cardHeight: CGFloat = 116
    let cardRadius: CGFloat = 14
    
    // App panel (Left) - Centered at (150, 190)
    let leftCardRect = NSRect(x: 92, y: 132, width: cardWidth, height: cardHeight)
    let leftCardPath = NSBezierPath(roundedRect: leftCardRect, xRadius: cardRadius, yRadius: cardRadius)
    NSColor(white: 0.0, alpha: 0.03).setFill()
    leftCardPath.fill()
    NSColor(white: 0.0, alpha: 0.08).setStroke()
    leftCardPath.lineWidth = 1
    leftCardPath.stroke()
    
    // Applications panel (Right) - Centered at (450, 190)
    let rightCardRect = NSRect(x: 392, y: 132, width: cardWidth, height: cardHeight)
    let rightCardPath = NSBezierPath(roundedRect: rightCardRect, xRadius: cardRadius, yRadius: cardRadius)
    NSColor(white: 0.0, alpha: 0.03).setFill()
    rightCardPath.fill()
    NSColor(white: 0.0, alpha: 0.08).setStroke()
    rightCardPath.lineWidth = 1
    rightCardPath.stroke()

    // 3. Draw a modern sleek arrow in the center pointing right (perfectly symmetric, dark gray)
    let arrowPath = NSBezierPath()
    let ax: CGFloat = 300
    let ay: CGFloat = 190
    arrowPath.move(to: NSPoint(x: ax - 30, y: ay - 6))
    arrowPath.line(to: NSPoint(x: ax + 10, y: ay - 6))
    arrowPath.line(to: NSPoint(x: ax + 10, y: ay - 16))
    arrowPath.line(to: NSPoint(x: ax + 30, y: ay))
    arrowPath.line(to: NSPoint(x: ax + 10, y: ay + 16))
    arrowPath.line(to: NSPoint(x: ax + 10, y: ay + 6))
    arrowPath.line(to: NSPoint(x: ax - 30, y: ay + 6))
    arrowPath.close()

    NSColor(white: 0.0, alpha: 0.12).setFill()
    arrowPath.fill()
    NSColor(white: 0.0, alpha: 0.28).setStroke()
    arrowPath.lineWidth = 2
    arrowPath.stroke()

    // 4. Draw labels and helper instructions (dark gray for light background contrast)
    let textStyle = NSMutableParagraphStyle()
    textStyle.alignment = .center
    
    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor(white: 0.0, alpha: 0.85),
        .paragraphStyle: textStyle
    ]
    
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor(white: 0.0, alpha: 0.50),
        .paragraphStyle: textStyle
    ]

    "Install IdleSentry".draw(in: NSRect(x: 0, y: 310, width: width, height: 25), withAttributes: titleAttributes)
    "Drag the icon into the Applications folder shortcut".draw(in: NSRect(x: 0, y: 285, width: width, height: 20), withAttributes: subtitleAttributes)

    image.unlockFocus()
    savePNG(image: image, path: "background.png")
    print("background.png generated successfully!")
}

// Run Generations
generateAppIcon()
generateDmgBackground()
