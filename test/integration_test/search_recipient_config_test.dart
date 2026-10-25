import 'package:flutter_test/flutter_test.dart';
import '../../integration_test/scenarios/search_email_by_date_time_and_sort_order_relevance_scenario.dart';

void main() {
  test(
    'uses the configured disposable recipient for all generated messages',
    () {
      expect(
        SearchEmailByDatetimeAndSortOrderRelevanceScenario.resolveRecipients(
          configuredRecipient: '+66951234567@numberinbox.test',
        ),
        everyElement('+66951234567@numberinbox.test'),
      );
    },
  );

  test('preserves upstream example recipients when unset', () {
    expect(
      SearchEmailByDatetimeAndSortOrderRelevanceScenario.resolveRecipients(),
      [
        'alice@example.com',
        'brian@example.com',
        'charlotte@example.com',
        'david@example.com',
        'emma@example.com',
      ],
    );
  });
}
