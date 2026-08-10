class Invoice < ApplicationRecord
  belongs_to :account
  belongs_to :subscription, optional: true

  validates :status, presence: true, inclusion: {
    in: %w[draft open paid uncollectible void]
  }
  validates :amount_due_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_paid_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :draft, -> { where(status: 'draft') }
  scope :open, -> { where(status: 'open') }
  scope :paid, -> { where(status: 'paid') }
  scope :unpaid, -> { where(status: ['draft', 'open']) }
  scope :overdue, -> { where(status: 'open').where('due_date < ?', Time.current) }

  def amount_due_dollars
    amount_due_cents / 100.0
  end

  def amount_due_dollars=(dollars)
    self.amount_due_cents = (dollars.to_f * 100).to_i
  end

  def amount_paid_dollars
    amount_paid_cents / 100.0
  end

  def amount_paid_dollars=(dollars)
    self.amount_paid_cents = (dollars.to_f * 100).to_i
  end

  def formatted_amount
    "$#{'%.2f' % amount_due_dollars}"
  end

  def paid?
    status == 'paid'
  end

  def open?
    status == 'open'
  end

  def draft?
    status == 'draft'
  end

  def overdue?
    open? && due_date.present? && due_date < Time.current
  end

  def mark_paid!
    update(status: 'paid', paid_at: Time.current, amount_paid_cents: amount_due_cents)
  end

  def mark_void!
    update(status: 'void')
  end

  def mark_uncollectible!
    update(status: 'uncollectible')
  end

  def finalize!
    update(status: 'open') if draft?
  end

  def month
    (period_start || created_at).strftime('%B %Y')
  end

  def invoice_url
    hosted_invoice_url || "#"
  end

  def sync_from_stripe(stripe_invoice, subscription: nil)
    assign_attributes(
      self.class.stripe_attributes(stripe_invoice).merge(subscription: subscription)
    )
    save!
  end

  def self.stripe_attributes(stripe_invoice)
    paid_at = stripe_invoice.status_transitions&.paid_at

    {
      number: stripe_invoice.number,
      status: stripe_invoice.status,
      amount_due_cents: stripe_invoice.amount_due,
      amount_paid_cents: stripe_invoice.amount_paid || 0,
      currency: stripe_invoice.currency,
      period_start: stripe_time(stripe_invoice.period_start),
      period_end: stripe_time(stripe_invoice.period_end),
      due_date: stripe_time(stripe_invoice.due_date),
      paid_at: stripe_time(paid_at),
      hosted_invoice_url: stripe_invoice.hosted_invoice_url,
      invoice_pdf_url: stripe_invoice.invoice_pdf
    }
  end

  def self.stripe_customer_id(stripe_invoice)
    stripe_object_id(stripe_invoice.customer)
  end

  def self.stripe_subscription_id(stripe_invoice)
    subscription = stripe_invoice.parent&.subscription_details&.subscription
    stripe_object_id(subscription)
  end

  def self.stripe_object_id(stripe_object)
    stripe_object.is_a?(String) ? stripe_object : stripe_object&.id
  end

  def self.stripe_time(timestamp)
    Time.at(timestamp) if timestamp
  end
end
