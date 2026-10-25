#include "DSHUD.h"
#include "DSGame.h"
#include "DSPlayerController.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Kismet/GameplayStatics.h"

namespace
{
	const FLinearColor Bone(0.85f, 0.81f, 0.72f), Ember(0.91f, 0.54f, 0.17f), Gold(0.54f, 0.48f, 0.33f), Ink(0.02f, 0.018f, 0.015f, 0.92f);
}

void ADSHUD::Txt(const FString& Str, float X, float Y, float Scale, const FLinearColor& C, int32 Align)
{
	float W = 0.f, H = 0.f;
	GetTextSize(Str, W, H, Font, Scale);
	if (Align == 1) X -= W * 0.5f; else if (Align == 2) X -= W;
	DrawText(Str, FLinearColor(0, 0, 0, C.A * 0.8f), X + 1.5f * S, Y + 1.5f * S, Font, Scale);
	DrawText(Str, C, X, Y, Font, Scale);
}

void ADSHUD::Box(float X, float Y, float W, float H, const FLinearColor& Fill, const FLinearColor& Border)
{
	if (Border.A > 0.f)
	{
		const float T = FMath::Max(1.f, 2.f * S);
		DrawRect(Border, X - T, Y - T, W + 2 * T, H + 2 * T);
	}
	DrawRect(Fill, X, Y, W, H);
}

void ADSHUD::Bar(float X, float Y, float W, float H, float Frac, float Trail, const FLinearColor& Col)
{
	Box(X, Y, W, H, FLinearColor(0.f, 0.f, 0.f, 0.7f), Gold);
	if (Trail > Frac) DrawRect(FLinearColor(0.9f, 0.85f, 0.7f, 0.8f), X, Y, W * FMath::Clamp(Trail, 0.f, 1.f), H);
	DrawRect(Col, X, Y, W * FMath::Clamp(Frac, 0.f, 1.f), H);
}

void ADSHUD::Button(const FString& Id, const FString& Label, float Cx, float Cy, float W, float H, bool bEnabled, float Cooldown, bool bBig)
{
	const float X = Cx - W * 0.5f, Y = Cy - H * 0.5f;
	Box(X, Y, W, H, FLinearColor(0.04f, 0.035f, 0.03f, bEnabled ? 0.75f : 0.45f), bEnabled ? Gold : FLinearColor(0.3f, 0.28f, 0.22f, 0.6f));
	if (Cooldown > 0.f) DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.6f), X, Y + H * (1.f - Cooldown), W, H * Cooldown);
	Txt(Label, Cx, Cy - 8.f * S * (bBig ? 1.4f : 1.f), bBig ? 1.3f * S : 0.9f * S, bEnabled ? Bone : FLinearColor(Bone.R, Bone.G, Bone.B, 0.45f), 1);
	G->AddButton(Id, FBox2D(FVector2D(X, Y), FVector2D(X + W, Y + H)), bEnabled);
}

void ADSHUD::DrawHUD()
{
	Super::DrawHUD();
	if (!G) G = Cast<ADSGame>(UGameplayStatics::GetActorOfClass(this, ADSGame::StaticClass()));
	if (!G || !Canvas) return;
	VW = Canvas->SizeX;
	VH = Canvas->SizeY;
	S = VH / 720.f;
	Font = GEngine->GetMediumFont();

	if (G->State == EDSState::Title) { DrawTitle(); return; }
	DrawPlay();
	if (G->State == EDSState::Play && !G->bDialogActive && !G->bShopOpen && !G->bPaused) DrawControls();
	if (G->bDialogActive) DrawDialog();
	if (G->bShopOpen) DrawShop();
	if (G->bPaused) DrawPause();
	if (G->State == EDSState::Dead || G->State == EDSState::Win) DrawEnd();
}

// ------------------------------------------------------------------ title

