import 'package:flutter/widgets.dart';
import 'data_store.dart';

export 'data_store.dart';

/// DataStore 注入器 — 基于 InheritedNotifier，无需 Provider 依赖
///
/// 在 app 根部包裹，子 widget 通过 `DataStoreProvider.of(context)` 获取 store，
/// store 调用 notifyListeners() 时所有依赖 widget 自动重建。
class DataStoreProvider extends InheritedNotifier<DataStore> {
  const DataStoreProvider({
    super.key,
    required DataStore store,
    required super.child,
  }) : super(notifier: store);

  static DataStore of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<DataStoreProvider>();
    assert(w != null, 'DataStoreProvider not found in ancestor tree');
    return w!.notifier!;
  }
}
