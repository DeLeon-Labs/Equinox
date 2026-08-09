// Copyright (c) 2026 Jon DeLeon

import XCTest
@testable import EquinoxCore

final class WallpaperProjectServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var service: WallpaperProjectServiceImpl!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WallpaperProjectTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        service = WallpaperProjectServiceImpl()
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory = temporaryDirectory,
           FileManager.default.fileExists(atPath: temporaryDirectory.path) {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
        service = nil
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testSaveCopiesOriginalBytesAndResolvesDuplicateFilenames() throws {
        let firstDirectory = temporaryDirectory.appendingPathComponent("First", isDirectory: true)
        let secondDirectory = temporaryDirectory.appendingPathComponent("Second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)

        let firstSource = firstDirectory.appendingPathComponent("wallpaper.png")
        let secondSource = secondDirectory.appendingPathComponent("wallpaper.png")
        let firstData = Data([0x01, 0x02, 0x03])
        let secondData = Data([0x04, 0x05, 0x06])
        try firstData.write(to: firstSource)
        try secondData.write(to: secondSource)

        let project = WallpaperProject(wallpaperKind: .appearance, images: [
            WallpaperProjectImage(
                identifier: "first",
                relativeImageFilename: "wallpaper.png",
                primary: true,
                appearanceDesignation: .light
            ),
            WallpaperProjectImage(
                identifier: "second",
                relativeImageFilename: "wallpaper.png",
                primary: false,
                appearanceDesignation: .dark
            )
        ])
        let packageURL = temporaryDirectory.appendingPathComponent("Saved.equinoxproject", isDirectory: true)

        let loaded = try service.save(
            project: project,
            sourceImageURLsByIdentifier: ["first": firstSource, "second": secondSource],
            to: packageURL
        )

        XCTAssertEqual(loaded.project.images.map(\.relativeImageFilename), ["wallpaper.png", "wallpaper-2.png"])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(loaded.imageURLsByIdentifier["first"])), firstData)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(loaded.imageURLsByIdentifier["second"])), secondData)
        XCTAssertTrue(loaded.imageURLsByIdentifier.values.allSatisfy { $0.path.hasPrefix(packageURL.path) })
    }

    func testSaveReplacesExistingPackageUsingPackageLocalSource() throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("source.png")
        try Data([0x10, 0x20, 0x30]).write(to: sourceURL)
        let project = oneImageProject(filename: "source.png")
        let packageURL = temporaryDirectory.appendingPathComponent("Saved.equinoxproject", isDirectory: true)
        let firstSave = try service.save(
            project: project,
            sourceImageURLsByIdentifier: ["image": sourceURL],
            to: packageURL
        )
        let packageLocalSource = try XCTUnwrap(firstSave.imageURLsByIdentifier["image"])
        let replacementData = Data([0x40, 0x50, 0x60])
        try replacementData.write(to: packageLocalSource)
        let updatedProject = WallpaperProject(
            wallpaperKind: .solar,
            images: [WallpaperProjectImage(
                identifier: "image",
                relativeImageFilename: "renamed.png",
                primary: true,
                solarAzimuth: 90,
                solarAltitude: 15
            )]
        )

        let secondSave = try service.save(
            project: updatedProject,
            sourceImageURLsByIdentifier: ["image": packageLocalSource],
            to: packageURL
        )

        let reboundURL = try XCTUnwrap(secondSave.imageURLsByIdentifier["image"])
        XCTAssertEqual(secondSave.project, updatedProject)
        XCTAssertEqual(try Data(contentsOf: reboundURL), replacementData)
        XCTAssertTrue(reboundURL.path.hasPrefix(packageURL.path))
    }

    func testLoadRejectsMissingPackageImage() throws {
        let packageURL = try makePackage(project: oneImageProject(filename: "missing.png"), createImages: false)

        XCTAssertThrowsError(try service.load(from: packageURL)) { error in
            XCTAssertEqual(error as? WallpaperProjectError, .missingPackageImage("missing.png"))
        }
    }

    func testLoadRejectsParentPathTraversal() throws {
        let packageURL = try makePackage(project: oneImageProject(filename: "../outside.png"), createImages: false)

        XCTAssertThrowsError(try service.load(from: packageURL)) { error in
            XCTAssertEqual(error as? WallpaperProjectError, .invalidRelativeImageFilename("../outside.png"))
        }
    }

    func testLoadRejectsAbsolutePath() throws {
        let packageURL = try makePackage(project: oneImageProject(filename: "/tmp/outside.png"), createImages: false)

        XCTAssertThrowsError(try service.load(from: packageURL)) { error in
            XCTAssertEqual(error as? WallpaperProjectError, .invalidRelativeImageFilename("/tmp/outside.png"))
        }
    }

    func testLoadRejectsUnsupportedSchemaVersion() throws {
        let project = WallpaperProject(
            schemaVersion: WallpaperProject.currentSchemaVersion + 1,
            wallpaperKind: .time,
            images: [WallpaperProjectImage(
                identifier: "image",
                relativeImageFilename: "image.png",
                primary: true,
                timeOfDaySeconds: 3_600
            )]
        )
        let packageURL = try makePackage(project: project, createImages: false)

        XCTAssertThrowsError(try service.load(from: packageURL)) { error in
            XCTAssertEqual(
                error as? WallpaperProjectError,
                .unsupportedSchemaVersion(WallpaperProject.currentSchemaVersion + 1)
            )
        }
    }

    func testLoadRejectsProjectWithoutExactlyOnePrimaryImage() throws {
        let project = WallpaperProject(wallpaperKind: .solar, images: [
            WallpaperProjectImage(identifier: "first", relativeImageFilename: "first.png", primary: false),
            WallpaperProjectImage(identifier: "second", relativeImageFilename: "second.png", primary: false)
        ])
        let packageURL = try makePackage(project: project, createImages: false)

        XCTAssertThrowsError(try service.load(from: packageURL)) { error in
            XCTAssertEqual(error as? WallpaperProjectError, .invalidPrimaryImageCount)
        }
    }

    private func oneImageProject(filename: String) -> WallpaperProject {
        return WallpaperProject(
            wallpaperKind: .solar,
            images: [WallpaperProjectImage(
                identifier: "image",
                relativeImageFilename: filename,
                primary: true,
                solarAzimuth: 180,
                solarAltitude: 45
            )]
        )
    }

    private func makePackage(project: WallpaperProject, createImages: Bool) throws -> URL {
        let packageURL = temporaryDirectory.appendingPathComponent("Fixture.equinoxproject", isDirectory: true)
        let imagesURL = packageURL.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        let manifestData = try JSONEncoder().encode(project)
        try manifestData.write(to: packageURL.appendingPathComponent("project.json"))

        if createImages {
            for image in project.images {
                try Data([0x01]).write(to: imagesURL.appendingPathComponent(image.relativeImageFilename))
            }
        }
        return packageURL
    }
}
