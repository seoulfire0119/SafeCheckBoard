const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

module.exports = function loader(overrides = {}) {
  const cache = new Map();
  function load(filename) {
    filename = path.resolve(__dirname, '..', filename);
    if (!path.extname(filename)) filename += '.ts';
    if (cache.has(filename)) return cache.get(filename).exports;
    const module = { exports: {} };
    cache.set(filename, module);
    const source = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, jsx: ts.JsxEmit.ReactJSX },
    }).outputText;
    const localRequire = (name) => {
      if (name in overrides) return overrides[name];
      return name.startsWith('.') ? load(path.resolve(path.dirname(filename), name)) : require(name);
    };
    new Function('require', 'module', 'exports', source)(localRequire, module, module.exports);
    return module.exports;
  }
  return load;
};
