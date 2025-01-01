import SwiftUI
import CoreText

// MARK: - 1. A Reusable Shape for Outlining Any Text
// --------------------------------------------------
// (Unchanged from earlier examples.)
struct TextOutlineShape: Shape {
    let text: String
    let font: UIFont
    
    func path(in rect: CGRect) -> Path {
        var textPath = Path()
        
        let attrString = NSAttributedString(
            string: text,
            attributes: [.font: font]
        )
        let line = CTLineCreateWithAttributedString(attrString)
        let runs = CTLineGetGlyphRuns(line) as [AnyObject] as! [CTRun]
        
        var xOffset: CGFloat = 0
        for run in runs {
            let runFont = unsafeBitCast(
                CFDictionaryGetValue(
                    CTRunGetAttributes(run),
                    Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()
                ),
                to: CTFont.self
            )
            let glyphCount = CTRunGetGlyphCount(run)
            for glyphIndex in 0..<glyphCount {
                let glyphRange = CFRange(location: glyphIndex, length: 1)
                var glyph: CGGlyph = 0
                CTRunGetGlyphs(run, glyphRange, &glyph)
                var position: CGPoint = .zero
                CTRunGetPositions(run, glyphRange, &position)
                
                if let letterPath = CTFontCreatePathForGlyph(runFont, glyph, nil) {
                    let transform = CGAffineTransform(
                        translationX: position.x + xOffset,
                        y: 0
                    )
                    textPath.addPath(Path(letterPath), transform: transform)
                }
            }
            let runWidth = CGFloat(CTRunGetTypographicBounds(
                run, CFRange(location: 0, length: 0), nil, nil, nil
            ))
            xOffset += runWidth
        }
        
        var finalPath = textPath.applying(CGAffineTransform(scaleX: 1, y: -1))
        
        let boundingBox = finalPath.boundingRect
        let offsetX = (rect.width - boundingBox.width) / 2
        let offsetY = (rect.height - boundingBox.height) / 2
        
        finalPath = finalPath.offsetBy(dx: offsetX, dy: offsetY + boundingBox.height)
        return finalPath
    }
}

func roundedUIFont(size: CGFloat, weight: UIFont.Weight = .heavy) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    if let descriptor = base.fontDescriptor.withDesign(.rounded) {
        return UIFont(descriptor: descriptor, size: size)
    }
    return base
}

struct AnimatedTextPath: View {
    let text: String
    let fontSize: CGFloat
    
    @Binding var onDrawingComplete: Bool
    
    @State private var animatedTrim: CGFloat = 0
    @State private var animateGradientAngle: Double = 0
    @State private var isDone = false
    var body: some View {
        ZStack {
            TextOutlineShape(
                text: text,
                font: roundedUIFont(size: fontSize)
            )
            .trim(from: 0, to: animatedTrim)
            .fill (
                

                isDone ? Color.white : Color.clear

                )
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple]),
                    center: .center,
                    angle: .degrees(animateGradientAngle)
                ),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
            // Glow effect
            .shadow(color: .white.opacity(0.7), radius: 10, x: 0, y: 0)
            .shadow(color: .cyan.opacity(0.4), radius: 15, x: 0, y: 0)
        }
        .onAppear {
            // Animate the "draw" effect over 4 seconds
            withAnimation(.linear(duration: 4)) {
                animatedTrim = 1
               
            }
            
            // Animate gradient angle forever
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                animateGradientAngle = 360
            }
            
            // After 4 seconds, signal drawing complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                onDrawingComplete = true
                withAnimation {
                    isDone = true
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let finalX: CGFloat
    let finalY: CGFloat
    let color: Color
}

struct Confetti2025View: View {
    @Binding var pop: Bool
    @Binding var on2025Complete: Bool
    
    @State private var particles: [ConfettiParticle] = []
    
