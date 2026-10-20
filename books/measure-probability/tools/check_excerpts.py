"""Bind per-statement quotation status to visible HTML and the source inventory."""
from html.parser import HTMLParser


class Statements(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.stack, self.rows, self.current, self.marker = [], {}, None, None
        self.math_label_depth = None
        self.feed(text)
        self.close()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'div' and 'statement' in attrs.get('class', '').split():
            anchor = attrs['id']
            if anchor in self.rows:
                raise ValueError('duplicate statement: ' + anchor)
            self.current = {'depth': len(self.stack), 'markers': []}
            self.rows[anchor] = self.current
        if 'data-source-status' in attrs:
            if self.current is None or self.marker is not None:
                raise ValueError('quotation status outside statement or nested')
            self.marker = {'depth': len(self.stack), 'status': attrs['data-source-status'], 'text': ''}
            self.current['markers'].append(self.marker)
        if tag == 'math' and self.marker is not None and attrs.get('aria-label'):
            # Preserve the exact quoted spelling of indices and spacing while
            # the presentation uses structured MathML.
            self.marker['text'] += attrs['aria-label']
            self.math_label_depth = len(self.stack)
        if tag not in {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'}:
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if tag not in self.stack:
            return
        depth = len(self.stack) - 1 - self.stack[::-1].index(tag)
        self.stack = self.stack[:depth]
        if self.math_label_depth is not None and depth == self.math_label_depth:
            self.math_label_depth = None
        if self.marker is not None and depth == self.marker['depth']:
            self.marker = None
        if self.current is not None and depth == self.current['depth']:
            self.current = None

    def handle_data(self, text):
        if self.marker is not None and self.math_label_depth is None and 'annotation' not in self.stack:
            self.marker['text'] += text


def check_excerpts(texts, source, record, chapters):
    expected = {x['anchor']: x for x in source['items'] if x['kind'] != '例'}
    rows = record['statements']
    if len(rows) != len(expected) or {r['anchor'] for r in rows} != set(expected):
        raise ValueError('statement/excerpt mapping is not one-to-one')
    scans = {page: Statements(text).rows for page, text in texts.items()}
    quoted = {chapter: 0 for chapter in chapters}
    for row in rows:
        item = expected[row['anchor']]
        if (row['page'] != chapters[item['chapter']] or row['key'] != item['key']
                or row['printed_pages'] != [item['printed_page']] or row['pdf_pages'] != [item['pdf_page']]):
            raise ValueError('excerpt source page/key drift: ' + row['anchor'])
        markers = scans[row['page']][row['anchor']]['markers']
        if len(markers) != 1 or markers[0]['status'] != row['status'] or row['text'] not in markers[0]['text']:
            raise ValueError('missing or altered quotation status: ' + row['anchor'])
        if row['status'] == 'excerpt':
            if not row.get('excerpt_scope') or row.get('verification') != '人工目视扫描页转录；非 OCR':
                raise ValueError('excerpt lacks transcription scope')
            quoted[item['chapter']] += 1
        elif row['status'] != 'location-only' or row['text'] != '仅页码定位，无逐句摘录。':
            raise ValueError('invalid quotation status')
    if not all(count >= 2 for count in quoted.values()):
        raise ValueError('each chapter needs core quotations')
    return {'statements': len(rows), 'quoted': sum(quoted.values()), 'location_only': len(rows) - sum(quoted.values())}
