// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TimeSyncProps {

 SyncDate get date; SyncTime get time; SyncTimeZone get timezone; bool get is12HourFormat;
/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimeSyncPropsCopyWith<TimeSyncProps> get copyWith => _$TimeSyncPropsCopyWithImpl<TimeSyncProps>(this as TimeSyncProps, _$identity);

  /// Serializes this TimeSyncProps to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TimeSyncProps&&(identical(other.date, date) || other.date == date)&&(identical(other.time, time) || other.time == time)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.is12HourFormat, is12HourFormat) || other.is12HourFormat == is12HourFormat));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,time,timezone,is12HourFormat);

@override
String toString() {
  return 'TimeSyncProps(date: $date, time: $time, timezone: $timezone, is12HourFormat: $is12HourFormat)';
}


}

/// @nodoc
abstract mixin class $TimeSyncPropsCopyWith<$Res>  {
  factory $TimeSyncPropsCopyWith(TimeSyncProps value, $Res Function(TimeSyncProps) _then) = _$TimeSyncPropsCopyWithImpl;
@useResult
$Res call({
 SyncDate date, SyncTime time, SyncTimeZone timezone, bool is12HourFormat
});


$SyncDateCopyWith<$Res> get date;$SyncTimeCopyWith<$Res> get time;$SyncTimeZoneCopyWith<$Res> get timezone;

}
/// @nodoc
class _$TimeSyncPropsCopyWithImpl<$Res>
    implements $TimeSyncPropsCopyWith<$Res> {
  _$TimeSyncPropsCopyWithImpl(this._self, this._then);

  final TimeSyncProps _self;
  final $Res Function(TimeSyncProps) _then;

/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? time = null,Object? timezone = null,Object? is12HourFormat = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as SyncDate,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SyncTime,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as SyncTimeZone,is12HourFormat: null == is12HourFormat ? _self.is12HourFormat : is12HourFormat // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncDateCopyWith<$Res> get date {
  
  return $SyncDateCopyWith<$Res>(_self.date, (value) {
    return _then(_self.copyWith(date: value));
  });
}/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncTimeCopyWith<$Res> get time {
  
  return $SyncTimeCopyWith<$Res>(_self.time, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncTimeZoneCopyWith<$Res> get timezone {
  
  return $SyncTimeZoneCopyWith<$Res>(_self.timezone, (value) {
    return _then(_self.copyWith(timezone: value));
  });
}
}


/// Adds pattern-matching-related methods to [TimeSyncProps].
extension TimeSyncPropsPatterns on TimeSyncProps {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TimeSyncProps value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TimeSyncProps() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TimeSyncProps value)  $default,){
final _that = this;
switch (_that) {
case _TimeSyncProps():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TimeSyncProps value)?  $default,){
final _that = this;
switch (_that) {
case _TimeSyncProps() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SyncDate date,  SyncTime time,  SyncTimeZone timezone,  bool is12HourFormat)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TimeSyncProps() when $default != null:
return $default(_that.date,_that.time,_that.timezone,_that.is12HourFormat);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SyncDate date,  SyncTime time,  SyncTimeZone timezone,  bool is12HourFormat)  $default,) {final _that = this;
switch (_that) {
case _TimeSyncProps():
return $default(_that.date,_that.time,_that.timezone,_that.is12HourFormat);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SyncDate date,  SyncTime time,  SyncTimeZone timezone,  bool is12HourFormat)?  $default,) {final _that = this;
switch (_that) {
case _TimeSyncProps() when $default != null:
return $default(_that.date,_that.time,_that.timezone,_that.is12HourFormat);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TimeSyncProps implements TimeSyncProps {
  const _TimeSyncProps({required this.date, required this.time, required this.timezone, this.is12HourFormat = false});
  factory _TimeSyncProps.fromJson(Map<String, dynamic> json) => _$TimeSyncPropsFromJson(json);

@override final  SyncDate date;
@override final  SyncTime time;
@override final  SyncTimeZone timezone;
@override@JsonKey() final  bool is12HourFormat;

/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimeSyncPropsCopyWith<_TimeSyncProps> get copyWith => __$TimeSyncPropsCopyWithImpl<_TimeSyncProps>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TimeSyncPropsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimeSyncProps&&(identical(other.date, date) || other.date == date)&&(identical(other.time, time) || other.time == time)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.is12HourFormat, is12HourFormat) || other.is12HourFormat == is12HourFormat));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,time,timezone,is12HourFormat);

@override
String toString() {
  return 'TimeSyncProps(date: $date, time: $time, timezone: $timezone, is12HourFormat: $is12HourFormat)';
}


}

