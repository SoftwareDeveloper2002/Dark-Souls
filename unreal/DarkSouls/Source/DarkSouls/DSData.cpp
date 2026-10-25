#include "DSData.h"

#include "DSRoute.inc"

using E = EDSEnemy;

namespace
{
	const FDSEnemyDef GEnemies[] = {
		// Name, Hp, SpdMin, SpdMax, Dmg, R, Reach, Wind, Rec, Souls, AI, Range, Cd, Fly, Lunge, Proj, Shield
		{ TEXT("HOLLOW SOLDIER"), 45.f, 3.1f, 3.9f, 14.f, 0.7f, 1.9f, 0.55f, 0.7f, 20, EDSAI::Melee },
		{ TEXT("ZOMBIE"), 75.f, 1.7f, 2.3f, 15.f, 0.75f, 1.9f, 0.9f, 0.9f, 24, EDSAI::Melee },
		{ TEXT("GHOUL"), 55.f, 4.2f, 4.8f, 18.f, 0.7f, 2.3f, 0.45f, 0.6f, 34, EDSAI::Melee, 0.f, 0.f, 0.f, 9.f },
		{ TEXT("SKELETON"), 60.f, 3.0f, 3.6f, 16.f, 0.7f, 2.0f, 0.5f, 0.65f, 26, EDSAI::Melee },
		{ TEXT("HOLLOW ARCHER"), 34.f, 2.8f, 3.2f, 12.f, 0.7f, 0.f, 0.8f, 0.f, 28, EDSAI::Ranged, 9.f, 2.4f, 0.f, 0.f, EDSProj::Arrow },
		{ TEXT("CULTIST MAGE"), 40.f, 2.6f, 3.0f, 18.f, 0.7f, 0.f, 0.9f, 0.f, 40, EDSAI::Ranged, 10.f, 2.8f, 0.f, 0.f, EDSProj::Magic },
		{ TEXT("IMP"), 30.f, 3.4f, 3.9f, 16.f, 0.6f, 0.f, 0.7f, 0.f, 32, EDSAI::Ranged, 9.5f, 2.2f, 2.f, 0.f, EDSProj::Fire },
		{ TEXT("FIEND"), 150.f, 3.0f, 3.4f, 26.f, 1.0f, 2.8f, 0.75f, 0.8f, 70, EDSAI::Melee, 0.f, 0.f, 0.f, 6.f },
		{ TEXT("HELLHOUND"), 50.f, 5.4f, 6.2f, 14.f, 0.8f, 2.0f, 0.4f, 0.55f, 30, EDSAI::Melee, 0.f, 0.f, 0.f, 10.f },
		{ TEXT("HOLLOW KNIGHT"), 120.f, 2.3f, 2.6f, 22.f, 0.85f, 2.4f, 0.8f, 0.9f, 50, EDSAI::Melee, 0.f, 0.f, 0.f, 0.f, EDSProj::None, true },
		{ TEXT("STONE SOLDIER"), 95.f, 2.4f, 2.8f, 20.f, 0.85f, 4.0f, 0.7f, 0.8f, 45, EDSAI::Melee },
		{ TEXT("BRUTE"), 260.f, 1.9f, 2.2f, 34.f, 1.1f, 2.9f, 1.0f, 1.2f, 80, EDSAI::Melee },
		{ TEXT("CAPTAIN"), 380.f, 2.8f, 3.0f, 28.f, 1.0f, 2.8f, 0.7f, 0.8f, 200, EDSAI::Melee, 0.f, 0.f, 0.f, 0.f, EDSProj::None, true },
		{ TEXT("ASYLUM DEMON"), 1000.f, 2.9f, 2.9f, 38.f, 1.7f, 3.1f, 0.95f, 1.1f, 1500, EDSAI::Boss },
		{ TEXT("SERPENT QUEEN"), 2000.f, 3.4f, 3.4f, 34.f, 1.4f, 3.2f, 0.8f, 0.9f, 4000, EDSAI::Boss },
		{ TEXT("CYBORG TITAN"), 3500.f, 2.0f, 2.0f, 42.f, 4.5f, 0.f, 1.0f, 1.0f, 6500, EDSAI::Boss },
		{ TEXT("LORD MALAKAR"), 30000.f, 3.3f, 3.3f, 48.f, 1.8f, 3.6f, 0.9f, 0.9f, 12000, EDSAI::Boss },
		{ TEXT("TITAN FIST"), 1.f, 0.f, 0.f, 0.f, 2.6f, 0.f, 1.0f, 1.0f, 0, EDSAI::Fist },
	};
	static_assert(UE_ARRAY_COUNT(GEnemies) == (int32)EDSEnemy::Count, "enemy table out of sync with EDSEnemy");

