"""Validate reader navigation against the source chapter inventory.

This checks structural promises, not the meaning of arrows or the correctness
of a figure. Those require the separate visual/content review.
"""
from collections import Counter
import re
from urllib.parse import unquote, urlsplit

from html_support import Document


def check_reader_navigation(sources, manifest):
    chapters = manifest['chapters']
    chapter_files = {c['chapter']: c['file'] for c in chapters}
    file_numbers = {c['file']: c['chapter'] for c in chapters}
    sequence = ['book_overview.html', 'preface.html', *chapter_files.values()]
    docs = {name: Document(source) for name, source in sources.items()}
    figures = svgs = chapter_labels = navigation_bars = 0

    for name, doc in docs.items():
        for figure in doc.root.walk('figure'):
            captions = list(figure.walk('figcaption'))
            if len(captions) != 1 or not captions[0].text().strip():
                raise ValueError(name + ': figure needs one readable caption')
            figures += 1
        for svg in doc.root.walk('svg'):
            labelledby = svg.attrs.get('aria-labelledby', '').split()
            ids = {n.attrs['id']: n for n in svg.walk() if n.attrs.get('id')}
            if labelledby:
                if any(ref not in ids or not ids[ref].text().strip() for ref in labelledby):
                    raise ValueError(name + ': SVG accessible label target is missing')
            elif not svg.attrs.get('aria-label', '').strip():
                raise ValueError(name + ': SVG needs an accessible label')
            svgs += 1
        for a in doc.root.walk('a'):
            ref = urlsplit(a.attrs.get('href', ''))
            if ref.scheme or ref.netloc:
                continue
            target = unquote(ref.path) or name
            label = a.attrs.get('aria-label') or a.text()
            number = re.search(r'(?:第\s*)?(\d+)\s*章', label)
            if number and target in file_numbers:
                if int(number[1]) != file_numbers[target]:
                    raise ValueError(name + ': chapter label disagrees with destination: ' + label)
                chapter_labels += 1

        index = sequence.index(name)
        prev = sequence[index-1] if index else None
        following = sequence[index+1] if index+1 < len(sequence) else None
        # RN-002: the map is not a "previous page" arrow, and the last page has no "next".
        expected_previous = [prev] if prev and prev != 'book_overview.html' else []
        expected_next = [following] if following else []
        bars = [n for n in doc.root.walk('p') if n.has_class('chapter-nav')]
        if len(bars) != 2:
            raise ValueError(name + ': expected header and footer navigation')
        for bar in bars:
            previous_links = [a.attrs.get('href') for a in bar.walk('a') if '←' in a.text()]
            next_links = [a.attrs.get('href') for a in bar.walk('a') if '→' in a.text()]
            if previous_links != expected_previous or next_links != expected_next:
                raise ValueError(name + ': previous/next navigation differs from source chapter order')
            navigation_bars += 1

    overview = docs['book_overview.html']
    maps = [n for n in overview.root.walk('figure') if n.attrs.get('id') == 'whole-book-map']
    if len(maps) != 1:
        raise ValueError('Whole-book map is missing')
    targets = [urlsplit(a.attrs.get('href', '')).path for a in maps[0].walk('a')]
    if Counter(targets) != Counter(chapter_files.values()):
        raise ValueError('Whole-book map must provide one separate entry for every source chapter')
    paths = [n for n in overview.root.walk('section') if n.attrs.get('id') == 'reading-path']
    path_tables = list(paths[0].walk('table')) if len(paths) == 1 else []
    if len(path_tables) != 1:
        raise ValueError('Per-chapter reading task table is missing')
    targets = [urlsplit(a.attrs.get('href', '')).path for a in path_tables[0].walk('a')]
    if Counter(targets) != Counter(chapter_files.values()):
        raise ValueError('Reading task table must cover every source chapter')
    return {'figures_with_captions': figures, 'accessible_svgs': svgs,
            'chapter_label_destinations': chapter_labels, 'navigation_bars': navigation_bars,
            'whole_book_map_chapters': len(chapters), 'reading_task_chapters': len(chapters)}


def check_navigation_mutations(sources, manifest):
    """Use valid but wrong destinations and missing entries, not broken URLs alone."""
    mutations = []
    map_source = sources['book_overview.html']
    overview = Document(map_source)
    figure = next(n for n in overview.root.walk('figure') if n.attrs.get('id') == 'whole-book-map')
    sixth = next(a for a in figure.walk('a') if a.attrs.get('href') == 'chapter06_memory.html')
    mutations.append(('missing_chapter_map_entry', 'book_overview.html',
                      map_source[:sixth.start] + map_source[sixth.end:]))
    wrong_target = map_source[:sixth.start] + map_source[sixth.start:sixth.end].replace(
        'chapter06_memory.html', 'chapter05_optimization.html') + map_source[sixth.end:]
    mutations.append(('wrong_existing_chapter_destination', 'book_overview.html', wrong_target))
    mutations.append(('wrong_reading_task_label', 'book_overview.html', map_source.replace(
        '>1章系统漫游</a>', '>2章系统漫游</a>', 1)))
    original = sources['chapter01_tour.html']
    mutations.append(('wrong_next_chapter', 'chapter01_tour.html', original.replace(
        'href="chapter02_information.html"', 'href="chapter03_machine_level.html"', 1)))
    mutations.append(('skipped_chapter_with_matching_label', 'chapter01_tour.html', original.replace(
        '<a href="chapter02_information.html">第 2 章 · 信息的表示和处理 →</a>',
        '<a href="chapter03_machine_level.html">第 3 章 · 程序的机器级表示 →</a>', 1)))
    mutations.append(('missing_figure_caption', 'chapter01_tour.html', original.replace(
        '<figcaption>', '<div>', 1).replace('</figcaption>', '</div>', 1)))
    mutations.append(('unresolved_svg_label', 'chapter01_tour.html', original.replace(
        'aria-labelledby="compile-flow-title"', 'aria-labelledby="absent-figure-title"', 1)))
    path = next(n for n in overview.root.walk('section') if n.attrs.get('id') == 'reading-path')
    twelfth = next(a for a in path.walk('a') if a.attrs.get('href') == 'chapter12_concurrency.html#s12-5')
    mutations.append(('missing_reading_task_entry', 'book_overview.html',
                      map_source[:twelfth.start] + twelfth.text() + map_source[twelfth.end:]))
    results = []
    for label, file, mutated in mutations:
        if mutated == sources[file]:
            raise ValueError('Mutation did not change its input: ' + label)
        try:
            check_reader_navigation({**sources, file: mutated}, manifest)
        except ValueError as error:
            results.append({'case': label, 'rejected': str(error)})
        else:
            raise ValueError('Reader navigation mutation was accepted: ' + label)
    return results
