@TestOn('vm')
library; // Uses dart:io

import 'dart:convert';
import 'dart:io';

import 'package:googleai_dart/googleai_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Google AI stream generate content API tests', () {
    late GoogleAIClient client;

    setUp(() {
      client = GoogleAIClient(
        apiKey: Platform.environment['GOOGLEAI_API_KEY'],
      );
    });

    tearDown(() {
      client.endSession();
    });

    test('Test Text-only input with gemini-pro', () async {
      final stream = client.streamGenerateContent(
        modelId: 'gemini-pro',
        request: const GenerateContentRequest(
          contents: [
            Content(
              parts: [
                Part(
                  text: 'List the numbers from 1 to 100 in order '
                      'without any spaces, commas or additional explanations.',
                ),
              ],
            ),
          ],
          generationConfig: GenerationConfig(
            temperature: 0,
          ),
        ),
      );

      var text = '';
      await for (final res in stream) {
        expect(res.promptFeedback?.blockReason, isNull);
        expect(res.candidates, isNotEmpty);
        final candidate = res.candidates!.first;
        expect(candidate.index, 0);
        expect(candidate.finishReason, CandidateFinishReason.stop);
        expect(candidate.content, isNotNull);
        final content = candidate.content!;
        expect(content.role, 'model');
        expect(content.parts, hasLength(1));
        text += content.parts!.first.text ?? '';
      }

      expect(
        text.replaceAll(RegExp(r'[\s\n]'), ''),
        contains('123456789'),
      );
    });

    test('Text-and-image input with gemini-pro-vision', () async {
      final stream = client.streamGenerateContent(
        modelId: 'gemini-pro-vision',
        request: GenerateContentRequest(
          contents: [
            Content(
              parts: [
                const Part(
                  text: 'What is this picture? Be detailed. '
                      'List all the elements that you see.',
                ),
                Part(
                  inlineData: Blob(
                    mimeType: 'image/png',
                    data: base64.encode(
                      await File('./test/assets/1.png').readAsBytes(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      var text = '';
      await for (final res in stream) {
        expect(res.promptFeedback?.blockReason, isNull);
        expect(res.candidates, isNotEmpty);
        final candidate = res.candidates!.first;
        expect(candidate.index, 0);
        expect(candidate.finishReason, CandidateFinishReason.stop);
        expect(candidate.content, isNotNull);
        final content = candidate.content!;
        expect(content.role, 'model');
        expect(content.parts, hasLength(1));
        final part = content.parts!.first;
        text += ' ${part.text!}';
      }

      expect(
        text,
        anyOf(
          contains('coffee'),
          contains('blueberries'),
          contains('cookies'),
        ),
      );
    });

    test('Test stop sequence', () async {
      final stream = client.streamGenerateContent(
        modelId: 'gemini-pro',
        request: const GenerateContentRequest(
          contents: [
            Content(
              parts: [
                Part(
                  text: 'List the numbers from 1 to 9 in order '
                      'without any spaces, commas or additional explanations.',
                ),
              ],
            ),
          ],
          generationConfig: GenerationConfig(
            stopSequences: ['4'],
          ),
        ),
      );

      var text = '';
      await for (final res in stream) {
        expect(res.candidates, isNotEmpty);
        final candidate = res.candidates!.first;
        expect(candidate.content, isNotNull);
        final content = candidate.content!;
        text +=
            content.parts!.first.text?.replaceAll(RegExp(r'[\s\n]'), '') ?? '';
      }

      expect(text, contains('123'));
      expect(text, isNot(contains('456789')));
    });

    test('Test max tokens', () async {
      final res = client.streamGenerateContent(
        modelId: 'gemini-pro',
        request: const GenerateContentRequest(
          contents: [
            Content(
              parts: [
                Part(text: 'Tell me a joke'),
              ],
            ),
          ],
          generationConfig: GenerationConfig(
            maxOutputTokens: 2,
          ),
        ),
      );

      await for (final res in res) {
        expect(res.candidates, isNotEmpty);
        final candidate = res.candidates!.first;
        expect(candidate.finishReason, CandidateFinishReason.maxTokens);
      }
    });

    test('Test Multi-turn conversations with gemini-pro', () async {
      final stream = client.streamGenerateContent(
        modelId: 'gemini-pro',
        request: const GenerateContentRequest(
          contents: [
            Content(
              role: 'user',
              parts: [
                Part(
                  text: 'List the numbers from 1 to 9 in order '
                      'without any spaces, commas or additional explanations.',
                ),
              ],
            ),
            Content(
              role: 'model',
              parts: [
                Part(
                  text: '123456789',
                ),
              ],
            ),
            Content(
              role: 'user',
              parts: [
                Part(
                  text: 'Remove the number 4 from the list',
                ),
              ],
            ),
          ],
        ),
      );

      var text = '';

      await for (final res in stream) {
        expect(res.promptFeedback?.blockReason, isNull);
        expect(res.candidates, isNotEmpty);
        final candidate = res.candidates!.first;
        expect(candidate.index, 0);
        expect(candidate.finishReason, CandidateFinishReason.stop);
        expect(candidate.content, isNotNull);
        final content = candidate.content!;
        expect(content.role, 'model');
        expect(content.parts, hasLength(1));
        final part = content.parts!.first;
        text += ' ${part.text!}';
      }

      expect(
        text,
        contains('12356789'),
      );
    });
  });
}