    let shapeText = "2025"
    let shapeFontSize: CGFloat = 120
    let totalPoints = 400
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: 4, height: 4)
                        .position(x: particle.x, y: particle.y)
                
                        
                }
            }
            .onAppear {
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2
                let shapeWidth: CGFloat = 350
                let shapeHeight: CGFloat = 120
                let shapeRect = CGRect(
                    x: centerX - shapeWidth/2,
                    y: centerY - shapeHeight/2,
                    width: shapeWidth,
                    height: shapeHeight
                )
                let shape = TextOutlineShape(
                    text: shapeText,
                    font: roundedUIFont(size: shapeFontSize)
                )
                let path = shape.path(in: CGRect(x: 0, y: 0, width: shapeWidth, height: shapeHeight)).cgPath
                let shapePoints = generatePoints(
                    in: path,
                    count: totalPoints,
                    boundingRect: CGRect(origin: .zero, size: CGSize(width: shapeWidth, height: shapeHeight))
                )
                
                let launchX = geo.size.width / 2
                let launchY = geo.size.height + 40
                
                particles = shapePoints.map { pt in
                    let finalPosX = shapeRect.origin.x + pt.x
                    let finalPosY = shapeRect.origin.y + pt.y
                    return ConfettiParticle(
                        x: launchX,
                        y: launchY,
                        finalX: finalPosX,
                        finalY: finalPosY,
                        color: randomConfettiColor()
                    )
                }
            }
            .onChange(of: pop) { newValue in
                guard newValue else { return }
                withAnimation(.easeOut(duration: 2)) {
                    for i in particles.indices {
                        particles[i].x = particles[i].finalX
                        particles[i].y = particles[i].finalY
                    }
                }
                // Once fully formed "2025", let parent know
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    on2025Complete = true
                }
            }
        }
    }
    
    func randomConfettiColor() -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue,
            .purple, .pink, .mint, .cyan, .white
        ]
        return colors.randomElement() ?? .white
    }
    
    func generatePoints(in path: CGPath, count: Int, boundingRect: CGRect) -> [CGPoint] {
        var results: [CGPoint] = []
        let maxAttempts = count * 10
        var attempts = 0
        
        while results.count < count && attempts < maxAttempts {
            attempts += 1
            let rx = CGFloat.random(in: 0..<boundingRect.width)
            let ry = CGFloat.random(in: 0..<boundingRect.height)
            let candidate = CGPoint(x: rx, y: ry)
            if path.contains(candidate) {
                results.append(candidate)
            }
        }
        return results
    }
}

struct AnyShape: Shape {
    private let makePath: (CGRect) -> Path
    
    init<S: Shape>(_ wrapped: S) {
        makePath = { rect in
            wrapped.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        makePath(rect)
    }
}

enum ConfettiShapeType: CaseIterable {
    case circle, capsule, roundedRect, star
    
    /// Build a SwiftUI View from the shape type.
    @ViewBuilder
    func shapeView() -> AnyShape {
        switch self {
        case .circle:
            return AnyShape(Circle())
        case .capsule:
            return AnyShape(Capsule())
        case .roundedRect:
            return AnyShape(RoundedRectangle(cornerRadius: 6))
        case .star:
            return AnyShape(StarShape(points: 5))
        }
    }
}

struct StarShape: Shape {
    let points: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        let angle = 2.0 * .pi / Double(points)
        let radius = min(rect.width, rect.height) / 2
        
        var currentAngle: Double = -Double.pi / 2
        let step = angle / 2
        
        // We'll make a star by alternating points at radius and some fraction of radius
        let innerRadius = radius * 0.4
        
        for i in 0..<(points * 2) {
            let dist = i % 2 == 0 ? radius : innerRadius
            let x = center.x + CGFloat(cos(currentAngle) * dist)
            let y = center.y + CGFloat(sin(currentAngle) * dist)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            currentAngle += step
        }
        path.closeSubpath()
        return path
    }
}

struct RealConfettiParticle: Identifiable {
    let id = UUID()
    
    // Position & movement
    var x: CGFloat
    var y: CGFloat
    
    // Shape & size
    let shapeType: ConfettiShapeType
    let size: CGSize
    
    // Color
    let color: Color
    
    // Rotation
    var rotation: Double
    let rotationSpeed: Double
    
