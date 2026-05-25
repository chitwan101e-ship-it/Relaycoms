'use client'

import { useEffect, useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { storagePathFromMessageImageUrl } from '@/lib/messageImageUrl'

type Props = {
  imageUrl: string
  alt?: string
  className?: string
  linkClassName?: string
}

/** Renders a chat attachment; uses a signed URL when the bucket is not public. */
export function ChatMessageImage({ imageUrl, alt = 'Attachment', className, linkClassName }: Props) {
  const [src, setSrc] = useState(imageUrl)
  const supabase = useMemo(() => createClient(), [])

  useEffect(() => {
    let cancelled = false
    setSrc(imageUrl)

    const path = storagePathFromMessageImageUrl(imageUrl)
    if (!path) return

    void (async () => {
      const { data, error } = await supabase.storage.from('message-images').createSignedUrl(path, 3600)
      if (cancelled || error || !data?.signedUrl) return
      setSrc(data.signedUrl)
    })()

    return () => {
      cancelled = true
    }
  }, [imageUrl, supabase])

  return (
    <a href={src} target="_blank" rel="noopener noreferrer" className={linkClassName ?? 'block'}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={alt} className={className} />
    </a>
  )
}
