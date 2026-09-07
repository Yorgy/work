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
/// O reconhecimento é forçado a ser local (`requiresOnDeviceRecognition`): o que
/// se dita inclui números da empresa e o nome da filha, e isso não vai para
/// servidor nenhum.
@MainActor
@Observable
public final class Ditado {
    public private(set) var aGravar = false
    public private(set) var caminhoDoAudio: String?
    public private(set) var erro: String?

    private let motor = AVAudioEngine()
    private var pedido: SFSpeechAudioBufferRecognitionRequest?
    private var tarefa: SFSpeechRecognitionTask?
    private var ficheiro: AVAudioFile?
    private let reconhecedor = SFSpeechRecognizer(locale: Locale(identifier: "pt_PT"))

    public init() {}

    public func comecar(aoTranscrever: @escaping (String) -> Void) {
        erro = nil
        Task {
            guard await pedirAutorizacoes() else {
                erro = "Sem permissão para o microfone ou para o reconhecimento de voz. Podes escrever à mesma."
                return
            }
            do {
                try arrancarMotor(aoTranscrever: aoTranscrever)
                aGravar = true
            } catch {
                erro = "Não foi possível gravar. Escreve em vez de ditar."
                limpar()
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
        // O ficheiro fecha-se ao ser libertado; o caminho já ficou registado.
        ficheiro = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Privado

    private func pedirAutorizacoes() async -> Bool {
        let voz = await withCheckedContinuation { continuacao in
            SFSpeechRecognizer.requestAuthorization { continuacao.resume(returning: $0) }
        }
        guard voz == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private func arrancarMotor(aoTranscrever: @escaping (String) -> Void) throws {
        let sessao = AVAudioSession.sharedInstance()
        try sessao.setCategory(.record, mode: .measurement, options: .duckOthers)
        try sessao.setActive(true, options: .notifyOthersOnDeactivation)

        let pedido = SFSpeechAudioBufferRecognitionRequest()
        pedido.shouldReportPartialResults = true
        // Local, sempre. Se o dispositivo não suportar, prefere-se não transcrever
        // a mandar o áudio para fora.
        pedido.requiresOnDeviceRecognition = true
        self.pedido = pedido

        let entrada = motor.inputNode
        let formato = entrada.outputFormat(forBus: 0)
        ficheiro = try criarFicheiro(formato: formato)

        entrada.installTap(onBus: 0, bufferSize: 1024, format: formato) { [weak self] buffer, _ in
            pedido.append(buffer)
            // A mesma passagem alimenta o reconhecedor e o ficheiro.
            try? self?.ficheiro?.write(from: buffer)
        }

        tarefa = reconhecedor?.recognitionTask(with: pedido) { resultado, erroDaTarefa in
            if let resultado {
                Task { @MainActor in
                    aoTranscrever(resultado.bestTranscription.formattedString)
                }
            }
            if erroDaTarefa != nil, resultado == nil {
                Task { @MainActor in
                    // Sem transcrição, mas o áudio ficou. A captura não se perde.
                    self.erro = "Não consegui transcrever, mas o áudio ficou guardado."
                }
            }
        }

        motor.prepare()
        try motor.start()
    }

    private func criarFicheiro(formato: AVAudioFormat) throws -> AVAudioFile? {
        guard let base = InboxSpool.directorioDoAppGroup(BussolaStore.appGroupID) else { return nil }
        let pasta = base.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)

        let destino = pasta
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        caminhoDoAudio = destino.path
        return try AVAudioFile(forWriting: destino, settings: formato.settings)
    }

    private func limpar() {
        aGravar = false
        pedido = nil
        tarefa = nil
        ficheiro = nil
    }
}
