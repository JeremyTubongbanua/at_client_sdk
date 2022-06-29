import 'package:at_client/src/manager/at_client_manager.dart';
import 'package:at_commons/at_commons.dart' show AtKey, AtValue;
import 'package:at_client/src/key_stream/collection/iterable_key_stream_impl.dart';
import 'package:at_client/src/key_stream/key_stream_mixin.dart';

abstract class IterableKeyStream<T> extends Stream<Iterable<T>> implements KeyStreamMixin<Iterable<T>> {
  /// Listens to notifications and exposes a Stream of the values stored as an Iterable.
  ///
  /// {@macro KeyStreamConvert}
  ///
  /// {@macro KeyStreamRegex}
  ///
  /// {@macro KeyStreamSharedBy}
  ///
  /// {@macro KeyStreamSharedBy}
  ///
  /// {@macro KeyStreamShouldGetKeys}
  ///
  /// {@macro KeyStreamGenerateRef}
  factory IterableKeyStream({
    required T? Function(AtKey key, AtValue value) convert,
    String? regex,
    String? sharedBy,
    String? sharedWith,
    bool shouldGetKeys = true,
    String Function(AtKey key, AtValue value)? generateRef,
    AtClientManager? atClientManager,
  }) {
    return IterableKeyStreamImpl<T>(
      regex: regex,
      convert: convert,
      generateRef: generateRef,
      sharedBy: sharedBy,
      sharedWith: sharedWith,
      shouldGetKeys: shouldGetKeys,
      atClientManager: atClientManager,
    );
  }
}
