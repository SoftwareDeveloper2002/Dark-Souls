#include "DSGame.h"
#include "DSVisual.h"
#include "DSSaveGame.h"
#include "Camera/CameraActor.h"
#include "Camera/CameraComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/DirectionalLight.h"
#include "Engine/ExponentialHeightFog.h"
#include "Engine/SkyLight.h"
#include "Engine/StaticMeshActor.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "Kismet/KismetSystemLibrary.h"
#include "Materials/MaterialInstanceDynamic.h"

namespace
{
	FLinearColor EnemyColor(EDSEnemy T)
	{
		switch (T)
		{
		case EDSEnemy::Hollow: return FLinearColor(0.45f, 0.40f, 0.33f);
		case EDSEnemy::Zombie: return FLinearColor(0.30f, 0.42f, 0.28f);
		case EDSEnemy::Ghoul: return FLinearColor(0.50f, 0.52f, 0.46f);
		case EDSEnemy::Skeleton: return FLinearColor(0.85f, 0.82f, 0.70f);
		case EDSEnemy::Archer: return FLinearColor(0.35f, 0.30f, 0.22f);
		case EDSEnemy::Mage: return FLinearColor(0.40f, 0.15f, 0.55f);
		case EDSEnemy::Imp: return FLinearColor(0.80f, 0.25f, 0.12f);
		case EDSEnemy::Fiend: return FLinearColor(0.50f, 0.10f, 0.10f);
		case EDSEnemy::Hound: return FLinearColor(0.20f, 0.15f, 0.14f);
		case EDSEnemy::Knight: return FLinearColor(0.35f, 0.38f, 0.45f);
		case EDSEnemy::StoneSoldier: return FLinearColor(0.50f, 0.50f, 0.48f);
		case EDSEnemy::Brute: return FLinearColor(0.45f, 0.25f, 0.18f);
		case EDSEnemy::Captain: return FLinearColor(0.55f, 0.12f, 0.12f);
		case EDSEnemy::Demon: return FLinearColor(0.55f, 0.18f, 0.08f);
		case EDSEnemy::Serpent: return FLinearColor(0.12f, 0.45f, 0.25f);
		case EDSEnemy::Cyborg: return FLinearColor(0.30f, 0.38f, 0.45f);
		case EDSEnemy::Malakar: return FLinearColor(0.20f, 0.04f, 0.08f);
		default: return FLinearColor(0.5f, 0.55f, 0.6f);
		}
	}
}

ADSGame::ADSGame()
{
	PrimaryActorTick.bCanEverTick = true;
	PrimaryActorTick.bTickEvenWhenPaused = false;
	SetRootComponent(CreateDefaultSubobject<USceneComponent>(TEXT("Root")));
}

void ADSGame::BeginPlay()
{
	Super::BeginPlay();
	BuildWorld();
	bHasSaveCached = HasSave();
	State = EDSState::Title;
}

void ADSGame::EndPlay(const EEndPlayReason::Type Reason)
{
	Super::EndPlay(Reason);
}

// ================================================================== world

float ADSGame::Ground(const FVector2D& P)
{
	if (OnBridge(P)) return Bridge.Base;
	const int64 Key = ((int64)FMath::RoundToInt(P.X * 2.0) << 32) ^ (int64)(uint32)FMath::RoundToInt(P.Y * 2.0);
	if (const float* Cached = HeightCache.Find(Key)) return *Cached;
	UWorld* W = GetWorld();
	if (!W) return LastH;
	FHitResult Hit;
	const FVector Start(P.X * 100.0, P.Y * 100.0, 3000000.0), End(P.X * 100.0, P.Y * 100.0, -3000000.0);
	FCollisionQueryParams Params(SCENE_QUERY_STAT(DSGround), false);
	if (W->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params))
	{
		LastH = Hit.ImpactPoint.Z / 100.f;
		bGroundFound = true;
		if (HeightCache.Num() > 400000) HeightCache.Reset();
		HeightCache.Add(Key, LastH);
		return LastH;
	}
	return LastH;
}

FVector ADSGame::P3(const FVector2D& P, float Dy)
{
	return FVector(P.X * 100.0, P.Y * 100.0, (Ground(P) + Dy) * 100.0);
}

bool ADSGame::WalkOk(const FVector2D& P)
{
	// The Godot terrain marks holes with a 0 height; here anything the ground trace can hit is walkable
	// (cliffs are refused by the slope test in Slide).
	if (!bGroundFound) return true;
	UWorld* W = GetWorld();
	if (!W) return true;
	FHitResult Hit;
	const FVector Start(P.X * 100.0, P.Y * 100.0, 3000000.0), End(P.X * 100.0, P.Y * 100.0, -3000000.0);
	FCollisionQueryParams Params(SCENE_QUERY_STAT(DSWalk), false);
	return W->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params);
}

