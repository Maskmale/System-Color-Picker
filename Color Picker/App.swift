import SwiftUI
import Defaults

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared
	@StateObject private var pasteboardObserver = NSPasteboard.SimpleObservable(.general, onlyWhileAppIsActive: true)

	init() {
		migrate()
	}

	var body: some Scene {
		WindowGroup {
			if false {}
		}
			// TODO: How to replace `File` menu with `Color`?
			// TODO: Remove `View` menu.
			.commands {
				CommandGroup(replacing: .newItem) {}
				CommandMenu("Color") {
					Button("Pick") {
						appState.pickColor()
					}
						.keyboardShortcut("p")
					Divider()
					Button("Copy as Hex") {
						appState.colorPanel.color.hexColorString.copyToPasteboard()
					}
						.keyboardShortcut("H")
					Button("Copy as HSL") {
						appState.colorPanel.color.hslColorString.copyToPasteboard()
					}
						.keyboardShortcut("S")
					Button("Copy as RGB") {
						appState.colorPanel.color.rgbColorString.copyToPasteboard()
					}
						.keyboardShortcut("R")
					Button("Copy as LCH") {
						appState.colorPanel.color.lchColorString.copyToPasteboard()
					}
						.keyboardShortcut("L")
					Button("Paste") {
						appState.pasteColor()
					}
						.help("Paste color in the format Hex, HSL, RGB, or LCH")
						.keyboardShortcut("V")
						.disabled(NSColor.fromPasteboardGraceful(.general) == nil)
				}
				CommandGroup(replacing: .help) {
					Button("What is LCH color?") {
						"https://lea.verou.me/2020/04/lch-colors-in-css-what-why-and-how/".openUrl()
					}
					Button("FAQ") {
						"https://github.com/sindresorhus/System-Color-Picker#faq".openUrl()
					}
					Divider()
					// TODO: Use `Link` when targeting macOS 12.
					Button("Website") {
						"https://sindresorhus.com/system-color-picker".openUrl()
					}
					Button("Rate on the App Store") {
						"macappstore://apps.apple.com/app/id1545870783?action=write-review".openUrl()
					}
					Button("More Apps by Me") {
						"macappstore://apps.apple.com/developer/id328077650".openUrl()
					}
					Divider()
					Button("Send Feedback…") {
						SSApp.openSendFeedbackPage()
					}
				}
			}
		Settings {
			SettingsView()
		}
	}

	private func migrate() {
		// TODO: Remove in 2023.
		Defaults.migrate(.shownColorFormats, to: .v5)
		Defaults.migrate(.colorFormatToCopyAfterPicking, to: .v5)

		// TODO: Remove in 2023.
		SSApp.runOnce(identifier: "migrateToPreferredColorFormatSetting") {
			guard !SSApp.isFirstLaunch else {
				return
			}

			if Defaults[.colorFormatToCopyAfterPicking] != .none {
				Defaults[.copyColorAfterPicking] = true
			}

			switch Defaults[.colorFormatToCopyAfterPicking] {
			case .none:
				break
			case .hex:
				Defaults[.preferredColorFormat] = .hex
			case .hsl:
				Defaults[.preferredColorFormat] = .hsl
			case .rgb:
				Defaults[.preferredColorFormat] = .rgb
			case .lch:
				Defaults[.preferredColorFormat] = .lch
			}
		}

		// Preserve the old behavior for existing users.
		SSApp.runOnce(identifier: "setDefaultsForMenuBarItemClickActionSetting") {
			guard !SSApp.isFirstLaunch else {
				return
			}

			Defaults[.menuBarItemClickAction] = .toggleWindow
		}
	}
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
