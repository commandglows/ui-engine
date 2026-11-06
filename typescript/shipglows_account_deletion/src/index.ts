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
