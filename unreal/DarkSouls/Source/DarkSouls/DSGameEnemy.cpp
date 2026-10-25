// Enemies, projectiles and ground zones. Port of the enemy half of game.gd.
#include "DSGame.h"
#include "DSVisual.h"

namespace
{
	float HeightScale(float R) { return FMath::Pow(R / 0.7f, 0.7f); }
}

// ================================================================== picking / spawning

EDSEnemy ADSGame::PickKind() const
{
	int32 Tot = 0;
	for (const TPair<EDSEnemy, int32>& P : Q.Table) Tot += P.Value;
	int32 R = FMath::RandRange(0, FMath::Max(Tot, 1) - 1);
	for (const TPair<EDSEnemy, int32>& P : Q.Table)
	{
		R -= P.Value;
		if (R < 0) return P.Key;
	}
	return Q.Table.Num() > 0 ? Q.Table[0].Key : EDSEnemy::Hollow;
}

EDSEnemy ADSGame::PickKindFor(int32 Ch) const
{
	const FDSQuest Full = DSData::MakeQuest(Ch * 10 + 10);   // the last quest of the chapter has the full pool
	int32 Tot = 0;
	for (const TPair<EDSEnemy, int32>& P : Full.Table) Tot += P.Value;
	int32 R = FMath::RandRange(0, FMath::Max(Tot, 1) - 1);
	for (const TPair<EDSEnemy, int32>& P : Full.Table)
	{
		R -= P.Value;
		if (R < 0) return P.Key;
	}
	return EDSEnemy::Hollow;
}

FVector2D ADSGame::SpawnNear(const FVector2D& C, float RMin, float RMax)
{
	const float Hc = Ground(C);
	for (int32 i = 0; i < 16; i++)
	{
		const FVector2D P = C + FromAngle(FMath::FRand() * 2.f * PI) * FMath::FRandRange(RMin, RMax);
		if (WalkOk(P) && FMath::Abs(Ground(P) - Hc) < 5.f && FVector2D::Distance(P, PPos) > 9.f) return P;
	}
	return C + FVector2D(RMin, 0.f);
}

int32 ADSGame::QuestEnemyCount() const
{
	int32 N = 0;
	for (const FDSEnemyPtr& E : Enemies)
		if (E->bQuest && !E->bDead && E->Type != EDSEnemy::Fist) N++;
	return N;
}

FDSEnemyPtr ADSGame::SpawnEnemy(EDSEnemy Kind, const FVector2D* At, bool bQuest, bool bIdle)
{
	const FDSEnemyDef& Cfg = DSData::Enemy(Kind);
	const bool bBoss = Cfg.AI == EDSAI::Boss;
	FDSEnemyPtr E = MakeShared<FDSEnemy>();
	const FVector2D Pos = At ? *At : SpawnNear(Site, 18.f, 28.f);
	const float Hs = bBoss ? 1.f : Q.Scale;
	const float Ds = bBoss ? 1.f : Q.DmgScale;
	E->Type = Kind;
	E->AI = Cfg.AI;
	E->Pos = Pos;
	E->R = Cfg.R;
	E->Hp = E->MaxHp = Cfg.Hp * Hs;
	E->Speed = FMath::FRandRange(Cfg.SpeedMin, FMath::Max(Cfg.SpeedMin, Cfg.SpeedMax));
	E->Face = FMath::FRand() * 2.f * PI;
	E->Dmg = Cfg.Dmg * Ds;
	E->Cd = FMath::FRandRange(1.f, 2.5f);
	E->Last = Pos;
	E->Side = FMath::FRand() < 0.5f ? 1.f : -1.f;
	E->bBoss = bBoss;
	E->bElite = Kind == EDSEnemy::Captain;
	E->Uid = ++Uid;
	E->TauntT = FMath::FRandRange(6.f, 14.f);
	E->Souls = (int32)(Cfg.Souls * (1.f + 0.03f * (QuestN - 1)));
	E->Mode = bIdle ? EDSMode::Idle : EDSMode::Alert;
	E->Home = Pos;
	E->Aggro = Cfg.AI == EDSAI::Ranged ? 18.f : 15.f;
	E->bQuest = bQuest;
	E->Fig = BuildFigure(Kind);
	if (bBoss)
	{
		E->Aggro = 0.f;
		BossAttach(*E);
	}
	Enemies.Add(E);
	return E;
}

