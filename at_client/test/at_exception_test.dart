import 'package:at_client/at_client.dart';
import 'package:at_client/src/client/verb_builder_manager.dart';
import 'package:at_client/src/decryption_service/shared_key_decryption.dart';
import 'package:at_client/src/transformer/request_transformer/get_request_transformer.dart';
import 'package:at_client/src/util/network_util.dart';
import 'package:at_commons/at_builders.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_lookup/at_lookup.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockRemoteSecondary extends Mock implements RemoteSecondary {
  @override
  Future<String> executeVerb(VerbBuilder builder, {bool? sync = false}) {
    if (builder is LookupVerbBuilder) {
      throw AtTimeoutException('connection timeout');
    }
    return Future.value('123');
  }
}

class MockAtLookup extends Mock implements AtLookupImpl {}

class MockLocalSecondary extends Mock implements LocalSecondary {}

class MockAtClientImpl extends Mock implements AtClientImpl {
  @override
  String? get currentAtSign => '@xyz';
}

class MockGetRequestTransformer extends Mock implements GetRequestTransformer {}

class MockSecondaryManager extends Mock implements SecondaryManager {}

class MockNetworkConnectivityChecker extends Mock
    implements NetworkConnectivityChecker {}

void main() {
  AtLookupImpl mockAtLookup = MockAtLookup();
  AtClientImpl mockAtClientImpl = MockAtClientImpl();
  LocalSecondary mockLocalSecondary = MockLocalSecondary();
  RemoteSecondary mockRemoteSecondary = MockRemoteSecondary();
  NetworkConnectivityChecker mockNetworkConnectivityChecker =
      MockNetworkConnectivityChecker();

  var lookupVerbBuilder = LookupVerbBuilder()
    ..atKey = 'phone.wavi'
    ..sharedBy = '@alice';

  var llookupVerbBuilder = LLookupVerbBuilder()
    ..atKey = 'shared_key.sitaram'
    ..sharedBy = '@murali';

  var lookupKey = AtKey()
    ..key = 'phone'
    ..sharedBy = '@alice';

  setUp(() {
    reset(mockAtLookup);
    when(() => mockAtLookup.executeVerb(lookupVerbBuilder)).thenAnswer(
        (_) async =>
            throw AtExceptionUtils.get('AT0015', 'Connection timeout'));
    when(() => mockAtClientImpl.getLocalSecondary())
        .thenAnswer((_) => mockLocalSecondary);
    when(() => mockAtClientImpl.getRemoteSecondary())
        .thenAnswer((_) => mockRemoteSecondary);
    when(() => mockAtClientImpl.getCurrentAtSign()).thenAnswer((_) => '@xyz');
    when(() => mockLocalSecondary.getEncryptionPublicKey('@xyz'))
        .thenAnswer((_) => Future.value('dummy_encryption_public_key'));
    when(() => mockLocalSecondary.executeVerb(llookupVerbBuilder))
        .thenAnswer((_) async => 'dummy_shared_key');
    when(() => mockNetworkConnectivityChecker.checkConnectivity())
        .thenAnswer((_) async => Future.value(true));
  });
  // The AtLookup verb throws exception is stacked by the executeVerb in remote secondary
  test('Test to verify exception gets stacked in remote secondary executeVerb',
      () async {
    RemoteSecondary remoteSecondary =
        RemoteSecondary('@alice', AtClientPreference());
    remoteSecondary.atLookUp = mockAtLookup;
    try {
      await remoteSecondary.executeVerb(lookupVerbBuilder);
    } on AtException catch (e) {
      expect(e.getTraceMessage(),
          'Failed to fetch data caused by\nConnection timeout');
    }
  });

  group('A group of tests to verify exceptions in decryption service', () {
    test(
        'A test to verify exception is thrown when public key checksum changes',
        () {
      var atKey = (AtKey.shared('phone', namespace: 'wavi', sharedBy: '@murali')
            ..sharedWith('@sitaram'))
          .build();
      atKey.metadata = Metadata()..pubKeyCS = '1234';
      var sharedKeyDecryption = SharedKeyDecryption(atClient: mockAtClientImpl);
      expect(() => sharedKeyDecryption.decrypt(atKey, '123'),
          throwsA(predicate((dynamic e) => e is AtPublicKeyChangeException)));
    });

    test('A test to verify exception is thrown when shared key is not found',
        () {
      var atKey = (AtKey.shared('phone', namespace: 'wavi', sharedBy: '@murali')
            ..sharedWith('@sitaram'))
          .build();
      atKey.metadata = Metadata()
        ..pubKeyCS = 'd4f6d9483907286a0563b9fdeb01aa61';
      var sharedKeyDecryption = SharedKeyDecryption(atClient: mockAtClientImpl);
      expect(
          () => sharedKeyDecryption.decrypt(atKey, '123'),
          throwsA(predicate((dynamic e) =>
              e is KeyNotFoundException &&
              e.message == 'shared encryption key not found')));
    });

    test(
        'A test to verify AtTimeout Exception is chained and thrown as AtClientException',
        () async {
      AtClientImpl atClientImpl =
          await AtClientImpl.create('@sitaram', 'wavi', AtClientPreference())
              as AtClientImpl;
      atClientImpl.secondaryManager.atClient = mockAtClientImpl;
      expect(
          () => atClientImpl.get(lookupKey),
          throwsA(predicate((dynamic e) =>
              e is AtClientException &&
              e.getTraceMessage() ==
                  'Failed to fetch data caused by\nconnection timeout')));
    });

    test('A test to verify AtPublicKeyChangeException', () async {
      AtClientImpl atClientImpl =
          await AtClientImpl.create('@sitaram', 'wavi', AtClientPreference())
              as AtClientImpl;
      atClientImpl.secondaryManager.atClient = mockAtClientImpl;
      expect(
          () => atClientImpl.get(AtKey()
            ..key = 'phone.wavi'
            ..sharedBy = '@sitaram'
            ..sharedWith = '@murali'),
          throwsA(predicate((dynamic e) =>
              e is AtClientException &&
              e.getTraceMessage() ==
                  'Failed to fetch data caused by\nconnection timeout')));
    });
  });
}
