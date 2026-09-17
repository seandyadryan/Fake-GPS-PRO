import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n.dart';
import '../l10n/languages.dart';
import '../providers/language_provider.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _query = '';
  bool _saving = false;

  Future<void> _select(Locale? locale) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(languageProvider.notifier).select(locale);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.languageSavedError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(languageProvider).valueOrNull;
    final languages = appLanguages
        .where(
          (language) =>
              '${language.nativeName} ${language.englishName} ${language.locale.toLanguageTag()}'
                  .toLowerCase()
                  .contains(_query.toLowerCase().trim()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.language)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(context.l10n.languageDescription),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  labelText: context.l10n.languageSearch,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (query) => setState(() => _query = query),
              ),
            ),
            if (_saving) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(context.l10n.systemLanguage),
                    trailing: selected == null
                        ? const Icon(Icons.check_circle)
                        : null,
                    selected: selected == null,
                    onTap: _saving ? null : () => _select(null),
                  ),
                  const Divider(),
                  for (final language in languages)
                    ListTile(
                      key: ValueKey(
                        'language-${language.locale.toLanguageTag()}',
                      ),
                      title: Text(language.nativeName),
                      subtitle: Text(language.englishName),
                      trailing: selected == language.locale
                          ? const Icon(Icons.check_circle)
                          : null,
                      selected: selected == language.locale,
                      onTap: _saving ? null : () => _select(language.locale),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
