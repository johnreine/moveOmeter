"""Minimal KiCad S-expression reader/writer."""
import re

class Q(str):
    """A quoted string token."""
    pass

_tok = re.compile(r'\s*(?:(\()|(\))|"((?:[^"\\]|\\.)*)"|([^\s()"]+))', re.S)

def parse(text):
    pos, stack, cur = 0, [], None
    root = []
    cur = root
    n = len(text)
    while True:
        m = _tok.match(text, pos)
        if not m:
            if text[pos:].strip():
                raise ValueError('parse error at %d: %r' % (pos, text[pos:pos+40]))
            break
        pos = m.end()
        if m.group(1):
            new = []
            cur.append(new)
            stack.append(cur)
            cur = new
        elif m.group(2):
            cur = stack.pop()
        elif m.group(3) is not None:
            s = m.group(3)
            s = re.sub(r'\\(.)', lambda mm: {'n': '\n', 't': '\t', '"': '"', '\\': '\\'}.get(mm.group(1), mm.group(1)), s)
            cur.append(Q(s))
        else:
            cur.append(m.group(4))
        if pos >= n:
            break
    assert not stack, 'unbalanced'
    return root[0] if len(root) == 1 else root

def esc(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'

def atom(a):
    if isinstance(a, Q):
        return esc(a)
    if isinstance(a, float):
        s = ('%.6f' % a).rstrip('0').rstrip('.')
        return '0' if s in ('-0', '') else s
    return str(a)

INLINE = {'at', 'xy', 'start', 'end', 'mid', 'center', 'size', 'drill', 'layers', 'layer', 'uuid', 'width', 'type',
          'thickness', 'font', 'net', 'offset', 'scale', 'rotate', 'xyz', 'hide', 'justify', 'fill', 'stroke',
          'roundrect_rratio', 'property', 'tags', 'descr', 'attr', 'path', 'sheetname', 'sheetfile', 'effects',
          'priority', 'connect_pads', 'hatch', 'min_thickness', 'clearance', 'name', 'unlocked'}

def dump(e, ind=0):
    if not isinstance(e, list):
        return atom(e)
    has_list = any(isinstance(x, list) for x in e[1:])
    if not has_list:
        return '(' + ' '.join(atom(x) for x in e) + ')'
    # short enough -> inline
    flat = '(' + ' '.join(dump(x, 0) if isinstance(x, list) else atom(x) for x in e) + ')'
    if len(flat) <= 100 and '\n' not in flat:
        return flat
    head = [atom(x) for x in e if not isinstance(x, list)]
    # keep leading atoms on first line (tag + positional atoms before first list)
    out = '('
    i = 0
    parts = []
    while i < len(e) and not isinstance(e[i], list):
        parts.append(atom(e[i]))
        i += 1
    out += ' '.join(parts)
    pad = '\t' * (ind + 1)
    for x in e[i:]:
        out += '\n' + pad + (dump(x, ind + 1) if isinstance(x, list) else atom(x))
    out += '\n' + '\t' * ind + ')'
    return out

def find(e, tag):
    for x in e:
        if isinstance(x, list) and x and x[0] == tag:
            return x
    return None

def findall(e, tag):
    return [x for x in e if isinstance(x, list) and x and x[0] == tag]
