#!/usr/bin/env python3
"""
Простой веб-сервер на чистом Python без зависимостей.
Отдает HTML, CSS и обрабатывает API-запросы.
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
from urllib.parse import urlparse, parse_qs


class SimpleHandler(BaseHTTPRequestHandler):
    """Обработчик HTTP-запросов"""
    
    def do_GET(self):
        """Обработка GET-запросов"""
        parsed = urlparse(self.path)
        path = parsed.path
        
        # API-эндпоинты
        if path == '/api/status':
            self.send_json_response({
                'status': 'ok',
                'message': 'Server is running',
                'version': '1.0.0'
            })
            return
            
        if path == '/api/health':
            self.send_json_response({
                'status': 'healthy',
                'uptime': 'unknown'
            })
            return
            
        if path == '/api/info':
            self.send_json_response({
                'service': 'my-service',
                'description': 'Simple web server',
                'port': self.server.server_port
            })
            return
        
        # Отдаем HTML-страницу для корня
        if path == '/' or path == '/index.html':
            self.send_html_response()
            return
        
        # Отдаем CSS файл
        if path == '/style.css':
            self.send_css_response()
            return
        
        # Если ничего не подошло - 404
        self.send_error_response(404, 'Not Found')
    
    def do_POST(self):
        """Обработка POST-запросов"""
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/api/echo':
            # Читаем тело запроса
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                self.send_json_response({
                    'echo': data,
                    'received': True
                })
            except:
                self.send_json_response({
                    'error': 'Invalid JSON',
                    'received': post_data.decode('utf-8', errors='ignore')
                }, status=400)
            return
        
        # Если ничего не подошло - 404
        self.send_error_response(404, 'Not Found')
    
    def send_json_response(self, data, status=200):
        """Отправка JSON-ответа"""
        response = json.dumps(data, indent=2)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response.encode('utf-8'))))
        self.end_headers()
        self.wfile.write(response.encode('utf-8'))
    
    def send_html_response(self):
        """Отправка HTML-страницы"""
        html = self.get_html_content()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(html.encode('utf-8'))))
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))
    
    def send_css_response(self):
        """Отправка CSS"""
        css = self.get_css_content()
        self.send_response(200)
        self.send_header('Content-Type', 'text/css; charset=utf-8')
        self.send_header('Content-Length', str(len(css.encode('utf-8'))))
        self.end_headers()
        self.wfile.write(css.encode('utf-8'))
    
    def send_error_response(self, code, message):
        """Отправка ошибки"""
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.end_headers()
        self.wfile.write(f'Error {code}: {message}'.encode('utf-8'))
    
    def get_html_content(self):
        """Возвращает HTML-контент"""
        return """<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Мой сервис</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>
    <div class="container">
        <h1>🚀 Мой сервер работает!</h1>
        <p>Это минималистичный веб-сервер на чистом Python.</p>
        
        <div class="card">
            <h2>API Эндпоинты:</h2>
            <ul>
                <li><code>GET /api/status</code> - статус сервера</li>
                <li><code>GET /api/health</code> - проверка здоровья</li>
                <li><code>GET /api/info</code> - информация о сервисе</li>
                <li><code>POST /api/echo</code> - отправить JSON и получить его обратно</li>
            </ul>
        </div>
        
        <div class="card">
            <h2>Тест API:</h2>
            <button onclick="testStatus()">Проверить статус</button>
            <button onclick="testEcho()">Отправить эхо</button>
            <div id="result" class="result"></div>
        </div>
    </div>
    
    <script>
        function testStatus() {
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('result').innerHTML = 
                        `<pre>${JSON.stringify(data, null, 2)}</pre>`;
                })
                .catch(error => {
                    document.getElementById('result').innerHTML = 
                        `<span class="error">Ошибка: ${error}</span>`;
                });
        }
        
        function testEcho() {
            const data = { message: "Hello from browser!", timestamp: Date.now() };
            fetch('/api/echo', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data)
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('result').innerHTML = 
                    `<pre>${JSON.stringify(data, null, 2)}</pre>`;
            })
            .catch(error => {
                document.getElementById('result').innerHTML = 
                    `<span class="error">Ошибка: ${error}</span>`;
            });
        }
    </script>
</body>
</html>"""
    
    def get_css_content(self):
        """Возвращает CSS-контент"""
        return """* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
}

.container {
    background: white;
    border-radius: 20px;
    padding: 40px;
    max-width: 600px;
    width: 100%;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
}

h1 {
    color: #333;
    margin-bottom: 10px;
    font-size: 28px;
}

h2 {
    color: #555;
    font-size: 18px;
    margin-bottom: 15px;
}

p {
    color: #666;
    margin-bottom: 20px;
}

.card {
    background: #f8f9fa;
    border-radius: 10px;
    padding: 20px;
    margin-bottom: 20px;
}

ul {
    list-style: none;
    padding: 0;
}

li {
    padding: 8px 0;
    border-bottom: 1px solid #eee;
    font-size: 14px;
}

li:last-child {
    border-bottom: none;
}

code {
    background: #e9ecef;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 13px;
    color: #495057;
}

button {
    background: #667eea;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 14px;
    cursor: pointer;
    transition: background 0.3s;
    margin-right: 10px;
}

button:hover {
    background: #5a67d8;
}

.result {
    margin-top: 15px;
    padding: 15px;
    background: #f1f3f5;
    border-radius: 8px;
    min-height: 50px;
}

.result pre {
    background: #2d3748;
    color: #e2e8f0;
    padding: 15px;
    border-radius: 6px;
    overflow-x: auto;
    font-size: 13px;
}

.error {
    color: #e53e3e;
    font-weight: bold;
}
"""


def run_server(port=8080):
    """Запуск HTTP-сервера"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, SimpleHandler)
    
    print(f'🚀 Сервер запущен на http://localhost:{port}')
    print(f'📡 Открывай в браузере: http://localhost:{port}')
    print(f'🛑 Для остановки нажми Ctrl+C')
    print('-' * 50)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\n👋 Сервер остановлен')
        httpd.shutdown()


if __name__ == '__main__':
    run_server()
