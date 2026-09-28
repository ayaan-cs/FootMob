import Foundation

/// Decodes an array, silently dropping elements that fail to decode.
/// ESPN payloads are large and loosely typed; one odd element shouldn't sink a whole scoreboard.
struct Lossy<Element: Decodable>: Decodable {
    var values: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Element] = []
        while !container.isAtEnd {
            if let value = try? container.decode(Element.self) {
                values.append(value)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        self.values = values
    }

    private struct Skip: Decodable {
        init(from decoder: Decoder) throws {}
    }
}

/// A string that ESPN sometimes sends as a number.
struct FlexString: Decodable, Hashable {
    var value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = double.rounded() == double ? String(Int(double)) : String(double)
        } else {
            throw DecodingError.typeMismatch(String.self, .init(codingPath: decoder.codingPath,
                                                                 debugDescription: "Expected string or number"))
        }
    }
}

/// Scores arrive as `"21"` on scoreboards and `{"value": 21.0, "displayValue": "21"}` on schedules.
struct ESPNScore: Decodable, Hashable {
    var value: Int?

    private enum CodingKeys: String, CodingKey { case value, displayValue }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer() {
            if let string = try? single.decode(String.self) {
                value = Int(string)
                return
            }
            if let double = try? single.decode(Double.self) {
                value = Int(double)
                return
            }
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        if let double = try? keyed.decode(Double.self, forKey: .value) {
            value = Int(double)
        } else if let display = try? keyed.decode(String.self, forKey: .displayValue) {
            value = Int(display)
        } else {
            value = nil
        }
    }
}

enum ESPNDate {
    /// ESPN mixes `2025-09-28T17:00Z`, `2025-09-28T17:00:00Z` and fractional-second variants.
    static func parse(_ raw: String?) -> Date? {
        guard var string = raw, !string.isEmpty else { return nil }
        if string.hasSuffix("Z"), let t = string.firstIndex(of: "T") {
            let time = string[string.index(after: t)...]
            if time.filter({ $0 == ":" }).count == 1 {
                string.insert(contentsOf: ":00", at: string.index(before: string.endIndex))
            }
        }
        if let date = try? Date(string, strategy: .iso8601) { return date }
        if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mmZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
