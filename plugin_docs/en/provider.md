# provider — Resource Provider

Plugins can register as resource sources to feed downloadable resources into
ZeroBox's resource library. Use cases: community repos, private catalogs, etc.

## register(definition)

```js
await ZeroBox.provider.register({
  id: 'org.example.source',     // Unique reverse-domain ID
  name: 'Example Source',       // Display name
  categories: async () => [     // Optional category list
    { id: 'watch', name: 'Watchfaces' },
    { id: 'app', name: 'Apps' }
  ],
  query: async (query) => {     // Search / list
    // query = { keyword: '', category: 'watch', page: 1,
    //           order: 'last_update', direction: 'desc' }
    return {
      items: [{
        id: 'res-001', name: 'Classic Watchface',
        type: 'watchface', author: 'Author',
        version: '1.0', paidType: 'free'
      }],
      hasMore: false, total: 1
    };
  },
  detail: async ({ id }) => ({ // Resource detail
    id, name: 'Classic Watchface',
    type: 'watchface',         // quickApp | watchface | firmware | fontpack | iconpack
    version: '1.0', paidType: 'free',
    authors: ['Author'],
    description: '...',
    supportedDevices: [{ name: 'Xiaomi Smart Band 9 Pro', codename: 'n67', platform: 'vela' }],
    files: [{ id: 'f1', name: 'file.bin', size: 102400, fileName: 'file.bin' }],
    content: { format: 'plainText', value: 'Details...' }
  }),
  download: async ({ id, fileId, targetDevice }) => ({
    path: '/cache/file.bin',   // Must be in this plugin's sandbox
    fileName: 'file.bin'
  })
});
```

### unregister(id)

```js
await ZeroBox.provider.unregister('org.example.source');
```

## Permission

Declare `provider`. Medium-risk.
