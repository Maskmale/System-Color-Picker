import SwiftUI
import Combine
import Defaults
import AppCenter
import AppCenterCrashes

final class AppState: ObservableObject {
	static let shared = AppState()

	var cancellables = Set<AnyCancellable>()

	private(set) lazy var colorPanel: ColorPanel = {
		let colorPanel = ColorPanel()
		colorPanel.titleVisibility = .hidden
		colorPanel.hidesOnDeactivate = false
		colorPanel.isFloatingPanel = false
		colorPanel.isRestorable = false
		colorPanel.styleMask.remove(.utilityWindow)
		colorPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
		colorPanel.standardWindowButton(.zoomButton)?.isHidden = true
		colorPanel.tabbingMode = .disallowed
		colorPanel.collectionBehavior = [
			.moveToActiveSpace,
			.fullScreenAuxiliary
		]
		colorPanel.makeMain()

		let view = ColorPickerView(colorPanel: colorPanel)
			.environmentObject(self)
		let accessoryView = NSHostingView(rootView: view)
		colorPanel.accessoryView = accessoryView
		accessoryView.constrainEdgesToSuperview()

		// This has to be after adding the accessory view to get correct size.
		colorPanel.setFrameUsingName(SSApp.name)
		colorPanel.setFrameAutosaveName(SSApp.name)

		return colorPanel
	}()

	private func createMenu() -> NSMenu {
		let menu = NSMenu()

		if Defaults[.menuBarItemClickAction] != .showColorSampler {
			menu.addCallbackItem("Pick Color") { [self] _ in
				pickColor()
			}
				.setShortcut(for: .pickColor)
		}

		if Defaults[.menuBarItemClickAction] != .toggleWindow {
			menu.addCallbackItem("Toggle Window") { [self] _ in
				colorPanel.toggle()
			}
				.setShortcut(for: .toggleWindow)
		}

		menu.addSeparator()

		if let colors = Defaults[.recentlyPickedColors].reversed().nilIfEmpty {
			menu.addHeader("Recently Picked Colors")

			for color in colors {
				let menuItem = menu.addCallbackItem(color.stringRepresentation) { _ in
					color.stringRepresentation.copyToPasteboard()
				}

				menuItem.image = color.swatchImage
			}
		}

		menu.addSeparator()

		menu.addSettingsItem()

		menu.addSeparator()

		menu.addCallbackItem("Send Feedback…") { _ in
			SSApp.openSendFeedbackPage()
		}

		menu.addSeparator()

		menu.addQuitItem()

		return menu
	}

	private(set) lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
		$0.isVisible = false
		$0.button!.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: nil)
		$0.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])

		let item = $0

		$0.button!.onAction { [self] _ in
			let event = NSApp.currentEvent!

			func showMenu() {
				item.menu = createMenu()
				item.button!.performClick(nil)
				item.menu = nil
			}

			switch Defaults[.menuBarItemClickAction] {
			case .showMenu:
				if event.type == .rightMouseUp {
					pickColor()
				} else {
					showMenu()
				}
			case .showColorSampler:
				if event.type == .rightMouseUp {
					showMenu()
				} else {
					pickColor()
				}
			case .toggleWindow:
				if event.type == .rightMouseUp {
					showMenu()
				} else {
					colorPanel.toggle()
				}
			}
		}
	}

	init() {
		AppCenter.start(
			withAppSecret: "f44a0ef2-9271-4bdb-8320-dcceaa857c36",
			services: [
				Crashes.self
			]
		)

		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		fixStuff()
		setUpEvents()
		showWelcomeScreenIfNeeded()
		requestReview()

		#if DEBUG
//		SSApp.showSettingsWindow()
		#endif
	}

	private func fixStuff() {
		// Make the invisible native SwitUI window not block access to the desktop. (macOS 12.0)
		NSApp.windows.first?.ignoresMouseEvents = true

		// Make the invisible native SwiftUI window not show up in mission control when in menu bar mode. (macOS 11.6)
		NSApp.windows.first?.collectionBehavior = .stationary

		// We hide the “View” menu as there's a macOS bug where it sometimes enables even though it doesn't work and then causes a crash when clicked.
		NSApp.mainMenu?.item(withTitle: "View")?.isHidden = true
	}

	private func requestReview() {
		SSApp.requestReviewAfterBeingCalledThisManyTimes([10, 100, 200, 1000])
	}

	private func addToRecentlyPickedColor(_ color: NSColor) {
		Defaults[.recentlyPickedColors] = Defaults[.recentlyPickedColors]
			.removingAll(color)
			.appending(color)
			.truncatingFromStart(toCount: 6)
	}

	func pickColor() {
		NSColorSampler().show { [weak self] in
			guard
				let self = self,
				let color = $0
			else {
				return
			}

			self.colorPanel.color = color
			self.addToRecentlyPickedColor(color)
			self.requestReview()

			if Defaults[.copyColorAfterPicking] {
				color.stringRepresentation.copyToPasteboard()
			}
		}
	}

	func pasteColor() {
		guard let color = NSColor.fromPasteboardGraceful(.general) else {
			return
		}

		colorPanel.color = color.usingColorSpace(.sRGB) ?? color
	}
}