    // We'll animate position from top to bottom and also animate rotation
}

struct RealConfettiShowerView: View {
    @Binding var startShower: Bool
    
    @State private var particles: [RealConfettiParticle] = []
    
    // Adjust how many to spawn & how quickly
    let totalParticles = 50
    let spawnInterval = 0.15
    let fallDuration: Double = 1.5
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    particle.shapeType.shapeView()
                        .fill(particle.color)
                        .frame(width: particle.size.width, height: particle.size.height)
                        // Apply a rotation effect
                        .rotationEffect(.degrees(particle.rotation))
                        // Position it
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onChange(of: startShower) { newValue in
                guard newValue else { return }
                // Start spawning real confetti from the top
                spawnConfetti(in: geo.size)
            }
        }
    }
    
    func spawnConfetti(in size: CGSize) {
        var spawned = 0
        
        Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { timer in
            guard spawned < totalParticles else {
                timer.invalidate()
                return
            }
            spawned += 1
            
            // Create a random confetti shape
            let randomShape = ConfettiShapeType.allCases.randomElement()!
            
            let randomWidth = CGFloat.random(in: 10...30)
            let randomHeight = CGFloat.random(in: 10...30)
            
            let randomX = CGFloat.random(in: 0...size.width)
            let topSpawnY = -40.0  // a bit above the screen
            let randomColor = randomConfettiColor()
            
            // Random rotation start & speed
            let startRotation = Double.random(in: 0...360)
            let rotationSpeed = Double.random(in: 30...200) // degrees per second
            
            let newParticle = RealConfettiParticle(
                x: randomX,
                y: topSpawnY,
                shapeType: randomShape,
                size: CGSize(width: randomWidth, height: randomHeight),
                color: randomColor,
                rotation: startRotation,
                rotationSpeed: rotationSpeed
            )
            
            particles.append(newParticle)
            
            // Animate the particle's fall + rotation
            let fallDistance = size.height + 80
            
            withAnimation(.linear(duration: fallDuration)) {
                if let idx = particles.firstIndex(where: { $0.id == newParticle.id }) {
                    // Move down
                    particles[idx].y += fallDistance
                }
            }
            
            // Also animate rotation in a separate Task or withAnimation
            // We'll increment rotation over fallDuration
            Task {
                let frames = 60.0 * fallDuration
                let degreesPerFrame = rotationSpeed / 60.0
                for _ in 0..<Int(frames) {
                    try? await Task.sleep(nanoseconds: 16_666_667)  // ~60 FPS
                    if let i = particles.firstIndex(where: { $0.id == newParticle.id }) {
                        particles[i].rotation += degreesPerFrame
                    } else {
                        break
                    }
                }
            }
        }
    }
    
    func randomConfettiColor() -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue,
            .purple, .pink, .mint, .cyan, .white, .brown
        ]
        return colors.randomElement() ?? .white
    }
}

struct HappyNewYearDrawnView: View {
    // Step 1
    @State private var drawingComplete = false
    // Step 2
    @State private var pop2025 = false
    @State private var yearFormationComplete = false
    // Step 3
    @State private var startRealConfettiShower = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // "Happy New Year!"
            AnimatedTextPath(
                text: "Happy New Year!",
                fontSize: 100,
                onDrawingComplete: $drawingComplete
            )
            .frame(width: 400, height: 200)
            
            // "2025" confetti
            Confetti2025View(pop: $pop2025, on2025Complete: $yearFormationComplete)
                .padding(.top, 300)
                .shadow(color: .white, radius: 10)
            
            // "Real" confetti shower
            RealConfettiShowerView(startShower: $startRealConfettiShower)
        }
        .onChange(of: drawingComplete) { done in
            if done {
                pop2025 = true
            }
        }
        .onChange(of: yearFormationComplete) { formed in
            if formed {
                // Trigger the "real confetti" shower
                startRealConfettiShower = true
            }
        }
    }
}

// MARK: - 6. Preview
struct HappyNewYearDrawnView_Previews: PreviewProvider {
    static var previews: some View {
        HappyNewYearDrawnView()
    }
}
