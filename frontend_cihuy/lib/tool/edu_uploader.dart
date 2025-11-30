// lib/services/edu_uploader.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class EduUploaderResult {
  final String originalUrl;
  final bool success;
  final String? message;
  final Map<String, dynamic>? insertedRow;

  EduUploaderResult({
    required this.originalUrl,
    required this.success,
    this.message,
    this.insertedRow,
  });
}

class EduUploader {
  final SupabaseClient _supabase;

  EduUploader([SupabaseClient? client]) : _supabase = client ?? Supabase.instance.client;

  /// Try to extract YouTube id and return embed URL if recognized.
  /// Otherwise returns null.
  String? toEmbedYouTubeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // handle youtu.be short links
      if (host.contains('youtu.be')) {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
        if (id != null && id.isNotEmpty) {
          return 'https://www.youtube.com/embed/$id?rel=0';
        }
      }

      // handle youtube.com
      if (host.contains('youtube.com')) {
        // watch?v=ID
        final vid = uri.queryParameters['v'];
        if (vid != null && vid.isNotEmpty) return 'https://www.youtube.com/embed/$vid?rel=0';

        // /shorts/ID
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'shorts') {
          final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
          if (id != null && id.isNotEmpty) return 'https://www.youtube.com/embed/$id?rel=0';
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Normalize a video URL for storage (ke embed if YouTube, otherwise raw)
  String normalizeVideoUrl(String url) {
    final maybeEmbed = toEmbedYouTubeUrl(url);
    return maybeEmbed ?? url;
  }

  /// Minimal auto-generated title from URL (can be improved by scraping)
  String genTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceAll('www.', '');
      return 'Video edukasi — $host';
    } catch (_) {
      return 'Video edukasi';
    }
  }

  /// Insert a single education item to Supabase.
  /// fields: title, summary, content_markdown, video_url, updated_at
  Future<EduUploaderResult> createEducationRecord({
    required String originalUrl,
    String? title,
    String? summary,
    String? contentMarkdown,
    Map<String, dynamic>? extra, // any extra columns to include
  }) async {
    try {
      final videoUrl = normalizeVideoUrl(originalUrl);
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final payload = <String, dynamic>{
        'title': title ?? genTitleFromUrl(originalUrl),
        'summary': summary ?? '',
        'content_markdown': contentMarkdown ?? '',
        'video_url': videoUrl,
        'updated_at': nowIso,
      };

      if (extra != null && extra.isNotEmpty) {
        payload.addAll(extra);
      }

      final res = await _supabase.from('educations').insert(payload).select().maybeSingle();

      // supabase returns null or inserted row
      if (res == null) {
        // If insert didn't return row, assume success but we can't show inserted data
        return EduUploaderResult(
          originalUrl: originalUrl,
          success: true,
          message: 'Inserted (no row returned).',
          insertedRow: null,
        );
      }

      return EduUploaderResult(
        originalUrl: originalUrl,
        success: true,
        message: 'Inserted',
        insertedRow: Map<String, dynamic>.from(res as Map),
      );
    } catch (e, st) {
      return EduUploaderResult(
        originalUrl: originalUrl,
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Bulk upload list of URLs. Runs in sequence (so you can see errors per item).
  /// Returns list of EduUploaderResult preserving order.
  Future<List<EduUploaderResult>> bulkUploadUrls(
    List<String> urls, {
    String Function(String url)? titleFor, // optional generator for title
    String Function(String url)? summaryFor,
    String Function(String url)? contentFor,
    Map<String, dynamic> Function(String url)? extraFor,
    Duration delayBetween = Duration.zero, // rate limiting if you want
  }) async {
    final results = <EduUploaderResult>[];

    for (final u in urls) {
      final trimmed = u.trim();
      if (trimmed.isEmpty) {
        results.add(EduUploaderResult(originalUrl: u, success: false, message: 'Empty URL'));
        continue;
      }

      final title = titleFor?.call(trimmed) ?? genTitleFromUrl(trimmed);
      final summary = summaryFor?.call(trimmed) ?? '';
      final content = contentFor?.call(trimmed) ?? '';
      final extra = extraFor?.call(trimmed);

      final r = await createEducationRecord(
        originalUrl: trimmed,
        title: title,
        summary: summary,
        contentMarkdown: content,
        extra: extra,
      );

      results.add(r);

      if (delayBetween > Duration.zero) {
        await Future.delayed(delayBetween);
      }
    }

    return results;
  }
}