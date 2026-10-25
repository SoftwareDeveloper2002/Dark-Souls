// Audio, weather and lightning, boss trash-talk, hidden emblems, execution finishers, the world map and the comic epilogue.
// Port of sfx.gd / music.gd / fx.gd, boss_talk.gd, emblems.gd, execution.gd, map_view.gd and comic.gd.
#include "DSGame.h"
#include "DSVisual.h"
#include "DSSaveGame.h"
#include "Components/AudioComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/SkyLight.h"
#include "Engine/Texture2D.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "Sound/SoundBase.h"
#include "Sound/SoundWave.h"
#include "UObject/SoftObjectPath.h"

#include "DSBossLines.inc"

// ================================================================== audio

namespace
{
	USoundBase* LoadSound(const FString& Path)
	{
		return Cast<USoundBase>(FSoftObjectPath(Path).TryLoad());
	}
}

void ADSGame::Sfx(const FString& Name, float VolDb, float Pitch)
{
	USoundBase* S = nullptr;
	if (TObjectPtr<USoundBase>* F = SoundCache.Find(Name)) S = F->Get();
	else
	{
		S = LoadSound(FString::Printf(TEXT("/Game/Audio/Sfx/%s.%s"), *Name, *Name));
		SoundCache.Add(Name, S);
	}
	if (S) UGameplayStatics::PlaySound2D(this, S, FMath::Pow(10.f, VolDb / 20.f) * SfxVol, FMath::Clamp(Pitch, 0.2f, 3.f));
}

void ADSGame::Voice(const FString& Name)
{
	const FString Key = TEXT("vox/") + Name;
	USoundBase* S = nullptr;
	if (TObjectPtr<USoundBase>* F = SoundCache.Find(Key)) S = F->Get();
	else
	{
		S = LoadSound(FString::Printf(TEXT("/Game/Audio/Vox/%s.%s"), *Name, *Name));
		SoundCache.Add(Key, S);
	}
	if (S) UGameplayStatics::PlaySound2D(this, S, SfxVol);
}

void ADSGame::Music(const FString& Track)
{
	if (Track == CurMusic) return;
	struct FTrack { const TCHAR* Id; const TCHAR* Asset; float Db; };
	static const FTrack Tracks[] = {
		{ TEXT("title"), TEXT("treasure_hunter"), -9.f }, { TEXT("game"), TEXT("determined_pursuit_loop"), -11.f },
		{ TEXT("boss"), TEXT("boss_epic"), -8.f }, { TEXT("final"), TEXT("boss_final"), -8.f } };
	for (const FTrack& T : Tracks)
	{
		if (Track != T.Id) continue;
		CurMusic = Track;
		USoundBase* S = LoadSound(FString::Printf(TEXT("/Game/Audio/Music/%s.%s"), T.Asset, T.Asset));
		if (MusicComp) MusicComp->FadeOut(1.4f, 0.f);
		MusicComp = nullptr;
		if (!S) return;
		if (USoundWave* Wave = Cast<USoundWave>(S)) Wave->bLooping = true;
		MusicComp = UGameplayStatics::SpawnSound2D(this, S, FMath::Pow(10.f, T.Db / 20.f) * MusicVol, 1.f, 0.f, nullptr, false, false);
		if (MusicComp) MusicComp->FadeIn(1.4f, FMath::Pow(10.f, T.Db / 20.f) * MusicVol);
		return;
	}
}

// ================================================================== weather, lightning, lighting

void ADSGame::ApplyLighting()
{
	const float Depth = TunnelDepth(PPos);
	if (Moon)
	{
		const float Base = MoonBase * 3.f * (1.f - 0.88f * Depth) * (1.f - 0.95f * DarkK);
		Moon->GetLightComponent()->SetIntensity(Base + FlashAmount * 9.f * FxIntensity);
	}
	if (Sky) Sky->GetLightComponent()->SetIntensity(1.2f * (1.f - 0.9f * DarkK) * (1.f - 0.6f * Depth) + FlashAmount * 1.5f);
}

