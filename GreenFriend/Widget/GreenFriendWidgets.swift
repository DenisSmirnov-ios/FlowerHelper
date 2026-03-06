#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

@main
struct GreenFriendWidgets: WidgetBundle {
    var body: some Widget {
        GreenFriendWateringWidget()
    }
}
#endif
