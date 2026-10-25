// Player: stats, movement, combat, skills. Port of the player half of game.gd (_update, _try_attack, _melee_hit, skills, _hurt_player).
#include "DSGame.h"
#include "DSVisual.h"

// ================================================================== stats & gear

void ADSGame::Recalc()
{
	const FDSArmorDef& A = DSData::Armor(Armor);
	PMaxHp = 100.f + 12.f * Lv[1] + (float)A.Hp;
	PMaxSt = 100.f + 8.f * Lv[2] + (float)A.St;
	PHp = FMath::Min(PHp, PMaxHp);
	PSt = FMath::Min(PSt, PMaxSt);
}

int32 ADSGame::TotalLevel() const
{
	int32 N = 1;
	for (int32 L : Lv) N += L;
	for (int32 W : WTier) N += W;
	for (int32 W = 0; W < 4; W++)
		for (int32 S = 0; S < 2; S++)
			N += Skills[W][S].Level + (Skills[W][S].bUnlocked ? 1 : 0);
	return N;
}

float ADSGame::WeaponDmg() const
{
	return (DSData::Weapon(Equipped).Dmg[FMath::Clamp(WTier[(int32)Equipped], 0, 4)] + 3.f * Lv[0]) * (PRage > 0.f ? 1.5f : 1.f);
}

float ADSGame::MoveMult() const
{
	return (1.f + 0.03f * Lv[4] + DSData::Armor(Armor).Mob) * (PRage > 0.f ? 1.12f : 1.f);
}

float ADSGame::DefenseMult() const
{
	return FMath::Max(0.35f, 1.f - 0.04f * Lv[3] - DSData::Armor(Armor).Def);
}

float ADSGame::SkillCdMax(int32 Slot) const
{
	return FMath::Max(3.f, DSData::Skill(Equipped, Slot).Cd - 0.6f * Skills[(int32)Equipped][Slot].Level);
}

float ADSGame::SkillCdFrac(int32 Slot) const
{
	return Cds[(int32)Equipped][Slot] / SkillCdMax(Slot);
}

bool ADSGame::SkillReady(int32 Slot) const
{
	const FDSSkillDef& D = DSData::Skill(Equipped, Slot);
	const int32 W = (int32)Equipped;
	if (!Skills[W][Slot].bUnlocked || Cds[W][Slot] > 0.f || PSt < D.St) return false;
	return D.Ammo == 0 || bUnlimitedAmmo || Ammo >= D.Ammo;
}

void ADSGame::EquipWeapon(EDSWeapon W)
{
	if (!WeaponsOwned[(int32)W]) return;
	Equipped = W;
	ShowBanner(FString(DSData::Weapon(W).Names[WTier[(int32)W]]).ToUpper(), 1.4f);
}

void ADSGame::CycleWeapon()
{
	if (State != EDSState::Play || IsFrozen() || !CanCycle()) return;
	if (PAct != EDSAct::Idle && PAct != EDSAct::Block) return;
	int32 Cur = (int32)Equipped;
	for (int32 i = 1; i <= 4; i++)
	{
		const int32 N = (Cur + i) % 4;
		if (WeaponsOwned[N]) { EquipWeapon((EDSWeapon)N); break; }
	}
}

void ADSGame::EquipArmor(EDSArmor A)
{
	if (!ArmorsOwned[(int32)A]) return;
	Armor = A;
	Recalc();
}

// ================================================================== update

