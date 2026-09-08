# Bússola — sistema operativo pessoal para iPhone

App nativa iOS que resolve um problema específico: **gerir cinco vidas em paralelo sem perder nada e sem acordar a adivinhar o dia.**

## O contexto

| Área | Natureza do trabalho | Falha típica |
|---|---|---|
| Financeira (agência de marketing) | Prazos rígidos, ciclos fixos, consequência legal | Datas que só se lembram tarde |
| Projectos web (clientes) | Trabalho profundo + espera por terceiros | Cliente que não responde e ninguém segue |
| Família (esposa, filha) | Logística contínua, partilhada | Perde sempre para o "trabalho" |
| Obras | Longo prazo, dependências, fornecedores | Fica meses parada sem se notar |
| Pessoal | Baixa urgência, alta importância | Invisível |

## A tese

O problema não é falta de uma app de tarefas. São **três falhas distintas** que a maioria das apps trata como uma só:

1. **Latência de captura** — a ideia surge onde não se pode escrever (carro, obra, reunião). Se capturar custa mais de 2 segundos, não se captura.
2. **Falta de confiança no sistema** — quando a lista não é fiável, o cérebro continua a fazer de lista. É o [efeito Zeigarnik](https://yukaichou.com/behavioral-analysis/zeigarnik-effect-incomplete-tasks-memory-tension/): a tensão de uma tarefa por fechar só se liberta quando existe um plano concreto para ela, não quando ela está escrita algures.
3. **Ausência de compromisso** — saber as tarefas não é ter decidido o dia. "Andar ao sabor do vento" é uma falha de decisão, não de memória.

As apps de mercado resolvem bem a #1 e falham a #2 e a #3. O resultado é sempre o mesmo: inbox com 400 itens, culpa acumulada, abandono ao fim de seis semanas.

**A Bússola é construída ao contrário: a captura é trivial, e o produto real é o ritual de 6 minutos das 21h que transforma captura em compromisso.**

## As cinco decisões que fazem a diferença

1. **Capturar e organizar nunca acontecem ao mesmo tempo.** Capturar nunca pede área, projecto nem data. A triagem é um ritual único diário, em lote, com a IA local do iPhone a pré-classificar para só confirmares.
2. **O dia tem orçamento, não lista.** 1 Rocha + 3 Pedras + Areia. Uma quinta tarefa obriga a remover outra. É este limite que mata o "sabor do vento".
3. **Termómetro de áreas.** A app mede dias desde o último toque em cada área e sinaliza as que estão a apagar-se. Com cinco áreas, o risco não é esquecer tarefas — é uma área inteira ficar escura durante um mês.
4. **"À espera de" é um estado de primeira classe**, com dono e follow-up automático. Metade do trabalho é esperar por clientes, contabilista e empreiteiros — e é aí que se perde dinheiro e credibilidade.
5. **A partilha com a esposa não se constrói.** Delega-se aos Lembretes da Apple. Ela não vai instalar uma app sideloaded.

## Estado

**MVP construído.** O domínio, a persistência, a triagem, os cinco ecrãs, os widgets e os App Intents estão escritos. Falta compilar num Mac — ver [08 — Como pôr isto a correr](docs/08-construir.md).

```
Packages/BussolaCore/   domínio, persistência e triagem · 99 testes
App/                    SwiftUI, cinco ecrãs
Shared/                 App Intents e instantâneo dos widgets
Widgets/                WidgetKit
project.yml             fonte de verdade do projecto Xcode (XcodeGen)
```

## Documentação

| Documento | Conteúdo |
|---|---|
| [01 — Diagnóstico e método](docs/01-diagnostico-e-metodo.md) | Pesquisa, o método escolhido, os rituais |
| [02 — Arquitectura](docs/02-arquitectura.md) | Stack, módulos, integrações, IA local |
| [03 — Modelo de dados](docs/03-modelo-de-dados.md) | Entidades, estados, invariantes |
| [04 — UX e ecrãs](docs/04-ux-ecras.md) | Os cinco ecrãs e porque não há um sexto |
| [05 — Roadmap](docs/05-roadmap.md) | Fases, esforço, critérios de sucesso |
| [06 — Decisões (ADR)](docs/06-decisoes-adr.md) | Decisões técnicas e o que se rejeitou |
| [07 — Fontes](docs/07-fontes.md) | Pesquisa consultada |
| [08 — Construir](docs/08-construir.md) | Do repositório ao iPhone |

## Aviso antes de escrever a primeira linha de Swift

Construir a app é a forma mais agradável de adiar a resolução do problema. A [Fase 0](docs/05-roadmap.md#fase-0--duas-semanas-sem-código) corre o método completo em Lembretes + Calendário durante duas semanas. Se não aguentares o ritual das 21h em papel, também não o aguentas em Swift — e é melhor descobrir isso em duas semanas do que em três meses.
