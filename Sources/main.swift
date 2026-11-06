import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
setbuf(stdout, nil)
do { try Paths.prepareData() }
catch { fputs("ERROR: \(error.localizedDescription)\n", stderr); exit(1) }
if let command = arguments.first, !command.hasPrefix("-psn") {
    let engine = Engine()
    engine.log = { AppLog.write($0); print($0) }
    do {
        switch command {
        case "package-info":
            let locations = ["resources": Paths.assets.path, "data": Paths.project.path, "ffmpeg": Paths.ffmpeg.path, "crimson": CrimsonPaths.archive.path, "crimsonInstaller": CrimsonPaths.hasInstaller ? "available" : "unavailable"]
            let data = try JSONSerialization.data(withJSONObject: locations, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
        case "diagnose": _ = try engine.diagnose()
        case "prepare":
            let profile = arguments.contains("--original") ? "original" : "compatible"
            var limit: Int?
            if let index = arguments.firstIndex(of: "--limit"), index + 1 < arguments.count { limit = Int(arguments[index + 1]) }
            _ = try engine.prepare(profile: profile, flipped: arguments.contains("--flip"), limit: limit)
        case "video-status": _ = try engine.analyzeVideoPatch()
        case "install-video": try engine.installVideoPatch()
        case "apply": try engine.apply()
        case "restore": try engine.restore()
        case "mod-status": _ = try CrimsonInstaller(engine: engine).analyze()
        case "mod-install":
            if engine.exists(Paths.modState) { try CrimsonInstaller(engine: engine).updateGameFiles() }
            else { try CrimsonInstaller(engine: engine).install() }
        case "mod-remove": try CrimsonInstaller(engine: engine).uninstall()
        case "select-game":
            guard arguments.count == 2 else { throw PatchError("Uso: select-game /ruta/a/la/carpeta/del/juego") }
            let selected = try SelectionStore.shared.select(URL(fileURLWithPath: arguments[1], isDirectory: true))
            print("Juego: \(selected.gamePath)\nSelección validada. Solo se modificarán archivos de esta carpeta.")
        case "verify-runtime": _ = try engine.verifyRuntime()
        default:
            print("DMC3 Patch: package-info | video-status | install-video | diagnose | prepare [--original] [--flip] [--limit N] | apply | restore | mod-status | mod-install | mod-remove | verify-runtime | select-game RUTA")
            exit(2)
        }
    } catch { AppLog.write("ERROR: " + error.localizedDescription); fputs("ERROR: \(error.localizedDescription)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate; app.run()
}