void ADSHUD::DrawTitle()
{
	DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.55f), 0, 0, VW, VH);
	Txt(TEXT("DARK SOULS"), VW * 0.5f, VH * 0.2f, 5.f * S, FLinearColor(0.85f, 0.7f, 0.35f), 1);
	Txt(TEXT("The Ashen Order"), VW * 0.5f, VH * 0.2f + 90.f * S, 1.4f * S, Bone, 1);
	float Y = VH * 0.55f;
	Button(TEXT("new"), TEXT("NEW GAME"), VW * 0.5f, Y, 320.f * S, 64.f * S, true, 0.f, true);
	if (G->bHasSaveCached)
	{
		Y += 84.f * S;
		Button(TEXT("continue"), TEXT("CONTINUE"), VW * 0.5f, Y, 320.f * S, 64.f * S, true, 0.f, true);
	}
}

// ------------------------------------------------------------------ in-game HUD

void ADSHUD::DrawPlay()
{
	const float M = 24.f * S;
	Bar(M, M, 360.f * S, 18.f * S, G->PHp / G->PMaxHp, G->HpTrail / G->PMaxHp, FLinearColor(0.65f, 0.1f, 0.08f));
	Bar(M, M + 26.f * S, 280.f * S, 11.f * S, G->PSt / G->PMaxSt, 0.f, FLinearColor(0.25f, 0.6f, 0.3f));
	Txt(FString::Printf(TEXT("SOULS  %d"), G->Souls), M, M + 46.f * S, 1.0f * S, FLinearColor(0.95f, 0.82f, 0.48f));
	Txt(FString::Printf(TEXT("POTIONS  %d"), G->Flasks), M, M + 68.f * S, 0.9f * S, Ember);
	if (G->WeaponsOwned[(int32)EDSWeapon::Gun])
		Txt(G->bUnlimitedAmmo ? FString(TEXT("AMMO  INF")) : FString::Printf(TEXT("AMMO  %d"), G->Ammo), M, M + 88.f * S, 0.9f * S, FLinearColor(0.54f, 0.85f, 1.f));

	if (G->State == EDSState::Play && !G->Q.Title.IsEmpty())
	{
		Txt(FString::Printf(TEXT("QUEST %d - %s"), G->QuestN, *G->Q.Title.ToUpper()), VW * 0.5f, M, 1.0f * S, Bone, 1);
		Txt(G->QuestLine(), VW * 0.5f, M + 22.f * S, 0.9f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.75f), 1);
		if (G->AwayWarn > 1.f) Txt(TEXT("RETURN TO THE FIGHT!"), VW * 0.5f, M + 46.f * S, 1.1f * S, FLinearColor(1.f, 0.4f, 0.3f), 1);
		// objective marker: arrow pointing along the road to the quest site
		if (!G->bQArrived || G->Q.Kind == EDSQuestKind::Boss)
		{
			const FVector2D Off = G->Site - G->PPos;
			const float D = Off.Size();
			if (D > 12.f && !G->bQArrived)
			{
				const FVector2D Dir = Off.GetSafeNormal();
				const FVector2D C(VW * 0.5f, VH * 0.5f);
				const FVector2D P = C + Dir * VH * 0.32f;
				DrawLine(P.X, P.Y, P.X - Dir.X * 22.f * S + Dir.Y * 10.f * S, P.Y - Dir.Y * 22.f * S - Dir.X * 10.f * S, Ember, 3.f);
				DrawLine(P.X, P.Y, P.X - Dir.X * 22.f * S - Dir.Y * 10.f * S, P.Y - Dir.Y * 22.f * S + Dir.X * 10.f * S, Ember, 3.f);
				Txt(FString::Printf(TEXT("%d m"), (int32)D), P.X, P.Y + 12.f * S, 0.8f * S, Ember, 1);
			}
		}
	}

	// boss bar
	for (const FDSEnemyPtr& E : G->Enemies)
	{
		if (!E->bBoss || E->bDead || E->Mode != EDSMode::Alert) continue;
		const float W = FMath::Min(VW * 0.6f, 700.f * S);
		const float X = (VW - W) * 0.5f, Y = VH - 60.f * S;
		Txt(DSData::Enemy(E->Type).Name, VW * 0.5f, Y - 26.f * S, 1.1f * S, Bone, 1);
		Bar(X, Y, W, 16.f * S, E->Hp / E->MaxHp, 0.f, FLinearColor(0.6f, 0.08f, 0.08f));
		if (E->Shield > 0.f) Bar(X, Y - 8.f * S, W, 6.f * S, E->Shield / FMath::Max(E->ShieldMax, 1.f), 0.f, FLinearColor(0.2f, 0.6f, 0.95f));
		break;
	}

	for (const FDSFloater& F : G->Floaters)
	{
		FVector2D Sp;
		if (!G->WorldToScreen(F.Pos + FVector(0, 0, F.Age * 120.f), Sp)) continue;
		FLinearColor C = F.Col;
		C.A = 1.f - FMath::Clamp((F.Age - F.Life * 0.6f) / (F.Life * 0.4f), 0.f, 1.f);
		Txt(F.Text, Sp.X, Sp.Y, 1.1f * S, C, 1);
	}

	if (G->BannerT > 0.f && !G->BannerText.IsEmpty())
	{
		const float A = FMath::Clamp(G->BannerT / 0.5f, 0.f, 1.f);
		DrawRect(FLinearColor(0, 0, 0, 0.45f * A), 0, VH * 0.3f, VW, 110.f * S);
		Txt(G->BannerText, VW * 0.5f, VH * 0.3f + 20.f * S, 2.4f * S, FLinearColor(0.85f, 0.7f, 0.35f, A), 1);
		if (!G->BannerSub.IsEmpty()) Txt(G->BannerSub, VW * 0.5f, VH * 0.3f + 74.f * S, 1.0f * S, FLinearColor(Bone.R, Bone.G, Bone.B, A), 1);
	}
}

