require 'test_helper'

class InvoiceTest < ActiveSupport::TestCase
  test 'sync_from_stripe maps Clover invoice fields and subscription' do
    account = create(:account)
    subscription = create(:subscription, account: account, stripe_subscription_id: 'sub_123')
    invoice = create(:invoice, account: account)

    customer = mock('customer')
    customer.stubs(:id).returns('cus_123')
    stripe_subscription = mock('subscription')
    stripe_subscription.stubs(:id).returns('sub_123')
    subscription_details = mock('subscription_details')
    subscription_details.stubs(:subscription).returns(stripe_subscription)
    parent = mock('parent')
    parent.stubs(:subscription_details).returns(subscription_details)
    status_transitions = mock('status_transitions')
    status_transitions.stubs(:paid_at).returns(1_700_000_300)

    stripe_invoice = mock('stripe_invoice')
    stripe_invoice.stubs(:customer).returns(customer)
    stripe_invoice.stubs(:parent).returns(parent)
    stripe_invoice.stubs(:number).returns('INV-123')
    stripe_invoice.stubs(:status).returns('paid')
    stripe_invoice.stubs(:amount_due).returns(1_000)
    stripe_invoice.stubs(:amount_paid).returns(1_000)
    stripe_invoice.stubs(:currency).returns('usd')
    stripe_invoice.stubs(:period_start).returns(1_700_000_000)
    stripe_invoice.stubs(:period_end).returns(1_700_000_100)
    stripe_invoice.stubs(:due_date).returns(1_700_000_200)
    stripe_invoice.stubs(:status_transitions).returns(status_transitions)
    stripe_invoice.stubs(:hosted_invoice_url).returns('https://invoice.stripe.com/i/123')
    stripe_invoice.stubs(:invoice_pdf).returns('https://invoice.stripe.com/i/123/pdf')

    invoice.sync_from_stripe(stripe_invoice, subscription: subscription)

    assert_equal 'cus_123', Invoice.stripe_customer_id(stripe_invoice)
    assert_equal 'sub_123', Invoice.stripe_subscription_id(stripe_invoice)
    assert_equal subscription, invoice.subscription
    assert_equal 'INV-123', invoice.number
    assert_equal 'paid', invoice.status
    assert_equal 1_000, invoice.amount_due_cents
    assert_equal 1_000, invoice.amount_paid_cents
    assert_equal Time.at(1_700_000_000), invoice.period_start
    assert_equal Time.at(1_700_000_100), invoice.period_end
    assert_equal Time.at(1_700_000_200), invoice.due_date
    assert_equal Time.at(1_700_000_300), invoice.paid_at
  end

  test 'stripe_subscription_id is nil for a standalone invoice' do
    stripe_invoice = mock('stripe_invoice')
    stripe_invoice.stubs(:parent).returns(nil)

    assert_nil Invoice.stripe_subscription_id(stripe_invoice)
  end
end
