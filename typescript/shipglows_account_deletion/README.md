# @shipglows/account-deletion

Server side of the shared account deletion. Each product deletes its own data,
then removes the user from its own Clerk application with this package. Clerk's
`user.deleted` webhook stays a safety net: Clerk does not guarantee its delivery.

- `requireClerkSecretKey(value)`: throws `account_deletion_not_configured` when
  the key is missing. Call it before deleting data, so a deployment that cannot
  reach Clerk deletes nothing.
- `deleteClerkUserWithRetry({ subject, secretKey, attempt, schedule })`: deletes
  the user. A 404 counts as deleted. On failure it calls `schedule` with the delay
  and the next attempt, until `CLERK_DELETION_MAX_ATTEMPTS`.

A Convex deployment wires it in one internal action:

```ts
export const removeClerkUser = internalAction({
  args: { subject: v.string(), attempt: v.number() },
  handler: (ctx, { subject, attempt }) =>
    deleteClerkUserWithRetry({
      subject,
      attempt,
      secretKey: requireClerkSecretKey(process.env.CLERK_SECRET_KEY),
      schedule: (delayMs, next) =>
        ctx.scheduler.runAfter(delayMs, internal.accountDeletion.removeClerkUser, { subject, attempt: next }),
    }),
})
```

Erasing the data, one bounded batch at a time. The product supplies its tables and
how to read them; repeat until `done`, then check nothing is left:

```ts
const take = (table, limit) =>
  ctx.db.query(table).withIndex('by_userId', (q) => q.eq('userId', userId)).take(limit)

// In a mutation, called until { done: true }.
await eraseUserDataBatch({ tables: USER_TABLES, take, remove: (_table, row) => ctx.db.delete(row._id) })

// Before removing the Clerk user: throws account_data_remaining.
await assertUserDataErased({ tables: USER_TABLES, take })
```

The suite ledger, on the CommandGlows Convex deployment, over its HTTP API:

- `closeInSuiteLedger(account, config)`: closes the product's account and keeps the
  trace of its access. Call it before erasing data.
- `hasRecoverableAccess(account, config)` and `recoverAccess(account, config)`: a
  client who comes back with the same verified email takes their paid access back.
  It moves only on an explicit request from the user, never on sign-in. Pass an email
  only when the identity provider confirmed it.
- `requireSuiteLedgerConfig(values)`: reads the settings, or throws
  `account_deletion_not_configured`.

The app side is the Flutter package `shipglows_account_deletion`.
