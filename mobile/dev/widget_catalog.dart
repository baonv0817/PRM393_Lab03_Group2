import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// T21: every shared widget of `lib/ui/core/widgets/` in each of its variants, on one scrolling page.
/// Run it on a phone with `flutter run -t dev/widget_catalog.dart`; `test/ui/core/widget_catalog_test.dart`
/// checks it at 360 dp and 412 dp (no overflow, 48 dp tap targets, labelled buttons, text contrast).
void main() => runApp(const WidgetCatalogApp());

class WidgetCatalogApp extends StatelessWidget {
  const WidgetCatalogApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BreakBite widgets',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: const WidgetCatalog(),
  );
}

const _item = MenuItem(
  id: 'm1',
  name: 'Combo Tacos Bò Phô Mai thêm sốt cay đặc biệt',
  priceVnd: 39000,
  category: ItemCategory.food,
  prepMinutes: 4,
  imageUrl: 'assets/images/menu/tacos-bo.jpg',
);

const _soldOut = MenuItem(
  id: 'm4',
  name: 'Trà đào cam sả',
  priceVnd: 25000,
  category: ItemCategory.drink,
  prepMinutes: 2,
  soldOut: true,
  imageUrl: 'assets/images/menu/tra-dao.jpg',
);

class WidgetCatalog extends StatefulWidget {
  const WidgetCatalog({super.key});

  @override
  State<WidgetCatalog> createState() => _WidgetCatalogState();
}

