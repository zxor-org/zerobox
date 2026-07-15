# AstroBox v1 Legacy Compatibility

An `.abp` package without `runtime` is routed to the Legacy JavaScript adapter.
Like Wine, the adapter translates guest `AstroBox.*` calls into the canonical
ZeroBox v1 Host API. The new host still owns permissions, storage, networking,
device access, and lifecycle.

The Dart manager does not implement ABv1 method names or a second storage and
device stack. Legacy file pickers still expose only the original file name;
the adapter maps it to an imported `/temp` file internally. The unused ABv1
provider API is intentionally not emulated.
