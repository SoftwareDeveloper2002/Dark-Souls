// Boss fights. Port of scripts/bosses.gd (demon, serpent queen, cyborg titan, Lord Malakar).
#include "DSGame.h"
#include "DSVisual.h"

namespace
{
	float WindBase(EDSBossAtk A)
	{
		switch (A)
		{
		case EDSBossAtk::Slam: return 0.95f;
		case EDSBossAtk::Sweep: return 0.7f;
		case EDSBossAtk::Charge: return 0.85f;
		case EDSBossAtk::Volley: return 0.9f;
		case EDSBossAtk::Bolts: return 1.0f;
		case EDSBossAtk::Summon: return 1.2f;
		case EDSBossAtk::Roll: return 1.1f;
		case EDSBossAtk::Gaze: return 1.4f;
		case EDSBossAtk::Stone: return 1.5f;
		case EDSBossAtk::Bite: return 0.55f;
		case EDSBossAtk::Spit: return 0.8f;
		case EDSBossAtk::Tail: return 0.8f;
		case EDSBossAtk::Fist: return 1.0f;
		case EDSBossAtk::Laser: return 1.5f;
		case EDSBossAtk::Missiles: return 1.0f;
		default: return 1.f;
		}
	}

	struct FAtkSet { TArray<EDSBossAtk> Near, Far; };

	FAtkSet FormAtk(EDSForm F)
	{
		using A = EDSBossAtk;
		switch (F)
		{
		case EDSForm::Demon: return { { A::Slam, A::Sweep }, { A::Roll, A::Roll, A::Charge } };
		case EDSForm::Serpent: return { { A::Tail, A::Sweep }, { A::Gaze, A::Stone, A::Spit } };
		case EDSForm::Cyborg: return { { A::Slam }, { A::Fist, A::Laser, A::Missiles, A::Bolts } };
		default: return { { A::Sweep, A::Slam }, { A::Charge, A::Bolts, A::Volley, A::Summon } };
		}
	}

	FAtkSet BaseAtk(EDSEnemy T)
	{
		using A = EDSBossAtk;
		switch (T)
		{
		case EDSEnemy::Demon: return { { A::Slam, A::Sweep }, { A::Roll } };
		case EDSEnemy::Serpent: return { { A::Bite, A::Tail }, { A::Spit, A::Bite } };
		default: return { { A::Fist }, { A::Fist, A::Laser, A::Missiles } };
		}
	}

	FLinearColor FormColor(EDSForm F)
	{
		switch (F)
		{
		case EDSForm::Demon: return FLinearColor(1.f, 0.54f, 0.13f);
		case EDSForm::Serpent: return FLinearColor(0.31f, 1.f, 0.5f);
		case EDSForm::Cyborg: return FLinearColor(0.19f, 0.88f, 1.f);
		default: return FLinearColor(1.f, 0.13f, 0.13f);
		}
	}

	const TCHAR* FormName(EDSForm F)
	{
		switch (F)
		{
		case EDSForm::Demon: return TEXT("THE ASYLUM DEMON");
		case EDSForm::Serpent: return TEXT("THE SERPENT QUEEN");
		case EDSForm::Cyborg: return TEXT("THE CYBORG TITAN");
		default: return TEXT("HIS OWN DARKNESS");
		}
	}
}

float ADSGame::WindTime(const FDSEnemy& E) const
{
	return WindBase(E.Atk) * (E.Phase > 1 ? 0.8f : 1.f);
}

void ADSGame::BossAttach(FDSEnemy& E)
{
	E.CdGaze = 3.f;
	E.CdStone = 9.f;
	UWorld* W = GetWorld();
	auto Flat = [&](EDSShape S, const FVector& Sc, const FLinearColor& C)
	{
		ADSVisual* V = W->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
		V->AddPart(S, FVector::ZeroVector, Sc, C);
		V->SetShadows(false);
		V->SetActorHiddenInGame(true);
		return V;
	};
	E.Tele = Flat(EDSShape::Cylinder, FVector(2, 2, 0.04), FLinearColor(1.f, 0.2f, 0.1f) * 2.f);
	E.Tele2 = Flat(EDSShape::Cube, FVector(1, 1, 0.04), FLinearColor(1.f, 0.2f, 0.1f) * 2.f);
	E.Cone = Flat(EDSShape::Cube, FVector(1, 1, 0.04), FLinearColor(0.3f, 1.f, 0.5f) * 2.f);
	E.Beam = Flat(EDSShape::Cube, FVector(1, 1, 1), FLinearColor(1.f, 0.3f, 0.25f) * 6.f);
	switch (E.Type)
	{
	case EDSEnemy::Demon: BossRaiseShield(E, 380.f); break;
	case EDSEnemy::Cyborg: E.bStatic = true; E.Sink = 3.f; break;
	case EDSEnemy::Serpent:
		for (int32 i = 0; i < 40; i++) E.Trail.Add(E.Pos + FVector2D(0, i * 0.45f));
		break;
	default: break;
	}
}

