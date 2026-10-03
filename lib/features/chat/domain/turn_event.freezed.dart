// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'turn_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TurnEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TurnEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TurnEvent()';
}


}

/// @nodoc
class $TurnEventCopyWith<$Res>  {
$TurnEventCopyWith(TurnEvent _, $Res Function(TurnEvent) __);
}


/// Adds pattern-matching-related methods to [TurnEvent].
extension TurnEventPatterns on TurnEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TurnEventToken value)?  token,TResult Function( TurnEventMeta value)?  meta,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TurnEventToken() when token != null:
return token(_that);case TurnEventMeta() when meta != null:
return meta(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TurnEventToken value)  token,required TResult Function( TurnEventMeta value)  meta,}){
final _that = this;
switch (_that) {
case TurnEventToken():
return token(_that);case TurnEventMeta():
return meta(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TurnEventToken value)?  token,TResult? Function( TurnEventMeta value)?  meta,}){
final _that = this;
switch (_that) {
case TurnEventToken() when token != null:
return token(_that);case TurnEventMeta() when meta != null:
return meta(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  token,TResult Function( ServerCounters counters)?  meta,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TurnEventToken() when token != null:
return token(_that.text);case TurnEventMeta() when meta != null:
return meta(_that.counters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  token,required TResult Function( ServerCounters counters)  meta,}) {final _that = this;
switch (_that) {
case TurnEventToken():
return token(_that.text);case TurnEventMeta():
return meta(_that.counters);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  token,TResult? Function( ServerCounters counters)?  meta,}) {final _that = this;
switch (_that) {
case TurnEventToken() when token != null:
return token(_that.text);case TurnEventMeta() when meta != null:
return meta(_that.counters);case _:
  return null;

}
}

}

/// @nodoc


class TurnEventToken implements TurnEvent {
  const TurnEventToken(this.text);
  

 final  String text;

/// Create a copy of TurnEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TurnEventTokenCopyWith<TurnEventToken> get copyWith => _$TurnEventTokenCopyWithImpl<TurnEventToken>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TurnEventToken&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'TurnEvent.token(text: $text)';
}


}

/// @nodoc
abstract mixin class $TurnEventTokenCopyWith<$Res> implements $TurnEventCopyWith<$Res> {
  factory $TurnEventTokenCopyWith(TurnEventToken value, $Res Function(TurnEventToken) _then) = _$TurnEventTokenCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$TurnEventTokenCopyWithImpl<$Res>
    implements $TurnEventTokenCopyWith<$Res> {
  _$TurnEventTokenCopyWithImpl(this._self, this._then);

  final TurnEventToken _self;
  final $Res Function(TurnEventToken) _then;

/// Create a copy of TurnEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(TurnEventToken(
null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TurnEventMeta implements TurnEvent {
  const TurnEventMeta(this.counters);
  

 final  ServerCounters counters;

/// Create a copy of TurnEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TurnEventMetaCopyWith<TurnEventMeta> get copyWith => _$TurnEventMetaCopyWithImpl<TurnEventMeta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TurnEventMeta&&(identical(other.counters, counters) || other.counters == counters));
}


@override
int get hashCode => Object.hash(runtimeType,counters);

@override
String toString() {
  return 'TurnEvent.meta(counters: $counters)';
}


}

/// @nodoc
abstract mixin class $TurnEventMetaCopyWith<$Res> implements $TurnEventCopyWith<$Res> {
  factory $TurnEventMetaCopyWith(TurnEventMeta value, $Res Function(TurnEventMeta) _then) = _$TurnEventMetaCopyWithImpl;
@useResult
$Res call({
 ServerCounters counters
});




}
/// @nodoc
class _$TurnEventMetaCopyWithImpl<$Res>
    implements $TurnEventMetaCopyWith<$Res> {
  _$TurnEventMetaCopyWithImpl(this._self, this._then);

  final TurnEventMeta _self;
  final $Res Function(TurnEventMeta) _then;

/// Create a copy of TurnEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? counters = null,}) {
  return _then(TurnEventMeta(
null == counters ? _self.counters : counters // ignore: cast_nullable_to_non_nullable
as ServerCounters,
  ));
}


}

// dart format on
