#!/usr/bin/env python3
"""Check bundled .strings catalogs and literal UI keys without launching the app."""

import argparse
from collections import Counter
import re
from pathlib import Path
import sys


TOKEN = re.compile(r'\s+|//[^\n]*|/\*.*?\*/|@?"(?:\\.|[^"\\])*"|[A-Za-z_]\w*|[^\s]', re.S)
FORMAT = re.compile(
    r'%(?:(?P<position>[1-9]\d*)\$)?[-+ #0\']*'
    r'(?:(?P<width_star>\*)(?:(?P<width_position>[1-9]\d*)\$)?|\d+)?'
    r'(?:\.(?:(?P<precision_star>\*)(?:(?P<precision_position>[1-9]\d*)\$)?|\d*))?'
    r'(?P<length>hh|ll|[hlLqztj])?(?P<conversion>[@diouxXfFeEgGaAcCsSpn])'
)
HAN = re.compile(r'[\u3400-\u9fff\uf900-\ufaff\U00020000-\U0003134f]')
REQUIRED_KEYS = {
    '双轨记', '语言', '界面语言', '跟随系统', '简体中文', 'English',
    '更改语言不会修改笔记或自定义提示文字。',
    '回车或软盘存盘 · 图钉变便签', '双轨记错位双轨', '便签图钉',
    '便签图钉，按住拖动便签', '双轨记错位双轨，按住拖动输入框',
    '%@玻璃风格', '%@交互光效', '%@染色强度', '%@恢复默认外观',
    '%@ · 玻璃外观', '%@，请换一个组合。',
}


def decode_literal(token):
    """Decode the C/Apple escapes used by .strings and Objective-C literals."""
    text = token[token.index('"') + 1:-1]
    escapes = {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f',
               'a': '\a', 'v': '\v', '"': '"', "'": "'", '?': '?', '\\': '\\'}
    result, index = [], 0
    while index < len(text):
        char = text[index]
        index += 1
        if char != '\\':
            result.append(char)
            continue
        if index == len(text):
            raise ValueError('unterminated escape')
        char = text[index]
        index += 1
        if char in escapes:
            result.append(escapes[char])
        elif char in 'uU':
            digits = text[index:index + 4]
            if len(digits) != 4 or not re.fullmatch(r'[0-9a-fA-F]{4}', digits):
                raise ValueError('invalid Unicode escape')
            result.append(chr(int(digits, 16)))
            index += 4
        elif char in '01234567':
            digits = char
            while index < len(text) and len(digits) < 3 and text[index] in '01234567':
                digits += text[index]
                index += 1
            result.append(chr(int(digits, 8)))
        elif char == '\n':
            pass
        elif char == '\r':
            if index < len(text) and text[index] == '\n':
                index += 1
        else:
            raise ValueError(f'unsupported escape: \\{char}')
    return ''.join(result)


def tokens(text):
    return [match for match in TOKEN.finditer(text)
            if not match.group().isspace() and not match.group().startswith(('//', '/*'))]


def parse_strings(text):
    items, result = tokens(text), {}
    if len(items) % 4:
        raise ValueError('expected "key" = "value"; entries')
    for index in range(0, len(items), 4):
        key, equals, value, semicolon = [item.group() for item in items[index:index + 4]]
        if not (key.startswith('"') and value.startswith('"') and equals == '=' and semicolon == ';'):
            line = text.count('\n', 0, items[index].start()) + 1
            raise ValueError(f'line {line}: expected "key" = "value";')
        key, value = decode_literal(key), decode_literal(value)
        if key in result:
            raise ValueError(f'duplicate key: {key!r}')
        if not key.strip() or not value.strip():
            raise ValueError(f'empty key or value: {key!r}')
        result[key] = value
    return result


def format_signature(text):
    """Track argument index, role, and C type; allow safe positional reordering."""
    result, next_argument, offset, percent_literals = [], 1, 0, 0
    while True:
        offset = text.find('%', offset)
        if offset == -1:
            break
        if text.startswith('%%', offset):
            percent_literals += 1
            offset += 2
            continue
        match = FORMAT.match(text, offset)
        if not match:
            raise ValueError(f'invalid NSString format near {text[offset:offset + 16]!r}')
        for role in ('width', 'precision'):
            if match.group(role + '_star'):
                position = match.group(role + '_position')
                result.append((int(position) if position else next_argument, role, 'int'))
                if not position:
                    next_argument += 1
        position = match.group('position')
        result.append((int(position) if position else next_argument, 'value',
                       (match.group('length') or '') + match.group('conversion')))
        if not position:
            next_argument += 1
        offset = match.end()
    return sorted(result), percent_literals


