//
//  MomentBehaviorEngine.swift
//  maxmiize-v1
//
//  Created by TechQuest on 24/12/2025.
//
//  Handles runtime logic for moment behaviors:
//  - Mutual exclusivity (deactivate conflicting moments)
//  - Activation/deactivation links (auto-activate/deactivate linked moments)
//  - Event-based triggers (respond to moment start/end events)
//  - Auto-duration timers (auto-deactivate after N seconds)
//

import Foundation
import Combine

@MainActor
class MomentBehaviorEngine: ObservableObject {
    static let shared = MomentBehaviorEngine()

    @Published var currentBlueprint: Blueprint?
    private var autoDurationTimers: [String: Timer] = [:]

    private init() {}

    /// Set the active blueprint for behavior checking
    func setBlueprint(_ blueprint: Blueprint) {
        currentBlueprint = blueprint
        print("🎯 MomentBehaviorEngine: Set blueprint '\(blueprint.name)' with \(blueprint.moments.count) moments")
    }

    /// Clear all running auto-duration timers
    func clearAllTimers() {
        autoDurationTimers.values.forEach { $0.invalidate() }
        autoDurationTimers.removeAll()
        print("⏱️ MomentBehaviorEngine: Cleared all auto-duration timers")
    }

    // MARK: - Moment Activation

    /// Handle all behaviors when a moment is activated
    /// - Parameters:
    ///   - momentCategory: Category of the moment being activated
    ///   - currentActiveCategory: Category of the currently active moment (if any)
    ///   - gameId: Game ID for database operations
    ///   - timestamp: Current timestamp
    ///   - onDeactivate: Callback to deactivate a moment by category
    ///   - onActivate: Callback to activate a moment by category
    func handleMomentActivation(
        momentCategory: String,
        currentActiveCategory: String?,
        gameId: String,
        timestamp: Int64,
        onDeactivate: @escaping (String) -> Void,
        onActivate: @escaping (String) -> Void
    ) {
        guard let blueprint = currentBlueprint else {
            print("⚠️ No blueprint loaded, skipping behavior checks")
            return
        }

        guard let momentButton = blueprint.moments.first(where: { $0.category == momentCategory }) else {
            print("⚠️ Moment '\(momentCategory)' not found in blueprint")
            return
        }

        print("🎯 MomentBehaviorEngine: Handling activation for '\(momentCategory)'")

        // 1. Check mutual exclusivity - deactivate conflicting moments
        if let mutualExclusive = momentButton.mutualExclusiveWith {
            for excludedId in mutualExclusive {
                if let excludedMoment = blueprint.moments.first(where: { $0.id == excludedId }) {
                    if currentActiveCategory == excludedMoment.category {
                        print("   🚫 Deactivating mutually exclusive moment: \(excludedMoment.category)")
                        onDeactivate(excludedMoment.category)
                    }
                }
            }
        }

        // 2. Execute deactivation links - auto-deactivate linked moments
        if let deactivationLinks = momentButton.deactivationLinks {
            for linkedId in deactivationLinks {
                if let linkedMoment = blueprint.moments.first(where: { $0.id == linkedId }) {
                    print("   🔗 Auto-deactivating linked moment: \(linkedMoment.category)")
                    onDeactivate(linkedMoment.category)
                }
            }
        }

        // 3. Execute activation links - auto-activate linked moments (with 1-2 frame delay)
        if let activationLinks = momentButton.activationLinks {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // ~50ms = 1-2 frames at 30fps
                for linkedId in activationLinks {
                    if let linkedMoment = blueprint.moments.first(where: { $0.id == linkedId }) {
                        print("   🔗 Auto-activating linked moment: \(linkedMoment.category)")
                        onActivate(linkedMoment.category)
                    }
                }
            }
        }

        // 4. Set up auto-duration timer if configured
        if momentButton.durationType == .auto, let duration = momentButton.autoDurationSeconds {
            setupAutoDurationTimer(
                momentId: momentButton.id,
                category: momentCategory,
                duration: duration,
                onDeactivate: onDeactivate
            )
        }

        // 5. Trigger event-based moments listening for this moment's start
        triggerEventBasedMoments(
            for: .onMomentStart(momentButton.id),
            onActivate: onActivate,
            onDeactivate: onDeactivate
        )
    }

    // MARK: - Moment Deactivation

    /// Handle all behaviors when a moment is deactivated
    /// - Parameters:
    ///   - momentCategory: Category of the moment being deactivated
    ///   - gameId: Game ID for database operations
    ///   - timestamp: Current timestamp
    ///   - onActivate: Callback to activate a moment by category
    ///   - onDeactivate: Callback to deactivate a moment by category
    func handleMomentDeactivation(
        momentCategory: String,
        gameId: String,
        timestamp: Int64,
        onActivate: @escaping (String) -> Void,
        onDeactivate: @escaping (String) -> Void
    ) {
        guard let blueprint = currentBlueprint else { return }

        guard let momentButton = blueprint.moments.first(where: { $0.category == momentCategory }) else {
            return
        }

        print("🎯 MomentBehaviorEngine: Handling deactivation for '\(momentCategory)'")

        // 1. Clear auto-duration timer if exists
        if let timer = autoDurationTimers[momentButton.id] {
            timer.invalidate()
            autoDurationTimers.removeValue(forKey: momentButton.id)
            print("   ⏱️ Cleared auto-duration timer")
        }

        // 2. Trigger event-based moments listening for this moment's end
        triggerEventBasedMoments(
            for: .onMomentEnd(momentButton.id),
            onActivate: onActivate,
            onDeactivate: onDeactivate
        )
    }

    // MARK: - Auto-Duration Timer

    private func setupAutoDurationTimer(
        momentId: String,
        category: String,
        duration: Int,
        onDeactivate: @escaping (String) -> Void
    ) {
        // Clear existing timer if any
        autoDurationTimers[momentId]?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(duration), repeats: false) { [weak self] _ in
            print("⏱️ Auto-duration timer expired for '\(category)' (\(duration)s)")
            onDeactivate(category)
            self?.autoDurationTimers.removeValue(forKey: momentId)
        }

        autoDurationTimers[momentId] = timer
        print("   ⏱️ Set up auto-duration timer: \(duration)s")
    }

    // MARK: - Event-Based Triggers

    /// Check all moments in blueprint to see if any should be triggered by this event
    private func triggerEventBasedMoments(
        for trigger: MomentEventTrigger,
        onActivate: @escaping (String) -> Void,
        onDeactivate: @escaping (String) -> Void
    ) {
        guard let blueprint = currentBlueprint else { return }

        for moment in blueprint.moments {
            // Check if this moment should activate based on the trigger
            if moment.activationTrigger == trigger {
                print("   📡 Triggering activation for '\(moment.category)' (event-based)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    onActivate(moment.category)
                }
            }

            // Check if this moment should deactivate based on the trigger
            if moment.deactivationTrigger == trigger {
                print("   📡 Triggering deactivation for '\(moment.category)' (event-based)")
                onDeactivate(moment.category)
            }
        }
    }
}