void ADSGame::BossRaiseShield(FDSEnemy& E, float Hp)
{
	E.Shield = E.ShieldMax = Hp;
	if (!E.Dome.IsValid())
	{
		ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(FVector::ZeroVector, FRotator::ZeroRotator);
		V->AddPart(EDSShape::Cylinder, FVector::ZeroVector, FVector(1, 1, 0.06), FLinearColor(0.1f, 0.5f, 1.f) * 3.f);   // shield ring on the ground
		V->SetShadows(false);
		E.Dome = V;
	}
	E.Dome->SetActorHiddenInGame(false);
}

void ADSGame::BossDropShield(FDSEnemy& E)
{
	E.Shield = 0.f;
	if (E.Dome.IsValid()) E.Dome->SetActorHiddenInGame(true);
}

void ADSGame::BossFreeNodes(FDSEnemy& E)
{
	for (TWeakObjectPtr<ADSVisual>* N : { &E.Tele, &E.Tele2, &E.Cone, &E.Beam, &E.Dome })
	{
		if (N->IsValid()) (*N)->Destroy();
		*N = nullptr;
	}
}

float ADSGame::BossAbsorb(FDSEnemy& E, float Dmg)
{
	if (E.Shield > 0.f)
	{
		E.Shield -= Dmg;
		E.DomeFlash = 0.3f;
		Float(P3(E.Pos, 4.6f), TEXT("SHIELD"), FLinearColor(0.48f, 0.82f, 1.f));
		if (E.Shield <= 0.f)
		{
			BossDropShield(E);
			E.Stun = 2.6f;
			E.bRolling = false;
			E.St = EDSEState::Recover;
			E.T = 0.f;
			Shake = 14.f;
			Burst(E.Pos, 24, FLinearColor(0.48f, 0.82f, 1.f), 12.f, 2.f);
			ShowBanner(TEXT("SHIELD BROKEN"), 1.8f);
		}
		return 0.f;
	}
	if (E.Stun > 0.f) Dmg *= 1.5f;
	return Dmg;
}

void ADSGame::BossSpawnAdds(FDSEnemy& E, int32 N)
{
	static const EDSEnemy Kinds[] = { EDSEnemy::Knight, EDSEnemy::Fiend, EDSEnemy::Skeleton, EDSEnemy::Ghoul };
	for (int32 i = 0; i < N; i++)
		if (QuestEnemyCount() < AddCap(9))
		{
			const FVector2D P = E.Pos + FromAngle(FMath::FRand() * 2.f * PI) * 4.5f;
			SpawnEnemy(Kinds[FMath::RandRange(0, 3)], &P, true);
		}
}

void ADSGame::BossPhaseCheck(FDSEnemy& E)
{
	const FDSBossDef& B = DSData::Boss(E.Type);
	int32 Want = 1;
	for (int32 i = 0; i < B.NumPhases; i++)
		if (E.Hp < E.MaxHp * B.Phases[i]) Want++;
	if (Want <= E.Phase) return;
	E.Phase = Want;
	E.Speed *= 1.12f;
	Shake = 14.f;
	ShowBanner(FString::Printf(TEXT("%s ENRAGES"), DSData::Enemy(E.Type).Name), 2.4f);
	Burst(E.Pos, 24, FLinearColor(1.f, 0.35f, 0.16f), 12.f, 1.f);
	Strike(E.Pos);
	switch (E.Type)
	{
	case EDSEnemy::Demon: BossRaiseShield(E, 260.f); E.Stun = 0.f; break;
	case EDSEnemy::Serpent: E.CdStone = 0.5f; E.CdGaze = FMath::Min(E.CdGaze, 2.f); break;
	case EDSEnemy::Malakar: BossSpawnAdds(E, 2); break;
	case EDSEnemy::Cyborg: E.CdStone = 0.f; break;
	default: break;
	}
	if (E.Type != EDSEnemy::Cyborg && E.Type != EDSEnemy::Serpent && E.Type != EDSEnemy::Malakar && QuestEnemyCount() < AddCap(8))
	{
		const FVector2D A = E.Pos + FVector2D(3, 0), B2 = E.Pos + FVector2D(-3, 0);
		SpawnEnemy(EDSEnemy::Skeleton, &A, true);
		SpawnEnemy(EDSEnemy::Hollow, &B2, true);
	}
}