void ADSGame::RemoveEnemy(FDSEnemy& E)
{
	E.bDead = true;
	if (E.Fig.IsValid()) E.Fig->Destroy();
	if (E.bBoss) BossFreeNodes(E);
}

// ================================================================== per-enemy update

void ADSGame::UpdateEnemy(FDSEnemy& E, float Dt)
{
	if (E.bDead) return;
	const FDSEnemyDef& Cfg = DSData::Enemy(E.Type);
	E.Flash = FMath::Max(0.f, E.Flash - Dt);
	E.Vcd = FMath::Max(0.f, E.Vcd - Dt);
	if (E.AI == EDSAI::Fist)
	{
		E.T += Dt;
		E.Life += Dt;
		if (E.Life > 4.8f)
		{
			for (const FDSEnemyPtr& P : Enemies) if (P.Get() == &E) { KillEnemy(P, false); break; }
		}
		return;
	}
	MoveE(E, E.Kb * Dt);
	E.Kb *= FMath::Pow(0.02f, Dt);
	if (E.Daze > 0.f)
	{
		// dazed: reeling, glowing, defenceless
		E.Daze -= Dt;
		E.St = EDSEState::Stagger;
		E.T = 0.f;
		E.Mv = 0.f;
		E.Flash = FMath::Max(E.Flash, ((int32)(Time * 5.f) % 2 == 0) ? 0.07f : 0.f);
		return;
	}
	const FVector2D ToP = PPos - E.Pos;
	const float Dist = ToP.Size();
	const float Ang = AngleOf(ToP);
	// idle camps and wayside groups wait until you come close
	if (E.Mode == EDSMode::Idle)
	{
		E.Mv = 0.f;
		E.Last = E.Pos;
		if (E.bForce || Dist < E.Aggro) E.Mode = EDSMode::Alert;
		else return;
	}
	else if (E.Mode == EDSMode::Return)
	{
		const FVector2D Back = E.Home - E.Pos;
		if (Back.Size() < 1.5f)
		{
			E.Mode = EDSMode::Idle;
			E.Hp = E.MaxHp;
			E.St = EDSEState::Chase;
		}
		else
		{
			E.Face = AngleOf(Back);
			MoveE(E, Back.GetSafeNormal() * E.Speed * Dt);
		}
		E.Mv = FVector2D::Distance(E.Pos, E.Last) / FMath::Max(Dt, 0.0001f);
		E.Last = E.Pos;
		return;
	}
	else if (E.bWayside && Dist > 52.f && E.St != EDSEState::Strike)
	{
		E.Mode = EDSMode::Return;
		return;
	}
	E.T += Dt;
	switch (E.AI)
	{
	case EDSAI::Melee: AiMelee(E, Cfg, Dt, Dist, Ang); break;
	case EDSAI::Ranged: AiRanged(E, Cfg, Dt, Dist, Ang); break;
	case EDSAI::Boss: BossAi(E, Dt, Dist, Ang); break;
	default: break;
	}
	E.Mv = FVector2D::Distance(E.Pos, E.Last) / FMath::Max(Dt, 0.0001f);
	E.Last = E.Pos;
}

