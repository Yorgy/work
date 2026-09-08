import Foundation
import BussolaDomain

#if canImport(FoundationModels)
import FoundationModels

/// O tipo que o modelo local preenche.
///
/// `@Generable` faz o modelo devolver um valor Swift verificado em vez de uma
/// string para parsear — é a razão principal para usar esta framework em vez de
/// pedir JSON a um LLM e torcer para que venha bem formado.
///
/// Os campos são deliberadamente estreitos: `AreaSugerida` é um enum, por isso o
/// modelo **não consegue** inventar uma área que não existe. Restringir o
/// espaço de saída vale mais do que qualquer instrução no prompt.
@Generable
struct SugestaoGerada {
    @Guide(description: "A tarefa reescrita como acção concreta começada por um verbo, em português de Portugal. Mantém os nomes próprios exactamente como aparecem.")
    var titulo: String

    @Guide(description: "A área de responsabilidade a que isto pertence.")
    var area: AreaSugerida

    @Guide(description: "O que isto é: uma acção própria, algo à espera de outra pessoa, informação de referência, ou lixo.")
    var tipo: TipoSugerido

    @Guide(description: "O nome da pessoa de quem se espera. Só preencher se o tipo for 'espera' e a pessoa estiver mesmo nomeada no texto. Nunca inventar um nome.")
    var pessoa: String?

    @Guide(description: "Minutos que isto demora, escolhendo entre 5, 15, 30, 60 ou 90.")
    var minutos: Int

    @Guide(description: "A data-limite mencionada no texto, no formato AAAA-MM-DD. Deixar vazio se não houver data explícita. Nunca inventar uma data.")
    var dataLimite: String?

    @Guide(description: "Quão certo estás desta classificação, de 0 a 100.")
    var confianca: Int
}

@Generable
enum AreaSugerida: String {
    case agencia, clientes, familia, obras, pessoal

    var dominio: AreaID {
        AreaID(rawValue: rawValue) ?? .pessoal
    }
}

@Generable
enum TipoSugerido: String {
    case accao, espera, referencia, lixo

    var dominio: ItemKind {
        ItemKind(rawValue: rawValue) ?? .accao
    }
}
#endif

/// Triagem com o modelo local do Apple Intelligence.
///
/// Grátis, offline, e os dados não saem do dispositivo — o que importa quando o
/// que se dita inclui números da empresa e o nome da filha.
///
/// Propõe, nunca decide (ADR-003). Toda a sugestão passa pelo polegar do
/// utilizador na triagem: uma app que arquiva sozinha perde-se ao primeiro erro
/// e nunca mais recupera a confiança.
public struct FoundationModelsTriager: Triaging {

    /// O caminho de recurso, sempre montado. Não é um plano B teórico: usa-se
    /// quando o modelo não está disponível, quando falha, e quando devolve algo
    /// que não se consegue aproveitar.
    private let recurso: RuleBasedTriager
    private let calendario: Calendar

    public init(calendario: Calendar = .current) {
        self.calendario = calendario
        self.recurso = RuleBasedTriager(calendario: calendario)
    }

