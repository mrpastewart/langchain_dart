@TestOn('vm')
library; // Uses dart:io

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:langchain/langchain.dart'
    show
        MemoryVectorStore,
        RecursiveCharacterTextSplitter,
        RetrievalQAChain,
        StuffDocumentsChain;
import 'package:langchain_community/langchain_community.dart';
import 'package:langchain_core/chat_models.dart';
import 'package:langchain_core/documents.dart';
import 'package:langchain_core/output_parsers.dart';
import 'package:langchain_core/prompts.dart';
import 'package:langchain_core/runnables.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:test/test.dart';

void main() {
  group('OpenAIQAWithSourcesChain tests', () {
    final openaiApiKey = Platform.environment['OPENAI_API_KEY'];

    test('Test OpenAIQAWithSourcesChain', () async {
      const filePath = './test/chains/assets/state_of_the_union.txt';
      const loader = TextLoader(filePath);
      final documents = await loader.load();

      const textSplitter = RecursiveCharacterTextSplitter(
        chunkSize: 800,
        chunkOverlap: 0,
      );
      final texts = textSplitter.splitDocuments(documents);
      final textsWithSources = texts
          .mapIndexed(
            (final i, final d) => d.copyWith(
              metadata: {
                ...d.metadata,
                'source': '$i-pl',
              },
            ),
          )
          .toList(growable: false);

      final embeddings = OpenAIEmbeddings(apiKey: openaiApiKey);
      final docSearch = await MemoryVectorStore.fromDocuments(
        documents: textsWithSources,
        embeddings: embeddings,
      );

      final llm = ChatOpenAI(
        apiKey: openaiApiKey,
        defaultOptions: const ChatOpenAIOptions(
          temperature: 0,
        ),
      );

      final qaChain = OpenAIQAWithSourcesChain(llm: llm);

      final docPrompt = PromptTemplate.fromTemplate(
        'Content: {page_content}\nSource: {source}',
      );
      final finalQAChain = StuffDocumentsChain(
        llmChain: qaChain,
        documentPrompt: docPrompt,
      );

      final retrievalQA = RetrievalQAChain(
        retriever: docSearch.asRetriever(),
        combineDocumentsChain: finalQAChain,
      );

      const query = 'What did President Biden say about Russia?';
      final res = await retrievalQA(query);

      expect(res[RetrievalQAChain.defaultInputKey], query);
      expect(
        res[RetrievalQAChain.sourceDocumentsOutputKey],
        isA<List<Document>>(),
      );

      final output = res[RetrievalQAChain.defaultOutputKey];
      expect(output, isA<QAWithSources>());
      final qaWithSources = output as QAWithSources;

      final answer = qaWithSources.answer;
      expect(answer, isNotEmpty);

      final sources = qaWithSources.sources;
      expect(sources, isNotEmpty);
      expect(sources.first, endsWith('-pl'));
    });

    test('Test custom RetrievalQA streaming pipeline', () async {
      const filePath = './test/chains/assets/state_of_the_union.txt';
      const loader = TextLoader(filePath);
      final documents = await loader.load();

      const textSplitter = RecursiveCharacterTextSplitter(
        chunkSize: 800,
        chunkOverlap: 0,
      );
      final texts = textSplitter.splitDocuments(documents);

      final embeddings = OpenAIEmbeddings(apiKey: openaiApiKey);
      final vectorStore = await MemoryVectorStore.fromDocuments(
        documents: texts,
        embeddings: embeddings,
      );
      final retriever = vectorStore.asRetriever();
      final docCombiner = Runnable.mapInput<List<Document>, String>(
        (docs) => docs.map((final d) => d.pageContent).join('\n'),
      );

      final promptTemplate = PromptTemplate.fromTemplate('''
Answer the question based only on the following context:
```
{context}
```
Question: {question}
      ''');

      final chatModel = ChatOpenAI(
        apiKey: openaiApiKey,
        defaultOptions: const ChatOpenAIOptions(
          temperature: 0,
        ),
      );
      const outputParser = StringOutputParser<ChatResult>();

      final chain = Runnable.fromMap<String>({
        'context': retriever.pipe(docCombiner),
        'question': Runnable.passthrough(),
      }).pipe(promptTemplate).pipe(chatModel).pipe(outputParser);

      final stream = chain.stream('What did President Biden say about Russia?');

      var content = '';
      var count = 0;
      await for (final res in stream) {
        content += res;
        count++;
      }
      expect(count, greaterThan(1));
      expect(content, isNotEmpty);
    });
  });
}
