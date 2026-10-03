// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trusted_instant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrustedInstant {

 DateTime get utc; TrustedTimeSourceKind get source; bool get isStale;
/// Create a copy of TrustedInstant
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrustedInstantCopyWith<TrustedInstant> get copyWith => _$TrustedInstantCopyWithImpl<TrustedInstant>(this as TrustedInstant, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrustedInstant&&(identical(other.utc, utc) || other.utc == utc)&&(identical(other.source, source) || other.source == source)&&(identical(other.isStale, isStale) || other.isStale == isStale));
}


@override
int get hashCode => Object.hash(runtimeType,utc,source,isStale);

@override
String toString() {
  return 'TrustedInstant(utc: $utc, source: $source, isStale: $isStale)';
}


}

/// @nodoc
abstract mixin class $TrustedInstantCopyWith<$Res>  {
  factory $TrustedInstantCopyWith(TrustedInstant value, $Res Function(TrustedInstant) _then) = _$TrustedInstantCopyWithImpl;
@useResult
$Res call({
 DateTime utc, TrustedTimeSourceKind source, bool isStale
});




}
/// @nodoc
class _$TrustedInstantCopyWithImpl<$Res>
    implements $TrustedInstantCopyWith<$Res> {
  _$TrustedInstantCopyWithImpl(this._self, this._then);

  final TrustedInstant _self;
  final $Res Function(TrustedInstant) _then;

/// Create a copy of TrustedInstant
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? utc = null,Object? source = null,Object? isStale = null,}) {
  return _then(_self.copyWith(
utc: null == utc ? _self.utc : utc // ignore: cast_nullable_to_non_nullable
as DateTime,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TrustedTimeSourceKind,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TrustedInstant].
extension TrustedInstantPatterns on TrustedInstant {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrustedInstant value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrustedInstant() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrustedInstant value)  $default,){
final _that = this;
switch (_that) {
case _TrustedInstant():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrustedInstant value)?  $default,){
final _that = this;
switch (_that) {
case _TrustedInstant() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime utc,  TrustedTimeSourceKind source,  bool isStale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrustedInstant() when $default != null:
return $default(_that.utc,_that.source,_that.isStale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime utc,  TrustedTimeSourceKind source,  bool isStale)  $default,) {final _that = this;
switch (_that) {
case _TrustedInstant():
return $default(_that.utc,_that.source,_that.isStale);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime utc,  TrustedTimeSourceKind source,  bool isStale)?  $default,) {final _that = this;
switch (_that) {
case _TrustedInstant() when $default != null:
return $default(_that.utc,_that.source,_that.isStale);case _:
  return null;

}
}

}

/// @nodoc


class _TrustedInstant implements TrustedInstant {
  const _TrustedInstant({required this.utc, required this.source, required this.isStale});
  

@override final  DateTime utc;
@override final  TrustedTimeSourceKind source;
@override final  bool isStale;

/// Create a copy of TrustedInstant
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrustedInstantCopyWith<_TrustedInstant> get copyWith => __$TrustedInstantCopyWithImpl<_TrustedInstant>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrustedInstant&&(identical(other.utc, utc) || other.utc == utc)&&(identical(other.source, source) || other.source == source)&&(identical(other.isStale, isStale) || other.isStale == isStale));
}


@override
int get hashCode => Object.hash(runtimeType,utc,source,isStale);

@override
String toString() {
  return 'TrustedInstant(utc: $utc, source: $source, isStale: $isStale)';
}


}

/// @nodoc
abstract mixin class _$TrustedInstantCopyWith<$Res> implements $TrustedInstantCopyWith<$Res> {
  factory _$TrustedInstantCopyWith(_TrustedInstant value, $Res Function(_TrustedInstant) _then) = __$TrustedInstantCopyWithImpl;
@override @useResult
$Res call({
 DateTime utc, TrustedTimeSourceKind source, bool isStale
});




}
/// @nodoc
class __$TrustedInstantCopyWithImpl<$Res>
    implements _$TrustedInstantCopyWith<$Res> {
  __$TrustedInstantCopyWithImpl(this._self, this._then);

  final _TrustedInstant _self;
  final $Res Function(_TrustedInstant) _then;

/// Create a copy of TrustedInstant
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? utc = null,Object? source = null,Object? isStale = null,}) {
  return _then(_TrustedInstant(
utc: null == utc ? _self.utc : utc // ignore: cast_nullable_to_non_nullable
as DateTime,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TrustedTimeSourceKind,isStale: null == isStale ? _self.isStale : isStale // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
