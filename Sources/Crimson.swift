import Foundation
import Darwin

enum CrimsonPaths {
    static let root = Paths.assets.appendingPathComponent("mods/crimson", isDirectory: true)
    static let prepared = root.appendingPathComponent("prepared", isDirectory: true)
    static let payload = prepared.appendingPathComponent("payload", isDirectory: true)
    static let archive = prepared.appendingPathComponent("payload.zip")
    static var hasInstaller: Bool {
        FileManager.default.fileExists(atPath: archive.path) ||
        FileManager.default.fileExists(atPath: payload.path)
    }
    static let recipe = prepared.appendingPathComponent("manifest.json")
    static var backups: URL { Paths.dataRoot.appendingPathComponent("mods/crimson/backups", isDirectory: true) }

}

struct ModFile: Codable {
    var path: String
    var hash: String
    var size: Int64
}
struct ModBaseFile: Codable { var path: String; var hash: String }
struct ModRecipe: Codable {
    var schema: Int
    var name: String
    var version: String
    var compatibility: String
    var baseFiles: [ModBaseFile]
    var files: [ModFile]
    var totalBytes: Int64
    var deployment: String?
    var archiveSHA256: String?
}
struct ModInstalledFile: Codable {
    var path: String
    var installedHash: String
    var originalHash: String?
    var originalMode: Int?
    var originalPath: String? = nil
}
struct ModRegistryValue: Codable {
    var section: String
    var name: String
    var originalLine: String?
    var installedLine: String
}
struct ModInstallation: Codable {
    var schema = 1
    var id: String
    var status: String
    var gamePath: String
    var prefixPath: String
    var version: String
    var files: [ModInstalledFile]
    var registryValues: [ModRegistryValue]
    var createdDirectories: [String]
    var saveBackupPaths: [String]
    var runtimeValidated = false
    var deployment: String?
}

enum CrimsonStatus: String, Codable {
    case notInstalled, installed, legacy, incomplete, changed, pending, untracked, incompatible
}
struct CrimsonReport: Codable {
    var gamePath: String
    var state: CrimsonStatus
    var total = 0
    var verified = 0
    var originals = 0
    var missing: [String] = []
    var changed: [String] = []
    var hasRecord = false
    var checkedAt = Date()
    var canInstall: Bool { state == .notInstalled || state == .legacy }
    var canRemove: Bool { hasRecord }
    var title: String {
        switch state {
        case .notInstalled: return "Crimson no instalado"
        case .installed: return "Crimson instalado"
        case .legacy: return "Crimson instalado · actualización disponible"
        case .incomplete: return "Crimson incompleto"
        case .changed: return "Crimson con cambios por revisar"
        case .pending: return "Crimson: recuperación pendiente"
        case .untracked: return "Crimson sin registro de instalación"
        case .incompatible: return "Juego incompatible con el paquete Crimson"
        }
    }
    var detail: String {
        switch state {
        case .notInstalled: return "Instalar añade el paquete completo con respaldo."
        case .installed: return "\(verified) archivos del mod verificados dentro del juego."
        case .legacy: return "Instalar actualiza los archivos locales y conserva los respaldos."
        case .incomplete: return "\(verified) de \(total) archivos del mod verificados; \(originals) originales y \(missing.count) faltantes. Usá Quitar antes de instalar de nuevo."
        case .changed: return "\(changed.count) archivos del mod tienen cambios ajenos a la instalación. Revisá el registro; esos cambios se conservan."
        case .pending: return "Usá Quitar para recuperar la operación anterior."
        case .untracked: return "Se encontraron archivos de Crimson sin respaldo registrado. Revisá esa instalación antes de reemplazarla."
        case .incompatible: return "Los archivos base del juego no coinciden con el paquete preparado. Revisá el registro."
        }
    }
}

final class CrimsonInstaller {
    let engine: Engine
    let fm = FileManager.default
    init(engine: Engine) { self.engine = engine }

