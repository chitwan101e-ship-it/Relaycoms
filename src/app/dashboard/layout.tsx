import type { Metadata } from 'next'

export const metadata: Metadata = {
  robots: { index: false, follow: false, nocache: true },
}

/** Private app surfaces should not be indexed by search engines. */
export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return children
}
