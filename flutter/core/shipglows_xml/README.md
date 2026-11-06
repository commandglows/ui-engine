# shipglows_xml

A small XML reader for untrusted documents, extracted from BeatGlows:
`parseSafeXml` builds a `SafeXmlNode` tree (`child`, `childrenNamed`,
`descendants`, `text`) and rejects every `<!` declaration but an optional
plain `DOCTYPE`, so entities are never expanded; `SafeXmlLimits` bounds size,
depth, node count and text. Used by `shipglows_storage` for S3 answers and by
BeatGlows for MusicXML and Guitar Pro.
