-- Seed data for Qata'ly (قطعلي) production database
-- Classrooms (teacher centers)
INSERT INTO public.classrooms (id, teacher_name, school_code, created_at)
VALUES
  ('c1111111-1111-1111-1111-111111111111'::uuid, 'مستر محمد علي', 'ALI2026', NOW()),
  ('c2222222-2222-2222-2222-222222222222'::uuid, 'مستر أحمد حسن', 'HASSAN88', NOW())
ON CONFLICT (id) DO NOTHING;

-- Activation Codes
INSERT INTO public.activation_codes (code, duration_days, claimed_by, claimed_at, created_at)
VALUES
  ('VIP-30DAYS', 30, NULL, NULL, NOW()),
  ('CODE-15D', 15, NULL, NULL, NOW()),
  ('FREE-WEEK', 7, NULL, NULL, NOW()),
  ('QATALY-SUPER', 90, NULL, NULL, NOW())
ON CONFLICT (code) DO NOTHING;

-- Passages
INSERT INTO public.passages (id, passage_text, difficulty_level, vocabulary_used, qa_json, created_at)
VALUES
  (
    'a1111111-1111-1111-1111-111111111111'::uuid,
    'The solar system is a vast and interesting place. It has eight planets orbiting the Sun. Earth is the third planet and the only one known to support life. The inner planets, like Mars and Venus, are rocky. The outer planets, like Jupiter and Saturn, are gas giants. Astronauts dream of exploring Mars one day to search for evidence of frozen water.',
    1,
    ARRAY['orbiting', 'support', 'evidence'],
    '{"questions": [{"id": 1, "question_text": "How many planets are in our solar system?", "options": {"A": "Five", "B": "Eight", "C": "Ten", "D": "Twelve"}, "correct_option": "B", "explanation": "سؤال مباشر جداً، القطعة بتقول بشكل صريح It has eight planets orbiting the Sun. الإجابة هي (B)."}]}',
    NOW()
  ),
  (
    'a2222222-2222-2222-2222-222222222222'::uuid,
    'Exercising daily is vital for maintaining physical health. People who walk or jog every morning have better heart rate efficiency. In addition to physical benefits, exercise releases chemicals in the brain called endorphins, which make you feel happy. Doctors recommend at least thirty minutes of active movement daily.',
    2,
    ARRAY['vital', 'efficiency', 'recommend'],
    '{"questions": [{"id": 1, "question_text": "What chemical does the brain release during exercise?", "options": {"A": "Water", "B": "Adrenaline", "C": "Endorphins", "D": "Glucose"}, "correct_option": "C", "explanation": "القطعة بتقول إن التمارين بتخلي المخ يفرز مواد كيميائية اسمها endorphins ودي المسؤولة عن تحسين المزاج والإحساس بالسعادة. الإجابة (C)."}]}',
    NOW()
  ),
  (
    'a3333333-3333-3333-3333-333333333333'::uuid,
    'Technology has undeniably altered the landscape of modern education. In the past, pupils relied strictly on printed textbooks, whereas today, digital libraries and AI tools offer instantaneous access to vast repositories of knowledge. However, this digital paradigm shift introduces new pedagogical challenges. Educators must ensure students develop critical thinking rather than relying on automated essay generation tools.',
    3,
    ARRAY['paradigm', 'pedagogical', 'repositories'],
    '{"questions": [{"id": 1, "question_text": "What is the main idea of the passage?", "options": {"A": "AI will completely replace traditional teachers soon.", "B": "Technology has changed education, requiring a balance with critical thinking.", "C": "Digital libraries are inferior to printed textbooks.", "D": "Educational challenges cannot be resolved by modern tools."}, "correct_option": "B", "explanation": "الممر دة بيتكلم عن إزاي التكنولوجيا غيرت التعليم بس لازم نوازن بينها وبين التفكير النقدي. الإجابة (B) هي الوحيدة اللي بتعبر عن التوازن دة."}, {"id": 2, "question_text": "What does the word pedagogical most likely mean?", "options": {"A": "Related to health and medicine.", "B": "Related to teaching and education.", "C": "Related to building materials.", "D": "Related to engineering calculations."}, "correct_option": "B", "explanation": "كلمة pedagogical جاية من pedagogy وهي علم التدريس. السياق بيتكلم عن تحديات تعليمية، فبالتالي معناها متعلق بالتعليم والتدريس (B)."}]}',
    NOW()
  ),
  (
    'a4444444-4444-4444-4444-444444444444'::uuid,
    'The Industrial Revolution marked a major turning point in human history, transitioning agrarian societies into mechanized industrial powerhouses. Beginning in Great Britain in the late 18th century, it rapidly disseminated across the globe. While it catalyzed unprecedented economic growth, it also precipitated massive urbanization, resulting in deplorable living conditions for the working class. The discrepancy between the affluent factory owners and impoverished laborers sparked early labor unions.',
    4,
    ARRAY['disseminated', 'precipitated', 'deplorable', 'discrepancy', 'affluent'],
    '{"questions": [{"id": 1, "question_text": "What initiated the formation of early labor unions?", "options": {"A": "The transition from Great Britain to other global nations.", "B": "The bad weather during the 18th century.", "C": "The huge discrepancy between wealthy owners and poor workers.", "D": "The massive reduction in agricultural production."}, "correct_option": "C", "explanation": "القطعة بتقول إن الفجوة (discrepancy) بين الأغنياء (affluent) والفقراء (impoverished) هي اللي أشعلت فكرة النقابات العمالية الأولى. الإجابة (C)."}, {"id": 2, "question_text": "Which word in the text means spread widely?", "options": {"A": "disseminated", "B": "precipitated", "C": "deplorable", "D": "transitioning"}, "correct_option": "A", "explanation": "كلمة disseminated تعني انتشر على نطاق واسع. الإجابة (A)."}]}',
    NOW()
  ),
  (
    'a5555555-5555-5555-5555-555555555555'::uuid,
    'Language acquisition has long intrigued researchers. Skinner proposed that language is acquired through behaviorist reinforcement, whereas Chomsky argued for an innate Universal Grammar, suggesting human brains are pre-wired for language. Modern cognitive scientists adopt a connectionist view, arguing that statistical learning from environment exposure shapes linguistic competence. This dispute remains a cornerstone of cognitive science.',
    5,
    ARRAY['acquisition', 'innate', 'competence', 'behaviorist', 'reinforcement'],
    '{"questions": [{"id": 1, "question_text": "What is Chomsky primary claim regarding language?", "options": {"A": "Language is learned purely through positive reinforcement.", "B": "Language is an innate, biologically pre-wired capacity in humans.", "C": "Language development is completely random and unpredictable.", "D": "Language is acquired through modern engineering devices."}, "correct_option": "B", "explanation": "تشومسكي (Chomsky) مشهور بنظرية النحو العالمي الفطري (innate Universal Grammar). دة معناه إنها قدرة فطرية (B)."}]}',
    NOW()
  )
ON CONFLICT (id) DO NOTHING;
