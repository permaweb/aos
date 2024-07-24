import { describe, test } from 'node:test'
import * as assert from 'node:assert'
import fs from 'node:fs'

import AoLoader from '@permaweb/ao-loader'

const wasm = fs.readFileSync('./process.wasm')
const options = { format: 'wasm64-unknown-emscripten-draft_2024_02_15' }

const env = {
  Process: {
    Id: 'AOS',
    Owner: 'FOOBAR',
    Tags: [
      { name: 'Name', value: 'Thomas' }
    ]
  }
}

describe('add the assignable MatchSpec', async () => {
  test('by name', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable('foobar', function (msg) return true end)
        Send({ Target = "TEST", Data = { length = #ao.assignables, name = ao.assignables[1].name } })
      `
    }

    const result = await handle(null, msg, env)

    assert.deepStrictEqual(JSON.parse(result.Messages[0].Data), { length: 1, name: 'foobar' })
  })

  test('update by name', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable('foobar', function (msg) return true end)
        ao.addAssignable('foobar', function (msg) return false end)
        Send({ Target = "TEST", Data = { length = #ao.assignables, name = ao.assignables[1].name } })
      `
    }

    const result = await handle(null, msg, env)

    assert.deepStrictEqual(JSON.parse(result.Messages[0].Data), { length: 1, name: 'foobar' })
  })

  test('by index', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return true end)
        Send({ Target = "TEST", Data = { length = #ao.assignables, name = ao.assignables[1].name } })
      `
    }

    const result = await handle(null, msg, env)

    assert.deepStrictEqual(JSON.parse(result.Messages[0].Data), { length: 1 })
  })

  test('require name to be a string', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(1234, function (msg) return true end)
      `
    }

    const result = await handle(null, msg, env)

    assert.ok(result.Error.includes('MatchSpec name MUST be a string'))
  })
})

describe('remove the assignable MatchSpec', () => {
  test('by name', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return true end)
        ao.addAssignable('foobar', function (msg) return true end)
        Send({ Target = "TEST", Data = { length = #ao.assignables, name = ao.assignables[2].name } })

        ao.removeAssignable('foobar')
        Send({ Target = "TEST", Data = { length = #ao.assignables } })
      `
    }

    const result = await handle(null, msg, env)

    assert.deepStrictEqual(JSON.parse(result.Messages[0].Data), { length: 2, name: 'foobar' })
    assert.deepStrictEqual(JSON.parse(result.Messages[1].Data), { length: 1 })
  })

  test('by index', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return true end)
        ao.addAssignable('foobar', function (msg) return true end)
        Send({ Target = "TEST", Data = { length = #ao.assignables, name = ao.assignables[2].name } })

        ao.removeAssignable(1)
        Send({ Target = "TEST", Data = { length = #ao.assignables, name = ao.assignables[1].name } })
      `
    }

    const result = await handle(null, msg, env)

    assert.deepStrictEqual(JSON.parse(result.Messages[0].Data), { length: 2, name: 'foobar' })
    assert.deepStrictEqual(JSON.parse(result.Messages[1].Data), { length: 1, name: 'foobar' })
  })

  test('require name to be a string or number', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'AOS',
      From: 'FOOBAR',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.removeAssignable({})
      `
    }

    const result = await handle(null, msg, env)
    assert.ok(result.Error.includes('index MUST be a number'))
  })
})

describe('determine whether the msg is an assignment or not', () => {
  test('is an assignment', async () => {
    const handle = await AoLoader(wasm, options)

    const addAssignableMsg = {
      Target: 'AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return true end)
        Handlers.add(
          "IsAssignment", 
          function (Msg) return Msg.Action == 'IsAssignment' end, 
          function (Msg) 
            Send({ Target = 'TEST', Data = { id = Msg.Id, isAssignment = ao.isAssignment(Msg) } })
          end
        )
      `
    }

    const { Memory } = await handle(null, addAssignableMsg, env)

    const msg = {
      Target: 'NOT_AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'IsAssignment' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: 'foobar'
    }

    const result = await handle(Memory, msg, env)
    assert.deepStrictEqual(JSON.parse(result.Messages[0].Data), { id: '1234xyxfoo', isAssignment: true })
  })

  test('is NOT an assignment', async () => {
    const handle = await AoLoader(wasm, options)

    const addAssignableMsg = {
      Target: 'AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return true end)
        Handlers.add(
          "IsAssignment", 
          function (Msg) return Msg.Action == 'IsAssignment' end, 
          function (Msg) 
            Send({ Target = 'TEST', Data = { id = Msg.Id, isAssignment = ao.isAssignment(Msg) } })
          end
        )
      `
    }

    const { Memory } = await handle(null, addAssignableMsg, env)

    const msg = {
      Target: 'AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'IsAssignment' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: 'foobar'
    }

    const result = await handle(Memory, msg, env)

    assert.deepStrictEqual(JSON.parse(result.Messages[0].Data), { id: '1234xyxfoo', isAssignment: false })
  })
})

describe('run handles on assignment based on assignables configured', () => {
  test('at least 1 assignable allows specific assignment', async () => {
    const handle = await AoLoader(wasm, options)

    const addAssignableMsg = {
      Target: 'AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return msg.Name == 'Frank' end)
        ao.addAssignable(function (msg) return msg.Name == 'Thomas' end)
      `
    }

    const { Memory } = await handle(null, addAssignableMsg, env)

    const msg = {
      Target: 'NOT_AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: '2 + 2'
    }

    const result = await handle(Memory, msg, env)
    assert.deepStrictEqual(result.Output.data, '4')
  })

  test('assignables do NOT allow specific assignment', async () => {
    const handle = await AoLoader(wasm, options)

    const addAssignableMsg = {
      Target: 'AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return msg.Name == 'Frank' end)
        ao.addAssignable(function (msg) return msg.Name == 'Thomas' end)
      `
    }

    const { Memory } = await handle(null, addAssignableMsg, env)

    const msg = {
      Target: 'NOT_AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Not-Thomas' }
      ],
      Data: '2 + 2'
    }

    const result = await handle(Memory, msg, env)
    assert.deepStrictEqual(result.Messages[0].Data, 'Assignment is not trusted by this process!')
  })

  test('assignable does NOT allow specific assignment', async () => {
    const handle = await AoLoader(wasm, options)

    const addAssignableMsg = {
      Target: 'AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Thomas' }
      ],
      Data: `
        ao.addAssignable(function (msg) return msg.Name == 'Thomas' end)
      `
    }

    const { Memory } = await handle(null, addAssignableMsg, env)

    const msg = {
      Target: 'NOT_AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Not-Thomas' }
      ],
      Data: '2 + 2'
    }

    const result = await handle(Memory, msg, env)
    assert.deepStrictEqual(result.Messages[0].Data, 'Assignment is not trusted by this process!')
  })

  test('no assignables defaults to no assignments allowed', async () => {
    const handle = await AoLoader(wasm, options)

    const msg = {
      Target: 'NOT_AOS',
      Owner: 'FOOBAR',
      'Block-Height': '1000',
      Id: '1234xyxfoo',
      From: 'FOOBAR',
      Module: 'WOOPAWOOPA',
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Name', value: 'Not-Thomas' }
      ],
      Data: '2 + 2'
    }

    const result = await handle(null, msg, env)
    assert.deepStrictEqual(result.Messages[0].Data, 'Assignment is not trusted by this process!')
  })
})