/// @nodoc
abstract mixin class _$TimeSyncPropsCopyWith<$Res> implements $TimeSyncPropsCopyWith<$Res> {
  factory _$TimeSyncPropsCopyWith(_TimeSyncProps value, $Res Function(_TimeSyncProps) _then) = __$TimeSyncPropsCopyWithImpl;
@override @useResult
$Res call({
 SyncDate date, SyncTime time, SyncTimeZone timezone, bool is12HourFormat
});


@override $SyncDateCopyWith<$Res> get date;@override $SyncTimeCopyWith<$Res> get time;@override $SyncTimeZoneCopyWith<$Res> get timezone;

}
/// @nodoc
class __$TimeSyncPropsCopyWithImpl<$Res>
    implements _$TimeSyncPropsCopyWith<$Res> {
  __$TimeSyncPropsCopyWithImpl(this._self, this._then);

  final _TimeSyncProps _self;
  final $Res Function(_TimeSyncProps) _then;

/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? time = null,Object? timezone = null,Object? is12HourFormat = null,}) {
  return _then(_TimeSyncProps(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as SyncDate,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SyncTime,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as SyncTimeZone,is12HourFormat: null == is12HourFormat ? _self.is12HourFormat : is12HourFormat // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncDateCopyWith<$Res> get date {
  
  return $SyncDateCopyWith<$Res>(_self.date, (value) {
    return _then(_self.copyWith(date: value));
  });
}/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncTimeCopyWith<$Res> get time {
  
  return $SyncTimeCopyWith<$Res>(_self.time, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of TimeSyncProps
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncTimeZoneCopyWith<$Res> get timezone {
  
  return $SyncTimeZoneCopyWith<$Res>(_self.timezone, (value) {
    return _then(_self.copyWith(timezone: value));
  });
}
}


/// @nodoc
mixin _$SyncDate {

 int get year; int get month; int get day;
/// Create a copy of SyncDate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncDateCopyWith<SyncDate> get copyWith => _$SyncDateCopyWithImpl<SyncDate>(this as SyncDate, _$identity);

  /// Serializes this SyncDate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncDate&&(identical(other.year, year) || other.year == year)&&(identical(other.month, month) || other.month == month)&&(identical(other.day, day) || other.day == day));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,year,month,day);

@override
String toString() {
  return 'SyncDate(year: $year, month: $month, day: $day)';
}


}

/// @nodoc
abstract mixin class $SyncDateCopyWith<$Res>  {
  factory $SyncDateCopyWith(SyncDate value, $Res Function(SyncDate) _then) = _$SyncDateCopyWithImpl;
@useResult
$Res call({
 int year, int month, int day
});




}
/// @nodoc
class _$SyncDateCopyWithImpl<$Res>
    implements $SyncDateCopyWith<$Res> {
  _$SyncDateCopyWithImpl(this._self, this._then);

  final SyncDate _self;
  final $Res Function(SyncDate) _then;

/// Create a copy of SyncDate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? year = null,Object? month = null,Object? day = null,}) {
  return _then(_self.copyWith(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as int,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncDate].
extension SyncDatePatterns on SyncDate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncDate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncDate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncDate value)  $default,){
final _that = this;
switch (_that) {
case _SyncDate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncDate value)?  $default,){
final _that = this;
switch (_that) {
case _SyncDate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int year,  int month,  int day)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncDate() when $default != null:
return $default(_that.year,_that.month,_that.day);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int year,  int month,  int day)  $default,) {final _that = this;
switch (_that) {
case _SyncDate():
return $default(_that.year,_that.month,_that.day);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int year,  int month,  int day)?  $default,) {final _that = this;
switch (_that) {
case _SyncDate() when $default != null:
return $default(_that.year,_that.month,_that.day);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncDate implements SyncDate {
  const _SyncDate({required this.year, required this.month, required this.day});
  factory _SyncDate.fromJson(Map<String, dynamic> json) => _$SyncDateFromJson(json);

@override final  int year;
@override final  int month;
@override final  int day;

/// Create a copy of SyncDate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncDateCopyWith<_SyncDate> get copyWith => __$SyncDateCopyWithImpl<_SyncDate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncDateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncDate&&(identical(other.year, year) || other.year == year)&&(identical(other.month, month) || other.month == month)&&(identical(other.day, day) || other.day == day));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,year,month,day);

@override
String toString() {
  return 'SyncDate(year: $year, month: $month, day: $day)';
}


}

/// @nodoc
abstract mixin class _$SyncDateCopyWith<$Res> implements $SyncDateCopyWith<$Res> {
  factory _$SyncDateCopyWith(_SyncDate value, $Res Function(_SyncDate) _then) = __$SyncDateCopyWithImpl;
@override @useResult
$Res call({
 int year, int month, int day
});




}
/// @nodoc
class __$SyncDateCopyWithImpl<$Res>
    implements _$SyncDateCopyWith<$Res> {
  __$SyncDateCopyWithImpl(this._self, this._then);

  final _SyncDate _self;
  final $Res Function(_SyncDate) _then;

/// Create a copy of SyncDate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? year = null,Object? month = null,Object? day = null,}) {
  return _then(_SyncDate(
year: null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int,month: null == month ? _self.month : month // ignore: cast_nullable_to_non_nullable
as int,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SyncTime {

 int get hour; int get minute; int get second; int get millisecond;
/// Create a copy of SyncTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncTimeCopyWith<SyncTime> get copyWith => _$SyncTimeCopyWithImpl<SyncTime>(this as SyncTime, _$identity);

  /// Serializes this SyncTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncTime&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.second, second) || other.second == second)&&(identical(other.millisecond, millisecond) || other.millisecond == millisecond));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hour,minute,second,millisecond);

@override
String toString() {
  return 'SyncTime(hour: $hour, minute: $minute, second: $second, millisecond: $millisecond)';
}


}

/// @nodoc
abstract mixin class $SyncTimeCopyWith<$Res>  {
  factory $SyncTimeCopyWith(SyncTime value, $Res Function(SyncTime) _then) = _$SyncTimeCopyWithImpl;
@useResult
$Res call({
 int hour, int minute, int second, int millisecond
});




}
/// @nodoc
class _$SyncTimeCopyWithImpl<$Res>
    implements $SyncTimeCopyWith<$Res> {
  _$SyncTimeCopyWithImpl(this._self, this._then);

  final SyncTime _self;
  final $Res Function(SyncTime) _then;

/// Create a copy of SyncTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hour = null,Object? minute = null,Object? second = null,Object? millisecond = null,}) {
  return _then(_self.copyWith(
hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,second: null == second ? _self.second : second // ignore: cast_nullable_to_non_nullable
as int,millisecond: null == millisecond ? _self.millisecond : millisecond // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncTime].
extension SyncTimePatterns on SyncTime {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncTime value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncTime() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncTime value)  $default,){
final _that = this;
switch (_that) {
case _SyncTime():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncTime value)?  $default,){
final _that = this;
switch (_that) {
case _SyncTime() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int hour,  int minute,  int second,  int millisecond)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncTime() when $default != null:
return $default(_that.hour,_that.minute,_that.second,_that.millisecond);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int hour,  int minute,  int second,  int millisecond)  $default,) {final _that = this;
switch (_that) {
case _SyncTime():
return $default(_that.hour,_that.minute,_that.second,_that.millisecond);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int hour,  int minute,  int second,  int millisecond)?  $default,) {final _that = this;
switch (_that) {
case _SyncTime() when $default != null:
return $default(_that.hour,_that.minute,_that.second,_that.millisecond);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncTime implements SyncTime {
  const _SyncTime({required this.hour, required this.minute, this.second = 0, this.millisecond = 0});
  factory _SyncTime.fromJson(Map<String, dynamic> json) => _$SyncTimeFromJson(json);

@override final  int hour;
@override final  int minute;
@override@JsonKey() final  int second;
@override@JsonKey() final  int millisecond;

/// Create a copy of SyncTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncTimeCopyWith<_SyncTime> get copyWith => __$SyncTimeCopyWithImpl<_SyncTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncTime&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.second, second) || other.second == second)&&(identical(other.millisecond, millisecond) || other.millisecond == millisecond));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hour,minute,second,millisecond);

@override
String toString() {
  return 'SyncTime(hour: $hour, minute: $minute, second: $second, millisecond: $millisecond)';
}


}

/// @nodoc
abstract mixin class _$SyncTimeCopyWith<$Res> implements $SyncTimeCopyWith<$Res> {
  factory _$SyncTimeCopyWith(_SyncTime value, $Res Function(_SyncTime) _then) = __$SyncTimeCopyWithImpl;
@override @useResult
$Res call({
 int hour, int minute, int second, int millisecond
});




}
/// @nodoc
class __$SyncTimeCopyWithImpl<$Res>
    implements _$SyncTimeCopyWith<$Res> {
  __$SyncTimeCopyWithImpl(this._self, this._then);

  final _SyncTime _self;
  final $Res Function(_SyncTime) _then;

/// Create a copy of SyncTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hour = null,Object? minute = null,Object? second = null,Object? millisecond = null,}) {
  return _then(_SyncTime(
hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,second: null == second ? _self.second : second // ignore: cast_nullable_to_non_nullable
as int,millisecond: null == millisecond ? _self.millisecond : millisecond // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SyncTimeZone {

 int get offset; int get dstOffset; String get id;
/// Create a copy of SyncTimeZone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncTimeZoneCopyWith<SyncTimeZone> get copyWith => _$SyncTimeZoneCopyWithImpl<SyncTimeZone>(this as SyncTimeZone, _$identity);

  /// Serializes this SyncTimeZone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncTimeZone&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.dstOffset, dstOffset) || other.dstOffset == dstOffset)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offset,dstOffset,id);

@override
String toString() {
  return 'SyncTimeZone(offset: $offset, dstOffset: $dstOffset, id: $id)';
}


}

/// @nodoc
abstract mixin class $SyncTimeZoneCopyWith<$Res>  {
  factory $SyncTimeZoneCopyWith(SyncTimeZone value, $Res Function(SyncTimeZone) _then) = _$SyncTimeZoneCopyWithImpl;
@useResult
$Res call({
 int offset, int dstOffset, String id
});




}
/// @nodoc
class _$SyncTimeZoneCopyWithImpl<$Res>
    implements $SyncTimeZoneCopyWith<$Res> {
  _$SyncTimeZoneCopyWithImpl(this._self, this._then);

  final SyncTimeZone _self;
  final $Res Function(SyncTimeZone) _then;

/// Create a copy of SyncTimeZone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? offset = null,Object? dstOffset = null,Object? id = null,}) {
  return _then(_self.copyWith(
offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,dstOffset: null == dstOffset ? _self.dstOffset : dstOffset // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncTimeZone].
extension SyncTimeZonePatterns on SyncTimeZone {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncTimeZone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncTimeZone() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncTimeZone value)  $default,){
final _that = this;
switch (_that) {
case _SyncTimeZone():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncTimeZone value)?  $default,){
final _that = this;
switch (_that) {
case _SyncTimeZone() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int offset,  int dstOffset,  String id)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncTimeZone() when $default != null:
return $default(_that.offset,_that.dstOffset,_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int offset,  int dstOffset,  String id)  $default,) {final _that = this;
switch (_that) {
case _SyncTimeZone():
return $default(_that.offset,_that.dstOffset,_that.id);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int offset,  int dstOffset,  String id)?  $default,) {final _that = this;
switch (_that) {
case _SyncTimeZone() when $default != null:
return $default(_that.offset,_that.dstOffset,_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncTimeZone implements SyncTimeZone {
  const _SyncTimeZone({required this.offset, this.dstOffset = 0, required this.id});
  factory _SyncTimeZone.fromJson(Map<String, dynamic> json) => _$SyncTimeZoneFromJson(json);

@override final  int offset;
@override@JsonKey() final  int dstOffset;
@override final  String id;

/// Create a copy of SyncTimeZone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncTimeZoneCopyWith<_SyncTimeZone> get copyWith => __$SyncTimeZoneCopyWithImpl<_SyncTimeZone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncTimeZoneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncTimeZone&&(identical(other.offset, offset) || other.offset == offset)&&(identical(other.dstOffset, dstOffset) || other.dstOffset == dstOffset)&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offset,dstOffset,id);

@override
String toString() {
  return 'SyncTimeZone(offset: $offset, dstOffset: $dstOffset, id: $id)';
}


}

/// @nodoc
abstract mixin class _$SyncTimeZoneCopyWith<$Res> implements $SyncTimeZoneCopyWith<$Res> {
  factory _$SyncTimeZoneCopyWith(_SyncTimeZone value, $Res Function(_SyncTimeZone) _then) = __$SyncTimeZoneCopyWithImpl;
@override @useResult
$Res call({
 int offset, int dstOffset, String id
});




}
/// @nodoc
class __$SyncTimeZoneCopyWithImpl<$Res>
    implements _$SyncTimeZoneCopyWith<$Res> {
  __$SyncTimeZoneCopyWithImpl(this._self, this._then);

  final _SyncTimeZone _self;
  final $Res Function(_SyncTimeZone) _then;

/// Create a copy of SyncTimeZone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? offset = null,Object? dstOffset = null,Object? id = null,}) {
  return _then(_SyncTimeZone(
offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,dstOffset: null == dstOffset ? _self.dstOffset : dstOffset // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