void ADSGame::WeatherUpdate(float Dt)
{
	const FDSChapter& C = DSData::Chapter(FMath::Max(ChapterShown, 0));
	DarkK = FMath::FInterpConstantTo(DarkK, FMath::Clamp(MazeMargin(PPos) / 3.f, 0.f, 1.f), Dt, 2.f);
	if (State == EDSState::Title) DarkK = 0.f;
	TunnelBannerCheck();
	// rain: a pool of thin streaks that follow the camera focus
	const int32 Want = State == EDSState::Title ? 40 : FMath::Min(C.Rain / 4, 130);
	while (RainDrops.Num() < Want)
	{
		FDSRain R;
		ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator(0, 0, 8));
		V->AddPart(EDSShape::Cube, FVector::ZeroVector, FVector(0.02, 0.02, 0.8), FLinearColor(0.55f, 0.65f, 0.85f));
		V->SetShadows(false);
		R.Node = V;
		R.Off = FVector(FMath::FRandRange(-2200.f, 2200.f), FMath::FRandRange(-1800.f, 1800.f), FMath::FRandRange(0.f, 1800.f));
		R.Speed = FMath::FRandRange(1600.f, 2200.f);
		RainDrops.Add(R);
	}
	const bool bIndoor = TunnelDepth(PPos) > 0.5f || DarkK > 0.5f;
	for (FDSRain& R : RainDrops)
	{
		if (!R.Node.IsValid()) continue;
		R.Off.Z -= R.Speed * Dt;
		if (R.Off.Z < 0.f)
		{
			R.Off.Z += 1800.f;
			R.Off.X = FMath::FRandRange(-2200.f, 2200.f);
			R.Off.Y = FMath::FRandRange(-1800.f, 1800.f);
		}
		R.Node->SetActorHiddenInGame(bIndoor);
		R.Node->SetActorLocation(CamFocus + R.Off);
	}
	// lightning
	ThunderTimer -= Dt;
	if (ThunderTimer <= 0.f && State != EDSState::Title && !bIndoor)
	{
		ThunderTimer = FMath::FRandRange(C.Thunder0, C.Thunder1) / FMath::Max(FxIntensity, 0.5f);
		FlashT = 0.f;
		FlashLen = FMath::FRandRange(0.35f, 0.6f);
		FlashPow = FMath::FRandRange(0.7f, 1.f);
		const FVector2D Far = FVector2D(CamFocus.X, CamFocus.Y) / 100.0 + FromAngle(FMath::FRand() * 2.f * PI) * FMath::FRandRange(25.f, 55.f);
		Strike(Far);
		Sfx(TEXT("thunder"), -4.f, FMath::FRandRange(0.8f, 1.1f));
	}
	FlashT += Dt;
	const float U = FlashT / FlashLen;
	FlashAmount = U < 1.f ? (1.f - U) * (0.55f + 0.45f * FMath::Abs(FMath::Sin(FlashT * 46.f))) * FlashPow : 0.f;
	FxIntensity = FMath::FInterpTo(FxIntensity, 1.f, Dt, 0.15f);
	ApplyLighting();
}

void ADSGame::TunnelBannerCheck()
{
	if (State != EDSState::Play) return;
	if (!bTunnelSeen && TunnelDepth(PPos) > 0.6f)
	{
		bTunnelSeen = true;
		ShowBanner(TEXT("THE SUNKEN TUNNEL"), 2.6f, TEXT("Something shuffles in the dark..."));
	}
}

// ================================================================== boss trash-talk