void ADSGame::AiMelee(FDSEnemy& E, const FDSEnemyDef& Cfg, float Dt, float Dist, float Ang)
{
	const float Reach = Cfg.Reach;
	const float Lunge = Cfg.Lunge;
	switch (E.St)
	{
	case EDSEState::Chase:
		E.Face = Ang;
		if (Dist > Reach + (Lunge > 0.f ? 3.5f : 0.f)) MoveE(E, FromAngle(Ang) * E.Speed * Dt);
		else
		{
			E.St = EDSEState::Wind;
			E.T = 0.f;
			E.bHitDone = false;
		}
		break;
	case EDSEState::Wind:
		if (E.T < Cfg.Wind * 0.45f) E.Face = Ang;
		if (E.T > Cfg.Wind)
		{
			E.St = EDSEState::Strike;
			E.T = 0.f;
			E.Dash = FromAngle(E.Face);
		}
		break;
	case EDSEState::Strike:
		if (Lunge > 0.f)
		{
			if (E.T < 0.28f) MoveE(E, E.Dash * Lunge * Dt);
			if (!E.bHitDone && E.T > 0.22f)
			{
				E.bHitDone = true;
				if (Dist < Reach + PR + 0.8f) HurtPlayer(E.Dmg, E.Pos);
			}
			if (E.T > 0.3f) { E.St = EDSEState::Recover; E.T = 0.f; }
		}
		else
		{
			if (!E.bHitDone)
			{
				E.bHitDone = true;
				if (Dist < Reach + PR + 0.6f && FMath::Abs(AngleDiff(Ang, E.Face)) < 1.f) HurtPlayer(E.Dmg, E.Pos);
				else if (E.Type == EDSEnemy::Brute) Shake = FMath::Max(Shake, 5.f);
			}
			if (E.T > 0.15f) { E.St = EDSEState::Recover; E.T = 0.f; }
		}
		break;
	case EDSEState::Recover:
		if (E.T > Cfg.Rec) { E.St = EDSEState::Chase; E.T = 0.f; }
		break;
	case EDSEState::Stagger:
		if (E.T > 0.45f) { E.St = EDSEState::Chase; E.T = 0.f; }
		break;
	}
}

void ADSGame::AiRanged(FDSEnemy& E, const FDSEnemyDef& Cfg, float Dt, float Dist, float Ang)
{
	E.Cd -= Dt;
	const float RngD = Cfg.Range;
	switch (E.St)
	{
	case EDSEState::Chase:
		E.Face = Ang;
		if (Dist < RngD * 0.55f) MoveE(E, -FromAngle(Ang) * E.Speed * 1.1f * Dt);
		else if (Dist > RngD) MoveE(E, FromAngle(Ang) * E.Speed * Dt);
		else MoveE(E, FromAngle(Ang + PI * 0.5f) * E.Side * E.Speed * 0.45f * Dt);
		if (E.Cd <= 0.f && Dist < RngD + 3.f) { E.St = EDSEState::Wind; E.T = 0.f; }
		break;
	case EDSEState::Wind:
		E.Face = Ang;
		if (E.T > Cfg.Wind)
		{
			Fire(E.Pos, Ang, E.Dmg, Cfg.Proj == EDSProj::Arrow ? 12.f : 9.f, Cfg.Proj, 0.f, 1.3f + Cfg.Fly);
			E.St = EDSEState::Recover;
			E.T = 0.f;
			E.Cd = Cfg.Cd * FMath::FRandRange(0.8f, 1.25f);
			E.Side = -E.Side;
		}
		break;
	case EDSEState::Recover:
		if (E.T > 0.5f) { E.St = EDSEState::Chase; E.T = 0.f; }
		break;
	case EDSEState::Stagger:
		if (E.T > 0.45f) { E.St = EDSEState::Chase; E.T = 0.f; }
		break;
	default: break;
	}
}

// ================================================================== damage dealt

