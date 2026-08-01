-- Supabase Unified Database Schema

-- 1. PROFILES TABLE
-- Stores user profile data connected to auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    name TEXT,
    budget_goal NUMERIC,
    email TEXT,
    active_since TEXT,
    runs_completed INTEGER DEFAULT 0,
    total_saved NUMERIC DEFAULT 0.0,
    language TEXT DEFAULT 'English',
    preferred_province TEXT,
    preferred_market TEXT,
    sync_over_wifi_only BOOLEAN DEFAULT TRUE
);

-- Enable RLS for Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own profile" 
    ON public.profiles FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT 
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE 
    USING (auth.uid() = id);

-- 2. GROCERY RUNS TABLE
-- Stores the header information for grocery runs
CREATE TABLE IF NOT EXISTS public.grocery_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    budget NUMERIC NOT NULL,
    spent NUMERIC DEFAULT 0.0,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'draft')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for Grocery Runs
ALTER TABLE public.grocery_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select their own runs" 
    ON public.grocery_runs FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own runs" 
    ON public.grocery_runs FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own runs" 
    ON public.grocery_runs FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own runs" 
    ON public.grocery_runs FOR DELETE 
    USING (auth.uid() = user_id);

-- 3. GROCERY RUN ITEMS TABLE
-- Stores individual items added to a specific run
CREATE TABLE IF NOT EXISTS public.grocery_run_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id UUID REFERENCES public.grocery_runs(id) ON DELETE CASCADE NOT NULL,
    commodity TEXT NOT NULL,
    price NUMERIC NOT NULL,
    quantity NUMERIC DEFAULT 1,
    unit TEXT,
    category TEXT,
    market TEXT,
    checked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS for Grocery Run Items
ALTER TABLE public.grocery_run_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select items of their own runs" 
    ON public.grocery_run_items FOR SELECT 
    USING (EXISTS (
        SELECT 1 FROM public.grocery_runs 
        WHERE public.grocery_runs.id = public.grocery_run_items.run_id 
        AND public.grocery_runs.user_id = auth.uid()
    ));

CREATE POLICY "Users can insert items into their own runs" 
    ON public.grocery_run_items FOR INSERT 
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.grocery_runs 
        WHERE public.grocery_runs.id = run_id 
        AND public.grocery_runs.user_id = auth.uid()
    ));

CREATE POLICY "Users can update items in their own runs" 
    ON public.grocery_run_items FOR UPDATE 
    USING (EXISTS (
        SELECT 1 FROM public.grocery_runs 
        WHERE public.grocery_runs.id = public.grocery_run_items.run_id 
        AND public.grocery_runs.user_id = auth.uid()
    ));

CREATE POLICY "Users can delete items from their own runs" 
    ON public.grocery_run_items FOR DELETE 
    USING (EXISTS (
        SELECT 1 FROM public.grocery_runs 
        WHERE public.grocery_runs.id = public.grocery_run_items.run_id 
        AND public.grocery_runs.user_id = auth.uid()
    ));

-- TRIGGERS FOR TIMESTAMPS
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_grocery_runs_updated_at
    BEFORE UPDATE ON public.grocery_runs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- TRIGGER TO AUTOMATICALLY RECALCULATE SPENT BUDGET
CREATE OR REPLACE FUNCTION update_grocery_run_spent()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.grocery_runs
    SET spent = COALESCE((
        SELECT SUM(price * quantity)
        FROM public.grocery_run_items
        WHERE run_id = COALESCE(NEW.run_id, OLD.run_id)
    ), 0.0),
    updated_at = now()
    WHERE id = COALESCE(NEW.run_id, OLD.run_id);
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_recalculate_spent
    AFTER INSERT OR UPDATE OR DELETE ON public.grocery_run_items
    FOR EACH ROW
    EXECUTE FUNCTION update_grocery_run_spent();

-- 4. ACCOUNT DELETION FUNCTION
-- SECURITY DEFINER allows this function to run with postgres bypass privileges to delete from auth.users
CREATE OR REPLACE FUNCTION delete_current_user()
RETURNS void AS $$
BEGIN
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