class _WidgetCatalogState extends State<WidgetCatalog> {
  var _chip = 0;
  var _quantity = 2;
  var _method = PaymentMethod.momo;
  var _card = 0;
  var _tab = 0;
  final _search = TextEditingController(text: 'tacos');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _noop() {}

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...children.expand((w) => [w, const SizedBox(height: AppSpacing.sm)]),
        ],
      ),
    );

    return Scaffold(
      appBar: AppTopBar(
        title: 'Thư viện widget',
        actions: [
          AppBadgeIconButton(icon: Icons.notifications_none, semanticLabel: 'Thông báo', onPressed: _noop, count: 3),
          AppBadgeIconButton(
            icon: Icons.shopping_cart_outlined,
            semanticLabel: 'Giỏ hàng',
            onPressed: _noop,
            showDot: true,
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        tabs: const [
          AppNavTab(label: 'Trang chủ', icon: Icons.home_outlined),
          AppNavTab(label: 'Thực đơn', icon: Icons.restaurant_menu),
          AppNavTab(label: 'Đơn hàng', icon: Icons.receipt_long_outlined),
          AppNavTab(label: 'Cá nhân', icon: Icons.person_outline),
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          section('Thương hiệu', [
            const Row(
              children: [
                BreakBiteLogo(size: 56),
                SizedBox(width: AppSpacing.sm),
                BreakBiteLogo(size: 56, variant: LogoVariant.soft),
                SizedBox(width: AppSpacing.sm),
                Flexible(child: FittedBox(child: BreakBiteWordmark(fontSize: 28))),
              ],
            ),
          ]),
          section('Nút', [
            AppButton(label: 'Xác nhận đặt món', onPressed: _noop, large: true),
            AppButton(
              label: 'Tiếp tục',
              onPressed: _noop,
              variant: AppButtonVariant.secondary,
              icon: Icons.arrow_forward,
            ),
            AppButton(label: 'Để sau', onPressed: _noop, variant: AppButtonVariant.text),
            AppButton(label: 'Huỷ đơn', onPressed: _noop, variant: AppButtonVariant.destructive),
            AppButton(label: 'Đang gửi', onPressed: _noop, loading: true),
            const AppButton(label: 'Không bấm được', onPressed: null),
            Row(
              children: [
                AppIconButton(icon: Icons.add, semanticLabel: 'Thêm', onPressed: _noop),
                AppIconButton(icon: Icons.favorite_border, semanticLabel: 'Yêu thích', onPressed: _noop, filled: true),
              ],
            ),
          ]),
          section('Ô nhập và bộ lọc', [
            AppSearchField(hint: 'Tìm món, ví dụ tacos', onTap: _noop),
            AppSearchField(hint: 'Tìm món', controller: _search, onChanged: (_) {}),
            const AppTextField(label: 'Mã số sinh viên', hint: 'SE183398'),
            const AppTextField(label: 'Mã số sinh viên', errorText: 'Mã số sinh viên có dạng SE và 6 chữ số.'),
            const AppTextField(label: 'Ghi chú cho bếp', helperText: 'Tối đa 100 ký tự'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (i, label) in const ['Tất cả', 'Dưới 5 phút', 'Đồ uống', 'Món chay'].indexed)
                  AppChip(label: label, selected: _chip == i, onSelected: (_) => setState(() => _chip = i)),
              ],
            ),
          ]),
          section('Thẻ món', [
            FoodCard(item: _item, onTap: _noop, onAdd: _noop),
            FoodCard(
              item: _item,
              onTap: _noop,
              onAdd: _noop,
              quantity: _quantity,
              onIncrement: () => setState(() => _quantity++),
              onDecrement: () => setState(() => _quantity = _quantity > 0 ? _quantity - 1 : 0),
            ),
            FoodCard(item: _soldOut, onTap: _noop, onAdd: _noop),
            FoodCard(item: _item, onTap: _noop, onAdd: _noop, kioskClosed: true, reopenLabel: 'Mở lại lúc 07:00'),
            const FoodCardSkeleton(),
          ]),
          section('Số lượng, trạng thái, lựa chọn', [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                QuantityStepper(
                  name: 'Combo Tacos',
                  quantity: _quantity,
                  onIncrement: () => setState(() => _quantity++),
                  onDecrement: () => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1),
                  removesAtOne: false,
                ),
                const StatusBadge(label: 'Sẵn sàng'),
                const StatusBadge(label: 'Trễ 2 phút', warning: true),
              ],
            ),
            for (final method in PaymentMethod.values)
              PaymentMethodTile(
                method: method,
                selected: _method == method,
                onTap: () => setState(() => _method = method),
                testId: 'catalog.pay.${method.name}',
              ),
            for (final i in [0, 1])
              SelectableCard(
                selected: _card == i,
                onTap: () => setState(() => _card = i),
                semanticLabel: i == 0 ? 'Sớm nhất' : 'Giờ nghỉ 10:15',
                child: Text(i == 0 ? 'Sớm nhất · khoảng 6 phút' : 'Giờ nghỉ 10:15 – 10:30'),
              ),
            QuickActionRow(
              actions: [
                QuickAction(label: 'Sửa đơn', icon: Icons.edit_outlined, onPressed: _noop),
                QuickAction(label: 'Phóng to mã QR', icon: Icons.qr_code_2, onPressed: _noop),
                QuickAction(label: 'Huỷ đơn', icon: Icons.close, onPressed: _noop, tone: QuickActionTone.destructive),
              ],
            ),
          ]),
          section('Ảnh, mã QR, người dùng', [
            const Row(
              children: [
                MenuItemImage(imageUrl: 'assets/images/menu/banh-mi.jpg'),
                SizedBox(width: AppSpacing.sm),
                MenuItemImage(imageUrl: null),
                SizedBox(width: AppSpacing.sm),
                UserAvatar(name: 'Nguyễn Thành Danh'),
              ],
            ),
            const Center(
              child: PickupQrCode(data: 'bb:A-204:100204', semanticLabel: 'Mã QR nhận món 100 204', size: 160),
            ),
          ]),
          section('Trạng thái màn hình', [
            const SizedBox(height: 160, child: LoadingView()),
            SizedBox(
              height: 340,
              child: EmptyView(message: 'Chưa có món yêu thích', actionLabel: 'Xem thực đơn', onAction: _noop),
            ),
            SizedBox(
              height: 340,
              child: ErrorView(message: 'Không tải được thực đơn.', onRetry: _noop),
            ),
            SizedBox(
              height: 140,
              child: ViewStateView<String>(
                state: const ViewData('Có dữ liệu'),
                builder: (context, value) => Text(value),
                onRetry: _noop,
              ),
            ),
            const SizedBox(height: 320, child: SkeletonList(count: 2)),
          ]),
          section('Thanh hành động dưới cùng', [
            BottomActionButton(label: 'Thanh toán · 78.000đ', onPressed: _noop),
            BottomActionButton(
              label: 'Lưu thay đổi',
              onPressed: _noop,
              secondaryLabel: 'Giữ nguyên đơn',
              onSecondary: _noop,
            ),
          ]),
        ],
      ),
    );
  }
}
