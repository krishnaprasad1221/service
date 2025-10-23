// lib/service_preview_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';

class ServicePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const ServicePreviewScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final String serviceName = (data['serviceName'] as String?)?.trim().isEmpty == true
        ? 'Service'
        : (data['serviceName'] as String?) ?? 'Service';
    final String? categoryName = data['categoryName'] as String?;
    final List<dynamic> subCategoryNames = (data['subCategoryNames'] as List?) ?? const [];
    final String description = (data['description'] as String?) ?? '';
    final String details = (data['detailedDescription'] as String?) ?? '';
    final String terms = (data['terms'] as String?) ?? '';
    final String contactPhone = (data['contactPhone'] as String?) ?? '';
    final String contactEmail = (data['contactEmail'] as String?) ?? '';
    final String websiteUrl = (data['websiteUrl'] as String?) ?? '';
    final int? durationMinutes = data['durationMinutes'] as int?;
    final List<dynamic> highlights = (data['highlights'] as List?) ?? const [];
    final String? addressDisplay = data['addressDisplay'] as String?;
    final String? imageFilePath = data['imageFilePath'] as String?;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Preview As Customer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.deepPurple,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                serviceName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageFilePath != null && imageFilePath.isNotEmpty && File(imageFilePath).existsSync())
                    Image.file(
                      File(imageFilePath),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 60, color: Colors.white54),
                    )
                  else
                    const Center(child: Icon(Icons.work, size: 60, color: Colors.white54)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),
              _section('Category', _buildCategory(categoryName, subCategoryNames)),
              _section('Description', _buildTextBlock(description)),
              if (details.isNotEmpty) _section('Details', _buildTextBlock(details)),
              if (highlights.isNotEmpty) _section('Highlights', _buildChips(highlights)),
              if (durationMinutes != null) _section('Duration', Text('$durationMinutes minutes')),
              if (addressDisplay != null && addressDisplay.isNotEmpty)
                _section('Location', _buildLocation(addressDisplay)),
              if (contactPhone.isNotEmpty) _section('Contact', Text(contactPhone)),
              if (contactEmail.isNotEmpty) _section('Email', Text(contactEmail)),
              if (websiteUrl.isNotEmpty) _section('Website', Text(websiteUrl)),
              if (terms.isNotEmpty) _section('Terms & Conditions', _buildTextBlock(terms)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Looks Good'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildCategory(String? categoryName, List subCategoryNames) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(categoryName ?? 'Uncategorized', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (subCategoryNames.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: subCategoryNames
                .map((e) => Chip(
                      label: Text(e.toString()),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          )
        else
          const Text('No sub-categories selected', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildTextBlock(String text) {
    return Text(
      text.isEmpty ? '—' : text,
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }

  Widget _buildChips(List<dynamic> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items
          .map((e) => Chip(
                label: Text(e.toString()),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ))
          .toList(),
    );
  }

  Widget _buildLocation(String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.place, size: 18, color: Colors.deepPurple),
        const SizedBox(width: 6),
        Expanded(child: Text(address)),
      ],
    );
  }
}
