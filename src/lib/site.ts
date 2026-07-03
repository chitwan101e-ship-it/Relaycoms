/** Public site identity — used for SEO, Open Graph, and email branding. */
export const SITE_NAME = 'Relay'
export const SITE_LEGAL_NAME = 'Relaycoms'
export const SITE_TAGLINE = 'Private messaging and customer support for teams.'
export const SITE_DESCRIPTION =
  'Relaycoms is a private messaging platform for customer support, team announcements, and secure business communication.'

export function getRootDomain(): string {
  return process.env.NEXT_PUBLIC_ROOT_DOMAIN?.trim() || 'relaycoms.com'
}

/** Canonical origin with no trailing slash (https://www.relaycoms.com). */
export function getSiteUrl(): string {
  const configured = process.env.NEXT_PUBLIC_APP_URL?.trim()
  if (configured) return configured.replace(/\/$/, '')
  const root = getRootDomain()
  return root.startsWith('localhost') ? `http://${root}` : `https://www.${root}`
}
