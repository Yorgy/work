import Foundation
import Testing
@testable import BussolaPersistence
import BussolaDomain

@Suite("Spool da Inbox — uma captura nunca pode falhar")
struct InboxSpoolTests {

    /// Directório próprio por teste, para não haver estado partilhado entre eles.
    private func spoolTemporario() -> (InboxSpool, URL) {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bussola-testes-\(UUID().uuidString)", isDirectory: true)
        return (InboxSpool(directory: base), base)
    }

    private func limpar(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Escrever e ler devolve a captura intacta")
    func idaEVolta() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        let original = Capture(
            text: "ver a caldeira com o Sr. Vítor",
            source: .actionButton,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try spool.escrever(original)

        let (capturas, ilegiveis) = try spool.pendentes()
        #expect(ilegiveis.isEmpty)
        #expect(capturas.count == 1)
        #expect(capturas.first?.id == original.id)
        #expect(capturas.first?.text == original.text)
        #expect(capturas.first?.source == .actionButton)
    }

    @Test("O directório é criado quando não existe — a captura não espera por setup")
    func criaDirectorio() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        #expect(!FileManager.default.fileExists(atPath: base.path))
        try spool.escrever(Capture(text: "primeira de todas"))
        #expect(FileManager.default.fileExists(atPath: base.path))
    }

    @Test("Ler um spool que nunca existiu devolve vazio, não um erro")
    func spoolInexistente() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        let (capturas, ilegiveis) = try spool.pendentes()
        #expect(capturas.isEmpty)
        #expect(ilegiveis.isEmpty)
        #expect(spool.contagemPendente() == 0)
    }

    @Test("As capturas saem por ordem de chegada — é a ordem por que se triam")
    func ordemCronologica() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        let agora = Date()
        let terceira = Capture(text: "terceira", createdAt: agora)
        let primeira = Capture(text: "primeira", createdAt: agora.addingTimeInterval(-200))
        let segunda = Capture(text: "segunda", createdAt: agora.addingTimeInterval(-100))

        // Escritas fora de ordem de propósito.
        try spool.escrever(terceira)
        try spool.escrever(primeira)
        try spool.escrever(segunda)

        let capturas = try spool.pendentes().capturas
        #expect(capturas.map(\.text) == ["primeira", "segunda", "terceira"])
    }

    @Test("Um ficheiro corrompido não leva as outras capturas atrás")
    func ficheiroCorrompidoNaoContamina() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        try spool.escrever(Capture(text: "boa"))
        try Data("isto não é JSON".utf8).write(
            to: base.appendingPathComponent("lixo.captura")
        )

        let (capturas, ilegiveis) = try spool.pendentes()
        #expect(capturas.count == 1)
        #expect(capturas.first?.text == "boa")
        #expect(ilegiveis.count == 1)
    }

    @Test("Um ficheiro ilegível vai para quarentena, não para o lixo")
    func quarentenaPreserva() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let mau = base.appendingPathComponent("mau.captura")
        try Data("corrompido".utf8).write(to: mau)

        try spool.quarentena(mau)

        #expect(!FileManager.default.fileExists(atPath: mau.path))
        let emQuarentena = base.appendingPathComponent("quarentena/mau.captura")
        #expect(FileManager.default.fileExists(atPath: emQuarentena.path))
        // E deixa de aparecer como pendente.
        #expect(try spool.pendentes().ilegiveis.isEmpty)
    }

    @Test("Remover tira o item da fila sem tocar nos outros")
    func remocaoSelectiva() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        let a = Capture(text: "a")
        let b = Capture(text: "b")
        try spool.escrever(a)
        try spool.escrever(b)

        try spool.remover(a.id)

        let capturas = try spool.pendentes().capturas
        #expect(capturas.count == 1)
        #expect(capturas.first?.id == b.id)
    }

    @Test("Remover algo que já não existe não rebenta")
    func remocaoIdempotente() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }
        #expect(throws: Never.self) { try spool.remover(UUID()) }
    }

    @Test("O áudio guarda-se e o caminho volta para a captura")
    func audioGuardado() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        let id = UUID()
        let caminho = try spool.guardarAudio(Data([0x00, 0x01, 0x02]), para: id)

        #expect(FileManager.default.fileExists(atPath: caminho))
        #expect(caminho.hasSuffix("\(id.uuidString).m4a"))
    }

    @Test("Escrever a mesma captura duas vezes não duplica")
    func escritaIdempotente() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        var captura = Capture(text: "rascunho")
        try spool.escrever(captura)
        captura.text = "versão corrigida"
        try spool.escrever(captura)

        let capturas = try spool.pendentes().capturas
        #expect(capturas.count == 1)
        #expect(capturas.first?.text == "versão corrigida")
    }

    @Test("Aguenta uma rajada de capturas sem perder nenhuma")
    func rajada() throws {
        let (spool, base) = spoolTemporario()
        defer { limpar(base) }

        for i in 0..<200 {
            try spool.escrever(Capture(text: "captura \(i)"))
        }
        #expect(try spool.pendentes().capturas.count == 200)
    }
}
