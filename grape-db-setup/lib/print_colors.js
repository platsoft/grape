
var colors = require('colors');

var level = 0;

function print_info (str) { console.error("  ".repeat(level) + colors.blue(str)); }
function print_ok (str) { console.error("  ".repeat(level) + colors.green(str)); }
function print_warn (str) { console.error("  ".repeat(level) + colors.yellow(str)); }
function print_err (str) { console.error("  ".repeat(level) + colors.red(str)); }

module.exports.level = level;
module.exports.print_info = print_info;
module.exports.print_ok = print_ok;
module.exports.print_warn = print_warn;
module.exports.print_err = print_err;

