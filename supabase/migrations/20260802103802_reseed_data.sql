-- Re-seed: Classrooms (teacher centers)
INSERT INTO public.classrooms (id, teacher_name, school_code, created_at)
VALUES
  ('c1111111-1111-1111-1111-111111111111'::uuid, 'مستر محمد علي', 'ALI2026', NOW()),
  ('c2222222-2222-2222-2222-222222222222'::uuid, 'مستر أحمد حسن', 'HASSAN88', NOW())
ON CONFLICT (id) DO NOTHING;

-- Re-seed: Activation Codes
INSERT INTO public.activation_codes (code, duration_days, claimed_by, claimed_at, created_at)
VALUES
  ('VIP-30DAYS', 30, NULL, NULL, NOW()),
  ('CODE-15D',   15, NULL, NULL, NOW()),
  ('FREE-WEEK',   7, NULL, NULL, NOW()),
  ('QATALY-SUPER',90, NULL, NULL, NOW())
ON CONFLICT (code) DO NOTHING;

-- Re-seed: Passages (5 passages difficulty 1-5)
INSERT INTO public.passages (id, passage_text, difficulty_level, vocabulary_used, qa_json, created_at)
VALUES
  (
    'a1111111-1111-1111-1111-111111111111'::uuid,
    'The solar system is a vast and interesting place. It has eight planets orbiting the Sun. Earth is the third planet and the only one known to support life. The inner planets, like Mars and Venus, are rocky. The outer planets, like Jupiter and Saturn, are gas giants. Astronauts dream of exploring Mars one day to search for evidence of frozen water.',
    1,
    ARRAY['orbiting','support','evidence','rocky','exploring'],
    '{"questions":[{"id":1,"question_text":"How many planets are in our solar system?","options":{"A":"Five","B":"Eight","C":"Ten","D":"Twelve"},"correct_option":"B","explanation":"القطعة بتقول صراحة eight planets، الإجابة B."},{"id":2,"question_text":"Which planet is the only one known to support life?","options":{"A":"Mars","B":"Venus","C":"Earth","D":"Jupiter"},"correct_option":"C","explanation":"Earth هي الكوكب الوحيد المعروف بوجود حياة عليه، الإجابة C."},{"id":3,"question_text":"What are Jupiter and Saturn described as?","options":{"A":"Rocky planets","B":"Ice giants","C":"Gas giants","D":"Dwarf planets"},"correct_option":"C","explanation":"القطعة بتوصفهم بـ gas giants، الإجابة C."},{"id":4,"question_text":"What do astronauts hope to find on Mars?","options":{"A":"Frozen water","B":"Diamonds","C":"Oil","D":"Gold"},"correct_option":"A","explanation":"القطعة بتقول بيدوروا على evidence of frozen water على المريخ، الإجابة A."},{"id":5,"question_text":"What does the word orbiting mean?","options":{"A":"Exploding","B":"Revolving around","C":"Landing on","D":"Disappearing"},"correct_option":"B","explanation":"Orbiting يعني بيدور حوالين، زي الكواكب بتدور حوالين الشمس، الإجابة B."},{"id":6,"question_text":"Which planets are described as rocky?","options":{"A":"Jupiter and Saturn","B":"Earth and Mars","C":"Mars and Venus","D":"Neptune and Uranus"},"correct_option":"C","explanation":"القطعة بتقول inner planets like Mars and Venus are rocky، الإجابة C."}]}'::jsonb,
    NOW()
  ),
  (
    'a2222222-2222-2222-2222-222222222222'::uuid,
    'Exercising daily is vital for maintaining physical health. People who walk or jog every morning have better heart rate efficiency. In addition to physical benefits, exercise releases chemicals in the brain called endorphins, which make you feel happy. Doctors recommend at least thirty minutes of active movement daily.',
    2,
    ARRAY['vital','efficiency','recommend','endorphins','maintain'],
    '{"questions":[{"id":1,"question_text":"What chemical does the brain release during exercise?","options":{"A":"Water","B":"Adrenaline","C":"Endorphins","D":"Glucose"},"correct_option":"C","explanation":"القطعة بتقول المخ بيفرز endorphins اللي بتحسن المزاج، الإجابة C."},{"id":2,"question_text":"How many minutes of exercise do doctors recommend daily?","options":{"A":"Ten","B":"Twenty","C":"Thirty","D":"Sixty"},"correct_option":"C","explanation":"القطعة بتقول at least thirty minutes، الإجابة C."},{"id":3,"question_text":"What does vital mean in the passage?","options":{"A":"Optional","B":"Very important","C":"Difficult","D":"Expensive"},"correct_option":"B","explanation":"Vital يعني حيوي وضروري جداً، الإجابة B."},{"id":4,"question_text":"What physical activity is mentioned in the passage?","options":{"A":"Swimming","B":"Cycling","C":"Walking or jogging","D":"Boxing"},"correct_option":"C","explanation":"القطعة بتذكر walking or jogging every morning، الإجابة C."},{"id":5,"question_text":"What does exercise improve besides happiness?","options":{"A":"Memory","B":"Heart rate efficiency","C":"Eyesight","D":"Hearing"},"correct_option":"B","explanation":"القطعة بتقول better heart rate efficiency، الإجابة B."},{"id":6,"question_text":"Endorphins are released by which organ?","options":{"A":"Heart","B":"Lungs","C":"Liver","D":"Brain"},"correct_option":"D","explanation":"القطعة بتقول exercise releases chemicals in the brain، الإجابة D."}]}'::jsonb,
    NOW()
  ),
  (
    'a3333333-3333-3333-3333-333333333333'::uuid,
    'Technology has undeniably altered the landscape of modern education. In the past, pupils relied strictly on printed textbooks, whereas today, digital libraries and AI tools offer instantaneous access to vast repositories of knowledge. However, this digital paradigm shift introduces new pedagogical challenges. Educators must ensure students develop critical thinking rather than relying on automated essay generation tools.',
    3,
    ARRAY['paradigm','pedagogical','repositories','instantaneous','undeniably'],
    '{"questions":[{"id":1,"question_text":"What is the main idea of the passage?","options":{"A":"AI will replace teachers.","B":"Technology changed education requiring balance with critical thinking.","C":"Digital libraries are worse than textbooks.","D":"Students should avoid technology."},"correct_option":"B","explanation":"الفكرة الرئيسية هي إن التكنولوجيا غيرت التعليم بس محتاجين نوازن مع التفكير النقدي، الإجابة B."},{"id":2,"question_text":"What does pedagogical mean?","options":{"A":"Related to health","B":"Related to teaching and education","C":"Related to technology","D":"Related to engineering"},"correct_option":"B","explanation":"Pedagogical تعني تربوي أو تعليمي متعلق بطرق التدريس، الإجابة B."},{"id":3,"question_text":"What did students use before digital tools?","options":{"A":"Tablets","B":"AI tools","C":"Printed textbooks","D":"Online videos"},"correct_option":"C","explanation":"القطعة بتقول pupils relied on printed textbooks، الإجابة C."},{"id":4,"question_text":"What concern does the passage raise about students?","options":{"A":"They read too many books","B":"They may rely on automated essay tools instead of thinking","C":"They study too many hours","D":"They avoid technology"},"correct_option":"B","explanation":"القطعة بتحذر من إن الطلاب يعتمدوا على automated essay generation بدل ما يفكروا بنفسهم، الإجابة B."},{"id":5,"question_text":"What does repositories mean?","options":{"A":"Questions","B":"Schools","C":"Storage places for knowledge","D":"Textbooks"},"correct_option":"C","explanation":"Repositories تعني مستودعات أو مخازن المعرفة، الإجابة C."},{"id":6,"question_text":"What does instantaneous mean?","options":{"A":"Slow and gradual","B":"Immediate, happening at once","C":"Very expensive","D":"Difficult to understand"},"correct_option":"B","explanation":"Instantaneous يعني فوري، حاصل في اللحظة دي، الإجابة B."}]}'::jsonb,
    NOW()
  ),
  (
    'a4444444-4444-4444-4444-444444444444'::uuid,
    'The Industrial Revolution marked a major turning point in human history, transitioning agrarian societies into mechanized industrial powerhouses. Beginning in Great Britain in the late 18th century, it rapidly disseminated across the globe. While it catalyzed unprecedented economic growth, it also precipitated massive urbanization, resulting in deplorable living conditions for the working class. The discrepancy between the affluent factory owners and impoverished laborers sparked early labor unions.',
    4,
    ARRAY['disseminated','precipitated','deplorable','discrepancy','affluent'],
    '{"questions":[{"id":1,"question_text":"What initiated the formation of early labor unions?","options":{"A":"Transition from Britain to other nations.","B":"Bad weather in the 18th century.","C":"The huge gap between wealthy owners and poor workers.","D":"Reduction in agricultural production."},"correct_option":"C","explanation":"القطعة بتقول الفجوة بين الأغنياء والفقراء أشعلت فكرة النقابات العمالية، الإجابة C."},{"id":2,"question_text":"What does disseminated mean?","options":{"A":"Disappeared","B":"Spread widely","C":"Collapsed","D":"Destroyed"},"correct_option":"B","explanation":"Disseminated يعني انتشر على نطاق واسع، الإجابة B."},{"id":3,"question_text":"Where did the Industrial Revolution begin?","options":{"A":"France","B":"USA","C":"Germany","D":"Great Britain"},"correct_option":"D","explanation":"القطعة بتقول Beginning in Great Britain، الإجابة D."},{"id":4,"question_text":"What does deplorable mean?","options":{"A":"Excellent","B":"Very bad and shocking","C":"Expensive","D":"Organized"},"correct_option":"B","explanation":"Deplorable يعني مزري وبائس للغاية، الإجابة B."},{"id":5,"question_text":"What does affluent mean?","options":{"A":"Poor","B":"Educated","C":"Wealthy","D":"Powerful"},"correct_option":"C","explanation":"Affluent يعني ثري وغني، الإجابة C."},{"id":6,"question_text":"What type of societies transitioned during the Industrial Revolution?","options":{"A":"Nomadic societies","B":"Agrarian (farming) societies","C":"Fishing communities","D":"Trading societies"},"correct_option":"B","explanation":"القطعة بتقول transitioning agrarian societies، يعني مجتمعات زراعية، الإجابة B."}]}'::jsonb,
    NOW()
  ),
  (
    'a5555555-5555-5555-5555-555555555555'::uuid,
    'Language acquisition has long intrigued researchers. Skinner proposed that language is acquired through behaviorist reinforcement, whereas Chomsky argued for an innate Universal Grammar, suggesting human brains are pre-wired for language. Modern cognitive scientists adopt a connectionist view, arguing that statistical learning from environment exposure shapes linguistic competence. This dispute remains a cornerstone of cognitive science.',
    5,
    ARRAY['acquisition','innate','competence','behaviorist','reinforcement'],
    '{"questions":[{"id":1,"question_text":"What is Chomsky primary claim regarding language?","options":{"A":"Language is learned through reinforcement.","B":"Language is an innate biological capacity in humans.","C":"Language is random and unpredictable.","D":"Language is acquired through devices."},"correct_option":"B","explanation":"تشومسكي بيقول إن اللغة قدرة فطرية موجودة في المخ من الأصل، الإجابة B."},{"id":2,"question_text":"What did Skinner believe about language?","options":{"A":"It is innate","B":"It is acquired through behaviorist reinforcement","C":"It is random","D":"It comes from Universal Grammar"},"correct_option":"B","explanation":"سكينر صاحب نظرية التعزيز السلوكي، بيقول اللغة بتتعلم بالتدريب والمكافأة، الإجابة B."},{"id":3,"question_text":"What does innate mean?","options":{"A":"Learned","B":"Difficult","C":"Natural from birth","D":"Scientific"},"correct_option":"C","explanation":"Innate يعني فطري موجود من الولادة مش متعلم، الإجابة C."},{"id":4,"question_text":"What view do modern cognitive scientists adopt?","options":{"A":"Behaviorist","B":"Universal Grammar","C":"Connectionist","D":"Traditional"},"correct_option":"C","explanation":"العلماء المعاصرين بيتبنوا الـ connectionist view، الإجابة C."},{"id":5,"question_text":"What does competence mean in the passage?","options":{"A":"Competition","B":"Ability and skill","C":"Problem","D":"Speed"},"correct_option":"B","explanation":"Competence تعني كفاءة وقدرة على أداء شيء بامتياز، الإجابة B."},{"id":6,"question_text":"What remains a cornerstone of cognitive science?","options":{"A":"Skinner experiments","B":"Universal Grammar alone","C":"The dispute about language acquisition","D":"Statistical learning models"},"correct_option":"C","explanation":"القطعة بتقول This dispute remains a cornerstone، يعني الجدال ده بيظل أساس علم الإدراك، الإجابة C."}]}'::jsonb,
    NOW()
  )
ON CONFLICT (id) DO NOTHING;
