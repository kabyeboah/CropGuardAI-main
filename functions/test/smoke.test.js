const test = require("node:test");
const assert = require("node:assert/strict");

test("Smoke test Node test runner", () => {
  assert.equal(1 + 1, 2);
});
