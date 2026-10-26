// Static game data, ported from game.gd (ENEMY / BOSS), weapons.gd, quests.gd, shop.gd and world.gd.
#pragma once

#include "CoreMinimal.h"
#include "Containers/ArrayView.h"

enum class EDSEnemy : uint8
{
	Hollow, Zombie, Ghoul, Skeleton, Archer, Mage, Imp, Fiend, Hound, Knight, StoneSoldier, Brute, Captain,
	Demon, Serpent, Cyborg, Malakar, Fist, Count
};

enum class EDSAI : uint8 { Melee, Ranged, Boss, Fist };
enum class EDSProj : uint8 { None, Arrow, Magic, Fire, Orb, Venom, Missile, Bullet };
enum class EDSWeapon : uint8 { Sword, Cleaver, Spear, Gun, Count };
enum class EDSArmor : uint8 { Ashen, Demon, Serpent, Cyborg, Count };
enum class EDSStyle : uint8 { Slash, Overhead, Thrust, Shoot };
enum class EDSAct : uint8 { Idle, Block, Roll, Attack, Shoot, Drink, Spin, Cast, Quake, Rage, Dash, Flurry, Fan, Blast, Dead };
enum class EDSQuestKind : uint8 { Kill, Survive, Elite, Boss, Maze };

struct FDSEnemyDef
{
	const TCHAR* Name;
	float Hp, SpeedMin, SpeedMax, Dmg, R, Reach, Wind, Rec;
	int32 Souls;
	EDSAI AI;
	float Range = 0.f, Cd = 0.f, Fly = 0.f, Lunge = 0.f;
	EDSProj Proj = EDSProj::None;
	bool bShield = false;
};

struct FDSBossDef { float SlamR, SweepLen; float Phases[2]; int32 NumPhases; };

struct FDSComboStep
{
	const TCHAR* Anim;
	float Dmg, Range, Arc, Stam, Lunge, Time, HitT, Kb;
	bool bSlam = false;
	int32 NumHits = 1;
	float Hits[2] = { 0.f, 0.f };
};

struct FDSWeaponDef
{
	const TCHAR* Name;
	const TCHAR* Icon;
	EDSStyle Style;
	const TCHAR* Names[5];
	float Dmg[5];
	int32 Cost[5];
	float Range, Arc, Stam, Time, HitT, Lunge;
};

struct FDSArmorDef { const TCHAR* Name; float Def; int32 Hp, St; float Mob; const TCHAR* Desc; };

struct FDSSkillDef
{
	const TCHAR* Id;
	const TCHAR* Name;
	const TCHAR* Label;
	const TCHAR* Desc;
	int32 Unlock, LvlCost;
	float St, Cd;
	EDSAct Act;
	int32 Ammo = 0;
};

struct FDSStatDef { const TCHAR* Key; const TCHAR* Label; const TCHAR* Effect; int32 Max, BaseCost; };

struct FDSChapter { const TCHAR* Name; const TCHAR* Sub; EDSEnemy Boss; FLinearColor Fog, Ambient, Moon; float MoonE; float Thunder0, Thunder1; int32 Rain; };

struct FDSBossReward { int32 Souls; const TCHAR* Key; int32 Weapon; int32 Armor; };   // Weapon/Armor: -1 = none

struct FDSLine { const TCHAR* Who; const TCHAR* Text; };

struct FDSComicPanel
{
	const TCHAR* Scene;
	float X, Y, W, H;                  // fractions of the page
	const TCHAR* Cap = TEXT("");       // caption box
	const TCHAR* Cap2 = TEXT("");
	const TCHAR* Bubble = TEXT("");    // speech bubble
	const TCHAR* Sfx = TEXT("");       // sound-effect lettering
};
struct FDSComicPage { const TCHAR* Num; const TCHAR* Title; TArrayView<const FDSComicPanel> Panels; };
struct FDSCreditLine { const TCHAR* Text; int32 Size; bool bBold; };

struct FDSQuest
{
	int32 N = 1, Ch = 0, Idx = 1;
	FString Title;
	EDSQuestKind Kind = EDSQuestKind::Kill;
	EDSEnemy Boss = EDSEnemy::Count;
	FString Text;
	int32 Target = 1;
	TArray<TPair<EDSEnemy, int32>> Table;
	int32 MaxAlive = 3;
	float Interval = 3.2f;
	float Scale = 1.f, DmgScale = 1.f;
};

namespace DSData
{
	const FDSEnemyDef& Enemy(EDSEnemy T);
	const FDSBossDef& Boss(EDSEnemy T);
	const FDSWeaponDef& Weapon(EDSWeapon W);
	TArrayView<const FDSComboStep> Combo(EDSWeapon W);
	const FDSArmorDef& Armor(EDSArmor A);
	const FDSSkillDef& Skill(EDSWeapon W, int32 Slot);
	const FDSChapter& Chapter(int32 Ch);
	const FDSBossReward& BossReward(int32 QuestN);
	TArrayView<const FDSStatDef> Stats();
	TArrayView<const FDSLine> Intro();
	TArrayView<const FDSLine> ChapterStart(int32 Ch);
	TArrayView<const FDSLine> BossIntro(int32 QuestN);
	TArrayView<const FDSLine> BossDefeat(int32 QuestN);
	TArrayView<const FDSLine> MazeText();
	TArrayView<const FDSLine> TunnelText();
	int32 ComicPageCount();
	FDSComicPage ComicPage(int32 I);
	TArrayView<const FDSCreditLine> Credits();
	FDSQuest MakeQuest(int32 N);

	constexpr int32 MaxQuest = 40;
	constexpr int32 PotionCost = 60, MaxPotions = 9, AmmoPack = 10, AmmoCost = 60, MaxAmmo = 99, MaxSkillLv = 5;

	// ---- the road (world.gd) -- all positions are metres in the game's 2D plane (Godot x, z) ----
	int32 RouteNum();
	FVector2D Route(int32 I);
	int32 RouteClear(int32 I);
	int32 SiteIndex(int32 QuestN);
	FVector2D Site(int32 QuestN);
	FVector2D DirAt(int32 I);
	FVector2D Checkpoint(int32 QuestN);
	FVector2D StartPos();
	FVector2D SwordSpot();
	TArray<FVector2D> Between(int32 I0, int32 I1, int32 Count);
	constexpr int32 StartIdx = 1;
}
