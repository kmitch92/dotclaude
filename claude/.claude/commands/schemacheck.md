# Schema Alignment Audit

Automated workflow to detect and fix GraphQL schema drift across all 15 Build Queue services.

## What This Does

1. Backs up current schema.graphql files to schema_old.graphql
2. Regenerates all schemas via `npm run generate:schemas`
3. Compares old vs new schemas and reports diffs
4. Identifies which Zod schemas need fixing based on diffs
5. Cleans up backup files after fixes
6. Runs final drift check via `./scripts/check-schema-drift.sh`

## Services Audited

- **Domain Services**: user-service, company-service, order-service, product-service, quotation-service, route-service, machine-service, qc-service, scheduling-service, material-service, inventory-service, comment-service, design-service
- **Supporting Services**: auth-service, file-service

## File Structure Per Service

```
src/common/schemas/{service}/
├── types.ts        # Zod schemas for GraphQL types
└── inputs.ts       # Zod schemas for input types

src/services/{service}-service/
├── src/gqloom/resolvers.ts    # GQLoom resolver definitions
└── schema/schema.graphql      # Generated GraphQL schema
```

## Common Schema Drift Scenarios

### Field Added to Type
**Symptom**: New field appears in GraphQL schema but not in generated output
**Fix**:
1. Add field to Zod schema in `types.ts`
   ```typescript
   export const ProductSchema = z.object({
     // ... existing fields
     newField: z.string(),  // Add here
   });
   ```
2. Mirror in `resolvers.ts` GQLoom resolver
   ```typescript
   export const Product = loom.object({
     newField: loom.field(z.string()),
   });
   ```

### Field Removed from Type
**Symptom**: Field exists in Zod schema but missing from GraphQL schema
**Fix**: Remove field from both `types.ts` and `resolvers.ts`

### Field Made Nullable
**Symptom**: Field is `Type` in GraphQL but `Type!` in Zod
**Fix**: Add `.nullish()` to Zod field
```typescript
export const ProductSchema = z.object({
  optionalField: z.string().nullish(),  // Was z.string()
});
```

### Field Made Required
**Symptom**: Field is `Type!` in GraphQL but `Type` in Zod
**Fix**: Remove `.nullish()` or `.optional()`
```typescript
export const ProductSchema = z.object({
  requiredField: z.string(),  // Was z.string().nullish()
});
```

### New Input Type Added
**Symptom**: Input type defined in GraphQL but not generated
**Fix**:
1. Add to `inputs.ts`
   ```typescript
   export const CreateProductInputSchema = z.object({
     name: z.string(),
     // ... fields
   });
   ```
2. Register in `resolvers.ts` collectNames()
   ```typescript
   collectNames(silk, {
     CreateProductInput: CreateProductInputSchema,
   });
   ```

### New Query/Mutation Added
**Symptom**: Resolver handler exists but not in GraphQL schema
**Fix**: Add to GQLoom resolver definition in `resolvers.ts`
```typescript
export const Query = resolver({
  newQuery: query(OutputSchema, {
    input: { id: z.string() },
    resolve: async () => { /* ... */ },
  }),
});
```

### Enum Value Added/Removed
**Symptom**: Enum values mismatch between GraphQL and Zod
**Fix**: Update Zod enum definition
```typescript
export const StatusSchema = z.enum([
  'PENDING',
  'IN_PROGRESS',
  'COMPLETED',
  'NEW_VALUE',  // Add/remove here
]);
```

## Execution Steps

### Step 1: Backup Current Schemas
```bash
for service in user company order product quotation route machine qc scheduling material inventory comment design auth file; do
  if [ -f "src/services/${service}-service/schema/schema.graphql" ]; then
    cp "src/services/${service}-service/schema/schema.graphql" \
       "src/services/${service}-service/schema/schema_old.graphql"
    echo "Backed up ${service}-service schema"
  fi
done
```

### Step 2: Regenerate All Schemas
```bash
npm run generate:schemas
```

### Step 3: Compare and Report Diffs
```bash
for service in user company order product quotation route machine qc scheduling material inventory comment design auth file; do
  old="src/services/${service}-service/schema/schema_old.graphql"
  new="src/services/${service}-service/schema/schema.graphql"

  if [ -f "$old" ] && [ -f "$new" ]; then
    echo "=== Checking ${service}-service ==="
    if diff -q "$old" "$new" > /dev/null; then
      echo "✓ No changes"
    else
      echo "✗ Schema drift detected:"
      diff "$old" "$new"
    fi
    echo ""
  fi
done
```

### Step 4: Identify Zod Fixes Needed
Based on diffs, check:
- `src/common/schemas/{service}/types.ts` - For type field changes
- `src/common/schemas/{service}/inputs.ts` - For input type changes
- `src/services/{service}-service/src/gqloom/resolvers.ts` - For resolver definitions

### Step 5: Apply Fixes
1. Edit Zod schemas based on diff analysis
2. Re-run `npm run generate:schemas`
3. Verify diffs eliminated

### Step 6: Cleanup Backups
```bash
for service in user company order product quotation route machine qc scheduling material inventory comment design auth file; do
  rm -f "src/services/${service}-service/schema/schema_old.graphql"
done
```

### Step 7: Final Drift Check
```bash
./scripts/check-schema-drift.sh
```

## Critical Zod Import Rule

**ALWAYS** import `z` from `@common/gqloom-generator`, NOT from `'zod'` directly:

```typescript
// ✅ CORRECT
import { z } from '@common/gqloom-generator';

// ❌ WRONG - Causes "extend is not a function" errors
import { z } from 'zod';
```

This prevents Zod instance mismatch errors during schema generation.

## Expected Output

### No Drift
```
✓ All 15 services schemas aligned
✓ No drift detected
```

### Drift Detected
```
✗ Schema drift in 3 services:
  - product-service: Field 'estimatedDuration' missing from Zod schema
  - task-service: Input 'CompleteTaskInput.materialUsage' not registered
  - material-service: Enum 'MaterialType' missing value 'COMPOSITE'

Next steps:
1. Fix src/common/schemas/product/types.ts
2. Fix src/common/schemas/task/inputs.ts
3. Fix src/common/schemas/material/types.ts
4. Re-run npm run generate:schemas
```

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "extend is not a function" | Wrong Zod import | Import from `@common/gqloom-generator` |
| Input type not appearing | Not registered in collectNames() | Add to resolvers.ts collectNames() |
| Field always nullable | Missing `.describe()` or resolver config | Add GQLoom field config |
| Enum values missing | Zod enum incomplete | Update enum definition in types.ts |

## Automation Tip

Run this check before every deployment:
```bash
npm run generate:schemas && ./scripts/check-schema-drift.sh
```

Add to CI/CD pipeline to catch drift early.