	const FDSBossDef GBosses[] = {
		{ 5.5f, 5.8f, { 0.5f, 0.f }, 1 },    // demon
		{ 5.2f, 6.0f, { 0.5f, 0.f }, 1 },    // serpent
		{ 5.0f, 0.0f, { 0.5f, 0.f }, 1 },    // cyborg
		{ 7.0f, 7.5f, { 0.66f, 0.33f }, 2 }, // malakar
	};

	const FDSWeaponDef GWeapons[] = {
		{ TEXT("Ashen Longsword"), TEXT("sword"), EDSStyle::Slash,
			{ TEXT("Blade of the Fallen"), TEXT("Knight's Longsword"), TEXT("Moonlight Greatblade"), TEXT("Dragonbane"), TEXT("Aegis of Dawn") },
			{ 24.f, 38.f, 56.f, 80.f, 112.f }, { 0, 700, 2200, 5200, 10000 }, 3.8f, 1.1f, 18.f, 0.42f, 0.14f, 6.f },
		{ TEXT("Demon Cleaver"), TEXT("axe"), EDSStyle::Overhead,
			{ TEXT("Demon Cleaver"), TEXT("Infernal Cleaver"), TEXT("Hellforged Cleaver"), TEXT("Archdemon Cleaver"), TEXT("Cleaver of the Abyss") },
			{ 72.f, 102.f, 142.f, 192.f, 262.f }, { 0, 1200, 3200, 7000, 14000 }, 4.6f, 1.7f, 30.f, 0.78f, 0.4f, 2.f },
		{ TEXT("Serpent Fang"), TEXT("spear"), EDSStyle::Thrust,
			{ TEXT("Serpent Fang"), TEXT("Basilisk Fang"), TEXT("Gorgon Lance"), TEXT("Viper King's Lance"), TEXT("Fang of the Eternal Serpent") },
			{ 44.f, 62.f, 86.f, 118.f, 158.f }, { 0, 900, 2600, 6000, 12000 }, 6.2f, 0.5f, 14.f, 0.46f, 0.2f, 9.f },
		{ TEXT("Ashen Revolver"), TEXT("gun"), EDSStyle::Shoot,
			{ TEXT("Ashen Revolver"), TEXT("Hunter's Revolver"), TEXT("Silver Revolver"), TEXT("Stormcaller Revolver"), TEXT("Dawnbreaker") },
			{ 22.f, 32.f, 46.f, 64.f, 88.f }, { 0, 800, 2400, 5600, 11000 }, 26.f, 0.f, 3.f, 0.3f, 0.f, 0.f },
	};

