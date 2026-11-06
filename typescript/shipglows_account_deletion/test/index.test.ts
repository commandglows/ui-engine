import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  assertUserDataErased,
  closeInSuiteLedger,
  deleteClerkUserWithRetry,
  eraseUserDataBatch,
  hasRecoverableAccess,
  recoverAccess,
  requireClerkSecretKey,
  requireSuiteLedgerConfig,
} from '../src/index.ts'

function tables(content: Record<string, number>) {
  const rows = { ...content }
  return {
    rows,
    take: async (table: string, limit: number) =>
      Array.from({ length: Math.min(rows[table] ?? 0, limit) }, () => table),
    remove: async (table: string) => {
      rows[table] -= 1
    },
  }
}

test('erases table by table within the batch, until done', async () => {
  const db = tables({ a: 3, b: 3 })
  const options = { tables: ['a', 'b'], take: db.take, remove: db.remove, batchSize: 4 }
  assert.deepEqual(await eraseUserDataBatch(options), { done: false })
  assert.deepEqual(db.rows, { a: 0, b: 2 })
  assert.deepEqual(await eraseUserDataBatch(options), { done: true })
  assert.deepEqual(db.rows, { a: 0, b: 0 })
})

test('a batch that exactly fills the budget asks for another pass', async () => {
  const db = tables({ a: 4 })
  const options = { tables: ['a'], take: db.take, remove: db.remove, batchSize: 4 }
  assert.deepEqual(await eraseUserDataBatch(options), { done: false })
  assert.deepEqual(await eraseUserDataBatch(options), { done: true })
})

test('refuses while a row remains', async () => {
  await assert.rejects(
    assertUserDataErased({ tables: ['a', 'b'], take: tables({ a: 0, b: 1 }).take }),
    /account_data_remaining/,
  )
  await assertUserDataErased({ tables: ['a', 'b'], take: tables({}).take })
})

test('the secret key is required before anything is deleted', () => {
  assert.throws(() => requireClerkSecretKey('  '), /account_deletion_not_configured/)
  assert.equal(requireClerkSecretKey(' key '), 'key')
})

test('a Clerk failure schedules a retry, then gives up', async () => {
  const failing = (async () => new Response(null, { status: 500 })) as typeof fetch
  const scheduled: number[] = []
  const schedule = async (_delay: number, next: number) => scheduled.push(next)
  const errors = console.error
  console.error = () => {}
  try {
    assert.equal(
      await deleteClerkUserWithRetry({ subject: 'u', secretKey: 'k', schedule, fetcher: failing }),
      'retrying',
    )
    assert.deepEqual(scheduled, [2])
    assert.equal(
      await deleteClerkUserWithRetry({ subject: 'u', secretKey: 'k', attempt: 6, schedule, fetcher: failing }),
      'gave_up',
    )
  } finally {
    console.error = errors
  }
  const gone = (async () => new Response(null, { status: 404 })) as typeof fetch
  assert.equal(
    await deleteClerkUserWithRetry({ subject: 'u', secretKey: 'k', schedule, fetcher: gone }),
    'already_deleted',
  )
})

function ledger(value: unknown, status = 'success') {
  const calls: { url: string; body: any }[] = []
  const fetcher = (async (url: string, init: RequestInit) => {
    calls.push({ url, body: JSON.parse(init.body as string) })
    return new Response(JSON.stringify({ status, value }))
  }) as unknown as typeof fetch
  return { calls, config: { convexUrl: 'https://x.convex.cloud/', bridgeSecret: 's', environment: 'development', fetcher } }
}

const account = { provider: 'replayglows_clerk', subject: 'user_1', issuer: 'https://i', verifiedEmail: 'a@b.c' }

test('the ledger calls carry the account, the environment and the secret', async () => {
  const { calls, config } = ledger({ status: 'closed' })
  await closeInSuiteLedger(account, config)
  assert.equal(calls[0].url, 'https://x.convex.cloud/api/mutation')
  assert.equal(calls[0].body.path, 'productAccountClosure:close')
  assert.equal(calls[0].body.args.environment, 'development')
  assert.equal(calls[0].body.args.bridgeSecret, 's')
})

test('the recovery reads through a query and writes through a mutation', async () => {
  const read = ledger({ recoverable: true })
  assert.equal(await hasRecoverableAccess(account, read.config), true)
  assert.equal(read.calls[0].url, 'https://x.convex.cloud/api/query')
  const write = ledger({ status: 'recovered' })
  assert.deepEqual(await recoverAccess(account, write.config), { status: 'recovered' })
  assert.equal(write.calls[0].body.path, 'productAccountClosure:recover')
})

test('a ledger error stops the caller', async () => {
  await assert.rejects(closeInSuiteLedger(account, ledger(null, 'error').config), /suite_ledger_unavailable/)
})

test('the ledger settings are required', () => {
  assert.throws(
    () => requireSuiteLedgerConfig({ convexUrl: 'u', bridgeSecret: undefined, environment: 'e' }),
    /account_deletion_not_configured/,
  )
})
