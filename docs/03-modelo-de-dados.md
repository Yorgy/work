# 03 — Modelo de dados

## Diagrama

```
Area (5, fixas)
 │  nome, cor, símbolo, lastTouchedAt, targetTouchesPerWeek
 ├──< Project            nome, resultado, estado, dueDate, nextActionID
 │      └──< Task
 └──< Task               (tarefas soltas, sem projecto — legítimo)

Capture ──(triagem)──► Task | WaitingFor | Reference | descartado
 texto, áudio, criadoEm, localização?, origem

Task
 título, notas, área, projecto?, estado, energia, minutosEstimados,
 dueDate?, defersUntil?, âncoraQuando?, âncoraOnde?, externalID?, recurrenceID?

WaitingFor
 tarefa, dono, pedidoEm, followUpEm, canal, tarefaOriginal

DayPlan (1 por dia)
 data, rochaID?, pedraIDs [máx 3], areiaIDs, capacidadeMin,
 planeadoEm, fechadoEm?, resultado

RecurrenceTemplate
 título, área, regra (RRULE), diasDeAntecedência, fonteDaData
```

## Entidades

### `Area` — cinco, fixas
Não são editáveis por design. Cinco áreas cabem na cabeça; oito não. Criar áreas novas é a forma mais comum de fugir ao trabalho de decidir.

```
Agência (Financeiro) · Clientes (Web) · Família · Obras · Pessoal
```

`lastTouchedAt` alimenta o **termómetro de áreas**. O "toque" conta quando se **conclui** uma tarefa da área — não quando se olha para ela. Ver uma área não é atendê-la.

$$T_{area} = \text{dias desde } lastTouchedAt$$

| $T$ | Estado | Efeito |
|---|---|---|
| 0–3 | 🟢 Viva | — |
| 4–7 | 🟡 A arrefecer | Sinalizada na revisão semanal |
| 8–14 | 🟠 Fria | O planeador prioriza-a nas Pedras |
| > 14 | 🔴 Escura | Bloqueia o ritual das 21h até se decidir: agir ou pausar explicitamente |

Este último ponto é deliberadamente incómodo. Uma área escura durante duas semanas é sempre um problema — ou tem trabalho por fazer, ou devia estar oficialmente em pausa. O que não pode é ficar num limbo silencioso, que é exactamente o que acontece hoje com as Obras.

### `Task` — a unidade de execução

**Estados:** `inbox → next → planned → doing → done` | `waiting` | `someday` | `dropped`

Três campos que a maioria das apps não tem e que aqui são o essencial:

- **`energia`** (`.deep` | `.shallow` | `.admin`) — a Rocha exige `.deep`. Não se agenda trabalho profundo para as 17h30 de sexta.
- **`âncoraQuando` / `âncoraOnde`** — a [implementation intention](https://pubmed.ncbi.nlm.nih.gov/22897132/). "Depois de deixar a miúda na escola, no carro." Sem âncora, uma Pedra não pode entrar no plano.
- **`defersUntil`** — a tarefa existe mas não aparece. Diferente de `dueDate`. Sem isto, a Inbox enche-se de coisas que ainda não são para agora e o sistema perde credibilidade.

**Invariantes** (forçados no `Domain`, testados unitariamente):
1. Um `Project` activo tem sempre exactamente uma próxima acção. Se não tem, é um defeito e aparece na revisão semanal.
2. Um `DayPlan` tem no máximo 1 Rocha e 3 Pedras.
3. As Pedras de um `DayPlan` não podem pertencer todas à mesma área.
4. Nenhuma `Task` pode estar em `planned` sem `âncoraQuando`.
5. Uma `Task` em `waiting` tem obrigatoriamente `WaitingFor` com dono e `followUpEm`.

### `WaitingFor` — o estado que salva a credibilidade

Metade do teu trabalho é esperar por outros: o cliente que tem de aprovar a maquete, o contabilista que tem de enviar o mapa, o empreiteiro que ficou de dar preço. Este é o buraco onde se perdem dinheiro e confiança, e as apps de tarefas tratam-no como uma tarefa normal — o que é errado: **não é trabalho teu, é dívida de outra pessoa que tu tens de cobrar.**

Follow-up automático por canal:

| Canal | Follow-up por omissão |
|---|---|
| Email | 3 dias |
| WhatsApp / mensagem | 2 dias |
| Chamada telefónica | 1 dia |
| Formal (contabilista, entidade oficial) | 7 dias |

Quando a data chega, gera uma Task de follow-up com o texto já redigido pela IA local, pronta a copiar. A lista completa aparece na revisão semanal, ordenada por dias de silêncio. É o ecrã que mais rapidamente paga o custo de construir a app.

### `DayPlan` — o compromisso

Criado no ritual das 21h, imutável a partir das 00h — só o `resultado` se pode alterar durante o dia. Replanear a meio do dia é como se comeu ao sabor do vento.

`capacidadeMin` guarda a capacidade calculada, para se poder comparar plano com realidade ao fim de semanas e calibrar o buffer com dados em vez de opinião.

### `RecurrenceTemplate` — o motor fiscal e doméstico

Gera tarefas com antecedência a partir de uma regra RRULE. Serve tanto para o IVA trimestral como para a inspecção do carro ou o pagamento da creche.

`fonteDaData` guarda a origem da data (ex.: `"CIVA art. 41.º — confirmar com contabilista"`). Uma data sem origem não é confiável, e um sistema com datas fiscais não confiáveis é um passivo, não um activo.

## Migrações

`VersionedSchema` + `SchemaMigrationPlan` desde o **primeiro commit**, ainda que só exista a V1. Migrar SwiftData com CloudKit activo e dados reais no telemóvel sem plano de migração é a forma mais rápida de perder um ano de capturas.