void ADSGame::HurtEnemy(FDSEnemyPtr E, float Dmg, float Ang, bool bBlocked, float KbMul)
{
	if (E->bDead) return;
	// Titan fists pass the damage on to the Titan itself
	if (FDSEnemyPtr Linked = E->Link.Pin())
	{
		E->Flash = 0.12f;
		Float(P3(E->Pos, 3.2f), FString::FromInt((int32)Dmg), FLinearColor(0.63f, 0.91f, 1.f));
		Burst(E->Pos, 6, FLinearColor(0.6f, 0.9f, 1.f), 6.f, 1.5f);
		HurtEnemy(Linked, Dmg, Ang, false);
		return;
	}
	if (E->bBoss)
	{
		Dmg = BossAbsorb(*E, Dmg);
		if (Dmg <= 0.f) { E->Flash = 0.1f; return; }
	}
	E->Hp -= Dmg;
	E->Flash = 0.15f;
	E->Mode = EDSMode::Alert;
	const bool bBig = E->bBoss || E->Type == EDSEnemy::Brute;
	E->Kb = FromAngle(Ang) * (E->bBoss ? 2.f : (bBig ? 3.f : (bBlocked ? 4.f : 12.f))) * KbMul;
	if (!E->bBoss && E->Type != EDSEnemy::Brute && !bBlocked && E->St != EDSEState::Strike && E->Type != EDSEnemy::Fist)
	{
		E->St = EDSEState::Stagger;
		E->T = 0.f;
	}
	const float Sh = HeightScale(E->R);
	if (bBlocked)
	{
		Burst(E->Pos, 7, FLinearColor(1.f, 0.9f, 0.66f), 7.f, 1.4f);
		Float(P3(E->Pos, 2.4f * Sh), TEXT("BLOCKED"), FLinearColor(0.79f, 0.76f, 0.66f));
	}
	else
	{
		Blood(E->Pos, Ang, bBig ? 18 : 10);
		Float(P3(E->Pos, FMath::Min(2.3f * Sh, 12.f)), FString::FromInt((int32)Dmg), FLinearColor(1.f, 0.95f, 0.78f));
	}
	Shake = FMath::Max(Shake, 5.f);
	if (E->Hp > 0.f && E->Type != EDSEnemy::Fist && E->Daze <= 0.f && E->Stun <= 0.f)
	{
		const float Thr = E->bBoss ? 0.1f : (E->bElite ? 0.42f : 0.45f);
		if (E->Hp < E->MaxHp * Thr)
		{
			if (E->bBoss)
			{
				E->Stun = 9.f;
				E->Atk = EDSBossAtk::None;
				E->St = EDSEState::Chase;
				E->T = 0.f;
				ShowBanner(TEXT("WEAKENED!"), 2.4f, TEXT("It takes extra damage while it reels"));
			}
			else if (E->bElite || FMath::FRand() < 0.7f)
			{
				E->Daze = 3.6f;
				E->St = EDSEState::Stagger;
			}
		}
	}
	if (E->Hp <= 0.f) KillEnemy(E, true);
}

void ADSGame::KillEnemy(FDSEnemyPtr E, bool bReward)
{
	if (E->bDead) return;
	E->bDead = true;
	if (E->Type == EDSEnemy::Fist)
	{
		Burst(E->Pos, 10, FLinearColor(0.6f, 0.67f, 0.73f), 8.f, 1.f);
		if (E->Fig.IsValid()) E->Fig->Destroy();
		return;
	}
	const float Sh = HeightScale(E->R);
	if (bReward)
	{
		Souls += E->Souls;
		Float(P3(E->Pos, FMath::Min(3.f * Sh, 12.f)), FString::Printf(TEXT("+%d"), E->Souls), FLinearColor(0.95f, 0.82f, 0.48f));
		const int32 N = E->bBoss ? 10 : 3;
		for (int32 i = 0; i < N; i++)
		{
			FDSOrb O;
			O.Node = MakeBall(0.28f, FLinearColor(0.95f, 0.82f, 0.48f) * 3.f);
			O.Pos = P3(E->Pos, 0.8f);
			O.Vel = FVector(FMath::FRandRange(-2, 2), FMath::FRandRange(-2, 2), FMath::FRandRange(3, 5)) * 100.0;
			OrbsList.Add(O);
		}
		if (WeaponsOwned[(int32)EDSWeapon::Gun] && (FMath::FRand() < 0.2f || E->bBoss))
		{
			FDSOrb O;
			O.bAmmo = true;
			O.Node = MakeBall(0.36f, FLinearColor(0.54f, 0.85f, 1.f) * 3.f);
			O.Pos = P3(E->Pos + FVector2D(0.6f, 0.4f), 0.8f);
			O.Vel = FVector(FMath::FRandRange(-2, 2), FMath::FRandRange(-2, 2), FMath::FRandRange(3, 5)) * 100.0;
			OrbsList.Add(O);
		}
		if (E->bQuest)
		{
			if (Q.Kind == EDSQuestKind::Kill) QKills++;
			if (E->bElite) bQEliteDead = true;
			if (E->bBoss)
			{
				bQBossDead = true;
				ShowBanner(FString::Printf(TEXT("%s  DEFEATED"), DSData::Enemy(E->Type).Name), 4.f);
			}
		}
	}
	Burst(E->Pos, E->bBoss ? 24 : 14, FLinearColor(0.95f, 0.76f, 0.35f), 8.f, 1.f);
	if (E->bBoss)
	{
		BossFreeNodes(*E);
		// a dead Titan takes its fists with it
		for (const FDSEnemyPtr& O : TArray<FDSEnemyPtr>(Enemies))
			if (O->Link.Pin() == E) KillEnemy(O, false);
	}
	if (E->Fig.IsValid())
	{
		FDSCorpse C;
		C.Fig = E->Fig;
		C.BaseZ = E->Fig->GetActorLocation().Z;
		C.bBoss = E->bBoss;
		Corpses.Add(C);
	}
}