FVector2D ADSGame::Slide(const FVector2D& Pos, const FVector2D& Delta)
{
	if (Delta.SizeSquared() < 1e-10) return Pos;
	const float H0 = Ground(Pos);
	const bool bStuck = WallHit(Pos, 0.5f);
	const FVector2D Tries[3] = { Delta, FVector2D(Delta.X, 0.0), FVector2D(0.0, Delta.Y) };
	for (const FVector2D& D : Tries)
	{
		const float Dl = D.Size();
		if (Dl < 1e-6f) continue;
		const FVector2D Look = Pos + D / Dl * FMath::Max(Dl, 0.6f);
		if (!WalkOk(Look)) continue;
		if (!bStuck && WallHit(Look, 0.5f)) continue;
		if (FMath::Abs(Ground(Look) - H0) / FVector2D::Distance(Pos, Look) > 0.85f) continue;
		return Pos + D;
	}
	return Pos;
}

FVector2D ADSGame::Contain(const FVector2D& P) const
{
	if (bBridgeActive) return BridgeClamp(P);
	if (bArenaActive)
	{
		const FVector2D V = P - Site;
		if (V.Size() > ArenaR) return Site + V.GetSafeNormal() * ArenaR;
	}
	return P;
}

void ADSGame::MoveE(FDSEnemy& E, const FVector2D& Delta)
{
	if (E.bStatic) return;
	E.Pos = Contain(Slide(E.Pos, Delta));
}

ADSVisual* ADSGame::MakeBall(float Radius, const FLinearColor& Col)
{
	ADSVisual* B = nullptr;
	while (BallPool.Num() > 0 && !B)
	{
		B = BallPool.Pop();
		if (!IsValid(B)) B = nullptr;
	}
	if (!B)
	{
		B = GetWorld()->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
		B->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(1.0), Col);
		B->SetShadows(false);
	}
	B->SetActorHiddenInGame(false);
	B->SetAllColor(Col);
	B->SetActorScale3D(FVector(Radius * 2.f));
	return B;
}

