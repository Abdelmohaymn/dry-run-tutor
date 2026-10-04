// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'relay_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RelayError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelayError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError()';
}


}

/// @nodoc
class $RelayErrorCopyWith<$Res>  {
$RelayErrorCopyWith(RelayError _, $Res Function(RelayError) __);
}


/// Adds pattern-matching-related methods to [RelayError].
extension RelayErrorPatterns on RelayError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RateLimited value)?  rateLimited,TResult Function( InvalidKey value)?  invalidKey,TResult Function( QuotaExhausted value)?  quotaExhausted,TResult Function( UnclearRetry value)?  unclearRetry,TResult Function( TurnCapReached value)?  turnCapReached,TResult Function( TrialConsumed value)?  trialConsumed,TResult Function( SessionAlreadyJudged value)?  sessionAlreadyJudged,TResult Function( EmptyTurn value)?  emptyTurn,TResult Function( TrialUnavailable value)?  trialUnavailable,TResult Function( TrialIpLimited value)?  trialIpLimited,TResult Function( ProblemKilled value)?  problemKilled,TResult Function( BadRequest value)?  badRequest,TResult Function( TransportFailure value)?  transport,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RateLimited() when rateLimited != null:
return rateLimited(_that);case InvalidKey() when invalidKey != null:
return invalidKey(_that);case QuotaExhausted() when quotaExhausted != null:
return quotaExhausted(_that);case UnclearRetry() when unclearRetry != null:
return unclearRetry(_that);case TurnCapReached() when turnCapReached != null:
return turnCapReached(_that);case TrialConsumed() when trialConsumed != null:
return trialConsumed(_that);case SessionAlreadyJudged() when sessionAlreadyJudged != null:
return sessionAlreadyJudged(_that);case EmptyTurn() when emptyTurn != null:
return emptyTurn(_that);case TrialUnavailable() when trialUnavailable != null:
return trialUnavailable(_that);case TrialIpLimited() when trialIpLimited != null:
return trialIpLimited(_that);case ProblemKilled() when problemKilled != null:
return problemKilled(_that);case BadRequest() when badRequest != null:
return badRequest(_that);case TransportFailure() when transport != null:
return transport(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RateLimited value)  rateLimited,required TResult Function( InvalidKey value)  invalidKey,required TResult Function( QuotaExhausted value)  quotaExhausted,required TResult Function( UnclearRetry value)  unclearRetry,required TResult Function( TurnCapReached value)  turnCapReached,required TResult Function( TrialConsumed value)  trialConsumed,required TResult Function( SessionAlreadyJudged value)  sessionAlreadyJudged,required TResult Function( EmptyTurn value)  emptyTurn,required TResult Function( TrialUnavailable value)  trialUnavailable,required TResult Function( TrialIpLimited value)  trialIpLimited,required TResult Function( ProblemKilled value)  problemKilled,required TResult Function( BadRequest value)  badRequest,required TResult Function( TransportFailure value)  transport,}){
final _that = this;
switch (_that) {
case RateLimited():
return rateLimited(_that);case InvalidKey():
return invalidKey(_that);case QuotaExhausted():
return quotaExhausted(_that);case UnclearRetry():
return unclearRetry(_that);case TurnCapReached():
return turnCapReached(_that);case TrialConsumed():
return trialConsumed(_that);case SessionAlreadyJudged():
return sessionAlreadyJudged(_that);case EmptyTurn():
return emptyTurn(_that);case TrialUnavailable():
return trialUnavailable(_that);case TrialIpLimited():
return trialIpLimited(_that);case ProblemKilled():
return problemKilled(_that);case BadRequest():
return badRequest(_that);case TransportFailure():
return transport(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RateLimited value)?  rateLimited,TResult? Function( InvalidKey value)?  invalidKey,TResult? Function( QuotaExhausted value)?  quotaExhausted,TResult? Function( UnclearRetry value)?  unclearRetry,TResult? Function( TurnCapReached value)?  turnCapReached,TResult? Function( TrialConsumed value)?  trialConsumed,TResult? Function( SessionAlreadyJudged value)?  sessionAlreadyJudged,TResult? Function( EmptyTurn value)?  emptyTurn,TResult? Function( TrialUnavailable value)?  trialUnavailable,TResult? Function( TrialIpLimited value)?  trialIpLimited,TResult? Function( ProblemKilled value)?  problemKilled,TResult? Function( BadRequest value)?  badRequest,TResult? Function( TransportFailure value)?  transport,}){
final _that = this;
switch (_that) {
case RateLimited() when rateLimited != null:
return rateLimited(_that);case InvalidKey() when invalidKey != null:
return invalidKey(_that);case QuotaExhausted() when quotaExhausted != null:
return quotaExhausted(_that);case UnclearRetry() when unclearRetry != null:
return unclearRetry(_that);case TurnCapReached() when turnCapReached != null:
return turnCapReached(_that);case TrialConsumed() when trialConsumed != null:
return trialConsumed(_that);case SessionAlreadyJudged() when sessionAlreadyJudged != null:
return sessionAlreadyJudged(_that);case EmptyTurn() when emptyTurn != null:
return emptyTurn(_that);case TrialUnavailable() when trialUnavailable != null:
return trialUnavailable(_that);case TrialIpLimited() when trialIpLimited != null:
return trialIpLimited(_that);case ProblemKilled() when problemKilled != null:
return problemKilled(_that);case BadRequest() when badRequest != null:
return badRequest(_that);case TransportFailure() when transport != null:
return transport(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Duration retryAfter)?  rateLimited,TResult Function()?  invalidKey,TResult Function()?  quotaExhausted,TResult Function()?  unclearRetry,TResult Function()?  turnCapReached,TResult Function()?  trialConsumed,TResult Function( JudgedContext ctx)?  sessionAlreadyJudged,TResult Function()?  emptyTurn,TResult Function()?  trialUnavailable,TResult Function()?  trialIpLimited,TResult Function( String problemId)?  problemKilled,TResult Function()?  badRequest,TResult Function()?  transport,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RateLimited() when rateLimited != null:
return rateLimited(_that.retryAfter);case InvalidKey() when invalidKey != null:
return invalidKey();case QuotaExhausted() when quotaExhausted != null:
return quotaExhausted();case UnclearRetry() when unclearRetry != null:
return unclearRetry();case TurnCapReached() when turnCapReached != null:
return turnCapReached();case TrialConsumed() when trialConsumed != null:
return trialConsumed();case SessionAlreadyJudged() when sessionAlreadyJudged != null:
return sessionAlreadyJudged(_that.ctx);case EmptyTurn() when emptyTurn != null:
return emptyTurn();case TrialUnavailable() when trialUnavailable != null:
return trialUnavailable();case TrialIpLimited() when trialIpLimited != null:
return trialIpLimited();case ProblemKilled() when problemKilled != null:
return problemKilled(_that.problemId);case BadRequest() when badRequest != null:
return badRequest();case TransportFailure() when transport != null:
return transport();case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Duration retryAfter)  rateLimited,required TResult Function()  invalidKey,required TResult Function()  quotaExhausted,required TResult Function()  unclearRetry,required TResult Function()  turnCapReached,required TResult Function()  trialConsumed,required TResult Function( JudgedContext ctx)  sessionAlreadyJudged,required TResult Function()  emptyTurn,required TResult Function()  trialUnavailable,required TResult Function()  trialIpLimited,required TResult Function( String problemId)  problemKilled,required TResult Function()  badRequest,required TResult Function()  transport,}) {final _that = this;
switch (_that) {
case RateLimited():
return rateLimited(_that.retryAfter);case InvalidKey():
return invalidKey();case QuotaExhausted():
return quotaExhausted();case UnclearRetry():
return unclearRetry();case TurnCapReached():
return turnCapReached();case TrialConsumed():
return trialConsumed();case SessionAlreadyJudged():
return sessionAlreadyJudged(_that.ctx);case EmptyTurn():
return emptyTurn();case TrialUnavailable():
return trialUnavailable();case TrialIpLimited():
return trialIpLimited();case ProblemKilled():
return problemKilled(_that.problemId);case BadRequest():
return badRequest();case TransportFailure():
return transport();}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Duration retryAfter)?  rateLimited,TResult? Function()?  invalidKey,TResult? Function()?  quotaExhausted,TResult? Function()?  unclearRetry,TResult? Function()?  turnCapReached,TResult? Function()?  trialConsumed,TResult? Function( JudgedContext ctx)?  sessionAlreadyJudged,TResult? Function()?  emptyTurn,TResult? Function()?  trialUnavailable,TResult? Function()?  trialIpLimited,TResult? Function( String problemId)?  problemKilled,TResult? Function()?  badRequest,TResult? Function()?  transport,}) {final _that = this;
switch (_that) {
case RateLimited() when rateLimited != null:
return rateLimited(_that.retryAfter);case InvalidKey() when invalidKey != null:
return invalidKey();case QuotaExhausted() when quotaExhausted != null:
return quotaExhausted();case UnclearRetry() when unclearRetry != null:
return unclearRetry();case TurnCapReached() when turnCapReached != null:
return turnCapReached();case TrialConsumed() when trialConsumed != null:
return trialConsumed();case SessionAlreadyJudged() when sessionAlreadyJudged != null:
return sessionAlreadyJudged(_that.ctx);case EmptyTurn() when emptyTurn != null:
return emptyTurn();case TrialUnavailable() when trialUnavailable != null:
return trialUnavailable();case TrialIpLimited() when trialIpLimited != null:
return trialIpLimited();case ProblemKilled() when problemKilled != null:
return problemKilled(_that.problemId);case BadRequest() when badRequest != null:
return badRequest();case TransportFailure() when transport != null:
return transport();case _:
  return null;

}
}

}

