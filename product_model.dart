enum PromoType { none, percent, amount, buyXGetY, bundlePrice }

class Product {
  final int id;

  final String name;

  // SKU manual (kode internal toko)
  final String sku;

  // Barcode hasil scan (umumnya EAN-13 / Code128)
  final String barcode;

  // Harga
  final double costPrice; // harga modal
  final double sellPrice; // harga jual

  // Kompatibilitas: jika ada kode lama yang masih pakai p.price
  double get price => sellPrice;

  // Kompatibilitas: jika ada kode lama yang pakai p.barcodeValue
  String get barcodeValue => barcode;

  final int stock;

  final String category;
  final String description;
  final String imageUrl;

  // Promo
  final PromoType promoType;
  final double promoPercent; // 0-100
  final double promoAmount; // potongan rupiah per item
  final int buyQty; // X
  final int freeQty; // Y
  final int bundleQty; // X
  final double bundleTotalPrice; // total harga jadi Y

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.costPrice,
    required this.sellPrice,
    required this.stock,
    required this.category,
    required this.description,
    required this.imageUrl,
    this.promoType = PromoType.none,
    this.promoPercent = 0,
    this.promoAmount = 0,
    this.buyQty = 0,
    this.freeQty = 0,
    this.bundleQty = 0,
    this.bundleTotalPrice = 0,
  });

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    double? costPrice,
    double? sellPrice,
    int? stock,
    String? category,
    String? description,
    String? imageUrl,
    PromoType? promoType,
    double? promoPercent,
    double? promoAmount,
    int? buyQty,
    int? freeQty,
    int? bundleQty,
    double? bundleTotalPrice,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      promoType: promoType ?? this.promoType,
      promoPercent: promoPercent ?? this.promoPercent,
      promoAmount: promoAmount ?? this.promoAmount,
      buyQty: buyQty ?? this.buyQty,
      freeQty: freeQty ?? this.freeQty,
      bundleQty: bundleQty ?? this.bundleQty,
      bundleTotalPrice: bundleTotalPrice ?? this.bundleTotalPrice,
    );
  }

  bool get hasPromo => promoType != PromoType.none;

  double get discountedUnitPrice {
    switch (promoType) {
      case PromoType.percent:
        final p = promoPercent.clamp(0, 100);
        return (sellPrice * (1 - (p / 100))).clamp(0, double.infinity);

      case PromoType.amount:
        final cut = promoAmount < 0 ? 0 : promoAmount;
        return (sellPrice - cut).clamp(0, double.infinity);

      case PromoType.none:
      case PromoType.buyXGetY:
      case PromoType.bundlePrice:
        return sellPrice;
    }
  }

  double get margin => (sellPrice - costPrice);

  double get marginPercent {
    if (sellPrice <= 0) return 0;
    return (margin / sellPrice) * 100;
  }

  String promoLabel() {
    switch (promoType) {
      case PromoType.none:
        return '';
      case PromoType.percent:
        return 'Diskon ${promoPercent.round()}%';
      case PromoType.amount:
        return 'Potong Rp ${promoAmount.round()}';
      case PromoType.buyXGetY:
        return 'Beli $buyQty Gratis $freeQty';
      case PromoType.bundlePrice:
        return 'Beli $bundleQty Total Rp ${bundleTotalPrice.round()}';
    }
  }
}
