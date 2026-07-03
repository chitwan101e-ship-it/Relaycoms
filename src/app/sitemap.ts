import type { MetadataRoute } from 'next'
import { getSiteUrl } from '@/lib/site'

export default function sitemap(): MetadataRoute.Sitemap {
  const base = getSiteUrl()
  const now = new Date()

  return [
    { url: `${base}/login`, lastModified: now, changeFrequency: 'monthly', priority: 0.9 },
    { url: `${base}/signup`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${base}/rules`, lastModified: now, changeFrequency: 'monthly', priority: 0.5 },
    { url: `${base}/reset-password`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
  ]
}
