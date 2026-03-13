import 'package:flutter/material.dart';

class ShopCatalogStore {
  ShopCatalogStore._();

  static final ShopCatalogStore instance = ShopCatalogStore._();

  final ValueNotifier<List<ShopCategory>> categoriesNotifier =
      ValueNotifier<List<ShopCategory>>(_initialCategories);

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
        ShopItem(
          id: 'insulated_gloves',
          name: 'Insulated Gloves',
          price: 300,
        ),
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
        ShopItem(
          id: 'wireless_charger',
          name: 'Wireless Charger',
          price: 1400,
        ),
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

  void addCategory({
    required String name,
    IconData icon = Icons.storefront_rounded,
    Color accentColor = Colors.deepPurple,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final String id = _buildId(trimmed);
    final ShopCategory category = ShopCategory(
      id: id,
      name: trimmed,
      icon: icon,
      accentColor: accentColor,
      items: const <ShopItem>[],
    );
    categoriesNotifier.value = <ShopCategory>[...categoriesNotifier.value, category];
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
      warranty: warranty,
      suitableFor: suitableFor,
      highlights: highlights ?? const <String>[],
    );
    categoriesNotifier.value = categoriesNotifier.value.map((category) {
      if (category.id != categoryId) return category;
      return category.copyWith(items: <ShopItem>[...category.items, item]);
    }).toList();
  }

  void removeItem({
    required String categoryId,
    required String itemId,
  }) {
    categoriesNotifier.value = categoriesNotifier.value.map((category) {
      if (category.id != categoryId) return category;
      return category.copyWith(
        items: category.items.where((i) => i.id != itemId).toList(),
      );
    }).toList();
  }

  static String _buildId(String source) {
    final String base = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${base}_${DateTime.now().microsecondsSinceEpoch}';
  }
}

class ShopCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color accentColor;
  final List<ShopItem> items;

  const ShopCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.accentColor,
    required this.items,
  });

  ShopCategory copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? accentColor,
    List<ShopItem>? items,
  }) {
    return ShopCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
      items: items ?? this.items,
    );
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
    this.warranty,
    this.suitableFor,
    this.highlights = const <String>[],
  });

  String get effectiveImageUrl {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl!.trim();
    }
    final query = name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ',');
    return 'https://source.unsplash.com/600x600/?$query,electronics,device,tool,accessory';
  }

  String get displayBrand {
    final String? provided = _clean(brand);
    if (provided != null) return provided;

    final String lower = name.toLowerCase();
    for (final entry in _brandHints.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'ServeZ Select';
  }

  String get displayModel {
    final String? provided = _clean(model);
    if (provided != null) return provided;
    final String compact =
        name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final String seed =
        compact.length >= 4 ? compact.substring(0, 4) : compact.padRight(4, 'X');
    return 'SZ-$seed-$price';
  }

  String get displayAbout {
    final String? provided = _clean(about);
    if (provided != null) return provided;
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
    if (provided.isNotEmpty) return provided.take(4).toList(growable: false);
    return _defaultHighlights();
  }

  List<String> _defaultHighlights() {
    final String lower = name.toLowerCase();
    final List<String> out = <String>[];

    if (lower.contains('wire') || lower.contains('cable')) {
      out.addAll(<String>[
        'Heat-resistant insulation',
        'Stable current flow',
      ]);
    }
    if (lower.contains('switch') || lower.contains('socket')) {
      out.addAll(<String>[
        'Easy wall-mount fit',
        'Shock-safe contact design',
      ]);
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
}
