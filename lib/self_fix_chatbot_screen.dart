import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:serviceprovider/utils/search_tokens.dart';
import 'package:serviceprovider/self_fix_screen.dart';
import 'package:serviceprovider/repair_guide_screen.dart';
import 'package:serviceprovider/view_services_screen.dart';
import 'package:serviceprovider/service_search_screen.dart';
import 'package:serviceprovider/my_requests_screen.dart';
import 'package:serviceprovider/customer_view_service_screen.dart';

class SelfFixChatbotScreen extends StatefulWidget {
  const SelfFixChatbotScreen({super.key});

  @override
  State<SelfFixChatbotScreen> createState() => _SelfFixChatbotScreenState();
}

class _SelfFixChatbotScreenState extends State<SelfFixChatbotScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isProcessing = false;
  final ImagePicker _imagePicker = ImagePicker();
  static final Set<String> _brandStopTokens = {
    'laptop',
    'notebook',
    'computer',
    'pc',
    'desktop',
    'monitor',
    'screen',
    'display',
    'keyboard',
    'mouse',
    'touch',
    'touchscreen',
    'windows',
    'intel',
    'core',
    'inside',
    'processor',
    'cpu',
    'gpu',
    'graphics',
    'nvidia',
    'geforce',
    'amd',
    'ryzen',
    'ram',
    'ssd',
    'hdd',
    'storage',
    'drive',
    'usb',
    'hd',
    'fhd',
    'uhd',
    '4k',
    '1080',
    '720',
    'wifi',
    'bluetooth',
    'battery',
    'charger',
    'adapter',
    'power',
    'input',
    'output',
    'voltage',
    'model',
    'serial',
    'number',
    'product',
    'made',
    'china',
    'service',
    'repair',
    'support',
    'warranty',
    'energy',
    'star',
    'led',
    'lcd',
    'smart',
    'thin',
    'light',
    'pro',
    'air',
    'max',
    'mini',
    'book',
    'series',
    'device',
    'appliance',
    'tv',
    'ac',
    'fan',
    'fridge',
    'refrigerator',
    'washing',
    'machine',
    'oven',
    'microwave',
    'cooling',
    'heating',
    'unit',
    'home',
    'office',
    'system',
    'brand',
    'logo',
    'madein',
    'i3',
    'i5',
    'i7',
    'i9',
    'watt',
    'watts',
    'volt',
    'volts',
    'hz',
    'amps',
    'amp',
    'kg',
    'cm',
    'mm',
  };
  static const Set<String> _knownBrandTokens = {
    'acer',
    'apple',
    'asus',
    'dell',
    'hp',
    'lenovo',
    'msi',
    'samsung',
    'sony',
    'toshiba',
    'huawei',
    'xiaomi',
    'oneplus',
    'oppo',
    'vivo',
    'realme',
    'nokia',
    'lg',
    'panasonic',
    'whirlpool',
    'haier',
    'bosch',
    'godrej',
    'voltas',
    'daikin',
  };

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      'Hi, I am your ServeSphere assistant. You can:\n'
      '• Describe an issue (e.g. "my AC is not cooling")\n'
      '• Ask for a service (e.g. "need an electrician near me")\n'
      '• Ask about your booking status (e.g. "status of my last booking")\n'
      '• Type "self fix" for basic troubleshooting tips',
    );
  }

  void _showServiceBasedProvidersSheet(List<QueryDocumentSnapshot> serviceDocs, String applianceLabel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.miscellaneous_services_rounded, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Services for $applianceLabel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: serviceDocs.length,
                  itemBuilder: (context, index) {
                    final doc = serviceDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final serviceName = (data['serviceName'] as String?) ?? 'Service';
                    final location = (data['addressDisplay'] as String?) ?? (data['locationAddress'] as String?) ?? '';

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.build_rounded, color: Colors.white),
                      ),
                      title: Text(serviceName),
                      subtitle: Text(
                        location.isNotEmpty ? location : 'Nearby service provider',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _openServiceFromSuggestions(doc.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 0),
                        ),
                        child: const Text('Book'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openServiceFromSuggestions(String serviceId) async {
    final id = serviceId.trim();
    if (id.isEmpty || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerViewServiceScreen(serviceId: id),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromBot: false));
    });
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, fromBot: true));
    });
  }

  void _addImageMessage(String imagePath, {bool fromBot = false}) {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: '',
          fromBot: fromBot,
          imagePath: imagePath,
        ),
      );
    });
  }

  Future<void> _handleSend() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty || _isProcessing) return;
    _inputController.clear();
    _addUserMessage(raw);

    setState(() {
      _isProcessing = true;
    });

    try {
      await _routeIntent(raw);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _routeIntent(String text) async {
    final lower = text.toLowerCase();

    if (lower.contains('status') || lower.contains('booking') || lower.contains('request')) {
      await _handleBookingStatusIntent(lower);
      return;
    }

    if (lower.contains('self fix') || lower.contains('self-fix') || lower.contains('troubleshoot')) {
      _addBotMessage('Opening SelfFix tools. You can explore quick checks and repair guides.');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SelfFixScreen()),
      );
      return;
    }

    if (lower.contains('guide') || lower.contains('repair')) {
      _addBotMessage('Opening detailed SelfFix repair guides for you.');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RepairGuideScreen()),
      );
      return;
    }

    if (lower.contains('service') || lower.contains('electrician') || lower.contains('plumb') || lower.contains('clean') || lower.contains('ac') || lower.contains('paint')) {
      await _handleServiceDiscoveryIntent(lower);
      return;
    }

    if (lower.contains('help') || lower.contains('how to use') || lower.contains('what can you do')) {
      _addBotMessage(
        'Here is what I can help you with right now:\n'
        '• Discover services near you\n'
        '• Suggest quick self-fix checks for basic issues\n'
        '• Show status of your recent bookings\n'
        '• Navigate to service list, search, and your requests timeline',
      );
      return;
    }

    await _handleServiceDiscoveryIntent(lower);
  }

  Future<void> _handleServiceDiscoveryIntent(String lower) async {
    String? category;
    if (lower.contains('plumb')) category = 'Plumbing';
    if (lower.contains('electric')) category = 'Electrician';
    if (lower.contains('clean')) category = 'Cleaning';
    if (lower.contains('paint')) category = 'Painting';
    if (lower.contains('ac') || lower.contains('air condition')) category = 'AC';

    if (category == null) {
      _addBotMessage(
        'I can help you find services. You can type things like:\n'
        '• "need an electrician for fan repair"\n'
        '• "looking for plumbing help"\n'
        'Or tap below to browse all services or search.',
      );
      _addBotMessage('[Action] Browse services or search to continue.');
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('services')
          .where('category', isEqualTo: category)
          .limit(5)
          .get();

      if (query.docs.isEmpty) {
        _addBotMessage('I could not find services under "$category" right now. You can still open the full services list to check.');
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('I found some "$category" services you might like:');
      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['serviceName'] as String?) ?? 'Service';
        final location = (data['addressDisplay'] as String?) ?? (data['locationAddress'] as String?) ?? '';
        buffer.write('- $name');
        if (location.isNotEmpty) buffer.write(' · $location');
        buffer.writeln();
      }
      buffer.writeln('You can tap below to view full details and book.');

      _addBotMessage(buffer.toString());
    } catch (e) {
      _addBotMessage('I had trouble fetching services right now. Please try again later or open the services list from the dashboard.');
    }
  }

  Future<void> _handleBookingStatusIntent(String lower) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addBotMessage('You need to be logged in to see your booking status.');
      return;
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('customerId', isEqualTo: user.uid)
          .orderBy('bookingTimestamp', descending: true)
          .limit(1);

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        _addBotMessage('I could not find any service requests linked to your account yet.');
        return;
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? 'pending';
      final serviceName = (data['serviceName'] as String?) ?? 'Service request';

      _addBotMessage('Your most recent request "$serviceName" is currently "$status". You can open "My Requests" from the dashboard to see full timeline and details.');
    } catch (e) {
      _addBotMessage('I could not load your booking status right now. Please try again in a moment or open My Requests directly.');
    }
  }

  void _handleQuickActionTap(String action) {
    if (action == 'browse_services') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ViewServicesScreen()),
      );
      return;
    }
    if (action == 'search_services') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServiceSearchScreen()),
      );
      return;
    }
    if (action == 'my_requests') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
      );
      return;
    }
    if (action == 'self_fix') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SelfFixScreen()),
      );
      return;
    }
    if (action == 'scan_appliance') {
      _handleApplianceScanAction();
      return;
    }
  }

  Future<void> _handleApplianceScanAction() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      _addBotMessage(
        'Let\'s identify your appliance. Please take a clear photo showing the full appliance.',
      );

      final XFile? imageFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 1024,
      );

      if (imageFile == null) {
        _addBotMessage('No image captured. You can try the camera option again anytime.');
        return;
      }

      _addImageMessage(imageFile.path, fromBot: false);

      _addBotMessage('Image captured. Analyzing the appliance and prioritizing providers based on success rate and experience...');

      await _classifyApplianceAndSuggestProviders(imageFile);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _classifyApplianceAndSuggestProviders(XFile imageFile) async {
    try {
      final String applianceLabel = await _runApplianceClassification(imageFile);
      final List<String> brandTokens = await _detectBrandTokens(imageFile);

      if (applianceLabel.isEmpty || applianceLabel == 'Unknown Appliance') {
        _addBotMessage(
          'I could not confidently identify the appliance from the photo. You can try another angle, better lighting, or describe the appliance and issue in text. You can also use the search and browse options below to find a suitable service.',
        );
        return;
      }

      // Log the detected appliance type as a service request snapshot.
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userId = user?.uid ?? 'anonymous';

        await FirebaseFirestore.instance.collection('service_requests').add({
          'userId': userId,
          'applianceType': applianceLabel,
          'brandTokens': brandTokens,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Ignore logging errors so main chatbot flow is not affected.
      }

      _addBotMessage('I detected that this looks like a "$applianceLabel". Let me fetch suitable service providers for you.');

      await _suggestProvidersForAppliance(applianceLabel, brandTokens: brandTokens);
    } catch (e) {
      _addBotMessage(
        'I had trouble analyzing the image just now. Please try again later or describe the appliance and issue in text.',
      );
    }
  }

  Future<String> _runApplianceClassification(XFile imageFile) async {
    try {
      final file = File(imageFile.path);
      final inputImage = InputImage.fromFile(file);

      // Use a slightly lower confidence threshold so that we
      // still see relevant labels for common appliances such
      // as laptops and computers in real-world lighting.
      final labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.3),
      );

      final List<ImageLabel> labels = await labeler.processImage(inputImage);
      labeler.close();

      for (final label in labels) {
        final text = label.label.toLowerCase();

        // Handle some common real-world labels explicitly first.
        if (text.contains('pedestal fan')) {
          return 'Fan';
        }
        if (text.contains('split ac indoor unit') || text.contains('split ac')) {
          return 'Air Conditioner';
        }

        if (text.contains('washing') || text.contains('washer') || text.contains('washing machine')) {
          return 'Washing Machine';
        }

        if (text.contains('refrigerator') || text.contains('fridge') || text.contains('freezer')) {
          return 'Refrigerator';
        }

        if (text.contains('television') || text.contains('tv') || text.contains('monitor tv')) {
          return 'Television';
        }

        // Prefer mapping anything clearly marked as a fan (ceiling fan,
        // table/desk/standing fan, etc.) to Fan before we consider
        // AC-related labels.
        if (text.contains('fan') ||
            text.contains('ceiling fan') ||
            text.contains('table fan') ||
            text.contains('desk fan') ||
            text.contains('standing fan') ||
            text.contains('electric fan')) {
          return 'Fan';
        }

        if (text.contains('air conditioner') ||
            text.contains('air conditioning') ||
            text.contains('ac unit') ||
            text.contains('aircon') ||
            text.contains('hvac')) {
          return 'Air Conditioner';
        }

        if (text.contains('mobile') || text.contains('phone') || text.contains('smartphone')) {
          return 'Mobile Phone';
        }

        if (text.contains('laptop') ||
            text.contains('notebook') ||
            text.contains('computer') ||
            text.contains('pc') ||
            text.contains('keyboard') ||
            text.contains('screen') ||
            text.contains('monitor')) {
          return 'Laptop';
        }
      }

      return '';
    } catch (_) {
      return '';
    }
  }

  Future<List<String>> _detectBrandTokens(XFile imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return _extractBrandTokens(recognizedText.text);
    } catch (_) {
      return const [];
    } finally {
      textRecognizer.close();
    }
  }

  List<String> _extractBrandTokens(String text) {
    final Set<String> tokens = <String>{};
    final matches = RegExp(r'[A-Za-z0-9]+').allMatches(text);
    for (final m in matches) {
      final token = m.group(0);
      if (token == null) continue;
      final lower = token.toLowerCase();
      if (lower.length < 2) continue;
      if (RegExp(r'^\d+$').hasMatch(lower)) continue;
      if (_brandStopTokens.contains(lower)) continue;
      tokens.add(lower);
    }
    final list = tokens.toList()
      ..sort((a, b) {
        final len = b.length.compareTo(a.length);
        return len != 0 ? len : a.compareTo(b);
      });
    final knownFirst = list.where((t) => _knownBrandTokens.contains(t)).toList();
    final other = list.where((t) => !_knownBrandTokens.contains(t)).toList();
    final ordered = <String>[...knownFirst, ...other];
    if (ordered.length > 10) return ordered.sublist(0, 10);
    return ordered;
  }

  bool _textContainsToken(String text, String token) {
    if (text.isEmpty || token.isEmpty) return false;
    if (token.length <= 3) {
      final pattern = RegExp(r'(^|[^a-z0-9])' + RegExp.escape(token) + r'([^a-z0-9]|$)');
      return pattern.hasMatch(text);
    }
    return text.contains(token);
  }

  bool _serviceMatchesBrandTokens(Map<String, dynamic> data, Set<String> tokens) {
    if (tokens.isEmpty) return false;

    final tokensField = data['searchTokens'];
    if (tokensField is List) {
      for (final t in tokensField.whereType<String>()) {
        if (tokens.contains(t.toLowerCase())) return true;
      }
    }

    final buffer = StringBuffer();
    void addField(dynamic value) {
      if (value == null) return;
      if (value is String) {
        buffer.write(' ');
        buffer.write(value.toLowerCase());
      } else if (value is List) {
        for (final v in value.whereType<String>()) {
          buffer.write(' ');
          buffer.write(v.toLowerCase());
        }
      }
    }

    addField(data['serviceName']);
    addField(data['description']);
    addField(data['categoryName'] ?? data['category']);
    addField(data['subCategoryName']);
    addField(data['subCategoryNames']);
    addField(data['providerName']);
    addField(data['brand']);
    addField(data['brandName']);
    addField(data['supportedBrand']);
    addField(data['supportedBrands']);
    addField(data['brands']);

    final combined = buffer.toString();
    for (final token in tokens) {
      if (_textContainsToken(combined, token)) return true;
    }
    return false;
  }

  Future<List<QueryDocumentSnapshot>> _fetchServicesByBrandTokens(
    List<String> brandTokens, {
    String? mappedCategory,
  }) async {
    if (brandTokens.isEmpty) return const <QueryDocumentSnapshot>[];
    final tokens = brandTokens
        .map((t) => t.toLowerCase())
        .where((t) => t.trim().isNotEmpty)
        .toList();
    final queryTokens = tokens.length > 10 ? tokens.sublist(0, 10) : tokens;

    final Map<String, QueryDocumentSnapshot> unique = <String, QueryDocumentSnapshot>{};
    final Set<String> tokenSet = queryTokens.toSet();
    final collection = FirebaseFirestore.instance.collection('services');

    try {
      final snapshot = await collection
          .where('searchTokens', arrayContainsAny: queryTokens)
          .limit(30)
          .get();
      for (final doc in snapshot.docs) {
        unique[doc.id] = doc;
      }
    } catch (_) {
      // Ignore and rely on fallback scan.
    }

    void addMatches(QuerySnapshot snap) {
      for (final doc in snap.docs) {
        if (unique.containsKey(doc.id)) continue;
        if (_serviceMatchesBrandTokens(doc.data() as Map<String, dynamic>, tokenSet)) {
          unique[doc.id] = doc;
        }
      }
    }

    // Fallback for legacy services without searchTokens or without brand tokens.
    if (mappedCategory != null) {
      final snapA = await collection
          .where('category', isEqualTo: mappedCategory)
          .limit(80)
          .get();
      addMatches(snapA);

      final snapB = await collection
          .where('categoryName', isEqualTo: mappedCategory)
          .limit(80)
          .get();
      addMatches(snapB);
    }

    if (unique.length < 6) {
      final snapAll = await collection.limit(120).get();
      addMatches(snapAll);
    }

    return unique.values.toList();
  }

  List<QueryDocumentSnapshot> _filterBrandServicesByAppliance(
      List<QueryDocumentSnapshot> docs,
      String applianceLabel,
      String? mappedCategory,
  ) {
    if (docs.isEmpty) return docs;
    final targetTokens = buildSearchTokens(
      serviceName: applianceLabel,
      categoryName: mappedCategory,
      subCategoryNames: const [],
      description: null,
      maxTokens: 12,
    ).toSet();

    if (targetTokens.isEmpty) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final tokensField = data['searchTokens'];
      final Set<String> serviceTokens = <String>{};
      if (tokensField is List) {
        for (final t in tokensField.whereType<String>()) {
          serviceTokens.add(t.toLowerCase());
        }
      }

      if (serviceTokens.isNotEmpty) {
        for (final t in targetTokens) {
          if (serviceTokens.contains(t)) return true;
        }
        return false;
      }

      final name = (data['serviceName'] ?? '').toString().toLowerCase();
      final category = (data['categoryName'] ?? data['category'] ?? '').toString().toLowerCase();
      final subName = (data['subCategoryName'] ?? '').toString().toLowerCase();
      final subNames = data['subCategoryNames'];
      final buffer = StringBuffer()
        ..write(name)
        ..write(' ')
        ..write(category)
        ..write(' ')
        ..write(subName);
      if (subNames is List) {
        for (final s in subNames.whereType<String>()) {
          buffer.write(' ');
          buffer.write(s.toLowerCase());
        }
      }
      final combined = buffer.toString();
      for (final t in targetTokens) {
        if (combined.contains(t)) return true;
      }
      return false;
    }).toList();
  }

  String? _pickBestBrandToken(List<String> brandTokens, List<QueryDocumentSnapshot> docs) {
    if (brandTokens.isEmpty) return null;
    final tokenSet = brandTokens.map((t) => t.toLowerCase()).toSet();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final tokensField = data['searchTokens'];
      if (tokensField is List) {
        for (final t in tokensField.whereType<String>()) {
          final lower = t.toLowerCase();
          if (tokenSet.contains(lower)) return lower;
        }
      }
      final name = (data['serviceName'] ?? '').toString().toLowerCase();
      for (final t in brandTokens) {
        if (name.contains(t.toLowerCase())) return t.toLowerCase();
      }
    }
    return brandTokens.first.toLowerCase();
  }

  String _formatBrandLabel(String brand) {
    if (brand.isEmpty) return brand;
    if (brand.length <= 3) return brand.toUpperCase();
    return brand[0].toUpperCase() + brand.substring(1);
  }

  Future<List<QueryDocumentSnapshot>> _fetchProvidersByAppliance(
      String applianceType) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('providers')
        .where('services', arrayContains: applianceType)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs;
  }

  String? _mapApplianceToCategory(String applianceLabel) {
    final labelLower = applianceLabel.toLowerCase();
    if (labelLower.contains('laptop')) {
      return 'Laptop';
    }
    if (labelLower.contains('mobile') || labelLower.contains('phone')) {
      return 'Mobile Phone';
    }
    if (labelLower.contains('ac') || labelLower.contains('air conditioner')) {
      return 'AC';
    }
    if (labelLower.contains('fridge') || labelLower.contains('refrigerator')) {
      return 'Refrigerator';
    }
    if (labelLower.contains('washing')) {
      return 'Washing Machine';
    }
    return null;
  }

  Future<void> _suggestProvidersForAppliance(
      String applianceLabel, {
      List<String> brandTokens = const [],
  }) async {
    final String? mappedCategory = _mapApplianceToCategory(applianceLabel);
    final bool hasBrandSignals = brandTokens.any((t) => t.trim().isNotEmpty);

    try {
      List<QueryDocumentSnapshot> brandSelected = const [];
      String? brandLabel;
      if (brandTokens.isNotEmpty) {
        final brandServicesRaw = await _fetchServicesByBrandTokens(
          brandTokens,
          mappedCategory: mappedCategory,
        );
        if (brandServicesRaw.isNotEmpty) {
          final filtered = _filterBrandServicesByAppliance(
              brandServicesRaw, applianceLabel, mappedCategory);
          brandSelected = filtered.isNotEmpty ? filtered : brandServicesRaw;
          final brand = _pickBestBrandToken(brandTokens, brandSelected);
          brandLabel = brand == null ? null : _formatBrandLabel(brand);
        }
      }

      if (hasBrandSignals && brandSelected.isNotEmpty) {
        final display = brandSelected.take(10).toList();
        final buffer = StringBuffer();
        if (brandLabel != null && brandLabel.isNotEmpty) {
          buffer.writeln(
            'I detected "$brandLabel" from the photo. Showing only "$brandLabel $applianceLabel" services:',
          );
        } else {
          buffer.writeln(
            'I detected brand text in the photo. Showing only brand-matched "$applianceLabel" services:',
          );
        }

        for (final doc in display) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['serviceName'] as String?) ?? 'Service';
          final location = (data['addressDisplay'] as String?) ??
              (data['locationAddress'] as String?) ??
              '';
          buffer.write('- $name');
          if (location.isNotEmpty) buffer.write(' Â· $location');
          buffer.writeln();
        }

        buffer.writeln('Tap "Book" to continue with the matching brand servicer.');
        _addBotMessage(buffer.toString());
        if (mounted) {
          _showServiceBasedProvidersSheet(display, applianceLabel);
        }
        return;
      }

      if (hasBrandSignals && brandSelected.isEmpty) {
        _addBotMessage(
          'I detected brand text from your photo, but an exact brand-only service is not listed right now. Showing the closest available "$applianceLabel" services.',
        );
      }

      // First, try to fetch active providers that explicitly support this
      // appliance type from the `providers` collection. Prefer a
      // normalized/mapped category string when available so that it
      // matches how services/providers are stored.
      if (brandSelected.isEmpty) {
        final String lookupType = mappedCategory ?? applianceLabel;
        final providerDocs = await _fetchProvidersByAppliance(lookupType);

        if (providerDocs.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.writeln('Here are some providers who can help with your "$applianceLabel":');

          for (final doc in providerDocs.take(5)) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String?) ?? 'Provider';
            buffer.writeln('- $name');
          }

          buffer.writeln('You can explore their services from the services section too.');
          _addBotMessage(buffer.toString());
          if (mounted) {
            _showProvidersSheet(providerDocs.take(10).toList(), applianceLabel);
          }
          return;
        }
      }

      // Fallback to existing services-based discovery logic if no providers
      // were found for this appliance type.
      Query query = FirebaseFirestore.instance.collection('services');

      if (mappedCategory != null) {
        query = query.where('category', isEqualTo: mappedCategory);
      }

      final snapshot = await query.limit(20).get();

      List<QueryDocumentSnapshot> candidates = snapshot.docs;

      // If category-based search returned nothing or very few docs, do a
      // secondary scan over serviceName and subCategoryNames so that we
      // can still find relevant services like "Laptop Repair" even when
      // category is more generic (e.g. "Repairs", "Electronics").
      if (candidates.isEmpty) {
        final allServices = await FirebaseFirestore.instance
            .collection('services')
            .limit(40)
            .get();

        final labelLower = applianceLabel.toLowerCase();
        candidates = allServices.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['serviceName'] as String? ?? '').toLowerCase();
          if (name.contains(labelLower)) return true;
          final sub = data['subCategoryNames'];
          if (sub is List) {
            for (final s in sub.whereType<String>()) {
              if (s.toLowerCase().contains(labelLower)) return true;
            }
          }
          return false;
        }).toList();
      }

      if (candidates.isEmpty && brandSelected.isEmpty) {
        _addBotMessage(
          'I identified the appliance as "$applianceLabel" but could not find matching services right now. You can still browse all services from the dashboard.',
        );
        return;
      }

      final List<QueryDocumentSnapshot> combined = <QueryDocumentSnapshot>[];
      final Set<String> seen = <String>{};
      for (final doc in brandSelected) {
        if (seen.add(doc.id)) combined.add(doc);
      }
      for (final doc in candidates) {
        if (seen.add(doc.id)) combined.add(doc);
      }

      final display = combined.take(10).toList();

      final buffer = StringBuffer();
      if (brandSelected.isNotEmpty) {
        if (brandLabel != null && brandLabel.isNotEmpty) {
          buffer.writeln('I noticed brand text like "$brandLabel". Showing brand-matched services and other "$applianceLabel" options:');
        } else {
          buffer.writeln('Here are services matching the brand text I found, plus other "$applianceLabel" options:');
        }
      } else {
        buffer.writeln('Here are some services that can help with your "$applianceLabel":');
      }

      for (final doc in display) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['serviceName'] as String?) ?? 'Service';
        final location = (data['addressDisplay'] as String?) ?? (data['locationAddress'] as String?) ?? '';
        buffer.write('- $name');
        if (location.isNotEmpty) buffer.write(' · $location');
        buffer.writeln();
      }

      buffer.writeln('You can tap below to view full details and book a visit.');

      _addBotMessage(buffer.toString());
      if (mounted) {
        _showServiceBasedProvidersSheet(display, applianceLabel);
      }
    } catch (e) {
      _addBotMessage(
        'I found "$applianceLabel" from the image, but had trouble fetching matching services. Please try again later or use the search and browse options.',
      );
    }
  }

  void _showProvidersSheet(List<QueryDocumentSnapshot> providerDocs, String applianceLabel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.handyman_rounded, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Providers for $applianceLabel',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: providerDocs.length,
                  itemBuilder: (context, index) {
                    final doc = providerDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] as String?) ?? 'Provider';
                    final servicesField = data['services'];
                    List<String> servicesList;
                    if (servicesField is List) {
                      servicesList = servicesField.whereType<String>().toList();
                    } else {
                      servicesList = [];
                    }
                    final expertise = servicesList.isNotEmpty
                        ? 'Expert in ${servicesList.join(', ')}'
                        : 'Appliance repair expert';

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        expertise,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 0),
                        ),
                        child: const Text('Book'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ServeSphere Assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildQuickActionsStrip();
                }
                final msg = _messages[index];
                return Align(
                  alignment:
                      msg.fromBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: msg.fromBot
                          ? Colors.white
                          : Colors.deepPurple.shade400,
                      borderRadius: BorderRadius.circular(16).subtract(
                        BorderRadius.only(
                          bottomLeft:
                              msg.fromBot ? const Radius.circular(0) : const Radius.circular(16),
                          bottomRight:
                              msg.fromBot ? const Radius.circular(16) : const Radius.circular(0),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.imagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(msg.imagePath!),
                              width: MediaQuery.of(context).size.width * 0.6,
                              fit: BoxFit.cover,
                            ),
                          ),
                        if (msg.imagePath != null && msg.text.isNotEmpty)
                          const SizedBox(height: 8),
                        if (msg.text.isNotEmpty)
                          Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.fromBot ? Colors.black87 : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Row(
                children: const [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Assistant is thinking...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickActionsStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 4),
            _buildQuickChip(
              label: 'Browse services',
              icon: Icons.apps_rounded,
              action: 'browse_services',
            ),
            _buildQuickChip(
              label: 'Search services',
              icon: Icons.search_rounded,
              action: 'search_services',
            ),
            _buildQuickChip(
              label: 'My requests',
              icon: Icons.list_alt_rounded,
              action: 'my_requests',
            ),
            _buildQuickChip(
              label: 'Self-fix tips',
              icon: Icons.settings_suggest_rounded,
              action: 'self_fix',
            ),
            _buildQuickChip(
              label: 'Identify Appliance by Camera',
              icon: Icons.photo_camera_rounded,
              action: 'scan_appliance',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip({required String label, required IconData icon, required String action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: Colors.deepPurple),
        label: Text(label),
        onPressed: () => _handleQuickActionTap(action),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.deepPurple.shade100),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: const InputDecoration(
                  hintText: 'Describe your issue or ask a question...',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.photo_camera_rounded, color: Colors.deepPurple),
              onPressed: _isProcessing ? null : _handleApplianceScanAction,
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.deepPurple),
              onPressed: _handleSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromBot;
  final String? imagePath;

  _ChatMessage({required this.text, required this.fromBot, this.imagePath});
}


