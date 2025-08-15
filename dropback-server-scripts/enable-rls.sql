-- Enable Row Level Security for all tables in the public schema
DO $$
DECLARE
    table_record RECORD;
BEGIN
    FOR table_record IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_record.tablename);
            
            -- Create a basic policy that allows access to authenticated users
            EXECUTE format('
                CREATE POLICY "allow_authenticated_users" ON %I
                FOR ALL
                TO authenticated
                USING (true)
                WITH CHECK (true)
            ', table_record.tablename);
        EXCEPTION
            WHEN duplicate_object THEN
                -- Policy already exists, skip
                NULL;
        END;
    END LOOP;
END $$;