//
//  AnnotationCanvas.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI
import AppKit

enum ResizeHandle {
    case none
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case start  // For arrows/rulers
    case end    // For arrows/rulers
}

struct AnnotationCanvas: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var annotationManager: AnnotationManager
    let angleId: String // Camera angle ID
    @State private var dragStartPoint: CGPoint?
    @State private var currentDragPoint: CGPoint?
    @State private var drawingPoints: [CGPoint] = []
    @State private var lastDragLocation: CGPoint?
    @State private var hoveredPoint: CGPoint?
    @State private var isActuallyDragging = false // Track if we're in drag mode vs click mode
    @State private var hasSavedUndoState = false
    @State private var activeResizeHandle: ResizeHandle = .none
    @State private var resizeStartBounds: CGRect = .zero

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    // Draw only annotations for this specific angle that are visible at current time
                    let currentTime = annotationManager.currentTimeMs
                    let visibleAnnotations = annotationManager.annotations(for: angleId, at: currentTime)

                    // Calculate scale factor based on current size vs reference size (1920x1080)
                    let referenceSize = CGSize(width: 1920, height: 1080)
                    let scaleX = size.width / referenceSize.width
                    let scaleY = size.height / referenceSize.height

                    // Apply scaling transformation
                    var scaledContext = context
                    scaledContext.scaleBy(x: scaleX, y: scaleY)

                    for annotation in visibleAnnotations {
                        // Skip text annotations - they're rendered as overlays
                        if annotation is TextAnnotation {
                            continue
                        }

                        annotation.draw(in: scaledContext, at: Double(currentTime))

                        // Draw selection border and resize handles if annotation is selected
                        if let selectedId = annotationManager.selectedAnnotationId, annotation.id == selectedId {
                            drawSelectionBorder(context: scaledContext, annotation: annotation)
                            drawResizeHandles(context: scaledContext, annotation: annotation)
                        }
                    }

                    // Draw preview of current drawing (only in draw mode)
                    if annotationManager.currentTool != .select {
                        if let startPoint = dragStartPoint, let endPoint = currentDragPoint {
                            // Scale preview coordinates back to reference size for consistency
                            let scaledStart = CGPoint(x: startPoint.x / scaleX, y: startPoint.y / scaleY)
                            let scaledEnd = CGPoint(x: endPoint.x / scaleX, y: endPoint.y / scaleY)
                            drawPreview(context: scaledContext, startPoint: scaledStart, endPoint: scaledEnd)
                        }

                        // Draw freehand preview
                        if annotationManager.currentTool == .pen && !drawingPoints.isEmpty {
                            let scaledPoints = drawingPoints.map { CGPoint(x: $0.x / scaleX, y: $0.y / scaleY) }
                            drawFreehandPreview(context: scaledContext, points: scaledPoints)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(value, canvasSize: geometry.size)
                        }
                        .onEnded { value in
                            handleDragEnded(value, canvasSize: geometry.size)
                        }
                )

                // Text annotation overlays
                let currentTime = annotationManager.currentTimeMs
                let visibleAnnotations = annotationManager.annotations(for: angleId, at: currentTime)
                let referenceSize = CGSize(width: 1920, height: 1080)
                let scaleX = geometry.size.width / referenceSize.width
                let scaleY = geometry.size.height / referenceSize.height

                ForEach(visibleAnnotations.compactMap { $0 as? TextAnnotation }, id: \.id) { textAnnotation in
                    Text(textAnnotation.text)
                        .font(.system(size: textAnnotation.fontSize * scaleY, weight: .semibold))
                        .foregroundColor(textAnnotation.color.opacity(textAnnotation.opacity))
                        .position(
                            x: textAnnotation.position.x * scaleX,
                            y: textAnnotation.position.y * scaleY
                        )
                        .allowsHitTesting(annotationManager.currentTool == .select)
                }

                // Text preview during drawing
                if annotationManager.currentTool == .text, let startPoint = dragStartPoint {
                    Text("Text")
                        .font(.system(size: 24 * scaleY, weight: .semibold))
                        .foregroundColor(annotationManager.selectedColor.opacity(annotationManager.opacity))
                        .position(
                            x: startPoint.x * scaleX,
                            y: startPoint.y * scaleY
                        )
                }

                // Cursor management overlay (transparent, doesn't block events)
                CursorManagerView(
                    annotationManager: annotationManager,
                    angleId: angleId,
                    hoveredPoint: $hoveredPoint
                )
            }
        }
    }

    // MARK: - Selection Border

    private func drawSelectionBorder(context: GraphicsContext, annotation: any Annotation) {
        let color = theme.accent
        let dashPattern: [CGFloat] = [5, 5]

        if let arrow = annotation as? ArrowAnnotation {
            let bounds = CGRect(
                x: min(arrow.startPoint.x, arrow.endPoint.x) - 10,
                y: min(arrow.startPoint.y, arrow.endPoint.y) - 10,
                width: abs(arrow.endPoint.x - arrow.startPoint.x) + 20,
                height: abs(arrow.endPoint.y - arrow.startPoint.y) + 20
            )
            drawDashedRect(context: context, rect: bounds, color: color, dashPattern: dashPattern)
        } else if let circle = annotation as? CircleAnnotation {
            let bounds = CGRect(
                x: circle.center.x - circle.radius - 10,
                y: circle.center.y - circle.radius - 10,
                width: circle.radius * 2 + 20,
                height: circle.radius * 2 + 20
            )
            drawDashedRect(context: context, rect: bounds, color: color, dashPattern: dashPattern)
        } else if let rect = annotation as? RectangleAnnotation {
            let bounds = CGRect(
                x: min(rect.startPoint.x, rect.endPoint.x) - 10,
                y: min(rect.startPoint.y, rect.endPoint.y) - 10,
                width: abs(rect.endPoint.x - rect.startPoint.x) + 20,
                height: abs(rect.endPoint.y - rect.startPoint.y) + 20
            )
            drawDashedRect(context: context, rect: bounds, color: color, dashPattern: dashPattern)
        } else if let ruler = annotation as? RulerAnnotation {
            let bounds = CGRect(
                x: min(ruler.startPoint.x, ruler.endPoint.x) - 10,
                y: min(ruler.startPoint.y, ruler.endPoint.y) - 10,
                width: abs(ruler.endPoint.x - ruler.startPoint.x) + 20,
                height: abs(ruler.endPoint.y - ruler.startPoint.y) + 20
            )
            drawDashedRect(context: context, rect: bounds, color: color, dashPattern: dashPattern)
        } else if let grid = annotation as? GridAnnotation {
            let bounds = CGRect(
                x: grid.origin.x - 10,
                y: grid.origin.y - 10,
                width: grid.size.width + 20,
                height: grid.size.height + 20
            )
            drawDashedRect(context: context, rect: bounds, color: color, dashPattern: dashPattern)
        } else if let text = annotation as? TextAnnotation {
            // Approximate text bounds based on font size
            let approximateWidth = CGFloat(text.text.count) * text.fontSize * 0.6
            let approximateHeight = text.fontSize * 1.2
            let bounds = CGRect(
                x: text.position.x - approximateWidth / 2 - 10,
                y: text.position.y - approximateHeight / 2 - 10,
                width: approximateWidth + 20,
                height: approximateHeight + 20
            )
            drawDashedRect(context: context, rect: bounds, color: color, dashPattern: dashPattern)
        }
    }

    private func drawDashedRect(context: GraphicsContext, rect: CGRect, color: Color, dashPattern: [CGFloat]) {
        let path = Path(roundedRect: rect, cornerRadius: 4)
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 2, dash: dashPattern)
        )
    }

    // MARK: - Resize Handles

    private func drawResizeHandles(context: GraphicsContext, annotation: any Annotation) {
        let handleSize: CGFloat = 8
        let handleColor = theme.accent
        let fillColor = theme.primaryBackground

        if let arrow = annotation as? ArrowAnnotation {
            // Draw handles at start and end points for arrows
            drawHandle(context: context, at: arrow.startPoint, size: handleSize, color: handleColor, fill: fillColor)
            drawHandle(context: context, at: arrow.endPoint, size: handleSize, color: handleColor, fill: fillColor)
        } else if let circle = annotation as? CircleAnnotation {
            // Draw handles at 4 corners of bounding box
            let bounds = CGRect(
                x: circle.center.x - circle.radius,
                y: circle.center.y - circle.radius,
                width: circle.radius * 2,
                height: circle.radius * 2
            )
            drawCornerHandles(context: context, bounds: bounds, size: handleSize, color: handleColor, fill: fillColor)
        } else if let rect = annotation as? RectangleAnnotation {
            // Draw handles at 4 corners
            let bounds = CGRect(
                x: min(rect.startPoint.x, rect.endPoint.x),
                y: min(rect.startPoint.y, rect.endPoint.y),
                width: abs(rect.endPoint.x - rect.startPoint.x),
                height: abs(rect.endPoint.y - rect.startPoint.y)
            )
            drawCornerHandles(context: context, bounds: bounds, size: handleSize, color: handleColor, fill: fillColor)
        } else if let ruler = annotation as? RulerAnnotation {
            // Draw handles at start and end points for rulers
            drawHandle(context: context, at: ruler.startPoint, size: handleSize, color: handleColor, fill: fillColor)
            drawHandle(context: context, at: ruler.endPoint, size: handleSize, color: handleColor, fill: fillColor)
        } else if let grid = annotation as? GridAnnotation {
            // Draw handles at 4 corners
            let bounds = CGRect(x: grid.origin.x, y: grid.origin.y, width: grid.size.width, height: grid.size.height)
            drawCornerHandles(context: context, bounds: bounds, size: handleSize, color: handleColor, fill: fillColor)
        } else if let text = annotation as? TextAnnotation {
            // Draw handle at text position for moving
            drawHandle(context: context, at: text.position, size: handleSize, color: handleColor, fill: fillColor)
        }
    }

    private func drawHandle(context: GraphicsContext, at point: CGPoint, size: CGFloat, color: Color, fill: Color) {
        let handleRect = CGRect(x: point.x - size/2, y: point.y - size/2, width: size, height: size)
        let handlePath = Path(ellipseIn: handleRect)

        context.fill(handlePath, with: .color(fill))
        context.stroke(handlePath, with: .color(color), lineWidth: 2)
    }

    private func drawCornerHandles(context: GraphicsContext, bounds: CGRect, size: CGFloat, color: Color, fill: Color) {
        // Top-left
        drawHandle(context: context, at: CGPoint(x: bounds.minX, y: bounds.minY), size: size, color: color, fill: fill)
        // Top-right
        drawHandle(context: context, at: CGPoint(x: bounds.maxX, y: bounds.minY), size: size, color: color, fill: fill)
        // Bottom-left
        drawHandle(context: context, at: CGPoint(x: bounds.minX, y: bounds.maxY), size: size, color: color, fill: fill)
        // Bottom-right
        drawHandle(context: context, at: CGPoint(x: bounds.maxX, y: bounds.maxY), size: size, color: color, fill: fill)
    }

    // MARK: - Handle Detection

    private func detectResizeHandle(at point: CGPoint, for annotation: any Annotation) -> ResizeHandle {
        let handleSize: CGFloat = 12 // Slightly larger hit area than visual size

        if let arrow = annotation as? ArrowAnnotation {
            if isPointNearHandle(point, handleCenter: arrow.startPoint, size: handleSize) {
                return .start
            }
            if isPointNearHandle(point, handleCenter: arrow.endPoint, size: handleSize) {
                return .end
            }
        } else if let circle = annotation as? CircleAnnotation {
            let bounds = CGRect(
                x: circle.center.x - circle.radius,
                y: circle.center.y - circle.radius,
                width: circle.radius * 2,
                height: circle.radius * 2
            )
            return detectCornerHandle(at: point, bounds: bounds, size: handleSize)
        } else if let rect = annotation as? RectangleAnnotation {
            let bounds = CGRect(
                x: min(rect.startPoint.x, rect.endPoint.x),
                y: min(rect.startPoint.y, rect.endPoint.y),
                width: abs(rect.endPoint.x - rect.startPoint.x),
                height: abs(rect.endPoint.y - rect.startPoint.y)
            )
            return detectCornerHandle(at: point, bounds: bounds, size: handleSize)
        } else if let ruler = annotation as? RulerAnnotation {
            if isPointNearHandle(point, handleCenter: ruler.startPoint, size: handleSize) {
                return .start
            }
            if isPointNearHandle(point, handleCenter: ruler.endPoint, size: handleSize) {
                return .end
            }
        } else if let grid = annotation as? GridAnnotation {
            let bounds = CGRect(x: grid.origin.x, y: grid.origin.y, width: grid.size.width, height: grid.size.height)
            return detectCornerHandle(at: point, bounds: bounds, size: handleSize)
        }

        return .none
    }

    private func isPointNearHandle(_ point: CGPoint, handleCenter: CGPoint, size: CGFloat) -> Bool {
        let distance = sqrt(pow(point.x - handleCenter.x, 2) + pow(point.y - handleCenter.y, 2))
        return distance <= size
    }

    private func detectCornerHandle(at point: CGPoint, bounds: CGRect, size: CGFloat) -> ResizeHandle {
        // Check each corner
        if isPointNearHandle(point, handleCenter: CGPoint(x: bounds.minX, y: bounds.minY), size: size) {
            return .topLeft
        }
        if isPointNearHandle(point, handleCenter: CGPoint(x: bounds.maxX, y: bounds.minY), size: size) {
            return .topRight
        }
        if isPointNearHandle(point, handleCenter: CGPoint(x: bounds.minX, y: bounds.maxY), size: size) {
            return .bottomLeft
        }
        if isPointNearHandle(point, handleCenter: CGPoint(x: bounds.maxX, y: bounds.maxY), size: size) {
            return .bottomRight
        }
        return .none
    }

    // MARK: - Gesture Handlers

    private func handleDragChanged(_ value: DragGesture.Value, canvasSize: CGSize) {
        // Scale coordinates to reference size (1920x1080)
        let referenceSize = CGSize(width: 1920, height: 1080)
        let scaleX = canvasSize.width / referenceSize.width
        let scaleY = canvasSize.height / referenceSize.height

        // Convert touch coordinates to reference coordinate space
        let scaledLocation = CGPoint(x: value.location.x / scaleX, y: value.location.y / scaleY)
        let scaledStartLocation = CGPoint(x: value.startLocation.x / scaleX, y: value.startLocation.y / scaleY)


        if annotationManager.currentTool == .select {
            // Selection/Move/Resize mode
            if dragStartPoint == nil {
                // First touch - initialize drag state
                dragStartPoint = scaledStartLocation
                lastDragLocation = scaledStartLocation
                isActuallyDragging = false
                hasSavedUndoState = false
                activeResizeHandle = .none

                // Check if we clicked on a resize handle of selected annotation
                if let selectedId = annotationManager.selectedAnnotationId,
                   let selectedAnnotation = annotationManager.annotations.first(where: { $0.id == selectedId }) {
                    let handle = detectResizeHandle(at: scaledStartLocation, for: selectedAnnotation)
                    if handle != .none {
                        // Clicked on a resize handle - enter resize mode
                        activeResizeHandle = handle
                        resizeStartBounds = getAnnotationBounds(selectedAnnotation)
                    } else {
                        // Clicked on annotation body or empty space
                        let didSelect = annotationManager.selectAnnotation(at: scaledStartLocation, in: angleId)
                        if !didSelect {
                            annotationManager.selectedAnnotationId = nil
                        }
                    }
                } else {
                    // No selection, try to select annotation at touch point
                    let didSelect = annotationManager.selectAnnotation(at: scaledStartLocation, in: angleId)
                    if !didSelect {
                        annotationManager.selectedAnnotationId = nil
                    }
                }
            } else if let startPoint = dragStartPoint {
                // Calculate distance from start point
                let distanceMoved = sqrt(
                    pow(scaledLocation.x - startPoint.x, 2) +
                    pow(scaledLocation.y - startPoint.y, 2)
                )

                // Drag threshold: 3 pixels - if moved more than this, it's a drag not a click
                let dragThreshold: CGFloat = 3.0

                if distanceMoved > dragThreshold {
                    isActuallyDragging = true

                    // Save undo state once when drag starts
                    if !hasSavedUndoState && annotationManager.selectedAnnotationId != nil {
                        annotationManager.saveStateForUndo()
                        hasSavedUndoState = true
                        annotationManager.isDragging = true
                    }

                    if activeResizeHandle != .none {
                        // RESIZE MODE: Resize annotation from the active handle
                        if annotationManager.selectedAnnotationId != nil {
                            annotationManager.resizeSelectedAnnotation(
                                handle: activeResizeHandle,
                                toPoint: scaledLocation,
                                startPoint: startPoint,
                                saveUndo: false
                            )
                        }
                    } else {
                        // MOVE MODE: Move annotation smoothly by delta from last position
                        if annotationManager.selectedAnnotationId != nil, let lastLocation = lastDragLocation {
                            let delta = CGPoint(
                                x: scaledLocation.x - lastLocation.x,
                                y: scaledLocation.y - lastLocation.y
                            )

                            // Move by delta (even tiny movements)
                            annotationManager.moveSelectedAnnotation(by: delta, saveUndo: false)
                            lastDragLocation = scaledLocation
                        }
                    }
                }
            }
        } else {
            // Drawing mode
            if dragStartPoint == nil {
                dragStartPoint = scaledStartLocation
            }
            currentDragPoint = scaledLocation

            if annotationManager.currentTool == .pen {
                drawingPoints.append(scaledLocation)
                annotationManager.currentDrawingPoints = drawingPoints
            }

            annotationManager.isDrawing = true
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, canvasSize: CGSize) {
        // Scale coordinates to reference size (1920x1080)
        let referenceSize = CGSize(width: 1920, height: 1080)
        let scaleX = canvasSize.width / referenceSize.width
        let scaleY = canvasSize.height / referenceSize.height

        // Convert touch coordinates to reference coordinate space
        let scaledLocation = CGPoint(x: value.location.x / scaleX, y: value.location.y / scaleY)

        if annotationManager.currentTool == .select {
            // If we didn't actually drag (just clicked), ensure selection happened
            if !isActuallyDragging {
                // This was a click, not a drag - selection already happened in handleDragChanged
            }

            // Reset all drag state
            dragStartPoint = nil
            lastDragLocation = nil
            isActuallyDragging = false
            hasSavedUndoState = false
            activeResizeHandle = .none
            annotationManager.isDragging = false
        } else {
            // Drawing mode - create annotation
            guard let startPoint = dragStartPoint else { return }
            let endPoint = scaledLocation

            if let annotation = annotationManager.createAnnotation(
                startPoint: startPoint,
                endPoint: endPoint,
                angleId: angleId
            ) {
                annotationManager.addAnnotation(annotation)
            }

            // Reset
            dragStartPoint = nil
            currentDragPoint = nil
            drawingPoints.removeAll()
            annotationManager.currentDrawingPoints.removeAll()
            annotationManager.isDrawing = false
        }
    }

    // MARK: - Helper Functions

    private func getAnnotationBounds(_ annotation: any Annotation) -> CGRect {
        if let arrow = annotation as? ArrowAnnotation {
            return CGRect(
                x: min(arrow.startPoint.x, arrow.endPoint.x),
                y: min(arrow.startPoint.y, arrow.endPoint.y),
                width: abs(arrow.endPoint.x - arrow.startPoint.x),
                height: abs(arrow.endPoint.y - arrow.startPoint.y)
            )
        } else if let circle = annotation as? CircleAnnotation {
            return CGRect(
                x: circle.center.x - circle.radius,
                y: circle.center.y - circle.radius,
                width: circle.radius * 2,
                height: circle.radius * 2
            )
        } else if let rect = annotation as? RectangleAnnotation {
            return CGRect(
                x: min(rect.startPoint.x, rect.endPoint.x),
                y: min(rect.startPoint.y, rect.endPoint.y),
                width: abs(rect.endPoint.x - rect.startPoint.x),
                height: abs(rect.endPoint.y - rect.startPoint.y)
            )
        } else if let ruler = annotation as? RulerAnnotation {
            return CGRect(
                x: min(ruler.startPoint.x, ruler.endPoint.x),
                y: min(ruler.startPoint.y, ruler.endPoint.y),
                width: abs(ruler.endPoint.x - ruler.startPoint.x),
                height: abs(ruler.endPoint.y - ruler.startPoint.y)
            )
        } else if let grid = annotation as? GridAnnotation {
            return CGRect(x: grid.origin.x, y: grid.origin.y, width: grid.size.width, height: grid.size.height)
        } else if let text = annotation as? TextAnnotation {
            let approximateWidth = CGFloat(text.text.count) * text.fontSize * 0.6
            let approximateHeight = text.fontSize * 1.2
            return CGRect(
                x: text.position.x - approximateWidth / 2,
                y: text.position.y - approximateHeight / 2,
                width: approximateWidth,
                height: approximateHeight
            )
        }
        return .zero
    }

    // MARK: - Preview Drawing

    private func drawPreview(context: GraphicsContext, startPoint: CGPoint, endPoint: CGPoint) {
        let color = annotationManager.selectedColor.opacity(annotationManager.opacity)
        let lineWidth = annotationManager.strokeWidth

        switch annotationManager.currentTool {
        case .arrow:
            drawArrowPreview(context: context, start: startPoint, end: endPoint, color: color, lineWidth: lineWidth)

        case .circle:
            drawCirclePreview(context: context, center: startPoint, toPoint: endPoint, color: color, lineWidth: lineWidth)

        case .rectangle:
            drawRectanglePreview(context: context, start: startPoint, end: endPoint, color: color, lineWidth: lineWidth)

        case .ruler:
            drawRulerPreview(context: context, start: startPoint, end: endPoint, color: color, lineWidth: lineWidth)

        case .grid1, .grid2, .grid3:
            drawGridPreview(context: context, start: startPoint, end: endPoint, color: color, lineWidth: lineWidth)

        default:
            break
        }
    }

    private func drawArrowPreview(context: GraphicsContext, start: CGPoint, end: CGPoint, color: Color, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(path, with: .color(color), lineWidth: lineWidth)

        // Draw arrowhead
        let arrowLength: CGFloat = lineWidth * 3
        let angle = atan2(end.y - start.y, end.x - start.x)

        let arrowPoint1 = CGPoint(
            x: end.x - arrowLength * cos(angle - .pi / 6),
            y: end.y - arrowLength * sin(angle - .pi / 6)
        )
        let arrowPoint2 = CGPoint(
            x: end.x - arrowLength * cos(angle + .pi / 6),
            y: end.y - arrowLength * sin(angle + .pi / 6)
        )

        var arrowPath = Path()
        arrowPath.move(to: end)
        arrowPath.addLine(to: arrowPoint1)
        arrowPath.move(to: end)
        arrowPath.addLine(to: arrowPoint2)

        context.stroke(
            arrowPath,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: annotationManager.endCapStyle == .rounded ? .round : .square
            )
        )
    }

    private func drawCirclePreview(context: GraphicsContext, center: CGPoint, toPoint: CGPoint, color: Color, lineWidth: CGFloat) {
        let radius = sqrt(pow(toPoint.x - center.x, 2) + pow(toPoint.y - center.y, 2))
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let path = Path(ellipseIn: rect)
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawRectanglePreview(context: GraphicsContext, start: CGPoint, end: CGPoint, color: Color, lineWidth: CGFloat) {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        let path = Path(roundedRect: rect, cornerRadius: 0)
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawFreehandPreview(context: GraphicsContext, points: [CGPoint]) {
        guard points.count > 1 else { return }

        var path = Path()
        path.move(to: points[0])

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        let color = annotationManager.selectedColor.opacity(annotationManager.opacity)
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: annotationManager.strokeWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func drawRulerPreview(context: GraphicsContext, start: CGPoint, end: CGPoint, color: Color, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(path, with: .color(color), lineWidth: lineWidth)

        // Draw measurement markers preview
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        let angle = atan2(end.y - start.y, end.x - start.x)

        let tickSpacing: CGFloat = 50
        let tickCount = Int(distance / tickSpacing)

        for i in 0...tickCount {
            let progress = CGFloat(i) * tickSpacing / distance
            let tickX = start.x + (end.x - start.x) * progress
            let tickY = start.y + (end.y - start.y) * progress

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

            context.stroke(tickPath, with: .color(color), lineWidth: lineWidth)
        }
    }

    private func drawGridPreview(context: GraphicsContext, start: CGPoint, end: CGPoint, color: Color, lineWidth: CGFloat) {
        let divisions: Int
        switch annotationManager.currentTool {
        case .grid1: divisions = 2
        case .grid2: divisions = 3
        case .grid3: divisions = 4
        default: divisions = 3
        }

        let origin = CGPoint(x: min(start.x, end.x), y: min(start.y, end.y))
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)

        // Draw outer rectangle
        let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        let outerPath = Path(rect)
        context.stroke(outerPath, with: .color(color), lineWidth: lineWidth)

        // Draw vertical lines
        for i in 1..<divisions {
            let x = origin.x + (width / CGFloat(divisions)) * CGFloat(i)
            var linePath = Path()
            linePath.move(to: CGPoint(x: x, y: origin.y))
            linePath.addLine(to: CGPoint(x: x, y: origin.y + height))
            context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
        }

        // Draw horizontal lines
        for i in 1..<divisions {
            let y = origin.y + (height / CGFloat(divisions)) * CGFloat(i)
            var linePath = Path()
            linePath.move(to: CGPoint(x: origin.x, y: y))
            linePath.addLine(to: CGPoint(x: origin.x + width, y: y))
            context.stroke(linePath, with: .color(color), lineWidth: lineWidth)
        }
    }
}

// MARK: - Cursor Manager View (Simple transparent overlay for cursor changes only)

struct CursorManagerView: NSViewRepresentable {
    @ObservedObject var annotationManager: AnnotationManager
    let angleId: String
    @Binding var hoveredPoint: CGPoint?

    func makeNSView(context: Context) -> NSView {
        let view = CursorNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let cursorView = nsView as? CursorNSView {
            cursorView.coordinator?.annotationManager = annotationManager
            cursorView.coordinator?.angleId = angleId
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(annotationManager: annotationManager, angleId: angleId, hoveredPoint: $hoveredPoint)
    }

    class Coordinator: NSObject {
        var annotationManager: AnnotationManager
        var angleId: String
        @Binding var hoveredPoint: CGPoint?

        init(annotationManager: AnnotationManager, angleId: String, hoveredPoint: Binding<CGPoint?>) {
            self.annotationManager = annotationManager
            self.angleId = angleId
            self._hoveredPoint = hoveredPoint
        }

        func updateCursor(for point: CGPoint, in view: NSView) {
            hoveredPoint = point

            // In select mode: check if hovering over annotation
            if annotationManager.currentTool == .select {
                if annotationManager.isDragging {
                    NSCursor.closedHand.set()
                } else {
                    // Check if point is over an annotation
                    let currentTime = annotationManager.currentTimeMs
                    let visibleAnnotations = annotationManager.annotations(for: angleId, at: currentTime)

                    var isOverAnnotation = false
                    for annotation in visibleAnnotations.reversed() {
                        if annotationManager.isPointInside(point, annotation: annotation) {
                            isOverAnnotation = true
                            break
                        }
                    }

                    if isOverAnnotation {
                        NSCursor.openHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            } else {
                // Drawing tools: use crosshair cursor
                NSCursor.crosshair.set()
            }
        }
    }

    class CursorNSView: NSView {
        weak var coordinator: Coordinator?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupView()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupView()
        }

        private func setupView() {
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }

            let trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
        }

        override func mouseMoved(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            let flippedY = bounds.height - location.y
            let point = CGPoint(x: location.x, y: flippedY)
            coordinator?.updateCursor(for: point, in: self)
        }

        override func cursorUpdate(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            let flippedY = bounds.height - location.y
            let point = CGPoint(x: location.x, y: flippedY)
            coordinator?.updateCursor(for: point, in: self)
        }

        override func mouseEntered(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            let flippedY = bounds.height - location.y
            let point = CGPoint(x: location.x, y: flippedY)
            coordinator?.updateCursor(for: point, in: self)
        }

        override func mouseExited(with event: NSEvent) {
            NSCursor.arrow.set()
        }

        // Don't handle mouse down/drag/up - let them pass through to Canvas gesture
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil // Transparent to mouse clicks
        }
    }
}
