import Foundation
import CryptoKit

struct GameSelection: Codable, Equatable {
    var gamePath: String
    var executableName: String? = nil
}
struct SelectionSettings: Codable {
    var schema = 1
    var selected: GameSelection?
    var legacyGamePath: String?
}
enum GameFolder {
    static func executableNameIsSafe(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && !name.contains("\0") &&
        name.lowercased().hasSuffix(".exe") && !["dmc1.exe", "dmc2.exe", "dmclauncher.exe"].contains(name.lowercased())
    }
    static func knownHashes() -> Set<String> {
        let url = Paths.assets.appendingPathComponent("mods/crimson/prepared/manifest.json")
        guard let data = try? Data(contentsOf: url), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return Set(["baseFiles", "files"].flatMap { key in
            (object[key] as? [[String: Any]] ?? []).filter { $0["path"] as? String == "dmc3.exe" }.compactMap { $0["hash"] as? String }
        })
    }
    static func candidates(_ folder: URL, hashes: Set<String>? = nil) throws -> [URL] {
        let known = hashes ?? knownHashes(); let engine = Engine()
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]).filter { file in
            guard executableNameIsSafe(file.lastPathComponent) else { return false }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { return false }
            let input = try FileHandle(forReadingFrom: file); defer { try? input.close() }
            guard try input.read(upToCount: 2) == Data("MZ".utf8) else { return false }
            if file.lastPathComponent.lowercased() == "dmc3.exe" { return true }
            return try known.contains(engine.hash(file))
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    static func executable(in folder: URL, preferred: String? = nil, hashes: Set<String>? = nil) throws -> URL {
        let choices = try candidates(folder, hashes: hashes)
        if let preferred, let selected = choices.first(where: { $0.lastPathComponent == preferred }) { return selected }
        if let original = choices.first(where: { $0.lastPathComponent.lowercased() == "dmc3.exe" }) { return original }
        guard let first = choices.first else { throw PatchError("No se encontró un ejecutable reconocido de DMC3. Si está renombrado, debe coincidir con una versión compatible.") }
        return first
    }
    static func validate(_ folder: URL, hashes: Set<String>? = nil) throws -> URL {
        let root = folder.standardizedFileURL.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("data/dmc3").path) else {
            throw PatchError("Elegí la carpeta que contiene el ejecutable de DMC3 y data/dmc3, aunque el ejecutable tenga otro nombre.")
        }
        _ = try executable(in: root, hashes: hashes)
        return root
    }
    static func commandIsGame(_ command: String, collection: Bool) -> Bool {
        var names = (try? candidates(Paths.game).map(\.lastPathComponent)) ?? []
        names += collection ? ["dmc1.exe", "dmc2.exe", "dmc3.exe", "dmcLauncher.exe"] : ["dmc3.exe"]
        if let remembered = SelectionStore.shared.selected?.executableName { names.append(remembered) }
        let alternatives = Set(names).map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return command.range(of: #"(?i)(?:^|[/\\\s"'])(?:"# + alternatives + #")(?:[\s"']|$)"#, options: .regularExpression) != nil
    }
}

final class SelectionStore {
    static let shared = SelectionStore(project: Paths.project)
    let project: URL
    private var settings: SelectionSettings
    var selected: GameSelection? { settings.selected }
    var dataRoot: URL { selected.map { dataRoot(for: $0.gamePath) } ?? project.appendingPathComponent(".no-game-selected") }
    init(project: URL) {
        self.project = project
        let storage = project.appendingPathComponent("game-selection.json")
        if let data = try? Data(contentsOf: storage), let value = try? JSONDecoder().decode(SelectionSettings.self, from: data), value.schema == 1 { settings = value }
        else {
            let oldFiles = [project.appendingPathComponent("active-patch.json"), project.appendingPathComponent("mods/crimson/installed.json")]
            let legacy = oldFiles.compactMap { try? Data(contentsOf: $0) }.compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }.compactMap { $0["gamePath"] as? String }.first
            settings = SelectionSettings(selected: nil, legacyGamePath: legacy)
        }
    }
    func dataRoot(for game: String) -> URL {
        if settings.legacyGamePath == game { return project }
        let key = SHA256.hash(data: Data(game.utf8)).map { String(format: "%02x", $0) }.joined()
        return project.appendingPathComponent("installations/" + key.prefix(20), isDirectory: true)
    }
    @discardableResult
    func select(_ folder: URL) throws -> GameSelection {
        let game = try GameFolder.validate(folder)
        let result = GameSelection(gamePath: game.path, executableName: try GameFolder.executable(in: game).lastPathComponent)
        let fm = FileManager.default
        let lock = project.appendingPathComponent(".operation-lock")
        do { try fm.createDirectory(at: lock, withIntermediateDirectories: false) }
        catch { throw PatchError("Esperá a que termine la operación activa antes de cambiar la carpeta del juego.") }
        defer { try? fm.removeItem(at: lock) }
        var updated = settings; updated.selected = result
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: project.appendingPathComponent("game-selection.json"), options: .atomic)
        settings = updated
        return result
    }
}
