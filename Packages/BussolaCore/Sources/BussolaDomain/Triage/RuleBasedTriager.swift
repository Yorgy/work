import Foundation

/// Triagem determinística por palavras-chave, padrões de data e heurísticas.
///
/// É o caminho de recurso quando o Apple Intelligence não está disponível — por
/// dispositivo, região ou idioma — e a rede de segurança se a avaliação em
/// pt-PT ficar abaixo do limiar. Ver ADR-007.
///
/// Deliberadamente conservador na confiança que atribui: uma proposta errada
/// apresentada com certeza é pior do que uma proposta hesitante, porque obriga
/// a ler tudo com desconfiança.
public struct RuleBasedTriager: Triaging {
    public var isAvailable: Bool { true }

    private let calendario: Calendar

    public init(calendario: Calendar = .current) {
        self.calendario = calendario
    }

    public func sugerir(para captura: Capture, agora: Date = Date()) async throws -> TriageSuggestion {
        analisar(captura.text, agora: agora)
    }

    /// Síncrono e puro — a forma que os testes usam.
    public func analisar(_ texto: String, agora: Date = Date()) -> TriageSuggestion {
        let palavras = PortugueseText.palavras(texto)
        let normalizado = PortugueseText.normalizar(texto)

        let (area, forcaDaArea) = detectarArea(palavras: palavras)
        let (kind, dono, canal) = detectarTipo(
            normalizado: normalizado, original: texto, palavras: palavras
        )
        let data = DateParserPT(calendario: calendario).detectar(palavras: palavras, agora: agora)
        let minutos = estimarMinutos(palavras: palavras, kind: kind)
        let energia = estimarEnergia(minutos: minutos, palavras: palavras)

        let confianca = calcularConfianca(
            forcaDaArea: forcaDaArea,
            temData: data != nil,
            kind: kind,
            temDono: dono != nil,
            numeroDePalavras: palavras.count
        )

        return TriageSuggestion(
            actionTitle: titulo(de: texto, kind: kind),
            area: area,
            kind: kind,
            energy: energia,
            estimatedMinutes: minutos,
            dueDate: data,
            waitingOn: dono,
            channel: canal,
            confidence: confianca
        )
    }

    // MARK: - Área

    /// Vocabulário real: fiscalidade portuguesa, web, casa, obra.
    /// Cresce com o uso — é a parte que mais beneficia de ser editada à mão
    /// depois de duas semanas de capturas verdadeiras.
    static let lexico: [AreaID: Set<String>] = [
        .agencia: [
            "iva", "irc", "irs", "fatura", "factura", "faturas", "facturas", "recibo",
            "recibos", "contabilista", "contabilidade", "financas", "fisco", "at",
            "seguranca", "social", "salario", "salarios", "ordenado", "ordenados",
            "retencao", "retencoes", "modelo", "ies", "banco", "tesouraria", "saldo",
            "pagamento", "pagamentos", "cobranca", "cobrancas", "despesa",
            "despesas", "receita", "receitas", "agencia", "empresa", "socio", "socios",
        ],
        .clientes: [
            "cliente", "clientes", "site", "sites", "website", "web", "deploy", "servidor",
            "dominio", "dns", "wordpress", "landing", "proposta", "propostas", "briefing",
            "maquete", "mockup", "design", "frontend", "backend", "api", "bug", "bugs",
            "hosting", "alojamento", "ssl", "seo", "loja", "checkout", "plugin", "tema",
            "reuniao", "call", "apresentacao", "projeto", "projecto",
        ],
        .familia: [
            "filha", "esposa", "mulher", "escola", "creche", "infantario", "pediatra",
            "medico", "consulta", "vacina", "aniversario", "prenda", "compras",
            "supermercado", "jantar", "almoco", "ferias", "praia", "parque", "brinquedo",
            "roupa", "fralda", "fraldas", "papa", "bebe", "familia", "sogros",
            "pais", "mae", "pai", "natal", "pascoa", "festa",
        ],
        .obras: [
            "obra", "obras", "empreiteiro", "pedreiro", "canalizador", "eletricista",
            "electricista", "pintor", "caldeira", "canalizacao", "tubagem", "azulejo",
            "azulejos", "tinta", "cimento", "telhado", "janela", "janelas", "porta",
            "portas", "cozinha", "casadebanho", "wc", "estaleiro", "material",
            "materiais", "licenca", "camara", "arquitecto", "arquiteto", "planta",
            "orcamento", "orcamentos", "banho", "medicoes", "chao", "parede",
            "paredes", "teto", "tecto", "empreitada", "andaime", "andaimes",
        ],
        .pessoal: [
            "ginasio", "correr", "corrida", "treino", "livro", "livros", "ler", "curso",
            "dentista", "cabeleireiro", "carro", "inspecao", "inspeccao", "seguro",
            "passaporte", "cartao", "renovar", "amigos", "cafe", "hobby", "musica",
        ],
    ]

