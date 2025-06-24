const express = require('express');
const cors = require('cors');

const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
app.use(cors());

app.use('/search', createProxyMiddleware({
  target: 'https://fundgz.1234567.com.cn',
  changeOrigin: true,
  secure: false, // 关闭 SSL 校验，仅用于开发环境
  logLevel: 'debug',
}));
app.use('/api', createProxyMiddleware({
  target: 'https://api.fund.eastmoney.com',
  changeOrigin: true,
  secure: false, // 关闭 SSL 校验，仅用于开发环境
  logLevel: 'debug',
}));

app.listen(8080, () => console.log('Proxy server listening on port 8080'));
/*
使用上述代理后，前端请求应指向代理服务器地址。例如：

http://localhost:8080/js/$fundCode.js

代理服务器会将请求转发到 https://fundgz.1234567.com.cn/js/$fundCode.js
*/
app.use((req, res, next) => {
    console.log(`Proxying request to: ${req.protocol}://${req.get('host')}${req.originalUrl}`);
    next();
});

