import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { GoogleAuth } from 'npm:google-auth-library@10.3.0'

const spreadsheetId = '1hwaPaPJs0nAtlGzR6nFmFwt3mIv4OznLEms6Bu7NrKg'
const sheetName = 'ACTIVE'
const jsonHeaders = { 'Content-Type': 'application/json' }
const allowedChangeStatuses = new Set([
  'login',
  'ongoing pre-checks',
  'ongoing planned',
  'ongoing post-checks',
  'implemented',
])

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

function requiredChangeNumber(value: unknown) {
  const number = String(value ?? '').trim().toUpperCase()
  if (!/^CHG\d{7}$/.test(number)) throw new Error('Invalid CHG number.')
  return number
}

function displayStatus(value: unknown) {
  const status = String(value ?? '').trim().toLowerCase().replace(/\s+/g, ' ')
  return allowedChangeStatuses.has(status) ? status : 'Not checked in'
}

function labeledValue(details: string, label: string) {
  const line = details
    .split(/\r?\n/)
    .find((value) => value.toLowerCase().startsWith(`${label.toLowerCase()}:`))
  return line?.slice(line.indexOf(':') + 1).trim() || null
}

async function accessToken() {
  const rawCredentials = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
  if (!rawCredentials) throw new Error('Google service account is not configured.')
  const auth = new GoogleAuth({
    credentials: JSON.parse(rawCredentials),
    scopes: ['https://www.googleapis.com/auth/spreadsheets'],
  })
  const client = await auth.getClient()
  const token = await client.getAccessToken()
  if (!token.token) throw new Error('Google access token could not be created.')
  return token.token
}