    func detectarArea(palavras: [String]) -> (AreaID, Int) {
        var pontos: [AreaID: Int] = [:]
        for palavra in palavras {
            for (area, termos) in Self.lexico where termos.contains(palavra) {
                pontos[area, default: 0] += 1
            }
        }

        // A ordem de `allCases` desempata. Iterar um dicionário não tem ordem
        // garantida, e uma triagem que muda de resultado entre execuções com o
        // mesmo texto é indefensável — a confiança do utilizador mede-se aqui.
        let melhor = AreaID.allCases
            .compactMap { area in pontos[area].map { (area: area, valor: $0) } }
            .max { $0.valor < $1.valor || ($0.valor == $1.valor && indice($1.area) < indice($0.area)) }

        guard let melhor, melhor.valor > 0 else {
            // Sem sinal nenhum, Pessoal é o balde menos danoso: não finge que
            // uma captura ambígua é trabalho da empresa.
            return (.pessoal, 0)
        }
        // Empate entre duas áreas é sinal fraco, não forte.
        let empatados = pontos.values.filter { $0 == melhor.valor }.count
        return (melhor.area, empatados > 1 ? 1 : melhor.valor + 1)
    }

    private func indice(_ area: AreaID) -> Int {
        AreaID.allCases.firstIndex(of: area) ?? 0
    }

    // MARK: - Tipo

    private static let marcadoresDeEspera: [String] = [
        "a espera", "aguardar", "aguardo", "pedir ao", "pedir a", "pedir ", "perguntar ao",
        "perguntar a", "falar com", "cobrar ao", "cobrar a", "confirmar com",
        "resposta do", "resposta da", "enviou", "prometeu", "ficou de",
        "ver com", "saber do", "saber da",
    ]

    private static let marcadoresDeReferencia: [String] = [
        "ideia", "nota", "lembrar que", "para memoria", "referencia", "guardar link",
        "artigo", "podcast", "video sobre",
    ]

    func detectarTipo(
        normalizado: String, original: String, palavras: [String]
    ) -> (ItemKind, String?, Channel?) {
        if palavras.isEmpty { return (.lixo, nil, nil) }

        for marcador in Self.marcadoresDeEspera where normalizado.contains(marcador) {
            let dono = extrairDono(normalizado: normalizado, original: original, apos: marcador)
            return (.espera, dono, canal(normalizado: normalizado))
        }
        for marcador in Self.marcadoresDeReferencia where normalizado.contains(marcador) {
            return (.referencia, nil, nil)
        }
        return (.accao, nil, nil)
    }

    /// Artigos e tratamentos que se atravessam entre o marcador e o nome.
    private static let artigos: Set<String> = [
        "o", "a", "os", "as", "ao", "aos", "do", "da", "dos", "das", "um", "uma",
        "sr", "sra", "srs", "senhor", "senhora", "dr", "dra", "eng",
    ]

    /// Onde a recolha do nome pára. Sem isto, "falar com o contabilista sobre o
    /// IVA" produzia o dono "Contabilista Sobre".
    private static let paragens: Set<String> = [
        "sobre", "para", "por", "com", "que", "se", "quando", "porque", "e", "ou",
        "em", "no", "na", "nos", "nas", "ate", "de", "the", "acerca", "quanto",
    ]

    /// Papéis que valem como dono mesmo em minúsculas — é assim que se fala:
    /// "o contabilista ainda não enviou", não "o Sr. Contabilista".
    private static let papeis: Set<String> = [
        "contabilista", "empreiteiro", "canalizador", "eletricista", "electricista",
        "pedreiro", "pintor", "arquitecto", "arquiteto", "advogado", "banco",
        "cliente", "fornecedor", "senhorio", "pediatra", "medico", "escola",
        "professora", "professor", "seguradora", "camara",
    ]