/// @nodoc


class RateLimited implements RelayError {
  const RateLimited({required this.retryAfter});
  

 final  Duration retryAfter;

/// Create a copy of RelayError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RateLimitedCopyWith<RateLimited> get copyWith => _$RateLimitedCopyWithImpl<RateLimited>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RateLimited&&(identical(other.retryAfter, retryAfter) || other.retryAfter == retryAfter));
}


@override
int get hashCode => Object.hash(runtimeType,retryAfter);

@override
String toString() {
  return 'RelayError.rateLimited(retryAfter: $retryAfter)';
}


}

/// @nodoc
abstract mixin class $RateLimitedCopyWith<$Res> implements $RelayErrorCopyWith<$Res> {
  factory $RateLimitedCopyWith(RateLimited value, $Res Function(RateLimited) _then) = _$RateLimitedCopyWithImpl;
@useResult
$Res call({
 Duration retryAfter
});




}
/// @nodoc
class _$RateLimitedCopyWithImpl<$Res>
    implements $RateLimitedCopyWith<$Res> {
  _$RateLimitedCopyWithImpl(this._self, this._then);

  final RateLimited _self;
  final $Res Function(RateLimited) _then;

/// Create a copy of RelayError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? retryAfter = null,}) {
  return _then(RateLimited(
retryAfter: null == retryAfter ? _self.retryAfter : retryAfter // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

/// @nodoc


class InvalidKey implements RelayError {
  const InvalidKey();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvalidKey);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.invalidKey()';
}


}




/// @nodoc


class QuotaExhausted implements RelayError {
  const QuotaExhausted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuotaExhausted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.quotaExhausted()';
}


}




