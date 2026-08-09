// Copyright (c) 2026 Jon DeLeon

import Foundation
import EquinoxCore
import EquinoxUI

struct WallpaperProjectSaveState {
    let project: WallpaperProject
    let sourceImageURLsByIdentifier: [String: URL]
}

enum WallpaperProjectAdapterError: Error {
    case missingImageURL(String)
    case invalidTimeOfDay(Int)
}

enum WallpaperProjectAdapter {
    static func makeSaveState(
        kind: WallpaperProjectKind,
        models: [GalleryModel],
        calendar: Calendar = .current
    ) -> WallpaperProjectSaveState {
        var sourceURLs: [String: URL] = [:]
        let images = models.map { model -> WallpaperProjectImage in
            let identifier = model.identifier
            sourceURLs[identifier] = model.url

            let appearanceDesignation: WallpaperProjectAppearanceDesignation?
            switch model.appearance {
            case .all:
                appearanceDesignation = nil
            case .light:
                appearanceDesignation = .light
            case .dark:
                appearanceDesignation = .dark
            }

            let timeOfDaySeconds: Int?
            if kind == .time, let time = model.time {
                let components = calendar.dateComponents([.hour, .minute, .second], from: time)
                timeOfDaySeconds = (components.hour ?? 0) * 3_600
                    + (components.minute ?? 0) * 60
                    + (components.second ?? 0)
            } else {
                timeOfDaySeconds = nil
            }

            return WallpaperProjectImage(
                identifier: identifier,
                relativeImageFilename: model.url.lastPathComponent,
                primary: model.primary,
                solarAzimuth: kind == .solar ? model.azimuth : nil,
                solarAltitude: kind == .solar ? model.altitude : nil,
                timeOfDaySeconds: timeOfDaySeconds,
                appearanceDesignation: appearanceDesignation
            )
        }

        return WallpaperProjectSaveState(
            project: WallpaperProject(wallpaperKind: kind, images: images),
            sourceImageURLsByIdentifier: sourceURLs
        )
    }

    static func makeGalleryModels(
        from loadedProject: LoadedWallpaperProject,
        calendar: Calendar = .current,
        now: Date = Date()
    ) throws -> [GalleryModel] {
        return try loadedProject.project.images.enumerated().map { index, image in
            guard let imageURL = loadedProject.imageURL(for: image) else {
                throw WallpaperProjectAdapterError.missingImageURL(image.identifier)
            }

            let appearance: EquinoxUI.AppearanceType
            switch image.appearanceDesignation {
            case .none:
                appearance = .all
            case .light:
                appearance = .light
            case .dark:
                appearance = .dark
            }

            var time: Date?
            if let seconds = image.timeOfDaySeconds {
                guard (0..<86_400).contains(seconds) else {
                    throw WallpaperProjectAdapterError.invalidTimeOfDay(seconds)
                }
                let hour = seconds / 3_600
                let minute = seconds % 3_600 / 60
                let second = seconds % 60
                time = calendar.date(bySettingHour: hour, minute: minute, second: second, of: now)
            }

            return GalleryModel(
                identifier: image.identifier,
                number: index + 1,
                url: imageURL,
                appearance: appearance,
                primary: image.primary,
                azimuth: image.solarAzimuth,
                altitude: image.solarAltitude,
                time: time
            )
        }
    }
}

extension WallpaperType {
    var projectKind: WallpaperProjectKind {
        switch self {
        case .solar:
            return .solar
        case .time:
            return .time
        case .appearance:
            return .appearance
        }
    }
}

extension WallpaperProjectKind {
    var wallpaperType: WallpaperType {
        switch self {
        case .solar:
            return .solar
        case .time:
            return .time
        case .appearance:
            return .appearance
        }
    }
}
