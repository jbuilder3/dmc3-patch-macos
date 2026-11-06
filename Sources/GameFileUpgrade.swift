import Foundation
import Darwin

private struct GameUpgrade: Codable {
    var previous: ModInstallation
    var paths: [String]
    var snapshot: String
}

extension CrimsonInstaller {
    func recoverGameUpgrade(_ current: ModInstallation, backup: URL) throws {
        let pending = backup.appendingPathComponent("pending-update.json")
        let update = try engine.read(pending, as: GameUpgrade.self)
        guard update.previous.id == current.id, update.previous.gamePath == Paths.game.path,
              !update.snapshot.contains("/"), !update.snapshot.contains("..") else { throw PatchError("Registro de actualización inválido.") }
        let old = Dictionary(uniqueKeysWithValues: update.previous.files.map { ($0.path, $0) })
        let newer = Dictionary(uniqueKeysWithValues: current.files.map { ($0.path, $0) })
        let snapshots = backup.appendingPathComponent("updates/" + update.snapshot)
        for path in update.paths {
            guard allowed(path) else { throw PatchError("Ruta ajena a la actualización.") }
            let destination = try safeURL(Paths.game, path)
            if engine.exists(destination) {
                let hash = try engine.hash(destination)
                guard hash == old[path]?.installedHash || hash == newer[path]?.installedHash || hash == old[path]?.originalHash else {
                    throw PatchError("\(path) recibió cambios posteriores. Se conservaron.")
                }
            }
            if let previous = old[path] {
                guard try engine.hash(safeURL(snapshots, path)) == previous.installedHash else { throw PatchError("El respaldo de actualización no coincide.") }
            }
        }
        for path in update.paths {
            let destination = try safeURL(Paths.game, path)
            if old[path] != nil {
                try Data(contentsOf: safeURL(snapshots, path)).write(to: destination, options: .atomic)
                if path.hasSuffix(".exe") { try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path) }
            } else if engine.exists(destination) { try fm.removeItem(at: destination) }
        }
        try saveJournal(update.previous, backup: backup)
        try fm.removeItem(at: pending)
    }
    func updateGameFiles() throws {
        try engine.withLock {
            try validateLayout(); try assertCollectionClosed()
            let previous = try loadState()
            let backup = try safeURL(CrimsonPaths.backups, previous.id)
            if previous.status == "updating" { try recoverGameUpgrade(previous, backup: backup); engine.log("Actualización anterior recuperada. Podés repetirla."); return }
            guard previous.status == "installed" else { throw PatchError("Recuperá la instalación pendiente antes de actualizar.") }
            let recipe = try loadRecipe()
            let old = Dictionary(uniqueKeysWithValues: previous.files.map { ($0.path, $0) })
            let target = Dictionary(uniqueKeysWithValues: recipe.files.map { ($0.path, $0) })
            for file in previous.files {
                guard try engine.hash(safeURL(Paths.game, file.path)) == file.installedHash else { throw PatchError("Cambió \(file.path). La actualización se detuvo para conservar tus cambios.") }
            }
            for file in recipe.files where old[file.path] == nil {
                guard !engine.exists(try safeURL(Paths.game, file.path)) else { throw PatchError("Ya existe un archivo ajeno al mod: \(file.path)") }
            }
            let paths = Set(previous.files.map(\.path) + recipe.files.map(\.path)).filter { old[$0]?.installedHash != target[$0]?.hash }.sorted()
            guard !paths.isEmpty || previous.deployment != "game-files-only-v1" else { engine.log("Los archivos locales del mod ya están actualizados."); return }
            var originals: [String: URL] = [:]
            if !CrimsonPaths.hasBundledInstaller {
                let saved = backup.appendingPathComponent("original", isDirectory: true)
                for base in recipe.baseFiles {
                    let name = try baseURL(base.path).lastPathComponent
                    if let file = old[name], file.originalHash != nil {
                        originals[base.path] = try safeURL(saved, file.originalPath ?? file.path)
                    }
                }
            }
            let payload = try unpackPayload(recipe, originals: originals)
            defer { releasePayload(payload) }
            try verifyPayload(recipe, in: payload)
            let id = UUID().uuidString; let snapshots = backup.appendingPathComponent("updates/" + id)
            let staging = Paths.game.appendingPathComponent(".dmc3-update-" + id)
            try engine.mkdir(snapshots)
            try engine.write(previous, snapshots.appendingPathComponent("previous-installation.json"))
            try engine.mkdir(staging); defer { try? fm.removeItem(at: staging) }
            for path in paths {
                if old[path] != nil {
                    let saved = try safeURL(snapshots, path); try engine.mkdir(saved.deletingLastPathComponent())
                    try fm.copyItem(at: safeURL(Paths.game, path), to: saved)
                    guard try engine.hash(saved) == old[path]?.installedHash else { throw PatchError("Falló el respaldo de actualización.") }
                }
                if let file = target[path] {
                    let staged = try safeURL(staging, path); try engine.mkdir(staged.deletingLastPathComponent())
                    try fm.copyItem(at: payloadURL(file, in: payload), to: staged)
                    guard try engine.hash(staged) == file.hash else { throw PatchError("La copia preparada no coincide.") }
                } else if let original = old[path]?.originalHash {
                    let saved = try safeURL(backup.appendingPathComponent("original"), old[path]?.originalPath ?? path)
                    guard try engine.hash(saved) == original else { throw PatchError("El respaldo original no coincide.") }
                    let staged = try safeURL(staging, path); try engine.mkdir(staged.deletingLastPathComponent()); try fm.copyItem(at: saved, to: staged)
                }
            }
            var next = previous; next.status = "updating"; next.prefixPath = ""; next.registryValues = []; next.deployment = "game-files-only-v1"
            next.files = recipe.files.map { file in ModInstalledFile(path: file.path, installedHash: file.hash, originalHash: old[file.path]?.originalHash, originalMode: old[file.path]?.originalMode, originalPath: old[file.path]?.originalPath) }
            try assertCollectionClosed(); try engine.checkCancel()
            try engine.write(GameUpgrade(previous: previous, paths: paths, snapshot: id), backup.appendingPathComponent("pending-update.json"))
            try saveJournal(next, backup: backup)
            do {
                for path in paths {
                    let staged = try safeURL(staging, path); let destination = try safeURL(Paths.game, path)
                    if engine.exists(staged) {
                        guard rename(staged.path, destination.path) == 0 else { throw PatchError("No se pudo actualizar \(path)") }
                        if path.hasSuffix(".exe") { try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path) }
                    } else if engine.exists(destination) { try fm.removeItem(at: destination) }
                }
                next.status = "installed"; try saveJournal(next, backup: backup)
                try fm.removeItem(at: backup.appendingPathComponent("pending-update.json"))
                engine.log("Crimson actualizado usando solo archivos del juego. Las partidas y los ajustes externos se conservaron.")
            } catch {
                try recoverGameUpgrade(next, backup: backup); throw error
            }
        }
    }
}
