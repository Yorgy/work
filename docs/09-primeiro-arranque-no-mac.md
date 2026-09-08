# 09 — Primeiro arranque no Mac

Copia bloco a bloco. **Nenhuma linha leva comentários com `#`** — o zsh interactivo não os trata como comentários e passa-os como argumentos, que é o erro `unexpected arguments: '#', '115', 'testes,'`.

## 1. Clonar o repositório

```bash
cd ~/Developer 2>/dev/null || mkdir -p ~/Developer && cd ~/Developer
git clone https://github.com/Yorgy/work.git bussola
cd bussola
git checkout claude/personal-organization-app-7qlx7i
```

Se já tinhas o repositório clonado noutro sítio, basta `cd` até lá e `git pull origin claude/personal-organization-app-7qlx7i`.

**Tens de estar dentro da pasta do repositório.** Tudo o resto falha em `~`.

## 2. Instalar o XcodeGen

```bash
brew install xcodegen
```

Se não tiveres Homebrew: https://brew.sh

## 3. Correr os testes

```bash
swift test --package-path Packages/BussolaCore
```

São 115 testes, sem simulador. É aqui que compensa começar: se o domínio passar, a lógica que interessa está sã e o que sobrar são erros de interface, rápidos de resolver.

Para correr só um conjunto:

```bash
swift test --package-path Packages/BussolaCore --filter DayPlanTests
```

## 4. Verificações sem compilador

```bash
./Tools/verificar.sh
```

Se o zsh responder `permission denied`:

```bash
chmod +x Tools/verificar.sh
```

## 5. Gerar o projecto Xcode

O Team ID está em https://developer.apple.com/account → Membership Details → Team ID. São dez caracteres.

```bash
export DEVELOPMENT_TEAM=OTEUTEAMID
xcodegen generate
open Bussola.xcodeproj
```

Para não repetires o `export` a cada sessão:

```bash
echo 'export DEVELOPMENT_TEAM=OTEUTEAMID' >> ~/.zshrc
```

## 6. No Xcode

Em **Signing & Capabilities**, nos dois alvos (`Bussola` e `BussolaWidgets`):

- App Groups → `group.pt.bussola.app`
- iCloud → CloudKit, contentor `iCloud.pt.bussola.app`, só no alvo da app

Depois `⌘R` com o iPhone ligado por cabo.

## Se alguma coisa falhar

| Mensagem | O que é |
|---|---|
| `no such file or directory: ./Tools/verificar.sh` | Não estás dentro do repositório |
| `unexpected arguments: '#'` | Copiaste um comentário `#` para a linha de comando |
| `command not found: xcodegen` | Falta o passo 2 |
| `error: the package requires macOS 14` | Actualiza o macOS, ou corre os testes só ao domínio |
| Erros de assinatura no Xcode | Falta o `DEVELOPMENT_TEAM` ou a conta Apple Developer |