async function sheetsRequest(path: string, init?: RequestInit) {
  const token = await accessToken()
  const response = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/${path}`,
    {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        ...init?.headers,
      },
    },
  )
  if (!response.ok) {
    console.error('Google Sheets API error', response.status, await response.text())
    throw new Error('Google Sheets request failed.')
  }
  return response.json()
}

async function findRow(number: string) {
  const range = encodeURIComponent(`${sheetName}!B2:U`)
  const data = await sheetsRequest(`values/${range}`)
  const values: unknown[][] = data.values ?? []
  const index = values.findIndex((row) => {
    const changeNumbers = String(row[7] ?? '')
      .toUpperCase()
      .match(/\bCHG\d{7}\b/g)
    return changeNumbers?.includes(number) ?? false
  })
  if (index < 0) return null
  const valuesForRow = values[index]
  return {
    rowNumber: index + 2,
    title: String(valuesForRow[0] ?? '').trim(),
    objective: String(valuesForRow[1] ?? '').trim(),
    status: String(valuesForRow[13] ?? '').trim(),
    loginTime: String(valuesForRow[14] ?? '').trim(),
    logoutTime: String(valuesForRow[15] ?? '').trim(),
    details: String(valuesForRow[18] ?? '').trim(),
    proponent: String(valuesForRow[19] ?? '').trim(),
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return reply({ error: 'Method not allowed.' }, 405)

  try {
    const authorization = request.headers.get('Authorization')
    const token = authorization?.replace(/^Bearer\s+/i, '')
    if (!token) return reply({ error: 'Authentication required.' }, 401)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authorization } } },
    )
    const { data, error } = await supabase.auth.getUser(token)
    const email = data.user?.email?.toLowerCase()
    if (error || !email) {
      return reply({ error: 'A verified company account is required.' }, 403)
    }
    const { data: domainAllowed, error: domainError } = await supabase.rpc(
      'is_allowed_email_domain',
      { candidate_email: email },
    )
    if (domainError || domainAllowed !== true) {
      return reply({ error: 'This company email domain is not approved.' }, 403)
    }
    const { data: userRole, error: roleError } = await supabase.rpc(
      'get_chglog_user_role',
      { candidate_email: email },
    )
    if (roleError) throw roleError
    const isWlnUser = userRole === 'wln'

    const body = await request.json()
    if (body.action === 'register-device') {
      const deviceToken = String(body.token ?? '').trim()
      if (deviceToken.length < 32 || deviceToken.length > 4096) {
        return reply({ error: 'Invalid device token.' }, 400)
      }
      const { error: tokenError } = await supabase.from('device_tokens').upsert(
        {
          token: deviceToken,
          user_id: data.user.id,
          platform: 'android',
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'token' },
      )
      if (tokenError) throw tokenError
      return reply({ registered: true })
    }
    if (body.action === 'list-activities') {
      const { data: activities, error: activitiesError } = await supabase
        .from('activities')
        .select('id,change_number,title,objective,proponent,status,checked_in_at,status_updated_at,checked_out_at,checked_out_time,full_name,wln_implementer')
        .order('checked_in_at', { ascending: false })
      if (activitiesError) throw activitiesError
      return reply({ activities })
    }

    const number = requiredChangeNumber(body.number)
    const row = await findRow(number)

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const findUnassignedManualActivity = async () => {
      if (row === null) return null
      const { data: activity, error: manualError } = await admin
        .from('activities')
        .select('id')
        .eq('source', 'manual')
        .eq('sheet_row', row.rowNumber)
        .eq('change_number', number)
        .is('user_id', null)
        .order('checked_in_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (manualError) throw manualError
      return activity
    }
    const findCurrentUserActivity = async () => {
      if (row === null) return null
      const { data: activity, error: currentError } = await supabase
        .from('activities')
        .select('id,full_name,company,contact_number')
        .eq('sheet_row', row.rowNumber)
        .eq('change_number', number)
        .order('checked_in_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (currentError) throw currentError
      return activity
    }

    if (body.action === 'find') {
      const status = displayStatus(row?.status)
      const manualActivity = await findUnassignedManualActivity()
      const currentUserActivity = await findCurrentUserActivity()
      const sheetDetails = row?.details ?? ''
      return reply({
        found: row !== null,
        number,
        title: row?.title ?? '',
        objective: row?.objective ?? '',
        status,
        loginTime: /^\d{4}H$/.test(row?.loginTime ?? '') ? row?.loginTime : null,
        logoutTime: status === 'implemented' && /^\d{4}H$/.test(row?.logoutTime ?? '')
          ? row?.logoutTime
          : null,
        proponent: row?.proponent ?? '',
        hasUnassignedManualActivity: manualActivity !== null,
        isWlnUser,
        hasCurrentUserActivity: currentUserActivity !== null,
        fullName: labeledValue(sheetDetails, 'Onsite implementer') ??
          labeledValue(sheetDetails, 'Full name') ??
          currentUserActivity?.full_name ?? null,
        company: labeledValue(sheetDetails, 'Company') ??
          currentUserActivity?.company ?? null,
        contactNumber: labeledValue(sheetDetails, 'Contact') ??
          currentUserActivity?.contact_number ?? null,
        email: labeledValue(sheetDetails, 'Email'),
        wlnImplementer: labeledValue(sheetDetails, 'WLN implementer'),
      })
    }
    if (body.action === 'add-wln-activity') {
      if (row === null) return reply({ error: 'CHG is not active.' }, 404)
      if (!isWlnUser) {
        return reply({ error: 'Only WLN users can add an activity without onsite details.' }, 403)
      }

      const { data: existing, error: existingError } = await admin
        .from('activities')
        .select('id')
        .eq('user_id', data.user.id)
        .eq('sheet_row', row.rowNumber)
        .eq('change_number', number)
        .limit(1)
        .maybeSingle()
      if (existingError) throw existingError
      if (existing !== null) return reply({ added: false, alreadyExists: true })

      const manualActivity = await findUnassignedManualActivity()
      if (manualActivity !== null) {
        const { data: claimed, error: claimError } = await admin
          .from('activities')
          .update({ user_id: data.user.id, user_email: email })
          .eq('id', manualActivity.id)
          .is('user_id', null)
          .select('id')
          .maybeSingle()
        if (claimError) throw claimError
        if (claimed === null) {
          return reply({ error: 'This activity was already added by another user.' }, 409)
        }
        return reply({ added: true, claimedManual: true })
      }

      const normalizedStatus = String(row.status).trim().toLowerCase().replace(/\s+/g, ' ')
      const displayName = String(
        data.user.user_metadata?.full_name ??
          data.user.user_metadata?.name ??
          '',
      ).trim()
      const { error: insertError } = await admin.from('activities').insert({
        user_id: data.user.id,
        user_email: email,
        sheet_row: row.rowNumber,
        change_number: number,
        title: row.title,
        objective: row.objective,
        proponent: row.proponent,
        status: allowedChangeStatuses.has(normalizedStatus) ? normalizedStatus : 'login',
        source: 'app',
        wln_implementer: displayName || null,
      })
      if (insertError) throw insertError
      return reply({ added: true, claimedManual: false })
    }
    if (body.action !== 'submit') return reply({ error: 'Unknown action.' }, 400)
    if (row === null) return reply({ error: 'CHG is not active.' }, 404)

    const fullName = String(body.fullName ?? '').trim()
    const company = String(body.company ?? '').trim()
    const contactNumber = String(body.contactNumber ?? '').trim()
    if (!fullName || !company || !/^\+?[\d ()-]{7,20}$/.test(contactNumber)) {
      return reply({ error: 'Invalid check-in details.' }, 400)
    }

    const timeText = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Asia/Manila',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(new Date()).replace(':', '') + 'H'
    const existingWlnImplementer = row.details
      .split(/\r?\n/)
      .find((line) => line.toLowerCase().startsWith('wln implementer:'))
      ?.slice('wln implementer:'.length).trim() ?? ''
    const details = [
      `Onsite implementer: ${fullName}`,
      `Company: ${company}`,
      `Contact: ${contactNumber}`,
      `Email: ${email}`,
      ...(existingWlnImplementer
        ? [`WLN implementer: ${existingWlnImplementer}`]
        : []),
    ].join('\n')

    const currentUserActivity = await findCurrentUserActivity()
    if (currentUserActivity !== null) {
      await sheetsRequest('values:batchUpdate', {
        method: 'POST',
        body: JSON.stringify({
          valueInputOption: 'RAW',
          data: [
            { range: `${sheetName}!T${row.rowNumber}`, values: [[details]] },
          ],
        }),
      })
      const { error: detailsError } = await admin
        .from('activities')
        .update({
          user_email: email,
          full_name: fullName,
          company,
          contact_number: contactNumber,
        })
        .eq('id', currentUserActivity.id)
        .eq('user_id', data.user.id)
      if (detailsError) throw detailsError
      return reply({ number, timeText: row.loginTime || timeText, updated: true })
    }

    const manualActivity = await findUnassignedManualActivity()
    if (manualActivity !== null) {
      await sheetsRequest('values:batchUpdate', {
        method: 'POST',
        body: JSON.stringify({
          valueInputOption: 'RAW',
          data: [
            { range: `${sheetName}!T${row.rowNumber}`, values: [[details]] },
          ],
        }),
      })
      const { data: claimed, error: claimError } = await admin
        .from('activities')
        .update({
          user_id: data.user.id,
          user_email: email,
          full_name: fullName,
          company,
          contact_number: contactNumber,
        })
        .eq('id', manualActivity.id)
        .is('user_id', null)
        .select('id')
        .maybeSingle()
      if (claimError) throw claimError
      if (claimed === null) {
        return reply({ error: 'This manual login was already linked to another account.' }, 409)
      }
      return reply({ number, timeText: row.loginTime || timeText, linked: true })
    }

    await sheetsRequest('values:batchUpdate', {
      method: 'POST',
      body: JSON.stringify({
        valueInputOption: 'RAW',
        data: [
          { range: `${sheetName}!O${row.rowNumber}`, values: [['login']] },
          { range: `${sheetName}!P${row.rowNumber}`, values: [[timeText]] },
          { range: `${sheetName}!T${row.rowNumber}`, values: [[details]] },
        ],
      }),
    })
    const { error: activityError } = await supabase.from('activities').insert({
      user_id: data.user.id,
      user_email: email,
      sheet_row: row.rowNumber,
      change_number: number,
      title: row.title,
      objective: row.objective,
      proponent: row.proponent,
      status: 'login',
      source: 'app',
      full_name: fullName,
      company,
      contact_number: contactNumber,
    })
    if (activityError) throw activityError
    return reply({ number, timeText })
  } catch (error) {
    console.error(error)
    const message = error instanceof Error ? error.message : 'Unexpected error.'
    return reply({ error: message }, message.startsWith('Invalid CHG') ? 400 : 500)
  }
})
