# Equinox project package v1

Editable wallpaper projects are directory packages with this layout:

```text
My Wallpaper.equinoxproject/
    project.json
    Images/
        ...
```

`project.json` contains schema version `1`, a stable wallpaper kind, and an ordered array of image records. Image records store a stable identifier, one package-relative filename, primary status, and the optional Solar, time-of-day, and appearance configuration used by the editor. Time is stored as seconds from midnight and has no timezone.

The manifest never stores source URLs. Saving copies the original image bytes into `Images/` through a Foundation item-replacement directory, resolves filename collisions, writes the manifest, and moves or replaces the completed package at the destination. Loading rejects unsupported versions, unsafe filenames, missing images, duplicate identifiers, and projects without exactly one primary image.

Equinox exports `com.rlxone.equinox.wallpaper-project` as a document type conforming to `com.apple.package`. Launch Services therefore presents `.equinoxproject` directories as single package documents and delivers Finder open events to the app delegate. Saved and opened editor windows use their project URL as the AppKit represented URL; unsaved editors keep their wallpaper-type title.

The app maps this project model to and from `EquinoxUI.GalleryModel`. HEIC export continues to receive the existing `EquinoxCore.ImageAttributes` and is outside the project format.