void ADSGame::Speak(FDSEnemy& E, const FString& Text, FLinearColor Col)
{
	FDSSpeech S;
	for (const FDSEnemyPtr& P : Enemies) if (P.Get() == &E) S.Who = P;
	S.Text = Text;
	S.Col = Col;
	S.Life = FMath::Clamp(Text.Len() * 0.055f + 2.f, 2.6f, 5.5f);
	// replace the same boss's older bubble
	Speeches.RemoveAll([&](const FDSSpeech& O) { return O.Who.Pin().Get() == &E; });
	Speeches.Add(S);
	const TCHAR* Pre = E.Type == EDSEnemy::Serpent ? TEXT("h") : (E.Type == EDSEnemy::Cyborg ? TEXT("m") : TEXT("v"));
	Sfx(FString::Printf(TEXT("%s%d"), Pre, FMath::RandRange(0, 3)), -4.f, E.Type == EDSEnemy::Serpent ? 0.95f : (E.Type == EDSEnemy::Malakar ? 0.42f : 0.55f));
}

void ADSGame::BossSay(FDSEnemy& E, int32 Kind, bool bForce)
{
	const int32 Bi = (int32)E.Type - (int32)EDSEnemy::Demon;
	if (Bi < 0 || Bi > 3 || (!bForce && E.TkCd > 0.f)) return;
	const FDSLineSet& Set = GBossLines[Bi][Kind];
	int32 Pick = FMath::RandRange(0, Set.Num - 1);
	if (Set.Num > 1 && E.TkLast[Kind] == Set.Lines[Pick]) Pick = (Pick + 1) % Set.Num;
	E.TkLast[Kind] = Set.Lines[Pick];
	E.TkCd = Kind != 10 ? 5.f : 99.f;
	static const FLinearColor Cols[4] = { FLinearColor(1.f, 0.6f, 0.35f), FLinearColor(0.48f, 1.f, 0.6f), FLinearColor(0.35f, 0.9f, 1.f), FLinearColor(1.f, 0.29f, 0.35f) };
	Speak(E, Set.Lines[Pick], Cols[Bi]);
}

void ADSGame::BossTalkUpdate(FDSEnemy& E, float Dt)
{
	if (E.bDead || State != EDSState::Play) return;
	if (E.TkLastHp < 0.f) { E.TkLastHp = PHp; E.TkFlasks = Flasks; }
	E.TkCd = FMath::Max(0.f, E.TkCd - Dt);
	E.TkDodgeCd = FMath::Max(0.f, E.TkDodgeCd - Dt);
	E.TkBlockCd = FMath::Max(0.f, E.TkBlockCd - Dt);
	E.TkIdle -= Dt;
	if (!E.TkEngaged) { E.TkEngaged = true; BossSay(E, 0, true); return; }
	if (PHp < E.TkLastHp - 0.5f && FMath::FRand() < 0.5f) BossSay(E, 1);
	E.TkLastHp = PHp;
	if (!E.TkLow && PHp < PMaxHp * 0.3f && PHp > 0.f) { E.TkLow = true; BossSay(E, 2, true); }
	else if (E.TkLow && PHp > PMaxHp * 0.55f) E.TkLow = false;
	if (Flasks < E.TkFlasks) BossSay(E, 3);
	E.TkFlasks = Flasks;
	const float Frac = E.Hp / FMath::Max(E.MaxHp, 1.f);
	static const float Marks[3] = { 0.75f, 0.5f, 0.25f };
	for (int32 i = 0; i < 3; i++)
		if (!E.TkMarks[i] && Frac < Marks[i]) { E.TkMarks[i] = true; BossSay(E, 4, true); }
	if (PAct == EDSAct::Roll && E.TkDodgeCd <= 0.f) { E.TkDodgeCd = 9.f; if (FMath::FRand() < 0.35f) BossSay(E, 5); }
	if (PShieldHit > 0.25f && E.TkBlockCd <= 0.f) { E.TkBlockCd = 10.f; if (FMath::FRand() < 0.5f) BossSay(E, 6); }
	if (E.TkIdle <= 0.f) { E.TkIdle = FMath::FRandRange(13.f, 21.f); BossSay(E, 8); }
}

// ================================================================== emblems