/// @nodoc


class UnclearRetry implements RelayError {
  const UnclearRetry();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnclearRetry);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.unclearRetry()';
}


}




/// @nodoc


class TurnCapReached implements RelayError {
  const TurnCapReached();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TurnCapReached);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.turnCapReached()';
}


}




/// @nodoc


class TrialConsumed implements RelayError {
  const TrialConsumed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrialConsumed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.trialConsumed()';
}


}




/// @nodoc


class SessionAlreadyJudged implements RelayError {
  const SessionAlreadyJudged({required this.ctx});
  

 final  JudgedContext ctx;

/// Create a copy of RelayError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionAlreadyJudgedCopyWith<SessionAlreadyJudged> get copyWith => _$SessionAlreadyJudgedCopyWithImpl<SessionAlreadyJudged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionAlreadyJudged&&(identical(other.ctx, ctx) || other.ctx == ctx));
}


@override
int get hashCode => Object.hash(runtimeType,ctx);

@override
String toString() {
  return 'RelayError.sessionAlreadyJudged(ctx: $ctx)';
}


}

/// @nodoc
abstract mixin class $SessionAlreadyJudgedCopyWith<$Res> implements $RelayErrorCopyWith<$Res> {
  factory $SessionAlreadyJudgedCopyWith(SessionAlreadyJudged value, $Res Function(SessionAlreadyJudged) _then) = _$SessionAlreadyJudgedCopyWithImpl;
@useResult
$Res call({
 JudgedContext ctx
});




}
/// @nodoc
class _$SessionAlreadyJudgedCopyWithImpl<$Res>
    implements $SessionAlreadyJudgedCopyWith<$Res> {
  _$SessionAlreadyJudgedCopyWithImpl(this._self, this._then);

  final SessionAlreadyJudged _self;
  final $Res Function(SessionAlreadyJudged) _then;

/// Create a copy of RelayError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? ctx = null,}) {
  return _then(SessionAlreadyJudged(
ctx: null == ctx ? _self.ctx : ctx // ignore: cast_nullable_to_non_nullable
as JudgedContext,
  ));
}


}

