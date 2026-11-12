import 'package:breakbite/ui/profile/view_models/student_info_view_model.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/ui/core/widgets/widgets.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class StudentInfoScreen extends StatelessWidget {
  const StudentInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StudentInfoViewModel>();
    return Scaffold(
      appBar: AppTopBar(title: 'Hồ sơ sinh viên', onBack: () => context.pop()),
      body: switch (vm.profile) {
        ViewLoading() || ViewEmpty() => const LoadingView(message: 'Đang tải hồ sơ…'),
        ViewError(:final message) => TestId(
          's16.retry',
          child: ErrorView(message: message, onRetry: vm.load),
        ),
        ViewData() => _StudentForm(vm: vm),
      },
    );
  }
}

class _StudentForm extends StatefulWidget {
  const _StudentForm({required this.vm});

  final StudentInfoViewModel vm;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  late final _name = TextEditingController(text: widget.vm.name);
  late final _studentId = TextEditingController(text: widget.vm.studentId);
  late final _phone = TextEditingController(text: widget.vm.phone);

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final result = await widget.vm.save.execute();
    if (!mounted || result == null) return;
    if (result case Err(:final error) when error is ValidationException) return;
    final message = switch (result) {
      Ok() => 'Đã lưu hồ sơ.',
      Err(:final error) => error.message,
    };
    showAppMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              AppSpacing.md,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.selected,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(color: colors.selectedBorder),
                ),
                child: Text(
                  'Không bắt buộc. Bạn vẫn đặt món được khi chưa điền.',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _Field(
                id: 's16.name',
                label: 'Họ tên',
                child: TextField(
                  controller: _name,
                  onChanged: vm.setName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(hintText: 'Nhập họ tên', errorText: vm.nameError),
                ),
              ),
              _Field(
                id: 's16.studentId',
                label: 'MSSV',
                child: TextField(
                  controller: _studentId,
                  onChanged: vm.setStudentId,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(hintText: 'Nhập mã số sinh viên', errorText: vm.studentIdError),
                ),
              ),
              _Field(
                id: 's16.phone',
                label: 'Số điện thoại',
                child: TextField(
                  controller: _phone,
                  onChanged: vm.setPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: 'Nhập số điện thoại', errorText: vm.phoneError),
                ),
              ),
              _Field(
                id: 's16.defaultKiosk',
                label: 'Nơi nhận mặc định',
                child: DropdownButtonFormField<String?>(
                  initialValue: vm.defaultKioskId,
                  isExpanded: true,
                  decoration: const InputDecoration(helperText: 'App chọn sẵn kiosk này mỗi khi bạn đăng nhập.'),
                  items: [
                    const DropdownMenuItem<String?>(child: Text('Chưa chọn')),
                    for (final kiosk in vm.kiosks) DropdownMenuItem<String?>(value: kiosk.id, child: Text(kiosk.name)),
                  ],
                  onChanged: vm.setDefaultKiosk,
                ),
              ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: vm.save,
          builder: (context, _) => BottomActionButton(
            label: 'Lưu hồ sơ',
            testId: 's16.save',
            loading: vm.save.running,
            onPressed: vm.hasChanges ? _save : null,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.id, required this.label, required this.child});

  final String id;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xxs),
          TestId(
            id,
            child: Semantics(label: label, child: child),
          ),
        ],
      ),
    );
  }
}
