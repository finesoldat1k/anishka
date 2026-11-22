import pathlib
p = pathlib.Path('lib/core/api/metadata/anilist.dart')
s = p.read_text()
# Fix the HTML entity replacements
s = s.replace('.replaceAll("&", "&")', '.replaceAll("&", "&")')
s = s.replace('.replaceAll(""", """)', '.replaceAll(""", """)')
s = s.replace('.replaceAll("&#039;", "\'")', '.replaceAll("&#039;", "\'")')
s = s.replace('.replaceAll("&apos;", "\'")', '.replaceAll("&apos;", "\'")')
s = s.replace('.replaceAll("<", "<")', '.replaceAll("<", "<")')
s = s.replace('.replaceAll(">", ">")', '.replaceAll(">", ">")')
p.write_text(s)
print('done')