void ADSGame::BuildWorld()
{
	UWorld* W = GetWorld();
	FActorSpawnParameters Sp;
	Sp.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	Camera = W->SpawnActor<ACameraActor>(FVector(0, 0, 3000), FRotator(-55, 0, 0), Sp);
	Camera->GetCameraComponent()->SetFieldOfView(55.f);
	Camera->GetCameraComponent()->SetConstraintAspectRatio(false);

	Moon = W->SpawnActor<ADirectionalLight>(FVector::ZeroVector, FRotator(-50, 35, 0), Sp);
	if (Moon)
	{
		Moon->GetRootComponent()->SetMobility(EComponentMobility::Movable);
		Moon->GetLightComponent()->SetCastShadows(true);
		Moon->GetLightComponent()->SetIntensity(3.f);
	}
	Fog = W->SpawnActor<AExponentialHeightFog>(FVector(0, 0, 0), FRotator::ZeroRotator, Sp);
	if (Fog) Fog->GetComponent()->SetFogDensity(0.004f);
	Sky = W->SpawnActor<ASkyLight>(FVector(0, 0, 500), FRotator::ZeroRotator, Sp);
	if (Sky)
	{
		Sky->GetRootComponent()->SetMobility(EComponentMobility::Movable);
		Sky->GetLightComponent()->SetIntensity(1.2f);
	}

	// Is there a landscape in the level? If not, lay a plain floor so the game is playable straight away.
	const FVector2D Start = DSData::StartPos();
	FHitResult Hit;
	const FVector A(Start.X * 100.0, Start.Y * 100.0, 3000000.0), B(Start.X * 100.0, Start.Y * 100.0, -3000000.0);
	if (!W->LineTraceSingleByChannel(Hit, A, B, ECC_Visibility))
	{
		UStaticMesh* Plane = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Plane.Plane"));
		AStaticMeshActor* Floor = W->SpawnActor<AStaticMeshActor>(FVector(512 * 100.0, -800 * 100.0, 0), FRotator::ZeroRotator, Sp);
		Floor->GetStaticMeshComponent()->SetMobility(EComponentMobility::Movable);
		Floor->GetStaticMeshComponent()->SetStaticMesh(Plane);
		Floor->SetActorScale3D(FVector(6000.0, 6000.0, 1.0));   // 6 km square
		Floor->GetStaticMeshComponent()->SetCollisionProfileName(TEXT("BlockAll"));
		if (UMaterialInterface* Base = LoadObject<UMaterialInterface>(nullptr, TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial")))
		{
			UMaterialInstanceDynamic* M = UMaterialInstanceDynamic::Create(Base, this);
			M->SetVectorParameterValue(TEXT("Color"), FLinearColor(0.08f, 0.08f, 0.07f));
			Floor->GetStaticMeshComponent()->SetMaterial(0, M);
		}
		FloorPlane = Floor;
		bGroundFound = true;
		LastH = 0.f;
	}
	else
	{
		bGroundFound = true;
	}
	BuildPlayerFigure();
	ApplyChapter(0);
	BuildTunnel();
	EmblemsInit();
	for (int32 q = 1; q <= 40; q++) Clearings.Add(DSData::Site(q));
	Clearings.Add(DSData::StartPos());
	Music(TEXT("title"));
}

void ADSGame::ApplyChapter(int32 Ch)
{
	if (ChapterShown == Ch) return;
	ChapterShown = Ch;
	const FDSChapter& C = DSData::Chapter(Ch);
	if (Moon)
	{
		Moon->GetLightComponent()->SetLightColor(C.Moon);
		MoonBase = C.MoonE;
	}
	if (Fog) Fog->GetComponent()->SetFogInscatteringColor(C.Fog * 6.f);
	if (Sky)
	{
		Sky->GetLightComponent()->SetLightColor(C.Ambient);
		Sky->GetLightComponent()->RecaptureSky();
	}
}

// ================================================================== camera

bool ADSGame::WorldToScreen(const FVector& WorldCm, FVector2D& Out) const
{
	APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0);
	return PC && PC->ProjectWorldLocationToScreen(WorldCm, Out, false);
}

void ADSGame::UpdateCamera(float Dt)
{
	FVector Target = P3(PPos);
	float ZoomT = 1.f;
	float PitchK = 1.f;
	float YawT = 0.f;
	if (State == EDSState::Title || State == EDSState::Comic)
	{
		const FVector2D S = DSData::StartPos();
		Target = P3(S + FVector2D(FMath::Cos(Time * 0.15f), FMath::Sin(Time * 0.15f)) * 6.0);
		ZoomT = 1.4f;
	}
	else if (bExecActive && ExecTarget.IsValid())
	{
		Target = P3((PPos + ExecTarget->Pos) * 0.5f, ExecTarget->bBoss ? 2.f : 1.1f);
		ZoomT = ExecTarget->bBoss ? 0.85f : 0.34f;
		PitchK = CamPitchK;
		YawT = CamYaw;
	}
	else
	{
		for (const FDSEnemyPtr& E : Enemies)
			if (E->Type == EDSEnemy::Cyborg && !E->bDead) { Target = FMath::Lerp(Target, P3(E->Pos), 0.4); ZoomT = bBridgeActive ? 1.55f : 1.5f; if (bBridgeActive) YawT = FMath::Atan2(-Bridge.D.X, -Bridge.D.Y); }
	}
	const bool bCine = bExecActive;
	Cam_Zoom = FMath::Lerp(Cam_Zoom, ZoomT, 1.f - FMath::Exp(-(bCine ? 7.f : 2.5f) * Dt));
	const bool bInMazeView = Maze.bBuilt && InMaze(PPos) && State == EDSState::Play && !bCine;
	MazeK = FMath::FInterpConstantTo(MazeK, bInMazeView ? 1.f : 0.f, Dt, 1.f / 0.8f);
	if (MazeK < 0.5f && !bCine)
		CamYaw = FMath::Lerp(CamYaw, YawT, 1.f - FMath::Exp(-3.f * Dt));
	CamFocus = FMath::Lerp(CamFocus, Target, 1.0 - FMath::Exp(-(bCine ? 12.0 : 9.0) * Dt));
	FVector Sh = FVector::ZeroVector;
	if (Shake > 0.f) Sh = FVector(FMath::FRandRange(-1.f, 1.f), FMath::FRandRange(-1.f, 1.f), FMath::FRandRange(-1.f, 1.f)) * Shake * 1.2f;
	// CAM_OFFSET rotated about the vertical axis (game plane x, y; up is z)
	const float Yaw = CamYaw;
	const FVector Off(12.4 * FMath::Sin(Yaw) * 100.0 * Cam_Zoom, 12.4 * FMath::Cos(Yaw) * 100.0 * Cam_Zoom, 17.2 * PitchK * 100.0 * Cam_Zoom);
	FVector Pos = CamFocus + Off + Sh;
	FVector Look = CamFocus + Sh;
	float Fov = 55.f;
	if (MazeK > 0.001f)
	{
		// over-the-shoulder third person: low behind the hero, the towering walls rising on both sides
		const float E = FMath::SmoothStep(0.f, 1.f, MazeK);
		const FVector2D Fwd(-FMath::Sin(Yaw), -FMath::Cos(Yaw));
		const FVector2D Right(-Fwd.Y, Fwd.X);
		const FVector Head = P3(PPos, 1.6f);
		const FVector Want = Head - FVector(Fwd.X, Fwd.Y, 0) * 420.0 + FVector(Right.X, Right.Y, 0) * 55.0 + FVector(0, 0, 55);
		FVector Dirn = Want - Head;
		const float Dist = Dirn.Size();
		Dirn /= Dist;
		float Reach = 0.f;
		while (Reach < Dist)
		{
			const FVector Q = Head + Dirn * Reach;
			if (WallOnly(FVector2D(Q.X, Q.Y) / 100.0, 0.55f)) break;
			Reach += 25.f;
		}
		const FVector TpPos = Head + Dirn * FMath::Max(Reach - 35.f, 90.f);
		const FVector TpLook = Head + FVector(Fwd.X, Fwd.Y, 0) * 500.0 + FVector(Right.X, Right.Y, 0) * 45.0 + FVector(0, 0, -30);
		Pos = FMath::Lerp(Pos, TpPos + Sh, E);
		Look = FMath::Lerp(Look, TpLook + Sh, E);
		Fov = FMath::Lerp(55.f, 78.f, E);
	}
	Camera->GetCameraComponent()->SetFieldOfView(Fov);
	Camera->SetActorLocationAndRotation(Pos, FRotationMatrix::MakeFromX(Look - Pos).Rotator());
}

// ================================================================== tick

bool ADSGame::IsFrozen() const
{
	return bPaused || bDialogActive || bShopOpen || bMapOpen || State == EDSState::Comic;
}

void ADSGame::Tick(float Dt)
{
	Super::Tick(Dt);
	Dt = FMath::Min(Dt, 0.05f);
	Buttons.Reset();                       // the HUD re-registers them while drawing this frame (see ADSHUD::DrawHUD)
	Time += Dt;
	MapBuildStep();
	WeatherUpdate(Dt);
	if (State == EDSState::Title)
	{
		UpdateCamera(Dt);
		UpdateParticles(Dt);
		return;
	}
	if (State == EDSState::Comic)
	{
		ComicT += Dt;
		if (bCredits) CreditsT += Dt;
		UpdateCamera(Dt);
		return;
	}
	for (FDSFloater& F : Floaters) F.Age += Dt;
	Floaters.RemoveAll([](const FDSFloater& F) { return F.Age >= F.Life; });
	if (!bPaused) BannerT -= Dt;
	for (FDSSpeech& S : Speeches) S.T += Dt;
	Speeches.RemoveAll([](const FDSSpeech& S) { return S.T > S.Life || !S.Who.IsValid(); });

	if (State == EDSState::Play)
	{
		if (!IsFrozen()) TickGame(Dt);
		if (bQDone && !(bPaused || bDialogActive)) PostQuest(Dt);
		if (!bPaused) EmblemsUpdate(Dt);
	}
	else
	{
		EndTimer += Dt;
	}
	UpdateDialog(Dt);
	if (!bPaused)
	{
		UpdateCorpses(Dt);
		UpdateParticles(Dt);
		UpdateRings(Dt);
		UpdateOrbs(Dt);
		UpdateChests(Dt);
		UpdateForest(PPos);
	}
	SyncVisuals(Dt);
	UpdateCamera(Dt);
	if (State == EDSState::Play && !bPaused && !bDialogActive) Shake = FMath::Max(0.f, Shake - 40.f * Dt);
}

void ADSGame::TickGame(float Dt)
{
	BufAtk = FMath::Max(0.f, BufAtk - Dt);
	BufRoll = FMath::Max(0.f, BufRoll - Dt);
	BufEstus = FMath::Max(0.f, BufEstus - Dt);
	BufSk1 = FMath::Max(0.f, BufSk1 - Dt);
	BufSk2 = FMath::Max(0.f, BufSk2 - Dt);
	TunnelBannerCheck();
	// the labyrinth: torch, civilians, failure and retry
	TorchUpdate(Dt);
	CivUpdate(Dt);
	if (MazeFailT >= 0.f)
	{
		MazeFailT += Dt;
		if (MazeFailT > 3.6f)
		{
			MazeFailT = -1.f;
			ClearField();
			bCampSpawned = false;
			SpawnCamp();
			PPos = Maze.Entrance;
			CamFocus = P3(PPos);
			PHp = PMaxHp;
			PSt = PMaxSt;
			ShowBanner(TEXT("TRY AGAIN"), 2.2f, TEXT("Keep every civilian alive"));
		}
	}
	UpdatePlayer(Dt);
}

// ================================================================== effects

void ADSGame::Float(const FVector& WorldCm, const FString& Text, const FLinearColor& Col)
{
	FDSFloater F;
	F.Pos = WorldCm;
	F.Text = Text;
	F.Col = Col;
	Floaters.Add(F);
	if (Floaters.Num() > 40) Floaters.RemoveAt(0);
}

void ADSGame::Burst(const FVector2D& Pos, int32 N, const FLinearColor& Col, float Spd, float Y)
{
	N = FMath::Min(N, 24);
	for (int32 i = 0; i < N; i++)
	{
		if (Particles.Num() > 220) break;
		FDSParticle P;
		P.Node = MakeBall(FMath::FRandRange(0.05f, 0.12f), Col * 3.f);
		const FVector Start = P3(Pos, Y);
		P.Node->SetActorLocation(Start);
		const float A = FMath::FRandRange(0.f, 2.f * PI);
		const float S = FMath::FRandRange(0.3f, 1.f) * Spd * 100.f;
		P.Vel = FVector(FMath::Cos(A) * S, FMath::Sin(A) * S, FMath::FRandRange(0.4f, 1.f) * Spd * 80.f);
		P.Max = P.Life = FMath::FRandRange(0.35f, 0.8f);
		Particles.Add(P);
	}
}

void ADSGame::Strike(const FVector2D& Pos)
{
	// a column of light where the lightning lands
	ADSVisual* Beam = GetWorld()->SpawnActor<ADSVisual>(P3(Pos, 10.f), FRotator::ZeroRotator);
	Beam->AddPart(EDSShape::Cylinder, FVector::ZeroVector, FVector(0.5, 0.5, 20.0), FLinearColor(6.f, 6.f, 8.f));
	Beam->SetShadows(false);
	Beam->SetLifeSpan(0.18f);
	Burst(Pos, 14, FLinearColor(0.7f, 0.8f, 1.f), 8.f, 0.5f);
}

void ADSGame::Ring(const FVector2D& Pos, const FLinearColor& Col, float Grow, float Life)
{
	FDSRing R;
	ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(Pos, 0.2f), FRotator::ZeroRotator);
	V->AddPart(EDSShape::Cylinder, FVector::ZeroVector, FVector(1.0, 1.0, 0.04), Col * 3.f);
	V->SetShadows(false);
	R.Node = V;
	R.Grow = Grow;
	R.Life = Life;
	Rings.Add(R);
}