	// Anim, Dmg, Range, Arc, Stam, Lunge, Time, HitT, Kb, Slam, NumHits, Hits
	const FDSComboStep GComboSword[] = {
		{ TEXT("slash_r"), 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.42f, 0.14f, 1.0f },
		{ TEXT("slash_l"), 1.05f, 1.0f, 1.0f, 1.0f, 1.0f, 0.40f, 0.13f, 1.0f },
		{ TEXT("diag"), 1.3f, 1.05f, 0.85f, 1.2f, 1.1f, 0.52f, 0.22f, 1.4f },
		{ TEXT("lunge"), 1.8f, 1.3f, 0.5f, 1.6f, 1.7f, 0.66f, 0.3f, 2.4f },
	};
	const FDSComboStep GComboCleaver[] = {
		{ TEXT("overhead"), 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.78f, 0.4f, 1.0f, true },
		{ TEXT("sweep"), 0.85f, 1.05f, 1.3f, 0.85f, 1.2f, 0.62f, 0.28f, 1.5f },
		{ TEXT("upper"), 1.1f, 0.95f, 0.9f, 1.0f, 1.0f, 0.7f, 0.3f, 2.0f },
		{ TEXT("overhead"), 1.7f, 1.15f, 1.2f, 1.5f, 0.6f, 1.0f, 0.56f, 3.0f, true },
	};
	const FDSComboStep GComboSpear[] = {
		{ TEXT("thrust"), 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 0.46f, 0.2f, 1.0f },
		{ TEXT("sweep"), 0.8f, 0.85f, 2.2f, 0.9f, 0.4f, 0.5f, 0.22f, 1.6f },
		{ TEXT("double"), 0.75f, 1.0f, 1.0f, 1.1f, 0.9f, 0.7f, 0.18f, 0.8f, false, 2, { 0.18f, 0.4f } },
		{ TEXT("vault"), 1.7f, 1.1f, 0.8f, 1.5f, 1.5f, 0.7f, 0.34f, 2.5f },
	};

	const FDSArmorDef GArmors[] = {
		{ TEXT("Ashen Plate"), 0.f, 0, 0, 0.f, TEXT("The old order's armour.") },
		{ TEXT("Demon Plate"), 0.12f, 30, 0, 0.f, TEXT("+12% defense, +30 health") },
		{ TEXT("Serpent Scale"), 0.10f, 0, 20, 0.08f, TEXT("+10% defense, +20 stamina, +8% speed") },
		{ TEXT("Titan Plating"), 0.20f, 50, 10, 0.f, TEXT("+20% defense, +50 health") },
	};

	const FDSSkillDef GSkills[4][2] = {
		{ { TEXT("whirl"), TEXT("WHIRLWIND"), TEXT("WHIRL"), TEXT("Spin and strike every foe around you"), 600, 400, 20.f, 7.f, EDSAct::Spin },
		  { TEXT("thunder"), TEXT("THUNDER SMITE"), TEXT("THUNDER"), TEXT("Call down lightning on your enemies"), 1500, 700, 25.f, 11.f, EDSAct::Cast } },
		{ { TEXT("quake"), TEXT("EARTHQUAKE"), TEXT("QUAKE"), TEXT("Leap and smash the ground, flattening everything near"), 800, 500, 30.f, 9.f, EDSAct::Quake },
		  { TEXT("rage"), TEXT("BLOOD RAGE"), TEXT("RAGE"), TEXT("Roar: +50% damage and faster for a few seconds"), 1800, 800, 25.f, 16.f, EDSAct::Rage } },
		{ { TEXT("dash"), TEXT("SKEWER DASH"), TEXT("DASH"), TEXT("Charge forward, impaling everything in your path"), 700, 450, 25.f, 7.f, EDSAct::Dash },
		  { TEXT("flurry"), TEXT("VIPER FLURRY"), TEXT("FLURRY"), TEXT("A blinding storm of thrusts"), 1600, 750, 30.f, 10.f, EDSAct::Flurry } },
		{ { TEXT("fan"), TEXT("FAN THE HAMMER"), TEXT("FAN"), TEXT("Empty six shots in a spread (uses 3 ammo)"), 700, 450, 15.f, 6.f, EDSAct::Fan, 3 },
		  { TEXT("blast"), TEXT("EXPLOSIVE ROUND"), TEXT("BLAST"), TEXT("A shell that explodes on impact (uses 2 ammo)"), 1600, 750, 20.f, 9.f, EDSAct::Blast, 2 } },
	};

	const FDSStatDef GStats[] = {
		{ TEXT("attack"), TEXT("ATTACK"), TEXT("+3 damage"), 15, 90 },
		{ TEXT("vigor"), TEXT("HEALTH"), TEXT("+12 max health"), 15, 80 },
		{ TEXT("endurance"), TEXT("STAMINA"), TEXT("+8 max stamina"), 15, 70 },
		{ TEXT("defense"), TEXT("DEFENSE"), TEXT("-4% damage taken"), 10, 110 },
		{ TEXT("mobility"), TEXT("MOBILITY"), TEXT("+3% speed, longer roll"), 10, 100 },
		{ TEXT("regen"), TEXT("REGENERATION"), TEXT("+0.5 health per second"), 10, 120 },
		{ TEXT("potency"), TEXT("POTION POWER"), TEXT("+6 healing per potion"), 10, 90 },
	};

