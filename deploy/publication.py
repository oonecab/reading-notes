"""Catalog extensions around the frozen I028 reader transformer."""
from html import escape
import reader_views as legacy

FROZEN_BOOKS = frozenset(legacy.BOOKS)
registered = {}


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
    return scope_labels(legacy.transform_reading_page(blob, name, views, **kwargs), name)


def build_reader_views(blobs):
    documents, views = legacy.build_reader_views(blobs)
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
    return {name: scope_labels(blob, name) for name, blob in documents.items()}, views


def entry_page(book):
    title, entry = escape(book['title']), escape(book['entry'], quote=True)
    return (f'<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<meta http-equiv="refresh" content="0;url={entry}"><title>{title}</title>'
            f'</head><body><p><a href="{entry}">进入 {title}</a></p></body></html>\n').encode()


def add_catalog_links(blob):
    new = registered.keys() - FROZEN_BOOKS
    if not new:
        return blob
    links = ''.join(f'<a href="{name}/{escape(registered[name]["entry"], quote=True)}">'
                    f'{escape(registered[name]["title"])}</a> ' for name in sorted(new))
    return blob.replace(b'</main>', ('<aside class="reading-hint"><p>新增书籍：' + links + '</p></aside></main>').encode(), 1)
