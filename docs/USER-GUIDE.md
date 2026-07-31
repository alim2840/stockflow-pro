# StockFlow Pro — User Guide

**Product:** StockFlow Pro 1.0.0 · **Publisher:** Mindtune Innovations
**Developed by:** Muhammad Ali — Accounts & Finance Expert, MBA (Finance) — alim2840@gmail.com

## 1. Signing in
1. Open **Start Menu → StockFlow Pro**.
2. First time only: enter your **company server address** (from your admin).
3. Sign in with your email and password. Use the eye icon to show/hide the
   password, tick **Remember me** to stay signed in on this PC, and
   **Forgot password?** to reset by email.
4. You will only see the companies, warehouses, projects and menus your
   administrator authorised for your role.

## 2. Finding your way around
- **Sidebar:** Dashboard, Inventory, Warehouses, Stock Transactions,
  Purchasing, Suppliers, Projects, Production, Stock Counts, Reports,
  Users & Roles, Backups, Audit Log, Notifications, Settings. It collapses with
  the arrow button; icons get tooltips when collapsed. Menu items you lack
  permission for are hidden — and blocked by the server even if addressed
  directly.
- **Dashboard:** live figures (inventory value, available/reserved stock, low
  stock, active projects, approvals, monthly received/consumed) — every number
  comes from posted ledger transactions, never typed in.
- **Light / dark mode** follows your Windows theme.

## 3. Working with inventory (the golden rules)
- Stock is **never edited directly**. Every change is a **transaction**:
  receipt, issue, return, transfer, adjustment, damage, count variance.
- **Posted transactions are permanent.** To correct one, post a **Reversal** —
  the system creates equal-and-opposite entries and links the two.
- **Issued ≠ consumed** on projects: issuing moves stock to the project;
  consumption records what was actually used; unused stock is returned.
- **Reservations** reduce *available* stock but never *on-hand* stock.
- **Transfers** dispatch into an in-transit state; the destination confirms
  receipt before stock appears there.
- The system **blocks negative stock** and **duplicate posting** automatically.
- Everything important is recorded in the **Audit Log**.

## 4. Everyday tasks
| Task | Where |
|---|---|
| Check an item's stock, per warehouse, and full history | Inventory → open the item |
| Record goods received against a PO (partial allowed) | Purchasing → Goods Receipt → Post |
| Issue materials to a project | Stock Transactions → New → Project issue |
| Record project consumption / returns | Stock Transactions → New |
| Move stock between warehouses | Stock Transactions → Transfers |
| Count stock | Stock Counts → new session → count → approval → post |
| Export a list (CSV) | Any table → Export. In the desktop app files land in your **Downloads** folder. |

## 5. Offline behaviour
If your internet drops, an amber banner appears: *"You're offline. Your entries
are kept on screen — reconnecting automatically…"*. Nothing you typed is lost;
when the connection returns a green **Back online** banner shows and you can
save. If the app can't reach the company server at startup, it shows a clear
status screen and retries every few seconds.

## 6. Notifications
The bell area (Notifications) lists low-stock alerts, pending approvals,
transfers awaiting receipt, overdue POs and backup alerts. Mark items read from
the list; preferences are per user.

## 7. About & support
Login screen footer → **About StockFlow Pro**, or **Settings → About**:
version, build, environment, update check, and support contact
(**alim2840@gmail.com** — opens your mail app).

## 8. Frequently asked
- **Do my colleagues abroad see my changes?** Yes — everyone works on the same
  live cloud database. A posted receipt in Pakistan is visible to an authorised
  user in the US as soon as their screen refreshes.
- **Can I lose data by uninstalling?** No. Business data lives in your
  company's cloud database, not on your PC.
- **Why can't I edit a posted transaction?** By design — accounting integrity.
  Post a reversal instead (if your role allows it).