	const FDSChapter GChapters[] = {
		{ TEXT("THE ASHEN GATE"), TEXT("CHAPTER I"), E::Demon, FLinearColor(0.03f, 0.04f, 0.09f), FLinearColor(0.28f, 0.32f, 0.5f), FLinearColor(0.6f, 0.7f, 1.0f), 0.9f, 9.f, 18.f, 220 },
		{ TEXT("THE SUNKEN CRYPT"), TEXT("CHAPTER II"), E::Serpent, FLinearColor(0.02f, 0.07f, 0.06f), FLinearColor(0.22f, 0.42f, 0.36f), FLinearColor(0.5f, 0.95f, 0.8f), 0.8f, 8.f, 15.f, 300 },
		{ TEXT("THE WAILING KEEP"), TEXT("CHAPTER III"), E::Cyborg, FLinearColor(0.06f, 0.07f, 0.12f), FLinearColor(0.4f, 0.46f, 0.62f), FLinearColor(0.8f, 0.88f, 1.0f), 1.0f, 6.f, 12.f, 420 },
		{ TEXT("THE DARK CITADEL"), TEXT("CHAPTER IV"), E::Malakar, FLinearColor(0.1f, 0.02f, 0.03f), FLinearColor(0.4f, 0.2f, 0.24f), FLinearColor(0.95f, 0.5f, 0.45f), 0.85f, 4.f, 9.f, 520 },
	};

	const TCHAR* GTitles[] = {
		TEXT("The Ashen Road"), TEXT("Broken Banners"), TEXT("Wolves of the Wall"), TEXT("Hold the Gate"), TEXT("Captain Varek"),
		TEXT("Archers in the Mist"), TEXT("The Long Watch"), TEXT("Pillars of Ash"), TEXT("Captain Rhogar"), TEXT("The Asylum Demon"),
		TEXT("Beyond the Tunnel"), TEXT("Bones Underfoot"), TEXT("The Whispering Hall"), TEXT("Hold the Stair"), TEXT("Captain Morrow"),
		TEXT("Arrows in the Dark"), TEXT("Vigil of the Dead"), TEXT("The Tomb Road"), TEXT("Captain Sable"), TEXT("The Serpent Queen"),
		TEXT("Winter's Edge"), TEXT("Cultists of the Veil"), TEXT("The Frozen Bridge"), TEXT("Hold the Rampart"), TEXT("Captain Isolde"),
		TEXT("Storm Callers"), TEXT("The Labyrinth of Echoes"), TEXT("Gargoyle Row"), TEXT("Captain Draven"), TEXT("The Cyborg Titan"),
		TEXT("The Black Gate"), TEXT("Blood Courtyard"), TEXT("Hall of Knights"), TEXT("Hold the Bridge"), TEXT("Captain Vael"),
		TEXT("Crimson Casters"), TEXT("The Last Stand"), TEXT("The Throne Road"), TEXT("Captain Kroth"), TEXT("Lord Malakar"),
	};
	static_assert(UE_ARRAY_COUNT(GTitles) == 40, "need 40 quest titles");

	struct FPoolEntry { EDSEnemy Kind; int32 Weight; int32 MinIdx; };

