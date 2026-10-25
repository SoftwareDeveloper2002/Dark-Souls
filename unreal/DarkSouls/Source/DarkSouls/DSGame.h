// The game director. This is a direct port of scripts/game.gd (+ bosses.gd, quests.gd, shop.gd, save.gd):
// the simulation is kept in the same 2D plane with the same units (metres, seconds) and the same numbers,
// and ADSVisual actors (primitive meshes) mirror it in 3D. One ADSGame lives in the level; ADSGameMode spawns it.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DSData.h"
#include "DSGame.generated.h"

class ADSVisual;
class ACameraActor;
class ADirectionalLight;
class AExponentialHeightFog;
class ASkyLight;
class UDSSaveGame;

enum class EDSState : uint8 { Title, Play, Dead, Win };
enum class EDSEState : uint8 { Chase, Wind, Strike, Recover, Stagger };
enum class EDSMode : uint8 { Idle, Alert, Return };
enum class EDSBossAtk : uint8 { None, Slam, Sweep, Charge, Volley, Bolts, Summon, Roll, Gaze, Stone, Bite, Spit, Tail, Fist, Laser, Missiles };
enum class EDSForm : uint8 { Own, Demon, Serpent, Cyborg };

struct FDSEnemy
{
	EDSEnemy Type = EDSEnemy::Hollow;
	EDSAI AI = EDSAI::Melee;
	FVector2D Pos = FVector2D::ZeroVector;
	float R = 0.7f, Hp = 1.f, MaxHp = 1.f, Speed = 1.f, Dmg = 1.f;
	EDSEState St = EDSEState::Chase;
	float T = 0.f, Face = 0.f;
	bool bHitDone = false;
	FVector2D Kb = FVector2D::ZeroVector;
	float Flash = 0.f;
	bool bDead = false;
	EDSBossAtk Atk = EDSBossAtk::None;
	int32 Phase = 1;
	float Cd = 0.f, Mv = 0.f;
	FVector2D Last = FVector2D::ZeroVector, Dash = FVector2D::ZeroVector;
	float Side = 1.f;
	bool bBoss = false, bElite = false;
	int32 Uid = 0;
	float Daze = 0.f, Vcd = 0.f, TauntT = 0.f;
	int32 Souls = 0;
	EDSMode Mode = EDSMode::Alert;
	FVector2D Home = FVector2D::ZeroVector;
	float Aggro = 15.f;
	bool bForce = false, bQuest = true, bWayside = false, bStatic = false;
	float Life = 0.f;
	float Sink = 0.f;
	TWeakPtr<FDSEnemy> Link;                       // a Titan fist points at its Titan
	TWeakObjectPtr<ADSVisual> Fig;                 // body
	// boss state
	float CdGaze = 3.f, CdStone = 9.f;
	float Stun = 0.f, FormT = 0.f, Shield = 0.f, ShieldMax = 0.f, DomeFlash = 0.f, HitCd = 0.f, Exposed = 0.f;
	float BeamA0 = 0.f, BeamA1 = 0.f, BeamTick = 0.f;
	bool bRolling = false;
	EDSForm Form = EDSForm::Own;
	TArray<FVector2D> Trail;
	TWeakObjectPtr<ADSVisual> Tele, Tele2, Cone, Beam, Dome;
	// pose bookkeeping
	float Walk = 0.f;
	float DeadT = 0.f;
};
using FDSEnemyPtr = TSharedPtr<FDSEnemy>;

struct FDSProjectile
{
	FVector2D Pos, Vel;
	float Dmg = 0.f, Life = 3.f, Homing = 0.f, H = 1.3f;
	EDSProj Kind = EDSProj::Arrow;
	enum class ETeam : uint8 { Enemy, Player, None } Team = ETeam::Enemy;
	TWeakObjectPtr<ADSVisual> Node;
};

struct FDSZone
{
	FVector2D Pos;
	float R = 1.f, T = 0.f, Delay = 1.f, Dmg = 0.f;
	bool bPlayer = false, bBoom = false, bDone = false;
	TWeakPtr<FDSEnemy> Fist;                       // set when the zone is a Titan fist telegraph
	TWeakObjectPtr<ADSVisual> Node;
};

struct FDSFloater { FVector Pos; FString Text; FLinearColor Col; float Age = 0.f, Life = 1.1f; };
struct FDSParticle { TWeakObjectPtr<ADSVisual> Node; FVector Vel; float Life = 0.f, Max = 1.f; bool bGravity = true; };
struct FDSOrb { TWeakObjectPtr<ADSVisual> Node; FVector Pos, Vel; float T = 0.f; bool bAmmo = false; };
struct FDSCorpse { TWeakObjectPtr<ADSVisual> Fig; float T = 0.f; float BaseZ = 0.f; bool bBoss = false; float NextBoom = 0.f; };
struct FDSRing { TWeakObjectPtr<ADSVisual> Node; float T = 0.f, Life = 0.6f, Grow = 8.f; };
struct FDSWayside { FVector2D Pos; TArray<EDSEnemy> Kinds; TArray<TWeakPtr<FDSEnemy>> Members; bool bSpawned = false, bDone = false; };
struct FDSButton { FString Id; FBox2D Rect; bool bEnabled = true; };
struct FDSSkillState { bool bUnlocked = false; int32 Level = 0; };

