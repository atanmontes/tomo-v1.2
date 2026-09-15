import 'package:flutter_test/flutter_test.dart';
import 'package:tomo/core/weebcentral/html_utils.dart';
import 'package:tomo/core/weebcentral/parsers.dart';

void main() {
  test('chapter numbers prefer the chapter token', () {
    expect(chapterNumberFromTitle('Chapter 10'), 10);
    expect(chapterNumberFromTitle('Vol. 2 Chapter 3.5'), 3.5);
  });

  test('parses a compact search article', () {
    const html = '''
    <html><body>
      <article>
        <a href="/series/ABC123/one-piece"></a>
        <section></section>
        <section>
          <a class="link">One Piece</a>
          <ul>
            <li><strong>Author(s):</strong> <a>Oda</a></li>
            <li><strong>Tag(s):</strong> <a>Action</a> <a>Adventure</a></li>
            <li><strong>Status:</strong> Ongoing</li>
            <li><strong>Type:</strong> Manga</li>
          </ul>
        </section>
      </article>
    </body></html>
    ''';

    final results = parseSearchResults(html);
    expect(results, hasLength(1));
    expect(results.first.id, 'ABC123');
    expect(results.first.title, 'One Piece');
    expect(results.first.authors, ['Oda']);
    expect(results.first.tags, ['Action', 'Adventure']);
    expect(results.first.status, 'Ongoing');
    expect(results.first.type, 'Manga');
  });
}
