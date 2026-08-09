// Copyright (c) 2026 Jon DeLeon

import Foundation

public struct LoadedWallpaperProject {
    public let project: WallpaperProject
    public let imageURLsByIdentifier: [String: URL]

    public init(project: WallpaperProject, imageURLsByIdentifier: [String: URL]) {
        self.project = project
        self.imageURLsByIdentifier = imageURLsByIdentifier
    }

    public func imageURL(for image: WallpaperProjectImage) -> URL? {
        return imageURLsByIdentifier[image.identifier]
    }
}

public protocol WallpaperProjectService {
    func save(
        project: WallpaperProject,
        sourceImageURLsByIdentifier: [String: URL],
        to packageURL: URL
    ) throws -> LoadedWallpaperProject
    func load(from packageURL: URL) throws -> LoadedWallpaperProject
}

public final class WallpaperProjectServiceImpl: WallpaperProjectService {
    private enum Constants {
        static let manifestFilename = "project.json"
        static let imagesDirectoryName = "Images"
    }

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    public func save(
        project: WallpaperProject,
        sourceImageURLsByIdentifier: [String: URL],
        to packageURL: URL
    ) throws -> LoadedWallpaperProject {
        try validate(project)

        // A save panel authorizes packageURL, not arbitrary siblings in its parent directory.
        // Foundation provides this temporary location specifically for safe item replacement.
        let replacementDirectoryURL = try fileManager.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: packageURL,
            create: true
        )
        let stagingURL = replacementDirectoryURL.appendingPathComponent(
            packageURL.lastPathComponent,
            isDirectory: true
        )
        let stagingImagesURL = stagingURL.appendingPathComponent(Constants.imagesDirectoryName, isDirectory: true)

        defer {
            if fileManager.fileExists(atPath: replacementDirectoryURL.path) {
                try? fileManager.removeItem(at: replacementDirectoryURL)
            }
        }

        try fileManager.createDirectory(at: stagingImagesURL, withIntermediateDirectories: true)

        var usedFilenames = Set<String>()
        var savedImages: [WallpaperProjectImage] = []

        for image in project.images {
            guard let sourceURL = sourceImageURLsByIdentifier[image.identifier],
                  fileManager.fileExists(atPath: sourceURL.path) else {
                throw WallpaperProjectError.missingSourceImage(image.identifier)
            }

            let requestedFilename = image.relativeImageFilename.isEmpty
                ? sourceURL.lastPathComponent
                : image.relativeImageFilename
            let filename = uniqueFilename(requestedFilename, usedFilenames: &usedFilenames)
            let destinationURL = stagingImagesURL.appendingPathComponent(filename, isDirectory: false)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)

            savedImages.append(WallpaperProjectImage(
                identifier: image.identifier,
                relativeImageFilename: filename,
                primary: image.primary,
                solarAzimuth: image.solarAzimuth,
                solarAltitude: image.solarAltitude,
                timeOfDaySeconds: image.timeOfDaySeconds,
                appearanceDesignation: image.appearanceDesignation
            ))
        }

        let savedProject = WallpaperProject(
            schemaVersion: project.schemaVersion,
            wallpaperKind: project.wallpaperKind,
            images: savedImages
        )
        let manifestData = try encoder.encode(savedProject)
        let manifestURL = stagingURL.appendingPathComponent(Constants.manifestFilename, isDirectory: false)
        try manifestData.write(to: manifestURL, options: .atomic)

        if fileManager.fileExists(atPath: packageURL.path) {
            _ = try fileManager.replaceItemAt(packageURL, withItemAt: stagingURL)
        } else {
            try fileManager.moveItem(at: stagingURL, to: packageURL)
        }

        return try load(from: packageURL)
    }

    public func load(from packageURL: URL) throws -> LoadedWallpaperProject {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: packageURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WallpaperProjectError.invalidPackage
        }

        let manifestURL = packageURL.appendingPathComponent(Constants.manifestFilename, isDirectory: false)
        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            throw WallpaperProjectError.invalidPackage
        }

        let project = try decoder.decode(WallpaperProject.self, from: manifestData)
        try validate(project)

        let imagesURL = packageURL.appendingPathComponent(Constants.imagesDirectoryName, isDirectory: true)
        var resolvedURLs: [String: URL] = [:]

        for image in project.images {
            try validateRelativeFilename(image.relativeImageFilename)
            let imageURL = imagesURL.appendingPathComponent(image.relativeImageFilename, isDirectory: false)
            var imageIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: imageURL.path, isDirectory: &imageIsDirectory),
                  !imageIsDirectory.boolValue else {
                throw WallpaperProjectError.missingPackageImage(image.relativeImageFilename)
            }
            resolvedURLs[image.identifier] = imageURL
        }

        return LoadedWallpaperProject(project: project, imageURLsByIdentifier: resolvedURLs)
    }

    private func validate(_ project: WallpaperProject) throws {
        guard project.schemaVersion == WallpaperProject.currentSchemaVersion else {
            throw WallpaperProjectError.unsupportedSchemaVersion(project.schemaVersion)
        }
        guard project.images.filter({ $0.primary }).count == 1 else {
            throw WallpaperProjectError.invalidPrimaryImageCount
        }

        var identifiers = Set<String>()
        for image in project.images {
            guard identifiers.insert(image.identifier).inserted else {
                throw WallpaperProjectError.duplicateImageIdentifier(image.identifier)
            }
            try validateRelativeFilename(image.relativeImageFilename)
            if let seconds = image.timeOfDaySeconds, !(0..<86_400).contains(seconds) {
                throw WallpaperProjectError.invalidTimeOfDay(seconds)
            }
        }
    }

    private func validateRelativeFilename(_ filename: String) throws {
        let path = filename as NSString
        let components = path.pathComponents
        guard !filename.isEmpty,
              !path.isAbsolutePath,
              components.count == 1,
              filename != ".",
              filename != "..",
              !filename.contains("/"),
              !filename.contains("\\") else {
            throw WallpaperProjectError.invalidRelativeImageFilename(filename)
        }
    }

    private func uniqueFilename(_ requestedFilename: String, usedFilenames: inout Set<String>) -> String {
        let requestedURL = URL(fileURLWithPath: requestedFilename)
        let originalFilename = requestedURL.lastPathComponent
        let pathExtension = requestedURL.pathExtension
        let baseName = requestedURL.deletingPathExtension().lastPathComponent
        var candidate = originalFilename
        var suffix = 2

        while usedFilenames.contains(candidate.lowercased()) {
            candidate = pathExtension.isEmpty
                ? "\(baseName)-\(suffix)"
                : "\(baseName)-\(suffix).\(pathExtension)"
            suffix += 1
        }
        usedFilenames.insert(candidate.lowercased())
        return candidate
    }
}
