-- ============================================================
-- FSL Seed: FSL Alphabet (A-Z) + Numbers (0-9) on Easy mode
--
-- Wires up the full alphabet that the gesture recognizer
-- supports (A-Z except J, which is a dynamic sign) plus the
-- digits 0-9, all with difficulty = 'easy' and is_active = true.
--
-- Idempotent: safe to re-run. Existing rows are left untouched.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1) Ensure an Easy-level exists. Reuse an existing level whose
--    name looks like Easy/Beginner; otherwise create one.
-- ------------------------------------------------------------
CREATE TEMP TABLE easy_level AS
SELECT id, name FROM lesson_levels
WHERE LOWER(name) IN ('easy', 'beginner')
ORDER BY sort_order ASC
LIMIT 1;

INSERT INTO lesson_levels (name, description, sort_order)
SELECT 'Easy', 'Foundational FSL signs for beginners.', 1
WHERE NOT EXISTS (SELECT 1 FROM easy_level)
RETURNING id, name;

-- Widen the temp view to include a newly created level.
DELETE FROM easy_level;
INSERT INTO easy_level
SELECT id, name FROM lesson_levels
WHERE LOWER(name) IN ('easy', 'beginner')
ORDER BY sort_order ASC
LIMIT 1;

-- ------------------------------------------------------------
-- 2) Ensure the two modules exist.
-- ------------------------------------------------------------
INSERT INTO lesson_modules (id, level_id, title, description, icon, total_lessons, sort_order)
SELECT '11111111-1111-1111-1111-111111111101'::uuid, el.id, 'FSL Alphabet',
       'Learn to fingerspell the Filipino Sign Language alphabet.',
       'spellcheck', 1, 1
FROM easy_level el
WHERE NOT EXISTS (SELECT 1 FROM lesson_modules WHERE id = '11111111-1111-1111-1111-111111111101'::uuid);

INSERT INTO lesson_modules (id, level_id, title, description, icon, total_lessons, sort_order)
SELECT '11111111-1111-1111-1111-111111111102'::uuid, el.id, 'Numbers',
       'Learn the FSL signs for numbers 0 through 9.',
       'pin', 1, 2
FROM easy_level el
WHERE NOT EXISTS (SELECT 1 FROM lesson_modules WHERE id = '11111111-1111-1111-1111-111111111102'::uuid);

-- ------------------------------------------------------------
-- 3) Ensure one lesson per module.
-- ------------------------------------------------------------
INSERT INTO lessons (id, module_id, title, description, total_signs, estimated_minutes, sort_order)
SELECT '22222222-2222-2222-2222-222222222201'::uuid, '11111111-1111-1111-1111-111111111101'::uuid,
       'Alphabet A-Z', 'Fingerspell every letter of the FSL alphabet.', 25, 10, 1
WHERE NOT EXISTS (SELECT 1 FROM lessons WHERE id = '22222222-2222-2222-2222-222222222201'::uuid);

INSERT INTO lessons (id, module_id, title, description, total_signs, estimated_minutes, sort_order)
SELECT '22222222-2222-2222-2222-222222222202'::uuid, '11111111-1111-1111-1111-111111111102'::uuid,
       'Numbers 0-9', 'Sign the FSL numbers from zero to nine.', 10, 5, 1
WHERE NOT EXISTS (SELECT 1 FROM lessons WHERE id = '22222222-2222-2222-2222-222222222202'::uuid);

-- ------------------------------------------------------------
-- 4) Insert alphabet signs (A-Z, excluding the dynamic J sign)
-- ------------------------------------------------------------
-- NOTE: lesson_signs has no 'difficulty' column; the app's model
-- defaults difficulty to 'easy' when the key is absent, so the
-- column list intentionally omits it.
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT        ('aaaaaaaa-0000-0000-0000-' || LPAD(seq::text, 12, '0'))::uuid,
       '22222222-2222-2222-2222-222222222201'::uuid,
       letter, 'FSL sign for ' || letter, letter, true, seq
FROM (
  SELECT chr(g) AS letter, g - 64 AS seq
  FROM generate_series(65, 90) AS g   -- A=65 ... Z=90
) t
WHERE letter <> 'J'                    -- J is a dynamic (motion) sign
  AND NOT EXISTS (
    SELECT 1 FROM lesson_signs s
    WHERE s.lesson_id = '22222222-2222-2222-2222-222222222201'::uuid
      AND UPPER(s.ai_label) = t.letter
  );

-- ------------------------------------------------------------
-- 5) Insert number signs (0-9)
-- ------------------------------------------------------------
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT        ('bbbbbbbb-0000-0000-0000-' || LPAD(seq::text, 12, '0'))::uuid,
       '22222222-2222-2222-2222-222222222202'::uuid,
       label, 'FSL sign for ' || label, ai_label, true, seq
FROM (
  SELECT CASE WHEN n = 0 THEN 'Zero' ELSE (n)::text END AS label,
         CASE WHEN n = 0 THEN '0'  ELSE (n)::text END AS ai_label,
         n + 1 AS seq
  FROM generate_series(0, 9) AS n
) t
WHERE NOT EXISTS (
    SELECT 1 FROM lesson_signs s
    WHERE s.lesson_id = '22222222-2222-2222-2222-222222222202'::uuid
      AND UPPER(s.ai_label) = UPPER(t.ai_label)
  );

-- ------------------------------------------------------------
-- 6) Ensure a Greetings module + lesson exists (motion-based signs).
--    Kumusta (hello), Salamat (thank you), Paalam (goodbye).
-- ------------------------------------------------------------
INSERT INTO lesson_modules (id, level_id, title, description, icon, total_lessons, sort_order)
SELECT '11111111-1111-1111-1111-111111111103'::uuid, el.id, 'Greetings',
       'Everyday FSL greetings you can sign with your hands.',
       'waving_hand', 1, 3
