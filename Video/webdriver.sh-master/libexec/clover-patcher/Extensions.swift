import Foundation

extension String {
        var lines: [String] {
                var result: [String] = []
                enumerateLines { line, _ in result.append(line) }
                return result
        }
}
