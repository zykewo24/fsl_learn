-- ============================================================
-- FSL Seed: Colors + Animals (Intermediate difficulty)
--
-- Adds two more Intermediate modules - "Colors" and "Animals" -
-- each with a single lesson of 6 signs. Every sign is a STATIC
-- hand sign whose frozen handshape matches a letter/digit the
-- static GestureRecognizer already detects (X, B, G, C, P, Y and
-- G, F, Y, V, C, 5 respectively), so camera practice works without
-- new recognition code.
--
-- Each sign ships with a bundled reference image under
-- assets/fsl/colors/ and assets/fsl/animals/ (resolved at runtime
-- via resolveSignAssetPath()).
--
-- Idempotent: safe to re-run. Existing rows are left untouched.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) Ensure an Intermediate-level exists (matches existing seed).
-- ------------------------------------------------------------
CREATE TEMP TABLE intermediate_level AS
SELECT id, name FROM lesson_levels
WHERE LOWER(name) IN ('intermediate', 'mid')
ORDER BY sort_order ASC
LIMIT 1;

INSERT INTO lesson_levels (name, description, sort_order)
SELECT 'Intermediate', 'Expanding FSL vocabulary for everyday situations.', 2
WHERE NOT EXISTS (SELECT 1 FROM intermediate_level)
RETURNING id, name;

-- Widen the temp view to include a newly created level.
DELETE FROM intermediate_level;
INSERT INTO intermediate_level
SELECT id, name FROM lesson_levels
WHERE LOWER(name) IN ('intermediate', 'mid')
ORDER BY sort_order ASC
LIMIT 1;

-- ------------------------------------------------------------
-- 2) Ensure the Colors module + lesson exist.
-- ------------------------------------------------------------
INSERT INTO lesson_modules (id, level_id, title, description, icon, total_lessons, sort_order)
SELECT '11111111-1111-1111-1111-111111111106'::uuid, il.id, 'Colors',
       'Static-handshape FSL signs for six common colors.',
       'palette', 1, 3
FROM intermediate_level il
WHERE NOT EXISTS (SELECT 1 FROM lesson_modules WHERE id = '11111111-1111-1111-1111-111111111106'::uuid);

INSERT INTO lessons (id, module_id, title, description, total_signs, estimated_minutes, sort_order)
SELECT '22222222-2222-2222-2222-222222222206'::uuid, '11111111-1111-1111-1111-111111111106'::uuid,
       'Color Basics', 'Red, blue, green, orange, purple, and yellow.', 6, 5, 1
WHERE NOT EXISTS (SELECT 1 FROM lessons WHERE id = '22222222-2222-2222-2222-222222222206'::uuid);

-- ------------------------------------------------------------
-- 3) Insert the colors signs (static handshapes).
--    ai_label values match the bundled asset names AND the
--    _shapeLabelByWord map in ai_practice_screen.dart so each
--    word resolves to the letter/digit the recognizer emits.
-- ------------------------------------------------------------
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT u.uuid, '22222222-2222-2222-2222-222222222206'::uuid,
       st.title, st.description, st.ai_label, true, st.seq
FROM (
  VALUES
    (1,  'Red',    'RED',    'Hold the hook-shaped X handshape near your chin.'),
    (2,  'Blue',   'BLUE',   'Hold the flat B handshape with your palm facing you.'),
    (3,  'Green',  'GREEN',  'Hold the G handshape and give a gentle twist.'),
    (4,  'Orange', 'ORANGE', 'Squeeze the curled C handshape a few times.'),
    (5,  'Purple', 'PURPLE', 'Hold the P handshape with the index and middle down.'),
    (6,  'Yellow', 'YELLOW', 'Hold the Y handshape and give a small shake.')
) AS st(seq, title, ai_label, description)
CROSS JOIN LATERAL (
  SELECT (('eeeeeeee-0000-0000-0000-' || LPAD((st.seq)::text, 12, '0'))::uuid) AS uuid
) u
WHERE NOT EXISTS (
  SELECT 1 FROM lesson_signs s
  WHERE s.lesson_id = '22222222-2222-2222-2222-222222222206'::uuid
    AND UPPER(s.ai_label) = UPPER(st.ai_label)
);

-- ------------------------------------------------------------
-- 4) Ensure the Animals module + lesson exist.
-- ------------------------------------------------------------
INSERT INTO lesson_modules (id, level_id, title, description, icon, total_lessons, sort_order)
SELECT '11111111-1111-1111-1111-111111111107'::uuid, il.id, 'Animals',
       'Static-handshape FSL signs for six common animals.',
       'pets', 1, 4
FROM intermediate_level il
WHERE NOT EXISTS (SELECT 1 FROM lesson_modules WHERE id = '11111111-1111-1111-1111-111111111107'::uuid);

INSERT INTO lessons (id, module_id, title, description, total_signs, estimated_minutes, sort_order)
SELECT '22222222-2222-2222-2222-222222222207'::uuid, '11111111-1111-1111-1111-111111111107'::uuid,
       'Animal Basics', 'Bird, cat, cow, frog, lion, and fish.', 6, 5, 1
WHERE NOT EXISTS (SELECT 1 FROM lessons WHERE id = '22222222-2222-2222-2222-222222222207'::uuid);

-- ------------------------------------------------------------
-- 5) Insert the animals signs (static handshapes).
-- ------------------------------------------------------------
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT u.uuid, '22222222-2222-2222-2222-222222222207'::uuid,
       st.title, st.description, st.ai_label, true, st.seq
FROM (
  VALUES
    (1,  'Bird', 'BIRD', 'Pinch the G handshape in front of you like a beak.'),
    (2,  'Cat',  'CAT',  'Pinch the F handshape at your cheek like whiskers.'),
    (3,  'Cow',  'COW',  'Hold the Y handshape to the side of your head like horns.'),
    (4,  'Frog', 'FROG', 'Hold the V handshape with the fingers up.'),
    (5,  'Lion', 'LION', 'Cup the curved C handshape around your face like a mane.'),
    (6,  'Fish', 'FISH', 'Hold the open 5 hand flat and wiggle it side to side.')
) AS st(seq, title, ai_label, description)
CROSS JOIN LATERAL (
  SELECT (('ffffffff-0000-0000-0000-' || LPAD((st.seq)::text, 12, '0'))::uuid) AS uuid
) u
WHERE NOT EXISTS (
  SELECT 1 FROM lesson_signs s
  WHERE s.lesson_id = '22222222-2222-2222-2222-222222222207'::uuid
    AND UPPER(s.ai_label) = UPPER(st.ai_label)
);

COMMIT;

-- ------------------------------------------------------------
-- Optional sanity check (run separately if you want to verify):
--   SELECT m.title AS module, l.title AS lesson, ls.title AS sign,
--          ls.ai_label
--   FROM lesson_modules m
--   JOIN lessons l ON l.module_id = m.id
--   JOIN lesson_signs ls ON ls.lesson_id = l.id
--   WHERE m.id IN ('11111111-1111-1111-1111-111111111106',
--                  '11111111-1111-1111-1111-111111111107')
--   ORDER BY m.sort_order, ls.sort_order;
-- ------------------------------------------------------------