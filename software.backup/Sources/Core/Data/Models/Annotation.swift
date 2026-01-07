//
//  Annotation.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI
@preconcurrency import Combine

// MARK: - Annotation Protocol

protocol Annotation: AnyObject, Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var isVisible: Bool { get set }
    var isLocked: Bool { get set }
    var color: Color { get set }
    var strokeWidth: CGFloat { get set }
    var opacity: Double { get set }
    var createdAt: Date { get }
    var keyframes: [Keyframe] { get set }
    var angleId: String { get set } // Camera angle ID for multi-angle support
    var startTimeMs: Int64 { get set } // Start time in milliseconds
    var endTimeMs: Int64 { get set } // End time in milliseconds (0 = no end)

    func draw(in context: GraphicsContext, at time: Double)
    func isVisible(at timeMs: Int64) -> Bool
}

// MARK: - Keyframe

struct Keyframe: Identifiable, Codable {
    let id: UUID
    var timestamp: Double // milliseconds
    var properties: AnnotationProperties

    init(id: UUID = UUID(), timestamp: Double, properties: AnnotationProperties) {
        self.id = id
        self.timestamp = timestamp
        self.properties = properties
    }
}

// MARK: - Annotation Properties

struct AnnotationProperties: Codable {
    var position: CGPoint
    var scale: CGFloat
    var rotation: Double
    var opacity: Double

    init(position: CGPoint = .zero, scale: CGFloat = 1.0, rotation: Double = 0.0, opacity: Double = 1.0) {
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
    }
}

// MARK: - Arrow Annotation

class ArrowAnnotation: Annotation, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var isVisible: Bool
    @Published var isLocked: Bool
    @Published var color: Color
    @Published var strokeWidth: CGFloat
    @Published var opacity: Double
    @Published var keyframes: [Keyframe]
    @Published var angleId: String
    @Published var startTimeMs: Int64
    @Published var endTimeMs: Int64
    let createdAt: Date

    @Published var startPoint: CGPoint
    @Published var endPoint: CGPoint
    @Published var endCapStyle: EndCapStyle

    init(name: String = "Arrow",
         startPoint: CGPoint,
         endPoint: CGPoint,
         angleId: String = "angle_a",
         color: Color = Color(hex: "2979ff"),
         strokeWidth: CGFloat = 4.0,
         opacity: Double = 1.0,
         endCapStyle: EndCapStyle = .rounded,
         startTimeMs: Int64 = 0,
         endTimeMs: Int64 = 0) {
        self.name = name
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.angleId = angleId
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.endCapStyle = endCapStyle
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.isVisible = true
        self.isLocked = false
        self.createdAt = Date()
        self.keyframes = []
    }

    func isVisible(at timeMs: Int64) -> Bool {
        guard isVisible else { return false }
        // If endTimeMs is 0, annotation is visible from startTimeMs onwards
        if endTimeMs == 0 {
            return timeMs >= startTimeMs
        }
        // Otherwise, check if time is within range
        return timeMs >= startTimeMs && timeMs <= endTimeMs
    }

    func draw(in context: GraphicsContext, at time: Double) {
        guard isVisible else { return }

        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        // Draw the line
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: strokeWidth
        )

        // Draw arrowhead
        let arrowLength: CGFloat = strokeWidth * 3
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)

        let arrowPoint1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - .pi / 6),
            y: endPoint.y - arrowLength * sin(angle - .pi / 6)
        )
        let arrowPoint2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + .pi / 6),
            y: endPoint.y - arrowLength * sin(angle + .pi / 6)
        )

        var arrowPath = Path()
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: arrowPoint1)
        arrowPath.move(to: endPoint)
        arrowPath.addLine(to: arrowPoint2)

        context.stroke(
            arrowPath,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(
                lineWidth: strokeWidth,
                lineCap: endCapStyle == .rounded ? .round : .square
            )
        )
    }
}

// MARK: - Circle Annotation

class CircleAnnotation: Annotation, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var isVisible: Bool
    @Published var isLocked: Bool
    @Published var color: Color
    @Published var strokeWidth: CGFloat
    @Published var opacity: Double
    @Published var keyframes: [Keyframe]
    @Published var angleId: String
    @Published var startTimeMs: Int64
    @Published var endTimeMs: Int64
    let createdAt: Date

    @Published var center: CGPoint
    @Published var radius: CGFloat

    init(name: String = "Circle",
         center: CGPoint,
         radius: CGFloat,
         angleId: String = "angle_a",
         color: Color = Color(hex: "ff4b4b"),
         strokeWidth: CGFloat = 4.0,
         opacity: Double = 1.0,
         startTimeMs: Int64 = 0,
         endTimeMs: Int64 = 0) {
        self.name = name
        self.center = center
        self.radius = radius
        self.angleId = angleId
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.isVisible = true
        self.isLocked = false
        self.createdAt = Date()
        self.keyframes = []
    }

    func isVisible(at timeMs: Int64) -> Bool {
        guard isVisible else { return false }
        if endTimeMs == 0 {
            return timeMs >= startTimeMs
        }
        return timeMs >= startTimeMs && timeMs <= endTimeMs
    }

    func draw(in context: GraphicsContext, at time: Double) {
        guard isVisible else { return }

        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let path = Path(ellipseIn: rect)

        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: strokeWidth
        )
    }
}

