import CrimsonArchiveC
import Darwin
import Foundation

extension CrimsonInstaller {
    private var archiveOriginals: [String: (path: String, size: Int64)] {
        [
            "dmcload.dll": ("dinput8.dll", 141_824),
            "DMCHDFix.asi": ("DMCHDFix.asi", 215_040),
            "DMCHDFix.ini": ("DMCHDFix.ini", 519)
        ]
    }

    func validateArchive(_ archive: URL) throws {
        let recipe = try engine.read(CrimsonPaths.recipe, as: ModRecipe.self)
        try readArchive(archive, recipe: recipe)
    }

    func prepareArchivePayload(_ archive: URL, recipe: ModRecipe, originals: [String: URL], in temporary: URL) throws {
        guard CrimsonPaths.hasInstaller else {
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

        engine.log("Preparando los archivos de Crimson para CrossOver…")
        try readArchive(archive, recipe: recipe, destination: temporary)
        for (target, input) in archiveOriginals {
            sources[target] = try safeURL(temporary, input.path)
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

    private func readArchive(_ url: URL, recipe: ModRecipe, destination: URL? = nil) throws {
        let invalidArchive = PatchError("No se pudo leer el ZIP o RAR de Crimson. Elegí el paquete completo de la versión 0.5a.")
        let type = url.pathExtension.lowercased()
        let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard ["zip", "rar"].contains(type), attributes.isRegularFile == true,
              let size = attributes.fileSize, size > 0, size <= 1_073_741_824,
              let archive = archive_read_new() else { throw invalidArchive }
        defer { archive_read_free(archive) }

        if type == "zip" {
            guard archive_read_support_format_zip(archive) == 0 else { throw invalidArchive }
        } else {
            guard archive_read_support_format_rar(archive) == 0,
                  archive_read_support_format_rar5(archive) == 0 else { throw invalidArchive }
        }
        guard url.withUnsafeFileSystemRepresentation({ archive_read_open_filename(archive, $0, 64 * 1024) }) == 0 else {
            throw invalidArchive
        }

        let adapted = Set(archiveOriginals.keys).union(["dmcLauncher.exe", "crimson_api.dll"])
        var expected: [String: Int64] = [:]
        for file in recipe.files where !adapted.contains(file.path) && !GameFolder.executableNameIsSafe(file.path) {
            expected[file.path] = file.size
        }
        for input in archiveOriginals.values { expected[input.path] = input.size }

        var wrapper: String?
        var seen: Set<String> = []
        var entries = 0
        var totalSize: Int64 = 0
        var entry: OpaquePointer?
        while true {
            try engine.checkCancel()
            let status = archive_read_next_header(archive, &entry)
            if status == 1 { break }
            entries += 1
            guard status == 0, entries <= 20_000, let entry,
                  let rawName = archive_entry_pathname_utf8(entry),
                  let name = String(validatingUTF8: rawName) else { throw invalidArchive }
            let entrySize = archive_entry_size(entry)
            guard entrySize >= 0, entrySize <= 2_147_483_648 - totalSize else { throw invalidArchive }
            totalSize += entrySize
            let relative = name.hasPrefix("./") ? String(name.dropFirst(2)) : name
            let components = relative.split(separator: "/")
            guard !relative.hasPrefix("/"), !relative.contains("\\"),
                  components.allSatisfy({ $0 != "." && $0 != ".." }) else { throw invalidArchive }
            let direct = components.joined(separator: "/")
            let nested = components.dropFirst().joined(separator: "/")
            let path = expected[direct] != nil ? direct : nested
            if let size = expected[path] {
                let prefix = path == direct ? "" : String(components[0])
                guard wrapper == nil || wrapper == prefix,
                      seen.insert(path).inserted,
                      archive_entry_filetype(entry) == mode_t(S_IFREG),
                      archive_entry_hardlink(entry) == nil,
                      archive_entry_symlink(entry) == nil,
                      archive_entry_is_encrypted(entry) == 0,
                      entrySize == size else { throw invalidArchive }
                wrapper = prefix
                if let destination {
                    let output = try safeURL(destination, path)
                    try writeArchiveEntry(archive, to: output, size: size)
                    continue
                }
            }
            guard archive_read_data_skip(archive) == 0 else { throw invalidArchive }
        }
        guard seen.count == expected.count else {
            throw PatchError("El archivo está incompleto o no es el paquete de Crimson 0.5a.")
        }
    }

    private func writeArchiveEntry(_ archive: OpaquePointer, to url: URL, size: Int64) throws {
        try engine.mkdir(url.deletingLastPathComponent())
        let error = PatchError("No se pudo extraer un archivo completo de Crimson. Revisá \(url.lastPathComponent).")
        guard fm.createFile(atPath: url.path, contents: nil) else { throw error }
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        var buffer = Data(count: 64 * 1024)
        var remaining = size
        while remaining > 0 {
            try engine.checkCancel()
            let requested = min(buffer.count, Int(remaining))
            let count = buffer.withUnsafeMutableBytes { archive_read_data(archive, $0.baseAddress, requested) }
            guard count > 0, count <= requested else { throw error }
            try file.write(contentsOf: buffer.prefix(count))
            remaining -= Int64(count)
        }
    }
}
