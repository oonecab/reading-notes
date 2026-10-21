"""Keep the displayed source action and the drawn path in agreement."""
from pathlib import Path
import importlib.util
import re
import unittest
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'books/visual-group-theory/tools'))
spec = importlib.util.spec_from_file_location('vgt_structures', ROOT/'books/visual-group-theory/tools/check_structures.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
TEXT = (ROOT/'src/content/books/visual-group-theory/chapter07_products_and_quotients.html').read_text()
LATTICE = (ROOT/'src/content/books/visual-group-theory/chapter06_subgroups.html').read_text()
class SourceDiagram(unittest.TestCase):
    def test_all_original_actions_and_quotient_actions(self):
        self.assertEqual(module.source_diagram_checks(TEXT), {'ex718-h-before':48, 'ex718-h-after':24})
    def test_source_target_substitution_is_rejected(self):
        changed = re.sub(r'data-target-node="(\d+)"', lambda m:f'data-target-node="{(int(m[1])+1)%16}"', TEXT, count=1)
        self.assertNotEqual(changed,TEXT)
        with self.assertRaises((AssertionError, ValueError)): module.source_diagram_checks(changed)
    def test_correct_metadata_cannot_hide_wrong_path(self):
        start=TEXT.index('<figure id="ex718-h-before">')
        before,tail=TEXT[:start],TEXT[start:]
        tail=re.sub(r'(<path class="edge"[^>]* d=")[^"]+',r'\g<1>M 0 0 L 1 1',tail,count=1)
        self.assertNotEqual(before+tail,TEXT)
        with self.assertRaises((AssertionError, ValueError)): module.source_diagram_checks(before+tail)
    def test_lattice_edges_are_read_with_presentation_attributes(self):
        changed = LATTICE.replace('<path class="rn-edge" d=', '<path data-role="containment" class="rn-edge" d=')
        self.assertNotEqual(changed, LATTICE)
        self.assertEqual(module.diagram_checks(changed), {'c24_nodes':8, 'c24_cover_edges':10, 'unrelated_node_crossings':0})
    def test_lattice_wrong_endpoint_is_rejected_with_presentation_attributes(self):
        block = re.search(r'<figure id="ex624">.*?</figure>', LATTICE, re.S)[0]
        altered = re.sub(r'(<path class="rn-edge" d=")M[\d.]+ ', r'\g<1>M999 ', block, count=1)
        self.assertNotEqual(block, altered)
        with self.assertRaisesRegex(ValueError, 'edge misses a node'):
            module.diagram_checks(LATTICE.replace(block, altered))
    def test_lattice_missing_cover_edge_is_rejected(self):
        block = re.search(r'<figure id="ex624">.*?</figure>', LATTICE, re.S)[0]
        altered = re.sub(r'<path class="rn-edge"[^>]*/>', '', block, count=1)
        self.assertNotEqual(block, altered)
        with self.assertRaisesRegex(ValueError, 'cover edges'):
            module.diagram_checks(LATTICE.replace(block, altered))
if __name__=='__main__':unittest.main()
