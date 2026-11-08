import AppKit
import UniformTypeIdentifiers

private enum Palette {
    static let background = NSColor(srgbRed: 0.075, green: 0.064, blue: 0.071, alpha: 1)
    static let sidebar = NSColor(srgbRed: 0.105, green: 0.066, blue: 0.087, alpha: 1)
    static let surface = NSColor(srgbRed: 0.125, green: 0.110, blue: 0.123, alpha: 1)
    static let border = NSColor(srgbRed: 0.39, green: 0.29, blue: 0.26, alpha: 0.62)
    static let accent = NSColor(srgbRed: 0.92, green: 0.26, blue: 0.34, alpha: 1)
    static let brass = NSColor(srgbRed: 0.88, green: 0.70, blue: 0.51, alpha: 1)
    static let blue = NSColor(srgbRed: 0.40, green: 0.61, blue: 0.86, alpha: 1)
    static let muted = NSColor(srgbRed: 0.73, green: 0.68, blue: 0.67, alpha: 1)
    static let paper = NSColor(srgbRed: 0.96, green: 0.91, blue: 0.83, alpha: 1)
    static let ink = NSColor(srgbRed: 0.21, green: 0.14, blue: 0.15, alpha: 1)
    static let wax = NSColor(srgbRed: 0.57, green: 0.14, blue: 0.21, alpha: 1)
}

private final class MissionArt: NSView {
    private static let weaponIcon = Bundle.main.url(forResource: "DMC3Patch", withExtension: "icns")
        .flatMap { NSImage(contentsOf: $0) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let icon = Self.weaponIcon {
            let side = min(bounds.width, bounds.height)
            icon.draw(in: NSRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side))
            return
        }

        // Fallback for development runs outside the app bundle.
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let scale = min(bounds.width, bounds.height) * 0.94 / 100
        context.saveGState()
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.scaleBy(x: scale, y: scale)

        let ring = NSBezierPath(ovalIn: NSRect(x: -49, y: -49, width: 98, height: 98))
        Palette.sidebar.setFill()
        ring.fill()
        Palette.brass.withAlphaComponent(0.72).setStroke()
        ring.lineWidth = 1.2
        ring.stroke()

        context.saveGState()
        context.rotate(by: -.pi / 5.6)
        drawRebellion()
        context.restoreGState()

        context.rotate(by: .pi / 5.2)
        drawYamato()
        context.restoreGState()
    }

    private func drawRebellion() {
        polygon([(-3, -39), (3, -39), (3, -21), (-3, -21)], color: Palette.accent)
        polygon([(-4, -39), (0, -44), (4, -39), (0, -35)], color: Palette.brass)

        let blade = NSColor(srgbRed: 0.94, green: 0.83, blue: 0.80, alpha: 1)
        polygon([(0, 44), (8, 29), (7, -12), (4, -15), (-4, -15), (-7, -12), (-8, 29)], color: blade)
        polygon([(0, 44), (8, 29), (7, -12), (0, -15)], color: Palette.accent)
        polygon([(-1.3, 30), (1.3, 30), (1.3, -10), (-1.3, -10)], color: Palette.wax)

        // Hooked horns and the skull at the base of Rebellion's blade.
        polygon([(-15, -5), (-13, -15), (-8, -21), (-4, -20), (4, -20), (8, -21),
                 (13, -15), (15, -5), (9, -13), (5, -15), (-5, -15), (-9, -13)], color: Palette.brass)
        polygon([(-4.5, -24), (4.5, -24), (6.5, -18), (5.5, -12), (0, -10),
                 (-5.5, -12), (-6.5, -18)], color: Palette.paper)
        Palette.sidebar.setFill()
        NSBezierPath(ovalIn: NSRect(x: -4.4, y: -18.3, width: 3.2, height: 3.5)).fill()
        NSBezierPath(ovalIn: NSRect(x: 1.2, y: -18.3, width: 3.2, height: 3.5)).fill()
        polygon([(-1.1, -21), (1.1, -21), (0, -18.7)], color: Palette.sidebar)
    }

    private func drawYamato() {
        let blade = NSBezierPath()
        blade.move(to: NSPoint(x: -3.5, y: -15))
        blade.curve(to: NSPoint(x: 5, y: 44), controlPoint1: NSPoint(x: -4, y: 10), controlPoint2: NSPoint(x: 0, y: 35))
        blade.curve(to: NSPoint(x: 3.5, y: -15), controlPoint1: NSPoint(x: 9, y: 40), controlPoint2: NSPoint(x: 3, y: 14))
        blade.close()
        NSColor(srgbRed: 0.84, green: 0.92, blue: 0.99, alpha: 1).setFill()
        blade.fill()
        let edge = NSBezierPath()
        edge.move(to: NSPoint(x: -0.7, y: -14))
        edge.curve(to: NSPoint(x: 5, y: 40), controlPoint1: NSPoint(x: -1, y: 9), controlPoint2: NSPoint(x: 2, y: 28))
        edge.lineWidth = 1.9
        Palette.blue.setStroke()
        edge.stroke()

        // Oval tsuba and white tsuka wrap with dark diamonds.
        Palette.brass.setFill()
        NSBezierPath(ovalIn: NSRect(x: -10, y: -20, width: 20, height: 6)).fill()
        Palette.paper.setFill()
        NSBezierPath(roundedRect: NSRect(x: -4.2, y: -42, width: 8.4, height: 23), xRadius: 1.4, yRadius: 1.4).fill()
        let indigo = NSColor(srgbRed: 0.23, green: 0.37, blue: 0.59, alpha: 1)
        for y: CGFloat in [-23, -29, -35] {
            polygon([(-2.6, y), (0, y + 2.2), (2.6, y), (0, y - 2.2)], color: indigo)
        }
        polygon([(-4.2, -39), (4.2, -39), (4.2, -42), (-4.2, -42)], color: Palette.brass)
    }

    private func polygon(_ points: [(CGFloat, CGFloat)], color: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: points[0].0, y: points[0].1))
        for (x, y) in points.dropFirst() { path.line(to: NSPoint(x: x, y: y)) }
        path.close()
        color.setFill()
        path.fill()
    }
}

