# shipglows_reviews example

Playground for `shipglows_reviews` on Windows and the web: the invitation
(no store prompt there), the form, the settings rows and offline sending.
Reviews go to an in-memory sink shown on screen; the policy is set to ask
after one success, every time.

```powershell
s start -ProjectPath flutter\shipglows_reviews\example -FlutterDevice windows
s start -ProjectPath flutter\shipglows_reviews\example -FlutterDevice web-server
```
