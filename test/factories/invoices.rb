FactoryBot.define do
  factory :invoice do
    account
    sequence(:stripe_invoice_id) { |n| "in_#{n}" }
    sequence(:number) { |n| "INV-#{n}" }
    status { 'draft' }
    amount_due_cents { 0 }
    amount_paid_cents { 0 }
    currency { 'usd' }
  end
end
