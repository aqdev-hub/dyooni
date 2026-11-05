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
}
