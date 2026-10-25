// Generated from scripts/boss_talk.gd. [boss][kind] -> lines
struct FDSLineSet { const TCHAR* const* Lines; int32 Num; };
static const TCHAR* const GLines_demon_engage[] = { TEXT("Come, little knight. Let me hear your bones crack!"), TEXT("My shield has broken better men than you.") };
static const TCHAR* const GLines_demon_hit[] = { TEXT("HAH! Did that hurt?"), TEXT("Weak. So weak."), TEXT("Crawl back to your fire!") };
static const TCHAR* const GLines_demon_low[] = { TEXT("You are nearly dead. Beg!"), TEXT("I can smell your fear, knight.") };
static const TCHAR* const GLines_demon_heal[] = { TEXT("Drink, drink! It will not save you!"), TEXT("Stalling? Pathetic!") };
static const TCHAR* const GLines_demon_hurt[] = { TEXT("A scratch! You call that a blow?"), TEXT("You only make me angrier!"), TEXT("Hmph... lucky strike.") };
static const TCHAR* const GLines_demon_dodge[] = { TEXT("Run, little rat!"), TEXT("Dancing will not save you!") };
static const TCHAR* const GLines_demon_block[] = { TEXT("Hide behind your tin plate!"), TEXT("Your shield will shatter, like the rest.") };
static const TCHAR* const GLines_demon_phase[] = { TEXT("ENOUGH! FEEL MY WRATH!"), TEXT("NOW I AM SERIOUS!") };
static const TCHAR* const GLines_demon_idle[] = { TEXT("Is that all the Ashen Order sent?"), TEXT("Come closer. I will not bite. Much."), TEXT("Where is your courage?") };
static const TCHAR* const GLines_demon_kill[] = { TEXT("Another fool for the asylum floor."), TEXT("Told you. Turn back.") };
static const TCHAR* const GLines_demon_death[] = { TEXT("No... the princess... is beyond... you..."), TEXT("Impossible... a mere knight...") };
static const TCHAR* const GLines_serpent_engage[] = { TEXT("Sssss... such a pretty statue you will make."), TEXT("Welcome to my garden, little knight.") };
static const TCHAR* const GLines_serpent_hit[] = { TEXT("Sss... sweet, sweet pain."), TEXT("Bleed for me, Ashen one."), TEXT("My venom runs in you now!") };
static const TCHAR* const GLines_serpent_low[] = { TEXT("You are fading... how delicious."), TEXT("Ssslow now... sssleep.") };
static const TCHAR* const GLines_serpent_heal[] = { TEXT("Sssip your potion... it only prolongs the fun."), TEXT("Sssuch desperation!") };
static const TCHAR* const GLines_serpent_hurt[] = { TEXT("You dare cut the Queen?!"), TEXT("Sss... a bite for a bite!"), TEXT("My children will feast on you!") };
static const TCHAR* const GLines_serpent_dodge[] = { TEXT("You cannot sssslither away!"), TEXT("Run, run, sssmall thing.") };
static const TCHAR* const GLines_serpent_block[] = { TEXT("Hiding? How very reptilian."), TEXT("Sssscared of my gaze?") };
static const TCHAR* const GLines_serpent_phase[] = { TEXT("SSSSEE MY TRUE FORM!"), TEXT("THE GARDEN AWAKENS!") };
static const TCHAR* const GLines_serpent_idle[] = { TEXT("Look into my eyes... look..."), TEXT("Sssso much stone to add to my garden."), TEXT("Do not struggle...") };
static const TCHAR* const GLines_serpent_kill[] = { TEXT("Sssss... another one for the garden."), TEXT("Sleep, little knight.") };
static const TCHAR* const GLines_serpent_death[] = { TEXT("Sss... my garden... withers..."), TEXT("The... stone... cracks...") };
static const TCHAR* const GLines_cyborg_engage[] = { TEXT("TARGET LOCKED. PROBABILITY OF SURVIVAL: 0.3 PERCENT."), TEXT("INTRUDER DETECTED. INITIATING PURGE.") };
static const TCHAR* const GLines_cyborg_hit[] = { TEXT("DAMAGE CONFIRMED. CONTINUING."), TEXT("HOSTILE WEAKENING."), TEXT("IMPACT SUCCESSFUL.") };
static const TCHAR* const GLines_cyborg_low[] = { TEXT("HOSTILE VITALS CRITICAL. TERMINATION IMMINENT."), TEXT("YOUR HEARTBEAT IS FAILING.") };
static const TCHAR* const GLines_cyborg_heal[] = { TEXT("HEALING DETECTED. FUTILE."), TEXT("CONSUMABLE USE DOES NOT ALTER OUTCOME.") };
static const TCHAR* const GLines_cyborg_hurt[] = { TEXT("ARMOUR INTEGRITY DECLINING. RECALCULATING."), TEXT("MINOR DAMAGE. IGNORED."), TEXT("SYSTEMS NOMINAL. MOSTLY.") };
static const TCHAR* const GLines_cyborg_dodge[] = { TEXT("EVASION PATTERN LOGGED."), TEXT("RUNNING ONLY DELAYS DELETION.") };
static const TCHAR* const GLines_cyborg_block[] = { TEXT("SHIELD ANALYSIS: INSUFFICIENT."), TEXT("DEFENCE WILL BE BREACHED.") };
static const TCHAR* const GLines_cyborg_phase[] = { TEXT("WARNING. WEAPONS SYSTEMS UNLEASHED."), TEXT("OVERRIDE ENGAGED. NO MERCY PROTOCOL.") };
static const TCHAR* const GLines_cyborg_idle[] = { TEXT("SCANNING... SCANNING... YOU ARE STILL HERE."), TEXT("THE BRIDGE IS MY DOMAIN."), TEXT("SURRENDER IS NOT IN YOUR PROGRAMMING.") };
static const TCHAR* const GLines_cyborg_kill[] = { TEXT("TARGET ELIMINATED. MISSION COMPLETE."), TEXT("HOSTILE TERMINATED.") };
static const TCHAR* const GLines_cyborg_death[] = { TEXT("CRITICAL... FAILURE... SHUTTING... DOWN..."), TEXT("ERR... OR... THE... GATE... OPENS...") };
static const TCHAR* const GLines_malakar_engage[] = { TEXT("So the little knight finally crawls to my throne."), TEXT("Dawn will never come, Ashen one.") };
static const TCHAR* const GLines_malakar_hit[] = { TEXT("Feel the dark, knight!"), TEXT("Did you think you could win?"), TEXT("Your light is so dim.") };
static const TCHAR* const GLines_malakar_low[] = { TEXT("Look at you. Barely standing. Kneel!"), TEXT("Your princess will watch you die.") };
static const TCHAR* const GLines_malakar_heal[] = { TEXT("Heal all you like. I devoured the guardians!"), TEXT("A flask? How quaint.") };
static const TCHAR* const GLines_malakar_hurt[] = { TEXT("Hah! You scratch a god!"), TEXT("Enough games!"), TEXT("You only delay the inevitable.") };
static const TCHAR* const GLines_malakar_dodge[] = { TEXT("Fleeing? Just like the others."), TEXT("There is nowhere to hide from me!") };
static const TCHAR* const GLines_malakar_block[] = { TEXT("Your shield is nothing before the abyss!"), TEXT("Break, little wall, break!") };
static const TCHAR* const GLines_malakar_phase[] = { TEXT("YOU WILL WITNESS TRUE DARKNESS!"), TEXT("BEHOLD THE POWER OF EVERY GUARDIAN!"), TEXT("KNEEL!") };
static const TCHAR* const GLines_malakar_idle[] = { TEXT("Elara screams your name. Can you hear her?"), TEXT("Come, take my head. If you can."), TEXT("I have waited a thousand nights for you.") };
static const TCHAR* const GLines_malakar_kill[] = { TEXT("Darkness wins. As it always does."), TEXT("Elara is mine. Forever.") };
static const TCHAR* const GLines_malakar_death[] = { TEXT("I took their power... the dawn... I cannot..."), TEXT("Impossible... the light... fades me...") };
static const FDSLineSet GBossLines[4][11] = {
	{ { GLines_demon_engage, UE_ARRAY_COUNT(GLines_demon_engage) }, { GLines_demon_hit, UE_ARRAY_COUNT(GLines_demon_hit) }, { GLines_demon_low, UE_ARRAY_COUNT(GLines_demon_low) }, { GLines_demon_heal, UE_ARRAY_COUNT(GLines_demon_heal) }, { GLines_demon_hurt, UE_ARRAY_COUNT(GLines_demon_hurt) }, { GLines_demon_dodge, UE_ARRAY_COUNT(GLines_demon_dodge) }, { GLines_demon_block, UE_ARRAY_COUNT(GLines_demon_block) }, { GLines_demon_phase, UE_ARRAY_COUNT(GLines_demon_phase) }, { GLines_demon_idle, UE_ARRAY_COUNT(GLines_demon_idle) }, { GLines_demon_kill, UE_ARRAY_COUNT(GLines_demon_kill) }, { GLines_demon_death, UE_ARRAY_COUNT(GLines_demon_death) } },
	{ { GLines_serpent_engage, UE_ARRAY_COUNT(GLines_serpent_engage) }, { GLines_serpent_hit, UE_ARRAY_COUNT(GLines_serpent_hit) }, { GLines_serpent_low, UE_ARRAY_COUNT(GLines_serpent_low) }, { GLines_serpent_heal, UE_ARRAY_COUNT(GLines_serpent_heal) }, { GLines_serpent_hurt, UE_ARRAY_COUNT(GLines_serpent_hurt) }, { GLines_serpent_dodge, UE_ARRAY_COUNT(GLines_serpent_dodge) }, { GLines_serpent_block, UE_ARRAY_COUNT(GLines_serpent_block) }, { GLines_serpent_phase, UE_ARRAY_COUNT(GLines_serpent_phase) }, { GLines_serpent_idle, UE_ARRAY_COUNT(GLines_serpent_idle) }, { GLines_serpent_kill, UE_ARRAY_COUNT(GLines_serpent_kill) }, { GLines_serpent_death, UE_ARRAY_COUNT(GLines_serpent_death) } },
	{ { GLines_cyborg_engage, UE_ARRAY_COUNT(GLines_cyborg_engage) }, { GLines_cyborg_hit, UE_ARRAY_COUNT(GLines_cyborg_hit) }, { GLines_cyborg_low, UE_ARRAY_COUNT(GLines_cyborg_low) }, { GLines_cyborg_heal, UE_ARRAY_COUNT(GLines_cyborg_heal) }, { GLines_cyborg_hurt, UE_ARRAY_COUNT(GLines_cyborg_hurt) }, { GLines_cyborg_dodge, UE_ARRAY_COUNT(GLines_cyborg_dodge) }, { GLines_cyborg_block, UE_ARRAY_COUNT(GLines_cyborg_block) }, { GLines_cyborg_phase, UE_ARRAY_COUNT(GLines_cyborg_phase) }, { GLines_cyborg_idle, UE_ARRAY_COUNT(GLines_cyborg_idle) }, { GLines_cyborg_kill, UE_ARRAY_COUNT(GLines_cyborg_kill) }, { GLines_cyborg_death, UE_ARRAY_COUNT(GLines_cyborg_death) } },
	{ { GLines_malakar_engage, UE_ARRAY_COUNT(GLines_malakar_engage) }, { GLines_malakar_hit, UE_ARRAY_COUNT(GLines_malakar_hit) }, { GLines_malakar_low, UE_ARRAY_COUNT(GLines_malakar_low) }, { GLines_malakar_heal, UE_ARRAY_COUNT(GLines_malakar_heal) }, { GLines_malakar_hurt, UE_ARRAY_COUNT(GLines_malakar_hurt) }, { GLines_malakar_dodge, UE_ARRAY_COUNT(GLines_malakar_dodge) }, { GLines_malakar_block, UE_ARRAY_COUNT(GLines_malakar_block) }, { GLines_malakar_phase, UE_ARRAY_COUNT(GLines_malakar_phase) }, { GLines_malakar_idle, UE_ARRAY_COUNT(GLines_malakar_idle) }, { GLines_malakar_kill, UE_ARRAY_COUNT(GLines_malakar_kill) }, { GLines_malakar_death, UE_ARRAY_COUNT(GLines_malakar_death) } },
};