void ADSGame::Blood(const FVector2D& Pos, float Ang, int32 N)
{
	Burst(Pos, N, FLinearColor(0.35f, 0.01f, 0.01f), 6.f, 1.2f);
}

void ADSGame::UpdateParticles(float Dt)
{
	for (FDSParticle& P : Particles)
	{
		P.Life -= Dt;
		if (!P.Node.IsValid()) { P.Life = -1.f; continue; }
		P.Vel.Z -= 1400.f * Dt;
		P.Node->AddActorWorldOffset(P.Vel * Dt);
		if (P.Life <= 0.f)
		{
			P.Node->SetActorHiddenInGame(true);
			BallPool.Add(P.Node.Get());
		}
	}
	Particles.RemoveAll([](const FDSParticle& P) { return P.Life <= 0.f; });
}

void ADSGame::UpdateRings(float Dt)
{
	for (FDSRing& R : Rings)
	{
		R.T += Dt;
		if (!R.Node.IsValid()) { R.T = 99.f; continue; }
		const float K = FMath::Clamp(R.T / R.Life, 0.f, 1.f);
		const float S = FMath::Lerp(0.5f, R.Grow * 2.f, K);
		R.Node->SetActorScale3D(FVector(S, S, 1.0));
		if (R.T >= R.Life) R.Node->Destroy();
	}
	Rings.RemoveAll([](const FDSRing& R) { return R.T >= R.Life; });
}

