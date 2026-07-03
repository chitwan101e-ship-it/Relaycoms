import type { Metadata } from 'next'
import { getSiteUrl, SITE_DESCRIPTION, SITE_NAME } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Sign in',
  description: `Sign in to ${SITE_NAME} on Relaycoms — ${SITE_DESCRIPTION}`,
  alternates: { canonical: `${getSiteUrl()}/login` },
  robots: { index: true, follow: true },
}

export default function LoginLayout({ children }: { children: React.ReactNode }) {
  return children
}
