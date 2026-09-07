# 01 — Diagnóstico e método

## 1. O que a pesquisa diz (e o que dela se aproveita)

Foram avaliados sete sistemas estabelecidos. Nenhum serve inteiro; cada um contribui uma peça.

| Sistema | O que resolve mesmo | Onde falha neste caso | Aproveita-se |
|---|---|---|---|
| **[GTD](https://www.asianefficiency.com/task-management/gtd-intro/)** (Allen) | Captura universal + revisão semanal como garantia de que nada se perde | Contextos (`@telefone`, `@computador`) são um resíduo de 2001 — hoje tudo se faz no telemóvel. Sobrecarrega quem tem pouco tempo. | Ciclo capturar → clarificar → organizar → rever → executar. Lista "À espera de". Revisão semanal. |
| **[PARA](https://www.taskade.com/blog/the-para-method)** (Forte) | Organizar por accionabilidade, não por tema. Distingue Projecto (tem fim) de Área (nunca acaba) | É um sistema de notas, não de tarefas | A distinção Área/Projecto é a espinha dorsal. As cinco áreas são estáveis; os projectos entram e saem. |
| **[Time blocking / shutdown ritual](https://calnewport.com/drastically-reduce-stress-with-a-work-shutdown-ritual/)** (Newport) | O ritual de encerramento fecha os ciclos abertos e prepara o dia seguinte | Blocos de 4h de trabalho profundo são fantasia para quem tem filha pequena e obra a decorrer | O ritual de encerramento é o coração da app. Blocos reduzidos a 90 min. |
| **[Ivy Lee](https://jamesclear.com/ivy-lee)** | Escolher no dia anterior e ordenar por importância. Cem anos e continua a ganhar. | Seis tarefas é demasiado para um dia real com interrupções | Escolher na véspera + ordem estrita. Reduzido a 4. |
| **[Personal Kanban](https://flow-e.com/personal-kanban/wip/)** | Limites de trabalho em curso (WIP) contra a dispersão | O quadro visual é fricção num ecrã de 6 polegadas | O limite de WIP, sem o quadro. |
| **[Implementation intentions](https://pubmed.ncbi.nlm.nih.gov/22897132/)** (Gollwitzer) | Evidência sólida: "quando X, faço Y" melhora memória prospectiva vs. uma intenção vaga | Não é um sistema, é um mecanismo | Toda a tarefa planeada leva âncora de **quando** e **onde**. |
| **[Zeigarnik / Masicampo & Baumeister](https://yukaichou.com/behavioral-analysis/zeigarnik-effect-incomplete-tasks-memory-tension/)** | A tensão mental de uma tarefa aberta liberta-se com um **plano concreto**, não com a conclusão | Idem | Justifica porque o ritual da véspera reduz mesmo a ansiedade — e porque escrever a tarefa sozinho não chega. |

### A conclusão que orienta tudo

> A libertação mental não vem de ter a tarefa escrita. Vem de ter a tarefa **agendada**.
>
> É por isso que a app não é um sítio onde se guardam tarefas. É uma máquina que, todas as noites, converte um monte de coisas soltas em quatro compromissos com hora.

## 2. As três falhas, e o mecanismo para cada uma

### Falha 1 — Latência de captura
**Sintoma declarado:** *"não tenho uma maneira rápida de assentar coisas"*

O custo de captura tem de ser inferior ao custo de manter a ideia na cabeça. Na prática: **menos de 2 segundos e sem desbloquear o telemóvel.**

**Mecanismo:** Botão de Acção → grava voz → transcreve → cai na Inbox. Sem escolher área, sem escolher data, sem abrir a app. Também disponível em widget de ecrã bloqueado, Centro de Controlo e Siri.

**Regra de desenho inegociável:** o ecrã de captura **nunca** pede metadados. Nenhum campo além do texto. Cada campo adicional reduz a taxa de captura de forma desproporcionada — e uma ideia não capturada custa infinitamente mais do que uma ideia mal classificada.

### Falha 2 — Falta de confiança no sistema
**Sintoma declarado:** *"às vezes não sei bem que tarefas tenho, esqueço-me de coisas"*

Um sistema em que não se confia é pior do que nenhum, porque acrescenta culpa sem reduzir carga. A confiança constrói-se com duas garantias verificáveis:

1. **A Inbox chega sempre a zero** — todos os dias, no ritual das 21h. Não a zero "arrumado": a zero real.
2. **Nenhuma área fica escura sem aviso** — o termómetro de áreas mostra dias desde o último toque.

**Mecanismo:** Triagem em lote com pré-classificação pela IA local. Cada item da Inbox aparece já com área, projecto e data propostos. O gesto é confirmar ou corrigir — não preencher.

### Falha 3 — Ausência de compromisso
**Sintoma declarado:** *"gostava de me organizar no dia antes para não andar a adivinhar e andar ao sabor do vento"*

Aqui está a inovação real, e é uma restrição, não uma funcionalidade: **o dia tem capacidade finita e a app recusa-se a fingir o contrário.**

A capacidade disponível calcula-se, não se adivinha:

$$C_{disp} = H_{acordado} - H_{calendário} - H_{família} - H_{buffer}$$

com $H_{buffer} \approx 0{,}4 \times (H_{acordado} - H_{calendário} - H_{família})$

Um buffer de 40% não é pessimismo — é a única forma de um plano sobreviver a uma filha com febre ou a um cliente em pânico. Um plano que assume 100% de aproveitamento falha **todos os dias**, e um plano que falha todos os dias deixa de se fazer ao fim de três semanas.

**Mecanismo:** o plano do dia seguinte tem exactamente quatro lugares.

## 3. O modelo do dia: Rocha, Pedras, Areia

| Lugar | Quantidade | Duração | Natureza |
|---|---|---|---|
| **Rocha** | 1 | 60–90 min | O trabalho que exige cabeça. Se só isto acontecer, o dia foi bom. |
| **Pedras** | 3 | 15–45 min | Compromissos concretos. Ordenados: só se passa à seguinte quando a anterior fechar. |
| **Areia** | ilimitada | < 5 min | Batch. Faz-se numa passagem única, tipicamente ao fim da manhã. |

**A restrição que faz o sistema funcionar:** para adicionar uma quinta Pedra é obrigatório remover uma. A app não permite ultrapassar. Este é o momento em que se decide o dia — e é precisamente o momento que hoje não existe.

**Regra da rotação de áreas:** as 3 Pedras não podem pertencer todas à mesma área. Com cinco áreas em jogo, garantir variedade é mais valioso do que optimizar urgência. Sem esta regra, Trabalho consome tudo e Obras e Família apagam-se — que é exactamente o padrão a corrigir.

## 4. Os três rituais

### Encerramento — 21h00, 6 minutos (o produto)
Notificação às 21h. Não de manhã: **de manhã já é tarde para planear.**

1. **Esvaziar a Inbox** (~2 min) — swipe sobre propostas da IA. Direita aceita, esquerda descarta, toque corrige.
2. **Fechar o dia** (~1 min) — o que ficou por fazer: reagendar, largar ou passar a "À espera de". Nada transita em silêncio para amanhã.
3. **Escolher amanhã** (~2 min) — a app propõe 1 Rocha e 3 Pedras a partir de prazos, idade das tarefas e áreas frias. Aceitas ou trocas.
4. **Ancorar** (~1 min) — cada Pedra recebe um *quando* e um *onde*. É aqui que a intenção passa a implementation intention, e é a diferença entre lembrar e executar.

Termina com **"Fechado."** e o ecrã encerra. O sinal físico importa.

### Alinhamento — 07h30, 30 segundos
Widget e notificação com o plano já decidido. Nada se planeia de manhã. Só se lê.

### Revisão semanal — domingo, 20 minutos
1. Termómetro de áreas — qual esteve escura?
2. Lista "À espera de" — quem não respondeu há mais de 7 dias? Gera follow-ups.
3. Projectos sem próxima acção definida — o defeito mais comum e o mais silencioso.
4. Radar 14 dias — prazos fiscais, escola, obra, entregas a clientes.
5. Uma pergunta escrita: *o que correu mal esta semana e o que muda na próxima?*

## 5. Áreas e o caso particular da gestão financeira

Cinco áreas fixas: **Agência (Financeiro)**, **Clientes (Web)**, **Família**, **Obras**, **Pessoal**.

Sobre a área financeira — não foi escolhida como módulo da v1, e essa decisão está correcta: um módulo de tesouraria é um produto inteiro e teria atrasado tudo. Mas, sendo trabalho **diário e com prazos legais**, entra na v1 na forma que dá 80% do valor por 5% do esforço:

**Modelos de recorrência com pré-visualização.** Cada obrigação (IVA trimestral, retenções na fonte, Segurança Social, Modelo 22, IES) é um `RecurrenceTemplate` que gera automaticamente uma tarefa com antecedência configurável. A tarefa "Preparar IVA do 3.º trimestre" aparece na Inbox a 10 de Novembro, não a 25.

As datas-chave em Portugal ([Calendário Fiscal 2026](https://www.doutorfinancas.pt/impostos/calendario-fiscal-de-2026-as-datas-que-nao-pode-mesmo-falhar/), [prazos de IVA](https://calculariva.pt/declaracoes-prazos/prazos-iva/)):

- **IVA trimestral** (volume de negócios ≤ 650 000 €): entrega até dia 20 do 2.º mês seguinte ao trimestre; pagamento até dia 25 — **25 de Fevereiro, Maio, Setembro e Novembro**
- **Retenções na fonte de IRS/IRC**: dia 20 do mês seguinte
- **Segurança Social**: dias 10 a 20 do mês seguinte
- **Modelo 22 (IRC)**: até 31 de Maio
- **IES**: até 15 de Julho
- **Pagamentos por conta**: Julho, Setembro, Dezembro

> ⚠️ Estas datas são o ponto de partida, não a fonte de verdade. Confirmar sempre com o contabilista e com o [Portal das Finanças](https://info.portaldasfinancas.gov.pt/) — o regime concreto da empresa (mensal vs. trimestral, isenções, prorrogações) altera-as. A app deve mostrar a origem de cada data e permitir editá-la.

A tesouraria a sério — previsão de saldo, contas a receber, contas a pagar — fica para a v2, com justificação em [ADR-008](06-decisoes-adr.md).