def literal_calls(text):
    items = tokens(text)
    for index, item in enumerate(items[:-2]):
        if item.group() not in {'YSL', 'YSLocalizedInLanguage'} or items[index + 1].group() != '(':
            continue
        parts = []
        for literal in items[index + 2:]:
            if not literal.group().startswith(('"', '@"')):
                break
            parts.append(decode_literal(literal.group()))
        if parts:
            yield ''.join(parts), text.count('\n', 0, item.start()) + 1


def check_helpers():
    assert parse_strings('/* note */ "键" = "A\\nB\\U4E2D";') == {'键': 'A\nB中'}
    assert parse_strings('"a"="b"; // trailing comment\n') == {'a': 'b'}
    for invalid in ('"a"="b"; "a"="c";', '"a"="";', '"a"="b"', 'garbage'):
        try:
            parse_strings(invalid)
        except ValueError:
            pass
        else:
            raise AssertionError(f'parser accepted {invalid!r}')
    assert format_signature('%@ %lu %.0f%%') == format_signature('%3$.0f%% %2$lu %1$@')
    assert format_signature('%*.*f') == format_signature('%3$*1$.*2$f')
    assert format_signature('%lu') != format_signature('%ld')
    assert format_signature('%@ %@') != format_signature('%@')
    assert format_signature('%.0f%%') != format_signature('%.0f')
    assert list(literal_calls('// YSL(@"不检查")\nYSL(@"检查" @"拼接");')) == [('检查拼接', 2)]
    for invalid in ('%', '%$@', '%12$'):
        try:
            format_signature(invalid)
        except ValueError:
            pass
        else:
            raise AssertionError(f'format checker accepted {invalid!r}')


def check_catalogs(root):
    catalogs, errors = {}, []
    for language in ('en', 'zh-Hans'):
        directory = root / 'src' / 'Resources' / (language + '.lproj')
        for table in ('Localizable', 'InfoPlist'):
            path = directory / (table + '.strings')
            try:
                catalogs[language, table] = parse_strings(path.read_text(encoding='utf-8-sig'))
            except (OSError, ValueError) as error:
                errors.append(f'{path.relative_to(root)}: {error}')
    if errors:
        return errors, 0, 0
    for table in ('Localizable', 'InfoPlist'):
        english, chinese = catalogs['en', table], catalogs['zh-Hans', table]
        for language, catalog, other in (('en', english, chinese), ('zh-Hans', chinese, english)):
            for key in sorted(catalog.keys() - other.keys()):
                errors.append(f'{table}: {key!r} exists only in {language}')
        for key in sorted(english.keys() & chinese.keys()):
            try:
                expected = format_signature(key)
                for language in ('en', 'zh-Hans'):
                    if format_signature(catalogs[language, table][key]) != expected:
                        errors.append(f'{language}/{table}: format arguments differ for {key!r}')
            except ValueError as error:
                errors.append(f'{table}/{key!r}: {error}')
    english = catalogs['en', 'Localizable']
    for key in sorted(REQUIRED_KEYS - english.keys()):
        errors.append(f'Localizable: required key missing: {key!r}')
    if english.get('双轨记') != '2ndJot':
        errors.append('English brand must be 2ndJot')
    for language, name in (('en', '2ndJot'), ('zh-Hans', '双轨记')):
        for key in ('CFBundleDisplayName', 'CFBundleName'):
            if catalogs[language, 'InfoPlist'].get(key) != name:
                errors.append(f'{language}/InfoPlist: {key} must be {name}')
    calls = Counter()
    for path in sorted((root / 'src').rglob('*')):
        if path.suffix not in {'.m', '.h'}:
            continue
        for key, line in literal_calls(path.read_text(encoding='utf-8')):
            if HAN.search(key):
                calls[key] += 1
                if key not in english:
                    errors.append(f'{path.relative_to(root)}:{line}: missing UI key {key!r}')
    return errors, len(english), sum(calls.values())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    arguments = parser.parse_args()
    check_helpers()
    errors, count, calls = check_catalogs(arguments.root.resolve())
    if errors:
        for error in errors:
            print('FAIL:', error, file=sys.stderr)
        return 1
    print(f'PASS localization: {count} bilingual keys, 2 localized app names, '
          f'{calls} literal UI calls; key, value, and format checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
