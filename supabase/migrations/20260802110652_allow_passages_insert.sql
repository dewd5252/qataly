-- Allow authenticated users (students and teachers) to insert AI-generated passages
CREATE POLICY passages_insert ON public.passages
    FOR INSERT TO authenticated WITH CHECK (true);