private struct CreditEntry: Decodable { var title: String; var authors: String; var detail: String; var url: String }
private struct CreditGroup: Decodable { var title: String; var entries: [CreditEntry] }
private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let engine = Engine()
    lazy var crimson = CrimsonInstaller(engine: engine)
    let status = NSTextField(labelWithString: "Listo")
    let modStatus = NSTextField(wrappingLabelWithString: "Sin analizar")
    let modDetail = NSTextField(wrappingLabelWithString: "Elegí primero la carpeta del juego en Resumen.")
    private var crimsonArchive: URL?
    private let crimsonArchiveLabel = NSTextField(wrappingLabelWithString: "")
    var crimsonReport: CrimsonReport?
    var crimsonAnalysisError: String?
    var hasChosenGame: Bool { Paths.hasSelection && (try? GameFolder.validate(Paths.game)) != nil }
    let videoSummary = NSTextField(labelWithString: "Sin aplicar")
    let modSummary = NSTextField(labelWithString: "Opcional")
    let videoStatus = NSTextField(wrappingLabelWithString: "Sin analizar")
    let videoDetail = NSTextField(wrappingLabelWithString: "Elegí la carpeta del juego para analizar sus videos.")
    var videoReport: VideoPatchReport?
    var videoAnalysisError: String?
    var installVideoButton: NSButton!
    var removeVideoButton: NSButton!
    let pageTitle = NSTextField(labelWithString: "Tu instalación")
    let pageSubtitle = NSTextField(labelWithString: "Videos compatibles y Crimson opcional para Steam dentro de CrossOver.")
    let pageContainer = NSView()
    let progressBar = NSProgressIndicator()
    let output = NSTextView()
    let cancelButton = NSButton(title: "Cancelar", target: nil, action: nil)
    var buttons: [NSButton] = []
    var gameActions: [NSButton] = []
    let selectedFolder = NSTextField(wrappingLabelWithString: "Todavía no elegiste una carpeta.")
    let detectedGame = NSTextField(wrappingLabelWithString: "Los cambios se aplican dentro de la carpeta elegida.")
    let scopeNotice = NSTextField(wrappingLabelWithString: "Elegí primero la carpeta del juego en Resumen.")
    let languageMenu = NSPopUpButton()
    var languageBindings: [() -> Void] = []
    var navigation: [NSButton] = []
    var pages: [NSView] = []
    var selectedPage = 0
    var installButton: NSButton!
    var removeButton: NSButton!
    var busy = false
    private var welcomePanel: NSPanel?
    private var welcomeReceipt: URL { Paths.project.appendingPathComponent("welcome-v1-seen") }

    func text(_ value: String, size: CGFloat = 12, color: NSColor = Palette.muted, weight: NSFont.Weight = .regular) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: L10n.text(value))
        languageBindings.append { field.stringValue = L10n.text(value) }
        field.font = .systemFont(ofSize: size, weight: weight); field.textColor = color
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        return field
    }
    func row(spacing: CGFloat = 10) -> NSStackView {
        let stack = NSStackView(); stack.orientation = .horizontal; stack.spacing = spacing; stack.alignment = .centerY; return stack
    }
    func column(spacing: CGFloat = 10) -> NSStackView {
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = spacing; return stack
    }
    func card() -> NSView {
        let view = NSView(); view.wantsLayer = true; view.layer?.cornerRadius = 10
        view.layer?.backgroundColor = Palette.surface.cgColor; view.layer?.borderColor = Palette.border.cgColor; view.layer?.borderWidth = 1
        return view
    }
    func inset(_ view: NSView, content: NSView, amount: CGFloat = 20, fill: Bool = true) {
        content.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: amount),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -amount),
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: amount)])
        (fill ? content.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -amount)
              : content.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -amount)).isActive = true
    }
    func fullWidth(_ view: NSView, in stack: NSStackView) {
        stack.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    func button(_ title: String, _ selector: Selector, primary: Bool = false, needsGame: Bool = true) -> NSButton {
        let button = NSButton(title: L10n.text(title), target: self, action: selector)
        languageBindings.append { button.title = L10n.text(title) }
        button.bezelStyle = .rounded; button.controlSize = .large; button.font = .systemFont(ofSize: 12, weight: .medium)
        if primary { button.bezelColor = Palette.accent; button.contentTintColor = .white }
        buttons.append(button); if needsGame { gameActions.append(button) }; return button
    }
    func heading(_ title: String, symbol: String, in stack: NSStackView) {
        let line = row(spacing: 10); let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = Palette.brass; icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        line.addArrangedSubview(icon); line.addArrangedSubview(text(title, size: 18, color: .labelColor, weight: .semibold)); stack.addArrangedSubview(line)
    }
    func summaryCard(_ title: String, value: NSTextField, symbol: String) -> NSView {
        let view = card(); let content = row(spacing: 14)
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
        icon.contentTintColor = symbol == "flame" ? Palette.accent : Palette.blue; icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        content.addArrangedSubview(icon); let labels = column(spacing: 5)
        labels.addArrangedSubview(text(title, size: 10, weight: .semibold))
        value.font = .systemFont(ofSize: 15, weight: .semibold); labels.addArrangedSubview(value); content.addArrangedSubview(labels)
        inset(view, content: content, amount: 15); return view
    }
    func makeSummary() -> NSView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let document = FlippedDocumentView(); let contents = column(spacing: 12); inset(document, content: contents, amount: 2)
        scroll.documentView = document; document.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let selection = card(); let selectionStack = column(spacing: 11); inset(selection, content: selectionStack, amount: 18)
        heading("1. Elegí la carpeta del juego", symbol: "folder", in: selectionStack)
        fullWidth(text("Seleccioná la carpeta que contiene el ejecutable de DMC3 y data. También se reconocen ejecutables renombrados compatibles."), in: selectionStack)
        selectionStack.addArrangedSubview(button("Elegir carpeta del juego…", #selector(chooseGameFolder), primary: true, needsGame: false))
        selectedFolder.font = .monospacedSystemFont(ofSize: 10, weight: .regular); selectedFolder.isSelectable = true
        fullWidth(selectedFolder, in: selectionStack)
        detectedGame.font = .systemFont(ofSize: 11, weight: .medium); fullWidth(detectedGame, in: selectionStack)
        fullWidth(selection, in: contents)
        let panel = card(); let stack = column(spacing: 12); inset(panel, content: stack, amount: 18)
        heading("2. Parche de video", symbol: "film", in: stack)
        videoStatus.font = .systemFont(ofSize: 15, weight: .semibold); fullWidth(videoStatus, in: stack)
        videoDetail.font = .systemFont(ofSize: 12); videoDetail.textColor = Palette.muted; fullWidth(videoDetail, in: stack)
        let actions = row(spacing: 10)
        installVideoButton = button("Instalar", #selector(installVideos), primary: true)
        removeVideoButton = button("Remover", #selector(removeVideos))
        for (action, symbol) in [(installVideoButton!, "arrow.down.circle"), (removeVideoButton!, "arrow.uturn.backward.circle"), (button("Analizar", #selector(analyze)), "magnifyingglass")] {
            action.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); action.imagePosition = .imageLeading
            action.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            action.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true
            actions.addArrangedSubview(action)
        }
        stack.addArrangedSubview(actions)
        fullWidth(text("Instalar convierte los videos a H.264/AAC y los copia con respaldo. Remover recupera los archivos previos. Analizar comprueba qué hay instalado."), in: stack)
        fullWidth(text("Cerrá el juego antes de instalar o remover. Después, jugá desde Steam en CrossOver. Conservá los respaldos para restaurar.", size: 11), in: stack)
        fullWidth(panel, in: contents)
        return scroll
    }
    func makeCrimson() -> NSView {
        let panel = card(); let stack = column(spacing: 13); inset(panel, content: stack, fill: false)
        heading("Crimson 0.5a", symbol: "flame", in: stack)
        fullWidth(text("El paquete completo de Berthrage y C-Team: modos de juego, estilos, armas, cámara, HUD, efectos, sonidos y texturas.", size: 13, color: .labelColor), in: stack)
        modStatus.font = .systemFont(ofSize: 12, weight: .semibold); modStatus.textColor = .systemGreen; fullWidth(modStatus, in: stack)
        fullWidth(text("Elegí el ZIP o RAR de Crimson 0.5a que ya descargaste. La app prepara el mod para CrossOver y respalda los archivos previos."), in: stack)
        stack.addArrangedSubview(button("Elegir ZIP o RAR de Crimson…", #selector(chooseCrimsonArchive), needsGame: false))
        crimsonArchiveLabel.textColor = Palette.muted
        crimsonArchiveLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        crimsonArchiveLabel.isSelectable = true
        fullWidth(crimsonArchiveLabel, in: stack)
        modDetail.font = .systemFont(ofSize: 12); modDetail.textColor = Palette.muted; fullWidth(modDetail, in: stack)
        let actions = row(spacing: 10)
        installButton = button("Instalar", #selector(installCrimson), primary: true)
        removeButton = button("Quitar", #selector(removeCrimson))
        for (action, symbol) in [(installButton!, "arrow.down.circle"), (removeButton!, "arrow.uturn.backward.circle"), (button("Analizar", #selector(analyzeCrimson)), "magnifyingglass")] {
            action.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); action.imagePosition = .imageLeading
            action.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            action.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true
            actions.addArrangedSubview(action)
        }
        stack.addArrangedSubview(actions)
        stack.addArrangedSubview(button("Guía de instalación", #selector(openCrimsonInstallGuide), needsGame: false))
        scopeNotice.font = .systemFont(ofSize: 11); scopeNotice.textColor = Palette.muted
        fullWidth(scopeNotice, in: stack)
        fullWidth(text("Cerrá el juego antes de instalar, actualizar o quitar Crimson. Los menús internos del mod conservan su idioma original.", size: 11), in: stack)
        return panel
    }
    func makeCredits() -> NSView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        let document = FlippedDocumentView(); let stack = column(spacing: 16); inset(document, content: stack, amount: 2)
        scroll.documentView = document; document.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let source = Bundle.main.resourceURL?.appendingPathComponent("Creditos.json")
        let url = source.flatMap { engine.exists($0) ? $0 : nil } ?? Paths.assets.appendingPathComponent("docs/CREDITOS.json")
        if let groups = try? engine.read(url, as: [CreditGroup].self) {
            for group in groups {
                stack.addArrangedSubview(text(group.title.uppercased(), size: 10, weight: .semibold))
                let panel = card(); let entries = column(spacing: 16); inset(panel, content: entries, amount: 16)
                for entry in group.entries {
                    let title = NSButton(title: entry.title + "  ↗", target: self, action: #selector(openCredit(_:)))
                    title.identifier = NSUserInterfaceItemIdentifier(entry.url); title.isBordered = false; title.alignment = .left
                    languageBindings.append { title.title = L10n.text(entry.title) + "  ↗" }; title.title = L10n.text(entry.title) + "  ↗"
                    title.font = .systemFont(ofSize: 13, weight: .semibold); title.contentTintColor = .labelColor; entries.addArrangedSubview(title)
                    fullWidth(text(entry.authors, size: 12, color: Palette.accent, weight: .medium), in: entries)
                    fullWidth(text(entry.detail, size: 11), in: entries)
                }
                fullWidth(panel, in: stack)
            }
        } else { fullWidth(text("Los créditos completos están en docs/CREDITOS.md."), in: stack) }
        let actions = row(); actions.addArrangedSubview(button("Licencias originales", #selector(openLicenses), needsGame: false)); stack.addArrangedSubview(actions)
        fullWidth(text("Devil May Cry pertenece a Capcom. Los autores originales conservan el crédito de sus componentes. La app y la adaptación para Mac se desarrollaron en este proyecto.", size: 11), in: stack)
        return scroll
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua); NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Acerca de DMC3 Patch", action: #selector(showCredits), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "Salir de DMC3 Patch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 860), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "DMC3 Patch"; window.minSize = NSSize(width: 1020, height: 830); window.titlebarAppearsTransparent = true
        window.delegate = self; window.isRestorable = false; window.backgroundColor = Palette.background
        let root = window.contentView!
        let sidebar = NSView(); sidebar.translatesAutoresizingMaskIntoConstraints = false; sidebar.wantsLayer = true; sidebar.layer?.backgroundColor = Palette.sidebar.cgColor; root.addSubview(sidebar)
        NSLayoutConstraint.activate([sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor), sidebar.topAnchor.constraint(equalTo: root.topAnchor), sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor), sidebar.widthAnchor.constraint(equalToConstant: 182)])
        let sideStack = column(spacing: 8); sideStack.translatesAutoresizingMaskIntoConstraints = false; sidebar.addSubview(sideStack)
        NSLayoutConstraint.activate([sideStack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 16), sideStack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -16), sideStack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 28)])
        let emblem = MissionArt()
        emblem.heightAnchor.constraint(equalToConstant: 89).isActive = true
        fullWidth(emblem, in: sideStack)
        let name = text("DMC3 PATCH", size: 17, color: Palette.brass, weight: .bold)
        name.font = NSFont(name: "Georgia-Bold", size: 17) ?? name.font
        sideStack.addArrangedSubview(name)
        sideStack.addArrangedSubview(text("MAC EDITION  /  III", size: 9, weight: .semibold))
        let spacer = NSView(); spacer.heightAnchor.constraint(equalToConstant: 22).isActive = true; sideStack.addArrangedSubview(spacer)
        let sections = [("Resumen", "folder.badge.gearshape"), ("Crimson", "flame"), ("Créditos", "heart.text.square")]
        for (index, section) in sections.enumerated() {
            let button = NSButton(title: "  " + L10n.text(section.0), target: self, action: #selector(navigate(_:)))
            languageBindings.append { button.title = "  " + L10n.text(section.0) }
            button.tag = index; button.image = NSImage(systemSymbolName: section.1, accessibilityDescription: nil); button.imagePosition = .imageLeading
            button.isBordered = false; button.alignment = .left; button.font = .systemFont(ofSize: 13, weight: .medium)
            button.wantsLayer = true; button.layer?.cornerRadius = 9; button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            fullWidth(button, in: sideStack); navigation.append(button)
        }
        let help = button("Cómo usar", #selector(openWelcome), needsGame: false)
        sideStack.setCustomSpacing(20, after: navigation[navigation.count - 1])
        fullWidth(help, in: sideStack)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.10.7"
        let sideFooter = text("v\(version)\n" + "Edición de GitHub", size: 10); sideFooter.translatesAutoresizingMaskIntoConstraints = false; sidebar.addSubview(sideFooter)
        NSLayoutConstraint.activate([sideFooter.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 22), sideFooter.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -22)])
        let stack = column(spacing: 12); stack.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 22), stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18)])
        let header = column(spacing: 6)
        let eyebrow = text("DMC3 PATCH  /  III", size: 10, color: Palette.brass, weight: .semibold)
        header.addArrangedSubview(eyebrow)
        pageTitle.font = NSFont(name: "Georgia-Bold", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)
        header.addArrangedSubview(pageTitle)
        pageSubtitle.font = .systemFont(ofSize: 12); pageSubtitle.textColor = Palette.muted; header.addArrangedSubview(pageSubtitle)
        let top = row(); top.addArrangedSubview(header)
        let headerSpace = NSView(); headerSpace.setContentHuggingPriority(.defaultLow, for: .horizontal); top.addArrangedSubview(headerSpace)
        languageMenu.addItems(withTitles: ["Español", "English"]); languageMenu.selectItem(at: L10n.language == "en" ? 1 : 0)
        languageMenu.target = self; languageMenu.action = #selector(changeLanguage); languageMenu.setAccessibilityLabel("Idioma / Language")
        languageMenu.widthAnchor.constraint(equalToConstant: 112).isActive = true
        top.addArrangedSubview(languageMenu)
        let banner = card()
        let tint = CAGradientLayer()
        tint.colors = [NSColor(srgbRed: 0.30, green: 0.09, blue: 0.14, alpha: 1).cgColor,
                       Palette.surface.cgColor,
                       NSColor(srgbRed: 0.11, green: 0.16, blue: 0.25, alpha: 1).cgColor]
        tint.startPoint = CGPoint(x: 0, y: 0.5)
        tint.endPoint = CGPoint(x: 1, y: 0.5)
        tint.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        tint.frame = banner.bounds
        banner.layer?.masksToBounds = true
        banner.layer?.insertSublayer(tint, at: 0)
        inset(banner, content: top, amount: 16)
        fullWidth(banner, in: stack)
        let summaries = row(spacing: 12); summaries.distribution = .fillEqually
        summaries.addArrangedSubview(summaryCard("CINEMÁTICAS", value: videoSummary, symbol: "play.rectangle"))
        summaries.addArrangedSubview(summaryCard("CRIMSON", value: modSummary, symbol: "flame")); fullWidth(summaries, in: stack)
        fullWidth(pageContainer, in: stack); pageContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        pages = [makeSummary(), makeCrimson(), makeCredits()]; selectPage(0)
        progressBar.style = .bar; progressBar.isIndeterminate = false; progressBar.minValue = 0; progressBar.maxValue = 1
        progressBar.controlTint = .graphiteControlTint; fullWidth(progressBar, in: stack)
        let stateRow = row(); status.font = .systemFont(ofSize: 12, weight: .medium); status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stateRow.addArrangedSubview(status); let flex = NSView(); flex.setContentHuggingPriority(.defaultLow, for: .horizontal); stateRow.addArrangedSubview(flex)
        cancelButton.target = self; cancelButton.action = #selector(cancel); cancelButton.bezelStyle = .rounded; stateRow.addArrangedSubview(cancelButton); fullWidth(stateRow, in: stack)
        let console = card(); let consoleStack = column(spacing: 8); inset(console, content: consoleStack, amount: 12)
        consoleStack.addArrangedSubview(text("REGISTRO DE ACTIVIDAD", size: 9, weight: .semibold))
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        output.isEditable = false; output.isSelectable = true; output.drawsBackground = false; output.textColor = .labelColor
        output.font = .monospacedSystemFont(ofSize: 10, weight: .regular); output.textContainerInset = NSSize(width: 0, height: 2)
        output.autoresizingMask = [.width]; output.isVerticallyResizable = true; output.isHorizontallyResizable = false; output.textContainer?.widthTracksTextView = true; scroll.documentView = output
        fullWidth(scroll, in: consoleStack); scroll.heightAnchor.constraint(equalToConstant: 96).isActive = true; fullWidth(console, in: stack)
        fullWidth(text("STEAM EN CROSSOVER  ·  El juego usa sus archivos instalados. Guardá los respaldos para restaurar.", size: 10), in: stack)
        engine.log = { [weak self] value in DispatchQueue.main.async { self?.append(value) } }
        engine.progress = { [weak self] value in DispatchQueue.main.async { self?.progressBar.doubleValue = value } }
        changeLanguage(); append("DMC3 Patch se usa para instalar, comprobar y restaurar. Elegí la carpeta del juego en Resumen. Después de aplicar, jugá desde Steam de Windows en CrossOver.")
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if engine.exists(welcomeReceipt) {
            if hasChosenGame { analyzeGame() }
        } else {
            presentWelcome(firstLaunch: true)
        }
    }
    func selectPage(_ index: Int) {
        guard pages.indices.contains(index) else { return }; selectedPage = index
        pageContainer.subviews.forEach { $0.removeFromSuperview() }
        let view = pages[index]; view.translatesAutoresizingMaskIntoConstraints = false; pageContainer.addSubview(view)
        NSLayoutConstraint.activate([view.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor), view.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor), view.topAnchor.constraint(equalTo: pageContainer.topAnchor), view.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor)])
        pageTitle.stringValue = L10n.text(["Juego y parche", "Crimson", "Créditos y fuentes"][index])
        pageSubtitle.stringValue = L10n.text(["Elegí el juego y administrá el parche de sus cinemáticas.", "El mod completo, disponible como instalación opcional.", "Autores originales, herramientas y licencias del proyecto."][index])
        for (i, button) in navigation.enumerated() {
            button.layer?.backgroundColor = (i == index ? Palette.accent.withAlphaComponent(0.15) : .clear).cgColor
            button.contentTintColor = i == index ? Palette.accent : Palette.muted
        }
    }
    func refresh() {
        let selected = hasChosenGame; let installed = selected && engine.exists(Paths.modState)
        let mod = crimsonReport.flatMap { $0.gamePath == Paths.game.path ? $0 : nil }
        buttons.forEach { $0.isEnabled = !busy }
        gameActions.forEach { $0.isEnabled = !busy && selected }
        let report = videoReport.flatMap { $0.gamePath == Paths.game.path ? $0 : nil }
        let legacyConflict = report?.legacyExecutablePatch == true && installed
        installVideoButton?.isEnabled = !busy && selected && report?.canInstall == true && !legacyConflict
        removeVideoButton?.isEnabled = !busy && selected && report?.canRemove == true && !legacyConflict
        installButton?.isEnabled = !busy && selected && CrimsonPaths.hasInstaller && crimsonArchive != nil && mod?.canInstall == true
        crimsonArchiveLabel.stringValue = crimsonArchive.map { L10n.text("Archivo listo: \($0.lastPathComponent)") }
            ?? L10n.text("Todavía no elegiste un archivo de Crimson.")
        removeButton?.isEnabled = !busy && selected && mod?.canRemove == true
        cancelButton.isEnabled = busy
        if let chosen = SelectionStore.shared.selected {
            selectedFolder.stringValue = chosen.gamePath
            detectedGame.stringValue = L10n.text("Ejecutable detectado: \(Paths.exe.lastPathComponent)")
            detectedGame.textColor = .systemGreen

        }
        if !selected { selectedFolder.stringValue = L10n.text("Todavía no elegiste una carpeta."); detectedGame.stringValue = L10n.text("Los cambios se aplican dentro de la carpeta elegida.") }
        scopeNotice.stringValue = L10n.text(selected ? "Las acciones de Crimson usan la carpeta del juego elegida en Resumen." : "Elegí primero la carpeta del juego en Resumen.")
        languageMenu.isEnabled = !busy
        if selected, let report {
            let color: NSColor = report.state == .installed ? .systemGreen : (report.state == .notInstalled || report.state == .originalsRestored ? .labelColor : .systemOrange)
            videoStatus.stringValue = L10n.text(report.title); videoStatus.textColor = color
            videoDetail.stringValue = L10n.text(legacyConflict ? "Quitá Crimson antes de remover el parche antiguo que modificaba dmc3.exe." : report.detail)
            videoSummary.stringValue = L10n.text(report.state == .installed ? "\(report.patched) videos instalados" : "Sin instalar")
            videoSummary.textColor = color
        } else {
            videoStatus.stringValue = L10n.text(videoAnalysisError == nil ? "Sin analizar" : "No se pudo analizar")
            videoStatus.textColor = videoAnalysisError == nil ? .labelColor : .systemRed
            videoDetail.stringValue = L10n.text(videoAnalysisError ?? (selected ? (busy ? "Analizando los archivos de video…" : "Usá Analizar para comprobar el estado del parche.") : "Elegí la carpeta del juego para analizar sus videos."))
            videoSummary.stringValue = L10n.text(selected ? "Sin analizar" : "Elegí una carpeta"); videoSummary.textColor = .labelColor
        }
        if selected, let mod {
            let color: NSColor = mod.state == .installed ? .systemGreen : mod.state == .notInstalled ? .labelColor : .systemOrange
            modStatus.stringValue = L10n.text(mod.title); modStatus.textColor = color
            modDetail.stringValue = L10n.text(mod.detail)
            modSummary.stringValue = L10n.text(mod.title); modSummary.textColor = color
        } else {
            modStatus.stringValue = L10n.text(crimsonAnalysisError == nil || !selected ? "Sin analizar" : "No se pudo analizar")
            modStatus.textColor = crimsonAnalysisError == nil || !selected ? .labelColor : .systemRed
            modDetail.stringValue = L10n.text(selected ? (crimsonAnalysisError ?? "Usá Analizar para comprobar los archivos de Crimson.") : "Elegí primero la carpeta del juego en Resumen.")
            modSummary.stringValue = L10n.text(selected ? "Sin analizar" : "Elegí una carpeta"); modSummary.textColor = .labelColor
        }
    }
    func append(_ value: String) {
        AppLog.write(value)
        guard let storage = output.textStorage else { return }
        storage.append(NSAttributedString(string: L10n.text(value) + "\n\n", attributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular), .foregroundColor: NSColor.labelColor]))
        if storage.length > 120_000 { storage.deleteCharacters(in: NSRange(location: 0, length: storage.length - 100_000)) }
        output.scrollToEndOfDocument(nil)
    }
    func work(_ label: String, operation: @escaping () throws -> Void) {
        guard !busy else { return }; busy = true; engine.reset(); refresh(); status.stringValue = L10n.text(label); status.textColor = .labelColor; progressBar.doubleValue = 0
        append(label)
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: String?; do { try operation() } catch { failure = error.localizedDescription }
            DispatchQueue.main.async {
                self.busy = false; self.refresh()
                if let failure { self.append("DETENIDO · " + failure); self.status.stringValue = L10n.text("Operación detenida. Revisá el registro."); self.status.textColor = .systemRed }
                else { self.status.stringValue = L10n.text("Operación completada."); self.status.textColor = .systemGreen; self.progressBar.doubleValue = 1 }
            }
        }
    }
    @objc func changeLanguage() {
        do { try L10n.set(languageMenu.indexOfSelectedItem == 1 ? "en" : "es") }
        catch { append(error.localizedDescription); return }
        languageBindings.forEach { $0() }
        status.stringValue = L10n.text(status.stringValue); cancelButton.title = L10n.text("Cancelar")
        output.string = L10n.text(output.string)
        if let menu = NSApp.mainMenu?.items.first?.submenu {
            menu.items.first?.title = L10n.text("Acerca de DMC3 Patch"); menu.items.last?.title = L10n.text("Salir de DMC3 Patch")
        }
        selectPage(selectedPage); refresh()
    }
    @objc func openWelcome() { presentWelcome() }

    private func letter(_ value: String, size: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: L10n.text(value))
        field.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        field.textColor = Palette.ink
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        return field
    }

    private func guideScroll(_ entries: NSStackView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let document = FlippedDocumentView()
        inset(document, content: entries, amount: 12)
        scroll.documentView = document
        document.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        return scroll
    }

    private func addGuideSteps(_ steps: [(String, String)], to stack: NSStackView) {
        for (index, step) in steps.enumerated() {
            let line = row(spacing: 12)
            let number = letter(String(format: "%02d", index + 1), size: 12, bold: true)
            number.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            number.textColor = Palette.wax
            number.widthAnchor.constraint(equalToConstant: 24).isActive = true
            line.addArrangedSubview(number)
            let details = column(spacing: 3)
            fullWidth(letter(step.0, bold: true), in: details)
            fullWidth(letter(step.1), in: details)
            line.addArrangedSubview(details)
            fullWidth(line, in: stack)
        }
    }

    private func makeCrimsonInstallGuide() -> NSView {
        let entries = column(spacing: 13)
        addGuideSteps([
            ("Descargá Crimson 0.5a", "Guardá el paquete completo en ZIP o RAR. Seleccionalo directamente desde el disco donde lo guardaste."),
            ("Elegí el juego y cerrá la colección", "En Resumen, elegí la carpeta que contiene el ejecutable de DMC3 y data/dmc3. Cerrá el juego y el launcher, y esperá a que Steam muestre Jugar."),
            ("Seleccioná y comprobá el archivo", "En Crimson, pulsá Elegir ZIP o RAR de Crimson. Cuando aparezca Archivo listo, usá Analizar para comprobar la instalación."),
            ("Instalá el mod", "Pulsá Instalar y esperá a que la app confirme Crimson instalado. Después abrí el juego desde Steam en CrossOver.")
        ], to: entries)
        fullWidth(letter("Si Instalar está desactivado, revisá el resultado de Analizar. Si dice Crimson sin registro de instalación, elegí una copia limpia del juego.", size: 12), in: entries)
        fullWidth(letter("Para quitar el mod, cerrá la colección y pulsá Quitar en Crimson. La app restaura los archivos que respaldó al instalar.", size: 12), in: entries)
        let links = row()
        for (title, url) in [
            ("Nexus Mods", "https://www.nexusmods.com/devilmaycryhdcollection/mods/272?tab=files"),
            ("GitHub", "https://github.com/berthrage/DMC3-Crimson/releases/tag/V0.5a")
        ] {
            let link = NSButton(title: title, target: self, action: #selector(openCredit(_:)))
            link.identifier = NSUserInterfaceItemIdentifier(url)
            links.addArrangedSubview(link)
        }
        links.addArrangedSubview(NSButton(title: L10n.text("Guía en español"), target: self, action: #selector(openGuide)))
        fullWidth(links, in: entries)
        return guideScroll(entries)
    }

    private func makeStorageGuide() -> NSView {
        let entries = column(spacing: 14)

        func addEntry(_ title: String, path: String, detail: String) {
            let entry = column(spacing: 4)
            fullWidth(letter(title, bold: true), in: entry)
            let location = letter(path)
            location.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
            location.isSelectable = true
            location.lineBreakMode = .byCharWrapping
            fullWidth(location, in: entry)
            fullWidth(letter(detail, size: 12), in: entry)
            fullWidth(entry, in: entries)
        }

        addEntry("Carpeta de datos de tu usuario", path: Paths.project.path,
                 detail: "Acá se guardan las preferencias, los informes y los respaldos de DMC3 Patch.")
        entries.addArrangedSubview(NSButton(title: L10n.text("Abrir carpeta de datos en Finder"), target: self, action: #selector(openDataFolder)))
        let cleanup = column(spacing: 4)
        fullWidth(letter("Antes de borrar los respaldos", bold: true), in: cleanup)
        fullWidth(letter("Cerrá el juego. Si instalaste Crimson, usá Quitar en su pestaña. Después usá Remover en Resumen para recuperar las cinemáticas originales. Repetilo para cada instalación que quieras limpiar y cerrá DMC3 Patch antes de borrar archivos.", size: 12), in: cleanup)
        fullWidth(letter("Borrar los datos de la app deja los cambios aplicados en el juego y elimina los respaldos para deshacerlos.", size: 12), in: cleanup)
        fullWidth(cleanup, in: entries)

        addEntry("Preferencias", path: "game-selection.json · language.json · welcome-v1-seen",
                 detail: "Están en la carpeta de datos. Si los borrás, se reinician respectivamente la carpeta elegida, el idioma y la bienvenida.")
        addEntry("Registros e informes", path: Paths.project.appendingPathComponent("reports").path,
                 detail: "Incluye app.log y los informes de análisis. Podés borrarlos con la app cerrada.")
        addEntry("Archivos temporales", path: Paths.project.appendingPathComponent(".build/tmp").path,
                 detail: "Podés borrar esta carpeta con la app cerrada. Se vuelve a crear cuando hace falta.")

        if Paths.hasSelection {
            addEntry("Respaldos de video de la instalación elegida", path: Paths.runs.path,
                     detail: "Contiene preparaciones y copias de los videos originales. Los registros active-patch.json y latest-prepared.txt se guardan junto a runs.")
            addEntry("Respaldos de Crimson de la instalación elegida", path: CrimsonPaths.backups.path,
                     detail: "Contiene archivos originales y copias de partidas si había un SavesDir. El registro installed.json se guarda en la carpeta que contiene backups.")
        } else {
            addEntry("Respaldos por instalación", path: "installations/<id>/runs · installations/<id>/mods/crimson/backups",
                     detail: "Elegí el juego en Resumen para ver las rutas exactas. Las instalaciones anteriores pueden tener sus respaldos directamente en la carpeta de datos.")
        }
        return guideScroll(entries)
    }

    @objc private func openDataFolder() { NSWorkspace.shared.open(Paths.project) }

    @objc private func openCrimsonInstallGuide() { presentWelcome(section: "Instalar Crimson") }

    private func presentWelcome(firstLaunch: Bool = false, section: String = "Cómo aplicar el parche") {
        guard !busy, welcomePanel == nil else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 650, height: 620),
                            styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = L10n.text("Carta de bienvenida")
        panel.appearance = NSAppearance(named: .aqua)
        panel.isRestorable = false

        let paper = NSView()
        paper.wantsLayer = true
        paper.layer?.backgroundColor = Palette.paper.cgColor
        panel.contentView = paper
        let content = column(spacing: 13)
        inset(paper, content: content, amount: 27)

        let intro = row(spacing: 20)
        let salutation = column(spacing: 6)
        salutation.addArrangedSubview(letter("DMC3 PATCH  /  01", size: 10, bold: true))
        let title = letter("Carta de bienvenida", size: 31, bold: true)
        title.font = NSFont(name: "Georgia-Bold", size: 31) ?? title.font
        salutation.addArrangedSubview(title)
        intro.addArrangedSubview(salutation)
        let space = NSView()
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)
        intro.addArrangedSubview(space)
        let seal = MissionArt()
        seal.widthAnchor.constraint(equalToConstant: 72).isActive = true
        seal.heightAnchor.constraint(equalToConstant: 60).isActive = true
        intro.addArrangedSubview(seal)
        fullWidth(intro, in: content)

        let instructions = NSView()
        let stepsStack = column(spacing: 13)
        inset(instructions, content: stepsStack, amount: 12, fill: false)
        fullWidth(letter("Hola. DMC3 Patch prepara las cinemáticas de Devil May Cry 3 para jugar en CrossOver y guarda un respaldo para restaurarlas."), in: stepsStack)
        let steps = [
            ("Cerrá la colección", "Cerrá DMC3 y el launcher antes de aplicar cambios."),
            ("Elegí la carpeta del juego", "En Resumen, seleccioná la carpeta que contiene el ejecutable y data/dmc3."),
            ("Instalá el parche de video", "Pulsá Instalar. Cuando termine, abrí el juego desde Steam en CrossOver.")
        ]
        addGuideSteps(steps, to: stepsStack)
        let note = CrimsonPaths.hasInstaller
            ? "Podés instalar el mod opcional en Crimson. Usá Remover en Resumen si querés recuperar los videos originales."
            : "Esta edición incluye el parche de video. Usá Remover en Resumen si querés recuperar los videos originales."
        fullWidth(letter(note, size: 12), in: stepsStack)
        let tabs = NSTabView()
        for (label, view) in [
            ("Cómo aplicar el parche", instructions),
            ("Instalar Crimson", makeCrimsonInstallGuide()),
            ("Datos y respaldos", makeStorageGuide())
        ] {
            let tab = NSTabViewItem(identifier: label)
            tab.label = L10n.text(label)
            tab.view = view
            tabs.addTabViewItem(tab)
        }
        tabs.selectTabViewItem(withIdentifier: section)
        tabs.setContentHuggingPriority(.defaultLow, for: .vertical)
        fullWidth(tabs, in: content)
        let close = NSButton(title: L10n.text("Empezar"), target: self, action: #selector(dismissWelcome))
        close.bezelStyle = .rounded
        close.controlSize = .large
        close.keyEquivalent = "\r"
        let actions = row()
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actions.addArrangedSubview(filler)
        actions.addArrangedSubview(close)
        fullWidth(actions, in: content)

        welcomePanel = panel
        window.beginSheet(panel) { [weak self] _ in
            guard let self else { return }
            self.welcomePanel = nil
            do { try Data([1]).write(to: self.welcomeReceipt, options: .atomic) }
            catch { self.append(error.localizedDescription) }
            if firstLaunch && self.hasChosenGame { self.analyzeGame() }
        }
    }

    @objc private func dismissWelcome() {
        if let panel = welcomePanel { window.endSheet(panel, returnCode: .OK) }
    }

    @objc func chooseGameFolder() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.title = L10n.text("Elegir Devil May Cry HD Collection")
        panel.message = L10n.text("Elegí la carpeta que contiene el ejecutable de DMC3 y data. Puede conservar su nombre personalizado.")
        panel.prompt = L10n.text("Elegir juego"); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.canCreateDirectories = false
        if let selected = SelectionStore.shared.selected { panel.directoryURL = URL(fileURLWithPath: selected.gamePath).deletingLastPathComponent() }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let folder = panel.url else { return }
            self.work("Analizando la carpeta del juego…") {
                let chosen = try SelectionStore.shared.select(folder)
                self.engine.log("Juego elegido: \(chosen.gamePath)\nLa selección no modifica archivos del juego.")
                try self.readGameReports()
            }
        }
    }
    @objc func navigate(_ sender: NSButton) { selectPage(sender.tag) }
    @objc func showCredits() { selectPage(2) }
    func readVideoReport() throws {
        do {
            let report = try engine.analyzeVideoPatch()
            DispatchQueue.main.async { self.videoReport = report; self.videoAnalysisError = nil }
        } catch {
            let message = error.localizedDescription
            DispatchQueue.main.async { self.videoReport = nil; self.videoAnalysisError = message }
            throw error
        }
    }
    @objc func analyze() {
        videoReport = nil; videoAnalysisError = nil
        work("Analizando videos…") { try self.readVideoReport() }
    }
    @objc func installVideos() {
        work("Instalando el parche de video…") {
            do { try self.engine.installVideoPatch() }
            catch { try? self.readVideoReport(); throw error }
            try self.readVideoReport()
        }
    }
    @objc func removeVideos() {
        work("Removiendo el parche de video…") {
            do { try self.engine.restore() }
            catch { try? self.readVideoReport(); throw error }
            try self.readVideoReport()
        }
    }
    func readCrimsonReport() throws {
        do {
            let report = try crimson.analyze()
            DispatchQueue.main.async { self.crimsonReport = report; self.crimsonAnalysisError = nil }
        } catch {
            let message = error.localizedDescription
            DispatchQueue.main.async { self.crimsonReport = nil; self.crimsonAnalysisError = message }
            throw error
        }
    }
    func readGameReports() throws {
        var failure: Error?
        do { try readVideoReport() } catch { failure = error }
        do { try readCrimsonReport() } catch { if failure == nil { failure = error } }
        if let failure { throw failure }
    }
    func analyzeGame() { work("Analizando el juego y Crimson…") { try self.readGameReports() } }
    @objc func analyzeCrimson() {
        guard hasChosenGame, !busy else { return }
        crimsonReport = nil; crimsonAnalysisError = nil
        work("Analizando Crimson…") { try self.readCrimsonReport() }
    }
    @objc private func chooseCrimsonArchive() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.title = L10n.text("Elegí el ZIP o RAR de Crimson 0.5a.")
        panel.allowedContentTypes = [.zip, UTType(filenameExtension: "rar") ?? .archive]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let archive = panel.url, let self else { return }
            self.crimsonArchive = nil
            self.work("Comprobando el archivo de Crimson…") {
                try self.crimson.validateArchive(archive)
                DispatchQueue.main.async {
                    self.crimsonArchive = archive
                    self.append("Archivo de Crimson comprobado.")
                }
            }
        }
    }
    @objc func installCrimson() {
        guard hasChosenGame, !busy, let archive = crimsonArchive else { return }
        work("Instalando Crimson con respaldo…") {
            do {
                if self.engine.exists(Paths.modState) { try self.crimson.updateGameFiles(archive: archive) }
                else { try self.crimson.install(archive: archive) }
            } catch { try? self.readCrimsonReport(); throw error }
            try self.readCrimsonReport()
        }
    }
    @objc func removeCrimson() {
        guard hasChosenGame, !busy else { return }
        work("Quitando Crimson…") {
            do { try self.crimson.uninstall() }
            catch { try? self.readCrimsonReport(); throw error }
            try self.readCrimsonReport()
        }
    }
    @objc func openGuide() {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("GuiaCrimson.html"); let local = Paths.assets.appendingPathComponent("docs/GUIA-CRIMSON-ES.html")
        NSWorkspace.shared.open(bundled.flatMap { engine.exists($0) ? $0 : nil } ?? local)
    }
    @objc func openCredit(_ sender: NSButton) {
        if let value = sender.identifier?.rawValue, let url = URL(string: value), url.scheme == "https" { NSWorkspace.shared.open(url) }
    }
    @objc func openLicenses() {
        if let folder = Bundle.main.resourceURL?.appendingPathComponent("licenses") { NSWorkspace.shared.open(folder) }
    }
    @objc func cancel() { if busy { engine.cancel(); status.stringValue = "Cancelando al terminar el paso actual…" } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy { status.stringValue = "Usá Cancelar y esperá a que termine la operación antes de salir."; return .terminateCancel }; return .terminateNow
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { !busy }
}
