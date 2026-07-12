// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'astrobox_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AstroBoxIndexItem {

 String get id; String get name;@JsonKey(name: 'restype') AstroBoxResourceType get type; String get repoOwner; String get repoName; String get repoCommitHash; String get icon; String get cover; List<String> get tags;@JsonKey(name: 'device_vendors') List<String> get deviceVendors; List<String> get devices;@JsonKey(name: 'paid_type') AstroBoxPaidType get paidType;
/// Create a copy of AstroBoxIndexItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxIndexItemCopyWith<AstroBoxIndexItem> get copyWith => _$AstroBoxIndexItemCopyWithImpl<AstroBoxIndexItem>(this as AstroBoxIndexItem, _$identity);

  /// Serializes this AstroBoxIndexItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.repoOwner, repoOwner) || other.repoOwner == repoOwner)&&(identical(other.repoName, repoName) || other.repoName == repoName)&&(identical(other.repoCommitHash, repoCommitHash) || other.repoCommitHash == repoCommitHash)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.cover, cover) || other.cover == cover)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.deviceVendors, deviceVendors)&&const DeepCollectionEquality().equals(other.devices, devices)&&(identical(other.paidType, paidType) || other.paidType == paidType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,repoOwner,repoName,repoCommitHash,icon,cover,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(deviceVendors),const DeepCollectionEquality().hash(devices),paidType);

@override
String toString() {
  return 'AstroBoxIndexItem(id: $id, name: $name, type: $type, repoOwner: $repoOwner, repoName: $repoName, repoCommitHash: $repoCommitHash, icon: $icon, cover: $cover, tags: $tags, deviceVendors: $deviceVendors, devices: $devices, paidType: $paidType)';
}


}

/// @nodoc
abstract mixin class $AstroBoxIndexItemCopyWith<$Res>  {
  factory $AstroBoxIndexItemCopyWith(AstroBoxIndexItem value, $Res Function(AstroBoxIndexItem) _then) = _$AstroBoxIndexItemCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'restype') AstroBoxResourceType type, String repoOwner, String repoName, String repoCommitHash, String icon, String cover, List<String> tags,@JsonKey(name: 'device_vendors') List<String> deviceVendors, List<String> devices,@JsonKey(name: 'paid_type') AstroBoxPaidType paidType
});




}
/// @nodoc
class _$AstroBoxIndexItemCopyWithImpl<$Res>
    implements $AstroBoxIndexItemCopyWith<$Res> {
  _$AstroBoxIndexItemCopyWithImpl(this._self, this._then);

  final AstroBoxIndexItem _self;
  final $Res Function(AstroBoxIndexItem) _then;

/// Create a copy of AstroBoxIndexItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? repoOwner = null,Object? repoName = null,Object? repoCommitHash = null,Object? icon = null,Object? cover = null,Object? tags = null,Object? deviceVendors = null,Object? devices = null,Object? paidType = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AstroBoxResourceType,repoOwner: null == repoOwner ? _self.repoOwner : repoOwner // ignore: cast_nullable_to_non_nullable
as String,repoName: null == repoName ? _self.repoName : repoName // ignore: cast_nullable_to_non_nullable
as String,repoCommitHash: null == repoCommitHash ? _self.repoCommitHash : repoCommitHash // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,deviceVendors: null == deviceVendors ? _self.deviceVendors : deviceVendors // ignore: cast_nullable_to_non_nullable
as List<String>,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as List<String>,paidType: null == paidType ? _self.paidType : paidType // ignore: cast_nullable_to_non_nullable
as AstroBoxPaidType,
  ));
}

}


/// Adds pattern-matching-related methods to [AstroBoxIndexItem].
extension AstroBoxIndexItemPatterns on AstroBoxIndexItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxIndexItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxIndexItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxIndexItem value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxIndexItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxIndexItem value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxIndexItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'restype')  AstroBoxResourceType type,  String repoOwner,  String repoName,  String repoCommitHash,  String icon,  String cover,  List<String> tags, @JsonKey(name: 'device_vendors')  List<String> deviceVendors,  List<String> devices, @JsonKey(name: 'paid_type')  AstroBoxPaidType paidType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.repoOwner,_that.repoName,_that.repoCommitHash,_that.icon,_that.cover,_that.tags,_that.deviceVendors,_that.devices,_that.paidType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'restype')  AstroBoxResourceType type,  String repoOwner,  String repoName,  String repoCommitHash,  String icon,  String cover,  List<String> tags, @JsonKey(name: 'device_vendors')  List<String> deviceVendors,  List<String> devices, @JsonKey(name: 'paid_type')  AstroBoxPaidType paidType)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxIndexItem():
return $default(_that.id,_that.name,_that.type,_that.repoOwner,_that.repoName,_that.repoCommitHash,_that.icon,_that.cover,_that.tags,_that.deviceVendors,_that.devices,_that.paidType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'restype')  AstroBoxResourceType type,  String repoOwner,  String repoName,  String repoCommitHash,  String icon,  String cover,  List<String> tags, @JsonKey(name: 'device_vendors')  List<String> deviceVendors,  List<String> devices, @JsonKey(name: 'paid_type')  AstroBoxPaidType paidType)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.repoOwner,_that.repoName,_that.repoCommitHash,_that.icon,_that.cover,_that.tags,_that.deviceVendors,_that.devices,_that.paidType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxIndexItem implements AstroBoxIndexItem {
  const _AstroBoxIndexItem({required this.id, required this.name, @JsonKey(name: 'restype') required this.type, required this.repoOwner, required this.repoName, required this.repoCommitHash, required this.icon, required this.cover, final  List<String> tags = const [], @JsonKey(name: 'device_vendors') final  List<String> deviceVendors = const [], final  List<String> devices = const [], @JsonKey(name: 'paid_type') required this.paidType}): _tags = tags,_deviceVendors = deviceVendors,_devices = devices;
  factory _AstroBoxIndexItem.fromJson(Map<String, dynamic> json) => _$AstroBoxIndexItemFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey(name: 'restype') final  AstroBoxResourceType type;
@override final  String repoOwner;
@override final  String repoName;
@override final  String repoCommitHash;
@override final  String icon;
@override final  String cover;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<String> _deviceVendors;
@override@JsonKey(name: 'device_vendors') List<String> get deviceVendors {
  if (_deviceVendors is EqualUnmodifiableListView) return _deviceVendors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_deviceVendors);
}

 final  List<String> _devices;