    /// O dono, extraído do texto **original** para não perder acentos.
    ///
    /// Conservador de propósito: um dono errado é pior do que nenhum, porque
    /// manda insistir com a pessoa errada. Só aceita duas fontes de sinal — uma
    /// palavra capitalizada por quem escreveu, ou um papel conhecido.
    private func extrairDono(normalizado: String, original: String, apos marcador: String) -> String? {
        guard let intervalo = normalizado.range(of: marcador) else { return nil }
        let corte = normalizado.distance(from: normalizado.startIndex, to: intervalo.upperBound)

        // `normalizar` mapeia carácter a carácter, por isso os offsets coincidem.
        // Se alguma vez deixarem de coincidir, é melhor não adivinhar.
        let normArr = Array(normalizado), origArr = Array(original)
        guard normArr.count == origArr.count, corte <= origArr.count else { return nil }

        let seguintes = tokenizarPreservandoOriginal(Array(origArr[corte...]))

        var nome: [String] = []
        for token in seguintes.prefix(6) {
            let chave = PortugueseText.normalizar(token)
            if Self.artigos.contains(chave) {
                if nome.isEmpty { continue } else { break }
            }
            if Self.paragens.contains(chave) { break }
            guard token.allSatisfy(\.isLetter), token.count >= 2 else { break }

            let ehNomeProprio = token.first?.isUppercase == true
            let ehPapel = Self.papeis.contains(chave)
            guard ehNomeProprio || (nome.isEmpty && ehPapel) else { break }

            nome.append(PortugueseText.capitalizarPrimeira(token))
            // Um papel é sempre um termo só: "contabilista", não "contabilista Silva".
            if ehPapel || nome.count == 2 { break }
        }
        return nome.isEmpty ? nil : nome.joined(separator: " ")
    }

    private func tokenizarPreservandoOriginal(_ caracteres: [Character]) -> [String] {
        String(caracteres)
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func canal(normalizado: String) -> Channel {
        if normalizado.contains("email") || normalizado.contains("e-mail") { return .email }
        if normalizado.contains("whatsapp") || normalizado.contains("mensagem")
            || normalizado.contains("sms") { return .mensagem }
        if normalizado.contains("ligar") || normalizado.contains("telefonar")
            || normalizado.contains("chamada") { return .chamada }
        if normalizado.contains("contabilista") || normalizado.contains("financas")
            || normalizado.contains("camara") { return .formal }
        return .email
    }

    // MARK: - Duração e energia

    private static let sinaisDeProfundo: Set<String> = [
        "escrever", "proposta", "planear", "desenhar", "arquitectura", "arquitetura",
        "analisar", "estudar", "rever", "orcamentar", "programar", "implementar",
        "modelo", "relatorio", "apresentacao",
    ]

    private static let sinaisDeRapido: Set<String> = [
        "ligar", "enviar", "responder", "confirmar", "marcar", "pagar", "comprar",
        "encomendar", "assinar", "reservar",
    ]

    func estimarMinutos(palavras: [String], kind: ItemKind) -> Int {
        if kind == .espera { return 5 }
        if palavras.contains(where: { Self.sinaisDeProfundo.contains($0) }) { return 60 }
        if palavras.contains(where: { Self.sinaisDeRapido.contains($0) }) { return 5 }
        return palavras.count > 8 ? 30 : 15
    }

    func estimarEnergia(minutos: Int, palavras: [String]) -> Energy {
        if minutos >= 45 { return .deep }
        if palavras.contains(where: { Self.sinaisDeRapido.contains($0) }) { return .admin }
        return .shallow
    }

    // MARK: - Título

    /// Mantém o texto do próprio, apenas arrumado. Reescrever aquilo que a
    /// pessoa ditou torna a lista estranha a quem a escreveu.
    func titulo(de texto: String, kind: ItemKind) -> String {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return "(captura vazia)" }
        return PortugueseText.capitalizarPrimeira(limpo)
    }

    // MARK: - Confiança

    func calcularConfianca(
        forcaDaArea: Int,
        temData: Bool,
        kind: ItemKind,
        temDono: Bool,
        numeroDePalavras: Int
    ) -> Int {
        // Base baixa: sem sinal, isto não sabe nada e não deve fingir que sabe.
        var pontos = 30
        pontos += min(30, forcaDaArea * 15)
        if temData { pontos += 15 }
        if kind == .espera && temDono { pontos += 15 }
        if kind == .espera && !temDono { pontos -= 10 }
        if numeroDePalavras <= 2 { pontos -= 15 }
        if numeroDePalavras >= 5 { pontos += 5 }
        return min(95, max(5, pontos))
    }
}
