// Copyright (c) 2021 Dmitry Meduho
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
// distribute, sublicense, create a derivative work, and/or sell copies of the
// Software in any work that is designed, intended, or marketed for pedagogical or
// instructional purposes related to programming, coding, application development,
// or information technology.  Permission for such use, copying, modification,
// merger, publication, distribution, sublicensing, creation of derivative works,
// or sale is expressly withheld.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import AppKit
import EquinoxAssets
import EquinoxCore
import EquinoxUI

// MARK: - Protocols

protocol WallpaperWindowControllerDelegate: AnyObject {
    func wallpaperWindowControllerNewWasInteracted()
    func wallpaperWindowControllerCalculatorWasInteracted()
}

// MARK: - Enums, Structs

extension WallpaperWindowController {
    private enum Constants {
        static let regularSize = NSSize(width: 930, height: 756)
        static let minSize = NSSize(width: 930, height: 650)
    }
}

// MARK: - Class

final class WallpaperWindowController: WindowController {
    private let type: WallpaperType
    private let fileService: FileService
    private let wallpaperService: WallpaperService
    private let solarService: SolarService
    private let settingsService: SettingsService
    private let imageProvider: ImageProvider
    private let projectService: WallpaperProjectService
    private let initialModels: [GalleryModel]

    private var contentWindow: Window?
    private var contentController: WindowViewController?
    private var wallpaperRootViewController: WallpaperRootViewController?
    private var toolbarController: WallpaperToolbarController?
    private var projectURL: URL? {
        didSet {
            updateWindowIdentity()
        }
    }

    init(
        type: WallpaperType,
        fileService: FileService,
        wallpaperService: WallpaperService,
        solarService: SolarService,
        settingsService: SettingsService,
        imageProvider: ImageProvider,
        projectService: WallpaperProjectService,
        initialModels: [GalleryModel] = [],
        projectURL: URL? = nil
    ) {
        self.type = type
        self.fileService = fileService
        self.wallpaperService = wallpaperService
        self.solarService = solarService
        self.settingsService = settingsService
        self.imageProvider = imageProvider
        self.projectService = projectService
        self.initialModels = initialModels
        self.projectURL = projectURL
        super.init(window: nil)
        setupWindow()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        let controller = WallpaperRootViewController(
            type: type,
            fileService: fileService,
            wallpaperService: wallpaperService,
            solarService: solarService,
            settingsService: settingsService,
            imageProvider: imageProvider,
            initialModels: initialModels
        )
        controller.delegate = self
        wallpaperRootViewController = controller

        let windowController = WindowViewController(contentViewController: controller)
        contentController = windowController

        contentWindow = Window(
            contentViewController: windowController,
            minSize: Constants.minSize
        )

        let toolbarController = WallpaperToolbarController(wallpaperType: type)
        self.toolbarController = toolbarController
        self.toolbarController?.delegate = self
        contentWindow?.toolbar = toolbarController.toolbar
        if #available(macOS 11.0, *) {
            contentWindow?.titlebarSeparatorStyle = .none
        }

        window = contentWindow
        window?.setContentSize(Constants.regularSize)
        updateWindowIdentity()
        window?.makeKeyAndOrderFront(self)
        window?.center()
    }

    private func updateWindowIdentity() {
        window?.titleVisibility = .visible

        guard let projectURL = projectURL else {
            setUnsavedWindowTitle()
            return
        }

        window?.representedURL = projectURL
        window?.setTitleWithRepresentedFilename(projectURL.path)
        window?.miniwindowTitle = window?.title ?? projectURL.lastPathComponent
    }

    private func setUnsavedWindowTitle() {
        let appName = NSApplication.appName
        var title: String
        
        switch type {
        case .solar:
            title = "\(appName) - \(Localization.Wallpaper.Main.solar)"
            
        case .time:
            title = "\(appName) - \(Localization.Wallpaper.Main.time)"

        case .appearance:
            title = "\(appName) - \(Localization.Wallpaper.Main.appearance)"
        }

        window?.representedURL = nil
        window?.title = title
        window?.miniwindowTitle = title
    }
    
    // MARK: - Public
    
    weak var delegate: WallpaperWindowControllerDelegate?

    func saveProject(saveAs: Bool) {
        if !saveAs, let projectURL = projectURL {
            saveProject(to: projectURL)
            return
        }

        guard let window = window else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "My Wallpaper.equinoxproject"
        savePanel.allowedFileTypes = ["equinoxproject"]
        savePanel.canSelectHiddenExtension = true
        savePanel.isExtensionHidden = false
        savePanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let selectedURL = savePanel.url else {
                return
            }
            let finalURL = selectedURL.pathExtension.isEmpty
                ? selectedURL.appendingPathExtension("equinoxproject")
                : selectedURL
            self?.saveProject(to: finalURL)
        }
    }

    private func saveProject(to url: URL) {
        guard let models = wallpaperRootViewController?.galleryModels, !models.isEmpty else {
            return
        }

        do {
            let state = WallpaperProjectAdapter.makeSaveState(kind: type.projectKind, models: models)
            let loadedProject = try projectService.save(
                project: state.project,
                sourceImageURLsByIdentifier: state.sourceImageURLsByIdentifier,
                to: url
            )
            let reboundModels = try WallpaperProjectAdapter.makeGalleryModels(from: loadedProject)
            wallpaperRootViewController?.replaceGalleryModels(reboundModels)
            projectURL = url
        } catch {
            presentProjectError(error)
        }
    }

    private func presentProjectError(_ error: Error) {
        guard let window = window else {
            return
        }
        NSAlert(error: error).beginSheetModal(for: window)
    }
}

// MARK: - WallpaperRootViewControllerDelegate

extension WallpaperWindowController: WallpaperRootViewControllerDelegate {
    func rootViewControllerNewWasInteracted() {
        delegate?.wallpaperWindowControllerNewWasInteracted()
    }
    
    func rootViewControllerCalculatorWasInteracted() {
        delegate?.wallpaperWindowControllerCalculatorWasInteracted()
    }

    func rootViewControllerShouldNotify(_ text: String) {
        contentController?.notify(text)
    }
}

// MARK: - WallpaperToolbarControllerDelegate

extension WallpaperWindowController: WallpaperToolbarControllerDelegate {
    func wallpaperToolbarControllerCalculatorWasInteracted(_ controller: WallpaperToolbarController) {
        delegate?.wallpaperWindowControllerCalculatorWasInteracted()
    }
    
    func wallpaperToolbarControllerHelpWasInteracted(_ controller: WallpaperToolbarController) {
        wallpaperRootViewController?.presentTipController(firstPresent: false, animated: true)
    }
}
