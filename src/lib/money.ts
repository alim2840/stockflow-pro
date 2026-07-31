import Decimal from 'decimal.js';

// Money & quantity math NEVER uses JS floats. All values are decimal.
// The DB stores numeric(18,4); we mirror that precision here.
Decimal.set({ precision: 34, rounding: Decimal.ROUND_HALF_UP });

export type Numeric = Decimal.Value;

export const dec = (v: Numeric) => new Decimal(v ?? 0);
export const add = (a: Numeric, b: Numeric) => dec(a).plus(dec(b));
export const sub = (a: Numeric, b: Numeric) => dec(a).minus(dec(b));
export const mul = (a: Numeric, b: Numeric) => dec(a).times(dec(b));
export const div = (a: Numeric, b: Numeric) => (dec(b).isZero() ? dec(0) : dec(a).div(dec(b)));

// Moving weighted-average cost (mirrors post_stock_transaction in SQL).
export function movingAverage(oldQty: Numeric, oldAvg: Numeric, recvQty: Numeric, unitCost: Numeric) {
  const total = add(oldQty, recvQty);
  if (dec(total).lte(0)) return dec(oldAvg).toDecimalPlaces(4);
  return div(add(mul(oldQty, oldAvg), mul(recvQty, unitCost)), total).toDecimalPlaces(4);
}

// Available stock formula (mirrors v_item_warehouse_balance).
export function available(onHand: Numeric, reserved: Numeric) {
  return Decimal.max(sub(onHand, reserved), 0);
}

export function formatMoney(value: Numeric, currency = 'PKR', locale = 'en-US') {
  const n = dec(value).toDecimalPlaces(2).toNumber();
  try {
    return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(n);
  } catch {
    return `${currency} ${new Intl.NumberFormat(locale, { minimumFractionDigits: 2 }).format(n)}`;
  }
}

export function formatQty(value: Numeric, locale = 'en-US') {
  return new Intl.NumberFormat(locale, { maximumFractionDigits: 4 }).format(dec(value).toNumber());
}
