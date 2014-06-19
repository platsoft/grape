
var Grape = require('grape');

var config = require('./config.js');

var app = new Grape.grape(config); 

app.start();