@override@JsonKey() List<String> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}

@override@JsonKey(name: 'paid_type') final  AstroBoxPaidType paidType;

/// Create a copy of AstroBoxIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxIndexItemCopyWith<_AstroBoxIndexItem> get copyWith => __$AstroBoxIndexItemCopyWithImpl<_AstroBoxIndexItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxIndexItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.repoOwner, repoOwner) || other.repoOwner == repoOwner)&&(identical(other.repoName, repoName) || other.repoName == repoName)&&(identical(other.repoCommitHash, repoCommitHash) || other.repoCommitHash == repoCommitHash)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.cover, cover) || other.cover == cover)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._deviceVendors, _deviceVendors)&&const DeepCollectionEquality().equals(other._devices, _devices)&&(identical(other.paidType, paidType) || other.paidType == paidType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,repoOwner,repoName,repoCommitHash,icon,cover,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_deviceVendors),const DeepCollectionEquality().hash(_devices),paidType);

@override
String toString() {
  return 'AstroBoxIndexItem(id: $id, name: $name, type: $type, repoOwner: $repoOwner, repoName: $repoName, repoCommitHash: $repoCommitHash, icon: $icon, cover: $cover, tags: $tags, deviceVendors: $deviceVendors, devices: $devices, paidType: $paidType)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxIndexItemCopyWith<$Res> implements $AstroBoxIndexItemCopyWith<$Res> {
  factory _$AstroBoxIndexItemCopyWith(_AstroBoxIndexItem value, $Res Function(_AstroBoxIndexItem) _then) = __$AstroBoxIndexItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'restype') AstroBoxResourceType type, String repoOwner, String repoName, String repoCommitHash, String icon, String cover, List<String> tags,@JsonKey(name: 'device_vendors') List<String> deviceVendors, List<String> devices,@JsonKey(name: 'paid_type') AstroBoxPaidType paidType
});




}
/// @nodoc
class __$AstroBoxIndexItemCopyWithImpl<$Res>
    implements _$AstroBoxIndexItemCopyWith<$Res> {
  __$AstroBoxIndexItemCopyWithImpl(this._self, this._then);

  final _AstroBoxIndexItem _self;
  final $Res Function(_AstroBoxIndexItem) _then;

/// Create a copy of AstroBoxIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? repoOwner = null,Object? repoName = null,Object? repoCommitHash = null,Object? icon = null,Object? cover = null,Object? tags = null,Object? deviceVendors = null,Object? devices = null,Object? paidType = null,}) {
  return _then(_AstroBoxIndexItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AstroBoxResourceType,repoOwner: null == repoOwner ? _self.repoOwner : repoOwner // ignore: cast_nullable_to_non_nullable
as String,repoName: null == repoName ? _self.repoName : repoName // ignore: cast_nullable_to_non_nullable
as String,repoCommitHash: null == repoCommitHash ? _self.repoCommitHash : repoCommitHash // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,deviceVendors: null == deviceVendors ? _self._deviceVendors : deviceVendors // ignore: cast_nullable_to_non_nullable
as List<String>,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<String>,paidType: null == paidType ? _self.paidType : paidType // ignore: cast_nullable_to_non_nullable
as AstroBoxPaidType,
  ));
}


}


/// @nodoc
mixin _$AstroBoxManifest {

 AstroBoxManifestItem get item; List<AstroBoxManifestLink> get links; Map<String, AstroBoxManifestDownload> get downloads; Map<String, dynamic> get ext;
/// Create a copy of AstroBoxManifest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxManifestCopyWith<AstroBoxManifest> get copyWith => _$AstroBoxManifestCopyWithImpl<AstroBoxManifest>(this as AstroBoxManifest, _$identity);

  /// Serializes this AstroBoxManifest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxManifest&&(identical(other.item, item) || other.item == item)&&const DeepCollectionEquality().equals(other.links, links)&&const DeepCollectionEquality().equals(other.downloads, downloads)&&const DeepCollectionEquality().equals(other.ext, ext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,item,const DeepCollectionEquality().hash(links),const DeepCollectionEquality().hash(downloads),const DeepCollectionEquality().hash(ext));

@override
String toString() {
  return 'AstroBoxManifest(item: $item, links: $links, downloads: $downloads, ext: $ext)';
}


}