FROM easy_level el
WHERE NOT EXISTS (SELECT 1 FROM lesson_modules WHERE id = '11111111-1111-1111-1111-111111111103'::uuid);

INSERT INTO lessons (id, module_id, title, description, total_signs, estimated_minutes, sort_order)
SELECT '22222222-2222-2222-2222-222222222203'::uuid, '11111111-1111-1111-1111-111111111103'::uuid,
       'Greetings Basics', 'Salamat, Paalam, and more.', 3, 3, 1
WHERE NOT EXISTS (SELECT 1 FROM lessons WHERE id = '22222222-2222-2222-2222-222222222203'::uuid);

-- Kumusta (hello) - vertical up/down wave
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT 'cccccccc-0000-0000-0000-000000000001'::uuid,
       '22222222-2222-2222-2222-222222222203'::uuid,
       'Kumusta', 'A friendly greeting. Nod your open hand up and down.', 'KUMASTA', true, 1
WHERE NOT EXISTS (SELECT 1 FROM lesson_signs WHERE id = 'cccccccc-0000-0000-0000-000000000001'::uuid);

-- Salamat (thank you) - outward push-away sweep
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT 'cccccccc-0000-0000-0000-000000000002'::uuid,
       '22222222-2222-2222-2222-222222222203'::uuid,
       'Salamat', 'Thank you. Sweep your open hand outward from your chin.', 'SALAMAT', true, 2
WHERE NOT EXISTS (SELECT 1 FROM lesson_signs WHERE id = 'cccccccc-0000-0000-0000-000000000002'::uuid);

-- Paalam (goodbye) - horizontal side-to-side wave
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT 'cccccccc-0000-0000-0000-000000000003'::uuid,
       '22222222-2222-2222-2222-222222222203'::uuid,
       'Paalam', 'Goodbye. Wave your open hand side to side.', 'PAALAM', true, 3
WHERE NOT EXISTS (SELECT 1 FROM lesson_signs WHERE id = 'cccccccc-0000-0000-0000-000000000003'::uuid);

-- ------------------------------------------------------------
-- 7) Ensure an Intermediate-level exists, then add an Emergency Signs
--    module + lesson underneath it. These motion-based signs are
--    recognized live via the EmergencyMotionRecognizer.
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

INSERT INTO lesson_modules (id, level_id, title, description, icon, total_lessons, sort_order)
SELECT '11111111-1111-1111-1111-111111111104'::uuid, il.id, 'Emergency Signs',
       'Motion-based FSL signs for emergencies and getting help.',
       'emergency', 1, 1
FROM intermediate_level il
WHERE NOT EXISTS (SELECT 1 FROM lesson_modules WHERE id = '11111111-1111-1111-1111-111111111104'::uuid);

INSERT INTO lessons (id, module_id, title, description, total_signs, estimated_minutes, sort_order)
SELECT '22222222-2222-2222-2222-222222222204'::uuid, '11111111-1111-1111-1111-111111111104'::uuid,
       'Emergency Basics', 'Signal for help, fire, danger, and medical needs.', 4, 5, 1
WHERE NOT EXISTS (SELECT 1 FROM lessons WHERE id = '22222222-2222-2222-2222-222222222204'::uuid);

-- HELP - single strong vertical thrust (pumping fist upward)
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT 'cccccccc-0000-0000-0000-000000000004'::uuid,
       '22222222-2222-2222-2222-222222222204'::uuid,
       'Help', 'Pump your closed hand upward to ask for help.', 'HELP', true, 1
WHERE NOT EXISTS (SELECT 1 FROM lesson_signs WHERE id = 'cccccccc-0000-0000-0000-000000000004'::uuid);

-- FIRE - vigorous shake / tremor of the hand
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT 'cccccccc-0000-0000-0000-000000000005'::uuid,
       '22222222-2222-2222-2222-222222222204'::uuid,
       'Fire', 'Shake your open hand vigorously to signal fire.', 'FIRE', true, 2
WHERE NOT EXISTS (SELECT 1 FROM lesson_signs WHERE id = 'cccccccc-0000-0000-0000-000000000005'::uuid);

-- DANGER - single hard horizontal strike (sharp sideways snap)
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT 'cccccccc-0000-0000-0000-000000000006'::uuid,
       '22222222-2222-2222-2222-222222222204'::uuid,
       'Danger', 'Strike your open hand sharply to the side to warn of danger.', 'DANGER', true, 3
WHERE NOT EXISTS (SELECT 1 FROM lesson_signs WHERE id = 'cccccccc-0000-0000-0000-000000000006'::uuid);

-- MEDICAL - short repeated taps that stay close to the starting spot
INSERT INTO lesson_signs (id, lesson_id, title, description, ai_label, is_active, sort_order)
SELECT 'cccccccc-0000-0000-0000-000000000007'::uuid,
       '22222222-2222-2222-2222-222222222204'::uuid,
       'Medical', 'Tap your hand in place to signal a medical need.', 'MEDICAL', true, 4
WHERE NOT EXISTS (SELECT 1 FROM lesson_signs WHERE id = 'cccccccc-0000-0000-0000-000000000007'::uuid);

COMMIT;

-- ------------------------------------------------------------
-- Optional sanity check (run separately if you want to verify):
--   SELECT ls.title FROM lesson_signs ls
--   JOIN lessons l ON l.id = ls.lesson_id
--   ORDER BY ls.lesson_id, ls.sort_order;
-- ------------------------------------------------------------
