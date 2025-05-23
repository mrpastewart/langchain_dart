// ignore_for_file: unsafe_variance

import 'dart:async';

import 'runnable.dart';
import 'types.dart';

/// {@template runnable_map_input}
/// A [RunnableMapInput] allows you to map the input to a different value.
///
/// You can create a [RunnableMapInput] using the [Runnable.mapInput] static
/// method.
///
/// When you call [invoke] on a [RunnableMapInput], it will take the
/// input it receives and returns the output returned by the given
/// [inputMapper] function.
///
/// Example:
///
/// ```dart
/// final agent = Agent.fromRunnable(
///   Runnable.mapInput(
///     (final AgentPlanInput planInput) => <String, dynamic>{
///       'input': planInput.inputs['input'],
///       'agent_scratchpad': buildScratchpad(planInput.intermediateSteps),
///     },
///   ).pipe(prompt).pipe(model).pipe(outputParser),
///   tools: [tool],
/// );
/// ```
/// {@endtemplate}
class RunnableMapInput<RunInput extends Object, RunOutput extends Object>
    extends Runnable<RunInput, RunnableOptions, RunOutput> {
  /// {@macro runnable_map_input}
  const RunnableMapInput(this.inputMapper)
      : super(defaultOptions: const RunnableOptions());

  /// A function that maps [RunInput] to [RunOutput].
  final FutureOr<RunOutput> Function(RunInput input) inputMapper;

  /// Invokes the [RunnableMapInput] on the given [input].
  ///
  /// - [input] - the input to invoke the [RunnableMapInput] on.
  /// - [options] - not used.
  @override
  Future<RunOutput> invoke(
    final RunInput input, {
    final RunnableOptions? options,
  }) async {
    return inputMapper(input);
  }
}