void ADSGame::EmblemsInit()
{
	Emblems.Reset();
	static const int32 CampQuests[3] = { 5, 12, 20 };
	for (int32 CampQ : CampQuests)
		for (int32 Src = 0; Src < 3; Src++)   // 0 tent, 1 rock, 2 tree
		{
			FDSEmblem E;
			E.Quest = CampQ;
			E.Src = Src;
			Emblems.Add(E);
		}
	for (int32 i = 0; i < 3; i++)
	{
		FDSEmblem E;
		E.Quest = 27;
		E.Src = 3;                            // wall
		Emblems.Add(E);
	}
}

void ADSGame::EmblemsCampBuilt(int32 Quest, const FVector2D& C)
{
	auto Nearest = [&](const TArray<FVector2D>& L, FVector2D& Out)
	{
		if (L.IsEmpty()) return false;
		Out = L[0];
		for (const FVector2D& P : L) if (FVector2D::Distance(P, C) < FVector2D::Distance(Out, C)) Out = P;
		return true;
	};
	for (FDSEmblem& E : Emblems)
	{
		if (E.Quest != Quest || E.Src == 3) continue;
		FVector2D Obj(1e9, 1e9);
		float Off = 2.f;
		if (E.Src == 0) { Nearest(CampTents, Obj); Off = 2.4f; }
		else if (E.Src == 1) { Nearest(CampRocks, Obj); Off = 1.9f; }
		else { Obj = NearestTree(C, 45.f); Off = 1.3f; }
		if (Obj.X > 1e8) Obj = C + FromAngle(E.Src * 2.1f) * 9.f;
		const FVector2D Dir = FVector2D::Distance(Obj, C) > 0.1 ? (C - Obj).GetSafeNormal() : FVector2D(1, 0);
		FVector2D Pos = Obj + Dir * Off;
		for (float Extra : { 0.f, 1.f, 2.f, -1.f }) { const FVector2D P = Obj + Dir * (Off + Extra); if (WalkOk(P)) { Pos = P; break; } }
		E.Pos = Pos;
		E.bLive = true;
	}
}

void ADSGame::EmblemsCampFreed()
{
	for (FDSEmblem& E : Emblems)
		if (E.Src != 3 && E.bLive)
		{
			E.bLive = false;
			if (E.Node.IsValid()) E.Node->Destroy();
			E.Node.Reset();
		}
}

void ADSGame::EmblemsMazeBuilt()
{
	TArray<FVector2D> Dead = Maze.Dead;
	Dead.RemoveAll([&](const FVector2D& D)
	{
		if (FVector2D::Distance(D, Maze.Entrance) <= 18.f) return true;
		for (const FVector2D& C : Maze.CivSpots) if (FVector2D::Distance(D, C) < 7.f) return true;
		return false;
	});
	Dead.Sort([&](const FVector2D& A, const FVector2D& B) { return FVector2D::Distance(A, Maze.Entrance) < FVector2D::Distance(B, Maze.Entrance); });
	TArray<FVector2D> Picks;
	for (float F : { 0.35f, 0.65f, 0.95f })
		if (!Dead.IsEmpty()) Picks.Add(Dead[FMath::Clamp((int32)((Dead.Num() - 1) * F), 0, Dead.Num() - 1)]);
	int32 Slot = 0;
	for (FDSEmblem& E : Emblems)
	{
		if (E.Src != 3) continue;
		if (Slot >= Picks.Num()) break;
		const FVector2D Cell = Picks[Slot++];
		FVector2D Best = Cell;
		for (const FVector2D& Dir : { FVector2D(1, 0), FVector2D(-1, 0), FVector2D(0, 1), FVector2D(0, -1) })
			if (WallOnly(Cell + Dir * Maze.Cell * 0.5f, 0.2f)) { Best = Cell + Dir * 1.5f; break; }
		E.Pos = Best;
		E.bLive = true;
	}
}