void ADSGame::UpdateOrbs(float Dt)
{
	const FVector Target = P3(PPos, 1.2f);
	for (FDSOrb& O : OrbsList)
	{
		if (!O.Node.IsValid()) { O.T = -99.f; continue; }
		O.T += Dt;
		if (O.T < 0.45f)
		{
			O.Vel.Z -= 1400.f * Dt;
			O.Pos += O.Vel * Dt;
		}
		else
		{
			O.Pos = FMath::Lerp(O.Pos, Target, 1.0 - FMath::Exp(-7.0 * Dt));
		}
		O.Node->SetActorLocation(O.Pos);
		if (O.T > 0.6f && FVector::Dist(O.Pos, Target) < 70.0)
		{
			if (O.bAmmo)
			{
				const int32 Gain = FMath::RandRange(4, 7);
				Ammo = FMath::Min(DSData::MaxAmmo, Ammo + Gain);
				Float(P3(PPos, 2.6f), FString::Printf(TEXT("+%d AMMO"), Gain), FLinearColor(0.54f, 0.85f, 1.f));
			}
			O.Node->SetActorHiddenInGame(true);
			BallPool.Add(O.Node.Get());
			O.T = -99.f;
		}
	}
	OrbsList.RemoveAll([](const FDSOrb& O) { return O.T < -50.f; });
}

