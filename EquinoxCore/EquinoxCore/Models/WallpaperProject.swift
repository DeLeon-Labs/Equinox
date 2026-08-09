// Copyright (c) 2026 Jon DeLeon

import Foundation

public enum WallpaperProjectKind: String, Codable, CaseIterable {
    case solar
    case time
    case appearance
}

public enum WallpaperProjectAppearanceDesignation: String, Codable, CaseIterable {
    case light
    case dark
}

public struct WallpaperProjectImage: Codable, Equatable {
    public let identifier: String
    public let relativeImageFilename: String
    public let primary: Bool
    public let solarAzimuth: Double?
    public let solarAltitude: Double?
    public let timeOfDaySeconds: Int?
    public let appearanceDesignation: WallpaperProjectAppearanceDesignation?

    public init(
        identifier: String,
        relativeImageFilename: String,
        primary: Bool,
        solarAzimuth: Double? = nil,
        solarAltitude: Double? = nil,
        timeOfDaySeconds: Int? = nil,
        appearanceDesignation: WallpaperProjectAppearanceDesignation? = nil
    ) {
        self.identifier = identifier
        self.relativeImageFilename = relativeImageFilename
        self.primary = primary
        self.solarAzimuth = solarAzimuth
        self.solarAltitude = solarAltitude
        self.timeOfDaySeconds = timeOfDaySeconds
        self.appearanceDesignation = appearanceDesignation
    }
}

public struct WallpaperProject: Codable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let wallpaperKind: WallpaperProjectKind
    public let images: [WallpaperProjectImage]

    public init(
        schemaVersion: Int = WallpaperProject.currentSchemaVersion,
        wallpaperKind: WallpaperProjectKind,
        images: [WallpaperProjectImage]
    ) {
        self.schemaVersion = schemaVersion
        self.wallpaperKind = wallpaperKind
        self.images = images
    }
}
