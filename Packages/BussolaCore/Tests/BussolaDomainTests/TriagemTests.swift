import Foundation
import Testing
@testable import BussolaDomain

@Suite("Triagem determinística — a rede de segurança quando não há IA")
struct RuleBasedTriagerTests {

    private let triager = RuleBasedTriager(calendario: Fixo.calendario)

    private func analisar(_ texto: String) -> TriageSuggestion {
        triager.analisar(texto, agora: Fixo.segunda)
    }

    @Test("Vocabulário fiscal cai na Agência", arguments: [
        "pagar o IVA do trimestre",
        "enviar as faturas ao contabilista",
        "ver as retenções na fonte",
    ])
    func areaAgencia(texto: String) {
        #expect(analisar(texto).area == .agencia)
    }

    @Test("Vocabulário de obra cai em Obras", arguments: [
        "pedir preço da caldeira ao canalizador",
        "comprar azulejos para a casa de banho",
        "falar com o empreiteiro sobre o telhado",
    ])
    func areaObras(texto: String) {
        #expect(analisar(texto).area == .obras)
    }

    @Test("Vocabulário familiar cai em Família")
    func areaFamilia() {
        #expect(analisar("marcar consulta no pediatra").area == .familia)
        #expect(analisar("comprar prenda de aniversário").area == .familia)
    }

    @Test("Sem sinal nenhum vai para Pessoal, com confiança baixa")
    func semSinal() {
        let s = analisar("aquilo")
        #expect(s.area == .pessoal)
        #expect(s.exigeRevisaoManual)
    }

    @Test("«pedir ao» marca espera e extrai o dono")
    func esperaComDono() {
        let s = analisar("pedir ao Vítor o orçamento da obra")
        #expect(s.kind == .espera)
        #expect(s.waitingOn == "Vítor")
    }

    @Test("«falar com» também é espera")
    func falarCom() {
        let s = analisar("falar com o contabilista sobre o IVA")
        #expect(s.kind == .espera)
        #expect(s.waitingOn == "Contabilista")
        #expect(s.channel == .formal)
    }

    @Test("Espera sem dono identificável perde confiança")
    func esperaSemDono() {
        let s = analisar("aguardar resposta")
        #expect(s.kind == .espera)
        #expect(s.waitingOn == nil)
        #expect(s.exigeRevisaoManual)
    }

    @Test("O canal determina o ritmo do follow-up")
    func canais() {
        #expect(analisar("pedir ao João por email o ficheiro").channel == .email)
        #expect(analisar("ligar ao Pedro para pedir a planta").channel == .chamada)
    }

    @Test("Verbos de fundo produzem trabalho profundo e longo")
    func trabalhoProfundo() {
        let s = analisar("escrever a proposta para o cliente novo")
        #expect(s.estimatedMinutes == 60)
        #expect(s.energy == .deep)
    }

    @Test("Verbos rápidos produzem Areia administrativa")
    func trabalhoRapido() {
        let s = analisar("pagar a fatura da luz")
        #expect(s.estimatedMinutes == 5)
        #expect(s.energy == .admin)
    }

    @Test("Uma data no texto sobe a confiança")
    func dataSobeConfianca() {
        let com = analisar("entregar o IVA dia 25")
        let sem = analisar("entregar o IVA")
        #expect(com.dueDate != nil)
        #expect(com.confidence > sem.confidence)
    }

    @Test("A confiança fica sempre dentro de 5…95 — nunca finge certeza absoluta")
    func confiancaLimitada() {
        let textos = ["", "a", "pedir ao contabilista o mapa de IVA até dia 25 de setembro por email"]
        for t in textos {
            let c = analisar(t).confidence
            #expect(c >= 5 && c <= 95)
        }
    }

    @Test("Captura vazia é lixo, não uma tarefa fantasma")
    func vazia() {
        #expect(analisar("   ").kind == .lixo)
    }

    @Test("O título mantém as palavras do próprio, só arrumadas")
    func tituloPreservado() {
        #expect(analisar("ver a caldeira com o Sr. Vítor").actionTitle
                == "Ver a caldeira com o Sr. Vítor")
        // Siglas não são estragadas por capitalização automática.
        #expect(analisar("pagar IVA").actionTitle == "Pagar IVA")
    }

    @Test("Materializar uma espera cria a tarefa já em estado de espera")
    func materializar() {
        let captura = Capture(text: "pedir ao Vítor o orçamento", createdAt: Fixo.segunda)
        let tarefa = analisar(captura.text).materializar(origem: captura, agora: Fixo.segunda)
        #expect(tarefa.status == .waiting)
        #expect(tarefa.area == .obras)
    }
}

@Suite("Normalização de português")
struct PortugueseTextTests {

    @Test("Acentos e cedilhas caem, sem depender de ICU")
    func acentos() {
        #expect(PortugueseText.normalizar("Orçamento à Distância") == "orcamento a distancia")
        #expect(PortugueseText.normalizar("SEGURANÇA") == "seguranca")
    }

    @Test("As barras das datas sobrevivem à tokenização")
    func tokenizacao() {
        #expect(PortugueseText.palavras("entregar dia 25/09, sem falta")
                == ["entregar", "dia", "25/09", "sem", "falta"])
    }

    @Test("Capitalizar a primeira não estraga siglas")
    func capitalizacao() {
        #expect(PortugueseText.capitalizarPrimeira("pagar IVA") == "Pagar IVA")
        #expect(PortugueseText.capitalizarPrimeira("") == "")
    }
}

