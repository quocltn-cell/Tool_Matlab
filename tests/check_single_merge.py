"""Static regression checks for the single multi-sheet merge file."""
from pathlib import Path
src=(Path(__file__).resolve().parents[1]/'BusHarnessApp.m').read_text()
assert 'mergedFile = writeMergedWorkbook(merged, selected, outputFolder, excel);' in src
assert 'mergedPaths = string(mergedFile);' in src
assert 'removeLegacyMergedWorkbooks(merged, outputFolder, mergedFile);' in src
assert 'Testcases_Merged.xlsx' in src
body=src.split('function file = writeMergedWorkbook(',1)[1].split('function removeLegacyMergedWorkbooks(',1)[0]
assert 'for k = 1:numel(workbooks)' in body
assert "writecell(cells, staged, 'Sheet', sheetName" in body
assert "movefile(staged, file, 'f')" in body
assert 'while isfile(file)' not in body
assert 'writtenSheets == 0' in body
assert 'filterWorkbookCases(group.Cells, group.Cases, chosen)' in body
print('PASS single fixed merged workbook; multiple worksheets; transactional replacement')
