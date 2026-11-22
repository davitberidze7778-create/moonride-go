CREATE OR REPLACE FUNCTION public.go_refund_wallet_on_ride_cancel()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_before numeric(14,2);
  v_after numeric(14,2);
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status
     AND NEW.status IN ('cancelled','no_driver')
     AND NEW.payment_method='wallet'
     AND NEW.payment_status='paid'
     AND NEW.fare_amount>0
     AND NOT EXISTS (
       SELECT 1 FROM public.go_wallet_transactions t
       WHERE t.transaction_type='ride_refund' AND t.source_id=NEW.id
     ) THEN
    SELECT balance INTO v_before
    FROM public.go_wallet_accounts
    WHERE user_id=NEW.passenger_id AND currency_code=NEW.currency_code
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Wallet account missing during ride refund'; END IF;
    UPDATE public.go_wallet_accounts
    SET balance=balance+NEW.fare_amount,updated_at=now()
    WHERE user_id=NEW.passenger_id AND currency_code=NEW.currency_code
    RETURNING balance INTO v_after;
    INSERT INTO public.go_wallet_transactions(
      user_id,currency_code,direction,transaction_type,amount,balance_before,balance_after,
      ride_id,source_type,source_id,note,created_by
    ) VALUES (
      NEW.passenger_id,NEW.currency_code,'credit','ride_refund',NEW.fare_amount,
      v_before,v_after,NEW.id,'ride',NEW.id,'Automatic refund for cancelled wallet ride',NEW.cancelled_by
    );
    UPDATE public.go_rides SET payment_status='refunded' WHERE id=NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;