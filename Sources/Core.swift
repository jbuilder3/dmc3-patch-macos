import Foundation
import CryptoKit
import Darwin

enum Paths {
    #if TESTING || MOD_TESTING
    private static let testRoot = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DMC3_PATCH_TEST_ROOT"] ?? FileManager.default.currentDirectoryPath)
    #if MOD_TESTING
    static let project = testRoot.appendingPathComponent("tests/mod-fixture/project", isDirectory: true)
    static let game = testRoot.appendingPathComponent("tests/mod-fixture/game", isDirectory: true)
    #else
    static let project = testRoot.appendingPathComponent("tests/fixture/project", isDirectory: true)
    static let game = testRoot.appendingPathComponent("tests/fixture/game", isDirectory: true)
    #endif
    static var assets: URL { project }
    #else
    // Immutable files travel with the application. User data is independent of
    // the bundle location so moving or updating the app preserves recovery.
    static let assets = Bundle.main.resourceURL!.appendingPathComponent("Project", isDirectory: true)
    static let project = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DMC3 Patch", isDirectory: true)
    static var game: URL { SelectionStore.shared.selected.map { URL(fileURLWithPath: $0.gamePath, isDirectory: true) } ?? project.appendingPathComponent(".no-game-selected") }
    #endif
    static func prepareData() throws {
        guard project.standardizedFileURL.path == project.resolvingSymlinksInPath().standardizedFileURL.path else {
            throw NSError(domain: "DMC3Patch", code: 1, userInfo: [NSLocalizedDescriptionKey: "La carpeta de datos de DMC3 Patch está redirigida mediante un enlace."])
        }
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".build/tmp"), withIntermediateDirectories: true)
    }
    static var hasSelection: Bool {
        #if TESTING || MOD_TESTING
        return true
        #else
        return SelectionStore.shared.selected != nil
        #endif
    }
    static var dataRoot: URL {
        #if TESTING || MOD_TESTING
        return project
        #else
        return SelectionStore.shared.dataRoot
        #endif
    }
    static var video: URL { game.appendingPathComponent("data/dmc3/Video", isDirectory: true) }
    static var legacy: URL { game.appendingPathComponent("data/dmc3/Video_bak", isDirectory: true) }
    static var exe: URL {
        (try? GameFolder.executable(in: game, preferred: SelectionStore.shared.selected?.executableName)) ?? game.appendingPathComponent("dmc3.exe")
    }
    static var runs: URL { dataRoot.appendingPathComponent("runs", isDirectory: true) }
    static var state: URL { dataRoot.appendingPathComponent("active-patch.json") }
    static var latest: URL { dataRoot.appendingPathComponent("latest-prepared.txt") }
    static var modState: URL { dataRoot.appendingPathComponent("mods/crimson/installed.json") }
    static var ffmpeg: URL { assets.appendingPathComponent("tools/bin/ffmpeg") }
    static var ffprobe: URL { assets.appendingPathComponent("tools/bin/ffprobe") }
}

struct PatchError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = L10n.text(message) }
    var errorDescription: String? { message }
}

struct FileRecord: Codable {
    var name: String
    var hash: String
}

struct VideoRecord: Codable {
    var source: String
    var sourceHash: String
    var output: String
    var outputHash: String
    var duration: Double
    var width: Int
    var height: Int
    var frames: Int
}

struct Manifest: Codable {
    var schema = 1
    var id: String
    var profile: String
    var flipped: Bool
    var status: String
    var gamePath: String
    var sourceDirectory: String
    var originalExeHash: String
    var patchedExeHash: String?
    var originalVideoExisted: Bool?
    var originalVideoFiles: [FileRecord]?
    var videos: [VideoRecord]
    var runtimeValidated = false
}

struct Media {
    var duration: Double
    var width: Int
    var height: Int
    var videoCodec: String
    var audioCodecs: [String]
    var frames: Int
    var frameRate: Double
}

