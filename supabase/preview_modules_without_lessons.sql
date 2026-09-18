-- ============================================================
-- SAFE DELETE: Remove modules that have no lessons.
--
-- IMPORTANT: Run inside the Supabase Dashboard -> SQL Editor.
-- This is a destructive, irreversible operation.
--
-- Step 1 (RECOMMENDED) — PREVIEW first. Run this SELECT to see the
-- module rows that WILL be deleted. Verify the list before deleting.
-- ============================================================
SELECT m.id, m.title, m.description, m.total_lessons
FROM lesson_modules m
LEFT JOIN lessons l ON l.module_id = m.id
GROUP BY m.id
HAVING COUNT(l.id) = 0
ORDER BY m.sort_order;
