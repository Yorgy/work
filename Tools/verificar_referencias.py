#!/usr/bin/env python3
"""
Análise de referências cruzadas em Swift, sem compilador.

Cobre a classe de erro que o verificador estrutural não vê e que é a mais
provável quando se escreve muito código de uma vez: chamar um tipo com
argumentos que não correspondem à sua declaração, e referir tipos que não
existem em lado nenhum.

Não é um compilador. Não resolve genéricos, extensões, herança nem overloads,
por isso reporta *suspeitas*, não erros. Cada uma tem de ser confirmada à mão.

Uso: python3 Tools/verificar_referencias.py [raiz...]
"""
import sys, re, pathlib
from collections import defaultdict

# Tipos do sistema e das frameworks: conhecê-los todos é impossível, por isso a
# regra é o contrário — só se reportam tipos declarados NESTE repositório.
DECL = re.compile(
    r'^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+|final\s+|@\w+\s+)*'
    r'(struct|class|enum|actor|protocol)\s+([A-Z]\w*)', re.M)

# `let x: T` / `var x: T = ...` ao nível de membro, para o init memberwise.
MEMBRO = re.compile(
    r'^ {4}(?P<wrapper>@\w+(?:\([^)]*\))?\s+)?'
    r'(?:public\s+|internal\s+|private\s+|fileprivate\s+)?'
    r'(?P<wrapper2>@\w+(?:\([^)]*\))?\s+)?'
    r'(?P<palavra>let|var)\s+(?P<nome>[a-z_]\w*)\s*:\s*'
    r'(?P<tipo>[^\n=]+?)\s*(?P<default>=\s*(.+))?$', re.M)

# Property wrappers que gerem o seu próprio armazenamento: não aparecem no init
# memberwise, e tratá-los como parâmetros produzia "argumento em falta" em toda
# a vista SwiftUI que tivesse um deles.
WRAPPERS_INTERNOS = {'@State', '@Environment', '@FocusState', '@StateObject',
                     '@EnvironmentObject', '@AppStorage', '@SceneStorage',
                     '@GestureState', '@Namespace', '@FetchRequest', '@Query'}

# Exactamente quatro espaços: é o nível de topo dentro do tipo. Sem esta
# âncora, um `init()` de uma struct aninhada (como `PlanProposer.Pesos`) era
# lido como sendo o do tipo exterior, e todos os seus parâmetros desapareciam.
INIT_INICIO = re.compile(r'^ {4}(?:public\s+|internal\s+)?init\s*\(', re.M)

# Chamada `Nome(label: ...)` — só a primeira linha de labels interessa.
CHAMADA = re.compile(r'\b([A-Z]\w*)\s*\(')

# Property wrappers cujo armazenamento muda o nome do parâmetro do init.
WRAPPERS_QUE_NAO_ENTRAM = ('@Environment', '@FocusState', '@State private')


def declaracoes(ficheiros):
    tipos = {}
    for f in ficheiros:
        texto = f.read_text(encoding='utf-8')
        for tipo, nome in DECL.findall(texto):
            tipos.setdefault(nome, []).append((tipo, f))
    return tipos


def ate_fechar(texto, pos, abre='(', fecha=')'):
    """Devolve o conteúdo entre parênteses equilibrados a partir de `pos`."""
    i, prof, buf = pos, 1, []
    while i < len(texto) and prof:
        c = texto[i]
        if c == abre:
            prof += 1
        elif c == fecha:
            prof -= 1
            if not prof:
                return ''.join(buf), i
        buf.append(c)
        i += 1
    return None, i


def dividir_por_virgulas(texto):
    """Divide no nível de topo, ignorando vírgulas dentro de () [] {} e strings."""
    partes, buf, prof, em_string = [], [], 0, False
    i = 0
    while i < len(texto):
        c = texto[i]
        if em_string:
            if c == '\\':
                buf.append(c)
                i += 1
                if i < len(texto):
                    buf.append(texto[i])
                i += 1
                continue
            if c == '"':
                em_string = False
            buf.append(c); i += 1; continue
        if c == '"':
            em_string = True; buf.append(c); i += 1; continue
        if c in '([{':
            prof += 1
        elif c in ')]}':
            prof -= 1
        if c == ',' and prof == 0:
            partes.append(''.join(buf)); buf = []
        else:
            buf.append(c)
        i += 1
    if buf:
        partes.append(''.join(buf))
    return partes


def corpo_do_tipo(texto, nome):
    """Extrai o corpo de um tipo pelo equilíbrio de chavetas."""
    m = re.search(r'\b(?:struct|class|enum|actor)\s+' + re.escape(nome) + r'\b[^{]*\{', texto)
    if not m:
        return None
    i, prof = m.end(), 1
    while i < len(texto) and prof:
        if texto[i] == '{':
            prof += 1
        elif texto[i] == '}':
            prof -= 1
        i += 1
    return texto[m.end():i - 1]