	TArrayView<const FPoolEntry> Pool(int32 Ch)
	{
		static const FPoolEntry P0[] = { { E::Hollow, 5, 1 }, { E::Zombie, 4, 1 }, { E::Imp, 2, 3 }, { E::Archer, 2, 4 }, { E::Hound, 1, 6 } };
		static const FPoolEntry P1[] = { { E::Skeleton, 5, 1 }, { E::Zombie, 3, 1 }, { E::Ghoul, 3, 2 }, { E::Hound, 3, 3 }, { E::Archer, 2, 1 }, { E::Knight, 1, 6 } };
		static const FPoolEntry P2[] = { { E::Mage, 3, 1 }, { E::StoneSoldier, 3, 1 }, { E::Fiend, 2, 2 }, { E::Imp, 3, 1 }, { E::Knight, 2, 3 }, { E::Hound, 2, 2 }, { E::Ghoul, 2, 4 } };
		static const FPoolEntry P3[] = { { E::Knight, 3, 1 }, { E::Fiend, 3, 1 }, { E::Brute, 2, 2 }, { E::Mage, 3, 1 }, { E::Skeleton, 2, 1 }, { E::Ghoul, 2, 1 }, { E::Hound, 2, 2 }, { E::Imp, 2, 1 } };
		switch (FMath::Clamp(Ch, 0, 3))
		{
		case 0: return TArrayView<const FPoolEntry>(P0, UE_ARRAY_COUNT(P0));
		case 1: return TArrayView<const FPoolEntry>(P1, UE_ARRAY_COUNT(P1));
		case 2: return TArrayView<const FPoolEntry>(P2, UE_ARRAY_COUNT(P2));
		default: return TArrayView<const FPoolEntry>(P3, UE_ARRAY_COUNT(P3));
		}
	}

	const FDSBossReward GRewards[] = {
		{ 1500, TEXT("BRONZE KEY"), (int32)EDSWeapon::Cleaver, (int32)EDSArmor::Demon },
		{ 3000, TEXT("SILVER KEY"), (int32)EDSWeapon::Spear, (int32)EDSArmor::Serpent },
		{ 5200, TEXT("GOLD KEY"), -1, (int32)EDSArmor::Cyborg },
		{ 8000, TEXT(""), -1, -1 },
	};

	const FDSLine GIntro[] = {
		{ TEXT(""), TEXT("Night falls over the kingdom of Eldoria. The Dark Lord Malakar has broken the royal gates and stolen away Princess Elara, the last light of the Ashen Throne.") },
		{ TEXT(""), TEXT("He has carried her to the Dark Citadel, sealed behind three keys. Each key is held by one of his lieutenants. The kingdom has fallen. Only one knight remains.") },
		{ TEXT(""), TEXT("You are the last of the Ashen Order. Arm yourself... and bring her home.") },
	};
	const FDSLine GChapterStart0[] = { { TEXT("ELARA"), TEXT("(a faint voice on the wind) Knight... if you can hear me... follow the ash road. I will hold on.") } };
	const FDSLine GChapterStart1[] = { { TEXT(""), TEXT("Beyond the gate lies the Sunken Crypt. The dead do not rest here. Malakar's curse has woken them all.") } };
	const FDSLine GChapterStart2[] = { { TEXT(""), TEXT("Snow and storm swallow the Wailing Keep. Somewhere in the howling dark, the Dread Queen calls the lightning.") } };
	const FDSLine GChapterStart3[] = {
		{ TEXT("ELARA"), TEXT("(a whisper through the stone) You are close... I can feel your light. Do not stop now.") },
		{ TEXT(""), TEXT("The Dark Citadel looms ahead. Beyond it waits Malakar... and the princess.") } };
	const FDSLine GBossIntro10[] = { { TEXT("ASYLUM DEMON"), TEXT("The princess? She is far beyond you, little knight. My shield cannot be broken. Turn back, or be crushed!") } };
	const FDSLine GBossIntro20[] = { { TEXT("SERPENT QUEEN"), TEXT("Sssss... look into my eyes, Ashen knight, and join my garden of stone. My children will tear what remains.") } };
	const FDSLine GBossIntro30[] = { { TEXT("CYBORG TITAN"), TEXT("TARGET ACQUIRED. THE BRIDGE IS THE ONLY WAY ACROSS. YOU WILL NOT SURVIVE IT.") } };
	const FDSLine GBossIntro40[] = { { TEXT("MALAKAR"), TEXT("You came all this way for a girl? I have devoured the power of every guardian you killed. Kneel, Ashen knight.") } };
	const FDSLine GBossDefeat10[] = { { TEXT(""), TEXT("The Asylum Demon falls, its shield shattered. From its hoard you take the BRONZE KEY, the DEMON CLEAVER and the crimson DEMON PLATE.") } };
	const FDSLine GBossDefeat20[] = { { TEXT(""), TEXT("The Serpent Queen coils and goes still. Among her gold lies the SILVER KEY, the SERPENT FANG spear and a coat of SERPENT SCALE.") } };
	const FDSLine GBossDefeat30[] = { { TEXT(""), TEXT("The Cyborg Titan sparks, shudders, and collapses into the chasm. You pull the GOLD KEY and TITAN PLATING from its wreckage. The Dark Citadel's gate will open.") } };
	const FDSLine GBossDefeat40[] = {
		{ TEXT("MALAKAR"), TEXT("Impossible... I took their power... the dawn... I cannot...") },
		{ TEXT(""), TEXT("The Dark Lord crumbles to ash. The cage opens, and Princess Elara steps into the light.") },
		{ TEXT("ELARA"), TEXT("I knew you would come. Thank you, brave knight. The long night is over.") },
		{ TEXT(""), TEXT("Dawn breaks over Eldoria. You have saved the princess.") } };

