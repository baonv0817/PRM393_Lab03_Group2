import 'dart:async';

import 'package:breakbite/ui/seller_menu/view_models/menu_item_form_view_model.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

/// The K14 form with the AI feature (docs/ai-feature.md), every service a fake.
class _Form {
  _Form({bool aiOn = true, String? itemId}) {
    if (aiOn) config.publish(RemoteKeys.aiEnabled, true);
    vm = MenuItemFormViewModel(
      menu: menu,
      storage: FakeStorageService(),
      photos: FakePhotoPickerService(),
      crash: crash,
      ai: ai,
      remoteConfig: config,
      analytics: analytics,
      kioskId: 'q9-t2',
      itemId: itemId,
    );
  }

  final menu = FakeMenuRepository();
  final crash = FakeCrashService();
  final ai = FakeMenuAiService();
  final config = FakeRemoteConfigService();
  final analytics = FakeAnalyticsService();
  late final MenuItemFormViewModel vm;

  List<String> get eventNames => [for (final event in analytics.events) event.name];

  Map<String, Object>? paramsOf(String name) => analytics.events.lastWhere((event) => event.name == name).params;

  Future<void> pickPhoto() => vm.pickPhoto(PhotoSource.gallery);
}

void main() {
  group('K14 AI: Remote Config switches the feature', () {
    test('the button is off by default and appears live when the console turns ai_enabled on, then off', () async {
      final form = _Form(aiOn: false);
      var rebuilds = 0;
      form.vm.addListener(() => rebuilds++);
      expect(form.vm.aiAvailable, isFalse, reason: 'off in the app until the console says otherwise');

      form.config.publish(RemoteKeys.aiEnabled, true);
      await pumpEventQueue();
      expect(form.vm.aiAvailable, isTrue);
      expect(rebuilds, greaterThan(0), reason: 'the screen rebuilds without reopening it');

      form.config.publish(RemoteKeys.aiEnabled, false);
      await pumpEventQueue();
      expect(form.vm.aiAvailable, isFalse);
    });

    test('editing an item (K15) never offers the AI, so it cannot overwrite what staff wrote', () {
      final form = _Form(itemId: 'q9-t2-banh-mi');
      expect(form.vm.aiAvailable, isFalse);
    });

    test('the model and the prompt come from Remote Config, and only the photo goes with them', () async {
      final form = _Form();
      form.config
        ..publish(RemoteKeys.aiModel, 'gemini-test-model')
        ..publish(RemoteKeys.aiPrompt, 'Prompt thử nghiệm');
      await form.pickPhoto();
      await form.vm.suggest.execute();
      final call = form.ai.calls.single;
      expect(call.model, 'gemini-test-model');
      expect(call.prompt, 'Prompt thử nghiệm');
      expect(call.photo, FakePhotoPickerService.onePixel);
    });

    test(
      'turned off between showing the button and pressing it: nothing is sent and the reason is "disabled"',
      () async {
        final form = _Form();
        await form.pickPhoto();
        form.config.publish(RemoteKeys.aiEnabled, false);
        final result = await form.vm.suggest.execute();
        expect(((result! as Err).error as AiException).reason, AiFailure.disabled);
        expect(form.ai.calls, isEmpty);
      },
    );
  });

  group('K14 AI: a suggestion fills the form, labelled, and staff decide', () {
    test('without a photo the AI cannot be asked', () async {
      final form = _Form();
      expect(form.vm.canSuggest, isFalse);
      final result = await form.vm.suggest.execute();
      expect((result! as Err).error, isA<ValidationException>());
      expect(form.ai.calls, isEmpty);
    });

    test('every field is filled and labelled "Gợi ý từ AI", and ai_request is logged with the model', () async {
      final form = _Form();
      await form.pickPhoto();
      expect(form.vm.canSuggest, isTrue);

      final result = await form.vm.suggest.execute();

      expect(result, isA<Ok<MenuItemSuggestion>>());
      final vm = form.vm;
      expect(vm.name, 'Bánh mì thịt nướng');
      expect(vm.category, ItemCategory.food);
      expect(vm.price, '25000');
      expect(vm.prepMinutes, '5');
      expect(vm.description, startsWith('Bánh mì giòn'));
      expect(AiField.values.every(vm.isAiSuggested), isTrue);
      expect(vm.hasAiSuggestion, isTrue);
      expect(form.paramsOf(AnalyticsEvents.aiRequest), {
        'feature': MenuItemFormViewModel.aiFeature,
        'model': RemoteKeys.defaultAiModel,
      });
      expect(await form.menu.getItem('q9-t2-banh-mi-thit-nuong'), isA<Err<MenuItem>>(), reason: 'nothing saved yet');
    });

    test('a field staff change loses its label; the notice goes once every field was changed', () async {
      final form = _Form();
      await form.pickPhoto();
      await form.vm.suggest.execute();
      final vm = form.vm..setPrice('30000');
      expect(vm.isAiSuggested(AiField.price), isFalse);
      expect(vm.isAiSuggested(AiField.name), isTrue);

      vm
        ..setName('Bánh mì đặc biệt')
        ..setCategory(ItemCategory.other)
        ..changePrepMinutes(1)
        ..setDescription('Thêm pate.');
      expect(vm.hasAiSuggestion, isFalse);
    });

    test('saving logs ai_result_accepted with how many fields staff kept and changed', () async {
      final form = _Form();
      await form.pickPhoto();
      await form.vm.suggest.execute();
      form.vm.setPrice('30000');

      final saved = await form.vm.save.execute();

      final id = (saved! as Ok<String>).value;
      final item = (await form.menu.getItem(id) as Ok<MenuItem>).value;
      expect(item.name, 'Bánh mì thịt nướng', reason: 'what the AI proposed');
      expect(item.priceVnd, 30000, reason: 'what staff changed');
      expect(form.paramsOf(AnalyticsEvents.aiResultAccepted), {
        'feature': MenuItemFormViewModel.aiFeature,
        'fields_kept': 4,
        'fields_changed': 1,
      });
    });

    test('an item typed by hand logs no AI event', () async {
      final form = _Form();
      form.vm
        ..setName('Xôi gà')
        ..setPrice('20000');
      await form.vm.save.execute();
      expect(form.eventNames.where((name) => name.startsWith('ai_')), isEmpty);
    });
  });

  group('K14 AI: failures leave the form usable by hand', () {
    test('the reason stays under the button (not a passing message) until another photo is chosen', () async {
      final form = _Form();
      await form.pickPhoto();
      form.ai.next = Result.error(AiException(AiFailure.notFood));
      await form.vm.suggest.execute();
      expect(form.vm.aiError, AiException(AiFailure.notFood).message);

      await form.pickPhoto();
      expect(form.vm.aiError, isNull);
    });

    for (final (reason, toCrashlytics) in [
      (AiFailure.quota, false),
      (AiFailure.network, false),
      (AiFailure.notFood, false),
      (AiFailure.badOutput, true),
      (AiFailure.other, true),
    ]) {
      test(
        '${reason.analyticsName}: what staff typed stays, ai_error says why, Crashlytics only if unexpected',
        () async {
          final form = _Form();
          form.vm
            ..setName('Xôi gà')
            ..setPrice('20000');
          await form.pickPhoto();
          form.ai.next = Result.error(AiException(reason));

          final result = await form.vm.suggest.execute();

          final error = (result! as Err).error as AiException;
          expect(error.reason, reason);
          expect(error.message, contains('nhập tay'), reason: 'the message points to the way that still works');
          expect(form.vm.name, 'Xôi gà');
          expect(form.vm.price, '20000');
          expect(form.vm.hasAiSuggestion, isFalse);
          expect(form.vm.suggest.running, isFalse);
          expect(form.paramsOf(AnalyticsEvents.aiError), {
            'feature': MenuItemFormViewModel.aiFeature,
            'reason': reason.analyticsName,
            'model': RemoteKeys.defaultAiModel,
          });
          expect(form.crash.errors, toCrashlytics ? hasLength(1) : isEmpty);

          final saved = await form.vm.save.execute();
          expect(saved, isA<Ok<String>>(), reason: 'the item can still be saved by hand');
        },
      );
    }
  });

  group('CR-F01: staff keep typing while Gemini answers', () {
    test('what staff typed while waiting is kept, and Save waits for the answer', () async {
      final form = _Form();
      await form.pickPhoto();
      form.ai.gate = Completer<void>();
      final pending = form.vm.suggest.execute();
      await pumpEventQueue();
      expect(form.vm.suggest.running, isTrue);
      form.vm
        ..setName('Bánh mì của quầy')
        ..setPrice('30000');
      expect(form.vm.canSave, isFalse, reason: 'the answer would rewrite the form after the item is saved');
      final early = await form.vm.save.execute();
      expect(early?.errorOrNull?.message, MenuItemFormViewModel.waitForAiMessage);

      form.ai.gate!.complete();
      await pending;
      expect(form.vm.name, 'Bánh mì của quầy', reason: 'typed while waiting, so the answer leaves it alone');
      expect(form.vm.price, '30000');
      expect(form.vm.isAiSuggested(AiField.name), isFalse);
      expect(form.vm.isAiSuggested(AiField.price), isFalse);
      expect(form.vm.description, FakeMenuAiService.banhMi.description, reason: 'untouched fields are filled');
      expect(form.vm.isAiSuggested(AiField.description), isTrue);
      expect(form.vm.canSave, isTrue);
    });

    test('a field changed before asking again is filled by the new answer', () async {
      final form = _Form();
      await form.pickPhoto();
      form.vm.setName('Tên cũ');
      await form.vm.suggest.execute();
      expect(form.vm.name, FakeMenuAiService.banhMi.name);
      expect(form.vm.isAiSuggested(AiField.name), isTrue);
    });
  });
}
