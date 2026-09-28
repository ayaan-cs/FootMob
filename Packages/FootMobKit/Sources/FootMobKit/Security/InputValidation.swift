import Foundation

/// Central checks for anything that crosses a trust boundary: deep links, widget/Siri intent
/// parameters, and URLs that arrive inside third-party API responses.
public enum InputValidation {
    /// Hosts FootMob will load images from. Anything else in an API response is dropped.
    public static let trustedImageHosts = ["espncdn.com", "espn.com"]

    /// Hosts FootMob will open article links for when they arrive via a deep link.
    public static let trustedArticleHosts = ["espn.com", "espn.go.com"]

    /// ESPN event and team IDs are short ASCII alphanumerics. Rejecting everything else stops
    /// path traversal (`../`) and query injection when IDs are placed into request URLs.
    public static func isValidIdentifier(_ value: String) -> Bool {
        (1...24).contains(value.unicodeScalars.count) && value.unicodeScalars.allSatisfy {
            $0.isASCII && CharacterSet.alphanumerics.contains($0)
        }
    }

    /// `true` for HTTPS URLs whose host is, or is a subdomain of, one of `hosts`.
    public static func isTrusted(_ url: URL, hosts: [String]) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              let host = url.host()?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Parses an image URL from an API response, keeping it only if it's HTTPS on a trusted host.
    public static func imageURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string), isTrusted(url, hosts: trustedImageHosts) else { return nil }
        return url
    }

    /// Parses a web link from an API response, keeping it only if it's HTTPS.
    public static func webURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string), url.scheme?.lowercased() == "https",
              url.host() != nil else { return nil }
        return url
    }

    /// Article URLs that arrive from outside the app (deep links) must point at a trusted news host.
    public static func isTrustedArticle(_ url: URL) -> Bool {
        isTrusted(url, hosts: trustedArticleHosts)
    }
}
