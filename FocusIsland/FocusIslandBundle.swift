//
//  FocusIslandBundle.swift
//  FocusIsland
//
//  Created by zineb on 09/03/2026.
//

import WidgetKit
import SwiftUI

@main
struct FocusIslandBundle: WidgetBundle {
    var body: some Widget {
        FocusIsland()
        FocusIslandControl()
        FocusIslandLiveActivity()
    }
}
