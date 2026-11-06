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

The app side is the Flutter package `shipglows_account_deletion`.
