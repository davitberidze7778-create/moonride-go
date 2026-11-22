-- Replace a driver's current document atomically while preserving its history.
CREATE OR REPLACE FUNCTION public.go_submit_driver_document(
  p_document_type text,
  p_storage_path text,
  p_expires_at date DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_old_id uuid;
  v_new_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.driver_profiles d ON d.user_id=p.id
    WHERE p.id=v_uid AND p.role='driver' AND p.account_status='active'
  ) THEN
    RAISE EXCEPTION 'Active driver account required' USING ERRCODE='42501';
  END IF;

  IF p_document_type NOT IN (
    'identity_document','driving_license','vehicle_registration',
    'permit','insurance','technical_inspection'
  ) THEN
    RAISE EXCEPTION 'Unsupported driver document type';
  END IF;
  IF p_storage_path IS NULL
     OR p_storage_path NOT LIKE v_uid::text || '/' || p_document_type || '/%'
     OR p_storage_path ~ '(^|/)\.\.?(/|$)' THEN
    RAISE EXCEPTION 'Invalid private storage path';
  END IF;

  SELECT id INTO v_old_id
  FROM public.driver_documents
  WHERE driver_user_id=v_uid AND document_type=p_document_type AND is_current=true
  FOR UPDATE;

  IF v_old_id IS NOT NULL THEN
    UPDATE public.driver_documents
    SET is_current=false
    WHERE id=v_old_id AND driver_user_id=v_uid;
  END IF;

  INSERT INTO public.driver_documents(
    driver_user_id,document_type,storage_path,status,is_current,
    supersedes_document_id,expires_at
  ) VALUES (
    v_uid,p_document_type,p_storage_path,'pending',true,v_old_id,p_expires_at
  ) RETURNING id INTO v_new_id;

  RETURN jsonb_build_object(
    'document_id',v_new_id,
    'supersedes_document_id',v_old_id,
    'status','pending',
    'is_current',true
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.go_submit_driver_document(text,text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.go_submit_driver_document(text,text,date) TO authenticated;
