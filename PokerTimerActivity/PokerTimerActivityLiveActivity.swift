//
//  PokerTimerActivityLiveActivity.swift
//  PokerTimerActivity
//
//  Created by Odds on 21.11.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct PokerTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct PokerTimerActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PokerTimerActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension PokerTimerActivityAttributes {
    fileprivate static var preview: PokerTimerActivityAttributes {
        PokerTimerActivityAttributes(name: "World")
    }
}

extension PokerTimerActivityAttributes.ContentState {
    fileprivate static var smiley: PokerTimerActivityAttributes.ContentState {
        PokerTimerActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: PokerTimerActivityAttributes.ContentState {
         PokerTimerActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: PokerTimerActivityAttributes.preview) {
   PokerTimerActivityLiveActivity()
} contentStates: {
    PokerTimerActivityAttributes.ContentState.smiley
    PokerTimerActivityAttributes.ContentState.starEyes
}
