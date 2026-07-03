import type { Metadata } from 'next'
import { getSiteUrl } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Program rules',
  description: 'Relaycoms community program rules and guidelines for members and businesses.',
  alternates: { canonical: `${getSiteUrl()}/rules` },
  robots: { index: true, follow: true },
}

export default function RulesLayout({ children }: { children: React.ReactNode }) {
  return children
}
