import clsx from 'clsx'

type RelayLogoProps = {
  theme?: 'dark' | 'light'
  size?: 'sm' | 'md' | 'lg'
  showWordmark?: boolean
  className?: string
}

const sizeMap = {
  sm: {
    wrap: 'w-9 h-9 rounded-xl',
    icon: 'w-5 h-5',
    word: 'text-xl',
  },
  md: {
    wrap: 'w-11 h-11 rounded-2xl',
    icon: 'w-6 h-6',
    word: 'text-2xl',
  },
  lg: {
    wrap: 'w-16 h-16 rounded-2xl',
    icon: 'w-9 h-9',
    word: 'text-5xl',
  },
}

/** Relay hop mark — two nodes linked by a forward path (distinct from legacy wave logo). */
function RelayMark({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className={className}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden
    >
      <circle cx="5.5" cy="12" r="2.2" fill="currentColor" />
      <path d="M8.5 12h5.5" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
      <path
        d="M14 10.2l3.2 1.8-3.2 1.8"
        stroke="currentColor"
        strokeWidth="2.2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx="19.5" cy="12" r="2.2" fill="currentColor" />
      <path
        d="M7 8.2c2.8-1.6 6.2-1.6 9 0"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        opacity="0.45"
      />
    </svg>
  )
}

export default function RelayLogo({ theme = 'dark', size = 'md', showWordmark = true, className }: RelayLogoProps) {
  const s = sizeMap[size]
  const isLight = theme === 'light'

  return (
    <div className={clsx('inline-flex items-center gap-3', className)}>
      <div
        className={clsx(
          'relative flex items-center justify-center shadow-[0_16px_35px_-20px_rgba(20,184,166,0.85)]',
          s.wrap
        )}
        style={{
          background: isLight
            ? 'linear-gradient(140deg, #2dd4bf 0%, #22d3ee 100%)'
            : 'linear-gradient(140deg, #14b8a6 0%, #0891b2 100%)',
        }}
      >
        <RelayMark className={clsx(s.icon, 'text-white')} />
      </div>

      {showWordmark ? (
        <span
          className={clsx(
            'relay-wordmark font-extrabold tracking-tight leading-none',
            s.word,
            isLight ? 'text-slate-900' : 'text-white'
          )}
        >
          Relay
        </span>
      ) : null}
    </div>
  )
}