void ADSGame::UpdateCorpses(float Dt)
{
	for (FDSCorpse& C : Corpses)
	{
		C.T += Dt;
		ADSVisual* F = C.Fig.Get();
		if (!F) { C.T = -99.f; continue; }
		const float Fall = FMath::Min(C.T * 2.6f, 1.5f);
		FRotator R = F->GetActorRotation();
		R.Pitch = -FMath::RadiansToDegrees(Fall);
		F->SetActorRotation(R);
		if (C.T > 1.6f)
		{
			FVector L = F->GetActorLocation();
			L.Z = C.BaseZ - (C.T - 1.6f) * 70.0;
			F->SetActorLocation(L);
		}
		if (C.bBoss && FMath::FRand() < Dt * 14.f)
		{
			Burst(FVector2D(F->GetActorLocation().X / 100.0, F->GetActorLocation().Y / 100.0) + FVector2D(FMath::FRandRange(-2.f, 2.f), FMath::FRandRange(-2.f, 2.f)), 4, FLinearColor(1.f, 0.6f, 0.2f), 6.f, FMath::FRandRange(0.5f, 3.f));
		}
		if (C.T > (C.bBoss ? 5.2f : 3.2f))
		{
			F->Destroy();
			C.T = -99.f;
		}
	}
	Corpses.RemoveAll([](const FDSCorpse& C) { return C.T < -50.f; });
}

// ================================================================== visuals

void ADSGame::BuildPlayerFigure()
{
	PlayerFig = GetWorld()->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
	const FLinearColor Steel(0.45f, 0.47f, 0.52f);
	PlayerFig->AddPart(EDSShape::Cylinder, FVector(0, 0, 0.95), FVector(0.62, 0.62, 1.0), Steel);          // 0 body
	PlayerFig->AddPart(EDSShape::Sphere, FVector(0, 0, 1.75), FVector(0.42, 0.42, 0.46), Steel * 1.2f);     // 1 head
	PlayerFig->AddPart(EDSShape::Cube, FVector(0.5, 0.45, 1.2), FVector(0.1, 0.1, 1.2), FLinearColor(0.8f, 0.82f, 0.9f)); // 2 weapon
	PlayerFig->AddPart(EDSShape::Cube, FVector(0.4, -0.5, 1.1), FVector(0.12, 0.6, 0.8), FLinearColor(0.35f, 0.15f, 0.1f)); // 3 shield
	PlayerFig->AddPart(EDSShape::Sphere, FVector(0.25, 0, 1.78), FVector(0.14, 0.3, 0.1), FLinearColor(0.9f, 0.4f, 0.1f)); // 4 visor glow
	PlayerFig->AddPart(EDSShape::Cylinder, FVector(0.6, 0.35, 1.1), FVector(0.09, 0.09, 1.0), FLinearColor(0.23f, 0.15f, 0.09f));   // 5 torch stick
	PlayerFig->AddPart(EDSShape::Cone, FVector(0.6, 0.35, 1.75), FVector(0.3, 0.3, 0.5), FLinearColor(1.f, 0.65f, 0.2f) * 5.f);         // 6 flame
	PlayerFig->SetActorHiddenInGame(true);
}

