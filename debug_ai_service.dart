import 'dart:convert';
import 'dart:io';

/// Debug script to test AI service endpoints
/// Run with: dart debug_ai_service.dart
void main() async {
  print('🔍 AI Service Diagnostic Tool');
  print('============================\n');

  // Test the chat endpoint
  await testChatEndpoint();
  
  // Test health endpoint
  await testHealthEndpoint();
}

Future<void> testChatEndpoint() async {
  print('📡 Testing Chat Endpoint...');
  
  try {
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('https://doctorjebasingh.in/ai/chat')
    );
    
    // Set headers
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer YOUR_TOKEN_HERE'); // Replace with actual token
    
    // Test payload
    final payload = {
      'message': 'test message',
      'use_mistral_only': false,
    };
    
    request.write(jsonEncode(payload));
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('Status Code: ${response.statusCode}');
    print('Response Headers: ${response.headers}');
    print('Response Body: $responseBody');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      if (data is Map && data.containsKey('messages')) {
        final messages = data['messages'] as List;
        if (messages.isNotEmpty) {
          final lastMessage = messages.last;
          if (lastMessage is Map && lastMessage['role'] == 'assistant') {
            final content = lastMessage['content'];
            if (content is Map) {
              final mediAi = content['medi_ai']?.toString() ?? '';
              final commonAi = content['common_ai']?.toString() ?? '';
              
              print('\n🤖 AI Service Status:');
              print('MediAI: ${mediAi.contains('No reply from Mistral') ? '❌ FAILED' : '✅ WORKING'}');
              print('Common AI: ${commonAi.contains('No reply from Mistral') ? '❌ FAILED' : '✅ WORKING'}');
              
              // Show content preview
              if (mediAi.isNotEmpty && !mediAi.contains('No reply from Mistral')) {
                print('\n📋 MediAI Content Preview:');
                print(mediAi.length > 200 ? '${mediAi.substring(0, 200)}...' : mediAi);
              }
              
              if (commonAi.isNotEmpty && !commonAi.contains('No reply from Mistral')) {
                print('\n📋 Common AI Content Preview:');
                print(commonAi.length > 200 ? '${commonAi.substring(0, 200)}...' : commonAi);
              }
              
              if (mediAi.contains('No reply from Mistral')) {
                print('\n⚠️  MediAI Issue: Mistral service is not responding');
              }
              if (commonAi.contains('No reply from Mistral')) {
                print('⚠️  Common AI Issue: Mistral service is not responding');
              }
              
              // Overall status
              if (mediAi.contains('No reply from Mistral') && commonAi.contains('No reply from Mistral')) {
                print('\n🚨 CRITICAL: Both AI services are failing - Mistral API is completely down');
              } else if (mediAi.contains('No reply from Mistral') || commonAi.contains('No reply from Mistral')) {
                print('\n⚠️  PARTIAL: One AI service is working, one is failing - Mistral API has issues');
              } else {
                print('\n✅ SUCCESS: Both AI services are working normally');
              }
            }
          }
        }
      }
    } else {
      print('❌ Request failed with status: ${response.statusCode}');
    }
    
    client.close();
  } catch (e) {
    print('❌ Error testing chat endpoint: $e');
  }
  
  print('\n');
}

Future<void> testHealthEndpoint() async {
  print('🏥 Testing Health Endpoint...');
  
  try {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('https://doctorjebasingh.in/api/health')
    );
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('Status Code: ${response.statusCode}');
    print('Response: $responseBody');
    
    if (response.statusCode == 200) {
      print('✅ Health endpoint is working');
    } else if (response.statusCode == 404) {
      print('⚠️  Health endpoint not found (404) - server is reachable but endpoint missing');
    } else {
      print('❌ Health endpoint failed with status: ${response.statusCode}');
    }
    
    client.close();
  } catch (e) {
    print('❌ Error testing health endpoint: $e');
  }
  
  print('\n');
}
