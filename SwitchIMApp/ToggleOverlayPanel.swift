import AppKit
import SwitchIMCore

/// Flat picker surface: an appearance-adaptive solid rounded rectangle drawn
/// the classic way (bezier fill). The area outside the rounded path is simply
/// not drawn, so the corners are transparent by construction — no layer
/// clipping involved.
@MainActor
private final class OverlayBackgroundView: NSView {
    private static let lightFill = NSColor(white: 0.90, alpha: 1.0)
    private static let darkFill = NSColor(white: 0.18, alpha: 1.0)

    var cornerRadius: CGFloat = 12

    override func draw(_ dirtyRect: NSRect) {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        (isDark ? Self.darkFill : Self.lightFill).setFill()
        NSBezierPath(
            roundedRect: bounds,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        ).fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Panel

/// Centered hold-to-pick overlay listing every selectable input source.
///
/// Presenting only shows the list — selection is driven externally through
/// `setSelectedIndex` by the toggle engine, and commit happens when the
/// chord's modifiers are released. The surface is a flat, appearance-adaptive
/// rounded rectangle in the style of the system input source picker — no
/// vibrancy and no shadow (see `OverlayBackgroundView`).
@MainActor
final class ToggleOverlayPanel {
    private static let minimumWidth: CGFloat = 180
    private static let maximumWidth: CGFloat = 340
    private static let rowSpacing: CGFloat = 2
    private static let outerPadding: CGFloat = 6
    private static let cornerRadius: CGFloat = 12

    private let panel: NSPanel
    private let listView: OverlayListView
    /// Bumped on every `present`; a `dismiss` whose completion fires after a
    /// newer present must not tear the re-shown panel down.
    private var presentGeneration = 0

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false

        let background = OverlayBackgroundView()
        background.cornerRadius = Self.cornerRadius

        let listView = OverlayListView()
        listView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(listView)
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: background.topAnchor, constant: Self.outerPadding),
            listView.bottomAnchor.constraint(
                equalTo: background.bottomAnchor, constant: -Self.outerPadding
            ),
            listView.leadingAnchor.constraint(
                equalTo: background.leadingAnchor, constant: Self.outerPadding
            ),
            listView.trailingAnchor.constraint(
                equalTo: background.trailingAnchor, constant: -Self.outerPadding
            ),
        ])
        panel.contentView = background

        self.panel = panel
        self.listView = listView
    }

    func present(sources: [InputSource], names: [String], selectedIndex: Int) {
        listView.update(sources: sources, names: names, selectedIndex: selectedIndex)
        resizeToFit(rowCount: sources.count, labelWidth: listView.preferredLabelWidth)
        positionOnMouseScreen()

        // Invalidate any in-flight dismiss so its completion handler won't
        // order the panel out from under this presentation.
        presentGeneration += 1

        let alreadyVisible = panel.isVisible
        if !alreadyVisible {
            panel.alphaValue = 0.0
        }
        panel.orderFrontRegardless()
        // Animate to full alpha: on re-present this replaces any fade-out
        // still in flight from a recent dismiss.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            panel.animator().alphaValue = 1.0
        }
    }

    func setSelectedIndex(_ index: Int) {
        listView.setSelectedIndex(index)
    }

    func dismiss() {
        guard panel.isVisible else { return }
        let generation = presentGeneration
        NSAnimationContext.runAnimationGroup(
            { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 0.0
            },
            completionHandler: { [panel, weak self] in
                MainActor.assumeIsolated {
                    // The panel was re-presented while fading out — keep it.
                    guard let self, generation == self.presentGeneration else { return }
                    panel.orderOut(nil)
                }
            })
    }

    // MARK: - Layout

    private func resizeToFit(rowCount: Int, labelWidth: CGFloat) {
        let rows = max(rowCount, 1)
        let listHeight =
            CGFloat(rows) * OverlayRowView.height
            + CGFloat(max(rows - 1, 0)) * Self.rowSpacing
        let height = listHeight + Self.outerPadding * 2

        // Width follows the content: icon + the widest label + paddings,
        // clamped so short names stay compact and long names truncate.
        let chrome: CGFloat = Self.outerPadding * 2 + 12 + 24 + 8 + 12
        let width = min(max(labelWidth + chrome, Self.minimumWidth), Self.maximumWidth)

        panel.setContentSize(NSSize(width: width, height: height))
    }

    private func positionOnMouseScreen() {
        let mouse = NSEvent.mouseLocation
        let screen =
            NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - panelSize.width / 2,
            y: frame.midY - panelSize.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

// MARK: - List view

@MainActor
final class OverlayListView: NSView {
    static let spacing: CGFloat = 2

    private let stack = NSStackView()
    private var rows: [OverlayRowView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        stack.orientation = .vertical
        stack.spacing = Self.spacing
        stack.alignment = .leading
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// The widest label in the current rows (0 when there are none).
    var preferredLabelWidth: CGFloat {
        rows.map(\.preferredLabelWidth).max() ?? 0
    }

    func update(sources: [InputSource], names: [String], selectedIndex: Int) {
        for row in rows {
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        rows = sources.enumerated().map { index, source in
            OverlayRowView(
                name: index < names.count ? names[index] : source.name,
                icon: IconLoader.icon(for: source, size: 24)
            )
        }
        for row in rows {
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        setSelectedIndex(selectedIndex)
    }

    func setSelectedIndex(_ index: Int) {
        for (i, row) in rows.enumerated() {
            row.isSelected = (i == index)
        }
    }
}

// MARK: - Row

@MainActor
final class OverlayRowView: NSView {
    static let height: CGFloat = 44

    private let highlight = NSView()
    private let nameField = NSTextField(labelWithString: "")

    var isSelected: Bool = false {
        didSet { applySelection() }
    }

    var preferredLabelWidth: CGFloat {
        (nameField.stringValue as NSString).size(
            withAttributes: [.font: nameField.font ?? .systemFont(ofSize: 14)]
        ).width
    }

    init(name: String, icon: NSImage?) {
        super.init(frame: .zero)
        wantsLayer = true

        highlight.wantsLayer = true
        highlight.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlight)

        let iconView = NSImageView()
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        nameField.stringValue = name
        nameField.font = .systemFont(ofSize: 14)
        nameField.alignment = .natural
        nameField.lineBreakMode = .byTruncatingTail
        nameField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameField)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),

            highlight.topAnchor.constraint(equalTo: topAnchor),
            highlight.bottomAnchor.constraint(equalTo: bottomAnchor),
            highlight.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlight.trailingAnchor.constraint(equalTo: trailingAnchor),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            nameField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        iconView.isHidden = (icon == nil)

        setAccessibilityElement(true)
        setAccessibilityLabel(name)

        applySelection()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Selection state is applied both on change (direct layer updates, which
    /// take effect immediately once the layer exists) and before each draw
    /// pass (covers the first draw, when the row's layer has only just been
    /// created and `didSet` could not have reached it yet).
    override func viewWillDraw() {
        super.viewWillDraw()
        applySelection()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applySelection()
    }

    /// A highlighted row uses the app's accent color with white text — the
    /// platform pattern for a selected list row.
    private func applySelection() {
        highlight.layer?.cornerRadius = 7
        highlight.layer?.cornerCurve = .continuous
        highlight.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.cgColor : nil
        nameField.textColor = isSelected ? .white : .labelColor
    }
}
