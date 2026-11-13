import 'dart:async';

import 'package:breakbite_core/data/services/stats_insight_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Calls Gemini through Firebase AI Logic (Gemini Developer API), like the K14 feature of the mobile app: the API key
/// stays in Firebase and every request carries the App Check token the web admin activates at start-up.
///
/// The answer is free text (a few bullet points), not structured output: the page shows it as written.
class FirebaseStatsInsightService implements StatsInsightService {
  FirebaseStatsInsightService({FirebaseAI Function()? ai, this.timeout = const Duration(seconds: 30)})
    : _ai = ai ?? FirebaseAI.googleAI;

  final FirebaseAI Function() _ai;
  final Duration timeout;

  @override
  Future<Result<String>> summarize(String digest, {required String model, required String prompt}) async {
    try {
      final gemini = _ai().generativeModel(
        model: model,
        systemInstruction: Content.system(prompt),
        generationConfig: GenerationConfig(temperature: 0.3, maxOutputTokens: 600),
      );
      final response = await gemini.generateContent([Content.text(digest)]).timeout(timeout);
      if (kDebugMode) debugPrint('Gemini stats answer ($model): ${response.text}');
      final text = response.text?.trim();
      if (text == null || text.isEmpty) return Result.error(AiException.insight(AiFailure.badOutput));
      return Result.ok(text);
    } on QuotaExceeded catch (error, stack) {
      return Result.error(AiException.insight(AiFailure.quota, cause: error, stackTrace: stack));
    } on TimeoutException catch (error, stack) {
      return Result.error(AiException.insight(AiFailure.network, cause: error, stackTrace: stack));
    } on FirebaseAIException catch (error, stack) {
      return Result.error(AiException.insight(AiFailure.other, cause: error, stackTrace: stack));
    } catch (error, stack) {
      return Result.error(AiException.insight(AiFailure.other, cause: error, stackTrace: stack));
    }
  }
}