void ADSGame::EmblemsUpdate(float Dt)
{
	for (int32 i = 0; i < Emblems.Num(); i++)
	{
		FDSEmblem& E = Emblems[i];
		if (EmblemsFound.Contains(i) || !E.bLive) continue;
		const float D = FVector2D::Distance(PPos, E.Pos);
		if (D < 95.f && !E.Node.IsValid())
		{
			ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(E.Pos, 0.75f), FRotator::ZeroRotator);
			V->AddPart(EDSShape::Cylinder, FVector::ZeroVector, FVector(0.5, 0.5, 0.06), FLinearColor(0.91f, 0.76f, 0.35f) * 2.5f);
			V->AddPart(EDSShape::Sphere, FVector(0, -0.05, 0), FVector(0.1), FLinearColor(0.35f, 0.82f, 1.f) * 5.f);
			if (UStaticMeshComponent* Disc = V->GetPart(0)) Disc->SetRelativeRotation(FRotator(90, 0, 0));
			V->SetShadows(false);
			E.Node = V;
		}
		else if (D > 120.f && E.Node.IsValid())
		{
			E.Node->Destroy();
			E.Node.Reset();
		}
		if (E.Node.IsValid())
			E.Node->SetActorLocationAndRotation(P3(E.Pos, 0.75f + FMath::Sin(Time * 1.6f + i) * 0.08f), FRotator(0, FMath::RadiansToDegrees(Time * 1.4f + i), 0));
		if (D < 1.9f && State == EDSState::Play)
		{
			EmblemsFound.Add(i);
			if (E.Node.IsValid()) E.Node->Destroy();
			E.Node.Reset();
			Burst(E.Pos, 20, FLinearColor(0.95f, 0.82f, 0.48f), 7.f, 1.f);
			Sfx(TEXT("chime"), -1.f, 1.15f);
			Float(P3(E.Pos, 1.8f), FString::Printf(TEXT("ASHEN EMBLEM  %d / 12"), EmblemsFound.Num()), FLinearColor(0.95f, 0.82f, 0.48f));
			if (EmblemsFound.Num() == 1) ShowBanner(TEXT("A HIDDEN ASHEN EMBLEM"), 4.f, TEXT("Eleven more lie at camp tents, rocks and trees, and in the labyrinth walls..."));
			else if (EmblemsComplete())
			{
				bUnlimitedAmmo = true;
				ShowBanner(TEXT("THE ASHEN ARSENAL"), 5.f, TEXT("All 12 emblems found - UNLIMITED AMMO for every gun"));
				Strike(PPos);
				Sfx(TEXT("chime"), 0.f, 0.8f);
			}
			else ShowBanner(FString::Printf(TEXT("ASHEN EMBLEM  %d / 12"), EmblemsFound.Num()), 2.4f);
			Save();
		}
	}
}

// ================================================================== execution (finisher)

bool ADSGame::ExecCan(const FDSEnemy& E) const
{
	if (E.bDead || E.Type == EDSEnemy::Fist || E.Link.IsValid() || E.Exec >= 0.f || E.Mode == EDSMode::Idle) return false;
	if (FVector2D::Distance(PPos, E.Pos) > E.R + (E.Type == EDSEnemy::Cyborg ? 16.f : 2.5f)) return false;
	if (E.bBoss) return E.Stun > 0.f && E.Hp < E.MaxHp * 0.1f;
	return E.Daze > 0.f;
}

FDSEnemyPtr ADSGame::ExecFind() const
{
	FDSEnemyPtr Best;
	float Bd = 1e9f;
	for (const FDSEnemyPtr& E : Enemies)
		if (ExecCan(*E))
		{
			const float D = FVector2D::Distance(PPos, E->Pos);
			if (D < Bd) { Bd = D; Best = E; }
		}
	return Best;
}

