-- ============================================================
-- FSL Seed: Everyday Communication (Intermediate difficulty)
--
-- Adds an "Everyday Communication" module + lesson under the
-- Intermediate level with 12 common conversation signs. Each sign
-- ships with a bundled reference image under assets/fsl/everyday/
-- (resolved at runtime via resolveSignAssetPath()).
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
-- 2) Ensure the Everyday Communication module + lesson exist.
-- ------------------------------------------------------------
INSERT INTO lesson_modules (id, level_id, title, description, icon, total_lessons, sort_order)
SELECT '11111111-1111-1111-1111-111111111105'::uuid, il.id, 'Everyday Communication',
       'Common FSL signs for day-to-day conversations.',
       'forum', 1, 2
FROM intermediate_level il
WHERE NOT EXISTS (SELECT 1 FROM lesson_modules WHERE id = '11111111-1111-1111-1111-111111111105'::uuid);

INSERT INTO lessons (id, module_id, title, description, total_signs, estimated_minutes, sort_order)
SELECT '22222222-2222-2222-2222-222222222205'::uuid, '11111111-1111-1111-1111-111111111105'::uuid,
       'Everyday Basics', 'Yes, no, please, sorry, and other daily essentials.', 12, 8, 1
WHERE NOT EXISTS (SELECT 1 FROM lessons WHERE id = '22222222-2222-2222-2222-222222222205'::uuid);

-- ------------------------------------------------------------
-- 3) Insert the everyday communication signs.
--    NOTE: lesson_signs has no 'difficulty' column; intermediate
--    placement comes from the module's level. ai_label values match
--    the bundled asset names in lib/core/utils/sign_asset.dart.
-- ------------------------------------------------------------
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT u.uuid, '22222222-2222-2222-2222-222222222205'::uuid,
       st.title, st.description, st.ai_label, true, st.seq
FROM (
  VALUES
    (1,  'Yes',        'YES',          'Nod your closed hand up and down, like a head nod.'),
    (2,  'No',         'NO',           'Pivot your open hand side to side, palm facing out.'),
    (3,  'Please',     'PLEASE',       'Rub your open hand in a small circle over your chest.'),
    (4,  'Sorry',      'SORRY',        'Rub your fist in a small circle over your chest.'),
    (5,  'Excuse Me',  'EXCUSE_ME',    'Give a gentle wave of your open hand toward someone.'),
    (6,  'Good Morning', 'GOOD_MORNING', 'Raise your open hand from your side up to your chest.'),
    (7,  'Good Night', 'GOOD_NIGHT',   'Tilt your folded hands against your cheek like sleeping.'),
    (8,  'Love',       'LOVE',         'Cross both fists over your chest.'),
    (9,  'Welcome',    'WELCOME',      'Sweep your open hand inward toward your chest.'),
    (10, 'Water',      'WATER',        'Form a W with your fingers and tap your chin.'),
    (11, 'Eat',        'EAT',          'Bring a pinched hand shape up to your mouth.'),
    (12, 'Drink',      'DRINK',        'Form a C with your hand and tilt it toward your mouth.')
) AS st(seq, title, ai_label, description)
CROSS JOIN LATERAL (
  SELECT (('dddddddd-0000-0000-0000-' || LPAD((st.seq)::text, 12, '0'))::uuid) AS uuid
) u
WHERE NOT EXISTS (
  SELECT 1 FROM lesson_signs s
  WHERE s.lesson_id = '22222222-2222-2222-2222-222222222205'::uuid
    AND UPPER(s.ai_label) = UPPER(st.ai_label)
);

COMMIT;

-- ------------------------------------------------------------
-- Optional sanity check (run separately if you want to verify):
--   SELECT ls.title, ls.ai_label FROM lesson_signs ls
--   JOIN lessons l ON l.id = ls.lesson_id
--   WHERE l.id = '22222222-2222-2222-2222-222222222205'::uuid
--   ORDER BY ls.sort_order;
-- ------------------------------------------------------------