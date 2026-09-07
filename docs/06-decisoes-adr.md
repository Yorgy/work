# 06 — Decisões de arquitectura (ADR)

Formato curto: contexto → decisão → consequência. O que se rejeitou importa tanto como o que se escolheu.

---

## ADR-001 — SwiftUI nativo, iOS 26+, sem compatibilidade retroactiva

**Contexto.** A app tem exactamente um utilizador e um dispositivo.

**Decisão.** Alvo mínimo iOS 26. Swift 6 com concorrência estrita.

**Consequência.** Acesso a Foundation Models, App Intents 2.0 e às APIs mais recentes de SwiftData sem código condicional. Se algum dia a app for para a App Store, isto revê-se — mas otimizar hoje para um cenário que provavelmente nunca acontece é custo garantido por benefício hipotético.

---

## ADR-002 — A partilha com a esposa faz-se por EventKit, não por CloudKit ⭐

**Contexto.** A área Família tem de ser partilhada. SwiftData [não suporta a base de dados partilhada do CloudKit](https://developer.apple.com/forums/thread/756721) e a alternativa oficial é `NSPersistentCloudKitContainer` (Core Data). Em iOS 26 há ainda [defeitos abertos em `CKShare`](https://developer.apple.com/forums/thread/788427).

**Decisão.** A área Família é uma **lista partilhada dos Lembretes da Apple**, lida e escrita por EventKit. Nenhum código de partilha é escrito.

**Consequência.** A restrição técnica desapareceu — mas o argumento decisivo nem sequer é técnico: **ela não vai instalar uma app compilada em Xcode.** Uma lista partilhada dos Lembretes funciona hoje no iPhone dela, sem instalação e sem manutenção. O custo é um mapeamento de campos com last-write-wins e o limite de que a Família não tem os campos ricos das outras áreas. Aceitável, e provavelmente até desejável.

**Rejeitado:** Core Data + `NSPersistentCloudKitContainer` (imposto arquitectural permanente por uma funcionalidade periférica) e sync próprio sobre `CKSyncEngine` (semanas de trabalho e uma classe inteira de bugs novos).

---

## ADR-003 — IA local a propor, humano a decidir

**Contexto.** Foundation Models corre um LLM de ~3B no dispositivo, grátis e offline. É bom a classificar, medíocre a julgar prioridades.

**Decisão.** A IA **só** propõe classificação na triagem. Nunca arquiva, nunca conclui, nunca reordena o dia sozinha. Toda a proposta passa pelo teu polegar.

**Consequência.** Mantém-se a confiança no sistema — o activo mais valioso e o mais frágil. Uma app que arquiva sozinha perde-se ao primeiro erro e nunca mais se recupera a confiança. Custo: continuas a passar 2 minutos por dia a confirmar. É o preço certo.

---

## ADR-004 — Cinco áreas fixas, não editáveis

**Contexto.** Todas as apps deixam criar categorias.

**Decisão.** Cinco áreas em código: Agência, Clientes, Família, Obras, Pessoal.

**Consequência.** Criar categorias novas é a forma mais comum de fugir ao trabalho de decidir — reorganizar a taxonomia sente-se produtivo e não produz nada. Cinco áreas cabem na cabeça e tornam o termómetro legível de relance. Se daqui a um ano faltar uma área, muda-se uma linha e recompila-se. Custo: cinco minutos de trabalho, uma vez.

---

## ADR-005 — Limites rígidos no plano do dia

**Contexto.** O sintoma central é "andar ao sabor do vento". Todas as apps deixam pôr tarefas infinitas no dia.

**Decisão.** 1 Rocha + 3 Pedras. Rígido. A quinta obriga a remover uma.

**Consequência.** Esta é a decisão mais importante do produto e a mais provável de irritar no início. Um limite que se pode ultrapassar não é um limite — é uma sugestão, e sugestões não resolvem problemas de compromisso. A fricção **é** a funcionalidade: obriga a escolher na véspera, que é exactamente o que hoje não acontece.

---

## ADR-006 — Sem ecrã de "todas as tarefas"

**Contexto.** Convenção universal em apps de tarefas.

**Decisão.** Não existe. O acesso ao conjunto completo faz-se por pesquisa e pelo ecrã de Áreas.

**Consequência.** Uma lista de 200 itens não é informação, é ansiedade formatada — e é meia causa do problema actual. O ecrã de Áreas responde a uma pergunta melhor: *o que estou a deixar cair?* em vez de *o que tenho para fazer?*

**Risco assumido:** pode dar sensação de perda de controlo nas primeiras semanas. Se ao fim de um mês de uso real a falta doer mesmo, revê-se — mas com dados, não com receio.

---

## ADR-007 — Fallback determinístico obrigatório na triagem

**Contexto.** Apple Intelligence pode não estar disponível (dispositivo, região, idioma) e a qualidade em pt-PT com vocabulário de obra e fiscalidade é uma incógnita até se medir.

**Decisão.** `TriageKit` expõe um protocolo com duas implementações: `FoundationModelsTriager` e `RuleBasedTriager` (palavras-chave, `NSDataDetector` para datas, heurísticas de "à espera"). Escolha em runtime por disponibilidade e por qualidade medida.

**Consequência.** A app nunca deixa de funcionar por causa da IA. Se a avaliação da semana 6 ficar abaixo do limiar, cai-se para regras sem reescrever nada. Custo: manter dois caminhos. Vale a pena — a alternativa é uma app que não abre em metade dos cenários.

---

## ADR-008 — Tesouraria fica para a v2

**Contexto.** A gestão financeira da agência é trabalho diário e com consequência legal, mas não foi escolhida para a v1.

**Decisão.** A v1 cobre a dimensão **temporal** do financeiro — prazos que geram tarefas automaticamente através de `RecurrenceTemplate`. Não cobre a dimensão **monetária** — saldos, previsões, contas a receber e a pagar.

**Consequência.** Correcto: um módulo de tesouraria é um produto inteiro (importação bancária, conciliação, IVA dedutível, categorização) e teria atrasado a v1 em meses, para resolver um problema que provavelmente já tens meio resolvido em Excel e com o contabilista. Os prazos, esses, estão hoje na tua cabeça — e é aí que a app entrega valor imediato.

**Reavaliar quando:** a v1 estiver estável há 3 meses. Se nessa altura o Excel continuar a chegar, a v2 não se faz.

---

## ADR-009 — `Domain` sem dependências de framework

**Contexto.** Testar SwiftData exige contentor em memória; testar EventKit exige simulador e permissões.

**Decisão.** As regras de negócio vivem em Swift puro, sem importar SwiftData, SwiftUI ou EventKit. A persistência mapeia para o domínio, não o contrário.

**Consequência.** Os invariantes que interessam — limites do plano, rotação de áreas, próxima acção obrigatória, cálculo de capacidade — testam-se em milissegundos. Se um dia SwiftData for substituído, o domínio não se mexe. Custo: uma camada de mapeamento. É barata e paga-se na primeira semana de refactoring.

---

## ADR-010 — Sem analytics, sem crash reporting, sem backend

**Contexto.** Convenção em qualquer app moderna.

**Decisão.** Nada sai do dispositivo excepto para o teu iCloud privado.

**Consequência.** Não é postura ideológica: **dados financeiros da empresa e informação sobre a tua filha não pertencem ao servidor de ninguém**, incluindo o de um SDK gratuito de crash reporting. Com um utilizador, os crashes vêem-se no Xcode ligado por cabo e as métricas de uso perguntam-se ao próprio. Custo real: zero.
