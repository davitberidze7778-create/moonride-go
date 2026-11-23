-- Tighten trigger-function privileges and index new foreign keys.
REVOKE ALL ON FUNCTION public.go_refund_wallet_on_ride_cancel() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.go_issue_10th_ride_loyalty_reward() FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS go_rides_loyalty_reward_id_idx ON public.go_rides(loyalty_reward_id);
CREATE INDEX IF NOT EXISTS go_vouchers_created_by_idx ON public.go_vouchers(created_by);
CREATE INDEX IF NOT EXISTS go_wallet_transactions_ride_id_idx ON public.go_wallet_transactions(ride_id);
CREATE INDEX IF NOT EXISTS go_wallet_transactions_created_by_idx ON public.go_wallet_transactions(created_by);
CREATE INDEX IF NOT EXISTS go_driver_wallet_transactions_created_by_idx ON public.go_driver_wallet_transactions(created_by);
CREATE INDEX IF NOT EXISTS go_driver_payout_requests_reviewed_by_idx ON public.go_driver_payout_requests(reviewed_by);
CREATE INDEX IF NOT EXISTS go_payment_attempts_ride_id_idx ON public.go_payment_attempts(ride_id);

-- Activate the internal Wallet, one-use voucher and 10th-ride reward modules.
-- Card PSP flags deliberately remain unavailable until provider credentials and webhook verification exist.
UPDATE public.go_app_feature_flags
SET is_enabled=true, is_available=true, updated_at=now()
WHERE feature_key IN ('payment.wallet','promos.vouchers','loyalty.10th_ride','driver.payouts');
