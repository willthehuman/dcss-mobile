// Helpers for Dart dart:js_interop @JS() externs.
// Must be loaded before flutter_bootstrap.js so all symbols are on window.
window._newDecompressionStream = function(format) {
  return new DecompressionStream(format);
};
window._jsProp = function(obj, prop) {
  return obj[prop];
};
window._jsCall0 = function(obj, method) {
  return obj[method]();
};
window._jsCall1Void = function(obj, method, arg) {
  obj[method](arg);
};
window._jsCallPromise0 = function(obj, method) {
  return obj[method]();
};
