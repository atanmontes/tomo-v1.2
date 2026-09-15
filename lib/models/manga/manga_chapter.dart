class ChapterItem {
  final String id;
  final String title;
  final String url;
  final double number;

  const ChapterItem({
    required this.id,
    required this.title,
    required this.url,
    this.number = double.infinity,
  });
}