	template <typename T, int32 N> TArrayView<const T> View(const T (&A)[N]) { return TArrayView<const T>(A, N); }

	TArray<int32> GSites;   // route index of each quest site

	void BuildSites()
	{
		GSites.Reset();
		const int32 Num = DSData::RouteNum();
		const int32 FirstSite = 18, SpawnGap = 3, TunnelLen = 11;
		const int32 Last = Num - 1 - SpawnGap - TunnelLen;
		for (int32 i = 0; i < 40; i++)
		{
			int32 Nominal = FirstSite + FMath::RoundToInt((float)i * (float)(Last - FirstSite) / 39.f);
			if (i >= 10) Nominal += TunnelLen;     // the tunnel takes up route length after quest 10
			int32 Pick = Nominal;
			if ((i + 1) % 10 == 0 && i < 39)
			{
				int32 Best = -1, Lo = Nominal - 7, Hi = Nominal + 8;
				if (i == 9) Hi = Nominal + 1;      // the tunnel starts right after the first boss arena
				for (int32 k = Lo; k < Hi; k++)
					if (k > 0 && k < Num && DSData::RouteClear(k) > Best) { Best = DSData::RouteClear(k); Pick = k; }
			}
			GSites.Add(Pick);
		}
	}
}

namespace DSData
{
	const FDSEnemyDef& Enemy(EDSEnemy T) { return GEnemies[(int32)T]; }
	const FDSBossDef& Boss(EDSEnemy T) { return GBosses[FMath::Clamp((int32)T - (int32)EDSEnemy::Demon, 0, 3)]; }
	const FDSWeaponDef& Weapon(EDSWeapon W) { return GWeapons[(int32)W]; }
	TArrayView<const FDSComboStep> Combo(EDSWeapon W)
	{
		switch (W)
		{
		case EDSWeapon::Sword: return View(GComboSword);
		case EDSWeapon::Cleaver: return View(GComboCleaver);
		case EDSWeapon::Spear: return View(GComboSpear);
		default: return TArrayView<const FDSComboStep>();
		}
	}
	const FDSArmorDef& Armor(EDSArmor A) { return GArmors[(int32)A]; }
	const FDSSkillDef& Skill(EDSWeapon W, int32 Slot) { return GSkills[(int32)W][Slot & 1]; }
	const FDSChapter& Chapter(int32 Ch) { return GChapters[FMath::Clamp(Ch, 0, 3)]; }
	const FDSBossReward& BossReward(int32 QuestN) { return GRewards[FMath::Clamp(QuestN / 10 - 1, 0, 3)]; }
	TArrayView<const FDSStatDef> Stats() { return View(GStats); }
	TArrayView<const FDSLine> Intro() { return View(GIntro); }
	TArrayView<const FDSLine> ChapterStart(int32 Ch)
	{
		switch (Ch) { case 0: return View(GChapterStart0); case 1: return View(GChapterStart1); case 2: return View(GChapterStart2); default: return View(GChapterStart3); }
	}
	TArrayView<const FDSLine> BossIntro(int32 N)
	{
		switch (N) { case 10: return View(GBossIntro10); case 20: return View(GBossIntro20); case 30: return View(GBossIntro30); default: return View(GBossIntro40); }
	}
	TArrayView<const FDSLine> BossDefeat(int32 N)
	{
		switch (N) { case 10: return View(GBossDefeat10); case 20: return View(GBossDefeat20); case 30: return View(GBossDefeat30); default: return View(GBossDefeat40); }
	}

