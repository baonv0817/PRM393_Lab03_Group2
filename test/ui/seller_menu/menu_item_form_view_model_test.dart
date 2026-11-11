import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/seller_menu/view_models/menu_item_form_view_model.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

class _OfflineGet extends FakeMenuRepository {
  @override
  Future<Result<MenuItem>> getItem(String id) async => const Result.error(NetworkException());
}

class _OfflineSave extends FakeMenuRepository {
  @override
  Future<Result<String>> upsertItem(MenuItem item) async => const Result.error(NetworkException());
}

/// Refuses the first upload, as a lost connection would.
class _FlakyStorage extends FakeStorageService {
  int attempts = 0;

  @override
  Future<Result<UploadedFile>> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) {
    attempts++;
    if (attempts == 1) return Future.value(const Result.error(NetworkException()));
    return super.upload(folder: folder, ownerId: ownerId, fileName: fileName, bytes: bytes, onProgress: onProgress);
  }
}

MenuItemFormViewModel _vm(
  FakeMenuRepository menu, {
  String? kioskId = 'q9-t2',
  String? itemId,
  FakeCrashService? crash,
  FakeStorageService? storage,
  FakePhotoPickerService? photos,
}) => MenuItemFormViewModel(
  menu: menu,
  storage: storage ?? FakeStorageService(),
  photos: photos ?? FakePhotoPickerService(),
  crash: crash ?? FakeCrashService(),
  kioskId: kioskId,
  itemId: itemId,
);

Future<MenuItem> _stored(FakeMenuRepository menu, String id) async => (await menu.getItem(id) as Ok<MenuItem>).value;

void _fill(MenuItemFormViewModel vm, {String name = 'Bún bò Huế', String price = '45000', String prep = '6'}) {
  vm
    ..setName(name)
    ..setPrice(price)
    ..setPrepMinutes(prep);
}

