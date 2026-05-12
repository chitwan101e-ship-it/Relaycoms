// src/app/api/auth/send-otp/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { Resend } from 'resend'
import { createServiceClient } from '@/lib/supabase/server'
import { getClientIp } from '@/lib/clientIp'
import { rateLimitSendOtp } from '@/lib/authRateLimit'
import { verifyTurnstileToken } from '@/lib/verifyTurnstile'
import crypto from 'crypto'

function getResend() {
  const key = process.env.RESEND_API_KEY
  if (!key) throw new Error('RESEND_API_KEY is not configured')
  return new Resend(key)
}

function hashToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex')
}

export async function POST(req: NextRequest) {
  try {
    const otpEnabled = process.env.ENABLE_OTP === 'true'
    const body = await req.json()
    const { email, turnstileToken } = body as { email?: string; turnstileToken?: string }
    if (!email) return NextResponse.json({ error: 'Email required' }, { status: 400 })

    const ip = getClientIp(req)

    const captcha = await verifyTurnstileToken(turnstileToken, ip)
    if (!captcha.ok) {
      return NextResponse.json({ error: captcha.error ?? 'Verification failed' }, { status: 400 })
    }

    const rl = await rateLimitSendOtp(ip, String(email))
    if (!rl.allowed) {
      return NextResponse.json(
        { error: 'Too many verification requests. Please try again later.' },
        {
          status: 429,
          headers: { 'Retry-After': String(rl.retryAfterSec) },
        }
      )
    }

    if (!otpEnabled) return NextResponse.json({ success: true, otpSkipped: true })

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString()
    const hashedOtp = hashToken(otp)
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString() // 10 min

    const supabase = createServiceClient()

    // Invalidate previous tokens for this email
    await supabase
      .from('otp_tokens')
      .update({ used: true })
      .eq('email', email)
      .eq('used', false)

    // Store hashed OTP
    const { error: dbError } = await supabase.from('otp_tokens').insert({
      email,
      token: hashedOtp,
      expires_at: expiresAt,
      used: false,
    })
    if (dbError) throw dbError

    // Send email via Resend
    const { error: emailError } = await getResend().emails.send({
      from: process.env.RESEND_FROM_EMAIL || 'noreply@jbcoms.com',
      to: email,
      subject: 'Your JBComs verification code',
      html: `
        <div style="font-family: sans-serif; max-width: 480px; margin: 0 auto; padding: 32px;">
          <h1 style="font-size: 24px; color: #1a56e8; margin-bottom: 8px;">JBComs</h1>
          <p style="color: #444; margin-bottom: 24px;">Your email verification code:</p>
          <div style="background: #f0f5ff; border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px;">
            <span style="font-size: 40px; font-weight: 700; letter-spacing: 8px; color: #1344cc;">${otp}</span>
          </div>
          <p style="color: #666; font-size: 14px;">This code expires in <strong>10 minutes</strong>. Do not share it with anyone.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
          <p style="color: #aaa; font-size: 12px;">If you didn't request this, you can safely ignore this email.</p>
        </div>
      `,
    })
    if (emailError) throw emailError

    return NextResponse.json({ success: true })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[send-otp]', err)

    if (message.includes('RESEND_API_KEY is not configured')) {
      return NextResponse.json(
        {
          error: 'OTP email provider is not configured. Set RESEND_API_KEY in .env.local and restart the dev server.',
        },
        { status: 500 }
      )
    }

    if (message.toLowerCase().includes('domain') || message.toLowerCase().includes('from')) {
      return NextResponse.json(
        {
          error: 'Email sender is not verified in Resend. Check RESEND_FROM_EMAIL and your verified sending domain.',
        },
        { status: 500 }
      )
    }

    return NextResponse.json({ error: 'Failed to send OTP email. Please try again.' }, { status: 500 })
  }
}
