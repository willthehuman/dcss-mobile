// Helper for Dart js_interop: ensures DecompressionStream is called with 'new'.
window._newDecompressionStream = function(format) {
  return new DecompressionStream(format);
};
