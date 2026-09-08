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

## 2. Apontar as ferramentas para o Xcode

O macOS traz um Swift nas *Command Line Tools*, separado e mais antigo do que o do Xcode. Se o `swift` que corres vier de `/Library/Developer/CommandLineTools/`, é esse. Confirma com:

```bash
xcode-select -p
```

Se **não** responder algo terminado em `/Applications/Xcode.app/Contents/Developer`, aponta-o para o Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
swift --version
```

Isto é obrigatório para compilar a app (o SDK do iOS 26 e o FoundationModels só existem no Xcode). Para correr os testes do pacote não é estritamente necessário, mas evita confusões.

## 3. Correr os testes

**Este passo não precisa de XcodeGen nem de Homebrew.** É o que dá informação a sério.

```bash
swift test --package-path Packages/BussolaCore
```

São 115 testes, sem simulador. Se o domínio passar, a lógica que interessa está sã e o que sobrar são erros de interface, rápidos de resolver.

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

## 5. Instalar o XcodeGen

Só é preciso a partir daqui. Duas vias.

**Sem Homebrew** — binário pré-compilado, fica só neste utilizador e não instala nada no sistema:

```bash
mkdir -p ~/.local/bin
curl -L -o /tmp/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
unzip -o /tmp/xcodegen.zip -d /tmp/xcodegen
cp -R /tmp/xcodegen/bin/* ~/.local/bin/
cp -R /tmp/xcodegen/share ~/.local/share 2>/dev/null || true
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
xcodegen --version
```

O macOS vai bloquear o binário à primeira execução por não estar assinado. Resolve-se com:

```bash
xattr -dr com.apple.quarantine ~/.local/bin/xcodegen
```

**Com Homebrew**, se preferires instalá-lo (demora mais e pede a tua palavra-passe):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install xcodegen
```

## 6. Gerar o projecto Xcode

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

## 7. No Xcode

Em **Signing & Capabilities**, nos dois alvos (`Bussola` e `BussolaWidgets`):

- App Groups → `group.pt.bussola.app`
- iCloud → CloudKit, contentor `iCloud.pt.bussola.app`, só no alvo da app

Depois `⌘R` com o iPhone ligado por cabo.

## Se alguma coisa falhar

| Mensagem | O que é |
|---|---|
| `no such file or directory: ./Tools/verificar.sh` | Não estás dentro do repositório |
| `unexpected arguments: '#'` | Copiaste um comentário `#` para a linha de comando |
| `command not found: xcodegen` | Falta o passo 5. Não é preciso para os testes |
| `command not found: brew` | Não tens Homebrew. Usa a via sem Homebrew do passo 5 |
| `xcodegen não pode ser aberto` | Gatekeeper. Corre o `xattr -dr com.apple.quarantine` |
| `error: 'v26' is unavailable` | Toolchain antigo a ler um pacote que pedia iOS 26. Já corrigido — faz `git pull` |
| `-package-description-version 6.0.0` no erro | O `swift` a correr vem das Command Line Tools. Ver passo 2 |
| Erros de assinatura no Xcode | Falta o `DEVELOPMENT_TEAM` ou a conta Apple Developer |
