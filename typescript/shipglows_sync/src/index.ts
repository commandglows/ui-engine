/** Transaction-independent command synchronisation. The caller supplies verified ownership,
 * one atomic transaction, domain execution and its field footprint. No provider or domain imports. */
export interface SyncRequest {
  protocolVersion: 1; userId: string; deviceId: string; commandId: string;
  baseRevision: number; type: string; payload: Record<string, unknown>;
  eventId: string; occurredAt: string; clientTimestamp: string;
}
export interface SyncDelta { entities: unknown[]; events: unknown[] }
export interface SyncEntry { revision: number; commandId: string; serverTimestamp: number; delta: SyncDelta }
export type SyncResult =
  | {status: 'accepted'; revision: number; sequence: number; serverTimestamp: number; replayed: boolean; entry: SyncEntry}
  | {status: 'conflict'; conflictId: string; revision: number; reason: string}
  | {status: 'rejected'; reason: string};
export interface FieldTouch { entityId: string; field: string }
export interface FieldWrite extends FieldTouch { revision: number; deviceId: string }
export const SYNC_COMMAND_BYTES = 32 * 1024;
export const SYNC_DOCUMENT_BYTES = 512 * 1024;
export const SYNC_PAGE_MAX = 100;
export const SYNC_PAGE_BYTES = 768 * 1024;
export class SyncError extends Error {
  readonly code:string;
  constructor(code: string) { super(code); this.code=code; this.name = 'SyncError'; }
}
export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    && Object.getPrototypeOf(value) === Object.prototype;
}
export function canonicalJson(value: unknown, depth = 0): string {
  if (depth > 80) throw new SyncError('invalid-json');
  if (value === null || typeof value === 'boolean' || typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number' && Number.isFinite(value)) return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(x => canonicalJson(x, depth + 1)).join(',')}]`;
  if (!isRecord(value)) throw new SyncError('invalid-json');
  return `{${Object.keys(value).sort().map(key => {
    if (['__proto__', 'prototype', 'constructor'].includes(key)) throw new SyncError('invalid-json');
    return `${JSON.stringify(key)}:${canonicalJson(value[key], depth + 1)}`;
  }).join(',')}}`;
}
export function jsonBytes(value: unknown): number { return new TextEncoder().encode(canonicalJson(value)).length; }
/** Fixed-size intent identity prevents snapshot receipts exceeding database document limits. */
export async function intentFingerprint(value:unknown):Promise<string> {
  const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(canonicalJson(value)));
  return Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join('');
}
export function identifier(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value);
}
export function revision(value: unknown): value is number { return Number.isSafeInteger(value) && (value as number) >= 0; }
export function decodeSyncRequest(value: unknown): SyncRequest {
  if (!isRecord(value)) throw new SyncError('invalid-request');
  const keys = ['protocolVersion','userId','deviceId','commandId','baseRevision','type','payload','eventId','occurredAt','clientTimestamp'];
  if (Object.keys(value).length !== keys.length || keys.some(key => !Object.hasOwn(value, key))) throw new SyncError('invalid-request');
  if (value.protocolVersion !== 1 || !['userId','deviceId','commandId','eventId'].every(key => identifier(value[key]))
    || !revision(value.baseRevision) || typeof value.type !== 'string' || value.type.length > 80 || !isRecord(value.payload)
    || ['occurredAt','clientTimestamp'].some(key => typeof value[key] !== 'string'
      || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value[key] as string) || !Number.isFinite(Date.parse(value[key] as string)))) throw new SyncError('invalid-request');
  if (jsonBytes(value) > SYNC_COMMAND_BYTES) throw new SyncError('command-too-large');
  return value as unknown as SyncRequest;
}
export function fieldsOverlap(left: string, right: string): boolean {
  return left === '*' || right === '*' || left === right || left.startsWith(`${right}.`) || right.startsWith(`${left}.`);
}
/** Keep one stamp per device and field. A same-device later write must not hide an earlier foreign write. */
export function concurrentWrite(request: SyncRequest, touches: FieldTouch[], writes: FieldWrite[]): boolean {
  return writes.some(write => write.revision > request.baseRevision && write.deviceId !== request.deviceId
    && touches.some(touch => touch.entityId === write.entityId && fieldsOverlap(touch.field, write.field)));
}
export interface SyncTransaction<Document> {
  head(): Promise<{revision: number; document: Document | null}>;
  receipt(commandId: string): Promise<{fingerprint: string; result: SyncResult} | null>;
  writes(touches: FieldTouch[]): Promise<FieldWrite[]>;
  remember(commandId: string, fingerprint: string, result: SyncResult): Promise<void>;
  conflict(request: SyncRequest, reason: string, revision: number): Promise<string>;
  accept(request: SyncRequest, document: Document, entry: SyncEntry, touches: FieldTouch[]): Promise<void>;
}
export async function executeSyncCommand<Document>(options: {
  owner: string; request: unknown; transaction: SyncTransaction<Document>; now: number;
  footprint(request: SyncRequest): FieldTouch[];
  execute(document: Document, request: SyncRequest): Promise<{document: Document; delta: SyncDelta} | {reason: string; recoverable?:boolean}>;
}): Promise<SyncResult> {
  const request = decodeSyncRequest(options.request);
  if (request.userId !== options.owner) throw new SyncError('account-mismatch');
  const fingerprint = await intentFingerprint(request);
  const tx = options.transaction;
  const prior = await tx.receipt(request.commandId);
  if (prior) {
    if (prior.fingerprint !== fingerprint) throw new SyncError('command-intent-mismatch');
    return prior.result.status === 'accepted' ? {...prior.result, replayed: true} : prior.result;
  }
  const current = await tx.head();
  if (request.baseRevision > current.revision) throw new SyncError('revision-ahead');
  if (!current.document) throw new SyncError('promotion-required');
  const touches = options.footprint(request);
  let result: SyncResult;
  if (concurrentWrite(request, touches, await tx.writes(touches))) {
    const reason = 'concurrent-field';
    result = {status: 'conflict', conflictId: await tx.conflict(request, reason, current.revision), revision: current.revision, reason};
  } else {
    const applied = await options.execute(current.document, request);
    if ('reason' in applied) {
      if(applied.recoverable===false) result={status:'rejected',reason:applied.reason};
      else {
        // Structural/domain divergence needs a durable recovery choice. A plain rejected
        // head would permanently wedge the FIFO worker without an archivable conflict.
        const reason=`domain:${applied.reason}`;
        result={status:'conflict',conflictId:await tx.conflict(request,reason,current.revision),revision:current.revision,reason};
      }
    } else {
      if (jsonBytes(applied.document) > SYNC_DOCUMENT_BYTES) throw new SyncError('document-too-large');
      if (!revision(current.revision + 1)) throw new SyncError('revision-exhausted');
      const entry = {revision: current.revision + 1, commandId: request.commandId, serverTimestamp: options.now, delta: applied.delta};
      await tx.accept(request, applied.document, entry, touches);
      result = {status: 'accepted', revision: entry.revision, sequence: entry.revision, serverTimestamp: entry.serverTimestamp, replayed: false, entry};
    }
  }
  await tx.remember(request.commandId, fingerprint, result);
  return result;
}