// ================================================================== projectiles & zones

void ADSGame::Fire(const FVector2D& From, float Ang, float Dmg, float Spd, EDSProj Kind, float Homing, float Height)
{
	FDSProjectile P;
	P.Pos = From;
	P.Vel = FromAngle(Ang) * Spd;
	P.Dmg = Dmg;
	P.Life = Homing > 0.f ? 5.f : 3.f;
	P.Kind = Kind;
	P.Homing = Homing;
	P.H = Height;
	P.Team = FDSProjectile::ETeam::Enemy;
	ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(From, Height), FRotator::ZeroRotator);
	switch (Kind)
	{
	case EDSProj::Arrow: V->AddPart(EDSShape::Cube, FVector::ZeroVector, FVector(0.9, 0.05, 0.05), FLinearColor(0.5f, 0.35f, 0.2f)); break;
	case EDSProj::Magic: V->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(0.5), FLinearColor(0.7f, 0.3f, 1.f) * 4.f); break;
	case EDSProj::Fire: V->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(0.5), FLinearColor(1.f, 0.5f, 0.1f) * 4.f); break;
	case EDSProj::Orb: V->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(0.6), FLinearColor(1.f, 0.15f, 0.15f) * 4.f); break;
	case EDSProj::Venom: V->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(0.5), FLinearColor(0.3f, 1.f, 0.35f) * 4.f); break;
	case EDSProj::Missile:
		V->AddPart(EDSShape::Cube, FVector::ZeroVector, FVector(1.4, 0.3, 0.3), FLinearColor(0.5f, 0.55f, 0.6f));
		V->AddPart(EDSShape::Sphere, FVector(-0.8, 0, 0), FVector(0.35), FLinearColor(1.f, 0.6f, 0.2f) * 5.f);
		break;
	default: V->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(0.4), FLinearColor::White); break;
	}
	V->SetShadows(false);
	P.Node = V;
	Projs.Add(P);
}

