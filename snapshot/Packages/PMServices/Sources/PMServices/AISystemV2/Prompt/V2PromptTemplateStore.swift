import Foundation

/// Manages v2 prompt template overrides stored in UserDefaults.
/// Falls back to compiled defaults from V2PromptDefaults when no override exists.
public final class V2PromptTemplateStore: @unchecked Sendable {
    public static let shared = V2PromptTemplateStore()

    private let defaults: UserDefaults
    private let keyPrefix = "v2PromptTemplate."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Get the template for a key — returns the user's override if set, otherwise the compiled default.
    public func template(for key: V2PromptTemplateKey) -> String {
        if let override = defaults.string(forKey: keyPrefix + key.rawValue), !override.isEmpty {
            return override
        }
        return V2PromptDefaults.defaultTemplate(for: key)
    }

    /// Set a custom template override. Pass nil to revert to default.
    public func setOverride(_ value: String?, for key: V2PromptTemplateKey) {
        if let value, !value.isEmpty {
            defaults.set(value, forKey: keyPrefix + key.rawValue)
        } else {
            defaults.removeObject(forKey: keyPrefix + key.rawValue)
        }
    }

    /// Check if a template has a user override.
    public func hasOverride(for key: V2PromptTemplateKey) -> Bool {
        defaults.string(forKey: keyPrefix + key.rawValue) != nil
    }

    /// Revert a template to its default.
    public func resetToDefault(for key: V2PromptTemplateKey) {
        defaults.removeObject(forKey: keyPrefix + key.rawValue)
    }

    /// Render a template with variable substitution.
    public func render(_ key: V2PromptTemplateKey, variables: [String: String] = [:]) -> String {
        var text = template(for: key)
        for (name, value) in variables {
            text = text.replacingOccurrences(of: "{{\(name)}}", with: value)
        }
        return text
    }
}