def parametros_aceites(texto, nome):
    """
    Os labels que um tipo aceita: os do init explícito, se existir, senão os
    membros armazenados (o init memberwise).
    Devolve (obrigatorios, todos) ou None se não se conseguir determinar.
    """
    corpo = corpo_do_tipo(texto, nome)
    if corpo is None:
        return None

    # Só o init do próprio tipo, não os aninhados. Os parâmetros lêem-se com
    # parênteses equilibrados: um default como `= UUID()` fecha um parêntese que
    # não é o do init, e uma expressão regular simples corta a lista a meio.
    m = INIT_INICIO.search(corpo)
    if m:
        crus, _ = ate_fechar(corpo, m.end())
        if crus is None:
            return None
        labels, obrigatorios = [], []
        for parte in dividir_por_virgulas(crus):
            parte = parte.strip()
            if not parte:
                continue
            cabeca = parte.split(':')[0].strip()
            label = cabeca.split()[0] if cabeca else ''
            labels.append(label)
            if '=' not in parte.split(':', 1)[-1]:
                obrigatorios.append(label)
        return set(obrigatorios), set(labels)

    # Init memberwise: membros armazenados, pela ordem de declaração.
    labels, obrigatorios = [], []
    for m2 in MEMBRO.finditer(corpo):
        wrapper = (m2.group('wrapper') or m2.group('wrapper2') or '').strip()
        base = wrapper.split('(')[0]
        if base in WRAPPERS_INTERNOS:
            continue
        tipo_txt = m2.group('tipo')
        # Computed properties têm `{` no tipo; não são armazenadas.
        if '{' in tipo_txt:
            continue
        nome_membro = m2.group('nome')
        labels.append(nome_membro)
        opcional = tipo_txt.strip().endswith('?')
        # var opcional recebe default nil; let não.
        if not m2.group('default') and not (m2.group('palavra') == 'var' and opcional):
            obrigatorios.append(nome_membro)
    if not labels:
        return None
    return set(obrigatorios), set(labels)


def labels_da_chamada(texto, pos):
    """Lê os labels de uma chamada a partir do parêntese aberto em `pos`."""
    i, prof, buf = pos, 1, []
    while i < len(texto) and prof:
        c = texto[i]
        if c in '([{':
            prof += 1
        elif c in ')]}':
            prof -= 1
            if not prof:
                break
        buf.append(c)
        i += 1
    dentro = ''.join(buf)
    if len(dentro) > 4000:
        return None
    labels = []
    for parte in dividir_por_virgulas(dentro):
        parte = parte.strip()
        if not parte:
            continue
        m = re.match(r'^([a-z_]\w*)\s*:(?!:)', parte)
        labels.append(m.group(1) if m else '_posicional')
    return labels, i


def main():
    raizes = [pathlib.Path(a) for a in (sys.argv[1:] or ['.'])]
    ficheiros = sorted({f for r in raizes for f in r.rglob('*.swift')})
    if not ficheiros:
        print('Nenhum ficheiro .swift encontrado.')
        return 1

    tipos = declaracoes(ficheiros)
    textos = {f: f.read_text(encoding='utf-8') for f in ficheiros}

    # Assinaturas, resolvidas uma vez por tipo.
    assinaturas = {}
    for nome, ocorrencias in tipos.items():
        if len(ocorrencias) > 1:      # ambíguo, não arriscar
            continue
        tipo, f = ocorrencias[0]
        if tipo in ('protocol',):
            continue
        r = parametros_aceites(textos[f], nome)
        if r:
            assinaturas[nome] = r

    suspeitas = defaultdict(list)
    for f, texto in textos.items():
        # Ignorar comentários de linha, para não ler exemplos em documentação.
        limpo = re.sub(r'//.*', '', texto)
        for m in CHAMADA.finditer(limpo):
            nome = m.group(1)
            if nome not in assinaturas:
                continue
            r = labels_da_chamada(limpo, m.end())
            if not r:
                continue
            labels, fim = r
            # Trailing closure: `Foo(a: 1) { ... }` fornece o último parâmetro
            # sem o nomear, e é o padrão dominante em SwiftUI.
            resto = limpo[fim + 1:fim + 40].lstrip()
            tem_trailing = resto.startswith('{')
            obrigatorios, permitidos = assinaturas[nome]
            usados = {l for l in labels if l != '_posicional'}

            # Trailing closure: o último parâmetro pode vir sem label.
            desconhecidos = usados - permitidos
            em_falta = obrigatorios - usados
            posicionais = sum(1 for l in labels if l == '_posicional')
            if tem_trailing:
                posicionais += 1
            # Cada posicional pode cobrir um obrigatório em falta.
            em_falta_reais = set(sorted(em_falta)[posicionais:]) if posicionais else em_falta

            linha = limpo[:m.start()].count('\n') + 1
            if desconhecidos:
                suspeitas[f].append((linha, nome, f"argumento(s) que o tipo não aceita: {sorted(desconhecidos)}"))
            elif em_falta_reais:
                suspeitas[f].append((linha, nome, f"argumento(s) obrigatório(s) em falta: {sorted(em_falta_reais)}"))

    total = sum(len(v) for v in suspeitas.values())
    print(f'{len(ficheiros)} ficheiros · {len(tipos)} tipos declarados · {len(assinaturas)} assinaturas resolvidas\n')
    if not total:
        print('Nenhuma discrepância entre chamadas e declarações.')
    else:
        for f in sorted(suspeitas):
            print(f'▸ {f}')
            for linha, nome, msg in sorted(suspeitas[f]):
                print(f'    {linha}: {nome} — {msg}')
        print(f'\n{total} suspeita(s). Confirmar à mão: overloads, extensões e')
        print('trailing closures podem gerar falsos positivos.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