    public var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 15.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
        #else
        return false
        #endif
    }

    /// Porque é que o modelo não está disponível, em linguagem de gente.
    /// A app diz isto no ecrã de definições em vez de esconder a degradação.
    public var razaoDeIndisponibilidade: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 15.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "Este iPhone não suporta Apple Intelligence. A triagem usa regras."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence está desligado nas Definições. A triagem usa regras."
            case .unavailable(.modelNotReady):
                return "O modelo ainda está a descarregar. A triagem usa regras entretanto."
            case .unavailable:
                return "O modelo local não está disponível. A triagem usa regras."
            }
        }
        return "Requer iOS 26. A triagem usa regras."
        #else
        return "Modelo local indisponível nesta plataforma. A triagem usa regras."
        #endif
    }

    public func sugerir(para captura: Capture, agora: Date = Date()) async throws -> TriageSuggestion {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 15.0, *), isAvailable {
            if let sugestao = await tentarModelo(captura: captura, agora: agora) {
                return sugestao
            }
        }
        #endif
        // Degradação silenciosa para o utilizador, explícita nas definições.
        return recurso.analisar(captura.text, agora: agora)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 15.0, *)
    private func tentarModelo(captura: Capture, agora: Date) async -> TriageSuggestion? {
        do {
            let sessao = LanguageModelSession(instructions: Self.instrucoes)
            let resposta = try await sessao.respond(
                to: Self.pergunta(para: captura.text, agora: agora, calendario: calendario),
                generating: SugestaoGerada.self
            )
            return converter(resposta.content, captura: captura, agora: agora)
        } catch {
            // Um erro do modelo não é um erro da app. Cai-se para regras e
            // segue-se — o utilizador está a triar às 21h, não a depurar.
            return nil
        }
    }

    @available(iOS 26.0, macOS 15.0, *)
    private func converter(
        _ gerada: SugestaoGerada, captura: Capture, agora: Date
    ) -> TriageSuggestion {
        let determinística = recurso.analisar(captura.text, agora: agora)

        // A data do modelo só se aceita se for válida e não estiver no passado
        // distante. Um LLM a alucinar datas em obrigações fiscais é um passivo,
        // por isso o parser determinístico tem a última palavra quando encontra
        // algo — ele lê o que lá está, o modelo interpreta.
        let dataDoModelo = gerada.dataLimite.flatMap(Self.interpretarISO)
        let data = determinística.dueDate ?? dataDoModelo

        // Um nome só conta se aparecer mesmo no texto original. É a salvaguarda
        // contra a alucinação mais cara deste sistema: mandar insistir com uma
        // pessoa que nunca esteve envolvida.
        let pessoa = gerada.pessoa.flatMap { nome -> String? in
            let procurado = PortugueseText.normalizar(nome)
            let texto = PortugueseText.normalizar(captura.text)
            return texto.contains(procurado) ? nome : nil
        } ?? determinística.waitingOn

        let tipo = gerada.tipo.dominio
        let minutos = Self.arredondarMinutos(gerada.minutos)

        return TriageSuggestion(
            actionTitle: gerada.titulo.isEmpty ? determinística.actionTitle : gerada.titulo,
            area: gerada.area.dominio,
            kind: tipo,
            energy: minutos >= 45 ? .deep : (minutos <= 5 ? .admin : .shallow),
            estimatedMinutes: minutos,
            dueDate: data,
            waitingOn: tipo == .espera ? pessoa : nil,
            channel: tipo == .espera ? determinística.channel : nil,
            // Uma espera sem dono identificado nunca passa por certa: é
            // exactamente o caso em que o utilizador tem de olhar.
            confidence: ajustarConfianca(gerada.confianca, tipo: tipo, temDono: pessoa != nil)
        )
    }

    private func ajustarConfianca(_ bruta: Int, tipo: ItemKind, temDono: Bool) -> Int {
        var valor = min(95, max(5, bruta))
        if tipo == .espera && !temDono { valor = min(valor, 55) }
        return valor
    }

    private static func interpretarISO(_ texto: String) -> Date? {
        let formatador = DateFormatter()
        formatador.calendar = Calendar(identifier: .gregorian)
        formatador.timeZone = .current
        formatador.locale = Locale(identifier: "en_US_POSIX")
        formatador.dateFormat = "yyyy-MM-dd"
        return formatador.date(from: texto)
    }

    private static func arredondarMinutos(_ bruto: Int) -> Int {
        let permitidos = [5, 15, 30, 60, 90]
        guard bruto > 0 else { return 15 }
        return permitidos.min { abs($0 - bruto) < abs($1 - bruto) } ?? 15
    }

    private static let instrucoes = """
        És um assistente de organização pessoal que classifica notas rápidas em \
        português de Portugal. As notas são ditadas ou escritas à pressa, muitas \
        vezes com erros, e podem estar incompletas.

        Quem escreve gere cinco áreas ao mesmo tempo:
        - agencia: gestão financeira de uma agência de marketing — IVA, faturas, \
        retenções, contabilista, salários, Segurança Social
        - clientes: projectos de desenvolvimento web para clientes — sites, \
        propostas, deploys, servidores, reuniões
        - familia: esposa, filha pequena, escola, médicos, compras, logística da casa
        - obras: uma empreitada em curso — empreiteiros, materiais, orçamentos de \
        obra, licenças
        - pessoal: saúde, carro, formação, tudo o que é só dele

        Regras que não podes quebrar:
        - Nunca inventes uma data que não esteja no texto.
        - Nunca inventes o nome de uma pessoa. Se o texto diz "aguardar resposta" \
        sem dizer de quem, deixa a pessoa vazia.
        - Classifica como 'espera' quando o próximo passo depende de outra pessoa.
        - Mantém o vocabulário de quem escreveu. Não traduzas nem embelezes.
        - Se não tiveres a certeza, baixa a confiança em vez de adivinhar.
        """

    private static func pergunta(para texto: String, agora: Date, calendario: Calendar) -> String {
        let formatador = DateFormatter()
        formatador.calendar = calendario
        formatador.locale = Locale(identifier: "pt_PT")
        formatador.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy"
        return """
            Hoje é \(formatador.string(from: agora)).

            Classifica esta nota:
            "\(texto)"
            """
    }
    #endif
}

/// Escolhe o triador disponível, uma vez, no arranque.
public enum TriagerFactory {
    public static func melhorDisponivel(calendario: Calendar = .current) -> any Triaging {
        let local = FoundationModelsTriager(calendario: calendario)
        return local.isAvailable ? local : RuleBasedTriager(calendario: calendario)
    }
}

/// Estado do triador para a interface, sem expor a framework.
public struct TriagerEstado: Sendable {
    public let disponivel: Bool
    public let razao: String?

    public init(disponivel: Bool, razao: String?) {
        self.disponivel = disponivel
        self.razao = razao
    }
}

public enum TriagerEstadoFactory {
    public static func actual() -> TriagerEstado {
        let local = FoundationModelsTriager()
        return TriagerEstado(
            disponivel: local.isAvailable,
            razao: local.razaoDeIndisponibilidade
        )
    }
}
