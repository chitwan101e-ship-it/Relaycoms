'use client'

import { useCallback, useEffect, useState } from 'react'
import { BellRing } from 'lucide-react'
import {
  desktopNotifySupported,
  getDesktopNotifyPermission,
  isDesktopNotifyEnabled,
  isDesktopNotifyPromptDismissed,
  requestDesktopNotifyPermission,
  dismissDesktopNotifyPrompt,
  sendTestDesktopNotification,
  type DesktopNotifyPermission,
} from '@/lib/desktopNotifications'

type Props = {
  variant: 'staff' | 'customer'
  isLight?: boolean
}

export function DesktopNotificationPrompt({ variant, isLight = false }: Props) {
  const [permission, setPermission] = useState<DesktopNotifyPermission>('default')
  const [busy, setBusy] = useState(false)
  const [testStatus, setTestStatus] = useState<'idle' | 'ok' | 'fail'>('idle')
  const [testMessage, setTestMessage] = useState<string | null>(null)

  const sync = useCallback(() => {
    setPermission(getDesktopNotifyPermission())
  }, [])

  useEffect(() => {
    sync()
  }, [sync])

  function onSendTestAlert() {
    setTestStatus('idle')
    setTestMessage(null)
    const result = sendTestDesktopNotification()
    if (result.ok) {
      setTestStatus('ok')
      setTestMessage('Test sent — check the bottom-right corner of Windows (or Action Center).')
      window.setTimeout(() => {
        setTestStatus('idle')
        setTestMessage(null)
      }, 8000)
      return
    }
    setTestStatus('fail')
    setTestMessage(result.reason ?? 'Could not show test alert.')
  }

  if (!desktopNotifySupported()) return null
  if (isDesktopNotifyEnabled()) {
    return (
      <div className={`space-y-1.5 ${isLight ? '' : ''}`}>
        <p className={`text-[10px] ${isLight ? 'text-slate-500' : 'text-[#5c647e]'}`}>
          Desktop alerts are on — corner popups for new customer messages and signup requests.
        </p>
        <button
          type="button"
          onClick={onSendTestAlert}
          className={`text-[10px] font-semibold underline underline-offset-2 ${
            isLight ? 'text-slate-600 hover:text-slate-900' : 'text-[#8d63ff] hover:text-[#a78bff]'
          }`}
        >
          Send test alert
        </button>
        {testMessage ? (
          <p
            className={`text-[10px] leading-snug ${
              testStatus === 'ok'
                ? isLight
                  ? 'text-emerald-700'
                  : 'text-emerald-300/90'
                : isLight
                  ? 'text-red-700'
                  : 'text-red-300/90'
            }`}
            role="status"
          >
            {testMessage}
          </p>
        ) : null}
      </div>
    )
  }
  if (isDesktopNotifyPromptDismissed()) return null

  const label =
    variant === 'staff'
      ? 'Enable message alerts'
      : 'Enable reply alerts'

  const deniedHint =
    permission === 'denied'
      ? 'Blocked in browser — allow notifications for this site in site settings.'
      : null

  async function onEnable() {
    setBusy(true)
    try {
      const p = await requestDesktopNotifyPermission()
      setPermission(p)
      sync()
    } finally {
      setBusy(false)
    }
  }

  function onDismiss() {
    dismissDesktopNotifyPrompt()
  }

  const shell = isLight
    ? 'border-slate-200/90 bg-slate-50 text-slate-700'
    : 'border-white/[0.08] bg-white/[0.04] text-[#aeb7d6]'
  const btn = isLight
    ? 'bg-slate-900 text-white hover:bg-slate-800'
    : 'bg-[#8d63ff] text-white hover:bg-[#9d73ff]'

  return (
    <div className={`flex flex-wrap items-center gap-2 rounded-[10px] border px-2.5 py-1.5 text-[11px] ${shell}`}>
      <BellRing className="w-3.5 h-3.5 shrink-0 opacity-80" aria-hidden />
      <span className="min-w-0 flex-1 leading-snug">
        {deniedHint ??
          'For staff on a laptop: corner popup for each new customer message and signup request (keep this tab open in Chrome/Edge).'}
      </span>
      {permission !== 'denied' ? (
        <button
          type="button"
          disabled={busy}
          onClick={() => void onEnable()}
          className={`shrink-0 rounded-[8px] px-2.5 py-1 text-[11px] font-semibold disabled:opacity-50 ${btn}`}
        >
          {busy ? '…' : label}
        </button>
      ) : null}
      <button
        type="button"
        onClick={onDismiss}
        className="shrink-0 text-[10px] opacity-60 hover:opacity-100 underline"
      >
        Not now
      </button>
    </div>
  )
}
