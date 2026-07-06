// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bt_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BTDeviceInfo {

 String get name; String get addr; String get connectType;
/// Create a copy of BTDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BTDeviceInfoCopyWith<BTDeviceInfo> get copyWith => _$BTDeviceInfoCopyWithImpl<BTDeviceInfo>(this as BTDeviceInfo, _$identity);

  /// Serializes this BTDeviceInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BTDeviceInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.connectType, connectType) || other.connectType == connectType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,addr,connectType);

@override
String toString() {
  return 'BTDeviceInfo(name: $name, addr: $addr, connectType: $connectType)';
}


}

/// @nodoc
abstract mixin class $BTDeviceInfoCopyWith<$Res>  {
  factory $BTDeviceInfoCopyWith(BTDeviceInfo value, $Res Function(BTDeviceInfo) _then) = _$BTDeviceInfoCopyWithImpl;
@useResult
$Res call({
 String name, String addr, String connectType
});




}
/// @nodoc
class _$BTDeviceInfoCopyWithImpl<$Res>
    implements $BTDeviceInfoCopyWith<$Res> {
  _$BTDeviceInfoCopyWithImpl(this._self, this._then);

  final BTDeviceInfo _self;
  final $Res Function(BTDeviceInfo) _then;

/// Create a copy of BTDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? addr = null,Object? connectType = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,connectType: null == connectType ? _self.connectType : connectType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BTDeviceInfo].
extension BTDeviceInfoPatterns on BTDeviceInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BTDeviceInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BTDeviceInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BTDeviceInfo value)  $default,){
final _that = this;
switch (_that) {
case _BTDeviceInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BTDeviceInfo value)?  $default,){
final _that = this;
switch (_that) {
case _BTDeviceInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String addr,  String connectType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BTDeviceInfo() when $default != null:
return $default(_that.name,_that.addr,_that.connectType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String addr,  String connectType)  $default,) {final _that = this;
switch (_that) {
case _BTDeviceInfo():
return $default(_that.name,_that.addr,_that.connectType);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String addr,  String connectType)?  $default,) {final _that = this;
switch (_that) {
case _BTDeviceInfo() when $default != null:
return $default(_that.name,_that.addr,_that.connectType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BTDeviceInfo implements BTDeviceInfo {
  const _BTDeviceInfo({required this.name, required this.addr, required this.connectType});
  factory _BTDeviceInfo.fromJson(Map<String, dynamic> json) => _$BTDeviceInfoFromJson(json);

@override final  String name;
@override final  String addr;
@override final  String connectType;

/// Create a copy of BTDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BTDeviceInfoCopyWith<_BTDeviceInfo> get copyWith => __$BTDeviceInfoCopyWithImpl<_BTDeviceInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BTDeviceInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BTDeviceInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.connectType, connectType) || other.connectType == connectType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,addr,connectType);

@override
String toString() {
  return 'BTDeviceInfo(name: $name, addr: $addr, connectType: $connectType)';
}


}

/// @nodoc
abstract mixin class _$BTDeviceInfoCopyWith<$Res> implements $BTDeviceInfoCopyWith<$Res> {
  factory _$BTDeviceInfoCopyWith(_BTDeviceInfo value, $Res Function(_BTDeviceInfo) _then) = __$BTDeviceInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String addr, String connectType
});




}
/// @nodoc
class __$BTDeviceInfoCopyWithImpl<$Res>
    implements _$BTDeviceInfoCopyWith<$Res> {
  __$BTDeviceInfoCopyWithImpl(this._self, this._then);

  final _BTDeviceInfo _self;
  final $Res Function(_BTDeviceInfo) _then;

/// Create a copy of BTDeviceInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? addr = null,Object? connectType = null,}) {
  return _then(_BTDeviceInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,connectType: null == connectType ? _self.connectType : connectType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MiWearState {

 String get name; String get addr; String get connectType; String? get authkey; String? get codename; bool get disconnected;
/// Create a copy of MiWearState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiWearStateCopyWith<MiWearState> get copyWith => _$MiWearStateCopyWithImpl<MiWearState>(this as MiWearState, _$identity);

  /// Serializes this MiWearState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiWearState&&(identical(other.name, name) || other.name == name)&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.connectType, connectType) || other.connectType == connectType)&&(identical(other.authkey, authkey) || other.authkey == authkey)&&(identical(other.codename, codename) || other.codename == codename)&&(identical(other.disconnected, disconnected) || other.disconnected == disconnected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,addr,connectType,authkey,codename,disconnected);

@override
String toString() {
  return 'MiWearState(name: $name, addr: $addr, connectType: $connectType, authkey: $authkey, codename: $codename, disconnected: $disconnected)';
}


}

/// @nodoc
abstract mixin class $MiWearStateCopyWith<$Res>  {
  factory $MiWearStateCopyWith(MiWearState value, $Res Function(MiWearState) _then) = _$MiWearStateCopyWithImpl;
@useResult
$Res call({
 String name, String addr, String connectType, String? authkey, String? codename, bool disconnected
});




}
/// @nodoc
class _$MiWearStateCopyWithImpl<$Res>
    implements $MiWearStateCopyWith<$Res> {
  _$MiWearStateCopyWithImpl(this._self, this._then);

  final MiWearState _self;
  final $Res Function(MiWearState) _then;

/// Create a copy of MiWearState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? addr = null,Object? connectType = null,Object? authkey = freezed,Object? codename = freezed,Object? disconnected = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,connectType: null == connectType ? _self.connectType : connectType // ignore: cast_nullable_to_non_nullable
as String,authkey: freezed == authkey ? _self.authkey : authkey // ignore: cast_nullable_to_non_nullable
as String?,codename: freezed == codename ? _self.codename : codename // ignore: cast_nullable_to_non_nullable
as String?,disconnected: null == disconnected ? _self.disconnected : disconnected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MiWearState].
extension MiWearStatePatterns on MiWearState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiWearState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiWearState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiWearState value)  $default,){
final _that = this;
switch (_that) {
case _MiWearState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiWearState value)?  $default,){
final _that = this;
switch (_that) {
case _MiWearState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String addr,  String connectType,  String? authkey,  String? codename,  bool disconnected)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiWearState() when $default != null:
return $default(_that.name,_that.addr,_that.connectType,_that.authkey,_that.codename,_that.disconnected);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String addr,  String connectType,  String? authkey,  String? codename,  bool disconnected)  $default,) {final _that = this;
switch (_that) {
case _MiWearState():
return $default(_that.name,_that.addr,_that.connectType,_that.authkey,_that.codename,_that.disconnected);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String addr,  String connectType,  String? authkey,  String? codename,  bool disconnected)?  $default,) {final _that = this;
switch (_that) {
case _MiWearState() when $default != null:
return $default(_that.name,_that.addr,_that.connectType,_that.authkey,_that.codename,_that.disconnected);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MiWearState implements MiWearState {
  const _MiWearState({required this.name, required this.addr, required this.connectType, this.authkey, this.codename, this.disconnected = false});
  factory _MiWearState.fromJson(Map<String, dynamic> json) => _$MiWearStateFromJson(json);

@override final  String name;
@override final  String addr;
@override final  String connectType;
@override final  String? authkey;
@override final  String? codename;
@override@JsonKey() final  bool disconnected;

/// Create a copy of MiWearState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiWearStateCopyWith<_MiWearState> get copyWith => __$MiWearStateCopyWithImpl<_MiWearState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MiWearStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiWearState&&(identical(other.name, name) || other.name == name)&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.connectType, connectType) || other.connectType == connectType)&&(identical(other.authkey, authkey) || other.authkey == authkey)&&(identical(other.codename, codename) || other.codename == codename)&&(identical(other.disconnected, disconnected) || other.disconnected == disconnected));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,addr,connectType,authkey,codename,disconnected);

@override
String toString() {
  return 'MiWearState(name: $name, addr: $addr, connectType: $connectType, authkey: $authkey, codename: $codename, disconnected: $disconnected)';
}


}

/// @nodoc
abstract mixin class _$MiWearStateCopyWith<$Res> implements $MiWearStateCopyWith<$Res> {
  factory _$MiWearStateCopyWith(_MiWearState value, $Res Function(_MiWearState) _then) = __$MiWearStateCopyWithImpl;
@override @useResult
$Res call({
 String name, String addr, String connectType, String? authkey, String? codename, bool disconnected
});




}
/// @nodoc
class __$MiWearStateCopyWithImpl<$Res>
    implements _$MiWearStateCopyWith<$Res> {
  __$MiWearStateCopyWithImpl(this._self, this._then);

  final _MiWearState _self;
  final $Res Function(_MiWearState) _then;

/// Create a copy of MiWearState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? addr = null,Object? connectType = null,Object? authkey = freezed,Object? codename = freezed,Object? disconnected = null,}) {
  return _then(_MiWearState(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as String,connectType: null == connectType ? _self.connectType : connectType // ignore: cast_nullable_to_non_nullable
as String,authkey: freezed == authkey ? _self.authkey : authkey // ignore: cast_nullable_to_non_nullable
as String?,codename: freezed == codename ? _self.codename : codename // ignore: cast_nullable_to_non_nullable
as String?,disconnected: null == disconnected ? _self.disconnected : disconnected // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ChargeInfo {

 int get state; int? get timestamp;
/// Create a copy of ChargeInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChargeInfoCopyWith<ChargeInfo> get copyWith => _$ChargeInfoCopyWithImpl<ChargeInfo>(this as ChargeInfo, _$identity);

  /// Serializes this ChargeInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChargeInfo&&(identical(other.state, state) || other.state == state)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,state,timestamp);

@override
String toString() {
  return 'ChargeInfo(state: $state, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $ChargeInfoCopyWith<$Res>  {
  factory $ChargeInfoCopyWith(ChargeInfo value, $Res Function(ChargeInfo) _then) = _$ChargeInfoCopyWithImpl;
@useResult
$Res call({
 int state, int? timestamp
});




}
/// @nodoc
class _$ChargeInfoCopyWithImpl<$Res>
    implements $ChargeInfoCopyWith<$Res> {
  _$ChargeInfoCopyWithImpl(this._self, this._then);

  final ChargeInfo _self;
  final $Res Function(ChargeInfo) _then;

/// Create a copy of ChargeInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,Object? timestamp = freezed,}) {
  return _then(_self.copyWith(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as int,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ChargeInfo].
extension ChargeInfoPatterns on ChargeInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChargeInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChargeInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChargeInfo value)  $default,){
final _that = this;
switch (_that) {
case _ChargeInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChargeInfo value)?  $default,){
final _that = this;
switch (_that) {
case _ChargeInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int state,  int? timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChargeInfo() when $default != null:
return $default(_that.state,_that.timestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int state,  int? timestamp)  $default,) {final _that = this;
switch (_that) {
case _ChargeInfo():
return $default(_that.state,_that.timestamp);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int state,  int? timestamp)?  $default,) {final _that = this;
switch (_that) {
case _ChargeInfo() when $default != null:
return $default(_that.state,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChargeInfo implements ChargeInfo {
  const _ChargeInfo({this.state = 0, this.timestamp});
  factory _ChargeInfo.fromJson(Map<String, dynamic> json) => _$ChargeInfoFromJson(json);

@override@JsonKey() final  int state;
@override final  int? timestamp;

/// Create a copy of ChargeInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChargeInfoCopyWith<_ChargeInfo> get copyWith => __$ChargeInfoCopyWithImpl<_ChargeInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChargeInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChargeInfo&&(identical(other.state, state) || other.state == state)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,state,timestamp);

@override
String toString() {
  return 'ChargeInfo(state: $state, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$ChargeInfoCopyWith<$Res> implements $ChargeInfoCopyWith<$Res> {
  factory _$ChargeInfoCopyWith(_ChargeInfo value, $Res Function(_ChargeInfo) _then) = __$ChargeInfoCopyWithImpl;
@override @useResult
$Res call({
 int state, int? timestamp
});




}
/// @nodoc
class __$ChargeInfoCopyWithImpl<$Res>
    implements _$ChargeInfoCopyWith<$Res> {
  __$ChargeInfoCopyWithImpl(this._self, this._then);

  final _ChargeInfo _self;
  final $Res Function(_ChargeInfo) _then;

/// Create a copy of ChargeInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,Object? timestamp = freezed,}) {
  return _then(_ChargeInfo(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as int,timestamp: freezed == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$BatteryStatus {

 int get capacity; ChargeStatus get chargeStatus; ChargeInfo? get chargeInfo;
/// Create a copy of BatteryStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BatteryStatusCopyWith<BatteryStatus> get copyWith => _$BatteryStatusCopyWithImpl<BatteryStatus>(this as BatteryStatus, _$identity);

  /// Serializes this BatteryStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BatteryStatus&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.chargeStatus, chargeStatus) || other.chargeStatus == chargeStatus)&&(identical(other.chargeInfo, chargeInfo) || other.chargeInfo == chargeInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,capacity,chargeStatus,chargeInfo);

@override
String toString() {
  return 'BatteryStatus(capacity: $capacity, chargeStatus: $chargeStatus, chargeInfo: $chargeInfo)';
}


}

/// @nodoc
abstract mixin class $BatteryStatusCopyWith<$Res>  {
  factory $BatteryStatusCopyWith(BatteryStatus value, $Res Function(BatteryStatus) _then) = _$BatteryStatusCopyWithImpl;
@useResult
$Res call({
 int capacity, ChargeStatus chargeStatus, ChargeInfo? chargeInfo
});


$ChargeInfoCopyWith<$Res>? get chargeInfo;

}
/// @nodoc
class _$BatteryStatusCopyWithImpl<$Res>
    implements $BatteryStatusCopyWith<$Res> {
  _$BatteryStatusCopyWithImpl(this._self, this._then);

  final BatteryStatus _self;
  final $Res Function(BatteryStatus) _then;

/// Create a copy of BatteryStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? capacity = null,Object? chargeStatus = null,Object? chargeInfo = freezed,}) {
  return _then(_self.copyWith(
capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,chargeStatus: null == chargeStatus ? _self.chargeStatus : chargeStatus // ignore: cast_nullable_to_non_nullable
as ChargeStatus,chargeInfo: freezed == chargeInfo ? _self.chargeInfo : chargeInfo // ignore: cast_nullable_to_non_nullable
as ChargeInfo?,
  ));
}
/// Create a copy of BatteryStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChargeInfoCopyWith<$Res>? get chargeInfo {
    if (_self.chargeInfo == null) {
    return null;
  }

  return $ChargeInfoCopyWith<$Res>(_self.chargeInfo!, (value) {
    return _then(_self.copyWith(chargeInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [BatteryStatus].
extension BatteryStatusPatterns on BatteryStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BatteryStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BatteryStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BatteryStatus value)  $default,){
final _that = this;
switch (_that) {
case _BatteryStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BatteryStatus value)?  $default,){
final _that = this;
switch (_that) {
case _BatteryStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int capacity,  ChargeStatus chargeStatus,  ChargeInfo? chargeInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BatteryStatus() when $default != null:
return $default(_that.capacity,_that.chargeStatus,_that.chargeInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int capacity,  ChargeStatus chargeStatus,  ChargeInfo? chargeInfo)  $default,) {final _that = this;
switch (_that) {
case _BatteryStatus():
return $default(_that.capacity,_that.chargeStatus,_that.chargeInfo);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int capacity,  ChargeStatus chargeStatus,  ChargeInfo? chargeInfo)?  $default,) {final _that = this;
switch (_that) {
case _BatteryStatus() when $default != null:
return $default(_that.capacity,_that.chargeStatus,_that.chargeInfo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BatteryStatus implements BatteryStatus {
  const _BatteryStatus({required this.capacity, this.chargeStatus = ChargeStatus.unknown, this.chargeInfo});
  factory _BatteryStatus.fromJson(Map<String, dynamic> json) => _$BatteryStatusFromJson(json);

@override final  int capacity;
@override@JsonKey() final  ChargeStatus chargeStatus;
@override final  ChargeInfo? chargeInfo;

/// Create a copy of BatteryStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BatteryStatusCopyWith<_BatteryStatus> get copyWith => __$BatteryStatusCopyWithImpl<_BatteryStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BatteryStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BatteryStatus&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.chargeStatus, chargeStatus) || other.chargeStatus == chargeStatus)&&(identical(other.chargeInfo, chargeInfo) || other.chargeInfo == chargeInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,capacity,chargeStatus,chargeInfo);

@override
String toString() {
  return 'BatteryStatus(capacity: $capacity, chargeStatus: $chargeStatus, chargeInfo: $chargeInfo)';
}


}

/// @nodoc
abstract mixin class _$BatteryStatusCopyWith<$Res> implements $BatteryStatusCopyWith<$Res> {
  factory _$BatteryStatusCopyWith(_BatteryStatus value, $Res Function(_BatteryStatus) _then) = __$BatteryStatusCopyWithImpl;
@override @useResult
$Res call({
 int capacity, ChargeStatus chargeStatus, ChargeInfo? chargeInfo
});


@override $ChargeInfoCopyWith<$Res>? get chargeInfo;

}
/// @nodoc
class __$BatteryStatusCopyWithImpl<$Res>
    implements _$BatteryStatusCopyWith<$Res> {
  __$BatteryStatusCopyWithImpl(this._self, this._then);

  final _BatteryStatus _self;
  final $Res Function(_BatteryStatus) _then;

/// Create a copy of BatteryStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? capacity = null,Object? chargeStatus = null,Object? chargeInfo = freezed,}) {
  return _then(_BatteryStatus(
capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as int,chargeStatus: null == chargeStatus ? _self.chargeStatus : chargeStatus // ignore: cast_nullable_to_non_nullable
as ChargeStatus,chargeInfo: freezed == chargeInfo ? _self.chargeInfo : chargeInfo // ignore: cast_nullable_to_non_nullable
as ChargeInfo?,
  ));
}

/// Create a copy of BatteryStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ChargeInfoCopyWith<$Res>? get chargeInfo {
    if (_self.chargeInfo == null) {
    return null;
  }

  return $ChargeInfoCopyWith<$Res>(_self.chargeInfo!, (value) {
    return _then(_self.copyWith(chargeInfo: value));
  });
}
}


/// @nodoc
mixin _$AppInfo {

 String get packageName; List<int> get fingerprint; int get versionCode; bool get canRemove; String get appName;
/// Create a copy of AppInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppInfoCopyWith<AppInfo> get copyWith => _$AppInfoCopyWithImpl<AppInfo>(this as AppInfo, _$identity);

  /// Serializes this AppInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppInfo&&(identical(other.packageName, packageName) || other.packageName == packageName)&&const DeepCollectionEquality().equals(other.fingerprint, fingerprint)&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.canRemove, canRemove) || other.canRemove == canRemove)&&(identical(other.appName, appName) || other.appName == appName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packageName,const DeepCollectionEquality().hash(fingerprint),versionCode,canRemove,appName);

@override
String toString() {
  return 'AppInfo(packageName: $packageName, fingerprint: $fingerprint, versionCode: $versionCode, canRemove: $canRemove, appName: $appName)';
}


}

/// @nodoc
abstract mixin class $AppInfoCopyWith<$Res>  {
  factory $AppInfoCopyWith(AppInfo value, $Res Function(AppInfo) _then) = _$AppInfoCopyWithImpl;
@useResult
$Res call({
 String packageName, List<int> fingerprint, int versionCode, bool canRemove, String appName
});




}
/// @nodoc
class _$AppInfoCopyWithImpl<$Res>
    implements $AppInfoCopyWith<$Res> {
  _$AppInfoCopyWithImpl(this._self, this._then);

  final AppInfo _self;
  final $Res Function(AppInfo) _then;

/// Create a copy of AppInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? packageName = null,Object? fingerprint = null,Object? versionCode = null,Object? canRemove = null,Object? appName = null,}) {
  return _then(_self.copyWith(
packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self.fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as List<int>,versionCode: null == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int,canRemove: null == canRemove ? _self.canRemove : canRemove // ignore: cast_nullable_to_non_nullable
as bool,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AppInfo].
extension AppInfoPatterns on AppInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppInfo value)  $default,){
final _that = this;
switch (_that) {
case _AppInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppInfo value)?  $default,){
final _that = this;
switch (_that) {
case _AppInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String packageName,  List<int> fingerprint,  int versionCode,  bool canRemove,  String appName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppInfo() when $default != null:
return $default(_that.packageName,_that.fingerprint,_that.versionCode,_that.canRemove,_that.appName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String packageName,  List<int> fingerprint,  int versionCode,  bool canRemove,  String appName)  $default,) {final _that = this;
switch (_that) {
case _AppInfo():
return $default(_that.packageName,_that.fingerprint,_that.versionCode,_that.canRemove,_that.appName);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String packageName,  List<int> fingerprint,  int versionCode,  bool canRemove,  String appName)?  $default,) {final _that = this;
switch (_that) {
case _AppInfo() when $default != null:
return $default(_that.packageName,_that.fingerprint,_that.versionCode,_that.canRemove,_that.appName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppInfo implements AppInfo {
  const _AppInfo({required this.packageName, final  List<int> fingerprint = const <int>[], this.versionCode = 0, this.canRemove = false, required this.appName}): _fingerprint = fingerprint;
  factory _AppInfo.fromJson(Map<String, dynamic> json) => _$AppInfoFromJson(json);

@override final  String packageName;
 final  List<int> _fingerprint;
@override@JsonKey() List<int> get fingerprint {
  if (_fingerprint is EqualUnmodifiableListView) return _fingerprint;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fingerprint);
}

@override@JsonKey() final  int versionCode;
@override@JsonKey() final  bool canRemove;
@override final  String appName;

/// Create a copy of AppInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppInfoCopyWith<_AppInfo> get copyWith => __$AppInfoCopyWithImpl<_AppInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppInfo&&(identical(other.packageName, packageName) || other.packageName == packageName)&&const DeepCollectionEquality().equals(other._fingerprint, _fingerprint)&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.canRemove, canRemove) || other.canRemove == canRemove)&&(identical(other.appName, appName) || other.appName == appName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packageName,const DeepCollectionEquality().hash(_fingerprint),versionCode,canRemove,appName);

@override
String toString() {
  return 'AppInfo(packageName: $packageName, fingerprint: $fingerprint, versionCode: $versionCode, canRemove: $canRemove, appName: $appName)';
}


}

/// @nodoc
abstract mixin class _$AppInfoCopyWith<$Res> implements $AppInfoCopyWith<$Res> {
  factory _$AppInfoCopyWith(_AppInfo value, $Res Function(_AppInfo) _then) = __$AppInfoCopyWithImpl;
@override @useResult
$Res call({
 String packageName, List<int> fingerprint, int versionCode, bool canRemove, String appName
});




}
/// @nodoc
class __$AppInfoCopyWithImpl<$Res>
    implements _$AppInfoCopyWith<$Res> {
  __$AppInfoCopyWithImpl(this._self, this._then);

  final _AppInfo _self;
  final $Res Function(_AppInfo) _then;

/// Create a copy of AppInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? packageName = null,Object? fingerprint = null,Object? versionCode = null,Object? canRemove = null,Object? appName = null,}) {
  return _then(_AppInfo(
packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,fingerprint: null == fingerprint ? _self._fingerprint : fingerprint // ignore: cast_nullable_to_non_nullable
as List<int>,versionCode: null == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int,canRemove: null == canRemove ? _self.canRemove : canRemove // ignore: cast_nullable_to_non_nullable
as bool,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$StorageInfo {

 int get used; int get total;
/// Create a copy of StorageInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StorageInfoCopyWith<StorageInfo> get copyWith => _$StorageInfoCopyWithImpl<StorageInfo>(this as StorageInfo, _$identity);

  /// Serializes this StorageInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StorageInfo&&(identical(other.used, used) || other.used == used)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,used,total);

@override
String toString() {
  return 'StorageInfo(used: $used, total: $total)';
}


}

/// @nodoc
abstract mixin class $StorageInfoCopyWith<$Res>  {
  factory $StorageInfoCopyWith(StorageInfo value, $Res Function(StorageInfo) _then) = _$StorageInfoCopyWithImpl;
@useResult
$Res call({
 int used, int total
});




}
/// @nodoc
class _$StorageInfoCopyWithImpl<$Res>
    implements $StorageInfoCopyWith<$Res> {
  _$StorageInfoCopyWithImpl(this._self, this._then);

  final StorageInfo _self;
  final $Res Function(StorageInfo) _then;

/// Create a copy of StorageInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? used = null,Object? total = null,}) {
  return _then(_self.copyWith(
used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [StorageInfo].
extension StorageInfoPatterns on StorageInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StorageInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StorageInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StorageInfo value)  $default,){
final _that = this;
switch (_that) {
case _StorageInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StorageInfo value)?  $default,){
final _that = this;
switch (_that) {
case _StorageInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int used,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StorageInfo() when $default != null:
return $default(_that.used,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int used,  int total)  $default,) {final _that = this;
switch (_that) {
case _StorageInfo():
return $default(_that.used,_that.total);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int used,  int total)?  $default,) {final _that = this;
switch (_that) {
case _StorageInfo() when $default != null:
return $default(_that.used,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StorageInfo implements StorageInfo {
  const _StorageInfo({required this.used, required this.total});
  factory _StorageInfo.fromJson(Map<String, dynamic> json) => _$StorageInfoFromJson(json);

@override final  int used;
@override final  int total;

/// Create a copy of StorageInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StorageInfoCopyWith<_StorageInfo> get copyWith => __$StorageInfoCopyWithImpl<_StorageInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StorageInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StorageInfo&&(identical(other.used, used) || other.used == used)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,used,total);

@override
String toString() {
  return 'StorageInfo(used: $used, total: $total)';
}


}

/// @nodoc
abstract mixin class _$StorageInfoCopyWith<$Res> implements $StorageInfoCopyWith<$Res> {
  factory _$StorageInfoCopyWith(_StorageInfo value, $Res Function(_StorageInfo) _then) = __$StorageInfoCopyWithImpl;
@override @useResult
$Res call({
 int used, int total
});




}
/// @nodoc
class __$StorageInfoCopyWithImpl<$Res>
    implements _$StorageInfoCopyWith<$Res> {
  __$StorageInfoCopyWithImpl(this._self, this._then);

  final _StorageInfo _self;
  final $Res Function(_StorageInfo) _then;

/// Create a copy of StorageInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? used = null,Object? total = null,}) {
  return _then(_StorageInfo(
used: null == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SystemInfo {

 String get serialNumber; String get firmwareVersion; String get imei; String get model; StorageInfo? get storageInfo;
/// Create a copy of SystemInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemInfoCopyWith<SystemInfo> get copyWith => _$SystemInfoCopyWithImpl<SystemInfo>(this as SystemInfo, _$identity);

  /// Serializes this SystemInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemInfo&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.firmwareVersion, firmwareVersion) || other.firmwareVersion == firmwareVersion)&&(identical(other.imei, imei) || other.imei == imei)&&(identical(other.model, model) || other.model == model)&&(identical(other.storageInfo, storageInfo) || other.storageInfo == storageInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serialNumber,firmwareVersion,imei,model,storageInfo);

@override
String toString() {
  return 'SystemInfo(serialNumber: $serialNumber, firmwareVersion: $firmwareVersion, imei: $imei, model: $model, storageInfo: $storageInfo)';
}


}

/// @nodoc
abstract mixin class $SystemInfoCopyWith<$Res>  {
  factory $SystemInfoCopyWith(SystemInfo value, $Res Function(SystemInfo) _then) = _$SystemInfoCopyWithImpl;
@useResult
$Res call({
 String serialNumber, String firmwareVersion, String imei, String model, StorageInfo? storageInfo
});


$StorageInfoCopyWith<$Res>? get storageInfo;

}
/// @nodoc
class _$SystemInfoCopyWithImpl<$Res>
    implements $SystemInfoCopyWith<$Res> {
  _$SystemInfoCopyWithImpl(this._self, this._then);

  final SystemInfo _self;
  final $Res Function(SystemInfo) _then;

/// Create a copy of SystemInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? serialNumber = null,Object? firmwareVersion = null,Object? imei = null,Object? model = null,Object? storageInfo = freezed,}) {
  return _then(_self.copyWith(
serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,firmwareVersion: null == firmwareVersion ? _self.firmwareVersion : firmwareVersion // ignore: cast_nullable_to_non_nullable
as String,imei: null == imei ? _self.imei : imei // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,storageInfo: freezed == storageInfo ? _self.storageInfo : storageInfo // ignore: cast_nullable_to_non_nullable
as StorageInfo?,
  ));
}
/// Create a copy of SystemInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StorageInfoCopyWith<$Res>? get storageInfo {
    if (_self.storageInfo == null) {
    return null;
  }

  return $StorageInfoCopyWith<$Res>(_self.storageInfo!, (value) {
    return _then(_self.copyWith(storageInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [SystemInfo].
extension SystemInfoPatterns on SystemInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemInfo value)  $default,){
final _that = this;
switch (_that) {
case _SystemInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemInfo value)?  $default,){
final _that = this;
switch (_that) {
case _SystemInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String serialNumber,  String firmwareVersion,  String imei,  String model,  StorageInfo? storageInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemInfo() when $default != null:
return $default(_that.serialNumber,_that.firmwareVersion,_that.imei,_that.model,_that.storageInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String serialNumber,  String firmwareVersion,  String imei,  String model,  StorageInfo? storageInfo)  $default,) {final _that = this;
switch (_that) {
case _SystemInfo():
return $default(_that.serialNumber,_that.firmwareVersion,_that.imei,_that.model,_that.storageInfo);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String serialNumber,  String firmwareVersion,  String imei,  String model,  StorageInfo? storageInfo)?  $default,) {final _that = this;
switch (_that) {
case _SystemInfo() when $default != null:
return $default(_that.serialNumber,_that.firmwareVersion,_that.imei,_that.model,_that.storageInfo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SystemInfo implements SystemInfo {
  const _SystemInfo({required this.serialNumber, required this.firmwareVersion, required this.imei, required this.model, this.storageInfo});
  factory _SystemInfo.fromJson(Map<String, dynamic> json) => _$SystemInfoFromJson(json);

@override final  String serialNumber;
@override final  String firmwareVersion;
@override final  String imei;
@override final  String model;
@override final  StorageInfo? storageInfo;

/// Create a copy of SystemInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemInfoCopyWith<_SystemInfo> get copyWith => __$SystemInfoCopyWithImpl<_SystemInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SystemInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemInfo&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.firmwareVersion, firmwareVersion) || other.firmwareVersion == firmwareVersion)&&(identical(other.imei, imei) || other.imei == imei)&&(identical(other.model, model) || other.model == model)&&(identical(other.storageInfo, storageInfo) || other.storageInfo == storageInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serialNumber,firmwareVersion,imei,model,storageInfo);

@override
String toString() {
  return 'SystemInfo(serialNumber: $serialNumber, firmwareVersion: $firmwareVersion, imei: $imei, model: $model, storageInfo: $storageInfo)';
}


}

/// @nodoc
abstract mixin class _$SystemInfoCopyWith<$Res> implements $SystemInfoCopyWith<$Res> {
  factory _$SystemInfoCopyWith(_SystemInfo value, $Res Function(_SystemInfo) _then) = __$SystemInfoCopyWithImpl;
@override @useResult
$Res call({
 String serialNumber, String firmwareVersion, String imei, String model, StorageInfo? storageInfo
});


@override $StorageInfoCopyWith<$Res>? get storageInfo;

}
/// @nodoc
class __$SystemInfoCopyWithImpl<$Res>
    implements _$SystemInfoCopyWith<$Res> {
  __$SystemInfoCopyWithImpl(this._self, this._then);

  final _SystemInfo _self;
  final $Res Function(_SystemInfo) _then;

/// Create a copy of SystemInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serialNumber = null,Object? firmwareVersion = null,Object? imei = null,Object? model = null,Object? storageInfo = freezed,}) {
  return _then(_SystemInfo(
serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,firmwareVersion: null == firmwareVersion ? _self.firmwareVersion : firmwareVersion // ignore: cast_nullable_to_non_nullable
as String,imei: null == imei ? _self.imei : imei // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,storageInfo: freezed == storageInfo ? _self.storageInfo : storageInfo // ignore: cast_nullable_to_non_nullable
as StorageInfo?,
  ));
}

/// Create a copy of SystemInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StorageInfoCopyWith<$Res>? get storageInfo {
    if (_self.storageInfo == null) {
    return null;
  }

  return $StorageInfoCopyWith<$Res>(_self.storageInfo!, (value) {
    return _then(_self.copyWith(storageInfo: value));
  });
}
}


/// @nodoc
mixin _$WatchfaceInfo {

 String get id; String get name; bool get isCurrent; bool get canRemove; int get versionCode; bool get canEdit; String get backgroundColor; String get backgroundImage; String get style; List<String> get backgroundImageList;
/// Create a copy of WatchfaceInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WatchfaceInfoCopyWith<WatchfaceInfo> get copyWith => _$WatchfaceInfoCopyWithImpl<WatchfaceInfo>(this as WatchfaceInfo, _$identity);

  /// Serializes this WatchfaceInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WatchfaceInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCurrent, isCurrent) || other.isCurrent == isCurrent)&&(identical(other.canRemove, canRemove) || other.canRemove == canRemove)&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.canEdit, canEdit) || other.canEdit == canEdit)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.backgroundImage, backgroundImage) || other.backgroundImage == backgroundImage)&&(identical(other.style, style) || other.style == style)&&const DeepCollectionEquality().equals(other.backgroundImageList, backgroundImageList));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isCurrent,canRemove,versionCode,canEdit,backgroundColor,backgroundImage,style,const DeepCollectionEquality().hash(backgroundImageList));

@override
String toString() {
  return 'WatchfaceInfo(id: $id, name: $name, isCurrent: $isCurrent, canRemove: $canRemove, versionCode: $versionCode, canEdit: $canEdit, backgroundColor: $backgroundColor, backgroundImage: $backgroundImage, style: $style, backgroundImageList: $backgroundImageList)';
}


}

/// @nodoc
abstract mixin class $WatchfaceInfoCopyWith<$Res>  {
  factory $WatchfaceInfoCopyWith(WatchfaceInfo value, $Res Function(WatchfaceInfo) _then) = _$WatchfaceInfoCopyWithImpl;
@useResult
$Res call({
 String id, String name, bool isCurrent, bool canRemove, int versionCode, bool canEdit, String backgroundColor, String backgroundImage, String style, List<String> backgroundImageList
});




}
/// @nodoc
class _$WatchfaceInfoCopyWithImpl<$Res>
    implements $WatchfaceInfoCopyWith<$Res> {
  _$WatchfaceInfoCopyWithImpl(this._self, this._then);

  final WatchfaceInfo _self;
  final $Res Function(WatchfaceInfo) _then;

/// Create a copy of WatchfaceInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? isCurrent = null,Object? canRemove = null,Object? versionCode = null,Object? canEdit = null,Object? backgroundColor = null,Object? backgroundImage = null,Object? style = null,Object? backgroundImageList = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCurrent: null == isCurrent ? _self.isCurrent : isCurrent // ignore: cast_nullable_to_non_nullable
as bool,canRemove: null == canRemove ? _self.canRemove : canRemove // ignore: cast_nullable_to_non_nullable
as bool,versionCode: null == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int,canEdit: null == canEdit ? _self.canEdit : canEdit // ignore: cast_nullable_to_non_nullable
as bool,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,backgroundImage: null == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as String,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as String,backgroundImageList: null == backgroundImageList ? _self.backgroundImageList : backgroundImageList // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [WatchfaceInfo].
extension WatchfaceInfoPatterns on WatchfaceInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WatchfaceInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WatchfaceInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WatchfaceInfo value)  $default,){
final _that = this;
switch (_that) {
case _WatchfaceInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WatchfaceInfo value)?  $default,){
final _that = this;
switch (_that) {
case _WatchfaceInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  bool isCurrent,  bool canRemove,  int versionCode,  bool canEdit,  String backgroundColor,  String backgroundImage,  String style,  List<String> backgroundImageList)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WatchfaceInfo() when $default != null:
return $default(_that.id,_that.name,_that.isCurrent,_that.canRemove,_that.versionCode,_that.canEdit,_that.backgroundColor,_that.backgroundImage,_that.style,_that.backgroundImageList);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  bool isCurrent,  bool canRemove,  int versionCode,  bool canEdit,  String backgroundColor,  String backgroundImage,  String style,  List<String> backgroundImageList)  $default,) {final _that = this;
switch (_that) {
case _WatchfaceInfo():
return $default(_that.id,_that.name,_that.isCurrent,_that.canRemove,_that.versionCode,_that.canEdit,_that.backgroundColor,_that.backgroundImage,_that.style,_that.backgroundImageList);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  bool isCurrent,  bool canRemove,  int versionCode,  bool canEdit,  String backgroundColor,  String backgroundImage,  String style,  List<String> backgroundImageList)?  $default,) {final _that = this;
switch (_that) {
case _WatchfaceInfo() when $default != null:
return $default(_that.id,_that.name,_that.isCurrent,_that.canRemove,_that.versionCode,_that.canEdit,_that.backgroundColor,_that.backgroundImage,_that.style,_that.backgroundImageList);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WatchfaceInfo implements WatchfaceInfo {
  const _WatchfaceInfo({required this.id, required this.name, this.isCurrent = false, this.canRemove = false, this.versionCode = 0, this.canEdit = false, this.backgroundColor = '', this.backgroundImage = '', this.style = '', final  List<String> backgroundImageList = const <String>[]}): _backgroundImageList = backgroundImageList;
  factory _WatchfaceInfo.fromJson(Map<String, dynamic> json) => _$WatchfaceInfoFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  bool isCurrent;
@override@JsonKey() final  bool canRemove;
@override@JsonKey() final  int versionCode;
@override@JsonKey() final  bool canEdit;
@override@JsonKey() final  String backgroundColor;
@override@JsonKey() final  String backgroundImage;
@override@JsonKey() final  String style;
 final  List<String> _backgroundImageList;
@override@JsonKey() List<String> get backgroundImageList {
  if (_backgroundImageList is EqualUnmodifiableListView) return _backgroundImageList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_backgroundImageList);
}


/// Create a copy of WatchfaceInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WatchfaceInfoCopyWith<_WatchfaceInfo> get copyWith => __$WatchfaceInfoCopyWithImpl<_WatchfaceInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WatchfaceInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WatchfaceInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCurrent, isCurrent) || other.isCurrent == isCurrent)&&(identical(other.canRemove, canRemove) || other.canRemove == canRemove)&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.canEdit, canEdit) || other.canEdit == canEdit)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.backgroundImage, backgroundImage) || other.backgroundImage == backgroundImage)&&(identical(other.style, style) || other.style == style)&&const DeepCollectionEquality().equals(other._backgroundImageList, _backgroundImageList));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,isCurrent,canRemove,versionCode,canEdit,backgroundColor,backgroundImage,style,const DeepCollectionEquality().hash(_backgroundImageList));

@override
String toString() {
  return 'WatchfaceInfo(id: $id, name: $name, isCurrent: $isCurrent, canRemove: $canRemove, versionCode: $versionCode, canEdit: $canEdit, backgroundColor: $backgroundColor, backgroundImage: $backgroundImage, style: $style, backgroundImageList: $backgroundImageList)';
}


}

/// @nodoc
abstract mixin class _$WatchfaceInfoCopyWith<$Res> implements $WatchfaceInfoCopyWith<$Res> {
  factory _$WatchfaceInfoCopyWith(_WatchfaceInfo value, $Res Function(_WatchfaceInfo) _then) = __$WatchfaceInfoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, bool isCurrent, bool canRemove, int versionCode, bool canEdit, String backgroundColor, String backgroundImage, String style, List<String> backgroundImageList
});




}
/// @nodoc
class __$WatchfaceInfoCopyWithImpl<$Res>
    implements _$WatchfaceInfoCopyWith<$Res> {
  __$WatchfaceInfoCopyWithImpl(this._self, this._then);

  final _WatchfaceInfo _self;
  final $Res Function(_WatchfaceInfo) _then;

/// Create a copy of WatchfaceInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? isCurrent = null,Object? canRemove = null,Object? versionCode = null,Object? canEdit = null,Object? backgroundColor = null,Object? backgroundImage = null,Object? style = null,Object? backgroundImageList = null,}) {
  return _then(_WatchfaceInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCurrent: null == isCurrent ? _self.isCurrent : isCurrent // ignore: cast_nullable_to_non_nullable
as bool,canRemove: null == canRemove ? _self.canRemove : canRemove // ignore: cast_nullable_to_non_nullable
as bool,versionCode: null == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int,canEdit: null == canEdit ? _self.canEdit : canEdit // ignore: cast_nullable_to_non_nullable
as bool,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as String,backgroundImage: null == backgroundImage ? _self.backgroundImage : backgroundImage // ignore: cast_nullable_to_non_nullable
as String,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as String,backgroundImageList: null == backgroundImageList ? _self._backgroundImageList : backgroundImageList // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
