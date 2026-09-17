import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/app_localizations.dart';

/// Flutter 3.41 has Material support for Pashto/Uyghur but lacks Pashto
/// Cupertino resources and Uyghur Widgets resources. Fill these gaps explicitly.
const appLocalizationDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  _UyghurWidgetsDelegate(),
  GlobalWidgetsLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  _PashtoCupertinoDelegate(),
  GlobalCupertinoLocalizations.delegate,
];

class _UyghurWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _UyghurWidgetsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ug';
  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(const _UyghurWidgets());
  @override
  bool shouldReload(_UyghurWidgetsDelegate old) => false;
}

class _UyghurWidgets extends DefaultWidgetsLocalizations {
  const _UyghurWidgets();
  @override
  TextDirection get textDirection => TextDirection.rtl;
  @override
  String get copyButtonLabel => 'كۆچۈرۈش';
  @override
  String get cutButtonLabel => 'كېسىش';
  @override
  String get pasteButtonLabel => 'چاپلاش';
  @override
  String get selectAllButtonLabel => 'ھەممىنى تاللاش';
  @override
  String get lookUpButtonLabel => 'ئىزدەش';
  @override
  String get searchWebButtonLabel => 'توردىن ئىزدەش';
  @override
  String get shareButtonLabel => 'ھەمبەھىرلەش';
  @override
  String get noResultsFound => 'نەتىجە تېپىلمىدى';
  @override
  String get radioButtonUnselectedLabel => 'تاللانمىدى';
  @override
  String get reorderItemDown => 'تۆۋەنگە يۆتكەش';
  @override
  String get reorderItemUp => 'يۇقىرىغا يۆتكەش';
  @override
  String get reorderItemLeft => 'سولغا يۆتكەش';
  @override
  String get reorderItemRight => 'ئوڭغا يۆتكەش';
  @override
  String get reorderItemToStart => 'باشقا يۆتكەش';
  @override
  String get reorderItemToEnd => 'ئاخىرغا يۆتكەش';
}

class _PashtoCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _PashtoCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ps';
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const _PashtoCupertino());
  @override
  bool shouldReload(_PashtoCupertinoDelegate old) => false;
}

/// Localizes text-editing and navigation controls. Unused Cupertino calendar
/// semantics inherit English until Flutter supplies a complete Pashto delegate.
class _PashtoCupertino extends DefaultCupertinoLocalizations {
  const _PashtoCupertino();
  @override
  String get copyButtonLabel => 'کاپي';
  @override
  String get cutButtonLabel => 'پرې کول';
  @override
  String get pasteButtonLabel => 'نښلول';
  @override
  String get selectAllButtonLabel => 'ټول غوره کړئ';
  @override
  String get clearButtonLabel => 'پاکول';
  @override
  String get lookUpButtonLabel => 'لټون';
  @override
  String get searchWebButtonLabel => 'په ویب کې لټون';
  @override
  String get shareButtonLabel => 'شریکول';
  @override
  String get searchTextFieldPlaceholderLabel => 'لټون';
  @override
  String get cancelButtonLabel => 'لغوه کول';
  @override
  String get backButtonLabel => 'شاته';
  @override
  String get modalBarrierDismissLabel => 'تړل';
  @override
  String get menuDismissLabel => 'مینو تړل';
}