// MARK: - Rectangle Annotation

class RectangleAnnotation: Annotation, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var isVisible: Bool
    @Published var isLocked: Bool
    @Published var color: Color
    @Published var strokeWidth: CGFloat
    @Published var opacity: Double
    @Published var keyframes: [Keyframe]
    @Published var angleId: String
    @Published var startTimeMs: Int64
    @Published var endTimeMs: Int64
    let createdAt: Date

    @Published var startPoint: CGPoint
    @Published var endPoint: CGPoint

    init(name: String = "Rectangle",
         startPoint: CGPoint,
         endPoint: CGPoint,
         angleId: String = "angle_a",
         color: Color = Color(hex: "f5c14e"),
         strokeWidth: CGFloat = 4.0,
         opacity: Double = 1.0,
         startTimeMs: Int64 = 0,
         endTimeMs: Int64 = 0) {
        self.name = name
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.angleId = angleId
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.isVisible = true
        self.isLocked = false
        self.createdAt = Date()
        self.keyframes = []
    }

    func isVisible(at timeMs: Int64) -> Bool {
        guard isVisible else { return false }
        if endTimeMs == 0 {
            return timeMs >= startTimeMs
        }
        return timeMs >= startTimeMs && timeMs <= endTimeMs
    }

    func draw(in context: GraphicsContext, at time: Double) {
        guard isVisible else { return }

        let rect = CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )

        let path = Path(roundedRect: rect, cornerRadius: 0)

        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: strokeWidth
        )
    }
}

// MARK: - Freehand Annotation

class FreehandAnnotation: Annotation, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var isVisible: Bool
    @Published var isLocked: Bool
    @Published var color: Color
    @Published var strokeWidth: CGFloat
    @Published var opacity: Double
    @Published var keyframes: [Keyframe]
    @Published var angleId: String
    @Published var startTimeMs: Int64
    @Published var endTimeMs: Int64
    let createdAt: Date

    @Published var points: [CGPoint]

    init(name: String = "Freehand",
         points: [CGPoint] = [],
         angleId: String = "angle_a",
         color: Color = Color(hex: "27c46d"),
         strokeWidth: CGFloat = 4.0,
         opacity: Double = 1.0,
         startTimeMs: Int64 = 0,
         endTimeMs: Int64 = 0) {
        self.name = name
        self.points = points
        self.angleId = angleId
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.isVisible = true
        self.isLocked = false
        self.createdAt = Date()
        self.keyframes = []
    }

    func isVisible(at timeMs: Int64) -> Bool {
        guard isVisible else { return false }
        if endTimeMs == 0 {
            return timeMs >= startTimeMs
        }
        return timeMs >= startTimeMs && timeMs <= endTimeMs
    }

    func draw(in context: GraphicsContext, at time: Double) {
        guard isVisible, points.count > 1 else { return }

        var path = Path()
        path.move(to: points[0])

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(
                lineWidth: strokeWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
}

// MARK: - Text Annotation

class TextAnnotation: Annotation, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var isVisible: Bool
    @Published var isLocked: Bool
    @Published var color: Color
    @Published var strokeWidth: CGFloat
    @Published var opacity: Double
    @Published var keyframes: [Keyframe]
    @Published var angleId: String
    @Published var startTimeMs: Int64
    @Published var endTimeMs: Int64
    let createdAt: Date

    @Published var position: CGPoint
    @Published var text: String
    @Published var fontSize: CGFloat

    init(name: String = "Text",
         position: CGPoint,
         text: String = "Text",
         fontSize: CGFloat = 24,
         angleId: String = "angle_a",
         color: Color = .white,
         opacity: Double = 1.0,
         startTimeMs: Int64 = 0,
         endTimeMs: Int64 = 0) {
        self.name = name
        self.position = position
        self.text = text
        self.fontSize = fontSize
        self.angleId = angleId
        self.color = color
        self.strokeWidth = 0
        self.opacity = opacity
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.isVisible = true
        self.isLocked = false
        self.createdAt = Date()
        self.keyframes = []
    }

    func isVisible(at timeMs: Int64) -> Bool {
        guard isVisible else { return false }
        if endTimeMs == 0 {
            return timeMs >= startTimeMs
        }
        return timeMs >= startTimeMs && timeMs <= endTimeMs
    }

    func draw(in context: GraphicsContext, at time: Double) {
        guard isVisible else { return }

        // Text drawing in Canvas requires using Text view
        // This will be handled in the Canvas drawing layer
    }
}

// MARK: - Ruler Annotation