void ADSHUD::DrawControls()
{
	const float Atk = 130.f * S;
	Button(TEXT("atk"), G->ControlLabel(), VW - 130.f * S, VH - 140.f * S, Atk, Atk, true, 0.f, true);
	Button(TEXT("roll"), TEXT("ROLL"), VW - 290.f * S, VH - 90.f * S, 92.f * S, 92.f * S, G->PSt >= 20.f);
	Button(TEXT("blk"), TEXT("BLOCK"), VW - 270.f * S, VH - 215.f * S, 92.f * S, 92.f * S);
	Button(TEXT("est"), FString::Printf(TEXT("ESTUS\n%d"), G->Flasks), VW - 80.f * S, VH - 290.f * S, 84.f * S, 84.f * S, G->Flasks > 0);
	const int32 W = (int32)G->Equipped;
	for (int32 Slot = 0; Slot < 2; Slot++)
	{
		const FDSSkillDef& D = DSData::Skill(G->Equipped, Slot);
		const bool bOk = G->Skills[W][Slot].bUnlocked;
		Button(Slot == 0 ? TEXT("sk0") : TEXT("sk1"), bOk ? FString(D.Label) : FString(TEXT("LOCKED")),
			VW - (410.f + 100.f * Slot) * S, VH - (80.f + 70.f * Slot) * S, 84.f * S, 84.f * S, bOk && G->SkillReady(Slot) , bOk ? G->SkillCdFrac(Slot) : 0.f);
	}
	if (G->CanCycle()) Button(TEXT("swap"), TEXT("SWAP"), VW - 70.f * S, 130.f * S, 76.f * S, 60.f * S);
	Button(TEXT("pause"), TEXT("II"), VW - 50.f * S, 50.f * S, 56.f * S, 56.f * S);

	if (ADSPlayerController* PC = Cast<ADSPlayerController>(GetOwningPlayerController()))
		if (PC->bStickActive)
		{
			const float R = PC->StickMax;
			Box(PC->StickOrigin.X - R, PC->StickOrigin.Y - 1.f, 2.f * R, 2.f, FLinearColor(1, 1, 1, 0.15f));
			Box(PC->StickOrigin.X - 1.f, PC->StickOrigin.Y - R, 2.f, 2.f * R, FLinearColor(1, 1, 1, 0.15f));
			Box(PC->StickPos.X - 18.f * S, PC->StickPos.Y - 18.f * S, 36.f * S, 36.f * S, FLinearColor(0.85f, 0.81f, 0.72f, 0.5f), Gold);
		}
}

