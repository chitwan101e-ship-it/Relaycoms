import './globals.css'
import type { Metadata, Viewport } from 'next'
import { Inter } from 'next/font/google'
import { getRootDomain, getSiteUrl, SITE_DESCRIPTION, SITE_LEGAL_NAME, SITE_NAME, SITE_TAGLINE } from '@/lib/site'

/** Loaded once from the server layout so client chunks (e.g. /feed) stay smaller — avoids dev ChunkLoadError/timeouts. */
const relayFooter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-relay-footer',
})

const siteUrl = getSiteUrl()

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: `${SITE_NAME} — ${SITE_TAGLINE}`,
    template: `%s · ${SITE_NAME}`,
  },
  description: SITE_DESCRIPTION,
  applicationName: SITE_LEGAL_NAME,
  keywords: ['Relaycoms', 'Relay', 'customer support', 'private messaging', 'team communication'],
  authors: [{ name: SITE_LEGAL_NAME, url: siteUrl }],
  creator: SITE_LEGAL_NAME,
  publisher: SITE_LEGAL_NAME,
  category: 'technology',
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true },
  },
  alternates: {
    canonical: '/',
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: siteUrl,
    siteName: SITE_LEGAL_NAME,
    title: `${SITE_NAME} — ${SITE_TAGLINE}`,
    description: SITE_DESCRIPTION,
  },
  twitter: {
    card: 'summary_large_image',
    title: `${SITE_NAME} — ${SITE_TAGLINE}`,
    description: SITE_DESCRIPTION,
  },
  icons: {
    icon: [{ url: '/favicon.svg', type: 'image/svg+xml' }],
    shortcut: '/favicon.svg',
    apple: '/favicon.svg',
  },
  other: {
    ...(process.env.GOOGLE_SITE_VERIFICATION
      ? { 'google-site-verification': process.env.GOOGLE_SITE_VERIFICATION }
      : {}),
  },
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#041210',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={relayFooter.variable} suppressHydrationWarning>
      <head>
        <link rel="canonical" href={siteUrl} />
        <link rel="manifest" href="/site.webmanifest" />
        <meta name="application-name" content={SITE_LEGAL_NAME} />
        <meta name="apple-mobile-web-app-title" content={SITE_NAME} />
      </head>
      <body suppressHydrationWarning>{children}</body>
    </html>
  )
}
