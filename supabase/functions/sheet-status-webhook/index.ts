import { createClient } from 'npm:@supabase/supabase-js@2.57.4'
import { GoogleAuth } from 'npm:google-auth-library@10.3.0'

const allowedStatuses = new Set([
  'login',
  'ongoing pre-checks',
  'ongoing planned',
  'ongoing post-checks',
  'implemented',
])

function reply(body: unknown, status = 200) {
  return Response.json(body, { status })
}

function labeledValue(details: string, label: string) {
  const line = details
    .split(/\r?\n/)
    .find((value) => value.toLowerCase().startsWith(`${label.toLowerCase()}:`))
  return line?.slice(line.indexOf(':') + 1).trim() || null
}

async function findUserIdByEmail(
  supabase: ReturnType<typeof createClient>,
  email: string | null,
) {
  if (!email) return null
  for (let page = 1; page <= 20; page += 1) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) throw error
    const match = data.users.find((user) => user.email?.toLowerCase() === email)
    if (match) return match.id
    if (data.users.length < 1000) return null
  }
  return null
}

async function firebaseAccessToken(credentials: Record<string, unknown>) {
  const auth = new GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const client = await auth.getClient()
  const token = await client.getAccessToken()
  if (!token.token) throw new Error('Firebase access token could not be created.')
  return token.token
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return reply({ error: 'Method not allowed.' }, 405)

  try {
    const expectedSecret = Deno.env.get('CHGLOG_WEBHOOK_SECRET')
    const suppliedSecret = request.headers.get('X-CHGLog-Webhook-Secret')
    if (!expectedSecret || suppliedSecret !== expectedSecret) {
      return reply({ error: 'Unauthorized.' }, 401)
    }

    const body = await request.json()
    const editType = String(body.editType ?? 'status')
    const rowNumber = Number(body.rowNumber)
    const status = String(body.status ?? '').trim().toLowerCase()
    const logoutTime = String(body.logoutTime ?? '').trim()
    const changeNumbers = Array.isArray(body.changeNumbers)
      ? [...new Set(body.changeNumbers.map((value: unknown) => String(value).toUpperCase()))]
          .filter((value) => /^CHG\d{7}$/.test(value))
      : []
    if (
      body.sheetName !== 'ACTIVE' ||
      !['status', 'details'].includes(editType) ||
      !Number.isInteger(rowNumber) ||
      rowNumber < 1 ||
      !allowedStatuses.has(status) ||
      (status === 'implemented' && !/^\d{4}H$/.test(logoutTime)) ||
      (status !== 'implemented' && logoutTime !== '') ||
      changeNumbers.length === 0
    ) {
      return reply({ error: 'Invalid status update.' }, 400)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const details = String(body.details ?? '').trim()
    const email = labeledValue(details, 'Email')?.toLowerCase() ?? null
    const manualDetails = {
      user_email: email,
      full_name: labeledValue(details, 'Onsite implementer') ??
        labeledValue(details, 'Full name'),
      company: labeledValue(details, 'Company'),
      contact_number: labeledValue(details, 'Contact'),
      wln_implementer: labeledValue(details, 'WLN implementer'),
      manual_logged_by: String(body.editedBy ?? '').trim() || null,
    }

    if (editType === 'details') {
      const matchedUserId = await findUserIdByEmail(supabase, email)
      const { data: existingManual, error: lookupError } = await supabase
        .from('activities')
        .select('id,user_id,change_number')
        .eq('source', 'manual')
        .eq('sheet_row', rowNumber)
        .in('change_number', changeNumbers)
      if (lookupError) throw lookupError

      if (!existingManual?.length) {
        if (status !== 'login') {
          return reply({ updated: 0, manualCreated: 0, linked: 0 })
        }
        const editedAt = String(body.editedAt ?? new Date().toISOString())
        const rows = changeNumbers.map((changeNumber) => ({
          user_id: matchedUserId,
          ...manualDetails,
          sheet_row: rowNumber,
          change_number: changeNumber,
          title: String(body.title ?? '').trim(),
          objective: String(body.objective ?? '').trim(),
          proponent: String(body.proponent ?? '').trim(),
          status: 'login',
          checked_in_at: editedAt,
          status_updated_at: editedAt,
          source: 'manual',
        }))
        const { data: inserted, error: insertError } = await supabase
          .from('activities')
          .insert(rows)
          .select('id,user_id')
        if (insertError) throw insertError
        return reply({
          updated: 0,
          manualCreated: inserted?.length ?? 0,
          linked: inserted?.filter((activity) => activity.user_id !== null).length ?? 0,
        })
      }

      let linked = 0
      for (const activity of existingManual) {
        const userId = activity.user_id ?? matchedUserId
        const { error: detailsError } = await supabase
          .from('activities')
          .update({ ...manualDetails, user_id: userId })
          .eq('id', activity.id)
        if (detailsError) throw detailsError
        if (activity.user_id === null && userId !== null) linked += 1
      }
      return reply({
        updated: existingManual.length,
        manualCreated: 0,
        linked,
      })
    }

    let { data: activities, error: updateError } = await supabase
      .from('activities')
      .update({
        status,
        status_updated_at: new Date().toISOString(),
        checked_out_at: status === 'implemented'
          ? String(body.editedAt ?? new Date().toISOString())
          : null,
        checked_out_time: status === 'implemented' ? logoutTime : null,
      })
      .eq('sheet_row', rowNumber)
      .in('change_number', changeNumbers)
      .select('id,user_id,change_number')
    if (updateError) throw updateError

    let manualCreated = 0
    if (!activities?.length && status === 'login') {
      const userId = await findUserIdByEmail(supabase, email)
      const editedAt = String(body.editedAt ?? new Date().toISOString())
      const loginTime = String(body.loginTime ?? '').trim()
      const rows = changeNumbers.map((changeNumber) => ({
        user_id: userId,
        user_email: email,
        sheet_row: rowNumber,
        change_number: changeNumber,
        title: String(body.title ?? '').trim(),
        objective: String(body.objective ?? '').trim(),
        proponent: String(body.proponent ?? '').trim(),
        status: 'login',
        checked_in_at: editedAt,
        status_updated_at: editedAt,
        source: 'manual',
        ...manualDetails,
      }))
      const { data: inserted, error: insertError } = await supabase
        .from('activities')
        .insert(rows)
        .select('id,user_id,change_number')
      if (insertError) throw insertError
      activities = inserted
      manualCreated = inserted?.length ?? 0
      console.log('Manual login recorded', { rowNumber, loginTime, manualCreated })
    }
    if (!activities?.length) {
      return reply({ updated: 0, manualCreated, notified: 0 })
    }

    const linkedActivities = activities.filter((activity) => activity.user_id !== null)
    const userIds = [...new Set(linkedActivities.map((activity) => activity.user_id))]
    let devices: { user_id: string; token: string }[] = []
    if (userIds.length > 0) {
      const { data, error: deviceError } = await supabase
        .from('device_tokens')
        .select('user_id,token')
        .in('user_id', userIds)
      if (deviceError) throw deviceError
      devices = data ?? []
    }

    const notificationRows = linkedActivities.map((activity) => ({
      user_id: activity.user_id,
      activity_id: activity.id,
      title: `${activity.change_number} status updated`,
      body: `Status changed to ${status}.`,
    }))
    if (notificationRows.length > 0) {
      const { error: notificationError } = await supabase
        .from('notifications')
        .insert(notificationRows)
      if (notificationError) throw notificationError
    }

    const rawFirebaseCredentials = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if (!rawFirebaseCredentials) {
      throw new Error('Firebase service account is not configured.')
    }
    const firebaseCredentials = JSON.parse(rawFirebaseCredentials)
    const projectId = String(firebaseCredentials.project_id ?? '')
    const accessToken = await firebaseAccessToken(firebaseCredentials)
    let notified = 0

    for (const activity of linkedActivities) {
      const userDevices = devices?.filter((device) => device.user_id === activity.user_id) ?? []
      for (const device of userDevices) {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token: device.token,
                notification: {
                  title: `${activity.change_number} status updated`,
                  body: `Status changed to ${status}.`,
                },
                data: {
                  activityId: activity.id,
                  changeNumber: activity.change_number,
                  status,
                },
                android: { priority: 'high' },
              },
            }),
          },
        )
        if (response.ok) notified += 1
        else console.error('FCM error', response.status, await response.text())
      }
    }

    return reply({ updated: activities.length, manualCreated, notified })
  } catch (error) {
    console.error(error)
    return reply({ error: 'Status update failed.' }, 500)
  }
})
