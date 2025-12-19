import Foundation

/// Template packs (titles, transitions, sticker sets, etc.)
/// Starter: loads JSON templates from the app bundle.
/// Next: add a local "Templates" folder + marketplace downloads.
final class TemplateService {
    struct TemplatePack: Codable, Identifiable {
        var id: String
        var name: String
        var templates: [Template]
    }

    struct Template: Codable, Identifiable {
        var id: String
        var kind: String // "title", "transition", "sticker", ...
        var displayName: String
        var payload: [String: String] // simple starter payload
    }

    func loadBundledPacks() -> [TemplatePack] {
        guard let url = Bundle.main.url(forResource: "template_pack_basic", withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TemplatePack].self, from: data)
        } catch {
            Log.error("Template load failed: \(error)")
            return []
        }
    }
}