void ADSGame::UpdatePlayer(float Dt)
{
	for (int32 W = 0; W < 4; W++)
		for (int32 S = 0; S < 2; S++)
			Cds[W][S] = FMath::Max(0.f, Cds[W][S] - Dt);
	if (PRage > 0.f)
	{
		PRage = FMath::Max(0.f, PRage - Dt);
		if (FMath::FRand() < 0.5f) Burst(PPos, 1, FLinearColor(1.f, 0.2f, 0.12f), 3.f, 0.4f + FMath::FRand() * 1.6f);
	}
	PGunCd = FMath::Max(0.f, PGunCd - Dt);
	PStone = FMath::Max(0.f, PStone - Dt);
	if (PAct != EDSAct::Attack) PComboWin = FMath::Max(0.f, PComboWin - Dt);
	PHitT = FMath::Max(0.f, PHitT - Dt);
	PShieldHit = FMath::Max(0.f, PShieldHit - Dt);
	PBlock = FMath::FInterpConstantTo(PBlock, PAct == EDSAct::Block ? 1.f : 0.f, Dt, 9.f);
	PBlockT = PAct == EDSAct::Block ? PBlockT + Dt : 0.f;

	// --- input ---
	FVector2D Iv = MoveInput;
	if (Iv.Size() > 1.0) Iv = Iv.GetSafeNormal();
	const float Il = Iv.Size();
	const bool bWantBlock = bBlockHeld;

	const bool bNearSword = bSwordOnGround && FVector2D::Distance(PPos, SwordPos) < 2.6f;
	const bool bNearChest = ChestActor.IsValid() && ChestT < 0.f && FVector2D::Distance(PPos, ChestPos) < 2.6f;
	bChestPrompt = bNearChest;

	// --- player ---
	PFlash = FMath::Max(0.f, PFlash - Dt);
	PInv = FMath::Max(0.f, PInv - Dt);
	PSinceHit += Dt;
	if (Lv[5] > 0 && PSinceHit > 4.f && PHp < PMaxHp) PHp = FMath::Min(PMaxHp, PHp + 0.5f * Lv[5] * Dt);
	if (PStDelay > 0.f) PStDelay -= Dt;
	else PSt = FMath::Min(PMaxSt, PSt + (PAct == EDSAct::Block ? 12.f : 34.f) * Dt);
	if (HpTrail > PHp) HpTrail = FMath::Max(PHp, HpTrail - 28.f * Dt);
	else HpTrail = PHp;

	if (PStun > 0.f)
	{
		PStun -= Dt;
	}
	else
	{
		const bool bChainReady = PAct == EDSAct::Attack && bPHitDone && PActT > PAtk.Time * 0.7f && BufAtk > 0.f;
		const bool bFree = PAct == EDSAct::Idle || PAct == EDSAct::Block || (PAct == EDSAct::Shoot && PActT > 0.15f) || bChainReady;
		if (bFree && PAct == EDSAct::Shoot) PAct = EDSAct::Idle;
		if (bFree && bWantBlock && PSt > 0.f && !bChainReady) PAct = EDSAct::Block;
		else if (PAct == EDSAct::Block) PAct = EDSAct::Idle;

		if (bFree && BufEstus > 0.f && Flasks > 0 && PHp < PMaxHp)
		{
			BufEstus = 0.f;
			Flasks--;
			PAct = EDSAct::Drink;
			PActT = 0.f;
		}
		else if (bFree && BufRoll > 0.f && PSt >= 20.f)
		{
			BufRoll = 0.f;
			PSt -= 22.f;
			PStDelay = 0.7f;
			PAct = EDSAct::Roll;
			PActT = 0.f;
			PInv = 0.32f + 0.01f * Lv[4];
			PRollDir = Il > 0.1f ? AngleOf(Iv) : PFace;
		}
		else if (bFree && BufSk1 > 0.f && bHasWeapon && SkillReady(0)) { BufSk1 = 0.f; UseSkill(0); }
		else if (bFree && BufSk2 > 0.f && bHasWeapon && SkillReady(1)) { BufSk2 = 0.f; UseSkill(1); }
		else if (bFree && BufAtk > 0.f)
		{
			BufAtk = 0.f;
			if (!bHasWeapon)
			{
				if (bNearSword)
				{
					bHasWeapon = true;
					bSwordOnGround = false;
					if (SwordPickup.IsValid()) SwordPickup->Destroy();
					ShowBanner(TEXT("ASHEN LONGSWORD"), 2.f, TEXT("Left stick moves, ATTACK strikes, ROLL dodges"));
				}
			}
			else if (bNearChest)
			{
				ChestT = 0.f;   // PostQuest animates the lid and hands out the treasure
			}
			else
			{
				TryAttack(Iv, Il);
			}
		}
	}

	float Spd = 0.f;
	FVector2D Mv = FVector2D::ZeroVector;
	const float Sp = 8.75f * MoveMult();
	if (PStun <= 0.f)
	{
		switch (PAct)
		{
		case EDSAct::Idle:
			Spd = Sp; Mv = Iv;
			if (Il > 0.1f) PFace = AngleOf(Iv);
			break;
		case EDSAct::Block:
			Spd = 4.f * MoveMult(); Mv = Iv;
			if (Il > 0.1f) PFace = AngleOf(Iv);
			break;
		case EDSAct::Shoot:
			PActT += Dt; Spd = 4.5f; Mv = Iv;
			if (PActT > 0.3f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Roll:
			PActT += Dt;
			Spd = 20.f * (1.f + 0.04f * Lv[4]) * (1.f - PActT / 0.5f);
			Mv = FromAngle(PRollDir);
			PFace = PRollDir;
			if (PActT >= 0.45f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Attack:
		{
			PActT += Dt;
			Spd = PActT < PAtk.HitT + 0.08f ? PAtk.Lunge : 1.f;
			Mv = FromAngle(PFace);
			if (PHitI < PAtk.Hits.Num() && PActT > PAtk.Hits[PHitI])
			{
				PHitI++;
				if (PHitI >= PAtk.Hits.Num()) bPHitDone = true;
				MeleeHit();
			}
			if (PActT > PAtk.Time) { PAct = EDSAct::Idle; PComboWin = 0.55f; }
			break;
		}
		case EDSAct::Spin:
			PActT += Dt; Spd = 2.f; Mv = Iv;
			if (!bPHitDone && PActT > 0.2f) { bPHitDone = true; SpinHit(); }
			if (!bPHit2 && PActT > 0.45f) { bPHit2 = true; SpinHit(); }
			if (PActT > 0.75f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Cast:
			PActT += Dt; Spd = 0.f;
			if (!bPHitDone && PActT > 0.25f)
			{
				bPHitDone = true;
				FVector2D Tgt = PPos + FromAngle(PFace) * 6.f;
				float Bd = 14.f;
				for (const FDSEnemyPtr& E : Enemies)
				{
					if (E->bDead || E->Type == EDSEnemy::Fist) continue;
					const float D2 = FVector2D::Distance(PPos, E->Pos);
					const float Lim = E->Type != EDSEnemy::Cyborg ? 14.f : 60.f;
					if (D2 < Lim && D2 < Bd + (E->Type == EDSEnemy::Cyborg ? 50.f : 0.f)) { Bd = D2; Tgt = E->Pos; }
				}
				AddZone(Tgt, 3.6f, 0.45f, WeaponDmg() * (2.4f + 0.4f * PSkl), true);
			}
			if (PActT > 0.6f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Quake:
			PActT += Dt; Spd = 0.f;
			if (!bPHitDone && PActT > 0.55f) { bPHitDone = true; QuakeHit(); }
			if (PActT > 1.f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Rage:
			PActT += Dt; Spd = 0.f;
			if (!bPHitDone && PActT > 0.3f)
			{
				bPHitDone = true;
				PRage = 7.f + (float)PSkl;
				Ring(PPos, FLinearColor(1.f, 0.2f, 0.12f), 9.f, 0.8f);
				Burst(PPos, 24, FLinearColor(1.f, 0.2f, 0.12f), 9.f, 1.f);
				Shake = FMath::Max(Shake, 14.f);
				Float(P3(PPos, 2.8f), TEXT("BLOOD RAGE"), FLinearColor(1.f, 0.42f, 0.35f));
			}
			if (PActT > 0.75f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Dash:
			PActT += Dt;
			Spd = PActT < 0.34f ? 30.f : 1.f;
			Mv = FromAngle(PFace);
			if (PActT < 0.34f)
			{
				DashHit();
				if (FMath::FRand() < 0.6f) Burst(PPos, 2, FLinearColor(0.9f, 0.86f, 0.75f), 4.f, 0.3f);
			}
			if (PActT > 0.6f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Flurry:
		{
			PActT += Dt; Spd = 1.5f;
			const int32 Fi = (int32)(PActT / 0.13f);
			if (Fi > PHitI && Fi <= 7) { PHitI = Fi; FlurryHit(); }
			if (PActT > 1.05f) PAct = EDSAct::Idle;
			break;
		}
		case EDSAct::Fan:
		{
			PActT += Dt; Spd = 2.5f; Mv = Iv;
			const int32 Gi = (int32)(PActT / 0.1f);
			if (Gi > PHitI && Gi <= 6)
			{
				PHitI = Gi;
				FireBullet(PFace + FMath::Lerp(-0.42f, 0.42f, (float)(Gi - 1) / 5.f), 0.7f + 0.08f * PSkl);
				Shake = FMath::Max(Shake, 3.f);
				Burst(PPos + FromAngle(PFace) * 1.f, 2, FLinearColor(1.f, 0.82f, 0.44f), 4.f, 1.4f);
			}
			if (PActT > 0.85f) PAct = EDSAct::Idle;
			break;
		}
		case EDSAct::Blast:
			PActT += Dt; Spd = 0.f;
			if (!bPHitDone && PActT > 0.3f) { bPHitDone = true; FireShell(); }
			if (PActT > 0.65f) PAct = EDSAct::Idle;
			break;
		case EDSAct::Drink:
			PActT += Dt; Spd = 2.f; Mv = Iv;
			if (PActT > 0.9f)
			{
				const float Heal = 55.f + 6.f * Lv[6];
				PHp = FMath::Min(PMaxHp, PHp + Heal);
				Burst(PPos, 12, FLinearColor(1.f, 0.7f, 0.28f), 5.f, 1.f);
				Float(P3(PPos, 2.4f), FString::Printf(TEXT("+%d"), (int32)Heal), FLinearColor(1.f, 0.7f, 0.28f));
				PAct = EDSAct::Idle;
			}
			break;
		default: break;
		}
	}
	const FVector2D Before = PPos;
	PPos = Contain(Slide(PPos, Mv * Spd * Dt));
	const float Moved = FVector2D::Distance(PPos, Before) / FMath::Max(Dt, 0.0001f);
	PMoveSpeed = ((PAct == EDSAct::Idle || PAct == EDSAct::Block || PAct == EDSAct::Shoot) && PStun <= 0.f) ? Moved : 0.f;

	// --- enemies ---
	for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
		UpdateEnemy(*E, Dt);
	for (const FDSEnemyPtr& E : Enemies)
	{
		if (E->bDead || E->bStatic || (E->Mode == EDSMode::Idle && !E->bForce)) continue;
		for (const FDSEnemyPtr& O : Enemies)
		{
			if (O == E || O->bDead || O->bStatic) continue;
			const FVector2D Off = E->Pos - O->Pos;
			const float Od = Off.Size();
			const float M = E->R + O->R;
			if (Od > 0.f && Od < M) E->Pos += Off / Od * (M - Od) * 0.5f;
		}
		const FVector2D Body = PPos - E->Pos;
		const float Bl = Body.Size();
		const float Mm = E->R + PR;
		if (Bl > 0.f && Bl < Mm && PAct != EDSAct::Roll) PPos = Contain(Slide(PPos, Body / Bl * (Mm - Bl)));
	}
	Enemies.RemoveAll([](const FDSEnemyPtr& E) { return E->bDead; });

	UpdateProjs(Dt);
	UpdateZones(Dt);
	UpdateWayside();
	QuestUpdate(Dt);
}

// ================================================================== attacks

void ADSGame::TryAttack(const FVector2D& Iv, float Il)
{
	const FDSWeaponDef& W = DSData::Weapon(Equipped);
	if (W.Style == EDSStyle::Shoot)
	{
		if (PGunCd > 0.f) return;
		if (Ammo <= 0 && !bUnlimitedAmmo)
		{
			Float(P3(PPos, 2.4f), TEXT("OUT OF AMMO"), FLinearColor(1.f, 0.54f, 0.42f));
			PGunCd = 0.4f;
			return;
		}
		FDSEnemyPtr Best;
		float Bd = 1e9f;
		for (const FDSEnemyPtr& E : Enemies)
		{
			if (E->bDead || (E->Mode == EDSMode::Idle && !E->bForce)) continue;
			const float D = FVector2D::Distance(PPos, E->Pos);
			if (D > W.Range || E->Type == EDSEnemy::Fist) continue;
			const float Away = FMath::Abs(AngleDiff(AngleOf(E->Pos - PPos), Il > 0.1f ? AngleOf(Iv) : PFace));
			const float Score = D + Away * 6.f;
			if (Score < Bd) { Bd = Score; Best = E; }
		}
		if (Best.IsValid()) PFace = AngleOf(Best->Pos - PPos);
		else if (Il > 0.1f) PFace = AngleOf(Iv);
		if (!bUnlimitedAmmo) Ammo--;
		PGunCd = W.Time;
		FireBullet(PFace);
		PAct = EDSAct::Shoot;
		PActT = 0.f;
		Shake = FMath::Max(Shake, 2.5f);
		Burst(PPos + FromAngle(PFace) * 1.f, 3, FLinearColor(1.f, 0.82f, 0.44f), 4.f, 1.4f);
		return;
	}
	// pick the next strike of this weapon's chain (resets if you wait too long)
	const TArrayView<const FDSComboStep> Chain = DSData::Combo(Equipped);
	int32 Nxt = 0;
	if (Chain.Num() > 0 && PComboWin > 0.f) Nxt = (PCombo + 1) % Chain.Num();
	const FDSComboStep Var = Chain.Num() > 0 ? Chain[Nxt] : FDSComboStep{ TEXT("slash_r"), 1.f, 1.f, 1.f, 1.f, 1.f, W.Time, W.HitT, 1.f };
	const float Cost = W.Stam * Var.Stam;
	if (PSt < Cost) return;
	PSt -= Cost;
	PStDelay = 0.7f;
	PCombo = Nxt;
	PComboWin = 1.f;     // stays open while swinging; shrinks once the swing is over
	PAtk.Anim = Var.Anim;
	PAtk.Dmg = Var.Dmg;
	PAtk.Range = W.Range * Var.Range;
	PAtk.Arc = W.Arc * Var.Arc;
	PAtk.Time = Var.Time;
	PAtk.HitT = Var.HitT;
	PAtk.Lunge = W.Lunge * Var.Lunge;
	PAtk.Kb = Var.Kb;
	PAtk.bSlam = Var.bSlam;
	PAtk.Hits.Reset();
	if (Var.NumHits > 1) { for (int32 i = 0; i < Var.NumHits; i++) PAtk.Hits.Add(Var.Hits[i]); }
	else PAtk.Hits.Add(Var.HitT);
	PAct = EDSAct::Attack;
	PActT = 0.f;
	bPHitDone = false;
	PHitI = 0;

	FDSEnemyPtr Best;
	float Bd = W.Range + 3.f;
	for (const FDSEnemyPtr& E : Enemies)
	{
		if (E->bDead || (E->Mode == EDSMode::Idle && !E->bForce)) continue;
		const float D = FVector2D::Distance(PPos, E->Pos) - E->R;
		if (D < Bd) { Bd = D; Best = E; }
	}
	if (Best.IsValid()) PFace = AngleOf(Best->Pos - PPos);
	else if (Il > 0.1f) PFace = AngleOf(Iv);
}

void ADSGame::MeleeHit()
{
	const FAtk A = PAtk;
	for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
	{
		if (E->bDead) continue;
		const FVector2D Off = E->Pos - PPos;
		if (Off.Size() < A.Range + E->R && FMath::Abs(AngleDiff(AngleOf(Off), PFace)) < A.Arc)
		{
			float Dmg = WeaponDmg() * A.Dmg;
			bool bBlocked = false;
			if (DSData::Enemy(E->Type).bShield && FMath::Abs(AngleDiff(AngleOf(PPos - E->Pos), E->Face)) < 1.1f)
			{
				Dmg *= 0.3f;
				bBlocked = true;
			}
			HurtEnemy(E, Dmg, AngleOf(Off), bBlocked, A.Kb);
		}
	}
	if (A.bSlam)
	{
		// the cleaver cracks the ground in front of you
		const FVector2D Impact = PPos + FromAngle(PFace) * 3.2f;
		Shake = FMath::Max(Shake, 11.f * A.Kb * 0.6f + 4.f);
		Burst(Impact, 20, FLinearColor(1.f, 0.48f, 0.19f), 10.f, 0.4f);
		for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
			if (!E->bDead && FVector2D::Distance(E->Pos, Impact) < 3.2f + E->R && FMath::Abs(AngleDiff(AngleOf(E->Pos - PPos), PFace)) >= A.Arc)
				HurtEnemy(E, WeaponDmg() * A.Dmg * 0.6f, AngleOf(E->Pos - Impact), false);
	}
	else if (A.Kb >= 2.f)
	{
		Shake = FMath::Max(Shake, 7.f);
	}
}

void ADSGame::SkillAim(float Rng)
{
	FDSEnemyPtr Best;
	float Bd = 1e9f;
	for (const FDSEnemyPtr& E : Enemies)
	{
		if (E->bDead || E->Type == EDSEnemy::Fist || (E->Mode == EDSMode::Idle && !E->bForce)) continue;
		const float D = FVector2D::Distance(PPos, E->Pos);
		if (D > Rng) continue;
		const float Away = FMath::Abs(AngleDiff(AngleOf(E->Pos - PPos), PFace));
		const float Score = D + Away * 6.f;
		if (Score < Bd) { Bd = Score; Best = E; }
	}
	if (Best.IsValid()) PFace = AngleOf(Best->Pos - PPos);
}

void ADSGame::UseSkill(int32 Slot)
{
	const FDSSkillDef& D = DSData::Skill(Equipped, Slot);
	const int32 W = (int32)Equipped;
	PSt -= D.St;
	PStDelay = 0.7f;
	Cds[W][Slot] = SkillCdMax(Slot);
	if (D.Ammo > 0 && !bUnlimitedAmmo) Ammo -= D.Ammo;
	PSkl = Skills[W][Slot].Level;
	PAct = D.Act;
	PActT = 0.f;
	bPHitDone = false;
	bPHit2 = false;
	PHitI = 0;
	PHitList.Reset();
	switch (PAct)
	{
	case EDSAct::Spin: PInv = 0.35f; break;
	case EDSAct::Quake: SkillAim(6.f); PInv = 0.8f; break;
	case EDSAct::Rage: PInv = 0.3f; break;
	case EDSAct::Dash: SkillAim(9.f); PInv = 0.6f; break;
	case EDSAct::Flurry: SkillAim(6.f); PInv = 0.2f; break;
	case EDSAct::Fan: SkillAim(DSData::Weapon(Equipped).Range); PGunCd = 0.8f; break;
	case EDSAct::Blast: SkillAim(DSData::Weapon(Equipped).Range); PGunCd = 0.6f; break;
	default: break;
	}
}

void ADSGame::QuakeHit()
{
	Shake = FMath::Max(Shake, 24.f);
	Ring(PPos, FLinearColor(1.f, 0.48f, 0.19f), 11.f, 0.7f);
	Burst(PPos, 24, FLinearColor(1.f, 0.48f, 0.19f), 12.f, 0.3f);
	Burst(PPos, 12, FLinearColor(0.54f, 0.42f, 0.29f), 9.f, 0.4f);
	const float Dmg = WeaponDmg() * (1.6f + 0.25f * PSkl);
	for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
	{
		if (E->bDead) continue;
		const FVector2D Off = E->Pos - PPos;
		if (Off.Size() < 5.8f + E->R) HurtEnemy(E, Dmg, AngleOf(Off), false, 2.f);
	}
}

void ADSGame::DashHit()
{
	const float Dmg = WeaponDmg() * (1.4f + 0.2f * PSkl);
	for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
	{
		if (E->bDead || PHitList.Contains(E->Uid)) continue;
		const FVector2D Off = E->Pos - PPos;
		if (Off.Size() < 2.f + E->R && FMath::Abs(AngleDiff(AngleOf(Off), PFace)) < 1.3f)
		{
			PHitList.Add(E->Uid);
			HurtEnemy(E, Dmg, AngleOf(Off), false, 2.5f);
			Burst(E->Pos, 8, FLinearColor(0.9f, 0.86f, 0.75f), 7.f, 1.2f);
			Shake = FMath::Max(Shake, 10.f);
		}
	}
}

void ADSGame::FlurryHit()
{
	SkillAim(6.f);
	const float Dmg = WeaponDmg() * (0.5f + 0.08f * PSkl);
	for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
	{
		if (E->bDead) continue;
		const FVector2D Off = E->Pos - PPos;
		if (Off.Size() < 4.2f + E->R && FMath::Abs(AngleDiff(AngleOf(Off), PFace)) < 0.6f)
		{
			HurtEnemy(E, Dmg, AngleOf(Off), false, 0.4f);
			Burst(E->Pos, 3, FLinearColor(1.f, 0.91f, 0.69f), 5.f, 1.3f);
		}
	}
	Shake = FMath::Max(Shake, 3.f);
}

void ADSGame::SpinHit()
{
	Shake = FMath::Max(Shake, 6.f);
	Burst(PPos, 12, FLinearColor(0.87f, 0.9f, 1.f), 9.f, 1.f);
	for (FDSEnemyPtr E : TArray<FDSEnemyPtr>(Enemies))
	{
		const FVector2D Off = E->Pos - PPos;
		if (!E->bDead && Off.Size() < 4.8f + E->R) HurtEnemy(E, WeaponDmg() * (0.85f + 0.2f * PSkl), AngleOf(Off), false);
	}
}

void ADSGame::FireShell()
{
	FVector2D Tgt = PPos + FromAngle(PFace) * 10.f;
	float Bd = 16.f;
	for (const FDSEnemyPtr& E : Enemies)
	{
		if (E->bDead || E->Type == EDSEnemy::Fist || (E->Mode == EDSMode::Idle && !E->bForce)) continue;
		const float D = FVector2D::Distance(PPos, E->Pos);
		if (D < Bd && FMath::Abs(AngleDiff(AngleOf(E->Pos - PPos), PFace)) < 0.5f) { Bd = D; Tgt = E->Pos; }
	}
	const float Travel = FMath::Max(FVector2D::Distance(PPos, Tgt) / 38.f, 0.12f);
	const FVector2D From = PPos + FromAngle(PFace) * 0.9f;
	FDSProjectile P;
	P.Pos = From;
	P.Vel = (Tgt - From).GetSafeNormal() * 38.f;
	P.Dmg = 0.f;
	P.Life = Travel;
	P.Kind = EDSProj::Fire;
	P.Team = FDSProjectile::ETeam::None;
	P.H = 1.35f;
	ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(From, 1.35f), FRotator::ZeroRotator);
	V->AddPart(EDSShape::Sphere, FVector::ZeroVector, FVector(0.5), FLinearColor(1.f, 0.6f, 0.15f) * 4.f);
	V->SetShadows(false);
	P.Node = V;
	Projs.Add(P);
	AddZone(Tgt, 3.8f, Travel, WeaponDmg() * (2.6f + 0.4f * PSkl), true, true);
	Shake = FMath::Max(Shake, 9.f);
	Burst(From, 6, FLinearColor(1.f, 0.82f, 0.44f), 5.f, 1.4f);
}

void ADSGame::FireBullet(float Ang, float Mult)
{
	const FVector2D From = PPos + FromAngle(Ang) * 0.9f;
	FDSProjectile P;
	P.Pos = From;
	P.Vel = FromAngle(Ang) * 44.f;
	P.Dmg = WeaponDmg() * Mult;
	P.Life = 0.75f;
	P.Kind = EDSProj::Bullet;
	P.Team = FDSProjectile::ETeam::Player;
	P.H = 1.35f;
	ADSVisual* V = GetWorld()->SpawnActor<ADSVisual>(P3(From, 1.35f), FRotator::ZeroRotator);
	V->AddPart(EDSShape::Cube, FVector::ZeroVector, FVector(0.7, 0.07, 0.07), FLinearColor(1.f, 0.85f, 0.4f) * 4.f);
	V->SetShadows(false);
	P.Node = V;
	Projs.Add(P);
}

// ================================================================== damage taken

void ADSGame::PetrifyPlayer(float Secs, float Dmg)
{
	if (PInv > 0.f || PAct == EDSAct::Roll || State != EDSState::Play)
	{
		Float(P3(PPos, 2.4f), TEXT("DODGED"), FLinearColor(0.63f, 1.f, 0.72f));
		return;
	}
	if (PAct == EDSAct::Block && PSt > 0.f)
	{
		Float(P3(PPos, 2.4f), TEXT("SHIELDED"), FLinearColor(0.63f, 1.f, 0.72f));
		PSt = FMath::Max(0.f, PSt - 30.f);
		return;
	}
	PStun = FMath::Max(PStun, Secs);
	PStone = Secs;
	PAct = EDSAct::Idle;
	Float(P3(PPos, 2.6f), TEXT("PETRIFIED!"), FLinearColor(0.82f, 0.82f, 0.78f));
	HurtPlayer(Dmg, PPos + FVector2D(1, 0), true);
}

void ADSGame::HurtPlayer(float Dmg, const FVector2D& Src, bool bUnblockable)
{
	if (PInv > 0.f || PAct == EDSAct::Dead || State != EDSState::Play) return;
	Dmg *= DefenseMult();
	const float ToSrc = AngleOf(Src - PPos);
	const float Side = FMath::Sign(AngleDiff(PFace, ToSrc));
	if (!bUnblockable && PAct == EDSAct::Block && FMath::Abs(AngleDiff(ToSrc, PFace)) < 1.3f && PSt > 0.f)
	{
		// a raised shield takes the whole blow: no health lost, stamina pays for it
		const bool bParry = PBlockT < 0.2f;
		PStDelay = 1.f;
		PShieldHit = 0.3f;
		PHitDir = Side;
		Burst(PPos + FromAngle(PFace) * 1.f, bParry ? 10 : 7, bParry ? FLinearColor(1.f, 0.94f, 0.75f) : FLinearColor(1.f, 0.85f, 0.63f), 8.f, 1.3f);
		Shake = FMath::Max(Shake, bParry ? 3.f : 4.f);
		PInv = 0.12f;
		if (bParry)
		{
			PSt = FMath::Min(PMaxSt, PSt + 8.f);
			Float(P3(PPos, 2.5f), TEXT("PARRY"), FLinearColor(1.f, 0.94f, 0.63f));
			for (const FDSEnemyPtr& E : Enemies)
				if (!E->bDead && !E->bBoss && E->Type != EDSEnemy::Brute && FVector2D::Distance(E->Pos, Src) < 1.2f)
				{
					E->St = EDSEState::Stagger;
					E->T = 0.f;
					E->Kb = FromAngle(-ToSrc) * 7.f;
				}
		}
		else
		{
			PSt -= Dmg * 0.9f;
			Float(P3(PPos, 2.5f), TEXT("BLOCKED"), FLinearColor(0.79f, 0.91f, 1.f));
		}
		if (PSt <= 0.f)
		{
			PSt = 0.f;
			PStun = 0.9f;
			PAct = EDSAct::Idle;
			Burst(PPos, 12, FLinearColor::White, 9.f);
			Float(P3(PPos, 2.9f), TEXT("GUARD BROKEN"), FLinearColor(1.f, 0.85f, 0.63f));
		}
		return;
	}
	if (PAct == EDSAct::Attack || PAct == EDSAct::Drink || PAct == EDSAct::Cast || PAct == EDSAct::Shoot ||
		PAct == EDSAct::Flurry || PAct == EDSAct::Fan || PAct == EDSAct::Blast)
		PAct = EDSAct::Idle;
	PStun = FMath::Max(PStun, 0.12f);
	PHitT = 0.4f;
	PHitDir = Side;
	Shake = FMath::Max(Shake, 9.f);
	Blood(PPos, ToSrc + PI, 14);
	PHp -= Dmg;
	PFlash = 0.2f;
	PSinceHit = 0.f;
	Float(P3(PPos, 2.2f), FString::FromInt((int32)FMath::CeilToInt(Dmg)), FLinearColor(1.f, 0.42f, 0.35f));
	if (PHp <= 0.f)
	{
		PHp = 0.f;
		State = EDSState::Dead;
		PAct = EDSAct::Dead;
		EndTimer = 0.f;
		LostSouls = Souls / 4;
		MoveInput = FVector2D::ZeroVector;
	}
}

void ADSGame::SetRage(bool bOn)
{
	PRage = bOn ? 7.f : 0.f;
}