ADSVisual* ADSGame::BuildFigure(EDSEnemy Type)
{
	const FDSEnemyDef& C = DSData::Enemy(Type);
	const FLinearColor Col = EnemyColor(Type);
	const float S = C.R / 0.7f;
	const float Hs = FMath::Pow(S, 0.7f);
	ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
	if (Type == EDSEnemy::Fist)
	{
		V->AddPart(EDSShape::Cube, FVector(0, 0, 1.3), FVector(3.2, 3.6, 2.6), FLinearColor(0.4f, 0.47f, 0.55f));
		V->AddPart(EDSShape::Cube, FVector(0, -1.8, 1.6), FVector(1.6, 0.4, 0.4), FLinearColor(0.2f, 0.9f, 1.f) * 3.f);
		return V;
	}
	if (Type == EDSEnemy::Serpent)
	{
		for (int32 i = 0; i < 6; i++)
			V->AddPart(EDSShape::Sphere, FVector(-i * 1.1, 0, 0.8 + (i == 0 ? 1.5 : 0.0)), FVector(1.5 - i * 0.18), Col);
		V->AddPart(EDSShape::Sphere, FVector(0.6, 0, 3.0), FVector(0.9), Col * 1.3f);
		V->AddPart(EDSShape::Sphere, FVector(1.0, 0.2, 3.1), FVector(0.2), FLinearColor(0.3f, 1.f, 0.5f) * 4.f);
		return V;
	}
	if (Type == EDSEnemy::Hound)
	{
		V->AddPart(EDSShape::Cube, FVector(0, 0, 0.7), FVector(1.5, 0.7, 0.7), Col);
		V->AddPart(EDSShape::Sphere, FVector(0.9, 0, 0.9), FVector(0.55), Col * 1.2f);
		V->AddPart(EDSShape::Sphere, FVector(1.15, 0.12, 0.98), FVector(0.1), FLinearColor(1.f, 0.3f, 0.1f) * 4.f);
		return V;
	}
	V->AddPart(EDSShape::Cylinder, FVector(0, 0, 0.95 * Hs), FVector(0.62 * S, 0.62 * S, 1.0 * Hs), Col);                    // 0 body
	V->AddPart(EDSShape::Sphere, FVector(0, 0, 1.75 * Hs + 0.1 * S), FVector(0.42 * S, 0.42 * S, 0.46 * S), Col * 1.25f);     // 1 head
	V->AddPart(EDSShape::Cube, FVector(0.5 * S, 0.45 * S, 1.2 * Hs), FVector(0.1 * S, 0.1 * S, 1.1 * Hs), FLinearColor(0.6f, 0.6f, 0.6f)); // 2 weapon
	const bool bBossLike = C.AI == EDSAI::Boss;
	V->AddPart(EDSShape::Sphere, FVector(0.3 * S, 0, 1.8 * Hs + 0.1 * S), FVector(0.15 * S, 0.34 * S, 0.1 * S),
		bBossLike ? FLinearColor(1.f, 0.3f, 0.1f) * 5.f : FLinearColor(1.f, 0.7f, 0.2f) * 3.f);                                // 3 eyes
	if (C.bShield) V->AddPart(EDSShape::Cube, FVector(0.45 * S, -0.55 * S, 1.1 * Hs), FVector(0.12, 0.65 * S, 0.85 * S), FLinearColor(0.3f, 0.3f, 0.35f));
	if (Type == EDSEnemy::Cyborg)
	{
		V->AddPart(EDSShape::Cube, FVector(0, 0, 6.0), FVector(5.0, 8.0, 7.0), Col);
		V->AddPart(EDSShape::Sphere, FVector(2.2, 0, 8.8), FVector(2.0), Col * 1.3f);
		V->AddPart(EDSShape::Sphere, FVector(3.6, 0, 9.0), FVector(0.5), FLinearColor(0.2f, 0.9f, 1.f) * 5.f);
	}
	return V;
}

void ADSGame::SyncVisuals(float Dt)
{
	if (State == EDSState::Title) return;
	SyncPlayer(Dt);
	for (const FDSEnemyPtr& E : Enemies) SyncEnemy(*E, Dt);
	for (FDSProjectile& P : Projs)
		if (ADSVisual* N = P.Node.Get())
			N->Place(P3(P.Pos, P.H), AngleOf(P.Vel));
}

