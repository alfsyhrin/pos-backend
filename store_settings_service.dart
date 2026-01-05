// store_settings_service.dart
class StoreSettings {
  // Data toko (default)
  static String storeName = 'CV. Betarak Indonesia';
  static String storeAddress = 'Jl, North Sangaji, Kota Ternate Utara, Ternate City';
  static String storePhone = '+62 812-3456-7890';
  static String storeFooterNote = 'Terima kasih telah berbelanja di toko kami!';
  static double taxPercentage = 10.0; // PPN 10%

  // Pengaturan struk yang fixed (tidak bisa diubah)
  static const String receiptTemplate = 'DEFAULT_TEMPLATE_V1';
  static const bool showStoreLogo = true;
  static const bool showItemDetails = true;
  static const bool showTaxInfo = true;
  static const bool showFooterNote = true;
  static const int paperWidth = 58; // 58mm

  // Method untuk update settings dari data yang diedit di settings screen
  static void updateStoreInfo({
    required String name,
    required String address,
    required String phone,
    required double tax,
  }) {
    storeName = name;
    storeAddress = address;
    storePhone = phone;
    taxPercentage = tax;
  }

  // Method untuk reset ke default
  static void resetToDefaults() {
    storeName = 'CV. Betarak Indonesia';
    storeAddress = 'Jl, North Sangaji, Kota Ternate Utara, Ternate City';
    storePhone = '+62 812-3456-7890';
    storeFooterNote = 'Terima kasih telah berbelanja di toko kami!';
    taxPercentage = 10.0;
  }

  // Method untuk mendapatkan data dalam format Map (untuk backup)
  static Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'storeAddress': storeAddress,
      'storePhone': storePhone,
      'storeFooterNote': storeFooterNote,
      'taxPercentage': taxPercentage,
      'receiptTemplate': receiptTemplate,
      'showStoreLogo': showStoreLogo,
      'showItemDetails': showItemDetails,
      'showTaxInfo': showTaxInfo,
      'showFooterNote': showFooterNote,
      'paperWidth': paperWidth,
    };
  }

  // Method untuk mengisi data dari Map (untuk restore/import)
  static void fromMap(Map<String, dynamic> data) {
    storeName = data['storeName'] ?? storeName;
    storeAddress = data['storeAddress'] ?? storeAddress;
    storePhone = data['storePhone'] ?? storePhone;
    storeFooterNote = data['storeFooterNote'] ?? storeFooterNote;
    taxPercentage = (data['taxPercentage'] ?? taxPercentage).toDouble();
  }
}