import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:spotnsend/core/config/app_config.dart';
import 'package:spotnsend/data/models/report_models.dart';

final translationServiceProvider = Provider<TranslationService>((ref) {
  final service = TranslationService(apiKey: AppConfig.geminiApiKey);
  ref.onDispose(service.dispose);
  return service;
});

class TranslationService {
  TranslationService({required String? apiKey})
      : _apiKey = apiKey,
        _client = http.Client();

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  final String? _apiKey;
  final http.Client _client;
  final Map<String, String> _cache = <String, String>{};

  bool get isEnabled {
    final key = _apiKey;
    return key != null && key.isNotEmpty;
  }

  Future<Map<String, String>> translateLabels(
    Iterable<String> labels, {
    String targetLanguageCode = 'ar',
  }) async {
    if (!isEnabled) return const <String, String>{};

    final sanitized = labels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toSet();

    if (sanitized.isEmpty) return const <String, String>{};

    final pending = <String>[];
    final results = <String, String>{};

    for (final label in sanitized) {
      final cached = _cache[label];
      if (cached != null) {
        results[label] = cached;
      } else {
        pending.add(label);
      }
    }

    if (pending.isEmpty) {
      return results;
    }

    final apiKey = _apiKey!;
    final prompt =
        'Translate the following UI labels from English to $targetLanguageCode. '
        'Respond with a JSON object where each key is the original English label and each value is the translation. '
        'Do not include backticks, commentary, or any text outside the JSON object. '
        'If a label is already in the target language, repeat it unchanged. Labels: ${jsonEncode(pending)}';

    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'topP': 0.9,
        'topK': 40,
      },
    });

    try {
      final response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('Translation failed: ${response.statusCode} ${response.body}');
        }
        return results;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final firstCandidate = candidates?.isNotEmpty == true ? candidates!.first : null;
      final content = firstCandidate is Map<String, dynamic> ? firstCandidate['content'] : null;
      final parts = content is Map<String, dynamic> ? content['parts'] as List<dynamic>? : null;
      final textPart = parts?.firstWhere(
        (part) => part is Map<String, dynamic> && part['text'] != null,
        orElse: () => null,
      );

      if (textPart is Map<String, dynamic>) {
        final text = textPart['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          try {
            final jsonResult = jsonDecode(text) as Map<String, dynamic>;
            jsonResult.forEach((key, value) {
              if (value == null) return;
              final original = key.toString();
              final translated = value.toString();
              _cache[original] = translated;
              results[original] = translated;
            });
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Failed to parse translation response: $e');
            }
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Translation request error: $e');
        debugPrintStack(stackTrace: st);
      }
    }

    return results;
  }

  Future<List<ReportCategory>> translateCategories(
    List<ReportCategory> categories,
  ) async {
    if (!isEnabled) return categories;

    final labels = <String>{};
    for (final category in categories) {
      labels.add(category.name);
      for (final sub in category.subcategories) {
        labels.add(sub.name);
      }
    }

    final translations = await translateLabels(labels);
    if (translations.isEmpty) return categories;

    return categories
        .map(
          (category) => category.copyWith(
            name: translations[category.name] ?? category.name,
            subcategories: category.subcategories
                .map(
                  (sub) => sub.copyWith(
                    name: translations[sub.name] ?? sub.name,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Future<List<Report>> translateReports(Iterable<Report> reports) async {
    if (!isEnabled) return reports.toList(growable: false);

    final labels = <String>{};
    for (final report in reports) {
      labels.add(report.categoryName);
      final sub = report.subcategoryName;
      if (sub != null && sub.trim().isNotEmpty) {
        labels.add(sub);
      }
    }

    final translations = await translateLabels(labels);
    if (translations.isEmpty) return reports.toList(growable: false);

    return reports
        .map(
          (report) => report.copyWith(
            categoryName: translations[report.categoryName] ?? report.categoryName,
            subcategoryName: report.subcategoryName == null
                ? null
                : translations[report.subcategoryName!] ?? report.subcategoryName,
          ),
        )
        .toList(growable: false);
  }

  Future<Report> translateReport(Report report) async {
    final localized = await translateReports([report]);
    return localized.isEmpty ? report : localized.first;
  }

  void dispose() {
    _client.close();
  }
}
