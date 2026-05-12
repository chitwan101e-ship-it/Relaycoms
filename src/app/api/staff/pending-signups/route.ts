import { NextResponse } from 'next/server'
import { createClient, createServiceClient } from '@/lib/supabase/server'

export async function GET() {
  try {
    if (!process.env.SUPABASE_SERVICE_ROLE_KEY?.trim()) {
      return NextResponse.json(
        { error: 'SUPABASE_SERVICE_ROLE_KEY is not set on the server.' },
        { status: 500 }
      )
    }

    const supabase = await createClient()
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { data: staff, error: staffErr } = await supabase
      .from('profiles')
      .select('id, role, business_role')
      .eq('id', user.id)
      .single()

    if (staffErr || !staff || staff.role !== 'business') {
      return NextResponse.json(
        { error: 'Only business staff can view pending signups.' },
        { status: 403 }
      )
    }

    const admin = createServiceClient()
    const { data: profiles, error: profErr } = await admin
      .from('profiles')
      .select('id, first_name, last_name, username, phone, referral_username, created_at, account_status')
      .eq('role', 'customer')
      .eq('account_status', 'pending')
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(80)

    if (profErr) {
      return NextResponse.json({ error: profErr.message }, { status: 500 })
    }

    const rows = profiles ?? []
    const enriched = await Promise.all(
      rows.map(async (p) => {
        const { data: authRes } = await admin.auth.admin.getUserById(p.id as string)
        const u = authRes?.user
        return {
          id: p.id as string,
          first_name: (p.first_name as string) ?? '',
          last_name: (p.last_name as string) ?? '',
          username: (p.username as string) ?? '',
          phone: (p.phone as string | null) ?? null,
          referral_username: (p.referral_username as string | null) ?? null,
          created_at: p.created_at as string,
          account_status: p.account_status as string,
          email: u?.email ?? null,
          email_verified: !!u?.email_confirmed_at,
        }
      })
    )

    return NextResponse.json({ pending: enriched })
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Server error'
    return NextResponse.json({ error: msg }, { status: 500 })
  }
}
