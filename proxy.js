const express = require('express');
const cors = require('cors');
const request = require('request');

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

app.use('/find', createProxyMiddleware({
  target: 'https://www.dayfund.cn',
  changeOrigin: true,
  secure: false, // 关闭 SSL 校验，仅用于开发环境
  logLevel: 'debug',
}));

app.use('/eastmoney', createProxyMiddleware({
  target: 'https://fundf10.eastmoney.com',
  changeOrigin: true,
  secure: false, // 关闭 SSL 校验，仅用于开发环境
  logLevel: 'debug',
}));

// 基金新闻代理路由
app.get('/news/fund_news', (req, res) => {
  const fundCode = req.query.fundCode;
  if (!fundCode) {
    return res.status(400).send('Missing fundCode parameter');
  }

  // 天天基金网基金新闻页面URL
  const url = `https://fund.eastmoney.com/news,${fundCode},cn.html`;
  
  // 设置请求头以模拟浏览器访问
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    'Referer': 'https://fund.eastmoney.com/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  // 发起请求
  request({ url, headers }, (error, response, body) => {
    if (error) {
      console.error('Error fetching fund news:', error);
      return res.status(500).send('Error fetching fund news');
    }

    if (response.statusCode !== 200) {
      console.error('Error response from fund news:', response.statusCode);
      return res.status(response.statusCode).send('Error response from fund news');
    }

    // 返回获取到的HTML内容
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.send(body);
  });
});

// 持仓股票新闻代理路由
app.get('/news/holdings_news', (req, res) => {
  const stockCodes = req.query.stockCodes;
  if (!stockCodes) {
    return res.status(400).send('Missing stockCodes parameter');
  }

  // 将股票代码转换为数组
  const codes = stockCodes.split(',');
  if (codes.length === 0) {
    return res.status(400).send('Empty stockCodes parameter');
  }

  // 构造搜索关键词（使用第一个股票代码）
  const firstCode = codes[0];
  const url = `https://finance.eastmoney.com/news/s${firstCode}.html`;
  
  // 设置请求头以模拟浏览器访问
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    'Referer': 'https://finance.eastmoney.com/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  // 发起请求
  request({ url, headers }, (error, response, body) => {
    if (error) {
      console.error('Error fetching holdings news:', error);
      return res.status(500).send('Error fetching holdings news');
    }

    if (response.statusCode !== 200) {
      console.error('Error response from holdings news:', response.statusCode);
      return res.status(response.statusCode).send('Error response from holdings news');
    }

    // 返回获取到的HTML内容
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.send(body);
  });
});

// 单个股票新闻代理路由
app.get('/news/stock_news', (req, res) => {
  const stockCode = req.query.stockCode;
  if (!stockCode) {
    return res.status(400).send('Missing stockCode parameter');
  }

  // 东方财富网股票新闻页面URL
  const url = `https://finance.eastmoney.com/news,s${stockCode}.html`;
  
  // 设置请求头以模拟浏览器访问
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
    'Referer': 'https://finance.eastmoney.com/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  // 发起请求
  request({ url, headers }, (error, response, body) => {
    if (error) {
      console.error('Error fetching stock news:', error);
      return res.status(500).send('Error fetching stock news');
    }

    if (response.statusCode !== 200) {
      console.error('Error response from stock news:', response.statusCode);
      return res.status(response.statusCode).send('Error response from stock news');
    }

    // 返回获取到的HTML内容
    res.set('Content-Type', 'text/html; charset=utf-8');
    res.send(body);
  });
});

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