/// @nodoc


class EmptyTurn implements RelayError {
  const EmptyTurn();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmptyTurn);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.emptyTurn()';
}


}




/// @nodoc


class TrialUnavailable implements RelayError {
  const TrialUnavailable();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrialUnavailable);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.trialUnavailable()';
}


}




/// @nodoc


class TrialIpLimited implements RelayError {
  const TrialIpLimited();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrialIpLimited);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.trialIpLimited()';
}


}




/// @nodoc


class ProblemKilled implements RelayError {
  const ProblemKilled({required this.problemId});
  

 final  String problemId;

/// Create a copy of RelayError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProblemKilledCopyWith<ProblemKilled> get copyWith => _$ProblemKilledCopyWithImpl<ProblemKilled>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProblemKilled&&(identical(other.problemId, problemId) || other.problemId == problemId));
}


@override
int get hashCode => Object.hash(runtimeType,problemId);

@override
String toString() {
  return 'RelayError.problemKilled(problemId: $problemId)';
}


}

/// @nodoc
abstract mixin class $ProblemKilledCopyWith<$Res> implements $RelayErrorCopyWith<$Res> {
  factory $ProblemKilledCopyWith(ProblemKilled value, $Res Function(ProblemKilled) _then) = _$ProblemKilledCopyWithImpl;
@useResult
$Res call({
 String problemId
});




}
/// @nodoc
class _$ProblemKilledCopyWithImpl<$Res>
    implements $ProblemKilledCopyWith<$Res> {
  _$ProblemKilledCopyWithImpl(this._self, this._then);

  final ProblemKilled _self;
  final $Res Function(ProblemKilled) _then;

/// Create a copy of RelayError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? problemId = null,}) {
  return _then(ProblemKilled(
problemId: null == problemId ? _self.problemId : problemId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class BadRequest implements RelayError {
  const BadRequest();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BadRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.badRequest()';
}


}




/// @nodoc


class TransportFailure implements RelayError {
  const TransportFailure();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportFailure);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'RelayError.transport()';
}


}




// dart format on