UCLASS()
class DARKSOULS_API ADSGame : public AActor
{
	GENERATED_BODY()

public:
	ADSGame();
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void EndPlay(const EEndPlayReason::Type Reason) override;

	// ---------------------------------------------------------------- constants (game.gd)
	static constexpr float ArenaFlat = 30.f, ArenaBlend = 26.f, ArenaR = 34.f;
	static constexpr float CampRange = 85.f, ArriveRange = 26.f;

	// ---------------------------------------------------------------- state read by the HUD
	EDSState State = EDSState::Title;
	bool bPaused = false;
	float Time = 0.f, EndTimer = 0.f;

	FVector2D PPos = FVector2D::ZeroVector;
	float PR = 0.7f, PFace = -PI * 0.5f;
	float PHp = 100.f, PMaxHp = 100.f, HpTrail = 100.f, PSt = 100.f, PMaxSt = 100.f, PStDelay = 0.f;
	EDSAct PAct = EDSAct::Idle;
	float PActT = 0.f;
	bool bPHitDone = false, bPHit2 = false;
	float PBlock = 0.f, PBlockT = 0.f, PShieldHit = 0.f, PHitT = 0.f, PHitDir = 0.f;
	float PRollDir = 0.f, PInv = 0.f, PStun = 0.f, PStone = 0.f, PFlash = 0.f, PSinceHit = 0.f, PGunCd = 0.f, PRage = 0.f;
	int32 PSkl = 0, PHitI = 0, PCombo = -1;
	float PComboWin = 0.f, PMoveSpeed = 0.f;
	bool bHasWeapon = false;
	TArray<int32> PHitList;
	struct FAtk { FString Anim; float Dmg = 1, Range = 1, Arc = 1, Time = 0.42f, HitT = 0.14f, Lunge = 1, Kb = 1; bool bSlam = false; TArray<float> Hits; } PAtk;

	bool WeaponsOwned[4] = { true, false, false, false };
	int32 WTier[4] = { 0, 0, 0, 0 };
	EDSWeapon Equipped = EDSWeapon::Sword;
	int32 Ammo = 0;
	bool ArmorsOwned[4] = { true, false, false, false };
	EDSArmor Armor = EDSArmor::Ashen;
	int32 Lv[7] = { 0, 0, 0, 0, 0, 0, 0 };                 // order of DSData::Stats()
	int32 Souls = 0, LostSouls = 0, Flasks = 3, Keys = 0;
	FDSSkillState Skills[4][2];
	float Cds[4][2] = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } };
	bool bUnlimitedAmmo = false;

	int32 QuestN = 1;
	FDSQuest Q;
	FVector2D Site = FVector2D::ZeroVector;
	bool bQArrived = false, bCampSpawned = false, bQActive = false, bQDone = false, bArenaActive = false;
	int32 QKills = 0;
	float QTimer = 0.f, QCd = 0.f, QDoneT = 0.f, AwayWarn = 0.f;
	bool bQBossDead = false, bQEliteDead = false;
	FString QStage;

	TArray<FDSEnemyPtr> Enemies;
	TArray<FDSFloater> Floaters;

	FString BannerText, BannerSub;
	float BannerT = 0.f;
	float Shake = 0.f;

	// dialogue
	bool bDialogActive = false;
	TArray<FDSLine> DialogLines;
	int32 DialogIdx = 0;
	float DialogShown = 0.f;

	// shop
	bool bShopOpen = false;
	int32 ShopTab = 0;

	// ---------------------------------------------------------------- input (set by ADSPlayerController)
	FVector2D MoveInput = FVector2D::ZeroVector;           // x right, y down (screen space)
	bool bBlockHeld = false;
	void PressAttack() { BufAtk = 0.25f; }
	void PressRoll() { BufRoll = 0.25f; }
	void PressEstus() { BufEstus = 0.25f; }
	void PressSkill(int32 Slot) { (Slot == 0 ? BufSk1 : BufSk2) = 0.25f; }
	void CycleWeapon();
	void TogglePause();
	void TapScreen();                                       // dialogue / death screen
	void OnButton(const FString& Id);                       // shop, title, pause buttons
	bool IsFrozen() const;
	bool IsFrozenExceptShop() const;

	// ---------------------------------------------------------------- UI helpers (HUD <-> controller)
	TArray<FDSButton> Buttons;
	void AddButton(const FString& Id, const FBox2D& Rect, bool bEnabled = true) { Buttons.Add({ Id, Rect, bEnabled }); }
	const FDSButton* HitTest(const FVector2D& ScreenPos) const;
	FString ControlLabel() const;                           // text on the attack button
	float SkillCdFrac(int32 Slot) const;
	bool SkillReady(int32 Slot) const;
	bool WorldToScreen(const FVector& WorldCm, FVector2D& Out) const;
	FString QuestLine() const;
	bool HasSave() const;
	bool CanCycle() const;

	// ---------------------------------------------------------------- derived stats
	void Recalc();
	float WeaponDmg() const;
	float MoveMult() const;
	float DefenseMult() const;
	int32 TotalLevel() const;
	float SkillCdMax(int32 Slot) const;
	static int32 StatCost(int32 Base, int32 Lvl) { return (int32)(Base * (1.f + 0.55f * Lvl)); }

	// ---------------------------------------------------------------- shop
	void ShopBuy(const FString& Id);

	// ---------------------------------------------------------------- world helpers (public for the boss code)
	float Ground(const FVector2D& P);                       // metres
	FVector P3(const FVector2D& P, float Dy = 0.f);         // world position in cm
	bool WalkOk(const FVector2D& P);
	FVector2D Slide(const FVector2D& Pos, const FVector2D& Delta);
	FVector2D Contain(const FVector2D& P) const;
	void MoveE(FDSEnemy& E, const FVector2D& Delta);

