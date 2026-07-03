import type { MetadataRoute } from 'next'
import { getSiteUrl } from '@/lib/site'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: ['/', '/login', '/signup', '/rules', '/reset-password'],
      disallow: [
        '/api/',
        '/dashboard',
        '/feed',
        '/profile',
        '/notifications',
        '/pending-approval',
        '/account-suspended',
        '/update-password',
        '/business/',
      ],
    },
    sitemap: `${getSiteUrl()}/sitemap.xml`,
    host: getSiteUrl(),
  }
}
