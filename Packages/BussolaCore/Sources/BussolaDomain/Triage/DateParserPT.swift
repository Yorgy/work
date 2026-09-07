import Foundation

/// Detecta datas em português corrente, do tipo que se dita a conduzir.
///
/// Cobre o que aparece mesmo nas capturas — "amanhã", "sexta", "dia 25",
/// "25/09" — e não tenta ser exaustivo. Uma data errada é pior do que nenhuma:
/// na dúvida, devolve `nil` e o ritual pergunta.
public struct DateParserPT: Sendable {
    private let calendario: Calendar
    /// Hora atribuída às datas sem hora explícita.
    private let horaPorOmissao: Int

    public init(calendario: Calendar = .current, horaPorOmissao: Int = 9) {
        self.calendario = calendario
        self.horaPorOmissao = horaPorOmissao
    }

    private static let diasDaSemana: [String: Int] = [
        // Índices de `Calendar`: 1 = domingo.
        "domingo": 1,
        "segunda": 2, "segundafeira": 2,
        "terca": 3, "tercafeira": 3,
        "quarta": 4, "quartafeira": 4,
        "quinta": 5, "quintafeira": 5,
        "sexta": 6, "sextafeira": 6,
        "sabado": 7,
    ]

    private static let meses: [String: Int] = [
        "janeiro": 1, "fevereiro": 2, "marco": 3, "abril": 4, "maio": 5, "junho": 6,
        "julho": 7, "agosto": 8, "setembro": 9, "outubro": 10, "novembro": 11, "dezembro": 12,
    ]

    public func detectar(palavras: [String], agora: Date = Date()) -> Date? {
        guard !palavras.isEmpty else { return nil }

        if palavras.contains("hoje") { return aoMeioDaManha(agora) }
        if palavras.contains("amanha") {
            if let d = calendario.date(byAdding: .day, value: 1, to: agora) { return aoMeioDaManha(d) }
        }
        if contemSequencia(palavras, ["depois", "de", "amanha"]) {
            if let d = calendario.date(byAdding: .day, value: 2, to: agora) { return aoMeioDaManha(d) }
        }
        if contemSequencia(palavras, ["proxima", "semana"])
            || contemSequencia(palavras, ["para", "a", "semana"]) {
            if let d = calendario.date(byAdding: .day, value: 7, to: agora) { return aoMeioDaManha(d) }
        }
        if contemSequencia(palavras, ["fim", "do", "mes"]) { return fimDoMes(agora) }

        if let numerica = dataNumerica(palavras: palavras, agora: agora) { return numerica }
        if let porExtenso = dataPorExtenso(palavras: palavras, agora: agora) { return porExtenso }
        if let doMes = diaDoMes(palavras: palavras, agora: agora) { return doMes }
        if let semana = proximoDiaDaSemana(palavras: palavras, agora: agora) { return semana }

        return nil
    }

    // MARK: - Formas

    /// "25/09", "25-09", "25/09/2026"
    private func dataNumerica(palavras: [String], agora: Date) -> Date? {
        for palavra in palavras {
            let partes = palavra.split(whereSeparator: { $0 == "/" || $0 == "-" }).map(String.init)
            guard partes.count >= 2,
                  let dia = Int(partes[0]), let mes = Int(partes[1]),
                  (1...31).contains(dia), (1...12).contains(mes) else { continue }

            let ano: Int
            if partes.count >= 3, let lido = Int(partes[2]) {
                ano = lido < 100 ? 2000 + lido : lido
            } else {
                ano = calendario.component(.year, from: agora)
            }

            guard let data = montar(ano: ano, mes: mes, dia: dia) else { continue }
            // Sem ano explícito e já passou: quis dizer o ano que vem.
            if partes.count < 3, data < calendario.startOfDay(for: agora) {
                return montar(ano: ano + 1, mes: mes, dia: dia)
            }
            return data
        }
        return nil
    }

