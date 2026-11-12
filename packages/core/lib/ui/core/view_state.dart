/// Explicit state model for every screen that loads data (handout section 5).
/// The ViewModel owns a [ViewState]; the screen only renders from that state.
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

  /// The data if present, otherwise `null`.
  T? get dataOrNull => switch (this) {
    ViewData<T>(:final data) => data,
    _ => null,
  };

  /// Turns a list into an empty or data state.
  static ViewState<List<E>> fromList<E>(List<E> items, {String? emptyMessage}) =>
      items.isEmpty ? ViewEmpty<List<E>>(emptyMessage) : ViewData<List<E>>(items);
}
