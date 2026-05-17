import WidgetKit
import SwiftUI

@main
struct ParabusWidgetBundle: WidgetBundle {
    var body: some Widget {
        MetrobusStatusWidget()
        MetrobusAccessoryWidget()

        // Live Activity (iOS 16.1+)
        if #available(iOS 16.2, *) {
            MetrobusLiveActivity()
        }
    }
}