private:
	// ---- helpers
	static FVector2D FromAngle(float A) { return FVector2D(FMath::Cos(A), FMath::Sin(A)); }
	static float AngleOf(const FVector2D& V) { return FMath::Atan2(V.Y, V.X); }
	static float AngleDiff(float From, float To) { float D = FMath::Fmod(To - From + PI, 2.f * PI); if (D < 0.f) D += 2.f * PI; return D - PI; }

	// ---- lifecycle / world
	void BuildWorld();
	void StartNewGame();
	void ContinueGame();
	void EnterGame();
	void ApplyChapter(int32 Ch);
	void UpdateCamera(float Dt);
	void TickGame(float Dt);
	void SyncVisuals(float Dt);
	void SyncPlayer(float Dt);
	void SyncEnemy(FDSEnemy& E, float Dt);
	void BuildPlayerFigure();
	ADSVisual* BuildFigure(EDSEnemy Type);

	// ---- player
	void UpdatePlayer(float Dt);
	void TryAttack(const FVector2D& Iv, float Il);
	void MeleeHit();
	void UseSkill(int32 Slot);
	void SkillAim(float Rng);
	void QuakeHit();
	void DashHit();
	void FlurryHit();
	void SpinHit();
	void FireShell();
	void FireBullet(float Ang, float Mult = 1.f);
	void EquipWeapon(EDSWeapon W);
	void EquipArmor(EDSArmor A);
	void HurtPlayer(float Dmg, const FVector2D& Src, bool bUnblockable = false);
	void PetrifyPlayer(float Secs, float Dmg);
	void SetRage(bool bOn);
	bool IsTp() const { return false; }

	// ---- enemies
	FDSEnemyPtr SpawnEnemy(EDSEnemy Kind, const FVector2D* At, bool bQuest = true, bool bIdle = false);
	void UpdateEnemy(FDSEnemy& E, float Dt);
	void AiMelee(FDSEnemy& E, const FDSEnemyDef& Cfg, float Dt, float Dist, float Ang);
	void AiRanged(FDSEnemy& E, const FDSEnemyDef& Cfg, float Dt, float Dist, float Ang);
	void HurtEnemy(FDSEnemyPtr E, float Dmg, float Ang, bool bBlocked, float KbMul = 1.f);
	void KillEnemy(FDSEnemyPtr E, bool bReward);
	void RemoveEnemy(FDSEnemy& E);
	EDSEnemy PickKind() const;
	EDSEnemy PickKindFor(int32 Ch) const;
	FVector2D SpawnNear(const FVector2D& C, float RMin, float RMax);
	int32 QuestEnemyCount() const;
	int32 AddCap(int32 Base) const { return FMath::Min(Base, 9); }
	void Fire(const FVector2D& From, float Ang, float Dmg, float Spd, EDSProj Kind, float Homing = 0.f, float Height = 1.3f);
	void AddZone(const FVector2D& Pos, float R, float Delay, float Dmg, bool bPlayer, bool bBoom = false, TWeakPtr<FDSEnemy> Fist = nullptr);
	void UpdateZones(float Dt);
	void UpdateProjs(float Dt);
	void UpdateOrbs(float Dt);
	void UpdateCorpses(float Dt);
	void UpdateParticles(float Dt);
	void UpdateRings(float Dt);

	// ---- bosses (DSGameBoss.cpp)
	void BossAttach(FDSEnemy& E);
	void BossAi(FDSEnemy& E, float Dt, float Dist, float Ang);
	void BossPhaseCheck(FDSEnemy& E);
	void BossBeginWind(FDSEnemy& E, float Ang);
	void BossWindUpdate(FDSEnemy& E, float Ang);
	void BossStrikeStart(FDSEnemy& E, float Dist, float Ang);
	void BossStrikeUpdate(FDSEnemy& E, float Dt, float Dist, float Ang);
	void BossSwitchForm(FDSEnemy& E, EDSForm Form);
	void BossSpawnAdds(FDSEnemy& E, int32 N);
	void BossRaiseShield(FDSEnemy& E, float Hp);
	void BossDropShield(FDSEnemy& E);
	void BossPlaceBeam(FDSEnemy& E, float A, float Thick);
	void BossFreeNodes(FDSEnemy& E);
	void SpawnFist(FDSEnemyPtr Boss, const FVector2D& Pos);
	float BossAbsorb(FDSEnemy& E, float Dmg);
	float WindTime(const FDSEnemy& E) const;
	void BossVisuals(FDSEnemy& E, float Dt);

	// ---- quests (DSGameQuest.cpp)
	void BeginQuest(int32 N, bool bIntro = true, bool bWithFire = false);
	void SpawnCamp();
	void Arrive();
	void QuestUpdate(float Dt);
	void CompleteQuest();
	void PostQuest(float Dt);
	void ClearField();
	void SetupWayside();
	void UpdateWayside();
	void CleanupQuestEnemies();
	void Respawn();
	void OpenShop();
	void CloseShop();
	void Save();
	void SaveNext();
	void Say(TArrayView<const FDSLine> Lines, TFunction<void()> Done);
	void UpdateDialog(float Dt);
	void ShowBanner(const FString& Text, float Secs, const FString& Sub = FString());
	void SetControls(bool bOn) { bControls = bOn; }
	void SpawnChest();
	void BuildBonfire(const FVector2D& At);
	void FreeCamp();
	void BuildCamp(const FVector2D& C, int32 Ch, bool bBoss);

	// ---- effects
	void Float(const FVector& WorldCm, const FString& Text, const FLinearColor& Col);
	void Burst(const FVector2D& Pos, int32 N, const FLinearColor& Col, float Spd = 6.f, float Y = 1.f);
	void Ring(const FVector2D& Pos, const FLinearColor& Col, float Grow, float Life);
	void Strike(const FVector2D& Pos);                       // lightning bolt
	void Blood(const FVector2D& Pos, float Ang, int32 N);
	ADSVisual* MakeBall(float Radius, const FLinearColor& Col);

	// ---- data
	int32 Uid = 1;
	bool bControls = true;
	float BufAtk = 0, BufRoll = 0, BufEstus = 0, BufSk1 = 0, BufSk2 = 0;
	float Cam_Zoom = 1.f;
	FVector CamFocus = FVector::ZeroVector;
	float LastH = 0.f;
	TMap<int64, float> HeightCache;
	bool bGroundFound = false;

	int32 ChapterShown = -1;
	TArray<FDSWayside> Wayside;
	TArray<FDSProjectile> Projs;
	TArray<FDSZone> Zones;
	TArray<FDSParticle> Particles;
	TArray<FDSOrb> OrbsList;
	TArray<FDSCorpse> Corpses;
	TArray<FDSRing> Rings;
	TFunction<void()> DialogDone;
	TArray<TWeakObjectPtr<ADSVisual>> CampProps;
	TArray<TWeakObjectPtr<AActor>> CampLights;
	TWeakObjectPtr<ADSVisual> ChestActor, SwordPickup;
	FVector2D ChestPos = FVector2D::ZeroVector, SwordPos = FVector2D::ZeroVector;
	float ChestT = -1.f;
	bool bSwordOnGround = false;
	bool bChestPrompt = false;
	bool bHasSaveCached = false;

	UPROPERTY() TObjectPtr<ADSVisual> PlayerFig;
	UPROPERTY() TObjectPtr<ACameraActor> Camera;
	UPROPERTY() TObjectPtr<ADirectionalLight> Moon;
	UPROPERTY() TObjectPtr<AExponentialHeightFog> Fog;
	UPROPERTY() TObjectPtr<ASkyLight> Sky;
	UPROPERTY() TObjectPtr<AActor> FloorPlane;
	UPROPERTY() TArray<TObjectPtr<ADSVisual>> BallPool;

	friend class ADSHUD;
	friend class ADSPlayerController;
};
