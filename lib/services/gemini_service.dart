import 'dart:convert';
import 'package:http/http.dart' as http;

/// Provided at build/run time via `--dart-define=GEMINI_API_KEY=...` so it
/// never lands in source control. Client-side calls still ship the key in
/// the compiled bundle — fine for a demo, but a production app should
/// proxy this through a backend instead.
const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

bool get geminiConfigured => _apiKey.isNotEmpty;

const _endpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent';

/// Asks Gemini to break a task into 3-5 concrete subtasks. Throws on any
/// failure (network, parsing, empty key) — callers fall back to the
/// static simulated list when this isn't configured or fails.
Future<List<String>> suggestSubtasks({
  required String title,
  required String description,
}) async {
  if (_apiKey.isEmpty) {
    throw StateError('Gemini API key not configured');
  }

  final prompt =
      'Break this task into 3 to 5 short, concrete, actionable subtasks. '
      'Reply with ONLY the subtasks, one per line, no numbering, no markdown, '
      'no extra commentary.\n\n'
      'Task: $title\n'
      'Description: $description';

  final response = await http.post(
    Uri.parse('$_endpoint?key=$_apiKey'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    }),
  );

  if (response.statusCode != 200) {
    throw StateError('Gemini request failed: ${response.statusCode} ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final candidates = data['candidates'] as List<dynamic>?;
  if (candidates == null || candidates.isEmpty) {
    throw StateError('Gemini returned no candidates');
  }
  final text = candidates[0]['content']['parts'][0]['text'] as String;

  final lines = text
      .split('\n')
      .map((l) => l.trim().replaceFirst(RegExp(r'^[-*\d.\s]+'), ''))
      .where((l) => l.isNotEmpty)
      .toList();

  if (lines.isEmpty) {
    throw StateError('Gemini returned no usable subtasks');
  }
  return lines;
}
