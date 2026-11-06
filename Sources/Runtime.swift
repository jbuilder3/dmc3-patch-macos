import Foundation

struct RuntimeReport: Codable {
    var schema = 1
    var checkedAt: Date
    var gamePath: String
    var verifiedFiles: Int
    var verifiedVideos: Int
    var verifiedModFiles: Int
    var configurationFiles: Int
    var projectLinks = 0
    var requiresPatchAppToPlay = false
    var validation = "Archivos y configuración; sin iniciar el juego"
}

extension Engine {
    /// Installed game files are independent copies; the project holds recovery.
    @discardableResult
    func verifyRuntime() throws -> RuntimeReport {
        try withLock {
            var expected: [String: String] = [:]
            var videos = 0
            var modFiles = 0
            let mod = CrimsonInstaller(engine: self)
            if exists(Paths.state) {
                let state = try read(Paths.state, as: Manifest.self)
                guard state.schema == 1, state.gamePath == Paths.game.path, state.status == "active",
                      state.profile == "compatible" || state.profile == "original", !state.videos.isEmpty else {
                    throw PatchError("El parche de video tiene una operación pendiente. Revisá su registro antes de comprobar la instalación.")
                }
                let inspection = try inspectVideoPatch()
                if inspection.state == .originalsRestored {
                    throw PatchError("Los videos originales están presentes. El parche de video no está instalado. Usá Instalar en Resumen.")
                }
                for video in state.videos {
                    guard !video.output.isEmpty, !video.output.contains("/"), !video.output.contains("\\"),
                          video.output != ".", video.output != "..", video.outputHash.count == 64 else {
                        throw PatchError("Registro de video inválido.")
                    }
                    let path = "data/dmc3/Video/" + video.output
                    guard expected[path] == nil else { throw PatchError("Video duplicado en el registro.") }
                    expected[path] = video.outputHash
                }
                videos = state.videos.count
            }
            if exists(Paths.modState) {
                let state = try mod.loadState()
                guard state.status == "installed", !state.files.isEmpty else {
                    throw PatchError("Crimson tiene una recuperación pendiente. Revisá su instalación.")
                }
                for file in state.files {
                    guard file.installedHash.count == 64, expected[file.path] == nil else {
                        throw PatchError("Registro de Crimson inválido.")
                    }
                    expected[file.path] = file.installedHash
                }
                modFiles = state.files.count

            }
            guard !expected.isEmpty else { throw PatchError("No hay una instalación registrada para comprobar. Aplicá el parche o instalá Crimson primero.") }
            log("Comprobando las copias instaladas dentro del juego…")
            for (index, entry) in expected.sorted(by: { $0.key < $1.key }).enumerated() {
                try checkCancel()
                let file = try mod.safeURL(Paths.game, entry.key)
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      try hash(file) == entry.value else {
                    throw PatchError("El archivo instalado cambió o depende de un enlace: \(entry.key)")
                }
                if index % 20 == 0 { progress(Double(index + 1) / Double(expected.count) * 0.9) }
            }
            var configs = try regularFiles(Paths.game).filter { $0.pathExtension.lowercased() == "ini" }
            let configDirectory = Paths.game.appendingPathComponent("Crimson/configs", isDirectory: true)
            if exists(configDirectory) {
                guard configDirectory.resolvingSymlinksInPath().path == configDirectory.path else {
                    throw PatchError("La configuración de Crimson usa un enlace externo.")
                }
                configs += try regularFiles(configDirectory).filter { ["json", "ini"].contains($0.pathExtension.lowercased()) }
            }
            let references = [Paths.assets.path.lowercased(), Paths.project.path.lowercased(), Paths.project.path.replacingOccurrences(of: "/", with: "\\").lowercased(), "dmc3 patch.app"]
            for config in configs {
                let value = try String(contentsOf: config, encoding: .utf8)
                    .replacingOccurrences(of: "\\/", with: "/").replacingOccurrences(of: "\\\\", with: "\\").lowercased()
                guard !references.contains(where: { value.contains($0) }) else {
                    throw PatchError("\(config.lastPathComponent) contiene una ruta al proyecto. Revisá esa configuración.")
                }
            }
            let report = RuntimeReport(checkedAt: Date(), gamePath: Paths.game.path, verifiedFiles: expected.count,
                                       verifiedVideos: videos, verifiedModFiles: modFiles, configurationFiles: configs.count)
            try mkdir(Paths.project.appendingPathComponent("reports"))
            try write(report, Paths.project.appendingPathComponent("reports/instalacion-independiente.json"))
            progress(1)
            log("Instalación independiente comprobada: \(videos) videos y \(modFiles) archivos de Crimson son copias completas dentro del juego.\nPodés cerrar o quitar DMC3 Patch y jugar desde Steam con CrossOver. Conservá los respaldos del proyecto para restaurar o reinstalar.\nVerificación de archivos y configuración; no se inició el juego.")
            return report
        }
    }
}
