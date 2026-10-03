// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'key_entry_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$KeyEntryState {

 String get providerId;
/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyEntryStateCopyWith<KeyEntryState> get copyWith => _$KeyEntryStateCopyWithImpl<KeyEntryState>(this as KeyEntryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyEntryState&&(identical(other.providerId, providerId) || other.providerId == providerId));
}


@override
int get hashCode => Object.hash(runtimeType,providerId);

@override
String toString() {
  return 'KeyEntryState(providerId: $providerId)';
}


}

/// @nodoc
abstract mixin class $KeyEntryStateCopyWith<$Res>  {
  factory $KeyEntryStateCopyWith(KeyEntryState value, $Res Function(KeyEntryState) _then) = _$KeyEntryStateCopyWithImpl;
@useResult
$Res call({
 String providerId
});




}
/// @nodoc
class _$KeyEntryStateCopyWithImpl<$Res>
    implements $KeyEntryStateCopyWith<$Res> {
  _$KeyEntryStateCopyWithImpl(this._self, this._then);

  final KeyEntryState _self;
  final $Res Function(KeyEntryState) _then;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerId = null,}) {
  return _then(_self.copyWith(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [KeyEntryState].
extension KeyEntryStatePatterns on KeyEntryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( KeyEntryEntering value)?  entering,TResult Function( KeyEntryProbing value)?  probing,TResult Function( KeyEntrySaved value)?  saved,TResult Function( KeyEntryRejected value)?  rejected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case KeyEntryEntering() when entering != null:
return entering(_that);case KeyEntryProbing() when probing != null:
return probing(_that);case KeyEntrySaved() when saved != null:
return saved(_that);case KeyEntryRejected() when rejected != null:
return rejected(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( KeyEntryEntering value)  entering,required TResult Function( KeyEntryProbing value)  probing,required TResult Function( KeyEntrySaved value)  saved,required TResult Function( KeyEntryRejected value)  rejected,}){
final _that = this;
switch (_that) {
case KeyEntryEntering():
return entering(_that);case KeyEntryProbing():
return probing(_that);case KeyEntrySaved():
return saved(_that);case KeyEntryRejected():
return rejected(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( KeyEntryEntering value)?  entering,TResult? Function( KeyEntryProbing value)?  probing,TResult? Function( KeyEntrySaved value)?  saved,TResult? Function( KeyEntryRejected value)?  rejected,}){
final _that = this;
switch (_that) {
case KeyEntryEntering() when entering != null:
return entering(_that);case KeyEntryProbing() when probing != null:
return probing(_that);case KeyEntrySaved() when saved != null:
return saved(_that);case KeyEntryRejected() when rejected != null:
return rejected(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<String> providers,  String providerId,  String value)?  entering,TResult Function( List<String> providers,  String providerId,  String value)?  probing,TResult Function( String providerId)?  saved,TResult Function( List<String> providers,  String providerId,  String value,  RelayError error)?  rejected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case KeyEntryEntering() when entering != null:
return entering(_that.providers,_that.providerId,_that.value);case KeyEntryProbing() when probing != null:
return probing(_that.providers,_that.providerId,_that.value);case KeyEntrySaved() when saved != null:
return saved(_that.providerId);case KeyEntryRejected() when rejected != null:
return rejected(_that.providers,_that.providerId,_that.value,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<String> providers,  String providerId,  String value)  entering,required TResult Function( List<String> providers,  String providerId,  String value)  probing,required TResult Function( String providerId)  saved,required TResult Function( List<String> providers,  String providerId,  String value,  RelayError error)  rejected,}) {final _that = this;
switch (_that) {
case KeyEntryEntering():
return entering(_that.providers,_that.providerId,_that.value);case KeyEntryProbing():
return probing(_that.providers,_that.providerId,_that.value);case KeyEntrySaved():
return saved(_that.providerId);case KeyEntryRejected():
return rejected(_that.providers,_that.providerId,_that.value,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<String> providers,  String providerId,  String value)?  entering,TResult? Function( List<String> providers,  String providerId,  String value)?  probing,TResult? Function( String providerId)?  saved,TResult? Function( List<String> providers,  String providerId,  String value,  RelayError error)?  rejected,}) {final _that = this;
switch (_that) {
case KeyEntryEntering() when entering != null:
return entering(_that.providers,_that.providerId,_that.value);case KeyEntryProbing() when probing != null:
return probing(_that.providers,_that.providerId,_that.value);case KeyEntrySaved() when saved != null:
return saved(_that.providerId);case KeyEntryRejected() when rejected != null:
return rejected(_that.providers,_that.providerId,_that.value,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class KeyEntryEntering implements KeyEntryState {
  const KeyEntryEntering({required final  List<String> providers, required this.providerId, required this.value}): _providers = providers;
  

 final  List<String> _providers;
 List<String> get providers {
  if (_providers is EqualUnmodifiableListView) return _providers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_providers);
}

@override final  String providerId;
 final  String value;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyEntryEnteringCopyWith<KeyEntryEntering> get copyWith => _$KeyEntryEnteringCopyWithImpl<KeyEntryEntering>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyEntryEntering&&const DeepCollectionEquality().equals(other._providers, _providers)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_providers),providerId,value);

@override
String toString() {
  return 'KeyEntryState.entering(providers: $providers, providerId: $providerId, value: $value)';
}


}

/// @nodoc
abstract mixin class $KeyEntryEnteringCopyWith<$Res> implements $KeyEntryStateCopyWith<$Res> {
  factory $KeyEntryEnteringCopyWith(KeyEntryEntering value, $Res Function(KeyEntryEntering) _then) = _$KeyEntryEnteringCopyWithImpl;
@override @useResult
$Res call({
 List<String> providers, String providerId, String value
});




}
/// @nodoc
class _$KeyEntryEnteringCopyWithImpl<$Res>
    implements $KeyEntryEnteringCopyWith<$Res> {
  _$KeyEntryEnteringCopyWithImpl(this._self, this._then);

  final KeyEntryEntering _self;
  final $Res Function(KeyEntryEntering) _then;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providers = null,Object? providerId = null,Object? value = null,}) {
  return _then(KeyEntryEntering(
providers: null == providers ? _self._providers : providers // ignore: cast_nullable_to_non_nullable
as List<String>,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class KeyEntryProbing implements KeyEntryState {
  const KeyEntryProbing({required final  List<String> providers, required this.providerId, required this.value}): _providers = providers;
  

 final  List<String> _providers;
 List<String> get providers {
  if (_providers is EqualUnmodifiableListView) return _providers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_providers);
}

@override final  String providerId;
 final  String value;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyEntryProbingCopyWith<KeyEntryProbing> get copyWith => _$KeyEntryProbingCopyWithImpl<KeyEntryProbing>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyEntryProbing&&const DeepCollectionEquality().equals(other._providers, _providers)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_providers),providerId,value);

@override
String toString() {
  return 'KeyEntryState.probing(providers: $providers, providerId: $providerId, value: $value)';
}


}

/// @nodoc
abstract mixin class $KeyEntryProbingCopyWith<$Res> implements $KeyEntryStateCopyWith<$Res> {
  factory $KeyEntryProbingCopyWith(KeyEntryProbing value, $Res Function(KeyEntryProbing) _then) = _$KeyEntryProbingCopyWithImpl;
@override @useResult
$Res call({
 List<String> providers, String providerId, String value
});




}
/// @nodoc
class _$KeyEntryProbingCopyWithImpl<$Res>
    implements $KeyEntryProbingCopyWith<$Res> {
  _$KeyEntryProbingCopyWithImpl(this._self, this._then);

  final KeyEntryProbing _self;
  final $Res Function(KeyEntryProbing) _then;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providers = null,Object? providerId = null,Object? value = null,}) {
  return _then(KeyEntryProbing(
providers: null == providers ? _self._providers : providers // ignore: cast_nullable_to_non_nullable
as List<String>,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class KeyEntrySaved implements KeyEntryState {
  const KeyEntrySaved({required this.providerId});
  

@override final  String providerId;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyEntrySavedCopyWith<KeyEntrySaved> get copyWith => _$KeyEntrySavedCopyWithImpl<KeyEntrySaved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyEntrySaved&&(identical(other.providerId, providerId) || other.providerId == providerId));
}


@override
int get hashCode => Object.hash(runtimeType,providerId);

@override
String toString() {
  return 'KeyEntryState.saved(providerId: $providerId)';
}


}

/// @nodoc
abstract mixin class $KeyEntrySavedCopyWith<$Res> implements $KeyEntryStateCopyWith<$Res> {
  factory $KeyEntrySavedCopyWith(KeyEntrySaved value, $Res Function(KeyEntrySaved) _then) = _$KeyEntrySavedCopyWithImpl;
@override @useResult
$Res call({
 String providerId
});




}
/// @nodoc
class _$KeyEntrySavedCopyWithImpl<$Res>
    implements $KeyEntrySavedCopyWith<$Res> {
  _$KeyEntrySavedCopyWithImpl(this._self, this._then);

  final KeyEntrySaved _self;
  final $Res Function(KeyEntrySaved) _then;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerId = null,}) {
  return _then(KeyEntrySaved(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class KeyEntryRejected implements KeyEntryState {
  const KeyEntryRejected({required final  List<String> providers, required this.providerId, required this.value, required this.error}): _providers = providers;
  

 final  List<String> _providers;
 List<String> get providers {
  if (_providers is EqualUnmodifiableListView) return _providers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_providers);
}

@override final  String providerId;
 final  String value;
 final  RelayError error;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KeyEntryRejectedCopyWith<KeyEntryRejected> get copyWith => _$KeyEntryRejectedCopyWithImpl<KeyEntryRejected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KeyEntryRejected&&const DeepCollectionEquality().equals(other._providers, _providers)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.value, value) || other.value == value)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_providers),providerId,value,error);

