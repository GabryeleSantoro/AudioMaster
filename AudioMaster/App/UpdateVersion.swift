import Foundation

enum UpdateVersion {
    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = parse(remote)
        let l = parse(local)
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    static func parse(_ string: String) -> [Int] {
        let cleaned = string.trimmingCharacters(in: .whitespaces)
        let withoutV = cleaned.hasPrefix("v") || cleaned.hasPrefix("V")
            ? String(cleaned.dropFirst())
            : cleaned
        let base = withoutV.split(separator: "-").first.map(String.init) ?? withoutV
        return base.split(separator: ".").compactMap { Int($0) }
    }
}