/// @nodoc
abstract mixin class $AstroBoxManifestCopyWith<$Res>  {
  factory $AstroBoxManifestCopyWith(AstroBoxManifest value, $Res Function(AstroBoxManifest) _then) = _$AstroBoxManifestCopyWithImpl;
@useResult
$Res call({
 AstroBoxManifestItem item, List<AstroBoxManifestLink> links, Map<String, AstroBoxManifestDownload> downloads, Map<String, dynamic> ext
});


$AstroBoxManifestItemCopyWith<$Res> get item;

}
/// @nodoc
class _$AstroBoxManifestCopyWithImpl<$Res>
    implements $AstroBoxManifestCopyWith<$Res> {
  _$AstroBoxManifestCopyWithImpl(this._self, this._then);

  final AstroBoxManifest _self;
  final $Res Function(AstroBoxManifest) _then;

/// Create a copy of AstroBoxManifest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? item = null,Object? links = null,Object? downloads = null,Object? ext = null,}) {
  return _then(_self.copyWith(
item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as AstroBoxManifestItem,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as List<AstroBoxManifestLink>,downloads: null == downloads ? _self.downloads : downloads // ignore: cast_nullable_to_non_nullable
as Map<String, AstroBoxManifestDownload>,ext: null == ext ? _self.ext : ext // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}
/// Create a copy of AstroBoxManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AstroBoxManifestItemCopyWith<$Res> get item {
  
  return $AstroBoxManifestItemCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// Adds pattern-matching-related methods to [AstroBoxManifest].
extension AstroBoxManifestPatterns on AstroBoxManifest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxManifest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxManifest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxManifest value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxManifest value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AstroBoxManifestItem item,  List<AstroBoxManifestLink> links,  Map<String, AstroBoxManifestDownload> downloads,  Map<String, dynamic> ext)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxManifest() when $default != null:
return $default(_that.item,_that.links,_that.downloads,_that.ext);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AstroBoxManifestItem item,  List<AstroBoxManifestLink> links,  Map<String, AstroBoxManifestDownload> downloads,  Map<String, dynamic> ext)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifest():
return $default(_that.item,_that.links,_that.downloads,_that.ext);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AstroBoxManifestItem item,  List<AstroBoxManifestLink> links,  Map<String, AstroBoxManifestDownload> downloads,  Map<String, dynamic> ext)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifest() when $default != null:
return $default(_that.item,_that.links,_that.downloads,_that.ext);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxManifest implements AstroBoxManifest {
  const _AstroBoxManifest({required this.item, final  List<AstroBoxManifestLink> links = const [], final  Map<String, AstroBoxManifestDownload> downloads = const {}, final  Map<String, dynamic> ext = const {}}): _links = links,_downloads = downloads,_ext = ext;
  factory _AstroBoxManifest.fromJson(Map<String, dynamic> json) => _$AstroBoxManifestFromJson(json);

@override final  AstroBoxManifestItem item;
 final  List<AstroBoxManifestLink> _links;
@override@JsonKey() List<AstroBoxManifestLink> get links {
  if (_links is EqualUnmodifiableListView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_links);
}

 final  Map<String, AstroBoxManifestDownload> _downloads;
@override@JsonKey() Map<String, AstroBoxManifestDownload> get downloads {
  if (_downloads is EqualUnmodifiableMapView) return _downloads;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_downloads);
}

 final  Map<String, dynamic> _ext;
@override@JsonKey() Map<String, dynamic> get ext {
  if (_ext is EqualUnmodifiableMapView) return _ext;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_ext);
}


/// Create a copy of AstroBoxManifest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxManifestCopyWith<_AstroBoxManifest> get copyWith => __$AstroBoxManifestCopyWithImpl<_AstroBoxManifest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxManifestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxManifest&&(identical(other.item, item) || other.item == item)&&const DeepCollectionEquality().equals(other._links, _links)&&const DeepCollectionEquality().equals(other._downloads, _downloads)&&const DeepCollectionEquality().equals(other._ext, _ext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,item,const DeepCollectionEquality().hash(_links),const DeepCollectionEquality().hash(_downloads),const DeepCollectionEquality().hash(_ext));

@override
String toString() {
  return 'AstroBoxManifest(item: $item, links: $links, downloads: $downloads, ext: $ext)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxManifestCopyWith<$Res> implements $AstroBoxManifestCopyWith<$Res> {
  factory _$AstroBoxManifestCopyWith(_AstroBoxManifest value, $Res Function(_AstroBoxManifest) _then) = __$AstroBoxManifestCopyWithImpl;
@override @useResult
$Res call({
 AstroBoxManifestItem item, List<AstroBoxManifestLink> links, Map<String, AstroBoxManifestDownload> downloads, Map<String, dynamic> ext
});


@override $AstroBoxManifestItemCopyWith<$Res> get item;

}
/// @nodoc
class __$AstroBoxManifestCopyWithImpl<$Res>
    implements _$AstroBoxManifestCopyWith<$Res> {
  __$AstroBoxManifestCopyWithImpl(this._self, this._then);

  final _AstroBoxManifest _self;
  final $Res Function(_AstroBoxManifest) _then;

/// Create a copy of AstroBoxManifest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? item = null,Object? links = null,Object? downloads = null,Object? ext = null,}) {
  return _then(_AstroBoxManifest(
item: null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as AstroBoxManifestItem,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as List<AstroBoxManifestLink>,downloads: null == downloads ? _self._downloads : downloads // ignore: cast_nullable_to_non_nullable
as Map<String, AstroBoxManifestDownload>,ext: null == ext ? _self._ext : ext // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

/// Create a copy of AstroBoxManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AstroBoxManifestItemCopyWith<$Res> get item {
  
  return $AstroBoxManifestItemCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// @nodoc
mixin _$AstroBoxManifestItem {

 String get id; AstroBoxResourceType get restype; String get name; String get description; String? get descriptionHtml; String? get descriptionBaseUrl; List<String> get preview; String get icon; String get cover; AstroBoxPaidType? get paidType; List<AstroBoxManifestAuthor> get author;
/// Create a copy of AstroBoxManifestItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxManifestItemCopyWith<AstroBoxManifestItem> get copyWith => _$AstroBoxManifestItemCopyWithImpl<AstroBoxManifestItem>(this as AstroBoxManifestItem, _$identity);

  /// Serializes this AstroBoxManifestItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxManifestItem&&(identical(other.id, id) || other.id == id)&&(identical(other.restype, restype) || other.restype == restype)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionHtml, descriptionHtml) || other.descriptionHtml == descriptionHtml)&&(identical(other.descriptionBaseUrl, descriptionBaseUrl) || other.descriptionBaseUrl == descriptionBaseUrl)&&const DeepCollectionEquality().equals(other.preview, preview)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.paidType, paidType) || other.paidType == paidType)&&const DeepCollectionEquality().equals(other.author, author));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restype,name,description,descriptionHtml,descriptionBaseUrl,const DeepCollectionEquality().hash(preview),icon,cover,paidType,const DeepCollectionEquality().hash(author));

@override
String toString() {
  return 'AstroBoxManifestItem(id: $id, restype: $restype, name: $name, description: $description, descriptionHtml: $descriptionHtml, descriptionBaseUrl: $descriptionBaseUrl, preview: $preview, icon: $icon, cover: $cover, paidType: $paidType, author: $author)';
}


}

/// @nodoc
abstract mixin class $AstroBoxManifestItemCopyWith<$Res>  {
  factory $AstroBoxManifestItemCopyWith(AstroBoxManifestItem value, $Res Function(AstroBoxManifestItem) _then) = _$AstroBoxManifestItemCopyWithImpl;
@useResult
$Res call({
 String id, AstroBoxResourceType restype, String name, String description, String? descriptionHtml, String? descriptionBaseUrl, List<String> preview, String icon, String cover, AstroBoxPaidType? paidType, List<AstroBoxManifestAuthor> author
});




}
/// @nodoc
class _$AstroBoxManifestItemCopyWithImpl<$Res>
    implements $AstroBoxManifestItemCopyWith<$Res> {
  _$AstroBoxManifestItemCopyWithImpl(this._self, this._then);

  final AstroBoxManifestItem _self;
  final $Res Function(AstroBoxManifestItem) _then;

/// Create a copy of AstroBoxManifestItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restype = null,Object? name = null,Object? description = null,Object? descriptionHtml = freezed,Object? descriptionBaseUrl = freezed,Object? preview = null,Object? icon = null,Object? cover = null,Object? paidType = freezed,Object? author = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restype: null == restype ? _self.restype : restype // ignore: cast_nullable_to_non_nullable
as AstroBoxResourceType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,descriptionHtml: freezed == descriptionHtml ? _self.descriptionHtml : descriptionHtml // ignore: cast_nullable_to_non_nullable
as String?,descriptionBaseUrl: freezed == descriptionBaseUrl ? _self.descriptionBaseUrl : descriptionBaseUrl // ignore: cast_nullable_to_non_nullable
as String?,preview: null == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as List<String>,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,paidType: freezed == paidType ? _self.paidType : paidType // ignore: cast_nullable_to_non_nullable
as AstroBoxPaidType?,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as List<AstroBoxManifestAuthor>,
  ));
}

}


