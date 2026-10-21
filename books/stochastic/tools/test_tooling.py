#!/usr/bin/env python3
"""Regression tests for previously missed mutations and release guarantees."""
import gzip
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
from html_support import Document, check_resources
from readable_numbers import readable_tex, readable_code
import content_integrity
import sync_code
import check_notes
import check_content_regressions

ROOT = Path(__file__).resolve().parents[1]


class RegressionTests(unittest.TestCase):
    def test_tex_decimal_and_c_hex_float(self):
        self.assertEqual(readable_tex(r'\approx.764706'),r'\approx0.764706')
        source='double x=0x1.8p3, y=0X.8P+1, z=.5; /* .3 */ const char *s=".2";'
        self.assertEqual(readable_code(source,'c'),source.replace('z=.5','z=0.5'))
        self.assertEqual(readable_code('x=.5\ns=".5"\n','python'),'x=0.5\ns=".5"\n')

    def test_resource_dependencies_and_redirection(self):
        check_resources('<style>path{marker-end:url(#arrow)}</style>', 'notes/chapter.html')
        for source in ['<style>@import "https://example.invalid/a.css";</style>',
                       '<style>x{background:u\\72l(https://example.invalid/a)}</style>',
                       '<p style="background:url(x.png)">text</p>',
                       '<base href="https://example.invalid/">',
                       '<meta http-equiv="refresh" content="0;url=https://example.invalid/">']:
            with self.assertRaises(ValueError):check_resources(source,'notes/chapter.html')
        check_resources('<meta http-equiv="refresh" content="0;url=notes/book_overview.html">',
                        'index.html',{'notes/book_overview.html'},allow_entry_refresh=True)

    def test_signals_and_wrong_exit_codes_are_failures(self):
        for status in [-6,-11,1,134]:
            with patch.object(check_notes.subprocess,'run',return_value=SimpleNamespace(returncode=status,stdout='',stderr='input error')):
                with self.assertRaises(AssertionError):check_notes.command(['probe'],'',False,2)

    def test_large_absolute_error_not_hidden(self):
        with self.assertRaises(AssertionError):check_notes.close([1e12],[1e12+10000],'large error')
        with self.assertRaises(AssertionError):check_notes.close([0],[1e-9],'zero error')

    def test_code_registry_and_language_and_quoted_greater_than(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory).resolve();(root/'code').mkdir();(root/'notes').mkdir()
            (root/'code/a.c').write_text('int a=0;\n');(root/'code/a.py').write_text('a=0\n')
            manifest={'programs':[{'id':'a','page':'notes/a.html','files':{'c':'code/a.c','python':'code/a.py'}}]}
            (root/'code/programs.json').write_text(json.dumps(manifest))
            valid='<code title="x &gt; y" id="a-c" data-language="c">int a=0;\n</code><code id="a-python" data-language="python">a=0\n</code>'
            with patch.object(sync_code,'ROOT',root):
                for mutated in [valid+'<code>stale old program</code>',
                                valid+'<pre><code>stale old program</code></pre>',
                                valid+'<p><code id="unknown">a.c</code></p>',
                                valid.replace('data-language="c"','data-language="python"')]:
                    (root/'notes/a.html').write_text(mutated)
                    with self.assertRaises(ValueError):sync_code.synchronize()
                (root/'notes/a.html').write_text(valid.replace('&gt;','>')+'<p>运行 <code>a.py</code>。</p>')
                self.assertEqual(sync_code.synchronize()['differences'],[])

    def test_content_mutation_and_empty_math_are_detected(self):
        path=ROOT/'notes/chapter01_markov_chains.html';old=path.read_text();real_read=Path.read_text
        main=next(Document(old).root.walk('main'))
        heading=next(main.walk('h2'));formula=next(main.walk('math'))
        for modified in [old[:heading.content_start]+'JUNK'+old[heading.content_end:],
                         old[:formula.start]+old[formula.start:formula.content_start].replace('data-tex="','data-tex="FAKE_TEX ',1)+old[formula.content_start:],
                         old[:formula.content_start]+old[formula.content_end:]]:
            def read(obj,*args,**kwargs):return modified if obj==path else real_read(obj,*args,**kwargs)
            with patch.object(Path,'read_text',read):
                with self.assertRaises(ValueError):content_integrity.check_snapshot()

    def test_archive_is_reproducible(self):
        import importlib.util
        spec=importlib.util.spec_from_file_location('release_builder',ROOT/'deploy/build_release.py')
        builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
        with tempfile.TemporaryDirectory() as directory:
            a,b=Path(directory)/'a.tar.gz',Path(directory)/'b.tar.gz'
            builder.write_archive(a,{'example.txt':b'same'})
            builder.write_archive(b,{'example.txt':b'same'})
            self.assertEqual(a.read_bytes(),b.read_bytes())
            self.assertEqual(int.from_bytes(a.read_bytes()[4:8],'little'),0)

    def test_corrected_content_regressions_reject_wrong_displayed_values(self):
        # Changes in notation or equivalent fraction spelling must not hide
        # a wrong traffic sum, parity price or average-price option value.
        real_read=Path.read_text
        cases=[
            ('chapter04_continuous_time_markov_chains.html','r₁=1+5/7=12/7','r₁=1+5/7=11/7'),
            ('chapter06_mathematical_finance.html','10368/1225','10367/1225'),
            ('chapter06_mathematical_finance.html',r'V_0=\frac{476}{375}',r'V_0=\frac{64}{25}'),
        ]
        for filename,correct,wrong in cases:
            path=ROOT/'notes'/filename;source=real_read(path)
            self.assertIn(correct,source)
            changed=source.replace(correct,wrong)
            if filename == 'chapter04_continuous_time_markov_chains.html':
                formula = next(n for n in Document(source).root.walk('math')
                               if n.attrs.get('aria-label') == correct)
                fragment = source[formula.start:formula.end]
                self.assertIn('<mn>12</mn>', fragment)
                # Mutate the displayed value as well as its accessible spelling.
                # Replacing the label alone would leave the actual value 12/7.
                altered = fragment.replace(correct, wrong).replace('<mn>12</mn>', '<mn>11</mn>')
                changed = source[:formula.start] + altered + source[formula.end:]
            self.assertNotEqual(changed, source)
            def read(obj,*args,**kwargs):return changed if obj==path else real_read(obj,*args,**kwargs)
            with self.subTest(filename=filename,value=wrong),patch.object(Path,'read_text',read):
                with self.assertRaises(AssertionError):check_content_regressions.main()


if __name__=='__main__':unittest.main()
