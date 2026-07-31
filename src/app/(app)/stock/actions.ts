'use server';
import { revalidatePath } from 'next/cache';
import { createServerSupabase } from '@/lib/supabase/server';
import { stockTxnSchema, type StockTxnInput } from '@/lib/validation/stock-transaction';

export type ActionResult =
  | { ok: true; transactionId: string; reference: string }
  | { ok: false; error: string; fieldErrors?: Record<string, string[]> };

// Create a DRAFT stock transaction and POST it via the DB RPC. All inventory
// effects, permission checks, negative-stock protection, atomicity and audit
// happen inside post_stock_transaction(). The client never mutates balances.
export async function createAndPostStockTransaction(input: StockTxnInput): Promise<ActionResult> {
  const parsed = stockTxnSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: 'Please fix the highlighted fields.', fieldErrors: parsed.error.flatten().fieldErrors as any };
  }
  const data = parsed.data;
  const supabase = await createServerSupabase();

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { ok: false, error: 'Your session has expired. Please sign in again.' };
  const { data: profile } = await supabase.from('profiles').select('org_id').eq('id', user.id).single();
  if (!profile) return { ok: false, error: 'Profile not found for the current user.' };

  // Idempotency: a repeated submit with the same key is rejected by the unique
  // (org, idempotency_key) constraint — no duplicate posting.
  const { data: existing } = await supabase.from('stock_transactions')
    .select('id, ref_no, status').eq('idempotency_key', data.idempotency_key).maybeSingle();
  if (existing) {
    if (existing.status !== 'posted') await supabase.rpc('post_stock_transaction', { p_txn_id: existing.id });
    return { ok: true, transactionId: existing.id, reference: existing.ref_no };
  }

  // Reference number is generated server-side (concurrency-safe).
  const prefixMap: Record<string, string> = {
    project_issue: 'ISS', general_issue: 'ISS', project_return: 'RTN', supplier_return: 'RTN',
    adjustment_increase: 'ADJ', adjustment_decrease: 'ADJ', damage: 'DMG', purchase_receipt: 'GRN',
  };
  const prefix = prefixMap[data.txn_type] ?? 'TXN';
  const year = new Date(data.txn_date).getUTCFullYear();
  const { data: refNo, error: refErr } = await supabase.rpc('next_reference', {
    p_org: profile.org_id, p_doc_type: prefix, p_prefix: prefix, p_year: year,
  });
  if (refErr) return { ok: false, error: `Could not generate a reference number: ${refErr.message}` };

  // Insert draft header (RLS: requires stock_txn.create).
  const { data: header, error: hErr } = await supabase.from('stock_transactions').insert({
    org_id: profile.org_id, ref_no: refNo, txn_type: data.txn_type, status: 'draft',
    txn_date: data.txn_date, project_id: data.project_id, supplier_id: data.supplier_id,
    currency: data.currency, reason: data.reason, notes: data.notes,
    idempotency_key: data.idempotency_key, created_by: user.id,
  }).select('id, ref_no').single();
  if (hErr) return { ok: false, error: mapDbError(hErr.message) };

  // Insert lines.
  const lines = data.lines.map((l, i) => ({
    org_id: profile.org_id, transaction_id: header.id, line_no: i + 1,
    item_id: l.item_id, warehouse_id: l.warehouse_id, location_id: l.location_id ?? null,
    quantity: l.quantity, unit_cost: l.unit_cost, batch_no: l.batch_no ?? null,
    serial_no: l.serial_no ?? null, expiry_date: l.expiry_date ?? null,
  }));
  const { error: lErr } = await supabase.from('stock_transaction_lines').insert(lines);
  if (lErr) return { ok: false, error: mapDbError(lErr.message) };

  // Post atomically via RPC.
  const { error: pErr } = await supabase.rpc('post_stock_transaction', { p_txn_id: header.id });
  if (pErr) return { ok: false, error: mapDbError(pErr.message) };

  revalidatePath('/dashboard');
  revalidatePath('/items');
  return { ok: true, transactionId: header.id, reference: header.ref_no };
}

// Turn raw Postgres errors into actionable, non-leaky messages.
function mapDbError(msg: string): string {
  if (/Negative stock blocked/i.test(msg)) return 'This would create negative stock. Receive or transfer stock first, or enable controlled negative stock in Settings.';
  if (/Permission denied|insufficient/i.test(msg)) return 'You do not have permission to perform this action.';
  if (/duplicate key|idempotency/i.test(msg)) return 'This transaction was already submitted.';
  if (/immutable/i.test(msg)) return 'This transaction is posted and cannot be modified. Use a reversal instead.';
  return 'The transaction could not be posted. Please review the details and try again.';
}