@Suite("Datas em português corrente")
struct DateParserTests {

    private let parser = DateParserPT(calendario: Fixo.calendario)

    private func detectar(_ texto: String) -> Date? {
        parser.detectar(palavras: PortugueseText.palavras(texto), agora: Fixo.segunda)
    }

    private func dia(_ data: Date?) -> DateComponents? {
        data.map { Fixo.calendario.dateComponents([.year, .month, .day], from: $0) }
    }

    @Test("Hoje, amanhã e depois de amanhã")
    func relativas() {
        #expect(dia(detectar("fazer hoje"))?.day == 7)
        #expect(dia(detectar("fazer amanhã"))?.day == 8)
        #expect(dia(detectar("fazer depois de amanhã"))?.day == 9)
    }

    @Test("«dia 25» aponta para este mês quando ainda não passou")
    func diaDoMesFuturo() {
        let d = dia(detectar("entregar dia 25"))
        #expect(d?.day == 25)
        #expect(d?.month == 9)
    }

    @Test("«dia 3» já passou, logo é o mês seguinte")
    func diaDoMesPassado() {
        let d = dia(detectar("pagar dia 3"))
        #expect(d?.day == 3)
        #expect(d?.month == 10)
    }

    @Test("Data numérica com e sem ano")
    func numericas() {
        let a = dia(detectar("entregar 25/09"))
        #expect(a?.day == 25 && a?.month == 9 && a?.year == 2026)

        let b = dia(detectar("prazo 15/07/2027"))
        #expect(b?.day == 15 && b?.month == 7 && b?.year == 2027)

        // Já passou este ano, sem ano explícito: é o ano seguinte.
        let c = dia(detectar("renovar 10/03"))
        #expect(c?.year == 2027)
    }

    @Test("Mês por extenso")
    func porExtenso() {
        let d = dia(detectar("entregar a IES até 15 de julho"))
        #expect(d?.day == 15 && d?.month == 7)
    }

    @Test("Dia da semana aponta sempre para a próxima ocorrência, nunca hoje")
    func diasDaSemana() {
        // 7 de Setembro de 2026 é uma segunda-feira.
        #expect(dia(detectar("na sexta"))?.day == 11)
        #expect(dia(detectar("na segunda"))?.day == 14)
    }

    @Test("«para a semana» é daqui a sete dias")
    func proximaSemana() {
        #expect(dia(detectar("tratar disto para a semana"))?.day == 14)
    }

    @Test("«fim do mês» é o último dia do mês corrente")
    func fimDoMes() {
        let d = dia(detectar("fechar contas fim do mês"))
        #expect(d?.day == 30 && d?.month == 9)
    }

    @Test("Datas impossíveis devolvem nil em vez de saltarem para o mês seguinte")
    func datasImpossiveis() {
        #expect(detectar("31/02") == nil)
        #expect(detectar("40/13") == nil)
    }

    @Test("Texto sem data devolve nil — na dúvida, o ritual pergunta")
    func semData() {
        #expect(detectar("comprar cimento") == nil)
        #expect(detectar("") == nil)
    }
}

@Suite("Triagem — propriedades que não podem falhar")
struct TriagemInvariantesTests {

    private let triager = RuleBasedTriager(calendario: Fixo.calendario)

    @Test("O mesmo texto dá sempre o mesmo resultado")
    func determinismo() {
        // Um texto com sinais de duas áreas ao mesmo tempo, que antes dependia
        // da ordem de iteração de um dicionário.
        let texto = "falar com o cliente sobre a fatura da obra"
        let primeira = triager.analisar(texto, agora: Fixo.segunda)
        for _ in 0..<50 {
            let outra = triager.analisar(texto, agora: Fixo.segunda)
            #expect(outra.area == primeira.area)
            #expect(outra.confidence == primeira.confidence)
            #expect(outra.waitingOn == primeira.waitingOn)
        }
    }

    @Test("O dono conserva os acentos do que foi escrito")
    func donoComAcentos() {
        #expect(triager.analisar("pedir ao Vítor o preço", agora: Fixo.segunda).waitingOn == "Vítor")
        #expect(triager.analisar("falar com a Mónica sobre isto", agora: Fixo.segunda).waitingOn == "Mónica")
    }

    @Test("Palavras funcionais nunca são confundidas com donos", arguments: [
        "aguardar resposta",
        "aguardo o orçamento",
        "à espera do email",
    ])
    func naoInventaDonos(texto: String) {
        #expect(triager.analisar(texto, agora: Fixo.segunda).waitingOn == nil)
    }

    @Test("Nunca rebenta, seja qual for a entrada", arguments: [
        "", "   ", "a", "?!?!", "25/09", "1234567890",
        "áéíóú çãõ", "PEDIR AO CONTABILISTA",
    ])
    func robustez(texto: String) {
        let s = triager.analisar(texto, agora: Fixo.segunda)
        #expect(s.confidence >= 5 && s.confidence <= 95)
        #expect(s.estimatedMinutes > 0)
        #expect(!s.actionTitle.isEmpty)
    }
}
