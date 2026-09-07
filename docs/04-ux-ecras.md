# 04 — UX e ecrãs

## Princípio: cinco ecrãs, e a defesa activa contra o sexto

Cada ecrã novo é uma decisão nova a tomar todos os dias. A app tem cinco ecrãs porque o teu problema tem cinco momentos — não porque cinco seja um número bonito.

| # | Ecrã | Momento | Duração |
|---|---|---|---|
| 1 | **Capturar** | Ao longo do dia, dezenas de vezes | < 2 s |
| 2 | **Hoje** | De manhã e entre tarefas | 10 s |
| 3 | **Ritual** | 21h, todos os dias | 6 min |
| 4 | **Áreas** | Quando queres ver o todo | 1 min |
| 5 | **Revisão** | Domingo | 20 min |

Não há ecrã de "Todas as tarefas". Deliberadamente. Uma lista com 200 itens não é informação — é ansiedade formatada, e é meia causa do problema actual.

---

## 1. Capturar

Fora da app na maior parte dos casos: Botão de Acção, Siri, widget de ecrã bloqueado, Centro de Controlo.

Dentro da app, um único campo e um botão grande de microfone. **Sem selector de área. Sem data. Sem projecto.** Um háptico confirma e o ecrã fecha.

> A tentação de "só mais um campinho para escolher a área" é a que mata o sistema. Cada campo reduz a taxa de captura, e uma ideia não capturada custa mais do que dez ideias mal classificadas — porque as mal classificadas corrigem-se em 3 segundos na triagem e a não capturada está perdida para sempre.

## 2. Hoje

O ecrã de omissão. Estrutura vertical, sem separadores:

```
┌──────────────────────────────────┐
│  Terça, 8 de Setembro            │
│                                  │
│  🪨 ROCHA        09h00 · 90 min  │
│  Fechar a proposta do cliente X  │
│  ↳ no escritório, café na mão    │
│  ─────────────────────────────── │
│  ⬤ 1. Enviar mapa ao contabilista│
│  ○ 2. Pedir preço da caldeira    │
│  ○ 3. Marcar pediatra da Matilde │
│  ─────────────────────────────── │
│  🏖 Areia (6)              ▾     │
│                                  │
│  ⏳ À espera de 4 pessoas   ▾    │
└──────────────────────────────────┘
```

