import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

serve(async (request) => {
  if (request.method != 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const clientId = Deno.env.get('CASHFREE_CLIENT_ID')
    const clientSecret = Deno.env.get('CASHFREE_CLIENT_SECRET')
    const { order_id: orderId } = await request.json()
    if (!clientId || !clientSecret || typeof orderId !== 'string') {
      return json({ error: 'Invalid verification request.' }, 400)
    }

    const isProd = Deno.env.get('CASHFREE_MODE') === 'PROD'
    const baseUrl = isProd ? 'https://api.cashfree.com/pg/orders' : 'https://sandbox.cashfree.com/pg/orders'

    const cashfreeResponse = await fetch(
      `${baseUrl}/${encodeURIComponent(orderId)}`,
      {
        headers: {
          'x-api-version': '2023-08-01',
          'x-client-id': clientId,
          'x-client-secret': clientSecret,
        },
      },
    )
    const responseBody = await cashfreeResponse.json()
    if (!cashfreeResponse.ok) return json({ error: responseBody.message ?? 'Cashfree verification failed.' }, cashfreeResponse.status)

    return json({ order_id: responseBody.order_id, order_status: responseBody.order_status })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unexpected error' }, 500)
  }
})
