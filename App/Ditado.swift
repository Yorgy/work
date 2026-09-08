import Foundation
import Observation
import AVFoundation
import Speech
import BussolaDomain
import BussolaPersistence

/// Ditado com gravação simultânea.
///
/// A transcrição e o ficheiro de áudio saem da **mesma** passagem do microfone.
/// Não é uma optimização: transcrição de português com o ruído de uma obra ou de
/// um carro falha com frequência, e o áudio é a única rede de segurança que
/// resta na triagem. Guarda-se sempre, mesmo quando a transcrição parece boa.
///
/// O reconhecimento é forçado a local (`requiresOnDeviceRecognition`): o que se
/// dita inclui números da empresa e o nome da filha, e isso não vai para
/// servidor nenhum.
///
/// A transcrição publica-se como estado observável em vez de um callback. Com a
/// concorrência estrita do Swift 6, um callback que atravessa a fronteira da
/// thread de áudio para o `MainActor` obriga a marcar `@Sendable` uma closure
/// que captura um `Binding` — que não é `Sendable`. Publicar estado resolve o
/// problema em vez de o contornar.
@MainActor
@Observable
public final class Ditado {
    public private(set) var aGravar = false
    public private(set) var transcricao = ""
    public private(set) var caminhoDoAudio: String?
    public private(set) var aviso: String?

    private let motor = AVAudioEngine()
    private var pedido: SFSpeechAudioBufferRecognitionRequest?
    private var tarefa: SFSpeechRecognitionTask?
    private let reconhecedor = SFSpeechRecognizer(locale: Locale(identifier: "pt_PT"))

    public init() {}

    public func comecar() {
        guard !aGravar else { return }
        aviso = nil
        transcricao = ""
        Task {
            guard await pedirAutorizacoes() else {
                aviso = "Sem permissão para o microfone ou para a voz. Podes escrever à mesma."
                return
            }
            do {
                try arrancar()
                aGravar = true
            } catch {
                aviso = "Não foi possível gravar. Escreve em vez de ditar."
                desmontar()
            }
        }
    }

    public func parar() {
        guard aGravar else { return }
        motor.stop()
        motor.inputNode.removeTap(onBus: 0)
        pedido?.endAudio()
        tarefa?.finish()
        aGravar = false
        desmontar()
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Privado

    private func pedirAutorizacoes() async -> Bool {
        let voz = await withCheckedContinuation { continuacao in
            SFSpeechRecognizer.requestAuthorization { continuacao.resume(returning: $0) }
        }
        guard voz == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private func arrancar() throws {
        let sessao = AVAudioSession.sharedInstance()
        try sessao.setCategory(.record, mode: .measurement, options: .duckOthers)
        try sessao.setActive(true, options: .notifyOthersOnDeactivation)

        let pedido = SFSpeechAudioBufferRecognitionRequest()
        pedido.shouldReportPartialResults = true
        // Local, sempre. Se o dispositivo não suportar reconhecimento local,
        // prefere-se não transcrever a mandar o áudio para fora.
        pedido.requiresOnDeviceRecognition = true
        self.pedido = pedido

        let entrada = motor.inputNode
        let formato = entrada.outputFormat(forBus: 0)

        // O tap corre numa thread de áudio em tempo real, fora do MainActor.
        // O ficheiro é capturado por valor local em vez de ser alcançado através
        // de `self`, para nada isolado ao MainActor atravessar essa fronteira.
        //
        // `nonisolated(unsafe)` é a forma honesta de dizer o que aqui se passa:
        // AVAudioFile não é Sendable, e a segurança vem de só esta closure lhe
        // tocar enquanto o motor está a correr — o tap é removido antes de o
        // ficheiro ser largado.
        nonisolated(unsafe) let ficheiro = try criarFicheiro(formato: formato)

        entrada.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            pedido.append(buffer)
            try? ficheiro?.write(from: buffer)
        }

        tarefa = reconhecedor?.recognitionTask(with: pedido) { [weak self] resultado, erro in
            let texto = resultado?.bestTranscription.formattedString
            let falhou = erro != nil && resultado == nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let texto { self.transcricao = texto }
                if falhou {
                    // Sem transcrição, mas o áudio ficou. A captura não se perde,
                    // e é isso que interessa dizer.
                    self.aviso = "Não consegui transcrever, mas o áudio ficou guardado."
                }
            }
        }

        motor.prepare()
        try motor.start()
    }

    private func criarFicheiro(formato: AVAudioFormat) throws -> AVAudioFile? {
        guard let base = InboxSpool.directorioDoAppGroup(BussolaStore.appGroupID) else {
            // Sem App Group não há onde guardar o áudio. A transcrição continua
            // a funcionar; perde-se a rede de segurança, e isso avisa-se.
            aviso = "O áudio não vai ser guardado — falta o grupo partilhado."
            return nil
        }
        let pasta = base.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)

        let destino = pasta
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        caminhoDoAudio = destino.path
        return try AVAudioFile(forWriting: destino, settings: formato.settings)
    }

    private func desmontar() {
        pedido = nil
        tarefa = nil
    }
}
