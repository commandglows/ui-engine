/** Pass the deployment's own Convex builders: this package does not choose its SDK version. */
export function syncTables({defineTable, v}: {defineTable: any; v: any}) {
  return {
    syncUsers: defineTable({issuer:v.string(),subject:v.string(),userId:v.string()}).index('by_identity',['issuer','subject']),
    syncDocuments: defineTable({userId:v.string(),revision:v.number(),document:v.any()}).index('by_user',['userId']),
    syncDevices: defineTable({userId:v.string(),deviceId:v.string(),issuer:v.string(),subject:v.string(),createdAt:v.number()}).index('by_user_device',['userId','deviceId']).index('by_device',['deviceId']),
    syncReceipts: defineTable({userId:v.string(),commandId:v.string(),fingerprint:v.string(),result:v.any()}).index('by_user_command',['userId','commandId']),
    syncJournal: defineTable({userId:v.string(),revision:v.number(),entry:v.any()}).index('by_user_revision',['userId','revision']),
    syncConflicts: defineTable({userId:v.string(),commandId:v.string(),request:v.any(),revision:v.number(),reason:v.string(),resolved:v.boolean(),decision:v.optional(v.string()),resolvedAt:v.optional(v.number())}).index('by_user_command',['userId','commandId']).index('by_user_resolved',['userId','resolved']),
    syncWrites: defineTable({userId:v.string(),entityId:v.string(),field:v.string(),deviceId:v.string(),revision:v.number()}).index('by_user_entity',['userId','entityId']).index('by_user_entity_field_device',['userId','entityId','field','deviceId']),
  };
}
