//
//  AnnotationManager.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI
import Combine

class AnnotationManager: ObservableObject {
    static let shared = AnnotationManager()

    @Published var annotations: [any Annotation] = []
    @Published var currentTool: AnnotationToolType = .arrow
    @Published var strokeWidth: CGFloat = 4.0
    @Published var opacity: Double = 0.7
    @Published var selectedColor: Color = Color(hex: "2979ff")
    @Published var endCapStyle: EndCapStyle = .rounded
    @Published var annotationDurationSeconds: Double = 5.0 // Duration in seconds (default 5s)

    // Undo/Redo stacks
    private var undoStack: [[any Annotation]] = []
    private var redoStack: [[any Annotation]] = []

    // Drawing state
    @Published var isDrawing = false
    @Published var currentDrawingPoints: [CGPoint] = []

    // Current playback time for time-based annotations
    @Published var currentTimeMs: Int64 = 0

    // Selection state
    @Published var selectedAnnotationId: UUID?
    @Published var isDragging = false

    // Keyframe and freeze settings
    @Published var enableKeyframes: Bool = false
    @Published var freezeDuration: Double = 2.0 // Seconds to freeze video when annotation appears (default: 2 seconds)

    // Immediate save debouncing
    private var immediateSaveTimer: Timer?
    private var currentProjectId: String?
    private var isSaving: Bool = false

    private init() {}
    
    deinit {
        // Clean up timer on deallocation
        immediateSaveTimer?.invalidate()
        immediateSaveTimer = nil
    }

    var selectedAnnotation: (any Annotation)? {
        guard let id = selectedAnnotationId else { return nil }
        return annotations.first(where: { $0.id == id })
    }

    // MARK: - Annotation Management

    func addAnnotation(_ annotation: any Annotation) {
        saveStateForUndo()
        annotations.append(annotation)
        
        // Immediate save to database after creating annotation
        triggerImmediateSave()
    }

    func removeAnnotation(_ annotation: any Annotation) {
        saveStateForUndo()
        annotations.removeAll { $0.id == annotation.id }
        
        // Immediate save to database after deleting annotation
        triggerImmediateSave()
    }

    func updateAnnotation(_ annotation: any Annotation) {
        saveStateForUndo()
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[index] = annotation
        }
        
