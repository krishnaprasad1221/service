import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ShopCatalogStore {
  ShopCatalogStore._() {
    _warmUpOnlineCategoryImages();
    _warmUpOnlineItemImages();
  }

  static final ShopCatalogStore instance = ShopCatalogStore._();

  final ValueNotifier<List<ShopCategory>> categoriesNotifier =
      ValueNotifier<List<ShopCategory>>(_initialCategories);
  final Map<String, Future<String?>> _pendingImageLookups =
      <String, Future<String?>>{};

  static final List<ShopCategory> _initialCategories = <ShopCategory>[
    ShopCategory(
      id: 'electrical_components',
      name: 'Electrical Components',
      icon: Icons.electrical_services_rounded,
      accentColor: Colors.indigo,
      items: <ShopItem>[
        ShopItem(id: 'switch', name: 'Switch', price: 120),
        ShopItem(id: 'smart_switch', name: 'Smart Switch', price: 850),
        ShopItem(id: 'dimmer_switch', name: 'Dimmer Switch', price: 650),
        ShopItem(id: 'wire', name: 'Wire', price: 300),
        ShopItem(id: 'power_cable', name: 'Power Cable', price: 450),
        ShopItem(id: 'extension_board', name: 'Extension Board', price: 550),
        ShopItem(id: 'power_socket', name: 'Power Socket', price: 180),
        ShopItem(id: 'power_plug', name: 'Power Plug', price: 90),
        ShopItem(id: 'fuse', name: 'Fuse', price: 60),
        ShopItem(id: 'fuse_holder', name: 'Fuse Holder', price: 110),
        ShopItem(id: 'circuit_breaker', name: 'Circuit Breaker', price: 980),
        ShopItem(id: 'mcb', name: 'MCB', price: 750),
        ShopItem(id: 'elcb', name: 'ELCB', price: 1300),
        ShopItem(
          id: 'distribution_board',
          name: 'Distribution Board',
          price: 1850,
        ),
        ShopItem(id: 'junction_box', name: 'Junction Box', price: 220),
        ShopItem(id: 'terminal_block', name: 'Terminal Block', price: 160),
      ],
    ),
    ShopCategory(
      id: 'repair_tools',
      name: 'Repair Tools',
      icon: Icons.build_circle_outlined,
      accentColor: Colors.teal,
      items: <ShopItem>[
        ShopItem(id: 'screwdriver_set', name: 'Screwdriver Set', price: 700),
        ShopItem(
          id: 'precision_screwdriver',
          name: 'Precision Screwdriver',
          price: 420,
        ),
        ShopItem(id: 'multimeter', name: 'Multimeter', price: 950),
        ShopItem(
          id: 'digital_multimeter',
          name: 'Digital Multimeter',
          price: 1450,
        ),
        ShopItem(id: 'wire_cutter', name: 'Wire Cutter', price: 380),
        ShopItem(id: 'wire_stripper', name: 'Wire Stripper', price: 420),
        ShopItem(id: 'soldering_iron', name: 'Soldering Iron', price: 650),
        ShopItem(id: 'solder_wire', name: 'Solder Wire', price: 180),
        ShopItem(id: 'desolder_pump', name: 'Desolder Pump', price: 220),
        ShopItem(id: 'electric_drill', name: 'Electric Drill', price: 2600),
        ShopItem(id: 'drill_bits', name: 'Drill Bits', price: 500),
        ShopItem(id: 'heat_gun', name: 'Heat Gun', price: 1700),
        ShopItem(id: 'voltage_tester', name: 'Voltage Tester', price: 350),
        ShopItem(id: 'crimping_tool', name: 'Crimping Tool', price: 620),
        ShopItem(id: 'pliers', name: 'Pliers', price: 320),
        ShopItem(id: 'spanner_set', name: 'Spanner Set', price: 980),
        ShopItem(id: 'allen_key_set', name: 'Allen Key Set', price: 450),
        ShopItem(id: 'tool_kit_box', name: 'Tool Kit Box', price: 1100),
        ShopItem(id: 'insulated_gloves', name: 'Insulated Gloves', price: 300),
        ShopItem(id: 'safety_goggles', name: 'Safety Goggles', price: 250),
      ],
    ),
    ShopCategory(
      id: 'smart_devices',
      name: 'Smart Devices',
      icon: Icons.devices_other_rounded,
      accentColor: Colors.orange,
      items: <ShopItem>[
        ShopItem(id: 'smart_bulb', name: 'Smart Bulb', price: 499),
        ShopItem(id: 'smart_plug', name: 'Smart Plug', price: 799),
        ShopItem(id: 'smart_switch_2', name: 'Smart Switch', price: 1099),
        ShopItem(id: 'smart_camera', name: 'Smart Camera', price: 2499),
        ShopItem(id: 'smart_door_lock', name: 'Smart Door Lock', price: 4599),
        ShopItem(id: 'smart_doorbell', name: 'Smart Doorbell', price: 3199),
        ShopItem(id: 'smart_thermostat', name: 'Smart Thermostat', price: 3999),
        ShopItem(
          id: 'smart_motion_sensor',
          name: 'Smart Motion Sensor',
          price: 1499,
        ),
        ShopItem(
          id: 'smart_smoke_detector',
          name: 'Smart Smoke Detector',
          price: 1799,
        ),
        ShopItem(id: 'smart_home_hub', name: 'Smart Home Hub', price: 5299),
      ],
    ),
    ShopCategory(
      id: 'maintenance_products',
      name: 'Maintenance Products',
      icon: Icons.cleaning_services_outlined,
      accentColor: Colors.green,
      items: <ShopItem>[
        ShopItem(
          id: 'ac_cleaning_spray',
          name: 'AC Cleaning Spray',
          price: 350,
        ),
        ShopItem(
          id: 'screen_cleaning_kit',
          name: 'Screen Cleaning Kit',
          price: 280,
        ),
        ShopItem(
          id: 'laptop_cleaning_brush',
          name: 'Laptop Cleaning Brush',
          price: 180,
        ),
        ShopItem(id: 'keyboard_cleaner', name: 'Keyboard Cleaner', price: 220),
        ShopItem(
          id: 'refrigerator_deodorizer',
          name: 'Refrigerator Deodorizer',
          price: 240,
        ),
        ShopItem(id: 'dust_blower', name: 'Dust Blower', price: 650),
        ShopItem(
          id: 'contact_cleaner_spray',
          name: 'Contact Cleaner Spray',
          price: 320,
        ),
        ShopItem(id: 'rust_remover', name: 'Rust Remover', price: 260),
        ShopItem(
          id: 'electrical_lubricant',
          name: 'Electrical Lubricant',
          price: 290,
        ),
        ShopItem(
          id: 'anti_static_spray',
          name: 'Anti Static Spray',
          price: 340,
        ),
      ],
    ),
    ShopCategory(
      id: 'accessories',
      name: 'Accessories',
      icon: Icons.headphones_rounded,
      accentColor: Colors.blue,
      items: <ShopItem>[
        ShopItem(id: 'phone_charger', name: 'Phone Charger', price: 500),
        ShopItem(id: 'usb_cable', name: 'USB Cable', price: 220),
        ShopItem(id: 'hdmi_cable', name: 'HDMI Cable', price: 480),
        ShopItem(id: 'laptop_stand', name: 'Laptop Stand', price: 900),
        ShopItem(
          id: 'laptop_cooling_pad',
          name: 'Laptop Cooling Pad',
          price: 1350,
        ),
        ShopItem(id: 'headphones', name: 'Headphones', price: 1600),
        ShopItem(id: 'earbuds', name: 'Earbuds', price: 2100),
        ShopItem(
          id: 'bluetooth_speaker',
          name: 'Bluetooth Speaker',
          price: 2400,
        ),
        ShopItem(id: 'power_bank', name: 'Power Bank', price: 1800),
        ShopItem(id: 'memory_card', name: 'Memory Card', price: 950),
      ],
    ),
    ShopCategory(
      id: 'computer_accessories',
      name: 'Computer Accessories',
      icon: Icons.computer_rounded,
      accentColor: Colors.cyan,
      items: <ShopItem>[
        ShopItem(id: 'computer_mouse', name: 'Computer Mouse', price: 450),
        ShopItem(
          id: 'mechanical_keyboard',
          name: 'Mechanical Keyboard',
          price: 2800,
        ),
        ShopItem(
          id: 'wireless_keyboard',
          name: 'Wireless Keyboard',
          price: 1800,
        ),
        ShopItem(id: 'usb_hub', name: 'USB Hub', price: 600),
        ShopItem(id: 'laptop_stand_2', name: 'Laptop Stand', price: 900),
        ShopItem(
          id: 'laptop_cooling_pad_2',
          name: 'Laptop Cooling Pad',
          price: 1350,
        ),
        ShopItem(id: 'webcam', name: 'Webcam', price: 2200),
        ShopItem(id: 'headphones_2', name: 'Headphones', price: 1600),
        ShopItem(
          id: 'external_hard_drive',
          name: 'External Hard Drive',
          price: 4200,
        ),
        ShopItem(id: 'usb_flash_drive', name: 'USB Flash Drive', price: 700),
      ],
    ),
    ShopCategory(
      id: 'mobile_accessories',
      name: 'Mobile Accessories',
      icon: Icons.phone_android_rounded,
      accentColor: Colors.pink,
      items: <ShopItem>[
        ShopItem(id: 'mobile_charger', name: 'Mobile Charger', price: 500),
        ShopItem(id: 'fast_charger', name: 'Fast Charger', price: 850),
        ShopItem(id: 'usb_cable_2', name: 'USB Cable', price: 220),
        ShopItem(id: 'wireless_charger', name: 'Wireless Charger', price: 1400),
        ShopItem(id: 'phone_case', name: 'Phone Case', price: 350),
        ShopItem(id: 'screen_protector', name: 'Screen Protector', price: 250),
        ShopItem(id: 'earbuds_2', name: 'Earbuds', price: 2100),
        ShopItem(
          id: 'bluetooth_headset',
          name: 'Bluetooth Headset',
          price: 1900,
        ),
        ShopItem(id: 'power_bank_2', name: 'Power Bank', price: 1800),
        ShopItem(id: 'mobile_holder', name: 'Mobile Holder', price: 300),
      ],
    ),
    ShopCategory(
      id: 'lighting_equipment',
      name: 'Lighting Equipment',
      icon: Icons.lightbulb_outline_rounded,
      accentColor: Colors.amber,
      items: <ShopItem>[
        ShopItem(id: 'led_bulb', name: 'LED Bulb', price: 180),
        ShopItem(id: 'tube_light', name: 'Tube Light', price: 420),
        ShopItem(id: 'smart_light', name: 'Smart Light', price: 1100),
        ShopItem(id: 'emergency_light', name: 'Emergency Light', price: 950),
        ShopItem(id: 'led_strip', name: 'LED Strip', price: 700),
        ShopItem(id: 'table_lamp', name: 'Table Lamp', price: 850),
        ShopItem(id: 'wall_light', name: 'Wall Light', price: 980),
        ShopItem(id: 'ceiling_light', name: 'Ceiling Light', price: 1500),
        ShopItem(id: 'outdoor_light', name: 'Outdoor Light', price: 1300),
        ShopItem(id: 'solar_light', name: 'Solar Light', price: 1700),
      ],
    ),
    ShopCategory(
      id: 'home_security_devices',
      name: 'Home Security Devices',
      icon: Icons.security_rounded,
      accentColor: Colors.red,
      items: <ShopItem>[
        ShopItem(id: 'cctv_camera', name: 'CCTV Camera', price: 2600),
        ShopItem(id: 'wireless_camera', name: 'Wireless Camera', price: 3200),
        ShopItem(id: 'video_doorbell', name: 'Video Doorbell', price: 3900),
        ShopItem(id: 'motion_sensor', name: 'Motion Sensor', price: 1400),
        ShopItem(id: 'burglar_alarm', name: 'Burglar Alarm', price: 3100),
        ShopItem(id: 'smart_lock', name: 'Smart Lock', price: 4600),
        ShopItem(id: 'door_sensor', name: 'Door Sensor', price: 1100),
        ShopItem(id: 'smoke_detector', name: 'Smoke Detector', price: 1800),
        ShopItem(
          id: 'gas_leak_detector',
          name: 'Gas Leak Detector',
          price: 2200,
        ),
        ShopItem(id: 'security_dvr', name: 'Security DVR', price: 5200),
      ],
    ),
    ShopCategory(
      id: 'home_automation',
      name: 'Home Automation',
      icon: Icons.home_rounded,
      accentColor: Colors.deepPurple,
      items: <ShopItem>[
        ShopItem(id: 'smart_hub', name: 'Smart Hub', price: 5299),
        ShopItem(id: 'smart_switch_3', name: 'Smart Switch', price: 1099),
        ShopItem(
          id: 'smart_curtain_controller',
          name: 'Smart Curtain Controller',
          price: 2899,
        ),
        ShopItem(
          id: 'smart_door_sensor',
          name: 'Smart Door Sensor',
          price: 1299,
        ),
        ShopItem(
          id: 'smart_temperature_sensor',
          name: 'Smart Temperature Sensor',
          price: 1599,
        ),
        ShopItem(
          id: 'smart_water_leak_sensor',
          name: 'Smart Water Leak Sensor',
          price: 1499,
        ),
        ShopItem(
          id: 'smart_light_controller',
          name: 'Smart Light Controller',
          price: 1799,
        ),
        ShopItem(
          id: 'smart_garage_door_controller',
          name: 'Smart Garage Door Controller',
          price: 3499,
        ),
      ],
    ),
    ShopCategory(
      id: 'audio_devices',
      name: 'Audio Devices',
      icon: Icons.audiotrack_rounded,
      accentColor: Colors.blueGrey,
      items: <ShopItem>[
        ShopItem(
          id: 'bluetooth_speaker_2',
          name: 'Bluetooth Speaker',
          price: 2400,
        ),
        ShopItem(id: 'soundbar', name: 'Soundbar', price: 6800),
        ShopItem(id: 'home_theater', name: 'Home Theater', price: 18500),
        ShopItem(id: 'portable_speaker', name: 'Portable Speaker', price: 2100),
        ShopItem(id: 'microphone', name: 'Microphone', price: 1800),
        ShopItem(id: 'amplifier', name: 'Amplifier', price: 7200),
        ShopItem(id: 'karaoke_system', name: 'Karaoke System', price: 12400),
        ShopItem(id: 'dj_controller', name: 'DJ Controller', price: 22600),
      ],
    ),
  ];

  Future<void> _warmUpOnlineItemImages() async {
    final List<ShopCategory> snapshot = <ShopCategory>[
      ...categoriesNotifier.value,
    ];
    for (final category in snapshot) {
      for (final item in category.items) {
        final String currentUrl = (item.imageUrl ?? '').trim();
        if (currentUrl.isNotEmpty) continue;
        final String? onlineUrl = await _resolveOnlineImageUrl(
          itemId: item.id,
          itemName: item.name,
          categoryName: category.name,
        );
        if (onlineUrl == null || onlineUrl.trim().isEmpty) continue;
        _applyImageUrl(
          categoryId: category.id,
          itemId: item.id,
          imageUrl: onlineUrl,
        );
      }
    }
  }

  Future<void> _warmUpOnlineCategoryImages() async {
    final List<ShopCategory> snapshot = <ShopCategory>[
      ...categoriesNotifier.value,
    ];
    for (final category in snapshot) {
      final String currentUrl = (category.imageUrl ?? '').trim();
      if (currentUrl.isNotEmpty) continue;
      final String? onlineUrl = await _resolveOnlineCategoryImageUrl(
        categoryId: category.id,
        categoryName: category.name,
      );
      if (onlineUrl == null || onlineUrl.trim().isEmpty) continue;
      _applyCategoryImageUrl(categoryId: category.id, imageUrl: onlineUrl);
    }
  }

  Future<String?> _resolveOnlineImageUrl({
    required String itemId,
    required String itemName,
    required String categoryName,
  }) {
    final String key = '$categoryName::$itemId';
    final Future<String?>? cached = _pendingImageLookups[key];
    if (cached != null) {
      return cached;
    }
    final Future<String?> lookup = _fetchWikimediaThumbnail(
      itemName: itemName,
      categoryName: categoryName,
    );
    _pendingImageLookups[key] = lookup;
    return lookup.whenComplete(() => _pendingImageLookups.remove(key));
  }

  Future<String?> _resolveOnlineCategoryImageUrl({
    required String categoryId,
    required String categoryName,
  }) {
    final String key = 'category::$categoryId';
    final Future<String?>? cached = _pendingImageLookups[key];
    if (cached != null) {
      return cached;
    }
    final Future<String?> lookup = () async {
      final String? title = _categoryWikiTitleById[categoryId];
      if (title != null) {
        final String? bySummary = await _fetchWikipediaSummaryThumbnail(title);
        if (bySummary != null && bySummary.trim().isNotEmpty) {
          return bySummary.trim();
        }
      }
      final String? bySearch = await _fetchWikimediaThumbnailFromQueries(
        _categoryImageQueries(categoryName),
      );
      if (bySearch != null && bySearch.trim().isNotEmpty) {
        return bySearch.trim();
      }
      return _onlineCategoryKeywordImageUrl(categoryName);
    }();
    _pendingImageLookups[key] = lookup;
    return lookup.whenComplete(() => _pendingImageLookups.remove(key));
  }

  Future<String?> _fetchWikimediaThumbnail({
    required String itemName,
    required String categoryName,
  }) async {
    final List<String> queries = _imageQueries(itemName, categoryName);
    return _fetchWikimediaThumbnailFromQueries(queries);
  }

  Future<String?> _fetchWikimediaThumbnailFromQueries(
    List<String> queries,
  ) async {
    for (final q in queries) {
      final Uri uri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'generator': 'search',
        'gsrsearch': q,
        'gsrlimit': '1',
        'prop': 'pageimages',
        'piprop': 'thumbnail',
        'pithumbsize': '700',
        'origin': '*',
      });
      try {
        final http.Response res = await http
            .get(uri)
            .timeout(const Duration(seconds: 7));
        if (res.statusCode != 200) continue;
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) continue;
        final dynamic query = decoded['query'];
        if (query is! Map<String, dynamic>) continue;
        final dynamic pages = query['pages'];
        if (pages is! Map<String, dynamic> || pages.isEmpty) continue;
        for (final dynamic raw in pages.values) {
          if (raw is! Map<String, dynamic>) continue;
          final dynamic thumbnail = raw['thumbnail'];
          if (thumbnail is! Map<String, dynamic>) continue;
          final dynamic source = thumbnail['source'];
          if (source is String && source.trim().isNotEmpty) {
            return source.trim();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _fetchWikipediaSummaryThumbnail(String title) async {
    final Uri uri = Uri.parse(
      'https://en.wikipedia.org/api/rest_v1/page/summary/'
      '${Uri.encodeComponent(title)}',
    );
    try {
      final http.Response res = await http
          .get(uri)
          .timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      final dynamic thumbnail = decoded['thumbnail'];
      if (thumbnail is! Map<String, dynamic>) return null;
      final dynamic source = thumbnail['source'];
      if (source is String && source.trim().isNotEmpty) {
        return source.trim();
      }
    } catch (_) {}
    return null;
  }

  List<String> _imageQueries(String itemName, String categoryName) {
    final String normalized = itemName.trim();
    final String lower = normalized.toLowerCase();
    final List<String> out = <String>[
      '$normalized $categoryName product',
      '$normalized appliance',
      '$normalized electronics',
      normalized,
    ];

    if (lower == 'mcb') {
      out.insert(0, 'Miniature circuit breaker');
    } else if (lower == 'elcb') {
      out.insert(0, 'Earth leakage circuit breaker');
    } else if (lower == 'dvr' || lower.contains('security dvr')) {
      out.insert(0, 'Digital video recorder CCTV');
    } else if (lower.contains('ac ')) {
      out.insert(0, 'Air conditioner spare part');
    } else if (lower.contains('usb')) {
      out.insert(0, 'USB accessory');
    } else if (lower.contains('smart')) {
      out.insert(0, 'Smart home device');
    }
    return out;
  }

  List<String> _categoryImageQueries(String categoryName) {
    final String normalized = categoryName.trim();
    final String lower = normalized.toLowerCase();
    final List<String> out = <String>[
      '$normalized electronics category',
      '$normalized tools category',
      '$normalized devices',
      normalized,
    ];

    if (lower.contains('electrical')) {
      out.insert(0, 'Electrical components');
    } else if (lower.contains('repair')) {
      out.insert(0, 'Repair tools');
    } else if (lower.contains('smart')) {
      out.insert(0, 'Smart home devices');
    } else if (lower.contains('automation')) {
      out.insert(0, 'Home automation');
    } else if (lower.contains('security')) {
      out.insert(0, 'Home security system');
    } else if (lower.contains('audio')) {
      out.insert(0, 'Audio equipment');
    }
    return out;
  }

  static const Map<String, String> _categoryWikiTitleById = <String, String>{
    'electrical_components': 'Electrical wiring',
    'repair_tools': 'Hand tool',
    'smart_devices': 'Smart home',
    'maintenance_products': 'Cleaning agent',
    'accessories': 'Electronic component',
    'computer_accessories': 'Computer peripheral',
    'mobile_accessories': 'Mobile phone accessories',
    'lighting_equipment': 'Lighting',
    'home_security_devices': 'Home security',
    'home_automation': 'Home automation',
    'audio_devices': 'Audio equipment',
  };

  String _onlineCategoryKeywordImageUrl(String categoryName) {
    final String key = categoryName.toLowerCase().trim().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      ',',
    );
    return 'https://loremflickr.com/700/700/$key,electronics';
  }

  void _applyImageUrl({
    required String categoryId,
    required String itemId,
    required String imageUrl,
  }) {
    bool changed = false;
    final List<ShopCategory> updated = categoriesNotifier.value
        .map((category) {
          if (category.id != categoryId) return category;
          final List<ShopItem> items = category.items
              .map((item) {
                if (item.id != itemId) return item;
                final String existing = (item.imageUrl ?? '').trim();
                if (existing.isNotEmpty) return item;
                changed = true;
                return item.copyWith(imageUrl: imageUrl);
              })
              .toList(growable: false);
          return category.copyWith(items: items);
        })
        .toList(growable: false);
    if (changed) {
      categoriesNotifier.value = updated;
    }
  }

  void _applyCategoryImageUrl({
    required String categoryId,
    required String imageUrl,
  }) {
    bool changed = false;
    final List<ShopCategory> updated = categoriesNotifier.value
        .map((category) {
          if (category.id != categoryId) return category;
          final String existing = (category.imageUrl ?? '').trim();
          if (existing.isNotEmpty) return category;
          changed = true;
          return category.copyWith(imageUrl: imageUrl);
        })
        .toList(growable: false);
    if (changed) {
      categoriesNotifier.value = updated;
    }
  }

  void addCategory({
    required String name,
    IconData icon = Icons.storefront_rounded,
    Color accentColor = Colors.deepPurple,
    String? imageUrl,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final String id = _buildId(trimmed);
    final ShopCategory category = ShopCategory(
      id: id,
      name: trimmed,
      icon: icon,
      accentColor: accentColor,
      imageUrl: imageUrl,
      items: const <ShopItem>[],
    );
    categoriesNotifier.value = <ShopCategory>[
      ...categoriesNotifier.value,
      category,
    ];
    if ((imageUrl ?? '').trim().isEmpty) {
      _resolveOnlineCategoryImageUrl(
        categoryId: id,
        categoryName: trimmed,
      ).then((url) {
        if (url == null || url.trim().isEmpty) return;
        _applyCategoryImageUrl(categoryId: id, imageUrl: url);
      });
    }
  }

  void removeCategory(String categoryId) {
    categoriesNotifier.value = categoriesNotifier.value
        .where((c) => c.id != categoryId)
        .toList();
  }

  void addItem({
    required String categoryId,
    required String name,
    required int price,
    String? imageUrl,
    String? brand,
    String? about,
    String? model,
    String? modelNumber,
    String? itemType,
    String? shade,
    String? material,
    String? packOf,
    String? deliveryLocation,
    int? deliveryWorkingDays,
    String? aboutSeller,
    double? overallRating,
    double? productQuality,
    double? serviceQuality,
    String? warranty,
    String? suitableFor,
    List<String>? highlights,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || price <= 0) return;
    final ShopItem item = ShopItem(
      id: _buildId(trimmed),
      name: trimmed,
      price: price,
      imageUrl: imageUrl,
      brand: brand,
      about: about,
      model: model,
      modelNumber: modelNumber,
      itemType: itemType,
      shade: shade,
      material: material,
      packOf: packOf,
      deliveryLocation: deliveryLocation,
      deliveryWorkingDays: deliveryWorkingDays,
      aboutSeller: aboutSeller,
      overallRating: overallRating,
      productQuality: productQuality,
      serviceQuality: serviceQuality,
      warranty: warranty,
      suitableFor: suitableFor,
      highlights: highlights ?? const <String>[],
    );
    categoriesNotifier.value = categoriesNotifier.value.map((category) {
      if (category.id != categoryId) return category;
      return category.copyWith(items: <ShopItem>[...category.items, item]);
    }).toList();
    if ((item.imageUrl ?? '').trim().isEmpty) {
      _resolveOnlineImageUrl(
        itemId: item.id,
        itemName: item.name,
        categoryName: _categoryNameById(categoryId),
      ).then((url) {
        if (url == null || url.trim().isEmpty) return;
        _applyImageUrl(categoryId: categoryId, itemId: item.id, imageUrl: url);
      });
    }
  }

  void removeItem({required String categoryId, required String itemId}) {
    categoriesNotifier.value = categoriesNotifier.value.map((category) {
      if (category.id != categoryId) return category;
      return category.copyWith(
        items: category.items.where((i) => i.id != itemId).toList(),
      );
    }).toList();
  }

  static String _buildId(String source) {
    final String base = source.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    return '${base}_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _categoryNameById(String categoryId) {
    for (final category in categoriesNotifier.value) {
      if (category.id == categoryId) return category.name;
    }
    return 'Electronics';
  }
}

class ShopCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color accentColor;
  final String? imageUrl;
  final List<ShopItem> items;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.accentColor,
    this.imageUrl,
    required this.items,
  });

  ShopCategory copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? accentColor,
    String? imageUrl,
    List<ShopItem>? items,
  }) {
    return ShopCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      imageUrl: imageUrl ?? this.imageUrl,
      items: items ?? this.items,
    );
  }

  String get effectiveImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl!.trim();
    }
    final String key = name.toLowerCase().trim().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      ',',
    );
    return 'https://loremflickr.com/700/700/$key,electronics';
  }
}