// ------------------------------------------------------------------ dialogue

void ADSHUD::DrawDialog()
{
	DrawRect(FLinearColor(0, 0, 0, 0.35f), 0, 0, VW, VH);
	const float X = 70.f * S, W = VW - 140.f * S, H = 176.f * S, Y = VH - H - 24.f * S;
	Box(X, Y, W, H, Ink, Gold);
	const FDSLine& L = G->DialogLines[FMath::Clamp(G->DialogIdx, 0, G->DialogLines.Num() - 1)];
	FString Who = L.Who;
	FString Text = L.Text;
	Text = Text.Left((int32)G->DialogShown);
	if (!Who.IsEmpty()) Txt(Who, X + 24.f * S, Y + 14.f * S, 1.3f * S, FLinearColor(0.95f, 0.82f, 0.48f));
	// word wrap
	const float MaxW = W - 48.f * S;
	float Cx = X + 24.f * S, Cy = Y + 50.f * S;
	TArray<FString> Words;
	Text.ParseIntoArray(Words, TEXT(" "));
	for (const FString& Word : Words)
	{
		float Tw = 0.f, Th = 0.f;
		GetTextSize(Word + TEXT(" "), Tw, Th, Font, 1.05f * S);
		if (Cx + Tw > X + 24.f * S + MaxW) { Cx = X + 24.f * S; Cy += Th + 4.f * S; }
		Txt(Word, Cx, Cy, 1.05f * S, Bone);
		Cx += Tw;
	}
	if (G->DialogShown >= FCString::Strlen(L.Text))
		Txt(TEXT("TAP TO CONTINUE"), X + W - 24.f * S, Y + H - 28.f * S, 0.8f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.5f + 0.4f * FMath::Sin(G->Time * 4.f)), 2);
}

// ------------------------------------------------------------------ shop

void ADSHUD::ShopRow(float X, float& Y, float W, const FString& Title, const FString& Level, const FString& Effect, const FString& Btn, bool bEnabled, const FString& Id)
{
	Txt(Title, X, Y + 10.f * S, 1.0f * S, Bone);
	Txt(Level, X + 250.f * S, Y + 10.f * S, 0.95f * S, FLinearColor(0.95f, 0.82f, 0.48f));
	Txt(Effect, X + 360.f * S, Y + 12.f * S, 0.8f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.65f));
	Button(Id, Btn, X + W - 90.f * S, Y + 22.f * S, 180.f * S, 44.f * S, bEnabled);
	Y += 54.f * S;
}

