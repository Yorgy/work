# 10 — Continuar no Mac com o Claude Code

A sessão que escreveu este código corre num container Linux na cloud: não tem Xcode, não tem toolchain Swift, e não vê o teu Mac. Nunca compilou nada disto.

O Claude Code instalado no teu Mac não tem esse problema. Corre no teu terminal, com acesso ao Xcode, ao `swift`, ao simulador e ao iPhone ligado por cabo.

## Como arrancar

```bash
cd ~/Developer/bussola
git pull
claude
```

E cola o prompt abaixo.

---

## Prompt de arranque

> Este repositório é uma app iOS chamada Bússola, escrita por outra sessão do Claude Code que corria num container Linux sem Xcode nem toolchain Swift. **O código nunca foi compilado.** Passou por três verificações estáticas (`./Tools/verificar.sh`) que confirmam estrutura, assinaturas e imports, mas nada de tipos, genéricos, overloads, protocolos ou concorrência.
>
> Lê primeiro o `CLAUDE.md` — tem as convenções, os invariantes e as armadilhas conhecidas.
>
> **Objectivo:** pôr a app a correr no meu iPhone.
>
> Ordem que quero:
>
> 1. `xcode-select -p`. Se não apontar para dentro do `Xcode.app`, diz-me o comando para eu correr com sudo.
> 2. `swift test --package-path Packages/BussolaCore` — 115 testes, sem simulador. Corrige os erros de compilação até passarem.
> 3. Instalar o XcodeGen se faltar (o guia em `docs/09-primeiro-arranque-no-mac.md` tem uma via sem Homebrew), `xcodegen generate`, e compilar para o simulador.
> 4. Corrigir os erros da app e dos widgets até compilar.
> 5. Correr no simulador e dizer-me o que vês nos ecrãs.
>
> **Regras enquanto corriges:**
>
> - Os invariantes do `CLAUDE.md` não se relaxam para fazer compilar. Se um deles for o que está a impedir a compilação, pára e explica-me antes de mexer.
> - Se um teste falhar, o mais provável é o teste estar certo e o código errado. Percebe qual antes de mudar o teste.
> - Não simplifiques funcionalidade para contornar um erro. Prefiro um erro por resolver a uma funcionalidade que desapareceu em silêncio.
> - Português de Portugal em código, comentários e commits.
>
> Vai commitando por etapas no ramo `claude/personal-organization-app-7qlx7i`, com mensagens que digam o que estava errado e porquê. No fim faz `git push` para eu ter tudo.
>
> Onde espero problemas, por ordem de probabilidade: os tipos `@Generable` do FoundationModels em `BussolaTriage`, a conformidade a Swift 6 do `App/Ditado.swift` (tap de áudio fora do MainActor), o `nonisolated(unsafe)` no `EKEventStore` em `BussolaBridge`, e os predicados `#Predicate` do SwiftData em `BussolaStore.swift`.

---

## Depois

Quando estiver a compilar, precisas ainda de:

- Conta Apple Developer (99 €/ano) — sem ela o perfil caduca de 7 em 7 dias
- App Groups (`group.pt.bussola.app`) e iCloud (`iCloud.pt.bussola.app`) nos dois alvos
- **Definições → Botão de Ação → Atalho → Bússola → Capturar** — é isto que faz o sistema todo funcionar

O passo a passo completo está em [`docs/08-construir.md`](08-construir.md).