class ShopItem {
  final String id;
  final String name;
  final int price;
  final String? imageUrl;
  final String? brand;
  final String? about;
  final String? model;
  final String? modelNumber;
  final String? itemType;
  final String? shade;
  final String? material;
  final String? packOf;
  final String? deliveryLocation;
  final int? deliveryWorkingDays;
  final String? aboutSeller;
  final double? overallRating;
  final double? productQuality;
  final double? serviceQuality;
  final String? warranty;
  final String? suitableFor;
  final List<String> highlights;

  static const Map<String, String> _brandHints = <String, String>{
    'smart': 'SmartLife',
    'camera': 'SecureVision',
    'charger': 'PowerMax',
    'battery': 'PowerCell',
    'switch': 'VoltEdge',
    'wire': 'CopperCore',
    'cable': 'CableLink',
    'speaker': 'SoundPro',
    'headphone': 'AudioWave',
    'earbud': 'AudioWave',
    'bulb': 'LumaTech',
    'light': 'LumaTech',
    'drill': 'FixMaster',
    'multimeter': 'MeterPro',
    'tool': 'FixMaster',
    'mouse': 'ClickPro',
    'keyboard': 'TypeFlow',
    'lock': 'SafeHome',
    'sensor': 'SenseGuard',
  };

  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.brand,
    this.about,
    this.model,
    this.modelNumber,
    this.itemType,
    this.shade,
    this.material,
    this.packOf,
    this.deliveryLocation,
    this.deliveryWorkingDays,
    this.aboutSeller,
    this.overallRating,
    this.productQuality,
    this.serviceQuality,
    this.warranty,
    this.suitableFor,
    this.highlights = const <String>[],
  });

  ShopItem copyWith({
    String? id,
    String? name,
    int? price,
    String? imageUrl,
    String? brand,
    String? about,
    String? model,
    String? modelNumber,
    String? itemType,
    String? shade,
    String? material,
    String? packOf,
    String? deliveryLocation,
    int? deliveryWorkingDays,
    String? aboutSeller,
    double? overallRating,
    double? productQuality,
    double? serviceQuality,
    String? warranty,
    String? suitableFor,
    List<String>? highlights,
  }) {
    return ShopItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      brand: brand ?? this.brand,
      about: about ?? this.about,
      model: model ?? this.model,
      modelNumber: modelNumber ?? this.modelNumber,
      itemType: itemType ?? this.itemType,
      shade: shade ?? this.shade,
      material: material ?? this.material,
      packOf: packOf ?? this.packOf,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      deliveryWorkingDays: deliveryWorkingDays ?? this.deliveryWorkingDays,
      aboutSeller: aboutSeller ?? this.aboutSeller,
      overallRating: overallRating ?? this.overallRating,
      productQuality: productQuality ?? this.productQuality,
      serviceQuality: serviceQuality ?? this.serviceQuality,
      warranty: warranty ?? this.warranty,
      suitableFor: suitableFor ?? this.suitableFor,
      highlights: highlights ?? this.highlights,
    );
  }

  String get effectiveImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl!.trim();
    }
    final String placeholder = Uri.encodeComponent(name.trim());
    return 'https://placehold.co/700x700/png?text=$placeholder';
  }

  String get displayBrand {
    final String? provided = _clean(brand);
    if (provided != null) {
      return provided;
    }

    final String lower = name.toLowerCase();
    for (final entry in _brandHints.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'ServeZ Select';
  }

  String get displayModel {
    final String? provided = _clean(model);
    if (provided != null) {
      return provided;
    }
    final String compact = name.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final String seed = compact.length >= 4
        ? compact.substring(0, 4)
        : compact.padRight(4, 'X');
    return 'SZ-$seed-$price';
  }

  String get displayModelNumber {
    final String? provided = _clean(modelNumber);
    if (provided != null) {
      return provided;
    }
    final String base = displayModel.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    return '$base-MN';
  }

  String get displayType {
    final String? provided = _clean(itemType);
    if (provided != null) {
      return provided;
    }
    final String lower = name.toLowerCase();
    if (lower.contains('switch')) {
      return 'Electrical Switch';
    }
    if (lower.contains('cable') || lower.contains('wire')) {
      return 'Cable Accessory';
    }
    if (lower.contains('charger') || lower.contains('adapter')) {
      return 'Power Accessory';
    }
    if (lower.contains('camera')) {
      return 'Security Device';
    }
    if (lower.contains('speaker') || lower.contains('headphone')) {
      return 'Audio Device';
    }
    if (lower.contains('sensor')) {
      return 'Smart Sensor';
    }
    if (lower.contains('bulb') || lower.contains('light')) {
      return 'Lighting Device';
    }
    if (lower.contains('drill') || lower.contains('tool')) {
      return 'Repair Tool';
    }
    return 'Electronic Accessory';
  }

  String get displayShade {
    final String? provided = _clean(shade);
    if (provided != null) {
      return provided;
    }
    final String lower = name.toLowerCase();
    if (lower.contains('bulb') || lower.contains('light')) {
      return 'Cool White';
    }
    if (lower.contains('camera') || lower.contains('security')) {
      return 'Matte Black';
    }
    return 'Standard';
  }

  String get displayMaterial {
    final String? provided = _clean(material);
    if (provided != null) {
      return provided;
    }
    final String lower = name.toLowerCase();
    if (lower.contains('wire') || lower.contains('cable')) {
      return 'Copper + PVC';
    }
    if (lower.contains('tool') ||
        lower.contains('drill') ||
        lower.contains('plier')) {
      return 'Alloy Steel';
    }
    if (lower.contains('case') || lower.contains('holder')) {
      return 'ABS Plastic';
    }
    return 'Engineering Grade Polymer';
  }

  String get displayPackOf {
    final String? provided = _clean(packOf);
    return provided ?? '1';
  }

  String get displayDeliveryLocation {
    final String? provided = _clean(deliveryLocation);
    if (provided != null) {
      return provided;
    }
    const List<String> hubs = <String>[
      'Chennai Hub',
      'Bengaluru Hub',
      'Hyderabad Hub',
      'Coimbatore Hub',
    ];
    final int seed = _seed();
    return hubs[seed % hubs.length];
  }

  int get displayDeliveryWorkingDays {
    final int? provided = deliveryWorkingDays;
    if (provided != null && provided >= 1) {
      return provided;
    }
    const List<int> options = <int>[3, 4, 5, 6];
    final int seed = _seed();
    return options[seed % options.length];
  }

  String get displayAboutSeller {
    final String? provided = _clean(aboutSeller);
    if (provided != null) {
      return provided;
    }
    return 'Trusted local seller with verified delivery and quality checks for every order.';
  }

  double get displayOverallRating {
    final double? provided = overallRating;
    if (provided != null && provided > 0) {
      return _clampRating(provided);
    }
    final double seedRating = 4.1 + ((_seed() % 8) * 0.1);
    return _clampRating(seedRating);
  }

  double get displayProductQuality {
    final double? provided = productQuality;
    if (provided != null && provided > 0) {
      return _clampRating(provided);
    }
    final double rating = displayOverallRating + 0.1;
    return _clampRating(rating);
  }

  double get displayServiceQuality {
    final double? provided = serviceQuality;
    if (provided != null && provided > 0) {
      return _clampRating(provided);
    }
    final double rating = displayOverallRating - 0.1;
    return _clampRating(rating);
  }

  String get displayAbout {
    final String? provided = _clean(about);
    if (provided != null) {
      return provided;
    }
    return 'Reliable ${name.toLowerCase()} built for daily electrical, repair, and home-utility use.';
  }

  String get displayWarranty {
    final String? provided = _clean(warranty);
    return provided ?? '6 months seller warranty';
  }

  String get displaySuitableFor {
    final String? provided = _clean(suitableFor);
    return provided ?? 'Home and professional service use';
  }

  List<String> get displayHighlights {
    final List<String> provided = highlights
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList(growable: false);
    final List<String> meta = <String>[
      'Pack of ${displayPackOf}',
      'Delivery in ${displayDeliveryWorkingDays} working days',
      'Type: ${displayType}',
      'Shade: ${displayShade}',
      'Material: ${displayMaterial}',
    ];
    final List<String> merged = <String>[
      ...provided,
      ..._defaultHighlights(),
      ...meta,
    ];
    return merged.take(6).toList(growable: false);
  }

  List<String> _defaultHighlights() {
    final String lower = name.toLowerCase();
    final List<String> out = <String>[];

    if (lower.contains('wire') || lower.contains('cable')) {
      out.addAll(<String>['Heat-resistant insulation', 'Stable current flow']);
    }
    if (lower.contains('switch') || lower.contains('socket')) {
      out.addAll(<String>['Easy wall-mount fit', 'Shock-safe contact design']);
    }
    if (lower.contains('battery') ||
        lower.contains('power bank') ||
        lower.contains('charger')) {
      out.addAll(<String>[
        'Fast and stable charging',
        'Over-voltage protection',
      ]);
    }
    if (lower.contains('camera') ||
        lower.contains('sensor') ||
        lower.contains('lock')) {
      out.addAll(<String>[
        'Reliable device integration',
        'Low-power operation',
      ]);
    }
    if (lower.contains('tool') ||
        lower.contains('drill') ||
        lower.contains('screwdriver') ||
        lower.contains('plier')) {
      out.addAll(<String>[
        'Durable build quality',
        'Comfortable grip handling',
      ]);
    }

    if (out.isEmpty) {
      out.addAll(<String>[
        'Quality tested product',
        'Easy installation',
        'Long-lasting performance',
      ]);
    }
    return out.take(4).toList(growable: false);
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _seed() {
    return id.codeUnits.fold<int>(0, (prev, e) => prev + e);
  }

  double _clampRating(double value) {
    if (value < 0) return 0;
    if (value > 5) return 5;
    return value;
  }
}
