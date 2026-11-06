# shipglows_account_deletion

Account deletion for ShipGlows Flutter apps: Apple and Google require it for an
app that creates accounts. It works on one product at a time, since each product
has its own Clerk application. Depends on `shipglows_clerk_auth`,
`shipglows_feedback` and `shipglows_theme`.

```dart
ShipglowsDeleteAccountButton(
  auth: AccountDeletionAuth.clerk(clerkClient),
  deleteOnServer: () => convex.action('accountDeletion:deleteMyAccount'),
  erasedData: const ['Ton profil', 'Tes résultats'],
)
```

- `ShipglowsDeleteAccountButton`: the button, its confirmation dialog (what is
  erased, what happens to a paid access) and its error message.
- `runAccountDeletion`: the same sequence without a widget. It asks for a sign-in
  again, stops if another account comes back, calls the server, then signs out.
- `AccountDeletionAuth`: `.clerk(client)` for `ClerkAuthClient`, or its own
  callbacks for an app that wraps its session, such as a web session through Clerk
  JS.
- `ShipglowsAccountDeletionStrings`: the texts, `.fr` or `.en`.

The reconnection does not send `prompt=login`: when the browser already holds the
same account, Clerk ended the fresh session and looped on its form (CommandGlows,
2026-10-30). The check runs in the app only.

The server side is `@shipglows/account-deletion` in `typescript/`.
