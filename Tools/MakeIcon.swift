// 生成透明背景的应用图标 PNG（无底色），供 make icon / 打包时使用。
// 用法：swiftc -o build/make-icon Tools/MakeIcon.swift && ./build/make-icon Resources

import AppKit

let canvas = 1024
let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

guard let context = CGContext(
    data: nil,
    width: canvas,
    height: canvas,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("无法创建绘图上下文\n".utf8))
    exit(1)
}

// 使用左上角为原点的坐标系，便于按设计稿摆放
context.translateBy(x: 0, y: CGFloat(canvas))
context.scaleBy(x: 1, y: -1)
context.setAllowsAntialiasing(true)
context.interpolationQuality = .high

let brandStart = color(0x7B5BFF)
let brandEnd = color(0x22D3EE)

func capsule(_ rect: CGRect) -> CGPath {
    CGPath(
        roundedRect: rect,
        cornerWidth: rect.height / 2,
        cornerHeight: rect.height / 2,
        transform: nil
    )
}

/// 以品牌渐变填充给定路径
func fillGradient(_ path: CGPath, alpha: CGFloat, from: CGPoint, to: CGPoint) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [brandStart.copy(alpha: alpha)!, brandEnd.copy(alpha: alpha)!] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: from, end: to, options: [])
    context.restoreGState()
}

// MARK: - 背景两条渐隐的「条目」条，营造列表 / 卡组层次

let ghostA = CGRect(x: 226, y: 624, width: 572, height: 76)
fillGradient(
    capsule(ghostA),
    alpha: 0.5,
    from: CGPoint(x: ghostA.minX, y: ghostA.minY),
    to: CGPoint(x: ghostA.maxX, y: ghostA.maxY)
)

let ghostB = CGRect(x: 326, y: 748, width: 372, height: 76)
fillGradient(
    capsule(ghostB),
    alpha: 0.3,
    from: CGPoint(x: ghostB.minX, y: ghostB.minY),
    to: CGPoint(x: ghostB.maxX, y: ghostB.maxY)
)

// MARK: - 主开关

let hero = CGRect(x: 150, y: 204, width: 724, height: 344)
let heroPath = capsule(hero)

fillGradient(
    heroPath,
    alpha: 1,
    from: CGPoint(x: hero.minX, y: hero.minY),
    to: CGPoint(x: hero.maxX, y: hero.maxY)
)

// 顶部高光，让平面渐变更有体积感
context.saveGState()
context.addPath(heroPath)
context.clip()
let highlight = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0xFFFFFF, alpha: 0.34), color(0xFFFFFF, alpha: 0.0)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    highlight,
    start: CGPoint(x: hero.midX, y: hero.minY),
    end: CGPoint(x: hero.midX, y: hero.midY),
    options: []
)
context.restoreGState()

// 白色滑块（开关处于开启状态）
let knobSize: CGFloat = 264
let knobRect = CGRect(
    x: hero.maxX - 40 - knobSize,
    y: hero.midY - knobSize / 2,
    width: knobSize,
    height: knobSize
)
context.saveGState()
context.addPath(CGPath(ellipseIn: knobRect, transform: nil))
context.setShadow(offset: CGSize(width: 0, height: -8), blur: 30, color: color(0x1B1464, alpha: 0.3))
context.setFillColor(color(0xFFFFFF, alpha: 0.98))
context.fillPath()
context.restoreGState()

// MARK: - 输出 PNG

guard let image = context.makeImage() else {
    FileHandle.standardError.write(Data("渲染失败\n".utf8))
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: image)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG 编码失败\n".utf8))
    exit(1)
}

let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let url = directory.appendingPathComponent("AppIcon.png")
try png.write(to: url)
print("已生成 \(url.path)（1024×1024，透明背景）")
