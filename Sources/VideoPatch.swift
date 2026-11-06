import Foundation

enum VideoPatchState: String, Codable {
    case notInstalled, installed, originalsRestored, partial, changed, pending, untracked
}
struct VideoPatchReport: Codable {
    var gamePath: String
    var state: VideoPatchState
    var total: Int
    var patched: Int
    var originals: Int
    var missing: [String]
    var changed: [String]
    var hasRecord: Bool
    var legacyExecutablePatch: Bool
    var checkedAt: Date

    var title: String {
        switch state {
        case .installed: return "Parche de video instalado"
        case .notInstalled, .originalsRestored: return "Parche de video no instalado"
        case .partial: return "Parche de video incompleto"
        case .changed: return "Videos con cambios por revisar"
        case .pending: return "Recuperación del parche pendiente"
        case .untracked: return "Videos compatibles sin respaldo registrado"
        }
    }
    var detail: String {
        switch state {
        case .installed: return "\(patched) videos parcheados y verificados."
        case .notInstalled: return "\(originals) videos originales detectados. Instalar preparará y aplicará el parche."
        case .originalsRestored: return "\(originals) videos originales verificados. El registro anterior estaba desactualizado; los respaldos se conservan."
        case .partial: return "\(patched) videos parcheados y \(originals) originales. Remover recupera los originales antes de reinstalar."
        case .changed: return "Se detectaron archivos distintos o faltantes. Revisá el registro antes de reemplazarlos."
        case .pending: return "Usá Remover para recuperar el estado anterior."
        case .untracked: return "Se detectó una conversión previa sin registro de esta app. No se pueden recuperar los originales desde esta instalación."
        }
    }
    var canInstall: Bool { state == .notInstalled || state == .originalsRestored }
    var canRemove: Bool { hasRecord && state != .originalsRestored }
}

extension Engine {
    @discardableResult
    func analyzeVideoPatch() throws -> VideoPatchReport {
        try withLock {
            let report = try inspectVideoPatch()
            try mkdir(Paths.project.appendingPathComponent("reports"))
            try write(report, Paths.project.appendingPathComponent("reports/video-analysis.json"))
            log(report.title + "\n" + report.detail)
            if !report.changed.isEmpty { log("Archivos por revisar: " + report.changed.joined(separator: ", ")) }
            if !report.missing.isEmpty { log("Archivos faltantes: " + report.missing.joined(separator: ", ")) }
            return report
        }
    }
    func inspectVideoPatch() throws -> VideoPatchReport {
        var report = VideoPatchReport(gamePath: Paths.game.path, state: .notInstalled, total: 0, patched: 0,
                                      originals: 0, missing: [], changed: [], hasRecord: exists(Paths.state), legacyExecutablePatch: false, checkedAt: Date())
        if !report.hasRecord {
            let current = try webms(Paths.video)
            let files = try current.isEmpty ? webms(Paths.legacy) : current
            guard !files.isEmpty else { throw PatchError("No hay videos originales WebM en Video ni en Video_bak.") }
            for file in files {
                let handle = try FileHandle(forReadingFrom: file)
                let header = try handle.read(upToCount: 12) ?? Data(); try handle.close()
                if header.count >= 8, header.subdata(in: 4..<8) == Data("ftyp".utf8) { report.patched += 1 }
                else if header.starts(with: [0x1a, 0x45, 0xdf, 0xa3]) { report.originals += 1 }
                else { report.changed.append(file.lastPathComponent) }
            }
            report.total = files.count
            report.state = !report.changed.isEmpty ? .changed : report.patched > 0 ? .untracked : .notInstalled
            return report
        }
        let manifest = try read(Paths.state, as: Manifest.self)
        guard manifest.schema == 1, manifest.gamePath == Paths.game.path, !manifest.videos.isEmpty,
              !manifest.id.isEmpty, !manifest.id.contains("/"), !manifest.id.contains("..") else { throw PatchError("Registro de restauración inválido.") }
        let actual = Dictionary(uniqueKeysWithValues: try records(Paths.video).map { ($0.name, $0.hash) })
        let originalRecords = manifest.originalVideoFiles ?? []
        guard Set(originalRecords.map(\.name)).count == originalRecords.count else { throw PatchError("Registro de restauración inválido.") }
        let original = Dictionary(uniqueKeysWithValues: originalRecords.map { ($0.name, $0.hash) })
        report.total = manifest.videos.count; report.legacyExecutablePatch = manifest.patchedExeHash != nil
        let expected = Set(manifest.videos.map(\.output))
        guard expected.count == manifest.videos.count else { throw PatchError("Video duplicado en el registro.") }
        for video in manifest.videos {
            guard !video.output.isEmpty, !video.output.contains("/"), !video.output.contains("\\"),
                  video.output != ".", video.output != "..", video.outputHash.count == 64, video.sourceHash.count == 64 else {
                throw PatchError("Registro de video inválido.")
            }
            if actual[video.output] == video.outputHash { report.patched += 1 }
            else if actual[video.output] == video.sourceHash || actual[video.output] == original[video.output] && actual[video.output] != nil { report.originals += 1 }
            else if actual[video.output] == nil { report.missing.append(video.output) }
            else { report.changed.append(video.output) }
        }
        report.changed += actual.keys.filter { !expected.contains($0) && actual[$0] != original[$0] }.sorted()
        if manifest.status != "active" { report.state = .pending }
        else if manifest.originalVideoExisted == true && !original.isEmpty && actual == original && manifest.profile != "original" {
            report.state = .originalsRestored; report.patched = 0; report.missing = []; report.changed = []
        } else if report.patched == report.total && report.changed.isEmpty { report.state = .installed }
        else if !report.changed.isEmpty || !report.missing.isEmpty { report.state = .changed }
        else { report.state = .partial }
        return report
    }
    func installVideoPatch() throws {
        try validatePaths(); try assertGameClosed()
        let report = try analyzeVideoPatch()
        if report.state == .installed { log("El parche de video ya está instalado. No se modificaron archivos."); return }
        guard report.canInstall else { throw PatchError("Revisá el análisis y usá Remover para recuperar los originales antes de reinstalar.") }
        if report.state == .originalsRestored { try restore() }
        if let latest = try? latestRun(), let manifest = try? read(latest.appendingPathComponent("manifest.json"), as: Manifest.self),
           manifest.status == "ready", manifest.gamePath == Paths.game.path, manifest.profile == "compatible", !manifest.flipped {
            log("Usando la preparación de video verificada.")
        } else { _ = try prepare() }
        try apply()
    }
}
