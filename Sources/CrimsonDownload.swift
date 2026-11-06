import Foundation

extension CrimsonInstaller {
    func prepareDownloadedPayload(_ recipe: ModRecipe, originals: [String: URL], in temporary: URL) throws {
        guard CrimsonPaths.hasDownloadInstaller else {
            throw PatchError("Faltan las herramientas de Crimson. Volvé a descargar DMC3 Patch.")
        }

        var sources: [String: URL] = [:]
        for base in recipe.baseFiles {
            let file = try originals[base.path] ?? baseURL(base.path)
            guard engine.exists(file), try engine.hash(file) == base.hash else {
                throw PatchError("No se encontró una copia original compatible de \(base.path).")
            }
            sources[base.path == "steam_api64.dll" ? "crimson_api.dll" : base.path] = file
        }

        let archive = temporary.appendingPathComponent("Crimson-0.5a-pack.rar")
        engine.log("Descargando Crimson 0.5a desde su release oficial (400 MB)…")
        try engine.run(URL(fileURLWithPath: "/usr/bin/curl"), [
            "--disable", "--fail", "--location", "--silent", "--show-error",
            "--proto", "=https", "--proto-redir", "=https", "--connect-timeout", "20",
            "--max-time", "900", "--max-filesize", "400161825", "--retry", "2",
            "--output", archive.path,
            "https://github.com/berthrage/DMC3-Crimson/releases/download/V0.5a/Crimson-0.5a-pack.rar"
        ])
        guard try engine.hash(archive) == "11208c56a33d08d936fa00efc23253f3ad211bca400df18bbaa2e8ea874470bd" else {
            throw PatchError("La descarga de Crimson no coincide con su huella de verificación.")
        }

        engine.log("Preparando los archivos de Crimson para CrossOver…")
        try engine.run(URL(fileURLWithPath: "/usr/bin/tar"), ["-xf", archive.path, "-C", temporary.path])
        try fm.removeItem(at: archive)
        for (target, source) in [("dmcload.dll", "dinput8.dll"),
                                 ("DMCHDFix.asi", "DMCHDFix.asi"),
                                 ("DMCHDFix.ini", "DMCHDFix.ini")] {
            sources[target] = try safeURL(temporary, source)
        }
        for (name, source) in sources.sorted(by: { $0.key < $1.key }) {
            let delta = try safeURL(CrimsonPaths.compatibility, name + ".vcdiff")
            let target = try safeURL(temporary, name)
            let output = temporary.appendingPathComponent(".adapted-" + name)
            try engine.run(CrimsonPaths.decoder, ["-d", "-s", source.path, delta.path, output.path])
            if engine.exists(target) { try fm.removeItem(at: target) }
            try fm.moveItem(at: output, to: target)
        }
    }
}
