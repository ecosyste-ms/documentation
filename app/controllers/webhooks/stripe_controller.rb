module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_login

    def create
      payload = request.body.read
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']
      endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
      rescue JSON::ParserError => e
        Rails.logger.error "[Stripe Webhook] Invalid payload: #{e.message}"
        render json: { error: 'Invalid payload' }, status: :bad_request
        return
      rescue Stripe::SignatureVerificationError => e
        Rails.logger.error "[Stripe Webhook] Invalid signature: #{e.message}"
        render json: { error: 'Invalid signature' }, status: :bad_request
        return
      end

      # Store the event in database for audit trail
      stripe_event = StripeEvent.find_or_initialize_by(event_id: event.id)
      stripe_event.assign_attributes(
        event_type: event.type,
        data: event.to_hash
      )
      stripe_event.save!

      Rails.logger.info "[Stripe Webhook] Received event: #{event.type} (#{event.id})"

      # Process the event
      begin
        case event.type
        when 'customer.subscription.created'
          handle_subscription_created(event.data.object)
        when 'customer.subscription.updated'
          handle_subscription_updated(event.data.object)
        when 'customer.subscription.deleted'
          handle_subscription_deleted(event.data.object)
        when 'invoice.payment_succeeded', 'invoice.payment_failed', 'invoice.finalized'
          handle_invoice(event.data.object)
        else
          Rails.logger.info "[Stripe Webhook] Unhandled event type: #{event.type}"
        end

        stripe_event.mark_as_processed!
        Rails.logger.info "[Stripe Webhook] Successfully processed event #{event.id}"
      rescue StandardError => e
        stripe_event.mark_as_failed!(e)
        Rails.logger.error "[Stripe Webhook] Failed to process event #{event.id}: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        render json: { error: 'Webhook processing failed' }, status: :internal_server_error
        return
      end

      render json: { received: true }, status: :ok
    end

    def handle_subscription_created(stripe_subscription)
      stripe_subscription = fetch_object_if_needed(stripe_subscription, Stripe::Subscription)
      update_subscription_from_stripe(stripe_subscription)
    end

    def handle_subscription_updated(stripe_subscription)
      stripe_subscription = fetch_object_if_needed(stripe_subscription, Stripe::Subscription)
      update_subscription_from_stripe(stripe_subscription)
    end

    def handle_subscription_deleted(stripe_subscription)
      # Fetch full object if thin payload
      stripe_subscription = fetch_object_if_needed(stripe_subscription, Stripe::Subscription)

      subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)

      if subscription
        subscription.update!(
          status: 'canceled',
          ended_at: Time.at(stripe_subscription.ended_at || Time.current.to_i)
        )
        Rails.logger.info "[Stripe Webhook] Canceled subscription #{subscription.id}"
      else
        Rails.logger.warn "[Stripe Webhook] Subscription not found: #{stripe_subscription.id}"
      end
    end

    def handle_invoice(stripe_invoice)
      stripe_invoice = fetch_object_if_needed(stripe_invoice, Stripe::Invoice)

      customer_id = Invoice.stripe_customer_id(stripe_invoice)
      account = Account.find_by(stripe_customer_id: customer_id)
      unless account
        Rails.logger.warn "[Stripe Webhook] Account not found for customer #{customer_id}"
        return
      end

      subscription_id = Invoice.stripe_subscription_id(stripe_invoice)
      subscription = account.subscriptions.find_by(stripe_subscription_id: subscription_id)

      invoice = account.invoices.find_or_initialize_by(stripe_invoice_id: stripe_invoice.id)
      invoice.sync_from_stripe(stripe_invoice, subscription: subscription)

      Rails.logger.info "[Stripe Webhook] Synced invoice #{invoice.id} (#{invoice.status})"
    end

    def update_subscription_from_stripe(stripe_subscription)
      subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription.id)

      if subscription
        subscription.sync_from_stripe(stripe_subscription)
        Rails.logger.info "[Stripe Webhook] Updated subscription #{subscription.id}"
      else
        Rails.logger.warn "[Stripe Webhook] Subscription not found: #{stripe_subscription.id}"
      end
    end

    # Handle both thin and snapshot payloads
    # If object is just an ID string, fetch the full object from Stripe
    def fetch_object_if_needed(object, klass)
      if object.is_a?(String)
        Rails.logger.info "[Stripe Webhook] Thin payload detected, fetching #{klass.name} #{object}"
        # Expand items for subscriptions to get billing period data (API 2025+)
        if klass == Stripe::Subscription
          klass.retrieve(object, expand: ['items.data'])
        else
          klass.retrieve(object)
        end
      else
        object
      end
    end
  end
end
