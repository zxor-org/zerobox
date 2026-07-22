# provider — 资源提供者

插件可以注册为资源源，向 ZeroBox 资源库提供可下载的资源。典型用途：
接入第三方社区源、私有资源库等。

## 注册

### register(definition)

```js
await ZeroBox.provider.register({
  id: 'org.example.source',     // 唯一标识，反向域名格式
  name: '示例资源源',             // 显示名称
  categories: async () => [      // 可选，返回分区列表
    { id: 'watch', name: '表盘' },
    { id: 'app', name: '应用' }
  ],
  query: async (query) => {      // 搜索/列表
    // query = { keyword: '', category: 'watch', page: 1,
    //           order: 'last_update', direction: 'desc' }
    return {
      items: [{
        id: 'res-001',
        name: '经典表盘',
        type: 'watchface',
        author: '作者名',
        version: '1.0',
        description: '简洁经典的表盘',
        thumbnail: base64Image,  // 可选，Base64 缩略图
        paidType: 'free',        // free | paid | forcePaid
        price: '0.00',
        createdAt: '2024-01-01',
        updatedAt: '2024-01-15'
      }],
      hasMore: false,
      total: 1
    };
  },
  detail: async ({ id }) => ({  // 资源详情
    id,
    name: '经典表盘',
    type: 'watchface',           // quickApp | watchface | firmware | fontpack | iconpack
    version: '1.0',
    paidType: 'free',
    authors: ['作者名'],
    description: '详细描述...',
    supportedDevices: [{         // 支持的设备
      name: 'Xiaomi Smart Band 9 Pro',
      codename: 'n67',
      platform: 'vela'
    }],
    files: [{                    // 下载包
      id: 'file-001',
      name: '表盘文件',
      size: 102400,
      fileName: 'watchface.bin'
    }],
    content: {                   // 详情页内容
      format: 'plainText',       // plainText | html
      value: '更多介绍...'
    }
  }),
  download: async ({ id, fileId, targetDevice }) => ({
    // 必须返回本插件沙箱内的文件路径
    path: '/cache/watchface.bin',
    fileName: 'watchface.bin'
  })
});
```

### unregister(id)

取消注册。

```js
await ZeroBox.provider.unregister('org.example.source');
```

## 完整示例：静态资源源

```js
globalThis.activate = async (plugin) => {
  await ZeroBox.provider.register({
    id: 'com.example.mysource',
    name: '我的资源源',
    categories: async () => [
      { id: 'watch', name: '表盘' }
    ],
    query: async (query) => ({
      items: [{
        id: 'demo-1',
        name: 'Demo Watchface',
        type: 'watchface',
        author: 'Demo',
        version: '1.0',
        paidType: 'free'
      }],
      hasMore: false,
      total: 1
    }),
    detail: async ({ id }) => ({
      id, name: 'Demo Watchface', type: 'watchface',
      version: '1.0', paidType: 'free',
      authors: ['Demo'],
      supportedDevices: [],
      files: [{ id: 'f1', name: 'file.bin', size: 0, fileName: 'file.bin' }],
      content: { format: 'plainText', value: 'Demo resource' }
    }),
    download: async () => ({
      path: '/data/dummy.bin',
      fileName: 'dummy.bin'
    })
  });
};
```

注册后，ZeroBox 资源库的「资源源」下拉菜单中会出现「我的资源源」。

## 权限

声明 `provider` 许可，中等风险。
