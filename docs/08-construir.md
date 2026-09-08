# 08 — Como pôr isto a correr no teu iPhone

## O que precisas

| | |
|---|---|
| Mac com **Xcode 26** ou superior | SwiftUI, SwiftData e Foundation Models de iOS 26 |
| **iPhone 15 Pro** ou superior | Apple Intelligence e Botão de Acção |
| Conta **Apple Developer** (99 €/ano) | Sem ela o perfil caduca de 7 em 7 dias e a app deixa de abrir |
| **XcodeGen** | `brew install xcodegen` |

> A conta paga faz-se **antes** de começar, não depois. Com a conta gratuita a app deixa de abrir ao fim de uma semana, e uma app de organização em que não se pode confiar é pior do que nenhuma.

## Passos

```bash
# 1. Gerar o projecto (o .xcodeproj não está no repositório, por desenho)
export DEVELOPMENT_TEAM=XXXXXXXXXX   # o teu Team ID, em developer.apple.com
xcodegen generate

# 2. Correr os testes do domínio antes de abrir o Xcode — são rápidos
swift test --package-path Packages/BussolaCore

# 3. Abrir
open Bussola.xcodeproj
```

No Xcode, em **Signing & Capabilities**, confirmar nos dois alvos (`Bussola` e `BussolaWidgets`):

- **App Groups** → `group.pt.bussola.app`
- **iCloud** → CloudKit, contentor `iCloud.pt.bussola.app` *(só no alvo da app)*

Os identificadores têm de ser criados uma vez no portal da Apple. Se preferires outro prefixo, muda em três sítios: `project.yml`, os dois `.entitlements`, e as constantes `BussolaStore.appGroupID` e a do contentor iCloud em `BussolaStore.init`.

## Configurar o Botão de Acção

Depois da primeira instalação: **Definições → Botão de Ação → Atalho → Bússola → Capturar**.

É esta configuração que faz o sistema todo funcionar. Sem ela, capturar volta a custar dez segundos e cinco toques — e a essa distância não se captura.

## Verificar que ficou bem

1. **Botão de Acção com o ecrã bloqueado** → dita qualquer coisa. Não deve pedir para desbloquear.
2. **Abrir a app** → a captura tem de aparecer na Inbox. Se não aparecer, o App Group não está bem configurado.
3. **Revisão → Estado** → deve dizer "Ligado ao iCloud". Se disser outra coisa, a mensagem explica porquê.
4. **Ritual** → percorrer os quatro passos até "Fechado."
5. **Widget "Hoje"** no ecrã principal → tem de mostrar a Rocha que acabaste de escolher.

## Sem toolchain Swift à mão

O verificador estrutural apanha chavetas, parênteses e aspas desequilibradas, que é a classe de erros que se comete a escrever muito código de uma vez:

```bash
python3 Tools/verificar_estrutura.py Packages/
python3 Tools/verificar_estrutura.py App/
```

Não substitui `swift build` — não sabe nada de tipos.

## Estrutura

```
Packages/BussolaCore/
  Sources/BussolaDomain/       Swift puro. Testável em qualquer plataforma.
  Sources/BussolaPersistence/  SwiftData + CloudKit + spool do App Group
  Sources/BussolaTriage/       Foundation Models
  Tests/                       99 testes
App/                           SwiftUI: 5 ecrãs
Shared/                        App Intents e o instantâneo dos widgets
                               (compilado nos dois alvos)
Widgets/                       WidgetKit
project.yml                    A fonte de verdade do projecto Xcode
```

## Quando alguma coisa correr mal

| Sintoma | Causa quase certa |
|---|---|
| Capturas do Botão de Acção não aparecem | App Group em falta num dos alvos, ou identificadores diferentes entre eles |
| "Ligado ao iCloud" nunca aparece | Sessão iCloud não iniciada, ou o contentor não existe no portal |
| Dados não passam para outro dispositivo | Alguma propriedade nova sem valor por omissão. Ver as regras de esquema em `Records.swift` |
| Triagem sempre com confiança baixa | Apple Intelligence desligado. Ver Definições — a app diz a razão exacta |
| A app deixou de abrir ao fim de uma semana | Perfil gratuito caducado. É para isto que serve a conta paga |
