import AppKit
import ImageIO
import TetherCore
import UniformTypeIdentifiers

struct ImportFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
@MainActor
struct AssetImporter {
    static var storageOverride: URL?
    static var directory: URL {
        if let storageOverride { return storageOverride }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Tether/Characters", isDirectory: true)
    }
    static var supportsWebP: Bool { (CGImageSourceCopyTypeIdentifiers() as NSArray).contains(UTType.webP.identifier) }
    nonisolated static func validate(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let bytes = values.fileSize, bytes > 0, bytes <= 20 * 1024 * 1024 else {
            throw ImportFailure(message: "Choose a PNG or supported WebP file smaller than 20 MB.")
        }
        let data = try Data(contentsOf: url)
        guard data.count <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              [UTType.png.identifier, UTType.webP.identifier].contains(type),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...4096).contains(width), (1...4096).contains(height),
              width * height * 4 * (((properties[kCGImagePropertyDepth] as? Int) ?? 8) > 8 ? 2 : 1) <= 64 * 1024 * 1024,
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
              image.bytesPerRow * image.height <= 64 * 1024 * 1024 else {
            throw ImportFailure(message: "Use a complete, single-frame PNG or supported WebP up to 4096 × 4096 pixels (64 MiB decoded). Animated images are not supported.")
        }
        if type == UTType.png.identifier { return data }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.png.identifier as CFString, 1, nil) else { throw ImportFailure(message: "This image could not be converted to PNG.") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), result.length <= 20 * 1024 * 1024 else { throw ImportFailure(message: "The converted PNG exceeds the 20 MB storage limit.") }
        return result as Data
    }
    static func importImage(_ url: URL, into folder: URL = directory) throws -> Charm {
        try save(validate(url), name: url.deletingPathExtension().lastPathComponent, into: folder)
    }
    static func save(_ data: Data, name: String, into folder: URL = directory) throws -> Charm {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let id = UUID().uuidString
        try data.write(to: folder.appendingPathComponent(id + ".png"), options: .withoutOverwriting)
        var charm = Charm(id: id, name: name, kind: .custom, assetFilename: id + ".png")
        charm.sanitize(); return charm
    }
    static func deleteArtwork(_ id: String, from store: PreferencesStore, folder: URL = directory) throws {
        guard let template = store.value.library.first(where: { $0.id == id }), template.kind == .custom else { throw LibraryError.builtin }
        var next = store.value
        try next.deleteArtwork(id)
        // Delete only a managed file with no remaining references. Failure leaves the library intact.
        if let file = template.assetFilename, !next.library.contains(where: { $0.assetFilename == file }), !next.charms.contains(where: { $0.assetFilename == file }) {
            let url = folder.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            AssetCache.shared.remove(file)
        }
        store.value = next
    }
}
@MainActor
final class AssetCache {
    static let shared = AssetCache()
    private let cache = NSCache<NSString, NSImage>()
    private var invalid = Set<String>()
    private(set) var decodeCount = 0
    init() { cache.countLimit = 16; cache.totalCostLimit = 64 * 1024 * 1024 }
    func image(_ filename: String?, folder: URL = AssetImporter.directory) -> NSImage? {
        guard let filename, filename == URL(fileURLWithPath: filename).lastPathComponent else { return nil }
        let key = folder.appendingPathComponent(filename).path
        if let image = cache.object(forKey: key as NSString) { return image }
        guard !invalid.contains(key) else { return nil }
        do {
            let data = try AssetImporter.validate(folder.appendingPathComponent(filename))
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 640, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { throw ImportFailure(message: "Artwork could not be decoded.") }
            let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            cache.setObject(image, forKey: key as NSString, cost: cg.bytesPerRow * cg.height); decodeCount += 1
            return image
        } catch { if invalid.count < 200 { invalid.insert(key) }; return nil }
    }
    func remove(_ filename: String) {
        let key = AssetImporter.directory.appendingPathComponent(filename).path
        cache.removeObject(forKey: key as NSString); invalid.remove(key)
    }
    func clear() { cache.removeAllObjects(); invalid.removeAll() }
}
