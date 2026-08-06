// The help center, end to end: category, draft, publish, search, clean up.
//
//   SUPDESK_API_KEY=sd_live_… dart run bin/help_center.dart
//
// Every write here needs a paid plan.
import 'dart:io';

import 'package:supdesk/supdesk.dart';

Future<void> main() async {
  final supdesk = SupDesk(apiKey: _env('SUPDESK_API_KEY'));

  try {
    // Categories sort by `sortOrder`, lowest first.
    final category = await supdesk.articleCategories.create(
      name: 'Exporting data',
      description: 'Getting your data out of the product.',
      sortOrder: 10,
    );
    print('category ${category.id} (${category.slug})');

    // Articles are created as drafts. The body is Markdown, not HTML.
    final draft = await supdesk.articles.create(
      title: 'How to export a report',
      body: '# Exporting\n\n1. Open **Reports**\n2. Click **Export**\n',
      excerpt: 'Export any report as CSV in two clicks.',
      slug: 'how-to-export-a-report',
      categoryId: category.id,
    );
    print('draft ${draft.id}, status ${draft.status.value}');

    // Publishing is an update, not a separate endpoint.
    final published = await supdesk.articles.update(
      draft.id,
      status: ArticleStatus.published,
    );
    print('published at ${published.publishedAt?.toIso8601String()}');

    // Search hits are a projection: id, title, slug, a snippet and a rank. Fetch
    // the article itself when you need the body.
    for (final hit in await supdesk.articles.search('export', limit: 5)) {
      print('${hit.rank.toStringAsFixed(2)}  ${hit.title}');
      print('        ${hit.snippet}');
      print('        in ${hit.categoryName ?? 'no category'}');
    }

    final full = await supdesk.articles.get(published.id);
    print('${full.helpfulCount} helpful / ${full.notHelpfulCount} not');

    // Listing filters by status and category.
    final page = await supdesk.articles.list(
      status: ArticleStatus.published,
      categoryId: category.id,
    );
    print('${page.data.length} published in this category');

    // Deleting a category keeps its articles; they become uncategorized.
    await supdesk.articles.delete(published.id);
    await supdesk.articleCategories.delete(category.id);
    print('cleaned up');
  } on ForbiddenException {
    print('Writes require a paid plan — the reads above still work.');
  } finally {
    supdesk.close();
  }
}

String _env(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    stderr.writeln('Set $name first.');
    exit(1);
  }
  return value;
}