class RulerAnnotation: Annotation, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var isVisible: Bool
    @Published var isLocked: Bool
    @Published var color: Color
    @Published var strokeWidth: CGFloat
    @Published var opacity: Double
    @Published var keyframes: [Keyframe]
    @Published var angleId: String
    @Published var startTimeMs: Int64
    @Published var endTimeMs: Int64
    let createdAt: Date

    @Published var startPoint: CGPoint
    @Published var endPoint: CGPoint

    init(name: String = "Ruler",
         startPoint: CGPoint,
         endPoint: CGPoint,
         angleId: String = "angle_a",
         color: Color = Color(hex: "27c46d"),
         strokeWidth: CGFloat = 2.0,
         opacity: Double = 1.0,
         startTimeMs: Int64 = 0,
         endTimeMs: Int64 = 0) {
        self.name = name
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.angleId = angleId
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.isVisible = true
        self.isLocked = false
        self.createdAt = Date()
        self.keyframes = []
    }

    func isVisible(at timeMs: Int64) -> Bool {
        guard isVisible else { return false }
        if endTimeMs == 0 {
            return timeMs >= startTimeMs
        }
        return timeMs >= startTimeMs && timeMs <= endTimeMs
    }

    func draw(in context: GraphicsContext, at time: Double) {
        guard isVisible else { return }

        var path = Path()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: strokeWidth
        )

        // Draw measurement markers
        let distance = sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2))
        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)

        // Draw tick marks every 50 points
        let tickSpacing: CGFloat = 50
        let tickCount = Int(distance / tickSpacing)

        for i in 0...tickCount {
            let progress = CGFloat(i) * tickSpacing / distance
            let tickX = startPoint.x + (endPoint.x - startPoint.x) * progress
            let tickY = startPoint.y + (endPoint.y - startPoint.y) * progress

            let tickLength: CGFloat = i % 5 == 0 ? 8 : 4

            let perpAngle = angle + .pi / 2
            let tick1 = CGPoint(
                x: tickX + tickLength * cos(perpAngle),
                y: tickY + tickLength * sin(perpAngle)
            )
            let tick2 = CGPoint(
                x: tickX - tickLength * cos(perpAngle),
                y: tickY - tickLength * sin(perpAngle)
            )

            var tickPath = Path()
            tickPath.move(to: tick1)
            tickPath.addLine(to: tick2)

            context.stroke(
                tickPath,
                with: .color(color.opacity(opacity)),
                lineWidth: strokeWidth
            )
        }
    }
}

// MARK: - Grid Annotation

class GridAnnotation: Annotation, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var isVisible: Bool
    @Published var isLocked: Bool
    @Published var color: Color
    @Published var strokeWidth: CGFloat
    @Published var opacity: Double
    @Published var keyframes: [Keyframe]
    @Published var angleId: String
    @Published var startTimeMs: Int64
    @Published var endTimeMs: Int64
    let createdAt: Date

    @Published var origin: CGPoint
    @Published var size: CGSize
    @Published var gridType: GridType

    enum GridType {
        case grid2x2
        case grid3x3
        case grid4x4
    }

    init(name: String = "Grid",
         origin: CGPoint,
         size: CGSize,
         gridType: GridType = .grid3x3,
         angleId: String = "angle_a",
         color: Color = Color(hex: "ffffff"),
         strokeWidth: CGFloat = 1.0,
         opacity: Double = 0.6,
         startTimeMs: Int64 = 0,
         endTimeMs: Int64 = 0) {
        self.name = name
        self.origin = origin
        self.size = size
        self.gridType = gridType
        self.angleId = angleId
        self.color = color
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.isVisible = true
        self.isLocked = false
        self.createdAt = Date()
        self.keyframes = []
    }

    func isVisible(at timeMs: Int64) -> Bool {
        guard isVisible else { return false }
        if endTimeMs == 0 {
            return timeMs >= startTimeMs
        }
        return timeMs >= startTimeMs && timeMs <= endTimeMs
    }

    func draw(in context: GraphicsContext, at time: Double) {
        guard isVisible else { return }

        let divisions: Int
        switch gridType {
        case .grid2x2: divisions = 2
        case .grid3x3: divisions = 3
        case .grid4x4: divisions = 4
        }

        // Draw outer rectangle
        let rect = CGRect(origin: origin, size: size)
        var outerPath = Path(rect)
        context.stroke(
            outerPath,
            with: .color(color.opacity(opacity)),
            lineWidth: strokeWidth
        )

        // Draw vertical lines
        for i in 1..<divisions {
            let x = origin.x + (size.width / CGFloat(divisions)) * CGFloat(i)
            var linePath = Path()
            linePath.move(to: CGPoint(x: x, y: origin.y))
            linePath.addLine(to: CGPoint(x: x, y: origin.y + size.height))
            context.stroke(
                linePath,
                with: .color(color.opacity(opacity)),
                lineWidth: strokeWidth
            )
        }

        // Draw horizontal lines
        for i in 1..<divisions {
            let y = origin.y + (size.height / CGFloat(divisions)) * CGFloat(i)
            var linePath = Path()
            linePath.move(to: CGPoint(x: origin.x, y: y))
            linePath.addLine(to: CGPoint(x: origin.x + size.width, y: y))
            context.stroke(
                linePath,
                with: .color(color.opacity(opacity)),
                lineWidth: strokeWidth
            )
        }
    }
}