final class Engine: @unchecked Sendable {
    let fm = FileManager.default
    var log: (String) -> Void = { print($0) }
    var progress: (Double) -> Void = { _ in }
    private let mutex = NSLock()
    private var child: Process?
    private var cancelled = false
    private var lockURL: URL { Paths.project.appendingPathComponent(".operation-lock") }

    func cancel() {
        mutex.lock(); cancelled = true; let p = child; mutex.unlock()
        if let p, p.isRunning { p.terminate() }
    }
    func checkCancel() throws {
        mutex.lock(); let stop = cancelled; mutex.unlock()
        if stop { throw PatchError("Operación cancelada. El juego conserva su estado anterior.") }
    }
    func reset() { mutex.lock(); cancelled = false; mutex.unlock() }

    func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }
    func mkdir(_ url: URL) throws { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
    func hash(_ url: URL) throws -> String {
        let stream = try FileHandle(forReadingFrom: url)
        defer { try? stream.close() }
        var sha = SHA256()
        while let data = try stream.read(upToCount: 1_048_576), !data.isEmpty { sha.update(data: data) }
        return sha.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func write<T: Encodable>(_ value: T, _ url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
    func read<T: Decodable>(_ url: URL, as: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
    func regularFiles(_ directory: URL) throws -> [URL] {
        guard exists(directory) else { return [] }
        return try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            .filter { url in
                let v = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if v.isSymbolicLink == true { throw PatchError("No se admiten enlaces simbólicos: \(url.path)") }
                return v.isRegularFile == true && !url.lastPathComponent.hasPrefix(".")
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    func webms(_ directory: URL) throws -> [URL] {
        try regularFiles(directory).filter { $0.pathExtension.lowercased() == "webm" }
    }
    func validatePaths() throws {
        guard Paths.hasSelection else { throw PatchError("Elegí la carpeta del juego en Resumen antes de continuar.") }
        for url in [Paths.assets, Paths.project, Paths.dataRoot, Paths.runs, Paths.state, Paths.latest, Paths.project.appendingPathComponent("reports"),
                    Paths.project.appendingPathComponent(".build"), Paths.project.appendingPathComponent(".build/tmp"),
                    Paths.game, Paths.exe, Paths.game.appendingPathComponent("data"), Paths.game.appendingPathComponent("data/dmc3"), Paths.video, Paths.legacy] {
            guard url.standardizedFileURL.path == url.resolvingSymlinksInPath().standardizedFileURL.path else {
                throw PatchError("Ruta redirigida fuera del alcance previsto: \(url.path)")
            }
        }
        guard exists(Paths.exe) else { throw PatchError("No se encontró dmc3.exe en la carpeta autorizada.") }
        guard Paths.ffmpeg.path.hasPrefix(Paths.assets.path + "/"), fm.isExecutableFile(atPath: Paths.ffmpeg.path),
              fm.isExecutableFile(atPath: Paths.ffprobe.path) else { throw PatchError("Faltan herramientas del paquete. Volvé a copiar la app completa.") }
    }
    func withLock<T>(_ body: () throws -> T) throws -> T {
        try validatePaths()
        do { try fm.createDirectory(at: lockURL, withIntermediateDirectories: false) }
        catch { throw PatchError("Hay otra operación activa. Si una ejecución anterior se cerró abruptamente, cerrá la app y revisá .operation-lock en los datos de DMC3 Patch.") }
        defer { try? fm.removeItem(at: lockURL) }
        return try body()
    }
    func processCommands() throws -> String {
        #if TESTING || MOD_TESTING
        let output = try run(URL(fileURLWithPath: "/bin/ps"), ["-axo", "ppid=,command="])
        return output.components(separatedBy: "\n").compactMap { line -> String? in
            let fields = line.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            return fields.count == 2 && fields[0] == String(getppid()) ? String(fields[1]) : nil
        }.joined(separator: "\n")
        #else
        return try run(URL(fileURLWithPath: "/bin/ps"), ["-axo", "command"])
        #endif
    }
    func assertGameClosed() throws {
        if GameFolder.commandIsGame(try processCommands(), collection: false) {
            throw PatchError("DMC3 está abierto. Cerralo antes de aplicar o restaurar.")
        }
    }
    @discardableResult
    func run(_ executable: URL, _ arguments: [String], line: ((String) -> Void)? = nil) throws -> String {
        try checkCancel()
        let p = Process(); p.executableURL = executable; p.arguments = arguments
        p.currentDirectoryURL = Paths.project
        var env = ProcessInfo.processInfo.environment
        env["TMPDIR"] = Paths.project.appendingPathComponent(".build/tmp").path
        env["AV_LOG_FORCE_NOCOLOR"] = "1"; p.environment = env
        let pipe = Pipe(); p.standardOutput = pipe
        let errorsURL = Paths.project.appendingPathComponent(".build/tmp/process-" + UUID().uuidString + ".log")
        try mkdir(errorsURL.deletingLastPathComponent())
        try Data().write(to: errorsURL)
        let errors = try FileHandle(forWritingTo: errorsURL)
        p.standardError = errors
        defer { try? errors.close(); try? fm.removeItem(at: errorsURL) }
        p.standardInput = FileHandle.nullDevice
        mutex.lock(); child = p; mutex.unlock()
        defer { mutex.lock(); child = nil; mutex.unlock() }
        try p.run()
        var result = Data(); var pending = ""
        while true {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            result.append(data)
            if let line {
                pending += String(decoding: data, as: UTF8.self)
                while let end = pending.firstIndex(of: "\n") {
                    line(String(pending[..<end])); pending.removeSubrange(...end)
                }
            }
        }
        p.waitUntilExit(); try errors.synchronize(); try checkCancel()
        let text = String(decoding: result, as: UTF8.self)
        let errorText = String(decoding: try Data(contentsOf: errorsURL), as: UTF8.self)
        guard p.terminationStatus == 0 else { throw PatchError("\(executable.lastPathComponent) terminó con error \(p.terminationStatus):\n\((errorText + text).suffix(5000))") }
        if !errorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log("Aviso de \(executable.lastPathComponent): \(errorText.suffix(2000))")
        }
        return text
    }
    func probe(_ file: URL, count: Bool = false) throws -> Media {
        var args = ["-v", "error", "-threads", "4", "-show_format", "-show_streams", "-of", "json"]
        if count { args += ["-count_frames"] }
        args += [file.path]
        let text = try run(Paths.ffprobe, args)
        guard let dict = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let streams = dict["streams"] as? [[String: Any]],
              let video = streams.first(where: { $0["codec_type"] as? String == "video" }),
              let format = dict["format"] as? [String: Any] else { throw PatchError("No se pudo analizar \(file.lastPathComponent).") }
        let duration = Double(format["duration"] as? String ?? "") ?? 0
        let rate = (video["avg_frame_rate"] as? String ?? "0/1").split(separator: "/").compactMap { Double($0) }
        let fps = rate.count == 2 && rate[1] != 0 ? rate[0] / rate[1] : 0
        let audio = streams.filter { $0["codec_type"] as? String == "audio" }.compactMap { $0["codec_name"] as? String }
        guard duration > 0 else { throw PatchError("Duración inválida en \(file.lastPathComponent).") }
        return Media(duration: duration, width: video["width"] as? Int ?? 0, height: video["height"] as? Int ?? 0,
                     videoCodec: video["codec_name"] as? String ?? "?", audioCodecs: audio,
                     frames: Int(video["nb_read_frames"] as? String ?? "") ?? 0, frameRate: fps)
    }
    func sourceDirectory() throws -> URL {
        if !(try webms(Paths.legacy)).isEmpty { return Paths.legacy }
        if !(try webms(Paths.video)).isEmpty { return Paths.video }
        throw PatchError("No hay videos originales WebM en Video ni en Video_bak.")
    }
    func diagnose() throws -> String {
        try withLock {
            let source = try sourceDirectory(); let files = try webms(source)
            let first = try probe(files[0]); let exeHash = try hash(Paths.exe)
            let inspection = try inspectVideoPatch()
            let text = """
            DMC3 PATCH · Diagnóstico
            Juego: \(Paths.game.path)
            Carpeta Video: \(exists(Paths.video) ? "presente" : "FALTA")
            Originales: \(files.count) videos en \(source.lastPathComponent)
            Muestra: \(first.videoCodec) / \(first.audioCodecs.joined(separator: ", ")) · \(first.width)×\(first.height)
            Ejecutable \(Paths.exe.lastPathComponent) SHA-256: \(exeHash)
            Estado del parche: \(inspection.title)
            Detalle: \(inspection.detail)
            Modo: archivos de la carpeta elegida
            Prueba en el juego: a cargo del usuario
            """
            try mkdir(Paths.project.appendingPathComponent("reports"))
            try text.write(to: Paths.project.appendingPathComponent("reports/diagnostico.txt"), atomically: true, encoding: .utf8)
            log(text); return text
        }
    }
    @discardableResult
    func prepare(profile: String = "compatible", flipped: Bool = false, limit: Int? = nil) throws -> URL {
        try withLock {
            guard !exists(Paths.state) else { throw PatchError("Restaurá el parche activo antes de preparar otro.") }
            guard profile == "compatible" || profile == "original" else { throw PatchError("Perfil desconocido o retirado. El perfil MP4 anterior alteraba el ejecutable y ya no se admite.") }
            let source = try sourceDirectory(); let allFiles = try webms(source)
            let files = limit.map { Array(allFiles.prefix($0)) } ?? allFiles
            guard !files.isEmpty else { throw PatchError("No hay videos para preparar.") }
            let id = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") + "-" + UUID().uuidString.prefix(8)
            let runURL = Paths.runs.appendingPathComponent(id, isDirectory: true)
            let output = runURL.appendingPathComponent("Video", isDirectory: true)
            try mkdir(output)
            let original = try Data(contentsOf: Paths.exe)
            try original.write(to: runURL.appendingPathComponent("original-dmc3.exe"), options: .atomic)
            var manifest = Manifest(id: id, profile: profile, flipped: flipped, status: "preparing", gamePath: Paths.game.path,
                                    sourceDirectory: source.path, originalExeHash: try hash(Paths.exe), videos: [])
            let manifestURL = runURL.appendingPathComponent("manifest.json")
            try write(manifest, manifestURL)
            log("Preparando \(files.count) videos. El juego todavía no cambia.")
            for (index, file) in files.enumerated() {
                try checkCancel()
                let info = try probe(file)
                let sourceHash = try hash(file)
                // Media Foundation/GStreamer detects the MP4 container from its contents.
                // Keep the original names so Steam's protected executable stays intact.
                let name = file.lastPathComponent
                let destination = output.appendingPathComponent(name)
                log("\(index + 1)/\(files.count) · \(file.lastPathComponent)")
                if profile == "original" { try fm.copyItem(at: file, to: destination) }
                else {
                    let partial = output.appendingPathComponent(name + ".partial")
                    var args = ["-hide_banner", "-v", "error", "-nostdin", "-n", "-threads", "4", "-i", file.path, "-map", "0:v:0", "-map", "0:a?",
                                "-map_metadata", "-1", "-c:v", "h264_videotoolbox", "-allow_sw", "1", "-b:v", "6000k", "-profile:v", "high", "-pix_fmt", flipped ? "nv12" : "yuv420p",
                                "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart"]
                    // vflip exposes negative row strides. Materialize a native
                    // NV12 buffer before VideoToolbox consumes the flipped frame.
                    if flipped { args += ["-vf", "vflip,format=nv12"] }
                    args += ["-progress", "pipe:1", "-nostats", "-f", "mp4", partial.path]
                    try run(Paths.ffmpeg, args) { line in
                        if line.hasPrefix("out_time_us="), let value = Double(line.dropFirst(12)), value >= 0 {
                            self.progress((Double(index) + min(value / 1_000_000 / info.duration, 0.99)) / Double(files.count))
                        }
                    }
                    try fm.moveItem(at: partial, to: destination)
                }
                let converted = try probe(destination, count: true)
                guard converted.width == info.width, converted.height == info.height,
                      abs(converted.duration - info.duration) < max(0.3, info.frameRate > 0 ? 3 / info.frameRate : 0.3),
                      converted.audioCodecs.count == info.audioCodecs.count, converted.frames > 0 else {
                    throw PatchError("La validación de duración, imagen o audio falló: \(name)")
                }
                if profile == "compatible", converted.videoCodec != "h264" || converted.audioCodecs.contains(where: { $0 != "aac" }) {
                    throw PatchError("Códecs inesperados en \(name).")
                }
                guard try hash(file) == sourceHash else { throw PatchError("El original cambió durante la preparación: \(file.lastPathComponent)") }
                manifest.videos.append(VideoRecord(source: file.lastPathComponent, sourceHash: sourceHash, output: name,
                                                    outputHash: try hash(destination), duration: converted.duration,
                                                    width: converted.width, height: converted.height, frames: converted.frames))
                try write(manifest, manifestURL); progress(Double(index + 1) / Double(files.count))
            }
            manifest.status = files.count == allFiles.count ? "ready" : "sample"
            try write(manifest, manifestURL)
            if manifest.status == "ready" { try id.write(to: Paths.latest, atomically: true, encoding: .utf8) }
            log(manifest.status == "ready" ? "Preparación verificada. Lista para aplicar; prueba en CrossOver pendiente." : "Muestra verificada. No se puede aplicar una preparación incompleta.")
            return runURL
        }
    }
    func latestRun() throws -> URL {
        guard exists(Paths.latest) else { throw PatchError("No hay una preparación lista. Usá Preparar antes de aplicar.") }
        let id = try String(contentsOf: Paths.latest, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !id.contains("/"), !id.contains("..") else { throw PatchError("Identificador de preparación inválido.") }
        let url = Paths.runs.appendingPathComponent(id, isDirectory: true)
        guard url.path == url.resolvingSymlinksInPath().path else { throw PatchError("La preparación está redirigida mediante un enlace simbólico.") }
        return url
    }
    func records(_ directory: URL) throws -> [FileRecord] {
        guard exists(directory) else { return [] }
        guard let tree = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]) else {
            throw PatchError("No se pudo leer la carpeta: \(directory.path)")
        }
        var result: [FileRecord] = []
        for case let url as URL in tree {
            if url.lastPathComponent == ".DS_Store" { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw PatchError("No se admiten enlaces simbólicos: \(url.path)") }
            let name = String(url.path.dropFirst(directory.path.count + 1))
            if values.isDirectory == true { result.append(FileRecord(name: name + "/", hash: "directory")) }
            else if values.isRegularFile == true { result.append(FileRecord(name: name, hash: try hash(url))) }
            else { throw PatchError("Tipo de archivo no admitido: \(url.path)") }
        }
        return result.sorted { $0.name < $1.name }
    }
    func verifyRecords(_ expected: [FileRecord], _ directory: URL) throws {
        let actual = try records(directory)
        let expectedMap = Dictionary(expected.map { ($0.name, $0.hash) }, uniquingKeysWith: { first, _ in first })
        guard expectedMap.count == expected.count, actual.count == expected.count,
              Dictionary(uniqueKeysWithValues: actual.map { ($0.name, $0.hash) }) == expectedMap else {
            throw PatchError("Los archivos cambiaron: \(directory.path). No se sobrescribió esa carpeta.")
        }
    }
    func apply() throws {
        try withLock {
            try assertGameClosed()
            guard !exists(Paths.state) else { throw PatchError("Ya existe un parche activo o una transacción pendiente.") }
            let runURL = try latestRun(); let manifestURL = runURL.appendingPathComponent("manifest.json")
            var manifest = try read(manifestURL, as: Manifest.self)
            guard manifest.schema == 1, manifest.status == "ready", manifest.gamePath == Paths.game.path else { throw PatchError("Preparación incompleta o de otra instalación.") }
            guard (manifest.profile == "compatible" || manifest.profile == "original"), manifest.patchedExeHash == nil else {
                throw PatchError("La preparación antigua que modificaba dmc3.exe fue retirada por errores de inicio de Steam. Prepará el perfil nuevo que conserva el ejecutable.")
            }
            guard try hash(runURL.appendingPathComponent("original-dmc3.exe")) == manifest.originalExeHash else { throw PatchError("El respaldo de dmc3.exe no coincide con su registro.") }
            let source = URL(fileURLWithPath: manifest.sourceDirectory)
            guard source == Paths.legacy || source == Paths.video else { throw PatchError("Origen fuera del alcance autorizado.") }
            let sourceFiles = try webms(source)
            guard sourceFiles.count == manifest.videos.count else { throw PatchError("Cambió la cantidad de originales.") }
            for video in manifest.videos {
                guard !video.source.contains("/"), !video.output.contains("/"),
                      try hash(source.appendingPathComponent(video.source)) == video.sourceHash else { throw PatchError("Cambió un video original. Prepará otra vez.") }
            }
            let expected = manifest.videos.map { FileRecord(name: $0.output, hash: $0.outputHash) }
            try verifyRecords(expected, runURL.appendingPathComponent("Video"))
            let originalVideo = runURL.appendingPathComponent("original-Video", isDirectory: true)
            manifest.originalVideoExisted = exists(Paths.video)
            if exists(Paths.video) {
                // Preserve the whole directory, including hidden files, in the project.
                try fm.copyItem(at: Paths.video, to: originalVideo)
                manifest.originalVideoFiles = try records(Paths.video)
                try verifyRecords(manifest.originalVideoFiles!, originalVideo)
            } else { manifest.originalVideoFiles = [] }
            let staging = Paths.game.appendingPathComponent("data/dmc3/.dmc3-patch-new", isDirectory: true)
            guard !exists(staging) else { throw PatchError("Existe una carpeta temporal de otra operación: \(staging.path)") }
            try fm.copyItem(at: runURL.appendingPathComponent("Video"), to: staging)
            defer { if exists(staging) { try? fm.removeItem(at: staging) } }
            try verifyRecords(expected, staging)
            try checkCancel()
            manifest.status = "applying"; try write(manifest, manifestURL); try write(manifest, Paths.state)
            // From here restoration is journaled; cancellation is deferred until after commit.
            do {
                if exists(Paths.video) { try fm.removeItem(at: Paths.video) }
                try fm.moveItem(at: staging, to: Paths.video)
                manifest.status = "active"; try write(manifest, manifestURL); try write(manifest, Paths.state)
                log("Parche aplicado a DMC3. Originales guardados en los datos de DMC3 Patch. Falta probar las cinemáticas en Steam/CrossOver.")
            } catch {
                log("La aplicación falló; recuperando el estado anterior…")
                do { try rollback(manifest, runURL: runURL, checkCurrent: false) }
                catch { throw PatchError("Recuperación pendiente. Conservá active-patch.json y runs. Detalle: \(error.localizedDescription)") }
                throw error
            }
        }
    }
    func rollback(_ manifest: Manifest, runURL: URL, checkCurrent: Bool) throws {
        let legacy = manifest.patchedExeHash != nil
        if legacy {
            guard try hash(runURL.appendingPathComponent("original-dmc3.exe")) == manifest.originalExeHash else { throw PatchError("El respaldo original de dmc3.exe cambió.") }
        }
        let originalVideo = runURL.appendingPathComponent("original-Video", isDirectory: true)
        if manifest.originalVideoExisted == true { try verifyRecords(manifest.originalVideoFiles ?? [], originalVideo) }
        let currentMap = Dictionary(uniqueKeysWithValues: try records(Paths.video).map { ($0.name, $0.hash) })
        let preparedMap = Dictionary(uniqueKeysWithValues: manifest.videos.map { ($0.output, $0.outputHash) })
        let originalMap = Dictionary(uniqueKeysWithValues: (manifest.originalVideoFiles ?? []).map { ($0.name, $0.hash) })
        if checkCurrent {
            if legacy {
                let currentExe = try hash(Paths.exe)
                guard currentExe == manifest.patchedExeHash || currentExe == manifest.originalExeHash else {
                    throw PatchError("Steam u otra herramienta cambió dmc3.exe. Se detuvo la restauración para conservar esos cambios.")
                }
            }
            // Known original, patched and missing entries can be recovered. Never
            // erase a file added or changed by the user after installation.
            guard currentMap.allSatisfy({ name, hash in hash == preparedMap[name] || hash == originalMap[name] }) else {
                throw PatchError("La carpeta Video tiene cambios ajenos al parche. No se sobrescribieron.")
            }
        }
        let originalsAlreadyPresent = manifest.originalVideoExisted == true && exists(Paths.video) && currentMap == originalMap
        if !originalsAlreadyPresent {
            let restore = Paths.game.appendingPathComponent("data/dmc3/.dmc3-patch-restore", isDirectory: true)
            if exists(restore) {
                guard manifest.originalVideoExisted == true else { throw PatchError("Carpeta temporal de restauración inesperada.") }
                try verifyRecords(manifest.originalVideoFiles ?? [], restore)
            } else if manifest.originalVideoExisted == true { try fm.copyItem(at: originalVideo, to: restore) }
            var journal = manifest; journal.status = "restoring"; try write(journal, Paths.state)
            if exists(Paths.video) { try fm.removeItem(at: Paths.video) }
            if manifest.originalVideoExisted == true { try fm.moveItem(at: restore, to: Paths.video) }
        }
        // Only the retired v0.1 patch changed the executable. Modern video
        // restoration must preserve Crimson and Steam executable updates.
        if legacy, try hash(Paths.exe) != manifest.originalExeHash {
            try Data(contentsOf: runURL.appendingPathComponent("original-dmc3.exe")).write(to: Paths.exe, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Paths.exe.path)
        }
        var restored = manifest; restored.status = "restored"
        try write(restored, runURL.appendingPathComponent("manifest.json"))
        if exists(Paths.state) { try fm.removeItem(at: Paths.state) }
    }
    func restore() throws {
        try withLock {
            try assertGameClosed()
            guard exists(Paths.state) else { throw PatchError("No hay un parche activo de esta app.") }
            let manifest = try read(Paths.state, as: Manifest.self)
            guard manifest.schema == 1, manifest.gamePath == Paths.game.path, !manifest.id.contains("/"), !manifest.id.contains("..") else { throw PatchError("Registro de restauración inválido.") }
            guard manifest.patchedExeHash == nil || !exists(Paths.modState) else {
                throw PatchError("Quitá Crimson antes de remover el parche antiguo que modificaba dmc3.exe.")
            }
            guard !manifest.id.isEmpty, Set(manifest.videos.map(\.output)).count == manifest.videos.count else { throw PatchError("Registro de restauración inválido.") }
            let runURL = Paths.runs.appendingPathComponent(manifest.id)
            guard runURL.path == runURL.resolvingSymlinksInPath().path else { throw PatchError("El respaldo está redirigido mediante un enlace simbólico.") }
            try rollback(manifest, runURL: runURL, checkCurrent: true)
            log("Estado anterior restaurado. Los respaldos originales permanecen en los datos de DMC3 Patch.")
        }
    }
}
