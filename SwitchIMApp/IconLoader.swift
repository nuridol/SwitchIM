import AppKit
import SwitchIMCore

/// Loads a small icon for an input source with a fallback chain:
/// 1. `kTISPropertyIconImageURL` as-is
/// 2. the same URL with a `.tiff` extension (Apple IMEs point at missing `.png`s)
/// 3. the IME bundle's `Assets.car` under the icon filename (multi-IME IMEs such
///    as Gureum bundle their per-layout icons there)
/// 4. the enclosing `.app` bundle icon (`NSWorkspace`)
///
/// Grayscale/PDF icons are marked as template so they adapt to the dark menu bar.
enum IconLoader {
    static func icon(for source: InputSource, size: CGFloat = 16) -> NSImage? {
        guard let url = source.iconImageURL else { return nil }

        var image: NSImage?
        if let direct = NSImage(contentsOf: url) {
            image = direct
        } else if let tiff = InputSourceIconURL.tiffFallbackURL(for: url),
            let tiffImage = NSImage(contentsOf: tiff)
        {
            image = tiffImage
        } else if let appURL = InputSourceIconURL.appBundleURL(from: url),
            let bundle = Bundle(url: appURL),
            let carImage = bundle.image(forResource: InputSourceIconURL.assetName(from: url))
        {
            image = carImage
        } else if let appURL = InputSourceIconURL.appBundleURL(from: url) {
            image = NSWorkspace.shared.icon(forFile: appURL.path)
        }

        guard let loaded = image else { return nil }
        let resized = loaded.scaled(to: size)
        resized.isTemplate = url.pathExtension.lowercased() == "pdf" || resized.isGrayScale()
        return resized
    }
}

extension NSImage {
    func scaled(to size: CGFloat) -> NSImage {
        let target = NSSize(width: size, height: size)
        let image = NSImage(size: target)
        image.lockFocus()
        draw(in: NSRect(origin: .zero, size: target))
        image.unlockFocus()
        return image
    }

    func isGrayScale() -> Bool {
        guard let imageRef = cgImage(), let colorSpace = imageRef.colorSpace else { return false }
        if colorSpace.model == .monochrome { return true }
        guard let data = imageRef.dataProvider?.data, let raw = CFDataGetBytePtr(data) else { return false }
        var index = 0
        for _ in 0..<imageRef.width * imageRef.height {
            let r = raw[index]
            let g = raw[index + 1]
            let b = raw[index + 2]
            guard r == g, g == b else { return false }
            index += 4
        }
        return true
    }

    private func cgImage() -> CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