/// Adds pattern-matching-related methods to [AstroBoxManifestItem].
extension AstroBoxManifestItemPatterns on AstroBoxManifestItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxManifestItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxManifestItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxManifestItem value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxManifestItem value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AstroBoxResourceType restype,  String name,  String description,  String? descriptionHtml,  String? descriptionBaseUrl,  List<String> preview,  String icon,  String cover,  AstroBoxPaidType? paidType,  List<AstroBoxManifestAuthor> author)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxManifestItem() when $default != null:
return $default(_that.id,_that.restype,_that.name,_that.description,_that.descriptionHtml,_that.descriptionBaseUrl,_that.preview,_that.icon,_that.cover,_that.paidType,_that.author);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AstroBoxResourceType restype,  String name,  String description,  String? descriptionHtml,  String? descriptionBaseUrl,  List<String> preview,  String icon,  String cover,  AstroBoxPaidType? paidType,  List<AstroBoxManifestAuthor> author)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestItem():
return $default(_that.id,_that.restype,_that.name,_that.description,_that.descriptionHtml,_that.descriptionBaseUrl,_that.preview,_that.icon,_that.cover,_that.paidType,_that.author);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AstroBoxResourceType restype,  String name,  String description,  String? descriptionHtml,  String? descriptionBaseUrl,  List<String> preview,  String icon,  String cover,  AstroBoxPaidType? paidType,  List<AstroBoxManifestAuthor> author)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestItem() when $default != null:
return $default(_that.id,_that.restype,_that.name,_that.description,_that.descriptionHtml,_that.descriptionBaseUrl,_that.preview,_that.icon,_that.cover,_that.paidType,_that.author);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxManifestItem implements AstroBoxManifestItem {
  const _AstroBoxManifestItem({required this.id, required this.restype, required this.name, required this.description, this.descriptionHtml, this.descriptionBaseUrl, final  List<String> preview = const [], required this.icon, required this.cover, this.paidType, final  List<AstroBoxManifestAuthor> author = const []}): _preview = preview,_author = author;
  factory _AstroBoxManifestItem.fromJson(Map<String, dynamic> json) => _$AstroBoxManifestItemFromJson(json);

@override final  String id;
@override final  AstroBoxResourceType restype;
@override final  String name;
@override final  String description;
@override final  String? descriptionHtml;
@override final  String? descriptionBaseUrl;
 final  List<String> _preview;
@override@JsonKey() List<String> get preview {
  if (_preview is EqualUnmodifiableListView) return _preview;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_preview);
}

@override final  String icon;
@override final  String cover;
@override final  AstroBoxPaidType? paidType;
 final  List<AstroBoxManifestAuthor> _author;
@override@JsonKey() List<AstroBoxManifestAuthor> get author {
  if (_author is EqualUnmodifiableListView) return _author;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_author);
}


/// Create a copy of AstroBoxManifestItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxManifestItemCopyWith<_AstroBoxManifestItem> get copyWith => __$AstroBoxManifestItemCopyWithImpl<_AstroBoxManifestItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxManifestItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxManifestItem&&(identical(other.id, id) || other.id == id)&&(identical(other.restype, restype) || other.restype == restype)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.descriptionHtml, descriptionHtml) || other.descriptionHtml == descriptionHtml)&&(identical(other.descriptionBaseUrl, descriptionBaseUrl) || other.descriptionBaseUrl == descriptionBaseUrl)&&const DeepCollectionEquality().equals(other._preview, _preview)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.paidType, paidType) || other.paidType == paidType)&&const DeepCollectionEquality().equals(other._author, _author));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restype,name,description,descriptionHtml,descriptionBaseUrl,const DeepCollectionEquality().hash(_preview),icon,cover,paidType,const DeepCollectionEquality().hash(_author));

