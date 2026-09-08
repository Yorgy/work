# 05 — Roadmap

Estimativas em **noites de 2h e sábados de manhã** — não em dias de trabalho a tempo inteiro. É esse o teu recurso real.

---

## Fase 0 — Duas semanas, sem código

**Objectivo: provar que o método funciona antes de investir três meses a automatizá-lo.**

Este é o passo que mais gente salta e é o que decide o resultado. Construir a app é a forma mais agradável de adiar a resolução do problema — sente-se progresso enquanto a desorganização continua exactamente igual.

**Montagem (1 hora):**
- Lembretes da Apple com 5 listas: Agência, Clientes, Família *(partilhada com a esposa)*, Obras, Pessoal
- Botão de Acção → Atalho que grava e envia para a lista Inbox
- Alarme recorrente às 21h com o nome "Ritual"
- Uma nota no Notas com quatro títulos: Rocha / Pedras / Areia / À espera de

**Todas as noites, 6 minutos:** esvaziar a Inbox, fechar o dia, escolher 1+3 para amanhã, ancorar cada uma com quando e onde.

**Critério de passagem à Fase 1:** 10 dos 14 rituais cumpridos. Se não chegares lá, o problema não é a ferramenta e nenhuma app o resolve — nesse caso a conversa a ter é sobre a estrutura dos dias, não sobre Swift.

**Recolha obrigatória:** guarda as capturas em bruto das duas semanas num ficheiro de texto. São o conjunto de avaliação da IA na Fase 2, e são reais — muito melhores do que exemplos inventados.

---

## Fase 1 — O ciclo mínimo (~4 semanas · 30–35h)

O objectivo é ter algo no telemóvel **na segunda semana**, não uma app completa no fim.

| Semana | Entrega |
|---|---|
| 1 | Projecto Xcode, pacote SPM, `Domain` com invariantes e testes, SwiftData + CloudKit, ecrã Capturar |
| 2 | **App Intent + Botão de Acção + widget de captura.** Ponto de instalação no telemóvel. |
| 3 | Ecrã Hoje, `DayPlan` com limites, triagem manual (sem IA) |
| 4 | Ritual das 21h completo, os 4 passos, notificação |

**Critério de sucesso:** uma semana inteira a usar a app em vez dos Lembretes, com a Inbox a zero todas as noites.

Nesta fase a triagem é **manual e deliberadamente**. Serve para descobrires onde a IA tem valor real, em vez de o adivinhares — e para a app ser útil mesmo que a IA falhe.

---

## Fase 2 — Inteligência e áreas (~3 semanas · 20–25h)

| Semana | Entrega |
|---|---|
| 5 | `TriageKit` com Foundation Models + `@Generable` + fallback determinístico |
| 6 | **Avaliação com as 50 capturas da Fase 0.** Métrica: acerto de área ≥ 70%, acerto de tipo ≥ 80% |
| 7 | Termómetro de áreas, algoritmo de proposta de Rocha/Pedras, revisão semanal |

**Ponto de decisão da semana 6.** Se o modelo local ficar abaixo do limiar em pt-PT: aumentar exemplos few-shot no prompt e reavaliar; se continuar, cair para regras determinísticas e reconsiderar cloud na v2 ([ADR-007](06-decisoes-adr.md)). **Não arrastar uma IA medíocre** — uma proposta errada em cada três é pior do que nenhuma proposta, porque obriga a ler tudo com desconfiança.

---

## Fase 3 — Pontes com o mundo ✅ (~3 semanas · 20h)

| Semana | Entrega |
|---|---|
| 8 | ✅ EventKit leitura de calendário → capacidade real do dia |
| 9 | ✅ **Ponte com os Lembretes: área Família partilhada com a esposa** |
| 10 | ✅ `WaitingFor` com follow-ups automáticos, `RecurrenceTemplate` com o calendário fiscal PT |

A semana 9 é onde a Família deixa de ser uma lista tua e passa a ser trabalho partilhado a sério. A semana 10 é onde os prazos fiscais deixam de depender da tua memória.

---

## Fase 4 — Obras e polimento (~2 semanas · 15h)

- Área Obras com fases, fornecedores e dependências (a obra é o projecto mais longo e o que mais precisa de estrutura)
- Live Activity durante a Rocha
- Exportação JSON/Markdown
- Ecrã de diagnóstico do sync CloudKit
- Acessibilidade a sério: AX5, VoiceOver no ritual completo

---

## v2 — só depois de 3 meses de uso real

Por ordem de valor esperado:

1. **Módulo de tesouraria** — previsão de saldo, contas a receber e a pagar ([ADR-008](06-decisoes-adr.md))
2. **Calibração do buffer com dados** — plano vs. realidade ao longo de meses, para deixar de usar 40% por convenção
3. **Ligação a projectos de clientes** — GitHub, email, propostas
4. **App para Apple Watch** — captura por voz no pulso, ainda mais rápida
5. **Retrospectiva mensal** — tendências do termómetro ao longo do tempo

---

## Riscos, e o que se faz quanto a eles

| Risco | Prob. | O que se faz |
|---|---|---|
| **Abandonar o ritual das 21h** | **Alta** | O maior risco de todos, e não é técnico. Mitigação: Fase 0 valida o hábito antes do código; o ritual tem de caber mesmo em 6 min; e a app **não** pune faltas com culpa — retomar tem de ser trivial |
| Qualidade da IA local em pt-PT | Média | Avaliação medida na semana 6, com plano B pronto |
| Perfil de developer caduca de 7 em 7 dias | Alta | Conta Apple Developer (99 €/ano) dá 1 ano por instalação. **Fazer isto antes da Fase 1** |
| Sync CloudKit a falhar em silêncio | Média | Regras de esquema respeitadas desde o dia 1 + ecrã de diagnóstico |
| Deriva de âmbito (adicionar funcionalidades) | **Alta** | Cada nova ideia vai para a Inbox da própria app e é decidida na revisão semanal. Ironia intencional. |
| Migração SwiftData a corromper dados | Baixa | `VersionedSchema` desde o primeiro commit + exportação semanal automática |

## Custos

| Item | Custo |
|---|---|
| Apple Developer Program | 99 €/ano |
| iCloud (já tens) | 0 € |
| Foundation Models (on-device) | 0 € |
| Servidores | 0 € |
| **Total** | **99 €/ano** |

Requisito de hardware: **iPhone 15 Pro ou superior** (Apple Intelligence + Botão de Acção). Em iPhones anteriores a app funciona, mas sem triagem por IA e sem o caminho de captura mais rápido — que são precisamente as duas coisas que resolvem o teu problema.

## Esforço total até v1 completa

**≈ 90 horas** ao longo de 12 semanas. A noites e fins-de-semana, com uma filha em casa, conta com 16 semanas. Mas tens uma app utilizável ao fim da **semana 2** e o ciclo completo ao fim da **semana 4** — o valor não espera pelo fim.
