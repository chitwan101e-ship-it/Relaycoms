/** Synthetic auth email for legacy support staff created before work-email onboarding (still supported for sign-in). */
export function staffAuthEmailForUsername(rawUsername: string): string {
  const clean = rawUsername.trim().replace(/^@+/, '').toLowerCase()
  const domain =
    (typeof process !== 'undefined' && process.env.STAFF_AUTH_EMAIL_DOMAIN?.trim()) || 'relay-staff.jbcoms'
  return `${clean}@${domain}`
}

export function isValidStaffUsername(raw: string): boolean {
  const s = raw.trim().replace(/^@+/, '').toLowerCase()
  return /^[a-z0-9_]{3,30}$/.test(s)
}

export function normalizeStaffUsername(raw: string): string {
  return raw.trim().replace(/^@+/, '').toLowerCase()
}
