"""Catalog extensions around the frozen I028 reader transformer."""
from html import escape
from html.parser import HTMLParser
from pathlib import Path
import reader_views as legacy

FROZEN_BOOKS = frozenset(legacy.BOOKS)
registered = {}

def with_auxiliary_typography(blob):
    css = (Path(__file__).resolve().parents[1] /
           'src/styles/reading-auxiliary-typography.css').read_bytes()
    return blob.replace(b'</head>', b'<style>' + css + b'</style></head>', 1)


class IconLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.found = False

    def handle_starttag(self, tag, attrs):
        if tag == 'link' and 'icon' in (dict(attrs).get('rel') or '').lower().split():
            self.found = True


def with_site_icon(blob, name):
    head, separator, body = blob.partition(b'</head>')
    if not separator:
        raise ValueError(f'Missing document head: {name}')
    icons = IconLinks()
    icons.feed(head.decode())
    if not icons.found:
        href = escape(legacy.relative(name, 'favicon.svg'), quote=True)
        head += f'<link rel="icon" href="{href}" type="image/svg+xml">'.encode()
    return head + separator + body


def configure(books):
    if not FROZEN_BOOKS <= books.keys() or any(book['publish_prefix'] != key for key, book in books.items()):
        raise ValueError('Historical books and publication prefixes must remain registered')
    registered.clear()
    registered.update(books)
    for name, book in books.items():
        # Preserve historical navigation byte-for-byte for the original books.
        legacy.BOOKS.setdefault(name, escape(book['title']))


def scope_labels(blob, name):
    if name.startswith('measure-probability/'):
        return blob.replace('全书地图'.encode(), '伴读总览'.encode())
    return blob


def transform_reading_page(blob, name, views, **kwargs):
    if name.startswith('eopl/notes/'):
        blob = blob.replace(
            b'href="../review/map-preface.md"',
            b'href="https://github.com/oonecab/reading-notes/blob/main/books/eopl/review/map-preface.md"')
    # Adapt the explicitly reviewed RN-001 scope around the frozen I028 parser.
    component_body = b'<body class="rn-components">'
    scoped = component_body in blob
    if scoped:
        if blob.count(component_body) != 1:
            raise ValueError(f'Duplicate reading component scope: {name}')
        blob = blob.replace(component_body, b'<body>', 1)
    published = legacy.transform_reading_page(blob, name, views, **kwargs)
    if scoped:
        published = published.replace(b'<body class="portal-reader">',
                                      b'<body class="portal-reader rn-components">', 1)
    return with_site_icon(scope_labels(published, name), name)


def build_reader_views(blobs):
    documents, views = legacy.build_reader_views(blobs)
    source = 'weiss/notes/README.md'
    if source in blobs:
        target = views[source]
        # The repository README also contains authoring and maintenance rules.
        # Publish its chapter navigation with reader-facing usage guidance.
        text = blobs[source].decode()
        marker = '## 当前入口\n'
        if text.count(marker) != 1:
            raise ValueError('Weiss guide needs one current chapter index')
        chapters = text.split(marker, 1)[1].split('\n## ', 1)[0]
        body = ('<section><h2>怎样使用这份伴读</h2>'
                '<p>从全书地图了解各章的联系，再进入章节正文。习题展开后先读原题，独立思考后再对照解答；'
                '程序区域可以分别展开 C11 与 Python 3 实现。</p>'
                '<p>运行环境、程序提取命令、实验口径与特殊依赖见 '
                '<a href="book_overview.html#program-guide">阅读与程序使用说明</a>。'
                '各章的实验数据与图表放在对应问题附近。</p></section>'
                '<section><h2>按章节阅读</h2>' + legacy.markdown(chapters, target, views) + '</section>')
        documents[target] = legacy.document(target, '阅读与程序使用说明',
                                           '选择章节，展开习题与程序，并沿正文中的说明复现实验。', body)
    source = 'measure-probability/code/README.md'
    if source in blobs:
        target = views[source]
        text = blobs[source].decode().split('## 校验', 1)[0]
        documents[target] = legacy.document(
            target, text.splitlines()[0].removeprefix('# '),
            '通过 C11/Python 程序复现可测结构、积分、条件均值、转移核与独立求和的分布。',
            legacy.markdown(text, source, views), raw=source)
    for name in registered.keys() - FROZEN_BOOKS:
        source, target = f'{name}/code/README.md', f'{name}/code/index.html'
        if source in blobs:
            views[source] = target
            text = blobs[source].decode()
            documents[target] = legacy.document(target, text.splitlines()[0].removeprefix('# '),
                                                '本书示例程序与运行说明。', legacy.markdown(text, target, views), raw=source)
    return {name: with_auxiliary_typography(scope_labels(blob, name))
            for name, blob in documents.items()}, views


def entry_page(book):
    title, entry = escape(book['title']), escape(book['entry'], quote=True)
    blob = (f'<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<meta http-equiv="refresh" content="0;url={entry}"><title>{title}</title>'
            f'</head><body><p><a href="{entry}">进入 {title}</a></p></body></html>\n').encode()
    return with_site_icon(with_auxiliary_typography(blob), f'{book["publish_prefix"]}/index.html')


def add_catalog_links(blob):
    new = {name for name in registered.keys() - FROZEN_BOOKS
           if f'href="{name}/{registered[name]["entry"]}"'.encode() not in blob}
    if not new:
        return blob
    links = ''.join(f'<a href="{name}/{escape(registered[name]["entry"], quote=True)}">'
                    f'{escape(registered[name]["title"])}</a> ' for name in sorted(new))
    return blob.replace(b'</main>', ('<aside class="reading-hint"><p>新增书籍：' + links + '</p></aside></main>').encode(), 1)
