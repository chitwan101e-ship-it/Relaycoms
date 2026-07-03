import type { Metadata } from 'next'
import { getSiteUrl, SITE_DESCRIPTION, SITE_NAME } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Create account',
  description: `Create your ${SITE_NAME} account on Relaycoms — ${SITE_DESCRIPTION}`,
  alternates: { canonical: `${getSiteUrl()}/signup` },
  robots: { index: true, follow: true },
}

export default function SignupLayout({ children }: { children: React.ReactNode }) {
  return children
}