@override
String toString() {
  return 'KeyEntryState.rejected(providers: $providers, providerId: $providerId, value: $value, error: $error)';
}


}

/// @nodoc
abstract mixin class $KeyEntryRejectedCopyWith<$Res> implements $KeyEntryStateCopyWith<$Res> {
  factory $KeyEntryRejectedCopyWith(KeyEntryRejected value, $Res Function(KeyEntryRejected) _then) = _$KeyEntryRejectedCopyWithImpl;
@override @useResult
$Res call({
 List<String> providers, String providerId, String value, RelayError error
});


$RelayErrorCopyWith<$Res> get error;

}
/// @nodoc
class _$KeyEntryRejectedCopyWithImpl<$Res>
    implements $KeyEntryRejectedCopyWith<$Res> {
  _$KeyEntryRejectedCopyWithImpl(this._self, this._then);

  final KeyEntryRejected _self;
  final $Res Function(KeyEntryRejected) _then;

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providers = null,Object? providerId = null,Object? value = null,Object? error = null,}) {
  return _then(KeyEntryRejected(
providers: null == providers ? _self._providers : providers // ignore: cast_nullable_to_non_nullable
as List<String>,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as RelayError,
  ));
}

/// Create a copy of KeyEntryState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RelayErrorCopyWith<$Res> get error {
  
  return $RelayErrorCopyWith<$Res>(_self.error, (value) {
    return _then(_self.copyWith(error: value));
  });
}
}

// dart format on
