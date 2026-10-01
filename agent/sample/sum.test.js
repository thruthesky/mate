import {test} from 'node:test';
import assert from 'node:assert/strict';
import {sum} from './sum.js';
test('sum adds two positive numbers', () => assert.equal(sum(2, 3), 5));
test('sum handles negative numbers', () => assert.equal(sum(-2, 3), 1));
test('sum handles zero', () => assert.equal(sum(0, 0), 0));
