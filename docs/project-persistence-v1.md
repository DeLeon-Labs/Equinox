# Equinox project package v1

Editable wallpaper projects are directory packages with this layout:

```text
My Wallpaper.equinoxproject/
    project.json
    Images/
        ...
```

`project.json` contains schema version `1`, a stable wallpaper kind, and an ordered array of image records. Image records store a stable identifier, one package-relative filename, primary status, and the optional Solar, time-of-day, and appearance configuration used by the editor. Time is stored as seconds from midnight and has no timezone.

The manifest never stores source URLs. Saving copies the original image bytes into `Images/` through a sibling staging directory, resolves filename collisions, writes the manifest, and replaces the destination package. Loading rejects unsupported versions, unsafe filenames, missing images, duplicate identifiers, and projects without exactly one primary image.

The app maps this project model to and from `EquinoxUI.GalleryModel`. HEIC export continues to receive the existing `EquinoxCore.ImageAttributes` and is outside the project format.