void ADSHUD::DrawShop()
{
	DrawRect(FLinearColor(0, 0, 0, 0.7f), 0, 0, VW, VH);
	const float W = FMath::Min(VW - 40.f * S, 1000.f * S);
	const float X = (VW - W) * 0.5f;
	Txt(TEXT("BONFIRE"), VW * 0.5f, 14.f * S, 2.f * S, FLinearColor(0.85f, 0.7f, 0.35f), 1);
	Txt(FString::Printf(TEXT("SOULS  %d     POTIONS  %d/%d     KEYS  %d/3%s"), G->Souls, G->Flasks, DSData::MaxPotions, G->Keys,
		G->WeaponsOwned[3] ? *FString::Printf(TEXT("     AMMO  %d"), G->Ammo) : TEXT("")), VW * 0.5f, 62.f * S, 1.0f * S, FLinearColor(0.95f, 0.82f, 0.48f), 1);
	static const TCHAR* Tabs[] = { TEXT("UPGRADES"), TEXT("SKILLS"), TEXT("SUPPLIES"), TEXT("GEAR") };
	for (int32 i = 0; i < 4; i++)
		Button(FString::Printf(TEXT("tab:%d"), i), Tabs[i], VW * 0.5f + (i - 1.5f) * 180.f * S, 112.f * S, 170.f * S, 42.f * S, G->ShopTab != i);

	float Y = 150.f * S;
	const int32 W0 = (int32)G->Equipped;
	const FDSWeaponDef& WD = DSData::Weapon(G->Equipped);
	auto StatRow = [&](int32 I)
	{
		const FDSStatDef& St = DSData::Stats()[I];
		const int32 L = G->Lv[I];
		if (L >= St.Max) ShopRow(X, Y, W, St.Label, TEXT("MAX"), St.Effect, TEXT("MAXED"), false, TEXT("none"));
		else
		{
			const int32 Cost = ADSGame::StatCost(St.BaseCost, L);
			ShopRow(X, Y, W, St.Label, FString::Printf(TEXT("Lv %d/%d"), L, St.Max), St.Effect, FString::Printf(TEXT("BUY  %d"), Cost), G->Souls >= Cost, FString::Printf(TEXT("stat:%d"), I));
		}
	};
	switch (G->ShopTab)
	{
	case 0:
	{
		const int32 T = G->WTier[W0];
		const FString Title = FString(TEXT("FORGE: ")) + FString(WD.Name).ToUpper();
		if (T < 4)
			ShopRow(X, Y, W, Title, FString::Printf(TEXT("Tier %d"), T + 1), FString::Printf(TEXT("%s -> %s (%d dmg)"), WD.Names[T], WD.Names[T + 1], (int32)WD.Dmg[T + 1]),
				FString::Printf(TEXT("FORGE  %d"), WD.Cost[T + 1]), G->Souls >= WD.Cost[T + 1], TEXT("tier"));
		else ShopRow(X, Y, W, Title, TEXT("MAX"), WD.Names[T], TEXT("MAXED"), false, TEXT("none"));
		for (int32 i = 0; i < 7; i++) if (i != 6) StatRow(i);
		break;
	}
	case 1:
		for (int32 Slot = 0; Slot < 2; Slot++)
		{
			const FDSSkillDef& D = DSData::Skill(G->Equipped, Slot);
			const FDSSkillState& St = G->Skills[W0][Slot];
			const FString Title = FString::Printf(TEXT("%s (%s)"), D.Name, WD.Name);
			const FString Id = FString::Printf(TEXT("skill:%d"), Slot);
			if (!St.bUnlocked) ShopRow(X, Y, W, Title, TEXT("LOCKED"), D.Desc, FString::Printf(TEXT("UNLOCK  %d"), D.Unlock), G->Souls >= D.Unlock, Id);
			else if (St.Level < DSData::MaxSkillLv)
			{
				const int32 Cost = (int32)(D.LvlCost * (1.f + 0.6f * St.Level));
				ShopRow(X, Y, W, Title, FString::Printf(TEXT("Lv %d/%d"), St.Level + 1, DSData::MaxSkillLv + 1), D.Desc, FString::Printf(TEXT("UPGRADE  %d"), Cost), G->Souls >= Cost, Id);
			}
			else ShopRow(X, Y, W, Title, TEXT("MAX"), D.Desc, TEXT("MAXED"), false, TEXT("none"));
		}
		break;
	case 2:
		ShopRow(X, Y, W, TEXT("HEALING POTION"), FString::Printf(TEXT("x%d"), G->Flasks), TEXT("Restores health"), FString::Printf(TEXT("BUY  %d"), DSData::PotionCost),
			G->Souls >= DSData::PotionCost && G->Flasks < DSData::MaxPotions, TEXT("potion"));
		if (G->WeaponsOwned[3])
			ShopRow(X, Y, W, TEXT("REVOLVER AMMO"), FString::Printf(TEXT("x%d"), G->Ammo), FString::Printf(TEXT("A pack of %d bullets"), DSData::AmmoPack), FString::Printf(TEXT("BUY  %d"), DSData::AmmoCost),
				G->Souls >= DSData::AmmoCost && G->Ammo < DSData::MaxAmmo, TEXT("ammo"));
		else ShopRow(X, Y, W, TEXT("REVOLVER AMMO"), TEXT("LOCKED"), TEXT("Win the revolver (quest 27)."), TEXT("???"), false, TEXT("none"));
		StatRow(6);
		break;
	default:
		for (int32 i = 0; i < 4; i++)
		{
			const FDSWeaponDef& D = DSData::Weapon((EDSWeapon)i);
			if (G->WeaponsOwned[i])
			{
				const bool bEq = W0 == i;
				ShopRow(X, Y, W, FString(D.Names[G->WTier[i]]).ToUpper(), FString::Printf(TEXT("Tier %d"), G->WTier[i] + 1), FString::Printf(TEXT("%d damage"), (int32)D.Dmg[G->WTier[i]]),
					bEq ? TEXT("EQUIPPED") : TEXT("EQUIP"), !bEq, FString::Printf(TEXT("eqw:%d"), i));
			}
			else ShopRow(X, Y, W, FString(D.Name).ToUpper(), TEXT("LOCKED"), TEXT("Found or won in the world."), TEXT("???"), false, TEXT("none"));
		}
		for (int32 i = 0; i < 4; i++)
		{
			const FDSArmorDef& A = DSData::Armor((EDSArmor)i);
			if (G->ArmorsOwned[i])
			{
				const bool bEq = (int32)G->Armor == i;
				ShopRow(X, Y, W, FString(A.Name).ToUpper(), TEXT("ARMOR"), A.Desc, bEq ? TEXT("WORN") : TEXT("WEAR"), !bEq, FString::Printf(TEXT("eqa:%d"), i));
			}
			else ShopRow(X, Y, W, FString(A.Name).ToUpper(), TEXT("LOCKED"), TEXT("Dropped by a boss."), TEXT("???"), false, TEXT("none"));
		}
		break;
	}
	Button(TEXT("continue"), TEXT("CONTINUE THE QUEST"), VW * 0.5f, VH - 44.f * S, 360.f * S, 52.f * S);
}