- A Rocha domina visualmente. É a única coisa que tem de acontecer.
- As Pedras estão **numeradas e ordenadas** ([Ivy Lee](https://jamesclear.com/ivy-lee)): a 2 só se activa quando a 1 fecha. O ecrã não é um buffet.
- A Areia está colapsada. Só se abre no batch.
- "À espera de" está sempre visível mas discreto — é consciência, não acção.

**Não existe botão de adicionar tarefa a este ecrã.** Adicionar ao dia é sempre um acto do ritual. Se algo urgente aparece a meio do dia, entra pela Captura como qualquer outra coisa. A defesa contra a interrupção é arquitectural, não de força de vontade.

## 3. Ritual (21h) — o ecrã que é o produto

Quatro passos em ecrã inteiro, com barra de progresso. Não se pode saltar passos.

**Passo 1 — Esvaziar (~2 min).** Cartões empilhados, um por captura, cada um já com a proposta da IA:

```
┌──────────────────────────────────┐
│  "ver a caldeira com o Sr. Vítor"│
│  ▶ ouvir original (0:04)         │
│  ─────────────────────────────── │
│  🔨 Obras · ⏳ à espera · 88%    │
│  Dono: Sr. Vítor · follow-up 3d  │
│                                  │
│  ← descartar   ✎ corrigir   →    │
└──────────────────────────────────┘
```

Confiança < 60% abre o cartão para edição em vez de propor swipe.

**Passo 2 — Fechar o dia (~1 min).** O que ficou por fazer, uma escolha obrigatória por item: **reagendar · largar · à espera de**. Nada transita para amanhã em silêncio — é isso que produz a lista fantasma que já não se acredita.

**Passo 3 — Escolher amanhã (~2 min).** A app propõe, tu decides:

```
Capacidade de amanhã: 3h20
(8h úteis − 3h de calendário − 1h40 de buffer)

🪨 Rocha sugerida:  Proposta do cliente X   [trocar]
⬤ Pedras:
   1. Mapa para o contabilista  💼  [trocar]
   2. Preço da caldeira         🔨  [trocar]  ← Obras há 11 dias
   3. Pediatra da Matilde       👨‍👩‍👧  [trocar]

⚠️ 5 tarefas excedem a capacidade. Remove uma.
```

O algoritmo de proposta pondera:

$$S = 3 \cdot U_{prazo} + 2 \cdot F_{area} + 1{,}5 \cdot B_{desbloqueia} + 1 \cdot I_{idade} - 2 \cdot X_{excesso}$$

- $U_{prazo}$ — urgência por prazo
- $F_{area}$ — frieza da área (peso alto: é o antídoto contra o trabalho engolir tudo)
- $B_{desbloqueia}$ — a tarefa desbloqueia terceiros? Tem prioridade: liberta trabalho de outra pessoa
- $I_{idade}$ — dias na lista sem ser tocada
- $X_{excesso}$ — penaliza uma segunda tarefa da mesma área

**Passo 4 — Ancorar (~1 min).** Cada Pedra recebe *quando* e *onde*, escolhidos a partir de sugestões contextuais ("depois do pequeno-almoço", "no carro a caminho da obra"). É o passo que a maioria das pessoas quer saltar e é o que tem a melhor evidência científica por trás.

Termina em **"Fechado."**, ecrã a escurecer. O fecho físico importa: é o sinal de que o dia acabou.

## 4. Áreas — o termómetro

Cinco cartões, cor por temperatura. Não mostra contagens de tarefas (isso é ansiedade); mostra **atenção**.

```
💼 Agência       🟢  tocada hoje          3 abertas
💻 Clientes      🟢  há 2 dias            7 abertas · 2 à espera
👨‍👩‍👧 Família       🟡  há 5 dias            4 abertas
🔨 Obras         🔴  há 16 dias           9 abertas · 3 à espera
🌱 Pessoal       🟠  há 9 dias            2 abertas
```

Este ecrã responde à pergunta que hoje não tem resposta: *"o que é que eu estou a deixar cair?"* — que é uma pergunta muito melhor do que *"o que é que eu tenho para fazer?"*

## 5. Revisão semanal

Cinco secções, 20 minutos, tudo em ecrã único com scroll:

1. **Termómetro** — que área esteve escura e o que se faz quanto a isso
2. **À espera de** — ordenada por dias de silêncio, com botão para gerar follow-ups em lote
3. **Projectos sem próxima acção** — o defeito silencioso mais comum
4. **Radar 14 dias** — fiscal, escola, obra, entregas
5. **Uma pergunta** — *o que correu mal e o que muda?* Texto livre, guardado, revisto no mês seguinte

---

## Widgets

| Widget | Tamanho | Conteúdo |
|---|---|---|
| Captura | pequeno / ecrã bloqueado | Um botão. Grava e guarda sem abrir a app. |
| Hoje | médio | Rocha + as 3 Pedras com estado |
| Termómetro | pequeno | As cinco áreas, só cores |

**Live Activity** durante a Rocha: tempo decorrido no ecrã bloqueado e na Ilha Dinâmica. Não é um cronómetro Pomodoro — é um lembrete visível de que existe um compromisso a decorrer.

## Notificações — exactamente três

| Hora | Conteúdo |
|---|---|
| 21h00 | *"6 minutos para amanhã não ser adivinhado."* |
| 07h30 | A Rocha do dia, e mais nada |
| Dom 20h00 | Revisão semanal |

Três. Uma app de organização que interrompe é uma contradição, e a quarta notificação é aquela em que se desliga tudo.

## Acessibilidade e realidade física

Estas não são caixas a assinalar — são requisitos que decorrem de onde a app vai ser usada:

- **Dynamic Type até AX5.** Vais ler isto na obra, com pó, sem óculos.
- **Alvos de toque ≥ 44 pt** e a captura funciona com uma mão, com o polegar, ao alcance do fundo do ecrã.
- **VoiceOver completo** no ritual — funciona a conduzir, por voz.
- **Modo escuro real.** O ritual é às 21h, no escuro, com a criança a dormir ao lado.
- **A cor nunca é o único sinal.** O termómetro tem cor *e* texto ("há 16 dias").
