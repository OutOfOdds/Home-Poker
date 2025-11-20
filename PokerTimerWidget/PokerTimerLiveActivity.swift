import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct PokerTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock Screen UI
            LockScreenTimerView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // Compact Leading
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Compact Trailing
                CompactTrailingView(context: context)
            } minimal: {
                // Minimal
                MinimalView(context: context)
            }
        }
    }
}