void ADSGame::ExecStart(FDSEnemyPtr E)
{
	bExecActive = true;
	ExecTarget = E;
	ExecStage = 0;
	ExecFrom = PPos;
	ExecDir = (E->Pos - PPos).GetSafeNormal();
	PFace = AngleOf(ExecDir);
	ExecSlowLeft = 0.f;
	ExecHitStop = 0.f;
	ExecOrbit = FMath::FRand() < 0.5f ? 1.f : -1.f;
	if (E->bBoss)
	{
		ExecKind = E->Type == EDSEnemy::Cyborg ? TEXT("titan") : TEXT("boss");
		ExecDur = E->Type == EDSEnemy::Cyborg ? 5.6f : 5.0f;
		ExecPre = 0.f;
	}
	else
	{
		static const TArray<FString> Pools[4] = {
			{ TEXT("decap"), TEXT("stab"), TEXT("impale") }, { TEXT("slam"), TEXT("uppercut"), TEXT("rip") },
			{ TEXT("impale"), TEXT("snap"), TEXT("stab") }, { TEXT("shoot"), TEXT("blast") } };
		const TArray<FString>& Pool = Pools[(int32)Equipped];
		ExecKind = Pool[FMath::RandRange(0, Pool.Num() - 1)];
		ExecDur = 2.6f;
		ExecPre = 1.0f;
	}
	ExecT = -ExecPre;
	E->Exec = ExecT;
	E->St = EDSEState::Stagger;
	PAct = EDSAct::Idle;
	PStun = 0.f;
	BufAtk = BufRoll = BufSk1 = BufSk2 = 0.f;
	if (!E->bBoss) ShowBanner(TEXT("FINISH HIM!"), 1.2f);
	Sfx(TEXT("swing"), -4.f, 0.6f);
}

void ADSGame::ExecAbort()
{
	if (ExecTarget.IsValid() && !ExecTarget->bDead) ExecTarget->Exec = -1.f;
	bExecActive = false;
	ExecTarget.Reset();
	CamPitchK = 1.f;
	UGameplayStatics::SetGlobalTimeDilation(this, 1.f);
	if (PAct == EDSAct::Attack) PAct = EDSAct::Idle;
	PInv = FMath::Max(PInv, 0.6f);
}

