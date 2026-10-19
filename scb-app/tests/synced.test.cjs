const test = require('node:test');
const assert = require('node:assert/strict');
const React = require('react');
const { create, act } = require('react-test-renderer');
let canEdit = true;
const load = require('./load-ts.cjs')({ '../session-context': { useSession: () => ({ canEdit, toast() {} }) } });
const { useSynced } = load('src/lib/useSynced.ts');
const { mergeEdits } = load('src/lib/merge.ts');
const { retrySaves } = load('src/lib/save-status.ts');
let api;
function Harness({ remote, save }) { api = useSynced(remote, save); return null; }
const render = (remote, save) => create(React.createElement(Harness, { remote, save }));

test('idle remote changes are reflected', async () => {
  let root;
  await act(async () => { root = render({ a: 1 }, async (v) => v); });
  await act(async () => { root.update(React.createElement(Harness, { remote: { a: 2 }, save: async (v) => v })); });
  assert.deepEqual(api[0], { a: 2 });
  await act(async () => root.unmount());
});
test('remote update during typing survives through the edit base', async () => {
  let root; let server = { a: 'old', b: 'old' };
  const save = async (v, base) => (server = mergeEdits(base, v, server));
  await act(async () => { root = render(server, save); });
  await act(async () => api[1]((v) => ({ ...v, a: 'mine' })));
  server = { a: 'old', b: 'theirs' };
  await act(async () => root.update(React.createElement(Harness, { remote: server, save })));
  await act(async () => api[2]());
  assert.deepEqual(api[0], { a: 'mine', b: 'theirs' });
  await act(async () => root.unmount());
});
test('failed save keeps draft and can retry', async () => {
  let root; let attempts = 0;
  const save = async (v) => { if (++attempts === 1) throw new Error('offline'); return v; };
  await act(async () => { root = render('old', save); });
  await act(async () => api[1]('new'));
  await act(async () => api[2]());
  assert.equal(api[0], 'new');
  await act(async () => { retrySaves(); await Promise.resolve(); });
  assert.equal(attempts, 2);
  assert.equal(api[0], 'new');
  await act(async () => root.unmount());
});
test('edits while saving are sent serially with acknowledged base', async () => {
  let root; let release; const calls = [];
  const save = async (v, base) => {
    calls.push([v, base]);
    if (calls.length === 1) await new Promise((r) => { release = r; });
    return v;
  };
  await act(async () => { root = render('old', save); });
  await act(async () => api[1]('first'));
  let request;
  act(() => { request = api[2](); });
  await act(async () => api[1]('second'));
  await act(async () => { release(); await request; });
  assert.deepEqual(calls, [['first', 'old'], ['second', 'first']]);
  assert.equal(api[0], 'second');
  await act(async () => root.unmount());
});
test('leaving a tab flushes outstanding draft', async () => {
  let root; const saved = [];
  await act(async () => { root = render('old', async (v) => { saved.push(v); return v; }); });
  await act(async () => api[1]('new'));
  await act(async () => root.unmount());
  assert.deepEqual(saved, ['new']);
});
test('viewer cannot change a draft', async () => {
  canEdit = false; let root;
  await act(async () => { root = render('old', async (v) => v); });
  await act(async () => api[1]('new'));
  assert.equal(api[0], 'old');
  await act(async () => root.unmount());
  canEdit = true;
});