@override
String toString() {
  return 'AstroBoxManifestItem(id: $id, restype: $restype, name: $name, description: $description, descriptionHtml: $descriptionHtml, descriptionBaseUrl: $descriptionBaseUrl, preview: $preview, icon: $icon, cover: $cover, paidType: $paidType, author: $author)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxManifestItemCopyWith<$Res> implements $AstroBoxManifestItemCopyWith<$Res> {
  factory _$AstroBoxManifestItemCopyWith(_AstroBoxManifestItem value, $Res Function(_AstroBoxManifestItem) _then) = __$AstroBoxManifestItemCopyWithImpl;
@override @useResult
$Res call({
 String id, AstroBoxResourceType restype, String name, String description, String? descriptionHtml, String? descriptionBaseUrl, List<String> preview, String icon, String cover, AstroBoxPaidType? paidType, List<AstroBoxManifestAuthor> author
});




}
/// @nodoc
class __$AstroBoxManifestItemCopyWithImpl<$Res>
    implements _$AstroBoxManifestItemCopyWith<$Res> {
  __$AstroBoxManifestItemCopyWithImpl(this._self, this._then);

  final _AstroBoxManifestItem _self;
  final $Res Function(_AstroBoxManifestItem) _then;

/// Create a copy of AstroBoxManifestItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restype = null,Object? name = null,Object? description = null,Object? descriptionHtml = freezed,Object? descriptionBaseUrl = freezed,Object? preview = null,Object? icon = null,Object? cover = null,Object? paidType = freezed,Object? author = null,}) {
  return _then(_AstroBoxManifestItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restype: null == restype ? _self.restype : restype // ignore: cast_nullable_to_non_nullable
as AstroBoxResourceType,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,descriptionHtml: freezed == descriptionHtml ? _self.descriptionHtml : descriptionHtml // ignore: cast_nullable_to_non_nullable
as String?,descriptionBaseUrl: freezed == descriptionBaseUrl ? _self.descriptionBaseUrl : descriptionBaseUrl // ignore: cast_nullable_to_non_nullable
as String?,preview: null == preview ? _self._preview : preview // ignore: cast_nullable_to_non_nullable
as List<String>,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,paidType: freezed == paidType ? _self.paidType : paidType // ignore: cast_nullable_to_non_nullable
as AstroBoxPaidType?,author: null == author ? _self._author : author // ignore: cast_nullable_to_non_nullable
as List<AstroBoxManifestAuthor>,
  ));
}


}


/// @nodoc
mixin _$AstroBoxManifestAuthor {

 String get name;@JsonKey(name: 'bindABAccount') bool get bindAbAccount;
/// Create a copy of AstroBoxManifestAuthor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxManifestAuthorCopyWith<AstroBoxManifestAuthor> get copyWith => _$AstroBoxManifestAuthorCopyWithImpl<AstroBoxManifestAuthor>(this as AstroBoxManifestAuthor, _$identity);

  /// Serializes this AstroBoxManifestAuthor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxManifestAuthor&&(identical(other.name, name) || other.name == name)&&(identical(other.bindAbAccount, bindAbAccount) || other.bindAbAccount == bindAbAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,bindAbAccount);

@override
String toString() {
  return 'AstroBoxManifestAuthor(name: $name, bindAbAccount: $bindAbAccount)';
}


}

