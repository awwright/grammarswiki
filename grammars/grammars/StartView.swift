import SwiftUI
import AppKit
import Foundation

public struct StartView: View {
	public var body: some View {
		VStack(spacing: 0) {
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.frame(width: 128, height: 128);

			Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
				  ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
				  ?? "Welcome")
				.font(.system(size: 36, weight: .bold))
				.multilineTextAlignment(.center)

			Text(String(format: "Version %@%@ (%@)",
				Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
				Bundle.main.object(forInfoDictionaryKey: "CE_VERSION_POSTFIX") as? String ?? "",
				Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
			))
			.foregroundColor(.secondary)
			.font(.system(size: 13.5));
		}.padding()
	}
}

#Preview {
	StartView()
}
