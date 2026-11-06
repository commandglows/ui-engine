const CLERK_USERS_API = 'https://api.clerk.com/v1/users'
const REQUEST_TIMEOUT_MS = 15_000

export const CLERK_DELETION_MAX_ATTEMPTS = 6
export const CLERK_DELETION_RETRY_MS = 10 * 60 * 1000

export type ClerkDeletionResult = 'deleted' | 'already_deleted' | 'retrying' | 'gave_up'

/** The Clerk secret key, or a stable error before any data is touched. */
export function requireClerkSecretKey(value: string | undefined): string {
  const secretKey = value?.trim()
  if (!secretKey) throw new Error('account_deletion_not_configured')
  return secretKey
}

async function requestDeletion(subject: string, secretKey: string, fetcher: typeof fetch) {
  try {
    const response = await fetcher(`${CLERK_USERS_API}/${encodeURIComponent(subject)}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${secretKey}` },
      redirect: 'error',
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    })
    if (response.ok) return 'deleted'
    if (response.status === 404) return 'already_deleted'
    console.error(`Clerk user deletion failed with status ${response.status}`)
  } catch {
    console.error('Clerk user deletion request failed')
  }
  return null
}

/**
 * Removes the user from the product's Clerk application. The product data is
 * already gone at this point, so a surviving Clerk account would sign back in to
 * an empty account: failures retry through `schedule` until Clerk confirms.
 */
export async function deleteClerkUserWithRetry(options: {
  subject: string
  secretKey: string
  attempt?: number
  schedule: (delayMs: number, nextAttempt: number) => Promise<unknown>
  fetcher?: typeof fetch
}): Promise<ClerkDeletionResult> {
  const attempt = options.attempt ?? 1
  const result = await requestDeletion(options.subject, options.secretKey, options.fetcher ?? fetch)
  if (result) return result
  if (attempt >= CLERK_DELETION_MAX_ATTEMPTS) {
    console.error('Clerk user deletion gave up after every attempt')
    return 'gave_up'
  }
  await options.schedule(CLERK_DELETION_RETRY_MS, attempt + 1)
  return 'retrying'
}

export const ERASE_BATCH_SIZE = 400

/**
 * Erases one bounded batch of a user's rows: Convex limits what a transaction can
 * write. Each product supplies its tables and how to read them. Call it again until
 * `done`; a table in `tables` is finished before the next one starts.
 */
export async function eraseUserDataBatch<Table extends string, Row>(options: {
  tables: readonly Table[]
  take: (table: Table, limit: number) => Promise<Row[]>
  remove: (table: Table, row: Row) => Promise<unknown>
  batchSize?: number
}): Promise<{ done: boolean }> {
  let budget = options.batchSize ?? ERASE_BATCH_SIZE
  for (const table of options.tables) {
    const limit = budget
    const rows = await options.take(table, limit)
    for (const row of rows) await options.remove(table, row)
    budget -= rows.length
    if (rows.length === limit) return { done: false }
  }
  return { done: true }
}

/**
 * Throws `account_data_remaining` while a table still holds a row. Removing the
 * Clerk user first would leave data nobody can sign in to erase.
 */
export async function assertUserDataErased<Table extends string, Row>(options: {
  tables: readonly Table[]
  take: (table: Table, limit: number) => Promise<Row[]>
}): Promise<void> {
  for (const table of options.tables) {
    if ((await options.take(table, 1)).length > 0) throw new Error('account_data_remaining')
  }
}

const LEDGER_TIMEOUT_MS = 8_000

/** Where a product reaches the suite ledger, on the CommandGlows Convex deployment. */
export type SuiteLedgerConfig = {
  convexUrl: string
  bridgeSecret: string
  environment: string
  fetcher?: typeof fetch
}

export type SuiteLedgerAccount = {
  provider: string
  subject: string
  issuer: string
}

/** Reads the three settings, or throws `account_deletion_not_configured`. */
export function requireSuiteLedgerConfig(values: {
  convexUrl: string | undefined
  bridgeSecret: string | undefined
  environment: string | undefined
}): SuiteLedgerConfig {
  const convexUrl = values.convexUrl?.trim()
  const bridgeSecret = values.bridgeSecret?.trim()
  const environment = values.environment?.trim()
  if (!convexUrl || !bridgeSecret || !environment) throw new Error('account_deletion_not_configured')
  return { convexUrl, bridgeSecret, environment }
}

async function callSuiteLedger<Result>(
  kind: 'query' | 'mutation',
  path: string,
  args: Record<string, unknown>,
  config: SuiteLedgerConfig,
): Promise<Result> {
  const response = await (config.fetcher ?? fetch)(`${config.convexUrl.replace(/\/+$/, '')}/api/${kind}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    redirect: 'error',
    signal: AbortSignal.timeout(LEDGER_TIMEOUT_MS),
    body: JSON.stringify({
      path,
      args: { ...args, environment: config.environment, bridgeSecret: config.bridgeSecret },
      format: 'json',
    }),
  })
  const payload = response.ok ? ((await response.json()) as { status?: string; value?: Result }) : undefined
  if (payload?.status !== 'success') throw new Error('suite_ledger_unavailable')
  return payload.value as Result
}

/**
 * Closes the account in the suite ledger, which keeps the trace of its access. Call
 * it before erasing data: a failure stops the deletion, and replaying is safe.
 */
export function closeInSuiteLedger(account: SuiteLedgerAccount, config: SuiteLedgerConfig) {
  return callSuiteLedger<{ status: string }>('mutation', 'productAccountClosure:close', { ...account }, config)
}

/** The verified email is the proof: pass only one the identity provider confirmed. */
export type RecoveringAccount = SuiteLedgerAccount & { verifiedEmail: string }

/** Whether a deleted account with this verified email left a paid access to take back. */
export async function hasRecoverableAccess(account: RecoveringAccount, config: SuiteLedgerConfig): Promise<boolean> {
  const { recoverable } = await callSuiteLedger<{ recoverable: boolean }>(
    'query',
    'productAccountClosure:findRecoverable',
    { ...account },
    config,
  )
  return recoverable
}

/** Moves that paid access to this account. Only on the user's explicit request. */
export function recoverAccess(account: RecoveringAccount, config: SuiteLedgerConfig) {
  return callSuiteLedger<{ status: 'recovered' | 'nothing_to_recover' }>(
    'mutation',
    'productAccountClosure:recover',
    { ...account },
    config,
  )
}