/// @nodoc
abstract mixin class $AstroBoxManifestAuthorCopyWith<$Res>  {
  factory $AstroBoxManifestAuthorCopyWith(AstroBoxManifestAuthor value, $Res Function(AstroBoxManifestAuthor) _then) = _$AstroBoxManifestAuthorCopyWithImpl;
@useResult
$Res call({
 String name,@JsonKey(name: 'bindABAccount') bool bindAbAccount
});




}
/// @nodoc
class _$AstroBoxManifestAuthorCopyWithImpl<$Res>
    implements $AstroBoxManifestAuthorCopyWith<$Res> {
  _$AstroBoxManifestAuthorCopyWithImpl(this._self, this._then);

  final AstroBoxManifestAuthor _self;
  final $Res Function(AstroBoxManifestAuthor) _then;

/// Create a copy of AstroBoxManifestAuthor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? bindAbAccount = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bindAbAccount: null == bindAbAccount ? _self.bindAbAccount : bindAbAccount // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AstroBoxManifestAuthor].
extension AstroBoxManifestAuthorPatterns on AstroBoxManifestAuthor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxManifestAuthor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxManifestAuthor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxManifestAuthor value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestAuthor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxManifestAuthor value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestAuthor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'bindABAccount')  bool bindAbAccount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxManifestAuthor() when $default != null:
return $default(_that.name,_that.bindAbAccount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name, @JsonKey(name: 'bindABAccount')  bool bindAbAccount)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestAuthor():
return $default(_that.name,_that.bindAbAccount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name, @JsonKey(name: 'bindABAccount')  bool bindAbAccount)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestAuthor() when $default != null:
return $default(_that.name,_that.bindAbAccount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxManifestAuthor implements AstroBoxManifestAuthor {
  const _AstroBoxManifestAuthor({required this.name, @JsonKey(name: 'bindABAccount') this.bindAbAccount = false});
  factory _AstroBoxManifestAuthor.fromJson(Map<String, dynamic> json) => _$AstroBoxManifestAuthorFromJson(json);

@override final  String name;
@override@JsonKey(name: 'bindABAccount') final  bool bindAbAccount;

/// Create a copy of AstroBoxManifestAuthor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxManifestAuthorCopyWith<_AstroBoxManifestAuthor> get copyWith => __$AstroBoxManifestAuthorCopyWithImpl<_AstroBoxManifestAuthor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxManifestAuthorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxManifestAuthor&&(identical(other.name, name) || other.name == name)&&(identical(other.bindAbAccount, bindAbAccount) || other.bindAbAccount == bindAbAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,bindAbAccount);

@override
String toString() {
  return 'AstroBoxManifestAuthor(name: $name, bindAbAccount: $bindAbAccount)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxManifestAuthorCopyWith<$Res> implements $AstroBoxManifestAuthorCopyWith<$Res> {
  factory _$AstroBoxManifestAuthorCopyWith(_AstroBoxManifestAuthor value, $Res Function(_AstroBoxManifestAuthor) _then) = __$AstroBoxManifestAuthorCopyWithImpl;
@override @useResult
$Res call({
 String name,@JsonKey(name: 'bindABAccount') bool bindAbAccount
});




}
/// @nodoc
class __$AstroBoxManifestAuthorCopyWithImpl<$Res>
    implements _$AstroBoxManifestAuthorCopyWith<$Res> {
  __$AstroBoxManifestAuthorCopyWithImpl(this._self, this._then);

  final _AstroBoxManifestAuthor _self;
  final $Res Function(_AstroBoxManifestAuthor) _then;

/// Create a copy of AstroBoxManifestAuthor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? bindAbAccount = null,}) {
  return _then(_AstroBoxManifestAuthor(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bindAbAccount: null == bindAbAccount ? _self.bindAbAccount : bindAbAccount // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AstroBoxManifestLink {

 String? get icon; String get title; String get url;
/// Create a copy of AstroBoxManifestLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxManifestLinkCopyWith<AstroBoxManifestLink> get copyWith => _$AstroBoxManifestLinkCopyWithImpl<AstroBoxManifestLink>(this as AstroBoxManifestLink, _$identity);

  /// Serializes this AstroBoxManifestLink to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxManifestLink&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,icon,title,url);

@override
String toString() {
  return 'AstroBoxManifestLink(icon: $icon, title: $title, url: $url)';
}


}

/// @nodoc
abstract mixin class $AstroBoxManifestLinkCopyWith<$Res>  {
  factory $AstroBoxManifestLinkCopyWith(AstroBoxManifestLink value, $Res Function(AstroBoxManifestLink) _then) = _$AstroBoxManifestLinkCopyWithImpl;
@useResult
$Res call({
 String? icon, String title, String url
});




}
/// @nodoc
class _$AstroBoxManifestLinkCopyWithImpl<$Res>
    implements $AstroBoxManifestLinkCopyWith<$Res> {
  _$AstroBoxManifestLinkCopyWithImpl(this._self, this._then);

  final AstroBoxManifestLink _self;
  final $Res Function(AstroBoxManifestLink) _then;

/// Create a copy of AstroBoxManifestLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? icon = freezed,Object? title = null,Object? url = null,}) {
  return _then(_self.copyWith(
icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AstroBoxManifestLink].
extension AstroBoxManifestLinkPatterns on AstroBoxManifestLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxManifestLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxManifestLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxManifestLink value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxManifestLink value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? icon,  String title,  String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxManifestLink() when $default != null:
return $default(_that.icon,_that.title,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? icon,  String title,  String url)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestLink():
return $default(_that.icon,_that.title,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? icon,  String title,  String url)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestLink() when $default != null:
return $default(_that.icon,_that.title,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxManifestLink implements AstroBoxManifestLink {
  const _AstroBoxManifestLink({this.icon, required this.title, required this.url});
  factory _AstroBoxManifestLink.fromJson(Map<String, dynamic> json) => _$AstroBoxManifestLinkFromJson(json);

@override final  String? icon;
@override final  String title;
@override final  String url;

/// Create a copy of AstroBoxManifestLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxManifestLinkCopyWith<_AstroBoxManifestLink> get copyWith => __$AstroBoxManifestLinkCopyWithImpl<_AstroBoxManifestLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxManifestLinkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxManifestLink&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,icon,title,url);

@override
String toString() {
  return 'AstroBoxManifestLink(icon: $icon, title: $title, url: $url)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxManifestLinkCopyWith<$Res> implements $AstroBoxManifestLinkCopyWith<$Res> {
  factory _$AstroBoxManifestLinkCopyWith(_AstroBoxManifestLink value, $Res Function(_AstroBoxManifestLink) _then) = __$AstroBoxManifestLinkCopyWithImpl;
@override @useResult
$Res call({
 String? icon, String title, String url
});




}
/// @nodoc
class __$AstroBoxManifestLinkCopyWithImpl<$Res>
    implements _$AstroBoxManifestLinkCopyWith<$Res> {
  __$AstroBoxManifestLinkCopyWithImpl(this._self, this._then);

  final _AstroBoxManifestLink _self;
  final $Res Function(_AstroBoxManifestLink) _then;

/// Create a copy of AstroBoxManifestLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? icon = freezed,Object? title = null,Object? url = null,}) {
  return _then(_AstroBoxManifestLink(
icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AstroBoxManifestDownload {

 String get version;@JsonKey(name: 'file_name') String get fileName;@JsonKey(name: 'version_code', fromJson: _versionCodeFromJson) int? get versionCode; String? get url; String? get sha256; String? get displayName;
/// Create a copy of AstroBoxManifestDownload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxManifestDownloadCopyWith<AstroBoxManifestDownload> get copyWith => _$AstroBoxManifestDownloadCopyWithImpl<AstroBoxManifestDownload>(this as AstroBoxManifestDownload, _$identity);

  /// Serializes this AstroBoxManifestDownload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxManifestDownload&&(identical(other.version, version) || other.version == version)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.url, url) || other.url == url)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,fileName,versionCode,url,sha256,displayName);

@override
String toString() {
  return 'AstroBoxManifestDownload(version: $version, fileName: $fileName, versionCode: $versionCode, url: $url, sha256: $sha256, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class $AstroBoxManifestDownloadCopyWith<$Res>  {
  factory $AstroBoxManifestDownloadCopyWith(AstroBoxManifestDownload value, $Res Function(AstroBoxManifestDownload) _then) = _$AstroBoxManifestDownloadCopyWithImpl;
@useResult
$Res call({
 String version,@JsonKey(name: 'file_name') String fileName,@JsonKey(name: 'version_code', fromJson: _versionCodeFromJson) int? versionCode, String? url, String? sha256, String? displayName
});




}
/// @nodoc
class _$AstroBoxManifestDownloadCopyWithImpl<$Res>
    implements $AstroBoxManifestDownloadCopyWith<$Res> {
  _$AstroBoxManifestDownloadCopyWithImpl(this._self, this._then);

  final AstroBoxManifestDownload _self;
  final $Res Function(AstroBoxManifestDownload) _then;

/// Create a copy of AstroBoxManifestDownload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? fileName = null,Object? versionCode = freezed,Object? url = freezed,Object? sha256 = freezed,Object? displayName = freezed,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,versionCode: freezed == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AstroBoxManifestDownload].
extension AstroBoxManifestDownloadPatterns on AstroBoxManifestDownload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxManifestDownload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxManifestDownload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxManifestDownload value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestDownload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxManifestDownload value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxManifestDownload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version, @JsonKey(name: 'file_name')  String fileName, @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)  int? versionCode,  String? url,  String? sha256,  String? displayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxManifestDownload() when $default != null:
return $default(_that.version,_that.fileName,_that.versionCode,_that.url,_that.sha256,_that.displayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version, @JsonKey(name: 'file_name')  String fileName, @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)  int? versionCode,  String? url,  String? sha256,  String? displayName)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestDownload():
return $default(_that.version,_that.fileName,_that.versionCode,_that.url,_that.sha256,_that.displayName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version, @JsonKey(name: 'file_name')  String fileName, @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)  int? versionCode,  String? url,  String? sha256,  String? displayName)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxManifestDownload() when $default != null:
return $default(_that.version,_that.fileName,_that.versionCode,_that.url,_that.sha256,_that.displayName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxManifestDownload implements AstroBoxManifestDownload {
  const _AstroBoxManifestDownload({required this.version, @JsonKey(name: 'file_name') required this.fileName, @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson) this.versionCode, this.url, this.sha256, this.displayName});
  factory _AstroBoxManifestDownload.fromJson(Map<String, dynamic> json) => _$AstroBoxManifestDownloadFromJson(json);

@override final  String version;
@override@JsonKey(name: 'file_name') final  String fileName;
@override@JsonKey(name: 'version_code', fromJson: _versionCodeFromJson) final  int? versionCode;
@override final  String? url;
@override final  String? sha256;
@override final  String? displayName;

/// Create a copy of AstroBoxManifestDownload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxManifestDownloadCopyWith<_AstroBoxManifestDownload> get copyWith => __$AstroBoxManifestDownloadCopyWithImpl<_AstroBoxManifestDownload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxManifestDownloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxManifestDownload&&(identical(other.version, version) || other.version == version)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.url, url) || other.url == url)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,fileName,versionCode,url,sha256,displayName);

@override
String toString() {
  return 'AstroBoxManifestDownload(version: $version, fileName: $fileName, versionCode: $versionCode, url: $url, sha256: $sha256, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxManifestDownloadCopyWith<$Res> implements $AstroBoxManifestDownloadCopyWith<$Res> {
  factory _$AstroBoxManifestDownloadCopyWith(_AstroBoxManifestDownload value, $Res Function(_AstroBoxManifestDownload) _then) = __$AstroBoxManifestDownloadCopyWithImpl;
@override @useResult
$Res call({
 String version,@JsonKey(name: 'file_name') String fileName,@JsonKey(name: 'version_code', fromJson: _versionCodeFromJson) int? versionCode, String? url, String? sha256, String? displayName
});




}
/// @nodoc
class __$AstroBoxManifestDownloadCopyWithImpl<$Res>
    implements _$AstroBoxManifestDownloadCopyWith<$Res> {
  __$AstroBoxManifestDownloadCopyWithImpl(this._self, this._then);

  final _AstroBoxManifestDownload _self;
  final $Res Function(_AstroBoxManifestDownload) _then;

/// Create a copy of AstroBoxManifestDownload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? fileName = null,Object? versionCode = freezed,Object? url = freezed,Object? sha256 = freezed,Object? displayName = freezed,}) {
  return _then(_AstroBoxManifestDownload(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,versionCode: freezed == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AstroBoxDeviceMap {

 Map<String, AstroBoxDevice> get xiaomi;
/// Create a copy of AstroBoxDeviceMap
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxDeviceMapCopyWith<AstroBoxDeviceMap> get copyWith => _$AstroBoxDeviceMapCopyWithImpl<AstroBoxDeviceMap>(this as AstroBoxDeviceMap, _$identity);

  /// Serializes this AstroBoxDeviceMap to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxDeviceMap&&const DeepCollectionEquality().equals(other.xiaomi, xiaomi));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(xiaomi));

@override
String toString() {
  return 'AstroBoxDeviceMap(xiaomi: $xiaomi)';
}


}

/// @nodoc
abstract mixin class $AstroBoxDeviceMapCopyWith<$Res>  {
  factory $AstroBoxDeviceMapCopyWith(AstroBoxDeviceMap value, $Res Function(AstroBoxDeviceMap) _then) = _$AstroBoxDeviceMapCopyWithImpl;
@useResult
$Res call({
 Map<String, AstroBoxDevice> xiaomi
});




}
/// @nodoc
class _$AstroBoxDeviceMapCopyWithImpl<$Res>
    implements $AstroBoxDeviceMapCopyWith<$Res> {
  _$AstroBoxDeviceMapCopyWithImpl(this._self, this._then);

  final AstroBoxDeviceMap _self;
  final $Res Function(AstroBoxDeviceMap) _then;

/// Create a copy of AstroBoxDeviceMap
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? xiaomi = null,}) {
  return _then(_self.copyWith(
xiaomi: null == xiaomi ? _self.xiaomi : xiaomi // ignore: cast_nullable_to_non_nullable
as Map<String, AstroBoxDevice>,
  ));
}

}


/// Adds pattern-matching-related methods to [AstroBoxDeviceMap].
extension AstroBoxDeviceMapPatterns on AstroBoxDeviceMap {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxDeviceMap value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxDeviceMap() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxDeviceMap value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxDeviceMap():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxDeviceMap value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxDeviceMap() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, AstroBoxDevice> xiaomi)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxDeviceMap() when $default != null:
return $default(_that.xiaomi);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, AstroBoxDevice> xiaomi)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxDeviceMap():
return $default(_that.xiaomi);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, AstroBoxDevice> xiaomi)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxDeviceMap() when $default != null:
return $default(_that.xiaomi);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxDeviceMap implements AstroBoxDeviceMap {
  const _AstroBoxDeviceMap({final  Map<String, AstroBoxDevice> xiaomi = const {}}): _xiaomi = xiaomi;
  factory _AstroBoxDeviceMap.fromJson(Map<String, dynamic> json) => _$AstroBoxDeviceMapFromJson(json);

 final  Map<String, AstroBoxDevice> _xiaomi;
@override@JsonKey() Map<String, AstroBoxDevice> get xiaomi {
  if (_xiaomi is EqualUnmodifiableMapView) return _xiaomi;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_xiaomi);
}


/// Create a copy of AstroBoxDeviceMap
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxDeviceMapCopyWith<_AstroBoxDeviceMap> get copyWith => __$AstroBoxDeviceMapCopyWithImpl<_AstroBoxDeviceMap>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxDeviceMapToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxDeviceMap&&const DeepCollectionEquality().equals(other._xiaomi, _xiaomi));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_xiaomi));

@override
String toString() {
  return 'AstroBoxDeviceMap(xiaomi: $xiaomi)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxDeviceMapCopyWith<$Res> implements $AstroBoxDeviceMapCopyWith<$Res> {
  factory _$AstroBoxDeviceMapCopyWith(_AstroBoxDeviceMap value, $Res Function(_AstroBoxDeviceMap) _then) = __$AstroBoxDeviceMapCopyWithImpl;
@override @useResult
$Res call({
 Map<String, AstroBoxDevice> xiaomi
});




}
/// @nodoc
class __$AstroBoxDeviceMapCopyWithImpl<$Res>
    implements _$AstroBoxDeviceMapCopyWith<$Res> {
  __$AstroBoxDeviceMapCopyWithImpl(this._self, this._then);

  final _AstroBoxDeviceMap _self;
  final $Res Function(_AstroBoxDeviceMap) _then;

/// Create a copy of AstroBoxDeviceMap
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? xiaomi = null,}) {
  return _then(_AstroBoxDeviceMap(
xiaomi: null == xiaomi ? _self._xiaomi : xiaomi // ignore: cast_nullable_to_non_nullable
as Map<String, AstroBoxDevice>,
  ));
}


}


/// @nodoc
mixin _$AstroBoxDevice {

 String get id; String get name; String get description; AstroBoxDeviceChip get chip; bool get fetch;
/// Create a copy of AstroBoxDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AstroBoxDeviceCopyWith<AstroBoxDevice> get copyWith => _$AstroBoxDeviceCopyWithImpl<AstroBoxDevice>(this as AstroBoxDevice, _$identity);

  /// Serializes this AstroBoxDevice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AstroBoxDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.chip, chip) || other.chip == chip)&&(identical(other.fetch, fetch) || other.fetch == fetch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,chip,fetch);

@override
String toString() {
  return 'AstroBoxDevice(id: $id, name: $name, description: $description, chip: $chip, fetch: $fetch)';
}


}

/// @nodoc
abstract mixin class $AstroBoxDeviceCopyWith<$Res>  {
  factory $AstroBoxDeviceCopyWith(AstroBoxDevice value, $Res Function(AstroBoxDevice) _then) = _$AstroBoxDeviceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, AstroBoxDeviceChip chip, bool fetch
});




}
/// @nodoc
class _$AstroBoxDeviceCopyWithImpl<$Res>
    implements $AstroBoxDeviceCopyWith<$Res> {
  _$AstroBoxDeviceCopyWithImpl(this._self, this._then);

  final AstroBoxDevice _self;
  final $Res Function(AstroBoxDevice) _then;

/// Create a copy of AstroBoxDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? chip = null,Object? fetch = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,chip: null == chip ? _self.chip : chip // ignore: cast_nullable_to_non_nullable
as AstroBoxDeviceChip,fetch: null == fetch ? _self.fetch : fetch // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AstroBoxDevice].
extension AstroBoxDevicePatterns on AstroBoxDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AstroBoxDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AstroBoxDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AstroBoxDevice value)  $default,){
final _that = this;
switch (_that) {
case _AstroBoxDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AstroBoxDevice value)?  $default,){
final _that = this;
switch (_that) {
case _AstroBoxDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  AstroBoxDeviceChip chip,  bool fetch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AstroBoxDevice() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.chip,_that.fetch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  AstroBoxDeviceChip chip,  bool fetch)  $default,) {final _that = this;
switch (_that) {
case _AstroBoxDevice():
return $default(_that.id,_that.name,_that.description,_that.chip,_that.fetch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  AstroBoxDeviceChip chip,  bool fetch)?  $default,) {final _that = this;
switch (_that) {
case _AstroBoxDevice() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.chip,_that.fetch);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AstroBoxDevice implements AstroBoxDevice {
  const _AstroBoxDevice({required this.id, required this.name, required this.description, required this.chip, this.fetch = false});
  factory _AstroBoxDevice.fromJson(Map<String, dynamic> json) => _$AstroBoxDeviceFromJson(json);

@override final  String id;
@override final  String name;
@override final  String description;
@override final  AstroBoxDeviceChip chip;
@override@JsonKey() final  bool fetch;

/// Create a copy of AstroBoxDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AstroBoxDeviceCopyWith<_AstroBoxDevice> get copyWith => __$AstroBoxDeviceCopyWithImpl<_AstroBoxDevice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AstroBoxDeviceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AstroBoxDevice&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.chip, chip) || other.chip == chip)&&(identical(other.fetch, fetch) || other.fetch == fetch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,chip,fetch);

@override
String toString() {
  return 'AstroBoxDevice(id: $id, name: $name, description: $description, chip: $chip, fetch: $fetch)';
}


}

/// @nodoc
abstract mixin class _$AstroBoxDeviceCopyWith<$Res> implements $AstroBoxDeviceCopyWith<$Res> {
  factory _$AstroBoxDeviceCopyWith(_AstroBoxDevice value, $Res Function(_AstroBoxDevice) _then) = __$AstroBoxDeviceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, AstroBoxDeviceChip chip, bool fetch
});




}
/// @nodoc
class __$AstroBoxDeviceCopyWithImpl<$Res>
    implements _$AstroBoxDeviceCopyWith<$Res> {
  __$AstroBoxDeviceCopyWithImpl(this._self, this._then);

  final _AstroBoxDevice _self;
  final $Res Function(_AstroBoxDevice) _then;

/// Create a copy of AstroBoxDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? chip = null,Object? fetch = null,}) {
  return _then(_AstroBoxDevice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,chip: null == chip ? _self.chip : chip // ignore: cast_nullable_to_non_nullable
as AstroBoxDeviceChip,fetch: null == fetch ? _self.fetch : fetch // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
