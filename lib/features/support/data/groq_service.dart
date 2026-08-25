import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class GroqService {
  String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  final String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // Switched to your selected safeguard model
  final String _model = 'openai/gpt-oss-safeguard-20b';

  List<Map<String, String>> _messages = [];
  String _orderContext = '';

  GroqService() {
    _resetMessages();
  }

  void _resetMessages() {
    _messages = [
      {
        'role': 'system',
        'content': 'You are "Ziko Support", the friendly voice of the Ziko delivery app. '
            'Your goal is to satisfy customers by being empathetic and helpful. '
            '\n\nSTRATEGY:'
            '\n1. Don\'t dump all information at once. Ask follow-up questions to understand the specific issue.'
            '\n2. If a user is complaining about an order, first ask for their Order ID or specific problem.'
            '\n3. Keep responses short and conversational. One small help at a time.'
            '\n4. NEVER provide the Support Number (+917551875341) at the beginning. First, try to solve the issue yourself by asking for details. ONLY provide it if you have tried at least 2-3 times and the user is still unsatisfied or the issue requires manual intervention.'
            '\n5. Use a warm, professional, yet friendly tone.'
            '\n6. IMPORTANT: Always respond in the SAME LANGUAGE as the user. If the user speaks in Bengali (Bangla), you MUST reply in Bengali. If they speak in English, reply in English.',
      }
    ];
  }

  void setOrderContext(String context) {
    _orderContext = context;
  }

  Future<String?> sendMessage(String message) async {
    try {
      final key = _apiKey;
      if (key.isEmpty) {
        debugPrint('Groq Error: API key is empty. Check if .env is loaded and GROQ_API_KEY is set.');
        return 'Error: Groq API key is not configured. Please restart the app.';
      }

      // Add dynamic context as a system message if available
      List<Map<String, String>> currentMessages = List.from(_messages);
      if (_orderContext.isNotEmpty) {
        currentMessages.add({
          'role': 'system',
          'content': 'CURRENT ORDER CONTEXT: $_orderContext'
        });
      }

      _messages.add({'role': 'user', 'content': message});
      currentMessages.add({'role': 'user', 'content': message});

      debugPrint('Groq: Sending request to $_baseUrl');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': currentMessages,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      debugPrint('Groq Response Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantMessage = data['choices'][0]['message']['content'] as String;
        _messages.add({'role': 'assistant', 'content': assistantMessage});
        return assistantMessage;
      } else {
        debugPrint('Groq API Error: ${response.statusCode} - ${response.body}');
        return 'Groq API Error: ${response.statusCode}. Please check your API key and quota.';
      }
    } catch (e) {
      debugPrint('Groq Exception: $e');
      return 'Connection Error: $e';
    }
  }

  void resetChat() {
    _resetMessages();
    _orderContext = '';
  }
}