    /// "25 de setembro", "15 de julho"
    private func dataPorExtenso(palavras: [String], agora: Date) -> Date? {
        for (indice, palavra) in palavras.enumerated() {
            guard let dia = Int(palavra), (1...31).contains(dia) else { continue }
            // O mês vem logo a seguir, ou depois de "de".
            let candidatos = [indice + 1, indice + 2].filter { $0 < palavras.count }
            for posicao in candidatos {
                guard let mes = Self.meses[palavras[posicao]] else { continue }
                let ano = calendario.component(.year, from: agora)
                guard let data = montar(ano: ano, mes: mes, dia: dia) else { continue }
                if data < calendario.startOfDay(for: agora) {
                    return montar(ano: ano + 1, mes: mes, dia: dia)
                }
                return data
            }
        }
        return nil
    }

    /// "dia 25", "até dia 25", "no dia 25"
    private func diaDoMes(palavras: [String], agora: Date) -> Date? {
        for (indice, palavra) in palavras.enumerated() where palavra == "dia" {
            guard indice + 1 < palavras.count,
                  let dia = Int(palavras[indice + 1]), (1...31).contains(dia) else { continue }

            let ano = calendario.component(.year, from: agora)
            let mes = calendario.component(.month, from: agora)
            guard let esteMes = montar(ano: ano, mes: mes, dia: dia) else { continue }
            if esteMes >= calendario.startOfDay(for: agora) { return esteMes }

            // Já passou este mês: é o mês seguinte.
            let proximoMes = mes == 12 ? 1 : mes + 1
            let proximoAno = mes == 12 ? ano + 1 : ano
            return montar(ano: proximoAno, mes: proximoMes, dia: dia)
        }
        return nil
    }

    /// "sexta", "na segunda" — sempre a próxima ocorrência, nunca hoje.
    private func proximoDiaDaSemana(palavras: [String], agora: Date) -> Date? {
        for palavra in palavras {
            guard let alvo = Self.diasDaSemana[palavra] else { continue }
            let hoje = calendario.component(.weekday, from: agora)
            var delta = alvo - hoje
            if delta <= 0 { delta += 7 }
            guard let data = calendario.date(byAdding: .day, value: delta, to: agora) else { continue }
            return aoMeioDaManha(data)
        }
        return nil
    }

    private func fimDoMes(_ agora: Date) -> Date? {
        let ano = calendario.component(.year, from: agora)
        let mes = calendario.component(.month, from: agora)
        var componentes = DateComponents()
        componentes.year = mes == 12 ? ano + 1 : ano
        componentes.month = mes == 12 ? 1 : mes + 1
        componentes.day = 1
        componentes.hour = horaPorOmissao
        guard let primeiroDoSeguinte = calendario.date(from: componentes) else { return nil }
        return calendario.date(byAdding: .day, value: -1, to: primeiroDoSeguinte)
    }

    // MARK: - Utilitários

    private func montar(ano: Int, mes: Int, dia: Int) -> Date? {
        var componentes = DateComponents()
        componentes.year = ano
        componentes.month = mes
        componentes.day = dia
        componentes.hour = horaPorOmissao
        guard let data = calendario.date(from: componentes) else { return nil }
        // `Calendar` normaliza 31 de Fevereiro para Março; isso não é a data
        // que a pessoa quis dizer, é ruído.
        guard calendario.component(.day, from: data) == dia,
              calendario.component(.month, from: data) == mes else { return nil }
        return data
    }

    private func aoMeioDaManha(_ data: Date) -> Date? {
        calendario.date(
            bySettingHour: horaPorOmissao, minute: 0, second: 0, of: data
        )
    }

    private func contemSequencia(_ palavras: [String], _ sequencia: [String]) -> Bool {
        guard sequencia.count <= palavras.count else { return false }
        for inicio in 0...(palavras.count - sequencia.count) {
            if Array(palavras[inicio..<(inicio + sequencia.count)]) == sequencia { return true }
        }
        return false
    }
}
