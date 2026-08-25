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
    if (!clientId || !clientSecret) {
      return json({ error: 'Cashfree credentials are not configured.' }, 500)
    }

    const body = await request.json()
    const amount = Number(body.amount)
    const orderId = String(body.merchant_order_id ?? '')
    const phone = String(body.customer_phone ?? '').replace(/\D/g, '').slice(-10)
    if (!/^[A-Za-z0-9_-]{3,45}$/.test(orderId) || !Number.isFinite(amount) || amount <= 0 || phone.length !== 10) {
      return json({ error: 'Invalid Cashfree order details.' }, 400)
    }

    // Test-only: the app sends the amount. Before production, compute it from
    // trusted cart/order data on the server; never trust a client-provided total.
    const isProd = Deno.env.get('CASHFREE_MODE') === 'PROD'
    const baseUrl = isProd ? 'https://api.cashfree.com/pg/orders' : 'https://sandbox.cashfree.com/pg/orders'

    const cashfreeResponse = await fetch(baseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-version': '2023-08-01',
        'x-client-id': clientId,
        'x-client-secret': clientSecret,
      },
      body: JSON.stringify({
        order_id: orderId,
        order_amount: Number(amount.toFixed(2)),
        order_currency: 'INR',
        customer_details: {
          customer_id: `customer_${phone}`,
          customer_name: String(body.customer_name ?? 'Customer').slice(0, 100),
          customer_email: String(body.customer_email ?? '').slice(0, 100),
          customer_phone: phone,
        },
        order_note: `Ziko order ${orderId}`,
      }),
    })
    const responseBody = await cashfreeResponse.json()
    if (!cashfreeResponse.ok) return json({ error: responseBody.message ?? 'Cashfree order creation failed.' }, cashfreeResponse.status)

    return json({ order_id: responseBody.order_id, payment_session_id: responseBody.payment_session_id })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Unexpected error' }, 500)
  }
})
