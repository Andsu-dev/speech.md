// Arte de fundo do dmg. Roda pelo scripts/dmg.sh, escreve um tiff com as
// representações 1x e 2x. Fica em script pra arte continuar editável — o
// tiff sozinho seria um blob que ninguém consegue mexer.
import AppKit

let W = 600.0, H = 400.0
let out1x = CommandLine.arguments[1]
let out2x = CommandLine.arguments[2]

/// Mesma onda do WaveformBars da ilha, congelada num instante bonito.
func barHeight(index: Int, time: Double, maxHeight: Double) -> Double {
    let phase = Double(index) * 0.55
    let wave = sin(time * 5.2 - phase) * 0.5 + sin(time * 2.7 - phase * 0.7) * 0.32
    return max(2.5, maxHeight * (0.18 + 0.82 * (wave + 0.82) / 1.64))
}

func text(
    _ string: String, size: CGFloat, weight: NSFont.Weight,
    design: NSFontDescriptor.SystemDesign = .default,
    color: NSColor, centerX: CGFloat, top: CGFloat
) {
    var font = NSFont.systemFont(ofSize: size, weight: weight)
    if let descriptor = font.fontDescriptor.withDesign(design) {
        font = NSFont(descriptor: descriptor, size: size) ?? font
    }
    let attributed = NSAttributedString(
        string: string, attributes: [.font: font, .foregroundColor: color]
    )
    let bounds = attributed.size()
    attributed.draw(at: NSPoint(x: centerX - bounds.width / 2, y: H - top - bounds.height))
}

func draw(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Fundo: o off-white morno do Theme.canvas claro.
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: [
        CGColor(colorSpace: space, components: [0.995, 0.992, 0.985, 1])!,
        CGColor(colorSpace: space, components: [0.953, 0.945, 0.933, 1])!
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: H), options: [])

    // A ilha, pendurada na borda de cima como no app: cantos de baixo
    // arredondados, os de cima retos porque encostam no topo da janela.
    let islandWidth = 196.0, islandHeight = 34.0
    let island = NSRect(x: (W - islandWidth) / 2, y: H - islandHeight,
                        width: islandWidth, height: islandHeight)
    let pill = NSBezierPath()
    let radius = 18.0
    pill.move(to: NSPoint(x: island.minX, y: island.maxY))
    pill.line(to: NSPoint(x: island.minX, y: island.minY + radius))
    pill.appendArc(withCenter: NSPoint(x: island.minX + radius, y: island.minY + radius),
                   radius: radius, startAngle: 180, endAngle: 270)
    pill.line(to: NSPoint(x: island.maxX - radius, y: island.minY))
    pill.appendArc(withCenter: NSPoint(x: island.maxX - radius, y: island.minY + radius),
                   radius: radius, startAngle: 270, endAngle: 360)
    pill.line(to: NSPoint(x: island.maxX, y: island.maxY))
    pill.close()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14,
                  color: NSColor.black.withAlphaComponent(0.22).cgColor)
    NSColor.black.setFill()
    pill.fill()
    ctx.restoreGState()

    // Orelha esquerda: as barras da waveform. Direita: o cronômetro.
    let barWidth = 3.0, barSpacing = 3.5, maxBar = 15.0
    let barsLeft = island.minX + 16
    for index in 0..<4 {
        let height = barHeight(index: index, time: 17.68, maxHeight: maxBar)
        let bar = NSRect(
            x: barsLeft + Double(index) * (barWidth + barSpacing),
            y: island.midY - height / 2, width: barWidth, height: height
        )
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
    }
    let clock = NSAttributedString(string: "0:07", attributes: [
        .font: NSFont(
            descriptor: NSFont.systemFont(ofSize: 11, weight: .medium)
                .fontDescriptor.withDesign(.rounded)!, size: 11
        )!,
        .foregroundColor: NSColor.white.withAlphaComponent(0.85)
    ])
    clock.draw(at: NSPoint(x: island.maxX - 16 - clock.size().width,
                           y: island.midY - clock.size().height / 2))

    // Seta entre os dois ícones, na altura do centro do ícone.
    let arrowConfig = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [
            NSColor(srgbRed: 0.74, green: 0.72, blue: 0.70, alpha: 1)
        ]))
    if let arrow = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)?
        .withSymbolConfiguration(arrowConfig) {
        let size = arrow.size
        arrow.draw(in: NSRect(x: (W - size.width) / 2, y: H - 201 - size.height / 2,
                              width: size.width, height: size.height))
    }

    text("Drag speech.md into Applications", size: 15, weight: .semibold,
         color: NSColor(srgbRed: 0.16, green: 0.15, blue: 0.14, alpha: 1),
         centerX: W / 2, top: 78)
    text("Voice transcription that never leaves your Mac", size: 12, weight: .regular,
         color: NSColor(srgbRed: 0.46, green: 0.44, blue: 0.42, alpha: 1),
         centerX: W / 2, top: 101)
    text("100% on-device  ·  appconty.com", size: 11, weight: .regular,
         color: NSColor(srgbRed: 0.64, green: 0.62, blue: 0.60, alpha: 1),
         centerX: W / 2, top: 356)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Dois pngs; quem junta em tiff hidpi é o tiffutil, no dmg.sh.
for (rep, path) in [(draw(scale: 1), out1x), (draw(scale: 2), out2x)] {
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}
