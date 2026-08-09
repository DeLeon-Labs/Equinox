// Copyright (c) 2026 Jon DeLeon

import Foundation

public enum WallpaperProjectError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidPrimaryImageCount
    case duplicateImageIdentifier(String)
    case invalidRelativeImageFilename(String)
    case invalidTimeOfDay(Int)
    case missingSourceImage(String)
    case missingPackageImage(String)
    case invalidPackage
}

extension WallpaperProjectError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported wallpaper project schema version: \(version)."
        case .invalidPrimaryImageCount:
            return "A wallpaper project must contain exactly one primary image."
        case .duplicateImageIdentifier(let identifier):
            return "The wallpaper project contains a duplicate image identifier: \(identifier)."
        case .invalidRelativeImageFilename(let filename):
            return "The wallpaper project contains an invalid image filename: \(filename)."
        case .invalidTimeOfDay(let seconds):
            return "The wallpaper project contains an invalid time of day: \(seconds)."
        case .missingSourceImage(let identifier):
            return "The source image is missing for project image \(identifier)."
        case .missingPackageImage(let filename):
            return "The wallpaper project image is missing: \(filename)."
        case .invalidPackage:
            return "The wallpaper project package is invalid."
        }
    }
}