void ADSGame::ExecUpdate(float DtScaled)
{
	if (!ExecTarget.IsValid() || ExecTarget->bDead || State != EDSState::Play) { ExecAbort(); return; }
	FDSEnemy& E = *ExecTarget;
	const float Dil = FMath::Max(UGameplayStatics::GetGlobalTimeDilation(this), 0.05f);
	float Dt = DtScaled / Dil;
	if (ExecHitStop > 0.f) { ExecHitStop -= Dt; Dt = 0.f; }
	if (ExecSlowLeft > 0.f)
	{
		ExecSlowLeft -= Dt;
		if (ExecSlowLeft <= 0.f) UGameplayStatics::SetGlobalTimeDilation(this, 1.f);
	}
	ExecT += Dt;
	E.Exec = ExecT;
	PInv = 5.f;
	E.Mv = 0.f;
	E.Daze = FMath::Max(E.Daze, 0.2f);
	const float Stand = E.R + (ExecKind == TEXT("titan") ? 6.f : 0.85f);
	const FVector2D StandPos = E.Pos - ExecDir * Stand;
	PPos = FMath::Lerp(PPos, StandPos, FMath::Clamp((ExecT + ExecPre) / 0.35f, 0.f, 1.f) * 0.35f);
	PFace = AngleOf(ExecDir);
	E.Face = AngleOf(PPos - E.Pos);
	// camera orbits the pair
	CamYaw += ExecOrbit * 0.5f * Dt;
	CamPitchK = 0.7f;
	// the blade animation loops while the blows land
	PAct = EDSAct::Attack;
	PAtk.Anim = (ExecKind == TEXT("stab") || ExecKind == TEXT("impale") || ExecKind == TEXT("shoot")) ? TEXT("thrust") : TEXT("overhead");
	PAtk.Time = 0.45f;
	PActT = FMath::Fmod(FMath::Max(ExecT, 0.f), 0.45f);

	auto At = [&](int32 Idx, float When) { if (ExecStage < Idx && ExecT >= When) { ExecStage = Idx; return true; } return false; };
	const bool bBoss = E.bBoss;
	const float Mid = ExecDur;
	if (!bBoss)
	{
		if (At(1, -ExecPre + 0.1f)) { Burst(PPos, 5, FLinearColor(0.78f, 0.72f, 0.6f), 4.f, 0.2f); Sfx(TEXT("swing"), -2.f, 0.6f); }
		if (At(2, -ExecPre + 0.45f))
		{
			Sfx(TEXT("hit"), 1.f, 0.65f);
			Shake = FMath::Max(Shake, 9.f);
			Burst(E.Pos, 8, FLinearColor(1.f, 0.91f, 0.69f), 5.f, 1.5f);
			Ring(E.Pos, FLinearColor(1.f, 0.91f, 0.69f), 3.f, 0.35f);
			ExecHitStop = 0.09f;
		}
		if (At(3, -ExecPre + 0.85f)) { Blood(E.Pos, AngleOf(ExecDir), 14); Sfx(TEXT("hit"), 2.f, 0.55f); Shake = FMath::Max(Shake, 12.f); ExecHitStop = 0.08f; }
	}
	for (int32 n = 0; n < 3; n++)
		if (At(4 + n, (bBoss ? 0.6f : 0.15f) + n * (bBoss ? 0.9f : 0.28f)))
		{
			Blood(E.Pos, AngleOf(ExecDir), 8 + n * 6);
			Sfx(TEXT("hit"), -2.f + n * 1.5f, 1.05f - 0.15f * n);
			Shake = FMath::Max(Shake, 6.f + 4.f * n);
		}
	if (At(8, Mid * 0.72f))
	{
		static const TMap<FString, FString> Names = {
			{ TEXT("decap"), TEXT("DECAPITATION") }, { TEXT("stab"), TEXT("HEART STAB") }, { TEXT("impale"), TEXT("IMPALED") }, { TEXT("slam"), TEXT("SKULL CRUSH") },
			{ TEXT("uppercut"), TEXT("UPPERCUT") }, { TEXT("rip"), TEXT("SPINE RIP") }, { TEXT("snap"), TEXT("NECK SNAP") }, { TEXT("shoot"), TEXT("POINT BLANK") },
			{ TEXT("blast"), TEXT("SHELL BLAST") }, { TEXT("boss"), TEXT("EXECUTION") }, { TEXT("titan"), TEXT("CORE BREAKER") } };
		if (const FString* N = Names.Find(ExecKind)) ShowBanner(*N, 1.6f);
		Blood(E.Pos, AngleOf(ExecDir), 24);
		Burst(E.Pos, 20, FLinearColor(1.f, 0.9f, 0.7f), 9.f, 1.6f);
		Shake = FMath::Max(Shake, 16.f);
		Sfx(TEXT("boom"), -4.f, 1.2f);
		if (ExecKind == TEXT("decap"))
		{
			FDSParticle P;
			P.Node = MakeBall(0.28f, FLinearColor(0.75f, 0.6f, 0.5f));
			P.Node->SetActorLocation(P3(E.Pos, 1.7f));
			P.Vel = FVector(ExecDir.X, ExecDir.Y, 0.f) * 600.0 + FVector(0, 0, 700);
			P.Max = P.Life = 1.4f;
			Particles.Add(P);
		}
		ExecSlowLeft = 0.7f;
		UGameplayStatics::SetGlobalTimeDilation(this, 0.3f);
	}
	if (ExecT >= ExecDur)
	{
		if (bBoss) E.Hp = 0.f;
		E.Exec = -1.f;
		FDSEnemyPtr T = ExecTarget;
		ExecAbort();
		KillEnemy(T, true);
	}
}

// ================================================================== map

