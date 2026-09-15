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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'number': number.isFinite ? number : null,
    };
  }

  factory ChapterItem.fromJson(Map<String, dynamic> json) {
    final rawNumber = json['number'];
    return ChapterItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      number: rawNumber is num ? rawNumber.toDouble() : double.infinity,
    );
  }
}
