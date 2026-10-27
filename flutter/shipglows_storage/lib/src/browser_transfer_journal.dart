/// The [TransferJournal] for a browser, kept in `localStorage` so an upload
/// resumes its missing parts after a page reload. The web build gets the
/// real class; other platforms get one whose constructor throws, so the
/// web-safe barrel still compiles and runs on the VM.
library;

export 'browser_transfer_journal_stub.dart'
    if (dart.library.js_interop) 'browser_transfer_journal_web.dart';
