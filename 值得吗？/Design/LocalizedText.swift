import SwiftUI

/// Localizes app copy without translating names, decision titles, or quoted classical text.
struct AppText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { SwiftUI.Text(verbatim: L10n.t(text)).fontDesign(.rounded) }
}
