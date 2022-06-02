const http = require('http');
http.createServer(function (req, res) {
    console.log(req.method + " " + req.url);
    res.write("<h1>Hello World!</h1>\n");
    res.end();
}).listen(3000);