// ------------------------------------------------------------------ pause / end

void ADSHUD::DrawPause()
{
	DrawRect(FLinearColor(0, 0, 0, 0.6f), 0, 0, VW, VH);
	Txt(TEXT("PAUSED"), VW * 0.5f, VH * 0.25f, 3.f * S, FLinearColor(0.85f, 0.7f, 0.35f), 1);
	Button(TEXT("resume"), TEXT("RESUME"), VW * 0.5f, VH * 0.5f, 300.f * S, 58.f * S);
	Button(TEXT("title"), TEXT("QUIT TO TITLE"), VW * 0.5f, VH * 0.5f + 80.f * S, 300.f * S, 58.f * S);
}

void ADSHUD::DrawEnd()
{
	const float A = FMath::Clamp(G->EndTimer / 1.2f, 0.f, 1.f);
	const bool bWin = G->State == EDSState::Win;
	DrawRect(bWin ? FLinearColor(0, 0, 0, 0.45f * A) : FLinearColor(0.12f, 0, 0, 0.6f * A), 0, 0, VW, VH);
	DrawRect(FLinearColor(0, 0, 0, 0.6f * A), 0, VH * 0.5f - 80.f * S, VW, 160.f * S);
	Txt(bWin ? TEXT("PRINCESS RESCUED") : TEXT("YOU DIED"), VW * 0.5f, VH * 0.5f - 50.f * S, (bWin ? 4.f : 5.5f) * S,
		bWin ? FLinearColor(0.85f, 0.7f, 0.35f, A) : FLinearColor(0.6f, 0.11f, 0.08f, A), 1);
	if (G->EndTimer > 2.2f)
	{
		Txt(bWin ? FString(TEXT("THE KINGDOM OF ELDORIA IS SAVED")) : FString::Printf(TEXT("SOULS LOST: %d"), G->LostSouls), VW * 0.5f, VH * 0.5f + 100.f * S, 1.0f * S, Bone, 1);
		Txt(bWin ? TEXT("TAP TO RETURN") : TEXT("TAP TO TRY AGAIN"), VW * 0.5f, VH * 0.5f + 130.f * S, 0.9f * S, FLinearColor(Bone.R, Bone.G, Bone.B, 0.5f + 0.35f * FMath::Sin(G->Time * 3.f)), 1);
	}
}
