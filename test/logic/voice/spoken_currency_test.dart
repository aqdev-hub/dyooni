import 'package:dyooni/data/models/currency_type.dart';
import 'package:dyooni/logic/voice/spoken_currency.dart';
import 'package:dyooni/logic/voice/voice_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mine = [
    CurrencyType(id: 'LOCAL', name: 'محلي'),
    CurrencyType(id: 'FOREIGN', name: 'أجنبي'),
    CurrencyType(id: 'دولار', name: 'دولار'),
    CurrencyType(id: 'ريال سعودي', name: 'ريال سعودي'),
  ];

  group('SpokenCurrency.match', () {
    test('finds the person\'s own currency by its name', () {
      expect(SpokenCurrency.match('احمد علي عليه خمسة الاف دولار', mine), 'دولار');
      expect(SpokenCurrency.match('له الف ريال سعودي', mine), 'ريال سعودي');
      expect(SpokenCurrency.match('له الف سعودي', mine), 'ريال سعودي');
      expect(SpokenCurrency.match('عليه مية اجنبي', mine), 'FOREIGN');
    });

    test('tolerates plural and spelling slips', () {
      expect(SpokenCurrency.match('ثلاثة الاف دولارات', mine), 'دولار');
      expect(SpokenCurrency.match('الف ريال سعودى', mine), 'ريال سعودي');
    });

    test('a bare ريال names nothing', () {
      expect(SpokenCurrency.match('احمد عليه الف ريال', mine), isNull);
      expect(SpokenCurrency.namesUnknownCurrency('احمد عليه الف ريال', mine), isFalse);
    });

    test('a currency the person has not added is reported', () {
      expect(SpokenCurrency.namesUnknownCurrency('عليه الف يورو', mine), isTrue);
      expect(SpokenCurrency.namesUnknownCurrency('عليه الف درهم', mine), isTrue);
      expect(SpokenCurrency.namesUnknownCurrency('عليه الف دولار', mine), isFalse);
    });

    test('older fixed codes still match natural speech', () {
      const old = [CurrencyType(id: 'LOCAL', name: 'محلي'), CurrencyType(id: 'USD', name: 'دولار أمريكي'), CurrencyType(id: 'SAR', name: 'العملة السعودية')];
      expect(SpokenCurrency.match('الف دولار', old), 'USD');
      expect(SpokenCurrency.match('الف سعودي', old), 'SAR');
    });
  });

  group('VoiceCommandParser with the person\'s currencies', () {
    const parser = VoiceCommandParser();

    test('records the named currency instead of the default', () {
      final d = parser.parse('احمد علي عليه خمسة الاف دولار', currencies: mine);
      expect(d.currency, 'دولار');
      expect(d.currencyUnsupported, isFalse);
    });

    test('no currency spoken → the default one', () {
      final d = parser.parse('احمد علي عليه خمسة الاف', currencies: mine);
      expect(d.currency, defaultCurrencyId);
      expect(d.currencyUnsupported, isFalse);
    });

    test('unknown currency → asks instead of saving the default', () {
      final d = parser.parse('احمد علي عليه خمسة الاف يورو', currencies: mine);
      expect(d.currencyUnsupported, isTrue);
    });
  });

  group('only the two built-in currencies', () {
    const builtIn = [CurrencyType(id: 'LOCAL', name: 'محلي'), CurrencyType(id: 'FOREIGN', name: 'أجنبي')];
    const parser = VoiceCommandParser();

    test('«ريال يمني» is the local currency, «أجنبي» and foreign words the other', () {
      expect(parser.parse('احمد علي له خمسة الاف ريال يمني', currencies: builtIn).currency, 'LOCAL');
      expect(parser.parse('احمد علي له خمسة الاف اجنبي', currencies: builtIn).currency, 'FOREIGN');
      expect(parser.parse('احمد علي له خمسة الاف بالأجنبي', currencies: builtIn).currency, 'FOREIGN');
      expect(parser.parse('احمد علي عليه مية دولار', currencies: builtIn).currency, 'FOREIGN');
      expect(parser.parse('احمد علي عليه مية ريال سعودي', currencies: builtIn).currency, 'FOREIGN');
      final d = parser.parse('احمد علي عليه مية دولار', currencies: builtIn);
      expect(d.currencyUnsupported, isFalse);
    });
  });

  group('bare «ريال»', () {
    const parser = VoiceCommandParser();
    const two = [
      CurrencyType(id: 'LOCAL', name: 'محلي'),
      CurrencyType(id: 'FOREIGN', name: 'أجنبي'),
      CurrencyType(id: 'ريال يمني', name: 'ريال يمني'),
      CurrencyType(id: 'ريال سعودي', name: 'ريال سعودي'),
    ];

    test('with two ريال currencies it asks which, never guesses', () {
      final d = parser.parse('محمد علي عليه خمسة الاف ريال', currencies: two);
      expect(d.currencyUnsupported, isTrue);
      expect(SpokenCurrency.riyalChoices('خمسة الاف ريال', two).map((c) => c.id), ['ريال يمني', 'ريال سعودي']);
    });

    test('a named one is not ambiguous', () {
      final d = parser.parse('محمد علي عليه خمسة الاف ريال يمني', currencies: two);
      expect(d.currency, 'ريال يمني');
      expect(d.currencyUnsupported, isFalse);
      expect(parser.parse('محمد علي عليه خمسة الاف ريال سعودي', currencies: two).currency, 'ريال سعودي');
    });

    test('the answer «يمني» / «سعودي» picks the right one', () {
      expect(parser.parse('يمني', currencies: two).currency, 'ريال يمني');
      expect(parser.parse('سعودي', currencies: two).currency, 'ريال سعودي');
    });

    test('only one ريال currency → that one, no question', () {
      const one = [CurrencyType(id: 'LOCAL', name: 'محلي'), CurrencyType(id: 'ريال يمني', name: 'ريال يمني')];
      final d = parser.parse('محمد علي عليه الف ريال', currencies: one);
      expect(d.currency, 'ريال يمني');
      expect(d.currencyUnsupported, isFalse);
    });

    test('no ريال currency at all → the default as before', () {
      const none = [CurrencyType(id: 'LOCAL', name: 'محلي'), CurrencyType(id: 'FOREIGN', name: 'أجنبي')];
      final d = parser.parse('محمد علي عليه الف ريال', currencies: none);
      expect(d.currency, 'LOCAL');
      expect(d.currencyUnsupported, isFalse);
    });
  });

  group('compound names built on «عبد»', () {
    test('are joined', () {
      expect(VoiceCommandParser.joinCompoundNames('عبد القدوس محمد'), 'عبدالقدوس محمد');
      expect(VoiceCommandParser.joinCompoundNames('محمد عبد الله'), 'محمد عبدالله');
      expect(VoiceCommandParser.joinCompoundNames('عبد الوهاب علي'), 'عبدالوهاب علي');
      expect(VoiceCommandParser.joinCompoundNames('عبد ربه سالم'), 'عبدربه سالم');
    });

    test('other names are left alone', () {
      expect(VoiceCommandParser.joinCompoundNames('عبد سالم'), 'عبد سالم');
      expect(VoiceCommandParser.joinCompoundNames('عبدالله محمد'), 'عبدالله محمد');
    });

    test('the parsed account name comes out joined', () {
      const parser = VoiceCommandParser();
      final d = parser.parse('عبد القدوس محمد عليه خمسة الاف');
      expect(d.accountName, 'عبدالقدوس محمد');
    });
  });
}
