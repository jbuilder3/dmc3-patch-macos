import Foundation

enum L10n {
    static var language: String = {
        let value = try? JSONSerialization.jsonObject(with: Data(contentsOf: Paths.project.appendingPathComponent("language.json"))) as? [String: String]
        return value?["language"] == "en" ? "en" : "es"
    }()
    static let pairs: [[String]] = {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Translations.json")
        let url = bundled.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? Paths.assets.appendingPathComponent("docs/Translations.json")
        return (try? JSONDecoder().decode([[String]].self, from: Data(contentsOf: url)))?.filter { $0.count == 2 } ?? []
    }()
    static func text(_ value: String) -> String {
        let from = language == "en" ? 0 : 1; let to = 1 - from
        if let exact = pairs.first(where: { $0[from] == value }) { return exact[to] }
        for pair in pairs where pair[from].contains("{0}") {
            var pattern = NSRegularExpression.escapedPattern(for: pair[from])
            for index in 0..<8 { pattern = pattern.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: "{\(index)}"), with: "([\\s\\S]*?)") }
            if let expression = try? NSRegularExpression(pattern: "^" + pattern + "$"),
               let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) {
                let input = value as NSString; var result = pair[to]
                for index in 1..<match.numberOfRanges { result = result.replacingOccurrences(of: "{\(index-1)}", with: input.substring(with: match.range(at: index))) }
                return result
            }
        }
        if value.contains("\n") { return value.components(separatedBy: "\n").map { text($0) }.joined(separator: "\n") }
        return value
    }
    static func set(_ language: String) throws {
        let selected = language == "en" ? "en" : "es"
        try JSONSerialization.data(withJSONObject: ["language": selected], options: [.sortedKeys]).write(to: Paths.project.appendingPathComponent("language.json"), options: .atomic)
        self.language = selected
    }
}
