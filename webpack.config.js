const path = require('path');
const Dotenv = require('dotenv-webpack');

module.exports = {
  entry: './src/frontend/main.js',
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'src/frontend/public'),
  },
  target: 'web',
  mode: 'development',
  plugins: [
    new Dotenv()
  ],
  devServer: {
    static: {
      directory: path.join(__dirname, 'src/frontend/public'),
    },
    proxy: [{
      context: ['/api'],
      target: 'http://localhost:4943',
    }],
    hot: true,
    open: true
  },
  resolve: {
    alias: {
      '@dfinity/agent': path.resolve(__dirname, 'node_modules/@dfinity/agent'),
    },
  },
};