    func safeURL(_ base: URL, _ relative: String) throws -> URL {
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard !relative.hasPrefix("/"), !relative.contains("\\"), !relative.contains("\0"),
              !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw PatchError("Ruta no válida en el paquete: \(relative)")
        }
        let url = base.appendingPathComponent(relative)
        var component = base
        for part in parts {
            component.appendPathComponent(String(part))
            if let attributes = try? fm.attributesOfItem(atPath: component.path), attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                throw PatchError("Se detectó un enlace simbólico: \(component.path)")
            }
        }
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        guard url.standardizedFileURL.path.caseInsensitiveCompare(resolved.path) == .orderedSame else {
            throw PatchError("Se detectó un enlace simbólico: \(url.path)")
        }
        return resolved
    }
    func allowed(_ path: String) -> Bool {
        let rootFiles: Set<String> = ["Crimson.dll", "DMCHDFix.asi", "DMCHDFix.ini", "LICENSE.txt", "SDL2.dll", "SDL2_mixer.dll", "d3d11.dll", "dmcload.dll", "dinput8.dll", "libmpg123-0.dll", "dmc3.exe", "dmcLauncher.exe", "crimson_api.dll"]
        return rootFiles.contains(path) || GameFolder.executableNameIsSafe(path) || path.hasPrefix("Crimson/") || path.hasPrefix("data/dmc3/GData.afs/")
    }
    func validateLayout() throws {
        guard Paths.hasSelection else { throw PatchError("Elegí la carpeta del juego en Resumen antes de continuar.") }
        for url in [CrimsonPaths.root, CrimsonPaths.prepared, CrimsonPaths.payload, CrimsonPaths.archive, CrimsonPaths.recipe, CrimsonPaths.backups, Paths.modState] {
            guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().standardizedFileURL.path else {
                throw PatchError("Se detectó un enlace simbólico: \(url.path)")
            }
        }
    }
    func assertCollectionClosed() throws {
        let commands = try engine.processCommands()
        if GameFolder.commandIsGame(commands, collection: true) || commands.components(separatedBy: "\n").contains(where: { $0.contains("waitforexitandrun") && $0.contains(Paths.game.path) }) {
            throw PatchError("Cerrá toda la colección, incluido el launcher, y esperá a que Steam muestre Jugar antes de instalar o quitar Crimson.")
        }
    }
    func loadRecipe() throws -> ModRecipe {
        var recipe = try engine.read(CrimsonPaths.recipe, as: ModRecipe.self)
        guard recipe.schema == 1, recipe.version == "0.5a", recipe.deployment == "game-files-only-v1", !recipe.files.isEmpty,
              Set(recipe.files.map(\.path)).count == recipe.files.count,
              Set(recipe.baseFiles.map(\.path)) == Set(["dmc3.exe", "dmcLauncher.exe", "steam_api64.dll"]) else {
            throw PatchError("La preparación de Crimson está incompleta o no es compatible.")
        }
        if let original = recipe.files.first(where: { $0.path == "dmc3.exe" }) {
            for alias in try GameFolder.candidates(Paths.game) where alias.lastPathComponent.lowercased() != "dmc3.exe" {
                recipe.files.append(ModFile(path: alias.lastPathComponent, hash: original.hash, size: original.size))
            }
        }
        for file in recipe.files {
            guard allowed(file.path), file.hash.count == 64, file.size > 0 else { throw PatchError("Archivo fuera del alcance de Crimson: \(file.path)") }
            _ = try safeURL(Paths.game, file.path)
            _ = try payloadURL(file)
        }
        return recipe
    }
    func payloadURL(_ file: ModFile, in payload: URL = CrimsonPaths.payload) throws -> URL {
        try safeURL(payload, GameFolder.executableNameIsSafe(file.path) ? "dmc3.exe" : file.path)
    }
    func baseURL(_ path: String) throws -> URL {
        if path == "dmc3.exe" { return Paths.exe }
        return try safeURL(Paths.game, path)
    }
    // Called under the operation lock. The signed manifest pins the exact ZIP
    // before extraction, and the existing file-level checks verify its contents.
    func unpackPayload(_ recipe: ModRecipe) throws -> URL {
        if engine.exists(CrimsonPaths.payload) { return CrimsonPaths.payload }
        guard engine.exists(CrimsonPaths.archive) else {
            throw PatchError("Esta edición incluye el parche de video. El instalador de Crimson requiere su paquete local.")
        }
        guard let expected = recipe.archiveSHA256, expected.count == 64,
              try engine.hash(CrimsonPaths.archive) == expected else {
            throw PatchError("El ZIP de Crimson no coincide con su huella de verificación.")
        }
        let temporary = Paths.project.appendingPathComponent(".build/tmp/crimson-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: false)
        do {
            engine.log("Descomprimiendo Crimson para esta instalación…")
            try engine.run(URL(fileURLWithPath: "/usr/bin/ditto"), ["-x", "-k", CrimsonPaths.archive.path, temporary.path])
            return temporary
        } catch {
            try? fm.removeItem(at: temporary)
            throw error
        }
    }
    func releasePayload(_ payload: URL) {
        if payload != CrimsonPaths.payload { try? fm.removeItem(at: payload) }
    }
    func verifyPayload(_ recipe: ModRecipe, in payload: URL) throws {
        engine.log("Verificando \(recipe.files.count) archivos del paquete Crimson…")
        for (index, file) in recipe.files.enumerated() {
            try engine.checkCancel()
            let url = try payloadURL(file, in: payload)
            guard engine.exists(url), try engine.hash(url) == file.hash else { throw PatchError("La preparación cambió o está incompleta: \(file.path)") }
            if index % 50 == 0 { engine.progress(Double(index) / Double(recipe.files.count) * 0.2) }
        }
    }
    func loadState(requireSelectedPrefix: Bool = false) throws -> ModInstallation {
        var state = try engine.read(Paths.modState, as: ModInstallation.self)
        guard state.schema == 1, state.gamePath == Paths.game.path,
              !state.id.isEmpty, !state.id.contains("/"), !state.id.contains(".."),
              Set(state.files.map(\.path)).count == state.files.count else { throw PatchError("Registro de Crimson inválido.") }
        var tracked = Set(state.files.map(\.path))
        for index in state.files.indices {
            let file = state.files[index]
            guard GameFolder.executableNameIsSafe(file.path), !engine.exists(try safeURL(Paths.game, file.path)) else { continue }
            let matches = try GameFolder.candidates(Paths.game).filter { candidate in
                try !tracked.contains(candidate.lastPathComponent) && engine.hash(candidate) == file.installedHash
            }
            if matches.count == 1 {
                state.files[index].originalPath = file.originalPath ?? file.path
                state.files[index].path = matches[0].lastPathComponent
                tracked.insert(matches[0].lastPathComponent)
            }
        }
        for file in state.files { guard allowed(file.path) else { throw PatchError("Ruta ajena a Crimson en el respaldo.") }; _ = try safeURL(Paths.game, file.path) }
        guard state.createdDirectories.allSatisfy({ directory in directory == "Crimson/configs" || state.files.contains(where: { $0.path.hasPrefix(directory + "/") }) }) else {
            throw PatchError("El registro contiene carpetas ajenas a los archivos instalados.")
        }
        return state
    }
    @discardableResult
    func analyze() throws -> CrimsonReport {
        try engine.withLock {
            try validateLayout()
            let recipe = try loadRecipe()
            var report = CrimsonReport(gamePath: Paths.game.path, state: .notInstalled)
            if engine.exists(Paths.modState) {
                let state = try loadState()
                guard !state.files.isEmpty else { throw PatchError("Registro de Crimson inválido.") }
                report.hasRecord = true; report.total = state.files.count
                for (index, file) in state.files.enumerated() {
                    try engine.checkCancel()
                    guard file.installedHash.count == 64, file.originalHash == nil || file.originalHash?.count == 64 else { throw PatchError("Registro de Crimson inválido.") }
                    let url = try safeURL(Paths.game, file.path)
                    if !engine.exists(url) { report.missing.append(file.path) }
                    else {
                        let hash = try engine.hash(url)
                        if hash == file.installedHash { report.verified += 1 }
                        else if hash == file.originalHash { report.originals += 1 }
                        else { report.changed.append(file.path) }
                    }
                    if index % 50 == 0 { engine.progress(Double(index + 1) / Double(state.files.count)) }
                }
                if state.status != "installed" { report.state = .pending }
                else if !report.changed.isEmpty { report.state = .changed }
                else if report.verified != report.total { report.state = .incomplete }
                else {
                    let recorded = Dictionary(uniqueKeysWithValues: state.files.map { ($0.path, $0.installedHash) })
                    let current = Dictionary(uniqueKeysWithValues: recipe.files.map { ($0.path, $0.hash) })
                    report.state = state.deployment == "game-files-only-v1" && recorded == current ? .installed : .legacy
                }
            } else {
                for name in ["Crimson.dll", "dmcload.dll"] where engine.exists(try safeURL(Paths.game, name)) { report.changed.append(name) }
                if !report.changed.isEmpty { report.state = .untracked }
                else {
                    for base in recipe.baseFiles {
                        let url = try baseURL(base.path)
                        if try !engine.exists(url) || engine.hash(url) != base.hash { report.changed.append(base.path) }
                    }
                    if !report.changed.isEmpty { report.state = .incompatible }
                    else { engine.log("La versión del juego coincide con los parches de compatibilidad preparados.") }
                }
            }
            try engine.mkdir(Paths.project.appendingPathComponent("reports"))
            try engine.write(report, Paths.project.appendingPathComponent("reports/crimson-analysis.json"))
            engine.log(report.title + "\n" + report.detail)
            if !report.changed.isEmpty { engine.log("Archivos por revisar: " + report.changed.joined(separator: ", ")) }
            if !report.missing.isEmpty { engine.log("Archivos faltantes: " + report.missing.joined(separator: ", ")) }
            return report
        }
    }
    func backupSaves(to backup: URL) throws -> [String] {
        let source = Paths.game.appendingPathComponent("SavesDir", isDirectory: true)
        guard source.resolvingSymlinksInPath().path == source.path else {
            throw PatchError("SavesDir está enlazada fuera de la carpeta del juego. Respaldá esas partidas manualmente antes de instalar.")
        }
        guard engine.exists(source) else { return [] }
        // Avoid following Wine's Documents links into personal macOS folders.
        // Also reject links nested inside SavesDir before copying the backup.
        _ = try engine.records(source)
        let destination = backup.appendingPathComponent("saves/0", isDirectory: true)
        try engine.mkdir(destination.deletingLastPathComponent())
        try fm.copyItem(at: source, to: destination)
        return [source.path]
    }
    func saveJournal(_ state: ModInstallation, backup: URL) throws {
        try engine.write(state, backup.appendingPathComponent("manifest.json"))
        try engine.write(state, Paths.modState)
    }
    func install() throws {
        try engine.withLock {
            try validateLayout(); try assertCollectionClosed()
            guard !engine.exists(Paths.modState) else { throw PatchError("Crimson ya está instalado o tiene una recuperación pendiente. Usá Quitar Crimson antes de reinstalar.") }
            let recipe = try loadRecipe()
            for base in recipe.baseFiles {
                guard try engine.hash(baseURL(base.path)) == base.hash else { throw PatchError("\(base.path) cambió. La instalación se detuvo antes de modificar el juego.") }
            }
            let payload = try unpackPayload(recipe)
            defer { releasePayload(payload) }
            try verifyPayload(recipe, in: payload)
            let id = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") + "-" + UUID().uuidString.prefix(8)
            let backup = try safeURL(CrimsonPaths.backups, id)
            try engine.mkdir(backup)
            let staging = Paths.game.appendingPathComponent(".dmc3-crimson-stage-" + id, isDirectory: true)
            guard !engine.exists(staging) else { throw PatchError("Existe una preparación temporal de Crimson.") }
            try engine.mkdir(staging)
            defer { try? fm.removeItem(at: staging) }
            var state = ModInstallation(id: id, status: "installing", gamePath: Paths.game.path, prefixPath: "",
                                        version: recipe.version, files: [], registryValues: [], createdDirectories: [], saveBackupPaths: [])
            var created: Set<String> = []
            engine.log("Guardando archivos previos y partidas antes de instalar…")
            for (index, file) in recipe.files.enumerated() {
                try engine.checkCancel()
                let destination = try safeURL(Paths.game, file.path)
                let staged = try safeURL(staging, file.path)
                try engine.mkdir(staged.deletingLastPathComponent())
                try fm.copyItem(at: payloadURL(file, in: payload), to: staged)
                guard try engine.hash(staged) == file.hash else { throw PatchError("La copia preparada no coincide: \(file.path)") }
                var originalHash: String?; var mode: Int?
                if engine.exists(destination) {
                    let attributes = try fm.attributesOfItem(atPath: destination.path)
                    guard attributes[.type] as? FileAttributeType == .typeRegular else { throw PatchError("El destino no es un archivo regular: \(file.path)") }
                    originalHash = try engine.hash(destination)
                    mode = attributes[.posixPermissions] as? Int
                    let saved = try safeURL(backup.appendingPathComponent("original"), file.path)
                    try engine.mkdir(saved.deletingLastPathComponent()); try fm.copyItem(at: destination, to: saved)
                    guard try engine.hash(saved) == originalHash else { throw PatchError("Falló la verificación del respaldo: \(file.path)") }
                }
                var parent = destination.deletingLastPathComponent()
                while parent.path != Paths.game.path && !engine.exists(parent) {
                    created.insert(String(parent.path.dropFirst(Paths.game.path.count + 1)))
                    parent.deleteLastPathComponent()
                }
                state.files.append(ModInstalledFile(path: file.path, installedHash: file.hash, originalHash: originalHash, originalMode: mode))
                if index % 50 == 0 { engine.progress(0.2 + Double(index) / Double(recipe.files.count) * 0.5) }
            }
            if !engine.exists(Paths.game.appendingPathComponent("Crimson/configs")) { created.insert("Crimson/configs") }
            state.createdDirectories = created.sorted { $0.count > $1.count }
            state.saveBackupPaths = try backupSaves(to: backup)
            state.deployment = "game-files-only-v1"
            try assertCollectionClosed(); try engine.checkCancel()
            // Recheck all overwritten files immediately before committing the journal.
            for file in state.files {
                let destination = try safeURL(Paths.game, file.path)
                if let original = file.originalHash { guard try engine.hash(destination) == original else { throw PatchError("El juego cambió durante el respaldo: \(file.path)") } }
                else { guard !engine.exists(destination) else { throw PatchError("Apareció un archivo nuevo: \(file.path)") } }
            }
            try saveJournal(state, backup: backup)
            do {
                engine.log("Instalando Crimson completo y su compatibilidad con la edición de 2026…")
                for directory in state.createdDirectories.reversed() { try engine.mkdir(safeURL(Paths.game, directory)) }
                for (index, file) in state.files.enumerated() {
                    let destination = try safeURL(Paths.game, file.path)
                    let staged = try safeURL(staging, file.path)
                    try engine.mkdir(destination.deletingLastPathComponent())
                    guard rename(staged.path, destination.path) == 0 else { throw PatchError("No se pudo instalar \(file.path): \(String(cString: strerror(errno)))") }
                    if file.path.hasSuffix(".exe") { try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path) }
                    if index % 50 == 0 { engine.progress(0.7 + Double(index) / Double(state.files.count) * 0.25) }
                }
                state.status = "installed"; try saveJournal(state, backup: backup)
                engine.progress(1)
                engine.log("Crimson \(state.version) instalado. El parche de video se conserva. Probalo desde Steam de Windows dentro de CrossOver.\nRespaldo: \(backup.path)")
            } catch {
                engine.log("La instalación falló. Recuperando los archivos previos…")
                do { try restore(state, backup: backup) }
                catch { throw PatchError("La recuperación quedó pendiente. Conservá los respaldos y usá Quitar Crimson. \(error.localizedDescription)") }
                throw error
            }
        }
    }
    func restore(_ state: ModInstallation, backup: URL) throws {
        for file in state.files {
            let destination = try safeURL(Paths.game, file.path)
            if let original = file.originalHash {
                guard try engine.hash(safeURL(backup.appendingPathComponent("original"), file.originalPath ?? file.path)) == original else { throw PatchError("El respaldo cambió: \(file.path)") }
            }
            if engine.exists(destination) {
                let current = try engine.hash(destination)
                guard current == file.installedHash || current == file.originalHash else {
                    throw PatchError("\(file.path) cambió después de instalar. No se sobrescribieron esos cambios.")
                }
            }
        }
        var journal = state; journal.status = "removing"; try saveJournal(journal, backup: backup)
        for file in state.files {
            let destination = try safeURL(Paths.game, file.path)
            if let original = file.originalHash {
                if engine.exists(destination), try engine.hash(destination) == original { continue }
                try engine.mkdir(destination.deletingLastPathComponent())
                let saved = try safeURL(backup.appendingPathComponent("original"), file.originalPath ?? file.path)
                try Data(contentsOf: saved).write(to: destination, options: .atomic)
                if let mode = file.originalMode { try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: destination.path) }
            } else if engine.exists(destination) { try fm.removeItem(at: destination) }
        }
        for directory in state.createdDirectories {
            let url = try safeURL(Paths.game, directory)
            if engine.exists(url), (try fm.contentsOfDirectory(atPath: url.path)).isEmpty { try fm.removeItem(at: url) }
        }
        journal.status = "removed"; try engine.write(journal, backup.appendingPathComponent("manifest.json"))
        if engine.exists(Paths.modState) { try fm.removeItem(at: Paths.modState) }
    }
    func uninstall() throws {
        try engine.withLock {
            try validateLayout(); try assertCollectionClosed()
            guard engine.exists(Paths.modState) else { throw PatchError("Crimson no está instalado desde esta app.") }
            let state = try loadState()
            let backup = try safeURL(CrimsonPaths.backups, state.id)
            if state.status == "updating" { try recoverGameUpgrade(state, backup: backup); return }
            try restore(state, backup: backup)
            engine.progress(1)
            engine.log("Crimson quitado. Se restauraron el ejecutable y el launcher previos. La API compartida de Steam, los videos corregidos y los archivos de configuración creados al jugar se conservan.")
        }
    }
}
