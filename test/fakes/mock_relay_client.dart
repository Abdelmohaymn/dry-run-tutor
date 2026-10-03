import 'package:dry_run/core/network/relay_client.dart';
import 'package:mocktail/mocktail.dart';

/// A mocktail mock of the whole relay client — `chat`/`trialChat` return
/// `Stream<SseFrame>`, so tests script them with `thenAnswer((_) => Stream.fromIterable([...]))`
/// or `thenAnswer((_) => Stream.error(...))`.
class MockRelayClient extends Mock implements RelayClient {}
