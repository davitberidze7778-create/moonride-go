-- Restore the previously agreed live ride-booking and cash-payment methods.
-- Dispatch still requires fresh approved drivers and server-side validation.
UPDATE public.go_app_feature_flags
SET is_enabled = true,
    is_available = true,
    updated_at = now()
WHERE feature_key IN ('ride.booking_dispatch','payment.cash');
