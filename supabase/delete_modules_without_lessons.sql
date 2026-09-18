-- ============================================================
-- SAFE DELETE: Remove modules that have no lessons.
--
-- IMPORTANT: Run inside the Supabase Dashboard -> SQL Editor.
-- This is a destructive, irreversible operation.
--
-- Recommended workflow:
--   1) Run preview_modules_without_lessons.sql first (verification).
--   2) If the list looks correct, run THIS script to delete.
--
-- A module is considered to have "no lessons" when there are zero
-- rows in the lessons table pointing to it (module_id). Because any
-- lessons under those modules are so few/none, we delete a merged set
-- of empty modules to a query also delete nothing else.
-- ============================================================
BEGIN;

DELETE FROM lesson_modules m
USING (
    SELECT m2.id
    FROM lesson_modules m2
    LEFT JOIN lessons l ON l.module_id = m2.id
    GROUP BY m2.id
    HAVING COUNT(l.id) = 0
) empty_modules
WHERE m.id = empty_modules.id;

COMMIT;

-- Optional confirmation (should now return 0 rows):
-- SELECT COUNT(*) FROM lesson_modules m
-- LEFT JOIN lessons l ON l.module_id = m.id
-- GROUP BY m.id HAVING COUNT(l.id) = 0;
