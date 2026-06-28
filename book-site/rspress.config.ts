import * as path from 'node:path';
import { defineConfig } from '@rspress/core';

export default defineConfig({
  root: path.join(__dirname, 'docs'),
  lang: 'zh',
  title: '如何设计内核：权限、调度与结构',
  description: '从零理解操作系统内核设计的三个基本模型',
  route: { cleanUrls: true },
  themeConfig: {
    socialLinks: [{
      icon: 'github', mode: 'link',
      content: 'https://github.com/dslsdzc/kernel-design-book',
    }],
    searchPlaceholderText: '搜索全书内容...',
    lastUpdated: true,
    prevPageText: '上一章',
    nextPageText: '下一章',
    outlineTitle: '本章目录',
  },
});
