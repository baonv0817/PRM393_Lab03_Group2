import 'package:breakbite/ui/search/view_models/search_view_model.dart';
import 'package:breakbite_core/data/repositories/local/in_memory_session_repository.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _Setup {
  _Setup() {
    session.selectKiosk('q9-t2');
  }

  final analytics = FakeAnalyticsService();
  final session = InMemorySessionRepository();

  SearchViewModel vm({Duration debounce = Duration.zero}) => SearchViewModel(
    menu: FakeMenuRepository(),
    cart: FakeCartRepository(),
    session: session,
    analytics: analytics,
    crash: FakeCrashService(),
    uid: 'u',
    debounce: debounce,
  );
}

List<String> _names(SearchViewModel vm) => (vm.state as ViewData<List<MenuItem>>).data.map((i) => i.name).toList();

void main() {
  group('SearchViewModel (S28)', () {
    test('lists nothing before anything is typed, then follows the words', () async {
      final vm = _Setup().vm();
      await pumpEventQueue();
      expect(vm.searching, isFalse);
      expect(vm.state, isA<ViewEmpty<List<MenuItem>>>());

      vm.setQuery('tacos');
      await pumpEventQueue();
      expect(_names(vm), ['Combo Tacos Bò Phô Mai', 'Tacos Gà Giòn Sốt Cay'], reason: 'in stock first, sold out last');
      expect(vm.resultCount, 2);
    });

    test('accents and case do not matter in either direction', () async {
      final vm = _Setup().vm();
      await pumpEventQueue();

      vm.setQuery('TRA DAO');
      await pumpEventQueue();
      expect(_names(vm), ['Trà Đào Chanh Sả']);
      vm.setQuery('mì trộn');
      await pumpEventQueue();
      expect(_names(vm), ['Mì Trộn Gà Cay Hàn Quốc']);
    });

    test('only this kiosk\'s menu is searched', () async {
      final vm = _Setup().vm();
      await pumpEventQueue();
      vm.setQuery('bánh mì');
      await pumpEventQueue();
      expect(vm.state, isA<ViewEmpty<List<MenuItem>>>(), reason: 'the bread is sold at the other kiosk');
    });

    test('a word with no match is an empty state that names the word (S28-EMPTY)', () async {
      final vm = _Setup().vm();
      await pumpEventQueue();
      vm.setQuery('bánh mì');
      await pumpEventQueue();
      expect((vm.state as ViewEmpty).message, 'Không tìm thấy "bánh mì"');
      expect(vm.resultCount, 0);
      expect(SearchViewModel.suggestions, isNotEmpty);
    });

    test('the filter keeps food or drinks, and a blank box clears the search at once', () async {
      final vm = _Setup().vm(debounce: const Duration(hours: 1));
      await pumpEventQueue();

      vm.searchNow('a');
      vm.setFilter(SearchFilter.drink);
      expect(_names(vm), ['Trà Đào Chanh Sả']);
      vm.setFilter(SearchFilter.food);
      expect(_names(vm), isNot(contains('Trà Đào Chanh Sả')));
      vm.setQuery('   ');
      expect(vm.searching, isFalse, reason: 'a blank box does not wait for the debounce');
    });

    test('waits for the debounce time before filtering, and a suggestion searches at once', () async {
      final vm = _Setup().vm(debounce: const Duration(milliseconds: 50));
      await pumpEventQueue();

      vm.setQuery('tacos');
      expect((vm.typed, vm.query), ('tacos', ''), reason: 'the box shows it, the list has not followed yet');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(vm.query, 'tacos');
      vm.searchNow('Trà đào');
      expect((vm.typed, vm.query), ('Trà đào', 'Trà đào'));
    });

    test('logs one search event with the term and the number of results, not one per key', () async {
      final s = _Setup();
      final vm = s.vm();
      await pumpEventQueue();

      vm.setQuery('tacos');
      await pumpEventQueue();
      vm.setFilter(SearchFilter.food);
      vm.setQuery('tacos');
      await pumpEventQueue();
      final events = s.analytics.events.where((e) => e.name == 'search').toList();
      expect(events, hasLength(1));
      expect(events.single.params, {'search_term': 'tacos', 'result_count': 2});
    });

    test('adds a result to the cart', () async {
      final vm = _Setup().vm();
      await pumpEventQueue();
      vm.setQuery('trà');
      await pumpEventQueue();
      final item = (vm.state as ViewData<List<MenuItem>>).data.single;
      await vm.addToCart(item);
      await pumpEventQueue();
      expect((vm.cartCount, vm.quantityOf(item)), (1, 1));
    });
  });
}
