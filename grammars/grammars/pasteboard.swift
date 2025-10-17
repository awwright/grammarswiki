import SwiftUI
func copyToPasteboard(_ string: String) {
	#if os(macOS)
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(string, forType: .string)
	#elseif os(iOS)
		UIPasteboard.general.string = string
	#endif
}