        // Immediate save to database after updating annotation
        triggerImmediateSave()
    }

    func clearAnnotations() {
        saveStateForUndo()
        annotations.removeAll()
        
        // Immediate save to database after clearing annotations
        triggerImmediateSave()
    }

    // MARK: - Tool Actions

    func createAnnotation(startPoint: CGPoint, endPoint: CGPoint, angleId: String) -> (any Annotation)? {
        // Use user-defined duration (0 means indefinite/until end of video)
        let startTime = currentTimeMs
        let endTime = annotationDurationSeconds > 0 ? startTime + Int64(annotationDurationSeconds * 1000) : 0

        switch currentTool {
        case .arrow:
            return ArrowAnnotation(
                name: "Arrow \(annotations.count + 1)",
                startPoint: startPoint,
                endPoint: endPoint,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                endCapStyle: endCapStyle,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .circle:
            let radius = sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2))
            return CircleAnnotation(
                name: "Circle \(annotations.count + 1)",
                center: startPoint,
                radius: radius,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .rectangle:
            return RectangleAnnotation(
                name: "Rectangle \(annotations.count + 1)",
                startPoint: startPoint,
                endPoint: endPoint,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .pen:
            return FreehandAnnotation(
                name: "Freehand \(annotations.count + 1)",
                points: currentDrawingPoints,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .text:
            return TextAnnotation(
                name: "Text \(annotations.count + 1)",
                position: startPoint,
                text: "Text",
                fontSize: 24,
                angleId: angleId,
                color: selectedColor,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .ruler:
            return RulerAnnotation(
                name: "Ruler \(annotations.count + 1)",
                startPoint: startPoint,
                endPoint: endPoint,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .grid1:
            let width = abs(endPoint.x - startPoint.x)
            let height = abs(endPoint.y - startPoint.y)
            return GridAnnotation(
                name: "Grid 2x2 \(annotations.count + 1)",
                origin: CGPoint(x: min(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y)),
                size: CGSize(width: width, height: height),
                gridType: .grid2x2,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .grid2:
            let width = abs(endPoint.x - startPoint.x)
            let height = abs(endPoint.y - startPoint.y)
            return GridAnnotation(
                name: "Grid 3x3 \(annotations.count + 1)",
                origin: CGPoint(x: min(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y)),
                size: CGSize(width: width, height: height),
                gridType: .grid3x3,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .grid3:
            let width = abs(endPoint.x - startPoint.x)
            let height = abs(endPoint.y - startPoint.y)
            return GridAnnotation(
                name: "Grid 4x4 \(annotations.count + 1)",
                origin: CGPoint(x: min(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y)),
                size: CGSize(width: width, height: height),
                gridType: .grid4x4,
                angleId: angleId,
                color: selectedColor,
                strokeWidth: strokeWidth,
                opacity: opacity,
                startTimeMs: startTime,
                endTimeMs: endTime
            )

        case .select:
            // Selection tool doesn't create annotations
            return nil
        }
    }

    // Get annotations for a specific angle
    func annotations(for angleId: String) -> [any Annotation] {
        return annotations.filter { $0.angleId == angleId }
    }

    // Get annotations visible at a specific time for a specific angle
    func annotations(for angleId: String, at timeMs: Int64) -> [any Annotation] {
        return annotations.filter { annotation in
            annotation.angleId == angleId && annotation.isVisible(at: timeMs)
        }
    }

    // MARK: - Selection and Moving

    func selectAnnotation(at point: CGPoint, in angleId: String, keepExisting: Bool = false) -> Bool {
        let visibleAnnotations = annotations(for: angleId, at: currentTimeMs)

        // Check annotations in reverse order (top to bottom)
        for annotation in visibleAnnotations.reversed() {
            if isPointInside(point, annotation: annotation) {
                // If keepExisting is true, check if this is the same annotation as already selected
                if keepExisting && selectedAnnotationId == annotation.id {
                    return true
                }
                selectedAnnotationId = annotation.id
                return true
            }
        }

        if !keepExisting {
            selectedAnnotationId = nil
        }
        return false
    }

    func isPointInside(_ point: CGPoint, annotation: any Annotation) -> Bool {
        let hitPadding: CGFloat = 20 // Increased from 10 for easier selection

        if let arrow = annotation as? ArrowAnnotation {
            return isPointNearLine(point, start: arrow.startPoint, end: arrow.endPoint, padding: hitPadding)
        } else if let circle = annotation as? CircleAnnotation {
            let distance = sqrt(pow(point.x - circle.center.x, 2) + pow(point.y - circle.center.y, 2))
            // Check if point is near the circle's stroke (inside or outside)
            return abs(distance - circle.radius) < hitPadding || circle.radius - distance < hitPadding
        } else if let rect = annotation as? RectangleAnnotation {
            let rectBounds = CGRect(
                x: min(rect.startPoint.x, rect.endPoint.x),
                y: min(rect.startPoint.y, rect.endPoint.y),
                width: abs(rect.endPoint.x - rect.startPoint.x),
                height: abs(rect.endPoint.y - rect.startPoint.y)
            )
            // Check if point is inside the expanded bounds
            let expandedBounds = rectBounds.insetBy(dx: -hitPadding, dy: -hitPadding)
            return expandedBounds.contains(point)
        } else if let freehand = annotation as? FreehandAnnotation {
            // Check if point is near any segment
            for i in 0..<(freehand.points.count - 1) {
                if isPointNearLine(point, start: freehand.points[i], end: freehand.points[i + 1], padding: hitPadding) {
                    return true
                }
            }
            return false
        } else if let ruler = annotation as? RulerAnnotation {
            return isPointNearLine(point, start: ruler.startPoint, end: ruler.endPoint, padding: hitPadding)
        } else if let grid = annotation as? GridAnnotation {
            let gridBounds = CGRect(origin: grid.origin, size: grid.size)
            return gridBounds.insetBy(dx: -hitPadding, dy: -hitPadding).contains(point)
        } else if let text = annotation as? TextAnnotation {
            // For text, create a reasonable hit box around the position
            let hitBox = CGRect(x: text.position.x - hitPadding, y: text.position.y - hitPadding,
                               width: hitPadding * 4, height: hitPadding * 2)
            return hitBox.contains(point)
        }

        return false
    }

    private func isPointNearLine(_ point: CGPoint, start: CGPoint, end: CGPoint, padding: CGFloat) -> Bool {
        let lineLength = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        if lineLength == 0 { return false }

        let t = max(0, min(1, ((point.x - start.x) * (end.x - start.x) + (point.y - start.y) * (end.y - start.y)) / (lineLength * lineLength)))
        let projection = CGPoint(x: start.x + t * (end.x - start.x), y: start.y + t * (end.y - start.y))
        let distance = sqrt(pow(point.x - projection.x, 2) + pow(point.y - projection.y, 2))

        return distance < padding
    }

    func moveSelectedAnnotation(by delta: CGPoint, saveUndo: Bool = true) {
        guard let id = selectedAnnotationId else { return }

        // Find index once instead of searching twice
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        if saveUndo { saveStateForUndo() }

        // Update annotation based on type - using index directly
        if var arrow = annotations[index] as? ArrowAnnotation {
            arrow.startPoint = CGPoint(x: arrow.startPoint.x + delta.x, y: arrow.startPoint.y + delta.y)
            arrow.endPoint = CGPoint(x: arrow.endPoint.x + delta.x, y: arrow.endPoint.y + delta.y)
            annotations[index] = arrow
        } else if var circle = annotations[index] as? CircleAnnotation {
            circle.center = CGPoint(x: circle.center.x + delta.x, y: circle.center.y + delta.y)
            annotations[index] = circle
        } else if var rect = annotations[index] as? RectangleAnnotation {
            rect.startPoint = CGPoint(x: rect.startPoint.x + delta.x, y: rect.startPoint.y + delta.y)
            rect.endPoint = CGPoint(x: rect.endPoint.x + delta.x, y: rect.endPoint.y + delta.y)
            annotations[index] = rect
        } else if var freehand = annotations[index] as? FreehandAnnotation {
            freehand.points = freehand.points.map { point in
                CGPoint(x: point.x + delta.x, y: point.y + delta.y)
            }
            annotations[index] = freehand
        } else if var ruler = annotations[index] as? RulerAnnotation {
            ruler.startPoint = CGPoint(x: ruler.startPoint.x + delta.x, y: ruler.startPoint.y + delta.y)
            ruler.endPoint = CGPoint(x: ruler.endPoint.x + delta.x, y: ruler.endPoint.y + delta.y)
            annotations[index] = ruler
        } else if var grid = annotations[index] as? GridAnnotation {
            grid.origin = CGPoint(x: grid.origin.x + delta.x, y: grid.origin.y + delta.y)
            annotations[index] = grid
        }
    }

    func resizeSelectedAnnotation(handle: ResizeHandle, toPoint: CGPoint, startPoint: CGPoint, saveUndo: Bool = true) {
        guard let id = selectedAnnotationId else { return }
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        if saveUndo { saveStateForUndo() }

        // Handle resizing based on annotation type and handle
        if var arrow = annotations[index] as? ArrowAnnotation {
            // For arrows: move start or end point
            if handle == .start {
                arrow.startPoint = toPoint
            } else if handle == .end {
                arrow.endPoint = toPoint
            }
            annotations[index] = arrow

        } else if var circle = annotations[index] as? CircleAnnotation {
            // For circles: resize radius based on distance from center
            let newRadius = sqrt(pow(toPoint.x - circle.center.x, 2) + pow(toPoint.y - circle.center.y, 2))
            circle.radius = max(10, newRadius) // Minimum radius of 10
            annotations[index] = circle

        } else if var rect = annotations[index] as? RectangleAnnotation {
            // For rectangles: adjust startPoint or endPoint based on which corner
            let minX = min(rect.startPoint.x, rect.endPoint.x)
            let maxX = max(rect.startPoint.x, rect.endPoint.x)
            let minY = min(rect.startPoint.y, rect.endPoint.y)
            let maxY = max(rect.startPoint.y, rect.endPoint.y)

            switch handle {
            case .topLeft:
                rect.startPoint = CGPoint(x: toPoint.x, y: toPoint.y)
                rect.endPoint = CGPoint(x: maxX, y: maxY)
            case .topRight:
                rect.startPoint = CGPoint(x: minX, y: toPoint.y)
                rect.endPoint = CGPoint(x: toPoint.x, y: maxY)
            case .bottomLeft:
                rect.startPoint = CGPoint(x: toPoint.x, y: minY)
                rect.endPoint = CGPoint(x: maxX, y: toPoint.y)
            case .bottomRight:
                rect.startPoint = CGPoint(x: minX, y: minY)
                rect.endPoint = CGPoint(x: toPoint.x, y: toPoint.y)
            default:
                break
            }
            annotations[index] = rect

        } else if var ruler = annotations[index] as? RulerAnnotation {
            // For rulers: move start or end point
            if handle == .start {
                ruler.startPoint = toPoint
            } else if handle == .end {
                ruler.endPoint = toPoint
            }
            annotations[index] = ruler

        } else if var grid = annotations[index] as? GridAnnotation {
            // For grids: resize from corners
            let minX = grid.origin.x
            let minY = grid.origin.y
            let maxX = grid.origin.x + grid.size.width
            let maxY = grid.origin.y + grid.size.height

            switch handle {
            case .topLeft:
                grid.origin = CGPoint(x: toPoint.x, y: toPoint.y)
                grid.size = CGSize(width: maxX - toPoint.x, height: maxY - toPoint.y)
            case .topRight:
                grid.origin = CGPoint(x: minX, y: toPoint.y)
                grid.size = CGSize(width: toPoint.x - minX, height: maxY - toPoint.y)
            case .bottomLeft:
                grid.origin = CGPoint(x: toPoint.x, y: minY)
                grid.size = CGSize(width: maxX - toPoint.x, height: toPoint.y - minY)
            case .bottomRight:
                grid.size = CGSize(width: toPoint.x - minX, height: toPoint.y - minY)
            default:
                break
            }

            // Ensure minimum size
            grid.size.width = max(20, grid.size.width)
            grid.size.height = max(20, grid.size.height)
            annotations[index] = grid
        }
    }

    // MARK: - Layer Management

    func toggleVisibility(for annotation: any Annotation) {
        if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? ArrowAnnotation {
            mutableAnnotation.isVisible.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? CircleAnnotation {
            mutableAnnotation.isVisible.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? RectangleAnnotation {
            mutableAnnotation.isVisible.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? FreehandAnnotation {
            mutableAnnotation.isVisible.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? TextAnnotation {
            mutableAnnotation.isVisible.toggle()
            updateAnnotation(mutableAnnotation)
        }
    }

    func toggleLock(for annotation: any Annotation) {
        if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? ArrowAnnotation {
            mutableAnnotation.isLocked.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? CircleAnnotation {
            mutableAnnotation.isLocked.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? RectangleAnnotation {
            mutableAnnotation.isLocked.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? FreehandAnnotation {
            mutableAnnotation.isLocked.toggle()
            updateAnnotation(mutableAnnotation)
        } else if var mutableAnnotation = annotations.first(where: { $0.id == annotation.id }) as? TextAnnotation {
            mutableAnnotation.isLocked.toggle()
            updateAnnotation(mutableAnnotation)
        }
    }

    // MARK: - Undo/Redo

    func saveStateForUndo() {
        undoStack.append(annotations)
        redoStack.removeAll()

        // Limit undo stack size
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard !undoStack.isEmpty else { return }

        redoStack.append(annotations)
        annotations = undoStack.removeLast()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }

        undoStack.append(annotations)
        annotations = redoStack.removeLast()
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    // MARK: - Duplicate

    func duplicateAnnotation(_ annotation: any Annotation) {
        if let arrow = annotation as? ArrowAnnotation {
            let duplicate = ArrowAnnotation(
                name: "\(arrow.name) Copy",
                startPoint: CGPoint(x: arrow.startPoint.x + 20, y: arrow.startPoint.y + 20),
                endPoint: CGPoint(x: arrow.endPoint.x + 20, y: arrow.endPoint.y + 20),
                angleId: arrow.angleId,
                color: arrow.color,
                strokeWidth: arrow.strokeWidth,
                opacity: arrow.opacity,
                endCapStyle: arrow.endCapStyle,
                startTimeMs: arrow.startTimeMs,
                endTimeMs: arrow.endTimeMs
            )
            addAnnotation(duplicate)
        } else if let circle = annotation as? CircleAnnotation {
            let duplicate = CircleAnnotation(
                name: "\(circle.name) Copy",
                center: CGPoint(x: circle.center.x + 20, y: circle.center.y + 20),
                radius: circle.radius,
                angleId: circle.angleId,
                color: circle.color,
                strokeWidth: circle.strokeWidth,
                opacity: circle.opacity,
                startTimeMs: circle.startTimeMs,
                endTimeMs: circle.endTimeMs
            )
            addAnnotation(duplicate)
        } else if let rect = annotation as? RectangleAnnotation {
            let duplicate = RectangleAnnotation(
                name: "\(rect.name) Copy",
                startPoint: CGPoint(x: rect.startPoint.x + 20, y: rect.startPoint.y + 20),
                endPoint: CGPoint(x: rect.endPoint.x + 20, y: rect.endPoint.y + 20),
                angleId: rect.angleId,
                color: rect.color,
                strokeWidth: rect.strokeWidth,
                opacity: rect.opacity,
                startTimeMs: rect.startTimeMs,
                endTimeMs: rect.endTimeMs
            )
            addAnnotation(duplicate)
        }
    }

    // MARK: - Keyframe Management

    /// Add a keyframe for the selected annotation at the current time
    func addKeyframeForSelectedAnnotation() {
        guard let id = selectedAnnotationId else { return }
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        saveStateForUndo()

        // Get the current position of the annotation
        let currentProperties = getCurrentAnnotationProperties(annotations[index])
        let keyframe = Keyframe(
            timestamp: Double(currentTimeMs),
            properties: currentProperties
        )

        // Add keyframe based on annotation type
        if var arrow = annotations[index] as? ArrowAnnotation {
            arrow.keyframes.append(keyframe)
            annotations[index] = arrow
        } else if var circle = annotations[index] as? CircleAnnotation {
            circle.keyframes.append(keyframe)
            annotations[index] = circle
        } else if var rect = annotations[index] as? RectangleAnnotation {
            rect.keyframes.append(keyframe)
            annotations[index] = rect
        } else if var freehand = annotations[index] as? FreehandAnnotation {
            freehand.keyframes.append(keyframe)
            annotations[index] = freehand
        } else if var text = annotations[index] as? TextAnnotation {
            text.keyframes.append(keyframe)
            annotations[index] = text
        } else if var ruler = annotations[index] as? RulerAnnotation {
            ruler.keyframes.append(keyframe)
            annotations[index] = ruler
        } else if var grid = annotations[index] as? GridAnnotation {
            grid.keyframes.append(keyframe)
            annotations[index] = grid
        }

        print("✅ Added keyframe at \(currentTimeMs)ms for annotation")
    }

    /// Remove keyframe at the current time for the selected annotation
    func removeKeyframeForSelectedAnnotation() {
        guard let id = selectedAnnotationId else { return }
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        saveStateForUndo()

        let currentTime = Double(currentTimeMs)
        let threshold = 100.0 // 100ms threshold for matching keyframes

        // Remove keyframe based on annotation type
        if var arrow = annotations[index] as? ArrowAnnotation {
            arrow.keyframes.removeAll { abs($0.timestamp - currentTime) < threshold }
            annotations[index] = arrow
        } else if var circle = annotations[index] as? CircleAnnotation {
            circle.keyframes.removeAll { abs($0.timestamp - currentTime) < threshold }
            annotations[index] = circle
        } else if var rect = annotations[index] as? RectangleAnnotation {
            rect.keyframes.removeAll { abs($0.timestamp - currentTime) < threshold }
            annotations[index] = rect
        } else if var freehand = annotations[index] as? FreehandAnnotation {
            freehand.keyframes.removeAll { abs($0.timestamp - currentTime) < threshold }
            annotations[index] = freehand
        } else if var text = annotations[index] as? TextAnnotation {
            text.keyframes.removeAll { abs($0.timestamp - currentTime) < threshold }
            annotations[index] = text
        } else if var ruler = annotations[index] as? RulerAnnotation {
            ruler.keyframes.removeAll { abs($0.timestamp - currentTime) < threshold }
            annotations[index] = ruler
        } else if var grid = annotations[index] as? GridAnnotation {
            grid.keyframes.removeAll { abs($0.timestamp - currentTime) < threshold }
            annotations[index] = grid
        }

        print("✅ Removed keyframe at \(currentTimeMs)ms for annotation")
    }

    /// Get the current properties of an annotation for keyframe creation
    private func getCurrentAnnotationProperties(_ annotation: any Annotation) -> AnnotationProperties {
        var position: CGPoint = .zero

        if let arrow = annotation as? ArrowAnnotation {
            position = arrow.startPoint
        } else if let circle = annotation as? CircleAnnotation {
            position = circle.center
        } else if let rect = annotation as? RectangleAnnotation {
            position = rect.startPoint
        } else if let freehand = annotation as? FreehandAnnotation {
            position = freehand.points.first ?? .zero
        } else if let text = annotation as? TextAnnotation {
            position = text.position
        } else if let ruler = annotation as? RulerAnnotation {
            position = ruler.startPoint
        } else if let grid = annotation as? GridAnnotation {
            position = grid.origin
        }

        return AnnotationProperties(
            position: position,
            scale: 1.0,
            rotation: 0.0,
            opacity: annotation.opacity
        )
    }

    // MARK: - Persistence

    /// Set the current project ID for auto-saving
    func setCurrentProject(_ projectId: String?) {
        currentProjectId = projectId
    }

    /// Trigger immediate save with debouncing (waits 1 second after last change)
    private func triggerImmediateSave() {
        guard let projectId = currentProjectId, !projectId.isEmpty else {
            print("⚠️ No valid project ID set - skipping immediate save")
            return
        }
        
        // Cancel existing timer (must be on main thread)
        DispatchQueue.main.async { [weak self] in
            self?.immediateSaveTimer?.invalidate()
            
            // Start new timer - save after 1 second of no changes
            self?.immediateSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.saveAnnotations(projectId: projectId)
            }
        }
    }

    /// Save all annotations to database (thread-safe, async)
    func saveAnnotations(projectId: String) {
        // Validate project ID
        guard !projectId.isEmpty else {
            print("⚠️ Invalid project ID - cannot save")
            return
        }
        
        // Prevent concurrent saves
        guard !isSaving else {
            print("⚠️ Save already in progress - skipping")
            return
        }
        
        isSaving = true
        
        // Serialize on main thread (accessing @Published properties)
        let annotationsData = serializeAnnotations()
        let annotationCount = annotations.count
        
        // Perform database operation (DatabaseManager handles threading)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let result = DatabaseManager.shared.saveAnnotations(annotationsData, projectId: projectId)
            
            // Update state on main thread
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success:
                    print("💾 ✅ Saved \(annotationCount) annotations for project \(projectId)")
                    
                    // Post notification for UI updates
                    NotificationCenter.default.post(
                        name: .annotationsSaved,
                        object: nil,
                        userInfo: ["projectId": projectId, "count": annotationCount]
                    )
                    
                case .failure(let error):
                    print("❌ Failed to save annotations: \(error.localizedDescription)")
                    
                    // Post error notification
                    NotificationCenter.default.post(
                        name: .annotationsSaveFailed,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
            }
        }
    }
    
    /// Force immediate synchronous save (for app termination)
    /// - Warning: Blocks the calling thread. Use only for critical scenarios.
    func forceSaveAnnotationsSync(projectId: String) {
        // Validate project ID
        guard !projectId.isEmpty else {
            print("⚠️ Invalid project ID - cannot force save")
            return
        }
        
        // Cancel any pending timer
        immediateSaveTimer?.invalidate()
        
        // Serialize on current thread
        let annotationsData = serializeAnnotations()
        let annotationCount = annotations.count
        
        // Perform synchronous save
        let result = DatabaseManager.shared.saveAnnotations(annotationsData, projectId: projectId)
        
        switch result {
        case .success:
            print("💾 ✅ Force saved \(annotationCount) annotations (sync)")
        case .failure(let error):
            print("❌ Force save failed: \(error.localizedDescription)")
        }
    }

    /// Load annotations from database (thread-safe)
    func loadAnnotations(projectId: String) {
        // Cancel any pending saves before loading
        immediateSaveTimer?.invalidate()

        // Load annotations (DatabaseManager handles threading with dbQueue)
        let annotationsData = DatabaseManager.shared.loadAnnotations(projectId: projectId)

        // Deserialize
        let loadedAnnotations = self.deserializeAnnotations(annotationsData)

        // Update state (must be on main thread since these are @Published)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.annotations = loadedAnnotations

            // Clear undo/redo stacks when loading new annotations
            self.undoStack.removeAll()
            self.redoStack.removeAll()

            // Clear selection
            self.selectedAnnotationId = nil

            print("📂 ✅ Loaded \(loadedAnnotations.count) annotations for project \(projectId)")

            // Post notification for UI updates
            NotificationCenter.default.post(
                name: .annotationsLoaded,
                object: nil,
                userInfo: ["projectId": projectId, "count": loadedAnnotations.count]
            )
        }
    }

    // MARK: - Serialization

    private func serializeAnnotations() -> [[String: Any]] {
        return annotations.compactMap { annotation -> [String: Any]? in
            var dict: [String: Any] = [
                "id": annotation.id.uuidString,
                "angleId": annotation.angleId,
                "startTimeMs": annotation.startTimeMs,
                "endTimeMs": annotation.endTimeMs,
                "strokeWidth": annotation.strokeWidth,
                "opacity": annotation.opacity,
                "isVisible": annotation.isVisible,
                "isLocked": annotation.isLocked,
                "name": annotation.name
            ]

            // Convert color to hex string
            if let nsColor = NSColor(annotation.color).usingColorSpace(.deviceRGB) {
                let r = Int(nsColor.redComponent * 255)
                let g = Int(nsColor.greenComponent * 255)
                let b = Int(nsColor.blueComponent * 255)
                dict["color"] = String(format: "#%02X%02X%02X", r, g, b)
            }

            // Serialize keyframes
            if !annotation.keyframes.isEmpty {
                let keyframesJSON = annotation.keyframes.map { kf in
                    """
                    {
                        "timestamp": \(kf.timestamp),
                        "position": {"x": \(kf.properties.position.x), "y": \(kf.properties.position.y)},
                        "scale": \(kf.properties.scale),
                        "rotation": \(kf.properties.rotation),
                        "opacity": \(kf.properties.opacity)
                    }
                    """
                }.joined(separator: ", ")
                dict["keyframes"] = "[\(keyframesJSON)]"
            }

            // Serialize based on type
            if let arrow = annotation as? ArrowAnnotation {
                dict["type"] = "arrow"
                dict["data"] = """
                {
                    "startPoint": {"x": \(arrow.startPoint.x), "y": \(arrow.startPoint.y)},
                    "endPoint": {"x": \(arrow.endPoint.x), "y": \(arrow.endPoint.y)},
                    "endCapStyle": "\(arrow.endCapStyle.rawValue)"
                }
                """
            } else if let circle = annotation as? CircleAnnotation {
                dict["type"] = "circle"
                dict["data"] = """
                {
                    "center": {"x": \(circle.center.x), "y": \(circle.center.y)},
                    "radius": \(circle.radius)
                }
                """
            } else if let rect = annotation as? RectangleAnnotation {
                dict["type"] = "rectangle"
                dict["data"] = """
                {
                    "startPoint": {"x": \(rect.startPoint.x), "y": \(rect.startPoint.y)},
                    "endPoint": {"x": \(rect.endPoint.x), "y": \(rect.endPoint.y)}
                }
                """
            } else if let freehand = annotation as? FreehandAnnotation {
                dict["type"] = "freehand"
                let pointsJSON = freehand.points.map { "{\"x\": \($0.x), \"y\": \($0.y)}" }.joined(separator: ", ")
                dict["data"] = "{ \"points\": [\(pointsJSON)] }"
            } else if let ruler = annotation as? RulerAnnotation {
                dict["type"] = "ruler"
                dict["data"] = """
                {
                    "startPoint": {"x": \(ruler.startPoint.x), "y": \(ruler.startPoint.y)},
                    "endPoint": {"x": \(ruler.endPoint.x), "y": \(ruler.endPoint.y)}
                }
                """
            } else if let grid = annotation as? GridAnnotation {
                dict["type"] = "grid"
                let gridTypeString: String
                switch grid.gridType {
                case .grid2x2: gridTypeString = "grid2x2"
                case .grid3x3: gridTypeString = "grid3x3"
                case .grid4x4: gridTypeString = "grid4x4"
                }
                dict["data"] = """
                {
                    "origin": {"x": \(grid.origin.x), "y": \(grid.origin.y)},
                    "size": {"width": \(grid.size.width), "height": \(grid.size.height)},
                    "gridType": "\(gridTypeString)"
                }
                """
            } else {
                return nil
            }

            return dict
        }
    }

    private func deserializeAnnotations(_ annotationsData: [[String: Any]]) -> [any Annotation] {
        return annotationsData.compactMap { dict -> (any Annotation)? in
            guard let type = dict["type"] as? String,
                  let angleId = dict["angleId"] as? String,
                  let startTimeMs = dict["startTimeMs"] as? Int64,
                  let endTimeMs = dict["endTimeMs"] as? Int64,
                  let colorHex = dict["color"] as? String,
                  let strokeWidth = dict["strokeWidth"] as? Double,
                  let opacity = dict["opacity"] as? Double,
                  let dataString = dict["data"] as? String,
                  let jsonData = dataString.data(using: .utf8),
                  let data = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }

            let color = Color(hex: colorHex)
            let name = dict["name"] as? String ?? ""
            let isVisible = dict["isVisible"] as? Bool ?? true
            let isLocked = dict["isLocked"] as? Bool ?? false

            // Deserialize keyframes if present
            var keyframes: [Keyframe] = []
            if let keyframesString = dict["keyframes"] as? String,
               let keyframesData = keyframesString.data(using: .utf8),
               let keyframesArray = try? JSONSerialization.jsonObject(with: keyframesData) as? [[String: Any]] {
                keyframes = keyframesArray.compactMap { kfDict -> Keyframe? in
                    guard let timestamp = kfDict["timestamp"] as? Double,
                          let posDict = kfDict["position"] as? [String: Any],
                          let x = posDict["x"] as? CGFloat,
                          let y = posDict["y"] as? CGFloat,
                          let scale = kfDict["scale"] as? CGFloat,
                          let rotation = kfDict["rotation"] as? Double,
                          let opacity = kfDict["opacity"] as? Double else {
                        return nil
                    }
                    return Keyframe(
                        timestamp: timestamp,
                        properties: AnnotationProperties(
                            position: CGPoint(x: x, y: y),
                            scale: scale,
                            rotation: rotation,
                            opacity: opacity
                        )
                    )
                }
            }

            switch type {
            case "arrow":
                guard let startPoint = parsePoint(data["startPoint"]),
                      let endPoint = parsePoint(data["endPoint"]),
                      let endCapStyleString = data["endCapStyle"] as? String else {
                    return nil
                }
                let endCapStyle = EndCapStyle(rawValue: endCapStyleString) ?? .rounded
                let arrow = ArrowAnnotation(
                    name: name.isEmpty ? "Arrow" : name,
                    startPoint: startPoint,
                    endPoint: endPoint,
                    angleId: angleId,
                    color: color,
                    strokeWidth: strokeWidth,
                    opacity: opacity,
                    endCapStyle: endCapStyle,
                    startTimeMs: startTimeMs,
                    endTimeMs: endTimeMs
                )
                arrow.isVisible = isVisible
                arrow.isLocked = isLocked
                arrow.keyframes = keyframes
                return arrow

            case "circle":
                guard let center = parsePoint(data["center"]),
                      let radius = data["radius"] as? CGFloat else {
                    return nil
                }
                let circle = CircleAnnotation(
                    name: name.isEmpty ? "Circle" : name,
                    center: center,
                    radius: radius,
                    angleId: angleId,
                    color: color,
                    strokeWidth: strokeWidth,
                    opacity: opacity,
                    startTimeMs: startTimeMs,
                    endTimeMs: endTimeMs
                )
                circle.isVisible = isVisible
                circle.isLocked = isLocked
                circle.keyframes = keyframes
                return circle

            case "rectangle":
                guard let startPoint = parsePoint(data["startPoint"]),
                      let endPoint = parsePoint(data["endPoint"]) else {
                    return nil
                }
                let rect = RectangleAnnotation(
                    name: name.isEmpty ? "Rectangle" : name,
                    startPoint: startPoint,
                    endPoint: endPoint,
                    angleId: angleId,
                    color: color,
                    strokeWidth: strokeWidth,
                    opacity: opacity,
                    startTimeMs: startTimeMs,
                    endTimeMs: endTimeMs
                )
                rect.isVisible = isVisible
                rect.isLocked = isLocked
                rect.keyframes = keyframes
                return rect

            case "freehand":
                guard let pointsData = data["points"] as? [[String: Any]] else {
                    return nil
                }
                let points = pointsData.compactMap { parsePoint($0) }
                let freehand = FreehandAnnotation(
                    name: name.isEmpty ? "Freehand" : name,
                    points: points,
                    angleId: angleId,
                    color: color,
                    strokeWidth: strokeWidth,
                    opacity: opacity,
                    startTimeMs: startTimeMs,
                    endTimeMs: endTimeMs
                )
                freehand.isVisible = isVisible
                freehand.isLocked = isLocked
                freehand.keyframes = keyframes
                return freehand

            case "ruler":
                guard let startPoint = parsePoint(data["startPoint"]),
                      let endPoint = parsePoint(data["endPoint"]) else {
                    return nil
                }
                let ruler = RulerAnnotation(
                    name: name.isEmpty ? "Ruler" : name,
                    startPoint: startPoint,
                    endPoint: endPoint,
                    angleId: angleId,
                    color: color,
                    strokeWidth: strokeWidth,
                    opacity: opacity,
                    startTimeMs: startTimeMs,
                    endTimeMs: endTimeMs
                )
                ruler.isVisible = isVisible
                ruler.isLocked = isLocked
                ruler.keyframes = keyframes
                return ruler

            case "grid":
                guard let origin = parsePoint(data["origin"]),
                      let sizeData = data["size"] as? [String: Any],
                      let width = sizeData["width"] as? CGFloat,
                      let height = sizeData["height"] as? CGFloat,
                      let gridTypeString = data["gridType"] as? String else {
                    return nil
                }
                let gridType: GridAnnotation.GridType
                switch gridTypeString {
                case "grid2x2": gridType = .grid2x2
                case "grid3x3": gridType = .grid3x3
                case "grid4x4": gridType = .grid4x4
                default: gridType = .grid3x3
                }
                let grid = GridAnnotation(
                    name: name.isEmpty ? "Grid" : name,
                    origin: origin,
                    size: CGSize(width: width, height: height),
                    gridType: gridType,
                    angleId: angleId,
                    color: color,
                    strokeWidth: strokeWidth,
                    opacity: opacity,
                    startTimeMs: startTimeMs,
                    endTimeMs: endTimeMs
                )
                grid.isVisible = isVisible
                grid.isLocked = isLocked
                grid.keyframes = keyframes
                return grid

            default:
                return nil
            }
        }
    }

    private func parsePoint(_ pointData: Any?) -> CGPoint? {
        guard let point = pointData as? [String: Any],
              let x = point["x"] as? CGFloat,
              let y = point["y"] as? CGFloat else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let annotationsSaved = Notification.Name("annotationsSaved")
    static let annotationsSaveFailed = Notification.Name("annotationsSaveFailed")
    static let annotationsLoaded = Notification.Name("annotationsLoaded")
}
