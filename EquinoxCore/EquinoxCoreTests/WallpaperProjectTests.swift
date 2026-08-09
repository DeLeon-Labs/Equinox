// Copyright (c) 2026 Jon DeLeon

import XCTest
@testable import EquinoxCore

final class WallpaperProjectTests: XCTestCase {
    func testEncodeDecodeRoundTripPreservesAllWallpaperKinds() throws {
        for kind in WallpaperProjectKind.allCases {
            let project = makeProject(kind: kind)
            let data = try JSONEncoder().encode(project)
            let decoded = try JSONDecoder().decode(WallpaperProject.self, from: data)
            XCTAssertEqual(decoded, project)
        }
    }

    func testRoundTripPreservesOrderingPrimaryAndMetadata() throws {
        let images = [
            WallpaperProjectImage(
                identifier: "first",
                relativeImageFilename: "first.heic",
                primary: false,
                solarAzimuth: 120.5,
                solarAltitude: 35.25,
                appearanceDesignation: .light
            ),
            WallpaperProjectImage(
                identifier: "second",
                relativeImageFilename: "second.png",
                primary: true,
                timeOfDaySeconds: 45_015,
                appearanceDesignation: .dark
            ),
            WallpaperProjectImage(
                identifier: "third",
                relativeImageFilename: "third.jpg",
                primary: false
            )
        ]
        let project = WallpaperProject(wallpaperKind: .solar, images: images)

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(WallpaperProject.self, from: data)

        XCTAssertEqual(decoded.images.map(\.identifier), ["first", "second", "third"])
        XCTAssertEqual(decoded.images.first(where: { $0.primary })?.identifier, "second")
        XCTAssertEqual(decoded.images[0].solarAzimuth, 120.5)
        XCTAssertEqual(decoded.images[0].solarAltitude, 35.25)
        XCTAssertEqual(decoded.images[1].timeOfDaySeconds, 45_015)
        XCTAssertEqual(decoded.images[0].appearanceDesignation, .light)
        XCTAssertEqual(decoded.images[1].appearanceDesignation, .dark)
        XCTAssertNil(decoded.images[2].appearanceDesignation)
    }

    private func makeProject(kind: WallpaperProjectKind) -> WallpaperProject {
        return WallpaperProject(
            wallpaperKind: kind,
            images: [
                WallpaperProjectImage(
                    identifier: "image",
                    relativeImageFilename: "image.png",
                    primary: true,
                    solarAzimuth: kind == .solar ? 180 : nil,
                    solarAltitude: kind == .solar ? 45 : nil,
                    timeOfDaySeconds: kind == .time ? 43_200 : nil,
                    appearanceDesignation: kind == .appearance ? .light : nil
                )
            ]
        )
    }
}