void ADSGame::BossSwitchForm(FDSEnemy& E, EDSForm Form)
{
	E.Form = Form;
	E.FormT = 0.f;
	if (Form == EDSForm::Demon) BossRaiseShield(E, 1800.f); else BossDropShield(E);
	E.CdGaze = 1.f;
	E.CdStone = 4.f;
	ShowBanner(FString::Printf(TEXT("MALAKAR MIMICS %s"), FormName(Form)), 2.6f, TEXT("He takes their power"));
	Burst(E.Pos, 24, FormColor(Form), 12.f, 2.f);
	Strike(E.Pos);
	Shake = 12.f;
}

void ADSGame::BossAi(FDSEnemy& E, float Dt, float Dist, float Ang)
{
	const FDSEnemyDef& Cfg = DSData::Enemy(E.Type);
	BossPhaseCheck(E);
	E.HitCd = FMath::Max(0.f, E.HitCd - Dt);
	E.DomeFlash = FMath::Max(0.f, E.DomeFlash - Dt);
	E.Exposed = FMath::Max(0.f, E.Exposed - Dt);
	E.CdGaze = FMath::Max(0.f, E.CdGaze - Dt);
	E.CdStone = FMath::Max(0.f, E.CdStone - Dt);
	if (E.Type == EDSEnemy::Malakar)
	{
		E.FormT += Dt;
		if (E.FormT > 26.f && E.St == EDSEState::Chase) BossSwitchForm(E, (EDSForm)(((int32)E.Form + 1) % 4));
	}
	if (E.Type == EDSEnemy::Serpent && (E.Trail.IsEmpty() || FVector2D::Distance(E.Pos, E.Trail[0]) > 0.4f))
	{
		E.Trail.Insert(E.Pos, 0);
		if (E.Trail.Num() > 90) E.Trail.Pop();
	}
	if (E.Stun > 0.f)
	{
		E.Stun -= Dt;
		E.Face = Ang;
		return;
	}
	const float Reach = Cfg.Reach;
	const EDSForm Kind = E.Type == EDSEnemy::Malakar ? E.Form : (E.Type == EDSEnemy::Serpent ? EDSForm::Serpent : (E.Type == EDSEnemy::Cyborg ? EDSForm::Cyborg : EDSForm::Demon));
	const bool bRangedStyle = Kind == EDSForm::Serpent || Kind == EDSForm::Cyborg;
	switch (E.St)
	{
	case EDSEState::Chase:
	{
		E.Face = Ang;
		E.Cd -= Dt;
		if (!E.bStatic)
		{
			if (Kind == EDSForm::Serpent)
			{
				if (Dist < 5.f) MoveE(E, -FromAngle(Ang) * E.Speed * 0.7f * Dt);
				else if (Dist > 9.f) MoveE(E, FromAngle(Ang) * E.Speed * Dt);
				else MoveE(E, FromAngle(Ang + PI * 0.5f) * E.Side * E.Speed * 0.5f * Dt);
			}
			else if (Kind == EDSForm::Cyborg)
			{
				if (Dist > 12.f) MoveE(E, FromAngle(Ang) * E.Speed * 0.8f * Dt);
				else if (Dist < 7.f) MoveE(E, -FromAngle(Ang) * E.Speed * 0.8f * Dt);
			}
			else if (Dist > Reach) MoveE(E, FromAngle(Ang) * E.Speed * Dt);
		}
		const FAtkSet Sets = E.Type == EDSEnemy::Malakar ? FormAtk(E.Form) : BaseAtk(E.Type);
		EDSBossAtk Choose = EDSBossAtk::None;
		if (Kind == EDSForm::Serpent && E.CdGaze <= 0.f && Dist > 3.5f && Dist < 22.f) Choose = EDSBossAtk::Gaze;
		else if (Kind == EDSForm::Serpent && E.CdStone <= 0.f && QuestEnemyCount() < AddCap(7)) Choose = EDSBossAtk::Stone;
		else if (!E.bStatic && Dist <= Reach + 1.f && Kind != EDSForm::Serpent && Kind != EDSForm::Cyborg) Choose = Sets.Near[FMath::RandRange(0, Sets.Near.Num() - 1)];
		else if (Kind == EDSForm::Serpent && Dist < 4.5f && E.Cd <= 0.f) Choose = Sets.Near[FMath::RandRange(0, Sets.Near.Num() - 1)];
		else if (E.Cd <= 0.f)
		{
			const TArray<EDSBossAtk>& Pool = (Dist > 6.f || E.bStatic || bRangedStyle) ? Sets.Far : Sets.Near;
			Choose = Pool[FMath::RandRange(0, Pool.Num() - 1)];
		}
		if (Choose != EDSBossAtk::None)
		{
			E.Atk = Choose;
			E.St = EDSEState::Wind;
			E.T = 0.f;
			E.bHitDone = false;
			E.Dash = FromAngle(Ang);
			BossBeginWind(E, Ang);
		}
		break;
	}
	case EDSEState::Wind:
	{
		const float Wd = WindTime(E);
		bool bTrack = E.T < Wd * 0.5f;
		if (E.Atk == EDSBossAtk::Charge || E.Atk == EDSBossAtk::Roll || E.Atk == EDSBossAtk::Bite) bTrack = E.T < Wd * 0.6f;
		if (E.Atk == EDSBossAtk::Gaze) bTrack = E.T < Wd * 0.75f;
		if (E.Atk == EDSBossAtk::Laser || E.Atk == EDSBossAtk::Fist || E.Atk == EDSBossAtk::Missiles) bTrack = true;
		if (bTrack) { E.Face = Ang; E.Dash = FromAngle(Ang); }
		BossWindUpdate(E, Ang);
		if (E.T > Wd)
		{
			E.St = EDSEState::Strike;
			E.T = 0.f;
			E.bHitDone = false;
			BossStrikeStart(E, Dist, Ang);
		}
		break;
	}
	case EDSEState::Strike:
		BossStrikeUpdate(E, Dt, Dist, Ang);
		break;
	case EDSEState::Recover:
		if (E.T > Cfg.Rec * (E.Phase > 1 ? 0.75f : 1.f))
		{
			E.St = EDSEState::Chase;
			E.T = 0.f;
			E.Cd = FMath::FRandRange(1.8f, 3.4f) * (E.Phase > 1 ? 0.75f : 1.f);
			if (E.Type == EDSEnemy::Cyborg) E.Cd = FMath::FRandRange(1.6f, 2.8f);
		}
		break;
	default: break;
	}
}