void ADSGame::MapBuildStep()
{
	if (bMapReady) return;
	if (MapW == 0)
	{
		FVector2D Mn(1e9, 1e9), Mx(-1e9, -1e9);
		for (int32 i = 0; i < DSData::RouteNum(); i++)
		{
			const FVector2D P = DSData::Route(i);
			Mn.X = FMath::Min(Mn.X, P.X); Mn.Y = FMath::Min(Mn.Y, P.Y);
			Mx.X = FMath::Max(Mx.X, P.X); Mx.Y = FMath::Max(Mx.Y, P.Y);
		}
		Mn -= FVector2D(180, 180);
		Mx += FVector2D(180, 180);
		MapOrigin = Mn;
		MapSizeM = Mx - Mn;
		MapW = (int32)(MapSizeM.X / MapStep);
		MapH = (int32)(MapSizeM.Y / MapStep);
		MapHeights.SetNumZeroed((MapW + 2) * (MapH + 2));
		MapRow = 0;
		MapCentre = DSData::StartPos();
	}
	for (int32 n = 0; n < 6 && MapRow < MapH + 2; n++, MapRow++)
		for (int32 X = 0; X < MapW + 2; X++)
			MapHeights[MapRow * (MapW + 2) + X] = Ground(MapOrigin + FVector2D(X, MapRow) * MapStep);
	if (MapRow < MapH + 2) return;
	MapPixels.SetNum(MapW * MapH);
	float Lo = 1e9f, Hi = -1e9f;
	for (float V : MapHeights) { Lo = FMath::Min(Lo, V); Hi = FMath::Max(Hi, V); }
	for (int32 Z = 0; Z < MapH; Z++)
		for (int32 X = 0; X < MapW; X++)
		{
			const int32 I = (Z + 1) * (MapW + 2) + (X + 1);
			const float H = MapHeights[I];
			const float Dx = MapHeights[I + 1] - MapHeights[I - 1], Dz = MapHeights[I + MapW + 2] - MapHeights[I - MapW - 2];
			const float Shade = FMath::Clamp(0.62f - (Dx + Dz) * 0.018f, 0.2f, 1.1f);
			const float K = FMath::Clamp((H - Lo) / FMath::Max(Hi - Lo, 1.f), 0.f, 1.f);
			const FLinearColor Low(0.08f, 0.16f, 0.1f), High(0.62f, 0.6f, 0.56f);
			const FLinearColor C = FMath::Lerp(Low, High, K * K) * Shade;
			MapPixels[Z * MapW + X] = C.ToFColor(true);
		}
	MapTex = UTexture2D::CreateTransient(MapW, MapH, PF_B8G8R8A8);
	if (MapTex)
	{
		FTexture2DMipMap& Mip = MapTex->GetPlatformData()->Mips[0];
		void* Data = Mip.BulkData.Lock(LOCK_READ_WRITE);
		FMemory::Memcpy(Data, MapPixels.GetData(), MapPixels.Num() * sizeof(FColor));
		Mip.BulkData.Unlock();
		MapTex->Filter = TF_Bilinear;
		MapTex->UpdateResource();
	}
	MapHeights.Empty();
	bMapReady = MapTex != nullptr;
}

// ================================================================== comic epilogue + credits

void ADSGame::ComicStart()
{
	State = EDSState::Comic;
	ComicPage = 0;
	ComicShown = 0;
	ComicT = 0.f;
	bCredits = false;
	CreditsT = 0.f;
	Music(TEXT("title"));
	if (PlayerFig) PlayerFig->SetActorHiddenInGame(true);
}

void ADSGame::ComicTap()
{
	if (ComicT < 0.3f) return;
	ComicT = 0.f;
	if (bCredits)
	{
		if (CreditsT > 2.f)
		{
			UGameplayStatics::DeleteGameInSlot(UDSSaveGame::SlotName, 0);
			ClearField();
			bCredits = false;
			State = EDSState::Title;
			bHasSaveCached = false;
		}
		return;
	}
	const FDSComicPage Page = DSData::ComicPage(ComicPage);
	if (ComicShown < Page.Panels.Num()) { ComicShown++; return; }
	ComicPage++;
	ComicShown = 0;
	if (ComicPage >= DSData::ComicPageCount()) { bCredits = true; CreditsT = 0.f; }
}