void ADSGame::SyncPlayer(float Dt)
{
	if (!PlayerFig) return;
	PlayerFig->SetActorHiddenInGame(false);
	const FVector Pos = P3(PPos);
	float Pitch = 0.f;
	if (PAct == EDSAct::Roll) Pitch = -360.f * FMath::Clamp(PActT / 0.45f, 0.f, 1.f);
	if (PAct == EDSAct::Dead) Pitch = -90.f;
	PlayerFig->SetActorLocationAndRotation(Pos, FRotator(Pitch, FMath::RadiansToDegrees(PFace), 0.0));
	PlayerFig->SetFlash(PFlash > 0.f);

	// weapon + shield poses (parts 2 and 3)
	const EDSWeapon W = Equipped;
	const FDSWeaponDef& WD = DSData::Weapon(W);
	FVector BladeScale(0.1, 0.1, 1.2);
	if (W == EDSWeapon::Cleaver) BladeScale = FVector(0.35, 0.12, 1.3);
	if (W == EDSWeapon::Spear) BladeScale = FVector(0.07, 0.07, 2.4);
	if (W == EDSWeapon::Gun) BladeScale = FVector(0.12, 0.1, 0.35);
	BladeScale *= (1.f + 0.06f * WTier[(int32)W]);
	UStaticMeshComponent* Blade = PlayerFig->GetPart(2);
	UStaticMeshComponent* Shield = PlayerFig->GetPart(3);
	if (Blade && Shield)
	{
		Blade->SetVisibility(bHasWeapon && !bTorchHeld);
		if (UStaticMeshComponent* Ts = PlayerFig->GetPart(5)) Ts->SetVisibility(bTorchHeld);
		if (UStaticMeshComponent* Tf = PlayerFig->GetPart(6)) Tf->SetVisibility(bTorchHeld);
		Blade->SetRelativeScale3D(BladeScale);
		const float K = (PAct == EDSAct::Attack && PAtk.Time > 0.f) ? FMath::Clamp(PActT / PAtk.Time, 0.f, 1.f) : 0.f;
		FVector Loc(0.55, 0.45, 1.25);
		FRotator Rot(0, 0, 0);
		const bool bGun = WD.Style == EDSStyle::Shoot;
		if (bGun) { Loc = FVector(0.7, 0.4, 1.2); Rot = FRotator(90, 0, 0); }
		else Rot = FRotator(0, 0, -20);
		if (PAct == EDSAct::Attack)
		{
			const FString& Anim = PAtk.Anim;
			if (Anim == TEXT("thrust") || Anim == TEXT("lunge") || Anim == TEXT("double") || Anim == TEXT("vault"))
			{
				Loc = FVector(0.4 + 1.6 * FMath::Sin(K * PI), 0.35, 1.2);
				Rot = FRotator(90, 0, 0);
			}
			else if (Anim == TEXT("overhead") || Anim == TEXT("upper"))
			{
				const float A = FMath::Lerp(-200.f, 40.f, K);
				Loc = FVector(0.5 + 0.8 * FMath::Sin(FMath::DegreesToRadians(A + 90.f)), 0.3, 1.2 + 1.0 * FMath::Cos(FMath::DegreesToRadians(A)));
				Rot = FRotator(A, 0, 0);
			}
			else
			{
				const float Dir = (Anim == TEXT("slash_l")) ? -1.f : 1.f;
				const float A = FMath::Lerp(-1.3f, 1.3f, K) * -Dir;
				Loc = FVector(FMath::Cos(A) * 0.9, FMath::Sin(A) * 0.9, 1.25);
				Rot = FRotator(90, FMath::RadiansToDegrees(A), 0);
			}
		}
		Blade->SetRelativeLocation(Loc * 100.0);
		Blade->SetRelativeRotation(Rot);

		Shield->SetVisibility(!bGun);
		const float B = PBlock;
		Shield->SetRelativeLocation(FVector(FMath::Lerp(0.2, 0.75, B), FMath::Lerp(-0.55, 0.0, B), 1.1) * 100.0);
		Shield->SetRelativeRotation(FRotator(0, FMath::Lerp(0.f, 0.f, B), 0));
	}
	if (PStone > 0.f) PlayerFig->SetPartColor(0, FLinearColor(0.5f, 0.5f, 0.48f));
	else PlayerFig->SetPartColor(0, PRage > 0.f ? FLinearColor(0.7f, 0.2f, 0.15f) : FLinearColor(0.45f, 0.47f, 0.52f));
}

void ADSGame::SyncEnemy(FDSEnemy& E, float Dt)
{
	ADSVisual* F = E.Fig.Get();
	if (!F || E.bDead) return;
	E.Walk += Dt * E.Mv * 1.5f;
	FVector Pos = P3(E.Pos);
	Pos.Z -= E.Sink * 100.0;
	float Pitch = 0.f;
	// lean into a wind-up, lunge on the strike
	if (E.AI == EDSAI::Melee || E.AI == EDSAI::Boss)
	{
		if (E.St == EDSEState::Wind) Pitch = 12.f;
		if (E.St == EDSEState::Strike) Pitch = -18.f;
	}
	if (E.St == EDSEState::Stagger) Pitch = 25.f;
	if (E.Type == EDSEnemy::Fist) Pos.Z += FMath::Max(0.f, 18.f - E.Life * 80.f) * 100.0;
	F->SetActorLocationAndRotation(Pos, FRotator(Pitch, FMath::RadiansToDegrees(E.Face), 0.0));
	F->SetFlash(E.Flash > 0.f);
	if (E.AI == EDSAI::Boss) BossVisuals(E, Dt);
	// the idle camp waits a little hidden in the ground until you are close enough to be seen
}

// ================================================================== simple state helpers

bool ADSGame::IsFrozenExceptShop() const
{
	return bPaused || bDialogActive;
}

const FDSButton* ADSGame::HitTest(const FVector2D& P) const
{
	for (int32 i = Buttons.Num() - 1; i >= 0; i--)
		if (Buttons[i].Rect.IsInside(P)) return &Buttons[i];
	return nullptr;
}

void ADSGame::ShowBanner(const FString& Text, float Secs, const FString& Sub)
{
	BannerText = Text;
	BannerSub = Sub;
	BannerT = Secs;
}

void ADSGame::TogglePause()
{
	if (State != EDSState::Play || bDialogActive || bShopOpen) return;
	bPaused = !bPaused;
}

bool ADSGame::CanCycle() const
{
	int32 N = 0;
	for (int32 i = 0; i < 4; i++) if (WeaponsOwned[i]) N++;
	return N > 1;
}
