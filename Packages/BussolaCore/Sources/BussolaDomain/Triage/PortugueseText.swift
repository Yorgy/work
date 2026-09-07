import Foundation

/// Normalização de texto português, feita à mão e sem ICU.
///
/// `folding(options:.diacriticInsensitive)` depende da disponibilidade de ICU,
/// que varia entre plataformas. Um mapa explícito é previsível, testável e
/// suficiente para o alfabeto que interessa.
public enum PortugueseText {
    private static let acentos: [Character: Character] = [
        "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a",
        "é": "e", "è": "e", "ê": "e", "ë": "e",
        "í": "i", "ì": "i", "î": "i", "ï": "i",
        "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
        "ú": "u", "ù": "u", "û": "u", "ü": "u",
        "ç": "c", "ñ": "n",
    ]

    /// Minúsculas, sem acentos. A base de toda a correspondência de palavras.
    public static func normalizar(_ texto: String) -> String {
        String(texto.lowercased().map { acentos[$0] ?? $0 })
    }

    /// Palavras, com pontuação removida mas preservando `/` e `-` para as datas.
    public static func palavras(_ texto: String) -> [String] {
        normalizar(texto)
            .split { !($0.isLetter || $0.isNumber || $0 == "/" || $0 == "-") }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Primeira letra maiúscula, resto intacto. `capitalized` estragaria nomes
    /// próprios e siglas — "IVA" não pode virar "Iva".
    public static func capitalizarPrimeira(_ texto: String) -> String {
        guard let primeira = texto.first else { return texto }
        return String(primeira).uppercased() + texto.dropFirst()
    }
}
