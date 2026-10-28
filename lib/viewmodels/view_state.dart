/// Mô hình trạng thái rõ ràng cho mọi màn tải dữ liệu (handout mục 5).
/// ViewModel sở hữu một [ViewState]; màn hình chỉ vẽ theo trạng thái.
sealed class ViewState<T> {
  const ViewState();
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

final class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty([this.message]);

  final String? message;
}

final class ViewError<T> extends ViewState<T> {
  const ViewError(this.message);

  final String message;
}

final class ViewData<T> extends ViewState<T> {
  const ViewData(this.data);

  final T data;
}

extension ViewStateX<T> on ViewState<T> {
  bool get isLoading => this is ViewLoading<T>;

  /// Dữ liệu nếu có, ngược lại `null`.
  T? get dataOrNull => switch (this) {
        ViewData<T>(:final data) => data,
        _ => null,
      };

  /// Đổi một danh sách thành trạng thái rỗng hoặc có dữ liệu.
  static ViewState<List<E>> fromList<E>(List<E> items, {String? emptyMessage}) =>
      items.isEmpty ? ViewEmpty<List<E>>(emptyMessage) : ViewData<List<E>>(items);
}
