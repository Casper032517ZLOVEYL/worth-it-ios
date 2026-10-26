import Foundation

struct ReleaseInformation {
    static func value(_ key: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return value.contains("$(") ? "" : value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func httpsURL(_ key: String) -> URL? {
        guard let url = URL(string: value(key)), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    static var privacyURL: URL? { httpsURL("PrivacyPolicyURL") }
    static var termsURL: URL? { httpsURL("TermsOfUseURL") }
    static var supportURL: URL? { httpsURL("SupportURL") }
    static var supportMailURL: URL? {
        let email = value("SupportEmail")
        guard AccountMethod.email.isValid(email) else { return nil }
        return URL(string: "mailto:" + email)
    }
}
