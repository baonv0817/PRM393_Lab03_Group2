class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.category,
    required this.prepMinutes,
    this.soldOut = false,
    this.kioskId = '',
    this.description = '',
    this.imageUrl,
  });

  final String id;
  final String name;
  final int priceVnd;
  final String category;
  final int prepMinutes;
  final bool soldOut;

  /// Kiosk bán món này; mỗi món thuộc đúng một kiosk.
  final String kioskId;
  final String description;

  /// Ảnh món: đường dẫn ảnh đóng gói trong app (`assets/images/menu/…`) hoặc link `https://`
  /// của ảnh trong Cloud Storage `menu/{kioskId}/…`.
  final String? imageUrl;

  MenuItem copyWith({bool? soldOut}) => MenuItem(
    id: id,
    name: name,
    priceVnd: priceVnd,
    category: category,
    prepMinutes: prepMinutes,
    soldOut: soldOut ?? this.soldOut,
    kioskId: kioskId,
    description: description,
    imageUrl: imageUrl,
  );
}