void ADSGame::BossBeginWind(FDSEnemy& E, float Ang)
{
	if (E.Atk == EDSBossAtk::Fist)
	{
		// mark the ground right now; the fist drops when the telegraph runs out
		FDSEnemyPtr Self;
		for (const FDSEnemyPtr& P : Enemies) if (P.Get() == &E) { Self = P; break; }
		const int32 Count = E.Phase == 1 ? 1 : 2;
		for (int32 i = 0; i < Count; i++)
		{
			const FVector2D Tgt = PPos + (i > 0 ? FromAngle(FMath::FRand() * 2.f * PI) * FMath::FRandRange(0.f, 4.f) : FVector2D::ZeroVector);
			AddZone(Tgt, 4.2f, WindTime(E), E.Dmg, false, false, Self);
		}
	}
	else if (E.Atk == EDSBossAtk::Stone)
	{
		Burst(E.Pos, 14, FLinearColor(0.75f, 0.75f, 0.69f), 8.f, 0.6f);
	}
}

void ADSGame::BossPlaceBeam(FDSEnemy& E, float A, float Thick)
{
	if (!E.Beam.IsValid()) return;
	const FVector2D Dir = FromAngle(A);
	const float Length = 60.f;
	const float H = E.Type == EDSEnemy::Cyborg ? 5.f : 1.4f;
	E.Beam->SetActorHiddenInGame(false);
	E.Beam->SetActorLocationAndRotation(P3(E.Pos + Dir * Length * 0.5f, H), FRotator(0, FMath::RadiansToDegrees(A), 0));
	E.Beam->SetActorScale3D(FVector(Length, Thick, Thick));
}