void ADSGame::UpdateProjs(float Dt)
{
	for (FDSProjectile& P : Projs)
	{
		P.Life -= Dt;
		if (P.Homing > 0.f && P.Team == FDSProjectile::ETeam::Enemy)
		{
			const float Want = AngleOf(PPos - P.Pos);
			const float Cur = AngleOf(P.Vel);
			const float Turn = FMath::Clamp(AngleDiff(Cur, Want), -P.Homing * Dt, P.Homing * Dt);
			P.Vel = FromAngle(Cur + Turn) * P.Vel.Size();
		}
		P.Pos += P.Vel * Dt;
		if (P.Team == FDSProjectile::ETeam::Enemy)
		{
			if (FVector2D::Distance(P.Pos, PPos) < PR + 0.5f && PInv <= 0.f && State == EDSState::Play)
			{
				HurtPlayer(P.Dmg, P.Pos - P.Vel.GetSafeNormal() * 0.5f);
				P.Life = 0.f;
				Burst(P.Pos, 5, FLinearColor(1.f, 0.75f, 0.5f), 5.f);
			}
		}
		else if (P.Team == FDSProjectile::ETeam::Player)
		{
			for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
			{
				if (E->bDead) continue;
				if (FVector2D::Distance(P.Pos, E->Pos) < E->R + 0.35f)
				{
					HurtEnemy(E, P.Dmg, AngleOf(P.Vel), false);
					Burst(P.Pos, 4, FLinearColor(1.f, 0.82f, 0.44f), 5.f, 1.3f);
					P.Life = 0.f;
					break;
				}
			}
		}
		if (FVector2D::Distance(P.Pos, PPos) > 80.f) P.Life = 0.f;
	}
	for (FDSProjectile& P : Projs)
		if (P.Life <= 0.f && P.Node.IsValid()) P.Node->Destroy();
	Projs.RemoveAll([](const FDSProjectile& P) { return P.Life <= 0.f; });
}

void ADSGame::AddZone(const FVector2D& Pos, float R, float Delay, float Dmg, bool bPlayer, bool bBoom, TWeakPtr<FDSEnemy> Fist)
{
	FDSZone Z;
	Z.Pos = Pos;
	Z.R = R;
	Z.Delay = FMath::Max(Delay, 0.05f);
	Z.Dmg = Dmg;
	Z.bPlayer = bPlayer;
	Z.bBoom = bBoom;
	Z.Fist = Fist;
	ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(Pos, 0.12f), FRotator::ZeroRotator);
	const FLinearColor Col = bBoom ? FLinearColor(1.f, 0.45f, 0.1f) : (bPlayer ? FLinearColor(0.3f, 0.5f, 1.f) : FLinearColor(1.f, 0.15f, 0.08f));
	V->AddPart(EDSShape::Cylinder, FVector::ZeroVector, FVector(R * 2.f, R * 2.f, 0.04), Col * 1.5f);
	V->SetShadows(false);
	Z.Node = V;
	Zones.Add(Z);
}

void ADSGame::UpdateZones(float Dt)
{
	for (FDSZone& Z : Zones)
	{
		Z.T += Dt;
		const float K = FMath::Clamp(Z.T / Z.Delay, 0.f, 1.f);
		if (Z.Node.IsValid()) Z.Node->SetActorScale3D(FVector(0.4f + 0.6f * K, 0.4f + 0.6f * K, 1.f));
		if (Z.T < Z.Delay) continue;
		Z.bDone = true;
		if (Z.Node.IsValid()) Z.Node->Destroy();
		if (FDSEnemyPtr Fist = Z.Fist.Pin())
		{
			if (!Fist->bDead) SpawnFist(Fist, Z.Pos);
			continue;
		}
		if (Z.bBoom)
		{
			Burst(Z.Pos, 24, FLinearColor(1.f, 0.6f, 0.19f), 13.f, 1.f);
			Ring(Z.Pos, FLinearColor(1.f, 0.6f, 0.19f), Z.R * 2.4f, 0.5f);
			Shake = FMath::Max(Shake, 15.f);
		}
		else
		{
			Strike(Z.Pos);
			Shake = FMath::Max(Shake, 7.f);
		}
		if (!Z.bPlayer)
		{
			if (FVector2D::Distance(PPos, Z.Pos) < Z.R + PR) HurtPlayer(Z.Dmg, Z.Pos, true);
		}
		else
		{
			for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
				if (!E->bDead && FVector2D::Distance(E->Pos, Z.Pos) < Z.R + E->R)
					HurtEnemy(E, Z.Dmg, AngleOf(E->Pos - Z.Pos), false);
		}
	}
	Zones.RemoveAll([](const FDSZone& Z) { return Z.bDone; });
}
