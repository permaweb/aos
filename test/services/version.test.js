import { mock, test } from 'node:test'
import * as assert from 'node:assert'
import { checkForUpdate } from '../../src/services/version.js'
import { STATUS_CODES } from 'node:http'

test('checkForUpdate() handles 404 response', async (context) => {
  fetch = context.mock.fn(fetch, () => {
    return {
      status: 404
    }
  })

  const actual = await checkForUpdate()
  assert.deepEqual(actual, { available: false })
})

test('checkForUpdate() handles 5xx responses', async (context) => {
  const statusCodes = Object
    .keys(STATUS_CODES)
    .filter((statusCode) => +statusCode >= 500 )
    .map((statusCode) => +statusCode)

  const statusContexts = statusCodes.map((statusCode) => {
    return {
      status: statusCode,
      expected: { available: false },
    }
  });

  for (const statusContext of statusContexts) {
    fetch = context.mock.fn(fetch, () => {
      return {
        status: statusContext.status,
      }
    })
  
    const actual = await checkForUpdate()
    assert.deepEqual(actual, statusContext.expected)
  }
})