void ADSGame::BossWindUpdate(FDSEnemy& E, float Ang)
{
	const float W = FMath::Clamp(E.T / WindTime(E), 0.f, 1.f);
	if (E.Atk == EDSBossAtk::Gaze && E.Cone.IsValid())
	{
		E.Cone->SetActorHiddenInGame(false);
		E.Cone->SetActorLocationAndRotation(P3(E.Pos + FromAngle(E.Face) * 11.f, 0.3f), FRotator(0, FMath::RadiansToDegrees(E.Face), 0));
		E.Cone->SetActorScale3D(FVector(22.f, 20.f, 1.f));
	}
	if (E.Atk == EDSBossAtk::Laser)
	{
		E.BeamA0 = Ang - 0.5f;
		E.BeamA1 = Ang + 0.5f;
		BossPlaceBeam(E, E.BeamA0, 0.12f + 0.1f * W);
	}
	if (E.Atk == EDSBossAtk::Roll && E.Tele2.IsValid())
	{
		E.Tele2->SetActorHiddenInGame(false);
		E.Tele2->SetActorLocationAndRotation(P3(E.Pos + FromAngle(E.Face) * 9.f, 0.12f), FRotator(0, FMath::RadiansToDegrees(E.Face), 0));
		E.Tele2->SetActorScale3D(FVector(18.f * W, 3.2f, 1.f));
	}
}

void ADSGame::BossStrikeStart(FDSEnemy& E, float Dist, float Ang)
{
	const FDSBossDef& Bc = DSData::Boss(E.Type);
	switch (E.Atk)
	{
	case EDSBossAtk::Slam:
	case EDSBossAtk::Tail:
	{
		const float R = E.Atk == EDSBossAtk::Slam ? Bc.SlamR : Bc.SlamR * 0.85f;
		if (Dist < R + PR) HurtPlayer(E.Dmg, E.Pos);
		Shake = FMath::Max(Shake, 14.f);
		Burst(E.Pos, 24, FLinearColor(0.48f, 0.54f, 0.65f), 11.f, 0.3f);
		Ring(E.Pos, FLinearColor(0.7f, 0.7f, 0.8f), R, 0.4f);
		if (E.Phase > 1) Strike(E.Pos);
		break;
	}
	case EDSBossAtk::Sweep:
		if (Dist < Bc.SweepLen + PR && FMath::Abs(AngleDiff(Ang, E.Face)) < 1.2f) HurtPlayer(E.Dmg * 0.8f, E.Pos);
		Shake = FMath::Max(Shake, 9.f);
		break;
	case EDSBossAtk::Volley:
	{
		const int32 N = E.Phase == 1 ? 5 : 7;
		for (int32 i = 0; i < N; i++) Fire(E.Pos, Ang + FMath::Lerp(-0.55f, 0.55f, (float)i / (N - 1)), E.Dmg * 0.55f, 11.f, EDSProj::Orb);
		break;
	}
	case EDSBossAtk::Spit:
		for (int32 i = 0; i < 3; i++) Fire(E.Pos, Ang + FMath::Lerp(-0.3f, 0.3f, i / 2.f), E.Dmg * 0.6f, 12.f, EDSProj::Venom);
		break;
	case EDSBossAtk::Bolts:
	{
		const int32 N = E.Phase == 1 ? 4 : 6;
		AddZone(PPos, 2.6f, 1.f, E.Dmg * 0.9f, false);
		for (int32 i = 0; i < N - 1; i++)
			AddZone(PPos + FromAngle(FMath::FRand() * 2.f * PI) * FMath::FRandRange(2.5f, 8.f), 2.6f, FMath::FRandRange(0.9f, 1.6f), E.Dmg * 0.9f, false);
		break;
	}
	case EDSBossAtk::Summon:
		BossSpawnAdds(E, 2);
		Burst(E.Pos, 20, FLinearColor(0.69f, 0.44f, 1.f), 9.f);
		break;
	case EDSBossAtk::Stone:
	{
		E.CdStone = E.Phase == 1 ? 18.f : 12.f;
		const int32 N = E.Phase == 1 ? 4 : 5;
		for (int32 i = 0; i < N; i++)
		{
			if (QuestEnemyCount() >= AddCap(9)) break;
			FVector2D Pp = PPos + FromAngle((float)i / N * 2.f * PI + FMath::FRand()) * 8.f;
			Pp = SpawnNear(Pp, 0.f, 2.5f);
			SpawnEnemy(EDSEnemy::StoneSoldier, &Pp, true);
			Burst(Pp, 10, FLinearColor(0.75f, 0.75f, 0.69f), 8.f, 0.4f);
		}
		Shake = 10.f;
		break;
	}
	case EDSBossAtk::Gaze:
		E.CdGaze = E.Phase == 1 ? 10.f : 8.f;
		if (E.Cone.IsValid()) E.Cone->SetActorHiddenInGame(true);
		if (Dist < 23.f && FMath::Abs(AngleDiff(Ang, E.Face)) < 0.58f) PetrifyPlayer(2.4f, E.Dmg * 0.4f);
		else Float(P3(PPos, 2.4f), TEXT("RESISTED"), FLinearColor(0.63f, 1.f, 0.72f));
		break;
	case EDSBossAtk::Roll:
		E.bRolling = true;
		E.HitCd = 0.f;
		break;
	case EDSBossAtk::Laser:
		E.BeamTick = 0.f;
		break;
	case EDSBossAtk::Missiles:
	{
		const int32 M = E.Phase == 1 ? 6 : 9;
		for (int32 i = 0; i < M; i++)
		{
			const float Side = i % 2 == 0 ? 1.f : -1.f;
			Fire(E.Pos, Ang + Side * (0.5f + 0.2f * (float)(i / 2)), E.Dmg * 0.55f, 8.f, EDSProj::Missile, 1.6f, 6.f);
		}
		Shake = 6.f;
		break;
	}
	default: break;
	}
}

