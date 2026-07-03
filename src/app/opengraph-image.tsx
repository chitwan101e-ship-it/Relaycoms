import { ImageResponse } from 'next/og'
import { SITE_LEGAL_NAME, SITE_TAGLINE } from '@/lib/site'

export const runtime = 'edge'
export const alt = `${SITE_LEGAL_NAME} — ${SITE_TAGLINE}`
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          justifyContent: 'center',
          padding: '72px',
          background: 'linear-gradient(145deg, #041210 0%, #0a2420 55%, #062a28 100%)',
          color: '#ecfeff',
          fontFamily: 'system-ui, sans-serif',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 28,
            marginBottom: 28,
          }}
        >
          <div
            style={{
              width: 96,
              height: 96,
              borderRadius: 24,
              background: 'linear-gradient(140deg, #14b8a6 0%, #0891b2 100%)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 24px 48px rgba(20, 184, 166, 0.35)',
            }}
          >
            <svg width="52" height="52" viewBox="0 0 24 24" fill="none">
              <circle cx="5.5" cy="12" r="2.2" fill="#fff" />
              <path d="M8.5 12h5.5" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" />
              <path
                d="M14 10.2l3.2 1.8-3.2 1.8"
                stroke="#fff"
                strokeWidth="2.2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              <circle cx="19.5" cy="12" r="2.2" fill="#fff" />
            </svg>
          </div>
          <span style={{ fontSize: 88, fontWeight: 800, letterSpacing: -3 }}>Relay</span>
        </div>
        <p style={{ fontSize: 34, color: '#99f6e4', maxWidth: 820, lineHeight: 1.35 }}>{SITE_TAGLINE}</p>
        <p style={{ fontSize: 22, color: '#5eead4', marginTop: 20, opacity: 0.85 }}>{SITE_LEGAL_NAME}.com</p>
      </div>
    ),
    { ...size }
  )
}
