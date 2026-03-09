//
//  FocusIslandLiveActivity.swift
//  FocusIsland
//
//  Created by zineb on 09/03/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusIslandAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FocusIslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusIslandAttributes.self) { context in
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

extension FocusIslandAttributes {
    fileprivate static var preview: FocusIslandAttributes {
        FocusIslandAttributes(name: "World")
    }
}

extension FocusIslandAttributes.ContentState {
    fileprivate static var smiley: FocusIslandAttributes.ContentState {
        FocusIslandAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FocusIslandAttributes.ContentState {
         FocusIslandAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FocusIslandAttributes.preview) {
   FocusIslandLiveActivity()
} contentStates: {
    FocusIslandAttributes.ContentState.smiley
    FocusIslandAttributes.ContentState.starEyes
}