void ADSGame::BossStrikeUpdate(FDSEnemy& E, float Dt, float Dist, float Ang)
{
	const FDSEnemyDef& Cfg = DSData::Enemy(E.Type);
	float SLen = 0.2f;
	switch (E.Atk)
	{
	case EDSBossAtk::Charge:
		SLen = 0.55f;
		MoveE(E, E.Dash * 26.f * Dt);
		if (!E.bHitDone && Dist < Cfg.R + PR + 0.8f) { E.bHitDone = true; HurtPlayer(E.Dmg * 0.9f, E.Pos); }
		Shake = FMath::Max(Shake, 4.f);
		break;
	case EDSBossAtk::Bite:
		SLen = 0.3f;
		MoveE(E, E.Dash * 22.f * Dt);
		if (!E.bHitDone && Dist < Cfg.R + PR + 1.4f)
		{
			E.bHitDone = true;
			HurtPlayer(E.Dmg, E.Pos);
			Burst(PPos, 5, FLinearColor(0.38f, 1.f, 0.56f), 6.f);
		}
		break;
	case EDSBossAtk::Roll:
	{
		SLen = 1.7f;
		if (E.Tele2.IsValid()) E.Tele2->SetActorHiddenInGame(true);
		MoveE(E, E.Dash * 21.f * Dt);
		if (bArenaActive)
		{
			const FVector2D Rel = E.Pos - Site;
			if (Rel.Size() > ArenaR - 2.8f)
			{
				const FVector2D N = (-Rel).GetSafeNormal();
				E.Dash = E.Dash - 2.f * FVector2D::DotProduct(E.Dash, N) * N;   // bounce off the arena wall
				Shake = FMath::Max(Shake, 8.f);
				Burst(E.Pos, 8, FLinearColor(0.6f, 0.54f, 0.44f), 8.f, 0.4f);
			}
		}
		Shake = FMath::Max(Shake, 3.f);
		if (E.HitCd <= 0.f && Dist < Cfg.R + PR + 0.9f)
		{
			E.HitCd = 0.7f;
			HurtPlayer(E.Dmg * 0.9f, E.Pos);
			PPos = Contain(Slide(PPos, (PPos - E.Pos).GetSafeNormal() * 2.5f));
		}
		break;
	}
	case EDSBossAtk::Laser:
	{
		SLen = 2.8f;
		const float K = FMath::Clamp(E.T / SLen, 0.f, 1.f);
		const float A = FMath::Lerp(E.BeamA0, E.BeamA1, K);
		BossPlaceBeam(E, A, 0.7f);
		E.BeamTick -= Dt;
		if (E.BeamTick <= 0.f)
		{
			E.BeamTick = 0.18f;
			const FVector2D Dir = FromAngle(A);
			const FVector2D Rel = PPos - E.Pos;
			const float Along = FVector2D::DotProduct(Rel, Dir);
			const float Off = FMath::Abs(FVector2D::CrossProduct(Rel, Dir));
			if (Along > 0.f && Along < 64.f && Off < 1.2f) HurtPlayer(E.Dmg * 0.35f, E.Pos, true);
		}
		Shake = FMath::Max(Shake, 3.f);
		break;
	}
	default: break;
	}
	if (E.T > SLen)
	{
		if (E.Atk == EDSBossAtk::Roll)
		{
			E.bRolling = false;
			E.Stun = 1.8f;
			Float(P3(E.Pos, 4.5f), TEXT("DIZZY"), FLinearColor(1.f, 0.88f, 0.44f));
		}
		if (E.Atk == EDSBossAtk::Laser)
		{
			if (E.Beam.IsValid()) E.Beam->SetActorHiddenInGame(true);
			E.Exposed = 3.f;
			Float(P3(E.Pos, 9.f), TEXT("CORE EXPOSED"), FLinearColor(0.48f, 0.82f, 1.f));
		}
		E.St = EDSEState::Recover;
		E.T = 0.f;
	}
}