	FDSQuest MakeQuest(int32 N)
	{
		N = FMath::Clamp(N, 1, MaxQuest);
		FDSQuest Q;
		Q.N = N;
		Q.Ch = FMath::Clamp((N - 1) / 10, 0, 3);
		Q.Idx = (N - 1) % 10 + 1;
		Q.Title = GTitles[N - 1];
		for (const FPoolEntry& P : Pool(Q.Ch))
			if (Q.Idx >= P.MinIdx) Q.Table.Add(TPair<EDSEnemy, int32>(P.Kind, P.Weight));
		Q.MaxAlive = FMath::Min(3 + N / 9, 7);
		Q.Interval = FMath::Max(1.6f, 3.2f - N * 0.03f);
		if (Q.Idx == 10)
		{
			Q.Kind = EDSQuestKind::Boss;
			Q.Boss = GChapters[Q.Ch].Boss;
			Q.Text = FString::Printf(TEXT("Defeat %s"), *Q.Title.ToUpper());
			Q.Target = 1;
		}
		else if (N == 27)
		{
			// The Godot game builds a labyrinth here (torch, civilians, treasure). That sub-game is not ported yet: it plays as a survival fight.
			Q.Kind = EDSQuestKind::Survive;
			Q.Target = 28 + N;
			Q.Text = TEXT("Survive the onslaught");
		}
		else if (Q.Idx == 5 || Q.Idx == 9)
		{
			Q.Kind = EDSQuestKind::Elite;
			Q.Text = TEXT("Defeat the Captain");
			Q.Target = 1;
		}
		else if (Q.Idx == 4 || Q.Idx == 7)
		{
			Q.Kind = EDSQuestKind::Survive;
			Q.Target = 28 + N;
			Q.Text = TEXT("Survive the onslaught");
		}
		else
		{
			Q.Kind = EDSQuestKind::Kill;
			Q.Target = 6 + (int32)((N - 1) * 0.3f) + Q.Idx / 2;
			Q.Text = TEXT("Slay the enemy");
		}
		Q.Scale = 1.f + 0.055f * (N - 1);
		Q.DmgScale = 1.f + 0.035f * (N - 1);
		return Q;
	}

	int32 RouteNum() { return UE_ARRAY_COUNT(GRouteClear); }
	FVector2D Route(int32 I) { I = FMath::Clamp(I, 0, RouteNum() - 1); return FVector2D(GRouteXY[I][0], GRouteXY[I][1]); }
	int32 RouteClear(int32 I) { return GRouteClear[FMath::Clamp(I, 0, RouteNum() - 1)]; }
	int32 SiteIndex(int32 N)
	{
		if (GSites.IsEmpty()) BuildSites();
		return GSites[FMath::Clamp(N, 1, 40) - 1];
	}
	FVector2D Site(int32 N) { return Route(SiteIndex(N)); }
	FVector2D DirAt(int32 I) { return (Route(I + 2) - Route(I - 2)).GetSafeNormal(); }
	FVector2D StartPos() { return Route(StartIdx); }
	FVector2D SwordSpot() { return Route(9) + FVector2D(3, 3); }
	FVector2D Checkpoint(int32 N)
	{
		if (N <= 1) return StartPos();
		return Route(SiteIndex(N - 1)) + FVector2D(3, 4);
	}
	TArray<FVector2D> Between(int32 I0, int32 I1, int32 Count)
	{
		TArray<FVector2D> Out;
		for (int32 k = 0; k < Count; k++)
		{
			const float F = (float)(k + 1) / (float)(Count + 1);
			Out.Add(Route((int32)FMath::Lerp((float)I0, (float)I1, F)));
		}
		return Out;
	}
}
