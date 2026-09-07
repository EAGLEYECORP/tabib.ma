export const PRESCRIPTION_STATUSES = ['draft','issued','cancelled','dispensed','expired'] as const;
export const PHARMACY_ORDER_STATUSES = ['requested','accepted','ready','dispensed','rejected','cancelled'] as const;
export function validPrescriptionExpiry(date: Date, now = new Date()) { return date.getTime() > now.getTime() && date.getTime() <= now.getTime() + 365*24*60*60*1000; }