void ADSGame::SpawnFist(FDSEnemyPtr Boss, const FVector2D& Pos)
{
	FDSEnemyPtr E = MakeShared<FDSEnemy>();
	E->Type = EDSEnemy::Fist;
	E->AI = EDSAI::Fist;
	E->Pos = Pos;
	E->R = 2.6f;
	E->Hp = E->MaxHp = 1.f;
	E->Mode = EDSMode::Alert;
	E->Home = E->Last = Pos;
	E->bForce = true;
	E->bQuest = false;
	E->bStatic = true;
	E->Life = 0.f;
	E->Link = Boss;
	E->Uid = ++Uid;
	E->Fig = BuildFigure(EDSEnemy::Fist);
	Enemies.Add(E);
	Shake = 16.f;
	Burst(Pos, 24, FLinearColor(0.6f, 0.67f, 0.73f), 11.f, 0.4f);
	if (FVector2D::Distance(PPos, Pos) < 4.2f + PR) HurtPlayer(Boss->Dmg, Pos, true);
}

void ADSGame::BossVisuals(FDSEnemy& E, float Dt)
{
	if (E.Dome.IsValid() && !E.Dome->IsHidden())
	{
		const float Rr = E.Type != EDSEnemy::Malakar ? 3.9f : 4.1f;
		E.Dome->SetActorLocation(P3(E.Pos, 0.15f));
		E.Dome->SetActorScale3D(FVector(Rr * 2.f, Rr * 2.f, 1.f));
		E.Dome->SetAllColor(FLinearColor(0.1f, 0.4f, 0.7f).CopyWithNewOpacity(1.f) * (E.DomeFlash > 0.f ? 6.f : 3.f));
	}
	if (E.Atk != EDSBossAtk::Gaze && E.Cone.IsValid()) E.Cone->SetActorHiddenInGame(true);
	if (E.Beam.IsValid() && !(E.Atk == EDSBossAtk::Laser && (E.St == EDSEState::Wind || E.St == EDSEState::Strike)))
		E.Beam->SetActorHiddenInGame(true);
	if (E.Atk == EDSBossAtk::Roll && E.bRolling)
	{
		if (ADSVisual* F = E.Fig.Get()) F->SetActorRotation(FRotator(Time * 800.f, FMath::RadiansToDegrees(E.Face), 0));
	}
	if (E.Stun > 0.f)
	{
		if (ADSVisual* F = E.Fig.Get()) F->SetActorRotation(FRotator(FMath::Sin(Time * 9.f) * 8.f, FMath::RadiansToDegrees(E.Face), FMath::Sin(Time * 6.f) * 8.f));
	}
}