void main() {
  group('MenuItemFormViewModel the photo of the item (K14, K15)', () {
    test(
      'a new item with a photo: it goes to Cloudinary under menu/<kiosk>/ and its link is saved in the item',
      () async {
        final menu = FakeMenuRepository();
        final storage = FakeStorageService();
        final vm = _vm(menu, storage: storage);
        await pumpEventQueue();
        expect(vm.hasPhoto, isFalse);

        expect((await vm.pickPhoto(PhotoSource.gallery)).isOk, isTrue);
        expect(vm.hasPhoto, isTrue);
        expect(vm.pickedPhoto, isNotNull);
        expect(storage.uploads, isEmpty, reason: 'nothing is sent before the item is saved');

        vm
          ..setName('Bánh flan')
          ..setPrice('15000');
        final result = await vm.save.execute();

        expect(result!.isOk, isTrue);
        expect(storage.uploads.single.url, startsWith('https://'));
        expect(storage.uploads.single.publicId, 'breakbite/menu/q9-t2/mon.png');
        final stored = await _stored(menu, 'q9-t2-banh-flan');
        expect(stored.imageUrl, storage.uploads.single.url);
        expect(vm.uploadProgress, isNull);
        vm.dispose();
      },
    );

    test('backing out of the picker changes nothing; a refused permission is an error that is not a crash', () async {
      final crash = FakeCrashService();
      final photos = FakePhotoPickerService()..next = null;
      final vm = _vm(FakeMenuRepository(), photos: photos, crash: crash);
      await pumpEventQueue();

      expect((await vm.pickPhoto(PhotoSource.camera)).isOk, isTrue);
      expect(vm.hasPhoto, isFalse);
      expect(photos.asked, [PhotoSource.camera]);

      photos.failure = const PermissionDeniedException(message: 'Chưa cho phép dùng camera.');
      final denied = await vm.pickPhoto(PhotoSource.camera);
      expect((denied as Err<void>).error.message, 'Chưa cho phép dùng camera.');
      expect(vm.hasPhoto, isFalse);
      expect(crash.errors, isEmpty);
      vm.dispose();
    });

    test(
      'a failed upload writes nothing, and the retry sends the photo once more, then it is not sent twice',
      () async {
        final menu = FakeMenuRepository();
        final storage = _FlakyStorage();
        final vm = _vm(menu, storage: storage);
        await pumpEventQueue();
        await vm.pickPhoto(PhotoSource.gallery);
        vm
          ..setName('Bánh flan')
          ..setPrice('15000');

        final first = await vm.save.execute();
        expect((first! as Err<String>).error, isA<NetworkException>());
        expect((await menu.getItem('q9-t2-banh-flan')).valueOrNull, isNull, reason: 'the item was not written');

        expect((await vm.save.execute())!.isOk, isTrue);
        expect(storage.attempts, 2);
        expect(storage.uploads, hasLength(1));
        vm.dispose();
      },
    );

    test('editing: a new photo replaces the old link, nothing changed keeps it, removing it clears it', () async {
      final menu = FakeMenuRepository();
      final storage = FakeStorageService();

      final keep = _vm(menu, itemId: 'm1', storage: storage);
      await pumpEventQueue();
      expect(keep.hasPhoto, isTrue);
      expect(keep.photoUrl, 'assets/images/menu/tacos-bo.jpg');
      expect(keep.canSave, isFalse);
      keep.setPrice('41000');
      await keep.save.execute();
      expect((await _stored(menu, 'm1')).imageUrl, 'assets/images/menu/tacos-bo.jpg');
      keep.dispose();

      final replace = _vm(menu, itemId: 'm1', storage: storage);
      await pumpEventQueue();
      await replace.pickPhoto(PhotoSource.gallery);
      expect(replace.canSave, isTrue, reason: 'a new photo is a change');
      expect(replace.photoUrl, isNull, reason: 'the new picture is shown instead of the saved one');
      await replace.save.execute();
      expect((await _stored(menu, 'm1')).imageUrl, storage.uploads.single.url);
      replace.dispose();

      final remove = _vm(menu, itemId: 'm1', storage: storage);
      await pumpEventQueue();
      remove.removePhoto();
      expect((remove.hasPhoto, remove.canSave), (false, true));
      await remove.save.execute();
      expect((await _stored(menu, 'm1')).imageUrl, isNull);
      remove.dispose();
    });

    test(
      'choosing a photo after removing one shows the new photo, and removing it again is a no-op without one',
      () async {
        final vm = _vm(FakeMenuRepository(), itemId: 'm1');
        await pumpEventQueue();
        vm.removePhoto();
        expect(vm.hasPhoto, isFalse);
        vm.removePhoto();
        await vm.pickPhoto(PhotoSource.gallery);
        expect(vm.hasPhoto, isTrue);
        expect(vm.pickedPhoto, isNotNull);
        vm.dispose();
      },
    );
  });

  group('MenuItemFormViewModel adding an item (K14)', () {
    test('starts empty with a preparation time already filled, and shows no error before saving is tried', () async {
      final vm = _vm(FakeMenuRepository());
      await pumpEventQueue();

      expect(vm.isNew, isTrue);
      expect(vm.state, isA<ViewData<MenuItem?>>());
      expect((vm.state as ViewData<MenuItem?>).data, isNull);
      expect((vm.name, vm.price, vm.prepMinutes, vm.category), ('', '', '5', ItemCategory.food));
      expect(vm.canSave, isTrue);
      expect(vm.isValid, isFalse);
      expect((vm.nameError, vm.priceError, vm.prepError), (null, null, null));
      vm.dispose();
    });

    test('saving an empty form is refused and every missing field shows its error (K14-ERR)', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu);
      await pumpEventQueue();

      final result = await vm.save.execute();

      expect((result! as Err<String>).error.message, MenuItemFormViewModel.invalidMessage);
      expect(vm.nameError, 'Nhập tên món.');
      expect(vm.priceError, 'Nhập giá món.');
      expect(vm.prepError, isNull);
      expect(await menu.watchMenu('q9-t2').first, hasLength(4));
      vm.dispose();
    });

    test('each field says what is wrong, and errors go away as it is fixed', () async {
      final vm = _vm(FakeMenuRepository());
      await pumpEventQueue();
      _fill(vm, name: '!!!', price: '0', prep: '121');
      await vm.save.execute();

      expect(vm.nameError, 'Tên món cần có chữ hoặc số.');
      expect(vm.priceError, 'Giá món phải lớn hơn 0.');
      expect(vm.prepError, 'Thời gian chuẩn bị tối đa 120 phút.');

      vm.setPrice('2000000');
      expect(vm.priceError, 'Giá món tối đa 1.000.000đ.');
      vm.setPrepMinutes('');
      expect(vm.prepError, 'Nhập thời gian chuẩn bị, tính bằng phút.');

      _fill(vm, prep: '0');
      expect(vm.isValid, isTrue, reason: 'a drink that needs no preparation is allowed');
      expect((vm.nameError, vm.priceError, vm.prepError), (null, null, null));
      vm.dispose();
    });

    test('the name and the description stop at their maximum length', () async {
      final vm = _vm(FakeMenuRepository());
      await pumpEventQueue();

      vm.setName('x' * (MenuItemFormViewModel.maxNameLength + 10));
      vm.setDescription('y' * (MenuItemFormViewModel.maxDescriptionLength + 10));
      expect(vm.name.length, MenuItemFormViewModel.maxNameLength);
      expect(vm.description.length, MenuItemFormViewModel.maxDescriptionLength);
      vm.dispose();
    });

    test('saving adds the item to the staff member\'s kiosk, on sale, and returns its id', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu);
      await pumpEventQueue();
      _fill(vm, name: '  Bún bò Huế  ');
      vm
        ..setCategory(ItemCategory.other)
        ..setDescription('  Cay vừa  ');

      final result = await vm.save.execute();

      final id = (result! as Ok<String>).value;
      expect(id, 'q9-t2-bun-bo-hue');
      final item = await _stored(menu, id);
      expect((item.name, item.priceVnd, item.prepMinutes), ('Bún bò Huế', 45000, 6));
      expect(
        (item.category, item.kioskId, item.dishId, item.soldOut),
        (ItemCategory.other, 'q9-t2', 'bun-bo-hue', false),
      );
      expect(item.description, 'Cay vừa');
      expect(await menu.watchMenu('q9-t2').first, hasLength(5));
      vm.dispose();
    });

    test('an item that is already on the menu is refused, and the name field says so until it changes', () async {
      final menu = FakeMenuRepository();
      final first = _vm(menu);
      await pumpEventQueue();
      _fill(first);
      await first.save.execute();

      final vm = _vm(menu);
      await pumpEventQueue();
      _fill(vm, name: 'bún bò huế');
      final result = await vm.save.execute();

      expect((result! as Err<String>).error.message, 'Món này đã có trong thực đơn.');
      expect(vm.nameError, 'Món này đã có trong thực đơn.');
      expect(await menu.watchMenu('q9-t2').first, hasLength(5));

      vm.setName('Bún bò Huế đặc biệt');
      expect(vm.nameError, isNull);
      first.dispose();
      vm.dispose();
    });

    test('a failed save is reported, recorded, and keeps what was typed', () async {
      final crash = FakeCrashService();
      final vm = _vm(_OfflineSave(), crash: crash);
      await pumpEventQueue();
      _fill(vm);

      final result = await vm.save.execute();

      expect((result! as Err<String>).error.message, const NetworkException().message);
      expect(crash.errors, hasLength(1));
      expect(vm.name, 'Bún bò Huế');
      vm.dispose();
    });

    test('an account without a kiosk cannot add items', () async {
      for (final kioskId in [null, '']) {
        final vm = _vm(FakeMenuRepository(), kioskId: kioskId);
        await pumpEventQueue();

        expect(vm.state, isA<ViewEmpty<MenuItem?>>());
        expect((vm.state as ViewEmpty<MenuItem?>).message, MenuItemFormViewModel.noKioskMessage);
        vm.dispose();
      }
    });
  });

  group('MenuItemFormViewModel editing an item (K15)', () {
    test('opens with the item\'s values, and has nothing to save until something changes', () async {
      final vm = _vm(FakeMenuRepository(), itemId: 'm1');
      await pumpEventQueue();

      expect(vm.isNew, isFalse);
      expect(vm.state, isA<ViewData<MenuItem?>>());
      expect(
        (vm.name, vm.price, vm.prepMinutes, vm.category),
        ('Combo Tacos Bò Phô Mai', '39000', '4', ItemCategory.food),
      );
      expect(vm.hasChanges, isFalse);
      expect(vm.canSave, isFalse);

      vm.setPrice('42000');
      expect(vm.hasChanges, isTrue);
      expect(vm.canSave, isTrue);
      vm.setPrice('39000');
      expect(vm.canSave, isFalse);
      vm.dispose();
    });

    test('saving changes the item in place: same id and dish, new values', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu, itemId: 'm1');
      await pumpEventQueue();
      vm
        ..setName('Combo Tacos Bò Phô Mai Lớn')
        ..setPrice('45000')
        ..setPrepMinutes('5')
        ..setCategory(ItemCategory.other)
        ..setDescription('Thêm phô mai');

      final result = await vm.save.execute();

      expect((result! as Ok<String>).value, 'm1');
      final item = await _stored(menu, 'm1');
      expect(
        (item.name, item.priceVnd, item.prepMinutes, item.category),
        ('Combo Tacos Bò Phô Mai Lớn', 45000, 5, ItemCategory.other),
      );
      expect((item.id, item.dishId, item.kioskId), ('m1', 'tacos-bo', 'q9-t2'));
      expect(item.description, 'Thêm phô mai');
      expect(item.imageUrl, 'assets/images/menu/tacos-bo.jpg', reason: 'the image is kept');
      expect(await menu.watchMenu('q9-t2').first, hasLength(4));
      vm.dispose();
    });

    test('a sold-out switch flipped while the form was open is not undone by saving', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu, itemId: 'm1');
      await pumpEventQueue();
      await menu.setSoldOut('m1', true, reason: SoldOutReason.machineBroken);
      vm.setPrice('41000');

      await vm.save.execute();

      final item = await _stored(menu, 'm1');
      expect((item.priceVnd, item.soldOut, item.soldOutReason), (41000, true, SoldOutReason.machineBroken));
      vm.dispose();
    });

    test('an invalid change is refused and shows its error', () async {
      final menu = FakeMenuRepository();
      final vm = _vm(menu, itemId: 'm1');
      await pumpEventQueue();
      vm.setPrice('0');

      final result = await vm.save.execute();

      expect(result, isA<Err<String>>());
      expect(vm.priceError, 'Giá món phải lớn hơn 0.');
      expect((await _stored(menu, 'm1')).priceVnd, 39000);
      vm.dispose();
    });

    test('an item of another kiosk, an unknown item and a failed load each get their own state', () async {
      final other = _vm(FakeMenuRepository(), itemId: 'm5');
      final unknown = _vm(FakeMenuRepository(), itemId: 'nope');
      final crash = FakeCrashService();
      final failing = _vm(_OfflineGet(), itemId: 'm1', crash: crash);
      await pumpEventQueue();

      expect((other.state as ViewEmpty<MenuItem?>).message, MenuItemFormViewModel.notYoursMessage);
      expect((unknown.state as ViewEmpty<MenuItem?>).message, MenuItemFormViewModel.notFoundMessage);
      expect(failing.state, isA<ViewError<MenuItem?>>());
      expect((failing.state as ViewError<MenuItem?>).message, const NetworkException().message);
      expect(crash.errors, hasLength(1));

      final retry = failing.load();
      expect(failing.state, isA<ViewLoading<MenuItem?>>());
      await retry;
      expect(failing.state, isA<ViewError<MenuItem?>>());
      for (final vm in [other, unknown, failing]) {
        vm.dispose();
      }
    });
  });
}
