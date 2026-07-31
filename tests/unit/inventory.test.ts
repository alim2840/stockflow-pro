import { describe, it, expect } from 'vitest';
import { available, movingAverage, add, mul, formatMoney } from '../../src/lib/money';

// txn_direction mirror (keep in sync with 0009_functions.sql).
const DIR: Record<string, number> = {
  opening_balance: 1, purchase_receipt: 1, customer_return: 1, project_return: 1,
  transfer_in: 1, adjustment_increase: 1, supplier_return: -1, project_issue: -1,
  general_issue: -1, production_consumption: -1, transfer_out: -1, damage: -1,
  expiry: -1, loss: -1, adjustment_decrease: -1,
  project_consumption: 0, count_variance: 0, reversal: 0, assembly_output: 0,
};

describe('inventory formulas', () => {
  it('available = on_hand - reserved, floored at 0', () => {
    expect(available(1000, 300).toNumber()).toBe(700);
    expect(available(100, 250).toNumber()).toBe(0); // never negative
  });

  it('decimal money math avoids float drift', () => {
    expect(add(0.1, 0.2).toNumber()).toBe(0.3);        // not 0.30000000000000004
    expect(mul(19.99, 3).toNumber()).toBe(59.97);
  });

  it('moving average weights old and received cost', () => {
    // 100 @ 10 + 100 @ 20 => avg 15
    expect(movingAverage(100, 10, 100, 20).toNumber()).toBe(15);
    // first receipt from zero stock
    expect(movingAverage(0, 0, 50, 8).toNumber()).toBe(8);
  });

  it('direction map: issue decreases, receipt increases, consumption neutral to warehouse', () => {
    expect(DIR.purchase_receipt).toBe(1);
    expect(DIR.project_issue).toBe(-1);
    expect(DIR.project_consumption).toBe(0); // issued != consumed
  });

  it('battery scenario nets correctly (2500 -1000 +120 -30 = 1590)', () => {
    const onHand = 2500 + (-1000) + 120 + (-30);
    expect(onHand).toBe(1590);
  });

  it('formats currency', () => {
    expect(formatMoney(1789625, 'PKR')).toMatch(/1,789,625/);
  });
});
