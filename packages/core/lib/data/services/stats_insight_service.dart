import 'package:breakbite_core/utils/result.dart';

/// The Gemini feature of the web admin's statistics page (docs/ai-feature.md, section "Stats summary"): writes a few
/// sentences about the figures of a period.
///
/// Only [digest] (see `statsDigest`) and the prompt are sent. Failures come back as an `AiException`, never as a
/// crash, so the page and its charts stay usable.
abstract interface class StatsInsightService {
  /// [model] and [prompt] come from Remote Config (`ai_model`, `ai_insight_prompt`).
  Future<Result<String>> summarize(String digest, {required String model, required String prompt});
}
